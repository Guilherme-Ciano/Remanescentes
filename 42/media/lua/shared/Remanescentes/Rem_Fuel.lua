-- Remanescentes - gasolina para o gerador da sua base.
--
-- O gerador que os moradores montam (obra "gerador", Rem_BaseBuild) gasta combustivel:
--   * a noite, com gasolina, eles ligam (com voce la, o gerador de verdade liga e a casa
--     acende); de dia desligam para economizar;
--   * longe de voce, gasta FUEL_PER_HOUR por hora ligado;
--   * luz a noite: mais defesa (eles veem chegando) e moral melhor (ninguem gosta do
--     escuro - e quem tem medo do escuro sofre menos, Rem_Traumas).
-- Gasolina: tarefa nova "buscar gasolina" (em dupla, como as outras saidas): sifonam carros
-- e postos em volta e trazem para o estoque (h.fuel, ate FUEL_MAX - galoes guardados).
-- Acabou a gasolina: aviso no Diario.
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_Journal"
require "Remanescentes/Rem_PlayerBase"
local Rem = Remanescentes
local PB = Rem.PlayerBase

local FU = Rem.module("Fuel", {
    FUEL_PER_HOUR = 1.5,      -- (0-100, como o gerador do jogo)
    TANK = 100,
    FUEL_MAX = 200,           -- tanque + galoes guardados
    TRIP = { 10, 25 },        -- gasolina trazida por saida (fora de cena)
    SIPHON = { 4, 9 },        -- por carro sifonado (em cena)
    LIGHT_DEFENSE = 1.0,
    LIGHT_MORALE = 1,         -- por hora a noite, com luz
    NIGHT_START = 19,
    NIGHT_END = 6,
    SYNC_MS = 5000,
})
local CFG = FU.CFG

PB.TRIP_JOBS.fuel = true
-- a tarefa nova entra antes da enfermaria e do descanso
do
    local exists = false
    for _, j in ipairs(PB.JOBS) do if j == "fuel" then exists = true end end
    if not exists then
        local pos = #PB.JOBS + 1
        for i, j in ipairs(PB.JOBS) do if j == "materials" then pos = i + 1 end end
        table.insert(PB.JOBS, pos, "fuel")
    end
end

Rem.BARKS.trip_fuel = { urgent = true, n = 3, cd = 0 }
Rem.BARKS.generator_on = { urgent = true, n = 2, cd = 0 }

local function night()
    local tod = getGameTime():getTimeOfDay()
    return tod >= CFG.NIGHT_START or tod < CFG.NIGHT_END
end

function FU.has(g) return g ~= nil and g.home ~= nil and g.home.builtGenerator == true end
function FU.amount(g) return (g and g.home and g.home.fuel) or 0 end

function FU.add(g, n)
    local h = g.home
    h.fuel = math.min(CFG.FUEL_MAX, (h.fuel or 0) + n)
    if h.fuel > 0 then h.fuelOutNoted = nil end
    return h.fuel
end

-- Luz agora? (gerador montado, com gasolina, de noite)
function FU.lit(g)
    return FU.has(g) and FU.amount(g) > 0 and night()
end

function FU.defenseBonus(g) return FU.lit(g) and CFG.LIGHT_DEFENSE or 0 end

-- ---------------------------------------------------------------- em cena: o gerador de verdade
local function generatorAt(d)
    local sq = d and getCell():getGridSquare(d.x, d.y, d.z or 0)
    if not sq then return nil end
    local objs = sq:getObjects()
    for i = 0, objs:size() - 1 do
        local o = objs:get(i)
        if instanceof(o, "IsoGenerator") then return o end
    end
    return nil
end

-- Sincroniza o tanque do gerador com o estoque de gasolina e liga/desliga.
function FU.sync(g)
    local h = g.home
    local gen = generatorAt(h.generator)
    if not gen then return nil end
    -- o que o jogo gastou com o gerador ligado
    if h.genFuelSeen then
        local used = h.genFuelSeen - gen:getFuel()
        if used > 0 then h.fuel = math.max(0, (h.fuel or 0) - used) end
    end
    -- completa o tanque com o que tem guardado
    local want = math.min(CFG.TANK, h.fuel or 0)
    Rem.safe(function() gen:setFuel(want) end)
    h.genFuelSeen = want
    local on = night() and want > 0
    if on ~= gen:isActivated() then
        Rem.safe(function() gen:setActivated(on) end)
        if on then
            for _, npc in pairs(Rem.active) do
                if npc.rec.groupId == g.id then Rem.bark(npc, "generator_on", true) break end
            end
        end
    end
    return gen
end

local lastSync = -999999
Rem.on("sceneUpdate", function(player, now)
    if now - lastSync < CFG.SYNC_MS then return end
    lastSync = now
    local g = PB.get()
    if not FU.has(g) or not g.home.generator then return end
    if Rem.dist2(player:getX(), player:getY(), g.home.x, g.home.y) < Rem.Safehouse.CFG.PREPARE_RADIUS then
        Rem.safe(FU.sync, g)
    end
end)

-- ---------------------------------------------------------------- longe: gasta, anima
function FU.hourly()
    local g = PB.get()
    if not FU.has(g) then return end
    local h = g.home
    if night() and (h.fuel or 0) > 0 then
        local loaded = g.home.genFuelSeen ~= nil and Rem.Safehouse.isLoaded(h)
        if not loaded then h.fuel = math.max(0, h.fuel - CFG.FUEL_PER_HOUR) end
        for _, p in ipairs(PB.members(g)) do
            if Rem.Persona then Rem.Persona.addMorale(p, CFG.LIGHT_MORALE) end
        end
        if h.fuel <= 0 and not h.fuelOutNoted then
            h.fuelOutNoted = true
            Rem.Journal.add("IGUI_Rem_Journal_fuel_out")
        end
    end
end
Rem.on("worldHour", function() Rem.safe(FU.hourly) end)

-- ---------------------------------------------------------------- saidas para buscar gasolina
-- (fora de cena: Rem_PlayerBase.tripOffscene chama FU.trip; em cena: FU.siphon)
function FU.trip(g)
    local n = ZombRand(CFG.TRIP[1], CFG.TRIP[2] + 1)
    FU.add(g, n)
    return n
end

function FU.siphon(npc)
    local rec = npc.rec
    rec.fuelCarry = (rec.fuelCarry or 0) + ZombRand(CFG.SIPHON[1], CFG.SIPHON[2] + 1)
    Rem.makeNoise(npc, 6)
    return rec.fuelCarry
end

function FU.deposit(npc, g)
    local rec = npc.rec
    if (rec.fuelCarry or 0) > 0 and g then
        FU.add(g, rec.fuelCarry)
        Rem.Journal.add("IGUI_Rem_Journal_fuel_trip", tostring(rec.name), tostring(math.floor(rec.fuelCarry)))
    end
    rec.fuelCarry = nil
end
