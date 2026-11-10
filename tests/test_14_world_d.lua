-- Fase D: regioes, viagens em passos, bases que evoluem, relacoes entre grupos.
local T = ...
local Rem = Remanescentes
local check, tick = T.check, T.tick
local player, realPrint = T.player, T.print
local RG, EV, REL = Rem.Regions, Rem.Evolution, Rem.Relations

local tl = Rem.getStore().timeline
local function setDay(d) tl.startHours = Rem.worldHours() - 24 * d end
local function fresh()
    Rem.dismissAll(); T.clearZombies(); Rem.hunting = {}
    Rem.getStore().relations = {}
    Rem.getStore().turned = {}
    Rem.getStore().nests = {}
end
local function groupsIn(x1, y1, x2, y2)
    local n = 0
    for _, g in pairs(Rem.getStore().groups) do
        if g.home.x >= x1 and g.home.x < x2 and g.home.y >= y1 and g.home.y < y2 then n = n + 1 end
    end
    return n
end
local function house(id, x, y, w, h)
    local def = T.addBuilding(id, x, y, w, h)
    for i = x, x + w - 1 do for j = y, y + h - 1 do T.indoorSq[i .. "," .. j] = true; T.sqBuilding[i .. "," .. j] = def end end
    return def
end

SandboxVars.Remanescentes.WorldGroups = 40
setDay(10)

realPrint("110) D1 Grupos por regiao")
fresh()
-- "cidade": 120 predios espalhados na regiao (60,60) = tiles 18000-18299
for i = 0, 119 do
    T.addBuilding(20000 + i, 18000 + (i % 12) * 24, 18000 + math.floor(i / 12) * 28, 8, 8)
end
-- "campo": 3 predios na regiao (62,60)
for i = 0, 2 do T.addBuilding(20200 + i, 18600 + i * 40, 18100, 8, 8) end
player.x, player.y = 18450, 18150     -- regiao (61,60), entre a cidade e o campo
-- predios colados em voce (na sua regiao): nenhum pode virar casa de grupo
for i = 0, 59 do T.addBuilding(20500 + i, 18420 + (i % 6) * 10, 18120 + math.floor(i / 6) * 6, 8, 5) end
Rem.getStore().regions = {}
local ruralChance = RG.CFG.RURAL_CHANCE
RG.CFG.RURAL_CHANCE = 100
local made = RG.seedAround(player)
RG.CFG.RURAL_CHANCE = ruralChance
local city = groupsIn(18000, 18000, 18300, 18300)
check(city >= 2 and city <= RG.CFG.MAX_PER_REGION, "cidade com 120 predios: alguns grupos (" .. city .. ")")
local farm = groupsIn(18600, 18000, 18900, 18300)
local farmFaction = nil
for _, g in pairs(Rem.getStore().groups) do
    if g.home.x >= 18600 and g.home.x < 18900 and g.home.y >= 18000 and g.home.y < 18300 then farmFaction = g.faction end
end
check(farm == 1 and farmFaction == "errantes", "campo com 3 predios: um errante, nada de grupo de cidade (" .. farm .. ", " .. tostring(farmFaction) .. ")")
local close = false
for _, g in pairs(Rem.getStore().groups) do
    if Rem.dist2(g.home.x, g.home.y, player.x, player.y) < RG.CFG.MIN_FROM_PLAYER then close = true end
end
check(not close, "nenhum grupo nasce colado em voce")
local again = RG.seedAround(player)
check(again == 0, "regiao ja semeada nao ganha grupos de novo")
-- explorando: regiao nova
for i = 0, 79 do T.addBuilding(20300 + i, 19200 + (i % 10) * 25, 18000 + math.floor(i / 10) * 30, 8, 8) end
player.x, player.y = 19300, 18150
RG.seedAround(player)
check(groupsIn(19200, 18000, 19500, 18300) >= 1, "voce explorou outra cidade: ela ganha grupos")
-- limite global
fresh()
Rem.getStore().regions = {}
SandboxVars.Remanescentes.WorldGroups = 1
player.x, player.y = 18450, 18150
RG.seedAround(player)
check(Rem.groupCount() <= 1, "respeita o maximo de grupos no mundo")
SandboxVars.Remanescentes.WorldGroups = 40

realPrint("111) D2 Viagens em passos")
fresh()
local gT = Rem.createGroup("civis", 21000, 21000, nil, 2)
gT.activity = "scavenge"
gT.target = { x = 21600, y = 21000, z = 0 }
Rem.stepGroups(10)
check(math.abs(gT.x - 21050) < 0.5, "a cada 10 min de jogo o grupo anda um trecho (" .. gT.x .. ")")
for _ = 1, 5 do Rem.stepGroups(10) end
Rem.simulateWorld(1)
check(math.abs(gT.x - 21300) < 1, "na hora cheia nao anda de novo o que ja andou: 300 tiles por hora (" .. gT.x .. ")")
local p1 = Rem.getPerson(gT.members[1])
check(math.abs(p1.x - gT.x) < 3, "as pessoas andam junto")

realPrint("112) D3 Bases que evoluem")
fresh()
local dF = house(22001, 22000, 22000, 10, 8)
local wins = {}
for i = 0, 4 do table.insert(wins, T.addObject(22001 + i * 2, 22000, 0, "IsoWindow", { exterior = true })) end
T.addObject(22005, 22007, 0, "IsoDoor", { exterior = true })
T.addObject(22002, 22002, 0, "container", { type = "fridge" })
local gF = Rem.createGroup("civis", 22005, 22004, "22001", 3, dF)
gF.supplies = 10
local fall0 = EV.CFG.FALL_PERMILLE
EV.CFG.FALL_PERMILLE = 0
EV.daily()
check((gF.home.fortifyLevel or 0) == 1, "com comida sobrando, fortificam aos poucos")
-- reforco aplicado quando voce chega
player.x, player.y = 22005, 22030
Rem.emit("sceneUpdate", player, T.clock)
local b0 = 0
for _, w in ipairs(wins) do if w.barricade then b0 = b0 + 1 end end
gF.home.fortifyLevel = 3
Rem.emit("sceneUpdate", player, T.clock)
local b1 = 0
for _, w in ipairs(wins) do if w.barricade then b1 = b1 + 1 end end
check(b1 > b0 or b0 == #wins, "voce volta e a casa esta mais barricada (" .. b0 .. " -> " .. b1 .. ")")
-- cair para uma horda
player.x, player.y = 25000, 25000
EV.CFG.FALL_PERMILLE = 1000
local ids = {}
for _, id in ipairs(gF.members) do table.insert(ids, id) end
local gid = gF.id
gF.home.fortifyLevel = 0
EV.daily()
check(Rem.getStore().groups[gid] == nil, "a base caiu: o grupo acabou")
check(#Rem.getStore().turned >= #ids, "os moradores viraram zumbis")
check(Rem.getStore().nests["22001"] ~= nil, "a casa virou um ninho")
EV.CFG.FALL_PERMILLE = fall0
local zb = 0
for _, z in ipairs(T.zombies) do if z.inWorld and not z.dead then zb = zb + 1 end end
player.x, player.y = 22005, 22030
Rem.emit("sceneUpdate", player, T.clock)
local zb2, inside = 0, 0
for _, z in ipairs(T.zombies) do
    if z.inWorld and not z.dead then
        zb2 = zb2 + 1
        if T.indoorSq[math.floor(z.x) .. "," .. math.floor(z.y)] then inside = inside + 1 end
    end
end
check(zb2 > zb and inside >= 3 and Rem.getStore().nests["22001"] == nil, "voce chega: zumbis dentro da casa (" .. inside .. ")")
-- recrutar errantes
fresh()
EV.CFG.FALL_PERMILLE = 0
local dR = house(22101, 23000, 23000, 8, 8)
local rich = Rem.createGroup("civis", 23004, 23004, "22101", 2, dR)
rich.supplies = 20
local drift = Rem.createGroup("errantes", 23100, 23000, nil, 1)
local dId = drift.members[1]
EV.daily()
check(#rich.members == 3 and Rem.getPerson(dId).groupId == rich.id and Rem.getPerson(dId).faction == "civis", "com fartura, recrutam um errante")
check(Rem.getStore().groups[drift.id] == nil, "o grupo do errante deixa de existir")
EV.CFG.FALL_PERMILLE = fall0
-- saqueadores tomam a base
fresh()
setDay(30)
local dV = house(22201, 24000, 24000, 8, 8)
local vict = Rem.createGroup("civis", 24004, 24004, "22201", 1, dV)
local gang = Rem.createGroup("saqueadores", 24100, 24000, nil, 6)
gang.activity = "raid"
gang.target = { x = vict.home.x, y = vict.home.y, z = 0, victim = vict.id }
gang.x, gang.y = vict.home.x, vict.home.y
gang.arrivedAt = Rem.worldHours() - 2
player.x, player.y = 30000, 30000
for _ = 1, 3 do Rem.simulateWorld(1) end
check(gang.home.bid == "22201" and gang.home.x1 == 24000, "6 contra 1: acabaram com o grupo e tomaram a base dele")

realPrint("113) D4 Relacoes entre grupos")
fresh()
setDay(30)
local a = Rem.createGroup("civis", 26000, 26000, nil, 3)
local b = Rem.createGroup("civis", 26100, 26000, nil, 2)
local r = Rem.createGroup("saqueadores", 26050, 26100, nil, 3)
local m = Rem.createGroup("sobreviventes", 26200, 26000, nil, 2)
check(Rem.relation(a, b) == REL.CFG.SAME_FACTION and Rem.relation(a, r) == REL.CFG.HOSTILE_DEFAULT and Rem.relation(a, m) == 0,
    "relacao inicial pela faccao")
Rem.changeRelation(a, b, 500)
check(Rem.relation(a, b) == 100, "relacao limitada a 100")
-- rixa
Rem.emit("raidResolved", r, a, r)
check(Rem.relation(r, a) < REL.CFG.HOSTILE_DEFAULT and Rem.relation(r, b) < REL.CFG.HOSTILE_DEFAULT,
    "atacar piora a relacao com a vitima e com os aliados dela")
-- alianca ajuda a defender
check(Rem.allyHelp(a) >= #b.members * REL.CFG.ALLY_HELP - 0.01, "aliado por perto ajuda a defender")
-- troca
a.supplies, b.supplies = 12, 1
a.activity, b.activity = "home", "home"
local rab = Rem.relation(a, b)
Rem.changeRelation(a, b, -60)   -- 40: ainda amigos (>= 20)
local traded = REL.trade()
check(traded >= 1 and a.supplies < 12 and b.supplies > 1, "amigos por perto dividem suprimentos")
-- noticias
Rem.changeRelation(a, b, 100)
local repB = Rem.getRep(b.id)
Rem.changeRep(a.id, -20, "golpe")
check(Rem.getRep(b.id) == repB - 10, "o que voce faz com um grupo chega aos aliados dele (pela metade)")
-- alvo por relacao
fresh()
setDay(30)
local civ = Rem.createGroup("civis", 27000, 27000, nil, 2)
local thugs = Rem.createGroup("saqueadores", 27100, 27000, nil, 3)
Rem.changeRelation(thugs, civ, 200)   -- fizeram as pazes
local raided = false
for _ = 1, 60 do
    thugs.supplies, thugs.activity, thugs.target = 0, "home", nil
    Rem.simulateWorld(1)
    if thugs.activity == "raid" then raided = true end
end
check(not raided, "saqueadores nao atacam quem esta em paz com eles")
-- expedicao punitiva
fresh()
setDay(30)
local mil = Rem.createGroup("sobreviventes", 28000, 28000, nil, 5)
local bad = Rem.createGroup("saqueadores", 28100, 28000, nil, 2)
local pc = Rem.World.CFG.PUNITIVE_CHANCE
Rem.World.CFG.PUNITIVE_CHANCE = 100
local punished = false
for _ = 1, 60 do
    mil.supplies, mil.activity, mil.target = 0, "home", nil
    Rem.simulateWorld(1)
    if mil.activity == "raid" and mil.target and mil.target.victim == bad.id then punished = true end
end
check(punished, "milicia forte faz expedicao punitiva contra saqueadores")
Rem.World.CFG.PUNITIVE_CHANCE = pc

SandboxVars.Remanescentes.WorldGroups = 0
setDay(0)
fresh()
