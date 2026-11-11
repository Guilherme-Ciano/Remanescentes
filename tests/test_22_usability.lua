-- Usabilidade (0.12): portas, saque do seguidor, bolsos e troca, panico do jogador,
-- companheiros que alcancam voce, ordens.
local T = ...
local Rem = Remanescentes
local check, tick = T.check, T.tick
local player, realPrint = T.player, T.print
require "Remanescentes/Rem_Calm"
local IA, DO, CP, CM, SC = Rem.Interact, Rem.Doors, Rem.Companion, Rem.Calm, Rem.Scavenge

local function fresh()
    Rem.dismissAll(); T.clearZombies(); Rem.hunting = {}
    Rem.Mugging.enc = {}
    local s = Rem.getStore()
    s.reputation, s.quests, s.knownGroups = {}, {}, {}
    player.inv.items = {}
    player.weapon, player.bag = nil, nil
    DO.opened = {}
end
local function house(id, x, y, w, h)
    local def = T.addBuilding(id, x, y, w, h)
    for i = x, x + w - 1 do for j = y, y + h - 1 do T.indoorSq[i .. "," .. j] = true; T.sqBuilding[i .. "," .. j] = def end end
    return def
end
local function ally(x, y, extra)
    local opts = { faction = "aliados", mode = "follow" }
    for k, v in pairs(extra or {}) do opts[k] = v end
    local npc = Rem.spawn(x, y, 0, opts)
    npc.rec.recruited = true
    return npc
end

realPrint("190) Portas: quem trava numa porta fechada abre e passa")
fresh()
player.x, player.y = 43000, 43010
house(43001, 43000, 43000, 8, 6)
local door = T.addObject(43003, 43005, 0, "IsoDoor", { exterior = true })
local walker = ally(43003.5, 43006.5, { mode = "stay" })
Rem.moveTo(walker, 43003.5, 43002.5, 0, Rem.nowMs(), "walk")
DO.tick(Rem.nowMs())                       -- primeira amostra
check(not door:IsOpen(), "(cenario) porta fechada no caminho")
T.clock = T.clock + DO.CFG.TICK_MS
Rem.moveTo(walker, 43003.5, 43002.5, 0, Rem.nowMs(), "walk")
DO.tick(Rem.nowMs())
check(door:IsOpen(), "quer andar, nao sai do lugar, tem porta fechada na frente: abre")
check(walker.nextPath == 0, "e recalcula o caminho na hora")
check(#DO.opened == 1, "porta externa: lembra de fechar depois")
walker.z.x, walker.z.y = 43003.5, 43001.5
T.clock = T.clock + DO.CFG.CLOSE_AFTER_MS + 100
DO.closeBehind(Rem.nowMs())
check(not door:IsOpen() and #DO.opened == 0, "passou: fecha a porta atras de si")
-- parado de proposito nao abre porta
door.open = false
walker.wantAt = nil
walker.z.x, walker.z.y = 43003.5, 43006.5
DO.tick(Rem.nowMs()); T.clock = T.clock + DO.CFG.TICK_MS; DO.tick(Rem.nowMs())
check(not door:IsOpen(), "quem esta parado porque quer nao sai abrindo porta")
-- trancada: so por dentro
door.locked = true
Rem.moveTo(walker, 43003.5, 43002.5, 0, Rem.nowMs(), "walk")
check(DO.openNear(walker, Rem.nowMs()) == nil and not door:IsOpen(), "porta trancada nao abre por fora")
walker.z.x, walker.z.y = 43003.5, 43004.5
Rem.moveTo(walker, 43003.5, 43008.5, 0, Rem.nowMs(), "walk")
check(DO.openNear(walker, Rem.nowMs()) == door and door:IsOpen() and not door.locked, "por dentro, destranca e abre")
-- barricada: nunca
door.open, door.barricade = false, {}
check(DO.openNear(walker, Rem.nowMs()) == nil, "porta com tabuas nao abre")
door.barricade = nil
-- porta atras dele nao interessa
door.open = false
walker.z.x, walker.z.y = 43003.5, 43003.9
Rem.moveTo(walker, 43003.5, 42990.5, 0, Rem.nowMs(), "walk")
check(DO.openNear(walker, Rem.nowMs()) == nil, "porta para o lado contrario do destino fica como esta")
-- sem porta: um passo para o lado
fresh()
player.x, player.y = 43100, 43010
local stuck = ally(43100.5, 43000.5, { mode = "stay" })
Rem.moveTo(stuck, 43100.5, 43020.5, 0, Rem.nowMs(), "walk")
DO.tick(Rem.nowMs())
local t0 = Rem.nowMs()
while Rem.nowMs() - t0 < DO.CFG.UNSTICK_MS + DO.CFG.TICK_MS * 2 do
    T.clock = T.clock + DO.CFG.TICK_MS
    stuck.wantAt = Rem.nowMs()
    DO.tick(Rem.nowMs())
end
check(stuck.detour ~= nil, "travado sem porta por alguns segundos: da um passo para o lado")
local det = stuck.detour
stuck.z.path = nil
stuck.nextPath = 0
Rem.moveTo(stuck, 43100.5, 43020.5, 0, Rem.nowMs(), "walk")
check(stuck.z.path and math.abs(stuck.z.path[1] - det.x) < 0.01 and math.abs(stuck.z.path[2] - det.y) < 0.01, "o proximo passo vai para o desvio")
T.clock = T.clock + DO.CFG.DETOUR_MS + 10
stuck.nextPath = 0
Rem.moveTo(stuck, 43100.5, 43020.5, 0, Rem.nowMs(), "walk")
check(stuck.detour == nil and math.abs(stuck.z.path[2] - 43020.5) < 0.01, "e depois volta ao destino de verdade")

realPrint("191) Chegar perto de um armario: quadrado livre ao lado")
fresh()
house(43201, 43200, 43000, 8, 6)
T.addObject(43202, 43002, 0, "container", { type = "counter" })
T.blockedSq["43202,43002"] = true
T.blockedSq["43202,43001"] = true
local sx, sy = Rem.standSquare(T.square(43202, 43002, 0), 43205, 43002)
check(sx == 43203.5 and sy == 43002.5, "armario num quadrado solido: fica no quadrado livre mais perto de quem vem (" .. sx .. "," .. sy .. ")")
sx, sy = Rem.standSquare(T.square(43202, 43002, 0), 43202, 43000)
check(not (sx == 43202.5 and sy == 43001.5), "nunca num vizinho bloqueado")
sx, sy = Rem.standSquare(T.square(43205, 43003, 0), 43200, 43000)
check(sx == 43205.5 and sy == 43003.5, "quadrado livre: ele mesmo")

realPrint("192) Aliado mandado vasculhar um predio")
player.x, player.y = 43204, 43008
local scout = ally(43204.5, 43007.5)
scout.rec.carry = {}
local shelf = T.addObject(43206, 43004, 0, "container", { type = "shelves" })
T.blockedSq["43206,43004"] = true
local okL = IA.lootHere(scout, T.square(43203, 43003, 0))
check(okL and scout.rec.mode == "loot", "ordem aceita")
scout.z.path = nil
tick(300, 2)
check(scout.z.path ~= nil and not (math.floor(scout.z.path[1]) == 43204 and math.floor(scout.z.path[2]) == 43003),
    "vai direto para um armario (nao para o centro do predio, que pode ser parede)")
local goal = scout.z.path
check(T.square(math.floor(goal[1]), math.floor(goal[2]), 0):isFree(), "e o destino e um quadrado onde da para ficar de pe")
-- armario inalcancavel: desiste dele e passa para o proximo
local cur = scout.fLootCont
T.clock = T.clock + SC.CFG.STUCK_MS + 500
tick(300, 2)
check(scout.rec.lootTarget.visited[cur.key] == true and scout.fLootCont ~= cur, "armario que ele nao alcanca: desiste e vai para o proximo")
-- chega, revira, pega
scout.rec.lootTarget.visited = {}
scout.fLootCont = nil
tick(300)
cur = scout.fLootCont
scout.z.x, scout.z.y = cur.sq:getX() + 1.5, cur.sq:getY() + 0.5
tick(300, 12)
check(#scout.rec.carry > 0, "revira o armario e pega o que presta")
-- acabou: volta e entrega
scout.rec.lootTarget.visited = scout.rec.lootTarget.visited or {}
tick(300, 40)
player.x, player.y = scout.z.x + 1, scout.z.y
player.inv.items = {}
tick(300, 3)
check(scout.rec.mode == "follow" and #player.inv.items > 0 and scout.rec.lootTarget == nil, "predio revirado: volta, entrega e volta a te seguir")
-- voce foi embora: ele larga e volta
okL = IA.lootHere(scout, T.square(43203, 43003, 0))
scout.detour, scout.stuckSince = nil, nil       -- (nos testes o corpo nao anda sozinho: sem "destravar")
player.x, player.y = scout.z.x + IA.CFG.LOOT_LEASH + 10, scout.z.y
scout.z.path = nil
tick(300, 2)
check(scout.z.path and math.abs(scout.z.path[1] - player.x) < 1, "voce se afastou demais: ele larga o saque e vem atras")
player.x, player.y = scout.z.x + 1, scout.z.y
scout.lootDoneBid, scout.rec.carry = scout.rec.lootTarget.bid, nil     -- nada mais para revirar, e nao achou nada
scout.z.said = {}
tick(300, 2)
check(scout.rec.mode == "follow" and T.saidPrefix(scout.z, "IGUI_Rem_Bark_loot_nothing_"), "voltou de maos vazias: avisa")
-- tempo maximo
okL = IA.lootHere(scout, T.square(43203, 43003, 0))
tick(300)
scout.lootStart = Rem.nowMs() - IA.CFG.LOOT_MAX_MS - 1
scout.detour, scout.stuckSince = nil, nil
scout.z.x, scout.z.y = player.x + 8, player.y
scout.z.path = nil
tick(300, 2)
check(scout.z.path and math.abs(scout.z.path[1] - player.x) < 1, "demorou demais: volta com o que tem")
local okN, lN = IA.lootHere(scout, T.square(43400, 43400, 0))
check(not okN and lN.key == "IGUI_Rem_Loot_nobuilding", "sem predio por perto: avisa")

realPrint("193) Bolsos e troca")
fresh()
player.x, player.y = 43500, 43000
local someone = Rem.spawn(43502, 43000, 0, { faction = "civis", mode = "stay", archetype = "medico" })
check(type(someone.rec.pockets) == "table" and #someone.rec.pockets >= 2, "toda pessoa leva alguma coisa nos bolsos (" .. #someone.rec.pockets .. ")")
local medical = false
for _, ft in ipairs(someone.rec.pockets) do
    for _, m in ipairs(Rem.Profile.POCKET_BY_ARCH.medico) do if ft == m then medical = true end end
end
check(medical, "coerente com o que ela e (medico leva remedio)")
local offer = IA.theirItems(someone)
check(#offer == #someone.rec.pockets and offer[1].src == "pockets", "gente de passagem e aliados tem o que trocar: a janela nao abre vazia")
someone.rec.carry = { "Base.TinnedBeans" }
offer = IA.theirItems(someone)
check(#offer == #someone.rec.pockets + 1, "o que carrega (saque) tambem entra")
local n0 = #someone.rec.pockets
local taken = IA.takeFromNpc(someone, { offer[1], offer[#offer] }, player)
check(taken == 0 and #player.inv.items == 2 and #someone.rec.carry == 0 and #someone.rec.pockets == n0 - 1, "pegar itens tira do lugar certo (bolso e carga)")
local old = Rem.newPerson({ faction = "civis", x = 43510, y = 43000 })
old.pockets = nil
local oldNpc = Rem.materialize(old)
check(old.pockets ~= nil, "pessoas de saves antigos ganham bolsos ao aparecer")
require "Remanescentes/Rem_DialogUI"
someone.rec.pockets, someone.rec.carry = {}, {}
local tw = RemTradeWindow.open(someone, player)
tw.drawn = {}
tw:render()
local msg = false
for _, t in ipairs(tw.drawn) do if t == "IGUI_Rem_Trade_nothing" then msg = true end end
check(#tw.theirs.items == 0 and msg, "sem nada mesmo: a janela diz que nao ha o que trocar")
tw:close()

realPrint("194) O jogador nao entra em panico por causa dos amigos")
fresh()
player.x, player.y = 43700, 43000
local stats = { visible = 0, panic = 10 }
CharacterStat = { PANIC = "PANIC" }
function stats:getNumVisibleZombies() return self.visible end
function stats:get(k) return self.panic end
function stats:set(k, v) self.panic = v end
player.getStats = function() return stats end
require "Remanescentes/Rem_Calm"
CM.reset()
local pal = ally(43703, 43000, { mode = "stay" })
local function frame() T.clock = T.clock + 150 return CM.update(player) end   -- (indice de zumbis por perto: 100 ms)
check(CM.friendlyCount(player) == 1 and CM.realCount(player) == 0, "(cenario) um aliado no raio, nenhum zumbi de verdade")
frame()                                            -- quadro 1: o jogo nao contou o aliado (atras da parede)
stats.visible, stats.panic = 1, 30                 -- quadro 2: contou, e assustou
check(frame() == 10 and stats.panic == 10, "aliado entrou na conta do jogo: o susto e desfeito")
stats.visible = 0
frame()
stats.visible, stats.panic = 1, 28                 -- de novo (aliados entram e saem da conta o tempo todo)
frame()
check(stats.panic == 10, "toda vez que ele pisca na conta, o susto e desfeito")
local z1 = T.newZombie(43701, 43003, 0)
local z2 = T.newZombie(43699, 43003, 0)
stats.visible, stats.panic = 3, 50                 -- dois zumbis de verdade apareceram
check(frame() == nil and stats.panic == 50, "zumbi de verdade continua assustando")
local z3 = T.newZombie(43702, 43004, 0)
stats.visible, stats.panic = 5, 70                 -- no mesmo quadro: mais um zumbi e o aliado de novo
frame()
check(math.abs(stats.panic - 60) < 0.001, "aliado e zumbi juntos: so a parte do aliado e desfeita (" .. tostring(stats.panic) .. ")")
T.clearZombies({ [pal.z] = true })
stats.visible = 1
frame()
local thug = Rem.spawn(43704, 43002, 0, { faction = "saqueadores", mode = "stay" })
stats.visible, stats.panic = 2, 80
check(CM.friendlyCount(player) == 1 and frame() == nil and stats.panic == 80, "saqueador hostil chegando assusta de verdade")
Rem.dismiss(thug)
stats.panic = 40
check(frame() == nil and stats.panic == 40, "sem mudanca, nao mexe no panico (ele cai sozinho)")
player.getStats = nil

realPrint("194b) Aliado se limpa depois da briga (sem cara de zumbi)")
fresh()
player.x, player.y = 43800, 43000
local LK = Rem.Look
local dirty = ally(43802, 43000, { mode = "stay" })
dirty.z.blood = 0.8
dirty.lastCombatAt = Rem.nowMs()
LK.refresh(dirty, Rem.nowMs())
check(dirty.z.blood == 0.8, "logo depois de lutar, continua sujo")
check(LK.refresh(dirty, Rem.nowMs() + LK.CFG.CALM_MS + 1) and dirty.z.blood == 0, "calmo ha um tempo: limpa o sangue do rosto e da roupa")
dirty.z.skin = "M_ZedBody01_level3"
check(LK.refresh(dirty, Rem.nowMs()) and dirty.z.skin == dirty.rec.skin, "o jogo trocou a pele para a de zumbi: volta a humana")
check(LK.refresh(dirty, Rem.nowMs() + LK.CFG.CALM_MS + 1) == false, "nada a fazer: nao refaz o modelo a toa")
Rem.on("zombieHitNPC", function() end)
Rem.emit("zombieHitNPC", dirty, T.newZombie(43803, 43000, 0), Rem.nowMs() + 99999)
check(dirty.lastCombatAt == Rem.nowMs() + 99999, "mordida/arranhao conta como briga")

realPrint("195) Companheiro que ficou para tras alcanca voce")
fresh()
player.x, player.y = 43900, 43000
local lag = ally(43902, 43000)
lag.z.x = 43900 + CP.CFG.CATCHUP_DIST + 20
local id = lag.rec.id
T.clock = T.clock + CP.CFG.CHECK_MS + 1
CP.tick(player, Rem.nowMs())
check(lag.farSince ~= nil and Rem.active[lag.z] ~= nil, "longe: comeca a contar (nao some na hora)")
T.clock = T.clock + CP.CFG.CATCHUP_MS + CP.CFG.CHECK_MS
CP.tick(player, Rem.nowMs())
local back = nil
for _, npc in pairs(Rem.active) do if npc.rec.id == id then back = npc end end
check(back and Rem.dist(back.z, player) <= CP.CFG.PLACE[2] + 1.5 and Rem.dist(back.z, player) >= CP.CFG.PLACE[1] - 1.5,
    "depois de um tempo longe, reaparece perto de voce")
check(T.saidPrefix(back.z, "IGUI_Rem_Bark_catchup_") and Rem.personCount() == 1, "avisa que chegou; continua sendo a mesma pessoa")
local waiting = ally(43902, 43002, { mode = "stay" })
waiting.z.x = 43900 + CP.CFG.CATCHUP_DIST + 20
T.clock = T.clock + CP.CFG.CATCHUP_MS * 3
CP.tick(player, Rem.nowMs())
T.clock = T.clock + CP.CFG.CATCHUP_MS * 3
CP.tick(player, Rem.nowMs())
check(Rem.active[waiting.z] ~= nil and waiting.z.x > 43940, "quem voce mandou esperar fica onde esta")
-- no papel
local paper = Rem.newPerson({ faction = "aliados", mode = "follow", x = 44500, y = 43000 })
T.clock = T.clock + CP.CFG.CHECK_MS + 1
CP.tick(player, Rem.nowMs())
check(Rem.dist2(paper.x, paper.y, player.x, player.y) <= CP.CFG.PLACE[2] + 1.5, "seguidor que ficou num lugar descarregado volta para o seu lado")

realPrint("196) Ordens: para todos e pela conversa")
fresh()
player.x, player.y = 44100, 43000
local a1, a2 = ally(44102, 43000), ally(44103, 43001)
local civil = Rem.spawn(44104, 43002, 0, { faction = "civis", mode = "wander" })
check(CP.orderAll("stay") == 2 and a1.rec.mode == "stay" and a2.rec.mode == "stay" and civil.rec.mode == "wander", "'Todos esperem aqui' vale so para os seus aliados")
check(CP.orderAll("follow") == 2 and a1.rec.mode == "follow", "'Todos comigo'")
local labels = {}
for _, o in ipairs(Rem.playerOptions) do labels[o.labelKey] = true end
check(labels.ContextMenu_Rem_AllFollow and labels.ContextMenu_Rem_AllStay, "as duas ordens estao no menu do clique direito")
local opts = {}
for _, oid in ipairs(IA.dialogOptions(a1, player)) do opts[oid] = true end
check(opts.order_stay and opts.order_guard and opts.order_loot and opts.order_release and not opts.order_follow, "a conversa com um aliado tem as ordens (menos a que ele ja cumpre)")
opts = {}
for _, oid in ipairs(IA.dialogOptions(civil, player)) do opts[oid] = true end
check(not opts.order_stay and not opts.order_loot, "quem nao e seu aliado nao recebe ordem")
local l = IA.choose("order_stay", a1, player)
check(a1.rec.mode == "stay" and l.key == "IGUI_Rem_Order_stay", "ordem pela conversa: esperar")
l = IA.choose("order_guard", a1, player)
check(a1.rec.mode == "guard" and l.key == "IGUI_Rem_Order_guard", "guardar")
l = IA.choose("order_follow", a1, player)
check(a1.rec.mode == "follow", "seguir")
house(44201, 44104, 43004, 6, 6)
T.addObject(44106, 43006, 0, "container", { type = "shelves" })
l = IA.choose("order_loot", a1, player)
check(a1.rec.mode == "loot" and l.key == "IGUI_Rem_Loot_ok", "vasculhar o predio aqui perto")
l = IA.choose("order_release", a2, player)
check(a2.rec.faction ~= "aliados" and l.key == "IGUI_Rem_Order_release", "liberar")
fresh()
