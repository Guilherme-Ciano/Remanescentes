-- Falas: tom pela personalidade, variedade, sem repetir em seguida; respostas da conversa.
local T = ...
local Rem = Remanescentes
local check, realPrint = T.check, T.print
local IA = Rem.Interact

realPrint("140) Falas com tom e variedade")
Rem.dismissAll(); T.clearZombies()
local thug = Rem.spawn(34000, 34000, 0, { faction = "saqueadores" })
local scared = Rem.spawn(34005, 34000, 0, { faction = "civis" })
scared.rec.temper = "medroso"
thug.z.said, scared.z.said = {}, {}
Rem.bark(thug, "kill", true)
Rem.bark(scared, "spot", true)
check(thug.z.said[1]:find("IGUI_Rem_Bark_kill_tough_"), "saqueador (agressivo) fala como durao")
check(scared.z.said[1]:find("IGUI_Rem_Bark_spot_scared_"), "civil medroso fala assustado")
local normal = Rem.spawn(34010, 34000, 0, { faction = "aliados" })
normal.z.said = {}
Rem.bark(normal, "kill", true)
check(normal.z.said[1]:find("IGUI_Rem_Bark_kill_%d"), "aliado (defensivo) usa a fala normal")
local repeats = 0
local realRand = ZombRand
ZombRand = function(a, b) return b and a or 0 end   -- sorteio "azarado": sempre a mesma frase
for _ = 1, 30 do
    Rem.bark(normal, "idle", true)
    local s = normal.z.said
    if #s >= 2 and s[#s] == s[#s - 1] then repeats = repeats + 1 end
end
ZombRand = realRand
check(repeats == 0, "nunca repete a mesma frase duas vezes seguidas, mesmo com o sorteio repetindo")

realPrint("141) Respostas da conversa variam com o tom")
local cold = Rem.spawn(34020, 34000, 0, { faction = "sobreviventes" })
cold.rec.personality.agressividade, cold.rec.personality.coragem = 9, 8
local l = IA.finalize({ key = "IGUI_Rem_Talk_bye", args = {} }, cold)
check(l.key:find("IGUI_Rem_Talk_bye_cold_%d"), "agressivo se despede seco (" .. l.key .. ")")
local shy = Rem.spawn(34030, 34000, 0, { faction = "civis" })
shy.rec.personality.coragem = 2
check(IA.greeting(shy).key:find("IGUI_Rem_Talk_hi_scared_"), "medroso cumprimenta assustado")
local byeShy = IA.finalize({ key = "IGUI_Rem_Talk_bye", args = {} }, shy)
check(byeShy.key:find("IGUI_Rem_Talk_bye_scared_%d"), "medroso se despede assustado (" .. byeShy.key .. ")")
local byeNormal = IA.finalize({ key = "IGUI_Rem_Talk_bye", args = {} }, normal)
check(byeNormal.key:find("IGUI_Rem_Talk_bye_%d"), "aliado se despede no tom normal (" .. byeNormal.key .. ")")
local seen = {}
for _ = 1, 20 do seen[IA.finalize({ key = "IGUI_Rem_Talk_need_food", args = {} }, normal).key] = true end
local n = 0
for _ in pairs(seen) do n = n + 1 end
check(n >= 2, "a mesma resposta tem variacoes (" .. n .. ")")
check(IA.text({ key = "IGUI_Rem_Talk_refuse", args = {} }):find("IGUI_Rem_Talk_refuse_%d"), "fala sem variacao escolhida e resolvida sozinha (nunca aparece a chave crua)")
Rem.dismissAll()

realPrint("142) Falas desenhadas sobre a cabeca (Say nao funciona em corpo de zumbi)")
Rem.dismissAll(); T.clearZombies()
local drawnText = {}
function getCore() return { getScreenWidth = function() return 1920 end, getScreenHeight = function() return 1080 end,
    getZoom = function() return 1 end } end
function getTextManager() return { getFontHeight = function() return 14 end, MeasureStringX = function() return 50 end,
    DrawStringCentre = function(_, font, x, y, text, r, g, b, a) table.insert(drawnText, { text = text, x = x, y = y, a = a, r = r }) end } end
function isoToScreenX(_, x) return x * 10 end
function isoToScreenY(_, x, y) return y * 10 end
require "Remanescentes/Rem_SpeechUI"
local SPUI = Rem.SpeechUI
local p = T.player
p.x, p.y = 35000, 35000
local talker = Rem.spawn(35002, 35000, 0, { faction = "civis", mode = "stay" })
local far = Rem.spawn(35100, 35000, 0, { faction = "civis", mode = "stay" })
Rem.bark(talker, "hello", true)
Rem.bark(far, "hello", true)
check(talker.speech and #talker.speech >= 1 and talker.speech[#talker.speech].text:find("IGUI_Rem_Bark_hello"), "fala guardada para desenhar")
T.fire("OnPreUIDraw")
local mine, farDrawn, outline = 0, 0, 0
for _, d in ipairs(drawnText) do
    if d.text == talker.speech[#talker.speech].text and d.r ~= 0 then mine = mine + 1 end
    if d.text == far.speech[1].text and math.abs(d.x - 351000) < 5 then farDrawn = farDrawn + 1 end
    if d.r == 0 then outline = outline + 1 end
end
check(mine == 1 and outline >= 4, "desenhada sobre ele, com contorno")
check(drawnText[#drawnText].y < 35000 * 10, "acima da cabeca (mais alto que os pes)")
check(farDrawn == 0, "longe demais: nao desenha")
Rem.speak(talker, "segunda")
Rem.speak(talker, "terceira")
check(#talker.speech == Rem.SPEECH.LINES and talker.speech[#talker.speech].text == "terceira", "no maximo " .. Rem.SPEECH.LINES .. " linhas, a mais nova embaixo")
drawnText = {}
T.fire("OnPreUIDraw")
local ys = {}
for _, d in ipairs(drawnText) do if d.r ~= 0 then ys[d.text] = d.y end end
check(ys.terceira and ys.segunda and ys.terceira > ys.segunda, "a fala nova fica embaixo da anterior")
T.clock = T.clock + Rem.SPEECH.MAX_MS + 100   -- so o relogio (sem tick: ele falaria de novo)
check(#Rem.speechOf(talker) == 0, "a fala some depois de um tempo")
drawnText = {}
T.fire("OnPreUIDraw")
check(#drawnText == 0, "nada mais desenhado")
Rem.speak(talker, "x")
local l = SPUI.linesFor(talker, talker.speech[1].untilMs - 100)
check(l[1].a < 1 and l[1].a > 0, "desvanece no fim")
check(SPUI.failures == 0, "nenhum erro ao desenhar")
Rem.dismissAll()
