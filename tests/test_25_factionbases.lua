-- Bases das faccoes: os grupos de NPC usam o mesmo sistema da sua base (obras por faccao,
-- duplas de material, hordas, defesa nos ataques), e o registro de projetos.
local T = ...
local Rem = Remanescentes
local check, tick = T.check, T.tick
local player, realPrint = T.player, T.print
local BB, GL, PB, IA, JN = Rem.BaseBuild, Rem.GroupLife, Rem.PlayerBase, Rem.Interact, Rem.Journal

local function fresh()
    Rem.dismissAll(); T.clearZombies(); Rem.hunting = {}
    Rem.Mugging.enc = {}
    local s = Rem.getStore()
    s.reputation, s.quests, s.journal, s.knownGroups, s.met, s.playerBase = {}, {}, {}, {}, {}, nil
    T.vehicles = {}
    BB.last = {}
end
local nextId = 70000
local function npcHome(faction, n)
    nextId = nextId + 400
    local x, y = nextId, 70000
    local def = T.addBuilding(nextId + 1, x, y, 8, 6)
    for i = x, x + 7 do for j = y, y + 5 do T.indoorSq[i .. "," .. j] = true; T.sqBuilding[i .. "," .. j] = def end end
    local wins = { T.addObject(x + 2, y, 0, "IsoWindow", { exterior = true }), T.addObject(x + 5, y, 0, "IsoWindow", { exterior = true }) }
    T.addObject(x + 4, y + 5, 0, "IsoDoor", { exterior = true })
    T.addObject(x + 2, y + 2, 0, "container", { type = "fridge" })
    player.x, player.y = x + 4, y + 14
    local g = Rem.createGroup(faction, x + 4, y + 3, tostring(nextId + 1), n or 4, def)
    g.supplies, g.activity = 30, "home"
    for _, id in ipairs(g.members) do
        local p = Rem.getPerson(id)
        if not p.onScene then Rem.materialize(p) end
    end
    Rem.emit("sceneUpdate", player, Rem.nowMs())   -- (a casa e "preparada")
    return g, { x = x, y = y, windows = wins, def = def }
end
local function members(g)
    local out = {}
    for _, npc in pairs(Rem.active) do if npc.rec.groupId == g.id then table.insert(out, npc) end end
    table.sort(out, function(a, b) return tostring(a.rec.id) < tostring(b.rec.id) end)
    return out
end
local function count(kind)
    local n = 0
    for _, list in pairs(T.sqObjects) do for _, o in ipairs(list) do if o.md and o.md[kind] then n = n + 1 end end end
    return n
end
T.timeOfDay = 10
SandboxVars.Remanescentes.MaxActive = 30

realPrint("220) Milicia constroi tudo: cerca, arame farpado, barril, carros, gerador")
fresh()
local Signals = Rem.Signals
local g, hs = npcHome("sobreviventes", 4)
g.home.decor, g.home.builtBarrel, g.home.builtGenerator = {}, nil, nil
g.materials = 1000
local plan = BB.scan(g)
check(#plan.barbed > 0 and #plan.barrel == 1 and #plan.generator == 1, "na fila: arame farpado, barril de chuva, gerador")
local seen, last = {}, nil
local guard = 0
while BB.next(g, BB.last[g.id]) and guard < 600 do
    local p = BB.step(g)
    if p and p ~= last then table.insert(seen, p) last = p end
    guard = guard + 1
end
local order = table.concat(seen, ",")
check(order:find("perimeter") and order:find("barbed") and order:find("barrel") and order:find("cars") and order:find("generator")
    and order:find("perimeter") < order:find("barbed") and order:find("barbed") < order:find("cars"), "na ordem (" .. order .. ")")
check(count("remFence") > 0 and count("remBarbed") > 0, "cerca e arame farpado de verdade")
local barbed = nil
for _, list in pairs(T.sqObjects) do for _, o in ipairs(list) do if o.md and o.md.remBarbed then barbed = o end end end
check(barbed.maxHealth == BB.CFG.BARBED_HEALTH and (barbed.sprite == BB.CFG.BARBED_N or barbed.sprite == BB.CFG.BARBED_W), "arame com a vida e os sprites do jogo")
check(g.home.builtBarrel and g.home.builtGenerator and #T.generators >= 1, "barril e gerador instalados")
check(#T.vehicles == BB.CFG.MAX_CARS, "carros queimados nas ruas")
local fenceKeys, barbedKeys = 0, 0
for k in pairs(g.home.fence) do fenceKeys = fenceKeys + 1 end
for k in pairs(g.home.barbed) do barbedKeys = barbedKeys + 1 end
check(barbedKeys > fenceKeys, "o arame fica do lado de fora da cerca (anel maior)")
check(BB.structureBonus(g) > 6, "base toda pronta: defesa alta (" .. string.format("%.1f", BB.structureBonus(g)) .. ")")

realPrint("221) Mestre de obras e duplas de material")
fresh()
g, hs = npcHome("civis", 5)
g.materials = 0
local jobs = GL.assignJobs(g)
check(jobs.guard == 1 and jobs.materials == 2 and jobs.build == 0, "sem material: guarda + dupla buscando material")
local gatherer = nil
for _, npc in ipairs(members(g)) do if npc.rec.job == "materials" then gatherer = npc break end end
local tdef = T.addBuilding(nextId + 333, hs.x + 30, hs.y, 8, 6)
for i = hs.x + 30, hs.x + 37 do for j = hs.y, hs.y + 5 do T.indoorSq[i .. "," .. j] = true; T.sqBuilding[i .. "," .. j] = tdef end end
T.addObject(hs.x + 33, hs.y + 2, 0, "container", { type = "shelves" })
g.nearby = nil
for _, npc in ipairs(members(g)) do npc.talkingUntil, npc.rec.lastTrip = nil, nil end
gatherer.z.x, gatherer.z.y = g.home.x, g.home.y
check(PB.scavBehavior(gatherer, { player = player }, Rem.nowMs()) and gatherer.rec.mode == "scav", "em cena: a dupla de NPC sai para buscar material")
local partner = nil
for _, npc in ipairs(members(g)) do if npc.rec.escortOf == gatherer.rec.id then partner = npc end end
check(partner ~= nil and partner.rec.groupId == g.id, "com um parceiro do mesmo grupo")
gatherer.rec.carry = { "Base.Plank", "Base.Plank", "Base.Nails", "Base.TinnedBeans" }
gatherer.lootDoneBid = gatherer.rec.lootTarget.bid
gatherer.z.x, gatherer.z.y = g.home.x, g.home.y
local m0 = g.materials
PB.scavBehavior(gatherer, { player = player }, Rem.nowMs())
check(g.materials == m0 + 3 and gatherer.rec.mode == "group" and partner.rec.mode == "group", "voltam: tabuas e pregos viram material do grupo, a comida vai para o estoque")
g.materials = 10
jobs = GL.assignJobs(g)
check(jobs.build >= 1 and jobs.materials == 0, "com material: fortificam")
-- longe de voce
for _, npc in ipairs(members(g)) do Rem.dematerialize(npc) end
player.x, player.y = hs.x + 900, hs.y
for k = 1, 2 do T.addBuilding(nextId + 340 + k, hs.x + 20 + k * 12, hs.y + 20, 8, 6) end
g.nearby, g.materials = nil, 0
GL.assignJobs(g)
for _, id in ipairs(g.members) do Rem.getPerson(id).lastTrip = nil end
local realRand = ZombRand
ZombRand = function(a, b) if a == 100 and not b then return 50 end return realRand(a, b) end
local trips = GL.trips(g)
ZombRand = realRand
check(trips >= 1 and g.materials >= PB.CFG.MAT_TRIP[1], "longe: a dupla volta com material (" .. g.materials .. ")")
check(#JN.entries() == 0, "(o diario so conta o que acontece na sua base)")
-- quem estava numa saida quando voce foi embora volta a rotina
local someone = Rem.getPerson(g.members[2])
someone.mode, someone.carry, someone.lastTrip = "scav", { "Base.Plank" }, nil
local m1 = g.materials
GL.resetTrips(g)
check(someone.mode == "group" and g.materials == m1 + 1 and someone.carry == nil, "saida interrompida: volta a rotina com o que tinha")

realPrint("222) Hordas nas bases dos NPCs e defesa nos ataques")
fresh()
g, hs = npcHome("civis", 4)
for _, npc in ipairs(members(g)) do Rem.dematerialize(npc) end
player.x, player.y = hs.x + 900, hs.y
Rem.changeRep(g.id, 10, "teste")            -- voce conhece o grupo
check(JN.knows(g), "(voce conhece o grupo)")
local realRand2 = ZombRand
ZombRand = function(a, b) if b then return b end return 0 end
local r = GL.horde(g)
ZombRand = realRand2
check(r == "dead" and #g.members == 3 and JN.entries()[#JN.entries()].key == "IGUI_Rem_Journal_npc_horde_dead", "casa aberta: a horda mata alguem (e voce fica sabendo)")
g.home.windowsTotal, g.home.windowsDone, g.home.fenceTotal, g.home.fenceBuilt = 2, 2, 40, 40
ZombRand = function(a, b) if b then return a end return 0 end
r = GL.horde(g)
ZombRand = realRand2
check(r == "held", "com cerca e janelas: aguentam")
-- ataques entre grupos: obras contam na defesa
local fortBonus = BB.structureBonus(g)
g.home.windowsDone, g.home.fenceBuilt = 0, 0
check(fortBonus > BB.structureBonus(g) + 4, "obras somam na defesa contra ataques de saqueadores")

realPrint("223) Conversa e diario mostram as obras dos outros")
fresh()
g, hs = npcHome("sobreviventes", 4)
g.materials = 20
BB.scan(g)
local talker = members(g)[2]
Rem.changeRep(g.id, 30, "teste")
local l = IA.status(talker)
local cur = BB.next(g, BB.last[g.id])
check(l.key == "IGUI_Rem_Goal_build" and l.args[1] == "IGUI_Rem_Project_" .. cur, "'Como vao as coisas?': 'Estamos trabalhando na casa: " .. cur .. "'")
g.materials = 0
check(IA.status(talker).key == "IGUI_Rem_Goal_materials", "sem material: dizem que falta")
g.home.finished = {}
BB.checkDone(g, "windows", { windows = {} })
check(JN.entries()[#JN.entries()].key == "IGUI_Rem_Journal_npc_done", "obra pronta num grupo que voce conhece: noticia")
require "Remanescentes/Rem_JournalUI"
local realGet = getText
getText = function(k, ...) return k .. " " .. table.concat({ ... }, " ") end
local text = JN.compose(player)
getText = realGet
check(text:find("IGUI_Rem_Journal_base_works", 1, true), "o diario mostra a obra de cada grupo conhecido")
-- casa nunca vista: obra estimada longe de voce, aplicada no que couber
fresh()
local def2 = T.addBuilding(nextId + 777, nextId + 777, 70000, 8, 6)
local unseen = Rem.createGroup("civis", nextId + 781, 70003, tostring(nextId + 777), 3, def2)
unseen.activity, unseen.materials = "home", 30
player.x, player.y = nextId + 5000, 70000
GL.assignJobs(unseen)
for _ = 1, 4 do Rem.emit("worldHour", Rem.worldHours()) end
local pend = 0
for _, n in pairs(unseen.home.pendingBuild or {}) do pend = pend + n end
check(pend > 0 and unseen.home.planEstimated, "casa que voce nunca viu: a obra anda mesmo assim (estimada)")
T.timeOfDay = 12
SandboxVars.Remanescentes.MaxActive = T.defaults().MaxActive
fresh()

realPrint("224) Regras finas")
fresh()
g, hs = npcHome("civis", 4)
g.home.decor = { barrel = { x = 1, y = 1 } }
check(#BB.scan(g).barrel == 0, "casa que ja tem barril de chuva nao ganha outro")
g.home.decor, g.home.builtBarrel = {}, true
check(#BB.scan(g).barrel == 0, "nem depois de construir um")
-- grupo fora de casa (saqueando) nao trabalha na obra
local b1 = members(g)[2]
b1.rec.job = "build"
g.materials = 10
g.activity = "scavenge"
check(BB.behavior(b1, { player = player }, Rem.nowMs()) == false, "grupo fora de casa: ninguem martela")
g.activity = "home"
-- morador de NPC descansando nao sai buscando nada
b1.rec.job = "rest"
b1.rec.lastTrip = nil
check(PB.scavBehavior(b1, { player = player }, Rem.nowMs()) == false and b1.rec.mode == "group", "morador de NPC sem tarefa de material nao sai")
-- sem parceiro, ninguem sai (longe)
for _, npc in ipairs(members(g)) do Rem.dematerialize(npc) end
for _, id in ipairs(g.members) do local p = Rem.getPerson(id) p.job, p.lastTrip = "build", nil end
local lone = Rem.getPerson(g.members[1])
lone.job = "materials"
local m2 = g.materials
check(GL.trips(g) == 0 and g.materials == m2, "longe, sozinho tambem nao sai")
-- grupo que voce nao conhece: obra pronta nao vira noticia
Rem.getStore().journal, Rem.getStore().met, Rem.getStore().reputation = {}, {}, {}
g.home.finished = {}
BB.checkDone(g, "windows", { windows = {} })
check(#JN.entries() == 0, "grupo desconhecido: obra pronta nao vira noticia")

SandboxVars.Remanescentes.NPCBaseWork = 0
check(BB.perDay(g) == 0 and BB.offscene(g) == 0, "sandbox 'Obras dos grupos' = 0: os NPCs nao constroem")
SandboxVars.Remanescentes.NPCBaseWork = 200
check(BB.perDay(g) == 2 * BB.builders(g) * BB.CFG.STEPS_PER_DAY, "200%: o dobro")
SandboxVars.Remanescentes.NPCBaseWork = nil

realPrint("225) Ataques e quedas: as obras contam")
fresh()
local vg, vh = npcHome("civis", 2)
for _, npc in ipairs(members(vg)) do Rem.dematerialize(npc) end
local rg = Rem.createGroup("saqueadores", vg.home.x + 50, vg.home.y, nil, 3)
for _, id in ipairs(rg.members) do Rem.getPerson(id).onScene = false end
player.x, player.y = vg.home.x + 3000, vg.home.y
local function raid()
    rg.activity, rg.target, rg.arrivedAt = "raid", { x = vg.home.x, y = vg.home.y, z = 0, victim = vg.id }, Rem.worldHours() - 2
    rg.x, rg.y = vg.home.x, vg.home.y
    for _, id in ipairs(rg.members) do local p = Rem.getPerson(id) p.x, p.y = vg.home.x, vg.home.y end
    local winner = nil
    Rem.on("raidResolved", function(a, v, w) winner = w end)
    local rr = ZombRand
    ZombRand = function(a, b) if b then return a end return 0 end    -- 1 baixa por lado, sem sorte
    Rem.simulateGroup(rg, Rem.worldHours())
    ZombRand = rr
    return winner
end
vg.home.windowsTotal, vg.home.windowsDone, vg.home.fenceTotal, vg.home.fenceBuilt = 2, 2, 40, 40
check(raid() == vg, "casa fortificada (cerca, janelas): os saqueadores perdem")
fresh()
vg, vh = npcHome("civis", 2)
for _, npc in ipairs(members(vg)) do Rem.dematerialize(npc) end
rg = Rem.createGroup("saqueadores", vg.home.x + 50, vg.home.y, nil, 3)
for _, id in ipairs(rg.members) do Rem.getPerson(id).onScene = false end
player.x, player.y = vg.home.x + 3000, vg.home.y
check(raid() == rg, "a mesma casa aberta: os saqueadores ganham")
-- cair para uma horda (diario do mundo)
fresh()
local fa = npcHome("civis", 2)
local fb = npcHome("civis", 2)
for _, gg in ipairs({ fa, fb }) do
    for _, npc in ipairs(members(gg)) do Rem.dematerialize(npc) end
    gg.supplies = 0
end
fb.home.windowsTotal, fb.home.windowsDone, fb.home.fenceTotal, fb.home.fenceBuilt = 2, 2, 40, 40
fb.home.cars = { {}, {}, {}, {} }
player.x, player.y = fa.home.x + 5000, fa.home.y
local rr = ZombRand
ZombRand = function(a, b) if a == 1000 and not b then return 10 end return rr(a, b) end
Rem.Evolution.daily()
ZombRand = rr
local groups = Rem.getStore().groups
check(groups[fa.id] == nil and groups[fb.id] ~= nil, "no mesmo azar, a casa aberta cai e a fortificada resiste")
T.timeOfDay = 12
fresh()
