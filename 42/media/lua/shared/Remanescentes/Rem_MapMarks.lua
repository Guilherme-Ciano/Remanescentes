-- Remanescentes - marcacoes no mapa do jogador (o NPC "marca com caneta" o que te conta).
--
-- Quando um sobrevivente revela onde fica outro grupo, te da uma missao com lugar, ou te
-- abriga, ele marca no seu mapa: circulo na cor da faccao, o simbolo do lugar e uma anotacao
-- escrita. As marcacoes ficam no save (store.mapMarks) e sao desenhadas no mapa do mundo
-- assim que ele existir (client/Remanescentes/Rem_MapMarksUI.lua). Cada lugar e marcado uma
-- vez so (id); depois de desenhada, a marcacao e sua (pode apagar com a borracha do mapa).
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_Barks"
local Rem = Remanescentes

local MM = Rem.module("MapMarks", {
    CIRCLE_SCALE = 2.2,
    NOTE_OFFSET_Y = -14,      -- anotacao escrita um pouco acima do lugar
})

-- cor (caneta) por faccao / tipo de marcacao
MM.COLORS = {
    civis = { 0.1, 0.6, 0.15 }, sobreviventes = { 0.1, 0.3, 0.85 }, saqueadores = { 0.85, 0.1, 0.1 },
    seita = { 0.55, 0.15, 0.7 }, errantes = { 0.85, 0.7, 0.05 }, aliados = { 0.1, 0.6, 0.6 },
    quest = { 0.95, 0.5, 0.05 }, shelter = { 0.1, 0.6, 0.15 },
}
MM.SYMBOLS = { saqueadores = "Skull", default = "House" }

Rem.BARKS.mark_map = { urgent = true, n = 3, cd = 0 }

local function marks()
    local s = Rem.getStore()
    s.mapMarks = s.mapMarks or {}
    return s.mapMarks
end

function MM.find(id)
    for _, m in ipairs(marks()) do if m.id == id then return m end end
    return nil
end

-- Adiciona uma marcacao (uma vez por id). m = { id, x, y, symbol, color = {r,g,b}, text, circle }
function MM.add(m, npc)
    if not m.id or MM.find(m.id) then return false end
    local c = m.color or MM.COLORS.quest
    table.insert(marks(), { id = m.id, x = m.x, y = m.y, symbol = m.symbol or "Asterisk",
        r = c[1], g = c[2], b = c[3], text = m.text, circle = m.circle ~= false, applied = false })
    if npc then Rem.bark(npc, "mark_map", true) end
    local player = getPlayer()
    if player then
        Rem.safe(function() player:playSoundLocal("MapAddSymbol") end)
        Rem.safe(function() HaloTextHelper.addText(player, getText("IGUI_Rem_Map_marked")) end)
    end
    Rem.emit("mapMarked", m)
    return true
end

function MM.pending()
    local out = {}
    for _, m in ipairs(marks()) do if not m.applied then table.insert(out, m) end end
    return out
end

-- ---------------------------------------------------------------- atalhos usados pela interacao
function MM.markGroup(g, npc)
    if not g or not g.home then return false end
    local fname = getText("IGUI_Rem_Faction_" .. tostring(g.faction))
    local who = npc and npc.rec and npc.rec.name or "?"
    return MM.add({ id = "group:" .. g.id, x = g.home.x, y = g.home.y,
        symbol = MM.SYMBOLS[g.faction] or MM.SYMBOLS.default,
        color = MM.COLORS[g.faction] or MM.COLORS.quest,
        text = getText("IGUI_Rem_Map_group", fname, who) }, npc)
end

function MM.markQuest(q, npc)
    if not q or not q.x then return false end
    local symbol = (q.kind == "lost") and "Question" or "Target"
    return MM.add({ id = "quest:" .. q.group .. ":" .. q.kind .. ":" .. tostring(q.expiresAt), x = q.x, y = q.y,
        symbol = symbol, color = MM.COLORS.quest,
        text = getText("IGUI_Rem_Map_quest_" .. q.kind, npc and npc.rec.name or "?") }, npc)
end

function MM.markShelter(g, npc)
    if not g or not g.home then return false end
    return MM.add({ id = "shelter:" .. g.id, x = g.home.x, y = g.home.y, symbol = "House",
        color = MM.COLORS.shelter, text = getText("IGUI_Rem_Map_shelter") }, npc)
end
