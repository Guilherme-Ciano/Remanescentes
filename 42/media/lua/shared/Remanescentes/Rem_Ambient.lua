-- Remanescentes - Fase C3/C5: populacao de passagem e eventos de rua ("dia zero").
--
-- Gente que NAO e de grupo nenhum: nasce fora da sua vista (32-42 tiles, de preferencia
-- atras de voce), cruza a area e some. Nao fica no mundo: quando se afasta (ou o tempo dela
-- acaba), e removida em vez de voltar ao papel (rec.transient).
-- Quanto: pela linha do tempo (muita gente nos primeiros dias, pouca depois) e pelo bairro
-- (cidade x campo). Nunca passa do limite de sobreviventes presentes (MaxActive).
--
-- Tipos:
--   walker    civil andando para algum lugar
--   runner    civil correndo, com zumbis atras dele
--   family    2-4 civis seguindo o lider
--   help      ferido gritando por socorro, com zumbis em volta; salvo, agradece
--             (+reputacao com os civis) e vai embora
--   knock     batendo numa porta, "Abre! Por favor!" (barulho que atrai zumbis)
--   boarder   pregando tabuas numa janela de uma casa (barricada de verdade)
--   fight     dois civis brigando por comida
--   scavenger dois milicianos carregando suprimentos
--   raider    1-2 saqueadores rondando (so depois do dia dos saqueadores; nunca na zona de
--             graca)
--   gunshot   (sem gente) tiro ao longe: som real e barulho que atrai zumbis para la
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_Factions"
require "Remanescentes/Rem_Spawn"
require "Remanescentes/Rem_Barks"
require "Remanescentes/Rem_Movement"
require "Remanescentes/Rem_Timeline"
require "Remanescentes/Rem_Spatial"
local Rem = Remanescentes

local AM = Rem.module("Ambient", {
    CHECK_MS = 12000,         -- de quanto em quanto tempo tenta um evento
    START_DELAY_MS = 20000,   -- espera depois de carregar
    BASE_CHANCE = 70,         -- (%) por tentativa, com densidade 1 numa cidade
    MAX_TRANSIENTS = 6,       -- com densidade 1 numa cidade
    SPAWN_MIN = 26, SPAWN_MAX = 36,   -- fora da tela, mas perto o bastante para voce ver passarem
    CROSS_OFFSET = 8,         -- o trajeto passa a ate isso de voce
    DISMISS_FAR = 35,         -- chegou ao destino e esta a mais disso: some
    URBAN_RADIUS = 60,
    URBAN_FULL = 20,          -- predios em volta para "cidade cheia"
    URBAN_MIN = 0.3,
    KEEP_FREE = 2,            -- vagas de MaxActive reservadas aos grupos
    LIFETIME_HOURS = 3,
    HELP_TIMEOUT_MS = 180000,
    HELP_SAFE_RADIUS = 8,
    KNOCK_MS = { 60000, 120000 },
    KNOCK_EVERY_MS = 6000,
    BOARD_EVERY_MS = 6000,
    BOARD_PLANKS = 3,
    FIGHT_LOSE_BELOW = 0.5,
    GUNSHOT_DIST = { 40, 50 },
    GUNSHOT_SOUNDS = { "M9Shoot", "JS2000ShotgunShoot", "MSR788Shoot" },
    GUNSHOT_NOISE = 60,
    PRIORITY = 260,
    HELP_REP = 5,
})
local CFG = AM.CFG

-- pesos por tipo (multiplicados pela linha do tempo em AM.weights)
AM.WEIGHTS = { walker = 30, runner = 20, family = 12, help = 10, knock = 8, boarder = 6,
    fight = 5, scavenger = 10, raider = 12, gunshot = 10 }

Rem.BARKS.help = { urgent = true, n = 4, cd = 12000 }
Rem.BARKS.knock = { urgent = true, n = 3, cd = 7000 }
Rem.BARKS.fight = { urgent = true, n = 3, cd = 8000 }

-- ---------------------------------------------------------------- utilidades
local function chance(p) return ZombRand(100) < p end

function AM.transients()
    local list = {}
    for _, npc in pairs(Rem.active) do
        if npc.rec.transient then table.insert(list, npc) end
    end
    return list
end

local urbanCache, urbanAt = 1, -999999
function AM.urban(player, now)
    if now - urbanAt < 30000 then return urbanCache end
    urbanAt = now
    local n = 0
    local px, py = player:getX(), player:getY()
    local ok = pcall(function()
        local list = getWorld():getMetaGrid():getBuildings()
        for i = 0, list:size() - 1 do
            local d = list:get(i)
            if Rem.dist2(px, py, d:getX() + d:getW() / 2, d:getY() + d:getH() / 2) < CFG.URBAN_RADIUS then n = n + 1 end
        end
    end)
    urbanCache = ok and math.max(CFG.URBAN_MIN, math.min(1, n / CFG.URBAN_FULL)) or 1
    return urbanCache
end

-- Pesos do momento, pela linha do tempo.
function AM.weights(x, y)
    local TL = Rem.Timeline
    local chaos = TL.density()               -- 1 no inicio, cai com os dias
    local w = {}
    for k, v in pairs(AM.WEIGHTS) do w[k] = v end
    w.runner = w.runner * chaos
    w.knock = w.knock * chaos
    w.boarder = w.boarder * chaos
    w.fight = w.fight * chaos
    w.gunshot = w.gunshot * chaos
    w.scavenger = w.scavenger * TL.militiaFactor()
    w.raider = (TL.protects(x, y) and 0) or w.raider * TL.raiderFactor()
    return w
end

function AM.pickType(x, y)
    local w = AM.weights(x, y)
    local names, total = {}, 0
    for k, v in pairs(w) do
        if v > 0 then table.insert(names, k) total = total + v end
    end
    table.sort(names)
    local r = ZombRandFloat(0, total)
    for _, k in ipairs(names) do
        r = r - w[k]
        if r <= 0 then return k end
    end
    return names[#names]
end

local function goodOutdoor(sq)
    return sq ~= nil and not sq:getRoom() and sq:isFree(false)
end

-- Ponto de nascimento: anel a [minD, maxD] do jogador, de preferencia atras dele.
function AM.spawnPoint(player, minD, maxD)
    local cell = getCell()
    local fx, fy = 0, 1
    pcall(function() local f = player:getForwardDirection() fx, fy = f:getX(), f:getY() end)
    local base = math.atan2(-fy, -fx)        -- atras de voce
    for attempt = 1, 12 do
        -- primeiras tentativas: atras de voce (+-70 graus); depois, qualquer direcao
        local spread = (attempt <= 6) and 1.2 or math.pi
        local a = base + (ZombRand(0, 201) / 100 - 1) * spread
        local d = ZombRand(minD, maxD + 1)
        local x = math.floor(player:getX() + math.cos(a) * d)
        local y = math.floor(player:getY() + math.sin(a) * d)
        local sq = cell:getGridSquare(x, y, 0)
        if goodOutdoor(sq) then return sq end
    end
    return nil
end

-- Destino que cruza a sua area: passa perto de voce e segue para o outro lado.
function AM.crossDest(sx, sy, player)
    local px, py = player:getX(), player:getY()
    local dx, dy = px - sx, py - sy
    local off = CFG.CROSS_OFFSET
    return math.floor(px + dx + ZombRand(-off, off + 1)), math.floor(py + dy + ZombRand(-off, off + 1))
end

local function makePerson(sq, opts)
    opts.x, opts.y, opts.z = sq:getX() + 0.5, sq:getY() + 0.5, sq:getZ()
    local rec = Rem.newPerson(opts)
    rec.transient = true
    rec.ambient = opts.ambient
    rec.expiresAt = Rem.worldHours() + CFG.LIFETIME_HOURS
    rec.mode = "ambient"
    local npc = Rem.materialize(rec)
    if not npc then Rem.removePerson(rec.id) return nil end
    return npc
end

local function zombiesAt(x, y, n, spread)
    local outfits = (Rem.FACTIONS.civis and Rem.FACTIONS.civis.outfits) or { "Generic01" }
    for _ = 1, n do
        Rem.safe(function()
            addZombiesInOutfit(math.floor(x + ZombRand(-spread, spread + 1)), math.floor(y + ZombRand(-spread, spread + 1)), 0,
                1, Rem.pick(outfits), 50, false, false, false, false, false, false, 1.0)
        end)
    end
end

-- ---------------------------------------------------------------- tipos
AM.SPAWN = {}

function AM.SPAWN.walker(player, sq)
    local npc = makePerson(sq, { faction = "civis", ambient = "walker" })
    if not npc then return nil end
    npc.rec.destX, npc.rec.destY = AM.crossDest(sq:getX(), sq:getY(), player)
    npc.rec.gait = "walk"
    return { npc }
end

function AM.SPAWN.runner(player, sq)
    local npc = makePerson(sq, { faction = "civis", ambient = "runner", archetype = "furtivo", stealth = false })
    if not npc then return nil end
    npc.rec.destX, npc.rec.destY = AM.crossDest(sq:getX(), sq:getY(), player)
    npc.rec.gait = "run"
    -- zumbis atras dele (do lado de fora da sua area)
    local dx, dy = sq:getX() - player:getX(), sq:getY() - player:getY()
    local len = math.max(1, math.sqrt(dx * dx + dy * dy))
    zombiesAt(sq:getX() + dx / len * 4, sq:getY() + dy / len * 4, ZombRand(1, 4), 1)
    Rem.bark(npc, "help", true)
    return { npc }
end

function AM.SPAWN.family(player, sq)
    local leader = makePerson(sq, { faction = "civis", ambient = "family" })
    if not leader then return nil end
    leader.rec.destX, leader.rec.destY = AM.crossDest(sq:getX(), sq:getY(), player)
    leader.rec.gait = "walk"
    local list = { leader }
    for _ = 1, ZombRand(1, 4) do
        local m = makePerson(sq, { faction = "civis", ambient = "family" })
        if m then
            m.rec.followId = leader.rec.id
            table.insert(list, m)
        end
    end
    return list
end

function AM.SPAWN.help(player, sq)
    local npc = makePerson(sq, { faction = "civis", ambient = "help" })
    if not npc then return nil end
    npc.z:setHealth(npc.rec.maxHealth * 0.4)
    npc.rec.hp = npc.rec.maxHealth * 0.4
    npc.rec.helpSince = Rem.nowMs()
    npc.rec.spotX, npc.rec.spotY = sq:getX() + 0.5, sq:getY() + 0.5
    zombiesAt(sq:getX(), sq:getY(), ZombRand(2, 4), 4)
    Rem.bark(npc, "help", true)
    return { npc }
end

-- Porta externa de alguma casa perto do ponto.
local function doorNear(x, y, r)
    local cell = getCell()
    for dx = -r, r do
        for dy = -r, r do
            local sq = cell:getGridSquare(x + dx, y + dy, 0)
            if sq then
                local objs = sq:getObjects()
                for i = 0, objs:size() - 1 do
                    local o = objs:get(i)
                    if instanceof(o, "IsoDoor") and o:isExterior() and not o:IsOpen() then return o, sq end
                end
            end
        end
    end
    return nil
end

local function windowNear(x, y, r)
    local cell = getCell()
    for dx = -r, r do
        for dy = -r, r do
            local sq = cell:getGridSquare(x + dx, y + dy, 0)
            if sq then
                local objs = sq:getObjects()
                for i = 0, objs:size() - 1 do
                    local o = objs:get(i)
                    if instanceof(o, "IsoWindow") and o:isExterior() and not o:isBarricaded() and o:isBarricadeAllowed() then
                        return o, sq
                    end
                end
            end
        end
    end
    return nil
end

function AM.SPAWN.knock(player, sq)
    local door, dsq = doorNear(sq:getX(), sq:getY(), 10)
    if not door then return AM.SPAWN.walker(player, sq) end
    local npc = makePerson(sq, { faction = "civis", ambient = "knock" })
    if not npc then return nil end
    npc.rec.spotX, npc.rec.spotY = dsq:getX() + 0.5, dsq:getY() + 0.5
    npc.rec.knockUntil = Rem.nowMs() + ZombRand(CFG.KNOCK_MS[1], CFG.KNOCK_MS[2])
    return { npc }
end

function AM.SPAWN.boarder(player, sq)
    local win, wsq = windowNear(sq:getX(), sq:getY(), 12)
    if not win then return AM.SPAWN.walker(player, sq) end
    local npc = makePerson(sq, { faction = "civis", ambient = "boarder", archetype = "engenheiro" })
    if not npc then return nil end
    npc.rec.spotX, npc.rec.spotY = wsq:getX() + 0.5, wsq:getY() + 0.5
    npc.boardWindow = win
    npc.rec.planks = 0
    return { npc }
end

function AM.SPAWN.fight(player, sq)
    local a = makePerson(sq, { faction = "civis", ambient = "fight", archetype = "brigao" })
    if not a then return nil end
    local b = makePerson(sq, { faction = "civis", ambient = "fight", archetype = "brigao" })
    if not b then Rem.dismiss(a) return nil end
    a.rec.foeId, b.rec.foeId = b.rec.id, a.rec.id
    a.rec.temper, b.rec.temper = "agressivo", "agressivo"
    Rem.bark(a, "fight", true)
    return { a, b }
end

function AM.SPAWN.scavenger(player, sq)
    local list = {}
    local items = { "Base.TinnedBeans", "Base.WaterRationCan", "Base.Bandage", "Base.CannedChili" }
    for _ = 1, 2 do
        local m = makePerson(sq, { faction = "sobreviventes", ambient = "scavenger" })
        if m then
            m.rec.carry = { Rem.pick(items), Rem.pick(items) }
            table.insert(list, m)
        end
    end
    if #list == 0 then return nil end
    list[1].rec.destX, list[1].rec.destY = AM.crossDest(sq:getX(), sq:getY(), player)
    list[1].rec.gait = "walk"
    for i = 2, #list do list[i].rec.followId = list[1].rec.id end
    return list
end

function AM.SPAWN.raider(player, sq)
    local list = {}
    for _ = 1, ZombRand(1, 3) do
        local m = makePerson(sq, { faction = "saqueadores", ambient = "raider" })
        if m then table.insert(list, m) end
    end
    if #list == 0 then return nil end
    list[1].rec.destX, list[1].rec.destY = AM.crossDest(sq:getX(), sq:getY(), player)
    list[1].rec.gait = "walk"
    for i = 2, #list do list[i].rec.followId = list[1].rec.id end
    return list
end

function AM.gunshot(player)
    local sq = AM.spawnPoint(player, CFG.GUNSHOT_DIST[1], CFG.GUNSHOT_DIST[2])
    if not sq then return nil end
    local name = Rem.pick(CFG.GUNSHOT_SOUNDS)
    Rem.safe(function() getSoundManager():PlayWorldSound(name, sq, 0, 120, 1.0, false) end)
    Rem.safe(function() addSound(nil, sq:getX(), sq:getY(), 0, CFG.GUNSHOT_NOISE, CFG.GUNSHOT_NOISE) end)
    Rem.debug("tiro ao longe em " .. sq:getX() .. "," .. sq:getY())
    return {}
end

-- Tenta um evento agora. Retorna o tipo e a lista de NPCs (ou nil).
function AM.trySpawn(player, now, forced)
    local cap = Rem.cfg("MaxActive", 12)
    if Rem.activeCount >= cap - CFG.KEEP_FREE and forced ~= "gunshot" then return nil end
    if not forced then
        local density = Rem.Timeline.density() * AM.urban(player, now) * Rem.cfg("AmbientDensity", 100) / 100
        local maxT = math.max(1, math.floor(CFG.MAX_TRANSIENTS * density + 0.5))
        if #AM.transients() >= maxT then return nil end
        if not chance(CFG.BASE_CHANCE * density) then return nil end
    end
    local kind = forced
    if not kind then
        kind = AM.pickType(player:getX(), player:getY())
    end
    if kind == "gunshot" then return kind, AM.gunshot(player) end
    local sq = AM.spawnPoint(player, CFG.SPAWN_MIN, CFG.SPAWN_MAX)
    if not sq then return nil end
    if kind == "raider" and Rem.Timeline.protects(sq:getX(), sq:getY()) then kind = "walker" end
    local fn = AM.SPAWN[kind]
    if not fn then return nil end
    local list = fn(player, sq)
    if list then Rem.debug("passagem: " .. kind .. " (" .. #list .. ") em " .. sq:getX() .. "," .. sq:getY()) end
    return kind, list
end

-- ---------------------------------------------------------------- comportamento
local function leave(npc, player)
    local rec = npc.rec
    rec.ambient = "walker"
    rec.spotX, rec.spotY = nil, nil
    if player then
        local dx, dy = npc.z:getX() - player:getX(), npc.z:getY() - player:getY()
        local len = math.max(1, math.sqrt(dx * dx + dy * dy))
        rec.destX = math.floor(npc.z:getX() + dx / len * 45)
        rec.destY = math.floor(npc.z:getY() + dy / len * 45)
    end
    rec.gait = "walk"
end

local function zombieNear(npc, r)
    local list = Rem.zombiesNear(npc.z:getX(), npc.z:getY(), r)
    for i = 1, #list do
        if not Rem.active[list[i]] then return true end
    end
    return false
end

function AM.behavior(npc, ctx, now)
    local rec = npc.rec
    if rec.mode ~= "ambient" then return false end
    local player = ctx.player
    local kind = rec.ambient

    -- seguir o lider (familia, catadores, saqueadores)
    if rec.followId then
        local leader = nil
        for _, other in pairs(Rem.active) do if other.rec.id == rec.followId then leader = other end end
        if leader then
            local d = Rem.dist(npc.z, leader.z)
            if d > 2.5 then
                Rem.moveTo(npc, leader.z:getX(), leader.z:getY(), leader.z:getZ(), now, leader.running and "run" or "walk")
            else
                Rem.idle(npc, now)
            end
            return true
        end
        rec.followId = nil
        leave(npc, player)
    end

    if kind == "help" then
        local safe = not zombieNear(npc, CFG.HELP_SAFE_RADIUS)
        if safe and player and Rem.dist(npc.z, player) <= CFG.HELP_SAFE_RADIUS then
            Rem.bark(npc, "thanks", true)
            if Rem.changeRep then Rem.changeRep("f:civis", CFG.HELP_REP, "salvou um civil") end
            leave(npc, player)
            return true
        end
        if now - (rec.helpSince or now) > CFG.HELP_TIMEOUT_MS then leave(npc, player) return true end
        Rem.bark(npc, "help")
        Rem.hangAround(npc, rec.spotX, rec.spotY, 0, now, 0)
        return true
    end

    if kind == "knock" then
        if now > (rec.knockUntil or 0) then leave(npc, player) return true end
        if Rem.dist2(npc.z:getX(), npc.z:getY(), rec.spotX, rec.spotY) > 1.3 then
            Rem.moveTo(npc, rec.spotX, rec.spotY, 0, now, "walk")
            return true
        end
        Rem.stopMoving(npc)
        if now >= (npc.nextKnock or 0) then
            npc.nextKnock = now + CFG.KNOCK_EVERY_MS
            Rem.bark(npc, "knock", true)
            Rem.makeNoise(npc, 12)
        end
        return true
    end

    if kind == "boarder" then
        local win = npc.boardWindow
        if not win or rec.planks >= CFG.BOARD_PLANKS then leave(npc, player) return true end
        if Rem.dist2(npc.z:getX(), npc.z:getY(), rec.spotX, rec.spotY) > 1.5 then
            Rem.moveTo(npc, rec.spotX, rec.spotY, 0, now, "walk")
            return true
        end
        Rem.stopMoving(npc)
        if now >= (npc.nextPlank or 0) then
            npc.nextPlank = now + CFG.BOARD_EVERY_MS
            Rem.safe(function()
                -- prega por fora (ele esta do lado de fora)
                local outsideOwn = win:getSquare():getRoom() == nil
                local b = win:isBarricaded() and (win:getBarricadeOnSameSquare() or win:getBarricadeOnOppositeSquare())
                    or IsoBarricade.AddBarricadeToObject(win, not outsideOwn)
                if b and b:canAddPlank() then b:addPlank(nil, nil) end
            end)
            rec.planks = rec.planks + 1
            Rem.makeNoise(npc, 10)
        end
        return true
    end

    if kind == "fight" and rec.foeId then
        return false   -- a briga em si e combate normal; o fim e decidido em AM.resolveFights
    end

    -- andar ate o destino (walker, runner, lider)
    if rec.destX then
        local d = Rem.dist2(npc.z:getX(), npc.z:getY(), rec.destX, rec.destY)
        if d <= 2 then
            if not player or Rem.dist(npc.z, player) > CFG.DISMISS_FAR then
                Rem.dismiss(npc)
            else
                leave(npc, player)
            end
            return true
        end
        Rem.moveTo(npc, rec.destX, rec.destY, 0, now, rec.gait or "walk")
        return true
    end
    leave(npc, player)
    return true
end

-- Fim das brigas por comida. Fica fora dos comportamentos: com o rival por perto o cerebro
-- esta em combate e nunca chega aos comportamentos.
function AM.resolveFights(player)
    local byId = {}
    for _, npc in pairs(Rem.active) do byId[npc.rec.id] = npc end
    for _, npc in pairs(Rem.active) do
        local rec = npc.rec
        if rec.ambient == "fight" and rec.foeId then
            local foe = byId[rec.foeId]
            local lost = Rem.healthFraction(npc) < CFG.FIGHT_LOSE_BELOW
            if not foe or lost or Rem.healthFraction(foe) < CFG.FIGHT_LOSE_BELOW then
                rec.foeId, rec.temper = nil, "medroso"
                if foe then foe.rec.foeId, foe.rec.temper = nil, "medroso" end
                npc.lastAttacker = nil
                if foe then foe.lastAttacker = nil end
                Rem.cancelAttack(npc)
                if foe then Rem.cancelAttack(foe) end
                leave(npc, player)
                if foe then leave(foe, player) end
                if lost then rec.gait = "run" elseif foe then foe.rec.gait = "run" end
            end
        end
    end
end

-- ---------------------------------------------------------------- ciclo
local startedAt, nextCheck = nil, 0
function AM.tick(player, now)
    if not startedAt then startedAt = now end
    if now - startedAt < CFG.START_DELAY_MS or now < nextCheck then return end
    nextCheck = now + CFG.CHECK_MS
    if Rem.cfg("AmbientDensity", 100) <= 0 then return end
    AM.trySpawn(player, now)
end

-- Pessoas de passagem que ficaram "no papel" (save/load, saiu de cena) e ja passaram do
-- tempo delas somem.
function AM.cleanup()
    local hours = Rem.worldHours()
    local gone = {}
    for id, rec in pairs(Rem.getStore().people) do
        if rec.transient and not rec.onScene and hours >= (rec.expiresAt or 0) then table.insert(gone, id) end
    end
    for _, id in ipairs(gone) do Rem.removePerson(id) end
end

Rem.on("sceneUpdate", function(player, now)
    Rem.safe(AM.resolveFights, player)
    Rem.safe(AM.tick, player, now)
end)
Events.EveryTenMinutes.Add(function() Rem.safe(AM.cleanup) end)
Rem.registerBehavior({ name = "ambient", priority = CFG.PRIORITY, run = AM.behavior })

-- ferramentas de teste: forcar cada tipo
for _, kind in ipairs({ "walker", "runner", "family", "help", "knock", "boarder", "fight", "scavenger", "raider", "gunshot" }) do
    Rem.registerDebugOption("ContextMenu_Rem_Amb_" .. kind, function(x, y, z, player)
        local k, list = AM.trySpawn(player, Rem.nowMs(), kind)
        player:Say(tostring(k) .. ": " .. tostring(list and #list or 0))
    end)
end
