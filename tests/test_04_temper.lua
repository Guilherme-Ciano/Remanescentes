-- Temperamentos, fuga, troca de alvo do zumbi (secoes 16-18).
local T = ...
local Rem = Remanescentes
local check, tick, fire, newZombie, square = T.check, T.tick, T.fire, T.newZombie, T.square
local clearZombies, saidPrefix, addBuilding = T.clearZombies, T.saidPrefix, T.addBuilding
local player, parts, logs, store, events = T.player, T.parts, T.logs, T.store, T.events
local realPrint = T.print

realPrint("16) Temperamentos: quando vale a pena lutar")
Rem.dismissAll(); clearZombies(); Rem.hunting = {}
Rem.playerFightAt = nil
player.x, player.y = 300, 300
local follower = Rem.spawn(300, 301, 0, { faction = "aliados", mode = "follow" })
follower.nextAttack = 0
-- zumbi distraido a 5 tiles, de costas, sem ver ninguem
local wanderer = newZombie(305, 301, 0, 1, 0); wanderer.canSee = false
tick(300); tick(100, 10)
check(Rem.hunting[wanderer] == nil, "(cenario) zumbi nao percebeu ninguem")
check(not (follower.z.path and follower.z.path[1] == 305), "aliado IGNORA zumbi distraido longe")
check(not wanderer.dead and follower.attackTarget ~= wanderer, "aliado nao ataca sem necessidade")
-- jogador parte pra cima: aliado entra na briga
fire("OnHitZombie", wanderer, player, nil, nil)
tick(300)
check(follower.z.path and follower.z.path[1] == 305, "jogador comecou a briga: aliado vai ajudar")
Rem.playerFightAt = nil
-- zumbi colado: aliado se defende
clearZombies({ [follower.z] = true }); Rem.hunting = {}
follower.z.x, follower.z.y = 300, 301; follower.z.vars.bPathfind = false; follower.moving = false
local close = newZombie(301, 301, 0, -1, 0); close.canSee = false
tick(300); tick(100, 20)
check(close.dead or follower.attackTarget == close, "zumbi colado: aliado se defende")
-- zumbi atras do jogador perto dele: aliado protege
clearZombies({ [follower.z] = true }); Rem.hunting = {}
follower.z.x, follower.z.y = 300, 301; follower.moving = false
local stalker = newZombie(303, 297, 0, 0, 1); stalker.canSee = false; stalker.target = player
tick(300)
check(follower.z.path and follower.z.path[1] == 303, "zumbi atacando o jogador: aliado protege")
stalker.target = nil
-- zumbi longe do jogador: seguidor nao larga o jogador
clearZombies({ [follower.z] = true }); Rem.hunting = {}
local farZ = newZombie(300, 311, 0, 0, -1); farZ.canSee = false
Rem.hunting[farZ] = { npc = follower, lastSeen = T.clock, nextPath = T.clock + 99999, real = false }
follower.z.x, follower.z.y = 300, 304; follower.moving = false
tick(300)
check(not (follower.z.path and follower.z.path[2] == 311), "seguidor nao corre atras de zumbi longe do jogador")
Rem.hunting = {}

realPrint("17) Civil foge, saqueador ataca")
Rem.dismissAll(); clearZombies(); Rem.hunting = {}
player.x, player.y = 400, 400
local civil = Rem.spawn(420, 420, 0, { faction = "civis", mode = "wander",
    personality = { agressividade = 1, confianca = 5, coragem = 1, ganancia = 3, lealdade = 5 } })   -- covarde
local scary = newZombie(420, 424, 0, 0, -1)
tick(600); tick(300)
check(Rem.hunting[scary] ~= nil, "(cenario) zumbi percebeu o civil")
check(civil.fleeing and civil.running, "civil covarde foge correndo de zumbi que o viu")
check(civil.z.path and civil.z.path[2] < 420, "foge para o lado oposto")
Rem.dismissAll(); clearZombies(); Rem.hunting = {}
-- arquetipo fixo: um saqueador furtivo (Rem_Profile) chega agachado e so ataca zumbi distraido de perto
local thug = Rem.spawn(440, 440, 0, { faction = "saqueadores", mode = "wander", archetype = "brigao" })
local unaware = newZombie(444, 440, 0, 1, 0); unaware.canSee = false
tick(300)
check(thug.z.path and thug.z.path[1] == 444, "saqueador (agressivo) vai atras de qualquer zumbi")
-- desvantagem: sobrevivente cauteloso recua de 4+ zumbis
Rem.dismissAll(); clearZombies(); Rem.hunting = {}
local vet = Rem.spawn(460, 460, 0, { faction = "sobreviventes", mode = "wander" })
for i = 1, 4 do local zz = newZombie(460 + i * 0.5, 462, 0, 0, -1); zz.canSee = false end
tick(300)
check(vet.fleeing, "sobrevivente cauteloso recua cercado por 4 zumbis")

realPrint("18) Zumbi atras do jogador troca para o saqueador colado nele")
Rem.dismissAll(); clearZombies(); Rem.hunting = {}
player.x, player.y = 500, 500
local bandit = Rem.spawn(500, 497, 0, { faction = "saqueadores", mode = "wander" })
bandit.nextAttack = T.clock + 9999999
local chaser = newZombie(500, 495, 0, 0, 1); chaser.target = player
tick(600)
check(chaser.target == bandit.z and chaser.noTeeth == true, "zumbi troca para o saqueador (sem dentes)")
chaser.target = player; tick(20)
check(chaser.noTeeth == false and Rem.hunting[chaser] == nil, "voltou ao jogador: dentes de volta")
tick(600)
check(chaser.target == player, "nao troca de novo logo em seguida (sem ficar indeciso)")
local far2 = newZombie(500, 485, 0, 0, 1); far2.target = player
tick(600)
check(far2.target == player, "saqueador longe do zumbi nao distrai")

realPrint("18b) Zumbis ligam para os sobreviventes como ligam para voce")
Rem.dismissAll(); clearZombies(); Rem.hunting = {}
player.x, player.y = 520, 520
local bait = Rem.spawn(520, 510, 0, { faction = "civis", mode = "stay" })
bait.nextAttack = T.clock + 9999999
local mid = newZombie(520, 505, 0, 0, 1); mid.target = player      -- 5 do civil, 15 de voce
tick(600)
check(mid.target == bait.z, "zumbi atras de voce troca para o sobrevivente bem mais perto dele (5 x 15 tiles)")
local even = newZombie(526, 515, 0, 0, 1); even.target = player    -- ~7,8 do civil, ~7,8 de voce
tick(600)
check(even.target == player, "a mesma distancia, continua em voce")
-- barulho: zumbis livres vem atras de QUEM fez o barulho
Rem.dismissAll(); clearZombies(); Rem.hunting = {}
local loud = Rem.spawn(540, 540, 0, { faction = "civis", mode = "stay" })
local back = newZombie(540, 548, 0, 0, 1)                           -- de costas para ele, a 8 tiles
local faraway = newZombie(540, 570, 0, 0, 1)
T.clock = T.clock + 200      -- (o indice de zumbis por perto e refeito a cada 100 ms)
local realRand = ZombRand
ZombRand = function(a, b) return b and a or 0 end
local n = Rem.Perception.attract(loud, 20)
ZombRand = realRand
check(n == 1 and Rem.hunting[back] and Rem.hunting[back].npc == loud and back.target == loud.z, "barulho de um sobrevivente: o zumbi livre por perto vai atras dele")
check(Rem.hunting[faraway] == nil, "longe demais nao escuta")
Rem.stopHunt(back)
T.clock = T.clock + 200
ZombRand = function(a, b) return b and a or 0 end
Rem.makeNoise(loud, 20)
ZombRand = realRand
check(Rem.hunting[back] and Rem.hunting[back].npc == loud, "todo barulho que ele faz (golpe, tiro, corrida) chama os zumbis")
local busy = newZombie(541, 545, 0, 0, 1); busy.target = player
T.clock = T.clock + 200
Rem.Perception.attract(loud, 20)
check(Rem.hunting[busy] == nil, "quem ja esta atras de alguem nao larga por causa do barulho")
Rem.dismissAll(); clearZombies(); Rem.hunting = {}
