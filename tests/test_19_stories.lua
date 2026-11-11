-- Historias (Rem_Stories): mascate, enlutado, emboscada, refem e cerco com mensageiro.
local T = ...
local Rem = Remanescentes
local check, tick = T.check, T.tick
local player, realPrint = T.player, T.print
local AM, ST, IA, BD, TL, MG = Rem.Ambient, Rem.Stories, Rem.Interact, Rem.Bonds, Rem.Timeline, Rem.Mugging

local tl = Rem.getStore().timeline
local function setDay(d) tl.startHours = Rem.worldHours() - 24 * d end
local function fresh()
    Rem.dismissAll(); T.clearZombies(); Rem.hunting = {}
    MG.enc = {}
    local s = Rem.getStore()
    s.reputation, s.siege, s.siegeLastH, s.mapMarks, s.knownGroups, s.quests = {}, nil, nil, {}, {}, {}
    player.inv.items = {}
    player.weapon, player.bag = nil, nil
    Rem.Banter.queue = {}
end
local function scene() Rem.emit("sceneUpdate", player, Rem.nowMs()) end
local function zombiesNear(x, y, r)
    local n = 0
    for _, z in ipairs(T.zombies) do
        if z.inWorld and not z.dead and not Rem.active[z] and Rem.dist2(z.x, z.y, x, y) <= r then n = n + 1 end
    end
    return n
end
local function ofKind(list, kind)
    local out = {}
    for _, npc in ipairs(list or {}) do if npc.rec.ambient == kind then table.insert(out, npc) end end
    return out
end
SandboxVars.Remanescentes.MaxActive = 20
SandboxVars.Remanescentes.RaiderMugging = true
tl.startX, tl.startY = 0, 0     -- longe: sem zona de graca aqui

realPrint("160) Pesos dos eventos novos pela linha do tempo")
fresh()
setDay(0)
local w = AM.weights(38000, 38000)
check(w.trader == 0 and w.ambush == 0 and w.hostage == 0 and w.mourner > 0, "dia 0: sem mascate, emboscada ou refem; luto ja existe")
setDay(30)
w = AM.weights(38000, 38000)
check(w.trader > 0 and w.ambush > 0 and w.hostage > 0, "mais tarde: todos acontecem")
tl.startX, tl.startY = 38000, 38000
setDay(1)
check(AM.weights(38000, 38000).ambush == 0, "nunca emboscada na zona de graca")
tl.startX, tl.startY = 0, 0
setDay(30)

realPrint("161) Mascate")
fresh()
player.x, player.y = 38000, 38000
local kind, list = AM.trySpawn(player, Rem.nowMs(), "trader")
local trader = list and list[1]
check(kind == "trader" and trader and trader.rec.faction == "errantes" and #trader.rec.carry >= ST.CFG.TRADER_GOODS[1],
    "errante com a mochila cheia de coisas para trocar")
check(not Rem.isHostileToPlayer(trader) and IA.canTalk(trader), "da para conversar com ele")
trader.z.said = {}
tick(300, 3)
check(trader.moving == true and #trader.z.said == 0, "longe de voce, segue viagem")
player.x, player.y = trader.z.x + 4, trader.z.y
tick(300, 3)
check(not trader.moving and T.saidPrefix(trader.z, "IGUI_Rem_Bark_trader_"), "voce chega perto: ele para e oferece troca")
check(#IA.theirItems(trader) == #trader.rec.carry + #trader.rec.pockets and #trader.rec.carry >= ST.CFG.TRADER_GOODS[1], "a troca usa o que ele carrega")
T.clock = T.clock + ST.CFG.TRADER_WAIT_MS + 1000
tick(300, 3)
check(trader.moving == true, "cansou de esperar: segue viagem")

realPrint("162) Enlutado")
fresh()
player.x, player.y = 38200, 38000
kind, list = AM.trySpawn(player, Rem.nowMs(), "mourner")
local mourner = list and list[1]
check(mourner and mourner.rec.griefFor and Rem.Persona.mood(mourner.rec, mourner) == "luto", "alguem de luto por quem perdeu")
tick(300, 4)
check(mourner.rest == "sit", "sentado, sozinho")
T.clock = T.clock + ST.CFG.MOURN_MS + 1000
tick(300, 2)
check(mourner.rest == nil and mourner.rec.ambient == "walker", "depois de um tempo levanta e vai embora")

realPrint("163) Emboscada")
fresh()
player.x, player.y = 38400, 38000
local sq = T.square(38420, 38000, 0)
list = AM.SPAWN.ambush(player, sq)
local decoy = ofKind(list, "ambush")[1]
local hidden = ofKind(list, "ambush_wait")
check(decoy and #hidden >= 1, "um 'ferido' e comparsas escondidos (" .. #hidden .. ")")
check(decoy.rec.faction == "saqueadores" and decoy.rec.disguised and not Rem.isHostileToPlayer(decoy), "o 'ferido' e saqueador disfarcado, ainda nao hostil")
local civilLook = false
for _, o in ipairs(Rem.FACTIONS.civis.outfits) do if decoy.rec.outfit == o then civilLook = true end end
check(civilLook, "com roupa de civil")
check(T.saidPrefix(decoy.z, "IGUI_Rem_Bark_help_"), "pedindo socorro")
check(zombiesNear(38420, 38000, 12) == 0, "a pista: nenhum zumbi em volta dele")
Rem.changeRep("f:saqueadores", -5, "teste")   -- a reputacao mexe: o disfarce nao pode cair por isso
check(decoy.rec.disguised and not Rem.isHostileToPlayer(decoy), "mudanca de reputacao nao desfaz o disfarce")
local civ = Rem.spawn(38421, 38001, 0, { faction = "civis", mode = "stay" })
check(not Rem.npcsHostile(civ, decoy), "os outros tambem nao sabem quem ele e")
Rem.dismiss(civ)
tick(300, 4)
check(decoy.rest == "sit" and hidden[1].sneaking == true, "ele fica sentado; os comparsas, agachados")
player.x, player.y = decoy.z.x + 3, decoy.z.y
player.weapon = T.newWeapon("Base.Axe")     -- armado (sem arma nem mochila eles so te mandam embora)
decoy.z.said = {}
tick(300, 2)
local allHostile = Rem.isHostileToPlayer(decoy) and decoy.rec.ambient == "raider" and not decoy.rec.disguised
for _, m in ipairs(hidden) do allHostile = allHostile and Rem.isHostileToPlayer(m) and not m.rec.disguised end
check(allHostile, "voce chega perto: a mascara cai, todos viram saqueadores")
check(T.saidPrefix(decoy.z, "IGUI_Rem_Bark_ambush_"), "'Agora!'")
check(MG.of(decoy) ~= nil and MG.of(decoy).stage == "demand", "e o assalto comeca (exigem as suas coisas)")
check(decoy.rest == nil, "o 'ferido' levanta")
-- bater nele antes de chegar perto tambem revela
fresh()
player.x, player.y = 38600, 38000
list = AM.SPAWN.ambush(player, T.square(38620, 38000, 0))
decoy = ofKind(list, "ambush")[1]
decoy.z.hp = decoy.z.hp - 0.3
tick(300, 2)
check(Rem.isHostileToPlayer(decoy), "ferir o 'ferido' de longe tambem revela")
-- ninguem cai: desistem
fresh()
player.x, player.y = 38800, 38000
list = AM.SPAWN.ambush(player, T.square(38830, 38000, 0))
decoy = ofKind(list, "ambush")[1]
T.clock = T.clock + ST.CFG.AMBUSH_TIMEOUT_MS + 1000
tick(300, 2)
check(not decoy.rec.disguised and decoy.rec.ambient ~= "ambush", "se ninguem cair na cilada, desistem")
tl.startX, tl.startY = 39000, 38000
setDay(1)
list = AM.SPAWN.ambush(player, T.square(39010, 38000, 0))
check(list and #list == 1 and list[1].rec.ambient == "walker" and list[1].rec.faction == "civis", "na zona de graca vira um civil comum")
tl.startX, tl.startY = 0, 0
setDay(30)

realPrint("164) Refem")
fresh()
SandboxVars.Remanescentes.RaiderMugging = false
player.x, player.y = 39200, 38000
list = AM.SPAWN.hostage(player, T.square(39225, 38000, 0))
local captive = ofKind(list, "hostage")[1]
local captors = ofKind(list, "captor")
check(captive and #captors == 2 and captive.rec.captive, "um civil rendido e dois saqueadores de guarda")
check(not Rem.npcsHostile(captors[1], captive) and Rem.isHostileToPlayer(captors[1]), "eles nao batem no refem; em voce, sim")
tick(300, 4)
check(captive.rest == "sit" and ST.guarded(captive), "o refem fica sentado enquanto houver captor por perto")
player.x, player.y = captive.z.x + 8, captive.z.y
captive.z.said = {}
captive.barkAt = {}
tick(300, 2)
check(T.saidPrefix(captive.z, "IGUI_Rem_Bark_hostage_"), "pede ajuda quando te ve")
local repC = Rem.getRep("f:civis")
for _, c in ipairs(captors) do Rem.dismiss(c) end
captive.z.said = {}
tick(300, 2)
check(not captive.rec.captive and captive.rest == nil and captive.rec.ambient == "freed", "sem os captores: livre")
check(T.saidPrefix(captive.z, "IGUI_Rem_Bark_freed_"), "agradece e se oferece para ir com voce")
check(captive.rec.bond == BD.DELTA.rescued and captive.rec.mem[1].k == "rescued" and Rem.getRep("f:civis") == repC + ST.CFG.HOSTAGE_REP,
    "vinculo forte e reputacao com os civis")
player.x = captive.z.x + 10
tick(300, 3)
check(captive.moving == true, "fica perto de voce por um tempo")
captive.rec.personality.lealdade = 5
check(IA.joinScore(captive) >= IA.CFG.JOIN_THRESHOLD, "aceita seguir voce (quase sempre)")
local okJ = IA.askJoin(captive)
check(okJ and captive.rec.faction == "aliados" and captive.rec.mode == "follow", "recrutado")
-- sem voce por perto: so vai embora
fresh()
player.x, player.y = 39400, 38000
list = AM.SPAWN.hostage(player, T.square(39430, 38000, 0))
captive = ofKind(list, "hostage")[1]
for _, c in ipairs(ofKind(list, "captor")) do Rem.dismiss(c) end
tick(300, 2)
check(captive.rec.ambient == "walker" and (captive.rec.bond or 0) == 0, "libertado por outro motivo, longe de voce: foge, sem divida com voce")
SandboxVars.Remanescentes.RaiderMugging = true

realPrint("165) Cerco: mensageiro, horda e resgate")
fresh()
local def = T.addBuilding(39601, 39600, 38000, 10, 8)
for i = 39600, 39609 do for j = 38000, 38007 do T.indoorSq[i .. "," .. j] = true; T.sqBuilding[i .. "," .. j] = def end end
local g = Rem.createGroup("civis", 39605, 38004, "39601", 4, def)
g.supplies = 50
player.x, player.y = 39605 - 120, 38004
check(#ST.siegeCandidates(player) == 0, "grupo que voce nao conhece nao pede ajuda")
Rem.getStore().knownGroups[g.id] = true
check(#ST.siegeCandidates(player) == 0, "nem grupo que nao gosta de voce o bastante")
Rem.changeRep(g.id, 30, "teste")
check(#ST.siegeCandidates(player) == 1, "grupo conhecido e amigo, nem perto nem longe demais: candidato")
player.x = 39605 - 20
check(#ST.siegeCandidates(player) == 0, "nao comeca com voce ja na porta")
player.x = 39605 - 120
local realRand = ZombRand
ZombRand = function(a, b) return b and a or 0 end
ST.hourly()
ZombRand = realRand
local s = Rem.getStore().siege
check(s and s.group == g.id and s.messenger, "o cerco comeca")
scene()
local messenger = nil
for _, npc in pairs(Rem.active) do if npc.rec.ambient == "messenger" then messenger = npc end end
check(messenger and messenger.rec.faction == g.faction and not Rem.getStore().siege.messenger, "um mensageiro do grupo vem ate voce")
tick(300, 2)
check(messenger.running == true, "correndo")
messenger.z.x, messenger.z.y = player.x + 2, player.y
messenger.z.said = {}
tick(300, 2)
check(T.saidPrefix(messenger.z, "IGUI_Rem_Bark_siege_call_"), "'Estao atacando a nossa casa!'")
local mark = nil
for _, m in ipairs(Rem.getStore().mapMarks) do if m.id:find("siege:") then mark = m end end
check(mark and mark.x == g.home.x and s.told, "e marca a casa no seu mapa")
check(messenger.rec.ambient == "walker" and messenger.rec.destX == math.floor(g.home.x), "depois volta correndo para casa")
check(zombiesNear(g.home.x, g.home.y, 20) == 0 and not s.spawned, "(a horda so aparece quando voce chega)")
player.x, player.y = g.home.x, g.home.y + 12
scene()
local horde = zombiesNear(g.home.x, g.home.y, 20)
check(s.spawned and horde >= ST.CFG.SIEGE_ZOMBIES[1], "chegando la: a horda esta em volta da casa (" .. horde .. ")")
local inside = 0
for _, z in ipairs(T.zombies) do
    if z.inWorld and not Rem.active[z] and z.x >= g.home.x1 and z.x <= g.home.x2 and z.y >= g.home.y1 and z.y <= g.home.y2 then inside = inside + 1 end
end
check(inside == 0, "do lado de fora, nao dentro da casa")
local member = Rem.materialize(Rem.getPerson(g.members[1]))
member.z.said = {}
T.clock = T.clock + ST.CFG.SIEGE_SETTLE_MS + 100
scene()
check(Rem.getStore().siege ~= nil and T.saidPrefix(member.z, "IGUI_Rem_Bark_siege_help_"), "com zumbis la, o cerco continua e os moradores pedem ajuda")
local rep0 = Rem.getRep(g.id)
local other = Rem.getPerson(g.members[2])
T.clearZombies()
member.z.said = {}
T.clock = T.clock + 200
scene()
check(Rem.getStore().siege == nil and Rem.getRep(g.id) == rep0 + ST.CFG.SIEGE_REP, "horda limpa: cerco vencido, reputacao sobe")
check(T.saidPrefix(member.z, "IGUI_Rem_Bark_siege_won_"), "'A casa aguentou por sua causa'")
check(member.rec.bond == BD.DELTA.sieged and other.bond == BD.DELTA.sieged * BD.CFG.GROUP_SHARE, "o grupo inteiro lembra de voce")
ST.hourly()
check(Rem.getStore().siege == nil, "nao ha outro cerco logo em seguida")

realPrint("166) Cerco sem ajuda")
fresh()
def = T.addBuilding(39801, 39800, 38000, 10, 8)
g = Rem.createGroup("civis", 39805, 38004, "39801", 5, def)
player.x, player.y = 39805 - 200, 38004
ST.startSiege(g).messenger = false
local before = #g.members
T.worldHours = T.worldHours + ST.CFG.SIEGE_HOURS + 1
ST.hourly()
check(Rem.getStore().siege == nil and #g.members < before and #g.members >= before - ST.CFG.SIEGE_LOSSES[2], "ninguem ajudou: o grupo perde gente (" .. before .. " -> " .. #g.members .. ")")
local griever = Rem.getPerson(g.members[1])
check(griever.griefUntil ~= nil, "e quem sobrou fica de luto")
local small = Rem.createGroup("civis", 40005, 38004, "40001", 2, T.addBuilding(40001, 40000, 38000, 10, 8))
ST.startSiege(small).messenger = false
T.worldHours = T.worldHours + ST.CFG.SIEGE_HOURS + 1
ST.hourly()
check(Rem.getStore().groups[small.id] == nil and Rem.getStore().nests and Rem.getStore().nests["40001"] ~= nil, "grupo pequeno demais: a casa cai e vira ninho")
SandboxVars.Remanescentes.MaxActive = T.defaults().MaxActive
SandboxVars.Remanescentes.RaiderMugging = false
fresh()
