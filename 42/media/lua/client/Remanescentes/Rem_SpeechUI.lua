-- Remanescentes - desenha as falas dos sobreviventes sobre a cabeca deles.
--
-- Por que nao usar o balao do jogo: IsoGameCharacter.Say() comeca com
-- "if (isZombie()) return;" e o corpo dos NPCs e um IsoZombie, entao nenhuma fala
-- aparecia. Rem.speak (Rem_Core) guarda as falas em npc.speech; aqui elas sao desenhadas
-- a cada quadro, antes das janelas (OnPreUIDraw), com contorno escuro e na cor da faccao.
require "Remanescentes/Rem_Core"
local Rem = Remanescentes

local SP = Rem.module("SpeechUI", {
    MAX_DIST = 30,        -- tiles: mais longe que isso nao desenha
    HEAD_PX = 125,        -- altura da cabeca em pixels com zoom 1
    FADE_MS = 600,        -- some aos poucos no fim
    LINE_GAP = 2,
})
local CFG = SP.CFG

local function tint(faction)
    local c = Rem.MapMarks and Rem.MapMarks.COLORS and Rem.MapMarks.COLORS[faction]
    if not c then return 1, 1, 1 end
    return c[1] * 0.35 + 0.65, c[2] * 0.35 + 0.65, c[3] * 0.35 + 0.65
end

local function visible(z)
    local a = 1
    pcall(function() a = z:getAlpha(0) end)
    return a > 0.05
end

-- Linhas a desenhar para um NPC: { text, r, g, b, a } (mais antiga primeiro).
function SP.linesFor(npc, now)
    local out = {}
    for _, l in ipairs(Rem.speechOf(npc, now)) do
        local left = l.untilMs - now
        local a = (left < CFG.FADE_MS) and math.max(0, left / CFG.FADE_MS) or 1
        local r, g, b = l.r, l.g, l.b
        if not r then r, g, b = tint(npc.rec and npc.rec.faction) end
        table.insert(out, { text = l.text, r = r, g = g, b = b, a = a })
    end
    return out
end

function SP.draw()
    local player = getPlayer()
    if not player then return end
    local now = Rem.nowMs()
    local tm = getTextManager()
    local fh = tm:getFontHeight(UIFont.Medium)
    local zoom = getCore():getZoom(0)
    for _, npc in pairs(Rem.active) do
        if npc.speech and #npc.speech > 0 and Rem.dist(npc.z, player) <= CFG.MAX_DIST and visible(npc.z) then
            local lines = SP.linesFor(npc, now)
            if #lines > 0 then
                local x, y, z = npc.z:getX(), npc.z:getY(), npc.z:getZ()
                local sx = isoToScreenX(0, x, y, z)
                local sy = isoToScreenY(0, x, y, z) - CFG.HEAD_PX / zoom
                for i = #lines, 1, -1 do
                    local l = lines[i]
                    sy = sy - fh - CFG.LINE_GAP
                    for _, o in ipairs({ { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }) do
                        tm:DrawStringCentre(UIFont.Medium, sx + o[1], sy + o[2], l.text, 0, 0, 0, l.a * 0.8)
                    end
                    tm:DrawStringCentre(UIFont.Medium, sx, sy, l.text, l.r, l.g, l.b, l.a)
                end
            end
        end
    end
end

-- Se der erro, registra e desliga depois de alguns quadros (nao enche o console a 60 fps).
SP.failures = 0
Events.OnPreUIDraw.Add(function()
    if SP.failures >= 5 then return end
    local ok, err = pcall(SP.draw)
    if not ok then
        SP.failures = SP.failures + 1
        Rem.log("ERRO ao desenhar falas: " .. tostring(err) .. (SP.failures >= 5 and " (desligado)" or ""))
    end
end)
