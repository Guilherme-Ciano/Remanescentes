-- A sua base (Rem_PlayerBase): definir, mandar aliados, tarefas, estoque, base viva longe de voce.
local T = ...
local Rem = Remanescentes
local check, tick = T.check, T.tick
local player, realPrint = T.player, T.print
local PB, IA, DR, JN = Rem.PlayerBase, Rem.Interact, Rem.Director, Rem.Journal

local function fresh()
    Rem.dismissAll(); T.clearZombies(); Rem.hunting = {}
    Rem.Mugging.enc = {}
    local s = Rem.getStore()
    s.reputation, s.quests, s.knownGroups, s.journal, s.siege = {}, {}, {}, {}, nil
    s.playerBase = nil
    player.inv.items = {}
    player.weapon, player.bag = nil, nil
end
local nextId = 50000
-- casa 12x8: 4 janelas ao norte, porta ao sul, geladeira, prateleira e uma caixa qualquer
local function house()
    nextId = nextId + 300
    local x, y = nextId, 50000
    local def = T.addBuilding(nextId + 1, x, y, 12, 8)
    for i = x, x + 11 do for j = y, y + 7 do T.indoorSq[i .. "," .. j] = true; T.sqBuilding[i .. "," .. j] = def end end
    local windows = {}
    for i = 0, 3 do table.insert(windows, T.addObject(x + 1 + i * 2, y, 0, "IsoWindow", { exterior = true })) end
    local door = T.addObject(x + 6, y + 7, 0, "IsoDoor", { exterior = true })
    local fridge = T.addObject(x + 2, y + 2, 0, "container", { type = "fridge" })
    local shelf = T.addObject(x + 3, y + 2, 0, "container", { type = "shelves" })
    local junk = T.addObject(x + 9, y + 5, 0, "container", { type = "sidetable" })
    return { def = def, x = x, y = y, windows = windows, door = door, fridge = fridge, shelf = shelf, junk = junk }
end
local function ally(x, y)
    local npc = Rem.spawn(x, y, 0, { faction = "aliados", mode = "follow" })
    npc.rec.recruited = true
    return npc
end
local function barricaded(list)
    local n = 0
    for _, w in ipairs(list) do if w:isBarricaded() then n = n + 1 end end
    return n
end
T.timeOfDay = 10
SandboxVars.Remanescentes.MaxActive = 20

realPrint("200) Definir a base")
fresh()
local hs = house()
player.x, player.y = hs.x + 20, hs.y + 3
local okSet = PB.canSetHere(player)
check(not okSet, "fora de um predio: nao da")
local g0, why = PB.setHere(player)
check(g0 == nil and why == "IGUI_Rem_Base_nobuilding", "e explica")
player.x, player.y = hs.x + 6, hs.y + 6
check(PB.canSetHere(player), "dentro de um predio: a opcao aparece")
local g, _, nStash, hasDoor = PB.setHere(player)
check(g and g.player and g.faction == "aliados" and PB.get() == g, "a base existe (um grupo seu)")
check(nStash == 3 and hasDoor and g.home.mainDoor.x == hs.x + 6, "estoque nos conteineres da casa, porta principal achada")
check(g.home.stash[1].type == "fridge", "geladeira primeiro no estoque")
check(#g.members == 0 and g.materials == 0, "comeca vazia, sem material")
check(not PB.canSetHere(player), "ja e a base: a opcao some")
check(barricaded(hs.windows) == 0 and hs.door.locked == false, "a casa NAO e 'preparada' como a dos NPCs (sem tabuas prontas, porta aberta para voce)")
local marked = false
for _, m in ipairs(Rem.getStore().mapMarks or {}) do if m.id == "playerbase:" .. g.home.bid then marked = true end end
check(marked, "marcada no seu mapa")
check(JN.entries()[#JN.entries()].key == "IGUI_Rem_Journal_base_set", "e no diario")
local labels = {}
for _, o in ipairs(Rem.playerOptions) do labels[o.labelKey] = o end
check(labels.ContextMenu_Rem_BaseSet and labels.ContextMenu_Rem_BaseSendAll, "opcoes no clique direito")
-- casa de outro grupo nao
local other = house()
local og = Rem.createGroup("civis", other.x + 6, other.y + 4, tostring(other.def:getID()), 2, other.def)
player.x, player.y = other.x + 6, other.y + 6
local g2, why2 = PB.setHere(player)
check(g2 == nil and why2 == "IGUI_Rem_Base_taken", "casa de outro grupo: nao")
-- mudar a base de lugar
local hs2 = house()
player.x, player.y = hs2.x + 6, hs2.y + 6
local g3 = PB.setHere(player)
check(g3 == g and g.home.bid == tostring(hs2.def:getID()), "definir em outro lugar muda a base (a mesma)")
player.x, player.y = hs.x + 6, hs.y + 6
PB.setHere(player)

realPrint("201) Mandar aliados para a base")
local a1 = ally(hs.x + 6, hs.y + 10)
local a2 = ally(hs.x + 7, hs.y + 10)
local a3 = ally(hs.x + 8, hs.y + 10)
local opts = {}
for _, id in ipairs(IA.dialogOptions(a1, player)) do opts[id] = true end
check(opts.order_base, "conversa com aliado: 'vai para a nossa base'")
local l = IA.choose("order_base", a1, player)
check(PB.isMember(a1.rec) and a1.rec.mode == "group" and a1.rec.job == "build" and l.key == "IGUI_Rem_Base_go_build", "foi: primeira tarefa e fortificar")
check(IA.followerCount() == 2, "deixa de contar no limite de quem anda com voce")
check(PB.sendAll() == 2 and a2.rec.job == "guard" and a3.rec.job == "scav", "'todos para a base': cada um pega o que falta (vigia, coleta)")
check(a2.rec.role == "guarda" and a3.rec.role == "morador", "vigia vira o guarda da porta")
opts = {}
for _, id in ipairs(IA.dialogOptions(a1, player)) do opts[id] = true end
check(opts.order_job_guard and opts.order_job_scav and opts.order_job_rest and not opts.order_job_build and opts.order_follow
    and not opts.order_base and not opts.shelter and not opts.quest and not opts.order_loot, "morador da base: tarefas, voltar com voce, sem pedir abrigo/missao")
-- limite
PB.CFG.MAX_MEMBERS = 3
local a4 = ally(hs.x + 9, hs.y + 10)
local okJ, lJ = PB.join(a4)
check(not okJ and lJ.key == "IGUI_Rem_Base_full", "base cheia: nao cabe mais")
IA.choose("order_base", a4, player)
check(IA.last.ok == false and IA.hint("order_base", a4).key == "IGUI_Rem_Hint_basefull", "a conversa explica")
PB.CFG.MAX_MEMBERS = 8
Rem.dismiss(a4)

realPrint("202) Moradores vivem na base")
for _, n in ipairs({ a1, a2, a3 }) do n.talkingUntil = nil end      -- (acabou a conversa)
a1.z.x, a1.z.y = hs.x + 6, hs.y + 30
a1.z.path = nil
tick(300, 2)
check(a1.z.path and math.abs(a1.z.path[2] - g.home.y) < 6, "vai ate a base")
-- tarefa: vigia fica na porta
a2.z.x, a2.z.y = hs.x + 1, hs.y + 1
a2.z.path, a2.banterUntil, a2.banterWith = nil, nil, nil
a2.nextPath, a2.lastPathX, a2.lastPathY = 0, nil, nil     -- (sem o "ja pedi esse caminho")
tick(300, 3)
local gs = Rem.Roles.guardSpot(g.home)
check(gs and a2.z.path and math.abs(a2.z.path[1] - (gs.x + 0.5)) < 1.1, "vigia vai para o lado da porta")
-- tarefa: fortificar so com material
DR.scanHome(g, Rem.nowMs(), true)
check(g.home.windowsTotal == 4 and g.home.windowsDone == 0, "(cenario) 4 janelas abertas")
check(DR.choose(g, 0) == "scavenge", "sem material: o objetivo e buscar")
hs.fridge.container:AddItem("Base.Plank"); hs.fridge.container:AddItem("Base.Plank")
hs.shelf.container:AddItem("Base.NailsBox")
PB.syncStash(g)
check(g.materials == 5 and #hs.fridge.container.items == 0 and #hs.shelf.container.items == 0, "tabuas e pregos que voce deixa no estoque viram material")
check(DR.choose(g, 0) == "fortify", "com material: fortificar")
local BB = Rem.BaseBuild
check(DR.worker(g) == nil and BB.builders(g) == 1, "na sua base as obras sao das pessoas com a tarefa 'fortificar' (Rem_BaseBuild)")
PB.setJob(a3, "build")
check(BB.builders(g) == 2, "dois fortificando")
PB.setJob(a3, "scav")

realPrint("203) Estoque: comida que voce traz e o que eles comem")
hs.fridge.container:AddItem("Base.TinnedBeans"); hs.fridge.container:AddItem("Base.TinnedSoup")
hs.shelf.container:AddItem("Base.Crackers"); hs.shelf.container:AddItem("Base.Hammer")
g.home.foodSync = nil
PB.syncStash(g)
check(g.supplies == 3 / Rem.World.CFG.ITEMS_PER_SUPPLY, "comida no estoque = suprimentos (" .. tostring(g.supplies) .. ")")
hs.fridge.container:AddItem("Base.CannedCorn")
PB.syncStash(g)
check(math.abs(g.supplies - 4 / Rem.World.CFG.ITEMS_PER_SUPPLY) < 0.001, "voce traz comida: os suprimentos sobem")
for _ = 1, 24 do PB.hourly() end
PB.syncStash(g)
local left = 0
for _, c in ipairs({ hs.fridge.container, hs.shelf.container }) do
    for _, it in ipairs(c.items) do if T.FOOD[it:getFullType()] then left = left + 1 end end
end
check(left < 4, "eles comem: a comida some do estoque (" .. left .. " de 4)")
local hammer = false
for _, it in ipairs(hs.shelf.container.items) do if it:getFullType() == "Base.Hammer" then hammer = true end end
check(hammer, "o que nao e comida (seu martelo) nunca e mexido")

realPrint("204) Busca de suprimentos com voce por perto")
-- um predio a umas 30 tiles da base
local tdef = T.addBuilding(nextId + 777, hs.x + 30, hs.y, 8, 6)
for i = hs.x + 30, hs.x + 37 do for j = hs.y, hs.y + 5 do T.indoorSq[i .. "," .. j] = true; T.sqBuilding[i .. "," .. j] = tdef end end
local target = { def = tdef, x = hs.x + 30, y = hs.y }
T.addObject(target.x + 4, target.y + 3, 0, "container", { type = "shelves" })
Rem.getStore().looted[tostring(target.def:getID())] = nil
a3.rec.lastTrip = nil
g.nearby = nil          -- (predios novos no teste: refaz a lista das redondezas)
a3.z.x, a3.z.y = g.home.x, g.home.y
player.x, player.y = g.home.x, g.home.y + 8
a3.z.said, a3.noPartnerAt = {}, nil
check(PB.scavBehavior(a3, { player = player }, Rem.nowMs()) == false and a3.rec.mode == "group" and T.saidPrefix(a3.z, "IGUI_Rem_Bark_trip_alone_"),
    "sozinho ninguem sai: 'Alguem vem comigo?'")
PB.setJob(a1, "rest")                 -- quem descansa pode acompanhar
a1.rec.lastTrip, a1.talkingUntil = nil, nil
local okT = PB.scavBehavior(a3, { player = player }, Rem.nowMs())
check(okT and a3.rec.mode == "scav" and a3.rec.lootTarget ~= nil, "de dia, em dupla, o coletor sai para um predio em volta")
check(a1.rec.mode == "escort" and a1.rec.escortOf == a3.rec.id, "o parceiro vai junto")
a1.z.x, a1.z.y = a3.z.x + 8, a3.z.y
a1.z.path, a1.nextPath, a1.lastPathX = nil, 0, nil
check(PB.escortBehavior(a1, { player = player }, Rem.nowMs()) and a1.z.path and math.abs(a1.z.path[1] - a3.z.x) < 1, "e fica perto de quem lidera")
check(a3.rec.lootTarget.bid ~= g.home.bid, "nunca a propria base")
local tb = a3.rec.lootTarget.bid
a3.rec.carry = { "Base.TinnedBeans", "Base.Bandage" }
a3.lootDoneBid = tb
a3.z.x, a3.z.y = g.home.x, g.home.y
local food0 = #hs.fridge.container.items + #hs.shelf.container.items
PB.scavBehavior(a3, { player = player }, Rem.nowMs())
check(a3.rec.mode == "group" and a3.rec.carry == nil and #hs.fridge.container.items + #hs.shelf.container.items == food0 + 2,
    "volta e guarda tudo no estoque da base")
check(a1.rec.mode == "group" and a1.rec.escortOf == nil, "o parceiro volta a rotina")
check(Rem.getStore().looted[tb] ~= nil, "o predio fica marcado como revirado")
local b2 = T.addBuilding(nextId + 778, hs.x + 45, hs.y, 8, 6)
g.nearby = nil
check(PB.scavBehavior(a3, { player = player }, Rem.nowMs()) == false and a3.rec.mode == "group", "descansa antes da proxima busca")
T.timeOfDay = 22
a3.rec.lastTrip = nil
check(PB.scavBehavior(a3, { player = player }, Rem.nowMs()) == false, "de noite nao sai")
T.timeOfDay = 10
g.goal = "hide"
check(PB.scavBehavior(a3, { player = player }, Rem.nowMs()) == false, "com horda em volta da casa nao sai")
g.goal = nil
PB.setJob(a3, "rest")
check(PB.scavBehavior(a3, { player = player }, Rem.nowMs()) == false, "quem nao e coletor nao sai")
PB.setJob(a3, "scav")
a3.rec.lastTrip, a1.rec.lastTrip = nil, nil
check(PB.scavBehavior(a3, { player = player }, Rem.nowMs()) and a3.rec.lootTarget.bid == tostring(b2:getID()), "depois sai de novo, para outro predio (nunca um ja revirado)")
PB.endTrip(a3, false)
a3.rec.lastTrip, a1.rec.lastTrip = nil, nil
check(PB.scavBehavior(a3, { player = player }, Rem.nowMs()) == false and a3.rec.mode == "group", "tudo em volta revirado: nao sai mais")
-- a conta generica de estoque dos NPCs nunca mexe nas suas coisas
g.supplies = 0
g.home.foodSync = nil
for _ = 1, 4 do hs.shelf.container:AddItem("Base.Hammer") end
local before3 = #hs.shelf.container.items
Rem.Scavenge.syncNear(player, Rem.nowMs() + 999999)
local hammer2 = false
for _, it in ipairs(hs.shelf.container.items) do if it:getFullType() == "Base.Hammer" then hammer2 = true end end
check(hammer2 and #hs.shelf.container.items == before3, "o estoque da base nao passa pela conta dos grupos de NPC")
-- a simulacao dos grupos de NPC nao manda a sua base sair para saquear
g.supplies = 0
T.addBuilding(nextId + 779, hs.x + 60, hs.y + 10, 8, 6)       -- um predio ainda nao revirado por perto
local rr = ZombRand
ZombRand = function(a, b) if not b and a == 3 then return 0 end return rr(a, b) end   -- (a sorte que faria um grupo de NPC sair)
Rem.simulateWorld(1)
ZombRand = rr
check(g.activity == "home", "a sua base nao sai inteira para saquear como os grupos de NPC")
-- itens trazidos de longe nao contam duas vezes
PB.syncStash(g)
local sup0 = g.supplies
g.pendingList = { "Base.TinnedBeans", "Base.TinnedBeans" }
g.supplies = sup0 + 2 / Rem.World.CFG.ITEMS_PER_SUPPLY      -- (somado quando ele voltou)
PB.syncStash(g)
check(math.abs(g.supplies - (sup0 + 2 / Rem.World.CFG.ITEMS_PER_SUPPLY)) < 0.001, "comida que chegou da busca nao e contada duas vezes")

PB.setJob(a1, "build")
realPrint("205) A base continua viva longe de voce")
local a4 = ally(hs.x + 6, hs.y + 12)
PB.join(a4)
PB.setJob(a4, "scav")                  -- par do coletor
BB.scan(g)
for _, npc in ipairs({ a1, a2, a3, a4 }) do Rem.dematerialize(npc) end
player.x, player.y = g.home.x + 800, g.home.y
for k = 1, 3 do
    local d = T.addBuilding(nextId + 800 + k, hs.x + 20 + k * 12, hs.y + 20, 8, 6)
end
g.nearby = nil
g.materials = 10
g.supplies = 10
g.home.buildToday, g.home.buildDay = 0, nil
JN.entries()
Rem.getStore().journal = {}
a3.rec.lastTrip = nil
local pending0 = #(g.pendingList or {})
local realRand = ZombRand
ZombRand = function(a, b) if a == 100 and not b then return 50 end return realRand(a, b) end   -- sem morte nem ferimento
Rem.emit("worldHour", Rem.worldHours())
ZombRand = realRand
check(#(g.pendingList or {}) > pending0, "o coletor sai e traz coisas (aparecem quando a casa carregar)")
local scavNews = false
for _, e in ipairs(JN.entries()) do if e.key == "IGUI_Rem_Journal_base_trip_scav" then scavNews = true end end
check(scavNews and a4.rec.lastTrip ~= nil, "em dupla, e vai para o diario")
local perHour = math.ceil(BB.CFG.STEPS_PER_DAY / 12)
check(g.home.pendingBuild and g.home.pendingBuild.windows == perHour, "quem fortifica continua trabalhando (" .. perHour .. " passo por hora)")
for _ = 1, 20 do Rem.emit("worldHour", Rem.worldHours()) end
local total = 0
for _, n in pairs(g.home.pendingBuild) do total = total + n end
check(total == BB.perDay(g), "ate o limite do dia (" .. BB.CFG.STEPS_PER_DAY .. " passos por pessoa fortificando)")
T.timeOfDay = 23
a3.rec.lastTrip = nil
local pn = #(g.pendingList or {})
PB.hourly()
check(#(g.pendingList or {}) == pn and a3.rec.lastTrip == nil, "de noite ninguem sai para buscar")
T.timeOfDay = 10
-- voce volta: tabuas e itens aparecem de verdade
player.x, player.y = g.home.x, g.home.y + 12
T.clock = T.clock + 10000
Rem.emit("sceneUpdate", player, Rem.nowMs())
T.clock = T.clock + DR.CFG.TICK_MS + 1
Rem.emit("sceneUpdate", player, Rem.nowMs())
check(barricaded(hs.windows) == 4, "voltando: as janelas estao com tabuas (" .. barricaded(hs.windows) .. ")")
check(g.pendingList == nil and #hs.fridge.container.items + #hs.shelf.container.items > food0, "e o que o coletor trouxe esta no estoque")

realPrint("206) Riscos: fome, mortes, ataques")
fresh()
local hb = house()
player.x, player.y = hb.x + 6, hb.y + 6
local base = PB.setHere(player)
local m1, m2 = ally(hb.x + 5, hb.y + 4), ally(hb.x + 6, hb.y + 4)
PB.join(m1); PB.join(m2)
Rem.dematerialize(m1); Rem.dematerialize(m2)
player.x, player.y = hb.x + 900, hb.y
base.supplies = 0
for _ = 1, PB.CFG.HUNGER_WARN do PB.hourly() end
check(JN.entries()[#JN.entries()].key == "IGUI_Rem_Journal_base_hungry", "um dia sem comida: aviso no diario")
for _ = PB.CFG.HUNGER_WARN + 1, PB.CFG.HUNGER_LEAVE do PB.hourly() end
check(#base.members == 1 and JN.entries()[#JN.entries()].key == "IGUI_Rem_Journal_base_left", "tres dias sem comida: alguem vai embora")
-- morte na busca
base.supplies = 10
local scav = Rem.getPerson(base.members[1])
scav.job, scav.lastTrip = "scav", nil
T.addBuilding(nextId + 950, hb.x + 30, hb.y + 20, 8, 6)
base.nearby = nil
SandboxVars.Remanescentes.ScavengeDeathChance = 8
ZombRand = function(a, b) if a == 100 and not b then return 0 end return realRand(a, b) end    -- o pior sorteio
local res = PB.tripOffscene(base, scav, nil, "scav")
ZombRand = realRand
SandboxVars.Remanescentes.ScavengeDeathChance = T.defaults().ScavengeDeathChance
check(res == "dead" and #base.members == 0 and Rem.getPerson(scav.id) == nil and JN.entries()[#JN.entries()].key == "IGUI_Rem_Journal_base_scav_died",
    "busca pode dar errado: ele nao volta")
-- ataque de saqueadores: vigias e janelas ajudam
base.home.windowsTotal, base.home.windowsDone = 4, 4
local g1 = ally(hb.x + 900, hb.y + 3); PB.join(g1); PB.setJob(g1, "guard")
check(math.abs(PB.defenseBonus(base) - (PB.CFG.GUARD_DEFENSE + PB.CFG.WINDOW_DEFENSE)) < 0.001, "defesa extra: vigias e janelas fechadas")
Rem.emit("raidResolved", { id = "x" }, base, base)
check(JN.entries()[#JN.entries()].key == "IGUI_Rem_Journal_base_raid_won", "ataque a base vai para o diario")
check(Rem.World and true, "")

realPrint("207) Voltar a andar com voce; liberar")
fresh()
local hc = house()
player.x, player.y = hc.x + 6, hc.y + 6
local bc = PB.setHere(player)
local r1 = ally(hc.x + 5, hc.y + 4)
PB.join(r1)
l = IA.choose("order_follow", r1, player)
check(not PB.isMember(r1.rec) and r1.rec.mode == "follow" and r1.rec.groupId == nil and r1.rec.job == nil and #bc.members == 0,
    "'vem comigo': sai da base e volta a te seguir")
PB.join(r1)
for i = 1, IA.CFG.MAX_FOLLOWERS do ally(hc.x + i, hc.y + 12) end
l = IA.choose("order_follow", r1, player)
check(PB.isMember(r1.rec) and l.key == "IGUI_Rem_Join_full", "ja com aliados demais: fica na base")
IA.choose("order_release", r1, player)
check(not PB.isMember(r1.rec) and r1.rec.faction ~= "aliados" and #bc.members == 0, "liberar: vai embora e sai da lista da base")
local r2 = ally(hc.x + 5, hc.y + 5)
PB.join(r2)
r2.z:Kill(nil)
check(#bc.members == 0, "morreu: sai da lista")

realPrint("208) Diario mostra a base")
require "Remanescentes/Rem_JournalUI"
local realGet = getText
getText = function(k, ...) return k .. " " .. table.concat({ ... }, " ") end
local r3 = ally(hc.x + 5, hc.y + 5)
PB.join(r3)
local text = JN.compose(player)
getText = realGet
check(text:find("IGUI_Rem_Journal_base_status", 1, true) and text:find(tostring(r3.rec.name), 1, true) and text:find("IGUI_Rem_Job_build", 1, true),
    "o diario mostra a base: moradores, tarefa, comida, material, janelas")
check(not text:find("IGUI_Rem_Journal_nobase", 1, true), "(com base)")

T.timeOfDay = 12
SandboxVars.Remanescentes.MaxActive = T.defaults().MaxActive
fresh()
