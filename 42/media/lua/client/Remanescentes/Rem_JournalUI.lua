-- Remanescentes - janela do diario (clique direito -> Primeiros Dias -> Diario).
-- Mostra: o dia do colapso, seus aliados, os grupos que voce conhece (reputacao, quantos
-- sao, o que estao fazendo, onde ficam), as missoes em aberto e os ultimos acontecimentos.
require "ISUI/ISCollapsableWindow"
require "ISUI/ISRichTextPanel"
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_Journal"
require "Remanescentes/Rem_Interact"
local Rem = Remanescentes
local JN = Rem.Journal

local PAD = 10
local function rgb(r, g, b) return string.format(" <RGB:%.2f,%.2f,%.2f> ", r, g, b) end
local TITLE, TEXT, DIM, GOOD, BAD = rgb(1, 0.85, 0.45), rgb(0.9, 0.9, 0.9), rgb(0.6, 0.6, 0.6), rgb(0.5, 0.9, 0.5), rgb(0.95, 0.45, 0.4)
local NL = " <LINE> "

RemJournalWindow = ISCollapsableWindow:derive("RemJournalWindow")

-- Texto do diario (separado da janela para poder ser testado).
function JN.compose(player)
    local store = Rem.getStore()
    local parts = {}
    local function add(t) table.insert(parts, t) end
    local day = Rem.Timeline and math.floor(Rem.Timeline.day()) + 1 or 1
    add(TITLE .. getText("IGUI_Rem_Journal_day", tostring(day)) .. NL)

    -- fama (Rem_Fame)
    local title = Rem.Fame and Rem.Fame.title()
    if title then add(DIM .. getText("IGUI_Rem_Journal_famous", getText("IGUI_Rem_Fame_" .. title)) .. NL) end
    -- cronica: os marcos da campanha (Rem_Chronicle)
    local CH = Rem.Chronicle
    if CH and #CH.list() > 0 then
        add(NL .. TITLE .. getText("IGUI_Rem_Journal_chronicle") .. NL)
        for _, e in ipairs(CH.list()) do
            add(DIM .. getText("IGUI_Rem_Journal_dayshort", tostring(CH.dayOf(e.h))) .. "  " .. GOOD
                .. getText("IGUI_Rem_Chapter_" .. e.k) .. NL)
        end
    end

    -- aliados
    add(NL .. TITLE .. getText("IGUI_Rem_Journal_allies") .. NL)
    local allies = {}
    for _, p in pairs(store.people) do if p.faction == "aliados" and not p.groupId then table.insert(allies, p) end end
    table.sort(allies, function(a, b) return tostring(a.name) < tostring(b.name) end)
    if #allies == 0 then add(DIM .. getText("IGUI_Rem_Journal_none") .. NL) end
    for _, p in ipairs(allies) do
        local mood = Rem.Persona and getText("IGUI_Rem_Mood_" .. Rem.Persona.mood(p)) or ""
        add(TEXT .. tostring(p.name) .. DIM .. "  -  " .. getText("IGUI_Rem_Journal_ally", tostring(p.level or 0), mood) .. NL)
    end

    -- sua base
    local PB = Rem.PlayerBase
    local base = PB and PB.get()
    add(NL .. TITLE .. getText("IGUI_Rem_Journal_base") .. NL)
    if not base then
        add(DIM .. getText("IGUI_Rem_Journal_nobase") .. NL)
    else
        local n = #PB.members(base)
        local days = (n > 0) and math.floor((base.supplies or 0) / n * 10) / 10 or 0
        local h = base.home
        local windows = h.windowsTotal and (tostring(h.windowsDone or 0) .. "/" .. tostring(h.windowsTotal)) or "?"
        add(TEXT .. getText("IGUI_Rem_Journal_base_status", tostring(n), tostring(PB.CFG.MAX_MEMBERS), tostring(days),
            tostring(math.floor(Rem.Director.materials(base))), windows) .. NL)
        if player then
            local d = math.floor(Rem.dist2(player:getX(), player:getY(), h.x, h.y) / 10) * 10
            local dir = Rem.Interact.direction(player:getX(), player:getY(), h.x, h.y) or "N"
            add(DIM .. getText("IGUI_Rem_Journal_where", tostring(d), getText("IGUI_Rem_Dir_" .. dir)) .. NL)
        end
        if (base.hungerHours or 0) > 0 then add(BAD .. getText("IGUI_Rem_Journal_base_nofood") .. NL) end
        -- obras
        local BB = Rem.BaseBuild
        if BB and h.plan then
            local cur = nil
            for _, p in ipairs(BB.PROJECTS) do if (h.plan[p] or 0) > 0 then cur = p break end end
            add(TEXT .. getText("IGUI_Rem_Journal_base_works", getText("IGUI_Rem_Project_" .. tostring(cur or "none")),
                tostring(h.fenceBuilt or 0), tostring(h.fenceTotal or 0), tostring(#(h.cars or {}))) .. NL)
        end
        for _, p in ipairs(PB.members(base)) do
            local mood = Rem.Persona and getText("IGUI_Rem_Mood_" .. Rem.Persona.mood(p)) or ""
            add(TEXT .. "  " .. tostring(p.name) .. DIM .. "  -  " .. getText("IGUI_Rem_Job_" .. tostring(p.job or "rest"))
                .. ", " .. mood .. NL)
        end
    end

    -- grupos conhecidos
    add(NL .. TITLE .. getText("IGUI_Rem_Journal_groups") .. NL)
    local groups = {}
    for _, g in pairs(store.groups) do if JN.knows(g) and not g.player then table.insert(groups, g) end end
    table.sort(groups, function(a, b) return tostring(a.id) < tostring(b.id) end)
    if #groups == 0 then add(DIM .. getText("IGUI_Rem_Journal_none") .. NL) end
    for _, g in ipairs(groups) do
        local rep = math.floor(Rem.getRep(g.id))
        local color = (rep >= 20 and GOOD) or (rep <= -40 and BAD) or TEXT
        local tag = g.allied and (GOOD .. " (" .. getText("IGUI_Rem_Journal_allied") .. ")" .. DIM) or ""
        add(color .. JN.groupName(g) .. tag .. DIM .. "  [" .. getText("IGUI_Rem_Faction_" .. tostring(g.faction)) .. "]  "
            .. TEXT .. getText("IGUI_Rem_Journal_group", tostring(rep), tostring(#g.members),
                getText("IGUI_Rem_GoalName_" .. tostring(g.goal or "routine"))))
        if g.home and player then
            local d = math.floor(Rem.dist2(player:getX(), player:getY(), g.home.x, g.home.y) / 10) * 10
            local dir = Rem.Interact.direction(player:getX(), player:getY(), g.home.x, g.home.y) or "N"
            add(DIM .. "  (" .. getText("IGUI_Rem_Journal_where", tostring(d), getText("IGUI_Rem_Dir_" .. dir)) .. ")")
        end
        local gh = g.home
        if Rem.BaseBuild and gh and gh.plan and not gh.planEstimated then
            local cur = nil
            for _, p in ipairs(Rem.BaseBuild.projectsFor(g)) do if (gh.plan[p] or 0) > 0 then cur = p break end end
            add(NL .. DIM .. "    " .. getText("IGUI_Rem_Journal_base_works", getText("IGUI_Rem_Project_" .. tostring(cur or "none")),
                tostring(gh.fenceBuilt or 0), tostring(gh.fenceTotal or 0), tostring(#(gh.cars or {}))))
        end
        add(NL)
    end

    -- missoes
    add(NL .. TITLE .. getText("IGUI_Rem_Journal_quests") .. NL)
    local any = false
    for gid, q in pairs(store.quests or {}) do
        local g = store.groups[gid]
        if g then
            any = true
            local left = math.max(0, (q.count or 0) - (q.progress or 0))
            add(TEXT .. JN.groupName(g) .. ": " .. getText("IGUI_Rem_Journal_quest_" .. tostring(q.kind), tostring(left)) .. NL)
        end
    end
    if store.siege and store.siege.told then
        any = true
        add(BAD .. getText("IGUI_Rem_Journal_siege", JN.groupName(store.groups[store.siege.group])) .. NL)
    end
    if not any then add(DIM .. getText("IGUI_Rem_Journal_none") .. NL) end

    -- acontecimentos (mais novos primeiro)
    add(NL .. TITLE .. getText("IGUI_Rem_Journal_events") .. NL)
    local list = JN.entries()
    if #list == 0 then add(DIM .. getText("IGUI_Rem_Journal_none") .. NL) end
    local start = (Rem.Timeline and Rem.getStore().timeline and Rem.getStore().timeline.startHours) or 0
    for i = #list, math.max(1, #list - 14), -1 do
        local e = list[i]
        local d = math.max(1, math.floor((e.h - start) / 24) + 1)
        add(DIM .. getText("IGUI_Rem_Journal_dayshort", tostring(d)) .. "  " .. TEXT .. JN.text(e) .. NL)
    end
    return table.concat(parts)
end

function RemJournalWindow.open(player)
    if RemJournalWindow.instance then RemJournalWindow.instance:close() end
    local w = RemJournalWindow:new(getCore():getScreenWidth() / 2 - 300, getCore():getScreenHeight() / 2 - 280, 600, 560)
    w.player = player or getPlayer()
    w:initialise()
    w:addToUIManager()
    RemJournalWindow.instance = w
    w:refresh()
    return w
end

function RemJournalWindow:new(x, y, width, height)
    local o = ISCollapsableWindow.new(self, x, y, width, height)
    o.title = getText("IGUI_Rem_Journal_title")
    o.resizable = false
    return o
end

function RemJournalWindow:createChildren()
    ISCollapsableWindow.createChildren(self)
    local top = self:titleBarHeight() + PAD
    self.panel = ISRichTextPanel:new(PAD, top, self.width - PAD * 2, self.height - top - PAD)
    self.panel:initialise()
    self.panel.background = true
    self.panel.backgroundColor = { r = 0.05, g = 0.05, b = 0.05, a = 0.75 }
    self.panel.borderColor = { r = 0.4, g = 0.4, b = 0.4, a = 1 }
    self.panel.autosetheight = false
    self.panel.clip = true
    pcall(function() self.panel:addScrollBars() end)
    self:addChild(self.panel)
end

function RemJournalWindow:refresh()
    self.refreshedAt = Rem.nowMs()
    local ok, text = pcall(JN.compose, self.player)
    if not ok then
        Rem.log("ERRO no diario: " .. tostring(text))
        text = getText("IGUI_Rem_Journal_error")
    end
    self.panel:setText(text)
    self.panel:paginate()
end

function RemJournalWindow:update()
    ISCollapsableWindow.update(self)
    if Rem.nowMs() - (self.refreshedAt or 0) > 5000 then self:refresh() end
end

function RemJournalWindow:close()
    ISCollapsableWindow.close(self)
    self:removeFromUIManager()
    if RemJournalWindow.instance == self then RemJournalWindow.instance = nil end
end

Rem.registerPlayerOption("ContextMenu_Rem_Journal", function(player) RemJournalWindow.open(player) end)
