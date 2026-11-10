-- Remanescentes - desenha no mapa do mundo as marcacoes feitas pelos sobreviventes
-- (shared/Remanescentes/Rem_MapMarks.lua). Os simbolos do mapa so existem quando a janela
-- do mapa ja foi criada (ISWorldMap_instance); entao desenha ao abrir o mapa e, se ele ja
-- existir, na hora em que a marcacao e feita.
require "ISUI/Maps/ISWorldMap"
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_MapMarks"
local Rem = Remanescentes
local MM = Rem.MapMarks

local function scale() return (ISMap and ISMap.SCALE) or 0.666 end

function MM.apply()
    local w = ISWorldMap_instance
    if not w or not w.mapAPI then return 0 end
    local api = w.mapAPI:getSymbolsAPIv2()
    local done = 0
    for _, m in ipairs(MM.pending()) do
        local ok = pcall(function()
            if m.circle then
                local c = api:addTexture("Circle", m.x, m.y)
                c:setRGBA(m.r, m.g, m.b, 1.0)
                c:setAnchor(0.5, 0.5)
                c:setScale(scale() * MM.CFG.CIRCLE_SCALE)
            end
            local s = api:addTexture(m.symbol, m.x, m.y)
            s:setRGBA(m.r, m.g, m.b, 1.0)
            s:setAnchor(0.5, 0.5)
            s:setScale(scale())
            if m.text then
                local t = api:addUntranslatedText(m.text, api:getDefaultTextLayerID(), m.x, m.y + MM.CFG.NOTE_OFFSET_Y)
                t:setRGBA(m.r, m.g, m.b, 1.0)
                t:setAnchor(0.5, 0.5)
                t:setScale(scale())
            end
        end)
        if ok then
            m.applied = true
            done = done + 1
        else
            Rem.log("ERRO: nao consegui desenhar a marcacao " .. tostring(m.id) .. " no mapa")
            m.applied = true   -- nao tenta para sempre
        end
    end
    return done
end

-- ao abrir o mapa
local showWorldMap = ISWorldMap.ShowWorldMap
ISWorldMap.ShowWorldMap = function(...)
    local r = showWorldMap(...)
    Rem.safe(MM.apply)
    return r
end

-- mapa ja criado: desenha na hora
Rem.on("mapMarked", function() Rem.safe(MM.apply) end)
