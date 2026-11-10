-- Mundo vivo: semeadura, simulacao, saque, cena, re-associacao, ataques fora de cena (secoes 9-14).
local T = ...
local Rem = Remanescentes
local check, tick, fire, newZombie, square = T.check, T.tick, T.fire, T.newZombie, T.square
local clearZombies, saidPrefix, addBuilding = T.clearZombies, T.saidPrefix, T.addBuilding
local player, parts, logs, store, events = T.player, T.parts, T.logs, T.store, T.events
local realPrint = T.print

-- ------------------------------------------------------------------ mundo vivo
realPrint("9) Semeadura: grupos em predios reais")
Rem.dismissAll(); clearZombies(); Rem.hunting = {}
player.x, player.y = 1000, 1000
addBuilding(1, 1100, 1000, 10, 10)   -- 105 tiles
addBuilding(2, 1000, 1200, 8, 8)     -- ~204
addBuilding(3, 1010, 1010, 6, 6)     -- muito perto do jogador (nao serve)
addBuilding(4, 1130, 1000, 10, 10)   -- alvo de saque perto do 1
SandboxVars.Remanescentes.WorldGroups = 2
Rem.getStore().seeded = false -- simula um save novo
Rem.getStore().regions = {}
local bpg, rural = Rem.Regions.CFG.BUILDINGS_PER_GROUP, Rem.Regions.CFG.RURAL_BELOW
Rem.Regions.CFG.BUILDINGS_PER_GROUP, Rem.Regions.CFG.RURAL_BELOW = 1, 0   -- 4 predios contam como "cidade"
tick(2000)
Rem.Regions.CFG.BUILDINGS_PER_GROUP, Rem.Regions.CFG.RURAL_BELOW = bpg, rural
check(Rem.groupCount() >= 1, "grupos criados (" .. Rem.groupCount() .. ")")
local g = select(1, Rem.nearestGroup(1105, 1005))
check(g and g.home and g.home.bid ~= "3", "nao nasce grupo colado no jogador")
check(g and #g.members >= 1 and Rem.getPerson(g.members[1]).groupId == g.id, "membros pertencem ao grupo")

realPrint("10) Simulacao fora de cena: fome, saque, volta")
g.supplies = 0.5
local sup0 = g.supplies
Rem.simulateWorld(1)
check(g.supplies < sup0 or g.activity == "scavenge", "consome suprimentos")
-- forca saida para saquear (faccao fixa: errantes tambem mudam de acampamento, o que
-- mexe na sequencia do sorteio deterministico do mock)
g.faction = "civis"
g.supplies = 0; g.activity = "home"
for _ = 1, 12 do if g.activity == "home" then Rem.simulateWorld(1) end end
check(g.activity == "scavenge" and g.target, "sai para saquear com pouca comida (" .. tostring(g.faction) .. "/" .. tostring(g.activity) .. "/" .. #g.members .. ")")
local tgtBid = g.target.bid
for _ = 1, 4 do T.worldHours = T.worldHours + 1; Rem.simulateWorld(1) end
check(Rem.getStore().looted[tgtBid] ~= nil, "predio alvo marcado como saqueado")
check(g.supplies > 0, "ganhou suprimentos")
-- volta para casa (com pouca comida pode sair de novo logo depois: vale ter chegado)
local cameHome = false
for _ = 1, 4 do
    T.worldHours = T.worldHours + 1; Rem.simulateWorld(1)
    if g.activity == "home" then cameHome = true end
end
check(cameHome, "voltou para casa")

realPrint("11) Casa saqueada fica vazia de verdade")
local emptied = false
local container = { _class = "ItemContainer", getSourceGrid = function() return { getBuilding = function() return { getDef = function() return { getID = function() return tonumber(tgtBid) end } end } end } end,
    removeAllItems = function() emptied = true end }
local pickerOk = pcall(fire, "OnFillContainer", "Zombie", "Bag", { _class = "ItemPickerContainer" })
check(pickerOk, "mochila de zumbi (ItemPickerContainer) e ignorada sem erro")
local logsBefore = #logs
fire("OnFillContainer", "Zombie", "Bag", { _class = "ItemPickerContainer" })
check(#logs == logsBefore, "nenhum ERRO no log para mochila de zumbi")
fire("OnFillContainer", "kitchen", "fridge", container)
check(emptied, "conteiner de predio saqueado e esvaziado")

realPrint("12) Materializar perto, desmaterializar longe")
for _, id in ipairs(g.members) do local p = Rem.getPerson(id); p.x, p.y = g.home.x, g.home.y end
player.x, player.y = g.home.x + 20, g.home.y
tick(1600)
local member = Rem.getPerson(g.members[1])
check(member.onScene and Rem.activeCount >= 1, "membro ganhou corpo ao jogador chegar perto")
local body
for z, n in pairs(Rem.active) do if n.rec == member then body = z end end
body.x = body.x + 1
player.x, player.y = g.home.x + 200, g.home.y
tick(1600)
check(not member.onScene and member.pid == nil, "longe: corpo removido, pessoa continua")
check(math.abs(member.x - (g.home.x + 1)) < 3, "posicao do corpo salva na pessoa")
check(body.inWorld == false, "zumbi do corpo saiu do mundo")

realPrint("13) Re-associar corpo salvo depois de um load")
local saved = newZombie(member.x, member.y, 0)
member.pid = saved.pid
member.onScene = false
Rem.invalidatePidIndex()
fire("OnZombieUpdate", saved)
check(Rem.active[saved] ~= nil and saved.useless, "zumbi salvo vira a pessoa de novo (sem duplicar)")
local stranger = newZombie(5, 5, 0)
fire("OnZombieUpdate", stranger)
check(Rem.active[stranger] == nil, "zumbi comum nao e afetado")

realPrint("14) Ataque de saqueadores fora de cena")
Rem.dismissAll(); clearZombies()
local victims = Rem.createGroup("civis", 2000, 2000, "v", 2)
local gang = Rem.createGroup("saqueadores", 2100, 2000, "r", 4)
victims.supplies = 10
gang.supplies = 0
player.x, player.y = 0, 0
gang.activity = "raid"; gang.target = { x = 2000, y = 2000, z = 0, victim = victims.id }
for _ = 1, 3 do T.worldHours = T.worldHours + 1; Rem.simulateWorld(1) end
check(#victims.members < 2 or gang.supplies > 0, "ataque resolvido: mortes e/ou suprimentos roubados")
check(gang.activity == "return" or gang.activity == "home", "saqueadores voltam para casa")
