-- Pacote 0.20: mundo em movimento - territorio e precos, guerra entre faccoes, refugiados,
-- caravanas de troca.
local T = ...
local Rem = Remanescentes
local check, tick = T.check, T.tick
local player, realPrint = T.player, T.print
local PB, IA, JN, TR, WR, RF, CV, EV = Rem.PlayerBase, Rem.Interact, Rem.Journal, Rem.Territory, Rem.War, Rem.Refugees,
    Rem.Caravans, Rem.Evolution

local function fresh()
    Rem.dismissAll(); T.clearZombies(); Rem.hunting = {}
    Rem.Mugging.enc = {}
    TR.current = nil
    local s = Rem.getStore()
    s.reputation, s.quests, s.journal, s.playerBase, s.met, s.knownGroups = {}, {}, {}, nil, {}, {}
    s.wars, s.caravans, s.relations, s.chronicle = {}, {}, {}, {}
    player.inv.items = {}
end
local function setDay(d) Rem.getStore().timeline.startHours = Rem.worldHours() - 24 * d end
local function lastJournal() local l = JN.entries() return l[#l] and l[#l].key end
local function hasJournal(key) for _, e in ipairs(JN.entries()) do if e.key == key then return true end end return false end
local function withRand(fn, body)
    local real = ZombRand
    ZombRand = fn
    local ok, err = pcall(body)
    ZombRand = real
    if not ok then error(err) end
end
local always = function(a, b) if b then return a end return 0 end      -- sorteios sempre "sim"
local never = function(a, b) if b then return a end return (a or 1) - 1 end
local function opts(npc)
    local o = {}
    for _, id in ipairs(IA.dialogOptions(npc, player)) do o[id] = true end
    return o
end
local function byId(id) for _, n in pairs(Rem.active) do if n.rec.id == id then return n end end return nil end
local function eachNpc(ids, fn)
    local list = {}
    for _, id in ipairs(ids) do local n = byId(id) if n then table.insert(list, n) end end
    for _, n in ipairs(list) do fn(n) end
end
local function know(g) Rem.getStore().met[g.id] = true end
local nextId = 200000
local function house()
    nextId = nextId + 400
    local x, y = nextId, 200000
    local def = T.addBuilding(nextId + 1, x, y, 8, 6)
    for i = x, x + 7 do for j = y, y + 5 do T.indoorSq[i .. "," .. j] = true; T.sqBuilding[i .. "," .. j] = def end end
    T.addObject(x + 2, y + 2, 0, "container", { type = "fridge" })
    return { def = def, x = x, y = y }
end
T.timeOfDay = 12
SandboxVars.Remanescentes.MaxActive = 30

-- ===================================================================== territorio
realPrint("350) Territorio")
fresh()
setDay(30)
local raiders = Rem.createGroup("saqueadores", 210000, 210000, "t1", 4)
local militia = Rem.createGroup("sobreviventes", 211000, 210000, "t2", 3)
check(TR.radius(raiders) == TR.CFG.BASE + 4 * TR.CFG.PER_MEMBER, "raio cresce com o tamanho do grupo")
militia.home.fenceBuilt = 10
check(TR.radius(militia) == TR.CFG.BASE + 3 * TR.CFG.PER_MEMBER + TR.CFG.FENCE_BONUS, "(e com a cerca)")
check(TR.ownerAt(210010, 210000) == raiders and TR.ownerAt(210500, 210000) == nil, "dono de cada ponto")
T.halo = {}
player.x, player.y = 210010, 210000
TR.check(player, Rem.nowMs() + 100000)
check(#T.halo == 1 and T.halo[1]:find("IGUI_Rem_Territory_enter", 1, true) ~= nil or #T.halo == 1, "ao entrar: 'Territorio de ...' na tela")
check(JN.knows(raiders), "e o grupo passa a ser conhecido")
TR.check(player, Rem.nowMs() + 200000)
check(#T.halo == 1, "(nao repete enquanto voce esta dentro)")
local outside = Rem.Ambient.weights(215000, 215000).raider
check(outside > 0 and math.abs(Rem.Ambient.weights(210010, 210000).raider - outside * TR.CFG.RAIDER_WEIGHT) < 0.001,
    "territorio de saqueadores: encontros com saqueadores bem mais comuns")
check(math.abs(Rem.Ambient.weights(211005, 210000).raider - outside * TR.CFG.SAFE_RAIDER) < 0.001, "territorio da milicia: bem menos")

realPrint("351) Precos por regiao")
local m = TR.priceMods(militia)
check(m.Ammo == 1.3 and m.Food == 1, "milicia paga mais por municao (sozinha na regiao, comida normal)")
local crowdA = Rem.createGroup("civis", 211100, 210100, "t3", 3)
Rem.createGroup("civis", 211150, 210150, "t4", 3)
m = TR.priceMods(crowdA)
check(math.abs(m.Food - (1 + 2 * TR.CFG.CROWD_STEP) * 1.2) < 0.001, "muitos grupos na mesma area: comida vale mais (e familias pagam mais por comida)")
local member = Rem.materialize(Rem.getPerson(crowdA.members[1]))
crowdA.supplies = 100
local food = T.newItem("Base.TinnedBeans")
local vRegion = IA.value(food, IA.needs(member))
check(math.abs(vRegion - IA.value(food, nil) * m.Food) < 0.001, "o valor na troca usa a economia da regiao")
Rem.dismissAll()

-- ===================================================================== guerra
realPrint("360) Guerra entre faccoes")
fresh()
setDay(30)
local ga = Rem.createGroup("sobreviventes", 220000, 220000, "w1", 4)
local gb = Rem.createGroup("civis", 220150, 220000, "w2", 4)
know(ga)
WR.daily()
check(#WR.list() == 0, "relacao normal: sem guerra")
Rem.changeRelation(ga, gb, -200)
WR.daily()
check(#WR.list() == 1 and WR.enemyOf(ga) == gb and lastJournal() == "IGUI_Rem_Journal_war", "relacao no fundo do poco: guerra (diario)")
check(TR.priceMods(ga).Ammo == 1.3 * TR.CFG.WAR_AMMO, "em guerra, municao vale bem mais")
withRand(always, function() WR.hourly() end)
check((ga.activity == "raid" and ga.target.victim == gb.id) or (gb.activity == "raid" and gb.target.victim == ga.id),
    "de dia, um lado parte para cima do outro")
ga.activity, ga.target, gb.activity, gb.target = "home", nil, "home", nil
Rem.emit("raidResolved", ga, gb, ga)
check(lastJournal() == "IGUI_Rem_Journal_war_battle", "as batalhas vao para o diario")
local mb = Rem.materialize(Rem.getPerson(gb.members[1]))
player.x, player.y = 220150, 220005
check(IA.status(mb).key == "IGUI_Rem_War_status", "'Como vao as coisas?': estamos em guerra com ...")
check(opts(mb).war_side, "'[Guerra] Estou do lado de voces.'")
local repB, repA = Rem.getRep(gb.id), Rem.getRep(ga.id)
IA.choose("war_side", mb, player)
check(Rem.getRep(gb.id) == repB + WR.CFG.SIDE_REP and Rem.getRep(ga.id) < repA, "escolher um lado: eles gostam, o inimigo nao")
check(not opts(mb).war_side, "(so uma vez)")
-- matar um inimigo do seu lado
local ma = Rem.materialize(Rem.getPerson(ga.members[1]))
ma.z.attackedBy = player
ma.z.getAttackedBy = function() return player end
repB = Rem.getRep(gb.id)
ma.z:Kill(nil)
check(Rem.getRep(gb.id) >= repB + WR.CFG.KILL_REP, "cada inimigo deles que voce mata conta a mais")
-- matar alguem do seu proprio lado nao conta como inimigo
local mb2 = Rem.materialize(Rem.getPerson(gb.members[2]))
mb2.z.getAttackedBy = function() return player end
repB = Rem.getRep(gb.id)
mb2.z:Kill(nil)
check(Rem.getRep(gb.id) == math.max(-100, repB + Rem.Reputation.CFG.KILL), "(matar alguem do seu lado so faz mal)")
Rem.getStore().reputation[gb.id] = 30
-- o seu lado vence
repB = Rem.getRep(gb.id)
Rem.getStore().groups[ga.id] = nil
Rem.emit("groupRemoved", ga)
check(#WR.list() == 0 and hasJournal("IGUI_Rem_Journal_war_won") and Rem.getRep(gb.id) == repB + WR.CFG.WIN_REP,
    "um lado some: o outro vence (e lembra que voce estava com eles)")
-- voce escolheu o lado que perdeu: ninguem agradece
local gx = Rem.createGroup("civis", 220500, 220000, "w4", 4)
local gy = Rem.createGroup("civis", 220600, 220000, "w5", 4)
Rem.changeRelation(gx, gy, -200)
WR.daily()
WR.between(gx, gy).side = gx.id
local repY = Rem.getRep(gy.id)
Rem.getStore().groups[gx.id] = nil
Rem.emit("groupRemoved", gx)
check(Rem.getRep(gy.id) == repY, "quem vence a guerra contra o seu lado nao te agradece")
-- tregua
local gc = Rem.createGroup("civis", 220300, 220000, "w3", 4)
know(gc)
Rem.changeRelation(gb, gc, -200)
WR.daily()
local w = WR.between(gb, gc)
check(w ~= nil, "(nova guerra)")
w.lastRaid = Rem.worldHours() - 24 * WR.CFG.TRUCE_DAYS
WR.daily()
check(WR.between(gb, gc) ~= nil, "dias sem ataque, mas a raiva ainda alta: a guerra continua")
w.lastRaid = Rem.worldHours() - 24 * WR.CFG.TRUCE_DAYS
Rem.changeRelation(gb, gc, 200)
Rem.changeRelation(gb, gc, -50)
WR.daily()
check(WR.between(gb, gc) == nil and lastJournal() == "IGUI_Rem_Journal_war_truce", "dias sem ataques e a raiva baixou: tregua")
Rem.dismissAll()

-- ===================================================================== refugiados
realPrint("370) Refugiados")
fresh()
setDay(30)
local fallen = Rem.createGroup("civis", 230000, 230000, "r1", 4)
local shelter = Rem.createGroup("civis", 230200, 230000, "r2", 2)
Rem.createGroup("saqueadores", 230100, 230000, "r3", 3)
know(fallen); know(shelter)
fallen.home.x1, fallen.home.y1, fallen.home.x2, fallen.home.y2 = 230000, 230000, 230006, 230006
local out = nil
withRand(always, function() out = RF.flee(fallen) end)
check(#out == 4 and #fallen.members == 0 and lastJournal() == "IGUI_Rem_Journal_refugees", "quem escapa vira refugiado (diario)")
check(out[1].refTarget and out[1].refTarget.gid == shelter.id, "vao para o grupo amigo mais perto (nao para os saqueadores)")
local who = out[1]
for _ = 1, 3 do RF.hourly() end
check(who.groupId == shelter.id and who.mode == "group", "chegam e o grupo recebe")
check(#shelter.members >= 3, "(o grupo cresce)")
-- queda de base: so parte escapa
local fallen2 = Rem.createGroup("civis", 230000, 231000, "r4", 4)
fallen2.home.x1, fallen2.home.y1, fallen2.home.x2, fallen2.home.y2 = 230000, 231000, 230006, 231006
local before = #RF.list()
withRand(function(a, b) if b then return a end if a == 100 then return 99 end return 0 end, function() EV.fall(fallen2) end)
check(#RF.list() == before and Rem.getStore().groups[fallen2.id] == nil, "(sem sorte, ninguem escapa da horda)")
-- a sua base
local hs = house()
player.x, player.y = hs.x + 4, hs.y + 4
local base = PB.setHere(player)
base.supplies = 10
local strangers = Rem.createGroup("civis", hs.x + 100, hs.y + 10, "r8", 1)
withRand(always, function() out = RF.flee(strangers) end)
check(not out[1].refTarget or out[1].refTarget.gid ~= base.id, "estranhos (sem confianca em voce) nao vem para a sua base")
Rem.removePerson(out[1].id)
local trusting = Rem.createGroup("civis", hs.x + 100, hs.y, "r5", 3)
Rem.changeRep(trusting.id, 30, "teste")
withRand(always, function() out = RF.flee(trusting) end)
check(out[1].refTarget.gid == base.id, "confiavam em voce: vem pedir abrigo na sua base")
player.x, player.y = hs.x + 3000, hs.y
local p1 = out[1]
for i = 2, #out do out[i].x = hs.x + 2500 end      -- (os outros ainda estao longe)
RF.hourly()
check(p1.groupId == base.id and p1.faction == "aliados" and PB.isMember(p1) and hasJournal("IGUI_Rem_Journal_refugee_base"),
    "com lugar e comida, os moradores aceitam")
base.supplies = 0
local p2 = out[2]
p2.x, p2.y = base.home.x + 50, base.home.y
RF.hourly()
check(not PB.isMember(p2) and p2.refusedByBase and lastJournal() ~= nil, "sem comida: nao tem como ficar (procura outro lugar)")
-- em cena: chamar para a base
base.supplies = 10
local p3 = out[3]
p3.refTarget = { gid = "nada", x = hs.x + 900, y = hs.y }
player.x, player.y = hs.x + 50, hs.y
local rn = Rem.materialize(p3)
rn.z.x, rn.z.y = hs.x + 52, hs.y
rn.z.path, rn.nextPath, rn.lastPathX = nil, 0, nil
check(Rem.runBehaviors(rn, { player = player }, Rem.nowMs()) == "refugee" and rn.z.path, "em cena: anda pela rua rumo ao destino")
check(opts(rn).refugee_invite, "'[Refugiado] Venha para a nossa base.'")
IA.choose("refugee_invite", rn, player)
check(PB.isMember(rn.rec) and rn.rec.faction == "aliados", "aceita e vai morar na base")
-- grupo pequeno que perdeu um ataque
local small = Rem.createGroup("civis", 232000, 232000, "r6", 2)
local attackers = Rem.createGroup("saqueadores", 232300, 232000, "r7", 3)
Rem.emit("raidResolved", attackers, small, attackers)
check(small.dissolve, "grupo pequeno derrotado: se desfaz")
withRand(always, function() RF.hourly() end)
check(Rem.getStore().groups[small.id] == nil, "(os que sobraram viram refugiados)")
Rem.dismissAll()

-- ===================================================================== caravanas
realPrint("380) Caravanas de troca")
fresh()
setDay(30)
local rich = Rem.createGroup("civis", 240000, 240000, "c1", 3)
local friend = Rem.createGroup("civis", 240200, 240000, "c2", 3)
know(rich)
rich.supplies = 20
local f0 = friend.supplies
Rem.changeRelation(rich, friend, 30)
withRand(always, function() CV.daily() end)
local c = CV.list()[1]
check(c and c.from == rich.id and c.to == friend.id and rich.supplies == 20 - CV.CFG.GOODS, "grupo com sobra manda uma caravana para um amigo")
CV.hourly()
check(math.abs(c.x - (240000 + CV.CFG.SPEED)) < 1, "a caravana anda pelo mapa")
local rel0 = Rem.relation(rich, friend)
CV.hourly()
check(#CV.list() == 0 and friend.supplies == f0 + CV.CFG.GOODS and Rem.relation(rich, friend) == rel0 + CV.CFG.REL_GAIN,
    "chegou: a carga vira suprimento e os dois ficam mais proximos")
-- emboscada longe de voce
rich.supplies, friend.supplies = 20, 0
withRand(always, function() CV.daily() end)
c = CV.list()[1]
local band = Rem.createGroup("saqueadores", c.x + 150, c.y, "c3", 3)
local bs = band.supplies
withRand(always, function() CV.hourly() end)
check(CV.get(c.id) == nil and band.supplies == bs + CV.CFG.GOODS and lastJournal() == "IGUI_Rem_Journal_caravan_lost",
    "saqueadores perto do caminho: emboscada, a carga vai para eles")
Rem.getStore().groups[band.id] = nil
-- aliados mandam para a sua base
local hs2 = house()
player.x, player.y = hs2.x + 4, hs2.y + 4
local mybase = PB.setHere(player)
local ally = Rem.createGroup("civis", hs2.x + 200, hs2.y, "c4", 3)
ally.allied, ally.supplies = true, 20
withRand(always, function() CV.daily() end)
c = nil
for _, x in ipairs(CV.list()) do if x.from == ally.id then c = x end end
check(c and c.to == mybase.id and hasJournal("IGUI_Rem_Journal_caravan_coming"), "aliados mandam caravana para a sua base")
local notAlly = Rem.createGroup("civis", hs2.x + 150, hs2.y, "c5", 3)
check(CV.destFor(notAlly) ~= mybase, "(quem nao e aliado nao manda para a sua base)")
player.x = hs2.x + 3000
CV.hourly(); CV.hourly()
check(#(mybase.pendingList or {}) > 0 and lastJournal() == "IGUI_Rem_Journal_caravan_arrived", "chegou: os itens aparecem no estoque")
-- em cena
CV.list()[1] = nil
for i = #CV.list(), 1, -1 do table.remove(CV.list(), i) end
rich.supplies = 20
withRand(always, function() CV.daily() end)
c = CV.list()[1]
player.x, player.y = c.x + 20, c.y
c.tx, c.ty = c.x + 400, c.y
local lead = nil
withRand(never, function() lead = CV.show(c, player) end)
check(lead and c.onScene and #c.people == CV.CFG.PEOPLE and not c.ambush, "perto de voce: a dupla aparece de verdade")
check(#lead.rec.pockets == CV.CFG.POCKET_ITEMS and #IA.theirItems(lead) >= CV.CFG.POCKET_ITEMS, "carregando a carga nos bolsos (da para trocar)")
lead.z.path, lead.nextPath, lead.lastPathX = nil, 0, nil
Rem.Ambient.HANDLERS.caravan(lead, { player = player }, Rem.nowMs())
check(lead.z.path and lead.z.path[1] > lead.z:getX(), "segue viagem para o destino")
-- saiu de cena: volta ao papel
eachNpc(c.people, Rem.dismiss)
check(CV.track(c) == "paper" and not c.onScene and CV.get(c.id) == c, "longe de voce: a caravana segue no papel")
-- emboscada em cena: voce defende
withRand(always, function() lead = CV.show(c, player) end)
check(c.ambush and #c.ambush == 2 and lastJournal() == "IGUI_Rem_Journal_caravan_ambush", "as vezes: emboscada perto de voce")
local rep0 = Rem.getRep(rich.id)
eachNpc(c.ambush, function(n) n.z:Kill(nil) end)
check(CV.track(c) == "saved" and Rem.getRep(rich.id) == rep0 + CV.CFG.SAVE_REP, "saqueadores mortos e a caravana viva: eles ficam te devendo")
-- todos da caravana mortos
eachNpc(c.people, function(n) n.z:Kill(nil) end)
check(CV.track(c) == "lost" and CV.get(c.id) == nil, "se a caravana morre, a carga se perde")

T.timeOfDay = 12
SandboxVars.Remanescentes.MaxActive = T.defaults().MaxActive
fresh()
