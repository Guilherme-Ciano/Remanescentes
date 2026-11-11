-- Remanescentes - os militares dos primeiros dias.
--
-- Nos primeiros dias o Exercito monta uma barreira de quarentena perto de onde voce comecou
-- (marcada no mapa: "Barreira militar"). Enquanto ela esta de pe:
--   * soldados armados guardam o lugar, atiram nos zumbis e mandam voce se afastar
--     ("Area em quarentena! Volte para casa!"); conversar so rende ordens e noticias;
-- A partir do dia ABANDON_DAY eles somem sem explicacao (Diario). A barreira fica para tras:
--   * alguns soldados viraram zumbis ali mesmo;
--   * a carga ficou no chao (municao, racoes, remedio) para quem chegar primeiro.
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_Barks"
require "Remanescentes/Rem_Journal"
require "Remanescentes/Rem_MapMarks"
require "Remanescentes/Rem_Ambient"
local Rem = Remanescentes
local AM = Rem.Ambient

local ML = Rem.module("Military", {
    PLACE = { 45, 80 },       -- distancia do jogador quando a barreira e montada
    ABANDON_DAY = 5,
    SHOW_DIST = 50,
    SOLDIERS = 3,
    WARN_DIST = 8,
    ZOMBIES = { 3, 6 },
    LOOT = { "Base.Bullets9mmBox", "Base.ShotgunShellsBox", "Base.308Bullets", "Base.WaterRationCan", "Base.WaterRationCan",
        "Base.TinnedBeans", "Base.Bandage", "Base.Bandage", "Base.Pills", "Base.Disinfectant" },
    LOOT_N = 6,
    OUTFITS = { "ArmyCamoGreen", "ArmyCamoDesert" },
    GUNS = { "Base.HuntingRifle", "Base.Shotgun", "Base.Pistol" },
})
local CFG = ML.CFG

Rem.registerFaction("militares", {
    hostileToPlayer = false, enemies = { saqueadores = true }, temper = "defensivo",
    outfits = CFG.OUTFITS, groupNames = { "Exercito" },
})
Rem.MapMarks.COLORS.militares = { 0.35, 0.45, 0.2 }

Rem.BARKS.soldier_warn = { urgent = true, n = 4, cd = 12000 }
Rem.BARKS.soldier_idle = { n = 4, cd = 60000 }

local function store()
    local s = Rem.getStore()
    return s
end

function ML.get() return store().checkpoint end

function ML.day()
    local t = store().timeline
    if not t or not t.startHours then return 0 end
    return (Rem.worldHours() - t.startHours) / 24
end

-- ---------------------------------------------------------------- montar
function ML.place(player)
    if ML.get() or ML.day() >= CFG.ABANDON_DAY then return nil end
    local sq = AM.spawnPoint(player, CFG.PLACE[1], CFG.PLACE[2])
    if not sq then return nil end
    local cp = { x = sq:getX(), y = sq:getY(), z = 0, state = "manned", at = Rem.worldHours() }
    store().checkpoint = cp
    Rem.MapMarks.add({ id = "checkpoint", x = cp.x, y = cp.y, symbol = "Asterisk", color = Rem.MapMarks.COLORS.militares,
        text = getText("IGUI_Rem_Map_checkpoint") }, nil)
    Rem.Journal.add("IGUI_Rem_Journal_checkpoint")
    return cp
end

-- ---------------------------------------------------------------- em cena
local function soldiersOnScene()
    local out = {}
    for _, npc in pairs(Rem.active) do if npc.rec.ambient == "soldier" then table.insert(out, npc) end end
    return out
end

function ML.showSoldiers(cp, player)
    local made = {}
    for i = 1, CFG.SOLDIERS do
        local sq = getCell():getGridSquare(cp.x + (i - 2) * 2, cp.y, 0)
        if not sq or not sq:isFree(false) then sq = AM.spawnPoint(player, 20, 30) end
        local npc = sq and AM.makePerson(sq, { faction = "militares", ambient = "soldier", archetype = "atirador" })
        if npc then
            local rec = npc.rec
            rec.spotX, rec.spotY = sq:getX() + 0.5, sq:getY() + 0.5
            local gun = Rem.pick(CFG.GUNS)
            local def = Rem.Ranged and Rem.Ranged.GUNS[gun]
            if def then rec.firearm, rec.ammoItem, rec.ammo = gun, def.ammo, Rem.Ranged.CFG.AMMO_MAX end
            table.insert(made, npc)
        end
    end
    cp.shown = #made > 0
    return made
end

-- Abandonada: zumbis de farda e a carga no chao (uma vez).
function ML.leftBehind(cp)
    cp.state = "looted"
    local n = ZombRand(CFG.ZOMBIES[1], CFG.ZOMBIES[2] + 1)
    for _ = 1, n do
        Rem.safe(function()
            addZombiesInOutfit(cp.x + ZombRand(-4, 5), cp.y + ZombRand(-4, 5), 0, 1, Rem.pick(CFG.OUTFITS), 0,
                false, false, false, false, false, false, 1.0)
        end)
    end
    local placed = 0
    local sq = getCell():getGridSquare(cp.x, cp.y, 0)
    if sq then
        for _ = 1, CFG.LOOT_N do
            if Rem.safe(function() sq:AddWorldInventoryItem(Rem.pick(CFG.LOOT), ZombRandFloat(0.1, 0.9), ZombRandFloat(0.1, 0.9), 0) end) then
                placed = placed + 1
            end
        end
    end
    Rem.Journal.add("IGUI_Rem_Journal_checkpoint_found")
    return placed
end

function ML.tick(player, now)
    local cp = ML.get()
    if not cp then
        if ML.day() < CFG.ABANDON_DAY then ML.place(player) end
        return
    end
    if cp.state == "manned" and ML.day() >= CFG.ABANDON_DAY then
        cp.state = "abandoned"
        for _, npc in ipairs(soldiersOnScene()) do AM.leave(npc, player) end
        Rem.Journal.add("IGUI_Rem_Journal_checkpoint_gone")
    end
    local d = Rem.dist2(player:getX(), player:getY(), cp.x, cp.y)
    if cp.state == "manned" then
        if d <= CFG.SHOW_DIST and #soldiersOnScene() == 0 then ML.showSoldiers(cp, player) end
    elseif cp.state == "abandoned" and d <= CFG.SHOW_DIST * 0.6 then
        ML.leftBehind(cp)
    end
end
local nextTick = 0
Rem.on("sceneUpdate", function(player, now)
    if now < nextTick then return end
    nextTick = now + 2000
    Rem.safe(ML.tick, player, now)
end)

-- Soldado: fica no posto e manda voce se afastar.
AM.HANDLERS.soldier = function(npc, ctx, now)
    local rec = npc.rec
    local cp = ML.get()
    if not cp or cp.state ~= "manned" then
        AM.leave(npc, ctx.player)
        return true
    end
    rec.expiresAt = Rem.worldHours() + 3
    if Rem.dist2(npc.z:getX(), npc.z:getY(), rec.spotX, rec.spotY) > 1.5 then
        Rem.moveTo(npc, rec.spotX, rec.spotY, 0, now, "walk")
        return true
    end
    Rem.stopMoving(npc)
    local p = ctx.player
    if p then
        local d = Rem.dist(npc.z, p)
        if d <= CFG.WARN_DIST then
            Rem.safe(function() npc.z:faceThisObject(p) end)
            Rem.bark(npc, "soldier_warn")
        elseif d <= 20 then
            Rem.bark(npc, "soldier_idle")
        end
    end
    return true
end

-- "Como vao as coisas?" de um soldado: noticias oficiais.
function ML.status(npc)
    if npc.rec.faction ~= "militares" then return nil end
    local day = math.floor(ML.day())
    local key = (day < 2) and "IGUI_Rem_Military_status_1" or ((day < 4) and "IGUI_Rem_Military_status_2" or "IGUI_Rem_Military_status_3")
    return { key = key, args = {} }
end
