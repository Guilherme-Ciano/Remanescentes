-- Remanescentes - cerebro: decide o que cada sobrevivente em cena faz.
-- Roda no OnTick, mas cada sobrevivente so "pensa" a cada THINK_MS.
--
-- Prioridades:
--   0. levando golpe / animacao de ataque -> espera
--   1. vida baixa e inimigo perto          -> FUGIR (correndo)
--   2. inimigo ao alcance                  -> ATACAR
--   3. inimigo perto e vale a pena         -> IR ATE ELE
--   4. ordem (seguir/ficar) ou rotina do grupo (casa/saque/volta)
--   5. nada a fazer                        -> OCIOSO
-- Inimigos: zumbis; sobreviventes de faccao rival; o jogador, se hostil e visivel.
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_Factions"
require "Remanescentes/Rem_Spawn"
require "Remanescentes/Rem_Barks"
require "Remanescentes/Rem_Perception"
require "Remanescentes/Rem_Combat"
local Rem = Remanescentes

local THINK_MS = 250
local SCAN_RADIUS = 12
local ENGAGE_RADIUS = 6
local STEALTH_ENGAGE = 3
local HOSTILE_SIGHT = 14        -- ate onde um hostil enxerga o jogador/rivais
local FOLLOW_DIST = 3
local RUN_DIST = 7
local HOME_DIST = 2
local WANDER_RADIUS = 5
local FLEE_DIST = 9
local SAFE_DIST = 10
local REPATH_MS = 1000
local RUN_NOISE_MS = 1000
local RUN_NOISE_RADIUS = 7
local ARRIVE_DIST = 4

-- ---------------------------------------------------------------- postura
function Rem.setGait(npc, gait)
    local sneak = (gait == "sneak")
    local run = (gait == "run")
    if npc.sneaking ~= sneak then
        npc.sneaking = sneak
        npc.z:setVariable("RemSneak", sneak)
    end
    if npc.running ~= run then
        npc.running = run
        npc.z:setVariable("RemRun", run)
    end
end

local function baseGait(npc)
    return npc.rec.stealth and "sneak" or "walk"
end

local function travelGait(npc, dist)
    if npc.rec.stealth then return "sneak" end
    if dist > RUN_DIST then return "run" end
    return "walk"
end

-- ---------------------------------------------------------------- movimento
-- Forca o PathFindState: zombie:pathToLocationF() cairia no WalkTowardState com caminho
-- livre, que manda zumbis useless direto para idle (sobrevivente parado).
function Rem.moveTo(npc, x, y, z, now, gait)
    Rem.setGait(npc, gait or baseGait(npc))
    if now < npc.nextPath and npc.lastPathX and math.abs(npc.lastPathX - x) < 1 and math.abs(npc.lastPathY - y) < 1 then
        return
    end
    npc.nextPath = now + REPATH_MS
    npc.lastPathX, npc.lastPathY = x, y
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
    if npc.running then Rem.setGait(npc, baseGait(npc)) end
end

function Rem.isMoving(npc)
    if npc.moving and not npc.z:getVariableBoolean("bPathfind") then
        npc.moving = false
        npc.lastPathX, npc.lastPathY = nil, nil
    end
    return npc.moving
end

-- ---------------------------------------------------------------- inimigos
local function canSee(npc, obj)
    local ok, sees = pcall(function() return npc.z:CanSee(obj) end)
    return not ok or sees ~= false
end

-- Retorna o inimigo mais perto (zumbi, sobrevivente rival ou jogador) e a distancia.
function Rem.findEnemy(npc)
    local z = npc.z
    local zFloor = math.floor(z:getZ())
    local best, bestD = nil, SCAN_RADIUS

    local list = getCell():getZombieList()
    for i = 0, list:size() - 1 do
        local other = list:get(i)
        if other ~= z and not other:isDead() and math.floor(other:getZ()) == zFloor then
            local d = Rem.dist(z, other)
            if d < bestD then
                local otherNpc = Rem.active[other]
                if not otherNpc then
                    best, bestD = other, d
                elseif Rem.npcsHostile(npc, otherNpc) and (d < 2 or (d < HOSTILE_SIGHT and canSee(npc, other))) then
                    best, bestD = other, d
                end
            end
        end
    end

    -- quem me atacou por ultimo (mesmo amigo que virou inimigo)
    local la = npc.lastAttacker
    if la and Rem.active[la.z] then
        local d = Rem.dist(z, la.z)
        if d < bestD then best, bestD = la.z, d end
    elseif la then
        npc.lastAttacker = nil
    end

    if Rem.isHostileToPlayer(npc) then
        local player = getPlayer()
        if player and not player:isDead() and math.floor(player:getZ()) == zFloor then
            local d = Rem.dist(z, player)
            local range = HOSTILE_SIGHT
            if player:isSneaking() then range = range * 0.5 end
            if d < bestD and (d < 2 or (d < range and canSee(npc, player))) then
                best, bestD = player, d
                if not npc.sawPlayer then
                    npc.sawPlayer = true
                    Rem.bark(npc, "threat", true)
                end
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

-- ---------------------------------------------------------------- destino da rotina
-- Para pessoas de grupo: onde deveriam estar agora, segundo a simulacao do grupo.
local function groupGoal(npc)
    local g = npc.rec.groupId and Rem.getStore().groups[npc.rec.groupId]
    if not g then return nil end
    if g.activity == "scavenge" and g.target then
        return g.target.x, g.target.y, g.target.z or 0, "scavenge"
    end
    if g.home then
        return g.home.x, g.home.y, g.home.z or 0, (g.activity == "return") and "return" or "home"
    end
    return nil
end

-- ---------------------------------------------------------------- comportamentos
local function flee(npc, enemy, now)
    local z = npc.z
    local dx, dy = z:getX() - enemy:getX(), z:getY() - enemy:getY()
    local len = math.max(0.01, math.sqrt(dx * dx + dy * dy))
    local tx = z:getX() + dx / len * FLEE_DIST
    local ty = z:getY() + dy / len * FLEE_DIST
    if npc.rec.mode == "follow" then
        local player = getPlayer()
        if player and Rem.dist(player, enemy) > Rem.dist(z, enemy) then
            tx, ty = player:getX(), player:getY()
        end
    end
    Rem.bark(npc, "flee")
    Rem.moveTo(npc, tx, ty, z:getZ(), now, "run")
end

local function idle(npc, now)
    local z = npc.z
    if now >= (npc.nextLook or 0) then
        npc.nextLook = now + ZombRand(5000, 12000)
        Rem.safe(function()
            z:faceLocationF(z:getX() + ZombRandFloat(-5, 5), z:getY() + ZombRandFloat(-5, 5))
        end)
        if ZombRand(6) == 0 then Rem.bark(npc, "idle") end
    end
end

-- Fica num lugar: vai ate la; chegando, passeia em volta de vez em quando.
local function hangAround(npc, x, y, z, now, radius)
    local d = Rem.distXY(npc.z, x, y)
    if d > (radius + ARRIVE_DIST) then
        Rem.moveTo(npc, x, y, z, now, travelGait(npc, d))
        return
    end
    if not Rem.isMoving(npc) then
        Rem.setGait(npc, baseGait(npc))
        idle(npc, now)
        if ZombRand(30) == 0 then
            local tx = x + ZombRand(-radius, radius + 1)
            local ty = y + ZombRand(-radius, radius + 1)
            local sq = getCell():getGridSquare(tx, ty, z)
            if sq and sq:isFree(false) then
                Rem.moveTo(npc, tx + 0.5, ty + 0.5, z, now, baseGait(npc))
            end
        end
    end
end

function Rem.think(npc, now)
    local z = npc.z
    if not z:isUseless() then z:setUseless(true) end
    if z:getTarget() then z:setTarget(nil) end
    Rem.syncRecord(npc)

    -- 0. levando golpe ou atacando
    if now < npc.hitUntil or now < npc.attackUntil then return end

    local rec = npc.rec
    local enemy, d = Rem.findEnemy(npc)

    -- 1. fugir com pouca vida
    local fleeAt = Rem.cfg("FleeHealthPercent", 30) / 100
    if enemy and Rem.healthFraction(npc) < fleeAt then
        npc.fleeing = true
    elseif npc.fleeing and (not enemy or d > SAFE_DIST) then
        npc.fleeing = false
    end
    if npc.fleeing and enemy then
        if d <= Rem.reach(npc) and ZombRand(3) == 0 then
            Rem.stopMoving(npc)
            z:faceThisObject(enemy)
            if now >= npc.nextAttack then Rem.startAttack(npc, enemy, now) end
        else
            flee(npc, enemy, now)
        end
        return
    end

    if enemy then
        -- 2. ao alcance: ataca
        if d <= Rem.reach(npc) then
            Rem.stopMoving(npc)
            Rem.setGait(npc, baseGait(npc))
            z:faceThisObject(enemy)
            if now >= npc.nextAttack then Rem.startAttack(npc, enemy, now) end
            return
        end
        -- 3. vale a pena ir ate ele?
        local isZombie = not Rem.active[enemy] and not Rem.isPlayerObj(enemy)
        local engage = ENGAGE_RADIUS
        if not isZombie then
            engage = HOSTILE_SIGHT -- pessoas hostis: vai atras
        elseif rec.stealth and not Rem.isAware(enemy, npc) then
            engage = STEALTH_ENGAGE
        end
        if d <= engage then
            if isZombie then Rem.bark(npc, "spot") end
            local gait = rec.stealth and "sneak" or (d > 4 and "run" or "walk")
            Rem.moveTo(npc, enemy:getX(), enemy:getY(), enemy:getZ(), now, gait)
            return
        end
    end

    -- 4a. ordens do jogador
    if rec.mode == "follow" then
        local player = getPlayer()
        if player and not player:isDead() then
            local pd = Rem.dist(z, player)
            local playerSneak = player:isSneaking()
            if pd > FOLLOW_DIST then
                local gait = travelGait(npc, pd)
                if playerSneak and gait ~= "run" then gait = "sneak" end
                Rem.moveTo(npc, player:getX(), player:getY(), player:getZ(), now, gait)
            else
                Rem.stopMoving(npc)
                Rem.setGait(npc, (playerSneak or rec.stealth) and "sneak" or "walk")
                idle(npc, now)
            end
            return
        end
    end

    if rec.mode == "stay" then
        hangAround(npc, rec.homeX + 0.5, rec.homeY + 0.5, rec.homeZ, now, 0)
        return
    end

    -- 4b. rotina do grupo
    if rec.mode == "group" then
        local gx, gy, gz = groupGoal(npc)
        if gx then
            hangAround(npc, gx + 0.5, gy + 0.5, gz, now, WANDER_RADIUS)
            return
        end
    end

    -- 5. wander perto de "casa"
    hangAround(npc, rec.homeX + 0.5, rec.homeY + 0.5, rec.homeZ, now, WANDER_RADIUS)
end

local function footsteps(npc, now)
    if npc.running and Rem.isMoving(npc) and now >= (npc.nextNoise or 0) then
        npc.nextNoise = now + RUN_NOISE_MS
        Rem.makeNoise(npc, RUN_NOISE_RADIUS)
    end
end

-- ---------------------------------------------------------------- loop principal
local function isValid(zombie, npc)
    if zombie:isDead() or not zombie:isExistInTheWorld() or zombie:getCurrentSquare() == nil then
        return false
    end
    return zombie:getPersistentOutfitID() == npc.rec.pid
end

local function onTick()
    if not Rem.isAuthority() then return end
    local now = Rem.nowMs()
    Rem.updateZombieAttacks(now)
    if Rem.activeCount == 0 then return end
    local gone = nil
    for zombie, npc in pairs(Rem.active) do
        if not isValid(zombie, npc) then
            gone = gone or {}
            table.insert(gone, zombie)
        else
            Rem.updateAttack(npc, now)
            Rem.updateHitReact(npc, now)
            if now >= npc.nextThink then
                npc.nextThink = now + THINK_MS
                Rem.safe(Rem.think, npc, now)
                Rem.safe(Rem.perceive, npc, now)
                Rem.safe(footsteps, npc, now)
            end
        end
    end
    if gone then
        -- chunk descarregou: a pessoa volta ao papel (pid fica, para re-associar no reload)
        for _, zombie in ipairs(gone) do Rem.deactivate(zombie) end
        Rem.invalidatePidIndex()
    end
end
Events.OnTick.Add(onTick)
