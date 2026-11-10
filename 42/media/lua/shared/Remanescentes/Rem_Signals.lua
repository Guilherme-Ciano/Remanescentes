-- Remanescentes - sinais de vida e estruturas da safehouse (Fase 3).
--
-- Colocados uma vez, quando a casa e preparada (evento "homeFortified"):
--   * placa de madeira na frente da porta. Ao chegar perto, voce le o que esta escrito
--     (texto flutuante): familias "TEMOS COMIDA. VENHA EM PAZ", milicia "FICA LONGE.
--     ATIRAMOS.", seita "ARREPENDA-SE", saqueadores as vezes "TEMOS COMIDA" (armadilha);
--   * poste com caveira (saqueadores e seita): aviso sem palavras;
--   * barril de chuva (mesmo objeto do jogo, coleta agua da chuva);
--   * gerador (milicia e seita, as vezes): liga a noite quando ha gente em casa.
-- Em cena:
--   * fogueira acesa no quintal de dia enquanto o grupo esta em casa (fogueira do jogo:
--     o fogo e "permanente" e nao se espalha). E o sinal de fumaca/fogo visivel de longe.
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_Safehouse"
local Rem = Remanescentes

local SG = Rem.module("Signals", {
    READ_DIST = 2.5,
    READ_CD_MS = 60000,
    CAMPFIRE_MS = 30000,      -- de quanto em quanto tempo confere a fogueira
    CAMPFIRE_FUEL = 60,       -- minutos de fogo por recarga
    DAY_START = 7, DAY_END = 19,
})
local CFG = SG.CFG

-- o que cada faccao coloca (chances em %)
SG.PLAN = {
    civis         = { sign = 70, signText = { "food" }, barrel = 50, generator = 0, campfire = 60 },
    sobreviventes = { sign = 80, signText = { "keepout" }, barrel = 60, generator = 35, campfire = 50 },
    saqueadores   = { sign = 40, signText = { "food", "private" }, skull = 70, barrel = 20, generator = 15, campfire = 40 },
    seita         = { sign = 60, signText = { "repent" }, skull = 80, barrel = 70, generator = 40, campfire = 70 },
    errantes      = { sign = 0, barrel = 0, generator = 0, campfire = 80 },
}

SG.SPRITES = {
    sign = "constructedobjects_signs_01_11",
    skull = "constructedobjects_signs_01_70",
    barrel = "carpentry_02_54",
}

local function chance(p) return ZombRand(100) < (p or 0) end

-- Quadrado livre, ao ar livre, fora da casa, a [minD, maxD] do ponto, longe de 'avoid'.
function SG.outsideSpot(h, px, py, minD, maxD, avoid)
    local cell = getCell()
    for r = minD, maxD do
        for dx = -r, r do
            for dy = -r, r do
                if math.abs(dx) == r or math.abs(dy) == r then
                    local x, y = px + dx, py + dy
                    local sq = cell:getGridSquare(x, y, 0)
                    local inHouse = h.x1 and x >= h.x1 and x < h.x2 and y >= h.y1 and y < h.y2
                    local taken = false
                    for _, a in ipairs(avoid or {}) do
                        if math.abs(a.x - x) <= 1 and math.abs(a.y - y) <= 1 then taken = true end
                    end
                    if sq and not inHouse and not taken and not sq:getRoom() and sq:isFree(false) then
                        return sq
                    end
                end
            end
        end
    end
    return nil
end

local function entranceOf(h)
    local e = h.entrance or h.mainDoor
    if e then return e.x, e.y end
    return math.floor((h.x1 + h.x2) / 2), h.y2
end

local function addTile(sq, sprite)
    local obj = IsoObject.new(sq, sprite)
    sq:AddTileObject(obj)
    return obj
end

-- Barril de chuva: mesmo processo do jogo (MORainCollectorBarrel): IsoThumpable + entidade.
function SG.placeBarrel(sq)
    local obj = IsoThumpable.new(getCell(), sq, SG.SPRITES.barrel, false, {})
    obj:setCanPassThrough(false)
    obj:setCanBarricade(false)
    obj:setIsThumpable(true)
    obj:setBlockAllTheSquare(true)
    obj:setName("Rain Collector Barrel")
    obj:setMaxHealth(450)
    obj:setHealth(450)
    obj:setBreakSound("BreakObject")
    local info = SpriteConfigManager.getObjectInfoFromSprite(SG.SPRITES.barrel)
    if info and info:getScript() and info:getScript():getParent() then
        GameEntityFactory.CreateIsoObjectEntity(obj, info:getScript():getParent(), true)
    end
    sq:AddSpecialObject(obj)
    return obj
end

function SG.placeGenerator(sq)
    local gen = IsoGenerator.new(instanceItem("Base.Generator"), getCell(), sq)
    gen:setConnected(true)
    gen:setFuel(30 + ZombRand(60))
    gen:setCondition(60 + ZombRand(40))
    return gen
end

-- Monta os sinais da casa (uma vez).
function SG.decorate(g)
    local h = g.home
    if not h or not h.x1 or h.decorated then return h and h.decor end
    local plan = SG.PLAN[g.faction] or {}
    local ex, ey = entranceOf(h)
    local used = {}
    local decor = {}
    local function take(sq, kind, extra)
        local d = { x = sq:getX(), y = sq:getY(), z = sq:getZ(), kind = kind }
        for k, v in pairs(extra or {}) do d[k] = v end
        table.insert(used, d)
        decor[kind] = d
        return d
    end
    if chance(plan.sign) then
        local sq = SG.outsideSpot(h, ex, ey, 2, 4, used)
        if sq and Rem.safe(addTile, sq, SG.SPRITES.sign) then
            take(sq, "sign", { text = Rem.pick(plan.signText or { "keepout" }) })
        end
    end
    if chance(plan.skull) then
        local sq = SG.outsideSpot(h, ex, ey, 3, 6, used)
        if sq and Rem.safe(addTile, sq, SG.SPRITES.skull) then take(sq, "skull") end
    end
    if chance(plan.barrel) then
        local sq = SG.outsideSpot(h, h.x1 - 1, math.floor((h.y1 + h.y2) / 2), 0, 4, used)
        if sq and Rem.safe(SG.placeBarrel, sq) then take(sq, "barrel") end
    end
    if chance(plan.generator) then
        local sq = SG.outsideSpot(h, h.x2, math.floor((h.y1 + h.y2) / 2), 1, 4, used)
        if sq and Rem.safe(SG.placeGenerator, sq) then take(sq, "generator") end
    end
    if chance(plan.campfire) then
        -- quintal: atras da casa (lado oposto da entrada), longe das paredes
        local sq = SG.outsideSpot(h, math.floor((h.x1 + h.x2) / 2), h.y1 - 3, 0, 4, used)
        if sq then take(sq, "campfire") end
    end
    h.decor = decor
    h.decorated = true
    return decor
end

-- ---------------------------------------------------------------- em cena
local lastRead = {}
function SG.readSigns(player, now)
    for gid, g in pairs(Rem.getStore().groups) do
        local s = g.home and g.home.decor and g.home.decor.sign
        if s and Rem.dist2(player:getX(), player:getY(), s.x + 0.5, s.y + 0.5) <= CFG.READ_DIST
            and now - (lastRead[gid] or -CFG.READ_CD_MS) >= CFG.READ_CD_MS then
            lastRead[gid] = now
            local text = getText("IGUI_Rem_Sign_" .. tostring(s.text))
            Rem.safe(function() HaloTextHelper.addText(player, text) end)
        end
    end
end

local function isDay()
    local tod = getGameTime():getTimeOfDay()
    return tod >= CFG.DAY_START and tod < CFG.DAY_END
end

local function someoneHome(g)
    if g.activity ~= "home" then return false end
    for _, id in ipairs(g.members) do
        if Rem.getPerson(id) then return true end
    end
    return false
end

local function findGenerator(d)
    local sq = getCell():getGridSquare(d.x, d.y, d.z or 0)
    if not sq then return nil end
    local objs = sq:getObjects()
    for i = 0, objs:size() - 1 do
        local o = objs:get(i)
        if instanceof(o, "IsoGenerator") then return o end
    end
    return nil
end

local nextCampfire = {}
function SG.updateLife(player, now)
    local px, py = player:getX(), player:getY()
    local day = isDay()
    for gid, g in pairs(Rem.getStore().groups) do
        local h = g.home
        local decor = h and h.decor
        if decor and Rem.dist2(px, py, h.x, h.y) < Rem.Safehouse.CFG.PREPARE_RADIUS then
            local home = someoneHome(g)
            -- gerador: liga a noite com gente em casa
            if decor.generator then
                local gen = findGenerator(decor.generator)
                if gen then
                    local want = home and not day and gen:getFuel() > 0
                    if gen:isActivated() ~= want then Rem.safe(function() gen:setActivated(want) end) end
                end
            end
            -- fogueira: acesa de dia com gente em casa
            local cf = decor.campfire
            if cf and home and day and now >= (nextCampfire[gid] or 0) and SCampfireSystem and SCampfireSystem.instance then
                nextCampfire[gid] = now + CFG.CAMPFIRE_MS
                Rem.safe(function()
                    local sys = SCampfireSystem.instance
                    local sq = getCell():getGridSquare(cf.x, cf.y, cf.z or 0)
                    if not sq then return end
                    local fire = sys:getLuaObjectOnSquare(sq) or sys:addCampfire(sq)
                    if fire and not fire.isLit then
                        fire:addFuel(CFG.CAMPFIRE_FUEL)
                        fire:lightFire()
                    end
                end)
            end
        end
    end
end

-- ---------------------------------------------------------------- ganchos
Rem.on("homeFortified", function(g) Rem.safe(SG.decorate, g) end)
Rem.on("sceneUpdate", function(player, now)
    Rem.safe(SG.readSigns, player, now)
    Rem.safe(SG.updateLife, player, now)
end)
Rem.on("groupRemoved", function(g) lastRead[g.id] = nil nextCampfire[g.id] = nil end)
