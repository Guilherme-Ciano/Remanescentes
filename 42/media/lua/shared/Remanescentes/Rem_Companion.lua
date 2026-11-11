-- Remanescentes - companheiros: usabilidade de quem anda com voce.
--
-- * Alcancar: um seguidor que ficou para tras (travado, perdido, voce correu ou pegou um
--   carro) reaparece perto de voce, fora da sua frente, depois de um tempo longe. Quem
--   estava "no papel" (chunk descarregou) tambem volta para o seu lado.
-- * Ordens para todos: "Todos comigo" e "Todos esperem aqui" no menu do clique direito.
-- * Ordens pela conversa: seguir, esperar, guardar, vasculhar o predio, liberar.
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_Spawn"
require "Remanescentes/Rem_Commands"
require "Remanescentes/Rem_Interact"
local Rem = Remanescentes
local IA = Rem.Interact

local CP = Rem.module("Companion", {
    CHECK_MS = 2000,
    CATCHUP_DIST = 30,        -- seguidor a mais que isso de voce...
    CATCHUP_MS = 7000,        -- ...por esse tempo: reaparece perto
    PLACE = { 5, 9 },         -- a essa distancia, de preferencia atras de voce
    PAPER_DIST = 25,          -- seguidor fora de cena a mais que isso: volta para o seu lado
})
local CFG = CP.CFG

Rem.BARKS.catchup = { urgent = true, n = 3, cd = 0 }

-- Quadrado livre perto do jogador, de preferencia atras dele.
function CP.placeNear(player)
    local cell = getCell()
    local fx, fy = 0, 1
    pcall(function() local f = player:getForwardDirection() fx, fy = f:getX(), f:getY() end)
    local base = math.atan2(-fy, -fx)
    local pz = math.floor(player:getZ())
    for attempt = 1, 16 do
        local spread = (attempt <= 8) and 1.0 or math.pi
        local a = base + (ZombRand(0, 201) / 100 - 1) * spread
        local d = ZombRand(CFG.PLACE[1], CFG.PLACE[2] + 1)
        local sq = cell:getGridSquare(math.floor(player:getX() + math.cos(a) * d), math.floor(player:getY() + math.sin(a) * d), pz)
        if sq and sq:isFree(false) then return sq end
    end
    return nil
end

-- Traz o seguidor para perto. Retorna o npc novo (o corpo e refeito) ou nil.
function CP.bring(npc, player)
    local sq = CP.placeNear(player)
    if not sq then return nil end
    local rec = npc.rec
    Rem.dematerialize(npc)
    rec.x, rec.y, rec.z = sq:getX() + 0.5, sq:getY() + 0.5, sq:getZ()
    local fresh = Rem.materialize(rec)
    if fresh then
        Rem.bark(fresh, "catchup", true)
        Rem.debug(tostring(rec.name) .. " alcancou voce")
    end
    return fresh
end

local nextCheck = 0
function CP.tick(player, now)
    if now < nextCheck then return end
    nextCheck = now + CFG.CHECK_MS
    local late = {}
    for _, npc in pairs(Rem.active) do
        if npc.rec.faction == "aliados" and npc.rec.mode == "follow" and npc.rec.stance ~= "retreat" then
            if Rem.dist(npc.z, player) > CFG.CATCHUP_DIST then
                npc.farSince = npc.farSince or now
                if now - npc.farSince >= CFG.CATCHUP_MS and now >= (npc.attackUntil or 0) then table.insert(late, npc) end
            else
                npc.farSince = nil
            end
        end
    end
    for _, npc in ipairs(late) do Rem.safe(CP.bring, npc, player) end
    -- seguidores no papel (o lugar onde estavam descarregou)
    local px, py = player:getX(), player:getY()
    for _, rec in pairs(Rem.getStore().people) do
        if rec.faction == "aliados" and rec.mode == "follow" and not rec.onScene and rec.x and rec.stance ~= "retreat"
            and Rem.dist2(px, py, rec.x, rec.y) > CFG.PAPER_DIST then
            local sq = CP.placeNear(player)
            if sq then
                rec.x, rec.y, rec.z = sq:getX() + 0.5, sq:getY() + 0.5, sq:getZ()
                rec.pid = nil
            end
        end
    end
end
Rem.on("sceneUpdate", function(player, now) Rem.safe(CP.tick, player, now) end)

-- ---------------------------------------------------------------- ordens para todos
function CP.followers()
    local out = {}
    for _, npc in pairs(Rem.active) do
        if npc.rec.faction == "aliados" then table.insert(out, npc) end
    end
    return out
end

function CP.orderAll(mode)
    local n = 0
    for _, npc in ipairs(CP.followers()) do
        if npc.rec.mode ~= mode or mode == "stay" then
            Rem.Commands.setMode(npc, mode)
            n = n + 1
        end
    end
    return n
end

local function hasFollowers() return #CP.followers() > 0 end
Rem.registerPlayerOption("ContextMenu_Rem_AllFollow", function() CP.orderAll("follow") end, hasFollowers)
Rem.registerPlayerOption("ContextMenu_Rem_AllStay", function() CP.orderAll("stay") end, hasFollowers)

-- ---------------------------------------------------------------- predio perto do jogador
function CP.buildingNear(player)
    local cell = getCell()
    local sq = cell:getGridSquare(math.floor(player:getX()), math.floor(player:getY()), math.floor(player:getZ()))
    if sq and sq:getBuilding() then return sq end
    for r = 1, 12 do
        for dx = -r, r do
            for dy = -r, r do
                if math.abs(dx) == r or math.abs(dy) == r then
                    local s = cell:getGridSquare(math.floor(player:getX()) + dx, math.floor(player:getY()) + dy, math.floor(player:getZ()))
                    if s and s:getBuilding() then return s end
                end
            end
        end
    end
    return nil
end

-- ---------------------------------------------------------------- ordens pela conversa
-- Opcoes "order_*" da janela de conversa (so para aliados). Retorna a fala de resposta.
CP.ORDERS = { "order_follow", "order_stay", "order_guard", "order_loot", "order_release" }

function CP.order(id, npc, player)
    local rec = npc.rec
    if id == "order_follow" then
        Rem.Commands.setMode(npc, "follow")
        return { key = "IGUI_Rem_Order_follow", args = {}, final = true }
    elseif id == "order_stay" then
        Rem.Commands.setMode(npc, "stay")
        return { key = "IGUI_Rem_Order_stay", args = {}, final = true }
    elseif id == "order_guard" then
        IA.guard(npc)
        return { key = "IGUI_Rem_Order_guard", args = {}, final = true }
    elseif id == "order_loot" then
        local ok, l = IA.lootHere(npc, CP.buildingNear(player))
        return l
    elseif id == "order_release" then
        IA.release(npc, player)
        return { key = "IGUI_Rem_Order_release", args = {}, final = true }
    end
    return nil
end
