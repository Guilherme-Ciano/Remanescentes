-- Remanescentes - mundo vivo (Fase 3): grupos no papel, simulacao horaria e
-- materializacao perto do jogador.
--
-- grupo = {
--   id, name, faction, members = { personId... },
--   home   = { x, y, z, bid },        -- predio real (BuildingDef) onde moram
--   x, y, z,                          -- posicao do grupo (fora de cena)
--   supplies,                         -- comida/agua em "pessoa-dias"
--   activity = "home"|"scavenge"|"return"|"raid",
--   target = { x, y, z, bid, victim }, arrivedAt, hungerHours,
-- }
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_Factions"
require "Remanescentes/Rem_Spawn"
local Rem = Remanescentes

local SPAWN_RADIUS = 45      -- pessoas a menos disso do jogador ganham corpo
local DESPAWN_RADIUS = 70    -- com corpo e mais longe que isso: volta ao papel
local SCENE_CHECK_MS = 1500
local START_GRACE_MS = 4000  -- apos carregar, espera os chunks re-associarem corpos salvos
local TRAVEL_PER_HOUR = 300  -- tiles por hora de jogo, fora de cena
local ARRIVE_DIST = 6
local SEED_RADIUS = 350
local SEED_MIN_DIST = 60     -- nao nasce grupo em cima do jogador
local HOME_SPACING = 40

-- ---------------------------------------------------------------- predios
local function buildings()
    return getWorld():getMetaGrid():getBuildings()
end

local function buildingCenter(def)
    return math.floor(def:getX() + def:getW() / 2), math.floor(def:getY() + def:getH() / 2)
end

local function bidOf(def)
    return tostring(def:getID())
end

local function isHomeOfGroup(bid)
    for _, g in pairs(Rem.getStore().groups) do
        if g.home and g.home.bid == bid then return true end
    end
    return false
end

-- Sorteia um predio a [minD, maxD] de (x, y). filter(def, bid) opcional.
function Rem.pickBuilding(x, y, minD, maxD, filter)
    local list = buildings()
    local n = list:size()
    if n == 0 then return nil end
    for _ = 1, 300 do
        local def = list:get(ZombRand(n))
        local bx, by = buildingCenter(def)
        local d = Rem.dist2(x, y, bx, by)
        local area = def:getW() * def:getH()
        if d >= minD and d <= maxD and area >= 30 and area <= 2500 then
            local bid = bidOf(def)
            if not filter or filter(def, bid, bx, by) then
                return def, bx, by, bid
            end
        end
    end
    return nil
end

-- ---------------------------------------------------------------- grupos
local GROUP_NAMES = {
    civis = { "Familia", "Vizinhos", "Moradores" },
    sobreviventes = { "Sobreviventes", "Bando", "Equipe" },
    saqueadores = { "Saqueadores", "Gangue", "Corvos" },
}

function Rem.createGroup(faction, x, y, bid, size)
    local store = Rem.getStore()
    local g = {
        id = Rem.newId("g"),
        faction = faction,
        name = Rem.pick(GROUP_NAMES[faction] or GROUP_NAMES.civis),
        members = {},
        home = { x = x, y = y, z = 0, bid = bid },
        x = x, y = y, z = 0,
        supplies = 2 + ZombRand(6),
        activity = "home",
        hungerHours = 0,
    }
    store.groups[g.id] = g
    for _ = 1, size do
        local p = Rem.newPerson({ faction = faction, groupId = g.id, mode = "group",
            x = x + ZombRandFloat(-2, 2), y = y + ZombRandFloat(-2, 2), z = 0 })
        table.insert(g.members, p.id)
    end
    Rem.log("grupo " .. g.id .. " (" .. faction .. ", " .. size .. " pessoas) mora em " .. x .. "," .. y)
    return g
end

local function randomFaction()
    local raid = Rem.cfg("RaiderPercent", 20)
    local r = ZombRand(100)
    if r < raid then return "saqueadores" end
    if r < raid + (100 - raid) * 0.45 then return "sobreviventes" end
    return "civis"
end

local function groupSize(faction)
    if faction == "saqueadores" then return 2 + ZombRand(4) end
    return 1 + ZombRand(4)
end

local function farFromOtherHomes(_, bid, bx, by)
    if isHomeOfGroup(bid) then return false end
    for _, g in pairs(Rem.getStore().groups) do
        if g.home and Rem.dist2(bx, by, g.home.x, g.home.y) < HOME_SPACING then return false end
    end
    return true
end

-- Cria um grupo morando num predio a [minD, maxD] do ponto.
function Rem.seedGroupNear(x, y, minD, maxD, faction)
    local def, bx, by, bid = Rem.pickBuilding(x, y, minD, maxD, farFromOtherHomes)
    if not def then return nil end
    faction = faction or randomFaction()
    return Rem.createGroup(faction, bx, by, bid, groupSize(faction))
end

function Rem.groupCount()
    local n = 0
    for _ in pairs(Rem.getStore().groups) do n = n + 1 end
    return n
end

function Rem.seedWorld(player)
    local store = Rem.getStore()
    if store.seeded then return end
    store.seeded = true
    local target = Rem.cfg("WorldGroups", 12)
    local made = 0
    for _ = 1, target do
        if Rem.seedGroupNear(player:getX(), player:getY(), SEED_MIN_DIST, SEED_RADIUS) then made = made + 1 end
    end
    Rem.log("mundo semeado: " .. made .. " grupos")
end

-- ---------------------------------------------------------------- simulacao (fora de cena)
local function membersOf(g)
    local out = {}
    local people = Rem.getStore().people
    for i = #g.members, 1, -1 do
        local p = people[g.members[i]]
        if p then table.insert(out, p) else table.remove(g.members, i) end
    end
    return out
end

local function anyOnScene(members)
    for _, p in ipairs(members) do
        if p.onScene then return p end
    end
    return nil
end

-- Mata/remove uma pessoa fora de cena.
local function killOffscene(p, reason)
    if p.onScene then return false end
    Rem.removePerson(p.id)
    Rem.debug(p.name .. " morreu fora de cena (" .. reason .. ")")
    return true
end

-- Move o grupo (e as pessoas sem corpo) em direcao a (tx, ty). Retorna true se chegou.
local function travel(g, members, tx, ty)
    local leader = anyOnScene(members)
    if leader then
        -- alguem com corpo: o cerebro anda de verdade; o grupo acompanha o lider
        g.x, g.y = leader.x, leader.y
    else
        local d = Rem.dist2(g.x, g.y, tx, ty)
        if d <= TRAVEL_PER_HOUR then
            g.x, g.y = tx, ty
        else
            g.x = g.x + (tx - g.x) / d * TRAVEL_PER_HOUR
            g.y = g.y + (ty - g.y) / d * TRAVEL_PER_HOUR
        end
        for _, p in ipairs(members) do
            p.x = g.x + ZombRandFloat(-2, 2)
            p.y = g.y + ZombRandFloat(-2, 2)
        end
    end
    return Rem.dist2(g.x, g.y, tx, ty) <= ARRIVE_DIST
end

local function chooseScavengeTarget(g)
    local looted = Rem.getStore().looted
    local def, bx, by, bid = Rem.pickBuilding(g.home.x, g.home.y, 25, 140, function(_, b)
        return not looted[b] and not isHomeOfGroup(b)
    end)
    if not def then return false end
    g.activity = "scavenge"
    g.target = { x = bx, y = by, z = 0, bid = bid }
    g.arrivedAt = nil
    Rem.debug("grupo " .. g.id .. " saiu para saquear " .. bx .. "," .. by)
    return true
end

local function chooseRaidTarget(g)
    local best, bestD = nil, 250
    for _, other in pairs(Rem.getStore().groups) do
        if other ~= g and other.home and Rem.factionsHostile(g.faction, other.faction) then
            local d = Rem.dist2(g.home.x, g.home.y, other.home.x, other.home.y)
            if d < bestD then best, bestD = other, d end
        end
    end
    if not best then return false end
    g.activity = "raid"
    g.target = { x = best.home.x, y = best.home.y, z = 0, victim = best.id }
    g.arrivedAt = nil
    Rem.debug("grupo " .. g.id .. " vai atacar o grupo " .. best.id)
    return true
end

-- Saque terminado no local: ganha suprimentos, marca o predio, pode perder gente.
local function finishScavenge(g, members, hour)
    local store = Rem.getStore()
    local bid = g.target and g.target.bid
    local gain = 1 + ZombRand(5)
    if bid and store.looted[bid] then gain = math.floor(gain / 3) end
    g.supplies = g.supplies + gain
    if bid then store.looted[bid] = hour end
    -- risco: cada saque pode custar alguem (so quem nao esta em cena)
    if ZombRand(100) < Rem.cfg("ScavengeDeathChance", 8) then
        local p = members[ZombRand(#members) + 1]
        if p then killOffscene(p, "saque") end
    end
    g.activity = "return"
    g.target = nil
    g.arrivedAt = nil
end

-- Ataque fora de cena: o mais forte ganha; o perdedor perde gente e suprimentos.
local function resolveRaid(g, members)
    local store = Rem.getStore()
    local victim = g.target and store.groups[g.target.victim]
    if victim and #membersOf(victim) > 0 then
        local vMembers = membersOf(victim)
        local attack = #members + ZombRandFloat(0, 2)
        local defend = #vMembers + ZombRandFloat(0, 2) + 0.5 -- defender a casa ajuda
        local loser, loserMembers, winner = victim, vMembers, g
        if defend > attack then loser, loserMembers, winner = g, members, victim end
        local losses = 1 + ZombRand(2)
        for i = 1, math.min(losses, #loserMembers) do killOffscene(loserMembers[i], "ataque") end
        local stolen = math.floor(loser.supplies / 2)
        loser.supplies = loser.supplies - stolen
        winner.supplies = winner.supplies + stolen
        Rem.log("ataque: grupo " .. g.id .. " x " .. victim.id .. " -> venceu " .. winner.id)
    end
    g.activity = "return"
    g.target = nil
end

function Rem.simulateGroup(g, hour)
    local members = membersOf(g)
    if #members == 0 then return "empty" end
    local n = #members

    -- consumo: 1 pessoa-dia por pessoa a cada 24h
    g.supplies = g.supplies - n / 24
    if g.supplies <= 0 then
        g.supplies = 0
        g.hungerHours = (g.hungerHours or 0) + 1
        if g.hungerHours >= 72 and ZombRand(24) == 0 then
            local p = members[ZombRand(n) + 1]
            if killOffscene(p, "fome") then g.hungerHours = 48 end
        end
    else
        g.hungerHours = 0
    end

    local tod = getGameTime():getTimeOfDay()
    local daytime = tod >= 7 and tod <= 19

    if g.activity == "home" then
        travel(g, members, g.home.x, g.home.y)
        local low = g.supplies < n * 2
        if low and daytime and ZombRand(3) == 0 then
            if g.faction == "saqueadores" and ZombRand(100) < 40 and chooseRaidTarget(g) then return end
            chooseScavengeTarget(g)
        end
    elseif g.activity == "scavenge" or g.activity == "raid" then
        if not g.target then g.activity = "return" return end
        if travel(g, members, g.target.x, g.target.y) then
            g.arrivedAt = g.arrivedAt or hour
            if hour - g.arrivedAt >= 1 then
                if g.activity == "raid" then
                    if not anyOnScene(members) then resolveRaid(g, members) else g.activity = "return" end
                else
                    finishScavenge(g, members, hour)
                end
            end
        end
    elseif g.activity == "return" then
        if travel(g, members, g.home.x, g.home.y) then g.activity = "home" end
    end
end

function Rem.simulateWorld(hours)
    local store = Rem.getStore()
    for _ = 1, (hours or 1) do
        local hour = Rem.worldHours()
        local empty = {}
        for id, g in pairs(store.groups) do
            local ok, res = pcall(Rem.simulateGroup, g, hour)
            if not ok then Rem.log("ERRO simulando grupo " .. id .. ": " .. tostring(res))
            elseif res == "empty" then table.insert(empty, id) end
        end
        for _, id in ipairs(empty) do
            local g = store.groups[id]
            store.abandoned = store.abandoned or {}
            if g and g.home and g.home.bid then store.abandoned[g.home.bid] = hour end
            store.groups[id] = nil
            Rem.log("grupo " .. id .. " acabou")
        end
    end
end

Events.EveryHours.Add(function()
    if Rem.isAuthority() then Rem.simulateWorld(1) end
end)

-- Mundo continua crescendo: se houver poucos grupos, nasce um novo longe do jogador.
Events.EveryDays.Add(function()
    if not Rem.isAuthority() then return end
    local player = getPlayer()
    if not player then return end
    if Rem.groupCount() < Rem.cfg("WorldGroups", 12) then
        Rem.seedGroupNear(player:getX(), player:getY(), 150, 450)
    end
end)

-- ---------------------------------------------------------------- casas saqueadas
-- Quando o jogo gera o loot de um conteiner pela 1a vez, esvazia se um grupo ja saqueou
-- aquele predio fora de cena (sobra um pouco).
Events.OnFillContainer.Add(function(roomType, containerType, container)
    if not Rem.isAuthority() then return end
    Rem.safe(function()
        local sq = container:getSourceGrid()
        local b = sq and sq:getBuilding()
        local def = b and b:getDef()
        if not def then return end
        if Rem.getStore().looted[bidOf(def)] and ZombRand(100) >= Rem.cfg("LootLeftPercent", 15) then
            container:removeAllItems()
        end
    end)
end)

-- ---------------------------------------------------------------- materializacao
local startedAt = nil

local function findZombieByPid(pid)
    local list = getCell():getZombieList()
    for i = 0, list:size() - 1 do
        local z = list:get(i)
        if z:getPersistentOutfitID() == pid and not z:isDead() then return z end
    end
    return nil
end

function Rem.updateScene(player, now)
    local store = Rem.getStore()
    local cap = Rem.cfg("MaxActive", 12)
    local px, py = player:getX(), player:getY()

    -- tira corpo de quem ficou longe (seguidores nunca)
    local far = nil
    for _, npc in pairs(Rem.active) do
        if npc.rec.mode ~= "follow" and Rem.dist2(px, py, npc.z:getX(), npc.z:getY()) > DESPAWN_RADIUS then
            far = far or {}
            table.insert(far, npc)
        end
    end
    if far then for _, npc in ipairs(far) do Rem.dematerialize(npc) end end

    -- da corpo a quem chegou perto (mais perto primeiro)
    local cand = {}
    for _, rec in pairs(store.people) do
        if not rec.onScene and rec.x then
            local d = Rem.dist2(px, py, rec.x, rec.y)
            if d < SPAWN_RADIUS then table.insert(cand, { rec = rec, d = d }) end
        end
    end
    table.sort(cand, function(a, b) return a.d < b.d end)
    for _, c in ipairs(cand) do
        if Rem.activeCount >= cap then break end
        local rec = c.rec
        local zombie = rec.pid and findZombieByPid(rec.pid)
        if zombie and not Rem.active[zombie] then
            Rem.activate(zombie, rec)
        elseif getCell():getGridSquare(math.floor(rec.x), math.floor(rec.y), math.floor(rec.z or 0)) then
            rec.pid = nil
            Rem.materialize(rec)
        end
    end
end

local nextScene = 0
Events.OnTick.Add(function()
    if not Rem.isAuthority() then return end
    local now = Rem.nowMs()
    if not startedAt then startedAt = now end
    if now < nextScene or now - startedAt < START_GRACE_MS then return end
    nextScene = now + SCENE_CHECK_MS
    local player = getPlayer()
    if not player or player:isDead() then return end
    Rem.safe(Rem.seedWorld, player)
    Rem.safe(Rem.updateScene, player, now)
end)

-- ---------------------------------------------------------------- consultas (debug/UI)
function Rem.nearestGroup(x, y)
    local best, bestD = nil, math.huge
    for _, g in pairs(Rem.getStore().groups) do
        local d = Rem.dist2(x, y, g.x, g.y)
        if d < bestD then best, bestD = g, d end
    end
    return best, bestD
end
