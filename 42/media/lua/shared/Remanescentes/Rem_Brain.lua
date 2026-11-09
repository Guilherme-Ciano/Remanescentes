-- Remanescentes - cerebro: decide o que cada sobrevivente faz.
-- Roda no OnTick, mas cada sobrevivente so "pensa" a cada THINK_MS para poupar CPU.
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_Spawn"
require "Remanescentes/Rem_Combat"
local Rem = Remanescentes

local THINK_MS = 250
local SCAN_RADIUS = 8        -- raio para procurar zumbis
local ENGAGE_RADIUS = 6      -- vai ate o zumbi se estiver a esta distancia
local FOLLOW_DIST = 3        -- distancia maxima do jogador ao seguir
local HOME_DIST = 2          -- distancia maxima de casa ao "ficar"
local WANDER_RADIUS = 6
local REPATH_MS = 1000

-- ---------------------------------------------------------------- movimento
function Rem.moveTo(npc, x, y, z, now)
    if now < npc.nextPath and npc.lastPathX and math.abs(npc.lastPathX - x) < 1 and math.abs(npc.lastPathY - y) < 1 then
        return
    end
    npc.nextPath = now + REPATH_MS
    npc.lastPathX, npc.lastPathY = x, y
    -- Nao usamos zombie:pathToLocationF(): com caminho livre ele escolhe o estado
    -- "walktoward", que desiste na hora em zumbis useless (WalkTowardState checa
    -- isUseless e volta para idle). O PathFindState nao checa, entao forcamos ele:
    -- define o destino no PathFindBehavior2 e liga bPathfind (actiongroups/zombie/idle/to_pathfind.xml).
    npc.z:getPathFindBehavior2():pathToLocationF(x, y, z)
    npc.z:setVariable("bPathfind", true)
    npc.moving = true
end

function Rem.stopMoving(npc)
    if npc.moving then
        Rem.safe(function()
            npc.z:getPathFindBehavior2():cancel()
            npc.z:setVariable("bPathfind", false)
        end)
        npc.moving = false
        npc.lastPathX, npc.lastPathY = nil, nil
    end
end

-- O PathFindState desliga bPathfind sozinho ao chegar/falhar; sincronizamos o estado.
function Rem.isMoving(npc)
    if npc.moving and not npc.z:getVariableBoolean("bPathfind") then
        npc.moving = false
        npc.lastPathX, npc.lastPathY = nil, nil
    end
    return npc.moving
end

-- ---------------------------------------------------------------- percepcao
function Rem.findEnemy(npc)
    local z = npc.z
    local best, bestD = nil, SCAN_RADIUS
    local list = getCell():getZombieList()
    for i = 0, list:size() - 1 do
        local other = list:get(i)
        if other ~= z and not Rem.active[other] and not other:isDead()
            and math.floor(other:getZ()) == math.floor(z:getZ()) then
            local d = Rem.dist(z, other)
            if d < bestD then
                best, bestD = other, d
            end
        end
    end
    return best, bestD
end

function Rem.reach(npc)
    local item = npc.z:getPrimaryHandItem()
    local r = 1.0
    if item and instanceof(item, "HandWeapon") then r = item:getMaxRange() end
    return math.max(0.9, r) + 0.15
end

-- ---------------------------------------------------------------- pensar
function Rem.think(npc, now)
    local z = npc.z
    -- Reafirma o modo humano (o jogo pode mexer no zumbi apos hit/queda).
    if not z:isUseless() then z:setUseless(true) end
    if z:getTarget() then z:setTarget(nil) end

    -- Animacao de ataque em andamento: so espera.
    if now < npc.attackUntil then return end

    local enemy, d = Rem.findEnemy(npc)
    if enemy then
        if d <= Rem.reach(npc) then
            Rem.stopMoving(npc)
            z:faceThisObject(enemy)
            if now >= npc.nextAttack then Rem.startAttack(npc, enemy, now) end
            return
        elseif d <= ENGAGE_RADIUS then
            if now - npc.lastSay > 15000 then
                npc.lastSay = now
                Rem.say(npc, "IGUI_Rem_SayEnemy")
            end
            Rem.moveTo(npc, enemy:getX(), enemy:getY(), enemy:getZ(), now)
            return
        end
    end

    local rec = npc.rec
    if rec.mode == "follow" then
        local player = getPlayer()
        if player and not player:isDead() then
            if Rem.dist(z, player) > FOLLOW_DIST then
                Rem.moveTo(npc, player:getX(), player:getY(), player:getZ(), now)
            else
                Rem.stopMoving(npc)
            end
            return
        end
    end

    if rec.mode == "stay" then
        if Rem.distXY(z, rec.homeX + 0.5, rec.homeY + 0.5) > HOME_DIST then
            Rem.moveTo(npc, rec.homeX + 0.5, rec.homeY + 0.5, rec.homeZ, now)
        end
        return
    end

    -- wander: passeia perto de casa de vez em quando
    if not Rem.isMoving(npc) and ZombRand(40) == 0 then
        local x = rec.homeX + ZombRand(-WANDER_RADIUS, WANDER_RADIUS + 1)
        local y = rec.homeY + ZombRand(-WANDER_RADIUS, WANDER_RADIUS + 1)
        local sq = getCell():getGridSquare(x, y, rec.homeZ)
        if sq and sq:isFree(false) then
            Rem.moveTo(npc, x + 0.5, y + 0.5, rec.homeZ, now)
        end
    end
end

-- ---------------------------------------------------------------- loop principal
local function isValid(zombie, npc)
    if zombie:isDead() or not zombie:isExistInTheWorld() or zombie:getCurrentSquare() == nil then
        return false
    end
    -- zumbis sao reciclados pelo jogo: confere se ainda e o mesmo
    return Rem.keyOf(zombie) == npc.key
end

local function onTick()
    if Rem.activeCount == 0 or not Rem.isAuthority() then return end
    local now = Rem.nowMs()
    local dead = nil
    for zombie, npc in pairs(Rem.active) do
        if not isValid(zombie, npc) then
            dead = dead or {}
            table.insert(dead, zombie)
        else
            Rem.updateAttack(npc, now)
            if now >= npc.nextThink then
                npc.nextThink = now + THINK_MS
                Rem.safe(Rem.think, npc, now)
                Rem.safe(Rem.zombieAggro, npc, now)
            end
        end
    end
    if dead then
        -- descarregou (chunk saiu da memoria) ou morreu: o registro fica, o runtime sai
        for _, zombie in ipairs(dead) do Rem.deactivate(zombie) end
    end
end
Events.OnTick.Add(onTick)
