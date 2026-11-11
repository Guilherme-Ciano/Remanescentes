-- Remanescentes - papeis dos moradores e habilidades dos arquetipos (Fase 3).
--
-- Papeis (rec.role), sorteados quando o grupo nasce:
--   guarda     : fica na porta principal da casa, dia e noite
--   cozinheiro : de dia fica na cozinha (fogao/geladeira); a noite, dentro de casa
--   morador    : de dia anda pela casa/quintal; a noite fica num canto dentro de casa
--                (descansando; ainda sem animacao de deitar)
-- Arquetipos:
--   medico     : vai ate um companheiro ferido e cura (NPCs do grupo; se for seu aliado,
--                faz curativo nos seus ferimentos sangrando)
--   engenheiro : a casa do grupo dele e mais bem barricada (Rem_Safehouse)
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_Spawn"
require "Remanescentes/Rem_Brain"
require "Remanescentes/Rem_Barks"
require "Remanescentes/Rem_Perception"
require "Remanescentes/Rem_Profile"
require "Remanescentes/Rem_Safehouse"
local Rem = Remanescentes

Rem.Roles = Rem.Roles or {}
local RO = Rem.Roles

RO.CFG = {
    ROLE_PRIORITY = 240,        -- antes de "home_indoors" (250) e da rotina do grupo (300)
    MEDIC_PRIORITY = 90,        -- antes de seguir (100): o medico sai do lado do jogador para curar
    MEDIC_RADIUS = 15,
    MEDIC_TOUCH = 1.3,
    HEAL_BELOW = 0.6,           -- cura quem esta abaixo de 60% da vida
    HEAL_AMOUNT = 0.35,         -- fracao da vida maxima curada
    HEAL_CD_MS = 30000,
    PLAYER_HEAL_RADIUS = 2.0,
    SIT_ODDS = 40,              -- a cada "pensamento" parado de dia, 1 em N senta
    SIT_MIN_MS = 20000,
    SIT_MAX_MS = 60000,
}

Rem.BARKS.heal = { n = 3, cd = 20000 }

-- ---------------------------------------------------------------- papeis
function RO.assignRoles(g)
    local people = Rem.getStore().people
    local list = {}
    for _, id in ipairs(g.members) do
        local p = people[id]
        if p then table.insert(list, p) end
    end
    for i, p in ipairs(list) do
        if #list >= 2 and i == 1 then p.role = "guarda"
        elseif #list >= 3 and i == 2 then p.role = "cozinheiro"
        else p.role = "morador" end
    end
end

Rem.on("groupCreated", function(g) RO.assignRoles(g) end)

-- grupos de saves antigos ganham papeis na primeira vez que alguem aparece
Rem.on("npcActivated", function(npc)
    local rec = npc.rec
    if rec.role or not rec.groupId then return end
    local g = Rem.getStore().groups[rec.groupId]
    if g then RO.assignRoles(g) end
end)

local function isNight()
    local tod = getGameTime():getTimeOfDay()
    return tod >= Rem.Safehouse.CFG.NIGHT_START or tod < Rem.Safehouse.CFG.NIGHT_END
end

-- Procura (uma vez) um ponto da cozinha: quadrado interno com fogao/geladeira/balcao.
function RO.kitchenSpot(h)
    if h.kitchen ~= nil then return h.kitchen or nil end
    if not Rem.Safehouse.isLoaded(h) then return nil end
    local best, bestScore = false, 0
    Rem.Safehouse.forEachSquare(h, h.z or 0, function(sq)
        if sq:getRoom() then
            local objs = sq:getObjects()
            for i = 0, objs:size() - 1 do
                local o = objs:get(i)
                for c = 0, o:getContainerCount() - 1 do
                    local cont = o:getContainerByIndex(c)
                    local t = cont and cont:getType() or ""
                    local score = (t == "stove" and 3) or ((t == "fridge" or t == "microwave") and 2) or (t == "counter" and 1) or 0
                    if score > bestScore then
                        best, bestScore = { x = sq:getX(), y = sq:getY(), z = sq:getZ() }, score
                    end
                end
            end
        end
    end)
    h.kitchen = best
    return best or nil
end

-- Posto do guarda: o quadrado interno colado na porta principal (ou a propria porta).
function RO.guardSpot(h)
    if h.guardSpot then return h.guardSpot end
    local d = h.mainDoor
    local cell = getCell()
    for _, off in ipairs({ { 0, -1 }, { -1, 0 }, { 1, 0 }, { 0, 1 } }) do
        local sq = cell:getGridSquare(d.x + off[1], d.y + off[2], d.z or 0)
        if sq and sq:getRoom() and sq:isFree(false) then
            h.guardSpot = { x = d.x + off[1], y = d.y + off[2], z = d.z or 0 }
            return h.guardSpot
        end
    end
    return d
end

function RO.roleBehavior(npc, ctx, now)
    local rec = npc.rec
    if rec.mode ~= "group" or not rec.role then return false end
    local g = rec.groupId and Rem.getStore().groups[rec.groupId]
    if not g or g.activity ~= "home" or not g.home or not g.home.x1 then return false end
    local h = g.home
    if rec.role == "guarda" and h.mainDoor then
        local spot = RO.guardSpot(h)
        Rem.hangAround(npc, spot.x + 0.5, spot.y + 0.5, spot.z or 0, now, 0)
        return true
    end
    if rec.role == "cozinheiro" and not isNight() then
        local k = RO.kitchenSpot(h)
        if k then
            Rem.hangAround(npc, k.x + 0.5, k.y + 0.5, k.z, now, 1)
            return true
        end
    end
    -- morador de dia: de vez em quando senta para descansar um pouco
    if rec.role == "morador" and not isNight() then
        if npc.rest == "sit" and now < (npc.restUntil or 0) then return true end
        if npc.rest == "sit" then Rem.clearRest(npc) end
        if not Rem.isMoving(npc) and ZombRand(RO.CFG.SIT_ODDS) == 0 then
            npc.restUntil = now + ZombRand(RO.CFG.SIT_MIN_MS, RO.CFG.SIT_MAX_MS)
            Rem.setRest(npc, "sit")
            return true
        end
    end
    return false -- morador (e cozinheiro a noite): "home_indoors" / rotina do grupo
end

-- ---------------------------------------------------------------- medico
local function friendsOf(a, b)
    if a == b then return false end
    if a.rec.groupId and a.rec.groupId == b.rec.groupId then return true end
    return Rem.isFriendly(a) and Rem.isFriendly(b) and a.rec.faction == b.rec.faction
end

function RO.findPatient(npc)
    local best, bestD = nil, RO.CFG.MEDIC_RADIUS
    for _, other in pairs(Rem.active) do
        if friendsOf(npc, other) and not other.z:isDead() then
            local maxH = other.rec.maxHealth or 1
            if other.z:getHealth() < maxH * RO.CFG.HEAL_BELOW and not Rem.isHuntedBy(other, 1) then
                local d = Rem.dist(npc.z, other.z)
                if d < bestD then best, bestD = other, d end
            end
        end
    end
    return best, bestD
end

function RO.healNPC(medic, patient, now)
    local maxH = patient.rec.maxHealth or 1
    local h = math.min(maxH, patient.z:getHealth() + maxH * RO.CFG.HEAL_AMOUNT)
    patient.z:setHealth(h)
    patient.rec.hp = h
    medic.nextHeal = now + RO.CFG.HEAL_CD_MS
    medic.z:faceThisObject(patient.z)
    Rem.bark(medic, "heal", true)
    Rem.debug(medic.rec.name .. " curou " .. tostring(patient.rec.name))
end

-- Curativo no jogador: para o sangramento das partes feridas (como uma atadura).
function RO.healPlayer(medic, player, now)
    local bd = player:getBodyDamage()
    if not bd then return false end
    local parts = bd:getBodyParts()
    local done = 0
    for i = 0, parts:size() - 1 do
        local part = parts:get(i)
        if part:bleeding() and not part:bandaged() then
            part:setBandaged(true, 4.0)
            part:setBleeding(false)
            done = done + 1
        end
    end
    if done > 0 then
        medic.nextHeal = now + RO.CFG.HEAL_CD_MS
        Rem.bark(medic, "heal", true)
    end
    return done > 0
end

function RO.medicBehavior(npc, ctx, now)
    if (npc.rec.archetype ~= "medico" and npc.rec.job ~= "heal") or ctx.enemy then return false end
    if now < (npc.nextHeal or 0) then return false end
    -- seu aliado medico cuida de voce
    local player = ctx.player
    if player and npc.rec.faction == "aliados" and Rem.dist(npc.z, player) <= RO.CFG.PLAYER_HEAL_RADIUS then
        if RO.healPlayer(npc, player, now) then return true end
    end
    local patient, d = RO.findPatient(npc)
    if not patient then return false end
    if d <= RO.CFG.MEDIC_TOUCH then
        Rem.stopMoving(npc)
        RO.healNPC(npc, patient, now)
    else
        Rem.moveTo(npc, patient.z:getX(), patient.z:getY(), patient.z:getZ(), now, Rem.travelGait(npc, d))
    end
    return true
end

-- ---------------------------------------------------------------- ganchos
Rem.registerBehavior({ name = "medic", priority = RO.CFG.MEDIC_PRIORITY, run = RO.medicBehavior })
Rem.registerBehavior({ name = "role", priority = RO.CFG.ROLE_PRIORITY, run = RO.roleBehavior })
