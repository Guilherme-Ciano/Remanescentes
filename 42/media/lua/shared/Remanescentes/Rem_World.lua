-- Remanescentes - mundo vivo (Fase 3): grupos no papel, semeadura, simulacao horaria
-- fora de cena e predios saqueados. A parte "em cena" (dar/tirar corpo perto do jogador,
-- teleporte de debug) esta em Rem_Scene.lua.
--
-- grupo = {
--   id, name, faction, members = { personId... },
--   home   = { x, y, z, bid, x1, y1, x2, y2 }, -- predio real (BuildingDef) e seu retangulo
--   x, y, z,                          -- posicao do grupo (fora de cena)
--   supplies,                         -- comida/agua em "pessoa-dias"
--   activity = "home"|"scavenge"|"return"|"raid",
--   target = { x, y, z, bid, victim }, arrivedAt, hungerHours,
-- }
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_Factions"
require "Remanescentes/Rem_Spawn"
require "Remanescentes/Rem_Scene"
require "Remanescentes/Rem_Timeline"
local Rem = Remanescentes

local W = Rem.module("World", {
    TRAVEL_PER_HOUR = 300,      -- tiles por hora de jogo, fora de cena
    ARRIVE_DIST = 6,
    SEED_RADIUS = 350,
    SEED_MIN_DIST = 60,         -- nao nasce grupo em cima do jogador
    HOME_SPACING = 40,
    NOMAD_MOVE_ODDS = 24,       -- errantes: 1 em N horas (de dia) mudam de acampamento
    ROUTINE_SCAVENGE_ODDS = 16, -- com comida sobrando: 1 em N horas (de dia) saem para saquear
    PUNITIVE_MIN = 4,           -- milicia com pelo menos tantos membros...
    PUNITIVE_CHANCE = 15,       -- ...(%) quando sai por comida, ataca saqueadores inimigos
    ITEMS_PER_SUPPLY = 2,       -- itens no estoque por "pessoa-dia" de suprimento
})

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
        if g.home and g.home.bid == bid then return true end   -- (inclui a sua base)
    end
    return false
end

-- Sorteia um predio a [minD, maxD] de (x, y). filter(def, bid) opcional.
-- Indice dos predios por celulas de BUCKET tiles (feito uma vez; refeito se a lista mudar).
-- Antes, pickBuilding sorteava 300 vezes entre TODOS os predios do mapa (milhares): perto
-- de um ponto quase nunca acertava, e grupos e coletores ficavam sem destino.
local BUCKET = 100
local bIndex, bIndexSize = nil, -1

local function buildingIndex()
    local list = buildings()
    local n = list:size()
    if bIndex and bIndexSize == n then return bIndex end
    bIndex, bIndexSize = {}, n
    for i = 0, n - 1 do
        local def = list:get(i)
        local bx, by = buildingCenter(def)
        local k = math.floor(bx / BUCKET) * 100000 + math.floor(by / BUCKET)
        local cell = bIndex[k]
        if not cell then cell = {} bIndex[k] = cell end
        table.insert(cell, def)
    end
    return bIndex
end

-- (testes: predios criados depois)
function Rem.resetBuildingIndex() bIndex, bIndexSize = nil, -1 end

-- Sorteia um predio a [minD, maxD] de (x, y). filter(def, bid, bx, by) opcional.
function Rem.pickBuilding(x, y, minD, maxD, filter)
    local index = buildingIndex()
    local cand = {}
    local c0x, c1x = math.floor((x - maxD) / BUCKET), math.floor((x + maxD) / BUCKET)
    local c0y, c1y = math.floor((y - maxD) / BUCKET), math.floor((y + maxD) / BUCKET)
    for cx = c0x, c1x do
        for cy = c0y, c1y do
            for _, def in ipairs(index[cx * 100000 + cy] or {}) do
                local bx, by = buildingCenter(def)
                local d = Rem.dist2(x, y, bx, by)
                local area = def:getW() * def:getH()
                if d >= minD and d <= maxD and area >= 30 and area <= 2500 then
                    table.insert(cand, def)
                end
            end
        end
    end
    -- ordem aleatoria (o mesmo sorteio de antes, mas so entre os que estao no raio)
    for i = #cand, 2, -1 do
        local j = ZombRand(i) + 1
        cand[i], cand[j] = cand[j], cand[i]
    end
    for _, def in ipairs(cand) do
        local bx, by = buildingCenter(def)
        local bid = bidOf(def)
        if not filter or filter(def, bid, bx, by) then
            return def, bx, by, bid
        end
    end
    return nil
end

-- ---------------------------------------------------------------- grupos
-- nomes de grupo por faccao (faccoes registradas podem trazer def.groupNames)
W.GROUP_NAMES = W.GROUP_NAMES or {
    civis = { "Familia", "Vizinhos", "Moradores" },
    sobreviventes = { "Sobreviventes", "Bando", "Equipe" },
    saqueadores = { "Saqueadores", "Gangue", "Corvos" },
}

local function groupNamesOf(faction)
    local names = W.GROUP_NAMES[faction]
    if not names then
        local fdef = Rem.FACTIONS[faction]
        names = fdef and fdef.groupNames
    end
    return names or W.GROUP_NAMES.civis
end

function Rem.createGroup(faction, x, y, bid, size, def)
    local store = Rem.getStore()
    local home = { x = x, y = y, z = 0, bid = bid }
    if def then
        home.x1, home.y1 = def:getX(), def:getY()
        home.x2, home.y2 = def:getX() + def:getW(), def:getY() + def:getH()
    end
    local g = {
        id = Rem.newId("g"),
        faction = faction,
        name = Rem.pick(groupNamesOf(faction)),
        members = {},
        home = home,
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
    Rem.debug("grupo " .. g.id .. " (" .. faction .. ", " .. size .. " pessoas) mora em " .. x .. "," .. y)
    Rem.emit("groupCreated", g, def)
    return g
end

-- Sorteio da faccao de um grupo novo. Saqueadores: sandbox RaiderPercent; o resto se
-- divide pelos pesos abaixo (seita e rara; errantes andam sozinhos).
W.FACTION_WEIGHTS = W.FACTION_WEIGHTS or { civis = 45, sobreviventes = 38, errantes = 12, seita = 5 }

-- tamanho do grupo { min, max } por faccao (safehouses: 2 a 6 moradores)
W.GROUP_SIZE = W.GROUP_SIZE or {
    civis = { 2, 5 }, sobreviventes = { 3, 6 }, saqueadores = { 2, 6 }, seita = { 4, 6 }, errantes = { 1, 1 },
}

-- A linha do tempo (Rem_Timeline) pesa o sorteio: sem saqueadores antes do dia de inicio
-- deles, milicias ainda se formando nos primeiros dias.
local function factionWeight(name)
    local w = W.FACTION_WEIGHTS[name] or 0
    if name == "sobreviventes" or name == "seita" then w = w * Rem.Timeline.militiaFactor() end
    return w
end

function Rem.randomFaction(noHostile)
    local raid = Rem.cfg("RaiderPercent", 20) * Rem.Timeline.raiderFactor()
    if not noHostile and ZombRand(100) < raid then return "saqueadores" end
    local names, total = {}, 0
    for name in pairs(W.FACTION_WEIGHTS) do
        if Rem.FACTIONS[name] and not (noHostile and Rem.Timeline.isHostileFaction(name)) then
            table.insert(names, name)
            total = total + factionWeight(name)
        end
    end
    table.sort(names)
    local r = ZombRandFloat(0, total)
    for _, name in ipairs(names) do
        r = r - factionWeight(name)
        if r <= 0 then return name end
    end
    return "civis"
end

function Rem.groupSizeFor(faction)
    local r = W.GROUP_SIZE[faction] or { 2, 4 }
    return ZombRand(r[1], r[2] + 1)
end

local function farFromOtherHomes(_, bid, bx, by)
    if isHomeOfGroup(bid) then return false end
    for _, g in pairs(Rem.getStore().groups) do
        if g.home and Rem.dist2(bx, by, g.home.x, g.home.y) < W.CFG.HOME_SPACING then return false end
    end
    return true
end

-- Cria um grupo morando num predio a [minD, maxD] do ponto.
W.farFromOtherHomes = farFromOtherHomes   -- (Rem_Regions)
W.isHomeOfGroup = isHomeOfGroup

function Rem.seedGroupNear(x, y, minD, maxD, faction)
    local def, bx, by, bid = Rem.pickBuilding(x, y, minD, maxD, farFromOtherHomes)
    if not def then return nil end
    -- zona de graca: perto de onde voce comecou, nos primeiros dias, nada hostil
    local graced = Rem.Timeline.protects(bx, by)
    faction = faction or Rem.randomFaction(graced)
    if graced and Rem.Timeline.isHostileFaction(faction) then faction = Rem.randomFaction(true) end
    return Rem.createGroup(faction, bx, by, bid, Rem.groupSizeFor(faction), def)
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
    Rem.Timeline.markStart(player)
    local made = 0
    if Rem.Regions then
        -- Fase D1: grupos por regiao (cidade cheia, campo vazio); o resto do mapa ganha
        -- grupos conforme voce explora (Rem_Regions)
        made = Rem.Regions.seedAround(player)
    else
        local target = Rem.cfg("WorldGroups", 40)
        for _ = 1, target do
            if Rem.seedGroupNear(player:getX(), player:getY(), W.CFG.SEED_MIN_DIST, W.CFG.SEED_RADIUS) then made = made + 1 end
        end
    end
    Rem.log("mundo semeado: " .. made .. " grupos")
    Rem.emit("worldSeeded", player)
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
-- Anda "step" tiles em direcao a (tx, ty), levando as pessoas sem corpo junto.
local function moveToward(g, members, tx, ty, step)
    local d = Rem.dist2(g.x, g.y, tx, ty)
    if step <= 0 then return end
    if d <= step then
        g.x, g.y = tx, ty
    else
        g.x = g.x + (tx - g.x) / d * step
        g.y = g.y + (ty - g.y) / d * step
    end
    for _, p in ipairs(members) do
        p.x = g.x + ZombRandFloat(-2, 2)
        p.y = g.y + ZombRandFloat(-2, 2)
    end
end

-- Viagem (D2): fora de cena o grupo anda em passos a cada 10 min de jogo (Rem.stepGroups);
-- aqui, na hora cheia, anda so o que faltou da hora (simulacoes sem os passos, como
-- "Simular 6 horas", andam a hora inteira). Retorna true se chegou.
local function travel(g, members, tx, ty)
    local leader = anyOnScene(members)
    if leader then
        -- alguem com corpo: o cerebro anda de verdade; o grupo acompanha o lider
        g.x, g.y = leader.x, leader.y
    else
        moveToward(g, members, tx, ty, W.CFG.TRAVEL_PER_HOUR - (g.movedThisHour or 0))
    end
    g.movedThisHour = 0
    return Rem.dist2(g.x, g.y, tx, ty) <= W.CFG.ARRIVE_DIST
end

local function destOf(g)
    if (g.activity == "scavenge" or g.activity == "raid") and g.target then return g.target.x, g.target.y end
    if g.activity == "return" and g.home then return g.home.x, g.home.y end
    return nil
end

-- Passo de viagem (a cada 10 min de jogo): grupos a caminho, sem ninguem em cena.
function Rem.stepGroups(minutes)
    local step = W.CFG.TRAVEL_PER_HOUR * minutes / 60
    for _, g in pairs(Rem.getStore().groups) do
        local tx, ty = destOf(g)
        if tx then
            local members = membersOf(g)
            if #members > 0 and not anyOnScene(members) then
                local before = Rem.dist2(g.x, g.y, tx, ty)
                moveToward(g, members, tx, ty, step)
                g.movedThisHour = (g.movedThisHour or 0) + math.min(step, before)
            end
        end
    end
end

local function chooseScavengeTarget(g)
    local looted = Rem.getStore().looted
    local def, bx, by, bid = Rem.pickBuilding(g.home.x, g.home.y, 25, 140, function(_, b)
        return not looted[b] and not isHomeOfGroup(b)
    end)
    if not def then return false end
    g.activity = "scavenge"
    g.target = { x = bx, y = by, z = 0, bid = bid,
        x1 = def:getX(), y1 = def:getY(), x2 = def:getX() + def:getW(), y2 = def:getY() + def:getH() }
    g.arrivedAt = nil
    Rem.debug("grupo " .. g.id .. " saiu para saquear " .. bx .. "," .. by)
    return true
end

-- (Rem_Director decide quando a comida ou o material acabam)
W.startScavenge = function(g) return chooseScavengeTarget(g) end

-- Alvo de ataque: grupo inimigo (relacao ruim, Rem_Relations; sem esse modulo, faccao
-- hostil). punitive = milicia atacando saqueadores.
local function isEnemy(g, other)
    if Rem.relation then return Rem.relation(g, other) <= Rem.Relations.CFG.ENEMY_AT end
    return Rem.factionsHostile(g.faction, other.faction)
end

local function chooseRaidTarget(g, punitive)
    if g.faction == "saqueadores" and Rem.Timeline.raiderFactor() <= 0 then return false end   -- ainda nao se organizaram
    local best, bestD = nil, 250
    for _, other in pairs(Rem.getStore().groups) do
        if other ~= g and other.home and isEnemy(g, other) and (not punitive or other.faction == "saqueadores")
            and not (other.player and Rem.Diplomacy and Rem.Diplomacy.protectedFrom(g)) then
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
    if anyOnScene(members) then
        -- saque em cena: o ganho sao os itens que eles pegaram de verdade nos armarios
        -- (contados quando guardam no estoque de casa, ver Rem_Scavenge)
    else
        local gain = 1 + ZombRand(5)
        if bid and store.looted[bid] then gain = math.floor(gain / 3) end
        g.supplies = g.supplies + gain
        -- itens que vao aparecer no estoque da casa quando ela carregar
        g.pendingItems = (g.pendingItems or 0) + gain * W.CFG.ITEMS_PER_SUPPLY
    end
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
        if victim.player and Rem.PlayerBase then defend = defend + Rem.PlayerBase.defenseBonus(victim) end   -- guardas e janelas
        if Rem.BaseBuild and not victim.player then defend = defend + Rem.BaseBuild.structureBonus(victim) end   -- cerca, arame, carros
        if Rem.allyHelp then defend = defend + Rem.allyHelp(victim) end   -- aliados por perto (D4)
        local loser, loserMembers, winner = victim, vMembers, g
        if defend > attack then loser, loserMembers, winner = g, members, victim end
        local losses = 1 + ZombRand(2)
        for i = 1, math.min(losses, #loserMembers) do killOffscene(loserMembers[i], "ataque") end
        local stolen = math.floor(loser.supplies / 2)
        loser.supplies = loser.supplies - stolen
        winner.supplies = winner.supplies + stolen
        Rem.debug("ataque: grupo " .. g.id .. " x " .. victim.id .. " -> venceu " .. winner.id)
        Rem.emit("raidResolved", g, victim, winner)
        -- (D3) atacantes acabaram com o grupo: tomam a base dele (fortificacoes e estoque).
        -- A sua base nao e tomada: fica vazia, e voce pode voltar a ocupa-la.
        if winner == g and #membersOf(victim) == 0 and victim.home and victim.home.x1 and not victim.player then
            g.oldHome = g.home
            g.home = victim.home
            Rem.debug("grupo " .. g.id .. " (" .. g.faction .. ") tomou a base do grupo " .. victim.id)
            Rem.emit("baseTaken", g, victim)
        end
    end
    g.activity = "return"
    g.target = nil
end

-- Errantes nao tem casa fixa: de tempos em tempos escolhem outro predio longe e vao ate la.
function Rem.moveCamp(g)
    local def, bx, by, bid = Rem.pickBuilding(g.home.x, g.home.y, 80, 250, function(_, b)
        return not isHomeOfGroup(b)
    end)
    if not def then return false end
    g.home = { x = bx, y = by, z = 0, bid = bid,
        x1 = def:getX(), y1 = def:getY(), x2 = def:getX() + def:getW(), y2 = def:getY() + def:getH() }
    g.activity = "return"
    g.target = nil
    Rem.debug("errantes " .. g.id .. " mudaram o acampamento para " .. bx .. "," .. by)
    return true
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
        if g.faction == "errantes" and daytime and ZombRand(W.CFG.NOMAD_MOVE_ODDS) == 0
            and Rem.moveCamp(g) then
            return
        end
        if low and daytime and ZombRand(3) == 0 then
            if g.faction == "saqueadores" and ZombRand(100) < 40 and chooseRaidTarget(g) then return end
            if g.faction == "sobreviventes" and n >= W.CFG.PUNITIVE_MIN and ZombRand(100) < W.CFG.PUNITIVE_CHANCE
                and chooseRaidTarget(g, true) then return end
            chooseScavengeTarget(g)
        elseif not low and daytime and n >= 2 and ZombRand(W.CFG.ROUTINE_SCAVENGE_ODDS) == 0 then
            -- de tempos em tempos saem para aumentar o estoque, mesmo sem fome
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
            local ok, res = true, nil
            if not g.player then ok, res = pcall(Rem.simulateGroup, g, hour) end   -- (base do jogador: Rem_PlayerBase)
            if not ok then Rem.log("ERRO simulando grupo " .. id .. ": " .. tostring(res))
            elseif res == "empty" then table.insert(empty, id) end
        end
        for _, id in ipairs(empty) do
            local g = store.groups[id]
            store.abandoned = store.abandoned or {}
            if g and g.home and g.home.bid then store.abandoned[g.home.bid] = hour end
            store.groups[id] = nil
            Rem.debug("grupo " .. id .. " acabou")
            if g then Rem.emit("groupRemoved", g) end
        end
        Rem.emit("worldHour", hour)
    end
end

Events.EveryHours.Add(function()
    if Rem.isAuthority() then Rem.simulateWorld(1) end
end)

Events.EveryTenMinutes.Add(function()
    if Rem.isAuthority() then Rem.safe(Rem.stepGroups, 10) end
end)

-- Mundo continua crescendo: se houver poucos grupos, nasce um novo longe do jogador.
Events.EveryDays.Add(function()
    if not Rem.isAuthority() then return end
    local player = getPlayer()
    if not player then return end
    if Rem.groupCount() < Rem.cfg("WorldGroups", 12) then
        Rem.seedGroupNear(player:getX(), player:getY(), 150, 450)
    end
    -- com o tempo, saqueadores novos se formam (mesmo com o mundo "cheio")
    local rf = Rem.Timeline.raiderFactor()
    if rf > 0 and Rem.groupCount() < Rem.cfg("WorldGroups", 12) + Rem.Timeline.CFG.EXTRA_GROUPS
        and ZombRand(100) < Rem.Timeline.CFG.LATE_RAIDER_CHANCE * rf then
        Rem.seedGroupNear(player:getX(), player:getY(), 150, 450, "saqueadores")
    end
end)

-- ---------------------------------------------------------------- casas saqueadas
-- Quando o jogo gera o loot de um conteiner pela 1a vez, esvazia se um grupo ja saqueou
-- aquele predio fora de cena (sobra um pouco).
Events.OnFillContainer.Add(function(roomType, containerType, container)
    if not Rem.isAuthority() then return end
    Rem.safe(function()
        -- o 3o argumento as vezes e um ItemPickerContainer (mochila de zumbi), nao um conteiner
        if not instanceof(container, "ItemContainer") then return end
        local sq = container:getSourceGrid()
        local b = sq and sq:getBuilding()
        local def = b and b:getDef()
        if not def then return end
        if Rem.getStore().looted[bidOf(def)] and ZombRand(100) >= Rem.cfg("LootLeftPercent", 15) then
            container:removeAllItems()
        end
    end)
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

-- ---------------------------------------------------------------- recriar grupos (teste)
-- Para saves antigos: tira todos os grupos (e seus membros) e semeia o mundo de novo.
-- Pessoas sem grupo (seus aliados, sobreviventes criados no menu) ficam.
function Rem.reseedWorld(player)
    local store = Rem.getStore()
    local gone = {}
    for _, npc in pairs(Rem.active) do
        if npc.rec.groupId then table.insert(gone, npc) end
    end
    for _, npc in ipairs(gone) do Rem.dismiss(npc) end
    for id, rec in pairs(store.people) do
        if rec.groupId then Rem.removePerson(id) end
    end
    local groups = {}
    for _, g in pairs(store.groups) do table.insert(groups, g) end
    store.groups = {}
    Rem.bulkRemove = true
    for _, g in ipairs(groups) do Rem.emit("groupRemoved", g) end
    Rem.bulkRemove = nil
    store.seeded = false
    store.regions = {}
    Rem.seedWorld(player)
    return Rem.groupCount()
end

Rem.registerDebugOption("ContextMenu_Rem_Reseed", function(x, y, z, player)
    local n = Rem.reseedWorld(player)
    player:Say(n .. " grupos novos no mundo.")
end)

