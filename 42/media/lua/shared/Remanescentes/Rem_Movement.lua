-- Remanescentes - movimento do sobrevivente: postura (andar/correr/agachar), pathfind,
-- ficar num lugar, ficar ocioso, fugir e o destino da rotina do grupo.
-- Usado pelo cerebro (Rem_Brain) e pelos comportamentos (Rem_Behaviors e modulos novos).
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_Barks"
local Rem = Remanescentes

-- As constantes de movimento ficam junto com as do cerebro (Rem.Brain.CFG).
local B = Rem.module("Brain", {
    RUN_DIST = 7,               -- mais longe que isso: corre
    REPATH_MS = 1000,           -- intervalo minimo para recalcular caminho ao mesmo destino
    ARRIVE_DIST = 4,            -- hangAround: folga alem do raio antes de ir ate o lugar
    FLEE_DIST = 9,              -- fuga: quanto corre para longe do inimigo
})

-- ---------------------------------------------------------------- postura
function Rem.setGait(npc, gait)
    -- sem folego ou mancando (Rem_Awareness): nao corre
    if gait == "run" and (npc.winded or npc.limping) then gait = "walk" end
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

-- Postura normal: agachado se estiver em modo furtivo, senao andando.
function Rem.baseGait(npc)
    return npc.rec.stealth and "sneak" or "walk"
end

-- Postura para percorrer dist tiles: corre se for longe (a menos que furtivo).
function Rem.travelGait(npc, dist)
    if npc.rec.stealth then return "sneak" end
    if dist > B.CFG.RUN_DIST then return "run" end
    return "walk"
end

-- ---------------------------------------------------------------- movimento
-- Forca o PathFindState: zombie:pathToLocationF() cairia no WalkTowardState com caminho
-- livre, que manda zumbis useless direto para idle (sobrevivente parado).
-- Descanso (sentado/dormindo): pose de animacao (RemRest), desfeita ao andar, atacar ou
-- levar golpe.
function Rem.setRest(npc, pose)
    if npc.rest ~= pose then
        npc.rest = pose
        npc.z:setVariable("RemRest", pose or "")
    end
end

function Rem.clearRest(npc)
    if npc.rest then Rem.setRest(npc, nil) end
end

function Rem.moveTo(npc, x, y, z, now, gait)
    Rem.clearRest(npc)
    Rem.setGait(npc, gait or Rem.baseGait(npc))
    if now < npc.nextPath and npc.lastPathX and math.abs(npc.lastPathX - x) < 1 and math.abs(npc.lastPathY - y) < 1 then
        return
    end
    npc.nextPath = now + B.CFG.REPATH_MS
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
    if npc.running then Rem.setGait(npc, Rem.baseGait(npc)) end
end

function Rem.isMoving(npc)
    if npc.moving and not npc.z:getVariableBoolean("bPathfind") then
        npc.moving = false
        npc.lastPathX, npc.lastPathY = nil, nil
    end
    return npc.moving
end

-- ---------------------------------------------------------------- destino da rotina
-- Para pessoas de grupo: onde deveriam estar agora, segundo a simulacao do grupo.
-- Retorna x, y, z, motivo ("scavenge"|"return"|"home") ou nil.
function Rem.groupGoal(npc)
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

-- ---------------------------------------------------------------- acoes basicas
-- Corre para longe do inimigo (seguidor corre para o jogador, se ele estiver mais seguro).
function Rem.flee(npc, enemy, now)
    local z = npc.z
    local dx, dy = z:getX() - enemy:getX(), z:getY() - enemy:getY()
    local len = math.max(0.01, math.sqrt(dx * dx + dy * dy))
    local tx = z:getX() + dx / len * B.CFG.FLEE_DIST
    local ty = z:getY() + dy / len * B.CFG.FLEE_DIST
    if npc.rec.mode == "follow" then
        local player = getPlayer()
        if player and Rem.dist(player, enemy) > Rem.dist(z, enemy) then
            tx, ty = player:getX(), player:getY()
        end
    end
    Rem.bark(npc, "flee")
    Rem.moveTo(npc, tx, ty, z:getZ(), now, "run")
end

-- Parado: olha em volta de vez em quando e as vezes comenta algo.
function Rem.idle(npc, now)
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
function Rem.hangAround(npc, x, y, z, now, radius)
    local d = Rem.distXY(npc.z, x, y)
    if d > (radius + B.CFG.ARRIVE_DIST) then
        Rem.moveTo(npc, x, y, z, now, Rem.travelGait(npc, d))
        return
    end
    if not Rem.isMoving(npc) then
        Rem.setGait(npc, Rem.baseGait(npc))
        Rem.idle(npc, now)
        if ZombRand(30) == 0 then
            local tx = x + ZombRand(-radius, radius + 1)
            local ty = y + ZombRand(-radius, radius + 1)
            local sq = getCell():getGridSquare(tx, ty, z)
            if sq and sq:isFree(false) then
                Rem.moveTo(npc, tx + 0.5, ty + 0.5, z, now, Rem.baseGait(npc))
            end
        end
    end
end
