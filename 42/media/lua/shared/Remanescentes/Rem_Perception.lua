-- Remanescentes - zumbis x sobreviventes: percepcao, perseguicao e ATAQUE REAL.
--
-- Visao: decidimos aqui se um zumbi "ve" o sobrevivente (distancia, luz, linha de visao,
--   para onde o zumbi olha, postura). Audicao: os sobreviventes emitem addSound() real.
--
-- Ataque real (ZombieAttackMode = 1, padrao): o zumbi recebe setTarget(npc) e usa a IA
--   dele inteira: persegue, da o bote, se vira e ataca (AttackState), e o proprio jogo
--   decide acerto/erro (getAttackOutcome() == "success").
--   Problema: no acerto o jogo chama alvo.getBodyDamage().AddRandomDamageFromZombie(),
--   e zumbis tem bodyDamage == null (so IsoPlayer/IsoAnimal recebem um). Esse trecho so
--   roda se o atacante tiver dentes (AttackState.animEvent: "if (!isNoTeeth())"). Entao,
--   enquanto o alvo for um sobrevivente, o atacante fica com setNoTeeth(true) e nos
--   aplicamos o dano ao ler o resultado. Quando o alvo deixa de ser sobrevivente (ex.: viu
--   o jogador), os dentes voltam no mesmo tick. noTeeth nao e salvo no save.
--
-- Modo simulado (ZombieAttackMode = 2): perseguicao + animacao de bote + dano em Lua.
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_Barks"
local Rem = Remanescentes

local PERCEIVE_MS = 500
local SCAN_RADIUS = 25
local BITE_RANGE = 0.9
local BITE_COOLDOWN_MS = 1500
local ZATTACK_ANIM_MS = 700
local HUNT_MEMORY_MS = 12000
local HUNT_GIVEUP_DIST = 30
local REPATH_MS = 1000
local HIT_REACT_MS = 450

-- [zumbi] = { npc=, lastSeen=, nextPath=, real=bool, lastOutcome=, wasAttacking= }
Rem.hunting = Rem.hunting or {}
local lastBite = {}
local attackAnimEnd = {}

local function realMode()
    return Rem.cfg("ZombieAttackMode", 1) == 1
end

-- ---------------------------------------------------------------- utilidades
local function daylight()
    local ok, v = pcall(function() return getClimateManager():getDayLightStrength() end)
    if not ok or not v then return 1 end
    return math.max(0, math.min(1, v))
end

function Rem.stanceOf(npc)
    if npc.sneaking then return "sneak" end
    if npc.running then return "run" end
    return "walk"
end

function Rem.isFacing(watcher, target, minDot)
    local fwd = watcher:getForwardDirection()
    local dx, dy = target:getX() - watcher:getX(), target:getY() - watcher:getY()
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 0.001 then return true end
    return (fwd:getX() * dx + fwd:getY() * dy) / len >= (minDot or 0)
end

-- Alcance de visao (tiles) de um observador contra este sobrevivente.
function Rem.sightRange(npc, base)
    local range = base or Rem.cfg("ZombieSightRange", 10)
    range = range * (0.5 + 0.5 * daylight())
    local stance = Rem.stanceOf(npc)
    if stance == "sneak" then range = range * 0.45
    elseif stance == "run" then range = range * 1.25 end
    return range
end

function Rem.zombieNotices(zombie, npc, d)
    local range = Rem.sightRange(npc)
    if d > range then return false end
    local close = d < (npc.sneaking and 1.2 or 2.0)
    if not close and not Rem.isFacing(zombie, npc.z, -0.1) then return false end
    local ok, sees = pcall(function() return zombie:CanSee(npc.z) end)
    if ok and sees == false then return false end
    local chance = 1 - (d / range)
    if npc.sneaking then chance = chance * 0.5 end
    if npc.running then chance = math.min(1, chance * 1.3 + 0.1) end
    return ZombRandFloat(0, 1) < chance
end

function Rem.huntersOf(npc)
    local n = 0
    for _, h in pairs(Rem.hunting) do
        if h.npc == npc then n = n + 1 end
    end
    return n
end

function Rem.isHuntedBy(npc, atLeast)
    return Rem.huntersOf(npc) >= (atLeast or 1)
end

function Rem.isAware(zombie, npc)
    local h = Rem.hunting[zombie]
    return h ~= nil and h.npc == npc
end

-- ---------------------------------------------------------------- inicio/fim da caca
local function aimAt(zombie, npc)
    zombie:setNoTeeth(true)
    zombie:setTarget(npc.z)
end

function Rem.startHunt(zombie, npc, now)
    local h = Rem.hunting[zombie]
    if h and h.npc ~= npc then Rem.stopHunt(zombie) h = nil end
    if not h then
        h = { npc = npc, lastSeen = now, nextPath = 0, real = realMode() }
        Rem.hunting[zombie] = h
        if Rem.isHuntedBy(npc, 2) then Rem.bark(npc, "hunted") end
        Rem.debug("zumbi percebeu " .. tostring(npc.rec.name))
    end
    h.lastSeen = now
    if h.real then aimAt(zombie, npc) end
    return h
end

-- Devolve o zumbi ao normal. SEMPRE restaura os dentes.
function Rem.stopHunt(zombie)
    local h = Rem.hunting[zombie]
    Rem.hunting[zombie] = nil
    if not h then return end
    Rem.safe(function()
        zombie:setNoTeeth(false)
        if h.npc and zombie:getTarget() == h.npc.z then zombie:setTarget(nil) end
        zombie:setVariable("RemZAttack", false)
    end)
end

-- Sobrevivente saiu de cena/morreu: solta todos os zumbis que o cacavam.
function Rem.releaseHunters(npc)
    local list = {}
    for zombie, h in pairs(Rem.hunting) do
        if h.npc == npc then table.insert(list, zombie) end
    end
    for _, zombie in ipairs(list) do Rem.stopHunt(zombie) end
end

-- ---------------------------------------------------------------- ruido
function Rem.makeNoise(npc, radius)
    radius = math.floor(radius * Rem.cfg("NPCNoiseMultiplier", 1.0))
    if radius <= 0 then return end
    local z = npc.z
    Rem.safe(function()
        addSound(z, math.floor(z:getX()), math.floor(z:getY()), math.floor(z:getZ()), radius, radius)
    end)
end

-- ---------------------------------------------------------------- reacao ao golpe
function Rem.hitReact(npc, now)
    npc.hitUntil = now + HIT_REACT_MS
    npc.z:setVariable("RemHit", true)
end

function Rem.updateHitReact(npc, now)
    if npc.hitUntil > 0 and now >= npc.hitUntil then
        npc.hitUntil = 0
        npc.z:setVariable("RemHit", false)
    end
end

-- ---------------------------------------------------------------- ataque simulado
local function zombieBite(zombie, npc, now)
    if now - (lastBite[zombie] or 0) < BITE_COOLDOWN_MS then return end
    lastBite[zombie] = now
    zombie:faceThisObject(npc.z)
    zombie:setVariable("RemZAttack", true)
    attackAnimEnd[zombie] = now + ZATTACK_ANIM_MS
    Rem.hitReact(npc, now)
    Rem.damageNPC(npc, Rem.cfg("ZombieDamage", 0.15))
end

-- ---------------------------------------------------------------- todo tick
-- * encerra animacoes do modo simulado
-- * modo real: garante dentes/alvo coerentes e aplica dano nos acertos
function Rem.updateZombieAttacks(now)
    for zombie, t in pairs(attackAnimEnd) do
        if now >= t then
            attackAnimEnd[zombie] = nil
            Rem.safe(function() zombie:setVariable("RemZAttack", false) end)
        end
    end

    local drop = nil
    for zombie, h in pairs(Rem.hunting) do
        if h.real then
            local ok = Rem.safe(function()
                if zombie:isDead() or not Rem.active[h.npc.z] then
                    drop = drop or {}; table.insert(drop, zombie); return
                end
                local target = zombie:getTarget()
                if target ~= h.npc.z then
                    if target ~= nil then
                        -- trocou de alvo (ex.: jogador): dentes de volta JA e esquece o npc
                        drop = drop or {}; table.insert(drop, zombie); return
                    end
                    -- perdeu o alvo sozinho: re-mira enquanto lembrar
                    aimAt(zombie, h.npc)
                end
                -- detecta cada acerto: borda de subida de "success" ou novo ciclo de ataque
                local attacking = zombie:isAttacking()
                if attacking and not h.wasAttacking then h.lastOutcome = nil end
                h.wasAttacking = attacking
                local outcome = zombie:getAttackOutcome()
                if outcome == "success" and h.lastOutcome ~= "success" then
                    Rem.hitReact(h.npc, now)
                    Rem.damageNPC(h.npc, Rem.cfg("ZombieDamage", 0.15))
                end
                h.lastOutcome = outcome
            end)
            if not ok then drop = drop or {}; table.insert(drop, zombie) end
        end
    end
    if drop then for _, zombie in ipairs(drop) do Rem.stopHunt(zombie) end end
end

-- ---------------------------------------------------------------- por sobrevivente
function Rem.perceive(npc, now)
    if now < (npc.nextPerceive or 0) then return end
    npc.nextPerceive = now + PERCEIVE_MS
    local z = npc.z
    local list = getCell():getZombieList()
    for i = 0, list:size() - 1 do
        local other = list:get(i)
        if other ~= z and not Rem.active[other] and not other:isDead()
            and math.floor(other:getZ()) == math.floor(z:getZ()) then
            local d = Rem.dist(z, other)
            if d <= SCAN_RADIUS then
                local h = Rem.hunting[other]
                if h and h.npc == npc then
                    local ok, sees = pcall(function() return other:CanSee(z) end)
                    if (ok and sees) or d <= BITE_RANGE then h.lastSeen = now end
                    if now - h.lastSeen > HUNT_MEMORY_MS or d > HUNT_GIVEUP_DIST then
                        Rem.stopHunt(other)
                    else
                        -- no modo real, perto do alvo a IA do zumbi assume (bote/ataque);
                        -- um pathTo nessa hora atrapalharia o AttackState
                        if now >= h.nextPath and d > (h.real and 2.0 or BITE_RANGE) then
                            h.nextPath = now + REPATH_MS
                            other:pathToCharacter(z)
                        end
                        if not h.real and d <= BITE_RANGE and not other:isOnFloor() then
                            zombieBite(other, npc, now)
                        end
                    end
                elseif not h and other:getTarget() == nil then
                    -- zumbi livre (nao esta atras de um jogador)
                    local bumped = d <= BITE_RANGE and not other:isOnFloor()
                    if bumped or Rem.zombieNotices(other, npc, d) then
                        h = Rem.startHunt(other, npc, now)
                        h.nextPath = now + REPATH_MS
                        other:pathToCharacter(z)
                        if bumped and not h.real then zombieBite(other, npc, now) end
                    end
                end
            end
        end
    end
end

function Rem.cleanupHunting()
    local drop = {}
    for zombie, h in pairs(Rem.hunting) do
        if zombie:isDead() or not zombie:isExistInTheWorld() or not Rem.active[h.npc.z] then
            table.insert(drop, zombie)
        end
    end
    for _, zombie in ipairs(drop) do Rem.stopHunt(zombie) end
    local n = 0
    for _ in pairs(lastBite) do n = n + 1 end
    if n > 500 then lastBite = {} end
end

Events.EveryOneMinute.Add(function() Rem.safe(Rem.cleanupHunting) end)
