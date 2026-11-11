-- Remanescentes - rotina da casa: hora de comer.
--
-- No almoco e no jantar, quem esta em casa (menos o guarda) vai para a cozinha, senta e
-- come junto: conversam ("Ate que ficou bom.") e o moral sobe. Sem comida no estoque,
-- ninguem se reune e alguem reclama da fome.
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_Barks"
require "Remanescentes/Rem_Movement"
require "Remanescentes/Rem_Roles"
local Rem = Remanescentes

local RT = Rem.module("Routine", {
    MEALS = { { 12, 13 }, { 19, 20 } },   -- janelas (hora do dia)
    PRIORITY = 235,                        -- antes dos papeis (240)
    RADIUS = 2,
    MORALE = 3,
})
local CFG = RT.CFG

Rem.BARKS.meal = { n = 4, cd = 45000 }
Rem.BARKS.meal_none = { n = 2, cd = 600000 }

-- Indice da refeicao de agora (1 = almoco, 2 = jantar) ou nil.
function RT.mealNow()
    local tod = getGameTime():getTimeOfDay()
    for i, m in ipairs(CFG.MEALS) do
        if tod >= m[1] and tod < m[2] then return i end
    end
    return nil
end

function RT.mealBehavior(npc, ctx, now)
    local rec = npc.rec
    if rec.mode ~= "group" or rec.role == "guarda" then return false end
    local meal = RT.mealNow()
    if not meal then
        if npc.eating then
            npc.eating = nil
            Rem.clearRest(npc)
        end
        return false
    end
    local g = rec.groupId and Rem.getStore().groups[rec.groupId]
    if not g or g.activity ~= "home" or not g.home or not g.home.x1 then return false end
    if (g.supplies or 0) <= 0 then
        Rem.bark(npc, "meal_none")
        return false
    end
    local k = Rem.Roles.kitchenSpot(g.home)
    if not k then return false end
    if Rem.distXY(npc.z, k.x + 0.5, k.y + 0.5) > CFG.RADIUS + 1 then
        npc.eating = nil
        Rem.moveTo(npc, k.x + 0.5, k.y + 0.5, k.z or 0, now, "walk")
        return true
    end
    Rem.stopMoving(npc)
    Rem.setRest(npc, "sit")
    npc.eating = true
    -- uma vez por refeicao: comer junto faz bem
    local stamp = math.floor(Rem.worldHours() / 24) * 10 + meal
    if rec.mealAt ~= stamp then
        rec.mealAt = stamp
        if Rem.Persona then Rem.Persona.addMorale(rec, CFG.MORALE) end
    end
    Rem.bark(npc, "meal")
    return true
end
Rem.registerBehavior({ name = "meal", priority = CFG.PRIORITY, run = RT.mealBehavior })
