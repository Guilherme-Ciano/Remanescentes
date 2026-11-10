-- Fases A (percepcao e perseguicao) e B (combate justo).
local T = ...
local Rem = Remanescentes
local check, tick = T.check, T.tick
local player, realPrint = T.player, T.print
local A = Rem.Awareness

local function fresh()
    Rem.dismissAll(); T.clearZombies(); Rem.hunting = {}
    Rem.Mugging.enc = {}
    player.running, player.sneaking, player.moving = false, false, true
    player.weapon, player.bag, player.defense = nil, nil, 0
    T.daylight = 1.0
end

local function hostile(x, y, opts)
    opts = opts or {}
    opts.faction = opts.faction or "saqueadores"
    opts.mode = opts.mode or "wander"
    opts.archetype = opts.archetype or "brigao"
    local npc = Rem.spawn(x, y, 0, opts)
    npc.z.fx, npc.z.fy = 0, 1          -- olhando para o sul (+y)
    npc.nextAttack = T.clock + 9999999 -- nestes testes ele nao golpeia (salvo quando o teste quer)
    return npc
end

local function damage()
    local t = 0
    for _, p in pairs(T.parts) do t = t + (p.damage or 0) end
    return t
end
local function clearParts() for k in pairs(T.parts) do T.parts[k] = nil end end

SandboxVars.Remanescentes.RaiderMugging = false

realPrint("70) A1 Visao: luz, postura e campo de visao")
fresh()
player.x, player.y = 9000, 9010
local h1 = hostile(9000, 9000)
tick(300); tick(250, 12)
check(h1.awareP and h1.awareP.state == "chase", "de dia, de frente, a 10 tiles: te nota")
fresh()
T.daylight = 0.0
player.x, player.y = 9000, 9010
local h2 = hostile(9000, 9000)
tick(300); tick(250, 20)
check(not h2.awareP or h2.awareP.state == "none", "na escuridao a 10 tiles: nao te ve")
fresh()
player.x, player.y = 9000, 9008
player.sneaking = true
local h3 = hostile(9000, 9000)
tick(300); tick(250, 6)
check(not h3.awareP or h3.awareP.state ~= "chase", "agachado a 8 tiles (alcance 9): nao reconhece logo")
tick(250, 30)
check(h3.awareP and h3.awareP.state == "chase", "...mas parado ali na frente dele, acaba notando")
fresh()
player.x, player.y = 9000, 8995
local h4 = hostile(9000, 9000)   -- olhando para o sul; voce esta ao norte (atras dele)
tick(300); tick(250, 20)
check(not h4.awareP or h4.awareP.state == "none", "de costas para voce a 5 tiles: nao te ve")
player.x, player.y = 9000, 8998.8
tick(300)
check(h4.awareP and h4.awareP.state == "chase", "colado nas costas dele: percebe")
fresh()
player.x, player.y = 9000, 9006
local h5 = hostile(9000, 9000)
h5.z.CanSee = function() error("falha na API") end
tick(300); tick(250, 20)
check(not h5.awareP or h5.awareP.state == "none", "erro na checagem de visao: NAO ve (falha fechada)")

realPrint("71) A2 Audicao")
fresh()
player.x, player.y = 9300, 9300
local ear = hostile(9200, 9200)
T.fire("OnWorldSound", 9210, 9200, 0, 40, 40, player)
check(ear.awareP and ear.awareP.state == "suspicious" and ear.awareP.lastX == 9210, "ouviu um tiro: fica desconfiado e marca o ponto do som")
tick(300)
check(ear.z.path and math.floor(ear.z.path[1]) == 9210, "vai investigar o ponto do som (nao direto em voce)")
local far = hostile(9500, 9500)
T.fire("OnWorldSound", 9210, 9200, 0, 40, 40, player)
check(not far.awareP or far.awareP.state == "none", "longe demais para ouvir: nada")

realPrint("72) A3 Memoria, procura e desistencia")
fresh()
player.x, player.y = 9600, 9605
local m = hostile(9600, 9600)
tick(300); tick(250, 8)
check(m.awareP.state == "chase", "(cenario) perseguindo")
m.z.canSee = false                 -- voce quebrou a linha de visao
player.x, player.y = 9600, 9612
tick(250, 6)
check(m.awareP.state == "chase", "logo depois de sumir ainda sabe onde voce esta")
tick(250, 12)
check(m.awareP.state == "search" and T.saidPrefix(m.z, "IGUI_Rem_Bark_search_"), "perdeu de vista: procura no ultimo ponto")
tick(250, 70)
check(m.awareP.state == "none" and T.saidPrefix(m.z, "IGUI_Rem_Bark_giveup_"), "nao achou: desiste")
local before = m.awareP.level
m.z.canSee = true
player.x, player.y = 9600, 9606
tick(250)
check(m.awareP.level < 1, "depois de desistir, demora mais para te notar de novo")

realPrint("73) A4 Folego")
fresh()
player.x, player.y = 9800, 9830
local r = hostile(9800, 9800)
r.rec.age = 50
r.awareP = { state = "chase", level = 1, lastSeen = T.clock, lastX = 9800, lastY = 9830 }
r.z.canSee = true
tick(300)
check(r.running, "(cenario) correndo atras de voce")
r.z.vars.bPathfind = true; r.moving = true
local secs = A.runSeconds(r.rec)
for _ = 1, math.ceil(secs * 4) + 4 do
    player.y = r.z.y + 30
    r.awareP.lastSeen = T.clock
    r.moving = true; r.z.vars.bPathfind = true
    tick(250)
end
check(r.winded and not r.running, "depois de ~" .. math.floor(secs) .. " s correndo: sem folego, anda")
check(T.saidPrefix(r.z, "IGUI_Rem_Bark_winded_"), "reclama do cansaco")
local hurt = hostile(9850, 9800)
hurt.z.hp = hurt.rec.maxHealth * 0.3
tick(300)
Rem.setGait(hurt, "run")
check(not hurt.running, "muito ferido: manca, nao corre")

realPrint("74) A5 Coleira")
fresh()
player.x, player.y = 10000, 10005
local L = hostile(10000, 10000)
L.rec.homeX, L.rec.homeY = 9900, 10000          -- casa a 100 tiles
tick(300); tick(250, 8)
check(not L.awareP or L.awareP.state ~= "chase", "longe demais de casa: desiste e volta")

realPrint("75) B1 Dano calibrado e roupa")
fresh()
clearParts()
local brute = hostile(10200, 10200)
Rem.woundPlayer(player, 3.0, brute, "melee")   -- facao no maximo
local dmg1 = damage()
check(dmg1 > 0 and dmg1 <= 30, "golpe de facao (dano 3.0): no maximo 30 numa parte do corpo (antes 54); foi " .. dmg1)
clearParts()
player.defense = 100
local res = Rem.woundPlayer(player, 3.0, brute, "melee")
local cut = false
for _, p in pairs(T.parts) do if p.cut or p.scratched then cut = true end end
check(res == "blocked" and not cut and damage() < dmg1 * 0.5, "roupa protege: sem corte, pouco dano")
clearParts()
player.defense = 0
SandboxVars.Remanescentes.NPCDifficulty = 1
Rem.woundPlayer(player, 3.0, brute, "melee")
check(damage() < dmg1, "dificuldade facil: menos dano")
SandboxVars.Remanescentes.NPCDifficulty = nil
clearParts()
Rem.woundPlayer(player, 1.0, brute, "bullet")
local bullet = false
for _, p in pairs(T.parts) do if p.bullet then bullet = true end end
check(bullet, "tiro sem protecao: bala alojada")
local t0 = T.clock
Rem.startAttack(brute, player, t0)
check(brute.hitAt - t0 >= 450 and brute.nextAttack - t0 >= 1600, "golpe em voce tem preparacao e intervalo maiores")

realPrint("76) B5 Vida por arquetipo e roupa")
local shooter = Rem.newPerson({ faction = "civis", archetype = "atirador", outfit = "Tourist" })
local cop = Rem.newPerson({ faction = "civis", archetype = "brigao", outfit = "Police" })
local base = Rem.cfg("NPCHealth", 2.0)
check(math.abs(shooter.maxHealth - base * 0.85) < 0.01, "atirador sem protecao: 85% da vida base")
check(cop.armored and math.abs(cop.maxHealth - base * 1.25) < 0.01, "brigao de farda: 125% da vida base")
Rem.removePerson(shooter.id); Rem.removePerson(cop.id)

realPrint("77) B2 Disciplina de tiro")
fresh()
player.x, player.y = 10400, 10407
local gun = hostile(10400, 10400, { archetype = "atirador" })
gun.rec.firearm, gun.rec.ammo = "Base.Pistol", 8
gun.awareP = { state = "chase", level = 1, lastSeen = T.clock, lastX = player.x, lastY = player.y }
tick(300)
check(gun.gunOut and T.saidPrefix(gun.z, "IGUI_Rem_Bark_aim_warn_") and gun.rec.ammo == 8, "primeiro: aponta e avisa, sem atirar")
tick(100, 20)
check(gun.rec.ammo == 8, "da tempo de reagir (" .. Rem.Ranged.CFG.WARN_MS / 1000 .. " s)")
tick(100, 12)
check(gun.rec.ammo < 8, "depois do aviso, atira")
-- noite: alcance menor
fresh()
T.daylight = 0.0
player.x, player.y = 10400, 10407
local ng = hostile(10400, 10400, { archetype = "atirador" })
ng.rec.firearm, ng.rec.ammo = "Base.Pistol", 8
ng.awareP = { state = "chase", level = 1, lastSeen = T.clock, lastX = player.x, lastY = player.y }
ng.z.canSee = true
tick(300); tick(100, 40)
check(ng.rec.ammo == 8 and not ng.gunOut, "a noite, a 7 tiles (alcance 6): nao atira")
-- aliado na linha de tiro
fresh()
player.x, player.y = 10500, 10508
local g2 = hostile(10500, 10500, { archetype = "atirador" })
local buddy = hostile(10500, 10504, { archetype = "brigao" })
g2.rec.firearm, g2.rec.ammo = "Base.Pistol", 8
g2.awareP = { state = "chase", level = 1, lastSeen = T.clock, lastX = player.x, lastY = player.y }
check(Rem.Ranged.friendInLine(g2, player), "companheiro entre ele e voce: linha bloqueada")
g2.z.canSee = true
tick(300); tick(100, 50)
check(g2.rec.ammo == 8, "nao atira com o companheiro na frente")
buddy.z.x = 10504
tick(300); tick(100, 50)
check(g2.rec.ammo < 8, "companheiro saiu da linha: atira")
-- muitos zumbis: nao atira em voce
fresh()
player.x, player.y = 10600, 10607
local g3 = hostile(10600, 10600, { archetype = "atirador" })
g3.rec.firearm, g3.rec.ammo = "Base.Pistol", 8
for i = 1, 5 do T.newZombie(10590 + i, 10590, 0) end
check(not Rem.Ranged.worthTheNoise(g3, player, T.clock), "com 5 zumbis por perto nao atira em voce (atrairia a horda)")
g3.z.hp = g3.rec.maxHealth * 0.3
check(Rem.Ranged.worthTheNoise(g3, player, T.clock), "...a menos que esteja desesperado")
-- pente e recarga
fresh()
local g4 = hostile(10700, 10700, { archetype = "atirador" })
g4.rec.firearm, g4.rec.ammo = "Base.Pistol", 20
local z1 = T.newZombie(10700, 10706, 0)
for _ = 1, 8 do Rem.Ranged.shoot(g4, z1, 6, T.clock) end
check(g4.nextShot - T.clock >= Rem.Ranged.CFG.RELOAD_MS, "8 tiros: recarrega (pausa)")
-- municao nao regenera e repoe do estoque
local rec4 = g4.rec
local ammo0 = rec4.ammo
T.fire("EveryHours")
Rem.emit("worldHour", 1)
check(rec4.ammo == ammo0, "municao nao regenera sozinha")

realPrint("78) B2 Municao do estoque")
fresh()
local dH = T.addBuilding(7999, 11000, 11000, 8, 6)
for i = 11000, 11007 do for j = 11000, 11005 do T.indoorSq[i .. "," .. j] = true; T.sqBuilding[i .. "," .. j] = dH end end
local box = T.addObject(11002, 11002, 0, "container", { type = "fridge" })
local gM = Rem.createGroup("sobreviventes", 11004, 11003, "7999", 2, dH)
player.x, player.y = 11004, 11030
Rem.emit("sceneUpdate", player, T.clock)
box.container:AddItem("Base.Bullets9mmBox")
local function boxes() local n = 0 for _, it in ipairs(box.container.items) do if it.id == "Base.Bullets9mmBox" then n = n + 1 end end return n end
local boxes0 = boxes()
local mil = Rem.materialize(Rem.getPerson(gM.members[1]))
mil.rec.firearm, mil.rec.ammo = "Base.Pistol", 1
mil.z.x, mil.z.y = 11004, 11003
Rem.emit("sceneUpdate", player, T.clock)
check(mil.rec.ammo == 1 + Rem.Ranged.CFG.ROUNDS_PER_BOX and boxes() == boxes0 - 1, "em casa: pega uma caixa de municao do estoque")

realPrint("79) B3 Assalto")
SandboxVars.Remanescentes.RaiderMugging = nil
fresh()
player.x, player.y = 11200, 11206
player.weapon, player.bag = { id = "Base.Axe" }, { id = "Base.Bag_Schoolbag" }
local boss = hostile(11200, 11200, { archetype = "brigao" })
boss.nextAttack = 0
clearParts()
tick(300); tick(250, 8)
local E = Rem.Mugging.of(boss)
check(E and E.stage == "demand" and T.saidPrefix(boss.z, "IGUI_Rem_Bark_demand_"), "te reconhece e EXIGE (larga a mochila e a arma)")
player.x, player.y = 11200, 11203
tick(250, 20)
check(damage() == 0, "durante a exigencia nao ataca")
-- obedece: larga tudo no chao
T.dropItem(11200, 11203, "Base.Axe"); T.dropItem(11200, 11203, "Base.Bag_Schoolbag")
player.weapon, player.bag = nil, nil
tick(300)
check(E.stage == "truce" and T.saidPrefix(boss.z, "IGUI_Rem_Bark_let_go_"), "obedeceu: deixam voce ir")
player.x, player.y = 11200, 11215
boss.z.x, boss.z.y = 11200, 11203.5
tick(300); tick(300)
local carried = boss.rec.carry and #boss.rec.carry or 0
check(carried == 2 and #(T.worldItems["11200,11203"] or {}) == 0, "pegam o que voce largou no chao")
player.x, player.y = 11200, 11205
tick(250, 10)
check(not (select(1, Rem.findEnemy(boss, T.clock)) == player), "tregua: te ignoram por um tempo")
-- ir embora
fresh()
player.x, player.y = 11300, 11306
player.weapon = { id = "Base.Axe" }
local b2 = hostile(11300, 11300)
tick(300); tick(250, 8)
local E2 = Rem.Mugging.of(b2)
check(E2 and E2.stage == "demand", "(cenario) exigindo")
player.x, player.y = 11300, 11325
tick(300)
check(E2.stage == "truce", "voce foi embora: deixam ir")
-- reagir
fresh()
player.x, player.y = 11400, 11406
player.weapon = { id = "Base.Axe" }
local b3 = hostile(11400, 11400)
tick(300); tick(250, 8)
local E3 = Rem.Mugging.of(b3)
T.fire("OnHitZombie", b3.z, player, nil, nil)
check(E3.stage == "fight", "voce reagiu: briga")
-- enrolar
fresh()
player.x, player.y = 11500, 11506
player.weapon = { id = "Base.Axe" }
local b4 = hostile(11500, 11500)
tick(300); tick(250, 8)
local E4 = Rem.Mugging.of(b4)
tick(1000, 16)
check(E4.stage == "fight", "prazo acabou com voce perto: briga")

realPrint("80) B3 Moral e rendicao")
fresh()
player.x, player.y = 11600, 11606
player.weapon = { id = "Base.Axe" }
local gang = Rem.createGroup("saqueadores", 11600, 11600, nil, 3)
local mem = {}
for _, id in ipairs(gang.members) do
    local n = Rem.materialize(Rem.getPerson(id))
    n.z.fx, n.z.fy = 0, 1
    n.nextAttack = T.clock + 9999999
    table.insert(mem, n)
end
tick(300); tick(250, 8)
local EG = Rem.Mugging.of(mem[1])
check(EG and EG.stage == "demand", "(cenario) grupo exigindo")
T.fire("OnHitZombie", EG.leader.z, player, nil, nil)
local leader = EG.leader
leader.z:Kill(player)
check(EG.stage == "rout" and T.count(Rem.active) >= 2, "lider caiu: os outros fogem")
local weak = nil
for _, n in ipairs(mem) do if n ~= leader and Rem.active[n.z] then weak = n end end
weak.z.hp = weak.rec.maxHealth * 0.2
weak.z.x, weak.z.y = player.x, player.y - 2
tick(300)
check(weak.rec.surrendered and weak.rest == "sit" and T.saidPrefix(weak.z, "IGUI_Rem_Bark_surrender_"), "ferido e encurralado: se rende")
check(not Rem.isHostileToPlayer(weak), "rendido nao e hostil")
player.x, player.y = weak.z.x, weak.z.y + 30
tick(300)
check(not weak.rec.surrendered, "voce se afastou: ele levanta e vai embora")

realPrint("81) B4 Corpo humano")
fresh()
local body = Rem.spawn(11800, 11800, 0, { faction = "civis" })
body.z.becomeCrawler = true
body.z.crawling = true
tick(300)
check(not body.z.becomeCrawler and not body.z.crawling and body.z.canWalk, "perna ferida: nao vira rastejante")
body.z.voicePlaying = "MaleZombieVoiceA"
tick(20)
check(body.z.voicePlaying == nil and (body.z.voiceStopped or 0) > 0, "gemido de zumbi e cortado")

fresh()
Rem.dismissAll()
