-- Remanescentes - revistar os corpos depois da briga.
--
-- Quando um hostil (saqueador, alguem que te atacou) morre perto de voce, quem segue voce
-- vai ate o corpo, revista (SEARCH_MS) e pega o que presta: municao da arma dele (vai
-- direto para o pente), armas, comida e remedio. Depois traz para voce (entra no seu
-- inventario). So quando a briga acabou (nenhum inimigo por perto) e nunca recuando.
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_Barks"
local Rem = Remanescentes

local SP = Rem.module("Spoils", {
    MAX_AGE_MS = 300000,      -- corpos mais velhos que isso: deixa para la
    NEAR_PLAYER = 25,         -- so corpos a essa distancia de voce
    REACH = 1.6,
    SEARCH_MS = 3500,
    GIVE_DIST = 2.5,
    PRIORITY = 98,            -- antes de seguir voce (100)
    KEEP = { Weapon = true, Ammo = true, Food = true, FirstAid = true },
})
local CFG = SP.CFG

Rem.BARKS.spoils_go = { urgent = true, n = 2, cd = 30000 }
Rem.BARKS.spoils_found = { urgent = true, n = 3, cd = 0 }
Rem.BARKS.spoils_none = { urgent = true, n = 2, cd = 0 }

SP.list = {}      -- { x, y, z, at, by, done }

local function isFollower(npc)
    local rec = npc.rec
    return rec.faction == "aliados" and not rec.groupId and not rec.prisoner and rec.mode == "follow"
end

-- Morreu um hostil: o corpo vale a pena revistar.
Rem.on("npcDied", function(npc)
    local rec = npc.rec
    if rec.faction == "aliados" or not Rem.isHostileToPlayer(npc) then return end
    local x, y, z = nil, nil, 0
    pcall(function() x, y, z = npc.z:getX(), npc.z:getY(), npc.z:getZ() end)
    if not x then return end
    table.insert(SP.list, { x = x, y = y, z = math.floor(z or 0), at = Rem.nowMs() })
end)

-- Corpos (IsoDeadBody) em volta do lugar.
function SP.bodies(spot)
    local out = {}
    local cell = getCell()
    for dx = -1, 1 do
        for dy = -1, 1 do
            local sq = cell:getGridSquare(math.floor(spot.x) + dx, math.floor(spot.y) + dy, spot.z or 0)
            local list = sq and sq:getDeadBodys()
            if list then for i = 0, list:size() - 1 do table.insert(out, list:get(i)) end end
        end
    end
    return out
end

local function category(item)
    local cat = ""
    pcall(function() cat = item:getDisplayCategory() or "" end)
    if cat == "" and instanceof(item, "HandWeapon") then cat = "Weapon" end
    return cat
end

-- Revista: municao da arma dele vai para o pente; o resto que presta vai para a mao.
-- Retorna quantos itens pegou.
function SP.loot(npc, spot)
    local rec = npc.rec
    local RG = Rem.Ranged
    local gun = rec.firearm and RG and RG.GUNS[rec.firearm]
    local max = Rem.Scavenge and Rem.Scavenge.CFG.CARRY_MAX or 6
    local took = 0
    rec.carry = rec.carry or {}
    for _, body in ipairs(SP.bodies(spot)) do
        local c = nil
        pcall(function() c = body:getContainer() end)
        if c then
            local items = c:getItems()
            for i = items:size() - 1, 0, -1 do
                local it = items:get(i)
                local ft = it:getFullType()
                if gun and ft == gun.ammo and (rec.ammo or 0) < RG.CFG.AMMO_MAX then
                    rec.ammo = math.min(RG.CFG.AMMO_MAX, (rec.ammo or 0) + RG.CFG.ROUNDS_PER_BOX)
                    c:DoRemoveItem(it)
                    took = took + 1
                elseif CFG.KEEP[category(it)] and #rec.carry < max then
                    table.insert(rec.carry, ft)
                    c:DoRemoveItem(it)
                    took = took + 1
                end
            end
        end
    end
    return took
end

-- O corpo mais perto para este seguidor (ou nil).
function SP.target(npc, player, now)
    local best, bestD = nil, nil
    for i = #SP.list, 1, -1 do
        local s = SP.list[i]
        if s.done or now - s.at > CFG.MAX_AGE_MS then
            table.remove(SP.list, i)
        elseif (not s.by or s.by == npc.rec.id)
            and Rem.dist2(player:getX(), player:getY(), s.x, s.y) <= CFG.NEAR_PLAYER then
            local d = Rem.distXY(npc.z, s.x, s.y)
            if not bestD or d < bestD then best, bestD = s, d end
        end
    end
    return best, bestD
end

function SP.behavior(npc, ctx, now)
    if not isFollower(npc) or ctx.enemy or npc.rec.stance == "retreat" then return false end
    local player = ctx.player
    if not player then return false end
    local rec = npc.rec
    -- entregar o que achou
    if npc.spoilsDeliver then
        if Rem.dist(npc.z, player) > CFG.GIVE_DIST then
            Rem.moveTo(npc, player:getX(), player:getY(), player:getZ(), now, Rem.travelGait(npc, Rem.dist(npc.z, player)))
            return true
        end
        npc.spoilsDeliver = nil
        if Rem.Interact then Rem.Interact.giveCarry(npc, player) end
        return true
    end
    local s, d = SP.target(npc, player, now)
    if not s then return false end
    if not s.by then
        s.by = rec.id
        Rem.bark(npc, "spoils_go")
    end
    if d > CFG.REACH then
        npc.spoilsUntil = nil
        Rem.moveTo(npc, s.x, s.y, s.z, now, Rem.travelGait(npc, d))
        return true
    end
    Rem.stopMoving(npc)
    Rem.safe(function() npc.z:faceLocationF(s.x, s.y) end)
    if not npc.spoilsUntil then npc.spoilsUntil = now + CFG.SEARCH_MS return true end
    if now < npc.spoilsUntil then return true end
    npc.spoilsUntil = nil
    s.done = true
    local ok, took = pcall(SP.loot, npc, s)
    took = ok and took or 0
    if took > 0 then
        Rem.bark(npc, "spoils_found", true)
        if rec.carry and #rec.carry > 0 then npc.spoilsDeliver = true end
    else
        Rem.bark(npc, "spoils_none", true)
    end
    return true
end
Rem.registerBehavior({ name = "spoils", priority = CFG.PRIORITY, run = SP.behavior })
