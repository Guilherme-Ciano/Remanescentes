-- Pacote 0.22: gasolina para o gerador, latas e estacas, os militares dos primeiros dias,
-- radio de pilha, eventos raros.
local T = ...
local Rem = Remanescentes
local check, tick = T.check, T.tick
local player, realPrint = T.player, T.print
local PB, IA, JN, BB, BE, WT, FU, TP, ML, RD, RE = Rem.PlayerBase, Rem.Interact, Rem.Journal, Rem.BaseBuild, Rem.BaseEvents,
    Rem.Watch, Rem.Fuel, Rem.Traps, Rem.Military, Rem.Radio, Rem.RareEvents

local function fresh()
    Rem.dismissAll(); T.clearZombies(); Rem.hunting = {}
    Rem.Mugging.enc = {}
    local s = Rem.getStore()
    s.reputation, s.quests, s.journal, s.playerBase, s.met, s.knownGroups = {}, {}, {}, nil, {}, {}
    s.checkpoint, s.rare, s.radioLastH, s.siege, s.caravans, s.wars = nil, nil, nil, nil, {}, {}
    player.inv.items = {}
    T.worldItems = {}
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
local always = function(a, b) if b then return a end return 0 end
local function opts(npc)
    local o = {}
    for _, id in ipairs(IA.dialogOptions(npc, player)) do o[id] = true end
    return o
end
local function ally(x, y)
    local npc = Rem.spawn(x, y, 0, { faction = "aliados", mode = "follow" })
    npc.rec.recruited = true
    return npc
end
local nextId = 300000
local function house()
    nextId = nextId + 400
    local x, y = nextId, 300000
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
        local a = ally(hs.x + 1 + i, hs.y + 3)
        PB.join(a)
        table.insert(list, a)
    end
    return g, hs, list
end
local function itemsAround(x, y, r)
    local n = 0
    for dx = -r, r do for dy = -r, r do n = n + #(T.worldItems[(x + dx) .. "," .. (y + dy)] or {}) end end
    return n
end
T.timeOfDay = 12
SandboxVars.Remanescentes.MaxActive = 30

-- ===================================================================== gasolina
realPrint("450) Gasolina para o gerador")
fresh()
setDay(30)
local g, hs, list = base(2)
local h = g.home
check(FU.defenseBonus(g) == 0 and not FU.has(g), "(sem gerador, sem luz)")
local gsq = getCell():getGridSquare(hs.x + 9, hs.y + 2, 0)
local gen = IsoGenerator.new(nil, getCell(), gsq)
h.builtGenerator, h.generator = true, { x = hs.x + 9, y = hs.y + 2, z = 0 }
local foundFuel = false
for _, j in ipairs(PB.JOBS) do if j == "fuel" then foundFuel = true end end
check(foundFuel and PB.TRIP_JOBS.fuel, "tarefa nova: buscar gasolina (em dupla)")
check(opts(list[1]).order_job_fuel, "'[Base] Busca gasolina para o gerador.'")
FU.add(g, 50)
T.timeOfDay = 22
FU.sync(g)
check(gen:isActivated() and gen:getFuel() == 50, "de noite, com gasolina: o gerador liga (o tanque vem do estoque)")
check(FU.defenseBonus(g) == FU.CFG.LIGHT_DEFENSE, "luz a noite: mais defesa")
gen:setFuel(44)          -- o jogo gastou
FU.sync(g)
check(FU.amount(g) == 44, "o que o gerador gastou sai do estoque")
T.timeOfDay = 12
FU.sync(g)
check(not gen:isActivated(), "de dia desligam para economizar")
-- longe de voce
h.genFuelSeen = nil
T.timeOfDay = 23
local m0 = list[1].rec.moral
h.fuel = 2
FU.hourly()
check(FU.amount(g) == 2 - FU.CFG.FUEL_PER_HOUR and list[1].rec.moral == m0 + FU.CFG.LIGHT_MORALE, "longe: gasta por hora e a luz anima")
FU.hourly()
check(FU.amount(g) == 0 and lastJournal() == "IGUI_Rem_Journal_fuel_out", "acabou: aviso no diario")
check(FU.defenseBonus(g) == 0, "(sem gasolina, sem luz)")
T.timeOfDay = 12
-- saidas
local before = FU.amount(g)
T.addBuilding(nextId + 9, hs.x + 30, hs.y, 5, 5)
g.nearby = nil
Rem.dematerialize(list[1]); Rem.dematerialize(list[2])
withRand(function(a, b) if b then return a end if a == 100 then return 99 end return 0 end, function()
    PB.tripOffscene(g, list[1].rec, list[2].rec, "fuel")
end)
check(FU.amount(g) == before + FU.CFG.TRIP[1] and lastJournal() == "IGUI_Rem_Journal_base_trip_fuel", "a dupla volta com gasolina (diario)")
local sip = Rem.spawn(hs.x + 2, hs.y + 2, 0, { faction = "aliados", mode = "group" })
FU.siphon(sip)
local carried = sip.rec.fuelCarry
check(carried >= FU.CFG.SIPHON[1], "em cena: sifonam carros")
before = FU.amount(g)
FU.deposit(sip, g)
check(FU.amount(g) == before + carried and sip.rec.fuelCarry == nil, "e guardam no estoque")
FU.add(g, 1000)
check(FU.amount(g) == FU.CFG.FUEL_MAX, "(tem limite: o tanque e uns galoes)")

-- ===================================================================== latas e estacas
realPrint("460) Latas de alarme e estacas")
fresh()
g, hs, list = base(2)
h = g.home
h.x1, h.y1, h.x2, h.y2 = hs.x, hs.y, hs.x + 8, hs.y + 6
local projs = {}
for _, p in ipairs(BB.projectsFor(g)) do projs[p] = true end
check(projs.cans and projs.traps, "obras novas na sua base: latas e estacas")
local band = Rem.createGroup("saqueadores", 310000, 310000, "x1", 3)
projs = {}
for _, p in ipairs(BB.projectsFor(band)) do projs[p] = true end
check(projs.traps and not projs.cans, "saqueadores: so estacas")
check(#BB.EXTRA.cans.plan(g, h) == TP.CFG.CANS_MAX, "plano: tantas latas quanto faltam")
for _ = 1, TP.CFG.CANS_FULL do BB.EXTRA.cans.apply(g, h, {}) end
check(TP.cansReady(h), "latas suficientes")
-- o vigia ouve mais longe
PB.setJob(list[1], "guard")
WT.updateRoles(g)
local far = T.newZombie(h.x2 + WT.CFG.ALARM_MARGIN + 3, hs.y + 2, 0)
local nz = WT.threats(g, list[1])
check(nz >= 1, "com latas, o vigia percebe de mais longe")
h.cans = 0
nz = WT.threats(g, list[1])
check(nz == 0, "(sem latas, nao)")
h.cans = TP.CFG.CANS_FULL
T.clearZombies()
-- surpresa menor
T.timeOfDay = 1
for _, n in ipairs(list) do PB.setJob(n, "rest") end
local d0 = BE.defense(g)
check(math.abs(WT.adjustDefense(g, d0) - d0 * TP.CFG.CANS_SURPRISE) < 0.001, "sem vigia, as latas ainda acordam alguem")
T.timeOfDay = 12
-- estacas fora de cena
for _ = 1, 10 do BB.EXTRA.traps.apply(g, h, {}) end
check(h.traps == TP.CFG.TRAPS_MAX and TP.hordeStopped(h) == TP.CFG.TRAP_HORDE_MAX, "estacas seguram parte da horda")
player.x = hs.x + 3000
for _, n in ipairs(list) do Rem.dematerialize(n) end
local held = nil
withRand(function(a, b) if b then return b end return 0 end, function() held = BE.horde(g) end)
check(h.traps == TP.CFG.TRAPS_MAX - TP.CFG.TRAP_HORDE_MAX, "(e se gastam)")
-- em cena
player.x, player.y = hs.x + 4, hs.y + 4
local zr = T.newZombie(h.x1 - 1, hs.y + 3, 0)
local hp0 = zr:getHealth()
local t0 = h.traps
withRand(always, function() TP.check(g) end)
check(h.traps == t0 - 1 and (zr.dead or zr:getHealth() < hp0), "zumbi no anel entre a cerca e a casa cai numa estaca")
withRand(always, function() TP.check(g) end)
check(h.traps == t0 - 1, "(cada zumbi so cai uma vez)")
T.clearZombies()

-- ===================================================================== militares
realPrint("470) Os militares dos primeiros dias")
fresh()
setDay(0)
player.x, player.y = 320000, 320000
ML.tick(player, Rem.nowMs())
local cp = ML.get()
check(cp and cp.state == "manned" and Rem.MapMarks.find("checkpoint") and hasJournal("IGUI_Rem_Journal_checkpoint"),
    "primeiros dias: uma barreira militar perto (mapa e diario)")
player.x, player.y = cp.x + 10, cp.y
ML.tick(player, Rem.nowMs())
local soldiers = {}
for _, n in pairs(Rem.active) do if n.rec.ambient == "soldier" then table.insert(soldiers, n) end end
check(#soldiers == ML.CFG.SOLDIERS and soldiers[1].rec.faction == "militares" and soldiers[1].rec.firearm, "soldados armados guardam o lugar")
check(not Rem.isHostileToPlayer(soldiers[1]) and Rem.npcsHostile(soldiers[1], Rem.spawn(cp.x + 30, cp.y, 0, { faction = "saqueadores", mode = "stay" })),
    "nao atacam voce; saqueadores sim")
local sd = soldiers[1]
player.x, player.y = sd.z:getX() + 3, sd.z:getY()
sd.rec.lastBark = nil
Rem.Ambient.HANDLERS.soldier(sd, { player = player }, Rem.nowMs() + 999999)
check(IA.status(sd).key == "IGUI_Rem_Military_status_1", "conversar: so noticias oficiais")
setDay(ML.CFG.ABANDON_DAY)
player.x, player.y = cp.x + 200, cp.y
ML.tick(player, Rem.nowMs())
check(cp.state == "abandoned" and lastJournal() == "IGUI_Rem_Journal_checkpoint_gone", "no dia 5 eles somem sem explicacao")
local z0 = #T.zombies
player.x, player.y = cp.x + 5, cp.y
ML.tick(player, Rem.nowMs())
check(cp.state == "looted" and #T.zombies > z0 and itemsAround(cp.x, cp.y, 1) == ML.CFG.LOOT_N, "a barreira ficou para tras: zumbis de farda e a carga no chao")
check(Rem.Chronicle.has("checkpoint"), "(capitulo da cronica)")
ML.tick(player, Rem.nowMs())
check(itemsAround(cp.x, cp.y, 1) == ML.CFG.LOOT_N, "(so uma vez)")

-- ===================================================================== radio
realPrint("480) Radio de pilha")
fresh()
setDay(0)
player.x, player.y = 330000, 330000
check(not RD.hasRadio(player), "sem radio, nada")
player.inv:AddItem("Base.RadioRed")
check(RD.hasRadio(player), "radio no inventario")
ML.place(player)
local k = RD.listen(player, "military")
check(k == "military" and lastJournal() == "IGUI_Rem_Radio_checkpoint", "primeiros dias: avisos oficiais (manda ir para a barreira)")
local raiders = Rem.createGroup("saqueadores", 330200, 330000, "r1", 3)
RD.listen(player, "raiders")
check(lastJournal() == "IGUI_Rem_Radio_raiders" and Rem.Journal.knows(raiders), "saqueadores se gabando entregam onde estao")
local hungry = Rem.createGroup("civis", 330300, 330000, "r2", 3)
hungry.supplies = 0
RD.listen(player, "distress")
check(lastJournal() == "IGUI_Rem_Radio_distress" and Rem.Journal.knows(hungry), "pedido de socorro (o grupo vai para o mapa)")
setDay(20)
RD.listen(player, "military")
check(lastJournal() == "IGUI_Rem_Radio_static", "depois de umas semanas: so chiado")
RD.listen(player, "chatter")
check(lastJournal():find("IGUI_Rem_Radio_chatter_", 1, true) == 1, "gente comum no ar")
Rem.getStore().radioLastH = nil
local n0 = #JN.entries()
withRand(always, function() RD.hourly() end)
check(#JN.entries() == n0 + 1, "de tempos em tempos, uma transmissao")
withRand(always, function() RD.hourly() end)
check(#JN.entries() == n0 + 1, "(nao toda hora)")
player.inv.items = {}

-- ===================================================================== eventos raros
realPrint("490) Eventos raros")
fresh()
setDay(10)
g, hs, list = base(1)
g.supplies = 20
player.x = hs.x + 3000
check(RE.fire("doctor", player) == "doctor", "um medico pede abrigo")
local doc = nil
for _, p in ipairs(PB.members(g)) do if p.archetype == "medico" and p ~= list[1].rec then doc = p end end
check(doc and hasJournal("IGUI_Rem_Journal_rare_doctor"), "longe de voce: os moradores aceitam (medico de verdade)")
check(RE.fire("doctor", player) == nil, "(so uma vez por campanha)")
player.x, player.y = 340000, 340000
check(RE.fire("convoy", player) == "convoy", "comboio abandonado avistado")
local c = RE.store().convoySpot
check(Rem.MapMarks.find("convoy") ~= nil, "(marcado no mapa)")
local zc = #T.zombies
player.x, player.y = c.x, c.y
RE.arriveConvoy(c, player)
check(c.found and #T.zombies > zc and itemsAround(c.x, c.y + 2, 1) == RE.CFG.CONVOY_LOOT_N and lastJournal() == "IGUI_Rem_Journal_rare_convoy_found",
    "chegando la: zumbis de farda e a carga espalhada")
check(RE.fire("cult", player) == nil, "(sem seita no mapa, sem convite)")
local cult = Rem.createGroup("seita", 340300, 340000, "s1", 3)
local rep0 = Rem.getRep(cult.id)
check(RE.fire("cult", player) == "cult" and Rem.getRep(cult.id) == rep0 + RE.CFG.CULT_REP and Rem.MapMarks.find("group:" .. cult.id),
    "a seita convida voce")
Rem.getStore().rare = {}
setDay(1)
withRand(always, function() RE.daily() end)
check(not RE.done("doctor") and not RE.done("convoy"), "(cedo demais: nada)")

T.timeOfDay = 12
SandboxVars.Remanescentes.MaxActive = T.defaults().MaxActive
fresh()
