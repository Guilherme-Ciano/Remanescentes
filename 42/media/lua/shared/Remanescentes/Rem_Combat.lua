-- Remanescentes - combate: sobrevivente x zumbi.
-- Zumbis do jogo so atacam jogadores, entao simulamos os dois lados aqui.
require "Remanescentes/Rem_Core"
local Rem = Remanescentes

local ATTACK_ANIM_MS = 750
local ATTACK_HIT_MS = 350
local ATTACK_COOLDOWN_MS = 1100
local AGGRO_MS = 1000
local AGGRO_RADIUS = 7
local BITE_RANGE = 0.9
local BITE_COOLDOWN_MS = 1500

local lastBite = {} -- [zumbi agressor] = ms

-- ---------------------------------------------------------------- sobrevivente ataca
function Rem.startAttack(npc, enemy, now)
    npc.attackTarget = enemy
    npc.attackUntil = now + ATTACK_ANIM_MS
    npc.hitAt = now + ATTACK_HIT_MS
    npc.nextAttack = now + ATTACK_COOLDOWN_MS
    npc.z:setVariable("RemAttack", true)
    local item = npc.z:getPrimaryHandItem()
    if item and instanceof(item, "HandWeapon") and item:getSwingSound() then
        Rem.safe(function() npc.z:playSound(item:getSwingSound()) end)
    end
end

local function weaponDamage(npc)
    local item = npc.z:getPrimaryHandItem()
    local minD, maxD = 0.3, 0.5
    if item and instanceof(item, "HandWeapon") then
        minD, maxD = item:getMinDamage(), item:getMaxDamage()
    end
    return ZombRandFloat(minD, maxD) * Rem.cfg("NPCDamageMultiplier", 1.0), item
end

local function applyHit(npc, enemy)
    if enemy:isDead() or Rem.dist(npc.z, enemy) > Rem.reach(npc) + 0.5 then return end
    local dmg, item = weaponDamage(npc)
    local hp = enemy:getHealth() - dmg
    if item and instanceof(item, "HandWeapon") and item:getZombieHitSound() then
        Rem.safe(function() enemy:playSound(item:getZombieHitSound()) end)
    end
    Rem.safe(function() enemy:splatBloodFloor() end)
    if hp <= 0 then
        enemy:setHealth(0)
        Rem.safe(function() enemy:Kill(nil) end)
        Rem.debug((npc.rec.name or "?") .. " matou um zumbi")
    else
        enemy:setHealth(hp)
        if ZombRand(100) < 35 then
            enemy:setStaggerBack(true)
        end
    end
end

function Rem.updateAttack(npc, now)
    if npc.hitAt > 0 and now >= npc.hitAt then
        npc.hitAt = 0
        if npc.attackTarget then Rem.safe(applyHit, npc, npc.attackTarget) end
    end
    if npc.attackUntil > 0 and now >= npc.attackUntil then
        npc.attackUntil = 0
        npc.attackTarget = nil
        npc.z:setVariable("RemAttack", false)
    end
end

-- ---------------------------------------------------------------- zumbis atacam o sobrevivente
function Rem.zombieAggro(npc, now)
    if now < npc.nextAggro then return end
    npc.nextAggro = now + AGGRO_MS
    local z = npc.z
    local list = getCell():getZombieList()
    for i = 0, list:size() - 1 do
        local other = list:get(i)
        if other ~= z and not Rem.active[other] and not other:isDead() and not other:isOnFloor()
            and math.floor(other:getZ()) == math.floor(z:getZ()) then
            local d = Rem.dist(z, other)
            if d <= BITE_RANGE then
                other:faceThisObject(z)
                if now - (lastBite[other] or 0) >= BITE_COOLDOWN_MS then
                    lastBite[other] = now
                    Rem.damageNPC(npc, Rem.cfg("ZombieDamage", 0.15))
                end
            elseif d <= AGGRO_RADIUS and other:getTarget() == nil then
                -- zumbi ocioso perto: vem atras do sobrevivente
                other:pathToCharacter(z)
            end
        end
    end
end

function Rem.damageNPC(npc, amount)
    local z = npc.z
    local hp = z:getHealth() - amount
    Rem.safe(function() z:splatBloodFloor() end)
    if hp <= 0 then
        z:setHealth(0)
        z:setAvoidDamage(false)
        Rem.safe(function() z:Kill(nil) end)
    else
        z:setHealth(hp)
        if ZombRand(4) == 0 then Rem.say(npc, "IGUI_Rem_SayHurt") end
    end
end

-- Cura lenta fora de combate.
Events.EveryOneMinute.Add(function()
    for zombie, npc in pairs(Rem.active) do
        local maxH = npc.rec.maxHealth or Rem.cfg("NPCHealth", 3.0)
        if not zombie:isDead() and zombie:getHealth() < maxH then
            zombie:setHealth(math.min(maxH, zombie:getHealth() + maxH * 0.01))
        end
    end
    -- limpa cooldowns de zumbis antigos
    local n = 0
    for _ in pairs(lastBite) do n = n + 1 end
    if n > 500 then lastBite = {} end
end)
