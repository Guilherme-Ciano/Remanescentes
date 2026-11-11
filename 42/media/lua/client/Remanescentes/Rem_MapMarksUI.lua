-- Remanescentes - desenha no mapa do mundo as marcacoes feitas pelos sobreviventes
-- (shared/Remanescentes/Rem_MapMarks.lua). Os simbolos do mapa so existem quando a janela
-- do mapa ja foi criada (ISWorldMap_instance); entao desenha ao abrir o mapa e, se ele ja
-- existir, na hora em que a marcacao e feita.
require "ISUI/Maps/ISWorldMap"
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_MapMarks"
local Rem = Remanescentes
local MM = Rem.MapMarks

function MM.apply()
    local w = ISWorldMap_instance
    if not w or not w.mapAPI then return 0 end
    local api = w.mapAPI:getSymbolsAPIv2()
    local done = 0
    local C = MM.CFG
    for _, m in ipairs(MM.pending()) do
        local ok = pcall(function()
            if m.circle then
                local c = api:addTexture("Circle", m.x, m.y)
                c:setRGBA(m.r, m.g, m.b, 1.0)
                c:setAnchor(0.5, 0.5)
                c:setScale(C.CIRCLE_SCALE)
            end
            local s = api:addTexture(m.symbol, m.x, m.y)
            s:setRGBA(m.r, m.g, m.b, 1.0)
            s:setAnchor(0.5, 0.5)
            s:setScale(C.SYMBOL_SCALE)
            if m.text then
                local t = api:addUntranslatedText(m.text, api:getDefaultTextLayerID(), m.x, m.y + C.NOTE_OFFSET_Y)
                t:setRGBA(m.r, m.g, m.b, 1.0)
                t:setAnchor(0.5, 0.5)
                t:setScale(C.TEXT_SCALE)
            end
        end)
        if ok then
            m.applied = true
            m.drawnX, m.drawnY = m.x, m.y
            done = done + 1
        else
            Rem.log("ERRO: nao consegui desenhar a marcacao " .. tostring(m.id) .. " no mapa")
            m.applied = true   -- nao tenta para sempre
        end
    end
    return done
end

-- Marcacoes desenhadas por versoes antigas (enormes e umas por cima das outras): apaga os
-- simbolos que o mod desenhou (no ponto da marcacao: circulo, simbolo e a anotacao logo
-- acima) e desenha de novo, no tamanho e na vaga certos. Uma vez por versao do desenho.
function MM.relayout()
    local store = Rem.getStore()
    if store.mapMarksScale == MM.CFG.SCALE_VERSION then return 0 end
    local w = ISWorldMap_instance
    if not w or not w.mapAPI then return 0 end
    local api = w.mapAPI:getSymbolsAPIv2()
    local marks = store.mapMarks or {}
    local removed = 0
    for i = api:getSymbolCount() - 1, 0, -1 do
        local sym = api:getSymbolByIndex(i)
        local x, y = sym:getWorldX(), sym:getWorldY()
        for _, m in ipairs(marks) do
            local mx, my = m.drawnX or m.x, m.drawnY or m.y
            if m.applied and math.abs(x - mx) < 0.6 then
                local same = sym:isTexture() and math.abs(y - my) < 0.6
                local note = sym:isText() and y < my and my - y < 20
                if same or note then
                    api:removeSymbolByIndex(i)
                    removed = removed + 1
                    break
                end
            end
        end
    end
    -- refaz as vagas na ordem em que foram marcadas, e redesenha
    for _, m in ipairs(marks) do m.slot = nil end
    for _, m in ipairs(marks) do
        m.bx, m.by = m.bx or m.x, m.by or m.y
        if m.wantCircle == nil then m.wantCircle = m.circle ~= false end
        MM.place(m)
        m.applied = false
    end
    store.mapMarksScale = MM.CFG.SCALE_VERSION
    if removed > 0 then Rem.debug("mapa: " .. removed .. " simbolos antigos refeitos") end
    return removed
end
MM.rescale = MM.relayout   -- (nome antigo)

-- ao abrir o mapa
local showWorldMap = ISWorldMap.ShowWorldMap
ISWorldMap.ShowWorldMap = function(...)
    local r = showWorldMap(...)
    Rem.safe(MM.relayout)
    Rem.safe(MM.apply)
    return r
end

-- mapa ja criado: desenha na hora
Rem.on("mapMarked", function() Rem.safe(MM.apply) end)
