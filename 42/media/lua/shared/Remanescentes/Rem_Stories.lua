-- Remanescentes - historias: eventos com comeco, meio e fim (usam a estrutura de
-- Rem_Ambient: AM.SPAWN / AM.HANDLERS / AM.WEIGHTS / AM.WEIGHT_MOD).
--
--   trader    mascate: errante com a mochila cheia, cruza a area; para e oferece troca quando
--             voce chega perto (Conversar -> Quero trocar).
--   mourner   alguem sentado, de luto por quem perdeu. Conversar ou dar um presente cria vinculo.
--   ambush    emboscada: um "ferido" pedindo socorro SEM zumbis em volta, com comparsas
--             escondidos. Chegou perto: "Agora!" e viram saqueadores (assalto normal).
--             So depois do dia dos saqueadores e fora da zona de graca.
--   hostage   refem: saqueadores guardando um civil rendido. Sem os captores por perto, ele
--             fica livre: agradece (vinculo e reputacao com os civis), espera um pouco para
--             voce chama-lo (Conversar -> Quer vir comigo?) e vai embora.
--   cerco     (nao e de passagem) um grupo amigo que voce conhece e atacado por uma horda. Um
--             mensageiro corre ate voce, pede ajuda e marca a casa no mapa. Chegando la, os
--             zumbis estao em volta: limpe-os para salvar o grupo (reputacao, vinculo com
--             todos). Se ninguem ajudar ate o prazo, o grupo perde gente (ou a casa cai).
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_Ambient"
require "Remanescentes/Rem_Timeline"
require "Remanescentes/Rem_MapMarks"
require "Remanescentes/Rem_Spatial"
local Rem = Remanescentes
local AM = Rem.Ambient

local ST = Rem.module("Stories", {
    TRADER_DAY = 1,               -- mascates aparecem a partir deste dia
    TRADER_GOODS = { 6, 9 },
    TRADER_STOP_DIST = 7,
    TRADER_WAIT_MS = 90000,
    MOURN_MS = 240000,
    AMBUSH_TRIGGER = 5,           -- voce chegou a essa distancia do "ferido"
    AMBUSH_TIMEOUT_MS = 180000,
    AMBUSH_HIDE = { 7, 10 },      -- distancia dos comparsas ao "ferido"
    HOSTAGE_GUARD_RADIUS = 30,    -- captor vivo a essa distancia: ainda preso
    HOSTAGE_FREE_DIST = 12,       -- voce a essa distancia quando ele fica livre: conta como resgate
    HOSTAGE_WAIT_MS = 75000,      -- quanto espera voce chama-lo
    HOSTAGE_REP = 8,
    SIEGE_REP_MIN = 15,           -- so grupos que gostam de voce pedem ajuda
    SIEGE_CHANCE = 3,             -- (%) por hora, com um grupo candidato
    SIEGE_COOLDOWN_HOURS = 48,
    SIEGE_HOURS = 10,             -- prazo
    SIEGE_DIST = { 60, 450 },     -- distancia da casa ate voce
    SIEGE_ZOMBIES = { 8, 14 },
    SIEGE_ARRIVE = 45,            -- chegou a essa distancia: a horda aparece
    SIEGE_RADIUS = 16,            -- zumbis a essa distancia da casa contam
    SIEGE_SETTLE_MS = 6000,
    SIEGE_REP = 20,
    SIEGE_LOSSES = { 1, 2 },
    MESSENGER_REACH = 4,
})
local CFG = ST.CFG

ST.TRADE_GOODS = { "Base.TinnedBeans", "Base.TinnedSoup", "Base.CannedChili", "Base.CannedCorn", "Base.BeefJerky",
    "Base.Crackers", "Base.WaterRationCan", "Base.Bandage", "Base.Disinfectant", "Base.Pills", "Base.Antibiotics",
    "Base.Matches", "Base.Candle", "Base.HandTorch", "Base.Nails", "Base.CigarettePack", "Base.Whiskey",
    "Base.Bullets9mmBox", "Base.ShotgunShellsBox", "Base.HuntingKnife" }

Rem.BARKS.trader = { urgent = true, n = 4, cd = 15000 }
Rem.BARKS.ambush = { urgent = true, n = 3, cd = 0 }
Rem.BARKS.hostage = { urgent = true, n = 3, cd = 20000 }
Rem.BARKS.captor = { urgent = true, n = 3, cd = 25000 }
Rem.BARKS.freed = { urgent = true, n = 3, cd = 0 }
Rem.BARKS.siege_call = { urgent = true, n = 3, cd = 0 }
Rem.BARKS.siege_help = { urgent = true, n = 3, cd = 20000 }
Rem.BARKS.siege_won = { urgent = true, n = 3, cd = 0 }

local function civilOutfit()
    return Rem.pick((Rem.FACTIONS.civis and Rem.FACTIONS.civis.outfits) or { "Generic01" })
end

local function squareNear(x, y, minD, maxD)
    local cell = getCell()
    for _ = 1, 12 do
        local a = ZombRandFloat(0, 6.283)
        local d = ZombRandFloat(minD, maxD)
        local sq = cell:getGridSquare(math.floor(x + math.cos(a) * d), math.floor(y + math.sin(a) * d), 0)
        if sq and not sq:getRoom() and sq:isFree(false) then return sq end
    end
    return nil
end

local function stayAt(npc, now, pose)
    local rec = npc.rec
    if Rem.dist2(npc.z:getX(), npc.z:getY(), rec.spotX, rec.spotY) > 1.5 then
        Rem.moveTo(npc, rec.spotX, rec.spotY, 0, now, "walk")
        return false
    end
    Rem.stopMoving(npc)
    if pose then Rem.setRest(npc, pose) end
    return true
end

-- ---------------------------------------------------------------- mascate
AM.WEIGHTS.trader = 7
AM.WEIGHT_MOD.trader = function(w) return (Rem.Timeline.day() >= CFG.TRADER_DAY) and w or 0 end

function AM.SPAWN.trader(player, sq)
    local npc = AM.makePerson(sq, { faction = "errantes", ambient = "trader",
        personality = { agressividade = 3, confianca = 6, coragem = 6, ganancia = 7, lealdade = 3 } })
    if not npc then return nil end
    local rec = npc.rec
    rec.destX, rec.destY = AM.crossDest(sq:getX(), sq:getY(), player)
    rec.gait = "walk"
    rec.carry = {}
    for _ = 1, ZombRand(CFG.TRADER_GOODS[1], CFG.TRADER_GOODS[2] + 1) do
        table.insert(rec.carry, Rem.pick(ST.TRADE_GOODS))
    end
    return { npc }
end

function AM.HANDLERS.trader(npc, ctx, now)
    local player = ctx.player
    if not player or Rem.dist(npc.z, player) > CFG.TRADER_STOP_DIST then return false end
    npc.traderSince = npc.traderSince or now
    if now - npc.traderSince > CFG.TRADER_WAIT_MS then return false end   -- cansou de esperar: segue viagem
    Rem.stopMoving(npc)
    Rem.safe(function() npc.z:faceThisObject(player) end)
    Rem.bark(npc, "trader")
    return true
end

-- ---------------------------------------------------------------- enlutado
AM.WEIGHTS.mourner = 5

function AM.SPAWN.mourner(player, sq)
    local npc = AM.makePerson(sq, { faction = "civis", ambient = "mourner" })
    if not npc then return nil end
    local rec = npc.rec
    rec.spotX, rec.spotY = sq:getX() + 0.5, sq:getY() + 0.5
    rec.griefFor = Rem.pick(Rem.NAMES)
    rec.griefUntil = Rem.worldHours() + 24
    rec.moral = 20
    rec.mournUntil = Rem.nowMs() + CFG.MOURN_MS
    return { npc }
end

function AM.HANDLERS.mourner(npc, ctx, now)
    local rec = npc.rec
    if now > (rec.mournUntil or 0) then
        Rem.clearRest(npc)
        AM.leave(npc, ctx.player)
        return true
    end
    if stayAt(npc, now, "sit") then Rem.bark(npc, "idle") end
    return true
end

-- ---------------------------------------------------------------- emboscada
AM.WEIGHTS.ambush = 6
AM.WEIGHT_MOD.ambush = function(w, x, y)
    if Rem.Timeline.protects(x, y) then return 0 end
    return w * Rem.Timeline.raiderFactor()
end

local function ambushers(id)
    local list = {}
    for _, npc in pairs(Rem.active) do
        if npc.rec.ambushId == id then table.insert(list, npc) end
    end
    return list
end

-- Cai a mascara: todos viram saqueadores comuns (o assalto segue por Rem_Mugging).
function ST.reveal(id, shout)
    local list = ambushers(id)
    for _, npc in ipairs(list) do
        local rec = npc.rec
        rec.disguised, rec.ambushId = nil, nil
        rec.hostileToPlayer = true
        rec.stealth = false
        rec.ambient = "raider"
        rec.spotX, rec.spotY = nil, nil
        Rem.clearRest(npc)
        Rem.setGait(npc, "walk")
        Rem.applyFriendlyFire(npc)
        local player = getPlayer()
        if shout and player and Rem.Awareness and Rem.Awareness.alert then
            Rem.Awareness.alert(npc, player, Rem.nowMs())   -- eles ja sabem onde voce esta
        end
    end
    if shout and list[1] then Rem.bark(shout, "ambush", true) end
    Rem.debug("emboscada revelada (" .. #list .. ")")
    return #list
end

function AM.SPAWN.ambush(player, sq)
    if Rem.Timeline.protects(sq:getX(), sq:getY()) then return AM.SPAWN.walker(player, sq) end
    local decoy = AM.makePerson(sq, { faction = "saqueadores", ambient = "ambush", outfit = civilOutfit(),
        hostileToPlayer = false })
    if not decoy then return nil end
    local id = decoy.rec.id
    local list = { decoy }
    decoy.rec.disguised, decoy.rec.ambushId = true, id
    decoy.rec.hostileToPlayer = false
    decoy.rec.spotX, decoy.rec.spotY = sq:getX() + 0.5, sq:getY() + 0.5
    decoy.rec.ambushUntil = Rem.nowMs() + CFG.AMBUSH_TIMEOUT_MS
    decoy.rec.ambushHp = decoy.z:getHealth()
    Rem.applyFriendlyFire(decoy)
    for _ = 1, ZombRand(1, 3) do
        local hide = squareNear(sq:getX(), sq:getY(), CFG.AMBUSH_HIDE[1], CFG.AMBUSH_HIDE[2])
        local m = hide and AM.makePerson(hide, { faction = "saqueadores", ambient = "ambush_wait", stealth = true,
            hostileToPlayer = false })
        if m then
            m.rec.disguised, m.rec.ambushId = true, id
            m.rec.hostileToPlayer = false
            m.rec.spotX, m.rec.spotY = hide:getX() + 0.5, hide:getY() + 0.5
            Rem.applyFriendlyFire(m)
            table.insert(list, m)
        end
    end
    Rem.bark(decoy, "help", true)
    return list
end

function AM.HANDLERS.ambush(npc, ctx, now)
    local rec = npc.rec
    local player = ctx.player
    local hit = npc.z:getHealth() < (rec.ambushHp or 0) - 0.01
    if hit or (player and Rem.dist(npc.z, player) <= CFG.AMBUSH_TRIGGER) then
        ST.reveal(rec.ambushId, npc)
        return true
    end
    if now > (rec.ambushUntil or 0) then   -- ninguem caiu: desistem e vao embora
        ST.reveal(rec.ambushId, nil)
        return true
    end
    if stayAt(npc, now, "sit") then Rem.bark(npc, "help") end
    return true
end

function AM.HANDLERS.ambush_wait(npc, ctx, now)
    local found = false
    for _, other in ipairs(ambushers(npc.rec.ambushId)) do
        if other.rec.ambient == "ambush" then found = true end
    end
    if not found then   -- o "ferido" morreu ou sumiu: acabou o teatro
        ST.reveal(npc.rec.ambushId, nil)
        return true
    end
    Rem.setGait(npc, "sneak")
    stayAt(npc, now, nil)
    return true
end

-- ---------------------------------------------------------------- refem
AM.WEIGHTS.hostage = 5
AM.WEIGHT_MOD.hostage = AM.WEIGHT_MOD.ambush

function AM.SPAWN.hostage(player, sq)
    if Rem.Timeline.protects(sq:getX(), sq:getY()) then return AM.SPAWN.walker(player, sq) end
    local captive = AM.makePerson(sq, { faction = "civis", ambient = "hostage" })
    if not captive then return nil end
    local list = { captive }
    captive.rec.captive = true
    captive.rec.spotX, captive.rec.spotY = sq:getX() + 0.5, sq:getY() + 0.5
    captive.rec.moral = 15
    for _ = 1, 2 do
        local s = squareNear(sq:getX(), sq:getY(), 1.5, 3) or sq
        local m = AM.makePerson(s, { faction = "saqueadores", ambient = "captor" })
        if m then
            m.rec.captiveId = captive.rec.id
            m.rec.spotX, m.rec.spotY = s:getX() + 0.5, s:getY() + 0.5
            table.insert(list, m)
        end
    end
    if #list == 1 then   -- sem captores nao ha historia
        captive.rec.captive = nil
        captive.rec.ambient = "walker"
    end
    return list
end

function ST.guarded(captive)
    for _, npc in pairs(Rem.active) do
        if npc.rec.captiveId == captive.rec.id and not npc.rec.surrendered and not npc.fleeing
            and Rem.dist(npc.z, captive.z) <= CFG.HOSTAGE_GUARD_RADIUS then
            local E = Rem.Mugging and Rem.Mugging.of(npc)
            if not (E and E.stage == "rout") then return true end
        end
    end
    return false
end

function AM.HANDLERS.hostage(npc, ctx, now)
    local rec = npc.rec
    local player = ctx.player
    if ST.guarded(npc) then
        if stayAt(npc, now, "sit") and player and Rem.dist(npc.z, player) <= 15 then Rem.bark(npc, "hostage") end
        return true
    end
    -- livre
    rec.captive = nil
    Rem.clearRest(npc)
    if player and Rem.dist(npc.z, player) <= CFG.HOSTAGE_FREE_DIST then
        rec.ambient = "freed"
        rec.freedUntil = now + CFG.HOSTAGE_WAIT_MS
        Rem.bark(npc, "freed", true)
        if Rem.changeRep then Rem.changeRep("f:civis", CFG.HOSTAGE_REP, "libertou um refem") end
        Rem.emit("playerDeed", "rescued", npc)
    else
        AM.leave(npc, player)
        rec.gait = "run"
    end
    return true
end

-- Solto: fica perto de voce um tempo (da para chama-lo para o seu grupo) e vai embora.
function AM.HANDLERS.freed(npc, ctx, now)
    local player = ctx.player
    if npc.rec.faction == "aliados" then return false end
    if not player or now > (npc.rec.freedUntil or 0) or Rem.dist(npc.z, player) > 25 then
        AM.leave(npc, player)
        return true
    end
    if Rem.dist(npc.z, player) > 3.5 then
        Rem.moveTo(npc, player:getX(), player:getY(), player:getZ(), now, "walk")
    else
        Rem.stopMoving(npc)
        Rem.safe(function() npc.z:faceThisObject(player) end)
    end
    return true
end

function AM.HANDLERS.captor(npc, ctx, now)
    local rec = npc.rec
    local alive = false
    for _, other in pairs(Rem.active) do
        if other.rec.id == rec.captiveId and other.rec.captive then alive = true end
    end
    if not alive then
        rec.captiveId, rec.spotX, rec.spotY = nil, nil, nil
        rec.ambient = "raider"
        return false
    end
    Rem.hangAround(npc, rec.spotX, rec.spotY, 0, now, 2)
    Rem.bark(npc, "captor")
    return true
end

-- ---------------------------------------------------------------- cerco
local function siegeStore() return Rem.getStore() end

local function membersOf(g)
    local out = {}
    for _, id in ipairs(g.members) do
        local p = Rem.getPerson(id)
        if p then table.insert(out, p) end
    end
    return out
end

function ST.siegeCandidates(player)
    local out = {}
    local store = Rem.getStore()
    local known = store.knownGroups or {}
    local px, py = player:getX(), player:getY()
    for id, g in pairs(store.groups) do
        local h = g.home
        if h and h.x1 and not Rem.Timeline.isHostileFaction(g.faction)
            and (known[id] or Rem.MapMarks.find("group:" .. id) or Rem.MapMarks.find("shelter:" .. id))
            and Rem.getRep(id) >= CFG.SIEGE_REP_MIN and #g.members > 0 then
            local d = Rem.dist2(px, py, h.x, h.y)
            if d >= CFG.SIEGE_DIST[1] and d <= CFG.SIEGE_DIST[2] then table.insert(out, g) end
        end
    end
    table.sort(out, function(a, b) return tostring(a.id) < tostring(b.id) end)
    return out
end

function ST.startSiege(g)
    local hours = Rem.worldHours()
    local s = { group = g.id, x = g.home.x, y = g.home.y, startH = hours, untilH = hours + CFG.SIEGE_HOURS,
        messenger = true }
    siegeStore().siege = s
    Rem.debug("cerco: a casa do grupo " .. g.id .. " esta sendo atacada")
    return s
end

function ST.hourly()
    local store = Rem.getStore()
    local hours = Rem.worldHours()
    local s = store.siege
    if s then
        if hours >= s.untilH then ST.endSiege(false) end
        return
    end
    if store.siegeLastH and hours - store.siegeLastH < CFG.SIEGE_COOLDOWN_HOURS then return end
    local player = getPlayer()
    if not player then return end
    local list = ST.siegeCandidates(player)
    if #list == 0 or ZombRand(100) >= CFG.SIEGE_CHANCE then return end
    ST.startSiege(Rem.pick(list))
end
Rem.on("worldHour", function() Rem.safe(ST.hourly) end)

-- O grupo aguentou sozinho ou nao: sem ajuda, perde gente; se sobrar pouca gente, a casa cai.
function ST.endSiege(won, player)
    local store = Rem.getStore()
    local s = store.siege
    if not s then return end
    store.siege = nil
    store.siegeLastH = Rem.worldHours()
    local g = store.groups[s.group]
    if not g then return end
    if won then
        if Rem.changeRep then Rem.changeRep(g.id, CFG.SIEGE_REP, "defendeu a casa") end
        local speaker = nil
        for _, npc in pairs(Rem.active) do
            if npc.rec.groupId == g.id then speaker = speaker or npc end
        end
        if speaker then
            Rem.bark(speaker, "siege_won", true)
            Rem.emit("playerDeed", "sieged", speaker)
        end
        Rem.debug("cerco: voce salvou o grupo " .. g.id)
        Rem.emit("siegeEnded", g, true, s)
        return
    end
    Rem.emit("siegeEnded", g, false, s)
    local list = membersOf(g)
    local losses = ZombRand(CFG.SIEGE_LOSSES[1], CFG.SIEGE_LOSSES[2] + 1)
    if #list - losses <= 1 and Rem.Evolution and Rem.Evolution.fall then
        Rem.Evolution.fall(g)
        return
    end
    for _ = 1, losses do
        local p = table.remove(list)
        if p and not p.onScene then
            for i = #g.members, 1, -1 do if g.members[i] == p.id then table.remove(g.members, i) end end
            if Rem.Persona then Rem.Persona.mourn(p) end
            Rem.removePerson(p.id)
        end
    end
    Rem.debug("cerco: o grupo " .. g.id .. " perdeu gente")
end

local function spawnHorde(s, g)
    local h = g.home
    local n = ZombRand(CFG.SIEGE_ZOMBIES[1], CFG.SIEGE_ZOMBIES[2] + 1)
    local outfits = (Rem.FACTIONS.civis and Rem.FACTIONS.civis.outfits) or { "Generic01" }
    local made = 0
    for _ = 1, n do
        -- em volta da casa, do lado de fora
        local side = ZombRand(4)
        local x = ZombRand(h.x1 - 5, h.x2 + 6)
        local y = ZombRand(h.y1 - 5, h.y2 + 6)
        if side == 0 then y = h.y1 - ZombRand(3, 6) elseif side == 1 then y = h.y2 + ZombRand(3, 6)
        elseif side == 2 then x = h.x1 - ZombRand(3, 6) else x = h.x2 + ZombRand(3, 6) end
        local ok = Rem.safe(function()
            addZombiesInOutfit(math.floor(x), math.floor(y), 0, 1, Rem.pick(outfits), 50,
                false, false, false, false, false, false, 1.0)
        end)
        if ok then made = made + 1 end
    end
    s.spawned, s.spawnedAt, s.count = true, Rem.nowMs(), made
    Rem.debug("cerco: " .. made .. " zumbis em volta da casa do grupo " .. g.id)
end

local function zombiesAround(x, y, r)
    local n = 0
    local list = Rem.zombiesNear(x, y, r)
    for i = 1, #list do
        if not Rem.active[list[i]] and not list[i]:isDead() then n = n + 1 end
    end
    return n
end

-- Mensageiro: corre ate voce, avisa, marca no mapa e volta.
function ST.sendMessenger(player, s, g)
    if Rem.activeCount >= Rem.cfg("MaxActive", 12) then return nil end
    local sq = AM.spawnPoint(player, AM.CFG.SPAWN_MIN, AM.CFG.SPAWN_MAX)
    if not sq then return nil end
    local npc = AM.makePerson(sq, { faction = g.faction, ambient = "messenger" })
    if not npc then return nil end
    npc.rec.siegeGroup = g.id
    npc.rec.gait = "run"
    s.messenger = false
    return npc
end

function AM.HANDLERS.messenger(npc, ctx, now)
    local rec = npc.rec
    local player = ctx.player
    local s = Rem.getStore().siege
    if not player or not s or s.group ~= rec.siegeGroup then
        AM.leave(npc, player)
        return true
    end
    if Rem.dist(npc.z, player) > CFG.MESSENGER_REACH then
        Rem.moveTo(npc, player:getX(), player:getY(), player:getZ(), now, "run")
        return true
    end
    Rem.stopMoving(npc)
    Rem.safe(function() npc.z:faceThisObject(player) end)
    Rem.bark(npc, "siege_call", true)
    local g = Rem.getStore().groups[s.group]
    Rem.MapMarks.add({ id = "siege:" .. s.group .. ":" .. tostring(math.floor(s.startH)), x = s.x, y = s.y, symbol = "Target",
        color = Rem.MapMarks.COLORS.quest, text = getText("IGUI_Rem_Map_siege", tostring(g and g.name or "?")) }, nil)
    s.told = true
    Rem.emit("siegeTold", g)
    -- volta correndo para casa
    rec.ambient = "walker"
    rec.destX, rec.destY = math.floor(s.x), math.floor(s.y)
    rec.gait = "run"
    return true
end

function ST.tick(player, now)
    local store = Rem.getStore()
    local s = store.siege
    if not s then return end
    local g = store.groups[s.group]
    if not g or not g.home then store.siege = nil return end
    if s.messenger then ST.sendMessenger(player, s, g) end
    local d = Rem.dist2(player:getX(), player:getY(), s.x, s.y)
    if not s.spawned then
        if d <= CFG.SIEGE_ARRIVE and getCell():getGridSquare(math.floor(s.x), math.floor(s.y), 0) then
            spawnHorde(s, g)
        end
        return
    end
    -- moradores pedem ajuda enquanto a horda esta la
    for _, npc in pairs(Rem.active) do
        if npc.rec.groupId == g.id then Rem.bark(npc, "siege_help") end
    end
    if now - s.spawnedAt >= CFG.SIEGE_SETTLE_MS and d <= CFG.SIEGE_ARRIVE
        and zombiesAround(s.x, s.y, CFG.SIEGE_RADIUS) <= 1 then
        ST.endSiege(true, player)
    end
end
Rem.on("sceneUpdate", function(player, now) Rem.safe(ST.tick, player, now) end)

-- ---------------------------------------------------------------- ferramentas de teste
for _, kind in ipairs({ "trader", "mourner", "ambush", "hostage" }) do AM.registerDebugKind(kind) end
Rem.registerDebugOption("ContextMenu_Rem_SiegeNearest", function(x, y, z, player)
    local g = Rem.nearestGroup(player:getX(), player:getY())
    if not g or not g.home or not g.home.x1 then player:Say("-") return end
    local s = ST.startSiege(g)
    s.messenger = false
    player:Say(tostring(g.id) .. ": cerco")
end, "world")
