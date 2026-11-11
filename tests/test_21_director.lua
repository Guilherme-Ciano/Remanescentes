-- O cerebro do grupo (Rem_Director): necessidades -> objetivo -> trabalho visivel; e o que
-- muda na conversa (o que estao fazendo, pedir ajuda, consequencias, diario).
local T = ...
local Rem = Remanescentes
local check, tick = T.check, T.tick
local player, realPrint = T.player, T.print
local DR, IA, BD, JN, TL = Rem.Director, Rem.Interact, Rem.Bonds, Rem.Journal, Rem.Timeline

local tl = Rem.getStore().timeline
local function setDay(d) tl.startHours = Rem.worldHours() - 24 * d end
local function fresh()
    Rem.dismissAll(); T.clearZombies(); Rem.hunting = {}
    Rem.Mugging.enc = {}
    local s = Rem.getStore()
    s.reputation, s.siege, s.mapMarks, s.knownGroups, s.quests, s.journal, s.met = {}, nil, {}, {}, {}, {}, {}
    player.inv.items = {}
    player.weapon, player.bag = nil, nil
    T.halo = {}
end
local function scene() Rem.emit("sceneUpdate", player, Rem.nowMs()) end
local nextId = 42000
-- casa 10x8 com 4 janelas externas (norte) e uma porta (sul); cozinha com geladeira
local function home(faction, n)
    nextId = nextId + 200
    local x, y = nextId, 42000
    local def = T.addBuilding(nextId + 1, x, y, 10, 8)
    for i = x, x + 9 do for j = y, y + 7 do T.indoorSq[i .. "," .. j] = true; T.sqBuilding[i .. "," .. j] = def end end
    local windows = {}
    for i = 0, 3 do table.insert(windows, T.addObject(x + 1 + i * 2, y, 0, "IsoWindow", { exterior = true })) end
    T.addObject(x + 5, y + 7, 0, "IsoDoor", { exterior = true })
    local box = T.addObject(x + 2, y + 2, 0, "container", { type = "fridge" })
    player.x, player.y = x + 5, y + 12
    local g = Rem.createGroup(faction or "civis", x + 5, y + 4, tostring(nextId + 1), n or 3, def)
    g.supplies, g.activity = 30, "home"
    for _, id in ipairs(g.members) do            -- todos em cena, dentro de casa
        local p = Rem.getPerson(id)
        if not p.onScene then Rem.materialize(p) end
    end
    return g, windows, box
end
local function barricaded(windows)
    local n = 0
    for _, w in ipairs(windows) do if w:isBarricaded() then n = n + 1 end end
    return n
end
local function members(g)
    local out = {}
    for _, npc in pairs(Rem.active) do if npc.rec.groupId == g.id then table.insert(out, npc) end end
    table.sort(out, function(a, b) return tostring(a.rec.id) < tostring(b.rec.id) end)
    return out
end
T.timeOfDay = 10
SandboxVars.Remanescentes.MaxActive = 20

realPrint("180) Primeiros dias: as casas ainda nao estao fechadas")
fresh()
DR.CFG.INITIAL_MIN = 0.15
setDay(0)
check(math.abs(DR.initialFortify() - 0.15) < 0.001, "dia 0: so 15% da fortificacao de antes")
setDay(3)
check(DR.initialFortify() > 0.5 and DR.initialFortify() < 0.65, "dia 3: metade")
setDay(10)
check(DR.initialFortify() == 1, "do dia 6 em diante: como antes")
setDay(0)
local total = 0
for _ = 1, 6 do
    local g0, w0 = home("sobreviventes", 2)
    scene()
    total = total + barricaded(w0)
    Rem.dismissAll()
end
check(total <= 8, "no dia 0 quase nenhuma janela nasce com tabua (" .. total .. " de 24)")

realPrint("181) Necessidades e objetivo")
fresh()
setDay(0)
local g, windows = home("civis", 3)
scene()
g.materials = 6
local n = DR.needs(g)
check(n.food == 0 and n.health == 0 and n.members == 3, "casa abastecida e sem feridos: comida e saude ok")
DR.scanHome(g, Rem.nowMs(), true)
local open0 = #g.home.openWindows
check(g.home.windowsTotal == 4 and open0 >= 3 and DR.needs(g).safety >= 0.75, "janelas abertas: seguranca e a necessidade (" .. open0 .. " abertas)")
check(DR.choose(g, 0) == "fortify", "objetivo: reforcar a casa")
g.materials = 0
check(DR.choose(g, 0) == "scavenge", "sem material: sair para buscar")
g.materials = 6
g.supplies = 1
check(DR.needs(g).food > DR.CFG.FOOD_URGENT and DR.choose(g, 0) == "scavenge", "comida acabando vem antes das janelas")
g.supplies = 30
local list = members(g)
list[1].z.hp, list[2].z.hp = list[1].rec.maxHealth * 0.3, list[2].rec.maxHealth * 0.3
check(DR.needs(g).wounded == 2 and DR.choose(g, 0) == "heal", "muitos feridos: ficam cuidando deles")
list[1].z.hp, list[2].z.hp = list[1].rec.maxHealth, list[2].rec.maxHealth
check(DR.choose(g, 1) == "clear", "um zumbi na rua: saem para limpar")
check(DR.choose(g, 40) == "hide", "uma horda: todo mundo para dentro")
local seen = nil
Rem.on("groupGoal", function(gg, goal) if gg == g then seen = goal end end)
DR.choose(g, 0)
check(seen == "fortify" and g.goal == "fortify" and g.goalSince ~= nil, "mudanca de objetivo vira evento (e fica guardada no grupo)")

realPrint("182) Trabalho de verdade: os grupos de NPC tambem constroem (mesmo sistema da sua base)")
local GL, BB = Rem.GroupLife, Rem.BaseBuild
local mat0 = g.materials
local jobs = GL.assignJobs(g)
check(jobs.guard == 1 and jobs.build >= 1, "o mestre de obras divide: um de guarda, quem fortifica")
local worker = nil
for _, npc in ipairs(members(g)) do if npc.rec.job == "build" then worker = npc end end
check(worker ~= nil and worker.rec.role ~= "guarda", "quem prega nunca e o guarda")
check(DR.worker(g) == nil, "(o cerebro do grupo nao prega mais: as obras sao de Rem_BaseBuild)")
local plan = BB.scan(g)
check(#plan.windows >= 3 and #plan.perimeter > 0 and #plan.cars == 0, "familia: janelas e cerca (carro na rua e coisa de milicia e saqueador)")
local target = plan.windows[1]
worker.z.said, worker.lastBark, worker.barkAt = {}, nil, {}
worker.z.x, worker.z.y = g.home.x + 3, g.home.y + 2
worker.nextPath, worker.lastPathX = 0, nil
check(BB.behavior(worker, { player = player }, Rem.nowMs()) == true and worker.moving, "vai ate a janela aberta")
worker.z.x, worker.z.y = target.x + 0.5, target.y + 1.5
Rem.stopMoving(worker)
local before = barricaded(windows)
BB.behavior(worker, { player = player }, Rem.nowMs())
check(barricaded(windows) == before + 1 and g.materials == mat0 - 1, "primeira martelada: a janela ganha tabua e o material e gasto")
check(T.saidPrefix(worker.z, "IGUI_Rem_Bark_work_"), "comenta o trabalho")
g.materials = 0
GL.assignJobs(g)
local builders, gatherers = 0, 0
for _, npc in ipairs(members(g)) do
    if npc.rec.job == "build" then builders = builders + 1 end
    if npc.rec.job == "materials" then gatherers = gatherers + 1 end
end
check(builders == 0 and gatherers == 2, "sem material: ninguem prega, uma dupla sai para buscar")
g.materials = 6
local mil = Rem.createGroup("sobreviventes", g.home.x + 300, g.home.y, nil, 3)
local milList = {}
for _, p in ipairs(BB.projectsFor(mil)) do milList[p] = true end
check(milList.cars and milList.barbed and milList.generator, "milicia: arame farpado, carros na rua, gerador")
local raidG = Rem.createGroup("saqueadores", g.home.x + 600, g.home.y, nil, 3)
local rl = {}
for _, p in ipairs(BB.projectsFor(raidG)) do rl[p] = true end
check(rl.cars and not rl.perimeter, "saqueadores: carros e arame, sem cerca de familia")
check(#BB.projectsFor(Rem.createGroup("errantes", g.home.x + 900, g.home.y, nil, 1)) == 0, "errantes nao constroem (estao de passagem)")
-- extensao: faccao e projeto de outro mod
Rem.registerFaction("teste_fortes", { hostileToPlayer = false, temper = "cauteloso", base = { projects = { "perimeter" } } })
local tf = Rem.createGroup("teste_fortes", g.home.x + 1200, g.home.y, nil, 2)
check(#BB.projectsFor(tf) == 1 and BB.projectsFor(tf)[1] == "perimeter", "faccao registrada escolhe as proprias obras (def.base.projects)")
local built = 0
BB.registerProject("teste_poste", { cost = 1, after = "windows", factions = { civis = true },
    plan = function(gg, h) return { { x = h.x2 + 2, y = h.y1, z = 0, left = 1 } } end,
    apply = function(gg, h, t) built = built + 1 return true end })
local order = BB.projectsFor(g)
check(order[2] == "teste_poste", "projeto registrado por outro mod entra na fila, na posicao pedida")
check(not (function() for _, p in ipairs(BB.projectsFor(mil)) do if p == "teste_poste" then return true end end end)(),
    "e so para as faccoes que ele permitir")
BB.EXTRA.teste_poste = nil
for i, p in ipairs(BB.PROJECTS) do if p == "teste_poste" then table.remove(BB.PROJECTS, i) break end end
Rem.removePerson(mil.members[1]); Rem.getStore().groups[mil.id] = nil
Rem.getStore().groups[raidG.id] = nil
Rem.getStore().groups[tf.id] = nil
Rem.FACTIONS.teste_fortes = nil

realPrint("183) Zumbis na rua: limpar ou se esconder")
local guard, brave = nil, nil
for _, npc in ipairs(members(g)) do
    npc.rec.personality.coragem = 5
    npc.rec.moral = 50
    if npc.rec.role == "guarda" then guard = npc end
end
local zed = T.newZombie(g.home.x, g.home.y2 + 10, 0, 0, 1)
zed.canSee = false
T.clock = T.clock + DR.CFG.TICK_MS + 1
scene()
check(g.goal == "clear" and guard.clearing == true, "um zumbi perto da casa: o guarda sai para limpar")
local clearing = 0
for _, npc in ipairs(members(g)) do if npc.clearing then clearing = clearing + 1 end end
check(clearing == math.min(DR.CFG.DEFENDERS, #members(g)), "saem " .. clearing .. " defensores; os outros ficam")
check(DR.inClearZone(guard, zed), "(o zumbi esta na area que eles limpam)")
guard.z.x, guard.z.y = g.home.x, g.home.y2 + 1
tick(300, 3)
check(guard.z.path and math.abs(guard.z.path[2] - zed.y) < 1.5, "ele vai ate o zumbi, mesmo sem ser ameaca direta")
T.clearZombies({ [guard.z] = true, [members(g)[1].z] = true, [members(g)[2].z] = true, [members(g)[3].z] = true })
-- muitos zumbis, mas longe das paredes: a vida segue (nao saem para a rua, nao se escondem)
for i = 1, 30 do T.newZombie(g.home.x - 8 + i * 0.5, g.home.y2 + 10, 0, 0, 1).canSee = false end
T.clock = T.clock + DR.CFG.TICK_MS + 1
scene()
check(g.goal ~= "hide" and g.goal ~= "clear", "horda passando na rua, longe das paredes: nao se trancam nem saem para brigar (" .. tostring(g.goal) .. ")")
T.clearZombies({ [members(g)[1].z] = true, [members(g)[2].z] = true, [members(g)[3].z] = true })
for i = 1, 30 do T.newZombie(g.home.x - 8 + i * 0.5, g.home.y2 + 3, 0, 0, 1).canSee = false end
T.clock = T.clock + DR.CFG.TICK_MS + 1
for _, npc in ipairs(members(g)) do npc.z.said, npc.barkAt, npc.lastBark = {}, {}, nil end
scene()
local hiding, said = 0, false
for _, npc in ipairs(members(g)) do
    if npc.hiding then hiding = hiding + 1 end
    if T.saidPrefix(npc.z, "IGUI_Rem_Bark_hide_") then said = true end
end
check(g.goal == "hide" and hiding == #members(g) and said, "horda: todos se escondem e alguem manda fazer silencio")
local hider = members(g)[2]
hider.fleeing = false
check(DR.hideBehavior(hider, { player = player }, Rem.nowMs()) == true and (hider.sneaking or hider.moving), "para dentro, agachado")
T.clearZombies({ [members(g)[1].z] = true, [members(g)[2].z] = true, [members(g)[3].z] = true })
Rem.hunting = {}
T.clock = T.clock + DR.CFG.TICK_MS + 1
scene()
check(g.goal ~= "hide" and not members(g)[2].hiding, "a horda passou: voltam ao trabalho")

realPrint("184) Fora de cena: buscar comida e material")
fresh()
local far = home("civis", 3)
Rem.dismissAll = Rem.dismissAll
for _, npc in ipairs(members(far)) do Rem.dematerialize(npc) end
player.x, player.y = far.home.x + 500, far.home.y
T.addBuilding(nextId + 77, far.home.x + 60, far.home.y, 8, 8)
far.supplies = 0.5
far.materials = 3
far.home.windowsTotal, far.home.windowsDone = 4, 4      -- (casa ja fechada: o material so acumula)
DR.hourly()
check(far.goal == "scavenge" and far.activity == "scavenge" and far.target ~= nil, "comida no fim: o grupo sai para buscar (sem depender de sorte)")
far.activity, far.lastActivity = "return", "return"
far.supplies = 30
far.activity = "home"
DR.hourly()
check(far.materials == 3 + DR.CFG.MATERIALS_PER_TRIP, "cada saque traz material para as janelas")

realPrint("184b) O trabalho continua quando voce vai embora")
fresh()
setDay(0)
local away, wa = home("civis", 3)
scene()
Rem.BaseBuild.scan(away)
local open1 = #Rem.BaseBuild.last[away.id].windows
check(open1 >= 2, "(cenario) casa com janelas abertas: " .. open1)
for _, npc in ipairs(members(away)) do Rem.dematerialize(npc) end
player.x, player.y = away.home.x + 500, away.home.y
away.materials = 20
T.timeOfDay = 10
Rem.GroupLife.assignJobs(away)
for _ = 1, 4 do Rem.emit("worldHour", Rem.worldHours()) end
local pend = 0
for _, n in pairs(away.home.pendingBuild or {}) do pend = pend + n end
check(pend >= 2 and away.materials < 20, "longe de voce, de dia, continuam pregando (gastando material): " .. pend .. " passos")
T.timeOfDay = 23
local p0 = pend
away.home.buildToday = 0
Rem.emit("worldHour", Rem.worldHours())
pend = 0
for _, n in pairs(away.home.pendingBuild or {}) do pend = pend + n end
check(pend == p0, "de noite ninguem martela")
T.timeOfDay = 10
local before2 = barricaded(wa)
player.x, player.y = away.home.x + 5, away.home.y + 12
T.clock = T.clock + 5000
scene()
check(barricaded(wa) > before2 and away.home.pendingBuild == nil, "voltando: as janelas fechadas na sua ausencia estao la, com tabuas")

realPrint("185) A conversa mostra o que estao fazendo, e as missoes acompanham")
fresh()
setDay(0)
local g2, w2, box2 = home("civis", 3)
scene()
g2.materials = 0
DR.scanHome(g2, Rem.nowMs(), true)
DR.choose(g2, 0)
local talker = members(g2)[1]
Rem.changeRep(g2.id, 30, "teste")
check(IA.status(talker).key == "IGUI_Rem_Goal_materials", "'Como vao as coisas?': querem fechar as janelas mas falta material")
local q, ql = IA.offerQuest(talker)
check(q.kind == "materials" and ql.key == "IGUI_Rem_Quest_materials", "e a missao que pedem e trazer tabuas e pregos")
for _ = 1, 4 do player.inv:AddItem("Base.Plank") end
player.inv:AddItem("Base.Book")
local okT = IA.turnIn(talker, player)
check(okT and g2.materials == 4 and #player.inv.items >= 1, "entregou: o material vira trabalho nas janelas")
DR.choose(g2, 0)
check(g2.goal == "fortify" and IA.status(talker).key == "IGUI_Rem_Goal_fortify", "e eles passam a reforcar a casa")
DR.choose(g2, 3)
check(IA.status(talker).key:find("IGUI_Rem_Goal_"), "com zumbis na rua, falam disso")
members(g2)[2].z.hp = members(g2)[2].rec.maxHealth * 0.2
check(IA.status(talker).key == "IGUI_Rem_Talk_need_medical", "ferido no grupo: pedem remedio antes de tudo")
members(g2)[2].z.hp = members(g2)[2].rec.maxHealth

realPrint("186) Pedir ajuda: o vinculo vale alguma coisa")
player.inv.items = {}
box2.container.items = {}
box2.container:AddItem("Base.TinnedBeans"); box2.container:AddItem("Base.Bandage")
g2.home.stash = g2.home.stash or { { x = box2.x, y = box2.y, z = 0 } }
talker.rec.bond, talker.rec.askedHelpAt = 0, nil
talker.rec.pockets = {}
Rem.getStore().reputation[g2.id] = 10
local okA, la = IA.askHelp(talker, player)
check(not okA and la.key == "IGUI_Rem_Ask_no" and #player.inv.items == 0, "estranho pedindo: nao")
local hint = IA.hint("ask", talker)
check(hint.key == "IGUI_Rem_Hint_bond" and hint.args[2] == tostring(IA.CFG.ASK_BOND), "e a conversa explica o que falta")
talker.rec.bond = IA.CFG.ASK_BOND
okA, la = IA.askHelp(talker, player)
check(okA and la.key == "IGUI_Rem_Ask_yes" and #player.inv.items == 1 and player.inv.items[1]:getFullType() == "Base.TinnedBeans",
    "com vinculo: te da comida do estoque")
check(talker.rec.bond == IA.CFG.ASK_BOND - IA.CFG.ASK_COST, "pedir gasta um pouco da boa vontade")
okA, la = IA.askHelp(talker, player)
check(not okA and la.key == "IGUI_Rem_Ask_wait", "uma vez por dia")
talker.rec.askedHelpAt = nil
talker.rec.bond = IA.CFG.ASK_BOND
local bd = player.getBodyDamage
player.getBodyDamage = function() return { getOverallBodyHealth = function() return 40 end } end
okA = IA.askHelp(talker, player)
player.getBodyDamage = bd
check(okA and player.inv.items[2]:getFullType() == "Base.Bandage", "voce ferido: ele te da remedio")
talker.rec.askedHelpAt = nil
talker.rec.bond = IA.CFG.ASK_BOND
talker.rec.pockets = {}
okA, la = IA.askHelp(talker, player)
check(not okA and la.key == "IGUI_Rem_Ask_nothing", "sem nada no estoque: gostaria, mas nao tem")
local opts = {}
for _, id in ipairs(IA.dialogOptions(talker, player)) do opts[id] = true end
check(opts.ask, "a opcao aparece na conversa")

realPrint("187) A conversa mostra as consequencias e o motivo das recusas")
player.x, player.y = talker.z.x + 1, talker.z.y
talker.rec.bond, talker.rec.giftAt, talker.rec.mem = 0, nil, nil
Rem.getStore().reputation[g2.id] = 5
Rem.Reputation.apply(talker.rec)
local w = RemDialogWindow.open(talker, player)
local function click(id)
    local b = nil
    for _, x in ipairs(w.buttons) do if x.internal == id then b = x end end
    w.historyPanel.text = ""
    b.onclick(w, b)
    return w.historyPanel.text
end
local txt = click("shelter")
check(txt:find("IGUI_Rem_Hint_rep", 1, true), "abrigo recusado: mostra a reputacao que falta")
txt = click("info")
check(txt:find("IGUI_Rem_Hint_rep", 1, true), "informacao recusada: idem")
talker.rec.personality.lealdade = 1
talker.rec.askedJoinAt = nil
txt = click("join")
check(txt:find("IGUI_Rem_Hint_join", 1, true), "recrutamento recusado: mostra a disposicao e o que ajuda")
player.inv.items = {}
player.inv:AddItem("Base.TinnedBeans")
txt = click("gift")
check(txt:find("IGUI_Rem_Fx_bond", 1, true) and txt:find("IGUI_Rem_Fx_rep", 1, true), "presente: mostra o vinculo e a reputacao que subiram")
Rem.getStore().reputation[g2.id] = 80
w.history = {}
click("shelter")
local hinted = false
for _, e in ipairs(w.history) do if e.who == "sys" and e.text:find("IGUI_Rem_Hint_", 1, true) then hinted = true end end
check(IA.last.ok and not hinted, "quando da certo, nao aparece 'falta...'")
txt = click("status")
check(w.history[#w.history].who == "npc", "pergunta sem efeito nao mostra nada a mais")
w:close()

realPrint("188) Diario")
require "Remanescentes/Rem_JournalUI"
fresh()
local g3 = home("civis", 3)
scene()
check(not JN.knows(g3), "grupo desconhecido nao entra no diario")
Rem.changeRep(g3.id, 30, "teste")
check(JN.knows(g3), "depois de mexer na reputacao, voce conhece o grupo")
local m3 = members(g3)
T.halo = {}
m3[1].z:Kill(nil)
local last = JN.entries()[#JN.entries()]
check(last and last.key == "IGUI_Rem_Journal_member_died" and #T.halo >= 1, "morte num grupo conhecido: entra no diario e aparece na tela")
local ally = Rem.spawn(player.x + 1, player.y, 0, { faction = "aliados", mode = "stay" })
Rem.emit("playerDeed", "recruited", ally)
check(JN.entries()[#JN.entries()].key == "IGUI_Rem_Journal_recruited", "recrutar tambem")
g3.goal = "fortify"
Rem.getStore().quests[g3.id] = { kind = "materials", group = g3.id, count = 4, progress = 0, expiresAt = Rem.worldHours() + 10 }
local realGet = getText
getText = function(k, ...) return k .. " " .. table.concat({ ... }, " ") end   -- (mostra tambem os argumentos)
local text = JN.compose(player)
getText = realGet
check(text:find("IGUI_Rem_Journal_day", 1, true) and text:find(tostring(ally.rec.name), 1, true) and text:find(JN.groupName(g3), 1, true)
    and text:find("IGUI_Rem_GoalName_fortify", 1, true) and text:find("IGUI_Rem_Journal_quest_materials", 1, true)
    and text:find("IGUI_Rem_Journal_member_died", 1, true), "o diario junta: dia, aliados, grupos (com o que estao fazendo), pedidos e acontecimentos")
local jw = RemJournalWindow.open(player)
check(jw.shown and jw.panel.text == JN.compose(player), "janela do diario abre com o texto")
jw:close()
local found = false
for _, o in ipairs(Rem.playerOptions) do if o.labelKey == "ContextMenu_Rem_Journal" then found = true end end
check(found, "o diario esta no menu do clique direito, mesmo sem ninguem por perto")
for i = 1, JN.CFG.MAX + 5 do JN.add("IGUI_Rem_Journal_quest", "x") end
check(#JN.entries() == JN.CFG.MAX, "o diario guarda so os ultimos acontecimentos")
Rem.dismissAll()
check(JN.entries()[#JN.entries()].key ~= "IGUI_Rem_Journal_group_gone", "limpeza de teste nao vira noticia")

DR.CFG.INITIAL_MIN = 1
T.timeOfDay = 12
SandboxVars.Remanescentes.MaxActive = T.defaults().MaxActive
fresh()
