-- Remanescentes - Fase D3: bases que evoluem (simulado mesmo longe de voce, uma vez por dia).
--
--   * fortificam aos poucos: com comida sobrando, o nivel de fortificacao sobe (engenheiro
--     acelera). Quando voce chega perto, a casa recebe as tabuas novas;
--   * podem CAIR: uma horda invade (mais provavel em grupos pequenos e pouco fortificados).
--     Os moradores viram zumbis e a casa vira um NINHO: zumbis la dentro, estoque e
--     barricadas intactos;
--   * crescem: grupos com fartura recrutam errantes que estejam por perto;
--   * saqueadores que acabam com um grupo tomam a base dele (em Rem_World, resolveRaid).
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_World"
require "Remanescentes/Rem_Timeline"
require "Remanescentes/Rem_Safehouse"
local Rem = Remanescentes

local EV = Rem.module("Evolution", {
    MAX_LEVEL = 3,
    FALL_PERMILLE = 20,       -- chance diaria (por mil) de uma base cair, grupo medio sem reforco
    SMALL_GROUP = 2,          -- grupos ate esse tamanho caem 2x mais
    LEVEL_PROTECTION = 0.25,  -- cada nivel de fortificacao corta isso da chance
    NEST_ZOMBIES = { 3, 8 },
    RECRUIT_RADIUS = 250,
    RECRUIT_SUPPLY = 3,       -- suprimento por pessoa para querer recrutar
    MAX_MEMBERS = 6,
    REINFORCE_WINDOWS = 2,    -- janelas novas barricadas por nivel
})
local CFG = EV.CFG

local function members(g)
    local out = {}
    for _, id in ipairs(g.members) do
        local p = Rem.getPerson(id)
        if p then table.insert(out, p) end
    end
    return out
end

local function onScene(list)
    for _, p in ipairs(list) do if p.onScene then return true end end
    return false
end

local function hasEngineer(list)
    for _, p in ipairs(list) do if p.archetype == "engenheiro" then return true end end
    return false
end

local function removeGroup(g)
    local store = Rem.getStore()
    store.groups[g.id] = nil
    Rem.emit("groupRemoved", g)
end

-- ---------------------------------------------------------------- cair para uma horda
function EV.fall(g)
    local store = Rem.getStore()
    local h = g.home
    store.turned = store.turned or {}
    for _, p in ipairs(members(g)) do
        table.insert(store.turned, { x = h.x + ZombRandFloat(-2, 2), y = h.y + ZombRandFloat(-2, 2), z = 0,
            outfit = p.outfit, female = p.female })
        Rem.removePerson(p.id)
    end
    store.nests = store.nests or {}
    if h.bid then
        store.nests[h.bid] = { x1 = h.x1, y1 = h.y1, x2 = h.x2, y2 = h.y2, x = h.x, y = h.y,
            count = ZombRand(CFG.NEST_ZOMBIES[1], CFG.NEST_ZOMBIES[2] + 1) }
    end
    Rem.debug("a base do grupo " .. g.id .. " (" .. g.faction .. ") caiu para os zumbis")
    removeGroup(g)
end

-- Ninho: quando a casa carrega perto de voce, os zumbis estao la dentro.
function EV.spawnNests(player)
    local nests = Rem.getStore().nests
    if not nests then return end
    local cell = getCell()
    for bid, n in pairs(nests) do
        if n.x1 and Rem.dist2(player:getX(), player:getY(), n.x, n.y) < Rem.Safehouse.CFG.PREPARE_RADIUS
            and cell:getGridSquare(math.floor(n.x), math.floor(n.y), 0) then
            local made = 0
            for _ = 1, n.count * 4 do
                if made >= n.count then break end
                local x, y = ZombRand(n.x1, n.x2), ZombRand(n.y1, n.y2)
                local sq = cell:getGridSquare(x, y, 0)
                if sq and sq:getRoom() and sq:isFree(false) then
                    Rem.safe(function()
                        addZombiesInOutfit(x, y, 0, 1, Rem.pick(Rem.FACTIONS.civis.outfits), 50,
                            false, false, false, false, false, false, 1.0)
                    end)
                    made = made + 1
                end
            end
            nests[bid] = nil
            Rem.debug("ninho em " .. bid .. ": " .. made .. " zumbis")
        end
    end
end

-- ---------------------------------------------------------------- recrutar errantes
function EV.recruit(g, e)
    local list = members(e)
    for _, p in ipairs(list) do
        p.groupId = g.id
        p.faction = g.faction
        p.mode = "group"
        p.role = "morador"
        table.insert(g.members, p.id)
        if Rem.Reputation and Rem.Reputation.apply then Rem.Reputation.apply(p) end
    end
    e.members = {}
    Rem.debug("grupo " .. g.id .. " recrutou " .. #list .. " errante(s) do grupo " .. e.id)
    removeGroup(e)
    return #list
end

local function nearestDrifters(g)
    local best, bestD = nil, CFG.RECRUIT_RADIUS
    for _, other in pairs(Rem.getStore().groups) do
        if other.faction == "errantes" and other ~= g then
            local list = members(other)
            if #list > 0 and not onScene(list) then
                local d = Rem.dist2(g.x, g.y, other.x, other.y)
                if d < bestD then best, bestD = other, d end
            end
        end
    end
    return best
end

-- ---------------------------------------------------------------- uma vez por dia
function EV.daily()
    local groups = {}
    for _, g in pairs(Rem.getStore().groups) do table.insert(groups, g) end
    for _, g in ipairs(groups) do
        if Rem.getStore().groups[g.id] then
            local list = members(g)
            local n = #list
            local h = g.home
            if n > 0 and h and h.x1 and g.activity == "home" and not onScene(list) then
                -- fortificar aos poucos
                if (g.supplies or 0) >= n then
                    h.fortifyLevel = math.min(CFG.MAX_LEVEL, (h.fortifyLevel or 0) + (hasEngineer(list) and 2 or 1))
                end
                -- cair para uma horda
                local p = CFG.FALL_PERMILLE * ((n <= CFG.SMALL_GROUP) and 2 or 1)
                    * math.max(0, 1 - (h.fortifyLevel or 0) * CFG.LEVEL_PROTECTION) * Rem.cfg("BaseFallRate", 100) / 100
                if ZombRand(1000) < p then
                    EV.fall(g)
                elseif (g.faction == "civis" or g.faction == "sobreviventes" or g.faction == "seita")
                    and (g.supplies or 0) >= n * CFG.RECRUIT_SUPPLY and n < CFG.MAX_MEMBERS then
                    local e = nearestDrifters(g)
                    if e then EV.recruit(g, e) end
                end
            end
        end
    end
end

-- ---------------------------------------------------------------- reforco em cena
local function objectsOf(sq)
    local out = {}
    local objs = sq:getObjects()
    for i = 0, objs:size() - 1 do table.insert(out, objs:get(i)) end
    return out
end

-- Aplica os niveis de fortificacao ganhos desde a ultima visita.
function EV.reinforce(g)
    local h = g.home
    local S = Rem.Safehouse
    local levels = (h.fortifyLevel or 0) - (h.reinforced or 0)
    if levels <= 0 then return 0 end
    local newWindows = 0
    local quota = levels * CFG.REINFORCE_WINDOWS
    S.forEachSquare(h, h.z or 0, function(sq)
        for _, obj in ipairs(objectsOf(sq)) do
            if instanceof(obj, "IsoWindow") and obj:isExterior() then
                local isEntrance = h.entrance and h.entrance.window and sq:getX() == h.entrance.x and sq:getY() == h.entrance.y
                if not isEntrance then
                    if not obj:isBarricaded() then
                        if newWindows < quota and Rem.safe(S.barricadeInside, obj, 2) then newWindows = newWindows + 1 end
                    else
                        Rem.safe(function()
                            local b = obj:getBarricadeOnSameSquare() or obj:getBarricadeOnOppositeSquare()
                            if b and b:canAddPlank() then b:addPlank(nil, nil) end
                        end)
                    end
                end
            end
        end
    end)
    h.reinforced = h.fortifyLevel
    Rem.debug("casa do grupo " .. g.id .. " reforcada: +" .. newWindows .. " janelas")
    return newWindows
end

function EV.reinforceNear(player)
    for _, g in pairs(Rem.getStore().groups) do
        local h = g.home
        if h and h.fortified and (h.fortifyLevel or 0) > (h.reinforced or 0)
            and Rem.dist2(player:getX(), player:getY(), h.x, h.y) < Rem.Safehouse.CFG.PREPARE_RADIUS
            and Rem.Safehouse.isLoaded(h) then
            Rem.safe(EV.reinforce, g)
        end
    end
end

-- ---------------------------------------------------------------- ganchos
Events.EveryDays.Add(function() if Rem.isAuthority() then Rem.safe(EV.daily) end end)
Rem.on("sceneUpdate", function(player)
    Rem.safe(EV.spawnNests, player)
    Rem.safe(EV.reinforceNear, player)
end)
Rem.registerDebugOption("ContextMenu_Rem_SimDay", function(x, y, z, player)
    EV.daily()
    player:Say("Um dia simulado (bases evoluem).")
end)
