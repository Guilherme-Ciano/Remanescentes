-- Remanescentes - escala de vigia da sua base.
--
-- A noite (21h-6h) e dividida em turnos (SHIFTS). Quem tem a tarefa "vigiar" reveza: um
-- fica no posto da porta, os outros vigias dormem. Com um vigia so, ele passa a noite em
-- claro (e cansa - Rem_Needs); cansado demais, pode cochilar no posto.
-- De dia, todos os vigias ficam no posto.
--
-- Alarme: o vigia em cena ve zumbis ou gente hostil chegando perto da base e grita. Todo
-- mundo acorda e vai para perto da porta; o aviso aparece para voce (e vai para o Diario).
-- Longe de voce: noite com vigia acordado = a base e avisada a tempo (mais defesa contra a
-- horda e os saqueadores, e o ladrao e espantado); noite sem vigia (ou vigia dormindo) =
-- pegos de surpresa (menos defesa).
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_Barks"
require "Remanescentes/Rem_Journal"
require "Remanescentes/Rem_PlayerBase"
local Rem = Remanescentes
local PB = Rem.PlayerBase

local WT = Rem.module("Watch", {
    SHIFTS = { { 21, 24 }, { 0, 3 }, { 3, 6 } },
    CHECK_MS = 1500,
    ALARM_MARGIN = 10,        -- ameaca a essa distancia das paredes da base
    ALARM_MS = 60000,         -- o alarme dura isso (em cena)
    ALARM_COOLDOWN_MS = 90000,
    ALARM_JOURNAL_H = 2,      -- no maximo uma entrada no diario a cada tantas horas
    ALARM_PRIORITY = 225,     -- antes das refeicoes, dos papeis e de dormir
    COVERED_BONUS = 2,        -- defesa a mais com o vigia acordado (fora de cena, a noite)
    SURPRISE_MULT = 0.6,      -- defesa sem ninguem vigiando (fora de cena, a noite)
    DOZE_AT = 90,             -- cansaco do vigia a partir do qual ele pode cochilar no posto
    DOZE_CHANCE = 35,         -- (%) por hora
})
local CFG = WT.CFG

Rem.BARKS.alarm_zombies = { urgent = true, n = 3, cd = 0 }
Rem.BARKS.alarm_people = { urgent = true, n = 3, cd = 0 }
Rem.BARKS.watch_start = { urgent = true, n = 3, cd = 0 }

local function hourNow() return math.floor(Rem.worldHours()) end

-- Turno de agora (1..#SHIFTS) ou nil de dia.
function WT.shift()
    local tod = getGameTime():getTimeOfDay()
    for i, s in ipairs(CFG.SHIFTS) do
        if tod >= s[1] and tod < s[2] then return i end
    end
    return nil
end

function WT.isNight() return WT.shift() ~= nil end

-- Vigias da base (tarefa "guard"), em ordem fixa.
function WT.guards(g)
    local out = {}
    for _, p in ipairs(PB.members(g)) do
        if p.job == "guard" and p.mode ~= "scav" and p.mode ~= "escort" then table.insert(out, p) end
    end
    table.sort(out, function(a, b) return tostring(a.id) < tostring(b.id) end)
    return out
end

-- Quem esta de vigia no turno (nil: ninguem).
function WT.onDuty(g, shift)
    shift = shift or WT.shift()
    local list = WT.guards(g)
    if #list == 0 then return nil end
    if not shift then return list[1] end
    return list[((shift - 1) % #list) + 1]
end

-- Esta pessoa esta de vigia agora (de noite)?
function WT.onWatch(rec)
    local g = PB.get()
    if not g or rec.groupId ~= g.id or not WT.isNight() then return false end
    return WT.onDuty(g) == rec
end

-- A noite esta coberta (vigia acordado)? De dia: ha algum vigia.
function WT.covered(g)
    local duty = WT.onDuty(g)
    if not duty then return false end
    if WT.isNight() and g.dozedH == hourNow() then return false end
    return true
end

-- Defesa ajustada pela vigia (so a noite).
function WT.adjustDefense(g, def)
    if not WT.isNight() then return def end
    if WT.covered(g) then return def + CFG.COVERED_BONUS end
    -- sem vigia acordado: as latas no fio ainda acordam alguem
    if Rem.Traps and Rem.Traps.cansReady(g.home) then return def * Rem.Traps.CFG.CANS_SURPRISE end
    return def * CFG.SURPRISE_MULT
end

-- Escala da noite: { {shift, rec}, ... } (para o painel da base).
function WT.roster(g)
    local out = {}
    for i = 1, #CFG.SHIFTS do table.insert(out, { shift = i, rec = WT.onDuty(g, i) }) end
    return out
end

-- ---------------------------------------------------------------- papeis da noite
-- Vigia de folga dorme (vira "morador" a noite); quem esta no turno fica no posto.
function WT.updateRoles(g)
    local night = WT.isNight()
    local duty = WT.onDuty(g)
    for _, p in ipairs(PB.members(g)) do
        if p.job == "guard" then
            p.role = (not night or p == duty) and "guarda" or "morador"
        end
    end
    if night and duty and g.lastDutyId ~= duty.id then
        g.lastDutyId = duty.id
        for _, npc in pairs(Rem.active) do
            if npc.rec == duty then
                if npc.rest == "sleep" then Rem.clearRest(npc) end
                Rem.bark(npc, "watch_start", true)
            end
        end
    elseif not night then
        g.lastDutyId = nil
    end
    return duty
end

function WT.hourly()
    local g = PB.get()
    if not g then return end
    local duty = WT.updateRoles(g)
    -- vigia exausto pode cochilar no posto
    -- cansado: cochila (menos se for vigia experiente); medo do escuro ou bebida (Rem_Traumas):
    -- pode cochilar mesmo descansado
    local extra = (Rem.Traumas and duty) and Rem.Traumas.dozeExtra(duty) or 0
    local doze = extra
    if duty and (duty.cansaco or 0) >= CFG.DOZE_AT then
        doze = CFG.DOZE_CHANCE - (Rem.Skills and Rem.Skills.dozeLess(duty) or 0) + extra
    end
    if WT.isNight() and duty and doze > 0 and ZombRand(100) < doze then
        g.dozedH = hourNow()
        if (g.dozedNoted or -999) < hourNow() - 12 then
            g.dozedNoted = hourNow()
            Rem.Journal.add("IGUI_Rem_Journal_watch_dozed", tostring(duty.name))
        end
    end
    if WT.isNight() and not duty and #g.members > 0 and (g.noWatchNoted or -999) < hourNow() - 20 then
        g.noWatchNoted = hourNow()
        Rem.Journal.add("IGUI_Rem_Journal_watch_none")
    end
end
Rem.on("worldHour", function() Rem.safe(WT.hourly) end)
Rem.on("playerBaseMember", function(g) Rem.safe(WT.updateRoles, g) end)

-- ---------------------------------------------------------------- alarme (em cena)
local function insideZone(h, x, y, m)
    return x >= h.x1 - m and x <= h.x2 + m and y >= h.y1 - m and y <= h.y2 + m
end

-- Ameacas perto da base: zumbis, pessoas hostis. Retorna zumbis, pessoas.
function WT.threats(g, guard)
    local h = g.home
    if not h or not h.x1 then return 0, 0 end
    local m = CFG.ALARM_MARGIN + ((Rem.Skills and guard) and Rem.Skills.watchRange(guard.rec) or 0)
    if Rem.Traps and Rem.Traps.cansReady(h) then m = m + Rem.Traps.CFG.CANS_ALARM end   -- latas no fio
    local nz, np = 0, 0
    local list = Rem.zombiesNear(h.x, h.y, m + math.max(h.x2 - h.x1, h.y2 - h.y1))
    for i = 1, #list do
        local zb = list[i]
        if not zb:isDead() and insideZone(h, zb:getX(), zb:getY(), m) then
            local other = Rem.active[zb]
            if not other then
                nz = nz + 1
            elseif other.rec.groupId ~= g.id and (Rem.isHostileToPlayer(other) or (guard and Rem.npcsHostile(guard, other))) then
                np = np + 1
            end
        end
    end
    return nz, np
end

-- O vigia em cena, acordado, no posto.
function WT.sentry(g)
    for _, npc in pairs(Rem.active) do
        local rec = npc.rec
        if rec.groupId == g.id and rec.role == "guarda" and npc.rest ~= "sleep" and Rem.canAct(npc) then
            if not (WT.isNight() and g.dozedH == hourNow()) then return npc end
        end
    end
    return nil
end

function WT.alarmOn(g, now)
    return g.alarmUntil ~= nil and (now or Rem.nowMs()) < g.alarmUntil
end

-- Da o alarme. Retorna true se deu.
function WT.raise(g, guard, zombies, people, now)
    now = now or Rem.nowMs()
    if WT.alarmOn(g, now) or now < (g.alarmCooldown or 0) then return false end
    g.alarmUntil = now + CFG.ALARM_MS
    g.alarmCooldown = now + CFG.ALARM_MS + CFG.ALARM_COOLDOWN_MS
    g.alarmUntilH = Rem.worldHours() + 1
    if guard then Rem.bark(guard, (people > 0) and "alarm_people" or "alarm_zombies", true) end
    -- todo mundo acorda
    for _, npc in pairs(Rem.active) do
        if npc.rec.groupId == g.id and npc.rest == "sleep" then
            Rem.clearRest(npc)
            Rem.bark(npc, "wake", true)
        end
    end
    if hourNow() - (g.alarmJournalH or -999) >= CFG.ALARM_JOURNAL_H then
        g.alarmJournalH = hourNow()
        if people > 0 then Rem.Journal.add("IGUI_Rem_Journal_alarm_people", tostring(guard and guard.rec.name or "?"), tostring(people))
        else Rem.Journal.add("IGUI_Rem_Journal_alarm_zombies", tostring(guard and guard.rec.name or "?"), tostring(zombies)) end
    end
    Rem.emit("baseAlarm", g, zombies, people)
    return true
end

local nextCheck = 0
function WT.tick(player, now)
    if now < nextCheck then return end
    nextCheck = now + CFG.CHECK_MS
    local g = PB.get()
    if not g or not g.home.x1 then return end
    local guard = WT.sentry(g)
    if not guard then return end
    local nz, np = WT.threats(g, guard)
    if nz + np > 0 then WT.raise(g, guard, nz, np, now) end
end
Rem.on("sceneUpdate", function(player, now) Rem.safe(WT.tick, player, now) end)

-- Durante o alarme: ninguem dorme; quem nao esta brigando vai para perto da porta.
function WT.alarmBehavior(npc, ctx, now)
    local rec = npc.rec
    if rec.mode ~= "group" then return false end
    local g = PB.get()
    if not g or rec.groupId ~= g.id or not WT.alarmOn(g, now) then return false end
    if npc.rest then Rem.clearRest(npc) end
    local h = g.home
    local spot = (Rem.Roles and h.mainDoor) and Rem.Roles.guardSpot(h) or { x = math.floor(h.x), y = math.floor(h.y), z = 0 }
    Rem.hangAround(npc, spot.x + 0.5, spot.y + 0.5, spot.z or 0, now, 3)
    return true
end
Rem.registerBehavior({ name = "alarm", priority = CFG.ALARM_PRIORITY, run = WT.alarmBehavior })

Rem.registerDebugOption("ContextMenu_Rem_BaseEv_alarm", function(x, y, z, player)
    local g = PB.get()
    if not g then player:Say(getText("IGUI_Rem_Base_none")) return end
    g.alarmCooldown, g.alarmUntil = nil, nil
    player:Say("alarm: " .. tostring(WT.raise(g, WT.sentry(g), 1, 0)))
end, "world")
