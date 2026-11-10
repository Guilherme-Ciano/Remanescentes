-- Marcacoes no mapa: o NPC marca com "caneta" o que te conta (grupo, missao, abrigo).
local T = ...
local Rem = Remanescentes
local check, realPrint = T.check, T.print
local IA, MM = Rem.Interact, Rem.MapMarks

local function fresh()
    Rem.dismissAll(); T.clearZombies(); Rem.hunting = {}
    Rem.getStore().quests = {}
    Rem.getStore().knownGroups = {}
    Rem.getStore().mapMarks = {}
    T.localSounds = {}
end

-- mock da API de simbolos do mapa do mundo
local calls = {}
local function symbol(kind, name, x, y)
    local s = { kind = kind, name = name, x = x, y = y }
    function s:setRGBA(r, g, b, a) self.r, self.g, self.b = r, g, b end
    function s:setAnchor() end
    function s:setScale(v) self.scale = v end
    table.insert(calls, s)
    return s
end
local symbolsAPI = {
    addTexture = function(_, name, x, y) return symbol("tex", name, x, y) end,
    addUntranslatedText = function(_, text, layer, x, y) return symbol("text", text, x, y) end,
    getDefaultTextLayerID = function() return "default" end,
}
ISMap = { SCALE = 0.666 }
ISWorldMap = { ShowWorldMap = function()
    ISWorldMap_instance = ISWorldMap_instance or { mapAPI = { getSymbolsAPIv2 = function() return symbolsAPI end } }
end }
ISWorldMap_instance = nil
require "Remanescentes/Rem_MapMarksUI"

realPrint("130) Marcar no mapa o grupo revelado")
fresh()
local player = T.player
player.x, player.y = 32000, 32000
local teller = Rem.spawn(32001, 32000, 0, { faction = "civis", mode = "stay" })
local mil = Rem.createGroup("sobreviventes", 32300, 32000, nil, 2)
local raid = Rem.createGroup("saqueadores", 31700, 32000, nil, 2)
Rem.changeRep("f:civis", 100, "teste")
local l = IA.groupInfo(teller, player)
local marks = Rem.getStore().mapMarks
check(#marks == 1 and marks[1].id:find("group:") ~= nil and (marks[1].x == raid.home.x or marks[1].x == mil.home.x), "o local do grupo revelado vai para o seu mapa")
local m1 = marks[1]
local g1 = (m1.x == mil.home.x) and mil or raid
local col = MM.COLORS[g1.faction]
check(m1.r == col[1] and m1.g == col[2] and m1.b == col[3], "na cor da faccao (" .. g1.faction .. ")")
check(m1.symbol == (MM.SYMBOLS[g1.faction] or "House") and m1.text and m1.text:find("IGUI_Rem_Map_group"), "simbolo e anotacao escrita")
check(T.saidPrefix(teller.z, "IGUI_Rem_Bark_mark_map_") and T.localSounds[#T.localSounds] == "MapAddSymbol", "ele avisa e voce ouve a caneta no mapa")
IA.groupInfo(teller, player)
check(#marks == 2 and marks[2].id ~= marks[1].id, "o segundo grupo contado tambem e marcado")
MM.markGroup(g1, teller)
check(#marks == 2, "o mesmo lugar nao e marcado duas vezes")

realPrint("131) Missao e abrigo marcados")
fresh()
local def = T.addBuilding(33001, 33000, 33000, 10, 8)
for i = 33000, 33009 do for j = 33000, 33007 do T.indoorSq[i .. "," .. j] = true; T.sqBuilding[i .. "," .. j] = def end end
T.addObject(33002, 33002, 0, "container", { type = "fridge" })
T.addBuilding(33002, 33150, 33000, 8, 8)
local g = Rem.createGroup("civis", 33005, 33004, "33001", 3, def)
g.supplies = 50
player.x, player.y = 33005, 33010
Rem.emit("sceneUpdate", player, T.clock)
local asker = Rem.materialize(Rem.getPerson(g.members[1]))
local q
for _ = 1, 20 do
    Rem.getStore().quests = {}
    q = IA.offerQuest(asker)
    if q.kind == "lost" then break end
end
local hasLost, hasHome = false, false
for _, m in ipairs(Rem.getStore().mapMarks) do
    if m.symbol == "Question" and m.x == q.x then hasLost = true end
    if m.id == "group:" .. g.id then hasHome = true end
end
check(q.kind == "lost" and hasLost, "missao 'alguem sumiu': um ? no lugar onde ele esta")
check(hasHome, "e a casa de quem pediu, para voce saber voltar")
Rem.changeRep(g.id, 100, "teste")
IA.askShelter(asker)
local hasShelter = false
for _, m in ipairs(Rem.getStore().mapMarks) do if m.id == "shelter:" .. g.id then hasShelter = true end end
check(hasShelter, "abrigo concedido: a casa e marcada")

realPrint("132) Desenhado no mapa do mundo")
calls = {}
ISWorldMap_instance = nil
local pending = #MM.pending()
check(pending >= 3, "(cenario) marcacoes pendentes: " .. pending)
ISWorldMap.ShowWorldMap(0)
local circles, texts = 0, 0
for _, c in ipairs(calls) do
    if c.kind == "tex" and c.name == "Circle" then circles = circles + 1 end
    if c.kind == "text" then texts = texts + 1 end
end
check(circles == pending and texts == pending and #MM.pending() == 0, "ao abrir o mapa: circulo, simbolo e anotacao de cada marcacao")
local circle = nil
for _, c in ipairs(calls) do if c.name == "Circle" then circle = c break end end
check(circle and circle.r and circle.scale > ISMap.SCALE, "circulo colorido e maior que o simbolo")
local n = #calls
ISWorldMap.ShowWorldMap(0)
check(#calls == n, "reabrir o mapa nao desenha de novo")
-- mapa ja existe: marcacao nova aparece na hora
MM.add({ id = "teste:1", x = 33500, y = 33500, symbol = "Star", color = MM.COLORS.quest, text = "x" })
check(#calls > n and #MM.pending() == 0, "com o mapa ja aberto, desenha na hora")
-- falha da API nao trava o jogo nem repete para sempre
symbolsAPI.addTexture = function() error("api") end
MM.add({ id = "teste:2", x = 1, y = 1, symbol = "Star" })
check(#MM.pending() == 0, "erro ao desenhar: registra e nao tenta para sempre")
check(tostring(T.logs[#T.logs]):find("teste:2", 1, true) ~= nil, "o erro de desenho fica registrado no log")
T.logs[#T.logs] = "(erro esperado do teste de marcacao, conferido acima)"
ISWorldMap_instance = nil
fresh()
