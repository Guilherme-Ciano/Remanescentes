-- Remanescentes - comportamentos padrao do cerebro (o que fazer quando nao ha briga).
-- Rodam em ordem de priority depois do bloco de combate de Rem.think (ver Rem_Brain.lua);
-- o primeiro que retornar true encerra o think. Modulos novos podem se inserir entre eles
-- (ex.: priority 250 roda depois de stay e antes da rotina do grupo).
--
--   100 follow  ordem "seguir": acompanha o jogador
--   200 stay    ordem "ficar": fica no lugar marcado
--   300 group   rotina do grupo (casa/saque/volta), segundo a simulacao
--   900 wander  passeia perto de "casa" (sempre trata o tick)
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_Movement"
local Rem = Remanescentes

local B = Rem.module("Brain", {
    FOLLOW_DIST = 3,            -- seguidor para a essa distancia do jogador
    WANDER_RADIUS = 5,          -- raio do passeio em volta de casa / do destino do grupo
})

-- 4a. ordens do jogador: seguir
Rem.registerBehavior({ name = "follow", priority = 100, run = function(npc, ctx, now)
    local rec = npc.rec
    if rec.mode ~= "follow" then return false end
    local player = getPlayer()
    if not player or player:isDead() then return false end
    local pd = Rem.dist(npc.z, player)
    local playerSneak = player:isSneaking()
    if pd > B.CFG.FOLLOW_DIST then
        local gait = Rem.travelGait(npc, pd)
        if playerSneak and gait ~= "run" then gait = "sneak" end
        Rem.moveTo(npc, player:getX(), player:getY(), player:getZ(), now, gait)
    else
        Rem.stopMoving(npc)
        Rem.setGait(npc, (playerSneak or rec.stealth) and "sneak" or "walk")
        Rem.idle(npc, now)
    end
    return true
end })

-- ordens do jogador: ficar
Rem.registerBehavior({ name = "stay", priority = 200, run = function(npc, ctx, now)
    local rec = npc.rec
    if rec.mode ~= "stay" then return false end
    Rem.hangAround(npc, rec.homeX + 0.5, rec.homeY + 0.5, rec.homeZ, now, 0)
    return true
end })

-- 4b. rotina do grupo
Rem.registerBehavior({ name = "group", priority = 300, run = function(npc, ctx, now)
    if npc.rec.mode ~= "group" then return false end
    local gx, gy, gz = Rem.groupGoal(npc)
    if not gx then return false end
    Rem.hangAround(npc, gx + 0.5, gy + 0.5, gz, now, B.CFG.WANDER_RADIUS)
    return true
end })

-- 5. passeio perto de "casa"
Rem.registerBehavior({ name = "wander", priority = 900, run = function(npc, ctx, now)
    local rec = npc.rec
    Rem.hangAround(npc, rec.homeX + 0.5, rec.homeY + 0.5, rec.homeZ, now, B.CFG.WANDER_RADIUS)
    return true
end })
