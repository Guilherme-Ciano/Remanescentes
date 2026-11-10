-- Ninguem nasce pelado: roupa sempre existe para o genero do corpo.
local T = ...
local Rem = Remanescentes
local check, realPrint = T.check, T.print

realPrint("100) Roupa x genero")
Rem.dismissAll(); T.clearZombies(); Rem.hunting = {}
local function spawnWith(outfit, female)
    local rec = Rem.newPerson({ faction = "civis", outfit = outfit, x = 15000, y = 15000 })
    rec.female = female
    local npc = Rem.materialize(rec)
    return npc, rec
end

local bad = {}
for name in pairs(Rem.OUTFIT_ONE_GENDER.male) do
    local npc, rec = spawnWith(name, true)
    if not npc or not Rem.outfitValid(rec.outfit, true) or npc.z.femaleChance ~= 100 or npc.z.outfit ~= rec.outfit then
        table.insert(bad, name)
    end
end
check(#bad == 0, "mulher com roupa so masculina: troca por equivalente feminina " .. table.concat(bad, ","))
local npcM, recM = spawnWith("Mechanic", true)
check(recM.outfit == "Fossoil", "mecanica vai de frentista (Fossoil)")
local npcS, recS = spawnWith("Security", true)
check(recS.outfit == "Police", "seguranca mulher vai de policial")
local npcO, recO = spawnWith("OfficeWorkerSkirt", false)
check(recO.outfit == "OfficeWorker" and npcO.z.femaleChance == 0, "homem com roupa so feminina: troca")
local npcP, recP = spawnWith("Police", true)
check(recP.outfit == "Police", "roupa valida para o genero: nao muda")
local _, recR = spawnWith("Mechanic", nil)
check(recR.female ~= nil and Rem.outfitValid(recR.outfit, recR.female), "genero decidido antes de criar o corpo")

realPrint("101) Lista de roupas do proprio jogo (getAllOutfits)")
getAllOutfits = function(female)
    if female then return T.JList({ "Generic01", "Police", "Nurse" }) end
    return T.JList({ "Generic01", "Police", "Mechanic" })
end
Rem.resetOutfitCache()
check(Rem.outfitValid("Nurse", true) and not Rem.outfitValid("Nurse", false), "usa a lista do jogo quando existe")
local _, recN = spawnWith("Nurse", false)
check(recN.outfit ~= "Nurse" and Rem.outfitValid(recN.outfit, false), "enfermeiro homem sem roupa masculina no jogo: troca")
getAllOutfits = nil
Rem.resetOutfitCache()

realPrint("102) Corpo pelado de save antigo e vestido de novo")
Rem.dismissAll(); T.clearZombies()
local rec = Rem.newPerson({ faction = "civis", outfit = "Mechanic", x = 15100, y = 15100 })
local body = T.newZombie(15100, 15100, 0)
body.female, body.naked = true, true
local npc = Rem.activate(body, rec)
check(body.dressed and Rem.outfitValid(body.dressed, true) and not body.naked, "veste de novo com roupa valida (" .. tostring(body.dressed) .. ")")
check(rec.pid == body.pid, "o reconhecimento do corpo (pid) continua certo depois de vestir")

realPrint("103) Ninguem pelado em massa")
Rem.dismissAll(); T.clearZombies()
local naked = 0
local factions = { "civis", "sobreviventes", "saqueadores", "seita", "errantes", "aliados" }
for i = 1, 300 do
    local r = Rem.newPerson({ faction = factions[(i % #factions) + 1], x = 15200, y = 15200 })
    r.female = (i % 2 == 0)
    Rem.ensureOutfit(r)
    if not Rem.outfitValid(r.outfit, r.female) then naked = naked + 1 end
    Rem.removePerson(r.id)
end
check(naked == 0, "300 pessoas de todas as faccoes/profissoes: nenhuma roupa invalida")
Rem.dismissAll()
