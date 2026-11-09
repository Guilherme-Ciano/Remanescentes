-- Remanescentes - combate do sobrevivente: golpear zumbi, outro sobrevivente ou o jogador;
-- receber dano; morte. A parte "zumbi ataca sobrevivente" esta em Rem_Perception.lua.
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_Barks"
require "Remanescentes/Rem_Perception"
local Rem = Remanescentes

local ATTACK_ANIM_MS = 750
local ATTACK_HIT_MS = 350
local ATTACK_COOLDOWN_MS = 1100
local STEALTH_MULT = 3.0        -- golpe furtivo em zumbi que nao percebeu o sobrevivente
local PLAYER_DAMAGE_SCALE = 18  -- dano de arma (~0.5-2.0) -> dano em parte do corpo (0-100)

-- ---------------------------------------------------------------- tipos de alvo
function Rem.isPlayerObj(obj)
    return obj ~= nil and instanceof(obj, "IsoPlayer")
end

function Rem.targetDead(obj)
    return obj == nil or obj:isDead()
end

-- ---------------------------------------------------------------- sobrevivente ataca
function Rem.startAttack(npc, target, now)
    npc.attackTarget = target
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
    return ZombRandFloat(minD, maxD), item
end

local function weaponNoise(item)
    if item and instanceof(item, "HandWeapon") then
        local ok, r = pcall(function() return item:getSoundRadius() end)
        if ok and r and r > 0 then return r end
    end
    return 8
end

-- Ferimento de arma no jogador: corte com sangramento, SEM infeccao
-- (BodyPart.setCut(true, true): o 2o parametro pula generateZombieInfection).
function Rem.damagePlayer(player, dmg, attackerNpc)
    local bd = player:getBodyDamage()
    if not bd then return end
    local maxIdx = BodyPartType.ToIndex(BodyPartType.MAX)
    local part = bd:getBodyPart(BodyPartType.FromIndex(ZombRand(maxIdx)))
    if not part then return end
    part:AddDamage(dmg * PLAYER_DAMAGE_SCALE * Rem.cfg("NPCVsPlayerDamage", 1.0))
    if ZombRand(100) < 60 then
        part:setCut(true, true)
    else
        part:setScratched(true, true)
    end
    Rem.safe(function() player:splatBloodFloor() end)
    if attackerNpc then Rem.safe(function() player:setAttackedBy(attackerNpc.z) end) end
end

local function applyHit(npc, target)
    if Rem.targetDead(target) or Rem.dist(npc.z, target) > Rem.reach(npc) + 0.5 then return end
    local dmg, item = weaponDamage(npc)
    local now = Rem.nowMs()
    if item and instanceof(item, "HandWeapon") and item:getZombieHitSound() then
        Rem.safe(function() target:playSound(item:getZombieHitSound()) end)
    end

    -- jogador
    if Rem.isPlayerObj(target) then
        Rem.damagePlayer(target, dmg, npc)
        Rem.makeNoise(npc, weaponNoise(item))
        return
    end

    -- outro sobrevivente
    local other = Rem.active[target]
    if other then
        Rem.hitReact(other, now)
        Rem.damageNPC(other, dmg * Rem.cfg("NPCDamageMultiplier", 1.0), npc)
        Rem.makeNoise(npc, weaponNoise(item))
        if not Rem.active[target] then Rem.bark(npc, "kill") end
        return
    end

    -- zumbi
    dmg = dmg * Rem.cfg("NPCDamageMultiplier", 1.0)
    local stealth = npc.sneaking and not Rem.isAware(target, npc) and not Rem.isFacing(target, npc.z, 0.3)
    if stealth then dmg = dmg * STEALTH_MULT end
    Rem.safe(function() target:splatBloodFloor() end)
    Rem.makeNoise(npc, weaponNoise(item) * (stealth and 0.3 or 1.0))
    local hp = target:getHealth() - dmg
    if hp <= 0 then
        target:setHealth(0)
        Rem.safe(function() target:Kill(nil) end)
        Rem.bark(npc, "kill")
        Rem.debug((npc.rec.name or "?") .. " matou um zumbi" .. (stealth and " (furtivo)" or ""))
    else
        target:setHealth(hp)
        Rem.startHunt(target, npc, now)
        if ZombRand(100) < 35 then target:setStaggerBack(true) end
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

-- ---------------------------------------------------------------- dano recebido
function Rem.healthFraction(npc)
    local maxH = npc.rec.maxHealth or Rem.cfg("NPCHealth", 3.0)
    return npc.z:getHealth() / maxH
end

-- attacker (opcional) = npc que causou o dano; o alvo passa a revidar contra ele
function Rem.damageNPC(npc, amount, attacker)
    local z = npc.z
    local hp = z:getHealth() - amount
    Rem.safe(function() z:splatBloodFloor() end)
    if attacker then npc.lastAttacker = attacker end
    if hp <= 0 then
        z:setHealth(0)
        z:setAvoidDamage(false)
        Rem.safe(function() z:Kill(nil) end)
    else
        z:setHealth(hp)
        npc.rec.hp = hp
        Rem.bark(npc, "hurt")
    end
end

-- Jogador golpeou um sobrevivente: amigo vira inimigo se fogo amigo estiver ligado e
-- ele for atingido varias vezes; hostil so revida.
Events.OnHitZombie.Add(function(zombie, attacker, bodyPart, weapon)
    local npc = Rem.active[zombie]
    if not npc or not Rem.isPlayerObj(attacker) then return end
    Rem.hitReact(npc, Rem.nowMs())
    if Rem.isFriendly(npc) and Rem.cfg("FriendlyFire", false) then
        npc.playerHits = (npc.playerHits or 0) + 1
        if npc.playerHits >= 3 then
            npc.rec.hostileToPlayer = true
            Rem.applyFriendlyFire(npc)
            Rem.bark(npc, "betrayed", true)
        end
    end
end)

-- Cura lenta fora de combate.
Events.EveryOneMinute.Add(function()
    for zombie, npc in pairs(Rem.active) do
        local maxH = npc.rec.maxHealth or Rem.cfg("NPCHealth", 3.0)
        if not zombie:isDead() and zombie:getHealth() < maxH and not Rem.isHuntedBy(npc, 1) then
            zombie:setHealth(math.min(maxH, zombie:getHealth() + maxH * 0.01))
        end
    end
end)
