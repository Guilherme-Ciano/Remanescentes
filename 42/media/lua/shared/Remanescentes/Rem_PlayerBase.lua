-- Remanescentes - a sua base: um lugar seu que continua vivo enquanto voce explora.
--
-- Clique direito dentro de um predio -> "Definir este predio como base". A base e um grupo
-- especial (g.player = true, faccao aliados) e reaproveita o resto do mod: casa, estoque,
-- portas, luz a noite, rotina, refeicoes, conversa, cerebro do grupo (Rem_Director), cercos.
-- Mas quem decide e voce:
--   * quem mora la: mande um aliado para a base (conversa ou clique direito); chame de volta
--   * a tarefa de cada um:
--       build  fortificar: prega tabuas nas janelas (2 janelas por dia por pessoa)
--       guard  vigiar: fica na porta; conta na defesa contra ataques de saqueadores
--       scav   buscar: sai para revirar predios em volta da base e traz o que achar
--       rest   descansar: fica em casa (recupera, come, conversa)
-- Estoque: os conteineres que voce escolhe (os melhores da casa, ate 4). Comida e agua que
--   estiverem la sao o que eles comem; tabuas e pregos que voce deixar la viram material
--   para fortificar. O que os coletores trazem aparece no estoque.
-- Longe de voce a base segue: comem, fortificam, saem para buscar (e podem se ferir ou
--   morrer), podem ser atacados por saqueadores. Tudo vai para o Diario.
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_World"
require "Remanescentes/Rem_Safehouse"
require "Remanescentes/Rem_Roles"
require "Remanescentes/Rem_Scavenge"
require "Remanescentes/Rem_Director"
require "Remanescentes/Rem_MapMarks"
require "Remanescentes/Rem_Journal"
local Rem = Remanescentes
local S = Rem.Safehouse

local PB = Rem.module("PlayerBase", {
    MAX_MEMBERS = 8,
    STASH_CONTAINERS = 4,
    SCAV_HOURS = 5,                -- intervalo entre buscas de cada coletor
    SCAV_ITEMS = { 2, 5 },         -- itens trazidos por busca (fora de cena)
    SCAV_MATERIALS = { 0, 2 },     -- tabuas/pregos por busca
    SCAV_RADIUS = { 12, 90 },      -- predios a essa distancia da base
    SCAV_HURT = 15,                -- (%) volta ferido
    SCAV_MAX_MS = 180000,          -- busca em cena: tempo maximo antes de voltar
    SCAV_PRIORITY = 105,
    MAT_TRIP = { 3, 7 },           -- material trazido por uma saida de material (fora de cena)
    DISMANTLE_MS = 5000,           -- arrancar tabuas de um movel
    DISMANTLE_NOISE = 12,
    ESCORT_DIST = 3,
    MEDIC_HEAL = 0.05,             -- cada medico na base cura isso a mais por hora
    GUARD_DEFENSE = 1.0,           -- cada vigia vale isso a mais na defesa
    WINDOW_DEFENSE = 2.0,          -- casa toda fechada vale isso a mais
    ARRIVE_DIST = 30,              -- morador fora de cena mais longe que isso: chega em casa
    HUNGER_WARN = 24,              -- horas sem comida: aviso no diario
    HUNGER_LEAVE = 72,             -- horas sem comida: alguem vai embora
    SYNC_MS = 4000,
    MATERIAL_ITEMS = { ["Base.Plank"] = 1, ["Base.Nails"] = 1, ["Base.NailsBox"] = 3, ["Base.SheetMetal"] = 2 },
})
local CFG = PB.CFG

PB.JOBS = { "build", "guard", "scav", "materials", "heal", "rest" }
PB.NOT_FOOD = { ["Base.Bandage"] = true, ["Base.Pills"] = true, ["Base.Disinfectant"] = true, ["Base.Matches"] = true,
    ["Base.Candle"] = true }
PB.SCAV_LOOT_FOOD = { "Base.TinnedBeans", "Base.TinnedSoup", "Base.CannedCorn", "Base.CannedChili", "Base.CannedPeas",
    "Base.Crackers", "Base.Cereal", "Base.WaterRationCan" }
PB.SCAV_LOOT = { "Base.TinnedBeans", "Base.TinnedSoup", "Base.CannedCorn", "Base.CannedChili", "Base.CannedPeas",
    "Base.Crackers", "Base.Cereal", "Base.WaterRationCan", "Base.WaterRationCan", "Base.Bandage", "Base.Pills",
    "Base.Disinfectant", "Base.Matches", "Base.Candle" }

Rem.BARKS.base_go = { urgent = true, n = 3, cd = 0 }
Rem.BARKS.base_job = { urgent = true, n = 3, cd = 0 }
Rem.BARKS.base_back = { urgent = true, n = 2, cd = 0 }
Rem.BARKS.trip_scav = { urgent = true, n = 3, cd = 0 }
Rem.BARKS.trip_materials = { urgent = true, n = 3, cd = 0 }
Rem.BARKS.trip_alone = { urgent = true, n = 2, cd = 0 }

local function line(key, ...) return { key = key, args = { ... } } end
local function ips() return Rem.World.CFG.ITEMS_PER_SUPPLY end
local function daytime()
    local tod = getGameTime():getTimeOfDay()
    return tod >= 7 and tod < 19
end

-- ---------------------------------------------------------------- consultas
function PB.get()
    local s = Rem.getStore()
    local g = s.playerBase and s.groups[s.playerBase]
    if s.playerBase and not g then s.playerBase = nil end
    return g
end

function PB.isMember(rec)
    local g = PB.get()
    return g ~= nil and rec.groupId == g.id
end

function PB.members(g)
    local out = {}
    for _, id in ipairs(g.members) do
        local p = Rem.getPerson(id)
        if p then table.insert(out, p) end
    end
    return out
end

local function activeOf(rec)
    for _, npc in pairs(Rem.active) do if npc.rec == rec then return npc end end
    return nil
end

local function isFood(item)
    local food, cat = false, ""
    pcall(function() food = item:isFood() end)
    pcall(function() cat = item:getDisplayCategory() or "" end)
    return food or cat == "Food" or cat == "Water"
end

-- ---------------------------------------------------------------- definir a base
local function objectsOf(sq)
    local out = {}
    local objs = sq:getObjects()
    for i = 0, objs:size() - 1 do table.insert(out, objs:get(i)) end
    return out
end

local function stashScore(c)
    local t = c:getType() or ""
    if t == "fridge" or t == "freezer" then return 4 end
    if t == "shelves" or t == "crate" or t == "counter" then return 3 end
    if t == "wardrobe" or t == "smallbox" then return 2 end
    return 1
end

-- Os melhores conteineres da casa viram o estoque; a porta externa mais perto, a porta.
function PB.setupHome(g, player)
    local h = g.home
    local found, doors = {}, {}
    S.forEachSquare(h, h.z or 0, function(sq)
        for _, obj in ipairs(objectsOf(sq)) do
            if sq:getRoom() then
                for i = 0, obj:getContainerCount() - 1 do
                    local c = obj:getContainerByIndex(i)
                    if c then table.insert(found, { c = c, sq = sq, score = stashScore(c) }) end
                end
            end
            if instanceof(obj, "IsoDoor") then
                local ext = false
                pcall(function() ext = obj:isExterior() end)
                if ext then table.insert(doors, sq) end
            end
        end
    end)
    table.sort(found, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        return a.sq:getY() * 100000 + a.sq:getX() < b.sq:getY() * 100000 + b.sq:getX()
    end)
    h.stash = {}
    for i = 1, math.min(CFG.STASH_CONTAINERS, #found) do
        local f = found[i]
        table.insert(h.stash, { x = f.sq:getX(), y = f.sq:getY(), z = f.sq:getZ(), type = f.c:getType() })
    end
    local px, py = player:getX(), player:getY()
    table.sort(doors, function(a, b) return Rem.dist2(px, py, a:getX(), a:getY()) < Rem.dist2(px, py, b:getX(), b:getY()) end)
    if doors[1] then
        h.mainDoor = { x = doors[1]:getX(), y = doors[1]:getY(), z = doors[1]:getZ() }
        h.entrance = h.mainDoor
    end
    h.guardSpot, h.kitchen, h.scanAt = nil, nil, nil
    g.nearby = nil
    -- o mod nao "prepara" a sua casa como a dos NPCs (sem barricadas prontas, placas, loot)
    h.fortified, h.stocked, h.decorated = true, true, true
    h.foodSync = nil
    return #h.stash, h.mainDoor ~= nil
end

-- Predio onde o jogador esta (BuildingDef) ou nil.
function PB.buildingAt(player)
    local sq = getCell():getGridSquare(math.floor(player:getX()), math.floor(player:getY()), math.floor(player:getZ()))
    local b = sq and sq:getBuilding()
    return b and b:getDef() or nil
end

function PB.canSetHere(player)
    local def = PB.buildingAt(player)
    if not def then return false end
    local g = PB.get()
    return not (g and g.home.bid == tostring(def:getID()))
end

-- Define (ou muda) a base para o predio onde voce esta. Retorna a base ou nil, motivo.
function PB.setHere(player)
    local def = PB.buildingAt(player)
    if not def then return nil, "IGUI_Rem_Base_nobuilding" end
    local bid = tostring(def:getID())
    for _, other in pairs(Rem.getStore().groups) do
        if not other.player and other.home and other.home.bid == bid and #other.members > 0 then
            return nil, "IGUI_Rem_Base_taken"      -- casa de outro grupo
        end
    end
    local cx, cy = def:getX() + def:getW() / 2, def:getY() + def:getH() / 2
    local g = PB.get()
    if g then
        g.home = { x = cx, y = cy, z = 0, bid = bid, x1 = def:getX(), y1 = def:getY(),
            x2 = def:getX() + def:getW(), y2 = def:getY() + def:getH() }
        g.x, g.y = cx, cy
        for _, p in ipairs(PB.members(g)) do p.indoorSpot = nil end
    else
        g = Rem.createGroup("aliados", cx, cy, bid, 0, def)
        g.player, g.name = true, getText("IGUI_Rem_Base_name")
        g.supplies, g.materials = 0, 0
        Rem.getStore().playerBase = g.id
    end
    local nStash, hasDoor = PB.setupHome(g, player)
    Rem.getStore().looted[bid] = Rem.worldHours()     -- (o jogo nao gera loot novo nos seus armarios)
    Rem.MapMarks.add({ id = "playerbase:" .. bid, x = cx, y = cy, symbol = "House", color = Rem.MapMarks.COLORS.aliados,
        text = getText("IGUI_Rem_Base_name") }, nil)
    if Rem.Journal then Rem.Journal.add("IGUI_Rem_Journal_base_set") end
    Rem.emit("playerBaseSet", g)
    Rem.debug("base do jogador em " .. math.floor(cx) .. "," .. math.floor(cy) .. " (" .. nStash .. " conteineres de estoque)")
    return g, nil, nStash, hasDoor
end

-- ---------------------------------------------------------------- moradores
local function assignRole(rec)
    rec.role = (rec.job == "guard") and "guarda" or "morador"
end
PB.assignRole = assignRole

-- Tarefa padrao: o que estiver faltando (fortificar, vigiar, buscar).
function PB.defaultJob(g)
    local have = {}
    for _, p in ipairs(PB.members(g)) do have[p.job or "rest"] = true end
    for _, job in ipairs({ "build", "guard", "scav", "materials" }) do
        if not have[job] then return job end
    end
    return "rest"
end

-- Manda um aliado morar na base. Retorna ok, fala.
function PB.join(npc)
    local g = PB.get()
    local rec = npc.rec
    if not g then return false, line("IGUI_Rem_Base_none") end
    if PB.isMember(rec) then return true, line("IGUI_Rem_Base_already") end
    if #g.members >= CFG.MAX_MEMBERS then return false, line("IGUI_Rem_Base_full", tostring(CFG.MAX_MEMBERS)) end
    rec.groupId = g.id
    rec.mode = "group"
    rec.job = PB.defaultJob(g)
    assignRole(rec)
    rec.indoorSpot = nil
    table.insert(g.members, rec.id)
    Rem.clearRest(npc)
    Rem.bark(npc, "base_go", true)
    Rem.emit("playerBaseMember", g, rec, "joined")
    return true, line("IGUI_Rem_Base_go_" .. rec.job)
end

-- Tira da base (volta a seguir voce, foi liberado ou morreu).
function PB.leave(rec)
    local g = PB.get()
    if not g or rec.groupId ~= g.id then return false end
    for i = #g.members, 1, -1 do if g.members[i] == rec.id then table.remove(g.members, i) end end
    rec.groupId, rec.job, rec.role, rec.indoorSpot = nil, nil, nil, nil
    if rec.mode == "group" or rec.mode == "scav" then rec.mode = "follow" end
    rec.lootTarget = nil
    return true
end

function PB.setJob(npc, job)
    local rec = npc.rec
    if not PB.isMember(rec) then return false end
    rec.job = job
    assignRole(rec)
    if rec.mode == "scav" and job ~= "scav" then PB.endTrip(npc, false) end
    npc.working = nil
    Rem.bark(npc, "base_job", true)
    return true
end

-- Muda a tarefa pelo registro (painel da base): com ou sem a pessoa em cena.
function PB.setJobRec(rec, job)
    local npc = activeOf(rec)
    if npc then return PB.setJob(npc, job) end
    if not PB.isMember(rec) then return false end
    if rec.mode == "scav" or rec.mode == "escort" then return false end   -- (fora, numa busca)
    rec.job = job
    assignRole(rec)
    return true
end

-- Proxima tarefa da lista (o botao do painel vai trocando).
function PB.nextJob(job)
    for i, j in ipairs(PB.JOBS) do
        if j == job then return PB.JOBS[(i % #PB.JOBS) + 1] end
    end
    return PB.JOBS[1]
end

-- ---------------------------------------------------------------- ordens (conversa)
function PB.order(id, npc, player)
    local rec = npc.rec
    if id == "order_base" then return PB.join(npc) end
    if id:sub(1, 10) == "order_job_" then
        local job = id:sub(11)
        PB.setJob(npc, job)
        return true, line("IGUI_Rem_Base_job_" .. job)
    end
    if id == "order_follow" then
        if Rem.Interact.followerCount() >= Rem.Interact.CFG.MAX_FOLLOWERS then
            return false, line("IGUI_Rem_Join_full")
        end
        PB.leave(rec)
        rec.mode = "follow"
        Rem.bark(npc, "base_back", true)
        return true, line("IGUI_Rem_Order_follow")
    end
    return false, line("IGUI_Rem_Talk_bye")
end

function PB.hint(npc)
    local g = PB.get()
    if g and #g.members >= CFG.MAX_MEMBERS then return line("IGUI_Rem_Hint_basefull", tostring(CFG.MAX_MEMBERS)) end
    return nil
end

-- Todos os que andam com voce vao para a base. Retorna quantos foram.
function PB.sendAll()
    local n = 0
    local list = {}
    for _, npc in pairs(Rem.active) do
        if npc.rec.faction == "aliados" and not npc.rec.groupId then table.insert(list, npc) end
    end
    table.sort(list, function(a, b) return tostring(a.rec.id) < tostring(b.rec.id) end)
    for _, npc in ipairs(list) do
        if PB.join(npc) then n = n + 1 end
    end
    return n
end

-- ---------------------------------------------------------------- estoque: comida e material
-- Comida e agua no estoque = suprimentos da base. O que voce poe ou tira conta na hora;
-- o que eles comem sai do estoque. Tabuas e pregos que voce deixa viram material.
function PB.syncStash(g)
    local h = g.home
    local conts = S.stashContainers(h)
    if not conts or #conts == 0 then return nil end
    -- o que chegou das buscas fora de cena
    -- (a comida delas ja foi somada aos suprimentos quando chegaram)
    local pending = g.pendingList or {}
    local pendingFood = 0
    for k, ft in ipairs(pending) do
        local c = conts[((k - 1) % #conts) + 1]
        Rem.safe(function() c:AddItem(ft) end)
        if not PB.NOT_FOOD[ft] and not CFG.MATERIAL_ITEMS[ft] then pendingFood = pendingFood + 1 end
    end
    g.pendingList = nil
    if h.foodSync then h.foodSync = h.foodSync + pendingFood end
    -- material: tabuas e pregos viram material de fortificar
    for _, c in ipairs(conts) do
        local items = c:getItems()
        for i = items:size() - 1, 0, -1 do
            local it = items:get(i)
            local v = CFG.MATERIAL_ITEMS[it:getFullType()]
            if v then
                c:DoRemoveItem(it)
                g.materials = Rem.Director.materials(g) + v
            end
        end
    end
    -- comida
    local food = 0
    for _, c in ipairs(conts) do
        local items = c:getItems()
        for i = 0, items:size() - 1 do if isFood(items:get(i)) then food = food + 1 end end
    end
    if h.foodSync and food ~= h.foodSync then
        g.supplies = math.max(0, (g.supplies or 0) + (food - h.foodSync) / ips())   -- voce pos ou tirou
    elseif not h.foodSync then
        g.supplies = food / ips()
    end
    -- o que eles comeram enquanto o estoque nao estava carregado
    local target = math.floor((g.supplies or 0) * ips() + 0.5)
    for _, c in ipairs(conts) do
        local items = c:getItems()
        for i = items:size() - 1, 0, -1 do
            if food <= target then break end
            local it = items:get(i)
            if isFood(it) then
                c:DoRemoveItem(it)
                food = food - 1
            end
        end
    end
    h.foodSync = food
    return food
end

-- ---------------------------------------------------------------- busca de suprimentos
-- Predios das redondezas da base (lista feita uma vez por lugar: sortear entre os milhares
-- de predios do mapa quase nunca acertava um perto).
function PB.nearby(g)
    local h = g.home
    if g.nearby and g.nearbyBid == h.bid and Rem.worldHours() - (g.nearbyH or 0) < 24 then return g.nearby end
    local out = {}
    pcall(function()
        local list = getWorld():getMetaGrid():getBuildings()
        for i = 0, list:size() - 1 do
            local def = list:get(i)
            local bx, by = def:getX() + def:getW() / 2, def:getY() + def:getH() / 2
            local d = Rem.dist2(h.x, h.y, bx, by)
            local bid = tostring(def:getID())
            if d >= CFG.SCAV_RADIUS[1] and d <= CFG.SCAV_RADIUS[2] and bid ~= h.bid then
                table.insert(out, { bid = bid, x = bx, y = by, x1 = def:getX(), y1 = def:getY(),
                    x2 = def:getX() + def:getW(), y2 = def:getY() + def:getH(), d = d })
            end
        end
    end)
    table.sort(out, function(a, b) return a.d < b.d end)
    g.nearby, g.nearbyBid, g.nearbyH = out, h.bid, Rem.worldHours()
    return out
end

-- Um predio ainda nao revirado em volta da base (os mais perto primeiro, com um pouco de
-- sorte no meio). Retorna def-like, x, y, bid (como Rem.pickBuilding).
local function scavTarget(g)
    local looted = Rem.getStore().looted
    local free = {}
    for _, b in ipairs(PB.nearby(g)) do
        local taken = false
        for _, other in pairs(Rem.getStore().groups) do
            if other ~= g and other.home and other.home.bid == b.bid then taken = true end
        end
        if not looted[b.bid] and not taken then table.insert(free, b) end
        if #free >= 5 then break end
    end
    if #free == 0 then return nil end
    local b = free[ZombRand(#free) + 1]
    local def = { getX = function() return b.x1 end, getY = function() return b.y1 end,
        getW = function() return b.x2 - b.x1 end, getH = function() return b.y2 - b.y1 end }
    return def, b.x, b.y, b.bid
end

-- ---------------------------------------------------------------- saidas em dupla
-- Ninguem sai sozinho: quem tem a tarefa "buscar suprimentos" (scav) ou "buscar material"
-- (materials) sai com um parceiro da mesma tarefa, ou com alguem que esta descansando.
-- Sem parceiro, espera (e diz isso). Material: tabuas, pregos e chapas, arrancados de
-- moveis e paredes dos predios em volta.
PB.TRIP_JOBS = { scav = true, materials = true }
PB.MATERIAL_LOOT = { "Base.Plank", "Base.Plank", "Base.Plank", "Base.Nails", "Base.Nails", "Base.SheetMetal" }

local function onTrip(rec) return rec.mode == "scav" or rec.mode == "escort" end

local function ready(rec, hours)
    return not onTrip(rec) and (not rec.lastTrip or hours - rec.lastTrip >= CFG.SCAV_HOURS)
        and (rec.hp or 1) >= (rec.maxHealth or 1) * 0.5
        and not (Rem.Wounds and Rem.Wounds.blocksTrips(rec))         -- perna ferida nao sai
end

PB.ready = ready

-- Parceiro para quem vai sair (mesma tarefa, ou alguem descansando). onScene: os dois em
-- cena (true) ou os dois fora (false).
function PB.partnerFor(g, rec, onScene)
    local hours = Rem.worldHours()
    local same, resting = {}, {}
    for _, p in ipairs(PB.members(g)) do
        if p ~= rec and (p.onScene == true) == onScene and ready(p, hours) then
            if p.job == rec.job then table.insert(same, p) elseif p.job == "rest" then table.insert(resting, p) end
        end
    end
    -- amigos primeiro; rivais so se nao houver mais ninguem (Rem_Friends)
    local pick = function(list) return Rem.Friends and Rem.Friends.pickPartner(rec, list) or list[1] end
    if #same > 0 then return pick(same) end
    if #resting > 0 then return pick(resting) end
    return nil
end

local function addCarry(g, list, ft)
    table.insert(list, ft)
end

-- Saida abstrata da dupla (fora de cena). Retorna o que trouxeram (itens) ou "dead"/0.
function PB.tripOffscene(g, rec, partner, kind)
    kind = kind or rec.job
    local hours = Rem.worldHours()
    -- (o diario conta so o que acontece na sua base)
    local function note(...) if g.player then Rem.Journal.add(...) end end
    rec.lastTrip = hours
    if partner then partner.lastTrip = hours end
    local def, bx, by, bid = scavTarget(g)
    if not def then
        if not g.exhaustedNoted then
            g.exhaustedNoted = true
            note("IGUI_Rem_Journal_base_exhausted")
        end
        return 0
    end
    g.exhaustedNoted = nil
    Rem.getStore().looted[bid] = hours
    local names = tostring(rec.name) .. (partner and (" e " .. tostring(partner.name)) or "")
    -- perigo: em dupla, metade do risco de quem sai sozinho
    -- especialidade: com alguem furtivo na dupla, o risco cai pela metade
    local sneaky = rec.archetype == "furtivo" or (partner and partner.archetype == "furtivo")
    -- coleta (Rem_Skills) e amizade (Rem_Friends) diminuem o risco
    local risk = Rem.cfg("ScavengeDeathChance", 8) / (partner and 4 or 2) / (sneaky and 2 or 1)
    if Rem.Skills then risk = risk / Rem.Skills.tripRiskDiv(rec, partner) end
    if Rem.Friends then risk = risk * Rem.Friends.tripRisk(rec, partner) end
    Rem.emit("tripDone", g, rec, partner, kind)
    if ZombRand(100) < risk then
        local dead = (partner and ZombRand(2) == 0) and partner or rec
        local alive = nil                       -- (sem "and/or": partner pode ser nil)
        if dead == rec then alive = partner else alive = rec end
        PB.leave(dead)
        if Rem.Persona then Rem.Persona.mourn(dead) end
        if alive then note("IGUI_Rem_Journal_base_trip_lost", tostring(alive.name), tostring(dead.name))
        else note("IGUI_Rem_Journal_base_scav_died", tostring(dead.name)) end
        Rem.removePerson(dead.id)
        return "dead"
    end
    g.pendingList = g.pendingList or {}
    local n, mat, food = 0, 0, 0
    if kind == "fuel" and Rem.Fuel then
        n = Rem.Fuel.trip(g)                          -- gasolina (Rem_Fuel): vai direto para o estoque
    elseif kind == "materials" then
        mat = ZombRand(CFG.MAT_TRIP[1], CFG.MAT_TRIP[2] + 1)
        g.materials = Rem.Director.materials(g) + mat
        n = ZombRand(0, 2)
        for _ = 1, n do
            local ft = Rem.pick(PB.SCAV_LOOT)
            addCarry(g, g.pendingList, ft)
            if not PB.NOT_FOOD[ft] then food = food + 1 end
        end
    else
        n = ZombRand(CFG.SCAV_ITEMS[1], CFG.SCAV_ITEMS[2] + 1) + (partner and 2 or 0)
            + (Rem.Skills and Rem.Skills.tripItems(rec, partner) or 0)
        for _ = 1, n do
            local ft = Rem.pick(PB.SCAV_LOOT)
            addCarry(g, g.pendingList, ft)
            if not PB.NOT_FOOD[ft] then food = food + 1 end
        end
        mat = ZombRand(CFG.SCAV_MATERIALS[1], CFG.SCAV_MATERIALS[2] + 1)
        g.materials = Rem.Director.materials(g) + mat
    end
    g.supplies = (g.supplies or 0) + food / ips()      -- ja da para comer (os itens aparecem quando a casa carregar)
    if not g.player then
        -- grupo de NPC: o estoque deles conta itens (Rem_Scavenge.syncStash)
        g.pendingItems = (g.pendingItems or 0) + #g.pendingList
        g.pendingList = nil
    end
    if ZombRand(100) < CFG.SCAV_HURT then
        local who = (partner and ZombRand(2) == 0) and partner or rec
        who.hp = (who.hp or who.maxHealth or 2) * 0.6
        if Rem.Wounds then Rem.Wounds.inflict(who) end
        note("IGUI_Rem_Journal_base_trip_hurt", names, tostring(who.name), tostring(n), tostring(mat))
    else
        note("IGUI_Rem_Journal_base_trip_" .. kind, names, tostring(n), tostring(mat))
    end
    return n + mat
end

-- Comeca uma saida de verdade (com voce por perto): rec lidera, partner acompanha.
function PB.startTrip(npc, g, partnerNpc)
    local def, bx, by, bid = scavTarget(g)
    if not def then return false end
    local rec = npc.rec
    rec.mode = "scav"
    rec.tripKind = rec.job
    rec.lootTarget = { x = bx, y = by, z = 0, bid = bid, x1 = def:getX(), y1 = def:getY(),
        x2 = def:getX() + def:getW(), y2 = def:getY() + def:getH() }
    npc.tripStart = Rem.nowMs()
    npc.fLootCont, npc.lootUntil, npc.lootDoneBid = nil, nil, nil
    if partnerNpc then
        partnerNpc.rec.mode = "escort"
        partnerNpc.rec.escortOf = rec.id
        rec.partnerId = partnerNpc.rec.id
        Rem.clearRest(partnerNpc)
    end
    local bark = "trip_scav"
    if rec.tripKind == "materials" then bark = "trip_materials" elseif rec.tripKind == "fuel" then bark = "trip_fuel" end
    Rem.bark(npc, bark, true)
    return true
end

-- Fim da saida: chegou em casa (deposit = true) ou foi interrompida.
function PB.endTrip(npc, deposit)
    local rec = npc.rec
    local g = rec.groupId and Rem.getStore().groups[rec.groupId] or nil
    if rec.lootTarget and rec.lootTarget.bid then Rem.getStore().looted[rec.lootTarget.bid] = Rem.worldHours() end
    local n = #(rec.carry or {})
    if deposit and g and n > 0 and not g.player then
        -- grupo de NPC: material vira material na hora; o resto vai para o estoque deles
        local keep = {}
        for _, ft in ipairs(rec.carry) do
            local v = CFG.MATERIAL_ITEMS[ft]
            if v then g.materials = Rem.Director.materials(g) + v else table.insert(keep, ft) end
        end
        rec.carry = keep
        if #keep > 0 then Rem.Scavenge.deposit(npc, g) end
        rec.carry = nil
        n = 0
    end
    if deposit and g and n > 0 then
        local conts = S.stashContainers(g.home)
        if conts and #conts > 0 then
            for i, ft in ipairs(rec.carry) do
                local c = conts[((i - 1) % #conts) + 1]
                Rem.safe(function() c:AddItem(ft) end)
            end
        else
            g.pendingList = g.pendingList or {}
            for _, ft in ipairs(rec.carry) do table.insert(g.pendingList, ft) end
        end
        rec.carry = nil
        Rem.bark(npc, "loot_home", true)
        Rem.Journal.add("IGUI_Rem_Journal_base_scav", tostring(rec.name), tostring(n), "0")
    end
    if deposit and g and Rem.Fuel then Rem.Fuel.deposit(npc, g) end
    if deposit and g then
        local partner = rec.partnerId and Rem.getPerson(rec.partnerId) or nil
        Rem.emit("tripDone", g, rec, partner, rec.tripKind)
    end
    -- o parceiro volta a rotina
    for _, other in pairs(Rem.active) do
        if other.rec.escortOf == rec.id then
            other.rec.mode, other.rec.escortOf = "group", nil
            other.rec.lastTrip = Rem.worldHours()
        end
    end
    for _, p in ipairs(g and PB.members(g) or {}) do
        if p.escortOf == rec.id then p.mode, p.escortOf, p.lastTrip = "group", nil, Rem.worldHours() end
    end
    rec.mode, rec.partnerId, rec.tripKind = "group", nil, nil
    rec.lootTarget = nil
    rec.lastTrip = Rem.worldHours()
    npc.tripStart, npc.fLootCont, npc.lootUntil, npc.lootDoneBid = nil, nil, nil, nil
end

-- Arranca material de um movel/parede (saida de material): tabuas, pregos, as vezes chapa.
function PB.dismantle(npc)
    local rec = npc.rec
    rec.carry = rec.carry or {}
    local took = 0
    for _ = 1, ZombRand(1, 3) do
        if #rec.carry >= Rem.Scavenge.CFG.CARRY_MAX then break end
        table.insert(rec.carry, Rem.pick(PB.MATERIAL_LOOT))
        took = took + 1
    end
    Rem.makeNoise(npc, CFG.DISMANTLE_NOISE)
    Rem.safe(function() npc.z:playSound("Dismantle") end)
    return took
end

-- Quem acompanha: fica perto de quem lidera (e briga junto, pelo cerebro).
function PB.escortBehavior(npc, ctx, now)
    local rec = npc.rec
    if rec.mode ~= "escort" then return false end
    local leader = nil
    for _, other in pairs(Rem.active) do if other.rec.id == rec.escortOf then leader = other end end
    if not leader or leader.rec.mode ~= "scav" then
        rec.mode, rec.escortOf = "group", nil
        return false
    end
    if Rem.dist(npc.z, leader.z) > CFG.ESCORT_DIST then
        Rem.moveTo(npc, leader.z:getX(), leader.z:getY(), leader.z:getZ(), now, leader.running and "run" or "walk")
    else
        Rem.stopMoving(npc)
        Rem.idle(npc, now)
    end
    return true
end
Rem.registerBehavior({ name = "base_escort", priority = CFG.SCAV_PRIORITY - 1, run = PB.escortBehavior })

-- Grupos que saem em dupla: a sua base, e os grupos de NPC com casa (so para material;
-- comida eles buscam com o grupo todo, Rem_World).
function PB.tripGroup(rec)
    local g = rec.groupId and Rem.getStore().groups[rec.groupId]
    if not g or not g.home or not g.home.x1 or g.activity ~= "home" then return nil end
    if not g.player and rec.job ~= "materials" and rec.mode ~= "scav" then return nil end
    return g
end

function PB.scavBehavior(npc, ctx, now)
    local rec = npc.rec
    local g = PB.tripGroup(rec)
    if not g then return false end
    local h = g.home
    -- sair (de dia, com a casa carregada, em dupla)
    if rec.mode == "group" then
        if not PB.TRIP_JOBS[rec.job] or not daytime() or g.goal == "hide" or g.goal == "clear" then return false end
        if not ready(rec, Rem.worldHours()) or Rem.healthFraction(npc) < 0.5 then return false end
        local partner = PB.partnerFor(g, rec, true)
        local pnpc = partner and activeOf(partner)
        if not pnpc or pnpc.rec.mode ~= "group" then
            if not npc.noPartnerAt or now - npc.noPartnerAt > 300000 then
                npc.noPartnerAt = now
                Rem.bark(npc, "trip_alone", true)
            end
            return false
        end
        if not PB.startTrip(npc, g, pnpc) then
            rec.lastTrip = Rem.worldHours()
            return false
        end
    end
    if rec.mode ~= "scav" or not rec.lootTarget then return false end
    local SC = Rem.Scavenge
    local t = rec.lootTarget
    local full = rec.carry and #rec.carry >= SC.CFG.CARRY_MAX
    local tooLong = now - (npc.tripStart or now) > CFG.SCAV_MAX_MS
    if full or tooLong or npc.lootDoneBid == t.bid then
        -- volta para a base e guarda
        if Rem.distXY(npc.z, h.x, h.y) > math.max(3, (h.x2 - h.x1) / 2) then
            Rem.moveTo(npc, h.x, h.y, h.z or 0, now, Rem.travelGait(npc, Rem.distXY(npc.z, h.x, h.y)))
            return true
        end
        PB.endTrip(npc, true)
        return true
    end
    local cur = npc.fLootCont
    if not cur then
        cur = SC.pickContainer(npc, t)
        if not cur then
            -- longe do predio: vai ate ele primeiro
            if Rem.dist2(npc.z:getX(), npc.z:getY(), t.x, t.y) > SC.CFG.NEAR_TARGET then
                Rem.moveTo(npc, t.x, t.y, 0, now, Rem.travelGait(npc, Rem.dist2(npc.z:getX(), npc.z:getY(), t.x, t.y)))
                return true
            end
            npc.lootDoneBid = t.bid
            return true
        end
        cur.since = now
        npc.fLootCont = cur
    end
    local cx, cy = cur.sq:getX() + 0.5, cur.sq:getY() + 0.5
    if Rem.dist2(npc.z:getX(), npc.z:getY(), cx, cy) > SC.CFG.TOUCH then
        if now - (cur.since or now) > SC.CFG.STUCK_MS then
            t.visited = t.visited or {}
            t.visited[cur.key] = true
            npc.fLootCont, npc.lootUntil = nil, nil
            return true
        end
        local sx, sy, sz = Rem.standSquare(cur.sq, npc.z:getX(), npc.z:getY())
        local d = Rem.dist2(npc.z:getX(), npc.z:getY(), sx, sy)
        Rem.moveTo(npc, sx, sy, sz, now, (d > 8) and Rem.travelGait(npc, d) or Rem.baseGait(npc))
        return true
    end
    Rem.stopMoving(npc)
    Rem.safe(function() npc.z:faceLocationF(cx, cy) end)
    local materials = rec.tripKind == "materials"
    local fuel = rec.tripKind == "fuel" and Rem.Fuel
    if not npc.lootUntil then npc.lootUntil = now + ((materials or fuel) and CFG.DISMANTLE_MS or SC.CFG.SEARCH_MS) return true end
    if now < npc.lootUntil then return true end
    if fuel then Rem.safe(Rem.Fuel.siphon, npc)
    elseif materials then Rem.safe(PB.dismantle, npc) else Rem.safe(SC.takeFrom, npc, cur.c) end
    t.visited = t.visited or {}
    t.visited[cur.key] = true
    npc.fLootCont, npc.lootUntil = nil, nil
    return true
end
Rem.registerBehavior({ name = "base_scav", priority = CFG.SCAV_PRIORITY, run = PB.scavBehavior })

-- ---------------------------------------------------------------- a cada hora
function PB.hourly()
    local g = PB.get()
    if not g then return end
    local list = PB.members(g)
    local n = #list
    local hours = Rem.worldHours()
    -- comem
    if n > 0 then
        g.supplies = (g.supplies or 0) - n / 24
        if g.supplies <= 0 then
            g.supplies = 0
            g.hungerHours = (g.hungerHours or 0) + 1
            if g.hungerHours == CFG.HUNGER_WARN then Rem.Journal.add("IGUI_Rem_Journal_base_hungry") end
            if g.hungerHours >= CFG.HUNGER_LEAVE then
                local p = list[n]
                if p and not p.onScene then
                    PB.leave(p)
                    Rem.Journal.add("IGUI_Rem_Journal_base_left", tostring(p.name))
                    Rem.removePerson(p.id)
                    g.hungerHours = CFG.HUNGER_WARN
                end
            end
        else
            g.hungerHours = 0
        end
    end
    local medics = 0
    -- medicos e quem esta na enfermaria (tarefa "heal"); medicina (Rem_Skills) conta
    for _, rec in ipairs(PB.members(g)) do
        if rec.archetype == "medico" or rec.job == "heal" then
            medics = medics + 1 + (Rem.Skills and Rem.Skills.level(rec, "medicina") * Rem.Skills.CFG.HEAL_BONUS / CFG.MEDIC_HEAL or 0)
        end
    end
    for _, rec in ipairs(PB.members(g)) do
        -- quem foi mandado para a base e saiu de cena no caminho: chegou
        if not rec.onScene and rec.x and Rem.dist2(rec.x, rec.y, g.home.x, g.home.y) > CFG.ARRIVE_DIST then
            rec.x, rec.y, rec.z = g.home.x + ZombRandFloat(-2, 2), g.home.y + ZombRandFloat(-2, 2), 0
            rec.pid = nil
            if rec.mode == "escort" then rec.mode, rec.escortOf, rec.lastTrip = "group", nil, hours end
            if rec.mode == "scav" then
                -- estava buscando quando voce foi embora: o que ja tinha pegado chega com ele
                g.pendingList = g.pendingList or {}
                for _, ft in ipairs(rec.carry or {}) do
                    table.insert(g.pendingList, ft)
                    if not PB.NOT_FOOD[ft] and not CFG.MATERIAL_ITEMS[ft] then g.supplies = (g.supplies or 0) + 1 / ips() end
                end
                rec.carry = nil
                if rec.lootTarget and rec.lootTarget.bid then Rem.getStore().looted[rec.lootTarget.bid] = hours end
                rec.mode, rec.lootTarget, rec.lastTrip, rec.partnerId, rec.tripKind = "group", nil, hours, nil, nil
            end
        end
        -- saidas de quem esta longe de voce (em dupla)
        if PB.TRIP_JOBS[rec.job] and not rec.onScene and daytime() and Rem.getPerson(rec.id) and ready(rec, hours) then
            local partner = PB.partnerFor(g, rec, false)
            if partner then
                PB.tripOffscene(g, rec, partner, rec.job)
            elseif not rec.noPartnerNoted then
                rec.noPartnerNoted = true
                Rem.Journal.add("IGUI_Rem_Journal_base_nopartner", tostring(rec.name))
            end
            if partner then rec.noPartnerNoted = nil end
        end
        -- descansando em casa: recupera (mais rapido com um medico na base)
        if not rec.onScene and rec.hp and rec.maxHealth and rec.hp < rec.maxHealth
            and not (Rem.Wounds and Rem.Wounds.noRegen(rec)) then              -- corte aberto nao fecha sozinho
            local rate = ((rec.job == "rest") and 0.08 or 0.03) + medics * CFG.MEDIC_HEAL
            rec.hp = math.min(rec.maxHealth, rec.hp + rec.maxHealth * rate)
        end
    end
end
Rem.on("worldHour", function() Rem.safe(PB.hourly) end)

-- Defesa extra contra ataques (Rem_World.resolveRaid): vigias e janelas fechadas.
function PB.defenseBonus(g)
    local guards = 0
    for _, p in ipairs(PB.members(g)) do if p.job == "guard" then guards = guards + 1 end end
    local h = g.home
    local sealed = (h.windowsTotal and h.windowsTotal > 0) and (h.windowsDone or 0) / h.windowsTotal or 0
    return guards * CFG.GUARD_DEFENSE + sealed * CFG.WINDOW_DEFENSE
end

-- ataque de saqueadores a sua base vai para o diario
Rem.on("raidResolved", function(attacker, victim, winner)
    if not victim or not victim.player then return end
    if winner == victim then Rem.Journal.add("IGUI_Rem_Journal_base_raid_won")
    else Rem.Journal.add("IGUI_Rem_Journal_base_raid_lost") end
end)

-- (morreu: Rem.removePerson ja tira da lista da base)

local lastSync = -999999
Rem.on("sceneUpdate", function(player, now)
    local g = PB.get()
    if not g or now - lastSync < CFG.SYNC_MS then return end
    lastSync = now
    if Rem.dist2(player:getX(), player:getY(), g.home.x, g.home.y) < S.CFG.PREPARE_RADIUS then
        Rem.safe(PB.syncStash, g)
    end
end)

-- ---------------------------------------------------------------- menu
local function hasFollowers()
    for _, npc in pairs(Rem.active) do
        if npc.rec.faction == "aliados" and not npc.rec.groupId then return true end
    end
    return false
end

Rem.registerPlayerOption("ContextMenu_Rem_BaseSet", function(player)
    local g, why, nStash, hasDoor = PB.setHere(player)
    if not g then
        player:Say(getText(why))
        return
    end
    player:Say(getText("IGUI_Rem_Base_set", tostring(nStash)))
end, function() local p = getPlayer() return p ~= nil and PB.canSetHere(p) end)

Rem.registerPlayerOption("ContextMenu_Rem_BaseSendAll", function(player)
    local n = PB.sendAll()
    player:Say(getText("IGUI_Rem_Base_sent", tostring(n)))
end, function() return PB.get() ~= nil and hasFollowers() end)

Rem.registerNpcOption("ContextMenu_Rem_SendToBase", function(npc) PB.join(npc) end, function(npc)
    return PB.get() ~= nil and npc.rec.faction == "aliados" and not npc.rec.groupId
end)
