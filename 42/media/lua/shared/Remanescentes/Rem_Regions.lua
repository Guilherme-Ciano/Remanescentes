-- Remanescentes - Fase D1: grupos espalhados pelo mapa inteiro, por regiao.
--
-- O mapa e dividido em regioes de SIZE x SIZE tiles. Quando voce chega perto de uma regiao
-- nova (ela ou as vizinhas), ela ganha grupos de acordo com quantos predios tem: cidade
-- cheia, bairro com alguns, campo quase nada (as vezes um errante). Assim o mundo todo
-- fica povoado conforme voce explora, ate o limite do sandbox "Grupos no mundo".
-- Faccoes seguem a linha do tempo e a zona de graca (Rem_Timeline).
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_World"
require "Remanescentes/Rem_Timeline"
local Rem = Remanescentes

local RG = Rem.module("Regions", {
    SIZE = 300,
    RADIUS = 1,               -- semeia a regiao do jogador e as vizinhas (3x3)
    CHECK_MS = 10000,
    BUILDINGS_PER_GROUP = 40, -- 1 grupo a cada tantos predios (densidade 100%)
    MAX_PER_REGION = 5,
    RURAL_BELOW = 8,          -- menos predios que isso: campo
    RURAL_CHANCE = 30,        -- (%) de um errante no campo
    MIN_FROM_PLAYER = 60,     -- nunca nasce grupo colado em voce
    MIN_AREA = 30, MAX_AREA = 2500,
})
local CFG = RG.CFG

local function regions()
    local s = Rem.getStore()
    s.regions = s.regions or {}
    return s.regions
end

function RG.keyOf(x, y)
    return math.floor(x / CFG.SIZE) .. "," .. math.floor(y / CFG.SIZE)
end

-- Indice dos predios habitaveis por regiao (uma vez por sessao).
local index = nil
function RG.index()
    if index then return index end
    index = {}
    local list = getWorld():getMetaGrid():getBuildings()
    for i = 0, list:size() - 1 do
        local d = list:get(i)
        local area = d:getW() * d:getH()
        if area >= CFG.MIN_AREA and area <= CFG.MAX_AREA then
            local k = RG.keyOf(d:getX() + d:getW() / 2, d:getY() + d:getH() / 2)
            index[k] = index[k] or {}
            table.insert(index[k], d)
        end
    end
    return index
end
function RG.resetIndex() index = nil end

local function cap() return Rem.cfg("WorldGroups", 40) end

-- Semeia uma regiao. Retorna quantos grupos criou.
function RG.seedRegion(key, player)
    regions()[key] = { seededAt = Rem.worldHours() }
    local defs = RG.index()[key] or {}
    local n = #defs
    local want
    local rural = n < CFG.RURAL_BELOW
    if rural then
        want = (n > 0 and ZombRand(100) < CFG.RURAL_CHANCE) and 1 or 0
    else
        local density = Rem.cfg("GroupDensity", 100) / 100
        local exact = n / CFG.BUILDINGS_PER_GROUP * density
        want = math.floor(exact)
        if ZombRandFloat(0, 1) < exact - want then want = want + 1 end
    end
    want = math.min(want, CFG.MAX_PER_REGION, math.max(0, cap() - Rem.groupCount()))
    local W = Rem.World
    local made = 0
    for _ = 1, want do
        for _ = 1, 30 do
            local def = defs[ZombRand(n) + 1]
            local bx, by = math.floor(def:getX() + def:getW() / 2), math.floor(def:getY() + def:getH() / 2)
            local bid = tostring(def:getID())
            local farFromPlayer = not player or Rem.dist2(bx, by, player:getX(), player:getY()) >= CFG.MIN_FROM_PLAYER
            if farFromPlayer and W.farFromOtherHomes(def, bid, bx, by) then
                local graced = Rem.Timeline.protects(bx, by)
                local faction = rural and "errantes" or Rem.randomFaction(graced)
                if graced and Rem.Timeline.isHostileFaction(faction) then faction = Rem.randomFaction(true) end
                if Rem.createGroup(faction, bx, by, bid, Rem.groupSizeFor(faction), def) then made = made + 1 end
                break
            end
        end
    end
    if made > 0 then Rem.debug("regiao " .. key .. " (" .. n .. " predios): " .. made .. " grupos") end
    return made
end

-- Saves de antes das regioes: as regioes onde ja existem grupos contam como semeadas.
local function migrate()
    local r = regions()
    if r._migrated then return end
    r._migrated = true
    for _, g in pairs(Rem.getStore().groups) do
        if g.home then r[RG.keyOf(g.home.x, g.home.y)] = r[RG.keyOf(g.home.x, g.home.y)] or { seededAt = -1 } end
    end
end

function RG.seedAround(player)
    migrate()
    local cx, cy = math.floor(player:getX() / CFG.SIZE), math.floor(player:getY() / CFG.SIZE)
    local made = 0
    for dx = -CFG.RADIUS, CFG.RADIUS do
        for dy = -CFG.RADIUS, CFG.RADIUS do
            local key = (cx + dx) .. "," .. (cy + dy)
            if not regions()[key] then made = made + RG.seedRegion(key, player) end
        end
    end
    return made
end

local nextCheck = 0
Rem.on("sceneUpdate", function(player, now)
    if now < nextCheck or not Rem.getStore().seeded then return end
    nextCheck = now + CFG.CHECK_MS
    Rem.safe(RG.seedAround, player)
end)
