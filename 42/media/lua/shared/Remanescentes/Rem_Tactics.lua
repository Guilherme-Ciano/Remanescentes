-- Remanescentes - lutar ou fugir: cada sobrevivente avalia a situacao.
--
-- Antes a decisao vinha so da faccao (civil = "medroso" = sempre foge). Agora cada um
-- compara o perigo com o que acha que aguenta:
--   forca   = ele + amigos por perto (e voce, se estiver do lado dele)
--   nervo   = temperamento x coragem x vida x moral x experiencia (+ defendendo a casa)
--   aguenta = forca x nervo x ZOMBIES_PER_POWER
--   perigo  = zumbis em volta / atras dele; cada humano hostil vale HUMAN_THREAT zumbis
-- Luta se perigo <= aguenta; senao foge. Quem ja esta fugindo so volta quando o perigo cai
-- com folga (para nao ficar indeciso). Resultado: um civil comum encara um zumbi sozinho,
-- foge de tres; dois ou tres juntos se defendem; um covarde foge de tudo; perto de casa
-- todo mundo e mais valente. Contra VOCE a decisao continua sendo de Rem_Awareness/Mugging.
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_Factions"
local Rem = Remanescentes

local TC = Rem.module("Tactics", {
    ALLY_RADIUS = 7,
    ALLY_WEIGHT = 0.7,
    PLAYER_WEIGHT = 1.0,
    ZOMBIES_PER_POWER = 2.0,
    HUMAN_THREAT = 2.0,           -- um humano hostil vale isso em zumbis
    HOME_BONUS = 1.3,
    HOME_MARGIN = 4,
    LEVEL_BONUS = 0.1,
    HYSTERESIS = 1.3,             -- fugindo: so volta com o perigo abaixo de aguenta / isso
})
local CFG = TC.CFG

TC.TEMPER = { agressivo = 1.6, cauteloso = 1.1, defensivo = 1.2, medroso = 0.8 }

function TC.atHome(npc)
    local rec = npc.rec
    local g = rec.groupId and Rem.getStore().groups[rec.groupId]
    local h = g and g.home
    if not h or not h.x1 then return false end
    local m = CFG.HOME_MARGIN
    local x, y = npc.z:getX(), npc.z:getY()
    return x >= h.x1 - m and x <= h.x2 + m and y >= h.y1 - m and y <= h.y2 + m
end

function TC.nerve(npc)
    local rec = npc.rec
    local n = (TC.TEMPER[Rem.temperOf(npc)] or 1) * (0.4 + Rem.trait(rec, "coragem") / 10)
    n = n * (0.5 + 0.5 * math.max(0, math.min(1, Rem.healthFraction(npc))))
    n = n * (0.85 + (rec.moral or 50) / 100 * 0.3)
    n = n * (1 + (rec.level or 0) * CFG.LEVEL_BONUS)
    if TC.atHome(npc) then n = n * CFG.HOME_BONUS end
    if Rem.Traumas then n = n * Rem.Traumas.nerveMult(rec) end       -- panico (Rem_Traumas)
    return n
end

-- Ele mais os amigos que estao por perto e em condicao de ajudar.
function TC.power(npc)
    local p = 1
    for zb, other in pairs(Rem.active) do
        if other ~= npc and not other.fleeing and not Rem.npcsHostile(npc, other) and Rem.canAct(other)
            and not other.rec.captive and not other.rec.surrendered
            and Rem.isHostileToPlayer(other) == Rem.isHostileToPlayer(npc)
            and Rem.dist(npc.z, zb) <= CFG.ALLY_RADIUS then
            p = p + CFG.ALLY_WEIGHT
        end
    end
    local player = getPlayer()
    if player and not player:isDead() and Rem.isFriendly(npc) and Rem.dist(npc.z, player) <= CFG.ALLY_RADIUS then
        p = p + CFG.PLAYER_WEIGHT
    end
    return p
end

-- Quanto perigo ele ve agora (em "zumbis").
function TC.threat(npc, enemy)
    local t = math.max(npc.crowd or 0, Rem.huntersOf and Rem.huntersOf(npc) or 0)
    local humans = 0
    for zb, other in pairs(Rem.active) do
        if other ~= npc and Rem.npcsHostile(npc, other) and Rem.canAct(other) and not other.rec.surrendered
            and Rem.dist(npc.z, zb) <= CFG.ALLY_RADIUS + 3 then
            humans = humans + 1
        end
    end
    t = t + humans * CFG.HUMAN_THREAT
    if enemy and t < 1 then t = 1 end
    return t
end

function TC.capacity(npc)
    return TC.power(npc) * TC.nerve(npc) * CFG.ZOMBIES_PER_POWER
end

-- "fight" ou "flee" contra um zumbi ou outro sobrevivente.
function TC.decide(npc, enemy, d, now)
    local threat = TC.threat(npc, enemy)
    local cap = TC.capacity(npc)
    npc.tactic = { threat = threat, capacity = cap }
    -- seguidor nao abandona o jogador no meio da briga que ele comecou
    if npc.rec.mode == "follow" and Rem.playerFighting and Rem.playerFighting(now) then return "fight" end
    if npc.fleeing then
        return (threat <= cap / CFG.HYSTERESIS) and "fight" or "flee"
    end
    return (threat <= cap) and "fight" or "flee"
end
