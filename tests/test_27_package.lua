-- Pacote 0.18: necessidades dos aliados, escala de vigia com alarme, ordens de combate,
-- prisioneiros e interrogatorio, painel da base.
local T = ...
local Rem = Remanescentes
local check, tick = T.check, T.tick
local player, realPrint = T.player, T.print
local PB, BE, IA, JN, ND, WT, OR, PR = Rem.PlayerBase, Rem.BaseEvents, Rem.Interact, Rem.Journal, Rem.Needs, Rem.Watch,
    Rem.Orders, Rem.Prisoners

local function fresh()
    Rem.dismissAll(); T.clearZombies(); Rem.hunting = {}
    Rem.Mugging.enc = {}
    OR.focus = nil
    local s = Rem.getStore()
    s.reputation, s.quests, s.journal, s.playerBase, s.met, s.knownGroups = {}, {}, {}, nil, {}, {}
    player.inv.items = {}
    player.weapon = nil
end
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
local nextId = 120000
local function house()
    nextId = nextId + 400
    local x, y = nextId, 120000
    local def = T.addBuilding(nextId + 1, x, y, 8, 6)
    for i = x, x + 7 do for j = y, y + 5 do T.indoorSq[i .. "," .. j] = true; T.sqBuilding[i .. "," .. j] = def end end
    T.addObject(x + 2, y, 0, "IsoWindow", { exterior = true })
    T.addObject(x + 4, y + 5, 0, "IsoDoor", { exterior = true })
    T.addObject(x + 2, y + 2, 0, "container", { type = "fridge" })
    return { def = def, x = x, y = y }
end
local function hourly(n) for _ = 1, (n or 1) do Rem.emit("worldHour", Rem.worldHours()) end end
local function lastJournal() local l = JN.entries() return l[#l] and l[#l].key end
local function withRand(fn, body)
    local real = ZombRand
    ZombRand = fn
    local ok, err = pcall(body)
    ZombRand = real
    if not ok then error(err) end
end
T.timeOfDay = 12
SandboxVars.Remanescentes.MaxActive = 30

-- ===================================================================== necessidades
realPrint("240) Necessidades: fome de quem segue voce")
fresh()
player.x, player.y = 130000, 130000
local a = ally(130002, 130000)
a.rec.pockets = { "Base.TinnedBeans", "Base.Bandage" }
a.rec.fome, a.rec.cansaco, a.rec.moral = 0, 0, 60
hourly(5)
check(a.rec.fome == 5 * ND.CFG.HUNGER_RATE, "a fome sobe com as horas (" .. tostring(a.rec.fome) .. ")")
check(a.rec.cansaco == 5 * ND.CFG.TIRED_RATE, "o cansaco tambem")
a.rec.fome = ND.CFG.POCKET_EAT_AT - 1
hourly()
check(#a.rec.pockets == 1 and a.rec.pockets[1] == "Base.Bandage" and a.rec.fome < ND.CFG.POCKET_EAT_AT,
    "com fome, come o que tem nos bolsos (a atadura fica)")
a.rec.fome = ND.CFG.ASK_FOOD_AT
a.rec.askedFoodAt = nil
T.speech = {}
local before = a.rec.lastBark
hourly()
check(a.rec.askedFoodAt ~= nil, "sem nada nos bolsos: pede comida")
check(IA.status(a).key == "IGUI_Rem_Needs_status_hungry", "a situacao dele fala da fome")
check(not opts(a).feed, "sem comida na sua mochila: a opcao de dar comida nao aparece")
player.inv:AddItem("Base.TinnedSoup")
check(opts(a).feed, "com comida: '[Comida] Toma, come isto.'")
local f0, b0 = a.rec.fome, a.rec.bond or 0
local l = IA.choose("feed", a, player)
check(a.rec.fome == math.max(0, f0 - ND.CFG.FOOD_VALUE) and #player.inv.items == 0 and l.key == "IGUI_Rem_Needs_fed",
    "ele come a sua lata (sai da mochila)")
check((a.rec.bond or 0) > b0 and a.rec.mem[#a.rec.mem].k == "fed", "e lembra de quem deu comida (vinculo)")
check(Rem.Persona.mood(a.rec) ~= "faminto", "deixa de estar faminto")

realPrint("241) Necessidades: cansaco e cochilo")
a.rec.cansaco = ND.CFG.SHOW_NAP_AT + 5
check(opts(a).nap, "cansado: '[Descanso] Tira um cochilo.'")
a.rec.cansaco = ND.CFG.ASK_SLEEP_AT + 1
check(Rem.Persona.mood(a.rec) == "cansado", "humor: cansado")
check(ND.damageMult(a.rec) == 1, "(ainda briga normal)")
a.rec.cansaco = ND.CFG.WEAK_TIRED
check(math.abs(ND.damageMult(a.rec) - ND.CFG.WEAK_TIRED_MULT) < 0.001 and ND.accuracyPenalty(a.rec) == ND.CFG.WEAK_ACCURACY,
    "exausto: bate mais fraco e erra mais")
l = IA.choose("nap", a, player)
check(l.key == "IGUI_Rem_Needs_nap" and a.rec.napUntil and a.rest == "sleep", "deita para cochilar ali mesmo")
a.talkingUntil = nil
local handled = Rem.runBehaviors(a, { player = player }, Rem.nowMs())
check(handled == "nap", "dormindo: o cochilo segura ele no lugar (nao sai seguindo)")
local c0 = a.rec.cansaco
hourly()
check(a.rec.cansaco == c0 - ND.CFG.SLEEP_RECOVER, "dormindo, o cansaco cai")
-- zumbi chega perto: acorda
local z = T.newZombie(130003, 130000, 0)
tick(300, 2)
check(a.rest ~= "sleep" and a.rec.napUntil == nil, "zumbi perto: acorda")
T.clearZombies()
T.worldHours = T.worldHours + ND.CFG.NAP_HOURS + 1

realPrint("242) Necessidades: quem desiste")
a.rec.fome, a.rec.moral = ND.CFG.STARVING, ND.CFG.DESERT_MORALE - 5
a.rec.pockets = {}
hourly()
check(a.rec.faction == "civis" and lastJournal() == "IGUI_Rem_Journal_deserted", "fome demais e moral no chao: vai embora (diario)")

realPrint("243) Necessidades: moradores da base")
fresh()
local hs = house()
player.x, player.y = hs.x + 4, hs.y + 4
local g = PB.setHere(player)
local m1 = ally(hs.x + 3, hs.y + 3); PB.join(m1); PB.setJob(m1, "build")
m1.rec.fome, m1.rec.cansaco = 40, 40
g.supplies = 5
hourly()
check(m1.rec.fome == 40 - ND.CFG.BASE_EAT, "com comida no estoque: a fome cai")
check(m1.rec.cansaco == 40 + ND.CFG.TIRED_RATE + ND.CFG.WORK_TIRED, "fortificar cansa mais")
g.supplies = 0
hourly()
check(m1.rec.fome == 40 - ND.CFG.BASE_EAT + ND.CFG.HUNGER_RATE, "estoque vazio: a fome sobe")
T.timeOfDay = 23
local c1 = m1.rec.cansaco
hourly()
check(ND.sleeping(m1.rec) and m1.rec.cansaco == c1 - ND.CFG.SLEEP_RECOVER, "a noite o morador dorme e descansa")
T.timeOfDay = 12

-- ===================================================================== vigia
realPrint("250) Vigia: escala da noite")
fresh()
hs = house()
player.x, player.y = hs.x + 4, hs.y + 4
g = PB.setHere(player)
local gA = ally(hs.x + 3, hs.y + 3); PB.join(gA); PB.setJob(gA, "guard")
local gB = ally(hs.x + 5, hs.y + 3); PB.join(gB); PB.setJob(gB, "guard")
local wk = ally(hs.x + 4, hs.y + 2); PB.join(wk); PB.setJob(wk, "build")
local first = (tostring(gA.rec.id) < tostring(gB.rec.id)) and gA or gB
local second = (first == gA) and gB or gA
T.timeOfDay = 22
check(WT.shift() == 1 and WT.onDuty(g) == first.rec, "primeiro turno: o primeiro vigia")
T.timeOfDay = 1
check(WT.shift() == 2 and WT.onDuty(g) == second.rec, "segundo turno: o outro (revezam)")
check(WT.onWatch(second.rec) and not WT.onWatch(first.rec), "so um de cada vez no posto")
WT.updateRoles(g)
check(second.rec.role == "guarda" and first.rec.role == "morador", "o de folga dorme como morador; o do turno fica na porta")
check(ND.sleeping(first.rec) and not ND.sleeping(second.rec), "(e as necessidades sabem disso)")
local roster = WT.roster(g)
check(#roster == 3 and roster[1].rec == first.rec and roster[2].rec == second.rec and roster[3].rec == first.rec, "escala: A, B, A")
check(WT.covered(g), "noite coberta")
T.timeOfDay = 12
WT.updateRoles(g)
check(first.rec.role == "guarda" and second.rec.role == "guarda", "de dia, os dois vigias ficam no posto")

realPrint("251) Vigia: cochilo no posto e noite sem vigia")
T.timeOfDay = 1
second.rec.cansaco = WT.CFG.DOZE_AT + 5
withRand(function(x, y) if x == 100 and not y then return 0 end return 0 end, function() WT.hourly() end)
check(not WT.covered(g) and lastJournal() == "IGUI_Rem_Journal_watch_dozed", "vigia exausto cochila no posto: a noite fica descoberta")
local d0 = BE.defense(g)
check(math.abs(WT.adjustDefense(g, d0) - d0 * WT.CFG.SURPRISE_MULT) < 0.001, "pegos de surpresa: menos defesa")
g.dozedH = nil
check(math.abs(WT.adjustDefense(g, d0) - (d0 + WT.CFG.COVERED_BONUS)) < 0.001, "vigia acordado: avisa a tempo (mais defesa)")
T.timeOfDay = 12
check(WT.adjustDefense(g, d0) == d0, "(de dia nao muda)")
-- ladrao: so o vigia acordado espanta
T.timeOfDay = 1
g.dozedH = math.floor(Rem.worldHours())
g.supplies = 4
check(BE.thief(g) == "stolen", "vigia dormindo: o ladrao leva comida")
g.dozedH = nil
check(BE.thief(g) == "scared", "vigia acordado: espanta o ladrao")
-- sem vigias
PB.setJob(gA, "rest"); PB.setJob(gB, "rest")
g.noWatchNoted = nil
WT.hourly()
check(not WT.covered(g) and lastJournal() == "IGUI_Rem_Journal_watch_none", "ninguem na vigia: o diario avisa")
T.timeOfDay = 12

realPrint("252) Vigia: alarme")
PB.setJob(gA, "guard")
WT.updateRoles(g)
T.timeOfDay = 23
WT.updateRoles(g)
wk.rec.mode = "group"
Rem.setRest(wk, "sleep")
g.alarmUntil, g.alarmCooldown = nil, nil
T.newZombie(hs.x + 10, hs.y + 2, 0)
WT.tick(player, Rem.nowMs() + 100000)
check(WT.alarmOn(g) and wk.rest ~= "sleep", "o vigia ve o zumbi chegando: alarme, quem dormia acorda")
check(lastJournal() == "IGUI_Rem_Journal_alarm_zombies", "o alarme vai para o diario")
check(not ND.sleeping(wk.rec), "durante o alarme ninguem dorme")
local h2 = Rem.runBehaviors(wk, { player = player }, Rem.nowMs())
check(h2 == "alarm", "quem nao esta brigando vai para perto da porta")
T.clearZombies()
T.timeOfDay = 12

-- ===================================================================== ordens
realPrint("260) Ordens de combate")
fresh()
player.x, player.y = 140000, 140000
local f1 = ally(140002, 140000)
local f2 = ally(140003, 140001)
local o1 = opts(f1)
check(o1.order_stance_hold and o1.order_stance_aggressive and not o1.order_stance_normal and not o1.order_retreat,
    "conversa: segurar fogo, atacar a vontade (recuar so com base)")
l = IA.choose("order_stance_hold", f1, player)
check(f1.rec.stance == "hold" and l.key == "IGUI_Rem_Order_stance_hold", "segura o fogo")
local zz = T.newZombie(140005, 140000, 0)
local e, d = OR.filter(f1, zz, 3, Rem.nowMs())
check(e == nil, "segurando fogo: nao vai atras de zumbi a 3 tiles")
e = OR.filter(f1, zz, 1, Rem.nowMs())
check(e == zz, "...mas se defende de quem esta colado")
f1.rec.firearm, f1.rec.ammo = "Base.Pistol", 10
check(Rem.tryRanged(f1, zz, 5, Rem.nowMs()) == false, "e nao atira")
check(opts(f1).order_stance_normal, "pode voltar ao normal")
IA.choose("order_stance_normal", f1, player)
check(f1.rec.stance == nil, "normal de novo")
OR.orderAll("aggressive")
check(f1.rec.stance == "aggressive" and f2.rec.stance == "aggressive", "para todos: atacar a vontade")
local foundAgg = false
for _, o in ipairs(Rem.playerOptions) do if o.labelKey == "ContextMenu_Rem_AllAggressive" then foundAgg = o.condition() end end
check(foundAgg, "(menu do clique direito)")
OR.orderAll("normal")
-- alvo marcado
local far = T.newZombie(140012, 140000, 0)
local tgt = nil
for _, o in ipairs(Rem.targetOptions) do if o.labelKey == "ContextMenu_Rem_AttackThis" then tgt = o end end
check(tgt and tgt.condition(far), "clique direito num zumbi: 'Aliados: ataquem este!'")
tgt.fn(far, player)
e, d = OR.filter(f1, zz, 3, Rem.nowMs())
check(e == far, "alvo marcado: largam o resto e vao nele")
check(OR.isFocus(far), "(e vao atras dele de longe)")
far.dead = true
e = OR.filter(f1, zz, 3, Rem.nowMs())
check(e == zz and OR.focus == nil, "alvo morto: voltam a decidir sozinhos")
T.clearZombies()

realPrint("261) Recuar para a base")
local hr = house()
local gb = PB.setHere({ getX = function() return hr.x + 4 end, getY = function() return hr.y + 4 end, getZ = function() return 0 end })
check(gb ~= nil, "(base)")
check(opts(f1).order_retreat, "com base: '[Combate] Recua para a base!'")
IA.choose("order_retreat", f1, player)
check(f1.rec.stance == "retreat", "recuando")
f1.z.path, f1.nextPath, f1.lastPathX = nil, 0, nil
f1.talkingUntil = nil
local h3 = Rem.runBehaviors(f1, { player = player }, Rem.nowMs())
check(h3 == "retreat" and f1.z.path and math.abs(f1.z.path[1] - gb.home.x) < 1, "corre para a base, nao para voce")
f1.z.x, f1.z.y = gb.home.x, gb.home.y
Rem.runBehaviors(f1, { player = player }, Rem.nowMs())
check(f1.rec.stance == nil and f1.rec.mode == "stay", "chegou: fica esperando la")
-- fora de cena
f2.rec.stance = "retreat"
Rem.dematerialize(f2)
OR.hourly()
check(f2.rec.mode == "stay" and math.abs(f2.rec.x - gb.home.x) < 2, "quem saiu de cena no caminho chega na base")

-- ===================================================================== prisioneiros
realPrint("270) Prisioneiros: levar e prender")
fresh()
hs = house()
player.x, player.y = hs.x + 4, hs.y + 4
g = PB.setHere(player)
local guard = ally(hs.x + 3, hs.y + 3); PB.join(guard); PB.setJob(guard, "guard")
local band = Rem.createGroup("saqueadores", hs.x + 250, hs.y, nil, 3)
band.activity = "home"
-- um saqueador do bando, em cena, perto de voce (cria mais se precisar)
local function raider(x, y)
    for _, id in ipairs(band.members) do
        local p = Rem.getPerson(id)
        if p and not p.onScene then
            local n = Rem.materialize(p)
            if n then n.z.x, n.z.y = x, y return n end
        end
    end
    local n = Rem.spawn(x, y, 0, { faction = "saqueadores", mode = "group" })
    n.rec.groupId = band.id
    table.insert(band.members, n.rec.id)
    return n
end
local rn = raider(hs.x + 9, hs.y + 4)
check(not opts(rn).prisoner_take, "(hostil de pe: nada de prisioneiro)")
Rem.Mugging.surrender(rn, Rem.nowMs())
check(opts(rn).prisoner_take, "rendido: '[Prisioneiro] Voce vem comigo.'")
local bandN = #band.members
l = IA.choose("prisoner_take", rn, player)
check(rn.rec.prisoner == "escort" and rn.rec.bandId == band.id and #band.members == bandN - 1 and l.key == "IGUI_Rem_Prisoner_taken",
    "vira prisioneiro (sai do bando)")
check(not Rem.isHostileToPlayer(rn) and not Rem.npcsHostile(rn, guard), "ninguem briga com o preso (nem ele com ninguem)")
Rem.Reputation.apply(rn.rec)
check(not Rem.isHostileToPlayer(rn), "(a reputacao do bando nao o torna hostil de novo)")
local zp = T.newZombie(hs.x + 10, hs.y + 4, 0)
local pe, pd, pflee = OR.filter(rn, zp, 1.5, Rem.nowMs())
check(pe == zp and pflee, "zumbi colado: o preso foge (nao briga)")
T.clearZombies()
rn.z.path, rn.nextPath, rn.lastPathX = nil, 0, nil
rn.talkingUntil = nil
rn.z.x, rn.z.y = hs.x + 14, hs.y + 4
check(Rem.runBehaviors(rn, { player = player }, Rem.nowMs()) == "prisoner" and rn.z.path, "anda atras de voce")
local po = opts(rn)
check(not po.trade and not po.gift and po.prisoner_interrogate and po.prisoner_release, "conversa de prisioneiro: so o que importa")
check(not po.prisoner_hold, "fora da base: ainda nao da para prender")
rn.z.x, rn.z.y = hs.x + 3, hs.y + 2
check(opts(rn).prisoner_hold, "dentro da base: '[Prisioneiro] Fica preso aqui.'")
IA.choose("prisoner_hold", rn, player)
check(rn.rec.prisoner == "held" and #PR.list(g) == 1 and rn.rec.cell, "preso na base, com um canto dele")
Rem.runBehaviors(rn, { player = player }, Rem.nowMs())

realPrint("271) Prisioneiros: interrogatorio")
setDay = function(dd) Rem.getStore().timeline.startHours = Rem.worldHours() - 24 * dd end
setDay(30)
check(BE.raiders(g) == band, "(o bando dele e quem atacaria a sua base)")
rn.rec.personality = rn.rec.personality or {}
rn.rec.personality.coragem = 8
local chance0 = PR.talkChance(rn, player)
withRand(function(x, y) if x == 100 and not y then return 99 end return x end, function() l = IA.choose("prisoner_interrogate", rn, player) end)
check(l.key == "IGUI_Rem_Prisoner_silent" and not rn.rec.talked, "primeira vez: fica calado")
check(PR.talkChance(rn, player) > chance0, "cada tentativa amolece")
l = IA.choose("prisoner_interrogate", rn, player)
check(l.key == "IGUI_Rem_Prisoner_tooSoon", "pressionar de novo logo: ainda e cedo")
T.worldHours = T.worldHours + PR.CFG.INTERROGATE_HOURS
local w = T.newWeapon("Base.BaseballBat"); player.weapon = w
check(PR.talkChance(rn, player) > PR.talkChance(rn, nil), "arma na mao ajuda")
withRand(function(x, y) if x == 100 and not y then return 0 end return x end, function() l = IA.choose("prisoner_interrogate", rn, player) end)
check(rn.rec.talked and l.key == "IGUI_Rem_Prisoner_talk_raid", "ele fala: onde fica o bando e que iam atacar")
check(JN.knows(band) and Rem.MapMarks.find("group:" .. band.id) ~= nil, "o esconderijo vai para o mapa e o diario")
check(Rem.worldHours() - g.lastRaid < BE.CFG.RAID_COOLDOWN_H, "o ataque a sua base atrasa")
player.weapon = nil

realPrint("272) Prisioneiros: resgate, recrutar, soltar, fugir")
check(opts(rn).prisoner_ransom, "bando vivo: '[Prisioneiro] Seu bando vai pagar por voce.'")
local rep0 = Rem.getRep(band.id)
local sup0 = g.supplies or 0
l = IA.choose("prisoner_ransom", rn, player)
check(not rn.rec.prisoner and rn.rec.groupId == band.id and #PR.list(g) == 0, "resgate pago: ele volta para o bando")
check(#(g.pendingList or {}) == PR.CFG.RANSOM_ITEMS and Rem.getRep(band.id) > rep0, "itens no seu estoque; o bando gosta do acordo")
check(lastJournal() == "IGUI_Rem_Journal_prisoner_ransom", "(diario)")
-- recrutar
local rn2 = raider(hs.x + 3, hs.y + 3)
Rem.Mugging.surrender(rn2, Rem.nowMs())
PR.take(rn2); PR.hold(rn2)
rn2.rec.moral = 80
check(not PR.recruit(rn2) and IA.hint("prisoner_recruit", rn2).key == "IGUI_Rem_Hint_prisoner", "recem-preso: ainda nao confia (e diz quanto falta)")
T.worldHours = T.worldHours + PR.CFG.RECRUIT_HOURS
check(PR.recruit(rn2) and rn2.rec.faction == "aliados" and PB.isMember(rn2.rec), "depois de uns dias bem tratado: vira morador da base")
-- soltar
local rn3 = raider(hs.x + 3, hs.y + 2)
Rem.Mugging.surrender(rn3, Rem.nowMs())
PR.take(rn3)
rep0 = Rem.getRep(band.id)
IA.choose("prisoner_release", rn3, player)
check(not rn3.rec.prisoner and Rem.getRep(band.id) > rep0, "soltar: o bando lembra do gesto")
-- fuga longe de voce
local rn4 = raider(hs.x + 3, hs.y + 2)
Rem.Mugging.surrender(rn4, Rem.nowMs())
PR.take(rn4); PR.hold(rn4)
local rec4 = rn4.rec
Rem.dematerialize(rn4)
rec4.onScene = false
g.supplies = 0
PB.setJob(guard, "rest")
check(PR.escapeChance(g) == PR.CFG.ESCAPE_BASE + PR.CFG.ESCAPE_UNWATCHED + PR.CFG.ESCAPE_HUNGRY, "sem vigia e sem comida: mais chance de fugir")
g.lastRaid = Rem.worldHours()
withRand(function(x, y) if x == 100 and not y then return 0 end return x end, function() PR.hourly() end)
check(not rec4.prisoner and rec4.groupId == band.id and g.lastRaid == nil and lastJournal() == "IGUI_Rem_Journal_prisoner_escaped",
    "fugiu: volta para o bando e conta onde fica a base")

-- ===================================================================== painel
realPrint("280) Painel da base")
require "Remanescentes/Rem_BasePanel"
PB.setJob(guard, "guard")
local held = raider(hs.x + 3, hs.y + 2)
Rem.Mugging.surrender(held, Rem.nowMs()); PR.take(held); PR.hold(held)
local realGet = getText
getText = function(k, ...) return k .. " " .. table.concat({ ... }, " ") end
local text = RemBasePanel.compose(player)
local label = RemBasePanel.memberLabel(guard.rec)
getText = realGet
check(text:find("IGUI_Rem_Panel_people", 1, true) and text:find("IGUI_Rem_Panel_defense", 1, true)
    and text:find("IGUI_Rem_Panel_shift", 1, true) and text:find(tostring(guard.rec.name), 1, true)
    and text:find("IGUI_Rem_Panel_prisoner", 1, true), "resumo: moradores, defesa, escala de vigia, prisioneiros")
check(label:find("IGUI_Rem_Job_guard", 1, true) and label:find(tostring(guard.rec.name), 1, true), "linha do morador: nome e tarefa")
local pw = RemBasePanel.open(player)
check(pw.shown and #pw.rows == #PB.members(g), "janela abre com um botao por morador")
local btn = nil
for _, b in ipairs(pw.rows) do if b.rec == guard.rec then btn = b end end
pw:onMember(btn)
check(guard.rec.job == PB.nextJob("guard") and guard.rec.job == "scav", "clicar troca a tarefa (vigiar -> buscar)")
Rem.dematerialize(guard)
for _, b in ipairs(pw.rows) do if b.rec == guard.rec then btn = b end end
pw:onMember(btn)
check(guard.rec.job == "materials", "funciona com a pessoa longe (fora de cena)")
pw:close()
local foundPanel = false
for _, o in ipairs(Rem.playerOptions) do if o.labelKey == "ContextMenu_Rem_BasePanel" then foundPanel = o.condition() end end
check(foundPanel, "clique direito -> 'Painel da base'")

T.timeOfDay = 12
SandboxVars.Remanescentes.MaxActive = T.defaults().MaxActive
fresh()
