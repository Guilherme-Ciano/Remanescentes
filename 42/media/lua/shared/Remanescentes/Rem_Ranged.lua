-- Remanescentes - tiro dos atiradores (Fase B2: disciplina de tiro).
--
-- Quem tem arma de fogo e municao (rec.firearm, rec.ammo; ver Rem_Profile):
--   * municao e finita e real: comeca com pouca (3-12) e so repoe com caixas de municao
--     do estoque da casa do grupo (nao regenera);
--   * em voce: antes do primeiro tiro AVISA ("Parado!") e mira por alguns segundos,
--     dando tempo de fugir, se esconder ou obedecer; alcance menor (pistola 10 tiles,
--     rifle 16) e ainda menor no escuro;
--   * precisao: arma + arquetipo (atirador e treinado, os outros nao) - distancia
--     - escuridao - alvo correndo - atirador acabou de andar + dificuldade;
--   * nao atira com aliado na linha de tiro;
--   * o tiro faz barulho de verdade e ATRAI ZUMBIS: amigos so atiram em zumbi quando
--     vale (cercados, feridos, voce ja brigando); hostis nao atiram em voce com muitos
--     zumbis por perto (a menos que estejam feridos);
--   * pente: depois de alguns tiros, recarrega (pausa);
--   * no maximo 2 do mesmo grupo atirando em voce ao mesmo tempo;
--   * mantem distancia: inimigo perto demais -> recua; colado -> faca;
--   * sem municao: guarda a arma e luta com a faca.
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_Barks"
require "Remanescentes/Rem_Perception"
require "Remanescentes/Rem_Combat"
require "Remanescentes/Rem_Movement"
require "Remanescentes/Rem_Brain"
require "Remanescentes/Rem_Spatial"
local Rem = Remanescentes

local RG = Rem.module("Ranged", {
    MIN_RANGE = 3.0,          -- mais perto que isso: recua (ou faca, se colado)
    MAX_RANGE = 14,           -- nunca atira mais longe que isso (mesmo com rifle)
    PLAYER_RANGE = { handgun = 10, rifle = 16 },   -- alcance contra voce
    NIGHT_RANGE = 0.6,        -- no escuro, o alcance contra voce cai para isso
    AIM_MS = 600,
    WARN_MS = 2500,           -- aviso + mira antes do primeiro tiro em voce
    WARN_MEMORY_MS = 60000,   -- avisou ha menos que isso: nao avisa de novo
    SHOT_ANIM_MS = 450,
    HIT_BONUS = 10,           -- somado a chance de acerto da arma, a queima-roupa
    HIT_PER_TILE = 3,         -- perde isso de chance por tile de distancia
    TRAINED_BONUS = 5,        -- arquetipo atirador
    UNTRAINED_PENALTY = 15,   -- os outros
    NIGHT_PENALTY = 20,
    RUNNING_PENALTY = 15,     -- alvo correndo
    MOVED_PENALTY = 10,       -- atirador andou ha pouco
    MIN_HIT = 5, MAX_HIT = 80,
    MAG = { handgun = 8, rifle = 4 },
    RELOAD_MS = 2500,
    MAX_SHOOTERS_AT_PLAYER = 2,
    ZOMBIE_NOISE_RADIUS = 15, -- zumbis contados antes de atirar
    ZOMBIE_NOISE_LIMIT = 4,   -- hostil nao atira em voce com tantos zumbis em volta...
    DESPERATE_BELOW = 0.5,    -- ...a menos que esteja com menos vida que isso
    LINE_OF_FIRE = 0.9,       -- amigo a essa distancia da linha de tiro: nao atira
    ROUNDS_PER_BOX = 15,
    RESTOCK_BELOW = 6,
    HOLSTER_MS = 5000,        -- sem inimigo por esse tempo: guarda a arma
    AIM_TIMEOUT_MS = 700,     -- sem pensar em atirar por esse tempo: baixa a mira
    BACKOFF_DIST = 3,
    FRIENDLY_CROWD = 2,       -- amigos so atiram em zumbi com pelo menos esses em volta
    AMMO_MAX = 30,
})
local CFG = RG.CFG

-- armas conhecidas (valores do weapon.txt do jogo)
RG.GUNS = {
    -- ammo: caixa que repoe a municao desta arma
    ["Base.Pistol"]       = { ammo = "Base.Bullets9mmBox", kind = "handgun", sound = "M9Shoot", radius = 100, range = 15, hit = 50, min = 0.6, max = 1.0, pellets = 1, cd = 1300 },
    ["Base.Pistol2"]      = { ammo = "Base.Bullets9mmBox", kind = "handgun", sound = "M9Shoot", radius = 100, range = 15, hit = 50, min = 0.7, max = 1.1, pellets = 1, cd = 1300 },
    ["Base.Shotgun"]      = { ammo = "Base.ShotgunShellsBox", kind = "rifle", sound = "JS2000ShotgunShoot", radius = 200, range = 10, hit = 65, min = 1.5, max = 2.2, pellets = 3, cd = 2000 },
    ["Base.HuntingRifle"] = { ammo = "Base.308Bullets", kind = "rifle", sound = "MSR788Shoot", radius = 170, range = 20, hit = 60, min = 1.2, max = 2.0, pellets = 1, cd = 2400 },
    ["Base.VarmintRifle"] = { ammo = "Base.223Bullets", kind = "rifle", sound = "MSR788Shoot", radius = 150, range = 20, hit = 60, min = 1.0, max = 1.6, pellets = 1, cd = 2200 },
}

Rem.BARKS.noammo = { urgent = true, n = 3, cd = 30000 }
Rem.BARKS.aim_warn = { urgent = true, n = 4, cd = 8000 }
Rem.BARKS.reload = { n = 3, cd = 15000 }

local function gunOf(rec) return rec.firearm and RG.GUNS[rec.firearm] end

function RG.canShoot(npc)
    return gunOf(npc.rec) ~= nil and (npc.rec.ammo or 0) > 0
end

-- Troca a arma na mao: arma de fogo (true) ou a arma branca (false).
function RG.equip(npc, gun)
    local rec = npc.rec
    if gun and not npc.gunOut then
        local g = gunOf(rec)
        Rem.safe(function() npc.z:setPrimaryHandItem(instanceItem(rec.firearm)) end)
        npc.z:setVariable("RemGun", g.kind)
        npc.gunOut = true
    elseif not gun and npc.gunOut then
        Rem.safe(function() npc.z:setPrimaryHandItem(rec.item and instanceItem(rec.item) or nil) end)
        npc.z:setVariable("RemGun", "")
        npc.z:setVariable("RemAim", false)
        npc.gunOut = false
        npc.aiming, npc.aimedAt = false, nil
    end
end

local function setAim(npc, on, now)
    if npc.aiming ~= on then
        npc.aiming = on
        npc.z:setVariable("RemAim", on)
        if not on then npc.aimedAt = nil end
    end
    if on then npc.lastAimThink = now end
end

local function canSee(npc, target)
    return Rem.Awareness.lineOfSight(npc, target)   -- erro = nao ve
end

-- Vale o barulho? Hostis e pessoas: sempre. Amigos contra zumbis: so se apertado.
function RG.worthTheNoise(npc, enemy, now)
    local desperate = Rem.healthFraction(npc) < CFG.DESPERATE_BELOW
    if Rem.isPlayerObj(enemy) then
        -- atirar em voce com zumbis em volta atrai a horda: so desesperado
        return desperate or RG.zombiesAround(npc, CFG.ZOMBIE_NOISE_RADIUS) < CFG.ZOMBIE_NOISE_LIMIT
    end
    local isZombie = not Rem.active[enemy]
    if not isZombie then return true end            -- outra pessoa armada/hostil
    if Rem.isHostileToPlayer(npc) then
        return desperate or (npc.crowd or 0) >= CFG.FRIENDLY_CROWD
    end
    if (npc.crowd or 0) >= CFG.FRIENDLY_CROWD then return true end
    if desperate then return true end
    return Rem.playerFighting(now)
end

-- ---------------------------------------------------------------- disparo
local function isNight()
    return Rem.Awareness.light() < 0.5
end

local function targetRunning(target)
    local run = false
    pcall(function() run = target:isRunning() or target:isSprinting() end)
    if not run and Rem.active[target] then run = Rem.active[target].running == true end
    return run
end

function RG.hitChance(npc, g, target, d, now)
    local c = g.hit + CFG.HIT_BONUS - d * CFG.HIT_PER_TILE
    c = c + ((npc.rec.archetype == "atirador") and CFG.TRAINED_BONUS or -CFG.UNTRAINED_PENALTY)
    if isNight() then c = c - CFG.NIGHT_PENALTY end
    if targetRunning(target) then c = c - CFG.RUNNING_PENALTY end
    if now - (npc.movedAt or -99999) < 1000 then c = c - CFG.MOVED_PENALTY end
    c = c + Rem.difficulty().acc
    -- experiencia (Rem_Bonds): quem ja lutou muito atira melhor; nunca contra voce
    if Rem.Bonds and not Rem.isPlayerObj(target) then c = c + Rem.Bonds.accuracyBonus(npc) end
    if Rem.Needs then c = c - Rem.Needs.accuracyPenalty(npc.rec) end
    return math.max(CFG.MIN_HIT, math.min(CFG.MAX_HIT, c))
end

-- Ha um amigo do atirador perto da linha de tiro (entre ele e o alvo)?
function RG.friendInLine(npc, target)
    local ax, ay = npc.z:getX(), npc.z:getY()
    local bx, by = target:getX(), target:getY()
    local vx, vy = bx - ax, by - ay
    local len2 = vx * vx + vy * vy
    if len2 < 0.01 then return false end
    local function blocks(x, y)
        local t = ((x - ax) * vx + (y - ay) * vy) / len2
        if t <= 0.05 or t >= 0.95 then return false end
        local px, py = ax + vx * t, ay + vy * t
        return Rem.dist2(x, y, px, py) < CFG.LINE_OF_FIRE
    end
    for zb, other in pairs(Rem.active) do
        if other ~= npc and zb ~= target and not Rem.npcsHostile(npc, other) and blocks(zb:getX(), zb:getY()) then
            return true
        end
    end
    if Rem.isFriendly(npc) then
        local p = getPlayer()
        if p and p ~= target and blocks(p:getX(), p:getY()) then return true end
    end
    return false
end

function RG.zombiesAround(npc, r)
    local n = 0
    local list = Rem.zombiesNear(npc.z:getX(), npc.z:getY(), r)
    for i = 1, #list do
        if not Rem.active[list[i]] then n = n + 1 end
    end
    return n
end

-- Quantos do mesmo grupo (ou faccao, se sem grupo) estao atirando no jogador agora.
local function shootersAtPlayer(npc, now)
    local n = 0
    for _, other in pairs(Rem.active) do
        if other ~= npc and other.shootingPlayerAt and now - other.shootingPlayerAt < 3000
            and ((npc.rec.groupId and other.rec.groupId == npc.rec.groupId) or
                 (not npc.rec.groupId and other.rec.faction == npc.rec.faction)) then
            n = n + 1
        end
    end
    return n
end

-- Ferimento a bala no jogador (bala alojada, sangra), sem infeccao de zumbi.
function RG.shootPlayer(player, dmg, npc)
    return Rem.woundPlayer(player, dmg, npc, "bullet")
end

local function hitZombie(npc, target, dmg, now)
    Rem.safe(function() target:splatBloodFloor() end)
    local hp = target:getHealth() - dmg
    if hp <= 0 then
        target:setHealth(0)
        Rem.safe(function() target:Kill(nil) end)
        Rem.bark(npc, "kill")
        Rem.emit("npcKilledZombie", npc, target)
        Rem.debug((npc.rec.name or "?") .. " matou um zumbi a tiro")
    else
        target:setHealth(hp)
        Rem.startHunt(target, npc, now)
        if ZombRand(100) < 50 then target:setStaggerBack(true) end
    end
end

function RG.shoot(npc, target, d, now)
    if not Rem.canAct(npc) then return 0 end
    local rec = npc.rec
    local g = gunOf(rec)
    rec.ammo = (rec.ammo or 0) - 1
    npc.shootUntil = now + CFG.SHOT_ANIM_MS
    npc.nextShot = now + g.cd
    npc.magShots = (npc.magShots or 0) + 1
    if npc.magShots >= (CFG.MAG[g.kind] or 6) and rec.ammo > 0 then
        npc.magShots = 0
        npc.nextShot = now + g.cd + CFG.RELOAD_MS     -- recarregando
        Rem.bark(npc, "reload")
    end
    if Rem.isPlayerObj(target) then npc.shootingPlayerAt = now end
    npc.z:setVariable("RemShoot", true)
    Rem.safe(function() npc.z:playSound(g.sound) end)
    Rem.makeNoise(npc, g.radius)

    local chance = RG.hitChance(npc, g, target, d, now)
    local hits = 0
    for _ = 1, g.pellets do
        if ZombRand(100) < chance then hits = hits + 1 end
    end
    if hits > 0 then
        local dmg = ZombRandFloat(g.min, g.max) * (hits / g.pellets) * (g.pellets > 1 and 1.5 or 1)
        dmg = dmg * Rem.cfg("NPCDamageMultiplier", 1.0)
        if Rem.isPlayerObj(target) then
            RG.shootPlayer(target, dmg, npc)
        elseif Rem.active[target] then
            local other = Rem.active[target]
            Rem.hitReact(other, now)
            Rem.damageNPC(other, dmg, npc)
            if not Rem.active[target] then Rem.bark(npc, "kill") end
        else
            hitZombie(npc, target, dmg, now)
        end
    end
    if rec.ammo <= 0 then
        rec.ammo = 0
        Rem.bark(npc, "noammo", true)
        RG.equip(npc, false)
    end
    return hits
end

-- Chamado pelo cerebro antes do corpo a corpo. true = cuidou deste "pensamento".
function Rem.tryRanged(npc, enemy, d, now)
    if npc.rec.stance == "hold" or npc.rec.prisoner then   -- segurar fogo (Rem_Orders), preso
        if npc.gunOut then RG.equip(npc, false) end
        return false
    end
    if not RG.canShoot(npc) then
        if npc.gunOut then RG.equip(npc, false) end
        return false
    end
    local g = gunOf(npc.rec)
    local atPlayer = Rem.isPlayerObj(enemy)
    local range = math.min(g.range, CFG.MAX_RANGE)
    if atPlayer then
        range = math.min(range, CFG.PLAYER_RANGE[g.kind] or 10)
        if isNight() then range = range * CFG.NIGHT_RANGE end
    end
    if d > range or not RG.worthTheNoise(npc, enemy, now) or not canSee(npc, enemy)
        or RG.friendInLine(npc, enemy)
        or (atPlayer and shootersAtPlayer(npc, now) >= CFG.MAX_SHOOTERS_AT_PLAYER) then
        setAim(npc, false, now)
        return false
    end
    if d < CFG.MIN_RANGE then
        setAim(npc, false, now)
        if d <= Rem.reach(npc) then
            RG.equip(npc, false)   -- colado: faca
            return false
        end
        -- recua para ganhar distancia
        local z = npc.z
        local dx, dy = z:getX() - enemy:getX(), z:getY() - enemy:getY()
        local len = math.max(0.01, math.sqrt(dx * dx + dy * dy))
        Rem.moveTo(npc, z:getX() + dx / len * CFG.BACKOFF_DIST, z:getY() + dy / len * CFG.BACKOFF_DIST, z:getZ(), now, "walk")
        npc.movedAt = now
        return true
    end
    RG.equip(npc, true)
    if Rem.isMoving(npc) then npc.movedAt = now end
    Rem.stopMoving(npc)
    npc.z:faceThisObject(enemy)
    setAim(npc, true, now)
    npc.lastGunUse = now
    if atPlayer then npc.shootingPlayerAt = now end
    -- primeiro tiro em voce: avisa e mira um tempo antes
    if atPlayer and now - (npc.warnedAt or -CFG.WARN_MEMORY_MS) >= CFG.WARN_MEMORY_MS then
        npc.warnedAt = now
        npc.aimedAt = now + CFG.WARN_MS
        Rem.bark(npc, "aim_warn", true)
        return true
    end
    if not npc.aimedAt then npc.aimedAt = now + CFG.AIM_MS end
    if now < npc.aimedAt or now < (npc.nextShot or 0) then return true end
    RG.shoot(npc, enemy, d, now)
    return true
end

-- ---------------------------------------------------------------- todo tick
local function update(now)
    for _, npc in pairs(Rem.active) do
        if npc.shootUntil and now >= npc.shootUntil then
            npc.shootUntil = nil
            npc.z:setVariable("RemShoot", false)
        end
        if npc.aiming and now - (npc.lastAimThink or 0) > CFG.AIM_TIMEOUT_MS then
            setAim(npc, false, now)
        end
        if npc.gunOut and now - (npc.lastGunUse or 0) > CFG.HOLSTER_MS then
            RG.equip(npc, false)
        end
    end
end

Events.OnTick.Add(function()
    if not Rem.isAuthority() or Rem.activeCount == 0 then return end
    Rem.safe(update, Rem.nowMs())
end)

-- Municao: so repoe com caixas do estoque da casa (nada de regenerar).
function RG.restock(npc)
    local rec = npc.rec
    local g = gunOf(rec)
    if not g or (rec.ammo or 0) >= CFG.RESTOCK_BELOW then return false end
    local grp = rec.groupId and Rem.getStore().groups[rec.groupId]
    if not grp or grp.activity ~= "home" or not grp.home or not Rem.Safehouse then return false end
    local h = grp.home
    if Rem.dist2(npc.z:getX(), npc.z:getY(), h.x, h.y) > math.max(4, (h.x2 and (h.x2 - h.x1)) or 0) then return false end
    local conts = Rem.Safehouse.stashContainers(h)
    if not conts then return false end
    for _, c in ipairs(conts) do
        local items = c:getItems()
        for i = items:size() - 1, 0, -1 do
            local it = items:get(i)
            if it:getFullType() == g.ammo then
                c:DoRemoveItem(it)
                rec.ammo = math.min(CFG.AMMO_MAX, (rec.ammo or 0) + CFG.ROUNDS_PER_BOX)
                h.syncCount = math.max(0, (h.syncCount or 1) - 1)
                h.stashCount = math.max(0, (h.stashCount or 1) - 1)
                Rem.debug(tostring(rec.name) .. " pegou municao no estoque (" .. rec.ammo .. ")")
                return true
            end
        end
    end
    return false
end

Rem.on("sceneUpdate", function()
    for _, npc in pairs(Rem.active) do
        if npc.rec.firearm then Rem.safe(RG.restock, npc) end
    end
end)
