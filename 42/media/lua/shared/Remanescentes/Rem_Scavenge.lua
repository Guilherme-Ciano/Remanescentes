-- Remanescentes - saque de verdade e estoque vivo da safehouse.
--
-- Em cena (perto do jogador):
--   * quando o grupo sai para saquear, o guarda fica em casa (grupos de 2+); os outros vao
--     ate o predio-alvo, entram, abrem armarios de verdade (o loot e gerado como quando o
--     jogador abre: ItemPicker.fillContainer), pegam comida/agua/remedio/municao primeiro,
--     e carregam (rec.carry, salvo no save);
--   * na volta, guardam o que trouxeram nos conteineres do estoque de casa. Cada 2 itens
--     viram 1 "pessoa-dia" de suprimento do grupo.
-- Fora de cena: a simulacao (Rem_World) da um ganho abstrato e guarda g.pendingItems; esses
--   itens aparecem no estoque quando a casa carregar.
-- Estoque vivo (casa carregada e jogador por perto):
--   * o grupo come: itens alem do que os suprimentos justificam somem (comida primeiro);
--   * itens que sumiram sem ser consumo (voce pegou) baixam os suprimentos do grupo.
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_World"
require "Remanescentes/Rem_Brain"
require "Remanescentes/Rem_Barks"
require "Remanescentes/Rem_Safehouse"
require "Remanescentes/Rem_Roles"
local Rem = Remanescentes

local SC = Rem.module("Scavenge", {
    PRIORITY = 290,          -- antes da rotina do grupo (300)
    DEPOSIT_PRIORITY = 80,   -- guardar o saque vem antes de curar, seguir, descansar
    NEAR_TARGET = 14,        -- a essa distancia do predio-alvo comeca a procurar armarios
    TOUCH = 1.6,
    STUCK_MS = 12000,        -- tempo tentando chegar num armario antes de desistir dele
    SEARCH_MS = 2500,        -- tempo revirando cada armario
    TAKE_PER_VISIT = 3,
    CARRY_MAX = 8,
    DEPOSIT_DIST = 3,        -- deposita ao chegar a essa distancia da casa
    SYNC_MS = 5000,
    STASH_MAX = 30,
    CONSUME_SLACK = 2,       -- tolerancia antes de "comer" itens do estoque
})
local CFG = SC.CFG

Rem.BARKS.loot_found = { n = 3, cd = 20000 }
Rem.BARKS.loot_home = { n = 3, cd = 60000 }

local function ips() return Rem.World.CFG.ITEMS_PER_SUPPLY end

-- ---------------------------------------------------------------- valor dos itens
-- O que um grupo procura primeiro: comida, agua, remedio, municao. Depois coisas leves.
function SC.itemScore(item)
    local ok, food = pcall(function() return item:isFood() end)
    if ok and food then return 3 end
    local dc = ""
    pcall(function() dc = item:getDisplayCategory() or "" end)
    if dc == "Food" or dc == "Water" or dc == "FirstAid" or dc == "Ammo" then return 3 end
    if dc == "Weapon" or dc == "WeaponCrafted" or dc == "Tool" then return 1.5 end
    local w = 99
    pcall(function() w = item:getActualWeight() end)
    if w <= 1.5 then return 0.5 end
    return 0
end

-- ---------------------------------------------------------------- utilidades
local function groupOf(rec)
    return rec.groupId and Rem.getStore().groups[rec.groupId]
end

local function carryCount(rec)
    return rec.carry and #rec.carry or 0
end

local function sqKey(sq) return sq:getX() .. "," .. sq:getY() .. "," .. sq:getZ() end

-- Proximo armario ainda nao revirado no predio-alvo (o mais perto do npc).
function SC.pickContainer(npc, t)
    if not t.x1 then return nil end
    t.visited = t.visited or {}
    local best, bestD = nil, math.huge
    local zx, zy = npc.z:getX(), npc.z:getY()
    Rem.Safehouse.forEachSquare({ x1 = t.x1, y1 = t.y1, x2 = t.x2, y2 = t.y2 }, t.z or 0, function(sq)
        if sq:getRoom() then
            local objs = sq:getObjects()
            for i = 0, objs:size() - 1 do
                local o = objs:get(i)
                for c = 0, o:getContainerCount() - 1 do
                    local cont = o:getContainerByIndex(c)
                    local key = sqKey(sq) .. "," .. tostring(cont and cont:getType())
                    if cont and not t.visited[key] then
                        local d = Rem.dist2(zx, zy, sq:getX() + 0.5, sq:getY() + 0.5)
                        if d < bestD then best, bestD = { c = cont, sq = sq, key = key }, d end
                    end
                end
            end
        end
    end)
    return best
end

-- Abre o armario (gera o loot se ninguem abriu antes) e pega o que vale mais.
function SC.takeFrom(npc, cont)
    if not cont:isExplored() then
        Rem.safe(function() ItemPicker.fillContainer(cont, getPlayer()) end)
        cont:setExplored(true)
    end
    local items = cont:getItems()
    local list = {}
    for i = 0, items:size() - 1 do
        local it = items:get(i)
        local sc = SC.itemScore(it)
        if sc > 0 then table.insert(list, { it = it, sc = sc }) end
    end
    table.sort(list, function(a, b) return a.sc > b.sc end)
    local rec = npc.rec
    rec.carry = rec.carry or {}
    local took = 0
    for _, e in ipairs(list) do
        if took >= CFG.TAKE_PER_VISIT or #rec.carry >= CFG.CARRY_MAX then break end
        local ft = e.it:getFullType()
        cont:DoRemoveItem(e.it)
        table.insert(rec.carry, ft)
        took = took + 1
    end
    if took > 0 then Rem.bark(npc, "loot_found") end
    return took
end

-- Guarda o que carrega no estoque de casa. Retorna quantos itens.
function SC.deposit(npc, g)
    local rec = npc.rec
    local n = carryCount(rec)
    if n == 0 then return 0 end
    local conts = Rem.Safehouse.stashContainers(g.home)
    if conts and #conts > 0 then
        for i, ft in ipairs(rec.carry) do
            local c = conts[((i - 1) % #conts) + 1]
            Rem.safe(function() c:AddItem(ft) end)
        end
        g.home.syncCount = (g.home.syncCount or 0) + n
        g.home.stashCount = (g.home.stashCount or 0) + n
    else
        -- casa ainda sem estoque montado: os itens entram como pendentes
        g.pendingItems = (g.pendingItems or 0) + n
    end
    g.supplies = (g.supplies or 0) + n / ips()
    rec.carry = nil
    Rem.bark(npc, "loot_home")
    Rem.debug(tostring(rec.name) .. " guardou " .. n .. " itens no estoque do grupo " .. g.id)
    return n
end

-- ---------------------------------------------------------------- comportamentos
-- Chegou em casa carregando: guarda no estoque antes de qualquer outra coisa (sentar,
-- dormir...). Roda cedo (DEPOSIT_PRIORITY) e nunca "segura" o pensamento.
function SC.depositBehavior(npc, ctx, now)
    local rec = npc.rec
    if rec.mode ~= "group" or carryCount(rec) == 0 then return false end
    local g = groupOf(rec)
    local h = g and g.home
    if g and g.activity == "home" and h
        and Rem.dist2(npc.z:getX(), npc.z:getY(), h.x, h.y) <= math.max(CFG.DEPOSIT_DIST, (h.x2 and (h.x2 - h.x1) / 2 or 0)) then
        SC.deposit(npc, g)
    end
    return false
end

function SC.behavior(npc, ctx, now)
    local rec = npc.rec
    if rec.mode ~= "group" then return false end
    local g = groupOf(rec)
    if not g then return false end
    local h = g.home

    if g.activity ~= "scavenge" or not g.target then
        npc.lootTarget, npc.lootUntil = nil, nil
        return false
    end

    -- o guarda fica tomando conta da casa
    if rec.role == "guarda" and #g.members >= 2 and h and h.mainDoor then
        local spot = Rem.Roles.guardSpot(h)
        Rem.hangAround(npc, spot.x + 0.5, spot.y + 0.5, spot.z or 0, now, 0)
        return true
    end

    local t = g.target
    if not t.x1 then Rem.Safehouse.fillRect(t) end   -- alvo de save antigo
    local d = Rem.dist2(npc.z:getX(), npc.z:getY(), t.x, t.y)
    if d > CFG.NEAR_TARGET or not t.x1 then return false end   -- a rotina do grupo leva ate la

    if carryCount(rec) >= CFG.CARRY_MAX or npc.lootDoneBid == t.bid then
        Rem.hangAround(npc, t.x + 0.5, t.y + 0.5, t.z or 0, now, 4)
        return true
    end

    local cur = npc.lootTarget
    if not cur then
        cur = SC.pickContainer(npc, t)
        if not cur then
            npc.lootDoneBid = t.bid   -- nada mais para revirar neste predio
            return true
        end
        npc.lootTarget = cur
    end
    local cx, cy = cur.sq:getX() + 0.5, cur.sq:getY() + 0.5
    if Rem.dist2(npc.z:getX(), npc.z:getY(), cx, cy) > CFG.TOUCH then
        -- armario fica num quadrado solido: vai ate o quadrado livre ao lado
        cur.since = cur.since or now
        if now - cur.since > CFG.STUCK_MS then      -- nao consegue chegar: desiste deste
            t.visited = t.visited or {}
            t.visited[cur.key] = true
            npc.lootTarget, npc.lootUntil = nil, nil
            return true
        end
        local sx, sy, sz = Rem.standSquare(cur.sq, npc.z:getX(), npc.z:getY())
        Rem.moveTo(npc, sx, sy, sz, now, Rem.baseGait(npc))
        return true
    end
    Rem.stopMoving(npc)
    if not npc.lootUntil then
        npc.lootUntil = now + CFG.SEARCH_MS
        Rem.safe(function() npc.z:faceLocationF(cx, cy) end)
        return true
    end
    if now < npc.lootUntil then return true end
    Rem.safe(SC.takeFrom, npc, cur.c)
    t.visited = t.visited or {}
    t.visited[cur.key] = true
    npc.lootTarget, npc.lootUntil = nil, nil
    return true
end

-- ---------------------------------------------------------------- estoque vivo
local function removeOne(conts, preferFood)
    for pass = 1, 2 do
        for _, c in ipairs(conts) do
            local items = c:getItems()
            for i = items:size() - 1, 0, -1 do
                local it = items:get(i)
                local food = false
                pcall(function() food = it:isFood() end)
                if pass == 2 or not preferFood or food then
                    c:DoRemoveItem(it)
                    return true
                end
            end
        end
    end
    return false
end

-- Ajusta o estoque real da casa aos suprimentos do grupo. Retorna o novo total.
function SC.syncStash(g)
    local h = g.home
    local conts = Rem.Safehouse.stashContainers(h)
    if not conts or #conts == 0 then return nil end
    local observed = 0
    for _, c in ipairs(conts) do observed = observed + c:getItems():size() end
    -- sumiu sem ser consumo: alguem levou (o grupo perde esses suprimentos)
    if h.syncCount and observed < h.syncCount then
        g.supplies = math.max(0, (g.supplies or 0) - (h.syncCount - observed) / ips())
    end
    -- chegou do saque fora de cena
    local pending = math.floor(g.pendingItems or 0)
    if pending > 0 then
        local list = Rem.Safehouse.STASH[g.faction] or Rem.Safehouse.STASH.default
        local room = math.max(0, CFG.STASH_MAX - observed)
        local add = math.min(pending, room)
        for k = 1, add do
            local c = conts[((k - 1) % #conts) + 1]
            Rem.safe(function() c:AddItem(list[ZombRand(#list) + 1]) end)
        end
        observed = observed + add
        g.pendingItems = (g.pendingItems or 0) - pending   -- o que nao coube se perde
    end
    -- o grupo comeu: tira o excedente (comida primeiro)
    local target = math.floor((g.supplies or 0) * ips())
    while observed > target + CFG.CONSUME_SLACK do
        if not removeOne(conts, true) then break end
        observed = observed - 1
    end
    h.syncCount = observed
    h.stashCount = observed   -- o detector de roubo (Rem_Reputation) nao conta o consumo
    return observed
end

local lastSync = {}
function SC.syncNear(player, now)
    local px, py = player:getX(), player:getY()
    for gid, g in pairs(Rem.getStore().groups) do
        local h = g.home
        -- (a base do jogador tem a conta dela, Rem_PlayerBase: nunca apaga os itens dele)
        if h and h.stocked and h.stash and not g.player and now - (lastSync[gid] or -CFG.SYNC_MS) >= CFG.SYNC_MS
            and Rem.dist2(px, py, h.x, h.y) < Rem.Safehouse.CFG.PREPARE_RADIUS then
            lastSync[gid] = now
            Rem.safe(SC.syncStash, g)
        end
    end
end

-- ---------------------------------------------------------------- ganchos
Rem.registerBehavior({ name = "deposit", priority = CFG.DEPOSIT_PRIORITY, run = SC.depositBehavior })
Rem.registerBehavior({ name = "scavenge", priority = CFG.PRIORITY, run = SC.behavior })
Rem.on("sceneUpdate", function(player, now) SC.syncNear(player, now) end)
Rem.on("groupRemoved", function(g) lastSync[g.id] = nil end)
