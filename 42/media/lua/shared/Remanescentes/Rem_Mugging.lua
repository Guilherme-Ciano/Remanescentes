-- Remanescentes - Fase B3: saqueadores com objetivo (assalto), moral e rendicao.
--
-- Um saqueador quer o que voce tem, nao necessariamente te matar. Quando o grupo te
-- reconhece (evento "spottedPlayer"):
--   demand : o lider exige ("Larga a mochila e a arma!"). Eles cercam a 3-5 tiles e NAO
--            atacam por DEMAND_MS. Saidas:
--              obedecer: ficar sem arma na mao e sem mochila nas costas -> "Isso, some."
--                        -> tregua; eles pegam o que voce largou no chao e vao embora;
--              ir embora: abrir distancia (LEAVE_DIST) -> deixam voce ir (tregua);
--              reagir: bater em qualquer um deles -> briga;
--              enrolar: o prazo acaba com voce ainda perto -> briga.
--   fight  : combate normal (percepcao, coleira, tiro disciplinado continuam valendo).
--   rout   : o lider caiu ou metade do grupo morreu -> os outros fogem de voce. Quem
--            estiver muito ferido e perto de voce se RENDE (senta, "Nao atira!") e fica
--            ali ate voce se afastar; depois vai embora.
--   truce  : por TRUCE_MS o grupo ignora voce.
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_Factions"
require "Remanescentes/Rem_Barks"
require "Remanescentes/Rem_Movement"
require "Remanescentes/Rem_Combat"
require "Remanescentes/Rem_Awareness"
local Rem = Remanescentes

local MG = Rem.module("Mugging", {
    DEMAND_MS = 15000,
    DEMAND_NEAR = 3,          -- fica a pelo menos isso
    DEMAND_FAR = 5,           -- e no maximo isso de voce
    LEAVE_DIST = 18,          -- voce se afastou isso do lider: deixam ir
    TRUCE_MS = 300000,        -- 5 min de tregua
    ROUT_MS = 60000,
    SURRENDER_BELOW = 0.3,    -- vida abaixo disso (fugindo) e voce perto: se rende
    SURRENDER_DIST = 4,
    SURRENDER_RELEASE = 15,   -- voce se afastou isso: o rendido levanta e vai embora
    COLLECT_RADIUS = 1,
    PRIORITY = 40,            -- antes de investigar (50) e de tudo mais
    FACTIONS = { saqueadores = true },
})
local CFG = MG.CFG

Rem.BARKS.demand = { urgent = true, n = 4, cd = 0 }
Rem.BARKS.let_go = { urgent = true, n = 3, cd = 0 }
Rem.BARKS.retreat = { urgent = true, n = 3, cd = 10000 }
Rem.BARKS.surrender = { urgent = true, n = 3, cd = 20000 }

MG.enc = MG.enc or {}   -- [chave do grupo] = encontro (runtime)

local function keyOf(rec)
    return rec.groupId or ("solo:" .. tostring(rec.id))
end

function MG.of(npc)
    return MG.enc[keyOf(npc.rec)]
end

local function membersOnScene(key)
    local list = {}
    for _, npc in pairs(Rem.active) do
        if keyOf(npc.rec) == key then table.insert(list, npc) end
    end
    return list
end

local function setStage(E, stage, now)
    E.stage = stage
    E.stageAt = now
end

-- ---------------------------------------------------------------- inicio
function MG.start(npc, now)
    if not Rem.cfg("RaiderMugging", true) or not CFG.FACTIONS[npc.rec.faction] then return nil end
    local key = keyOf(npc.rec)
    local E = MG.enc[key]
    if E and (E.stage ~= "truce" or now < (E.truceUntil or 0)) then return E end
    local members = membersOnScene(key)
    E = { key = key, leader = npc, startedAt = now, untilMs = now + CFG.DEMAND_MS,
          members0 = math.max(1, #members), dead = 0 }
    setStage(E, "demand", now)
    MG.enc[key] = E
    Rem.bark(npc, "demand", true)
    Rem.debug("assalto: " .. key .. " (" .. E.members0 .. ")")
    return E
end

Rem.on("spottedPlayer", function(npc, now) MG.start(npc, now) end)

-- ---------------------------------------------------------------- consultas
function MG.ignoresPlayer(npc, now)
    if npc.rec.surrendered then return true end
    local E = MG.of(npc)
    return E ~= nil and E.stage == "truce" and now < (E.truceUntil or 0)
end

local function playerObeyed(player)
    local weapon, bag = nil, nil
    pcall(function() weapon = player:getPrimaryHandItem() end)
    pcall(function() bag = player:getClothingItem_Back() end)
    return weapon == nil and bag == nil
end

local function truce(E, now, player, collect)
    setStage(E, "truce", now)
    E.truceUntil = now + CFG.TRUCE_MS
    if collect and player then E.dropX, E.dropY, E.dropZ = player:getX(), player:getY(), player:getZ() end
    for _, m in ipairs(membersOnScene(E.key)) do Rem.Awareness.giveUp(m, now, true) end
    if E.leader and Rem.active[E.leader.z] then Rem.bark(E.leader, "let_go", true) end
end

function MG.rout(E, now)
    if E.stage == "rout" then return end
    setStage(E, "rout", now)
    E.routUntil = now + CFG.ROUT_MS
    local members = membersOnScene(E.key)
    if members[1] then Rem.bark(members[1], "retreat", true) end
    Rem.debug("assalto: " .. E.key .. " fugindo")
end

-- ---------------------------------------------------------------- no cerebro
-- Chamado pelo cerebro quando o inimigo atual e o jogador. true = cuidou do pensamento.
function MG.handle(npc, player, d, now)
    local E = MG.of(npc)
    if not E then return false end

    if E.stage == "demand" then
        local leader = (E.leader and Rem.active[E.leader.z]) and E.leader or npc
        local ld = Rem.dist(leader.z, player)
        if playerObeyed(player) then
            truce(E, now, player, true)
            return true
        end
        if ld > CFG.LEAVE_DIST then
            truce(E, now, player, false)
            return true
        end
        if now > E.untilMs then
            setStage(E, "fight", now)
            Rem.bark(leader, "angry", true)
            return false
        end
        -- cerca a 3-5 tiles, sem atacar
        if d > CFG.DEMAND_FAR then
            Rem.moveTo(npc, player:getX(), player:getY(), player:getZ(), now, "walk")
        elseif d < CFG.DEMAND_NEAR then
            -- voce chegou perto demais: ele recua um passo e mantem a distancia
            local dx, dy = npc.z:getX() - player:getX(), npc.z:getY() - player:getY()
            local len = math.max(0.01, math.sqrt(dx * dx + dy * dy))
            Rem.moveTo(npc, npc.z:getX() + dx / len * 1.5, npc.z:getY() + dy / len * 1.5, npc.z:getZ(), now, "walk")
            npc.z:faceThisObject(player)
        else
            Rem.stopMoving(npc)
            npc.z:faceThisObject(player)
        end
        return true
    end

    if E.stage == "rout" then
        if now > (E.routUntil or 0) then
            truce(E, now, nil, false)
            return true
        end
        if Rem.healthFraction(npc) < CFG.SURRENDER_BELOW and d <= CFG.SURRENDER_DIST then
            MG.surrender(npc, now)
            return true
        end
        Rem.flee(npc, player, now)
        return true
    end
    return false
end

-- ---------------------------------------------------------------- rendicao
function MG.surrender(npc, now)
    local rec = npc.rec
    if rec.surrendered then return end
    rec.surrendered = true
    rec.hostileToPlayer = false
    Rem.cancelAttack(npc)
    Rem.stopMoving(npc)
    Rem.setRest(npc, "sit")
    Rem.applyFriendlyFire(npc)
    Rem.bark(npc, "surrender", true)
    Rem.debug(tostring(rec.name) .. " se rendeu")
end

-- Rendido fica sentado ate voce se afastar; depois levanta e vai para casa.
function MG.surrenderedBehavior(npc, ctx, now)
    local rec = npc.rec
    if not rec.surrendered then return false end
    local player = ctx.player
    if player and Rem.dist(npc.z, player) < CFG.SURRENDER_RELEASE then
        Rem.setRest(npc, "sit")
        return true
    end
    rec.surrendered = nil
    Rem.clearRest(npc)
    local E = MG.enc[keyOf(rec)]
    if E then truce(E, now, nil, false) end
    return false
end

-- ---------------------------------------------------------------- pegar o que voce largou
local function collectAt(npc, E)
    local cell = getCell()
    local took = 0
    local r = CFG.COLLECT_RADIUS
    for dx = -r, r do
        for dy = -r, r do
            local sq = cell:getGridSquare(math.floor(E.dropX) + dx, math.floor(E.dropY) + dy, math.floor(E.dropZ or 0))
            if sq then
                local objs = sq:getWorldObjects()
                for i = objs:size() - 1, 0, -1 do
                    local wo = objs:get(i)
                    local item = wo:getItem()
                    if item then
                        npc.rec.carry = npc.rec.carry or {}
                        table.insert(npc.rec.carry, item:getFullType())
                        sq:removeWorldObject(wo)
                        took = took + 1
                    end
                end
            end
        end
    end
    return took
end

function MG.collectBehavior(npc, ctx, now)
    local E = MG.of(npc)
    if not E or E.stage ~= "truce" or not E.dropX then return false end
    local d = Rem.dist2(npc.z:getX(), npc.z:getY(), E.dropX, E.dropY)
    if d > 1.4 then
        Rem.moveTo(npc, E.dropX, E.dropY, E.dropZ or 0, now, "walk")
        return true
    end
    Rem.stopMoving(npc)
    Rem.safe(collectAt, npc, E)
    E.dropX = nil   -- pegaram o que tinha; vao embora
    return true
end

-- ---------------------------------------------------------------- eventos
-- Voce bateu num deles durante a exigencia: briga.
Events.OnHitZombie.Add(function(zombie, attacker)
    local npc = Rem.active[zombie]
    if not npc or not Rem.isPlayerObj(attacker) then return end
    local E = MG.of(npc)
    if E and (E.stage == "demand" or E.stage == "truce") then
        setStage(E, "fight", Rem.nowMs())
        npc.rec.surrendered = nil
        Rem.bark(npc, "angry", true)
    end
end)

-- Moral: lider caiu ou metade morreu -> fogem.
Rem.on("npcDied", function(npc)
    local E = MG.of(npc)
    if not E or E.stage == "truce" then return end
    E.dead = E.dead + 1
    local now = Rem.nowMs()
    if npc == E.leader or E.dead >= math.ceil(E.members0 / 2) then MG.rout(E, now) end
end)

-- encontros vencidos somem
Events.EveryOneMinute.Add(function()
    local now = Rem.nowMs()
    for key, E in pairs(MG.enc) do
        if E.stage == "truce" and now >= (E.truceUntil or 0) and not E.dropX then MG.enc[key] = nil end
    end
end)

Rem.registerBehavior({ name = "surrendered", priority = CFG.PRIORITY - 5, run = MG.surrenderedBehavior })
Rem.registerBehavior({ name = "mug_collect", priority = CFG.PRIORITY, run = MG.collectBehavior })
