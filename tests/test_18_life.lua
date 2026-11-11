-- Vida dos personagens: jeito, historia, humor, moral, luto (Rem_Persona); vinculo, memoria,
-- presente e experiencia (Rem_Bonds); conversas e comentarios (Rem_Banter).
local T = ...
local Rem = Remanescentes
local check, tick = T.check, T.tick
local player, realPrint = T.player, T.print
local PS, BD, BT, IA = Rem.Persona, Rem.Bonds, Rem.Banter, Rem.Interact

local function fresh()
    Rem.dismissAll(); T.clearZombies(); Rem.hunting = {}
    Rem.Mugging.enc = {}
    Rem.getStore().reputation = {}
    BT.queue, BT.state, BT.kills = {}, {}, {}
    player.inv.items = {}
    player.weapon, player.bag = nil, nil
end
local function scene() Rem.emit("sceneUpdate", player, Rem.nowMs()) end
local function byPlayer(z) z.getAttackedBy = function() return player end end
local function neutral(npc)   -- personalidade neutra: a atitude sai so da reputacao e do vinculo
    npc.rec.personality = { agressividade = 5, confianca = 5, coragem = 5, ganancia = 5, lealdade = 5 }
    npc.rec.moral = 50
    Rem.Reputation.apply(npc.rec)
    return npc
end
local function lastSaid(npc) return npc.z.said[#npc.z.said] or "" end
local realRand = ZombRand
local function rand(v) ZombRand = function(a, b) return b and a or v end end   -- sorteio fixo
local function unrand() ZombRand = realRand end

realPrint("150) Jeito, historia e humor")
fresh()
player.x, player.y = 36000, 36000
local a = neutral(Rem.spawn(36002, 36000, 0, { faction = "civis", mode = "stay" }))
local okQuirk = false
for _, q in ipairs(PS.QUIRKS) do if a.rec.quirk == q then okQuirk = true end end
check(okQuirk, "toda pessoa nasce com um jeito (" .. tostring(a.rec.quirk) .. ")")
check(a.rec.story and a.rec.story.lost >= 1 and a.rec.story.lost <= PS.STORY_LOST and a.rec.story.goal >= 1
    and a.rec.story.goal <= PS.STORY_GOAL, "e com uma historia (quem perdeu, o que quer)")
local old = Rem.newPerson({ faction = "civis", x = 36010, y = 36000 })
old.quirk, old.story = nil, nil
local oldNpc = Rem.materialize(old)
check(old.quirk ~= nil and old.story ~= nil, "pessoas de saves antigos ganham jeito e historia ao aparecer")
Rem.dismiss(oldNpc)
local cult = Rem.newPerson({ faction = "seita", x = 36020, y = 36000 })
local religious = 0
for _ = 1, 40 do if PS.rollQuirk(cult) == "religioso" then religious = religious + 1 end end
check(religious >= 12, "na seita a maioria e 'de fe' (" .. religious .. "/40)")
Rem.removePerson(cult.id)

check(PS.mood(a.rec, a) == "calmo", "humor: calmo por padrao")
a.rec.moral = 80
check(PS.mood(a.rec, a) == "animado", "moral alto: animado")
a.rec.moral = 10
check(PS.mood(a.rec, a) == "abatido", "moral baixo: abatido")
a.rec.griefUntil, a.rec.griefFor = Rem.worldHours() + 5, "Ana"
check(PS.mood(a.rec, a) == "luto", "luto pesa mais que o moral")
a.z.hp = a.rec.maxHealth * 0.3
check(PS.mood(a.rec, a) == "ferido", "ferido pesa mais que o luto")
a.z.hp = a.rec.maxHealth
a.rec.sick = true
check(PS.mood(a.rec, a) == "doente", "infectado passando mal: doente")
a.rec.sick = nil

realPrint("151) O jeito e o humor mudam as falas")
a.z.said = {}
rand(0)
Rem.bark(a, "idle", true)
check(lastSaid(a):find("IGUI_Rem_Bark_idle_luto_"), "de luto, resmunga sobre a perda (" .. lastSaid(a) .. ")")
a.rec.griefUntil, a.rec.moral = nil, 50
a.rec.quirk = "piadista"
Rem.bark(a, "idle", true)
check(lastSaid(a):find("IGUI_Rem_Bark_idle_piadista_"), "calmo, fala do jeito dele (" .. lastSaid(a) .. ")")
Rem.bark(a, "kill", true)
check(lastSaid(a):find("IGUI_Rem_Bark_kill_"), "outras falas nao mudam")
a.rec.quirk = "calado"
local n0 = #a.z.said
rand(1)
a.barkAt, a.lastBark = {}, nil
check(Rem.bark(a, "idle") == false and #a.z.said == n0, "calado: quase nunca puxa assunto")
unrand()

realPrint("152) 'Me fala de voce'")
a.rec.quirk = "falante"
a.rec.personality.confianca = 1
a.rec.bond, a.rec.toldStory = 0, nil
local l = IA.choose("about", a, player)
check(l.key:find("IGUI_Rem_About_refuse_%d"), "desconfiado nao conta a vida para um estranho (" .. l.key .. ")")
a.rec.bond = PS.CFG.ABOUT_BOND
l = IA.choose("about", a, player)
check(l.key == "IGUI_Rem_About" and #l.args == 3 and a.rec.toldStory, "depois de um favor, conta: quem era, quem perdeu, o que quer")
check(a.rec.bond == PS.CFG.ABOUT_BOND + BD.DELTA.about, "contar a historia cria vinculo")
local b0 = a.rec.bond
IA.choose("about", a, player)
check(a.rec.bond == b0, "so na primeira vez")
local opts = {}
for _, id in ipairs(IA.dialogOptions(a, player)) do opts[id] = true end
check(opts.about and opts.gift, "a conversa tem 'Me fala de voce' e 'dar um presente'")

realPrint("153) Moral e luto")
fresh()
local g = Rem.createGroup("civis", 36200, 36000, nil, 3)
g.supplies = 0
local m1, m2, m3 = Rem.getPerson(g.members[1]), Rem.getPerson(g.members[2]), Rem.getPerson(g.members[3])
m1.moral, m2.moral, m3.moral = 50, 50, 50
check(PS.hungry(m1) and PS.mood(m1) == "faminto", "grupo sem comida: com fome")
PS.hourly()
check(m1.moral < 50, "fome derruba o moral")
g.supplies = 50
m1.moral = 40
PS.hourly()
check(m1.moral == 41 and PS.mood(m1) == "calmo", "casa abastecida: o moral volta aos poucos")
m1.moral, m2.moral, m3.moral = 50, 50, 50
player.x, player.y = 36200, 36005
local n1 = Rem.materialize(m1)
local n2 = Rem.materialize(m2)
n2.z.said = {}
local deadName = m1.name
n1.z:Kill(nil)
check(m2.griefUntil ~= nil and m2.griefFor == deadName and m3.griefUntil ~= nil, "morte no grupo: os outros ficam de luto (mesmo fora de cena)")
check(m2.moral == 50 - PS.CFG.GRIEF_MORALE, "e o moral cai")
check(T.saidPrefix(n2.z, "IGUI_Rem_Bark_grief_"), "quem esta perto fala na hora")
check(PS.mood(m2, n2) == "luto", "humor: de luto")
T.worldHours = T.worldHours + PS.CFG.GRIEF_HOURS + 1
PS.hourly()
check(m2.griefUntil == nil, "o luto passa depois de um dia")
local stranger = Rem.spawn(36230, 36000, 0, { faction = "civis", mode = "stay" })
check(stranger.rec.griefUntil == nil, "quem nao era do grupo nao sente")

realPrint("154) Vinculo e memoria")
fresh()
player.x, player.y = 36400, 36000
local c = neutral(Rem.spawn(36402, 36000, 0, { faction = "civis", mode = "stay" }))
check(Rem.attitudeOf(c.rec) == "neutro", "(cenario) civil neutro")
BD.add(c.rec, "gift", 20)
check(Rem.attitudeOf(c.rec) == "amigavel" and c.rec.attitude == "amigavel", "vinculo alto: amigavel com voce, mesmo com o grupo neutro")
BD.add(c.rec, "hit", -200)
check(c.rec.bond == BD.CFG.MIN and Rem.attitudeOf(c.rec) == "hostil" and c.rec.hostileToPlayer == true, "vinculo no fundo: hostil (e limitado a -100)")
c.rec.bond, c.rec.mem = 0, nil
Rem.Reputation.apply(c.rec)
for i = 1, 5 do BD.add(c.rec, (i % 2 == 0) and "gift" or "traded") end
BD.add(c.rec, "saved"); BD.add(c.rec, "saved"); BD.add(c.rec, "quest")
check(#c.rec.mem == BD.CFG.MEM_MAX and c.rec.mem[#c.rec.mem].k == "quest" and c.rec.mem[#c.rec.mem - 1].k == "saved"
    and c.rec.mem[#c.rec.mem - 2].k == "traded",
    "guarda as ultimas lembrancas, sem repetir a mesma em seguida")
c.rec.bond, c.rec.mem = 0, nil
local zed = T.newZombie(36403, 36000, 0)
Rem.hunting[zed] = { npc = c }
byPlayer(zed)
zed:Kill(nil)
check(c.rec.bond == BD.DELTA.saved and c.rec.mem[1].k == "saved", "matar o zumbi que o cacava: ele lembra")
local gl = IA.greeting(c)
check(gl.key:find("IGUI_Rem_Talk_hi_saved_"), "cumprimento lembra: 'ainda te devo a vida' (" .. gl.key .. ")")
gl = IA.greeting(c)
check(not gl.key:find("hi_saved"), "cada lembranca e citada uma vez (" .. gl.key .. ")")
c.rec.bond = BD.CFG.CLOSE_BOND
check(IA.greeting(c).key:find("IGUI_Rem_Talk_hi_close_"), "vinculo forte: cumprimento de amigo")
c.rec.bond = -20
BD.remember(c.rec, "hit")
check(IA.greeting(c).key:find("IGUI_Rem_Talk_hi_grudge_"), "rancor: 'ainda lembro do que voce fez'")
c.rec.bond, c.rec.mem, c.rec.talkedAt = 0, nil, nil
check(BD.talked(c) and c.rec.bond == 1 and not BD.talked(c) and c.rec.bond == 1 and c.rec.mem == nil,
    "conversar aproxima um pouco, uma vez por dia, sem virar lembranca")
local js0 = IA.joinScore(c)
c.rec.bond = 40
check(IA.joinScore(c) == js0 + 40 * IA.CFG.JOIN_BOND_WEIGHT - 1 * IA.CFG.JOIN_BOND_WEIGHT, "vinculo ajuda a recrutar")

-- cumprimento de passagem (sem abrir conversa)
c.rec.bond, c.greetAt, c.barkAt, c.lastBark = 30, nil, {}, nil
c.z.said = {}
player.x, player.y = c.z.x + 2, c.z.y
scene()
check(T.saidPrefix(c.z, "IGUI_Rem_Bark_greet_bond_"), "quem gosta de voce te cumprimenta de longe como amigo")
c.rec.bond, c.greetAt, c.barkAt, c.lastBark = -30, nil, {}, nil
Rem.Reputation.apply(c.rec)
c.z.said = {}
scene()
check(T.saidPrefix(c.z, "IGUI_Rem_Bark_greet_grudge_"), "quem guarda rancor (sem ser hostil) te manda passar reto")
c.rec.bond = 0
Rem.Reputation.apply(c.rec)

realPrint("155) Presente")
c.rec.bond, c.rec.mem, c.rec.giftAt = 0, nil, nil
local okG, lg = IA.gift(c, player)
check(not okG and lg.key == "IGUI_Rem_Gift_none", "sem nada util: nao da presente")
player.inv:AddItem("Base.Book")
okG, lg = IA.gift(c, player)
check(not okG and lg.key == "IGUI_Rem_Gift_none" and #player.inv.items == 1, "tralha nao serve de presente (so comida, agua, remedio, municao)")
player.inv:AddItem("Base.TinnedBeans"); player.inv:AddItem("Base.Bandage")
c.z.hp = c.rec.maxHealth * 0.4      -- ferido: remedio vale mais
local rep0, moral0 = Rem.repOf(c.rec), c.rec.moral
okG, lg = IA.gift(c, player)
local has = {}
for _, it in ipairs(player.inv.items) do has[it:getFullType()] = true end
check(okG and lg.key == "IGUI_Rem_Gift_thanks" and not has["Base.Bandage"] and has["Base.TinnedBeans"] and has["Base.Book"],
    "da o que ele mais precisa (ferido: a bandagem)")
check(c.rec.carry[#c.rec.carry] == "Base.Bandage", "o item fica com ele")
check(c.rec.bond >= IA.CFG.GIFT_BOND[1] and c.rec.bond <= IA.CFG.GIFT_BOND[2] and c.rec.mem[1].k == "gift", "vinculo sobe e ele lembra")
check(Rem.repOf(c.rec) == rep0 + IA.CFG.GIFT_REP and c.rec.moral == moral0 + PS.CFG.MORALE_GIFT, "reputacao e moral sobem um pouco")
local bg = c.rec.bond
okG, lg = IA.gift(c, player)
check(not okG and lg.key == "IGUI_Rem_Gift_enough" and c.rec.bond == bg and has["Base.TinnedBeans"], "um presente por vez: nao da para comprar amizade em 1 minuto")
T.worldHours = T.worldHours + IA.CFG.GIFT_HOURS + 1
okG = IA.gift(c, player)
check(okG, "horas depois, pode de novo")
c.z.hp = c.rec.maxHealth

realPrint("156) Experiencia")
fresh()
local vet = Rem.spawn(36600, 36000, 0, { faction = "aliados", mode = "stay" })
vet.z.said = {}
check(BD.level(vet.rec) == 0 and BD.damageMult(vet) == 1 and BD.accuracyBonus(vet) == 0, "comeca sem experiencia")
for _ = 1, BD.CFG.LEVELS[1] - 1 do Rem.emit("npcKilledZombie", vet) end
check(BD.level(vet.rec) == 0 and BD.toNext(vet.rec) == 1, "quase la")
Rem.emit("npcKilledZombie", vet)
check(vet.rec.level == 1 and vet.rec.kills == BD.CFG.LEVELS[1] and T.saidPrefix(vet.z, "IGUI_Rem_Bark_levelup_"), "nivel 1: comenta que esta pegando o jeito")
check(math.abs(BD.damageMult(vet) - (1 + BD.CFG.LEVEL_DAMAGE)) < 0.001 and BD.accuracyBonus(vet) == BD.CFG.LEVEL_ACCURACY, "mais dano e pontaria")
vet.rec.kills = 999
Rem.emit("npcKilledZombie", vet)
check(vet.rec.level == #BD.CFG.LEVELS and BD.toNext(vet.rec) == nil, "tem nivel maximo")
-- o golpe de verdade conta
vet.rec.kills, vet.rec.level = 0, 0
player.x, player.y = 36600, 36003
local target = T.newZombie(36600.8, 36000, 0)
target.hp = 0.01
target.target = vet.z
tick(300, 20)
check(target.dead and vet.rec.kills == 1, "zumbi morto no golpe entra na conta (" .. tostring(vet.rec.kills) .. ")")
local RG = Rem.Ranged
local g9 = { hit = 60 }
local base = RG.hitChance(vet, g9, target, 5, T.clock)
vet.rec.level = 3
check(RG.hitChance(vet, g9, target, 5, T.clock) == math.min(RG.CFG.MAX_HIT, base + 3 * BD.CFG.LEVEL_ACCURACY), "veterano atira melhor em zumbis")
local onPlayer = RG.hitChance(vet, g9, player, 5, T.clock)
vet.rec.level = 0
check(RG.hitChance(vet, g9, player, 5, T.clock) == onPlayer, "mas nunca melhor em voce")

realPrint("157) Conversas entre sobreviventes")
fresh()
player.x, player.y = 36800, 36000
local p1 = neutral(Rem.spawn(36803, 36000, 0, { faction = "civis", mode = "stay" }))
local p2 = neutral(Rem.spawn(36805, 36000, 0, { faction = "civis", mode = "stay" }))
p1.rec.quirk, p2.rec.quirk = "falante", "falante"
p1.z.said, p2.z.said = {}, {}
local now = Rem.nowMs()
local fa, fb = BT.findPair(player, now)
check(fa and fb and fa ~= fb, "dois parados perto um do outro (e de voce) podem conversar")
local topics = {}
for _, t in ipairs(BT.topicsFor(p1, p2)) do topics[t] = true end
check(topics.generic and not topics.grief and not topics.raider and not topics.hungry, "assunto: conversa fiada")
p2.rec.griefUntil, p2.rec.griefFor = Rem.worldHours() + 5, "Bruno"
topics = {}
for _, t in ipairs(BT.topicsFor(p1, p2)) do topics[t] = true end
check(topics.grief, "com alguem de luto, falam de quem morreu")
T.timeOfDay = 23
topics = {}
for _, t in ipairs(BT.topicsFor(p1, p2)) do topics[t] = true end
check(topics.night, "de noite, falam da noite")
T.timeOfDay = 12
p1.rec.quirk = "piadista"
topics = {}
for _, t in ipairs(BT.topicsFor(p1, p2)) do topics[t] = true end
check(topics.joke and not topics.faith, "piadista conta piada")
Rem.changeRep("f:civis", 60, "teste")
topics = {}
for _, t in ipairs(BT.topicsFor(p1, p2)) do topics[t] = true end
check(topics.player_good and not topics.player_bad, "com boa fama, falam bem de voce")
BT.start(p1, p2, now, "grief")
check(#BT.queue == 2 and p1.banterUntil and p2.banterWith == p1, "conversa marcada: um fala, o outro responde")
BT.flush(now)
check(lastSaid(p1):find("IGUI_Rem_Banter_grief_%d_1") and #p2.z.said == 0, "primeiro quem puxou (" .. lastSaid(p1) .. ")")
T.clock = T.clock + BT.CFG.TURN_MS
BT.flush(Rem.nowMs())
check(lastSaid(p2):find("IGUI_Rem_Banter_grief_%d_2") and #BT.queue == 0, "depois o outro responde (" .. lastSaid(p2) .. ")")
check(not BT.available(p1, Rem.nowMs()), "cada um descansa antes de outra conversa")
local handled = BT.behavior(p1, { player = player }, Rem.nowMs())
check(handled == true, "enquanto conversam, ficam parados se olhando")
T.clock = T.clock + BT.CFG.TURN_MS * 3
check(BT.behavior(p1, { player = player }, Rem.nowMs()) == false and p1.banterUntil == nil, "e depois voltam ao que faziam")
p1.banterAt, p2.banterAt = 0, 0
p1.crowd = 2
check(not BT.available(p1, Rem.nowMs()), "com zumbi em volta, ninguem conversa")
p1.crowd = 0
local r1 = Rem.spawn(36803, 36010, 0, { faction = "saqueadores", mode = "stay" })
local r2 = Rem.spawn(36805, 36010, 0, { faction = "saqueadores", mode = "stay" })
check(#BT.topicsFor(r1, r2) == 1 and BT.topicsFor(r1, r2)[1] == "raider", "saqueadores tem os assuntos deles")
Rem.dismiss(r1); Rem.dismiss(r2)
-- pelo ciclo normal
BT.queue = {}
p1.z.said, p2.z.said = {}, {}
rand(0)
T.clock = T.clock + BT.CFG.CHECK_MS + 1
scene()
unrand()
check(#p1.z.said + #p2.z.said >= 1, "acontece sozinho de tempos em tempos")

realPrint("158) Comentarios sobre o que acontece")
fresh()
player.x, player.y = 37000, 37000
local ally = Rem.spawn(37002, 37000, 0, { faction = "aliados", mode = "stay" })
local civil = neutral(Rem.spawn(37001, 37003, 0, { faction = "civis", mode = "stay" }))
ally.z.said, civil.z.said = {}, {}
for i = 1, BT.CFG.CHEER_KILLS do
    local z = T.newZombie(37010 + i, 37000, 0)
    byPlayer(z)
    z:Kill(nil)
end
check(T.saidPrefix(ally.z, "IGUI_Rem_Bark_context_cheer_") and not T.saidPrefix(civil.z, "IGUI_Rem_Bark_context_cheer_"),
    "voce derruba varios zumbis seguidos: seu aliado comemora")
ally.z.said = {}
local bd = player.getBodyDamage
player.getBodyDamage = function() return { getOverallBodyHealth = function() return 30 end } end
BT.context(player, Rem.nowMs())
check(T.saidPrefix(ally.z, "IGUI_Rem_Bark_context_hurt_"), "voce muito ferido: o aliado manda parar e cuidar disso")
ally.z.said = {}
BT.context(player, Rem.nowMs())
check(#ally.z.said == 0, "sem repetir toda hora")
player.getBodyDamage = bd
T.clearZombies()
for i = 1, BT.CFG.HORDE_COUNT do T.newZombie(37000 + i, 37012, 0) end
T.clock = T.clock + 200
BT.context(player, Rem.nowMs())
check(T.saidPrefix(ally.z, "IGUI_Rem_Bark_context_horde_"), "horda por perto: comenta")
T.clearZombies()
T.clock = T.clock + 200
RainManager = { isRaining = function() return false end }
BT.context(player, Rem.nowMs())
RainManager = { isRaining = function() return true end }
ally.z.said = {}
BT.context(player, Rem.nowMs())
check(T.saidPrefix(ally.z, "IGUI_Rem_Bark_context_rain_"), "comecou a chover: comenta")
RainManager = nil
player.isAiming = function() return true end
player.weapon = T.newWeapon("Base.Axe")
player.getForwardDirection = function() return { getX = function() return 0.3 end, getY = function() return 0.95 end } end
civil.z.said = {}
BT.context(player, Rem.nowMs())
check(T.saidPrefix(civil.z, "IGUI_Rem_Bark_context_aim_"), "apontar a arma para um neutro: ele reclama")
player.isAiming, player.weapon, player.getForwardDirection = nil, nil, nil
T.timeOfDay = 21.2
ally.z.said = {}
Rem.emit("worldHour", Rem.worldHours())
check(T.saidPrefix(ally.z, "IGUI_Rem_Bark_context_night_"), "anoiteceu: o aliado quer achar um teto")
T.timeOfDay = 12
Rem.dismiss(ally)
civil.z.said = {}
T.clock = T.clock + 700000
T.timeOfDay = 21.2
Rem.emit("worldHour", Rem.worldHours())
check(#civil.z.said == 0, "quem nao e seu aliado nao comenta a noite")
T.timeOfDay = 12
fresh()

realPrint("159) Hora de comer")
fresh()
local RT = Rem.Routine
local hdef = T.addBuilding(37201, 37200, 37000, 10, 8)
for i = 37200, 37209 do for j = 37000, 37007 do T.indoorSq[i .. "," .. j] = true; T.sqBuilding[i .. "," .. j] = hdef end end
T.addObject(37202, 37002, 0, "container", { type = "fridge" })
T.addObject(37205, 37007, 0, "IsoDoor", { exterior = true })
local hg = Rem.createGroup("civis", 37205, 37004, "37201", 3, hdef)
hg.supplies, hg.activity = 20, "home"
player.x, player.y = 37205, 37012
scene()
local guard, eater = nil, nil
for _, npc in pairs(Rem.active) do
    if npc.rec.groupId == hg.id then
        if npc.rec.role == "guarda" then guard = npc elseif npc.rec.role == "morador" then eater = npc end
    end
end
if not eater then
    for _, id in ipairs(hg.members) do
        local p = Rem.getPerson(id)
        if p.role == "morador" then eater = Rem.active and Rem.materialize(p) or eater end
    end
end
check(eater ~= nil and RT.mealNow() == 1, "(cenario) morador em casa na hora do almoco")
local kitchen = Rem.Roles.kitchenSpot(hg.home)
eater.z.x, eater.z.y = 37207.5, 37005.5
eater.rec.moral = 50
eater.z.said = {}
check(RT.mealBehavior(eater, { player = player }, Rem.nowMs()) == true and eater.moving, "vai para a cozinha")
eater.z.x, eater.z.y = kitchen.x + 0.5, kitchen.y + 1.5
Rem.stopMoving(eater)
check(RT.mealBehavior(eater, { player = player }, Rem.nowMs()) == true and eater.rest == "sit", "senta para comer")
check(eater.rec.moral == 50 + RT.CFG.MORALE and T.saidPrefix(eater.z, "IGUI_Rem_Bark_meal_"), "comer junto sobe o moral; conversam")
RT.mealBehavior(eater, { player = player }, Rem.nowMs())
check(eater.rec.moral == 50 + RT.CFG.MORALE, "uma vez por refeicao")
if guard then check(RT.mealBehavior(guard, { player = player }, Rem.nowMs()) == false, "o guarda nao larga o posto") end
T.timeOfDay = 15
check(RT.mealBehavior(eater, { player = player }, Rem.nowMs()) == false and eater.rest == nil, "acabou o almoco: levanta")
T.timeOfDay = 19.5
check(RT.mealNow() == 2, "jantar")
hg.supplies = 0
eater.z.said, eater.barkAt, eater.lastBark = {}, {}, nil
check(RT.mealBehavior(eater, { player = player }, Rem.nowMs()) == false and T.saidPrefix(eater.z, "IGUI_Rem_Bark_meal_none_"),
    "sem comida, ninguem se reune e alguem reclama")
T.timeOfDay = 12
fresh()
