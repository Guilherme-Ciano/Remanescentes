-- Remanescentes - conversas entre sobreviventes e comentarios sobre o que esta acontecendo.
--
-- Conversa (banter): de tempos em tempos, dois sobreviventes parados perto um do outro (e
--   perto de voce) trocam duas falas: um puxa o assunto, o outro responde. O assunto sai da
--   situacao: luto, fome, noite, zumbis por perto, o jeito de quem puxou (piada, fe,
--   resmungo), o que acham de voce, ou conversa fiada. Saqueadores tem os assuntos deles.
--   Textos: IGUI_Rem_Banter_<assunto>_<n>_<vez>.
-- Comentarios (context_*): seus aliados (ou quem estiver perto) reagem a noite caindo, ao
--   amanhecer, a chuva, a voce ferido, a uma horda, a uma sequencia de zumbis mortos por
--   voce; e um neutro reclama se voce apontar a arma para ele.
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_Barks"
require "Remanescentes/Rem_Movement"
require "Remanescentes/Rem_Spatial"
local Rem = Remanescentes

local BT = Rem.module("Banter", {
    CHECK_MS = 9000,          -- de quanto em quanto tempo tenta uma conversa
    CHANCE = 40,              -- (%) por tentativa
    PAIR_DIST = 5,            -- distancia maxima entre os dois
    PLAYER_DIST = 16,         -- so conversam se voce estiver perto para ouvir
    TURN_MS = 3200,           -- intervalo entre as falas
    NPC_CD_MS = 120000,       -- cada um so entra em outra conversa depois disso
    PRIORITY = 35,            -- comportamento: parar e olhar para o outro
    ZOMBIES_NEAR = 3,         -- zumbis a ZOMBIE_RADIUS para o assunto "zumbis"
    ZOMBIE_RADIUS = 18,
    REP_GOOD = 30, REP_BAD = -10,
    CONTEXT_MS = 3000,        -- checagem dos comentarios
    CONTEXT_DIST = 12,        -- quem comenta esta a ate isso de voce
    HURT_BELOW = 50,          -- sua saude geral abaixo disso
    HURT_CD_MS = 300000,
    HORDE_COUNT = 12, HORDE_RADIUS = 20, HORDE_CD_MS = 180000,
    CHEER_KILLS = 4, CHEER_WINDOW_MS = 20000, CHEER_CD_MS = 120000,
    AIM_DIST = 5, AIM_CD_MS = 30000,
    RAIN_CD_MS = 600000,
})
local CFG = BT.CFG

-- assunto = { n = quantas conversas, w = peso }
BT.TOPICS = {
    generic = { n = 6, w = 10 }, night = { n = 3, w = 14 }, hungry = { n = 3, w = 18 }, zombies = { n = 3, w = 16 },
    grief = { n = 2, w = 30 }, joke = { n = 3, w = 14 }, faith = { n = 2, w = 12 }, grumble = { n = 3, w = 12 },
    player_good = { n = 2, w = 10 }, player_bad = { n = 2, w = 10 }, raider = { n = 4, w = 10 },
    argue = { n = 3, w = 0 },       -- (so por evento: moradores da sua base brigando, Rem_BaseEvents)
    base_work = { n = 3, w = 14 },  -- moradores da sua base falando das obras
}
BT.TURNS = 2

for cat, n in pairs({ context_night = 3, context_dawn = 2, context_rain = 3, context_hurt = 3, context_horde = 3,
    context_cheer = 3, context_aim = 3 }) do
    Rem.BARKS[cat] = { urgent = true, n = n, cd = 0 }
end

BT.queue = BT.queue or {}

-- ---------------------------------------------------------------- quem pode conversar
local function isNight()
    local h = getGameTime():getTimeOfDay()
    return h >= 21 or h < 5
end

function BT.available(npc, now)
    if not Rem.canAct(npc) or npc.fleeing or npc.running or npc.rest == "sleep" then return false end
    if (npc.crowd or 0) > 0 or now < (npc.attackUntil or 0) or now < (npc.shootUntil or 0) then return false end
    if npc.talkingUntil and now < npc.talkingUntil then return false end
    if npc.awareP and npc.awareP.state and npc.awareP.state ~= "none" then return false end
    if npc.rec.surrendered or npc.rec.captive or npc.rec.disguised then return false end
    if Rem.Mugging and Rem.Mugging.of(npc) and Rem.Mugging.of(npc).stage ~= "truce" then return false end
    return now >= (npc.banterAt or 0)
end

local function countZombies(x, y, r)
    local n = 0
    local list = Rem.zombiesNear(x, y, r)
    for i = 1, #list do if not Rem.active[list[i]] then n = n + 1 end end
    return n
end

-- Assuntos possiveis para o par (a puxa a conversa).
function BT.topicsFor(a, b)
    local ra, rb = a.rec, b.rec
    if ra.faction == "saqueadores" then return { "raider" } end
    local list = { "generic" }
    local P = Rem.Persona
    local moodA = P and P.mood(ra, a) or "calmo"
    local moodB = P and P.mood(rb, b) or "calmo"
    if (moodA == "luto" and ra.griefFor) or (moodB == "luto" and rb.griefFor) then table.insert(list, "grief") end
    if moodA == "faminto" or moodB == "faminto" then table.insert(list, "hungry") end
    if isNight() then table.insert(list, "night") end
    if countZombies(a.z:getX(), a.z:getY(), CFG.ZOMBIE_RADIUS) >= CFG.ZOMBIES_NEAR then table.insert(list, "zombies") end
    if ra.quirk == "piadista" then table.insert(list, "joke") end
    if ra.quirk == "religioso" then table.insert(list, "faith") end
    if ra.quirk == "ranzinza" then table.insert(list, "grumble") end
    if Rem.PlayerBase and Rem.PlayerBase.isMember(ra) then table.insert(list, "base_work") end
    if ra.faction ~= "aliados" and Rem.repOf then
        local rep = Rem.repOf(ra)
        if rep >= CFG.REP_GOOD then table.insert(list, "player_good") end
        if rep <= CFG.REP_BAD then table.insert(list, "player_bad") end
    end
    return list
end

function BT.pickTopic(a, b)
    local list = BT.topicsFor(a, b)
    local total = 0
    for _, t in ipairs(list) do total = total + BT.TOPICS[t].w end
    local r = ZombRandFloat(0, total)
    for _, t in ipairs(list) do
        r = r - BT.TOPICS[t].w
        if r <= 0 then return t end
    end
    return list[#list]
end

-- ---------------------------------------------------------------- conversa
-- Agenda as falas de a e b. Retorna o assunto.
function BT.start(a, b, now, topic)
    topic = topic or BT.pickTopic(a, b)
    local def = BT.TOPICS[topic]
    local i = ZombRand(1, def.n + 1)
    local name = a.rec.griefFor or b.rec.griefFor or "?"
    for turn = 1, BT.TURNS do
        local who = (turn % 2 == 1) and a or b
        local other = (who == a) and b or a
        table.insert(BT.queue, { at = now + (turn - 1) * CFG.TURN_MS, id = who.rec.id, to = other.rec.id,
            key = "IGUI_Rem_Banter_" .. topic .. "_" .. i .. "_" .. turn, arg = name })
    end
    local busy = now + BT.TURNS * CFG.TURN_MS
    a.banterUntil, b.banterUntil = busy, busy
    a.banterWith, b.banterWith = b, a
    a.banterAt, b.banterAt = now + CFG.NPC_CD_MS, now + CFG.NPC_CD_MS
    Rem.debug("conversa (" .. topic .. "): " .. tostring(a.rec.name) .. " e " .. tostring(b.rec.name))
    Rem.emit("banterStarted", a, b, topic)
    return topic
end

local function byId(id)
    for _, npc in pairs(Rem.active) do if npc.rec.id == id then return npc end end
    return nil
end

-- Fala o que estiver na hora. A conversa para se um dos dois sair de cena ou entrar em briga.
function BT.flush(now)
    local keep = {}
    for _, e in ipairs(BT.queue) do
        if now < e.at then
            table.insert(keep, e)
        else
            local npc, other = byId(e.id), byId(e.to)
            if npc and other and Rem.canAct(npc) and (npc.crowd or 0) == 0 and not npc.fleeing then
                Rem.speak(npc, getText(e.key, e.arg))
            end
        end
    end
    BT.queue = keep
end

function BT.findPair(player, now)
    local list = {}
    for _, npc in pairs(Rem.active) do
        if Rem.dist(npc.z, player) <= CFG.PLAYER_DIST and BT.available(npc, now) then table.insert(list, npc) end
    end
    table.sort(list, function(x, y) return tostring(x.rec.id) < tostring(y.rec.id) end)
    if #list < 2 then return nil end
    local start = ZombRand(#list) + 1
    for k = 0, #list - 1 do
        local a = list[(start + k - 1) % #list + 1]
        for _, b in ipairs(list) do
            if a ~= b and not Rem.npcsHostile(a, b) and Rem.dist(a.z, b.z) <= CFG.PAIR_DIST
                and math.floor(a.z:getZ()) == math.floor(b.z:getZ())
                and (a.rec.faction == "saqueadores") == (b.rec.faction == "saqueadores") then
                return a, b
            end
        end
    end
    return nil
end

local nextCheck = 0
function BT.tick(player, now)
    BT.flush(now)
    if now < nextCheck then return end
    nextCheck = now + CFG.CHECK_MS
    if not Rem.cfg("Barks", true) or ZombRand(100) >= CFG.CHANCE then return end
    local a, b = BT.findPair(player, now)
    if a then BT.start(a, b, now) end
end

-- Enquanto conversam, param e se olham.
function BT.behavior(npc, ctx, now)
    if not npc.banterUntil then return false end
    local other = npc.banterWith
    if now > npc.banterUntil or not other or not Rem.active[other.z] then
        npc.banterUntil, npc.banterWith = nil, nil
        return false
    end
    Rem.stopMoving(npc)
    Rem.safe(function() npc.z:faceThisObject(other.z) end)
    return true
end
Rem.registerBehavior({ name = "banter", priority = CFG.PRIORITY, run = BT.behavior })

-- ---------------------------------------------------------------- comentarios
BT.state = BT.state or {}   -- ultimas vezes (runtime)

-- Quem comenta: o aliado mais perto; sem aliado (anyone=true), qualquer amigo perto.
function BT.speaker(player, anyone)
    local best, bestD, ally = nil, CFG.CONTEXT_DIST, false
    for _, npc in pairs(Rem.active) do
        local isAlly = npc.rec.faction == "aliados"
        if (isAlly or anyone) and Rem.isFriendly(npc) and Rem.canAct(npc) and not npc.rec.surrendered
            and not npc.rec.captive and not npc.rec.disguised and npc.rest ~= "sleep" then
            local d = Rem.dist(npc.z, player)
            if d <= CFG.CONTEXT_DIST and ((isAlly and not ally) or (isAlly == ally and d < bestD)) then
                best, bestD, ally = npc, d, isAlly
            end
        end
    end
    return best
end

function BT.comment(player, category, anyone)
    local npc = BT.speaker(player, anyone)
    if not npc then return nil end
    Rem.bark(npc, category)
    return npc
end

local function due(name, now, cd)
    if now - (BT.state[name] or -cd) < cd then return false end
    BT.state[name] = now
    return true
end

function BT.context(player, now)
    local st = BT.state
    -- chuva comecou
    local raining = false
    pcall(function() raining = RainManager.isRaining() end)
    if raining and st.raining == false and due("rain", now, CFG.RAIN_CD_MS) then BT.comment(player, "context_rain", true) end
    st.raining = raining
    -- voce esta mal
    local health = 100
    pcall(function() health = player:getBodyDamage():getOverallBodyHealth() end)
    if health < CFG.HURT_BELOW and due("hurt", now, CFG.HURT_CD_MS) then BT.comment(player, "context_hurt", false) end
    -- horda
    if countZombies(player:getX(), player:getY(), CFG.HORDE_RADIUS) >= CFG.HORDE_COUNT and due("horde", now, CFG.HORDE_CD_MS) then
        BT.comment(player, "context_horde", true)
    end
    -- apontando a arma para um neutro
    local aiming = false
    pcall(function() aiming = player:isAiming() and player:getPrimaryHandItem() ~= nil end)
    if aiming then
        for _, npc in pairs(Rem.active) do
            if npc.rec.faction ~= "aliados" and Rem.isFriendly(npc) and Rem.canAct(npc)
                and Rem.dist(npc.z, player) <= CFG.AIM_DIST and Rem.isFacing(player, npc.z, 0.6)
                and now - (npc.aimWarnAt or -CFG.AIM_CD_MS) >= CFG.AIM_CD_MS then
                npc.aimWarnAt = now
                Rem.bark(npc, "context_aim")
                Rem.safe(function() npc.z:faceThisObject(player) end)
                break
            end
        end
    end
end

-- noite caindo e amanhecer
Rem.on("worldHour", function()
    local player = getPlayer()
    if not player then return end
    local h = math.floor(getGameTime():getTimeOfDay())   -- (o evento passa a idade do mundo, nao a hora do dia)
    local now = Rem.nowMs()
    if h == 21 and due("night", now, 600000) then BT.comment(player, "context_night", false)
    elseif h == 6 and due("dawn", now, 600000) then BT.comment(player, "context_dawn", false) end
end)

-- sequencia de zumbis mortos por voce
BT.kills = BT.kills or {}
Events.OnZombieDead.Add(function(zombie)
    if Rem.active[zombie] then return end
    local by = nil
    pcall(function() by = zombie:getAttackedBy() end)
    if not by or not Rem.isPlayerObj(by) then return end
    local now = Rem.nowMs()
    local keep = { now }
    for _, t in ipairs(BT.kills) do if now - t < CFG.CHEER_WINDOW_MS then table.insert(keep, t) end end
    BT.kills = keep
    if #keep >= CFG.CHEER_KILLS and due("cheer", now, CFG.CHEER_CD_MS) then
        BT.kills = {}
        local player = getPlayer()
        if player then BT.comment(player, "context_cheer", false) end
    end
end)

local nextContext = 0
Rem.on("sceneUpdate", function(player, now)
    Rem.safe(BT.tick, player, now)
    if now >= nextContext then
        nextContext = now + CFG.CONTEXT_MS
        Rem.safe(BT.context, player, now)
    end
end)
