-- Pacote 0.21: fama, sua faccao (nome, pacto, tributo), conselho da base, missoes
-- pessoais, traumas e vicios.
local T = ...
local Rem = Remanescentes
local check, tick = T.check, T.tick
local player, realPrint = T.player, T.print
local PB, IA, JN, FM, TM, PQ, CO, DP, BE = Rem.PlayerBase, Rem.Interact, Rem.Journal, Rem.Fame, Rem.Traumas,
    Rem.PersonalQuests, Rem.Council, Rem.Diplomacy, Rem.BaseEvents

local function fresh()
    Rem.dismissAll(); T.clearZombies(); Rem.hunting = {}
    Rem.Mugging.enc = {}
    local s = Rem.getStore()
    s.reputation, s.quests, s.journal, s.playerBase, s.met, s.knownGroups = {}, {}, {}, nil, {}, {}
    s.fame, s.chronicle, s.relations, s.wars = nil, {}, {}, {}
    player.inv.items = {}
    player.weapon = nil
end
local function lastJournal() local l = JN.entries() return l[#l] and l[#l].key end
local function hasJournal(key) for _, e in ipairs(JN.entries()) do if e.key == key then return true end end return false end
local function withRand(fn, body)
    local real = ZombRand
    ZombRand = fn
    local ok, err = pcall(body)
    ZombRand = real
    if not ok then error(err) end
end
local always = function(a, b) if b then return a end return 0 end
local never = function(a, b) if b then return a end return (a or 1) - 1 end
local function opts(npc)
    local o = {}
    for _, id in ipairs(IA.dialogOptions(npc, player)) do o[id] = true end
    return o
end
local function ally(x, y, extra)
    local o = { faction = "aliados", mode = "follow" }
    for k, v in pairs(extra or {}) do o[k] = v end
    local npc = Rem.spawn(x, y, 0, o)
    npc.rec.recruited = true
    return npc
end
local nextId = 250000
local function house()
    nextId = nextId + 400
    local x, y = nextId, 250000
    local def = T.addBuilding(nextId + 1, x, y, 8, 6)
    for i = x, x + 7 do for j = y, y + 5 do T.indoorSq[i .. "," .. j] = true; T.sqBuilding[i .. "," .. j] = def end end
    T.addObject(x + 2, y + 2, 0, "container", { type = "fridge" })
    return { def = def, x = x, y = y }
end
local function base(n)
    local hs = house()
    player.x, player.y = hs.x + 4, hs.y + 4
    local g = PB.setHere(player)
    local list = {}
    for i = 1, (n or 0) do
        local a = ally(hs.x + 1 + i % 6, hs.y + 3)
        PB.join(a)
        table.insert(list, a)
    end
    return g, hs, list
end
local function hourly(n) for _ = 1, (n or 1) do Rem.emit("worldHour", Rem.worldHours()) end end
T.timeOfDay = 12
SandboxVars.Remanescentes.MaxActive = 30

-- ===================================================================== fama
realPrint("400) Fama")
fresh()
player.x, player.y = 260000, 260000
check(FM.title() == nil, "comeca sem apelido")
local civ = Rem.spawn(260002, 260000, 0, { faction = "civis", mode = "stay" })
for _ = 1, 4 do Rem.emit("playerDeed", "saved", civ) end
check(FM.title() == nil, "(4 salvamentos ainda nao)")
local mod0 = FM.attitudeMod(civ.rec)
Rem.emit("playerDeed", "saved", civ)
check(FM.title() == "salvador" and lastJournal() == "IGUI_Rem_Journal_fame", "salvou gente bastante: 'quem salva gente' (diario)")
check(FM.attitudeMod(civ.rec) == mod0 + 12, "a primeira impressao melhora")
local stranger = Rem.spawn(260004, 260000, 0, { faction = "civis", mode = "stay" })
local hi = IA.greeting(stranger)
check(hi.key:find("IGUI_Rem_Fame_hi_salvador", 1, true) == 1, "quem nunca te viu ja ouviu falar ('Voce e quem anda salvando gente?')")
check(IA.greeting(stranger).key:find("IGUI_Rem_Fame_hi", 1, true) == nil, "(comenta uma vez so)")
-- matar inocentes
local victim = Rem.spawn(260006, 260000, 0, { faction = "civis", mode = "stay" })
victim.z.getAttackedBy = function() return player end
victim.z:Kill(nil)
local v2 = Rem.spawn(260008, 260000, 0, { faction = "sobreviventes", mode = "stay" })
v2.z.getAttackedBy = function() return player end
v2.z:Kill(nil)
-- quem estava com raiva de voce (voce provocou) nao conta como inocente
local angry = Rem.spawn(260012, 260000, 0, { faction = "seita", mode = "stay" })
angry.rec.hostileToPlayer = true
angry.z.getAttackedBy = function() return player end
local inn = FM.count("innocents")
angry.z:Kill(nil)
check(FM.count("innocents") == inn, "(quem estava te atacando nao conta como inocente)")
check(FM.title() == "assassino", "matar inocentes: 'quem mata gente' (o apelido mais forte)")
check(FM.attitudeMod(civ.rec) < mod0, "e as portas se fecham")
check(FM.attitudeMod({ faction = "saqueadores" }) > FM.attitudeMod({ faction = "civis" }), "(saqueadores respeitam quem mata)")
-- cacador: saqueadores se rendem mais cedo
local s = FM.store()
s.counts.raiders = 7
local r = Rem.spawn(260010, 260000, 0, { faction = "saqueadores", mode = "stay" })
r.z.getAttackedBy = function() return player end
r.z:Kill(nil)
check(s.titles.cacador ~= nil, "saqueadores mortos: 'o terror dos saqueadores'")
require "Remanescentes/Rem_JournalUI"
local realGet = getText
getText = function(k, ...) return k .. " " .. table.concat({ ... }, " ") end
local text = JN.compose(player)
getText = realGet
check(text:find("IGUI_Rem_Journal_famous", 1, true) ~= nil, "o Diario diz o que falam de voce")

-- ===================================================================== traumas
realPrint("410) Traumas e vicios")
fresh()
local g, hs, list = base(3)
local a, b, c = list[1], list[2], list[3]
Rem.Friends.add(a.rec, b.rec, 60)
withRand(always, function() Rem.Persona.mourn(a.rec) end)
check(TM.has(b.rec, "panico") and lastJournal() == "IGUI_Rem_Journal_trauma", "viu o amigo morrer: panico (diario)")
local n0 = Rem.Tactics.nerve(c)
c.rec.trauma = { kind = "panico", level = 3 }
check(math.abs(Rem.Tactics.nerve(c) - n0 * TM.CFG.PANIC_NERVE) < 0.001, "panico: a coragem some na briga")
c.rec.trauma = nil
check(not TM.give(b.rec, "bebida") and b.rec.trauma.kind == "panico", "(um trauma de cada vez)")
-- medo do escuro: ferido de noite
T.timeOfDay = 23
withRand(always, function() Rem.Wounds.inflict(c.rec, "corte") end)
check(TM.has(c.rec, "escuro"), "ferido de noite: medo do escuro")
T.timeOfDay = 12
check(TM.dozeExtra(c.rec) == TM.CFG.DARK_DOZE, "no posto a noite, se distrai")
PB.setJob(c, "guard")
T.timeOfDay = 1
g.dozedH = nil
c.rec.cansaco = 0
withRand(always, function() Rem.Watch.hourly() end)
check(g.dozedH ~= nil, "mesmo descansado, pode 'cochilar' no posto")
local m0 = c.rec.moral
TM.hourly()
check(c.rec.moral < m0, "e perde moral vigiando no escuro")
T.timeOfDay = 12
-- bebida
local d = ally(hs.x + 5, hs.y + 2)
withRand(always, function() PB.join(d) end)
check(TM.has(d.rec, "bebida"), "alguns ja chegam bebendo")
T.timeOfDay = TM.CFG.DRINK_HOUR
g.supplies, d.rec.moral, d.rec.cansaco = 5, 40, 0
TM.hourly()
check(d.rec.moral == 40 + TM.CFG.DRINK_MORALE and d.rec.cansaco == TM.CFG.DRINK_TIRED and g.supplies == 5 - TM.CFG.DRINK_FOOD,
    "a noite bebe: anima na hora, cansa, gasta comida")
T.timeOfDay = 12
-- conversar
check(opts(d).trauma_talk, "'[Conversa] Como voce esta, de verdade?'")
d.rec.bond = 0
local l = IA.choose("trauma_talk", d, player)
check(l.key == "IGUI_Rem_Trauma_closed_bebida" and d.rec.trauma.level == 3, "sem vinculo, se fecha")
check(not opts(d).trauma_talk, "(uma vez por dia)")
d.rec.bond = 30
T.worldHours = T.worldHours + TM.CFG.TALK_HOURS
l = IA.choose("trauma_talk", d, player)
check(l.key == "IGUI_Rem_Trauma_talk_bebida" and d.rec.trauma.level == 2, "com vinculo, conversar ajuda")
d.rec.trauma.level = 1
T.worldHours = T.worldHours + TM.CFG.TALK_HOURS
l = IA.choose("trauma_talk", d, player)
check(d.rec.trauma == nil and l.key == "IGUI_Rem_Trauma_over_bebida" and lastJournal() == "IGUI_Rem_Journal_trauma_over", "superou (diario)")
require "Remanescentes/Rem_DialogUI"
local lines = RemProfileWindow.extraLines(b.rec)
local hasTrauma = false
for _, ln in ipairs(lines) do if ln[1]:find("IGUI_Rem_Profile_trauma", 1, true) or ln[1]:find(":", 1, true) then hasTrauma = true end end
check(hasTrauma, "a Ficha mostra o trauma")

-- ===================================================================== conselho
realPrint("420) Conselho da base")
fresh()
g, hs, list = base(3)
check(CO.vote("newcomer", nil) == nil, "com 3 moradores ainda nao ha conselho")
local e = ally(hs.x + 6, hs.y + 3); PB.join(e)
table.insert(list, e)
g.supplies = 40
for _, p in ipairs(list) do p.rec.moral = 60; p.rec.personality = p.rec.personality or {}; p.rec.personality.confianca = 7 end
local v = CO.vote("newcomer", nil)
check(v and v.passed and v.yes == 4 and lastJournal() == "IGUI_Rem_Journal_council_yes", "comida sobrando e gente confiante: aprovam (diario)")
for _, p in ipairs(list) do p.rec.personality.confianca = 1; p.rec.moral = 30 end
g.supplies = 0
local m1 = list[1].rec.moral
v = CO.vote("newcomer", nil)
check(not v.passed and list[1].rec.moral == m1 - CO.CFG.AGAINST_MORALE and lastJournal() == "IGUI_Rem_Journal_council_no",
    "sem comida e desconfiados: votam contra; voce decide, mas o moral cai")
check(g.lastVote.kind == "newcomer", "(o painel mostra a ultima votacao)")
-- quem e amigo de quem chega vota a favor
local newcomer = Rem.spawn(hs.x + 3, hs.y + 1, 0, { faction = "civis", mode = "stay" })
Rem.Friends.add(list[1].rec, newcomer.rec, 50)
check(CO.opinion(list[1].rec, "newcomer", newcomer.rec, g), "amigo de quem chega vota a favor")
check(not CO.opinion(list[2].rec, "newcomer", newcomer.rec, g), "(os outros, nao)")
-- votacao acontece de verdade: visitante aceito
newcomer.rec.ambient = "visitor"
g.lastVote = nil
BE.accept(newcomer)
check(g.lastVote and g.lastVote.kind == "newcomer", "aceitar um visitante passa pelo conselho")

-- ===================================================================== diplomacia
realPrint("430) Sua faccao: nome, pacto, tributo")
fresh()
g, hs, list = base(1)
check(DP.rename("  Os Teimosos  ") and g.name == "Os Teimosos" and lastJournal() == "IGUI_Rem_Journal_named", "dar um nome ao grupo (diario)")
check(not DP.rename("   "), "(nome vazio nao vale)")
DP.rename("100%% feliz")
check(not g.name:find("%", 1, true), "(o nome nao quebra as traducoes)")
local found = false
for _, o in ipairs(Rem.playerOptions) do if o.labelKey == "ContextMenu_Rem_NameGroup" then found = o.condition() end end
check(found, "clique direito -> 'Dar um nome ao seu grupo'")
-- pacto
local fam = Rem.createGroup("sobreviventes", hs.x + 150, hs.y, "p1", 3)
local fm = Rem.materialize(Rem.getPerson(fam.members[1]))
player.x, player.y = hs.x + 150, hs.y + 3
check(opts(fm).pact, "'[Diplomacia] Vamos respeitar o territorio um do outro.'")
Rem.getStore().reputation[fam.id] = -10
local ok = DP.pact(fm)
check(not ok and not fam.pact, "sem confianca: recusam")
Rem.getStore().reputation[fam.id] = 10
local rel0 = Rem.relation(fam, g)
IA.choose("pact", fm, player)
check(fam.pact and Rem.relation(fam, g) == rel0 + DP.CFG.PACT_RELATION and lastJournal() == "IGUI_Rem_Journal_pact", "pacto fechado")
check(DP.protectedFrom(fam), "eles nao atacam a sua base")
Rem.changeRep(fam.id, -80, "teste")
check(not fam.pact and lastJournal() == "IGUI_Rem_Journal_pact_broken", "fazer algo grave contra eles acaba com o pacto")
-- tributo
local setDay = function(dd) Rem.getStore().timeline.startHours = Rem.worldHours() - 24 * dd end
setDay(30)
local band = Rem.createGroup("saqueadores", hs.x + 200, hs.y, "p2", 3)
band.activity = "home"
check(BE.raiders(g) == band, "(o bando e candidato a atacar a sua base)")
local rn = Rem.materialize(Rem.getPerson(band.members[1]))
Rem.Mugging.surrender(rn, Rem.nowMs())
check(opts(rn).tribute, "rendido: '[Diplomacia] Diga ao seu bando: pagamos ...'")
g.supplies = 1
ok = DP.tribute(rn)
check(not ok, "sem comida para pagar, nao da")
g.supplies = 10
IA.choose("tribute", rn, player)
check(g.supplies == 10 - DP.CFG.TRIBUTE and DP.paid(band) and lastJournal() == "IGUI_Rem_Journal_tribute", "tributo pago (sai do estoque)")
check(BE.raiders(g) == nil, "o bando deixa a base em paz")
T.worldHours = T.worldHours + DP.CFG.TRIBUTE_DAYS * 24
DP.hourly()
check(not DP.paid(band) and lastJournal() == "IGUI_Rem_Journal_tribute_over" and BE.raiders(g) == band, "o prazo acaba: eles voltam a cobrar")

-- ===================================================================== missoes pessoais
realPrint("440) Missoes pessoais")
fresh()
g, hs, list = base(2)
local seeker = list[1]
seeker.rec.story = { lost = 1, goal = 5 }
check(not opts(seeker).pq_offer, "(so depois de contar a historia)")
seeker.rec.toldStory = true
check(opts(seeker).pq_offer, "'[Pessoal] Posso te ajudar com aquilo?'")
local far = Rem.createGroup("civis", hs.x + 400, hs.y, "q1", 3)
l = IA.choose("pq_offer", seeker, player)
local q = seeker.rec.pquest
check(q and q.kind == "family" and q.gid == far.id and l.key == "IGUI_Rem_PQ_family_start", "familia: um parente esta vivo, com outro grupo")
check(Rem.MapMarks.find("pquest:" .. seeker.rec.id) ~= nil and lastJournal() == "IGUI_Rem_Journal_pq_family", "marcado no mapa e no diario")
local rel = Rem.getPerson(q.pid)
player.x, player.y = hs.x + 400, hs.y + 3
local rnpc = Rem.materialize(rel)
check(opts(rnpc).pq_reunite, "achou: '[Pessoal] Tem alguem procurando voce.'")
local mor = seeker.rec.moral or 50
IA.choose("pq_reunite", rnpc, player)
check(rnpc.rec.faction == "aliados" and PB.isMember(rnpc.rec) and Rem.Friends.isFriend(seeker.rec, rnpc.rec), "reencontro: o parente vem morar na base")
check(seeker.rec.pquestDone and (seeker.rec.moral or 0) > mor and hasJournal("IGUI_Rem_Journal_pq_reunion"), "(moral la em cima; diario)")
check(Rem.Chronicle.has("reunion"), "(e vira capitulo da cronica)")
-- parente morre antes
local s2 = list[2]
s2.rec.story, s2.rec.toldStory = { lost = 1, goal = 5 }, true
player.x, player.y = hs.x + 4, hs.y + 4
IA.choose("pq_offer", s2, player)
local pid = s2.rec.pquest.pid
Rem.removePerson(pid)
check(s2.rec.pquest == nil and s2.rec.griefUntil and lastJournal() == "IGUI_Rem_Journal_pq_family_dead", "o parente morreu antes: a noticia chega")
-- horta
local gardener = ally(hs.x + 3, hs.y + 2); PB.join(gardener)
gardener.rec.story, gardener.rec.toldStory = { lost = 1, goal = 6 }, true
IA.choose("pq_offer", gardener, player)
check(not opts(gardener).pq_plant, "(sem sementes ainda)")
player.inv:AddItem("Base.CarrotSeed")
check(opts(gardener).pq_plant, "com sementes: '[Pessoal] Trouxe sementes para a sua horta.'")
IA.choose("pq_plant", gardener, player)
check(g.garden and #player.inv.items == 0, "horta plantada na base")
local sup = g.supplies or 0
check(PQ.harvest(g) == 0, "(antes de uma semana, nada)")
T.worldHours = T.worldHours + PQ.CFG.GARDEN_DAYS * 24
check(PQ.harvest(g) == PQ.CFG.GARDEN_FOOD and g.supplies == sup + PQ.CFG.GARDEN_FOOD and lastJournal() == "IGUI_Rem_Journal_pq_harvest",
    "primeira colheita: comida todo dia")
-- norte
local dreamer = ally(hs.x + 3, hs.y + 1)
dreamer.rec.story, dreamer.rec.toldStory = { lost = 1, goal = 2 }, true
IA.choose("pq_offer", dreamer, player)
local nq = dreamer.rec.pquest
check(nq and nq.kind == "north" and nq.y < player.y, "o lugar ao norte vai para o mapa")
player.inv.items = {}
player.x, player.y = nq.x, nq.y
PQ.checkNorth(player)
check(dreamer.rec.pquestDone and #player.inv.items == PQ.CFG.NORTH_LOOT and lastJournal() == "IGUI_Rem_Journal_pq_north_found",
    "chegou la: um esconderijo, e ele fica em paz")

T.timeOfDay = 12
SandboxVars.Remanescentes.MaxActive = T.defaults().MaxActive
fresh()
