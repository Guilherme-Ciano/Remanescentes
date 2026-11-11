-- Pacote 0.19: habilidades por tarefa, relacoes entre moradores, ferimentos que duram e
-- enfermaria, revistar corpos, cronica de marcos.
local T = ...
local Rem = Remanescentes
local check, tick = T.check, T.tick
local player, realPrint = T.player, T.print
local PB, BB, BE, IA, JN, SK, FR, WD, SP, CH, WT = Rem.PlayerBase, Rem.BaseBuild, Rem.BaseEvents, Rem.Interact, Rem.Journal,
    Rem.Skills, Rem.Friends, Rem.Wounds, Rem.Spoils, Rem.Chronicle, Rem.Watch

local function fresh()
    Rem.dismissAll(); T.clearZombies(); Rem.hunting = {}
    Rem.Mugging.enc = {}
    SP.list = {}
    local s = Rem.getStore()
    s.reputation, s.quests, s.journal, s.playerBase, s.met, s.chronicle = {}, {}, {}, nil, {}, {}
    player.inv.items = {}
    player.weapon = nil
end
local function ally(x, y, extra)
    local o = { faction = "aliados", mode = "follow" }
    for k, v in pairs(extra or {}) do o[k] = v end
    local npc = Rem.spawn(x, y, 0, o)
    npc.rec.recruited = true
    return npc
end
local nextId = 160000
local function house()
    nextId = nextId + 400
    local x, y = nextId, 160000
    local def = T.addBuilding(nextId + 1, x, y, 8, 6)
    for i = x, x + 7 do for j = y, y + 5 do T.indoorSq[i .. "," .. j] = true; T.sqBuilding[i .. "," .. j] = def end end
    T.addObject(x + 2, y, 0, "IsoWindow", { exterior = true })
    T.addObject(x + 4, y + 5, 0, "IsoDoor", { exterior = true })
    T.addObject(x + 2, y + 2, 0, "container", { type = "fridge" })
    return { def = def, x = x, y = y }
end
local function base()
    local hs = house()
    player.x, player.y = hs.x + 4, hs.y + 4
    return PB.setHere(player), hs
end
local function member(g, hs, job, extra)
    local n = ally(hs.x + 3, hs.y + 3, extra)
    PB.join(n)
    if job then PB.setJob(n, job) end
    return n
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
local function opts(npc)
    local o = {}
    for _, id in ipairs(IA.dialogOptions(npc, player)) do o[id] = true end
    return o
end
T.timeOfDay = 12
SandboxVars.Remanescentes.MaxActive = 30

-- ===================================================================== habilidades
realPrint("300) Habilidades: aprender fazendo")
fresh()
local g, hs = base()
local b1 = member(g, hs, "build")
check(SK.level(b1.rec, "carpintaria") == 0, "comeca sem saber carpintaria")
local w0 = BB.workforce(g)
for _ = 1, 8 do SK.hourly() end
check(SK.level(b1.rec, "carpintaria") == 1 and lastJournal() == "IGUI_Rem_Journal_skill_up", "fortificando um dia: sobe para carpintaria 1 (diario)")
check(math.abs(BB.workforce(g) - w0 * (1 + SK.CFG.BUILD_BONUS)) < 0.001, "e rende mais nas obras")
T.timeOfDay = 23
local xp = b1.rec.skills.carpintaria
SK.hourly()
check(b1.rec.skills.carpintaria == xp, "(a noite ninguem fortifica: nao aprende)")
T.timeOfDay = 12
local s1 = member(g, hs, "scav")
local s2 = member(g, hs, "scav")
Rem.dematerialize(s1); Rem.dematerialize(s2)
T.addBuilding(nextId + 7, hs.x + 30, hs.y, 5, 5)      -- (um predio para revirar)
g.nearby = nil
withRand(function(a, bb) if a == 100 and not bb then return 99 end if bb then return a end return 0 end, function()
    PB.tripOffscene(g, s1.rec, s2.rec, "scav")
end)
check(s1.rec.skills.coleta == SK.CFG.TRIP_XP and s2.rec.skills.coleta == SK.CFG.TRIP_XP, "cada saida ensina coleta aos dois da dupla")
s1.rec.skills.coleta = SK.CFG.LEVELS[4]
check(SK.tripItems(s1.rec, s2.rec) == math.floor(4 * SK.CFG.TRIP_ITEMS) and SK.tripRiskDiv(s1.rec, nil) > 1,
    "coletor experiente traz mais e corre menos risco")
local gd = member(g, hs, "guard", { archetype = "atirador" })
gd.rec.archetype = "atirador"; gd.rec.skills = nil
check(SK.level(gd.rec, "vigia") == 1, "atirador ja comeca com olho de vigia")
check(SK.dozeLess(gd.rec) == SK.CFG.WATCH_DOZE and SK.watchRange(gd.rec) == SK.CFG.WATCH_RANGE, "vigia experiente cochila menos e ve mais longe")
require "Remanescentes/Rem_DialogUI"
local lines = RemProfileWindow.extraLines(s1.rec)
check(lines[1] and lines[1][1]:find("IGUI_Rem_Profile_skills", 1, true) or (lines[1] and lines[1][1] ~= ""), "a Ficha mostra as habilidades")

-- ===================================================================== enfermaria e ferimentos
realPrint("310) Ferimentos que duram")
fresh()
g, hs = base()
local m1 = member(g, hs, "build")
local m2 = member(g, hs, "scav")
local m3 = member(g, hs, "scav")
WD.inflict(m2.rec, "perna")
check(m2.rec.wound.kind == "perna" and lastJournal() == "IGUI_Rem_Journal_wounded", "ferido na perna (diario)")
check(Rem.Persona.mood(m2.rec) == "ferido", "humor: ferido")
check(Rem.travelGait(m2, 50) == "walk", "manca: nao corre")
check(not PB.ready(m2.rec, Rem.worldHours() + 100), "perna ferida nao sai para buscar")
check(PB.partnerFor(g, m3.rec, true) ~= m2.rec, "(nem como parceiro)")
WD.inflict(m1.rec, "braco")
check(WD.damageMult(m1.rec) == WD.CFG.ARM_DAMAGE, "braco ferido bate mais fraco")
check(math.abs(BB.workforce(g) - WD.CFG.ARM_WORK) < 0.001, "e rende metade nas obras")
WD.inflict(m1.rec, "corte")
check(m1.rec.wound.kind == "braco", "um ferimento mais leve nao troca o pior")
-- corte nao fecha sozinho
local m4 = member(g, hs, "rest")
Rem.dematerialize(m4)
m4.rec.hp = (m4.rec.maxHealth or 2) * 0.5
WD.inflict(m4.rec, "corte")
local hp0 = m4.rec.hp
PB.hourly()
check(m4.rec.hp == hp0, "corte aberto: nao recupera a vida")
-- sarar: sozinho x enfermaria
local left0 = WD.hoursLeft(m2.rec)
WD.hourly()
local selfHeal = left0 - WD.hoursLeft(m2.rec)
check(selfHeal == 0, "(sem ninguem cuidando, o tempo e o relogio)")
check(opts(m3).order_job_heal, "nova tarefa: '[Base] Cuida dos feridos.'")
IA.choose("order_job_heal", m3, player)
check(m3.rec.job == "heal", "m3 vai para a enfermaria")
left0 = WD.hoursLeft(m2.rec)
WD.hourly()
check(left0 - WD.hoursLeft(m2.rec) >= WD.CFG.MEDIC_EXTRA, "com enfermaria: sara mais rapido")
m3.rec.skills.medicina = SK.CFG.LEVELS[2]
left0 = WD.hoursLeft(m2.rec)
WD.hourly()
check(left0 - WD.hoursLeft(m2.rec) > WD.CFG.MEDIC_EXTRA, "quem sabe medicina cura ainda mais rapido")
SK.hourly()
check(m3.rec.skills.medicina > SK.CFG.LEVELS[2], "cuidar de feridos ensina medicina")
T.worldHours = T.worldHours + WD.CFG.HOURS.perna
WD.hourly()
check(m2.rec.wound == nil, "sarou")
check(Rem.runBehaviors and Rem.Roles, "(enfermaria em cena usa o comportamento de medico)")
local hurtNpc = member(g, hs, "rest")
hurtNpc.z:setHealth(0.2)
m3.nextHeal = 0
local handled = Rem.Roles.medicBehavior(m3, { player = nil }, Rem.nowMs())
check(handled, "quem esta na enfermaria vai ate o ferido e trata")
-- golpe forte em cena
local m5 = member(g, hs, "rest")
withRand(function(a, bb) if a == 100 and not bb then return 0 end if bb then return a end return 0 end, function()
    Rem.damageNPC(m5, (m5.rec.maxHealth or 2) * 0.35)
end)
check(m5.rec.wound ~= nil, "golpe forte em cena pode deixar um ferimento")

-- ===================================================================== relacoes
realPrint("320) Relacoes: amigos e rivais")
fresh()
g, hs = base()
local a = member(g, hs, "scav")
local b = member(g, hs, "scav")
local c = member(g, hs, "scav")
check(FR.of(a.rec, b.rec) == 0, "comecam neutros")
Rem.emit("tripDone", g, a.rec, b.rec, "scav")
check(FR.of(a.rec, b.rec) == FR.CFG.TRIP and FR.of(b.rec, a.rec) == FR.CFG.TRIP, "sair junto aproxima (dos dois lados)")
Rem.Banter.start(a, c, Rem.nowMs(), "generic")
check(FR.of(a.rec, c.rec) == FR.CFG.BANTER, "conversar aproxima")
for _ = 1, 4 do Rem.emit("tripDone", g, a.rec, b.rec, "scav") end
check(FR.isFriend(a.rec, b.rec) and lastJournal() == "IGUI_Rem_Journal_friends", "viraram amigos (diario)")
check(PB.partnerFor(g, c.rec, true) ~= nil, "(c tem parceiros)")
FR.add(c.rec, a.rec, -50)
check(FR.isRival(c.rec, a.rec) and lastJournal() == "IGUI_Rem_Journal_rivals", "rivais (diario)")
check(FR.pickPartner(c.rec, { a.rec, b.rec }) == b.rec, "rival nao e escolhido como parceiro")
check(FR.pickPartner(a.rec, { c.rec, b.rec }) == b.rec, "amigo e o preferido")
check(FR.pickPartner(c.rec, { a.rec }) == a.rec, "(sem outra opcao, vai com o rival mesmo)")
check(FR.tripRisk(a.rec, b.rec) == FR.CFG.FRIEND_RISK and FR.tripRisk(a.rec, c.rec) == 1, "amigos juntos correm menos risco")
local x1, x2 = FR.rivalPair(PB.members(g))
check((x1 == a.rec and x2 == c.rec) or (x1 == c.rec and x2 == a.rec), "o par de rivais e achado")
local before = FR.of(a.rec, c.rec)
BE.argue(g)
check(FR.of(a.rec, c.rec) == math.max(-100, before + FR.CFG.ARGUE), "a briga e entre os rivais (e piora)")
local fl, rl = FR.list(a.rec)
check(#fl == 1 and fl[1] == tostring(b.rec.name) and #rl == 1, "amigos e rivais por nome (Ficha)")
-- jeito: diario por dia
a.rec.personality = a.rec.personality or {}; b.rec.personality = b.rec.personality or {}
a.rec.personality.agressividade, b.rec.personality.agressividade = 9, 1
local ab = FR.of(a.rec, b.rec)
FR.daily(g)
check(FR.of(a.rec, b.rec) == ab + FR.CFG.DAILY_CLASH, "jeitos que nao combinam se estranham com o tempo")
-- luto de amigo
FR.add(a.rec, b.rec, 20)
b.rec.moral = 60
local m0 = 60
Rem.Persona.mourn(a.rec)
check(b.rec.griefFor == tostring(a.rec.name) and b.rec.moral < m0 - Rem.Persona.CFG.GRIEF_MORALE, "a morte de um amigo pesa muito mais")
check(b.rec.griefUntil >= Rem.worldHours() + FR.CFG.FRIEND_GRIEF_H, "(e o luto dura mais)")
Rem.removePerson(a.rec.id)
check(b.rec.rel[a.rec.id] == nil, "quem saiu da historia sai das relacoes")

-- ===================================================================== revistar corpos
realPrint("330) Revistar corpos")
fresh()
player.x, player.y = 170000, 170000
local f = ally(170002, 170000)
f.rec.firearm, f.rec.ammo = "Base.Pistol", 5
local raider = Rem.spawn(170006, 170000, 0, { faction = "saqueadores", mode = "stay" })
check(Rem.isHostileToPlayer(raider), "(saqueador hostil)")
local holder = T.addObject(170300, 170300, 0, "container", { type = "corpse" })
local corpseC = holder.container
corpseC:AddItem("Base.Bullets9mmBox")
corpseC:AddItem(instanceItem("Base.Shotgun"))
corpseC:AddItem("Base.TinnedBeans")
corpseC:AddItem("Base.Sofa")
local key = "170006,170000"
T.deadBodies[key] = { { getContainer = function() return corpseC end } }
raider.z:Kill(nil)
check(#SP.list == 1, "hostil morto: o corpo fica para revistar")
local civ = Rem.spawn(170010, 170000, 0, { faction = "civis", mode = "stay" })
civ.z:Kill(nil)
check(#SP.list == 1, "(gente que nao era hostil nao e revistada)")
f.z.path, f.nextPath, f.lastPathX = nil, 0, nil
local h = Rem.runBehaviors(f, { player = player }, Rem.nowMs())
check(h == "spoils" and f.z.path and math.abs(f.z.path[1] - 170006) < 1.5, "a briga acabou: vai ate o corpo")
check(not SP.behavior(f, { player = player, enemy = T.newZombie(170003, 170000, 0) }, Rem.nowMs()), "(com inimigo por perto, nao)")
T.clearZombies()
f.z.x, f.z.y = 170006, 170000.5
local now = Rem.nowMs()
SP.behavior(f, { player = player }, now)
SP.behavior(f, { player = player }, now + 100)
check(#corpseC.items == 4, "revistar leva um tempo")
SP.behavior(f, { player = player }, now + SP.CFG.SEARCH_MS + 10)
check(f.rec.ammo == 5 + Rem.Ranged.CFG.ROUNDS_PER_BOX, "municao da arma dele vai direto para o pente")
check(#f.rec.carry == 2 and #corpseC.items == 1, "pega a espingarda e a comida; deixa o sofa")
check(f.spoilsDeliver, "e traz para voce")
f.z.x, f.z.y = player.x + 1, player.y
SP.behavior(f, { player = player }, now + SP.CFG.SEARCH_MS + 200)
local got = 0
for _, it in ipairs(player.inv.items) do if it:getFullType() == "Base.Shotgun" or it:getFullType() == "Base.TinnedBeans" then got = got + 1 end end
check(got == 2 and (f.rec.carry == nil or #f.rec.carry == 0), "entrega no seu inventario")
check(not SP.behavior(f, { player = player }, now + SP.CFG.SEARCH_MS + 300), "corpo ja revistado: volta a seguir voce")
f.rec.stance = "retreat"
table.insert(SP.list, { x = 170001, y = 170000, z = 0, at = Rem.nowMs() })
check(not SP.behavior(f, { player = player }, Rem.nowMs()), "(recuando nao para para revistar)")
f.rec.stance = nil

-- ===================================================================== cronica
realPrint("340) Cronica de marcos")
fresh()
T.halo = {}
g, hs = base()
check(CH.has("base") and #T.halo >= 1, "definir a base: capitulo 'Um lugar para chamar de casa' (aparece na tela)")
local nb = #CH.list()
PB.setHere(player)
check(#CH.list() == nb, "cada marco so uma vez")
local r = ally(hs.x + 3, hs.y + 3)
Rem.emit("playerDeed", "recruited", r)
check(CH.has("first_ally"), "primeiro aliado")
Rem.emit("baseProjectDone", g, "perimeter")
check(CH.has("first_work") and CH.has("fence"), "primeira obra e a cerca")
JN.add("IGUI_Rem_Journal_alarm_zombies", "x", "3")
check(CH.has("alarm"), "o primeiro alarme (vem do diario)")
Rem.Persona.mourn(r.rec)
check(CH.has("first_loss"), "o primeiro adeus")
Rem.getStore().timeline.startHours = Rem.worldHours() - 24 * 8
CH.hourly()
check(CH.has("night1") and CH.has("week1") and not CH.has("month1"), "uma semana de pe")
require "Remanescentes/Rem_JournalUI"
local realGet = getText
getText = function(k, ...) return k .. " " .. table.concat({ ... }, " ") end
local text = JN.compose(player)
getText = realGet
check(text:find("IGUI_Rem_Journal_chronicle", 1, true) and text:find("IGUI_Rem_Chapter_fence", 1, true), "o Diario tem a secao Cronica")
local entries = 0
for _, e in ipairs(JN.entries()) do if e.key == "IGUI_Rem_Journal_chapter" then entries = entries + 1 end end
check(entries == 0, "(capitulos nao enchem a lista de acontecimentos)")

T.timeOfDay = 12
SandboxVars.Remanescentes.MaxActive = T.defaults().MaxActive
fresh()
