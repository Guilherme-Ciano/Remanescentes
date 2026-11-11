-- Remanescentes - portas: sobrevivente travado numa porta fechada abre e passa.
--
-- O corpo dos sobreviventes e um zumbi, e zumbi nao abre porta: o caminho dele para na
-- porta fechada (era por isso que um aliado mandado saquear uma casa "nao ia a lugar
-- nenhum"). Aqui, quem QUER andar e nao sai do lugar procura uma porta fechada colada nele,
-- na direcao do destino, e abre. Porta trancada so abre por dentro (como para voce).
-- Portas externas abertas por eles sao fechadas de novo depois que passam.
-- (A porta principal das safehouses continua com Rem_Safehouse.manageDoors.)
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_Movement"
local Rem = Remanescentes

local DO = Rem.module("Doors", {
    TICK_MS = 450,
    STUCK_MOVE = 0.2,        -- andou menos que isso entre duas checagens = travado
    UNSTICK_MS = 4000,       -- travado esse tempo, sem porta para abrir: da um passo para o lado
    DETOUR_MS = 1300,
    WANT_MS = 1500,          -- "quer andar": pediu caminho ha menos que isso
    RADIUS = 2,              -- procura portas ate essa distancia (tiles)
    REACH = 2.3,
    CLOSE_AFTER_MS = 5000,
    CLOSE_CLEAR = 1.6,       -- ninguem a essa distancia da porta para fechar
})
local CFG = DO.CFG

DO.opened = DO.opened or {}   -- { door =, at =, x =, y = } portas externas que eles abriram

local function doorsNear(x, y, z)
    local out = {}
    local cell = getCell()
    local r = CFG.RADIUS
    for dx = -r, r do
        for dy = -r, r do
            local sq = cell:getGridSquare(math.floor(x) + dx, math.floor(y) + dy, z)
            if sq then
                local objs = sq:getObjects()
                for i = 0, objs:size() - 1 do
                    local o = objs:get(i)
                    if instanceof(o, "IsoDoor") then table.insert(out, { door = o, x = sq:getX() + 0.5, y = sq:getY() + 0.5 }) end
                end
            end
        end
    end
    return out
end

local function inside(npc)
    local z = npc.z
    local sq = getCell():getGridSquare(math.floor(z:getX()), math.floor(z:getY()), math.floor(z:getZ()))
    return sq ~= nil and sq:getRoom() ~= nil
end

-- Abre a porta fechada mais perto dele, na direcao para onde quer ir. Retorna a porta.
function DO.openNear(npc, now)
    local z = npc.z
    local x, y = z:getX(), z:getY()
    local tx, ty = npc.wantX or x, npc.wantY or y
    local vx, vy = tx - x, ty - y
    local vlen = math.max(0.01, math.sqrt(vx * vx + vy * vy))
    local best, bestD = nil, CFG.REACH
    for _, e in ipairs(doorsNear(x, y, math.floor(z:getZ()))) do
        local d = e.door
        local closed, blocked = false, false
        pcall(function() closed = not d:IsOpen() end)
        pcall(function() blocked = d:isBarricaded() end)
        if closed and not blocked then
            local dx, dy = e.x - x, e.y - y
            local dist = math.sqrt(dx * dx + dy * dy)
            local ahead = (dx * vx + dy * vy) / vlen       -- para o lado do destino?
            if dist <= bestD and (dist < 1.2 or ahead > -0.3) then best, bestD = e, dist end
        end
    end
    if not best then return nil end
    local door = best.door
    local locked = false
    pcall(function() locked = door:isLocked() or door:isLockedByKey() end)
    if locked then
        if not inside(npc) then return nil end      -- trancada por fora: nao passa
        pcall(function() door:setLocked(false) end)
        pcall(function() door:setLockedByKey(false) end)
    end
    local ok = pcall(function() door:ToggleDoorSilent() end)
    if not ok then return nil end
    Rem.safe(function() z:playSound("DoorWoodMediumOpen") end)
    local exterior = false
    pcall(function() exterior = door:isExterior() end)
    if exterior then table.insert(DO.opened, { door = door, at = now, x = best.x, y = best.y }) end
    -- recalcula o caminho ja
    npc.nextPath, npc.lastPathX, npc.lastPathY = 0, nil, nil
    Rem.debug(tostring(npc.rec.name) .. " abriu uma porta")
    return door
end

-- Travado sem porta: um passo para um quadrado livre ao lado e tenta de novo.
function DO.unstick(npc, now)
    local z = npc.z
    local cell = getCell()
    local x, y, zz = math.floor(z:getX()), math.floor(z:getY()), math.floor(z:getZ())
    local options = {}
    for dx = -1, 1 do
        for dy = -1, 1 do
            if dx ~= 0 or dy ~= 0 then
                local sq = cell:getGridSquare(x + dx, y + dy, zz)
                if sq and sq:isFree(false) then table.insert(options, sq) end
            end
        end
    end
    if #options == 0 then return false end
    local sq = options[ZombRand(#options) + 1]
    npc.detour = { x = sq:getX() + 0.5, y = sq:getY() + 0.5, untilMs = now + CFG.DETOUR_MS }
    npc.nextPath, npc.lastPathX, npc.lastPathY = 0, nil, nil
    return true
end

local function someoneNear(x, y)
    local player = getPlayer()
    if player and Rem.dist2(player:getX(), player:getY(), x, y) <= CFG.CLOSE_CLEAR then return true end
    for zb in pairs(Rem.active) do
        if Rem.dist2(zb:getX(), zb:getY(), x, y) <= CFG.CLOSE_CLEAR then return true end
    end
    return false
end

function DO.closeBehind(now)
    local keep = {}
    for _, e in ipairs(DO.opened) do
        if now - e.at < CFG.CLOSE_AFTER_MS or someoneNear(e.x, e.y) then
            table.insert(keep, e)
        else
            pcall(function() if e.door:IsOpen() then e.door:ToggleDoorSilent() end end)
        end
    end
    DO.opened = keep
end

function DO.tick(now)
    for _, npc in pairs(Rem.active) do
        local z = npc.z
        local x, y = z:getX(), z:getY()
        local wants = npc.wantAt ~= nil and now - npc.wantAt <= CFG.WANT_MS and Rem.canAct(npc)
        local s = npc.doorSample
        if wants and s and Rem.dist2(x, y, s.x, s.y) < CFG.STUCK_MOVE
            and Rem.dist2(x, y, npc.wantX or x, npc.wantY or y) > 1.2 then
            npc.stuckSince = npc.stuckSince or now
            local ok, door = pcall(DO.openNear, npc, now)
            if ok and door then
                npc.stuckSince = nil
            elseif now - npc.stuckSince >= CFG.UNSTICK_MS and not npc.detour then
                DO.unstick(npc, now)
                npc.stuckSince = now
            end
        else
            npc.stuckSince = nil
        end
        npc.doorSample = { x = x, y = y }
    end
    DO.closeBehind(now)
end

local nextTick = 0
Events.OnTick.Add(function()
    if not Rem.isAuthority() or Rem.activeCount == 0 then return end
    local now = Rem.nowMs()
    if now < nextTick then return end
    nextTick = now + CFG.TICK_MS
    Rem.safe(DO.tick, now)
end)
