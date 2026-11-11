-- Remanescentes - eventos raros: cada um acontece no maximo uma vez por campanha.
--
--   doctor   um medico de verdade (do hospital) aparece no portao da sua base pedindo abrigo.
--            Com voce la, converse com ele; longe, os moradores decidem.
--   convoy   um comboio militar abandonado e avistado (marcado no mapa). Chegando la:
--            carros queimados, soldados que viraram zumbis e a carga espalhada.
--   cult     a seita deixa um convite: eles querem voce do lado deles (a reputacao com eles
--            sobe e o lugar vai para o mapa).
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_Journal"
require "Remanescentes/Rem_MapMarks"
local Rem = Remanescentes

local RE = Rem.module("RareEvents", {
    CHANCE = 6,               -- (%) por dia, para cada evento que ainda nao aconteceu
    MIN_DAY = { doctor = 3, convoy = 6, cult = 8 },
    CONVOY_DIST = { 150, 400 },
    CONVOY_ARRIVE = 25,
    CONVOY_ZOMBIES = { 4, 8 },
    CONVOY_LOOT = { "Base.Bullets9mmBox", "Base.ShotgunShellsBox", "Base.308Bullets", "Base.HuntingRifle",
        "Base.WaterRationCan", "Base.WaterRationCan", "Base.TinnedBeans", "Base.Bandage", "Base.Disinfectant", "Base.Pills" },
    CONVOY_LOOT_N = 8,
    CONVOY_CARS = 2,
    CULT_REP = 10,
})
local CFG = RE.CFG

RE.ORDER = { "doctor", "convoy", "cult" }

function RE.store()
    local s = Rem.getStore()
    s.rare = s.rare or {}
    return s.rare
end

function RE.done(kind) return RE.store()[kind] ~= nil end

local function day()
    local t = Rem.getStore().timeline
    if not t or not t.startHours then return 0 end
    return (Rem.worldHours() - t.startHours) / 24
end

-- ---------------------------------------------------------------- eventos
RE.RUN = {}

function RE.RUN.doctor(player)
    local PB = Rem.PlayerBase
    local g = PB and PB.get()
    if not g or not Rem.BaseEvents then return nil end
    local res = Rem.BaseEvents.visitor(g, player)
    if not res then return nil end
    local rec = res.rec or res
    rec.archetype = "medico"
    rec.profession, rec.professionUI = "base:doctor", "UI_prof_Doctor"
    Rem.Journal.add("IGUI_Rem_Journal_rare_doctor", tostring(rec.name))
    return rec
end

function RE.RUN.convoy(player)
    local a = ZombRandFloat(0, math.pi * 2)
    local d = ZombRand(CFG.CONVOY_DIST[1], CFG.CONVOY_DIST[2] + 1)
    local c = { x = math.floor(player:getX() + math.cos(a) * d), y = math.floor(player:getY() + math.sin(a) * d) }
    RE.store().convoySpot = c
    Rem.MapMarks.add({ id = "convoy", x = c.x, y = c.y, symbol = "Asterisk",
        color = Rem.MapMarks.COLORS.militares or Rem.MapMarks.COLORS.quest, text = getText("IGUI_Rem_Map_convoy") }, nil)
    Rem.Journal.add("IGUI_Rem_Journal_rare_convoy")
    return c
end

function RE.RUN.cult(player)
    local best, bestD = nil, nil
    for _, g in pairs(Rem.getStore().groups) do
        if g.faction == "seita" and g.home and #g.members > 0 then
            local dd = Rem.dist2(player:getX(), player:getY(), g.home.x, g.home.y)
            if not bestD or dd < bestD then best, bestD = g, dd end
        end
    end
    if not best then return nil end
    Rem.changeRep(best.id, CFG.CULT_REP, "convite")
    Rem.MapMarks.markGroup(best, nil)
    Rem.Journal.add("IGUI_Rem_Journal_rare_cult", Rem.Journal.groupName(best))
    return best
end

-- Dispara um evento (forcado ou sorteado). Retorna o tipo ou nil.
function RE.fire(kind, player)
    player = player or getPlayer()
    if not player or RE.done(kind) then return nil end
    local ok, res = pcall(RE.RUN[kind], player)
    if ok and res then
        RE.store()[kind] = Rem.worldHours()
        Rem.emit("rareEvent", kind)
        return kind
    end
    if not ok then Rem.log("ERRO no evento raro " .. kind .. ": " .. tostring(res)) end
    return nil
end

function RE.daily()
    local d = day()
    for _, kind in ipairs(RE.ORDER) do
        if not RE.done(kind) and d >= CFG.MIN_DAY[kind] and ZombRand(100) < CFG.CHANCE then
            if RE.fire(kind) then return kind end
        end
    end
    return nil
end
Events.EveryDays.Add(function() if Rem.isAuthority() then Rem.safe(RE.daily) end end)

-- ---------------------------------------------------------------- comboio: chegar la
function RE.arriveConvoy(c, player)
    c.found = true
    local cell = getCell()
    for _ = 1, ZombRand(CFG.CONVOY_ZOMBIES[1], CFG.CONVOY_ZOMBIES[2] + 1) do
        Rem.safe(function()
            addZombiesInOutfit(c.x + ZombRand(-6, 7), c.y + ZombRand(-6, 7), 0, 1, Rem.pick({ "ArmyCamoGreen", "ArmyCamoDesert" }), 0,
                false, false, false, false, false, false, 1.0)
        end)
    end
    local cars = Rem.BaseBuild and Rem.BaseBuild.CARS or {}
    for i = 1, CFG.CONVOY_CARS do
        local sq = cell:getGridSquare(c.x + (i - 1) * 6, c.y, 0)
        if sq and #cars > 0 then Rem.safe(function() addVehicleDebug(Rem.pick(cars), IsoDirections.E, nil, sq) end) end
    end
    local sq = cell:getGridSquare(c.x, c.y + 2, 0)
    local placed = 0
    if sq then
        for _ = 1, CFG.CONVOY_LOOT_N do
            if Rem.safe(function() sq:AddWorldInventoryItem(Rem.pick(CFG.CONVOY_LOOT), ZombRandFloat(0.1, 0.9), ZombRandFloat(0.1, 0.9), 0) end) then
                placed = placed + 1
            end
        end
    end
    Rem.Journal.add("IGUI_Rem_Journal_rare_convoy_found")
    return placed
end

local nextCheck = 0
Rem.on("sceneUpdate", function(player, now)
    if now < nextCheck then return end
    nextCheck = now + 3000
    local c = RE.store().convoySpot
    if c and not c.found and Rem.dist2(player:getX(), player:getY(), c.x, c.y) <= CFG.CONVOY_ARRIVE then
        Rem.safe(RE.arriveConvoy, c, player)
    end
end)

for _, kind in ipairs(RE.ORDER) do
    Rem.registerDebugOption("ContextMenu_Rem_Rare_" .. kind, function(x, y, z, player)
        RE.store()[kind] = nil
        player:Say(kind .. ": " .. tostring(RE.fire(kind, player)))
    end, "ambient")
end
