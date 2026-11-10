-- Migracao da 0.2 e inicio do mundo (secao 0). Roda primeiro: depende do store vazio.
local T = ...
local Rem = Remanescentes
local check, tick, fire, newZombie, square = T.check, T.tick, T.fire, T.newZombie, T.square
local clearZombies, saidPrefix, addBuilding = T.clearZombies, T.saidPrefix, T.addBuilding
local player, parts, logs, store, events = T.player, T.parts, T.logs, T.store, T.events
local realPrint = T.print

-- migracao: save da 0.2 com store.npcs
store.Remanescentes = { npcs = { ["555"] = { name = "Velho", item = "Base.Hammer", wtype = "1h", mode = "stay", homeX = 5, homeY = 5, homeZ = 0 } } }
fire("OnInitGlobalModData", false)

realPrint("0) Migracao da 0.2")
local s = Rem.getStore()
check(s.npcs == nil and Rem.personCount() == 1, "store.npcs vira store.people")
local migrated
for _, p in pairs(s.people) do migrated = p end
check(migrated.faction == "aliados" and migrated.pid == 555 and migrated.x == 5, "pessoa migrada como aliada, com pid e posicao")
Rem.removePerson(migrated.id)

tick(5000) -- passa o periodo de carencia do mundo
