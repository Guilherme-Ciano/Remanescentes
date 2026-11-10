-- Mocks da API do Project Zomboid e utilitarios dos testes offline.
-- Uso: local T = dofile("tests/mocks.lua"). Cria os globais que o jogo daria (Events,
-- getPlayer, getCell, ZombRand, ModData...) e retorna a tabela T com:
--   T.check(cond, msg), T.tick(ms, n), T.fire(evento, ...), T.newZombie(x, y, z, fx, fy),
--   T.square(x, y, z), T.clearZombies(keep), T.saidPrefix(z, prefixo), T.count(t),
--   T.addBuilding(id, x, y, w, h), T.JList(t), T.newWeapon(id), T.defaults()
--   T.player, T.parts, T.events, T.logs, T.store, T.zombies (tabelas: podem ser apelidadas)
--   T.clock, T.worldHours, T.timeOfDay, T.daylight, T.sounds, T.blockedSq, T.indoorSq,
--   T.worldLoaded, T.rngCounter (valores: leia/escreva sempre via T.)
--   T.print = print original (o print do mod vai para T.logs)
-- O global T_MOD_DIR (opcional) e o prefixo da pasta do mod.

local T = {}
T.MOD = (T_MOD_DIR or "") .. "42/media/lua/"

-- ------------------------------------------------------------------ mocks basicos
T.clock = 0
T.trace = {}  -- registro (CHECK/PATH/VAR) para comparar execucoes: REM_TRACE=arquivo
local events = {}
T.events = events
Events = setmetatable({}, { __index = function(t, name)
    local ev = { list = {} }
    function ev.Add(fn) table.insert(ev.list, fn) end
    function ev.Remove(fn) end
    events[name] = ev
    rawset(t, name, ev)
    return ev
end })
function T.fire(name, ...)
    if events[name] then for _, fn in ipairs(events[name].list) do fn(...) end end
end

function T.defaults()
    return { MaxActive = 12, NPCHealth = 3.0, NPCDamageMultiplier = 1.0, ZombieDamage = 0.15,
        FriendlyFire = false, DebugMenu = true, Verbose = true, ZombieSightRange = 10,
        NPCNoiseMultiplier = 1.0, FleeHealthPercent = 30, Barks = true, ZombieAttackMode = 1,
        NPCVsPlayerDamage = 1.0, WorldGroups = 0, RaiderPercent = 20, ScavengeDeathChance = 0,
        LootLeftPercent = 0, AmbientDensity = 0 }  -- passagem desligada (ligada so em test_12)
end
SandboxVars = { Remanescentes = T.defaults() }

local logs = {}
T.logs = logs
local realPrint = print
T.print = realPrint
print = function(s) table.insert(logs, s) end
function getText(k, ...) return k end
function isClient() return false end
function isServer() return false end
function getTimestampMs() return T.clock end
-- sorteio deterministico que varia (ciclo), para nao escolher sempre o mesmo predio
T.rngCounter = 0
function ZombRand(a, b)
    T.rngCounter = T.rngCounter + 1
    if b then return a + (T.rngCounter % math.max(1, b - a)) end
    return T.rngCounter % math.max(1, a)
end
function ZombRandFloat(a, b) return (a + b) / 2 end
T.worldHours, T.timeOfDay = 100, 12
function getGameTime()
    return { getWorldAgeHours = function() return T.worldHours end, getTimeOfDay = function() return T.timeOfDay end }
end
function instanceof(o, cls) return type(o) == "table" and o._class == cls end

T.daylight = 1.0
function getClimateManager() return { getDayLightStrength = function() return T.daylight end } end

T.sounds = {}
function addSound(src, x, y, z, radius, volume) table.insert(T.sounds, { src = src, radius = radius }) end

local store = {}
T.store = store
BloodBodyPartType = { MAX = { index = function() return 3 end }, FromIndex = function(i) return i end }
BodyPartType = { MAX = "MAX", ToIndex = function() return 17 end, FromIndex = function(i) return i end }
ModData = { getOrCreate = function(k) store[k] = store[k] or {}; return store[k] end }

function T.JList(t)
    return { _t = t, size = function(self) return #self._t end, get = function(self, i) return self._t[i + 1] end }
end

-- predios do "mapa"
local buildingDefs = {}
T.buildingDefs = buildingDefs
function T.addBuilding(id, x, y, w, h)
    local d = { id = id, x = x, y = y, w = w, h = h }
    function d:getX() return self.x end
    function d:getY() return self.y end
    function d:getW() return self.w end
    function d:getH() return self.h end
    function d:getID() return self.id end
    table.insert(buildingDefs, d)
    if Remanescentes and Remanescentes.Regions then Remanescentes.Regions.resetIndex() end
    return d
end
function getWorld()
    return { getMetaGrid = function() return {
        getBuildings = function() return T.JList(buildingDefs) end,
        getBuildingAt = function(_, x, y)
            for _, d in ipairs(buildingDefs) do
                if x >= d.x and x < d.x + d.w and y >= d.y and y < d.y + d.h then return d end
            end
            return nil
        end,
    } end }
end

-- ------------------------------------------------------------------ personagens falsos
local zombies = {}
T.zombies = zombies
local nextPid = 100

function T.newWeapon(id)
    local stats = { ["Base.BaseballBat"] = { 0.8, 1.1, 1.25 }, ["Base.HuntingKnife"] = { 0.6, 1.2, 0.9 } }
    local s = stats[id] or { 0.5, 1.0, 1.0 }
    return { _class = "HandWeapon", id = id,
        getMinDamage = function() return s[1] end, getMaxDamage = function() return s[2] end,
        getMaxRange = function() return s[3] end, getSoundRadius = function() return 15 end,
        getSwingSound = function() return "Swing" end, getZombieHitSound = function() return "Hit" end }
end
T.WEAPONS = { ["Base.BaseballBat"] = true, ["Base.HuntingKnife"] = true, ["Base.KitchenKnife"] = true, ["Base.Axe"] = true,
    ["Base.Crowbar"] = true, ["Base.LeadPipe"] = true, ["Base.Shovel"] = true, ["Base.Machete"] = true, ["Base.Hammer"] = true,
    ["Base.Wrench"] = true, ["Base.Pipe"] = true, ["Base.Pistol"] = true, ["Base.Shotgun"] = true, ["Base.HuntingRifle"] = true }
function instanceItem(id)
    if T.WEAPONS[id] or not T.newItem then
        local w = T.newWeapon(id)
        function w:getFullType() return id end
        function w:getDisplayName() return id end
        function w:getDisplayCategory() return "Weapon" end
        function w:isFood() return false end
        function w:getActualWeight() return 2 end
        return w
    end
    return T.newItem(id)
end

local function vec(x, y) return { getX = function() return x end, getY = function() return y end } end

function T.newZombie(x, y, z, fx, fy)
    nextPid = nextPid + 1
    local o = { x = x, y = y, z = z, hp = 1.5, dead = false, useless = false, vars = {}, pid = nextPid,
        target = nil, inWorld = true, path = nil, said = {}, onFloor = false, fx = fx or 0, fy = fy or -1,
        canSee = true, noTeeth = false, attacking = false, outcome = "" }
    function o:getX() return self.x end
    function o:getY() return self.y end
    function o:getZ() return self.z end
    function o:getHealth() return self.hp end
    function o:setHealth(h) self.hp = h end
    function o:isDead() return self.dead end
    function o:Kill(k) self.dead = true; T.fire("OnZombieDead", self) end
    function o:setUseless(b) self.useless = b end
    function o:isUseless() return self.useless end
    function o:setNoTeeth(b) self.noTeeth = b end
    function o:setTarget(t) self.target = t end
    function o:getTarget() return self.target end
    function o:setVariable(k, v) self.vars[k] = v; table.insert(T.trace, "VAR " .. self.pid .. " " .. k .. "=" .. tostring(v) .. " " .. T.clock) end
    function o:getVariableBoolean(k) return self.vars[k] == true end
    function o:setAvoidDamage(b) self.avoid = b end
    function o:setPrimaryHandItem(i) self.hand = i end
    function o:getPrimaryHandItem() return self.hand end
    function o:clearItemsToSpawnAtDeath() end
    function o:addItemToSpawnAtDeath() end
    function o:resetModelNextFrame() end
    function o:getPersistentOutfitID() return self.pid end
    function o:Say(s) table.insert(self.said, s) end
    function o:pathToLocationF() error("nao usar zombie:pathToLocationF (cai em walktoward)") end
    function o:pathToCharacter(c) self.path = { c.x, c.y }; self.chasing = c end
    function o:getPathFindBehavior2()
        local me = self
        return { pathToLocationF = function(_, x, y, z) me.path = { x, y }; table.insert(T.trace, "PATH " .. me.pid .. " " .. x .. " " .. y .. " " .. T.clock) end, cancel = function() me.path = nil end }
    end
    function o:getForwardDirection() return vec(self.fx, self.fy) end
    function o:CanSee(other) return self.canSee end
    function o:faceLocationF() end
    function o:isFemale() return self.female == true end
    function o:dressInNamedOutfit(name) self.dressed = name; self.outfit = name; self.naked = false; T.nextPid = (T.nextPid or 5000) + 1; self.pid = T.nextPid end
    function o:getHumanVisual()
        local me = self
        return { setSkinTextureName = function(_, n) me.skin = n end, removeBlood = function() end, removeDirt = function() end }
    end
    function o:getItemVisuals()
        local me = self
        if me.naked then return T.JList({}) end   -- corpo pelado (roupa invalida para o genero)
        return T.JList({ { setBlood = function() me.cleaned = true end, setDirt = function() end } })
    end
    function o:resetModel() end
    function o:faceThisObject() end
    function o:playSound() end
    function o:splatBloodFloor() end
    function o:setStaggerBack() end
    function o:isOnFloor() return self.onFloor end
    function o:getActionStateName() return self.state or "idle" end
    function o:isBecomeCrawler() return self.becomeCrawler == true end
    function o:setBecomeCrawler(b) self.becomeCrawler = b end
    function o:isCrawling() return self.crawling == true end
    function o:setCrawler(b) self.crawling = b end
    function o:setCanWalk(b) self.canWalk = b end
    function o:getVoiceSoundName() return "MaleZombieVoiceA" end
    function o:getEmitter()
        local me = self
        return { isPlaying = function(_, n) return me.voicePlaying == n end,
                 stopSoundByName = function(_, n) if me.voicePlaying == n then me.voicePlaying = nil end me.voiceStopped = (me.voiceStopped or 0) + 1 end }
    end
    function o:isExistInTheWorld() return self.inWorld end
    function o:getCurrentSquare() return self.inWorld and {} or nil end
    function o:isAttacking() return self.attacking end
    function o:getAttackOutcome() return self.outcome end
    function o:removeFromWorld() self.inWorld = false end
    function o:removeFromSquare() end
    table.insert(zombies, o)
    return o
end

function addZombiesInOutfit(x, y, z, n, outfit, femaleChance)
    local zz = T.newZombie(x, y, z)
    zz.outfit, zz.femaleChance = outfit, femaleChance
    zz.female = femaleChance == 100
    return T.JList({ zz })
end

-- jogador com partes do corpo
local parts = {}
T.parts = parts
local player = { _class = "IsoPlayer", x = 10, y = 10, z = 0, said = {}, sneaking = false }
function player:getX() return self.x end
function player:getY() return self.y end
function player:getZ() return self.z end
function player:isDead() return false end
function player:isSneaking() return self.sneaking end
function player:isRunning() return self.running == true end
function player:isSprinting() return false end
function player:isPlayerMoving() return self.moving ~= false end
function player:getPrimaryHandItem() return self.weapon end
function player:getClothingItem_Back() return self.bag end
player.inv = { items = {} }
function player.inv:getItems() return T.JList(self.items) end
function player.inv:AddItem(x)
    local it = (type(x) == "string") and T.newItem(x) or x
    table.insert(self.items, it)
    return it
end
function player.inv:DoRemoveItem(it)
    for i, x in ipairs(self.items) do if x == it then table.remove(self.items, i) return end end
end
function player:getInventory() return self.inv end
function player:isEquipped(it) return it == self.weapon end
function player:getBodyPartClothingDefense(i, bite, bullet) return self.defense or 0 end
function player:Say(s) table.insert(self.said, s) end
function player:playSound() end
function player:playSoundLocal(n) T.localSounds = T.localSounds or {} table.insert(T.localSounds, n) end
function player:splatBloodFloor() end
function player:setAttackedBy(a) self.attackedBy = a end
function player:teleportTo(x, y, z) self.x, self.y, self.z = x, y, z end
function player:getBodyDamage()
    return { getBodyPart = function(_, i)
        parts[i] = parts[i] or { damage = 0,
            AddDamage = function(s, d) s.damage = s.damage + d end,
            setCut = function(s, b, noInf) s.cut = b; s.noInfection = noInf end,
            setScratched = function(s, b, noInf) s.scratched = b; s.noInfection = noInf end,
            setHaveBullet = function(s, b) s.bullet = b end }
        return parts[i]
    end }
end
T.player = player
function getPlayer() return player end

T.blockedSq, T.indoorSq = {}, {}   -- "x,y" -> true
T.sqBuilding = {}                   -- "x,y" -> BuildingDef falso
T.sqObjects = {}                    -- "x,y,z" -> { objetos }
T.worldItems = {}                   -- "x,y" -> { IsoWorldInventoryObject falsos }
T.deadBodies = {}                   -- "x,y" -> { IsoDeadBody falsos }
function T.addCorpse(x, y, outfit)
    local key = math.floor(x) .. "," .. math.floor(y)
    T.deadBodies[key] = T.deadBodies[key] or {}
    table.insert(T.deadBodies[key], { getOutfitName = function() return outfit end })
end
T.worldSounds = {}
function getSoundManager()
    return { PlayWorldSound = function(_, name, sq) table.insert(T.worldSounds, { name = name, x = sq:getX(), y = sq:getY() }) end }
end
function T.dropItem(x, y, id)
    local key = math.floor(x) .. "," .. math.floor(y)
    T.worldItems[key] = T.worldItems[key] or {}
    local it = T.newItem(id)
    table.insert(T.worldItems[key], { getItem = function() return it end })
end
T.worldLoaded = true
local function sqKey(x, y) return math.floor(x) .. "," .. math.floor(y) end
function T.square(x, y, z)
    return { getX = function() return math.floor(x) end, getY = function() return math.floor(y) end,
        getZ = function() return z end, isFree = function() return not T.blockedSq[sqKey(x, y)] end,
        isOutside = function() return not T.indoorSq[sqKey(x, y)] end,
        getRoom = function() return T.indoorSq[sqKey(x, y)] and {} or nil end,
        getBuilding = function()
            local def = T.sqBuilding[sqKey(x, y)]
            return def and { getDef = function() return def end } or nil
        end,
        getObjects = function() return T.JList(T.sqObjects[sqKey(x, y) .. "," .. tostring(z or 0)] or {}) end,
        AddTileObject = function(_, o) T.putObject(x, y, z or 0, o) end,
        getWorldObjects = function() return T.JList(T.worldItems[sqKey(x, y)] or {}) end,
        getDeadBodys = function() return T.JList(T.deadBodies[sqKey(x, y)] or {}) end,
        removeCorpse = function(_, b)
            local list = T.deadBodies[sqKey(x, y)] or {}
            for i, w in ipairs(list) do if w == b then table.remove(list, i) break end end
        end,
        removeWorldObject = function(_, wo)
            local list = T.worldItems[sqKey(x, y)] or {}
            for i, w in ipairs(list) do if w == wo then table.remove(list, i) break end end
        end,
        AddSpecialObject = function(_, o) T.putObject(x, y, z or 0, o) end,
        getMovingObjects = function()
            local here = {}
            for _, zb in ipairs(zombies) do
                if zb.inWorld and math.floor(zb.x) == math.floor(x) and math.floor(zb.y) == math.floor(y) then
                    table.insert(here, zb)
                end
            end
            return T.JList(here)
        end }
end

function getCell()
    return {
        getZombieList = function()
            local live = {}
            for _, z in ipairs(zombies) do if z.inWorld and not z.dead then table.insert(live, z) end end
            return T.JList(live)
        end,
        getGridSquare = function(_, x, y, z) if not T.worldLoaded then return nil end return T.square(x, y, z) end,
        addLamppost = function(_, x, y, z) T.lights[x .. "," .. y .. "," .. z] = true end,
        removeLamppost = function(_, x, y, z) T.lights[x .. "," .. y .. "," .. z] = nil end,
    }
end

-- luzes (addLamppost) e corpos (createRandomDeadBody)
T.lights = {}
T.corpses = {}
function createRandomDeadBody(sq, blood) table.insert(T.corpses, { x = sq:getX(), y = sq:getY() }) return {} end

-- barricadas: IsoBarricade.AddBarricadeToObject(obj, addOpposite)
IsoBarricade = {
    AddBarricadeToObject = function(obj, addOpposite)
        local b = { planks = 0 }
        function b:canAddPlank() return self.planks < 4 end
        function b:addPlank() self.planks = self.planks + 1 end
        obj.barricade, obj.barricadeOpposite = b, addOpposite
        return b
    end,
}

-- Item falso: comida se o id parecer comida
T.FOOD = { ["Base.TinnedBeans"] = true, ["Base.TinnedSoup"] = true, ["Base.Crackers"] = true, ["Base.Cereal"] = true,
    ["Base.CannedCorn"] = true, ["Base.CannedChili"] = true, ["Base.CannedPeas"] = true, ["Base.Rice"] = true,
    ["Base.Pasta"] = true, ["Base.BeefJerky"] = true, ["Base.Crisps"] = true, ["Base.WaterRationCan"] = true }
function T.newItem(id)
    local it = { id = id }
    function it:getFullType() return self.id end
    function it:isFood() return T.FOOD[self.id] == true end
    function it:getDisplayCategory()
        if T.FOOD[self.id] then return "Food" end
        if self.id:find("Bandage") or self.id:find("Disinfectant") or self.id:find("Pills") then return "FirstAid" end
        if self.id:find("Bullets") or self.id:find("Shells") then return "Ammo" end
        return "Junk"
    end
    function it:getActualWeight() return self.id:find("Sofa") and 50 or 1 end
    function it:getDisplayName() return self.id end
    function it:isEquipped() return false end
    function it:isFavorite() return false end
    return it
end

function T.putObject(x, y, z, o)
    local key = math.floor(x) .. "," .. math.floor(y) .. "," .. tostring(z or 0)
    T.sqObjects[key] = T.sqObjects[key] or {}
    o.x, o.y, o.z = math.floor(x), math.floor(y), z or 0
    o.getContainerCount = o.getContainerCount or function() return 0 end
    table.insert(T.sqObjects[key], o)
    return o
end

-- objetos colocados pelo mod (placa, barril, gerador...)
IsoObject = { new = function(sq, sprite) return { _class = "IsoObject", sprite = sprite } end }
IsoThumpable = { new = function(cell, sq, sprite)
    local o = { _class = "IsoThumpable", sprite = sprite }
    setmetatable(o, { __index = function() return function() end end })
    return o
end }
SpriteConfigManager = { getObjectInfoFromSprite = function() return nil end }
GameEntityFactory = { CreateIsoObjectEntity = function() end }
T.generators = {}
IsoGenerator = { new = function(item, cell, sq)
    local gen = { _class = "IsoGenerator", fuel = 0, active = false, connected = false }
    function gen:setConnected(b) self.connected = b end
    function gen:setFuel(f) self.fuel = f end
    function gen:getFuel() return self.fuel end
    function gen:setCondition() end
    function gen:setActivated(b) self.active = b end
    function gen:isActivated() return self.active end
    T.putObject(sq:getX(), sq:getY(), sq:getZ(), gen)
    table.insert(T.generators, gen)
    return gen
end }
T.halo = {}
HaloTextHelper = { addText = function(p, text) table.insert(T.halo, text) end }
T.campfires = {}
SCampfireSystem = { instance = {
    getLuaObjectOnSquare = function(_, sq) return T.campfires[sq:getX() .. "," .. sq:getY()] end,
    addCampfire = function(_, sq)
        local f = { isLit = false, fuelAmt = 0 }
        function f:addFuel(a) self.fuelAmt = self.fuelAmt + a end
        function f:lightFire() if self.fuelAmt > 0 then self.isLit = true end end
        T.campfires[sq:getX() .. "," .. sq:getY()] = f
        return f
    end,
} }
T.filled = 0
ItemPicker = { fillContainer = function(c) T.filled = T.filled + 1; c:AddItem("Base.TinnedBeans"); c:AddItem("Base.Bandage"); c:AddItem("Base.Sofa") end }

-- Objeto de mapa falso. kind: "IsoWindow" | "IsoDoor" | "container"
function T.addObject(x, y, z, kind, opts)
    opts = opts or {}
    local o = { _class = (kind ~= "container") and kind or "IsoObject", x = x, y = y, z = z,
        exterior = opts.exterior, open = opts.open == true, locked = opts.locked == true, containers = {} }
    function o:getSquare() return T.square(self.x, self.y, self.z) end
    function o:isExterior() return self.exterior == true end
    function o:isBarricaded() return self.barricade ~= nil end
    function o:isBarricadeAllowed() return true end
    function o:getBarricadeOnSameSquare() return (self.barricadeOpposite == false) and self.barricade or nil end
    function o:getBarricadeOnOppositeSquare() return (self.barricadeOpposite == true) and self.barricade or nil end
    function o:IsOpen() return self.open end
    function o:ToggleDoorSilent() self.open = not self.open end
    function o:isLocked() return self.locked end
    function o:isLockedByKey() return false end
    function o:setLocked(b) self.locked = b end
    function o:getContainerCount() return #self.containers end
    function o:getContainerByIndex(i) return self.containers[i + 1] end
    if kind == "container" then
        local c = { _class = "ItemContainer", ctype = opts.type or "counter", items = {}, explored = opts.explored == true }
        function c:getType() return self.ctype end
        function c:AddItem(x)   -- como no jogo: aceita o tipo ("Base.X") ou o proprio item
            local it = (type(x) == "table") and x or T.newItem(x)
            table.insert(self.items, it)
            return it
        end
        function c:getItems() return T.JList(self.items) end
        function c:setExplored(b) self.explored = b end
        function c:isExplored() return self.explored end
        function c:DoRemoveItem(it)
            for i, x in ipairs(self.items) do if x == it then table.remove(self.items, i) return end end
        end
        o.containers[1] = c
        o.container = c
    end
    local key = math.floor(x) .. "," .. math.floor(y) .. "," .. tostring(z)
    T.sqObjects[key] = T.sqObjects[key] or {}
    table.insert(T.sqObjects[key], o)
    return o
end

function T.clearZombies(keep)
    for _, z in ipairs(zombies) do if not (keep and keep[z]) then z.inWorld = false end end
end

local loaded = {}
function require(name)
    if loaded[name] then return end
    loaded[name] = true
    for _, base in ipairs({ T.MOD .. "shared/", T.MOD .. "client/" }) do
        local f = io.open(base .. name .. ".lua")
        if f then f:close(); dofile(base .. name .. ".lua"); return end
    end
end

-- ------------------------------------------------------------------ framework de teste
T.passed, T.failed = 0, 0

function T.check(cond, msg)
    table.insert(T.trace, "CHECK " .. tostring(not not cond) .. " rng=" .. T.rngCounter .. " clock=" .. T.clock .. " " .. msg)
    if cond then T.passed = T.passed + 1; realPrint("  ok   " .. msg)
    else T.failed = T.failed + 1; realPrint("  FAIL " .. msg) end
end
function T.tick(ms, n)
    for _ = 1, (n or 1) do T.clock = T.clock + ms; T.fire("OnTick") end
end
function T.saidPrefix(z, prefix)
    for _, s in ipairs(z.said) do if s:sub(1, #prefix) == prefix then return true end end
    return false
end
function T.count(t) local n = 0 for _ in pairs(t) do n = n + 1 end return n end

-- Ferramentas de teste agrupadas em sub-submenus: lista plana das opcoes (na ordem).
function T.flattenDebug(dbg)
    local out = {}
    for _, g in ipairs(dbg.options) do
        if g.sub then
            for _, o in ipairs(g.sub.options) do o.groupName = g.name table.insert(out, o) end
        else
            table.insert(out, g)
        end
    end
    return out
end

return T
