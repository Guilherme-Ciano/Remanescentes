-- Remanescentes - cerebro: decide o que cada sobrevivente em cena faz.
-- Roda no OnTick, mas cada sobrevivente so "pensa" a cada THINK_MS.
--
-- Prioridades (Rem.think):
--   0. levando golpe / animacao de ataque -> espera
--   1. vida baixa, em desvantagem ou medo  -> FUGIR (correndo)
--   2. inimigo ao alcance                  -> ATACAR
--   3. inimigo perto e vale a pena         -> IR ATE ELE
--   4. comportamentos registrados (Rem.registerBehavior), em ordem crescente de priority;
--      o primeiro que retornar true encerra o think. Padrao (Rem_Behaviors.lua):
--        100 follow   seguir o jogador
--        200 stay     ficar no lugar
--        300 group    rotina do grupo (casa/saque/volta)
--        900 wander   passear perto de "casa" / ocioso
-- Inimigos: zumbis; sobreviventes de faccao rival; o jogador, se hostil e visivel.
--
-- Zumbis so viram inimigos se forem AMEACA (exceto para o temperamento agressivo):
--   * colado no sobrevivente; ou
--   * percebeu o sobrevivente e esta vindo; ou
--   * (amigos do jogador) atacando o jogador por perto; ou
--   * (amigos do jogador) o jogador comecou a briga ha pouco e o zumbi esta perto dele.
-- Um zumbi distraido passando longe e ignorado.
--
-- Comportamento novo (ex.: num modulo de necessidades):
--   Rem.registerBehavior({ name = "comer", priority = 250, run = function(npc, ctx, now)
--       if not estaComFome(npc) then return false end
--       Rem.hangAround(npc, x, y, z, now, 1); return true
--   end })
-- ctx = { enemy = inimigo ou nil, dist = distancia dele, temper = temperamento, player = getPlayer() }
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_Factions"
require "Remanescentes/Rem_Spawn"
require "Remanescentes/Rem_Barks"
require "Remanescentes/Rem_Perception"
require "Remanescentes/Rem_Combat"
require "Remanescentes/Rem_Movement"
require "Remanescentes/Rem_Behaviors"
require "Remanescentes/Rem_Awareness"
require "Remanescentes/Rem_Spatial"
local Rem = Remanescentes

local B = Rem.module("Brain", {
    THINK_MS = 250,
    SCAN_RADIUS = 12,
    ENGAGE_RADIUS = 6,
    STEALTH_ENGAGE = 3,
    HOSTILE_SIGHT = 14,         -- ate onde um hostil enxerga o jogador/rivais
    SAFE_DIST = 10,             -- fugindo: para de fugir com o inimigo mais longe que isso
    RUN_NOISE_MS = 1000,
    RUN_NOISE_RADIUS = 7,
    CLOSE_THREAT = 2.2,         -- zumbi a essa distancia e sempre ameaca
    THREAT_RADIUS = 8,          -- zumbi que percebeu o sobrevivente, ate essa distancia
    GUARD_RADIUS = 5,           -- zumbi atras do jogador, a essa distancia do jogador
    ASSIST_RADIUS = 7,          -- jogador brigando: zumbis a essa distancia dele
    PLAYER_FIGHT_MS = 10000,    -- quanto tempo "o jogador esta brigando" dura apos um golpe
    CROWD_RADIUS = 5,
    LEASH = 8,                  -- seguidor nao se afasta mais que isso do jogador por um zumbi
    OUTNUMBERED = { cauteloso = 4, defensivo = 5 }, -- zumbis em volta para recuar
    SCARED_RADIUS = 6,          -- medroso foge de ameacas a essa distancia
    SPAWN_SETTLE_MS = 3000,     -- corpo recem-criado pode ficar sem quadrado por esse tempo
})

-- ---------------------------------------------------------------- comportamentos
-- Registro em Rem_Registry.lua (Rem.registerBehavior); os padrao em Rem_Behaviors.lua.
-- Roda os comportamentos em ordem; retorna o nome do que tratou o tick (ou nil).
-- Erro num comportamento e logado e o proximo e tentado.
function Rem.runBehaviors(npc, ctx, now)
    local list = Rem.behaviors
    for i = 1, #list do
        local b = list[i]
        local ok, handled = pcall(b.run, npc, ctx, now)
        if not ok then
            Rem.log("ERRO no comportamento " .. tostring(b.name) .. ": " .. tostring(handled))
        elseif handled then
            return b.name
        end
    end
    return nil
end

-- ---------------------------------------------------------------- inimigos

-- O jogador comecou uma briga ha pouco? (golpeou um zumbi)
function Rem.playerFighting(now)
    return Rem.playerFightAt ~= nil and (now - Rem.playerFightAt) < B.CFG.PLAYER_FIGHT_MS
end

-- Este zumbi e uma ameaca que justifica lutar? (ver cabecalho)
function Rem.isThreat(npc, zombie, d, player, assist)
    if d <= B.CFG.CLOSE_THREAT then return true end
    if d <= B.CFG.THREAT_RADIUS and (Rem.isAware(zombie, npc) or zombie:getTarget() == npc.z) then return true end
    if player and Rem.isFriendly(npc) then
        local pd = Rem.dist(zombie, player)
        if pd <= B.CFG.GUARD_RADIUS and zombie:getTarget() == player then return true end
        if assist and pd <= B.CFG.ASSIST_RADIUS then return true end
    end
    return false
end

-- Retorna o inimigo mais perto (zumbi que ameaca, sobrevivente rival ou jogador) e a
-- distancia. Conta tambem quantos zumbis estao em volta (npc.crowd).
function Rem.findEnemy(npc, now)
    now = now or Rem.nowMs()
    local z = npc.z
    local zFloor = math.floor(z:getZ())
    local best, bestD = nil, B.CFG.SCAN_RADIUS
    local aggressive = Rem.temperOf(npc) == "agressivo"
    local player = getPlayer()
    if player and player:isDead() then player = nil end
    local assist = player ~= nil and Rem.isFriendly(npc) and Rem.playerFighting(now)
    local crowd = 0

    local near = Rem.zombiesNear(z:getX(), z:getY(), math.max(B.CFG.SCAN_RADIUS, B.CFG.CROWD_RADIUS))
    for i = 1, #near do
        local other = near[i]
        if other ~= z and math.floor(other:getZ()) == zFloor then
            local d = Rem.dist(z, other)
            local otherNpc = Rem.active[other]
            if not otherNpc and d <= B.CFG.CROWD_RADIUS then crowd = crowd + 1 end
            if d < bestD then
                if not otherNpc then
                    if aggressive or Rem.isThreat(npc, other, d, player, assist) then
                        best, bestD = other, d
                    end
                elseif Rem.npcsHostile(npc, otherNpc) and Rem.Awareness.sees(npc, other, d) then
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

    npc.crowd = crowd
    -- jogador: so e inimigo se o hostil te percebeu de verdade (Rem_Awareness: visao com
    -- luz/postura/campo de visao, memoria curta, procura, desistencia, coleira) e se nao
    -- houver tregua (assalto resolvido, rendicao; Rem_Mugging)
    if player and math.floor(player:getZ()) == zFloor and Rem.isHostileToPlayer(npc)
        and not (Rem.Mugging and Rem.Mugging.ignoresPlayer(npc, now)) then
        if Rem.Awareness.trackPlayer(npc, player, now) then
            local d = Rem.dist(z, player)
            if not best or d < bestD then best, bestD = player, d end
        end
    elseif npc.awareP and npc.awareP.state ~= "none" then
        Rem.Awareness.giveUp(npc, now, true)   -- deixou de ser hostil (tregua, reputacao)
    end
    return best, bestD
end

function Rem.reach(npc)
    local item = npc.z:getPrimaryHandItem()
    local r = 1.0
    if item and instanceof(item, "HandWeapon") then r = item:getMaxRange() end
    return math.max(0.9, r) + 0.15
end

function Rem.think(npc, now)
    local z = npc.z
    if not z:isUseless() then z:setUseless(true) end
    if z:getTarget() then z:setTarget(nil) end
    Rem.syncRecord(npc)

    -- 0a. no chao, levantando, cambaleando: nao faz nada (nem ataca)
    if not Rem.canAct(npc) then
        Rem.cancelAttack(npc)
        npc.downSince = npc.downSince or now
        return
    end
    npc.downSince = nil

    -- 0. levando golpe, atacando ou atirando
    if now < npc.hitUntil or now < npc.attackUntil or now < (npc.shootUntil or 0) then return end

    local rec = npc.rec
    local enemy, d = Rem.findEnemy(npc, now)
    local temper = Rem.temperOf(npc)
    local player = getPlayer()
    local isZombie = enemy ~= nil and not Rem.active[enemy] and not Rem.isPlayerObj(enemy)

    -- seguidor nao larga o jogador para correr atras de zumbi longe dele
    if enemy and isZombie and rec.mode == "follow" and player and d > Rem.reach(npc)
        and Rem.dist(enemy, player) > B.CFG.LEASH then
        enemy, d = nil, nil
    end

    -- 0b. saqueador exigindo / grupo fugindo / rendicao (Rem_Mugging): decide antes da
    --     fuga generica (senao um ferido nunca se renderia)
    if enemy and Rem.Mugging and Rem.isPlayerObj(enemy) and Rem.Mugging.handle(npc, enemy, d, now) then return end

    -- 1. fugir: pouca vida, em desvantagem, ou medo
    local fleeAt = Rem.cfg("FleeHealthPercent", 30) / 100
    local limit = B.CFG.OUTNUMBERED[temper]
    local outnumbered = limit ~= nil and (npc.crowd or 0) >= limit
        and not (temper == "defensivo" and Rem.playerFighting(now))
    local scared = temper == "medroso" and d ~= nil and d <= B.CFG.SCARED_RADIUS
    if enemy and (Rem.healthFraction(npc) < fleeAt or outnumbered or scared) then
        npc.fleeing = true
    elseif npc.fleeing and (not enemy or d > B.CFG.SAFE_DIST) then
        npc.fleeing = false
    end
    if npc.fleeing and enemy then
        if d <= Rem.reach(npc) and ZombRand(3) == 0 then
            Rem.stopMoving(npc)
            z:faceThisObject(enemy)
            if now >= npc.nextAttack then Rem.startAttack(npc, enemy, now) end
        else
            Rem.flee(npc, enemy, now)
        end
        return
    end

    if enemy then
        -- 2b. atirador com municao: atira de longe (Rem_Ranged)
        if Rem.tryRanged and Rem.tryRanged(npc, enemy, d, now) then return end
        -- 2. ao alcance: ataca
        if d <= Rem.reach(npc) then
            Rem.stopMoving(npc)
            Rem.setGait(npc, Rem.baseGait(npc))
            z:faceThisObject(enemy)
            if now >= npc.nextAttack then Rem.startAttack(npc, enemy, now) end
            return
        end
        -- 3. vale a pena ir ate ele?
        local engage = B.CFG.ENGAGE_RADIUS
        if Rem.isPlayerObj(enemy) then
            engage = Rem.Awareness.CFG.CHASE_MAX -- perseguindo voce (Rem_Awareness ja decide quando desistir)
        elseif not isZombie then
            engage = B.CFG.HOSTILE_SIGHT -- pessoas hostis: vai atras
        elseif rec.stealth and not Rem.isAware(enemy, npc) then
            engage = B.CFG.STEALTH_ENGAGE
        end
        if d <= engage then
            if isZombie then Rem.bark(npc, "spot") end
            local gait = rec.stealth and "sneak" or (d > 4 and "run" or "walk")
            Rem.moveTo(npc, enemy:getX(), enemy:getY(), enemy:getZ(), now, gait)
            return
        end
    end

    -- 4. ordens do jogador, rotina do grupo, passeio... (comportamentos registrados)
    local ctx = { enemy = enemy, dist = d, temper = temper, player = player }
    Rem.runBehaviors(npc, ctx, now)
end

local function footsteps(npc, now)
    if npc.running and Rem.isMoving(npc) and now >= (npc.nextNoise or 0) then
        npc.nextNoise = now + B.CFG.RUN_NOISE_MS
        Rem.makeNoise(npc, B.CFG.RUN_NOISE_RADIUS)
    end
end

-- ---------------------------------------------------------------- loop principal
-- true = ok; "wait" = acabou de nascer e ainda nao esta num quadrado; false = sumiu.
-- Nos primeiros frames apos addZombiesInOutfit o corpo pode estar sem quadrado; antes
-- isso era lido como "chunk descarregou" e o corpo era re-ativado (aparencia/arma de novo).
local function isValid(zombie, npc, now)
    if zombie:isDead() or zombie:getPersistentOutfitID() ~= npc.rec.pid then return false end
    if not zombie:isExistInTheWorld() or zombie:getCurrentSquare() == nil then
        if now - (npc.activatedAt or 0) < B.CFG.SPAWN_SETTLE_MS then return "wait" end
        return false
    end
    return true
end

local function onTick()
    if not Rem.isAuthority() then return end
    local now = Rem.nowMs()
    Rem.updateZombieAttacks(now)
    if Rem.activeCount == 0 then return end
    local gone = nil
    for zombie, npc in pairs(Rem.active) do
        local valid = isValid(zombie, npc, now)
        if not valid then
            gone = gone or {}
            table.insert(gone, zombie)
        elseif valid == true then
            Rem.updateAttack(npc, now)
            Rem.updateHitReact(npc, now)
            if now >= npc.nextThink then
                npc.nextThink = now + B.CFG.THINK_MS
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
