-- Spawn, seguir, combate, ataque real/simulado dos zumbis, hostis, NPC x NPC, morte (secoes 1-8).
local T = ...
local Rem = Remanescentes
local check, tick, fire, newZombie, square = T.check, T.tick, T.fire, T.newZombie, T.square
local clearZombies, saidPrefix, addBuilding = T.clearZombies, T.saidPrefix, T.addBuilding
local player, parts, logs, store, events = T.player, T.parts, T.logs, T.store, T.events
local realPrint = T.print

realPrint("1) Spawn e aparencia")
local npc = Rem.spawn(12, 12, 0, { faction = "aliados", mode = "follow", item = "Base.BaseballBat", wtype = "bat" })
check(npc ~= nil and npc.rec.id ~= nil, "spawn cria pessoa com id")
check(npc.z.useless == true and npc.z.noTeeth == true, "corpo e zumbi inutil e sem dentes")
check(npc.z.vars.RemNPC == true and npc.z.vars.RemWeapon == "bat", "variaveis de animacao")
check(npc.z.skin and npc.z.skin:sub(1, 9) == "MaleBody0" and npc.z.cleaned, "pele humana e roupa limpa")
check(npc.z.avoid == true, "aliado protegido de fogo amigo")
check(npc.rec.pid == npc.z.pid and npc.rec.onScene, "pessoa sabe qual corpo e o dela")
check(saidPrefix(npc.z, "IGUI_Rem_Bark_hello_"), "cumprimenta")

realPrint("2) Seguir: correr longe, andar perto, agachar junto")
player.x, player.y = 30, 30
tick(300)
check(npc.z.path and npc.z.path[1] == 30 and npc.z.vars.bPathfind == true, "anda via pathfind ate o jogador")
check(npc.running, "corre quando longe")
npc.z.x, npc.z.y = 26, 26
tick(1100)
check(not npc.running, "anda quando perto")
npc.z.vars.bPathfind = false; npc.z.x, npc.z.y = 30, 31
player.sneaking = true
tick(300)
check(npc.z.vars.RemSneak == true, "agacha quando o jogador agacha")
player.sneaking = false
tick(300)
check(npc.rec.x == 30 and npc.rec.y == 31, "posicao sincronizada na pessoa")

realPrint("3) Combate contra zumbi")
npc.lastBark = nil; npc.barkAt = {}
local enemy = newZombie(30, 32, 0)
T.sounds = {}
tick(300); tick(100, 45)
check(enemy.dead, "mata o zumbi")
check(#T.sounds > 0, "golpes fazem barulho")
check(saidPrefix(npc.z, "IGUI_Rem_Bark_kill_"), "comenta a morte")

realPrint("4) Ataque REAL dos zumbis: mira, dentes e troca de alvo")
clearZombies({ [npc.z] = true }); Rem.hunting = {}
npc.nextAttack = T.clock + 9999999 -- npc nao revida nestes testes
local hunter = newZombie(30, 28, 0, 0, 1)
tick(600)
check(hunter.target == npc.z, "zumbi mira o sobrevivente (setTarget)")
check(hunter.noTeeth == true, "atacante fica sem dentes enquanto mira o sobrevivente")
local hp0 = npc.z.hp
hunter.attacking = true; hunter.outcome = "start"; tick(20)
hunter.outcome = "success"; tick(20)
check(npc.z.hp < hp0, "acerto real (outcome=success) causa dano")
check(npc.z.vars.RemHit == true, "sobrevivente faz animacao de golpe")
local hp1 = npc.z.hp
tick(20)
check(npc.z.hp == hp1, "mesmo acerto nao conta duas vezes")
hunter.attacking = false; tick(20); hunter.attacking = true; tick(20)
check(npc.z.hp < hp1, "novo ciclo de ataque conta de novo")
tick(600)
check(npc.z.vars.RemHit == false, "reacao ao golpe termina")
hunter.target = player; tick(20)
check(hunter.noTeeth == false, "trocou para o jogador: DENTES DE VOLTA no mesmo tick")
check(Rem.hunting[hunter] == nil, "e esquece o sobrevivente")
hunter.target = nil
npc.z.hp = 3.0

realPrint("5) Ataque simulado (opcao do sandbox)")
SandboxVars.Remanescentes.ZombieAttackMode = 2
clearZombies({ [npc.z] = true }); Rem.hunting = {}
local biter = newZombie(30.5, 31.4, 0)
tick(600)
check(biter.vars.RemZAttack == true and npc.z.hp < 3.0, "bote animado + dano")
check(biter.target == nil and biter.noTeeth == false, "modo simulado nao mexe em alvo/dentes")
tick(800)
check(biter.vars.RemZAttack == false, "animacao termina")
SandboxVars.Remanescentes.ZombieAttackMode = 1
npc.z.hp = 3.0

realPrint("6) Saqueador hostil ataca o jogador")
SandboxVars.Remanescentes.RaiderMugging = false   -- aqui interessa o combate (assalto: test_11)
clearZombies({ [npc.z] = true }); Rem.hunting = {}
npc.rec.mode = "stay"; npc.rec.homeX, npc.rec.homeY = 30, 31
local raider = Rem.spawn(30, 36, 0, { faction = "saqueadores", item = "Base.BaseballBat", wtype = "bat" })
check(raider.z.avoid == false, "hostil pode ser ferido pelo jogador")
raider.nextAttack = 0
npc.z.inWorld = false; tick(20); -- tira o aliado da cena para isolar o duelo
player.x, player.y = 30, 37
tick(300)
check(raider.attackTarget == player or raider.z.path ~= nil, "hostil vai/ataca o jogador")
check(saidPrefix(raider.z, "IGUI_Rem_Bark_threat_"), "ameaca o jogador")
tick(100, 6)
local hurt = nil
for _, p in pairs(parts) do if p.damage > 0 then hurt = p end end
check(hurt ~= nil, "jogador leva dano numa parte do corpo")
check(hurt and (hurt.cut or hurt.scratched) and hurt.noInfection == true, "ferimento de arma SEM infeccao")

realPrint("7) Sobrevivente x sobrevivente (faccoes rivais)")
npc.z.inWorld = true
local ally = Rem.active[npc.z]
if not ally then ally = Rem.activate(npc.z, npc.rec) end
player.x, player.y = 45, 45 -- jogador afastado (mas dentro da cena), so os dois
raider.z.x, raider.z.y = 30, 32
ally.nextAttack = 0; raider.nextAttack = 0
local rhp = raider.z.hp
tick(300); tick(100, 30)
check(raider.z.hp < rhp or raider.z.dead, "aliado ataca o saqueador")
check(ally.z.hp < 3.0 or raider.attackTarget == ally.z or raider.z.dead, "saqueador revida no aliado")

realPrint("8) Morte solta os zumbis que cacavam")
Rem.dismissAll(); clearZombies(); Rem.hunting = {}
player.x, player.y = 45, 45
ally = Rem.spawn(30, 31, 0, { faction = "aliados", mode = "stay" })
ally.rec.homeX, ally.rec.homeY = 30, 31
local h2 = newZombie(30, 28, 0, 0, 1)
ally.nextAttack = T.clock + 9999999
tick(600)
check(h2.noTeeth == true, "zumbi cacando sem dentes")
ally.z.hp = 0.01
Rem.damageNPC(ally, 1)
tick(20)
check(ally.z.dead and h2.noTeeth == false, "sobrevivente morreu: zumbi volta a ter dentes")
check(Rem.getPerson(ally.rec.id) == nil, "pessoa removida")
