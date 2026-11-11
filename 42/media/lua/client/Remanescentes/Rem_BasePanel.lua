-- Remanescentes - painel da sua base (clique direito -> Primeiros Dias -> Painel da base).
-- Em cima: estoque, defesa, obra atual, escala de vigia da noite, prisioneiros.
-- Embaixo: um botao por morador (nome, tarefa, humor, fome e cansaco); clicar troca a
-- tarefa dele para a proxima (fortificar -> vigiar -> buscar -> material -> descansar),
-- esteja ele em cena ou longe.
require "ISUI/ISCollapsableWindow"
require "ISUI/ISRichTextPanel"
require "ISUI/ISButton"
require "ISUI/ISTextBox"
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_PlayerBase"
local Rem = Remanescentes

local PAD, ROW_H, SUMMARY_H = 10, 26, 250
local function rgb(r, g, b) return string.format(" <RGB:%.2f,%.2f,%.2f> ", r, g, b) end
local TITLE, TEXT, DIM, GOOD, BAD = rgb(1, 0.85, 0.45), rgb(0.9, 0.9, 0.9), rgb(0.6, 0.6, 0.6), rgb(0.5, 0.9, 0.5), rgb(0.95, 0.45, 0.4)
local NL = " <LINE> "

RemBasePanel = ISCollapsableWindow:derive("RemBasePanel")


-- Linha de um morador (texto do botao).
function RemBasePanel.memberLabel(rec)
    local mood = Rem.Persona and getText("IGUI_Rem_Mood_" .. Rem.Persona.mood(rec)) or ""
    local job = getText("IGUI_Rem_Job_" .. tostring(rec.job or "rest"))
    if Rem.Watch and Rem.Watch.onWatch(rec) then job = job .. " (" .. getText("IGUI_Rem_Panel_onwatch") .. ")" end
    local label = getText("IGUI_Rem_Panel_member", tostring(rec.name), job, mood,
        tostring(math.floor(rec.fome or 0)), tostring(math.floor(rec.cansaco or 0)))
    -- ferimento e melhor habilidade
    if rec.wound then label = label .. "  [" .. getText("IGUI_Rem_Wound_" .. rec.wound.kind) .. "]" end
    if rec.trauma and rec.trauma.level > 0 then label = label .. "  [" .. getText("IGUI_Rem_Trauma_" .. rec.trauma.kind) .. "]" end
    if Rem.Skills then
        local s, l = Rem.Skills.best(rec)
        if s then label = label .. "  " .. getText("IGUI_Rem_Skill_" .. s) .. " " .. tostring(l) end
    end
    return label
end

-- Resumo (separado da janela para poder ser testado).
function RemBasePanel.compose(player)
    local PB = Rem.PlayerBase
    local g = PB.get()
    local parts = {}
    local function add(t) table.insert(parts, t) end
    if not g then return DIM .. getText("IGUI_Rem_Journal_nobase") end
    local h = g.home
    local list = PB.members(g)
    local n = #list
    local days = (n > 0) and math.floor((g.supplies or 0) / n * 10) / 10 or 0
    add(TITLE .. tostring(g.name) .. NL)
    add(TITLE .. getText("IGUI_Rem_Panel_people", tostring(n), tostring(PB.CFG.MAX_MEMBERS)) .. NL)
    add(((days < 1) and BAD or TEXT) .. getText("IGUI_Rem_Panel_food", tostring(days)) .. NL)
    add(TEXT .. getText("IGUI_Rem_Panel_materials", tostring(math.floor(Rem.Director.materials(g)))) .. NL)
    if Rem.BaseEvents then
        add(TEXT .. getText("IGUI_Rem_Panel_defense", tostring(math.floor(Rem.BaseEvents.defense(g) * 10) / 10)) .. NL)
        add(TEXT .. getText("IGUI_Rem_Panel_morale", tostring(math.floor(Rem.BaseEvents.morale(g)))) .. NL)
    end
    -- obra
    local BB = Rem.BaseBuild
    if BB and h.plan then
        local cur = nil
        for _, p in ipairs(BB.PROJECTS) do if (h.plan[p] or 0) > 0 then cur = p break end end
        add(TEXT .. getText("IGUI_Rem_Journal_base_works", getText("IGUI_Rem_Project_" .. tostring(cur or "none")),
            tostring(h.fenceBuilt or 0), tostring(h.fenceTotal or 0), tostring(#(h.cars or {}))) .. NL)
    end
    -- gerador e perimetro (Rem_Fuel, Rem_Traps)
    if Rem.Fuel and Rem.Fuel.has(g) then
        add(((Rem.Fuel.amount(g) > 0) and TEXT or BAD) .. getText("IGUI_Rem_Panel_fuel", tostring(math.floor(Rem.Fuel.amount(g)))) .. NL)
    end
    if (h.cans or 0) > 0 or (h.traps or 0) > 0 then
        add(TEXT .. getText("IGUI_Rem_Panel_traps", tostring(h.cans or 0), tostring(h.traps or 0)) .. NL)
    end
    -- horta (Rem_PersonalQuests)
    if g.garden then
        local days = math.floor((Rem.worldHours() - g.garden.since) / 24)
        add(GOOD .. getText("IGUI_Rem_Panel_garden", tostring(days)) .. NL)
    end
    -- conselho e diplomacia
    if g.lastVote then
        local v = g.lastVote
        add(((v.passed and GOOD) or BAD) .. getText("IGUI_Rem_Panel_vote", getText("IGUI_Rem_Council_" .. v.kind), tostring(v.yes), tostring(v.no)) .. NL)
    end
    if Rem.Diplomacy then
        local d = Rem.Diplomacy.summary()
        if #d.allies > 0 then add(TEXT .. getText("IGUI_Rem_Panel_allies", table.concat(d.allies, ", ")) .. NL) end
        if #d.pacts > 0 then add(TEXT .. getText("IGUI_Rem_Panel_pacts", table.concat(d.pacts, ", ")) .. NL) end
        if #d.paid > 0 then add(DIM .. getText("IGUI_Rem_Panel_paid", table.concat(d.paid, ", ")) .. NL) end
    end
    -- vigia
    if Rem.Watch then
        add(NL .. TITLE .. getText("IGUI_Rem_Panel_watch") .. NL)
        local any = false
        for _, r in ipairs(Rem.Watch.roster(g)) do
            local s = Rem.Watch.CFG.SHIFTS[r.shift]
            local who = r.rec and tostring(r.rec.name) or nil
            if who then any = true end
            add(((who and TEXT) or BAD) .. getText("IGUI_Rem_Panel_shift", tostring(s[1]), tostring(s[2] % 24),
                who or getText("IGUI_Rem_Panel_nobody")) .. NL)
        end
        if not any then add(DIM .. getText("IGUI_Rem_Panel_watch_hint") .. NL) end
        if Rem.Watch.alarmOn(g) then add(BAD .. getText("IGUI_Rem_Panel_alarm") .. NL) end
    end
    -- prisioneiros
    if Rem.Prisoners then
        local pr = Rem.Prisoners.list(g)
        if #pr > 0 then
            add(NL .. TITLE .. getText("IGUI_Rem_Panel_prisoners") .. NL)
            for _, p in ipairs(pr) do
                local held = math.floor((Rem.worldHours() - (p.heldSince or Rem.worldHours())) / 24 * 10) / 10
                local band = Rem.Prisoners.bandOf(p)
                add(TEXT .. tostring(p.name) .. DIM .. "  -  " .. getText("IGUI_Rem_Panel_prisoner", tostring(held),
                    band and Rem.Journal.groupName(band) or getText("IGUI_Rem_Panel_noband"),
                    p.talked and getText("IGUI_Rem_Panel_talked") or "") .. NL)
            end
        end
    end
    add(NL .. DIM .. getText("IGUI_Rem_Panel_hint") .. NL)
    return table.concat(parts)
end

function RemBasePanel.open(player)
    if RemBasePanel.instance then RemBasePanel.instance:close() end
    local w = RemBasePanel:new(getCore():getScreenWidth() / 2 - 320, getCore():getScreenHeight() / 2 - 300, 640, 600)
    w.player = player or getPlayer()
    w:initialise()
    w:addToUIManager()
    RemBasePanel.instance = w
    w:refresh()
    return w
end

function RemBasePanel:new(x, y, width, height)
    local o = ISCollapsableWindow.new(self, x, y, width, height)
    o.title = getText("IGUI_Rem_Panel_title")
    o.resizable = false
    o.rows = {}
    return o
end

function RemBasePanel:createChildren()
    ISCollapsableWindow.createChildren(self)
    local top = self:titleBarHeight() + PAD
    self.panel = ISRichTextPanel:new(PAD, top, self.width - PAD * 2, SUMMARY_H)
    self.panel:initialise()
    self.panel.background = true
    self.panel.backgroundColor = { r = 0.05, g = 0.05, b = 0.05, a = 0.75 }
    self.panel.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 1 }
    self.panel.autosetheight = false
    self.panel.clip = true
    pcall(function() self.panel:addScrollBars() end)
    self:addChild(self.panel)
    self.rowsTop = top + SUMMARY_H + PAD + 26
    -- dar nome ao grupo
    self.renameBtn = ISButton:new(PAD, top + SUMMARY_H + PAD - 2, 200, 22, getText("IGUI_Rem_Panel_rename"), self, RemBasePanel.onRename)
    self.renameBtn:initialise()
    self:addChild(self.renameBtn)
end

-- Caixa de texto do jogo para o nome do grupo.
function RemBasePanel.askName(player)
    local current = Rem.Diplomacy and Rem.Diplomacy.name() or ""
    local ok = pcall(function()
        local box = ISTextBox:new(getCore():getScreenWidth() / 2 - 140, getCore():getScreenHeight() / 2 - 60, 280, 140,
            getText("IGUI_Rem_Panel_rename_prompt"), current, nil, function(_, button)
                if button.internal == "OK" then Rem.Diplomacy.rename(button.parent.entry:getText()) end
                if RemBasePanel.instance then RemBasePanel.instance:refresh() end
            end)
        box:initialise()
        box:addToUIManager()
    end)
    return ok
end

function RemBasePanel:onRename() RemBasePanel.askName(self.player) end

-- Um botao por morador (refeito a cada atualizacao).
function RemBasePanel:buildRows()
    for _, b in ipairs(self.rows) do self:removeChild(b) end
    self.rows = {}
    local PB = Rem.PlayerBase
    local g = PB.get()
    if not g then return end
    local y = self.rowsTop or 300
    for _, rec in ipairs(PB.members(g)) do
        if y + ROW_H > self.height - PAD then break end
        local b = ISButton:new(PAD, y, self.width - PAD * 2, ROW_H - 4, RemBasePanel.memberLabel(rec), self, RemBasePanel.onMember)
        b.rec = rec
        b:initialise()
        self:addChild(b)
        table.insert(self.rows, b)
        y = y + ROW_H
    end
end

function RemBasePanel:onMember(button)
    local rec = button and button.rec
    if not rec then return end
    Rem.PlayerBase.setJobRec(rec, Rem.PlayerBase.nextJob(rec.job))
    if Rem.Watch then Rem.safe(Rem.Watch.updateRoles, Rem.PlayerBase.get()) end
    self:refresh()
end

function RemBasePanel:refresh()
    self.refreshedAt = Rem.nowMs()
    local ok, text = pcall(RemBasePanel.compose, self.player)
    if not ok then
        Rem.log("ERRO no painel da base: " .. tostring(text))
        text = getText("IGUI_Rem_Journal_error")
    end
    self.panel:setText(text)
    self.panel:paginate()
    local okRows, err = pcall(self.buildRows, self)
    if not okRows then Rem.log("ERRO no painel da base: " .. tostring(err)) end
end

function RemBasePanel:update()
    ISCollapsableWindow.update(self)
    if Rem.nowMs() - (self.refreshedAt or 0) > 4000 then self:refresh() end
end

function RemBasePanel:close()
    ISCollapsableWindow.close(self)
    self:removeFromUIManager()
    if RemBasePanel.instance == self then RemBasePanel.instance = nil end
end

Rem.registerPlayerOption("ContextMenu_Rem_BasePanel", function(player) RemBasePanel.open(player) end,
    function() return Rem.PlayerBase.get() ~= nil end)
Rem.registerPlayerOption("ContextMenu_Rem_NameGroup", function(player) RemBasePanel.askName(player) end,
    function() return Rem.PlayerBase.get() ~= nil and Rem.Diplomacy ~= nil end)
