-- Remanescentes - combate do sobrevivente: golpear zumbi, outro sobrevivente ou o jogador;
-- receber dano; morte. A parte "zumbi ataca sobrevivente" esta em Rem_Perception.lua.
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_Barks"
require "Remanescentes/Rem_Perception"
local Rem = Remanescentes

local M = Rem.module("Combat", {
    ATTACK_ANIM_MS = 750,
    ATTACK_HIT_MS = 350,
    ATTACK_COOLDOWN_MS = 1100,
    STEALTH_MULT = 3.0,         -- golpe furtivo em zumbi que nao percebeu o sobrevivente
    PLAYER_DAMAGE_SCALE = 8,    -- dano de arma (~0.5-3.0) -> dano em parte do corpo (0-100)
    BULLET_DAMAGE_SCALE = 14,
    BLOCKED_FACTOR = 0.2,       -- roupa segurou o golpe: so isso do dano
    PLAYER_HIT_MS = 480,        -- golpe no jogador: mais preparacao (da para reagir)
    PLAYER_COOLDOWN_MS = 1700,  -- e mais intervalo entre golpes
})

-- ---------------------------------------------------------------- tipos de alvo
function Rem.isPlayerObj(obj)
    return obj ~= nil and instanceof(obj, "IsoPlayer")
end

function Rem.targetDead(obj)
    return obj == nil or obj:isDead()
end

-- ---------------------------------------------------------------- pode agir?
-- O corpo do sobrevivente e um zumbi: quando derrubado/empurrado o motor do jogo o poe em
-- estados de chao (onground, getup, staggerback, falldown, knockeddown...). Nesses estados
-- ele NAO pode atacar, atirar nem andar. So age de pe, nos estados que o mod controla.
M.CFG.ACTIVE_STATES = M.CFG.ACTIVE_STATES or { idle = true, pathfind = true, walktoward = true }

local function flag(z, method)
    local ok, v = pcall(function() return z[method](z) end)
    return ok and v == true
end

function Rem.canAct(npc)
    local z = npc.z
    local ok, st = pcall(function() return z:getActionStateName() end)
    if ok and st and st ~= "" and not M.CFG.ACTIVE_STATES[st] then return false end
    if flag(z, "isOnFloor") or flag(z, "isKnockedDown") or flag(z, "isGettingUp") or flag(z, "isStaggerBack") then
        return false
    end
    return true
end

-- Cancela o golpe/tiro em andamento (derrubado no meio do ataque).
function Rem.cancelAttack(npc)
    npc.hitAt, npc.attackUntil, npc.attackTarget = 0, 0, nil
    npc.z:setVariable("RemAttack", false)
    if npc.shootUntil then
        npc.shootUntil = nil
        npc.z:setVariable("RemShoot", false)
    end
end

-- ---------------------------------------------------------------- sobrevivente ataca
function Rem.startAttack(npc, target, now)
    if Rem.clearRest then Rem.clearRest(npc) end
    npc.attackTarget = target
    npc.attackUntil = now + M.CFG.ATTACK_ANIM_MS
    local atPlayer = Rem.isPlayerObj(target)
    npc.hitAt = now + (atPlayer and M.CFG.PLAYER_HIT_MS or M.CFG.ATTACK_HIT_MS)
    npc.nextAttack = now + (atPlayer and M.CFG.PLAYER_COOLDOWN_MS or M.CFG.ATTACK_COOLDOWN_MS)
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

-- Ferimento no jogador (Fase B1), SEM infeccao de zumbi.
-- * dano = dano da arma x escala x dificuldade x sandbox (NPCVsPlayerDamage);
-- * a ROUPA protege: a mesma defesa por parte do corpo que o jogo usa
--   (getBodyPartClothingDefense, com "bala" para tiros). Bloqueou: so um hematoma
--   (pouco dano, sem corte/bala);
-- * nao bloqueou: golpe vira corte ou arranhao (setCut/setScratched com o 2o parametro
--   pulando a infeccao); tiro deixa a bala alojada (setHaveBullet).
-- kind: "melee" (padrao) ou "bullet".
function Rem.woundPlayer(player, dmg, attackerNpc, kind)
    local bd = player:getBodyDamage()
    if not bd then return nil end
    local bullet = (kind == "bullet")
    local maxIdx = BodyPartType.ToIndex(BodyPartType.MAX)
    local idx = ZombRand(maxIdx)
    local part = bd:getBodyPart(BodyPartType.FromIndex(idx))
    if not part then return nil end
    local scale = bullet and M.CFG.BULLET_DAMAGE_SCALE or M.CFG.PLAYER_DAMAGE_SCALE
    local amount = dmg * scale * Rem.difficulty().dmg * Rem.cfg("NPCVsPlayerDamage", 1.0)
    local defense = 0
    pcall(function() defense = player:getBodyPartClothingDefense(idx, false, bullet) or 0 end)
    local blocked = ZombRand(100) < defense
    if blocked then
        part:AddDamage(amount * M.CFG.BLOCKED_FACTOR)
    else
        part:AddDamage(amount)
        if bullet then
            part:setHaveBullet(true, 0)
        elseif ZombRand(100) < 60 then
            part:setCut(true, true)
        else
            part:setScratched(true, true)
        end
        Rem.safe(function() player:splatBloodFloor() end)
    end
    if attackerNpc then Rem.safe(function() player:setAttackedBy(attackerNpc.z) end) end
    return blocked and "blocked" or "wounded"
end

-- (nome antigo, mantido)
function Rem.damagePlayer(player, dmg, attackerNpc)
    return Rem.woundPlayer(player, dmg, attackerNpc, "melee")
end

local function applyHit(npc, target)
    if not Rem.canAct(npc) then return end   -- caiu no meio do golpe: nao acerta
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
        Rem.damageNPC(other, dmg * Rem.cfg("NPCDamageMultiplier", 1.0) * (Rem.Wounds and Rem.Wounds.damageMult(npc.rec) or 1), npc)
        Rem.makeNoise(npc, weaponNoise(item))
        if not Rem.active[target] then Rem.bark(npc, "kill") end
        return
    end

    -- zumbi
    dmg = dmg * Rem.cfg("NPCDamageMultiplier", 1.0) * (Rem.Bonds and Rem.Bonds.damageMult(npc) or 1)
        * (Rem.Needs and Rem.Needs.damageMult(npc.rec) or 1)
        * (Rem.Wounds and Rem.Wounds.damageMult(npc.rec) or 1)
    local stealth = npc.sneaking and not Rem.isAware(target, npc) and not Rem.isFacing(target, npc.z, 0.3)
    if stealth then dmg = dmg * M.CFG.STEALTH_MULT end
    Rem.safe(function() target:splatBloodFloor() end)
    Rem.makeNoise(npc, weaponNoise(item) * (stealth and 0.3 or 1.0))
    local hp = target:getHealth() - dmg
    if hp <= 0 then
        target:setHealth(0)
        Rem.safe(function() target:Kill(nil) end)
        Rem.bark(npc, "kill")
        Rem.emit("npcKilledZombie", npc, target)
        Rem.debug((npc.rec.name or "?") .. " matou um zumbi" .. (stealth and " (furtivo)" or ""))
    else
        target:setHealth(hp)
        Rem.startHunt(target, npc, now)
        if ZombRand(100) < 35 then target:setStaggerBack(true) end
    end
end

function Rem.updateAttack(npc, now)
    if (npc.hitAt > 0 or npc.attackUntil > 0) and not Rem.canAct(npc) then
        Rem.cancelAttack(npc)
        return
    end
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
    local maxH = npc.rec.maxHealth or Rem.cfg("NPCHealth", 2.0)
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
        Rem.emit("npcDamaged", npc, amount, attacker)     -- (golpe forte pode ferir de verdade: Rem_Wounds)
    end
end

-- Jogador golpeou um sobrevivente: amigo vira inimigo se fogo amigo estiver ligado e
-- ele for atingido varias vezes; hostil so revida.
Events.OnHitZombie.Add(function(zombie, attacker, bodyPart, weapon)
    if not Rem.isPlayerObj(attacker) then return end
    local npc = Rem.active[zombie]
    if not npc then
        -- jogador golpeou um zumbi: os aliados entram na briga (Rem.playerFighting)
        Rem.playerFightAt = Rem.nowMs()
        return
    end
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
        local maxH = npc.rec.maxHealth or Rem.cfg("NPCHealth", 2.0)
        if not zombie:isDead() and zombie:getHealth() < maxH and not Rem.isHuntedBy(npc, 1) then
            zombie:setHealth(math.min(maxH, zombie:getHealth() + maxH * 0.01))
        end
    end
end)
