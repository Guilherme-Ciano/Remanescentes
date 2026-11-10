-- Remanescentes - cena: perto do jogador as pessoas ganham corpo (materializar), longe
-- voltam ao papel (desmaterializar). Tambem o teleporte seguro das ferramentas de teste.
-- A simulacao fora de cena esta em Rem_World.lua.
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_Factions"
require "Remanescentes/Rem_Spawn"
local Rem = Remanescentes

local S = Rem.module("Scene", {
    SPAWN_RADIUS = 45,          -- pessoas a menos disso do jogador ganham corpo
    DESPAWN_RADIUS = 70,        -- com corpo e mais longe que isso: volta ao papel
    SCENE_CHECK_MS = 1500,
    START_GRACE_MS = 4000,      -- apos carregar, espera os chunks re-associarem corpos salvos
    TELEPORT_GAP = 5,           -- distancia da parede da casa
    TELEPORT_SEARCH = 20,       -- raio da busca pelo quadrado bom
    TELEPORT_NO_ZOMBIE = 6,     -- sem zumbis a essa distancia
    TELEPORT_TIMEOUT_MS = 15000,
})

-- ---------------------------------------------------------------- materializacao
local startedAt = nil

local function findZombieByPid(pid)
    local list = getCell():getZombieList()
    for i = 0, list:size() - 1 do
        local z = list:get(i)
        if z:getPersistentOutfitID() == pid and not z:isDead() then return z end
    end
    return nil
end

function Rem.updateScene(player, now)
    local store = Rem.getStore()
    local cap = Rem.cfg("MaxActive", 12)
    local px, py = player:getX(), player:getY()

    -- tira corpo de quem ficou longe (seguidores nunca)
    local far = nil
    for _, npc in pairs(Rem.active) do
        local mode = npc.rec.mode
        -- seguidores (inclusive saqueando para voce) nunca saem de cena
        if mode ~= "follow" and mode ~= "loot" and Rem.dist2(px, py, npc.z:getX(), npc.z:getY()) > S.CFG.DESPAWN_RADIUS then
            far = far or {}
            table.insert(far, npc)
        end
    end
    -- gente de passagem (Rem_Ambient) nao volta ao papel: some
    if far then
        for _, npc in ipairs(far) do
            if npc.rec.transient then Rem.dismiss(npc) else Rem.dematerialize(npc) end
        end
    end

    -- da corpo a quem chegou perto (mais perto primeiro)
    local cand = {}
    for _, rec in pairs(store.people) do
        if not rec.onScene and rec.x then
            local d = Rem.dist2(px, py, rec.x, rec.y)
            if d < S.CFG.SPAWN_RADIUS then table.insert(cand, { rec = rec, d = d }) end
        end
    end
    table.sort(cand, function(a, b) return a.d < b.d end)
    for _, c in ipairs(cand) do
        if Rem.activeCount >= cap then break end
        local rec = c.rec
        local zombie = rec.pid and findZombieByPid(rec.pid)
        if zombie and not Rem.active[zombie] then
            Rem.activate(zombie, rec)
        elseif getCell():getGridSquare(math.floor(rec.x), math.floor(rec.y), math.floor(rec.z or 0)) then
            rec.pid = nil
            Rem.materialize(rec)
        end
    end
    Rem.emit("sceneUpdate", player, now)
end

local nextScene = 0
Events.OnTick.Add(function()
    if not Rem.isAuthority() then return end
    local now = Rem.nowMs()
    if not startedAt then startedAt = now end
    if now < nextScene or now - startedAt < S.CFG.START_GRACE_MS then return end
    nextScene = now + S.CFG.SCENE_CHECK_MS
    local player = getPlayer()
    if not player or player:isDead() then return end
    if Rem.seedWorld then Rem.safe(Rem.seedWorld, player) end -- Rem_World
    Rem.safe(Rem.updateScene, player, now)
end)

-- ---------------------------------------------------------------- teleporte seguro (debug)
-- Antes de carregar o lugar nao da para saber o que tem la. Entao: 1) teleporta para um
-- ponto do lado de fora da casa; 2) quando os quadrados existirem, procura em volta um
-- quadrado livre, ao ar livre e sem zumbis perto, e ajusta a posicao.
local pendingTeleport = nil

local function outsidePoint(g)
    local h = g.home
    if g.activity ~= "home" then
        -- grupo fora de casa (saque/volta): perto de onde ele esta
        return math.floor(g.x), math.floor(g.y) + 8
    end
    if h.x1 then
        -- lado sul (maior y), no meio da fachada
        return math.floor((h.x1 + h.x2) / 2), math.floor(h.y2 + S.CFG.TELEPORT_GAP)
    end
    return math.floor(h.x) , math.floor(h.y) + 12
end

-- Zumbis comuns perto de (cx, cy), uma vez so por busca.
local function zombiesAround(cx, cy, r)
    local out = {}
    local list = getCell():getZombieList()
    for i = 0, list:size() - 1 do
        local zb = list:get(i)
        if not zb:isDead() and not Rem.active[zb] and Rem.dist2(cx, cy, zb:getX(), zb:getY()) < r then
            table.insert(out, { zb:getX(), zb:getY() })
        end
    end
    return out
end

local function zombieNear(zlist, x, y, r)
    for _, p in ipairs(zlist) do
        if Rem.dist2(x, y, p[1], p[2]) < r then return true end
    end
    return false
end

local function goodSquare(sq)
    if not sq or not sq:isFree(false) then return false end
    local ok, out = pcall(function() return sq:isOutside() end)
    return not ok or out == true
end

-- Retorna x, y de um quadrado bom perto de (cx, cy), ou nil se o lugar ainda nao carregou.
function Rem.findSafeSpot(cx, cy, z)
    local cell = getCell()
    if not cell:getGridSquare(cx, cy, z) then return nil end
    local zlist = zombiesAround(cx, cy, S.CFG.TELEPORT_SEARCH + S.CFG.TELEPORT_NO_ZOMBIE + 1)
    local fallback = nil
    for r = 0, S.CFG.TELEPORT_SEARCH do
        for dx = -r, r do
            for dy = -r, r do
                if math.abs(dx) == r or math.abs(dy) == r then
                    local sq = cell:getGridSquare(cx + dx, cy + dy, z)
                    if goodSquare(sq) then
                        if not zombieNear(zlist, cx + dx, cy + dy, S.CFG.TELEPORT_NO_ZOMBIE) then
                            return cx + dx, cy + dy
                        end
                        fallback = fallback or { cx + dx, cy + dy }
                    end
                end
            end
        end
    end
    if fallback then return fallback[1], fallback[2] end
    return nil
end

function Rem.teleportNearGroup(player, g)
    local tx, ty = outsidePoint(g)
    pendingTeleport = { x = tx, y = ty, z = 0, untilMs = Rem.nowMs() + S.CFG.TELEPORT_TIMEOUT_MS }
    local sx, sy = Rem.findSafeSpot(tx, ty, 0)
    if sx then
        pendingTeleport = nil
        player:teleportTo(sx + 0.5, sy + 0.5, 0)
    else
        player:teleportTo(tx + 0.5, ty + 0.5, 0)
    end
end

Events.OnTick.Add(function()
    if not pendingTeleport then return end
    local t = pendingTeleport
    local player = getPlayer()
    if not player or Rem.nowMs() > t.untilMs then pendingTeleport = nil return end
    local sx, sy = Rem.findSafeSpot(t.x, t.y, t.z)
    if sx then
        pendingTeleport = nil
        player:teleportTo(sx + 0.5, sy + 0.5, t.z)
        Rem.debug("teleporte ajustado para " .. sx .. "," .. sy)
    end
end)
