-- Remanescentes - janelas de conversa e de troca (a logica fica em
-- shared/Remanescentes/Rem_Interact.lua).
--
-- Conversa: retrato 3D (roupa e genero do sobrevivente), nome, profissao e arquetipo,
--   selo da faccao, atitude e barra de reputacao a esquerda; historico da conversa e opcoes
--   numeradas a direita. As respostas tambem aparecem em balao sobre o NPC no mundo.
-- Troca: suas coisas x as deles, com icone, categoria e valor; do que o grupo precisa e a
--   margem deles; totais coloridos; "Trocar" so habilita com troca justa.
require "ISUI/ISCollapsableWindow"
require "ISUI/ISScrollingListBox"
require "ISUI/ISButton"
require "ISUI/ISRichTextPanel"
require "ISUI/ISUI3DModel"
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_Interact"
require "Remanescentes/Rem_MapMarks"
local Rem = Remanescentes
local IA = Rem.Interact

local FONT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local PAD = 10
local BTN_H = math.max(24, FONT_SMALL + 10)
local MAX_DIST = 6
local HISTORY = 12

local ATT_COLOR = { amigavel = { 0.45, 0.85, 0.45 }, neutro = { 0.95, 0.8, 0.35 }, hostil = { 0.95, 0.35, 0.3 } }

local function factionColor(f)
    local c = Rem.MapMarks and Rem.MapMarks.COLORS[f]
    return c or { 0.6, 0.6, 0.6 }
end

local function attitudeOf(rec)
    return rec.attitude or (Rem.attitudeOf and Rem.attitudeOf(rec)) or "neutro"
end

local function rich(r, g, b) return string.format(" <RGB:%.2f,%.2f,%.2f> ", r, g, b) end

-- ---------------------------------------------------------------- conversa
RemDialogWindow = ISCollapsableWindow:derive("RemDialogWindow")

function RemDialogWindow.open(npc, player)
    if RemDialogWindow.instance then RemDialogWindow.instance:close() end
    local w = RemDialogWindow:new(getCore():getScreenWidth() / 2 - 340, getCore():getScreenHeight() / 2 - 250, 680, 500)
    w.npc, w.player = npc, player
    w.history = {}
    w:initialise()
    w:addToUIManager()
    RemDialogWindow.instance = w
    w:npcSays(IA.greeting(npc))
    IA.hold(npc)
    return w
end

function RemDialogWindow:new(x, y, width, height)
    local o = ISCollapsableWindow.new(self, x, y, width, height)
    o.title = getText("IGUI_Rem_Talk_title")
    o.resizable = false
    return o
end

function RemDialogWindow:createChildren()
    ISCollapsableWindow.createChildren(self)
    local top = self:titleBarHeight() + PAD
    self.leftW = 190
    -- retrato 3D com a roupa do sobrevivente (pose humana; o corpo real e um zumbi)
    self.avatar = ISUI3DModel:new(PAD + 5, top + 5, self.leftW - 10, 210)
    self.avatar:setVisible(true)
    self:addChild(self.avatar)
    self.avatarReady = false
    -- historico
    local rx = PAD * 2 + self.leftW
    self.rightX, self.rightW = rx, self.width - rx - PAD
    self.historyPanel = ISRichTextPanel:new(rx, top, self.rightW, 230)
    self.historyPanel:initialise()
    self.historyPanel.background = true
    self.historyPanel.backgroundColor = { r = 0.05, g = 0.05, b = 0.05, a = 0.75 }
    self.historyPanel.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 1 }
    self.historyPanel.autosetheight = false
    self.historyPanel.clip = true
    self:addChild(self.historyPanel)
    self.optionsY = top + 230 + PAD
    self.buttons = {}
    self.byeButton = ISButton:new(self.width - PAD - 120, self.height - PAD - BTN_H, 120, BTN_H,
        getText("IGUI_Rem_Opt_bye"), self, RemDialogWindow.onOption)
    self.byeButton.internal = "bye"
    self.byeButton:initialise()
    self:addChild(self.byeButton)
end

function RemDialogWindow:setupAvatar()
    if self.avatarReady then return end
    self.avatarReady = true
    local rec = self.npc.rec
    pcall(function()
        self.avatar:setOutfitName(rec.outfit or "Generic01", rec.female == true, false)
        self.avatar:setState("idle")
        self.avatar:setDirection(IsoDirections.S)
        self.avatar:setIsometric(false)
    end)
end

function RemDialogWindow:push(who, text)
    table.insert(self.history, { who = who, text = text })
    while #self.history > HISTORY do table.remove(self.history, 1) end
    local name = tostring(self.npc.rec.name or "?")
    local parts = {}
    for _, e in ipairs(self.history) do
        if e.who == "you" then
            table.insert(parts, rich(0.55, 0.75, 1) .. getText("IGUI_Rem_Talk_you") .. ": " .. rich(0.8, 0.88, 1) .. e.text)
        else
            local c = factionColor(self.npc.rec.faction)
            table.insert(parts, rich(c[1] * 0.5 + 0.5, c[2] * 0.5 + 0.5, c[3] * 0.5 + 0.5) .. name .. ": " .. rich(1, 1, 1) .. e.text)
        end
    end
    self.historyPanel:setText(table.concat(parts, " <LINE> <LINE> "))
    self.historyPanel:paginate()
    pcall(function() self.historyPanel:setYScroll(-10000) end)   -- rola ate o fim
end

-- Fala do NPC: no historico e em balao sobre ele no mundo.
function RemDialogWindow:npcSays(l)
    local text = IA.text(IA.finalize(l, self.npc))
    self.lastLine = text
    self:push("npc", text)
    pcall(function() self.npc.z:Say(text) end)
    self:rebuildButtons()
end

function RemDialogWindow:rebuildButtons()
    for _, b in ipairs(self.buttons) do self:removeChild(b) end
    self.buttons = {}
    local y = self.optionsY
    local n = 0
    for _, id in ipairs(IA.dialogOptions(self.npc, self.player)) do
        if id ~= "bye" then
            n = n + 1
            local b = ISButton:new(self.rightX, y, self.rightW, BTN_H, n .. ".  " .. getText("IGUI_Rem_Opt_" .. id), self, RemDialogWindow.onOption)
            b.internal = id
            b:initialise()
            pcall(function() b:setFont(UIFont.Small) end)
            self:addChild(b)
            table.insert(self.buttons, b)
            y = y + BTN_H + 3
        end
    end
    local h = math.max(y + PAD + BTN_H + PAD, self:titleBarHeight() + PAD + 400)
    self:setHeight(h)
    self.byeButton:setY(h - PAD - BTN_H)
end

function RemDialogWindow:onOption(button)
    local id = button.internal
    if id == "bye" then
        local l = IA.finalize({ key = "IGUI_Rem_Talk_bye", args = {} }, self.npc)
        pcall(function() self.npc.z:Say(IA.text(l)) end)
        self:close()
        return
    end
    self:push("you", getText("IGUI_Rem_Opt_" .. id))
    if id == "trade" then
        RemTradeWindow.open(self.npc, self.player)
        return
    end
    self:npcSays(IA.choose(id, self.npc, self.player))
end

function RemDialogWindow:render()
    ISCollapsableWindow.render(self)
    self:setupAvatar()
    local rec = self.npc.rec
    local top = self:titleBarHeight() + PAD
    -- moldura do retrato
    self:drawRect(PAD, top, self.leftW, 220, 0.6, 0.08, 0.08, 0.08)
    self:drawRectBorder(PAD, top, self.leftW, 220, 0.8, 0.45, 0.45, 0.45)
    local y = top + 228
    self:drawText(tostring(rec.name or "?"), PAD, y, 1, 1, 1, 1, UIFont.Medium)
    y = y + FONT_MEDIUM + 2
    local prof = rec.professionUI and getText(rec.professionUI) or ""
    local age = rec.age and (", " .. tostring(math.floor(rec.age))) or ""
    self:drawText(prof .. age, PAD, y, 0.75, 0.75, 0.75, 1, UIFont.Small)
    y = y + FONT_SMALL + 1
    self:drawText(getText("IGUI_Rem_Arch_" .. tostring(rec.archetype or "brigao")), PAD, y, 0.6, 0.6, 0.6, 1, UIFont.Small)
    y = y + FONT_SMALL + 8
    -- selo da faccao
    local fc = factionColor(rec.faction)
    local fname = getText("IGUI_Rem_Faction_" .. tostring(rec.faction))
    self:drawRect(PAD, y, self.leftW, FONT_SMALL + 6, 0.85, fc[1] * 0.6, fc[2] * 0.6, fc[3] * 0.6)
    self:drawText(fname, PAD + 6, y + 3, 1, 1, 1, 1, UIFont.Small)
    y = y + FONT_SMALL + 12
    -- atitude
    local att = attitudeOf(rec)
    local ac = ATT_COLOR[att] or ATT_COLOR.neutro
    self:drawText(getText("IGUI_Rem_Talk_attitude") .. ": ", PAD, y, 0.75, 0.75, 0.75, 1, UIFont.Small)
    self:drawText(getText("IGUI_Rem_Att_" .. att), PAD + 70, y, ac[1], ac[2], ac[3], 1, UIFont.Small)
    y = y + FONT_SMALL + 6
    -- barra de reputacao (-100..100, centro = 0)
    local rep = Rem.repOf and Rem.repOf(rec) or 0
    self:drawText(getText("IGUI_Rem_Talk_reputation") .. ": " .. tostring(math.floor(rep)), PAD, y, 0.75, 0.75, 0.75, 1, UIFont.Small)
    y = y + FONT_SMALL + 3
    local bw, bh = self.leftW, 8
    self:drawRect(PAD, y, bw, bh, 0.8, 0.15, 0.15, 0.15)
    local half = bw / 2
    local fill = math.min(1, math.abs(rep) / 100) * half
    if rep >= 0 then
        self:drawRect(PAD + half, y, fill, bh, 0.9, 0.3, 0.75, 0.3)
    else
        self:drawRect(PAD + half - fill, y, fill, bh, 0.9, 0.8, 0.25, 0.2)
    end
    self:drawRect(PAD + half, y - 2, 1, bh + 4, 1, 0.9, 0.9, 0.9)
    -- titulo das opcoes
    self:drawText(getText("IGUI_Rem_Talk_options"), self.rightX, self.optionsY - FONT_SMALL - 2, 0.7, 0.7, 0.7, 1, UIFont.Small)
end

function RemDialogWindow:update()
    ISCollapsableWindow.update(self)
    local npc = self.npc
    if not npc or not Rem.active[npc.z] or npc.z:isDead() or Rem.dist(npc.z, self.player) > MAX_DIST
        or (Rem.isHostileToPlayer(npc) and not npc.rec.surrendered) then
        self:close()
        return
    end
    IA.hold(npc)
end

function RemDialogWindow:close()
    ISCollapsableWindow.close(self)
    self:removeFromUIManager()
    if RemDialogWindow.instance == self then RemDialogWindow.instance = nil end
end

-- ---------------------------------------------------------------- troca
RemTradeWindow = ISCollapsableWindow:derive("RemTradeWindow")

function RemTradeWindow.open(npc, player)
    if RemTradeWindow.instance then RemTradeWindow.instance:close() end
    local w = RemTradeWindow:new(getCore():getScreenWidth() / 2 - 370, getCore():getScreenHeight() / 2 - 270, 740, 540)
    w.npc, w.player = npc, player
    w:initialise()
    w:addToUIManager()
    RemTradeWindow.instance = w
    w:refresh()
    return w
end

function RemTradeWindow:new(x, y, width, height)
    local o = ISCollapsableWindow.new(self, x, y, width, height)
    o.title = getText("IGUI_Rem_Trade_title")
    o.resizable = false
    return o
end

local ROW_H = math.max(26, FONT_SMALL + 10)

-- Linha da lista: icone, nome, categoria e valor a direita.
local function drawEntry(list, y, item, alt)
    local e = item.item
    local w = list:getWidth()
    if e.marked then
        local c = list.markColor
        list:drawRect(0, y, w, ROW_H - 1, 0.35, c[1], c[2], c[3])
    elseif alt then
        list:drawRect(0, y, w, ROW_H - 1, 0.15, 0.25, 0.25, 0.25)
    end
    local tex = nil
    pcall(function() tex = e.item:getTex() end)
    if tex then list:drawTextureScaledAspect(tex, 4, y + 3, ROW_H - 6, ROW_H - 6, 1, 1, 1, 1) end
    local tx = ROW_H + 4
    list:drawText(e.name or "?", tx, y + (ROW_H - FONT_SMALL) / 2, 1, 1, 1, 1, UIFont.Small)
    local v = e.valueText or ""
    local vw = getTextManager():MeasureStringX(UIFont.Small, v)
    list:drawText(v, w - vw - 18, y + (ROW_H - FONT_SMALL) / 2, 0.95, 0.85, 0.4, 1, UIFont.Small)
    return y + ROW_H
end

function RemTradeWindow:createChildren()
    ISCollapsableWindow.createChildren(self)
    local top = self:titleBarHeight() + PAD
    self.infoY = top
    self.listsY = top + FONT_MEDIUM + FONT_SMALL * 2 + PAD * 2
    local colW = (self.width - PAD * 3) / 2
    local listH = self.height - self.listsY - FONT_SMALL - BTN_H * 2 - PAD * 4
    self.colW = colW
    self.mine = ISScrollingListBox:new(PAD, self.listsY + FONT_SMALL + 4, colW, listH)
    self.theirs = ISScrollingListBox:new(PAD * 2 + colW, self.listsY + FONT_SMALL + 4, colW, listH)
    self.mine.markColor = { 0.3, 0.75, 0.3 }
    self.theirs.markColor = { 0.9, 0.55, 0.15 }
    for _, l in ipairs({ self.mine, self.theirs }) do
        l:initialise()
        l:instantiate()
        l.itemheight = ROW_H
        l.drawBorder = true
        l.doDrawItem = drawEntry
        l:setOnMouseDownFunction(self, RemTradeWindow.onToggle)
        self:addChild(l)
    end
    self.summaryY = self.listsY + FONT_SMALL + 4 + listH + PAD
    self.ok = ISButton:new(PAD, self.height - BTN_H - PAD, colW, BTN_H, getText("IGUI_Rem_Trade_accept"), self, RemTradeWindow.onAccept)
    self.ok:initialise()
    self:addChild(self.ok)
    self.cancel = ISButton:new(PAD * 2 + colW, self.height - BTN_H - PAD, colW, BTN_H, getText("IGUI_Rem_Trade_close"), self, RemTradeWindow.close)
    self.cancel:initialise()
    self:addChild(self.cancel)
end

local function categoryName(item)
    local dc = "Junk"
    pcall(function() dc = item:getDisplayCategory() or "Junk" end)
    return dc
end

function RemTradeWindow:refresh()
    local needs = IA.needs(self.npc)
    local mk = IA.markup(self.npc)
    self.mine:clear()
    self.theirs:clear()
    for _, e in ipairs(IA.playerItems(self.player)) do
        e.name = e.item:getDisplayName()
        e.valueText = string.format("%.1f", IA.value(e.item, needs))
        self.mine:addItem(e.name, e)
    end
    for _, e in ipairs(IA.theirItems(self.npc)) do
        e.name = e.item:getDisplayName()
        e.valueText = string.format("%.1f", IA.value(e.item, needs) * mk)
        self.theirs:addItem(e.name, e)
    end
    -- faixa: do que precisam + margem
    local parts = {}
    if needs.medical then table.insert(parts, getText("IGUI_Rem_Trade_need_medical")) end
    if needs.food then table.insert(parts, getText("IGUI_Rem_Trade_need_food")) end
    if needs.ammo then table.insert(parts, getText("IGUI_Rem_Trade_need_ammo")) end
    self.needsText = (#parts > 0) and (getText("IGUI_Rem_Trade_needs") .. " " .. table.concat(parts, ", "))
        or getText("IGUI_Rem_Trade_noneeds")
    self.markupText = getText("IGUI_Rem_Trade_markup", tostring(math.floor((mk - 1) * 100 + 0.5)))
    self.message = nil
    self:updateButton()
end

function RemTradeWindow:onToggle(entry)
    entry.marked = not entry.marked
    self:updateButton()
end

local function marked(list)
    local out = {}
    for _, it in ipairs(list.items) do if it.item.marked then table.insert(out, it.item) end end
    return out
end

function RemTradeWindow:updateButton()
    local give, take = marked(self.mine), marked(self.theirs)
    local bal = IA.balance(self.npc, give, take)
    local enable = (#give + #take > 0) and bal >= 0
    pcall(function() self.ok:setEnable(enable) end)
end

function RemTradeWindow:onAccept()
    local ok, l = IA.trade(self.player, self.npc, marked(self.mine), marked(self.theirs))
    IA.finalize(l, self.npc)
    self:refresh()
    self.message = IA.text(l)
    self.messageOk = ok
    pcall(function() self.npc.z:Say(self.message) end)
    if RemDialogWindow.instance and RemDialogWindow.instance.npc == self.npc then
        RemDialogWindow.instance:push("npc", self.message)
    end
end

function RemTradeWindow:render()
    ISCollapsableWindow.render(self)
    local rec = self.npc.rec
    local fc = factionColor(rec.faction)
    local y = self.infoY
    self:drawText(getText("IGUI_Rem_Trade_with", tostring(rec.name), getText("IGUI_Rem_Faction_" .. tostring(rec.faction))),
        PAD, y, fc[1] * 0.5 + 0.5, fc[2] * 0.5 + 0.5, fc[3] * 0.5 + 0.5, 1, UIFont.Medium)
    y = y + FONT_MEDIUM + 4
    self:drawText(self.needsText or "", PAD, y, 0.95, 0.75, 0.4, 1, UIFont.Small)
    y = y + FONT_SMALL + 2
    self:drawText(self.markupText or "", PAD, y, 0.7, 0.7, 0.7, 1, UIFont.Small)
    self:drawText(getText("IGUI_Rem_Trade_yours"), PAD, self.listsY, 0.6, 0.9, 0.6, 1, UIFont.Small)
    self:drawText(getText("IGUI_Rem_Trade_theirs"), self.theirs:getX(), self.listsY, 0.95, 0.7, 0.4, 1, UIFont.Small)
    -- totais
    local bal, give, take = IA.balance(self.npc, marked(self.mine), marked(self.theirs))
    local sy = self.summaryY
    self:drawText(getText("IGUI_Rem_Trade_give", string.format("%.1f", give)), PAD, sy, 0.6, 0.9, 0.6, 1, UIFont.Small)
    self:drawText(getText("IGUI_Rem_Trade_take", string.format("%.1f", take)), PAD + 200, sy, 0.95, 0.7, 0.4, 1, UIFont.Small)
    local r, g = (bal >= 0) and 0.5 or 1, (bal >= 0) and 1 or 0.4
    self:drawText(getText("IGUI_Rem_Trade_balance", string.format("%+.1f", bal)), PAD + 400, sy, r, g, 0.45, 1, UIFont.Small)
    if self.message then
        local mr, mg = self.messageOk and 0.6 or 1, self.messageOk and 1 or 0.5
        self:drawText(self.message, PAD, sy + FONT_SMALL + 6, mr, mg, 0.6, 1, UIFont.Small)
    end
end

function RemTradeWindow:update()
    ISCollapsableWindow.update(self)
    local npc = self.npc
    if not npc or not Rem.active[npc.z] or npc.z:isDead() or Rem.dist(npc.z, self.player) > MAX_DIST then
        self:close()
        return
    end
    IA.hold(npc)
end

function RemTradeWindow:close()
    ISCollapsableWindow.close(self)
    self:removeFromUIManager()
    if RemTradeWindow.instance == self then RemTradeWindow.instance = nil end
end

-- ---------------------------------------------------------------- menu do NPC
local function canTalk(npc) return not Rem.isHostileToPlayer(npc) or npc.rec.surrendered end
local function isFollower(npc) return npc.rec.faction == "aliados" end

-- predio onde voce esta (ou o mais perto, ate 12 tiles)
local function buildingSquareNear(player)
    local sq = player:getCurrentSquare()
    if sq and sq:getBuilding() then return sq end
    local cell = getCell()
    for r = 1, 12 do
        for dx = -r, r do
            for dy = -r, r do
                if math.abs(dx) == r or math.abs(dy) == r then
                    local s = cell:getGridSquare(math.floor(player:getX()) + dx, math.floor(player:getY()) + dy, math.floor(player:getZ()))
                    if s and s:getBuilding() then return s end
                end
            end
        end
    end
    return nil
end

Rem.registerNpcOption("ContextMenu_Rem_Talk", function(npc) RemDialogWindow.open(npc, getPlayer()) end, canTalk)
Rem.registerNpcOption("ContextMenu_Rem_Guard", function(npc) IA.guard(npc) end, isFollower)
Rem.registerNpcOption("ContextMenu_Rem_LootHere", function(npc)
    local player = getPlayer()
    local ok, l = IA.lootHere(npc, buildingSquareNear(player))
    pcall(function() npc.z:Say(IA.text(l)) end)
end, isFollower)
Rem.registerNpcOption("ContextMenu_Rem_Release", function(npc) IA.release(npc, getPlayer()) end, function(npc)
    return isFollower(npc) and npc.rec.recruited == true
end)
