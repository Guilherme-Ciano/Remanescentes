-- Sistemas mais amplos: especialidades, equipar aliados, aliancas, ataques a sua base.
local T = ...
local Rem = Remanescentes
local check, tick = T.check, T.tick
local player, realPrint = T.player, T.print
local PB, BB, BE, IA, JN, GE, AL = Rem.PlayerBase, Rem.BaseBuild, Rem.BaseEvents, Rem.Interact, Rem.Journal, Rem.Gear, Rem.Alliance

local function fresh()
    Rem.dismissAll(); T.clearZombies(); Rem.hunting = {}
    Rem.Mugging.enc = {}
    local s = Rem.getStore()
    s.reputation, s.quests, s.journal, s.playerBase, s.met = {}, {}, {}, nil, {}
    player.inv.items = {}
    player.weapon, player.weapon2 = nil, nil
end
local function weapon(id, opts)
    local w = T.newWeapon(id)
    w.getFullType = function() return id end
    w.getDisplayName = function() return id end
    w.isRanged = function() return opts and opts.ranged or false end
    w.isTwoHandWeapon = function() return opts and opts.two or false end
    w.isRequiresEquippedBothHands = function() return false end
    return w
end
player.setPrimaryHandItem = function(self, i) self.weapon = i end
player.getSecondaryHandItem = function(self) return self.weapon2 end
player.setSecondaryHandItem = function(self, i) self.weapon2 = i end
local function ally(x, y, extra)
    local opts = { faction = "aliados", mode = "follow" }
    for k, v in pairs(extra or {}) do opts[k] = v end
    local npc = Rem.spawn(x, y, 0, opts)
    npc.rec.recruited = true
    return npc
end
local nextId = 80000
local function house()
    nextId = nextId + 400
    local x, y = nextId, 80000
    local def = T.addBuilding(nextId + 1, x, y, 8, 6)
    for i = x, x + 7 do for j = y, y + 5 do T.indoorSq[i .. "," .. j] = true; T.sqBuilding[i .. "," .. j] = def end end
    T.addObject(x + 2, y, 0, "IsoWindow", { exterior = true })
    T.addObject(x + 4, y + 5, 0, "IsoDoor", { exterior = true })
    T.addObject(x + 2, y + 2, 0, "container", { type = "fridge" })
    return { def = def, x = x, y = y }
end
T.timeOfDay = 10
SandboxVars.Remanescentes.MaxActive = 30

realPrint("230) Equipar: dar a sua arma")
fresh()
player.x, player.y = 90000, 90000
local a = ally(90002, 90000)
local opts = {}
for _, id in ipairs(IA.dialogOptions(a, player)) do opts[id] = true end
check(not opts.gear_weapon, "sem arma na mao: a opcao nao aparece")
local axe = weapon("Base.Axe", { two = true })
player.inv:AddItem(axe)
player.weapon = axe
opts = {}
for _, id in ipairs(IA.dialogOptions(a, player)) do opts[id] = true end
check(opts.gear_weapon, "com arma na mao: '[Equipar] Usa esta arma.'")
local oldItem = a.rec.item
local l = IA.choose("gear_weapon", a, player)
local hasOld, hasAxe = false, false
for _, it in ipairs(player.inv.items) do
    if it:getFullType() == oldItem then hasOld = true end
    if it == axe then hasAxe = true end
end
check(a.rec.item == "Base.Axe" and a.rec.wtype == "bat" and l.key == "IGUI_Rem_Gear_ok", "ele passa a usar o machado (duas maos: animacoes de taco)")
check(player.weapon == nil and not hasAxe and hasOld, "o machado sai do seu inventario; a arma antiga dele volta para voce")
check(a.rec.mem[#a.rec.mem].k == "armed", "e ele lembra disso")
local knife = weapon("Base.HuntingKnife")
player.inv:AddItem(knife); player.weapon = knife
IA.choose("gear_weapon", a, player)
check(a.rec.item == "Base.HuntingKnife" and a.rec.wtype == "1h", "faca: animacoes de uma mao")
-- arma de fogo
local pistol = weapon("Base.Pistol", { ranged = true })
player.inv:AddItem(pistol); player.weapon = pistol
for _ = 1, 3 do player.inv:AddItem("Base.Bullets9mmBox") end
l = IA.choose("gear_weapon", a, player)
local boxes = 0
for _, it in ipairs(player.inv.items) do if it:getFullType() == "Base.Bullets9mmBox" then boxes = boxes + 1 end end
check(a.rec.firearm == "Base.Pistol" and a.rec.ammo == 2 * Rem.Ranged.CFG.ROUNDS_PER_BOX and boxes == 1 and l.key == "IGUI_Rem_Gear_gun_ok",
    "pistola: leva junto 2 caixas de municao (e sabe atirar)")
check(Rem.Ranged.canShoot(a), "agora ele atira")
opts = {}
for _, id in ipairs(IA.dialogOptions(a, player)) do opts[id] = true end
check(opts.gear_ammo, "voce ainda tem uma caixa: '[Equipar] Toma municao.'")
a.rec.ammo = 0
l = IA.choose("gear_ammo", a, player)
check(a.rec.ammo == Rem.Ranged.CFG.ROUNDS_PER_BOX and l.key == "IGUI_Rem_Gear_ammo_ok", "municao entregue")
local weird = weapon("Base.Rifle_Exotic", { ranged = true })
player.inv:AddItem(weird); player.weapon = weird
l = IA.choose("gear_weapon", a, player)
check(l.key == "IGUI_Rem_Gear_unknown_gun" and a.rec.firearm == "Base.Pistol" and player.weapon == weird, "arma de fogo que ele nao conhece: recusa e voce fica com ela")
local civ = Rem.spawn(90004, 90000, 0, { faction = "civis", mode = "stay" })
opts = {}
for _, id in ipairs(IA.dialogOptions(civ, player)) do opts[id] = true end
check(not opts.gear_weapon, "so para quem anda com voce (ou mora na sua base)")
local okC, lC = GE.giveWeapon(civ, player)
check(not okC and lC.key == "IGUI_Rem_Gear_no" and player.weapon == weird, "(e um estranho nao aceita a sua arma)")

realPrint("231) Especialidades")
fresh()
local hs = house()
player.x, player.y = hs.x + 4, hs.y + 4
local g = PB.setHere(player)
local eng = ally(hs.x + 3, hs.y + 3, { archetype = "engenheiro" })
eng.rec.archetype = "engenheiro"
PB.join(eng); PB.setJob(eng, "build")
check(BB.perDay(g) == math.floor(BB.CFG.ENGINEER_BONUS * BB.CFG.STEPS_PER_DAY + 0.5), "engenheiro rende mais nas obras")
eng.rec.archetype = "brigao"
check(BB.perDay(g) == BB.CFG.STEPS_PER_DAY, "(outro arquetipo: o normal)")
local d0 = BE.defense(g)
eng.rec.firearm, eng.rec.ammo = "Base.Pistol", 10
check(math.abs(BE.defense(g) - d0 - BE.CFG.GUNNER_BONUS) < 0.001, "quem tem arma e municao defende mais a base")
-- medico acelera a recuperacao
local doc = ally(hs.x + 5, hs.y + 3)
doc.rec.archetype = "medico"
PB.join(doc); PB.setJob(doc, "rest")
eng.rec.archetype = "brigao"
for _, n in ipairs({ eng, doc }) do Rem.dematerialize(n) end
player.x, player.y = hs.x + 900, hs.y
g.supplies = 50
eng.rec.hp = eng.rec.maxHealth * 0.2
eng.rec.job = "guard"
PB.hourly()
local withDoc = eng.rec.hp
eng.rec.hp = eng.rec.maxHealth * 0.2
doc.rec.archetype = "brigao"
PB.hourly()
check(withDoc > eng.rec.hp, "medico na base: os feridos se recuperam mais rapido")
-- furtivo na dupla: menos risco
local a1, a2 = Rem.getPerson(eng.rec.id), Rem.getPerson(doc.rec.id)
for k = 1, 2 do T.addBuilding(nextId + 300 + k, hs.x + 30 + k * 12, hs.y + 20, 8, 6) end
g.nearby = nil
SandboxVars.Remanescentes.ScavengeDeathChance = 8
local realRand = ZombRand
ZombRand = function(x, y) if x == 100 and not y then return 1 end return realRand(x, y) end
a1.archetype, a2.archetype = "brigao", "brigao"
a1.lastTrip, a2.lastTrip = nil, nil
local r1 = PB.tripOffscene(g, a1, a2, "scav")
check(r1 == "dead", "(o azar que mata uma dupla comum)")
local b1 = ally(hs.x + 900, hs.y + 1); PB.join(b1)
local b2 = ally(hs.x + 900, hs.y + 2); PB.join(b2)
b1.rec.archetype = "furtivo"
g.nearby = nil
local r2 = PB.tripOffscene(g, b1.rec, b2.rec, "scav")
ZombRand = realRand
SandboxVars.Remanescentes.ScavengeDeathChance = T.defaults().ScavengeDeathChance
check(r2 ~= "dead", "com alguem furtivo na dupla, o mesmo azar nao mata")

realPrint("232) Aliancas")
fresh()
local def2 = T.addBuilding(nextId + 77, nextId + 77, 80000, 8, 6)
for i = nextId + 77, nextId + 84 do for j = 80000, 80005 do T.indoorSq[i .. "," .. j] = true; T.sqBuilding[i .. "," .. j] = def2 end end
player.x, player.y = nextId + 81, 80010
local fam = Rem.createGroup("civis", nextId + 81, 80003, tostring(nextId + 77), 3, def2)
fam.activity, fam.supplies = "home", 40
local talker = Rem.materialize(Rem.getPerson(fam.members[1]))
talker.talkingUntil = nil
opts = {}
for _, id in ipairs(IA.dialogOptions(talker, player)) do opts[id] = true end
check(opts.ally, "conversa: 'Vamos nos aliar'")
Rem.getStore().reputation[fam.id] = 30
talker.rec.bond = 0
local okA = AL.propose(talker)
check(not okA and not fam.allied and IA.hint("ally", talker).key == "IGUI_Rem_Hint_ally", "pouca confianca: ainda nao (e a conversa diz quanto falta)")
talker.rec.bond = 60
okA, l = AL.propose(talker)
check(okA and fam.allied and l.key == "IGUI_Rem_Ally_yes", "reputacao + vinculo com quem voce conversa: alianca fechada")
check(JN.entries()[#JN.entries()].key == "IGUI_Rem_Journal_ally" and talker.rec.mem[#talker.rec.mem].k == "allied", "diario e memoria")
check(IA.markup(talker) == 1.0, "aliados trocam sem margem")
opts = {}
for _, id in ipairs(IA.dialogOptions(talker, player)) do opts[id] = true end
check(not opts.ally, "ja aliados: a opcao some")
local raiders = Rem.createGroup("saqueadores", nextId + 400, 80000, nil, 3)
local rnpc = Rem.materialize(Rem.getPerson(raiders.members[1]))
check(not AL.canAsk(rnpc), "saqueadores nao fazem alianca")
-- ajuda na defesa da sua base e comida
local hb = house()
player.x, player.y = hb.x + 4, hb.y + 4
local base = PB.setHere(player)
local m = ally(hb.x + 3, hb.y + 3); PB.join(m)
base.home.x, base.home.y = hb.x + 4, hb.y + 3
fam.home.x = base.home.x + 100
local withAlly = BE.defense(base)
fam.allied = nil
check(math.abs(withAlly - BE.defense(base) - AL.CFG.HELP_DEFENSE) < 0.001, "grupo aliado por perto manda gente quando a base e atacada")
fam.allied = true
fam.home.x = base.home.x + AL.CFG.HELP_RADIUS + 100
check(math.abs(BE.defense(base) - (withAlly - AL.CFG.HELP_DEFENSE)) < 0.001, "aliado longe demais nao chega a tempo")
fam.home.x = base.home.x + 100
local sup0 = base.supplies or 0
fam.supplies = 3 * AL.CFG.SHARE_SURPLUS + 10
check(AL.share() == AL.CFG.SHARE_ITEMS and base.supplies > sup0 and #(base.pendingList or {}) == AL.CFG.SHARE_ITEMS, "aliado com sobra manda comida para a base")
fam.supplies = 1
check(AL.share() == 0, "sem sobra, nao manda")
-- a alianca cai junto com a reputacao
Rem.changeRep(fam.id, -100, "teste")
check(not fam.allied and JN.entries()[#JN.entries()].key == "IGUI_Rem_Journal_ally_broken", "bater, ameacar ou matar alguem deles: a alianca acaba")

realPrint("233) Saqueadores atacam a sua base")
fresh()
local hr = house()
player.x, player.y = hr.x + 4, hr.y + 4
local rb = PB.setHere(player)
local def1 = ally(hr.x + 3, hr.y + 3); PB.join(def1)
setDay = function(d) Rem.getStore().timeline.startHours = Rem.worldHours() - 24 * d end
setDay(0)
local band = Rem.createGroup("saqueadores", hr.x + 200, hr.y, nil, 4)
band.activity = "home"
check(BE.raiders(rb) == nil, "antes do dia dos saqueadores: ninguem ataca")
setDay(30)
check(BE.raiders(rb) == band, "depois: o bando mais perto e o candidato")
band.home.x = hr.x + BE.CFG.RAID_RADIUS + 50
check(BE.raiders(rb) == nil, "bando longe demais nao vem")
band.home.x = hr.x + 200
-- com voce la: eles chegam de verdade
local made = BE.raid(rb, player)
local raidersHere = 0
for _, npc in pairs(Rem.active) do if npc.rec.ambient == "base_raid" then raidersHere = raidersHere + 1 end end
check(made == "here" and raidersHere == math.min(BE.CFG.RAID_MAX, #band.members) and JN.entries()[#JN.entries()].key == "IGUI_Rem_Journal_ev_raid_here",
    "com voce la: o bando chega de verdade (" .. raidersHere .. ") e vai para a base")
local one = nil
for _, npc in pairs(Rem.active) do if npc.rec.ambient == "base_raid" then one = npc end end
check(Rem.isHostileToPlayer(one) and Rem.npcsHostile(one, def1), "hostis a voce e aos moradores")
one.z.path, one.nextPath, one.lastPathX = nil, 0, nil
Rem.Ambient.HANDLERS.base_raid(one, { player = player }, Rem.nowMs())
check(one.z.path and math.abs(one.z.path[1] - rb.home.x) < 1, "correndo para a base")
-- longe
for _, npc in pairs(Rem.active) do if npc.rec.ambient == "base_raid" then Rem.dismiss(npc) end end
Rem.dematerialize(def1)
player.x, player.y = hr.x + 3000, hr.y
rb.supplies = 10
local realRand2 = ZombRand
ZombRand = function(x, y) if y then return x end return 0 end
rb.home.windowsTotal, rb.home.windowsDone, rb.home.fenceTotal, rb.home.fenceBuilt = 2, 0, 40, 0
local r = BE.raid(rb, player)
check(r == "lost" and rb.supplies == 5 and #rb.members == 0, "base aberta e pouca gente: invadem, levam metade da comida, matam alguem")
local def2b = ally(hr.x + 3000, hr.y + 1); PB.join(def2b); PB.setJob(def2b, "guard")
Rem.dematerialize(def2b)
rb.home.windowsDone, rb.home.fenceBuilt = 2, 40
local bandSize = #band.members
r = BE.raid(rb, player)
ZombRand = realRand2
check(r == "held" and #band.members == bandSize - 1, "base fortificada com vigia: repelidos (o bando perde alguem)")
T.timeOfDay = 12
SandboxVars.Remanescentes.MaxActive = T.defaults().MaxActive
fresh()
