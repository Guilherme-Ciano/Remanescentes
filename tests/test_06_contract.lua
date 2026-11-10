-- Contrato de extensao: eventos, comportamentos, faccoes, opcoes de menu e CFG publicas.
-- Roda depois dos test_0N anteriores (precisa do menu carregado pelo test_03_menu).
local T = ...
local Rem = Remanescentes
local check, tick, fire, newZombie = T.check, T.tick, T.fire, T.newZombie
local clearZombies, addBuilding = T.clearZombies, T.addBuilding
local player = T.player
local realPrint = T.print

local function reset()
    Rem.dismissAll(); clearZombies(); Rem.hunting = {}
end

-- grava (nome, args) de cada evento emitido enquanto estiver ligado
local seen = {}
local recorders = {}
local EVENTS = { "npcActivated", "npcDeactivated", "npcDied", "personCreated", "personRemoved",
    "groupCreated", "groupRemoved", "worldHour", "sceneUpdate", "worldSeeded" }
for _, name in ipairs(EVENTS) do
    recorders[name] = function(...) table.insert(seen, { name = name, args = { ... } }) end
    Rem.on(name, recorders[name])
end
local function lastOf(name)
    for i = #seen, 1, -1 do if seen[i].name == name then return seen[i] end end
end
local function countOf(name)
    local n = 0
    for _, e in ipairs(seen) do if e.name == name then n = n + 1 end end
    return n
end

realPrint("22) Barramento de eventos: on/off/emit")
do
    local calls = {}
    local function a(x) table.insert(calls, "a" .. tostring(x)) end
    local function bad() error("falha proposital") end
    local function c(x) table.insert(calls, "c" .. tostring(x)) end
    Rem.on("teste", a); Rem.on("teste", bad); Rem.on("teste", c)
    Rem.on("teste", a) -- repetido nao duplica
    local nLogs = #T.logs
    Rem.emit("teste", 1)
    check(#calls == 2 and calls[1] == "a1" and calls[2] == "c1", "emit chama todos, em ordem, sem duplicar")
    local logged = false
    for i = nLogs + 1, #T.logs do if tostring(T.logs[i]):find("falha proposital", 1, true) then logged = true end end
    check(logged, "erro num handler e logado e nao impede os outros")
    Rem.off("teste", a)
    calls = {}
    Rem.emit("teste", 2)
    check(#calls == 1 and calls[1] == "c2", "off remove o handler")
    Rem.off("teste", bad); Rem.off("teste", c)
    check(pcall(Rem.emit, "evento_sem_ninguem", 1), "emit sem handlers nao da erro")
end

realPrint("23) Eventos de pessoas e corpos")
reset()
player.x, player.y = 700, 700
seen = {}
local npc = Rem.spawn(701, 701, 0, { faction = "aliados", mode = "stay", personality = "teimoso" })
local pc = lastOf("personCreated")
check(pc and pc.args[1] == npc.rec and pc.args[2] and pc.args[2].personality == "teimoso",
    "personCreated(rec, opts) com a opts recebida")
local act = lastOf("npcActivated")
check(act and act.args[1] == npc and Rem.active[npc.z] == npc, "npcActivated(npc) ao fim de activate")
local stillThere, wasActive = nil, nil
local function onDied(n)
    stillThere = Rem.getPerson(n.rec.id) ~= nil
    wasActive = Rem.active[n.z] == n
end
Rem.on("npcDied", onDied)
local id = npc.rec.id
Rem.damageNPC(npc, 999)
Rem.off("npcDied", onDied)
local died = lastOf("npcDied")
check(died and died.args[1] == npc, "npcDied(npc) na morte de um sobrevivente")
check(stillThere == true and wasActive == true, "npcDied vem antes de remover a pessoa (ainda ativo)")
check(lastOf("npcDeactivated") and lastOf("npcDeactivated").args[1] == npc, "npcDeactivated(npc)")
local rem = lastOf("personRemoved")
check(rem and rem.args[1].id == id and Rem.getPerson(id) == nil, "personRemoved(rec) ao remover a pessoa")
seen = {}
local zombie = newZombie(5, 5, 0)
zombie:Kill(nil)
check(countOf("npcDied") == 0, "zumbi comum morrendo nao emite npcDied")

realPrint("24) Eventos do mundo: grupos, hora simulada, cena, semeadura")
reset()
seen = {}
local fakeDef = { getX = function() return 3000 end, getY = function() return 3000 end,
    getW = function() return 10 end, getH = function() return 10 end }
local membersAtEmit = nil
local function onGroup(g) membersAtEmit = #g.members end
Rem.on("groupCreated", onGroup)
local g = Rem.createGroup("civis", 3005, 3005, "g3000", 2, fakeDef)
Rem.off("groupCreated", onGroup)
local gc = lastOf("groupCreated")
check(gc and gc.args[1] == g and gc.args[2] == fakeDef, "groupCreated(g, def)")
check(membersAtEmit == 2, "groupCreated emitido com g.members ja preenchido")
local g2 = Rem.createGroup("civis", 3100, 3100, nil, 1)
check(lastOf("groupCreated").args[1] == g2 and lastOf("groupCreated").args[2] == nil, "groupCreated com def nil")
check(countOf("personCreated") == 3, "personCreated para cada membro")
for _, pid in ipairs(g2.members) do Rem.removePerson(pid) end
seen = {}
T.worldHours = T.worldHours + 1
Rem.simulateWorld(2)
check(countOf("worldHour") == 2 and lastOf("worldHour").args[1] == T.worldHours, "worldHour(hour) a cada hora simulada")
check(lastOf("groupRemoved") and lastOf("groupRemoved").args[1] == g2 and Rem.getStore().groups[g2.id] == nil,
    "groupRemoved(g) quando o grupo acaba")
seen = {}
player.x, player.y = 1000, 1000
addBuilding(50, 1150, 1000, 10, 10)
SandboxVars.Remanescentes.WorldGroups = 1
Rem.getStore().seeded = false
tick(1600)
SandboxVars.Remanescentes.WorldGroups = 0
check(lastOf("worldSeeded") and lastOf("worldSeeded").args[1] == player, "worldSeeded(player) ao semear")
local su = lastOf("sceneUpdate")
check(su and su.args[1] == player and su.args[2] == T.clock, "sceneUpdate(player, now) ao fim de updateScene")
local nSeeded = countOf("worldSeeded")
tick(1600)
check(countOf("worldSeeded") == nSeeded, "worldSeeded so quando semeia de verdade")

realPrint("25) registerBehavior: prioridade intermediaria entra entre os padrao")
reset()
local names, prios = {}, {}
for _, b in ipairs(Rem.getBehaviors()) do table.insert(names, b.name); prios[b.name] = b.priority end
check(prios.follow == 100 and prios.stay == 200 and prios.group == 300 and prios.wander == 900,
    "padrao registrados: follow 100, stay 200, group 300, wander 900")
player.x, player.y = 800, 800
local walker = Rem.spawn(800, 801, 0, { faction = "aliados", mode = "wander" })
local stayer = Rem.spawn(803, 801, 0, { faction = "aliados", mode = "stay" })
walker.z.x, walker.z.y = 815, 801   -- longe de casa: o wander mandaria voltar
stayer.z.x, stayer.z.y = 818, 801   -- longe do lugar: o stay mandaria voltar
local held = {}
local lastCtx = nil
Rem.registerBehavior({ name = "teste_segurar", priority = 250, run = function(n, ctx, now)
    held[n] = (held[n] or 0) + 1
    lastCtx = ctx
    return true
end })
local order = {}
-- (filtra os comportamentos padrao + o do teste; outros modulos do mod registram os seus)
local mine = { follow = true, stay = true, teste_segurar = true, group = true, wander = true }
for _, b in ipairs(Rem.getBehaviors()) do if mine[b.name] then table.insert(order, b.name) end end
check(table.concat(order, ",") == "follow,stay,teste_segurar,group,wander", "ordem por prioridade: " .. table.concat(order, ","))
walker.z.path = nil; stayer.z.path = nil
tick(300)
check(held[walker] ~= nil and walker.z.path == nil, "comportamento 250 trata o tick antes do wander (900)")
check(held[stayer] == nil and stayer.z.path ~= nil, "stay (200) continua antes do comportamento 250")
check(lastCtx and lastCtx.temper == "defensivo" and lastCtx.player == player and lastCtx.enemy == nil,
    "ctx tem enemy, dist, temper e player")
-- re-registrar o mesmo name substitui
local replaced = false
Rem.registerBehavior({ name = "teste_segurar", priority = 250, run = function() replaced = true return false end })
local n250 = 0
for _, b in ipairs(Rem.getBehaviors()) do if b.name == "teste_segurar" then n250 = n250 + 1 end end
check(n250 == 1, "re-registrar o mesmo name substitui (sem duplicar)")
tick(300)
check(replaced and walker.z.path ~= nil, "retornando false, o proximo comportamento (wander) age")
-- erro num comportamento nao trava o sobrevivente
Rem.registerBehavior({ name = "teste_segurar", priority = 250, run = function() error("quebrado") end })
walker.z.path = nil; walker.z.x, walker.z.y = 815, 801; walker.nextPath = 0; walker.lastPathX = nil
tick(300)
check(walker.z.path ~= nil, "comportamento com erro e pulado")
Rem.unregisterBehavior("teste_segurar")
check(Rem.getBehavior("teste_segurar") == nil, "unregisterBehavior remove")

realPrint("26) Utilitarios de movimento publicos")
check(type(Rem.hangAround) == "function" and type(Rem.idle) == "function" and type(Rem.flee) == "function"
    and type(Rem.groupGoal) == "function" and type(Rem.travelGait) == "function" and type(Rem.baseGait) == "function",
    "Rem.hangAround/idle/flee/groupGoal/travelGait/baseGait existem")
check(Rem.travelGait(walker, 20) == "run" and Rem.travelGait(walker, 3) == "walk" and Rem.baseGait(walker) == "walk",
    "travelGait/baseGait como antes")
local gg = Rem.createGroup("civis", 850, 850, nil, 1)
walker.rec.groupId = gg.id
local gx, gy, _, why = Rem.groupGoal(walker)
check(gx == 850 and gy == 850 and why == "home", "groupGoal le o destino do grupo")
walker.rec.groupId = nil

realPrint("27) registerFaction")
local def = Rem.registerFaction("mercenarios", {
    hostileToPlayer = true, enemies = { civis = true }, temper = "cauteloso",
    outfits = { "Police" }, groupNames = { "Mercenarios" },
})
check(Rem.factionDef("mercenarios") == def and Rem.FACTIONS.mercenarios == def, "faccao registrada")
check(Rem.factionsHostile("mercenarios", "civis") and Rem.factionsHostile("civis", "mercenarios")
    and not Rem.factionsHostile("mercenarios", "aliados"), "hostilidade simetrica")
local merc = Rem.spawn(805, 805, 0, { faction = "mercenarios" })
check(merc and merc.rec.outfit == "Police" and Rem.temperOf(merc) == "cauteloso" and Rem.isHostileToPlayer(merc),
    "pessoa da faccao nova usa roupa, temperamento e hostilidade dela " .. tostring(merc and merc.rec.outfit) .. "/" .. tostring(merc and Rem.temperOf(merc)) .. "/" .. tostring(merc and Rem.isHostileToPlayer(merc)) .. "/" .. tostring(merc and merc.rec.attitude))
local mg = Rem.createGroup("mercenarios", 4000, 4000, nil, 1)
check(mg.name == "Mercenarios", "grupo da faccao nova usa groupNames")
check(Rem.FACTIONS.aliados.temper == "defensivo" and Rem.FACTIONS.civis.temper == "medroso"
    and Rem.FACTIONS.sobreviventes.temper == "cauteloso" and Rem.FACTIONS.saqueadores.temper == "agressivo",
    "as 4 faccoes padrao continuam iguais")
local minimal = Rem.registerFaction("eremitas", { temper = "medroso" })
check(minimal.enemies and minimal.outfits and minimal.hostileToPlayer == false, "campos ausentes recebem padrao")

realPrint("28) registerDebugOption / registerNpcOption no menu")
reset()
local clicked = nil
Rem.registerDebugOption("ContextMenu_Teste_Debug", function(x, y, z, p) clicked = { x, y, z, p } end)
local npcClicked = nil
Rem.registerNpcOption("ContextMenu_Teste_Npc", function(n) npcClicked = n end)
Rem.registerNpcOption("ContextMenu_Teste_Hostil", function() end, function(n) return Rem.isHostileToPlayer(n) end)
player.x, player.y = 900, 900
local friend = Rem.spawn(910, 910, 0, { faction = "aliados", mode = "stay" })
local ok, err, ctx = T.openMenu(910, 910)
check(ok, "menu com opcoes registradas abre sem erro " .. tostring(err or ""))
local root = T.findOpt(ctx, "ContextMenu_Rem_Title")
local dbg = T.findOpt(root.sub, "ContextMenu_Rem_Debug").sub
local last = dbg.options[#dbg.options]
check(last.name == "ContextMenu_Teste_Debug" and dbg.options[1].name == "ContextMenu_Rem_SpawnAlly",
    "opcao de debug registrada aparece depois das padrao")
last.fn(last.target, unpack(last.args))
check(clicked and clicked[1] == 910.5 and clicked[2] == 910.5 and clicked[3] == 0 and clicked[4] == player,
    "clique chama fn(x, y, z, player)")
local npcMenu = nil
for _, o in ipairs(root.sub.options) do if o.sub and T.findOpt(o.sub, "ContextMenu_Rem_Info") then npcMenu = o.sub end end
local labels = {}
local knownNpc = { ContextMenu_Rem_Follow = true, ContextMenu_Rem_Stay = true, ContextMenu_Rem_Stealth = true,
    ContextMenu_Rem_Normal = true, ContextMenu_Rem_Info = true, ContextMenu_Rem_Dismiss = true, ContextMenu_Teste_Npc = true }
for _, o in ipairs(npcMenu.options) do if knownNpc[o.name] then table.insert(labels, o.name) end end
check(table.concat(labels, ",") == "ContextMenu_Rem_Follow,ContextMenu_Rem_Stay,ContextMenu_Rem_Stealth,ContextMenu_Rem_Info,ContextMenu_Rem_Dismiss,ContextMenu_Teste_Npc",
    "submenu do aliado: padrao na ordem original + a registrada (" .. table.concat(labels, ",") .. ")")
local opt = T.findOpt(npcMenu, "ContextMenu_Teste_Npc")
opt.fn(opt.target, unpack(opt.args))
check(npcClicked == friend, "clique chama fn(npc)")
-- comandos padrao continuam funcionando pelo registro
local follow = T.findOpt(npcMenu, "ContextMenu_Rem_Follow")
follow.fn(follow.target, unpack(follow.args))
check(friend.rec.mode == "follow", "ordem Seguir funciona")
local stealth = T.findOpt(npcMenu, "ContextMenu_Rem_Stealth")
stealth.fn(stealth.target, unpack(stealth.args))
check(friend.rec.stealth == true and friend.z.vars.RemSneak == true, "ordem Furtivo funciona")
local _, _, ctx2 = T.openMenu(910, 910)
local root2 = T.findOpt(ctx2, "ContextMenu_Rem_Title")
local m2
for _, o in ipairs(root2.sub.options) do if o.sub and T.findOpt(o.sub, "ContextMenu_Rem_Info") then m2 = o.sub end end
check(T.findOpt(m2, "ContextMenu_Rem_Normal") and not T.findOpt(m2, "ContextMenu_Rem_Stealth"), "furtivo: mostra Normal no lugar de Furtivo")
-- hostil: sem ordens, condicao da opcao registrada respeitada
local thug = Rem.spawn(920, 920, 0, { faction = "saqueadores", mode = "stay" })
local _, _, ctx3 = T.openMenu(920, 920)
local root3 = T.findOpt(ctx3, "ContextMenu_Rem_Title")
local m3
for _, o in ipairs(root3.sub.options) do if o.sub and T.findOpt(o.sub, "ContextMenu_Rem_Info") then m3 = o.sub end end
check(m3 and not T.findOpt(m3, "ContextMenu_Rem_Follow") and T.findOpt(m3, "ContextMenu_Teste_Hostil"),
    "hostil: sem ordens; condition(npc) decide se a opcao aparece")
SandboxVars.Remanescentes.DebugMenu = false
local _, _, ctx4 = T.openMenu(920, 920)
local root4 = T.findOpt(ctx4, "ContextMenu_Rem_Title")
local m4
for _, o in ipairs(root4.sub.options) do if o.sub then m4 = o.sub end end
check(not T.findOpt(root4.sub, "ContextMenu_Rem_Debug") and not T.findOpt(m4, "ContextMenu_Rem_Dismiss"),
    "sem DebugMenu: sem ferramentas de teste e sem Dispensar")
SandboxVars.Remanescentes.DebugMenu = true
Rem.unregisterDebugOption("ContextMenu_Teste_Debug")
Rem.unregisterNpcOption("ContextMenu_Teste_Npc")
Rem.unregisterNpcOption("ContextMenu_Teste_Hostil")

realPrint("29) Constantes publicas (CFG) com os valores de antes, lidas no uso")
check(Rem.Brain.CFG.THINK_MS == 250 and Rem.Brain.CFG.FOLLOW_DIST == 3 and Rem.Brain.CFG.REPATH_MS == 1000
    and Rem.Brain.CFG.OUTNUMBERED.cauteloso == 4, "Rem.Brain.CFG")
check(Rem.World.CFG.TRAVEL_PER_HOUR == 300 and Rem.Scene.CFG.SPAWN_RADIUS == 45 and Rem.Scene.CFG.DESPAWN_RADIUS == 70,
    "Rem.World.CFG / Rem.Scene.CFG")
check(Rem.Perception.CFG.PERCEIVE_MS == 500 and Rem.Combat.CFG.ATTACK_COOLDOWN_MS == 1100 and Rem.Barks.CFG.GLOBAL_CD == 6000,
    "Rem.Perception.CFG / Rem.Combat.CFG / Rem.Barks.CFG")
local old = Rem.Combat.CFG.ATTACK_COOLDOWN_MS
Rem.Combat.CFG.ATTACK_COOLDOWN_MS = 5000
Rem.startAttack(friend, thug.z, T.clock)
check(friend.nextAttack == T.clock + 5000, "ajuste em CFG tem efeito sem recarregar")
Rem.Combat.CFG.ATTACK_COOLDOWN_MS = old
local m = Rem.module("Brain", { THINK_MS = 1, NOVA_CHAVE = 7 })
check(m == Rem.Brain and m.CFG.THINK_MS == 250 and m.CFG.NOVA_CHAVE == 7, "Rem.module nao sobrescreve valores existentes")
m.CFG.NOVA_CHAVE = nil

for _, name in ipairs(EVENTS) do Rem.off(name, recorders[name]) end
reset()
