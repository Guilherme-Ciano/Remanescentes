-- Fase C: linha do tempo, zona de graca, populacao de passagem, eventos de rua, infeccao.
local T = ...
local Rem = Remanescentes
local check, tick = T.check, T.tick
local player, realPrint = T.player, T.print
local TL, AM, IN = Rem.Timeline, Rem.Ambient, Rem.Infection

local tl = Rem.getStore().timeline
local function setDay(d) tl.startHours = Rem.worldHours() - 24 * d end
local function fresh()
    Rem.dismissAll(); T.clearZombies(); Rem.hunting = {}
    Rem.Mugging.enc = {}
    T.daylight = 1.0
end
local function liveZombies()
    local n = 0
    for _, z in ipairs(T.zombies) do if z.inWorld and not z.dead and not Rem.active[z] then n = n + 1 end end
    return n
end

SandboxVars.Remanescentes.RaiderMugging = false

realPrint("90) C1 Linha do tempo")
setDay(0)
local seen = {}
for _ = 1, 200 do seen[Rem.randomFaction()] = true end
check(not seen.saqueadores, "dia 0: nenhum grupo de saqueadores e sorteado")
check(TL.raiderFactor() == 0 and TL.militiaFactor() < 1 and TL.density() == 1, "dia 0: caos civil, milicias se formando, rua cheia")
setDay(5)
check(TL.raiderFactor() > 0 and TL.raiderFactor() < 1, "dia 5: primeiros saqueadores")
setDay(30)
check(TL.raiderFactor() == 1 and TL.density() < 0.5, "dia 30: saqueadores comuns, ruas mais vazias")
setDay(0)
SandboxVars.TimeSinceApo = 3
check(TL.day() >= 60 and TL.raiderFactor() == 1, "sandbox '2 meses depois': ja comeca no dia 60")
SandboxVars.TimeSinceApo = nil
SandboxVars.Remanescentes.CollapsePace = 3
setDay(3)
check(TL.day() >= 6, "ritmo rapido: o tempo do colapso anda 2x")
SandboxVars.Remanescentes.CollapsePace = nil
SandboxVars.Remanescentes.RaiderStartDay = 10
setDay(6)
check(TL.raiderFactor() == 0, "dia de inicio dos saqueadores configuravel")
SandboxVars.Remanescentes.RaiderStartDay = nil

realPrint("91) C2 Zona de graca")
fresh()
setDay(1)
tl.startX, tl.startY = 12000, 12000
T.addBuilding(12001, 12040, 12000, 8, 8)
local g = Rem.seedGroupNear(12000, 12000, 0, 100, "saqueadores")
check(g and g.faction ~= "saqueadores", "nos primeiros dias, nada hostil nasce perto de onde voce comecou (" .. tostring(g and g.faction) .. ")")
setDay(4)
check(not TL.protects(12040, 12000), "depois da graca, a protecao acaba")
setDay(1)
check(not TL.protects(12400, 12000), "longe do inicio nao ha protecao")
-- saqueadores existentes ficam quietos antes do dia deles
local gang = Rem.createGroup("saqueadores", 12300, 12300, nil, 3)
local victims = Rem.createGroup("civis", 12350, 12300, nil, 2)
local raided = false
for _ = 1, 120 do
    gang.supplies, gang.activity, gang.target = 0, "home", nil
    Rem.simulateWorld(1)
    if gang.activity == "raid" then raided = true end
end
check(not raided, "antes do dia dos saqueadores, nenhum ataque a outros grupos")
setDay(30)
raided = false
for _ = 1, 120 do
    gang.supplies, gang.activity, gang.target = 0, "home", nil
    victims.supplies = 5
    Rem.simulateWorld(1)
    if gang.activity == "raid" then raided = true end
end
check(raided, "(controle) no dia 30, nas mesmas condicoes, atacam")
setDay(1)
-- com o tempo, grupos de saqueadores novos se formam
setDay(25)
local chance0 = TL.CFG.LATE_RAIDER_CHANCE
TL.CFG.LATE_RAIDER_CHANCE = 100
player.x, player.y = 12000, 12000
T.addBuilding(12002, 12250, 12000, 8, 8)
local before = 0
for _, gg in pairs(Rem.getStore().groups) do if gg.faction == "saqueadores" then before = before + 1 end end
T.fire("EveryDays")
local after = 0
for _, gg in pairs(Rem.getStore().groups) do if gg.faction == "saqueadores" then after = after + 1 end end
check(after > before, "dia 25: um grupo novo de saqueadores se formou")
TL.CFG.LATE_RAIDER_CHANCE = chance0

realPrint("92) C3 Populacao de passagem")
fresh()
setDay(0)
SandboxVars.Remanescentes.AmbientDensity = 100
player.x, player.y = 13000, 13000
local kind, list = AM.trySpawn(player, T.clock, "walker")
local w = list and list[1]
check(w and w.rec.transient and w.rec.ambient == "walker", "civil de passagem criado")
local d0 = Rem.dist(w.z, player)
check(d0 >= AM.CFG.SPAWN_MIN - 1 and d0 <= AM.CFG.SPAWN_MAX + 1, "nasce longe da sua vista (" .. math.floor(d0) .. " tiles)")
check(Rem.dist2(w.rec.destX, w.rec.destY, player.x, player.y) > 20, "o destino fica do outro lado (ele cruza a area)")
tick(300)
check(w.z.path and math.floor(w.z.path[1]) == w.rec.destX, "anda para o destino")
local zBefore = liveZombies()
local _, rl = AM.trySpawn(player, T.clock, "runner")
check(rl and rl[1].rec.gait == "run" and liveZombies() > zBefore, "civil fugindo, correndo, com zumbis atras")
local _, fl = AM.trySpawn(player, T.clock, "family")
check(fl and #fl >= 2 and fl[2].rec.followId == fl[1].rec.id, "familia: os outros seguem o lider")
fl[2].z.x, fl[2].z.y = fl[1].z.x + 6, fl[1].z.y
tick(300)
check(fl[2].z.path and math.abs(fl[2].z.path[1] - fl[1].z.x) < 1, "quem ficou para tras vai ate o lider")
-- some quando se afasta (nao volta ao papel)
local id = w.rec.id
w.z.x, w.z.y = player.x + 100, player.y
tick(1600)
check(Rem.getPerson(id) == nil, "se afastou: some (nao vira grupo nem fica no save)")
-- chegou ao destino longe de voce: some
local _, wl = AM.trySpawn(player, T.clock, "walker")
local w2 = wl[1]
w2.rec.destX, w2.rec.destY = math.floor(player.x + 50), math.floor(player.y)   -- destino longe de voce
w2.z.x, w2.z.y = w2.rec.destX, w2.rec.destY
local id2 = w2.rec.id
tick(300)
check(Rem.getPerson(id2) == nil, "chegou ao destino longe de voce: some")
-- limite e densidade
fresh()
local maxActive = SandboxVars.Remanescentes.MaxActive
SandboxVars.Remanescentes.MaxActive = 3
AM.trySpawn(player, T.clock, "walker")
local k3 = AM.trySpawn(player, T.clock, "walker")
check(k3 == nil, "respeita o limite de sobreviventes presentes (reserva vagas para os grupos)")
SandboxVars.Remanescentes.MaxActive = maxActive
setDay(0)
local cap0 = math.floor(AM.CFG.MAX_TRANSIENTS * TL.density() + 0.5)
setDay(40)
local cap40 = math.floor(AM.CFG.MAX_TRANSIENTS * TL.density() + 0.5)
check(cap0 > cap40, "dia 0 tem mais gente na rua que o dia 40 (" .. cap0 .. " x " .. cap40 .. ")")
setDay(0)
-- saqueador de passagem: nunca na zona de graca
fresh()
setDay(1)
tl.startX, tl.startY = player.x, player.y
local kr, rlist = AM.trySpawn(player, T.clock, "raider")
check(rlist and rlist[1].rec.faction == "civis", "zona de graca: saqueador de passagem vira civil")
setDay(20)
tl.startX = player.x + 5000
local _, rlist2 = AM.trySpawn(player, T.clock, "raider")
check(rlist2 and rlist2[1].rec.faction == "saqueadores", "depois: saqueadores rondando")
setDay(0)
-- sobrou no papel e o tempo acabou: some
fresh()
local _, pl = AM.trySpawn(player, T.clock, "walker")
local paperRec = pl[1].rec
Rem.dematerialize(pl[1])
T.worldHours = T.worldHours + AM.CFG.LIFETIME_HOURS + 1
AM.cleanup()
check(Rem.getPerson(paperRec.id) == nil, "passagem que ficou no papel some depois do tempo dela")

realPrint("93) C3 Socorro")
fresh()
local _, hl = AM.trySpawn(player, T.clock, "help")
local helpN = hl[1]
check(Rem.healthFraction(helpN) < 0.5 and T.saidPrefix(helpN.z, "IGUI_Rem_Bark_help_"), "ferido gritando por socorro")
check(liveZombies() >= 2, "com zumbis em volta")
local rep0 = Rem.getRep("f:civis")
T.clearZombies({ [helpN.z] = true })
player.x, player.y = helpN.z.x + 3, helpN.z.y
tick(300)
check(T.saidPrefix(helpN.z, "IGUI_Rem_Bark_thanks_") and Rem.getRep("f:civis") == rep0 + AM.CFG.HELP_REP, "salvo: agradece e a reputacao dos civis sobe")
check(helpN.rec.ambient == "walker", "depois vai embora")

realPrint("94) C5 Eventos de rua")
fresh()
player.x, player.y = 13500, 13500
local dsq = getCell():getGridSquare(13536, 13500, 0)
local door = T.addObject(13538, 13500, 0, "IsoDoor", { exterior = true })
local kl = AM.SPAWN.knock(player, dsq)
local kn = kl[1]
tick(300)
kn.z.x, kn.z.y = 13538.5, 13500.5
T.sounds = {}
tick(300)
check(T.saidPrefix(kn.z, "IGUI_Rem_Bark_knock_") and #T.sounds > 0, "batendo na porta: grita e faz barulho (atrai zumbis)")
local bsq = getCell():getGridSquare(13460, 13500, 0)
local win = T.addObject(13462, 13500, 0, "IsoWindow", { exterior = true })
local bl = AM.SPAWN.boarder(player, bsq)
local bn = bl[1]
bn.z.x, bn.z.y = 13462.5, 13500.5
tick(300); tick(1000, 20)
check(win.barricade and win.barricade.planks >= 2, "pregando tabuas: a janela fica barricada de verdade (" .. tostring(win.barricade and win.barricade.planks) .. ")")
local _, fg = AM.trySpawn(player, T.clock, "fight")
check(fg and Rem.npcsHostile(fg[1], fg[2]), "briga por comida: os dois sao inimigos entre si")
fg[1].nextAttack, fg[2].nextAttack = 0, 0
local hp1, hp2 = fg[1].z.hp, fg[2].z.hp
tick(300); tick(100, 30)
check(fg[1].z.hp < hp1 or fg[2].z.hp < hp2, "e brigam de verdade")
fg[2].z.hp = fg[2].rec.maxHealth * 0.3
tick(1600)   -- o fim da briga e decidido na atualizacao de cena (a cada 1,5 s)
check(not fg[1].rec.foeId and not fg[2].rec.foeId, "um perdeu: a briga acaba")
local _, sl = AM.trySpawn(player, T.clock, "scavenger")
check(sl and sl[1].rec.faction == "sobreviventes" and #sl[1].rec.carry > 0, "catadores carregando suprimentos")
T.worldSounds = {}
local zb = liveZombies()
AM.trySpawn(player, T.clock, "gunshot")
check(#T.worldSounds == 1 and Rem.dist2(T.worldSounds[1].x, T.worldSounds[1].y, player.x, player.y) >= 39, "tiro ao longe: som real longe de voce")

realPrint("95) C4 Mordidos viram zumbis")
SandboxVars.Remanescentes.AmbientDensity = 0   -- (passagem criaria zumbis extras e baguncaria as contagens)
fresh()
SandboxVars.Remanescentes.NPCInfectionChance = 100
local victim = Rem.spawn(13700, 13700, 0, { faction = "civis", mode = "stay" })
local biter = T.newZombie(13700, 13701, 0)
Rem.emit("zombieHitNPC", victim, biter, T.clock)
check(victim.rec.infectedAt and T.saidPrefix(victim.z, "IGUI_Rem_Bark_bitten_"), "mordido: infectado e avisa")
local body = victim.z
T.worldHours = victim.rec.infectedAt + victim.rec.turnAfter * 0.6
Rem.emit("worldHour", 1)
check(victim.rec.sick and T.saidPrefix(victim.z, "IGUI_Rem_Bark_sick_"), "passa mal no meio do caminho")
T.worldHours = victim.rec.infectedAt + victim.rec.turnAfter + 0.1
local vid = victim.rec.id
Rem.emit("worldHour", 1)
check(Rem.getPerson(vid) == nil and Rem.active[body] == nil, "virou zumbi: deixou de ser sobrevivente")
check(body.useless == false and body.noTeeth == false and body.vars.RemNPC == false, "o corpo agora e um zumbi de verdade (morde)")
check(body.skin and body.skin:find("ZedBody"), "pele de zumbi (" .. tostring(body.skin) .. ")")
-- fora de cena
local far = Rem.newPerson({ faction = "civis", x = 14500, y = 14500 })
IN.infect(far, T.worldHours)
T.worldHours = T.worldHours + far.turnAfter + 0.1
Rem.emit("worldHour", 1)
check(Rem.getPerson(far.id) == nil and #Rem.getStore().turned >= 1, "longe de voce: vira zumbi no papel")
player.x, player.y = 14500, 14520
local zt = liveZombies()
Rem.emit("sceneUpdate", player, T.clock)
check(liveZombies() == zt + 1, "voce chega perto: o zumbi esta la (mesma roupa)")
-- morto por zumbis levanta
fresh()
local dead = Rem.spawn(13800, 13800, 0, { faction = "civis", mode = "stay" })
local outfit = dead.rec.outfit
Rem.emit("zombieHitNPC", dead, biter, T.clock)
dead.z:Kill(nil)
T.addCorpse(13800, 13800, outfit)
local zd = liveZombies()
T.clock = T.clock + IN.CFG.REANIMATE_MS[2] + 10
Rem.emit("sceneUpdate", player, T.clock)
check(#(T.deadBodies["13800,13800"] or {}) == 0 and liveZombies() == zd + 1, "morto por zumbis: o corpo levanta como zumbi")
-- desligado no sandbox
SandboxVars.Remanescentes.NPCsTurn = false
local safe = Rem.spawn(13900, 13900, 0, { faction = "civis", mode = "stay" })
Rem.emit("zombieHitNPC", safe, biter, T.clock)
check(not safe.rec.infectedAt, "sandbox NPCsTurn desligado: ninguem e infectado")
SandboxVars.Remanescentes.NPCsTurn = nil
SandboxVars.Remanescentes.NPCInfectionChance = nil

SandboxVars.Remanescentes.AmbientDensity = 0
SandboxVars.Remanescentes.RaiderMugging = nil
setDay(0)
fresh()
