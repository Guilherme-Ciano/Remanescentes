-- Fase E: conversar, trocar, abrigo, recrutar e comandos, missoes, ameacar; e as janelas.
local T = ...
local Rem = Remanescentes
local check, tick = T.check, T.tick
local player, realPrint = T.player, T.print
local IA = Rem.Interact

local function fresh()
    Rem.dismissAll(); T.clearZombies(); Rem.hunting = {}
    Rem.Mugging.enc = {}
    Rem.getStore().quests = {}
    Rem.getStore().knownGroups = {}
    player.inv.items = {}
    player.weapon, player.bag = nil, nil
end
local function house(id, x, y, w, h)
    local def = T.addBuilding(id, x, y, w, h)
    for i = x, x + w - 1 do for j = y, y + h - 1 do T.indoorSq[i .. "," .. j] = true; T.sqBuilding[i .. "," .. j] = def end end
    return def
end
local function hasItem(id)
    for _, it in ipairs(player.inv.items) do if it:getFullType() == id then return true end end
    return false
end
local function talker(g, idx)
    local npc = Rem.materialize(Rem.getPerson(g.members[idx or 1]))
    npc.z.fx, npc.z.fy = 0, 1
    return npc
end

SandboxVars.Remanescentes.RaiderMugging = false

-- base de testes: casa de um grupo de civis com estoque
local function homeGroup(id, x, y, faction, n)
    local def = house(id, x, y, 10, 8)
    local box = T.addObject(x + 2, y + 2, 0, "container", { type = "fridge" })
    T.addObject(x + 5, y + 7, 0, "IsoDoor", { exterior = true })
    local g = Rem.createGroup(faction or "civis", x + 5, y + 4, tostring(id), n or 3, def)
    g.supplies = 6
    player.x, player.y = x + 5, y + 6
    Rem.emit("sceneUpdate", player, T.clock)
    return g, box
end

realPrint("120) E1 Conversar")
fresh()
local g, box = homeGroup(30001, 30000, 30000)
local npc = talker(g)
check(IA.canTalk(npc), "da para conversar com um civil")
check(IA.greeting(npc).key:find("IGUI_Rem_Talk_hi_"), "cumprimenta conforme a atitude")
local thug = Rem.spawn(30020, 30020, 0, { faction = "saqueadores" })
check(not IA.canTalk(thug), "saqueador hostil nao conversa")
local other = Rem.materialize(Rem.getPerson(g.members[2]))
other.z.hp = other.rec.maxHealth * 0.3
check(IA.needs(npc).medical and IA.status(npc).key == "IGUI_Rem_Talk_need_medical", "conta que tem ferido no grupo")
local far = Rem.createGroup("sobreviventes", 30300, 30000, nil, 2)
local l = IA.groupInfo(npc, player)
check(l.key == "IGUI_Rem_Talk_info_distrust", "nao confia em voce o bastante para contar de outros grupos")
Rem.changeRep(g.id, 30, "teste")
l = IA.groupInfo(npc, player)
check(l.key == "IGUI_Rem_Talk_info" and l.args[2] == getText("IGUI_Rem_Dir_E"), "com confianca: conta onde fica outro grupo (" .. tostring(l.args[2]) .. ")")
l = IA.groupInfo(npc, player)
check(l.key == "IGUI_Rem_Talk_info_none", "nao repete o mesmo grupo")
check(IA.direction(0, 0, 0, -10) == "N" and IA.direction(0, 0, 10, 10) == "SE", "direcoes certas (y cresce para o sul)")

realPrint("121) E2 Trocar")
local bandage = T.newItem("Base.Bandage")
local beans = T.newItem("Base.TinnedBeans")
local needs = IA.needs(npc)
check(IA.value(bandage, needs) > IA.value(bandage, nil), "remedio vale mais para um grupo com ferido")
Rem.changeRep(g.id, -100, "teste")
local mkLow = IA.markup(npc)
Rem.changeRep(g.id, 200, "teste")
check(IA.markup(npc) < mkLow, "reputacao alta = margem menor")
box.container.items = {}
local their = box.container:AddItem("Base.CannedChili")
player.inv.items = {}
local junk = player.inv:AddItem("Base.Sofa")
local mine = player.inv:AddItem("Base.Bandage")
local offer = IA.theirItems(npc)
check(#offer == 1 and offer[1].item == their, "eles oferecem o que esta no estoque da casa")
local ok, res = IA.trade(player, npc, { { item = junk } }, { offer[1] })
check(not ok and res.key == "IGUI_Rem_Trade_unfair", "troca injusta e recusada")
Rem.changeRep(g.id, -50, "teste")   -- longe do teto, para ver a reputacao subir
local rep0 = Rem.repOf(npc.rec)
local sync0 = g.home.syncCount or 0
ok = IA.trade(player, npc, { { item = mine } }, { offer[1] })
check(ok and hasItem("Base.CannedChili") and not hasItem("Base.Bandage"), "troca justa: os itens trocam de mao")
local inStash = false
for _, it in ipairs(box.container.items) do if it:getFullType() == "Base.Bandage" then inStash = true end end
check(inStash and Rem.repOf(npc.rec) == rep0 + IA.CFG.TRADE_REP, "o que voce deu vai para o estoque; reputacao sobe")
-- gente de passagem: troca com o que carrega
fresh()
player.x, player.y = 31000, 31000
local walker = Rem.spawn(31002, 31000, 0, { faction = "civis", mode = "wander" })
walker.rec.carry = { "Base.TinnedBeans", "Base.WaterRationCan" }
player.inv:AddItem("Base.Bandage")
player.inv:AddItem("Base.Bandage")
local wo = IA.theirItems(walker)
ok = IA.trade(player, walker, { { item = player.inv.items[1] }, { item = player.inv.items[2] } }, { wo[1] })
check(ok and hasItem("Base.TinnedBeans") and #walker.rec.carry == 3, "troca com quem esta de passagem (o que ele carrega)")

realPrint("122) E3 Abrigo")
fresh()
local gs, boxs = homeGroup(30101, 30400, 30000, "sobreviventes", 3)
local mil = talker(gs)
ok, l = IA.askShelter(mil)
check(not ok, "sem confianca: sem abrigo (" .. l.key .. ")")
Rem.changeRep(gs.id, 80, "teste")
ok, l = IA.askShelter(mil)
check(ok and IA.isGuest(gs), "com boa reputacao: pode ficar uns dias")
check(not Rem.Safehouse.locksOut(gs), "a porta fica destrancada para voce")
Rem.changeRep(gs.id, -70, "teste")   -- (de volta a neutro)
check(not Rem.Safehouse.locksOut(gs), "hospede com reputacao neutra: a porta continua aberta para voce")
player.x, player.y = gs.home.x, gs.home.y + 2
Rem.Reputation.state[gs.id] = nil
Rem.emit("sceneUpdate", player, T.clock)
check(not T.saidPrefix(mil.z, "IGUI_Rem_Bark_warn_"), "hospede: a milicia nao manda voce embora")

realPrint("123) E4 Recrutar e comandos")
fresh()
local gr = homeGroup(30201, 30600, 30000, "civis", 4)
local loyal = talker(gr, 1)
loyal.rec.personality.lealdade = 2
Rem.changeRep(gr.id, -Rem.getRep(gr.id), "teste")    -- reputacao 0 (neutro, nao hostil)
ok, l = IA.askJoin(loyal)
check(not ok and l.key ~= "IGUI_Rem_Talk_refuse", "pouca lealdade e reputacao neutra: recusa (" .. l.key .. ")")
ok, l = IA.askJoin(loyal)
check(not ok and l.key == "IGUI_Rem_Join_asked", "pergunta repetida no mesmo dia: 'ja respondi'")
loyal.rec.askedJoinAt = nil
loyal.rec.personality.lealdade = 10
Rem.changeRep(gr.id, 200, "teste")
local nBefore = #gr.members
ok, l = IA.askJoin(loyal)
check(ok and loyal.rec.faction == "aliados" and loyal.rec.mode == "follow" and #gr.members == nBefore - 1, "lealdade alta + reputacao: vira seu aliado")
check(loyal.z.avoid == true, "e protegido dos seus golpes como aliado")
-- guardar posicao
IA.guard(loyal)
local gx, gy = loyal.rec.homeX, loyal.rec.homeY
loyal.z.x, loyal.z.y = gx + 8, gy
tick(300)
check(loyal.z.path and math.floor(loyal.z.path[1]) == gx, "guardar posicao: volta para o ponto")
-- saquear aqui
local dL = house(30202, 30700, 30000, 8, 6)
local shelf = T.addObject(30702, 30002, 0, "container", { type = "shelves" })
ok = IA.lootHere(loyal, getCell():getGridSquare(30703, 30003, 0))
check(ok and loyal.rec.mode == "loot", "saquear aqui: vai ate o predio")
loyal.z.x, loyal.z.y = 30702.5, 30002.5
tick(300); tick(300, 12)
check(loyal.rec.carry and #loyal.rec.carry > 0, "pega coisas dos armarios")
tick(300, 4)
player.x, player.y = loyal.z.x + 1, loyal.z.y
player.inv.items = {}
tick(300)
check(#player.inv.items > 0 and loyal.rec.mode == "follow", "volta e entrega para voce")
-- liberar
IA.release(loyal, player)
check(loyal.rec.faction == "civis" and loyal.rec.transient and loyal.rec.mode == "ambient", "liberar: vai embora")

realPrint("124) E5 Missoes")
fresh()
local gq, boxq = homeGroup(30301, 30900, 30000, "civis", 3)
local q1 = talker(gq, 1)
local hurt = Rem.materialize(Rem.getPerson(gq.members[2]))
hurt.z.hp = hurt.rec.maxHealth * 0.3
local q, ql = IA.offerQuest(q1)
check(q and q.kind == "medical" and ql.key == "IGUI_Rem_Quest_medical", "grupo com ferido pede remedio")
ok, l = IA.turnIn(q1, player)
check(not ok and l.key == "IGUI_Rem_Quest_medical_remind", "sem os itens: lembra o que falta")
player.inv:AddItem("Base.Bandage"); player.inv:AddItem("Base.Disinfectant")
local repq = Rem.getRep(gq.id)
local before = #player.inv.items
ok, l = IA.turnIn(q1, player)
-- os 2 itens pedidos saem; a recompensa (pode ser outra bandagem do estoque deles) entra
local after = #player.inv.items - ((l and l.key == "IGUI_Rem_Quest_reward_item") and 1 or 0)
check(ok and Rem.getRep(gq.id) >= repq + IA.CFG.QUEST_REP and after == before - 2, "entregou: reputacao sobe (" .. before .. " -> " .. after .. ")")
check(l.key == "IGUI_Rem_Quest_reward_item" or l.key == "IGUI_Rem_Quest_reward_info", "e ganha uma recompensa")
check(IA.questOf(q1) == nil, "missao concluida")
-- limpar zumbis
hurt.z.hp = hurt.rec.maxHealth
gq.supplies = 50
for _ = 1, 10 do
    q = nil
    Rem.getStore().quests = {}
    q = select(1, IA.offerQuest(q1))
    if q.kind == "clear" then break end
end
check(q.kind == "clear", "(cenario) missao de limpar a rua")
for i = 1, q.count do
    local z = T.newZombie(gq.home.x + 5, gq.home.y + 5, 0)
    z.getAttackedBy = function() return player end
    z:Kill(player)
end
ok = IA.turnIn(q1, player)
check(ok, "matou os zumbis perto da casa: missao cumprida")
-- achar quem sumiu
T.addBuilding(30302, 31000, 30100, 8, 8)
local lostQ
for _ = 1, 20 do
    Rem.getStore().quests = {}
    lostQ = select(1, IA.offerQuest(q1))
    if lostQ.kind == "lost" then break end
end
check(lostQ.kind == "lost" and Rem.getPerson(lostQ.memberId) and Rem.getPerson(lostQ.memberId).lost, "alguem do grupo sumiu longe de casa")
local lostRec = Rem.getPerson(lostQ.memberId)
player.x, player.y = lostRec.x + 2, lostRec.y
local lostNpc = Rem.materialize(lostRec)
check(IA.dialogOptions(lostNpc, player)[1] == "status" and (function() for _, o in ipairs(IA.dialogOptions(lostNpc, player)) do if o == "findlost" then return true end end end)(),
    "conversando com ele aparece 'sua familia esta te esperando'")
IA.findLost(lostNpc)
check(lostRec.mode == "group", "ele volta para casa")
lostRec.x, lostRec.y = gq.home.x, gq.home.y
Rem.emit("sceneUpdate", player, T.clock)
ok = IA.turnIn(q1, player)
check(ok, "chegou em casa: missao cumprida")

realPrint("125) E6 Ameacar")
fresh()
local gt, boxt = homeGroup(30401, 31200, 30000, "civis", 2)
boxt.container:AddItem("Base.Pistol")
local coward = talker(gt, 1)
coward.rec.personality.coragem = 2
ok, l = IA.threaten(coward, player)
check(not ok and l.key == "IGUI_Rem_Threat_unarmed", "sem arma na mao: nao funciona")
player.weapon = instanceItem("Base.Axe")
local repT = Rem.getRep(gt.id)
ok, l = IA.threaten(coward, player)
check(ok and hasItem("Base.Pistol") and Rem.getRep(gt.id) <= repT + IA.CFG.THREAT_REP, "medroso entrega (e a reputacao despenca)")
local brave = talker(gt, 2)
brave.rec.personality.coragem = 9
ok, l = IA.threaten(brave, player)
check(not ok and l.key == "IGUI_Rem_Threat_fight" and brave.rec.hostileToPlayer, "corajoso reage: briga")

realPrint("126) Janelas (conversa e troca)")
fresh()
-- mocks minimos da interface do jogo
UIFont = { Small = 1, Medium = 2 }
function getCore() return { getScreenWidth = function() return 1920 end, getScreenHeight = function() return 1080 end } end
function getTextManager() return { getFontHeight = function() return 14 end, MeasureStringX = function() return 50 end } end
local function uiClass()
    local C = {}
    C.__index = C
    function C:derive(name) local D = setmetatable({}, { __index = self }) D.__index = D return D end
    return C
end
ISUIElement = uiClass()
function ISUIElement:addChild(c) self.children = self.children or {} table.insert(self.children, c) end
function ISUIElement:removeChild(c) for i, x in ipairs(self.children or {}) do if x == c then table.remove(self.children, i) end end end
function ISUIElement:initialise() end
function ISUIElement:instantiate() end
function ISUIElement:setHeight(h) self.height = h end
function ISUIElement:getWidth() return self.width end
function ISUIElement:getX() return self.x end
function ISUIElement:drawText(t) self.drawn = self.drawn or {} table.insert(self.drawn, t) end
function ISUIElement:drawRect() end
function ISUIElement:drawRectBorder() end
function ISUIElement:drawTextureScaledAspect() end
function ISUIElement:setY(y) self.y = y end
function ISUIElement:setYScroll() end
function ISUIElement:setVisible(v) self.visible = v end
IsoDirections = { S = "S" }
ISUI3DModel = setmetatable({}, { __index = ISUIElement })
ISUI3DModel.__index = ISUI3DModel
function ISUI3DModel:new(x, y, w, h) return setmetatable({ x = x, y = y, width = w, height = h }, ISUI3DModel) end
function ISUI3DModel:setOutfitName(n, f) self.outfit, self.female = n, f end
function ISUI3DModel:setState(s) self.state = s end
function ISUI3DModel:setDirection() end
function ISUI3DModel:setIsometric() end
ISCollapsableWindow = setmetatable({}, { __index = ISUIElement })
ISCollapsableWindow.__index = ISCollapsableWindow
function ISCollapsableWindow:derive(name) local D = setmetatable({}, { __index = self }) D.__index = D return D end
function ISCollapsableWindow.new(cls, x, y, w, h) local o = setmetatable({ x = x, y = y, width = w, height = h }, cls) return o end
function ISCollapsableWindow:createChildren() end
function ISCollapsableWindow:titleBarHeight() return 16 end
function ISCollapsableWindow:addToUIManager() self.shown = true if not self.built then self.built = true self:createChildren() end end
function ISCollapsableWindow:removeFromUIManager() self.shown = false end
function ISCollapsableWindow:update() end
function ISCollapsableWindow:render() end
function ISCollapsableWindow:close() self.closed = true end
ISRichTextPanel = setmetatable({}, { __index = ISUIElement })
ISRichTextPanel.__index = ISRichTextPanel
function ISRichTextPanel:new(x, y, w, h) return setmetatable({ x = x, y = y, width = w, height = h }, ISRichTextPanel) end
function ISRichTextPanel:setText(t) self.text = t end
function ISRichTextPanel:paginate() end
ISButton = setmetatable({}, { __index = ISUIElement })
ISButton.__index = ISButton
function ISButton:new(x, y, w, h, title, target, onclick) return setmetatable({ x = x, y = y, width = w, height = h, title = title, target = target, onclick = onclick, enabled = true }, ISButton) end
function ISButton:setEnable(b) self.enabled = b end
function ISButton:setFont() end
ISScrollingListBox = setmetatable({}, { __index = ISUIElement })
ISScrollingListBox.__index = ISScrollingListBox
function ISScrollingListBox:new(x, y, w, h) return setmetatable({ x = x, y = y, width = w, height = h, items = {} }, ISScrollingListBox) end
function ISScrollingListBox:addItem(name, item) table.insert(self.items, { text = name, item = item }) end
function ISScrollingListBox:clear() self.items = {} end
function ISScrollingListBox:setOnMouseDownFunction(t, f) self.mdTarget, self.mdFn = t, f end
require "Remanescentes/Rem_DialogUI"

local gu, boxu = homeGroup(30501, 31400, 30000, "civis", 2)
boxu.container.items = {}
boxu.container:AddItem("Base.CannedChili")
local un = talker(gu, 1)
Rem.changeRep(gu.id, 60, "teste")
player.x, player.y = un.z.x + 1, un.z.y
local w = RemDialogWindow.open(un, player)
check(w and w.historyPanel.text and w.historyPanel.text:find("IGUI_Rem_Talk_hi_"), "janela de conversa abre com o cumprimento no historico")
w:render()
check(w.avatar.outfit == un.rec.outfit and w.avatar.state == "idle", "retrato 3D com a roupa dele, em pose humana")
local said = false
for _, t in ipairs(un.z.said) do if t:find("IGUI_Rem_Talk_hi_") then said = true end end
check(said, "o cumprimento tambem aparece em balao sobre ele")
local ids = {}
for _, b in ipairs(w.buttons) do ids[b.internal] = b end
ids.bye = w.byeButton
check(ids.status and ids.trade and ids.join and ids.bye, "botoes das opcoes (e 'ate mais' separado)")
check(w.buttons[1].title:sub(1, 2) == "1.", "opcoes numeradas")
ids.status.onclick(w, ids.status)
check(w.lastLine:find("IGUI_Rem_Talk_need_") and w.historyPanel.text:find("IGUI_Rem_Talk_you"), "clicou 'como voces estao': sua pergunta e a resposta entram no historico")
check(w.lastLine:find("_%d$"), "a resposta vem de uma das variacoes (" .. w.lastLine .. ")")
check(un.talkingUntil and un.talkingUntil > T.clock, "o NPC para para conversar")
ids.trade.onclick(w, ids.trade)
local tw = RemTradeWindow.instance
check(tw and #tw.theirs.items == 1, "janela de troca abre com o estoque deles")
player.inv.items = {}
player.inv:AddItem("Base.Bandage"); player.inv:AddItem("Base.Bandage")
tw:refresh()
check(tw.ok.enabled == false, "'Trocar' desabilitado sem nada marcado")
-- (a lista chama onmousedown(target, item.item), como no ISScrollingListBox vanilla)
tw.theirs.mdFn(tw.theirs.mdTarget, tw.theirs.items[1].item)
tw:render()
check(tw.ok.enabled == false, "so pegar sem dar nada (saldo negativo): 'Trocar' desabilitado")
tw.theirs.mdFn(tw.theirs.mdTarget, tw.theirs.items[1].item)   -- desmarca
for _, it in ipairs(tw.mine.items) do tw.mine.mdFn(tw.mine.mdTarget, it.item) end
tw.theirs.mdFn(tw.theirs.mdTarget, tw.theirs.items[1].item)
tw:render()
check(tw.ok.enabled == true, "troca justa marcada: 'Trocar' habilitado")
check(tw.needsText and tw.markupText, "mostra do que precisam e a margem deles")
tw:onAccept()
check(hasItem("Base.CannedChili"), "marcou os itens e trocou pela janela")
player.x = un.z.x + 20
w:update()
check(w.closed, "voce se afastou: a janela fecha")
local optCount = 0
for _, o in ipairs(Rem.npcOptions) do
    if o.labelKey == "ContextMenu_Rem_Talk" or o.labelKey == "ContextMenu_Rem_Guard" or o.labelKey == "ContextMenu_Rem_LootHere" then optCount = optCount + 1 end
end
check(optCount == 3, "menu do NPC: Conversar, Guardar posicao, Saquear aqui")

SandboxVars.Remanescentes.RaiderMugging = nil
fresh()
