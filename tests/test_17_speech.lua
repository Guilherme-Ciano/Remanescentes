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
