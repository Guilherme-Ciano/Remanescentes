-- Remanescentes - janelas de conversa e de troca (a logica fica em
-- shared/Remanescentes/Rem_Interact.lua).
--
-- Conversa: retrato (icone da profissao sobre a cor da faccao), nome, profissao e
--   arquetipo, selo da faccao, atitude e barra de reputacao a esquerda; historico da conversa
--   e opcoes numeradas a direita. As respostas tambem aparecem sobre a cabeca do NPC.
--   NAO usar ISUI3DModel aqui: com roupa de NPC o UI3DModel fica sem modelInstance e lanca
--   NullPointerException no render do Java a cada quadro (o Lua nao consegue capturar), o
--   que derruba o desenho da interface inteira.
-- Ficha: retrato, identidade, vida, moral, municao e barras de personalidade.
-- Troca: suas coisas x as deles, com icone, categoria e valor; do que o grupo precisa e a
--   margem deles; totais coloridos; "Trocar" so habilita com troca justa.
require "ISUI/ISCollapsableWindow"
require "ISUI/ISScrollingListBox"
require "ISUI/ISButton"
require "ISUI/ISRichTextPanel"
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_Interact"
require "Remanescentes/Rem_MapMarks"
require "Remanescentes/Rem_Companion"
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

-- Icone da profissao do jogo (o mesmo da criacao de personagem), com cache.
local profTex = {}
local function professionTexture(rec)
    local id = rec.profession
    if not id then return nil end
    if profTex[id] ~= nil then return profTex[id] or nil end
    local tex = false
    pcall(function()
        local list = CharacterProfessionDefinition.getProfessions()
        for i = 0, list:size() - 1 do
            local def = list:get(i)
            if tostring(def:getType()) == id or (rec.professionUI and def:getUIName() == getText(rec.professionUI)) then
                tex = def:getTexture() or false
                break
            end
        end
    end)
    profTex[id] = tex
    return tex or nil
end

local function initials(name)
    local out = ""
    for w in tostring(name or "?"):gmatch("%S+") do
        out = out .. w:sub(1, 1):upper()
        if #out >= 2 then break end
    end
    return out
end

-- Retrato 2D: fundo na cor da faccao, icone da profissao (ou iniciais) e moldura.
local function drawPortrait(ui, x, y, w, h, rec)
    local c = factionColor(rec.faction)
    local steps = 12
    for i = 0, steps - 1 do
        local k = 0.18 + 0.22 * (1 - i / steps)
        ui:drawRect(x, y + h * i / steps, w, h / steps + 1, 1, c[1] * k, c[2] * k, c[3] * k)
    end
    local tex = professionTexture(rec)
    local size = math.min(w, h) - 40
    if tex then
        ui:drawTextureScaledAspect(tex, x + (w - size) / 2, y + (h - size) / 2 - 8, size, size, 1, 1, 1, 1)
    else
        local t = initials(rec.name)
        local tw = getTextManager():MeasureStringX(UIFont.Large, t)
        ui:drawText(t, x + (w - tw) / 2, y + h / 2 - 20, c[1] * 0.4 + 0.6, c[2] * 0.4 + 0.6, c[3] * 0.4 + 0.6, 1, UIFont.Large)
    end
    -- faixa inferior com a faccao
    ui:drawRect(x, y + h - FONT_SMALL - 8, w, FONT_SMALL + 8, 0.85, c[1] * 0.55, c[2] * 0.55, c[3] * 0.55)
    local fname = getText("IGUI_Rem_Faction_" .. tostring(rec.faction))
    local fw = getTextManager():MeasureStringX(UIFont.Small, fname)
    ui:drawText(fname, x + (w - fw) / 2, y + h - FONT_SMALL - 4, 1, 1, 1, 1, UIFont.Small)
    ui:drawRectBorder(x, y, w, h, 1, c[1] * 0.6 + 0.3, c[2] * 0.6 + 0.3, c[3] * 0.6 + 0.3)
end

-- ---------------------------------------------------------------- consequencias
-- Enquanto uma escolha e resolvida, guardamos o que ela mudou (reputacao, vinculo, mapa)
-- para mostrar na conversa: "[Reputacao com Familia Silva: +15 (agora 27)]".
local capture = nil
Rem.on("reputationChanged", function(key, old, new)
    if capture then table.insert(capture, { kind = "rep", key = key, delta = new - old, value = new }) end
end)
Rem.on("bondChanged", function(rec, delta)
    if capture then table.insert(capture, { kind = "bond", rec = rec, delta = delta, value = rec.bond or 0 }) end
end)
Rem.on("mapMarked", function()
    if capture then table.insert(capture, { kind = "map" }) end
end)

local function keyOf(rec) return rec.groupId or ("f:" .. tostring(rec.faction)) end

local function groupLabel(rec)
    local g = rec.groupId and Rem.getStore().groups[rec.groupId]
    return g and tostring(g.name or g.id) or getText("IGUI_Rem_Faction_" .. tostring(rec.faction))
end

-- Linhas de sistema do que a escolha mudou para ESTA pessoa e o grupo dela.
local function effectLines(list, npc)
    local out = {}
    local rep, bond, map = nil, nil, false
    for _, e in ipairs(list or {}) do
        if e.kind == "rep" and e.key == keyOf(npc.rec) then
            rep = rep or { delta = 0 }
            rep.delta, rep.value = rep.delta + e.delta, e.value
        elseif e.kind == "bond" and e.rec == npc.rec then
            bond = bond or { delta = 0 }
            bond.delta, bond.value = bond.delta + e.delta, e.value
        elseif e.kind == "map" then
            map = true
        end
    end
    if rep and math.floor(rep.delta) ~= 0 then
        table.insert(out, { text = getText("IGUI_Rem_Fx_rep", groupLabel(npc.rec), string.format("%+d", math.floor(rep.delta)),
            tostring(math.floor(rep.value))), good = rep.delta > 0 })
    end
    if bond and math.floor(bond.delta) ~= 0 then
        table.insert(out, { text = getText("IGUI_Rem_Fx_bond", tostring(npc.rec.name), string.format("%+d", math.floor(bond.delta)),
            tostring(math.floor(bond.value))), good = bond.delta > 0 })
    end
    if map then table.insert(out, { text = getText("IGUI_Rem_Fx_map"), good = true }) end
    return out
end

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
    if Rem.Bonds then Rem.Bonds.talked(npc) end   -- conversar aproxima (uma vez por dia)
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

function RemDialogWindow:push(who, text, tone)
    table.insert(self.history, { who = who, text = text, good = tone == "good", bad = tone == "bad" })
    while #self.history > HISTORY do table.remove(self.history, 1) end
    local name = tostring(self.npc.rec.name or "?")
    local parts = {}
    for _, e in ipairs(self.history) do
        if e.who == "sys" then
            table.insert(parts, (e.bad and rich(0.95, 0.6, 0.45) or (e.good and rich(0.55, 0.9, 0.55) or rich(0.65, 0.65, 0.65)))
                .. "[" .. e.text .. "]")
        elseif e.who == "you" then
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
    self.npc.speech = nil          -- a resposta da conversa substitui a fala solta de antes
    Rem.speak(self.npc, text)
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
    local h = math.max(y + PAD + BTN_H + PAD, self:titleBarHeight() + PAD + 440)
    self:setHeight(h)
    self.byeButton:setY(h - PAD - BTN_H)
end

function RemDialogWindow:onOption(button)
    local id = button.internal
    if id == "bye" then
        local l = IA.finalize({ key = "IGUI_Rem_Talk_bye", args = {} }, self.npc)
        Rem.speak(self.npc, IA.text(l))
        self:close()
        return
    end
    self:push("you", getText("IGUI_Rem_Opt_" .. id))
    if id == "trade" then
        RemTradeWindow.open(self.npc, self.player)
        return
    end
    capture = {}
    local ok, l = pcall(IA.choose, id, self.npc, self.player)
    local fx = capture
    capture = nil
    if not ok then
        Rem.log("ERRO na conversa (" .. tostring(id) .. "): " .. tostring(l))
        return
    end
    self:npcSays(l)
    if id == "order_release" then self:close() return end
    -- o que mudou, e por que nao deu (quando nao deu)
    for _, e in ipairs(effectLines(fx, self.npc)) do self:push("sys", e.text, e.good and "good" or "bad") end
    if IA.last and IA.last.id == id and not IA.last.ok then
        local h = IA.hint(id, self.npc)
        if h then self:push("sys", getText(h.key, unpack(h.args or {}))) end
    end
end

function RemDialogWindow:render()
    ISCollapsableWindow.render(self)
    local rec = self.npc.rec
    local top = self:titleBarHeight() + PAD
    drawPortrait(self, PAD, top, self.leftW, 220, rec)
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
    y = y + FONT_SMALL + 2
    if Rem.Persona then
        self:drawText(getText("IGUI_Rem_Profile_mood") .. ": ", PAD, y, 0.75, 0.75, 0.75, 1, UIFont.Small)
        self:drawText(getText("IGUI_Rem_Mood_" .. Rem.Persona.mood(rec, self.npc)), PAD + 70, y, 0.85, 0.85, 0.85, 1, UIFont.Small)
        y = y + FONT_SMALL + 2
    end
    y = y + 4
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
    capture = {}
    local ok, l = IA.trade(self.player, self.npc, marked(self.mine), marked(self.theirs))
    local fx = capture
    capture = nil
    IA.finalize(l, self.npc)
    self:refresh()
    self.message = IA.text(l)
    self.messageOk = ok
    self.npc.speech = nil
    Rem.speak(self.npc, self.message)
    if RemDialogWindow.instance and RemDialogWindow.instance.npc == self.npc then
        local d = RemDialogWindow.instance
        d:push("npc", self.message)
        for _, e in ipairs(effectLines(fx, self.npc)) do d:push("sys", e.text, e.good and "good" or "bad") end
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
    if #self.theirs.items == 0 then
        self:drawText(getText("IGUI_Rem_Trade_nothing"), self.theirs:getX() + 8, self.theirs:getY() + 8, 0.6, 0.6, 0.6, 1, UIFont.Small)
    end
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

-- ---------------------------------------------------------------- ficha
RemProfileWindow = ISCollapsableWindow:derive("RemProfileWindow")
local TRAITS = { "agressividade", "confianca", "coragem", "ganancia", "lealdade" }

function RemProfileWindow.open(npc)
    if RemProfileWindow.instance then RemProfileWindow.instance:close() end
    local w = RemProfileWindow:new(getCore():getScreenWidth() / 2 - 270, getCore():getScreenHeight() / 2 - 320, 540, 640)
    w.npc = npc
    w:initialise()
    w:addToUIManager()
    RemProfileWindow.instance = w
    return w
end

function RemProfileWindow:new(x, y, width, height)
    local o = ISCollapsableWindow.new(self, x, y, width, height)
    o.title = getText("IGUI_Rem_Profile_title")
    o.resizable = false
    return o
end

-- barra horizontal com rotulo e valor
local function bar(ui, x, y, w, label, frac, valueText, r, g, b)
    ui:drawText(label, x, y, 0.75, 0.75, 0.75, 1, UIFont.Small)
    local vw = getTextManager():MeasureStringX(UIFont.Small, valueText)
    ui:drawText(valueText, x + w - vw, y, 0.9, 0.9, 0.9, 1, UIFont.Small)
    local by = y + FONT_SMALL + 2
    ui:drawRect(x, by, w, 6, 0.8, 0.15, 0.15, 0.15)
    ui:drawRect(x, by, w * math.max(0, math.min(1, frac)), 6, 0.9, r, g, b)
    return by + 6 + 6
end

-- barra de -100 a 100 com o zero no meio (reputacao, vinculo)
local function centeredBar(ui, x, y, w, value)
    local half = w / 2
    local fill = math.min(1, math.abs(value) / 100) * half
    ui:drawRect(x, y, w, 8, 0.8, 0.15, 0.15, 0.15)
    if value >= 0 then
        ui:drawRect(x + half, y, fill, 8, 0.9, 0.3, 0.75, 0.3)
    else
        ui:drawRect(x + half - fill, y, fill, 8, 0.9, 0.8, 0.25, 0.2)
    end
    ui:drawRect(x + half, y - 2, 1, 12, 1, 0.9, 0.9, 0.9)
    return y + 8 + 8
end

local MOOD_COLOR = { calmo = { 0.8, 0.8, 0.8 }, animado = { 0.45, 0.85, 0.45 }, ferido = { 0.95, 0.45, 0.35 },
    doente = { 0.75, 0.85, 0.3 }, luto = { 0.6, 0.6, 0.9 }, faminto = { 0.95, 0.75, 0.35 }, abatido = { 0.6, 0.6, 0.6 },
    cansado = { 0.7, 0.65, 0.85 } }

-- Linhas extras da Ficha: habilidades, ferimento, amigos e rivais. { texto, r, g, b }
function RemProfileWindow.extraLines(rec)
    local out = {}
    if Rem.Skills then
        local s = Rem.Skills.summary(rec)
        if s ~= "" then table.insert(out, { getText("IGUI_Rem_Profile_skills", s), 0.75, 0.85, 0.95 }) end
    end
    if rec.wound and Rem.Wounds then
        local days = math.ceil(Rem.Wounds.hoursLeft(rec) / 24 * 10) / 10
        table.insert(out, { getText("IGUI_Rem_Profile_wound", getText("IGUI_Rem_Wound_" .. rec.wound.kind), tostring(days)), 0.95, 0.5, 0.4 })
    end
    if rec.trauma and rec.trauma.level > 0 then
        table.insert(out, { getText("IGUI_Rem_Profile_trauma", getText("IGUI_Rem_Trauma_" .. rec.trauma.kind), tostring(rec.trauma.level)), 0.85, 0.6, 0.9 })
    end
    if Rem.Friends then
        local friends, rivals = Rem.Friends.list(rec)
        if #friends > 0 then table.insert(out, { getText("IGUI_Rem_Profile_friends", table.concat(friends, ", ")), 0.5, 0.9, 0.5 }) end
        if #rivals > 0 then table.insert(out, { getText("IGUI_Rem_Profile_rivals", table.concat(rivals, ", ")), 0.95, 0.6, 0.4 }) end
    end
    return out
end

function RemProfileWindow:render()
    ISCollapsableWindow.render(self)
    local npc = self.npc
    local rec = npc.rec
    local P, BD = Rem.Persona, Rem.Bonds
    if P then P.ensure(rec) end
    local top = self:titleBarHeight() + PAD
    local pw, ph = 150, 200
    drawPortrait(self, PAD, top, pw, ph, rec)
    local x = PAD * 2 + pw
    local w = self.width - x - PAD
    local y = top
    self:drawText(tostring(rec.name or "?"), x, y, 1, 1, 1, 1, UIFont.Medium)
    y = y + FONT_MEDIUM + 2
    local prof = rec.professionUI and getText(rec.professionUI) or ""
    self:drawText(prof .. (rec.age and (", " .. tostring(math.floor(rec.age))) or ""), x, y, 0.8, 0.8, 0.8, 1, UIFont.Small)
    y = y + FONT_SMALL + 1
    local sub = getText("IGUI_Rem_Arch_" .. tostring(rec.archetype or "brigao"))
    if rec.quirk then sub = sub .. "  |  " .. getText("IGUI_Rem_Profile_quirk") .. ": " .. getText("IGUI_Rem_Quirk_" .. rec.quirk) end
    self:drawText(sub, x, y, 0.6, 0.6, 0.6, 1, UIFont.Small)
    y = y + FONT_SMALL + 6
    local att = attitudeOf(rec)
    local ac = ATT_COLOR[att] or ATT_COLOR.neutro
    self:drawText(getText("IGUI_Rem_Talk_attitude") .. ": ", x, y, 0.75, 0.75, 0.75, 1, UIFont.Small)
    self:drawText(getText("IGUI_Rem_Att_" .. att) .. "  (" .. tostring(math.floor(Rem.repOf and Rem.repOf(rec) or 0)) .. ")",
        x + 70, y, ac[1], ac[2], ac[3], 1, UIFont.Small)
    y = y + FONT_SMALL + 2
    if P then
        local mood = P.mood(rec, npc)
        local mc = MOOD_COLOR[mood] or MOOD_COLOR.calmo
        local label = getText("IGUI_Rem_Mood_" .. mood)
        if mood == "luto" and rec.griefFor then label = label .. " (" .. tostring(rec.griefFor) .. ")" end
        self:drawText(getText("IGUI_Rem_Profile_mood") .. ": ", x, y, 0.75, 0.75, 0.75, 1, UIFont.Small)
        self:drawText(label, x + 70, y, mc[1], mc[2], mc[3], 1, UIFont.Small)
        y = y + FONT_SMALL + 2
    end
    y = y + 4
    local hp = 1
    pcall(function() hp = Rem.healthFraction(npc) end)
    y = bar(self, x, y, w, getText("IGUI_Rem_Profile_health"), hp, tostring(math.floor(hp * 100 + 0.5)) .. "%", 0.85 - hp * 0.5, 0.3 + hp * 0.5, 0.3)
    local moral = math.floor(rec.moral or 50)
    y = bar(self, x, y, w, getText("IGUI_Rem_Profile_morale"), moral / 100, tostring(moral), 0.45, 0.6, 0.9)
    self:drawText(getText("IGUI_Rem_Profile_level", tostring(rec.level or 0), tostring(rec.kills or 0)), x, y, 0.8, 0.8, 0.8, 1, UIFont.Small)
    y = y + FONT_SMALL + 2
    if rec.firearm then
        self:drawText(getText("IGUI_Rem_Profile_ammo", tostring(math.floor(rec.ammo or 0))), x, y, 0.95, 0.8, 0.4, 1, UIFont.Small)
    end

    -- daqui para baixo, largura toda
    local fullW = self.width - PAD * 2
    y = top + ph + PAD
    if rec.faction ~= "aliados" or (rec.bond or 0) ~= 0 then
        local bond = math.floor(rec.bond or 0)
        self:drawText(getText("IGUI_Rem_Profile_bond") .. ": " .. tostring(bond), PAD, y, 0.75, 0.75, 0.75, 1, UIFont.Small)
        y = centeredBar(self, PAD, y + FONT_SMALL + 3, fullW, bond)
    end
    for _, l in ipairs(RemProfileWindow.extraLines(rec)) do
        self:drawText(l[1], PAD, y, l[2], l[3], l[4], 1, UIFont.Small)
        y = y + FONT_SMALL + 2
    end
    self:drawText(getText("IGUI_Rem_Profile_personality"), PAD, y, 0.7, 0.7, 0.7, 1, UIFont.Small)
    y = y + FONT_SMALL + 4
    local colW = (fullW - PAD) / 2
    local rowH = FONT_SMALL + 16
    for i, t in ipairs(TRAITS) do
        local v = Rem.trait(rec, t)
        local cx = PAD + ((i - 1) % 2) * (colW + PAD)
        local cy = y + math.floor((i - 1) / 2) * rowH
        bar(self, cx, cy, colW, getText("IGUI_Rem_Trait_" .. t), v / 10, tostring(v) .. "/10", 0.75, 0.65, 0.35)
    end
    y = y + math.ceil(#TRAITS / 2) * rowH + 4

    -- lembrancas (as 3 mais recentes)
    self:drawText(getText("IGUI_Rem_Profile_memories"), PAD, y, 0.7, 0.7, 0.7, 1, UIFont.Small)
    y = y + FONT_SMALL + 2
    local mem = rec.mem or {}
    if #mem == 0 then
        self:drawText(getText("IGUI_Rem_Profile_nomem"), PAD + 8, y, 0.55, 0.55, 0.55, 1, UIFont.Small)
        y = y + FONT_SMALL + 1
    else
        for i = #mem, math.max(1, #mem - 2), -1 do
            local bad = BD and BD.BAD[mem[i].k]
            self:drawText("- " .. getText("IGUI_Rem_Mem_" .. tostring(mem[i].k)), PAD + 8, y, bad and 0.95 or 0.6, bad and 0.5 or 0.9, 0.5, 1, UIFont.Small)
            y = y + FONT_SMALL + 1
        end
    end
    y = y + 6

    -- historia (so depois que ela contar)
    self:drawText(getText("IGUI_Rem_Profile_story"), PAD, y, 0.7, 0.7, 0.7, 1, UIFont.Small)
    y = y + FONT_SMALL + 2
    if rec.toldStory and rec.story then
        local lines = { rec.professionUI and getText("IGUI_Rem_Story_intro", getText(rec.professionUI)) or getText("IGUI_Rem_Story_intro_none"),
            getText("IGUI_Rem_Story_lost_" .. tostring(rec.story.lost)), getText("IGUI_Rem_Story_goal_" .. tostring(rec.story.goal)) }
        for _, t in ipairs(lines) do
            self:drawText(t, PAD + 8, y, 0.85, 0.85, 0.8, 1, UIFont.Small)
            y = y + FONT_SMALL + 1
        end
    else
        self:drawText(getText("IGUI_Rem_Profile_nostory"), PAD + 8, y, 0.55, 0.55, 0.55, 1, UIFont.Small)
        y = y + FONT_SMALL + 1
    end
    self.contentBottom = y
end

function RemProfileWindow:update()
    ISCollapsableWindow.update(self)
    local npc = self.npc
    if not npc or not Rem.active[npc.z] or npc.z:isDead() then self:close() end
end

function RemProfileWindow:close()
    ISCollapsableWindow.close(self)
    self:removeFromUIManager()
    if RemProfileWindow.instance == self then RemProfileWindow.instance = nil end
end

Rem.showProfile = function(npc) RemProfileWindow.open(npc) end

-- ---------------------------------------------------------------- menu do NPC
local function canTalk(npc) return not Rem.isHostileToPlayer(npc) or npc.rec.surrendered end
local function isFollower(npc) return npc.rec.faction == "aliados" end

Rem.registerNpcOption("ContextMenu_Rem_Talk", function(npc) RemDialogWindow.open(npc, getPlayer()) end, canTalk)
Rem.registerNpcOption("ContextMenu_Rem_Guard", function(npc) IA.guard(npc) end, isFollower)
Rem.registerNpcOption("ContextMenu_Rem_LootHere", function(npc)
    local player = getPlayer()
    local ok, l = IA.lootHere(npc, Rem.Companion.buildingNear(player))
    Rem.speak(npc, IA.text(l))
end, isFollower)
Rem.registerNpcOption("ContextMenu_Rem_Release", function(npc) IA.release(npc, getPlayer()) end, function(npc)
    return isFollower(npc) and npc.rec.recruited == true
end)
