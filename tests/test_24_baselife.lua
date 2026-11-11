-- Base viva: obras em fila (janelas, portas, reforco, cerca, carros queimados), saidas de
-- material em dupla, e eventos (horda, visitante, briga, ladrao, festa).
local T = ...
local Rem = Remanescentes
local check, tick = T.check, T.tick
local player, realPrint = T.player, T.print
local PB, BB, BE, IA, JN = Rem.PlayerBase, Rem.BaseBuild, Rem.BaseEvents, Rem.Interact, Rem.Journal

local function fresh()
    Rem.dismissAll(); T.clearZombies(); Rem.hunting = {}
    Rem.Mugging.enc = {}
    local s = Rem.getStore()
    s.reputation, s.quests, s.journal, s.playerBase = {}, {}, {}, nil
    player.inv.items = {}
    T.vehicles = {}
    BB.last = {}
end
local nextId = 60000
-- casa 8x6, com 2 janelas ao norte, porta principal ao sul e porta dos fundos a oeste
local function house()
    nextId = nextId + 400
    local x, y = nextId, 60000
    local def = T.addBuilding(nextId + 1, x, y, 8, 6)
    for i = x, x + 7 do for j = y, y + 5 do T.indoorSq[i .. "," .. j] = true; T.sqBuilding[i .. "," .. j] = def end end
    local w1 = T.addObject(x + 2, y, 0, "IsoWindow", { exterior = true })
    local w2 = T.addObject(x + 5, y, 0, "IsoWindow", { exterior = true })
    local front = T.addObject(x + 4, y + 5, 0, "IsoDoor", { exterior = true })
    local back = T.addObject(x, y + 3, 0, "IsoDoor", { exterior = true })
    local fridge = T.addObject(x + 2, y + 2, 0, "container", { type = "fridge" })
    return { def = def, x = x, y = y, windows = { w1, w2 }, front = front, back = back, fridge = fridge }
end
local function ally(x, y)
    local npc = Rem.spawn(x, y, 0, { faction = "aliados", mode = "follow" })
    npc.rec.recruited = true
    return npc
end
local function fences()
    local n = 0
    for _, list in pairs(T.sqObjects) do
        for _, o in ipairs(list) do if o._class == "IsoThumpable" and o.md and o.md.remFence then n = n + 1 end end
    end
    return n
end
local function base(withBuilder)
    local hs = house()
    player.x, player.y = hs.x + 4, hs.y + 4
    local g = PB.setHere(player)
    local b = ally(hs.x + 3, hs.y + 3)
    PB.join(b)
    PB.setJob(b, withBuilder == false and "rest" or "build")
    b.talkingUntil = nil
    return g, hs, b
end
T.timeOfDay = 10
SandboxVars.Remanescentes.MaxActive = 20

realPrint("210) Fila de obras")
fresh()
local g, hs, b = base()
local plan = BB.scan(g)
check(#plan.windows == 2 and #plan.doors == 1 and #plan.perimeter > 0, "janelas, a porta dos fundos (a principal nunca) e a cerca na lista")
check(plan.doors[1].obj == hs.back, "(a porta dos fundos)")
check(g.home.plan.windows == 2 * BB.CFG.WINDOW_PLANKS and g.home.plan.doors == BB.CFG.WINDOW_PLANKS, "contas por tabua")
local p1 = BB.next(g, plan)
check(p1 == "windows", "primeiro as janelas")
-- cerca: retangulo em volta, com passagem na frente da porta principal
local sq = BB.fenceSquares(g.home)
local gapOk, around = true, 0
local m = BB.CFG.PERIM_MARGIN
for _, f in ipairs(sq) do
    if f.north and f.y == hs.y + 6 - 1 + m + 1 and math.abs(f.x - (hs.x + 4)) <= BB.CFG.GAP then gapOk = false end
    around = around + 1
end
local full = 2 * (8 + 2 * m) + 2 * (6 + 2 * m)
check(gapOk and around == full - (2 * BB.CFG.GAP + 1), "cerca a " .. m .. " tiles das paredes, com passagem na frente da porta (" .. around .. " pedacos)")

local savedDoor = g.home.mainDoor
g.home.mainDoor = { x = hs.x + 4, y = hs.y, z = 0 }            -- porta ao norte
local northGap = false
for _, f in ipairs(BB.fenceSquares(g.home)) do
    if f.north and f.y == hs.y - m and math.abs(f.x - (hs.x + 4)) <= BB.CFG.GAP then northGap = true end
end
check(not northGap, "porta em outro lado: a passagem acompanha")
g.home.mainDoor = savedDoor

realPrint("211) Trabalho em cena: tabua por tabua, depois a cerca")
g.materials = 0
check(BB.step(g) == nil and hs.windows[1].barricade == nil, "sem material, nenhum passo")
g.materials = 100
local guard = 0
local steps = 0
while BB.next(g, BB.last[g.id]) == "windows" and guard < 20 do
    BB.step(g); steps = steps + 1; guard = guard + 1
end
check(steps == 2 * BB.CFG.WINDOW_PLANKS and hs.windows[1].barricade.planks == 2 and hs.windows[2].barricade.planks == 2, "janelas: 2 tabuas cada")
check(g.materials == 100 - steps * BB.CFG.COST.windows, "cada tabua gasta material")
check(BB.next(g, BB.last[g.id]) == "doors", "depois a porta dos fundos")
BB.step(g); BB.step(g)
check(hs.back.barricade and hs.back.barricade.planks == 2 and not hs.front.barricade, "porta dos fundos fechada; a principal nunca")
check(BB.next(g, BB.last[g.id]) == "reinforce", "depois reforcar")
for _ = 1, 6 do BB.step(g) end
check(hs.windows[1].barricade.planks == BB.CFG.MAX_PLANKS and hs.back.barricade.planks == BB.CFG.MAX_PLANKS, "ate " .. BB.CFG.MAX_PLANKS .. " tabuas em cada")
check(BB.next(g, BB.last[g.id]) == "perimeter", "depois a cerca")
local f0, mat0 = fences(), g.materials
BB.step(g)
check(fences() == f0 + 1 and g.materials == mat0 - BB.CFG.COST.perimeter, "um pedaco de cerca de madeira de verdade (gasta " .. BB.CFG.COST.perimeter .. ")")
local fence = nil
for _, list in pairs(T.sqObjects) do for _, o in ipairs(list) do if o.md and o.md.remFence then fence = o end end end
check(fence.maxHealth == BB.CFG.FENCE_HEALTH and (fence.sprite == BB.CFG.FENCE_N or fence.sprite == BB.CFG.FENCE_W), "com a vida e o sprite da cerca de carpintaria")
check(g.home.fenceBuilt == 1, "contada")
-- comportamento: vai ate o lugar e martela, uma vez a cada STEP_MS
fresh()
g, hs, b = base()
g.materials = 10
b.z.x, b.z.y = hs.x + 6, hs.y + 4
b.z.path, b.nextPath, b.lastPathX = nil, 0, nil
check(BB.behavior(b, { player = player }, Rem.nowMs()) and b.z.path ~= nil, "o morador vai ate a janela")
local tgt = BB.last[g.id].windows[1]
b.z.x, b.z.y = tgt.x + 0.5, tgt.y + 1.5
b.z.said, b.lastBark, b.barkAt = {}, nil, {}     -- (sem o intervalo entre falas)
BB.behavior(b, { player = player }, Rem.nowMs())
check(g.materials == 9 and T.saidPrefix(b.z, "IGUI_Rem_Bark_work_"), "chegou: martela (gasta material, comenta)")
BB.behavior(b, { player = player }, Rem.nowMs())
check(g.materials == 9, "uma martelada a cada " .. BB.CFG.STEP_MS / 1000 .. " s")
T.timeOfDay = 22
b.nextBuild = 0
check(BB.behavior(b, { player = player }, Rem.nowMs()) == false, "de noite nao martela")
T.timeOfDay = 10
g.goal = "hide"
check(BB.behavior(b, { player = player }, Rem.nowMs()) == false, "com horda nao martela")
g.goal = nil
g.materials = 0
check(BB.behavior(b, { player = player }, Rem.nowMs()) == false, "sem material, nao")
g.materials = 50
g.home.buildToday, g.home.buildDay = BB.CFG.STEPS_PER_DAY, math.floor(Rem.worldHours() / 24)
check(BB.behavior(b, { player = player }, Rem.nowMs()) == false, "limite do dia")
g.home.buildToday = 0
PB.setJob(b, "rest")
check(BB.behavior(b, { player = player }, Rem.nowMs()) == false, "so quem esta com a tarefa 'fortificar'")

realPrint("212) Carros queimados como barricada de rua")
fresh()
g, hs, b = base()
g.materials = 500
BB.scan(g)
local n0 = 0
local guard2 = 0
while BB.next(g, BB.last[g.id]) ~= "cars" and BB.next(g, BB.last[g.id]) and guard2 < 400 do BB.step(g) guard2 = guard2 + 1 end
check(BB.next(g, BB.last[g.id]) == "cars", "depois da cerca: os carros")
local fenceDone = false
for _, e in ipairs(JN.entries()) do if e.key == "IGUI_Rem_Journal_ev_done_perimeter" then fenceDone = true end end
check(fenceDone, "cerca pronta: comemoram (diario)")
local mat1 = g.materials
for _ = 1, BB.CFG.CAR_STEPS - 1 do BB.step(g) end
check(#T.vehicles == 0, "arrastar um carro leva varios passos")
BB.step(g)
check(#T.vehicles == 1 and T.vehicles[1].script:find("Burnt") and g.materials == mat1, "um carro queimado de verdade na rua (sem gastar material)")
local car = T.vehicles[1]
local outside = car.y > hs.y + 5 + BB.CFG.PERIM_MARGIN or car.y < hs.y - BB.CFG.PERIM_MARGIN
    or car.x > hs.x + 7 + BB.CFG.PERIM_MARGIN or car.x < hs.x - BB.CFG.PERIM_MARGIN
check(outside, "do lado de fora da cerca")
check(math.abs(car.y - (hs.y + 5 + BB.CFG.PERIM_MARGIN + BB.CFG.CAR_OUT)) < 1, "o primeiro, na rua da frente (lado da porta)")
for _ = 1, BB.CFG.CAR_STEPS * 4 do BB.step(g) end
check(#T.vehicles == BB.CFG.MAX_CARS and #g.home.cars == BB.CFG.MAX_CARS, "ate " .. BB.CFG.MAX_CARS .. " carros, um em cada rua em volta")
check(BB.next(g, BB.last[g.id]) == nil, "tudo pronto")
-- sem espaco na rua, nao poe carro
fresh()
g, hs, b = base()
for x = hs.x - 15, hs.x + 25 do for y = hs.y - 15, hs.y + 20 do
    if not T.indoorSq[x .. "," .. y] and (x < hs.x - 4 or x > hs.x + 11 or y < hs.y - 4 or y > hs.y + 9) then T.blockedSq[x .. "," .. y] = true end
end end
local plan2 = BB.scan(g)
check(#plan2.cars == 0, "rua tomada (arvores, muros): nada de carro")
for x = hs.x - 15, hs.x + 25 do for y = hs.y - 15, hs.y + 20 do T.blockedSq[x .. "," .. y] = nil end end

realPrint("213) Obras longe de voce")
fresh()
g, hs, b = base()
BB.scan(g)
Rem.dematerialize(b)
player.x, player.y = hs.x + 900, hs.y
g.materials = 100
g.home.buildToday, g.home.buildDay = 0, nil
local onAgain = Rem.materialize(b.rec)
check(BB.offscene(g) == 0, "com alguem da base em cena, o trabalho e o de verdade (nao o de longe)")
Rem.dematerialize(onAgain)
for _ = 1, 12 do Rem.emit("worldHour", Rem.worldHours()) end
local pend = 0
for _, n in pairs(g.home.pendingBuild or {}) do pend = pend + n end
check(pend == BB.perDay(g) and g.materials < 100, "de dia, longe de voce: " .. BB.CFG.STEPS_PER_DAY .. " passos por dia, gastando material")
check((g.home.pendingBuild.windows or 0) == 4 and (g.home.pendingBuild.doors or 0) == 2, "na ordem: janelas, depois portas")
T.timeOfDay = 23
g.home.buildToday = 0
local before = pend
for _ = 1, 3 do Rem.emit("worldHour", Rem.worldHours()) end
pend = 0
for _, n in pairs(g.home.pendingBuild or {}) do pend = pend + n end
check(pend == before, "de noite, nada")
T.timeOfDay = 10
player.x, player.y = hs.x + 4, hs.y + 12
T.clock = T.clock + 5000
Rem.emit("sceneUpdate", player, Rem.nowMs())
check(hs.windows[1].barricade and hs.windows[1].barricade.planks == 2 and hs.back.barricade and g.home.pendingBuild == nil,
    "voltando: tudo o que fizeram aparece (janelas e porta com tabuas)")

realPrint("214) Saidas de material, em dupla")
fresh()
g, hs, b = base(false)                            -- b descansa
local c = ally(hs.x + 4, hs.y + 3); PB.join(c); PB.setJob(c, "materials")
c.talkingUntil, b.talkingUntil = nil, nil
local opts = {}
for _, id in ipairs(IA.dialogOptions(b, player)) do opts[id] = true end
check(opts.order_job_materials, "nova tarefa na conversa: buscar tabuas e pregos")
local tdef = T.addBuilding(nextId + 333, hs.x + 30, hs.y, 8, 6)
for i = hs.x + 30, hs.x + 37 do for j = hs.y, hs.y + 5 do T.indoorSq[i .. "," .. j] = true; T.sqBuilding[i .. "," .. j] = tdef end end
local shelf = T.addObject(hs.x + 33, hs.y + 2, 0, "container", { type = "shelves" })
g.nearby = nil
c.z.x, c.z.y = g.home.x, g.home.y
check(PB.scavBehavior(c, { player = player }, Rem.nowMs()) and c.rec.tripKind == "materials" and b.rec.mode == "escort", "sai em dupla (com quem esta descansando)")
local cur = nil
for _ = 1, 3 do PB.scavBehavior(c, { player = player }, Rem.nowMs()) end
cur = c.fLootCont
c.z.x, c.z.y = cur.sq:getX() + 1.5, cur.sq:getY() + 0.5
PB.scavBehavior(c, { player = player }, Rem.nowMs())
T.clock = T.clock + PB.CFG.DISMANTLE_MS + 10
PB.scavBehavior(c, { player = player }, Rem.nowMs())
local planks = 0
for _, ft in ipairs(c.rec.carry or {}) do if PB.CFG.MATERIAL_ITEMS[ft] then planks = planks + 1 end end
check(planks >= 1 and #shelf.container.items == 0, "arranca tabuas e pregos dos moveis (nao pega comida)")
c.lootDoneBid = c.rec.lootTarget.bid
c.z.x, c.z.y = g.home.x, g.home.y
local mat2 = g.materials
PB.scavBehavior(c, { player = player }, Rem.nowMs())
PB.syncStash(g)
check(g.materials > mat2 and c.rec.mode == "group" and b.rec.mode == "group", "volta, guarda, e o estoque vira material para as obras")
-- longe de voce
for _, npc in ipairs({ b, c }) do Rem.dematerialize(npc) end
player.x, player.y = hs.x + 900, hs.y
for k = 1, 3 do T.addBuilding(nextId + 340 + k, hs.x + 20 + k * 12, hs.y + 20, 8, 6) end
g.nearby = nil
c.rec.lastTrip, b.rec.lastTrip = nil, nil
local realRand = ZombRand
ZombRand = function(a, bb) if a == 100 and not bb then return 50 end return realRand(a, bb) end
local mat3 = g.materials
local res = PB.tripOffscene(g, c.rec, b.rec, "materials")
ZombRand = realRand
check(g.materials - mat3 >= PB.CFG.MAT_TRIP[1] and JN.entries()[#JN.entries()].key == "IGUI_Rem_Journal_base_trip_materials", "longe: voltam com material (" .. (g.materials - mat3) .. ")")
-- sem parceiro: avisa no diario
PB.setJob(b.rec and { rec = b.rec, z = b.z } or b, "build")
b.rec.job = "build"
c.rec.lastTrip, c.rec.noPartnerNoted = nil, nil
PB.hourly()
check(JN.entries()[#JN.entries()].key == "IGUI_Rem_Journal_base_nopartner", "sem parceiro: nao sai e o diario explica")
-- dupla: um morre, o outro volta com a noticia
b.rec.job = "materials"
c.rec.lastTrip, b.rec.lastTrip = nil, nil
SandboxVars.Remanescentes.ScavengeDeathChance = 8
ZombRand = function(a, bb) if a == 100 and not bb then return 0 end return realRand(a, bb) end
res = PB.tripOffscene(g, c.rec, b.rec, "materials")
ZombRand = realRand
SandboxVars.Remanescentes.ScavengeDeathChance = T.defaults().ScavengeDeathChance
check(res == "dead" and #g.members == 1 and JN.entries()[#JN.entries()].key == "IGUI_Rem_Journal_base_trip_lost", "em dupla, quando da errado, um volta com a noticia")

-- em dupla o risco e menor
local d1 = ally(hs.x + 900, hs.y + 1); PB.join(d1)
local d2 = ally(hs.x + 900, hs.y + 2); PB.join(d2)
d1.rec.job, d2.rec.job = "scav", "scav"
SandboxVars.Remanescentes.ScavengeDeathChance = 8
for k = 1, 2 do T.addBuilding(nextId + 360 + k, hs.x + 40 + k * 12, hs.y - 20, 8, 6) end
ZombRand = function(a, bb) if a == 100 and not bb then return 3 end return realRand(a, bb) end
g.nearby = nil
local rPair = PB.tripOffscene(g, d1.rec, d2.rec, "scav")
d1.rec.lastTrip = nil
local rAlone = PB.tripOffscene(g, d1.rec, nil, "scav")
ZombRand = realRand
SandboxVars.Remanescentes.ScavengeDeathChance = T.defaults().ScavengeDeathChance
check(rPair ~= "dead" and rAlone == "dead", "o mesmo azar que mata quem sai sozinho, em dupla nao mata")

realPrint("215) Eventos: horda")
fresh()
g, hs, b = base()
local d0 = BE.defense(g)
g.home.windowsTotal, g.home.windowsDone, g.home.fenceTotal, g.home.fenceBuilt = 2, 2, 40, 40
check(BE.defense(g) > d0 + 7, "janelas e cerca contam na defesa")
PB.setJob(b, "guard")
check(BE.defense(g) > d0 + 8, "vigia conta mais")
-- com voce la: zumbis aparecem do lado de fora da cerca
local zb0 = #T.zombies
local r = BE.horde(g)
local outsideAll = true
for i = zb0 + 1, #T.zombies do
    local z = T.zombies[i]
    if z.x >= hs.x - 1 and z.x <= hs.x + 8 and z.y >= hs.y - 1 and z.y <= hs.y + 6 then outsideAll = false end
end
check(r == "here" and #T.zombies > zb0 and outsideAll, "com voce la: a horda chega de verdade, do lado de fora")
-- longe: defesa decide
Rem.dematerialize(b)
player.x, player.y = hs.x + 900, hs.y
ZombRand = function(a, bb) if bb then return a end return 0 end
g.lastHorde = nil
r = BE.horde(g)
check(r == "held", "defesa forte: aguentou")
g.home.windowsDone, g.home.fenceBuilt = 0, 0
PB.setJob({ rec = b.rec, z = b.z }, "rest")
b.rec.job = "rest"
ZombRand = function(a, bb) if bb then return bb end return 0 end
r = BE.horde(g)
check(r == "dead" and #g.members == 0, "casa aberta e horda grande: alguem morre")
ZombRand = realRand

realPrint("216) Eventos: visitante")
fresh()
g, hs, b = base(false)
Rem.dematerialize(b)
player.x, player.y = hs.x + 900, hs.y
g.supplies = 0
check(BE.visitor(g, player) == false and #g.members == 1, "longe e sem comida: os moradores mandam embora")
g.supplies = 20
local v = BE.visitor(g, player)
check(v and v.faction == "aliados" and #g.members == 2 and JN.entries()[#JN.entries()].key == "IGUI_Rem_Journal_ev_visitor_stayed", "longe e com comida: fica (vira morador)")
-- com voce la
player.x, player.y = hs.x + 4, hs.y + 4
local bb2 = Rem.materialize(b.rec)
local vis = BE.visitor(g, player)
check(vis and vis.rec.ambient == "visitor" and T.saidPrefix(vis.z, "IGUI_Rem_Bark_base_visitor_"), "com voce la: alguem no portao pedindo para ficar")
check(vis.z.y > hs.y + 5, "do lado de fora, na frente da porta")
opts = {}
for _, id in ipairs(IA.dialogOptions(vis, player)) do opts[id] = true end
check(opts.accept_visitor, "conversa: 'Pode ficar na nossa base'")
local l = IA.choose("accept_visitor", vis, player)
check(vis.rec.faction == "aliados" and PB.isMember(vis.rec) and vis.rec.mode == "group" and not vis.rec.transient, "aceito: vira morador")
T.clock = T.clock + BE.CFG.VISITOR_MS + 1
check(PB.isMember(vis.rec), "e nao vai mais embora")

realPrint("217) Eventos: briga, ladrao, festa")
fresh()
g, hs, b = base(false)
local c2 = ally(hs.x + 5, hs.y + 3); PB.join(c2)
for _, p in ipairs(PB.members(g)) do p.moral = 20 end
b.z.said, c2.z.said = {}, {}
check(BE.argue(g) == "argue", "moral baixo: dois brigam")
check(b.rec.moral < 20 and c2.rec.moral < 20, "e o moral cai")
check(#Rem.Banter.queue >= 1 and Rem.Banter.queue[1].key:find("IGUI_Rem_Banter_argue_"), "com voce la: a briga e falada")
Rem.Banter.queue = {}
Rem.dematerialize(b); Rem.dematerialize(c2)
for _, p in ipairs(PB.members(g)) do p.moral = BE.CFG.LEAVE_MORALE end
check(BE.argue(g) == "left" and #g.members == 1, "moral no fundo: alguem vai embora")
-- ladrao
g.supplies = 10
check(BE.thief(g) == "stolen" and g.supplies < 10, "sem vigia: levam comida")
local gu = Rem.getPerson(g.members[1]); gu.job = "guard"
local s0 = g.supplies
check(BE.thief(g) == "scared" and g.supplies == s0, "com vigia: espantado")
-- festa
local mor = gu.moral or 50
Rem.emit("baseProjectDone", g, "windows")
check((gu.moral or 50) > mor and JN.entries()[#JN.entries()].key == "IGUI_Rem_Journal_ev_done_windows", "obra pronta: moral sobe, diario")
local nJ = #JN.entries()
g.home.finished = {}
check(BB.checkDone(g, "doors", { doors = {} }) == true and BB.checkDone(g, "doors", { doors = {} }) == false and #JN.entries() == nJ + 1,
    "cada obra pronta e comemorada uma vez so")
-- cerca derrubada (horda longe de voce)
fresh()
g, hs, b = base()
g.materials = 500
local g2 = 0
while BB.next(g, BB.last[g.id]) ~= "cars" and g2 < 300 do BB.step(g) g2 = g2 + 1 end
local fb = fences()
check(BB.damageFence(g, 3) == 3 and fences() == fb - 3 and not g.home.finished.perimeter, "pedacos de cerca derrubados somem")
BB.scan(g)
check(#BB.last[g.id].perimeter == 3 and BB.next(g, BB.last[g.id]) == "perimeter", "e voltam para a fila de obras")
-- sorteio por hora
fresh()
g, hs, b = base()
ZombRand = function(a, bb) if bb then return a end return 0 end
T.timeOfDay = 23
check(BE.hourly() == "horde", "de noite, o sorteio pode trazer uma horda")
check(BE.hourly() ~= "horde", "e nao outra logo em seguida")
ZombRand = realRand
T.timeOfDay = 12
SandboxVars.Remanescentes.MaxActive = T.defaults().MaxActive
fresh()
