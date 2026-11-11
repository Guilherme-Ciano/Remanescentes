-- Remanescentes - o cerebro do grupo: necessidades -> objetivo -> trabalho de verdade.
--
-- Cada grupo com casa avalia a propria situacao e escolhe UM objetivo (g.goal). O objetivo
-- aparece no que os moradores fazem, no que respondem ("Como vao as coisas?"), nas missoes
-- que pedem e no seu diario. Necessidades (0 = tranquilo, 1 = critico):
--   comida     suprimentos por pessoa
--   saude      quantos estao feridos ou infectados
--   seguranca  quantas janelas da casa ainda estao abertas
-- Objetivos, em ordem de urgencia:
--   hide      horda grande demais em volta da casa: todos para dentro, agachados, em silencio
--   clear     zumbis em volta da casa que os defensores aguentam: saem para limpar a rua
--   heal      muita gente ferida: ficam em casa, o medico trabalha
--   scavenge  comida acabando (ou sem material para as janelas): saem para buscar
--   fortify   janelas abertas e material no estoque: um morador prega tabuas, uma por uma
--   routine   nada urgente: rotina da casa (papeis, refeicoes, conversa)
-- Material (g.materials): tabuas e pregos. Cada janela gasta WORK_PLANKS; cada saque traz
-- um pouco; voce pode trazer (missao "materials").
-- Nos primeiros dias as casas ainda nao estao fechadas: a fortificacao inicial cresce com
-- o dia do colapso (DR.initialFortify) e o resto e trabalho que voce ve acontecer.
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_World"
require "Remanescentes/Rem_Safehouse"
require "Remanescentes/Rem_Roles"
require "Remanescentes/Rem_Timeline"
require "Remanescentes/Rem_Tactics"
require "Remanescentes/Rem_Spatial"
local Rem = Remanescentes
local S = Rem.Safehouse

local DR = Rem.module("Director", {
    TICK_MS = 4000,               -- decisoes em cena
    FOOD_DAYS = 3,                -- suprimentos por pessoa para "comida = 0"
    FOOD_URGENT = 0.6,
    HEALTH_URGENT = 0.34,
    SAFETY_WORK = 0.25,           -- acima disso, fortificar vale a pena
    WOUNDED_BELOW = 0.6,
    CLEAR_RADIUS = 14,            -- zumbis a essa distancia da casa contam
    DANGER_MARGIN = 5,            -- zumbis a essa distancia das paredes sao perigo imediato
    DEFENDERS = 2,                -- quantos saem para limpar (o guarda e o mais valente)
    WORK_MS = 6000,               -- intervalo entre marteladas
    WORK_PLANKS = 2,              -- tabuas por janela
    WORK_PER_DAY = 3,             -- janelas por dia (para o trabalho durar dias)
    BUILDER_PER_DAY = 2,          -- na sua base: janelas por dia por morador fortificando
    WORK_NOISE = 9,
    WORK_PRIORITY = 232,          -- antes da refeicao (235) e dos papeis (240)
    HIDE_PRIORITY = 228,
    MATERIALS_START = { 2, 6 },
    MATERIALS_PER_TRIP = 4,
    SCAN_MS = 20000,
    INITIAL_MIN = 0.15,           -- dia 0: fracao da fortificacao "normal"
    INITIAL_DAYS = 6,             -- dia em que as casas ja nascem fechadas como antes
})
local CFG = DR.CFG

DR.GOALS = { "hide", "clear", "heal", "scavenge", "fortify", "routine" }

Rem.BARKS.work = { n = 4, cd = 25000 }
Rem.BARKS.clear = { urgent = true, n = 3, cd = 30000 }
Rem.BARKS.hide = { urgent = true, n = 3, cd = 45000 }
Rem.BARKS.work_done = { urgent = true, n = 2, cd = 0 }

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

local function membersOf(g)
    local out = {}
    for _, id in ipairs(g.members) do
        local p = Rem.getPerson(id)
        if p then table.insert(out, p) end
    end
    return out
end

local function onSceneOf(g)
    local out = {}
    for _, npc in pairs(Rem.active) do
        if npc.rec.groupId == g.id then table.insert(out, npc) end
    end
    table.sort(out, function(a, b) return tostring(a.rec.id) < tostring(b.rec.id) end)
    return out
end

local function dayStamp() return math.floor(Rem.worldHours() / 24) end

local function daytime()
    local tod = getGameTime():getTimeOfDay()
    return tod >= 7 and tod < 19
end

-- ---------------------------------------------------------------- primeiros dias
-- Fracao da fortificacao inicial de uma casa, pelo dia do colapso (1 = como antes).
function DR.initialFortify()
    local day = Rem.Timeline and Rem.Timeline.day() or CFG.INITIAL_DAYS
    return clamp(CFG.INITIAL_MIN + (1 - CFG.INITIAL_MIN) * day / CFG.INITIAL_DAYS, CFG.INITIAL_MIN, 1)
end

-- ---------------------------------------------------------------- a casa: janelas
local function objectsOf(sq)
    local out = {}
    local objs = sq:getObjects()
    for i = 0, objs:size() - 1 do table.insert(out, objs:get(i)) end
    return out
end

local function windowAt(pos)
    local sq = getCell():getGridSquare(pos.x, pos.y, pos.z or 0)
    if not sq then return nil end
    for _, obj in ipairs(objectsOf(sq)) do
        if instanceof(obj, "IsoWindow") and obj:isExterior() then return obj, sq end
    end
    return nil
end

-- Conta as janelas externas e guarda as que ainda estao abertas (h.openWindows).
function DR.scanHome(g, now, force)
    local h = g.home
    if not h or not h.x1 or not S.isLoaded(h) then return nil end
    if not force and h.scanAt and now - h.scanAt < CFG.SCAN_MS then return h.openWindows end
    h.scanAt = now
    local total, done, open = 0, 0, {}
    S.forEachSquare(h, h.z or 0, function(sq)
        for _, obj in ipairs(objectsOf(sq)) do
            if instanceof(obj, "IsoWindow") and obj:isExterior() then
                local entrance = h.entrance and h.entrance.window and sq:getX() == h.entrance.x and sq:getY() == h.entrance.y
                if not entrance then
                    total = total + 1
                    if obj:isBarricaded() then done = done + 1
                    else table.insert(open, { x = sq:getX(), y = sq:getY(), z = sq:getZ() }) end
                end
            end
        end
    end)
    table.sort(open, function(a, b) if a.y ~= b.y then return a.y > b.y end return a.x < b.x end)
    h.windowsTotal, h.windowsDone, h.openWindows = total, done, open
    return open
end

-- ---------------------------------------------------------------- necessidades
function DR.materials(g)
    if g.materials == nil then g.materials = ZombRand(CFG.MATERIALS_START[1], CFG.MATERIALS_START[2] + 1) end
    return g.materials
end

function DR.needs(g)
    local list = membersOf(g)
    local n = math.max(1, #list)
    local wounded = 0
    for _, p in ipairs(list) do
        local frac = (p.hp or 1) / (p.maxHealth or 1)
        for _, npc in pairs(Rem.active) do
            if npc.rec == p then frac = Rem.healthFraction(npc) end
        end
        if frac < CFG.WOUNDED_BELOW or p.infectedAt then wounded = wounded + 1 end
    end
    local h = g.home or {}
    local safety
    if h.windowsTotal and h.windowsTotal > 0 then
        safety = 1 - (h.windowsDone or 0) / h.windowsTotal
    elseif h.windowsTotal == 0 then
        safety = 0
    else
        local maxLevel = (Rem.Evolution and Rem.Evolution.CFG.MAX_LEVEL) or 5
        safety = 1 - clamp((h.fortifyLevel or 0) / maxLevel, 0, 1) * 0.7
    end
    return {
        food = clamp(1 - (g.supplies or 0) / (n * CFG.FOOD_DAYS), 0, 1),
        health = wounded / n,
        safety = clamp(safety, 0, 1),
        wounded = wounded,
        members = #list,
        materials = DR.materials(g),
    }
end

-- Zumbis em volta da casa (so com a casa carregada). Retorna o total na rua em volta e
-- quantos estao colados nas paredes (perigo imediato).
function DR.zombiesAtHome(g)
    local h = g.home
    if not h or not h.x1 then return 0, 0 end
    local r = CFG.CLEAR_RADIUS + math.max(h.x2 - h.x1, h.y2 - h.y1) / 2
    local n, close = 0, 0
    local m = CFG.DANGER_MARGIN
    local list = Rem.zombiesNear(h.x, h.y, r)
    for i = 1, #list do
        local zb = list[i]
        if not Rem.active[zb] and not zb:isDead() then
            n = n + 1
            local x, y = zb:getX(), zb:getY()
            if x >= h.x1 - m and x <= h.x2 + m and y >= h.y1 - m and y <= h.y2 + m then close = close + 1 end
        end
    end
    return n, close
end

-- O zumbi esta na area que os defensores limpam? (usado por Rem.findEnemy)
function DR.inClearZone(npc, zombie)
    local g = npc.rec.groupId and Rem.getStore().groups[npc.rec.groupId]
    local h = g and g.home
    if not h or not h.x1 then return false end
    local m = CFG.CLEAR_RADIUS
    local x, y = zombie:getX(), zombie:getY()
    return x >= h.x1 - m and x <= h.x2 + m and y >= h.y1 - m and y <= h.y2 + m
end

-- Quem sai para limpar: o guarda e os mais valentes, ate DEFENDERS.
function DR.defenders(g)
    local list = onSceneOf(g)
    table.sort(list, function(a, b)
        local ga, gb = a.rec.role == "guarda", b.rec.role == "guarda"
        if ga ~= gb then return ga end
        local ca, cb = Rem.trait(a.rec, "coragem"), Rem.trait(b.rec, "coragem")
        if ca ~= cb then return ca > cb end
        return tostring(a.rec.id) < tostring(b.rec.id)
    end)
    local out = {}
    for _, npc in ipairs(list) do
        if #out < CFG.DEFENDERS and Rem.canAct(npc) and Rem.healthFraction(npc) >= CFG.WOUNDED_BELOW then
            table.insert(out, npc)
        end
    end
    return out
end

-- Quantos zumbis os defensores aguentam juntos.
function DR.defense(g)
    local total = 0
    for _, npc in ipairs(DR.defenders(g)) do total = total + Rem.Tactics.nerve(npc) end
    return total * Rem.Tactics.CFG.ZOMBIES_PER_POWER
end

-- ---------------------------------------------------------------- escolher o objetivo
-- zombies = zumbis na rua em volta da casa, close = colados nas paredes (nil fora de cena).
-- Horda colada na casa: esconder. Poucos (que os defensores aguentam): limpar. Muitos mas
-- longe: a vida segue (trabalham, comem) sem chamar atencao saindo para a rua.
function DR.choose(g, zombies, close)
    local needs = DR.needs(g)
    local goal = "routine"
    if g.activity ~= "home" then
        goal = "scavenge"                       -- ja esta na rua (saque, volta)
    elseif zombies and (close or zombies) > DR.defense(g) then
        goal = "hide"
    elseif zombies and zombies > 0 and zombies <= DR.defense(g) then
        goal = "clear"
    elseif needs.health >= CFG.HEALTH_URGENT then
        goal = "heal"
    elseif needs.food >= CFG.FOOD_URGENT and not g.player then
        goal = "scavenge"           -- (na sua base, quem busca comida e quem voce mandou buscar)
    elseif needs.safety >= CFG.SAFETY_WORK then
        goal = (needs.materials >= 1) and "fortify" or "scavenge"
    end
    if g.goal ~= goal then
        g.goal, g.goalSince = goal, Rem.worldHours()
        Rem.debug("grupo " .. g.id .. " (" .. tostring(g.name) .. "): objetivo = " .. goal)
        Rem.emit("groupGoal", g, goal, needs)
    end
    g.needs = { food = needs.food, health = needs.health, safety = needs.safety }
    return goal, needs
end

-- ---------------------------------------------------------------- fora de cena (por hora)
function DR.hourly()
    local store = Rem.getStore()
    for _, g in pairs(store.groups) do
        local h = g.home
        if h and h.x1 and #g.members > 0 then
            -- voltou de um saque: trouxe material
            if g.lastActivity == "return" and g.activity == "home" then
                g.materials = DR.materials(g) + CFG.MATERIALS_PER_TRIP
            end
            g.lastActivity = g.activity
            local goal = DR.choose(g, nil)
            if goal == "scavenge" and g.activity == "home" and daytime() and Rem.World.startScavenge and not g.player then
                Rem.World.startScavenge(g)
            elseif goal == "fortify" and daytime() and not DR.watched(g) then
                DR.workOffscene(g)
            end
        end
    end
end
Rem.on("worldHour", function() Rem.safe(DR.hourly) end)

-- Janelas por dia: na sua base, cada um que voce mandou fortificar fecha BUILDER_PER_DAY.
function DR.workPerDay(g)
    if not g.player then return CFG.WORK_PER_DAY end
    local n = 0
    for _, id in ipairs(g.members) do
        local p = Rem.getPerson(id)
        if p and p.job == "build" then n = n + 1 end
    end
    return n * CFG.BUILDER_PER_DAY
end

-- ---------------------------------------------------------------- longe de voce
-- O trabalho nao para quando voce vai embora: a cada hora de dia um morador fecha uma
-- janela (ate WORK_PER_DAY por dia), gastando material. As tabuas aparecem de verdade
-- quando a casa carregar perto de voce (DR.applyPending).
function DR.watched(g)
    for _, npc in pairs(Rem.active) do
        if npc.rec.groupId == g.id then return true end
    end
    return false
end

function DR.workOffscene(g)
    if g.player or Rem.BaseBuild then return false end   -- (Rem_BaseBuild)
    local h = g.home
    if h.workDay ~= dayStamp() then h.workDay, h.workedToday = dayStamp(), 0 end
    if (h.workedToday or 0) >= DR.workPerDay(g) or DR.materials(g) < CFG.WORK_PLANKS then return false end
    local open = h.windowsTotal and (h.windowsTotal - (h.windowsDone or 0) - (h.pendingWork or 0)) or 1
    if open <= 0 then return false end
    g.materials = DR.materials(g) - CFG.WORK_PLANKS
    h.pendingWork = (h.pendingWork or 0) + 1
    h.workedToday = (h.workedToday or 0) + 1
    Rem.debug("grupo " .. g.id .. " fechou uma janela longe de voce (" .. h.pendingWork .. " para aparecer)")
    return true
end

-- Casa carregada: as janelas fechadas enquanto voce estava longe aparecem com tabuas.
function DR.applyPending(g)
    local h = g.home
    if not h or not h.pendingWork or h.pendingWork <= 0 or not S.isLoaded(h) then return 0 end
    local open = DR.scanHome(g, Rem.nowMs(), true) or {}
    local done = 0
    for _, pos in ipairs(open) do
        if done >= h.pendingWork then break end
        local win = windowAt(pos)
        if win and Rem.safe(S.barricadeInside, win, CFG.WORK_PLANKS) then done = done + 1 end
    end
    h.pendingWork = 0
    if done > 0 then
        DR.scanHome(g, Rem.nowMs(), true)
        Rem.emit("homeWorked", g, nil)
        Rem.debug("grupo " .. g.id .. ": " .. done .. " janelas fechadas enquanto voce estava longe")
    end
    return done
end

-- ---------------------------------------------------------------- em cena

-- Quem prega as tabuas: engenheiro, senao um morador (nunca o guarda).
function DR.worker(g)
    if g.player or Rem.BaseBuild then return nil end      -- (as obras sao de Rem_BaseBuild, para todos os grupos)
    local best, bestScore = nil, -1
    for _, npc in ipairs(onSceneOf(g)) do
        local rec = npc.rec
        if rec.role ~= "guarda" and Rem.canAct(npc) and Rem.healthFraction(npc) >= CFG.WOUNDED_BELOW then
            local score = (rec.archetype == "engenheiro" and 10 or 0) + (rec.role == "morador" and 2 or 0)
            if score > bestScore then best, bestScore = npc, score end
        end
    end
    return best
end

function DR.sceneGroup(g, now)
    local h = g.home
    local people = onSceneOf(g)
    if #people == 0 or not S.isLoaded(h) then return nil end
    DR.scanHome(g, now)
    local zombies, close = DR.zombiesAtHome(g)
    DR.applyPending(g)
    local goal = DR.choose(g, zombies, close)
    -- limpa as tarefas de antes
    for _, npc in ipairs(people) do npc.clearing, npc.hiding, npc.working = nil, nil, nil end
    if goal == "clear" then
        local list = DR.defenders(g)
        for _, npc in ipairs(list) do npc.clearing = true end
        if list[1] then Rem.bark(list[1], "clear") end
    elseif goal == "hide" then
        for _, npc in ipairs(people) do npc.hiding = true end
        Rem.bark(people[1], "hide")
    elseif goal == "fortify" and daytime() then
        if h.workDay ~= dayStamp() then h.workDay, h.workedToday = dayStamp(), 0 end
        if (h.workedToday or 0) < DR.workPerDay(g) and h.openWindows and #h.openWindows > 0 then
            local w = DR.worker(g)
            if w then w.working = true end
        end
    end
    return goal
end

local nextTick = 0
function DR.tick(player, now)
    if now < nextTick then return end
    nextTick = now + CFG.TICK_MS
    for _, g in pairs(Rem.getStore().groups) do
        local h = g.home
        if h and h.pendingWork and h.pendingWork > 0 then Rem.safe(DR.applyPending, g) end   -- (mesmo sem ninguem em cena)
        if h and h.x1 and g.activity == "home" then Rem.safe(DR.sceneGroup, g, now) end
    end
end
Rem.on("sceneUpdate", function(player, now) Rem.safe(DR.tick, player, now) end)

-- Quadrado de dentro, colado na janela, onde o morador fica para pregar.
local function standSpot(pos)
    local cell = getCell()
    local sq = cell:getGridSquare(pos.x, pos.y, pos.z or 0)
    if sq and sq:getRoom() then return pos end
    for _, off in ipairs({ { 0, -1 }, { -1, 0 }, { 1, 0 }, { 0, 1 } }) do
        local s = cell:getGridSquare(pos.x + off[1], pos.y + off[2], pos.z or 0)
        if s and s:getRoom() and s:isFree(false) then return { x = pos.x + off[1], y = pos.y + off[2], z = pos.z or 0 } end
    end
    return pos
end

-- Pregar tabuas numa janela aberta, uma martelada de cada vez.
function DR.workBehavior(npc, ctx, now)
    if not npc.working then return false end
    local rec = npc.rec
    local g = rec.groupId and Rem.getStore().groups[rec.groupId]
    local h = g and g.home
    if not h or g.activity ~= "home" or not h.openWindows then return false end
    local target = h.workTarget or h.openWindows[1]
    if not target or DR.materials(g) < 1 then
        npc.working = nil
        return false
    end
    h.workTarget = target
    local spot = standSpot(target)
    if Rem.distXY(npc.z, spot.x + 0.5, spot.y + 0.5) > 1.2 then
        Rem.moveTo(npc, spot.x + 0.5, spot.y + 0.5, spot.z or 0, now, "walk")
        return true
    end
    Rem.stopMoving(npc)
    Rem.safe(function() npc.z:faceLocationF(target.x + 0.5, target.y + 0.5) end)
    if now < (npc.nextWork or 0) then return true end
    npc.nextWork = now + CFG.WORK_MS
    local win = windowAt(target)
    local added = false
    if win then
        local ok, res = pcall(function()
            if not win:isBarricaded() then return S.barricadeInside(win, 1) == true end
            local b = win:getBarricadeOnSameSquare() or win:getBarricadeOnOppositeSquare()
            if not b or not b:canAddPlank() then return false end
            b:addPlank(nil, nil)
            return true
        end)
        added = ok and res == true
    end
    if added then
        g.materials = DR.materials(g) - 1
        h.workPlanks = (h.workPlanks or 0) + 1
        Rem.makeNoise(npc, CFG.WORK_NOISE)
        Rem.safe(function() npc.z:playSound("Hammering") end)
        Rem.bark(npc, "work")
    end
    if not added or h.workPlanks >= CFG.WORK_PLANKS then
        -- janela pronta (ou impossivel): proxima
        h.workTarget, h.workPlanks = nil, nil
        h.workedToday = (h.workedToday or 0) + 1
        npc.working = nil
        DR.scanHome(g, now, true)
        if added then
            Rem.bark(npc, "work_done", true)
            Rem.emit("homeWorked", g, npc)
        end
    end
    return true
end
Rem.registerBehavior({ name = "work", priority = CFG.WORK_PRIORITY, run = DR.workBehavior })

-- Limpando a rua: vai ate o zumbi mais perto da casa (a briga em si e o combate normal).
function DR.clearBehavior(npc, ctx, now)
    if not npc.clearing or ctx.enemy then return false end
    local g = npc.rec.groupId and Rem.getStore().groups[npc.rec.groupId]
    local h = g and g.home
    if not h or not h.x1 then return false end
    local best, bestD = nil, math.huge
    local list = Rem.zombiesNear(h.x, h.y, CFG.CLEAR_RADIUS + math.max(h.x2 - h.x1, h.y2 - h.y1) / 2)
    for i = 1, #list do
        local zb = list[i]
        if not Rem.active[zb] and not zb:isDead() then
            local d = Rem.dist(npc.z, zb)
            if d < bestD then best, bestD = zb, d end
        end
    end
    if not best then return false end
    Rem.moveTo(npc, best:getX(), best:getY(), best:getZ(), now, "walk")
    return true
end
Rem.registerBehavior({ name = "clear", priority = CFG.HIDE_PRIORITY - 2, run = DR.clearBehavior })

-- Horda la fora: para dentro, agachado, sem barulho.
function DR.hideBehavior(npc, ctx, now)
    if not npc.hiding then return false end
    local rec = npc.rec
    local g = rec.groupId and Rem.getStore().groups[rec.groupId]
    local h = g and g.home
    if not h then return false end
    local spot = S.indoorSpot(rec, h)
    if not spot then return false end
    if Rem.distXY(npc.z, spot.x + 0.5, spot.y + 0.5) > 1.5 then
        Rem.moveTo(npc, spot.x + 0.5, spot.y + 0.5, spot.z or 0, now, "sneak")
    else
        Rem.stopMoving(npc)
        Rem.setGait(npc, "sneak")
    end
    return true
end
Rem.registerBehavior({ name = "hide", priority = CFG.HIDE_PRIORITY, run = DR.hideBehavior })

-- ---------------------------------------------------------------- ferramenta de teste
Rem.registerDebugOption("ContextMenu_Rem_GoalNearest", function(x, y, z, player)
    local g = Rem.nearestGroup(player:getX(), player:getY())
    if not g then player:Say("-") return end
    local zs, close = nil, nil
    if S.isLoaded(g.home) then zs, close = DR.zombiesAtHome(g) end
    local goal, n = DR.choose(g, zs, close)
    local text = string.format("%s: %s | comida %.1f saude %.1f seguranca %.1f | material %d | janelas %s/%s",
        tostring(g.name or g.id), goal, n.food, n.health, n.safety, math.floor(n.materials),
        tostring(g.home.windowsDone or "?"), tostring(g.home.windowsTotal or "?"))
    player:Say(text)
    Rem.log(text)
end, "world")
