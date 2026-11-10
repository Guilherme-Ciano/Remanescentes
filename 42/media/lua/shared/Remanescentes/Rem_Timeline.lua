-- Remanescentes - Fase C1/C2: linha do tempo do apocalipse e zona de graca.
--
-- O mundo nao comeca no "mes 3". O dia do apocalipse conta a partir do inicio do jogo,
-- mais os meses do sandbox vanilla "Meses desde o apocalipse" (TimeSinceApo), e anda no
-- ritmo do sandbox "Ritmo do colapso".
--   dias 0-3  : caos civil. Muita gente comum na rua, fugindo; milicias ainda se formando;
--               NENHUM saqueador organizado (ate o dia do sandbox "RaiderStartDay").
--   dias 4-14 : grupos se organizam; os primeiros saqueadores aparecem e crescem aos poucos.
--   dia 15+   : escassez. Menos gente na rua, saqueadores comuns.
-- Zona de graca: nos primeiros GRACE_DAYS, nenhum grupo hostil nasce a menos de
-- GRACE_RADIUS do ponto onde voce comecou.
require "Remanescentes/Rem_Core"
local Rem = Remanescentes

local TL = Rem.module("Timeline", {
    RAMP_DAYS = 10,           -- saqueadores vao de 0 a 100% nesse tempo depois do dia de inicio
    MILITIA_DAYS = 3,         -- milicias chegam a 100% nesse tempo
    MILITIA_MIN = 0.3,
    DENSITY_MIN = 0.35,       -- gente na rua no fim (fracao do inicio)
    DENSITY_FALL_DAYS = 40,   -- quanto tempo leva para cair ate o minimo
    GRACE_DAYS = 3,
    GRACE_RADIUS = 150,
    PACE = { 0.5, 1.0, 2.0 }, -- Ritmo do colapso: lento, normal, rapido
    LATE_RAIDER_CHANCE = 40,  -- (%) por dia, com saqueadores a 100%, de nascer um grupo novo
    EXTRA_GROUPS = 4,         -- alem do WorldGroups, so para esses grupos novos
})
local CFG = TL.CFG

local function store()
    local s = Rem.getStore()
    s.timeline = s.timeline or {}
    return s.timeline
end

-- Marca o inicio (uma vez por save): hora e lugar onde o jogador comecou.
function TL.markStart(player)
    local t = store()
    if t.startHours then return end
    t.startHours = Rem.worldHours()
    if player then t.startX, t.startY = player:getX(), player:getY() end
end

function TL.pace()
    return CFG.PACE[Rem.cfg("CollapsePace", 2)] or 1.0
end

-- Dia do apocalipse (0 = primeiro dia).
function TL.day()
    local t = store()
    local hours = Rem.worldHours() - (t.startHours or Rem.worldHours())
    local months = math.max(0, (SandboxVars and SandboxVars.TimeSinceApo or 1) - 1)
    return math.max(0, hours / 24 * TL.pace() + months * 30)
end

-- 0..1: quanto os saqueadores ja existem.
function TL.raiderFactor()
    local start = Rem.cfg("RaiderStartDay", 4)
    local d = TL.day()
    if d < start then return 0 end
    return math.min(1, (d - start) / CFG.RAMP_DAYS + 0.1)
end

function TL.militiaFactor()
    return math.max(CFG.MILITIA_MIN, math.min(1, TL.day() / CFG.MILITIA_DAYS))
end

-- 0..1: quanta gente comum ainda anda pela rua (populacao de passagem).
function TL.density()
    return math.max(CFG.DENSITY_MIN, 1 - TL.day() / CFG.DENSITY_FALL_DAYS)
end

function TL.inGrace()
    return TL.day() < CFG.GRACE_DAYS
end

-- Ponto (x, y) esta na zona de graca agora?
function TL.protects(x, y)
    if not TL.inGrace() then return false end
    local t = store()
    if not t.startX then return false end
    return Rem.dist2(x, y, t.startX, t.startY) < CFG.GRACE_RADIUS
end

function TL.isHostileFaction(faction)
    local def = Rem.FACTIONS and Rem.FACTIONS[faction]
    return def ~= nil and def.hostileToPlayer == true
end

Rem.on("worldSeeded", function(player) TL.markStart(player) end)
