-- Remanescentes - Fase A: percepcao e perseguicao "como gente".
--
-- Visao (A1): alcance pela luz do dia (noite reduz muito), pela sua postura (agachado,
--   andando, correndo) e pelo campo de visao do NPC (de frente ve longe; de lado, menos;
--   de costas so colado). Linha de visao pelo jogo (CanSee), e se a checagem falhar o NPC
--   NAO ve (falha fechada).
-- Atencao: ver nao e instantaneo. A atencao sobe aos poucos (mais rapido perto) e cai
--   quando nao te ve. Estados: none -> suspicious (viu algo, vai olhar) -> chase (te
--   reconheceu, persegue) -> search (te perdeu: procura no ultimo ponto) -> desiste.
-- Audicao (A2): sons do mundo (tiros, gritos, vidro, NPCs atirando) chamam a atencao:
--   o NPC vai investigar o ponto do som, sem saber exatamente onde voce esta.
-- Memoria (A3): perdeu de vista -> segue ate o ultimo ponto por alguns segundos, procura
--   em volta e desiste ("Sumiu..."). Depois de desistir, demora mais para te notar de novo.
-- Folego (A4): correr cansa. Sem folego (ou muito ferido), so anda.
-- Coleira (A5): longe demais de casa/do grupo, desiste e volta.
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_Factions"
require "Remanescentes/Rem_Barks"
require "Remanescentes/Rem_Movement"
require "Remanescentes/Rem_Perception"
local Rem = Remanescentes

local A = Rem.module("Awareness", {
    SIGHT = 18,               -- alcance de dia, de frente, voce andando
    NIGHT_FACTOR = 0.35,      -- multiplicador do alcance na escuridao total
    STANCE = { sneak = 0.5, still = 0.8, walk = 1.0, run = 1.3 },
    FOV_FRONT = 0.35,         -- produto escalar acima disso: campo de visao frontal
    FOV_SIDE = -0.2,          -- entre SIDE e FRONT: visao lateral
    SIDE_FACTOR = 0.5,
    BEHIND_RANGE = 1.8,       -- de costas: so percebe colado
    CLOSE = 1.8,              -- colado: percebe na hora
    NOTICE_RATE = 1.4,        -- atencao ganha por segundo a queima-roupa (cai com a distancia)
    MIN_NOTICE = 0.15,
    SUSPICIOUS_AT = 0.35,
    DECAY_RATE = 0.2,         -- atencao perdida por segundo sem te ver (antes de perseguir)
    MEMORY_MS = 3000,         -- perdeu de vista: ainda "sabe" onde voce esta por esse tempo
    SEARCH_MS = 15000,        -- procura no ultimo ponto por esse tempo
    SEARCH_RADIUS = 5,
    ARRIVE = 1.5,
    REGAIN_FACTOR = 0.5,      -- depois de desistir: nota mais devagar...
    REGAIN_MS = 60000,        -- ...por esse tempo
    HEAR_FACTOR = 0.8,        -- ouve sons a ate raio*isso
    INVESTIGATE_MS = 12000,
    LEASH = { default = 45, saqueadores = 70, seita = 55 },
    CHASE_MAX = 40,           -- nunca persegue alem disso (mesmo vendo)
    RUN_SECONDS_YOUNG = 25,   -- folego de corrida aos 18 anos (cai com a idade)
    RUN_SECONDS_MIN = 10,
    REGEN_SECONDS = 30,       -- folego volta todo em tanto tempo andando/parado
    WINDED_RECOVER = 0.4,     -- sem folego: so volta a correr com essa fracao
    LIMP_BELOW = 0.4,         -- vida abaixo disso: manca (nao corre)
    INVESTIGATE_PRIORITY = 50,
    TICK_MS = 250,
})
local CFG = A.CFG

Rem.BARKS.suspicious = { n = 3, cd = 20000 }
Rem.BARKS.search = { urgent = true, n = 3, cd = 15000 }   -- avisa que voce despistou
Rem.BARKS.giveup = { urgent = true, n = 3, cd = 30000 }
Rem.BARKS.winded = { n = 3, cd = 30000 }

-- ---------------------------------------------------------------- luz e visao
function A.light()
    local ok, v = pcall(function() return getClimateManager():getDayLightStrength() end)
    if not ok or not v then return 1 end
    return math.max(0, math.min(1, v))
end

local function stanceOf(obj)
    if Rem.isPlayerObj(obj) then
        local sneak = false
        pcall(function() sneak = obj:isSneaking() end)
        if sneak then return "sneak" end
        local run = false
        pcall(function() run = obj:isRunning() or obj:isSprinting() end)
        if run then return "run" end
        local moving = true
        pcall(function() moving = obj:isPlayerMoving() end)
        return moving and "walk" or "still"
    end
    local other = Rem.active[obj]
    if other then
        if other.sneaking then return "sneak" end
        if other.running then return "run" end
    end
    return "walk"
end

-- Linha de visao do jogo; erro = nao ve.
function A.lineOfSight(npc, obj)
    local ok, sees = pcall(function() return npc.z:CanSee(obj) end)
    return ok and sees == true
end

-- Alcance efetivo de visao de npc contra obj (sem contar a linha de visao).
function A.sightRange(npc, obj)
    local range = CFG.SIGHT * Rem.difficulty().sight
    range = range * (CFG.NIGHT_FACTOR + (1 - CFG.NIGHT_FACTOR) * A.light())
    range = range * (CFG.STANCE[stanceOf(obj)] or 1)
    local dot = 1
    local ok = pcall(function()
        local fwd = npc.z:getForwardDirection()
        local dx, dy = obj:getX() - npc.z:getX(), obj:getY() - npc.z:getY()
        local len = math.sqrt(dx * dx + dy * dy)
        if len > 0.001 then dot = (fwd:getX() * dx + fwd:getY() * dy) / len end
    end)
    if not ok then dot = 1 end
    if dot < CFG.FOV_SIDE then return CFG.BEHIND_RANGE end
    if dot < CFG.FOV_FRONT then range = range * CFG.SIDE_FACTOR end
    return range
end

-- O npc ve obj a distancia d agora?
function A.sees(npc, obj, d)
    if d <= CFG.CLOSE then return true end
    if d > A.sightRange(npc, obj) then return false end
    return A.lineOfSight(npc, obj)
end

-- ---------------------------------------------------------------- atencao sobre o jogador
local function homeOf(npc)
    local rec = npc.rec
    local g = rec.groupId and Rem.getStore().groups[rec.groupId]
    if g and g.home then return g.home.x, g.home.y end
    return rec.homeX, rec.homeY
end

function A.leashOf(npc)
    return CFG.LEASH[npc.rec.faction] or CFG.LEASH.default
end

function A.state(npc)
    npc.awareP = npc.awareP or { level = 0, state = "none" }
    return npc.awareP
end

function A.giveUp(npc, now, quiet)
    local aw = A.state(npc)
    if aw.state == "chase" or aw.state == "search" then
        if not quiet then Rem.bark(npc, "giveup") end
        aw.gaveUpAt = now
    end
    aw.state, aw.level = "none", 0
    aw.lastSeen, aw.searchUntil = nil, nil
end

-- Ja sabe onde voce esta (ex.: emboscada, Rem_Stories): comeca a perseguir na hora.
function A.alert(npc, player, now)
    local aw = A.state(npc)
    aw.level = 1
    aw.lastX, aw.lastY, aw.lastZ = player:getX(), player:getY(), player:getZ()
    aw.lastSeen, aw.updatedAt = now, now
    if aw.state ~= "chase" then
        aw.state = "chase"
        aw.chaseStart = now
        Rem.emit("spottedPlayer", npc, now)
    end
end

-- Atualiza a atencao do npc sobre o jogador. Retorna true se o jogador e o inimigo atual
-- (visto agora ou ha pouquissimo tempo).
function A.trackPlayer(npc, player, now)
    local aw = A.state(npc)
    local dt = math.min(1, (now - (aw.updatedAt or now)) / 1000)
    aw.updatedAt = now
    local d = Rem.dist(npc.z, player)
    local hx, hy = homeOf(npc)

    -- coleira: longe de casa ou longe demais, desiste
    if (aw.state == "chase" or aw.state == "search") and
        ((hx and Rem.dist2(npc.z:getX(), npc.z:getY(), hx, hy) > A.leashOf(npc)) or d > CFG.CHASE_MAX) then
        A.giveUp(npc, now)
        return false
    end

    local sees = A.sees(npc, player, d)
    if sees then
        local rate = CFG.NOTICE_RATE * math.max(CFG.MIN_NOTICE, 1 - d / math.max(1, A.sightRange(npc, player)))
        if aw.gaveUpAt and now - aw.gaveUpAt < CFG.REGAIN_MS then rate = rate * CFG.REGAIN_FACTOR end
        aw.level = math.min(1, aw.level + rate * dt)
        if d <= CFG.CLOSE then aw.level = 1 end
        aw.lastX, aw.lastY, aw.lastZ = player:getX(), player:getY(), player:getZ()
        aw.lastSeen = now
        if aw.level >= 1 then
            if aw.state ~= "chase" then
                aw.state = "chase"
                aw.chaseStart = now
                Rem.emit("spottedPlayer", npc, now)
                Rem.bark(npc, "threat", true)
            end
        elseif aw.level >= CFG.SUSPICIOUS_AT and aw.state == "none" then
            aw.state = "suspicious"
            aw.searchUntil = now + CFG.INVESTIGATE_MS
            Rem.bark(npc, "suspicious")
        end
    else
        if aw.state == "chase" then
            if now - (aw.lastSeen or 0) > CFG.MEMORY_MS then
                aw.state = "search"
                aw.searchUntil = now + CFG.SEARCH_MS
                Rem.bark(npc, "search")
            end
        elseif aw.state == "search" or aw.state == "suspicious" then
            if now > (aw.searchUntil or 0) then A.giveUp(npc, now, aw.state == "suspicious") end
        else
            aw.level = math.max(0, aw.level - CFG.DECAY_RATE * dt)
        end
    end
    -- persegue quem esta vendo, ou quem acabou de sumir (ainda sabe onde esta)
    return aw.state == "chase" and now - (aw.lastSeen or 0) <= CFG.MEMORY_MS
end

-- ---------------------------------------------------------------- audicao
function A.hear(x, y, z, radius, source)
    if not Rem.isAuthority() then return end
    local now = Rem.nowMs()
    local player = getPlayer()
    for _, npc in pairs(Rem.active) do
        if npc.z ~= source and math.floor(npc.z:getZ()) == math.floor(z or 0) then
            local d = Rem.dist2(npc.z:getX(), npc.z:getY(), x, y)
            if d <= radius * CFG.HEAR_FACTOR and d > 1 then
                if Rem.isHostileToPlayer(npc) then
                    local aw = A.state(npc)
                    if aw.state == "none" or aw.state == "suspicious" or aw.state == "search" then
                        if aw.state == "none" then Rem.bark(npc, "suspicious") end
                        aw.state = (aw.state == "search") and "search" or "suspicious"
                        aw.lastX, aw.lastY, aw.lastZ = x, y, z or 0
                        aw.searchUntil = now + CFG.INVESTIGATE_MS
                    end
                else
                    Rem.safe(function() npc.z:faceLocationF(x, y) end)
                end
            end
        end
    end
end

-- OnWorldSound(x, y, z, raio, volume, fonte)
Events.OnWorldSound.Add(function(x, y, z, radius, volume, source)
    Rem.safe(A.hear, x, y, z, radius, source)
end)

-- ---------------------------------------------------------------- investigar / procurar
-- Comportamento: hostil desconfiado ou que te perdeu vai ate o ultimo ponto e procura.
function A.investigateBehavior(npc, ctx, now)
    local aw = npc.awareP
    if not aw or not (aw.state == "suspicious" or aw.state == "search") or not aw.lastX then return false end
    if not Rem.isHostileToPlayer(npc) then return false end
    local d = Rem.dist2(npc.z:getX(), npc.z:getY(), aw.lastX, aw.lastY)
    if d > CFG.ARRIVE then
        local gait = (aw.state == "search") and Rem.travelGait(npc, d) or Rem.baseGait(npc)
        Rem.moveTo(npc, aw.lastX, aw.lastY, aw.lastZ or 0, now, gait)
        return true
    end
    -- chegou: procura em volta
    if not Rem.isMoving(npc) and ZombRand(4) == 0 then
        local r = CFG.SEARCH_RADIUS
        Rem.moveTo(npc, aw.lastX + ZombRand(-r, r + 1), aw.lastY + ZombRand(-r, r + 1), aw.lastZ or 0, now, Rem.baseGait(npc))
    end
    return true
end

-- ---------------------------------------------------------------- folego
function A.runSeconds(rec)
    local age = rec.age or 30
    return math.max(CFG.RUN_SECONDS_MIN, CFG.RUN_SECONDS_YOUNG - (age - 18) * 0.25)
end

function A.tickStamina(npc, now)
    local dt = math.min(1, (now - (npc.staminaAt or now)) / 1000)
    npc.staminaAt = now
    npc.stamina = npc.stamina or 1
    if npc.running and Rem.isMoving(npc) then
        npc.stamina = math.max(0, npc.stamina - dt / A.runSeconds(npc.rec))
        if npc.stamina <= 0 and not npc.winded then
            npc.winded = true
            Rem.bark(npc, "winded")
        end
    else
        npc.stamina = math.min(1, npc.stamina + dt / CFG.REGEN_SECONDS)
        if npc.winded and npc.stamina >= CFG.WINDED_RECOVER then npc.winded = false end
    end
    npc.limping = Rem.healthFraction and Rem.healthFraction(npc) < CFG.LIMP_BELOW
    -- sem folego/mancando: se estava correndo, passa a andar
    if npc.running and (npc.winded or npc.limping) then Rem.setGait(npc, "walk") end
end

local nextTick = 0
Events.OnTick.Add(function()
    if not Rem.isAuthority() or Rem.activeCount == 0 then return end
    local now = Rem.nowMs()
    if now < nextTick then return end
    nextTick = now + CFG.TICK_MS
    for _, npc in pairs(Rem.active) do Rem.safe(A.tickStamina, npc, now) end
end)

-- ---------------------------------------------------------------- ganchos
Rem.registerBehavior({ name = "investigate", priority = CFG.INVESTIGATE_PRIORITY, run = A.investigateBehavior })
