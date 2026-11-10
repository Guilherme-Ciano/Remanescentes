-- Teleporte seguro, corpo recem-criado, remover tudo (secoes 19-21).
local T = ...
local Rem = Remanescentes
local check, tick, fire, newZombie, square = T.check, T.tick, T.fire, T.newZombie, T.square
local clearZombies, saidPrefix, addBuilding = T.clearZombies, T.saidPrefix, T.addBuilding
local player, parts, logs, store, events = T.player, T.parts, T.logs, T.store, T.events
local realPrint = T.print

realPrint("19) Teleporte seguro perto de um grupo")
Rem.dismissAll(); clearZombies(); Rem.hunting = {}
local home = Rem.createGroup("civis", 1000, 1000, "77", 2,
    { getX = function() return 990 end, getY = function() return 992 end, getW = function() return 20 end, getH = function() return 16 end })
check(home.home.x2 == 1010 and home.home.y2 == 1008, "grupo guarda o retangulo da casa")
T.blockedSq["1000,1013"] = true          -- parede/objeto no ponto ideal
local zNear = newZombie(1001, 1014, 0)  -- e um zumbi ali do lado
Rem.teleportNearGroup(player, home)
local tx, ty = math.floor(player.x), math.floor(player.y)
check(not T.blockedSq[tx .. "," .. ty], "nao cai dentro de parede/objeto")
check(Rem.dist2(tx, ty, zNear.x, zNear.y) >= 6, "nao cai em cima de zumbis")
check(ty >= 1008, "fica do lado de fora da casa")
check(Rem.dist2(tx, ty, 1000, 1000) < 45, "perto o bastante para os moradores aparecerem")
-- lugar ainda nao carregado: ajusta depois
T.worldLoaded = false
Rem.teleportNearGroup(player, home)
T.worldLoaded = true
tick(20)
tx, ty = math.floor(player.x), math.floor(player.y)
check(not T.blockedSq[tx .. "," .. ty] and Rem.dist2(tx, ty, zNear.x, zNear.y) >= 6, "ajusta a posicao quando o lugar carrega")
T.blockedSq = {}

realPrint("20) Corpo recem-criado sem quadrado nao e re-ativado")
Rem.dismissAll(); clearZombies(); Rem.hunting = {}
player.x, player.y = 600, 600
local fresh = Rem.spawn(601, 601, 0, { faction = "aliados", mode = "stay" })
local activations = 0
for _, l in ipairs(logs) do if l:find("ativado " .. fresh.rec.name, 1, true) then activations = activations + 1 end end
fresh.z.getCurrentSquare = function() return nil end
tick(100, 5)
check(Rem.active[fresh.z] == fresh, "continua ativo nos primeiros frames sem quadrado")
fresh.z.getCurrentSquare = function(self) return {} end
tick(1600)
local after = 0
for _, l in ipairs(logs) do if l:find("ativado " .. fresh.rec.name, 1, true) then after = after + 1 end end
check(after == activations, "nao foi ativado duas vezes")

realPrint("21) Remover tudo")
Rem.dismissAll()
check(Rem.personCount() == 0 and Rem.groupCount() == 0 and Rem.activeCount == 0, "limpo")
