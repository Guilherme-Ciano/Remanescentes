-- Remanescentes - obras da sua base: a casa vai sendo fechada aos poucos, na sua frente.
--
-- Quem tem a tarefa "fortificar" trabalha numa fila de projetos, em ordem:
--   windows    tabuas nas janelas abertas (2 tabuas por janela)
--   doors      tabuas nas portas externas que nao sao a principal (2 por porta)
--   reinforce  mais tabuas ate 4 em cada janela e porta ja barricada
--   perimeter  cerca de madeira em volta da casa (a PERIM_MARGIN tiles das paredes), com
--              uma passagem em frente a porta principal
--   cars       carros queimados arrastados para as ruas em volta, como barricada
-- Cada passo (uma tabua, um pedaco de cerca, um pedaco do trabalho de arrastar um carro)
-- leva STEP_MS, faz barulho (atrai zumbis) e gasta material. Por dia, cada um faz ate
-- STEPS_PER_DAY passos.
-- Longe de voce o trabalho continua: os passos ficam guardados e aparecem quando a casa
-- carregar perto de voce. Os objetos sao os do jogo: barricada de tabuas (IsoBarricade),
-- cerca de madeira (IsoThumpable, mesmos sprites e vida da cerca de carpintaria) e carros
-- queimados de verdade (addVehicleDebug).
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_Safehouse"
require "Remanescentes/Rem_Movement"
require "Remanescentes/Rem_Director"
local Rem = Remanescentes
local S = Rem.Safehouse

local BB = Rem.module("BaseBuild", {
    STEP_MS = 6000,
    STEPS_PER_DAY = 8,             -- por pessoa fortificando
    ENGINEER_BONUS = 1.5,          -- engenheiro rende isso
    WINDOW_PLANKS = 2,
    MAX_PLANKS = 4,
    PERIM_MARGIN = 3,
    GAP = 1,                       -- passagem: a porta +- isso
    FENCE_W = "carpentry_02_40",   -- cerca de madeira (nivel 1 da carpintaria): face oeste
    FENCE_N = "carpentry_02_41",   --                                            face norte
    FENCE_HEALTH = 250,
    COST = { windows = 1, doors = 1, reinforce = 1, perimeter = 2, barbed = 1, barrel = 2, cars = 0, generator = 6 },
    BARBED_W = "fencing_01_20",    -- arame farpado (o do jogo): face oeste / norte
    BARBED_N = "fencing_01_21",
    BARBED_HEALTH = 100,
    ESTIMATE = { windows = 12, doors = 4, reinforce = 16, perimeter = 50, barbed = 50, barrel = 1, cars = 16, generator = 1 },
    CAR_STEPS = 4,                 -- arrastar um carro e trabalho de varios passos (sem material)
    MAX_CARS = 4,
    CAR_OUT = 4,                   -- distancia alem da cerca
    PRIORITY = 231,
    NOISE = 10,
})
local CFG = BB.CFG

-- Todos os projetos, na ordem em que sao feitos. Cada grupo faz os da sua faccao (BB.FACTION
-- ou def.base.projects em Rem.registerFaction); a sua base faz todos.
BB.PROJECTS = { "windows", "doors", "reinforce", "perimeter", "barbed", "barrel", "cars", "generator" }
BB.FACTION = {
    aliados       = { "windows", "doors", "reinforce", "perimeter", "barbed", "barrel", "cars", "generator" },
    civis         = { "windows", "doors", "reinforce", "perimeter", "barrel" },
    sobreviventes = { "windows", "doors", "reinforce", "perimeter", "barbed", "barrel", "cars", "generator" },
    saqueadores   = { "windows", "doors", "barbed", "cars" },
    seita         = { "windows", "doors", "reinforce", "perimeter", "barrel" },
    errantes      = {},
}

-- Projetos registrados por outros modulos/mods (BB.registerProject):
--   def = { cost = n, after = "nomeDeOutroProjeto" (opcional),
--           plan = function(g, h) return { tarefa, ... } end,   -- cada tarefa: { x, y, z, left = passos }
--           apply = function(g, h, t) return true/false end,    -- um passo
--           estimate = n (opcional: passos supostos antes da casa carregar) }
BB.EXTRA = BB.EXTRA or {}
function BB.registerProject(name, def)
    if type(name) ~= "string" or type(def) ~= "table" or type(def.plan) ~= "function" or type(def.apply) ~= "function" then
        return nil
    end
    BB.EXTRA[name] = def
    local exists = false
    for _, p in ipairs(BB.PROJECTS) do if p == name then exists = true end end
    if not exists then
        local pos = #BB.PROJECTS + 1
        for i, p in ipairs(BB.PROJECTS) do if p == def.after then pos = i + 1 end end
        table.insert(BB.PROJECTS, pos, name)
    end
    CFG.COST[name] = def.cost or CFG.COST[name] or 1
    return def
end

-- Projetos que este grupo faz, na ordem.
function BB.projectsFor(g)
    local list = nil
    if g.player then
        list = BB.FACTION.aliados
    else
        local fdef = Rem.FACTIONS and Rem.FACTIONS[g.faction]
        list = (fdef and fdef.base and fdef.base.projects) or BB.FACTION[g.faction] or BB.FACTION.civis
    end
    local allowed = {}
    for _, p in ipairs(list) do allowed[p] = true end
    for name, def in pairs(BB.EXTRA) do
        if def.factions == nil or def.factions[g.player and "aliados" or g.faction] then allowed[name] = true end
    end
    local out = {}
    for _, p in ipairs(BB.PROJECTS) do if allowed[p] then table.insert(out, p) end end
    return out
end
BB.CARS = { "Base.CarNormalBurnt", "Base.SmallCarBurnt", "Base.PickupBurnt", "Base.VanBurnt", "Base.SUVBurnt",
    "Base.TaxiBurnt", "Base.ModernCarBurnt", "Base.SmallCar02Burnt" }

Rem.BARKS.build_fence = { n = 3, cd = 25000 }
Rem.BARKS.build_car = { n = 3, cd = 25000 }
Rem.BARKS.build_done = { urgent = true, n = 3, cd = 0 }

local function objectsOf(sq)
    local out = {}
    local objs = sq:getObjects()
    for i = 0, objs:size() - 1 do table.insert(out, objs:get(i)) end
    return out
end

local function dayStamp() return math.floor(Rem.worldHours() / 24) end
local function key(x, y) return x .. "," .. y end

-- ---------------------------------------------------------------- o que falta fazer
-- Barricada (do lado de dentro) de uma janela ou porta, ou nil.
local function barricadeOf(obj)
    local b = nil
    pcall(function() b = obj:getBarricadeOnSameSquare() or obj:getBarricadeOnOppositeSquare() end)
    return b
end

local function planksOf(obj)
    local b = barricadeOf(obj)
    if not b then return 0 end
    local n = 0
    pcall(function() n = b:getNumPlanks() end)
    return n
end

-- Quadrados da cerca: { x, y, north } em volta da casa, sem a passagem da porta.
-- margin: distancia das paredes (padrao PERIM_MARGIN; o arame farpado fica 1 alem).
function BB.fenceSquares(h, margin)
    local m = margin or CFG.PERIM_MARGIN
    local x0, x1 = h.x1 - m, h.x2 - 1 + m
    local y0, y1 = h.y1 - m, h.y2 - 1 + m
    local out = {}
    local d = h.mainDoor
    local function gap(edge, v)
        if not d then return false end
        if edge == "N" and d.y < h.y1 + 1 then return math.abs(v - d.x) <= CFG.GAP end
        if edge == "S" and d.y >= h.y2 - 1 then return math.abs(v - d.x) <= CFG.GAP end
        if edge == "W" and d.x < h.x1 + 1 then return math.abs(v - d.y) <= CFG.GAP end
        if edge == "E" and d.x >= h.x2 - 1 then return math.abs(v - d.y) <= CFG.GAP end
        return false
    end
    for x = x0, x1 do
        if not gap("N", x) then table.insert(out, { x = x, y = y0, north = true }) end
        if not gap("S", x) then table.insert(out, { x = x, y = y1 + 1, north = true }) end
    end
    for y = y0, y1 do
        if not gap("W", y) then table.insert(out, { x = x0, y = y, north = false }) end
        if not gap("E", y) then table.insert(out, { x = x1 + 1, y = y, north = false }) end
    end
    return out
end

-- Da para por cerca aqui? (chao de fora, livre, fora de outro predio)
local function fenceOk(sq)
    return sq ~= nil and not sq:getRoom() and not sq:getBuilding() and sq:isFree(false)
end

-- Vagas para carros: no meio de cada lado, CAR_OUT alem da cerca (lado da porta primeiro).
function BB.carSpots(h)
    local m = CFG.PERIM_MARGIN + CFG.CAR_OUT
    local cx, cy = math.floor((h.x1 + h.x2) / 2), math.floor((h.y1 + h.y2) / 2)
    local spots = {
        { x = cx, y = h.y2 - 1 + m, dir = "E", edge = "S" }, { x = cx, y = h.y1 - m, dir = "E", edge = "N" },
        { x = h.x1 - m, y = cy, dir = "N", edge = "W" }, { x = h.x2 - 1 + m, y = cy, dir = "N", edge = "E" },
    }
    local d = h.mainDoor
    if d then
        table.sort(spots, function(a, b)
            return Rem.dist2(a.x, a.y, d.x, d.y) < Rem.dist2(b.x, b.y, d.x, d.y)
        end)
    end
    return spots
end

-- Um carro (uns 2 x 5 tiles) cabe aqui?
local function carFits(spot)
    local cell = getCell()
    local along = (spot.dir == "E")
    for i = -2, 2 do
        for j = -1, 1 do
            local x = spot.x + (along and i or j)
            local y = spot.y + (along and j or i)
            local sq = cell:getGridSquare(x, y, 0)
            if not fenceOk(sq) then return false end
        end
    end
    return true
end

-- Levanta tudo o que falta (com a casa carregada). Guarda as contas em h.plan.
function BB.scan(g)
    local h = g.home
    if not h or not h.x1 or not S.isLoaded(h) then return nil end
    local plan = {}
    for _, p in ipairs(BB.PROJECTS) do plan[p] = {} end
    local mine = {}
    for _, p in ipairs(BB.projectsFor(g)) do mine[p] = true end
    local seen = {}
    S.forEachSquare(h, h.z or 0, function(sq)
        for _, obj in ipairs(objectsOf(sq)) do
            if not seen[obj] then
                seen[obj] = true
                local ext = false
                pcall(function() ext = obj:isExterior() end)
                local isWin, isDoor = instanceof(obj, "IsoWindow"), instanceof(obj, "IsoDoor")
                if ext and (isWin or isDoor) then
                    local main = isDoor and h.mainDoor and sq:getX() == h.mainDoor.x and sq:getY() == h.mainDoor.y
                    local entrance = h.entrance and h.entrance.window and sq:getX() == h.entrance.x and sq:getY() == h.entrance.y
                    if not main and not entrance then
                        local planks = planksOf(obj)
                        local t = { obj = obj, x = sq:getX(), y = sq:getY(), z = sq:getZ() }
                        if planks < CFG.WINDOW_PLANKS then
                            t.left = CFG.WINDOW_PLANKS - planks
                            table.insert(isWin and plan.windows or plan.doors, t)
                        elseif planks < CFG.MAX_PLANKS then
                            t.left = CFG.MAX_PLANKS - planks
                            table.insert(plan.reinforce, t)
                        end
                    end
                end
            end
        end
    end)
    h.fence = h.fence or {}
    local cell = getCell()
    local fenceTotal = 0
    for _, f in ipairs(BB.fenceSquares(h)) do
        local sq = cell:getGridSquare(f.x, f.y, 0)
        if h.fence[key(f.x, f.y) .. (f.north and "N" or "W")] then
            fenceTotal = fenceTotal + 1
        elseif fenceOk(sq) then
            fenceTotal = fenceTotal + 1
            table.insert(plan.perimeter, { x = f.x, y = f.y, z = 0, north = f.north, left = 1 })
        end
    end
    h.cars = h.cars or {}
    for _, spot in ipairs(BB.carSpots(h)) do
        if #plan.cars + #h.cars >= CFG.MAX_CARS then break end
        local done = false
        for _, c in ipairs(h.cars) do if c.edge == spot.edge then done = true end end
        if not done and carFits(spot) then
            table.insert(plan.cars, { x = spot.x, y = spot.y, z = 0, dir = spot.dir, edge = spot.edge, left = CFG.CAR_STEPS })
        end
    end
    -- arame farpado: anel 1 tile alem da cerca
    h.barbed = h.barbed or {}
    for _, f in ipairs(BB.fenceSquares(h, CFG.PERIM_MARGIN + 1)) do
        local k = key(f.x, f.y) .. (f.north and "N" or "W")
        if not h.barbed[k] and fenceOk(cell:getGridSquare(f.x, f.y, 0)) then
            table.insert(plan.barbed, { x = f.x, y = f.y, z = 0, north = f.north, left = 1 })
        end
    end
    -- barril de chuva e gerador (uma vez, se a casa ainda nao tem)
    local decor = h.decor or {}
    local mx, my = math.floor((h.x1 + h.x2) / 2), math.floor((h.y1 + h.y2) / 2)
    if not decor.barrel and not h.builtBarrel and Rem.Signals then
        local sq = Rem.Signals.outsideSpot(h, h.x1 - 1, my, 0, 2, {})
        if sq then table.insert(plan.barrel, { x = sq:getX(), y = sq:getY(), z = 0, left = 1 }) end
    end
    if not decor.generator and not h.builtGenerator and Rem.Signals then
        local sq = Rem.Signals.outsideSpot(h, h.x2, my, 1, 2, {})
        if sq then table.insert(plan.generator, { x = sq:getX(), y = sq:getY(), z = 0, left = 1 }) end
    end
    -- projetos de outros modulos
    for name, def in pairs(BB.EXTRA) do
        local ok, list = pcall(def.plan, g, h)
        plan[name] = (ok and type(list) == "table") and list or {}
    end
    -- so o que esta faccao faz
    for _, p in ipairs(BB.PROJECTS) do
        if not mine[p] then plan[p] = {} end
    end
    -- contas (para o diario e para o trabalho longe de voce)
    local counts = {}
    for _, p in ipairs(BB.PROJECTS) do
        local n = 0
        for _, t in ipairs(plan[p]) do n = n + t.left end
        counts[p] = n
    end
    h.plan = counts
    h.fenceTotal, h.fenceBuilt = fenceTotal, 0
    for _ in pairs(h.fence) do h.fenceBuilt = h.fenceBuilt + 1 end
    BB.last = BB.last or {}
    BB.last[g.id] = plan
    return plan
end

-- Projeto em andamento (o primeiro que ainda tem passos) e a proxima tarefa dele.
function BB.next(g, plan)
    plan = plan or (BB.last and BB.last[g.id]) or BB.scan(g)
    if not plan then return nil end
    for _, p in ipairs(BB.projectsFor(g)) do
        local t = plan[p] and plan[p][1]
        if t then return p, t end
    end
    return nil
end

-- ---------------------------------------------------------------- um passo de obra
function BB.addFence(f)
    local sq = getCell():getGridSquare(f.x, f.y, f.z or 0)
    if not fenceOk(sq) then return false end
    local obj = IsoThumpable.new(getCell(), sq, f.north and CFG.FENCE_N or CFG.FENCE_W, f.north, {})
    obj:setMaxHealth(CFG.FENCE_HEALTH)
    obj:setHealth(CFG.FENCE_HEALTH)
    obj:setBreakSound("BreakObject")
    obj:setIsThumpable(true)
    obj:setCanPassThrough(false)
    obj:getModData().remFence = true
    sq:AddSpecialObject(obj)
    pcall(function() sq:RecalcAllWithNeighbours(true) end)
    return true
end

function BB.addBarbed(f)
    local sq = getCell():getGridSquare(f.x, f.y, f.z or 0)
    if not fenceOk(sq) then return false end
    local obj = IsoThumpable.new(getCell(), sq, f.north and CFG.BARBED_N or CFG.BARBED_W, f.north, {})
    obj:setMaxHealth(CFG.BARBED_HEALTH)
    obj:setHealth(CFG.BARBED_HEALTH)
    obj:setBreakSound("BreakObject")
    obj:setIsThumpable(true)
    obj:setIsHoppable(true)
    obj:getModData().remBarbed = true
    sq:AddSpecialObject(obj)
    pcall(function() sq:RecalcAllWithNeighbours(true) end)
    return true
end

function BB.addCar(c)
    local sq = getCell():getGridSquare(c.x, c.y, c.z or 0)
    if not sq then return false end
    local v = addVehicleDebug(Rem.pick(BB.CARS), (c.dir == "E") and IsoDirections.E or IsoDirections.N, nil, sq)
    return v ~= nil
end

-- Aplica um passo da tarefa t (do projeto p). Retorna true se fez.
function BB.apply(g, p, t)
    local h = g.home
    if p == "windows" or p == "doors" or p == "reinforce" then
        local obj = t.obj
        if not obj then return false end
        local ok, res = pcall(function()
            local b = barricadeOf(obj)
            if not b then return S.barricadeInside(obj, 1) == true end
            if not b:canAddPlank() then return false end
            b:addPlank(nil, nil)
            return true
        end)
        return ok and res == true
    elseif p == "perimeter" then
        local ok, res = pcall(BB.addFence, t)
        if ok and res then
            h.fence = h.fence or {}
            h.fence[key(t.x, t.y) .. (t.north and "N" or "W")] = true
            return true
        end
        return false
    elseif p == "barbed" then
        local ok, res = pcall(BB.addBarbed, t)
        if ok and res then
            h.barbed = h.barbed or {}
            h.barbed[key(t.x, t.y) .. (t.north and "N" or "W")] = true
            return true
        end
        return false
    elseif p == "barrel" or p == "generator" then
        local sq = getCell():getGridSquare(t.x, t.y, t.z or 0)
        if not sq or not Rem.Signals then return false end
        local ok, res = pcall(function()
            if p == "barrel" then return Rem.Signals.placeBarrel(sq) ~= nil end
            return Rem.Signals.placeGenerator(sq) ~= nil
        end)
        if ok and res then
            if p == "barrel" then h.builtBarrel = true
            else
                h.builtGenerator = true
                h.generator = { x = t.x, y = t.y, z = t.z or 0 }        -- (combustivel: Rem_Fuel)
            end
            return true
        end
        return false
    elseif BB.EXTRA[p] then
        local ok, res = pcall(BB.EXTRA[p].apply, g, h, t)
        return ok and res == true
    elseif p == "cars" then
        t.left = t.left - 1
        if t.left > 0 then return true end          -- ainda arrastando
        local ok, res = pcall(BB.addCar, t)
        if ok and res then
            h.cars = h.cars or {}
            table.insert(h.cars, { edge = t.edge, x = t.x, y = t.y })
            return true
        end
        return false
    end
    return false
end

-- Janela/porta acabou de ficar com WINDOW_PLANKS: entra na fila de reforco.
local function queueReinforce(g, plan, p, t)
    if (p ~= "windows" and p ~= "doors") or t.left > 0 or not plan then return end
    local more = CFG.MAX_PLANKS - CFG.WINDOW_PLANKS
    if more <= 0 then return end
    table.insert(plan.reinforce, { obj = t.obj, x = t.x, y = t.y, z = t.z, left = more })
    g.home.plan = g.home.plan or {}
    g.home.plan.reinforce = (g.home.plan.reinforce or 0) + more
end

-- Faz um passo (tira da fila, gasta material, conta o dia). Retorna o projeto ou nil.
function BB.step(g, plan)
    local h = g.home
    local p, t = BB.next(g, plan)
    if not p then return nil end
    local cost = CFG.COST[p] or 1
    if Rem.Director.materials(g) < cost then return nil end
    plan = plan or BB.last[g.id]
    local done = BB.apply(g, p, t)
    if p ~= "cars" then t.left = t.left - 1 end
    if t.left <= 0 or not done then table.remove(plan[p], 1) end
    if done then queueReinforce(g, plan, p, t) end
    if done then
        g.materials = Rem.Director.materials(g) - cost
        h.plan = h.plan or {}
        h.plan[p] = math.max(0, (h.plan[p] or 1) - 1)
        if p == "perimeter" then h.fenceBuilt = (h.fenceBuilt or 0) + 1 end
        BB.checkDone(g, p, plan)
    end
    return done and p or nil
end

-- Projeto terminado: festa e diario (uma vez).
function BB.checkDone(g, p, plan)
    local h = g.home
    if plan and #plan[p] > 0 then return false end
    h.finished = h.finished or {}
    if h.finished[p] then return false end
    h.finished[p] = true
    Rem.emit("baseProjectDone", g, p)
    return true
end

-- ---------------------------------------------------------------- limite por dia
function BB.builders(g)
    local n = 0
    for _, id in ipairs(g.members) do
        local p = Rem.getPerson(id)
        if p and p.job == "build" then n = n + 1 end
    end
    return n
end

-- Passos por dia. Grupos de NPC: sandbox "Obras dos grupos" (porcentagem; 0 desliga).
-- Especialidade: engenheiro rende ENGINEER_BONUS vezes mais.
function BB.workforce(g)
    local n = 0
    for _, id in ipairs(g.members) do
        local p = Rem.getPerson(id)
        if p and p.job == "build" then
            local v = (p.archetype == "engenheiro") and CFG.ENGINEER_BONUS or 1
            if Rem.Skills then v = v * Rem.Skills.buildMult(p) end          -- carpintaria
            if Rem.Wounds then v = v * Rem.Wounds.workMult(p) end           -- braco ferido
            n = n + v
        end
    end
    return n
end

function BB.perDay(g)
    local n = math.floor(BB.workforce(g) * CFG.STEPS_PER_DAY + 0.5)
    if not g.player then n = math.floor(n * Rem.cfg("NPCBaseWork", 100) / 100 + 0.5) end
    return n
end

function BB.capLeft(g)
    local h = g.home
    if h.buildDay ~= dayStamp() then h.buildDay, h.buildToday = dayStamp(), 0 end
    return BB.perDay(g) - (h.buildToday or 0)
end

local function daytime()
    local tod = getGameTime():getTimeOfDay()
    return tod >= 7 and tod < 19
end

-- ---------------------------------------------------------------- em cena
local function standFor(p, t)
    local cell = getCell()
    if p == "perimeter" or p == "cars" then
        -- do lado de dentro da cerca / do lado da casa
        local sq = cell:getGridSquare(t.x, t.y, 0)
        if sq and sq:isFree(false) then return t.x + 0.5, t.y + 0.5 end
    end
    local sq = cell:getGridSquare(t.x, t.y, t.z or 0)
    if sq and sq:getRoom() and sq:isFree(false) then return t.x + 0.5, t.y + 0.5 end
    for _, off in ipairs({ { 0, -1 }, { -1, 0 }, { 1, 0 }, { 0, 1 } }) do
        local s = cell:getGridSquare(t.x + off[1], t.y + off[2], t.z or 0)
        if s and s:getRoom() and s:isFree(false) then return t.x + off[1] + 0.5, t.y + off[2] + 0.5 end
    end
    return t.x + 0.5, t.y + 0.5
end

-- Grupo com casa onde a pessoa mora (a sua base ou a de um grupo de NPC).
function BB.homeGroupOf(rec)
    local g = rec.groupId and Rem.getStore().groups[rec.groupId]
    if not g or not g.home or not g.home.x1 or g.activity ~= "home" then return nil end
    return g
end

function BB.behavior(npc, ctx, now)
    local rec = npc.rec
    if rec.job ~= "build" or rec.mode ~= "group" then return false end
    local g = BB.homeGroupOf(rec)
    if not g then return false end
    if g.goal == "hide" or g.goal == "clear" or not daytime() then return false end
    if BB.capLeft(g) <= 0 then return false end
    local plan = BB.last and BB.last[g.id]
    if not plan or now - (g.home.buildScanAt or 0) > 30000 then
        plan = BB.scan(g)
        g.home.buildScanAt = now
    end
    if not plan then return false end
    local p, t = BB.next(g, plan)
    if not p or Rem.Director.materials(g) < (CFG.COST[p] or 1) then return false end
    local sx, sy = standFor(p, t)
    if Rem.distXY(npc.z, sx, sy) > 1.3 then
        Rem.moveTo(npc, sx, sy, t.z or 0, now, "walk")
        return true
    end
    Rem.stopMoving(npc)
    Rem.safe(function() npc.z:faceLocationF(t.x + 0.5, t.y + 0.5) end)
    if now < (npc.nextBuild or 0) then return true end
    npc.nextBuild = now + CFG.STEP_MS
    local done = BB.step(g, plan)
    if done then
        g.home.buildToday = (g.home.buildToday or 0) + 1
        Rem.makeNoise(npc, CFG.NOISE)
        Rem.safe(function() npc.z:playSound((done == "cars") and "BuildWoodenStructureLarge" or "Hammering") end)
        Rem.bark(npc, (done == "perimeter") and "build_fence" or ((done == "cars") and "build_car" or "work"))
    end
    return true
end
Rem.registerBehavior({ name = "base_build", priority = CFG.PRIORITY, run = BB.behavior })

-- ---------------------------------------------------------------- longe de voce
-- A cada hora de dia, cada um que esta fortificando faz STEPS_PER_DAY / 12 passos (guardados).
function BB.offscene(g)
    local h = g.home
    if not daytime() or not h or not h.x1 then return 0 end
    -- casa que voce nunca viu: o trabalho e estimado (aplica-se o que couber quando carregar)
    if not h.plan then
        h.plan = {}
        for p, n in pairs(CFG.ESTIMATE) do h.plan[p] = n end
        h.planEstimated = true
    end
    for _, id in ipairs(g.members) do
        local p = Rem.getPerson(id)
        if p and p.onScene then return 0 end          -- (com alguem em cena, o trabalho e de verdade)
    end
    h.pendingBuild = h.pendingBuild or {}
    local steps = math.ceil(BB.perDay(g) / 12)
    local made = 0
    for _ = 1, steps do
        if BB.capLeft(g) <= 0 then break end
        local proj = nil
        for _, p in ipairs(BB.projectsFor(g)) do
            if (h.plan[p] or 0) > (h.pendingBuild[p] or 0) then proj = p break end
        end
        if not proj or Rem.Director.materials(g) < (CFG.COST[proj] or 1) then break end
        g.materials = Rem.Director.materials(g) - (CFG.COST[proj] or 1)
        h.pendingBuild[proj] = (h.pendingBuild[proj] or 0) + 1
        h.buildToday = (h.buildToday or 0) + 1
        made = made + 1
    end
    return made
end

-- Casa carregou: aplica os passos feitos longe de voce.
function BB.applyPending(g)
    local h = g.home
    if not h.pendingBuild or not S.isLoaded(h) then return 0 end
    local plan = BB.scan(g)
    if not plan then return 0 end
    local applied = 0
    for _, p in ipairs(BB.projectsFor(g)) do
        local n = h.pendingBuild[p] or 0
        while n > 0 and plan[p][1] do
            local t = plan[p][1]
            local done = BB.apply(g, p, t)
            if p ~= "cars" then t.left = t.left - 1 end
            if t.left <= 0 or not done then table.remove(plan[p], 1) end
            if done then queueReinforce(g, plan, p, t) end
            if done or p == "cars" then n = n - 1 end
            if done then applied = applied + 1 end
        end
        if #plan[p] == 0 then BB.checkDone(g, p, plan) end
    end
    h.pendingBuild = nil
    BB.scan(g)
    if applied > 0 then Rem.debug("base: " .. applied .. " passos de obra feitos enquanto voce estava longe") end
    return applied
end

-- ---------------------------------------------------------------- defesa das obras
-- O quanto as obras da casa ajudam a resistir (ataques e hordas): janelas, cerca, arame,
-- carros. 0 (casa aberta) a uns 6,5 (tudo pronto).
function BB.structureBonus(g)
    local h = g.home
    if not h then return 0 end
    local win = (h.windowsTotal and h.windowsTotal > 0) and (h.windowsDone or 0) / h.windowsTotal or 0
    local fence = (h.fenceTotal and h.fenceTotal > 0) and (h.fenceBuilt or 0) / h.fenceTotal or 0
    local barbed = 0
    for _ in pairs(h.barbed or {}) do barbed = barbed + 1 end
    barbed = (h.fenceTotal and h.fenceTotal > 0) and math.min(1, barbed / h.fenceTotal) or 0
    return win * 2 + fence * 3 + barbed * 1 + math.min(2, #(h.cars or {}) * 0.5)
end

-- ---------------------------------------------------------------- danos (eventos)
-- Remove n pedacos da cerca (horda forcou). Retorna quantos.
function BB.damageFence(g, n)
    local h = g.home
    if not h.fence or not S.isLoaded(h) then
        h.fenceDamage = (h.fenceDamage or 0) + n
        return 0
    end
    local removed = 0
    local cell = getCell()
    for k in pairs(h.fence) do
        if removed >= n then break end
        local x, y = k:match("^(%-?%d+),(%-?%d+)")
        local sq = x and cell:getGridSquare(tonumber(x), tonumber(y), 0)
        if sq then
            for _, obj in ipairs(objectsOf(sq)) do
                local ok, md = pcall(function() return obj:getModData() end)
                if ok and md and md.remFence then
                    pcall(function() sq:transmitRemoveItemFromSquare(obj) end)
                    pcall(function() obj:removeFromSquare() end)
                    break
                end
            end
        end
        h.fence[k] = nil
        removed = removed + 1
    end
    if h.finished then h.finished.perimeter = nil end
    return removed
end

-- ---------------------------------------------------------------- ganchos
-- Todos os grupos com casa (a sua base e as dos NPCs) trabalham longe de voce.
Rem.on("worldHour", function()
    for _, g in pairs(Rem.getStore().groups) do
        if g.home and g.home.x1 and g.activity == "home" and #g.members > 0 then Rem.safe(BB.offscene, g) end
    end
end)

local lastTick = -999999
Rem.on("sceneUpdate", function(player, now)
    if now - lastTick < 4000 then return end
    lastTick = now
    local px, py = player:getX(), player:getY()
    for _, g in pairs(Rem.getStore().groups) do
        local h = g.home
        if h and h.x1 and Rem.dist2(px, py, h.x, h.y) < S.CFG.PREPARE_RADIUS and S.isLoaded(h)
            and (g.player or h.fortified) then          -- (casa de NPC: so depois de "preparada")
            if h.fenceDamage and h.fenceDamage > 0 then
                local n = h.fenceDamage
                h.fenceDamage = nil
                BB.damageFence(g, n)
            end
            if h.pendingBuild then Rem.safe(BB.applyPending, g) end
            if not h.plan or h.planEstimated then
                h.planEstimated = nil
                Rem.safe(BB.scan, g)
            end
        end
    end
end)

Rem.on("playerBaseSet", function(g) BB.last = BB.last or {} BB.last[g.id] = nil g.home.plan = nil end)
