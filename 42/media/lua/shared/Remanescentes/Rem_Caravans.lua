-- Remanescentes - caravanas de troca entre os grupos.
--
-- Uma vez por dia, um grupo com comida sobrando pode mandar uma dupla carregada para um
-- grupo amigo (relacao boa, Rem_Relations) - ou para a SUA base, se forem seus aliados
-- (Rem_Alliance). A caravana anda pelo mapa:
--   * longe de voce: anda no papel; saqueadores perto do caminho podem emboscar (a carga
--     vai para eles e a rixa piora);
--   * perto de voce: a dupla aparece de verdade na rua, carregando as coisas nos bolsos
--     (da para conversar e trocar). As vezes saqueadores aparecem para emboscar - se voce
--     defender e a caravana sobreviver, o grupo dela fica te devendo uma;
--   * chegando: a carga vira suprimento do destino e a relacao entre os dois melhora. Na
--     sua base, os itens aparecem no estoque.
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_Barks"
require "Remanescentes/Rem_Journal"
require "Remanescentes/Rem_Relations"
require "Remanescentes/Rem_Ambient"
local Rem = Remanescentes
local AM = Rem.Ambient

local CV = Rem.module("Caravans", {
    MAX = 4,
    CHANCE = 35,              -- (%) por dia, para cada grupo que pode mandar
    MIN_DIST = 60,
    MAX_DIST = 450,
    SURPLUS = 3,              -- suprimentos por pessoa acima disso: manda caravana
    GOODS = 3,                -- suprimentos levados
    SPEED = 150,              -- tiles por hora
    ARRIVE = 8,
    AMBUSH_RADIUS = 250,
    AMBUSH_CHANCE = 3,        -- (%) por hora, com saqueadores inimigos perto do caminho
    REL_GAIN = 8,
    REL_LOSS = 20,
    SCENE_DIST = 45,          -- caravana a essa distancia: aparece de verdade
    SCENE_AMBUSH = 30,        -- (%) chance de emboscada quando aparece perto de voce
    SAVE_REP = 12,
    PEOPLE = 2,
    POCKET_ITEMS = 4,
})
local CFG = CV.CFG

Rem.BARKS.caravan = { n = 3, cd = 90000 }
Rem.BARKS.caravan_ambush = { urgent = true, n = 3, cd = 0 }
Rem.BARKS.caravan_saved = { urgent = true, n = 2, cd = 0 }

CV.GOODS_LOOT = { "Base.TinnedBeans", "Base.TinnedSoup", "Base.CannedCorn", "Base.WaterRationCan", "Base.Crackers",
    "Base.Bandage", "Base.Pills", "Base.Nails" }

local function groups() return Rem.getStore().groups end
local function known(g) return g and Rem.Journal.knows(g) end

function CV.list()
    local s = Rem.getStore()
    s.caravans = s.caravans or {}
    return s.caravans
end

function CV.get(id)
    for _, c in ipairs(CV.list()) do if c.id == id then return c end end
    return nil
end

local function remove(c)
    local list = CV.list()
    for i = #list, 1, -1 do if list[i] == c then table.remove(list, i) end end
end

-- ---------------------------------------------------------------- mandar
local function canSend(g)
    return g.home and not g.player and g.activity == "home" and #g.members >= 3
        and (g.supplies or 0) > #g.members * CFG.SURPLUS
end

-- Destino de uma caravana de g: a sua base (se aliados) ou o grupo amigo mais perto.
function CV.destFor(g)
    local base = Rem.PlayerBase and Rem.PlayerBase.get()
    if base and g.allied and Rem.dist2(g.home.x, g.home.y, base.home.x, base.home.y) <= CFG.MAX_DIST then return base end
    local best, bestD = nil, nil
    for _, o in pairs(groups()) do
        if o ~= g and o.home and not o.player and #o.members > 0 and Rem.relation(g, o) >= Rem.Relations.CFG.TRADE_AT then
            local d = Rem.dist2(g.home.x, g.home.y, o.home.x, o.home.y)
            if d >= CFG.MIN_DIST and d <= CFG.MAX_DIST and (not bestD or d < bestD) then best, bestD = o, d end
        end
    end
    return best
end

function CV.send(g, dest)
    local s = Rem.getStore()
    s.caravanSeq = (s.caravanSeq or 0) + 1
    local c = { id = "cv" .. s.caravanSeq, from = g.id, to = dest.id, faction = g.faction,
        x = g.home.x, y = g.home.y, tx = dest.home.x, ty = dest.home.y, goods = CFG.GOODS, at = Rem.worldHours() }
    g.supplies = g.supplies - CFG.GOODS
    table.insert(CV.list(), c)
    if dest.player then Rem.Journal.add("IGUI_Rem_Journal_caravan_coming", Rem.Journal.groupName(g)) end
    Rem.debug("caravana " .. c.id .. ": " .. g.id .. " -> " .. dest.id)
    return c
end

function CV.daily()
    local list = {}
    for _, g in pairs(groups()) do if canSend(g) then table.insert(list, g) end end
    table.sort(list, function(a, b) return a.id < b.id end)
    local sent = 0
    for _, g in ipairs(list) do
        if #CV.list() >= CFG.MAX then break end
        if ZombRand(100) < CFG.CHANCE then
            local dest = CV.destFor(g)
            if dest then CV.send(g, dest) sent = sent + 1 end
        end
    end
    return sent
end
Events.EveryDays.Add(function() if Rem.isAuthority() then Rem.safe(CV.daily) end end)

-- ---------------------------------------------------------------- chegar ou cair
function CV.arrive(c)
    local from, to = groups()[c.from], groups()[c.to]
    remove(c)
    if not to then return "lost" end
    to.supplies = (to.supplies or 0) + c.goods
    if from then Rem.changeRelation(from, to, CFG.REL_GAIN) end
    if to.player then
        to.pendingList = to.pendingList or {}
        for _ = 1, math.floor(c.goods * Rem.World.CFG.ITEMS_PER_SUPPLY) do table.insert(to.pendingList, Rem.pick(CV.GOODS_LOOT)) end
        Rem.Journal.add("IGUI_Rem_Journal_caravan_arrived", from and Rem.Journal.groupName(from) or "?")
    end
    Rem.emit("caravanArrived", c, from, to)
    return "arrived"
end

-- Saqueadores inimigos perto do ponto (x, y), ou nil.
function CV.raidersNear(c)
    local from = groups()[c.from]
    for _, g in pairs(groups()) do
        if g.faction == "saqueadores" and g.home and #g.members >= 2 and g.id ~= c.from
            and Rem.dist2(c.x, c.y, g.home.x, g.home.y) <= CFG.AMBUSH_RADIUS
            and (not from or Rem.relation(from, g) <= Rem.Relations.CFG.ENEMY_AT or Rem.factionsHostile(c.faction, g.faction)) then
            return g
        end
    end
    return nil
end

function CV.ambushed(c, raiders)
    local from = groups()[c.from]
    remove(c)
    if raiders then
        raiders.supplies = (raiders.supplies or 0) + c.goods
        if from then Rem.changeRelation(from, raiders, -CFG.REL_LOSS) end
    end
    if known(from) or (groups()[c.to] and groups()[c.to].player) then
        Rem.Journal.add("IGUI_Rem_Journal_caravan_lost", from and Rem.Journal.groupName(from) or "?",
            raiders and Rem.Journal.groupName(raiders) or "?")
    end
    Rem.emit("caravanLost", c, raiders)
end

function CV.hourly()
    local list = {}
    for _, c in ipairs(CV.list()) do table.insert(list, c) end
    for _, c in ipairs(list) do
        if not c.onScene then
            local d = Rem.dist2(c.x, c.y, c.tx, c.ty)
            if d <= CFG.ARRIVE + CFG.SPEED then
                c.x, c.y = c.tx, c.ty
                CV.arrive(c)
            else
                c.x, c.y = c.x + (c.tx - c.x) / d * CFG.SPEED, c.y + (c.ty - c.y) / d * CFG.SPEED
                local raiders = CV.raidersNear(c)
                if raiders and ZombRand(100) < CFG.AMBUSH_CHANCE then CV.ambushed(c, raiders) end
            end
        end
    end
end
Rem.on("worldHour", function() Rem.safe(CV.hourly) end)

-- ---------------------------------------------------------------- em cena
local function activeById(id)
    for _, npc in pairs(Rem.active) do if npc.rec.id == id then return npc end end
    return nil
end

local function pocketsFor()
    local out = {}
    for _ = 1, CFG.POCKET_ITEMS do table.insert(out, Rem.pick(CV.GOODS_LOOT)) end
    return out
end

-- A caravana chegou perto de voce: a dupla aparece (e talvez uma emboscada).
function CV.show(c, player)
    local sq = getCell():getGridSquare(math.floor(c.x), math.floor(c.y), 0)
    if not sq or not sq:isFree(false) or sq:getRoom() then sq = AM.spawnPoint(player, 20, 35) end
    if not sq then return nil end
    c.people, c.dead = {}, 0
    local lead = nil
    for i = 1, CFG.PEOPLE do
        local npc = AM.makePerson(sq, { faction = c.faction, ambient = "caravan" })
        if npc then
            npc.rec.caravanId = c.id
            npc.rec.pockets = pocketsFor()
            if lead then npc.rec.followId = lead.rec.id else lead = npc end
            table.insert(c.people, npc.rec.id)
        end
    end
    if not lead then return nil end
    c.onScene = true
    Rem.bark(lead, "caravan")
    -- emboscada
    if Rem.Timeline.raiderFactor() > 0 and ZombRand(100) < CFG.SCENE_AMBUSH then
        c.ambush = {}
        local rsq = AM.spawnPoint(player, 14, 24)
        for _ = 1, 2 do
            local r = rsq and AM.makePerson(rsq, { faction = "saqueadores", ambient = "caravan_raider", hostileToPlayer = true })
            if r then
                r.rec.caravanId = c.id
                r.rec.foeId = lead.rec.id
                table.insert(c.ambush, r.rec.id)
            end
        end
        if #c.ambush > 0 then
            Rem.bark(lead, "caravan_ambush", true)
            Rem.Journal.add("IGUI_Rem_Journal_caravan_ambush", Rem.Journal.groupName(groups()[c.from]))
        else
            c.ambush = nil
        end
    end
    return lead
end

-- Acompanha a caravana em cena: posicao, emboscada resolvida, saiu de cena.
function CV.track(c)
    local alive = {}
    for _, id in ipairs(c.people or {}) do
        local npc = activeById(id)
        if npc then
            -- (o lider morreu: o outro segue com a carga em vez de ir embora)
            if npc.rec.ambient ~= "caravan" then npc.rec.ambient, npc.rec.followId = "caravan", nil end
            table.insert(alive, npc)
        end
    end
    if #alive == 0 then
        -- morreram todos (ou sairam de cena: a caravana segue no papel)
        if (c.dead or 0) >= #(c.people or {}) and #(c.people or {}) > 0 then
            CV.ambushed(c, CV.raidersNear(c))
            return "lost"
        end
        c.onScene, c.people, c.ambush = nil, nil, nil
        return "paper"
    end
    c.x, c.y = alive[1].z:getX(), alive[1].z:getY()
    if c.ambush then
        local left = 0
        for _, id in ipairs(c.ambush) do if activeById(id) then left = left + 1 end end
        if left == 0 then
            c.ambush = nil
            local from = groups()[c.from]
            if from then Rem.changeRep(from.id, CFG.SAVE_REP, "defendeu a caravana") end
            Rem.bark(alive[1], "caravan_saved", true)
            if from then Rem.Journal.add("IGUI_Rem_Journal_caravan_saved", Rem.Journal.groupName(from)) end
            return "saved"
        end
    end
    if Rem.dist2(c.x, c.y, c.tx, c.ty) <= CFG.ARRIVE then
        for _, npc in ipairs(alive) do Rem.dismiss(npc) end
        c.onScene = nil
        CV.arrive(c)
        return "arrived"
    end
    return "moving"
end

function CV.tick(player, now)
    for _, c in ipairs(CV.list()) do
        if c.onScene then
            CV.track(c)
        elseif Rem.dist2(player:getX(), player:getY(), c.x, c.y) <= CFG.SCENE_DIST then
            CV.show(c, player)
        end
    end
end
local nextTick = 0
Rem.on("sceneUpdate", function(player, now)
    if now < nextTick then return end
    nextTick = now + 1000
    Rem.safe(CV.tick, player, now)
end)

Rem.on("npcDied", function(npc)
    local c = npc.rec.caravanId and CV.get(npc.rec.caravanId)
    if c and npc.rec.ambient == "caravan" then c.dead = (c.dead or 0) + 1 end
end)

-- Andar: o lider vai para o destino (o segundo segue o lider, Rem_Ambient).
AM.HANDLERS.caravan = function(npc, ctx, now)
    local c = CV.get(npc.rec.caravanId)
    if not c then
        AM.leave(npc, ctx.player)
        return true
    end
    npc.rec.expiresAt = Rem.worldHours() + 3          -- (nao some enquanto viaja)
    local d = Rem.distXY(npc.z, c.tx, c.ty)
    local step = math.min(d, 30)
    if d < 0.5 then Rem.idle(npc, now) return true end
    Rem.moveTo(npc, npc.z:getX() + (c.tx - npc.z:getX()) / d * step, npc.z:getY() + (c.ty - npc.z:getY()) / d * step, 0, now, "walk")
    if ctx.player and Rem.dist(npc.z, ctx.player) < 10 then Rem.bark(npc, "caravan") end
    return true
end

-- Emboscada: vao atras da caravana (a briga e do cerebro).
AM.HANDLERS.caravan_raider = function(npc, ctx, now)
    local c = CV.get(npc.rec.caravanId)
    local lead = c and c.people and activeById(c.people[1])
    if not lead then
        AM.leave(npc, ctx.player)
        return true
    end
    Rem.moveTo(npc, lead.z:getX(), lead.z:getY(), lead.z:getZ(), now, "run")
    return true
end

Rem.registerDebugOption("ContextMenu_Rem_CaravanHere", function(x, y, z, player)
    local from = nil
    for _, g in pairs(groups()) do if g.home and not g.player and #g.members > 0 then from = g break end end
    if not from then player:Say("-") return end
    local s = Rem.getStore()
    s.caravanSeq = (s.caravanSeq or 0) + 1
    local c = { id = "cv" .. s.caravanSeq, from = from.id, to = from.id, faction = from.faction, x = x + 30, y = y,
        tx = from.home.x, ty = from.home.y, goods = CFG.GOODS, at = Rem.worldHours() }
    table.insert(CV.list(), c)
    player:Say("caravana " .. c.id)
end, "ambient")
