-- Remanescentes - armadilhas e alarmes no perimetro (obras novas, Rem_BaseBuild).
--
--   latas      latas penduradas num fio em volta da cerca: quem passa faz barulho. O vigia
--              ouve mais longe (alarme) e, longe de voce, ninguem e pego tao de surpresa
--              mesmo sem vigia acordado.
--   estacas    buracos com estacas no caminho ate a casa. Em cena, zumbi que entra no anel
--              entre a cerca e a casa pode cair numa (fica muito ferido, a estaca se gasta).
--              Longe de voce, cada estaca segura parte da horda.
-- Sua base e a milicia fazem as duas; saqueadores, so estacas.
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_BaseBuild"
local Rem = Remanescentes
local BB = Rem.BaseBuild

local TP = Rem.module("Traps", {
    CANS_MAX = 8,
    TRAPS_MAX = 10,
    CANS_FULL = 4,            -- latas a partir disso: o alarme conta
    CANS_ALARM = 4,           -- tiles a mais de alarme
    CANS_SURPRISE = 0.85,     -- sem vigia acordado, com latas: defesa x isso (em vez de 0,6)
    TRAP_HORDE = 0.4,         -- zumbis da horda segurados por estaca (fora de cena)
    TRAP_HORDE_MAX = 4,
    TRAP_CHANCE = 35,         -- (%) zumbi no anel cai numa estaca (por verificacao)
    TRAP_DAMAGE = 1.2,
    CHECK_MS = 2000,
    RING = 2,                 -- o anel vai ate tantos tiles alem das paredes (ate a cerca)
})
local CFG = TP.CFG

local function spots(h, n)
    -- tarefas em volta da casa (os quatro lados, em rodizio)
    local out = {}
    local m = 2
    local pts = { { h.x1 - m, math.floor((h.y1 + h.y2) / 2) }, { h.x2 - 1 + m, math.floor((h.y1 + h.y2) / 2) },
        { math.floor((h.x1 + h.x2) / 2), h.y1 - m }, { math.floor((h.x1 + h.x2) / 2), h.y2 - 1 + m } }
    for i = 1, n do
        local p = pts[((i - 1) % #pts) + 1]
        table.insert(out, { x = p[1], y = p[2], z = 0, left = 1 })
    end
    return out
end

BB.registerProject("cans", {
    cost = 1, after = "barbed", estimate = CFG.CANS_MAX,
    factions = { aliados = true, sobreviventes = true },
    plan = function(g, h)
        if not h.x1 then return {} end
        return spots(h, math.max(0, CFG.CANS_MAX - (h.cans or 0)))
    end,
    apply = function(g, h, t)
        h.cans = math.min(CFG.CANS_MAX, (h.cans or 0) + 1)
        return true
    end,
})

BB.registerProject("traps", {
    cost = 2, after = "cans", estimate = CFG.TRAPS_MAX,
    factions = { aliados = true, sobreviventes = true, saqueadores = true },
    plan = function(g, h)
        if not h.x1 then return {} end
        return spots(h, math.max(0, CFG.TRAPS_MAX - (h.traps or 0)))
    end,
    apply = function(g, h, t)
        h.traps = math.min(CFG.TRAPS_MAX, (h.traps or 0) + 1)
        return true
    end,
})

function TP.cansReady(h) return (h.cans or 0) >= CFG.CANS_FULL end

-- Zumbis da horda que as estacas seguram (fora de cena).
function TP.hordeStopped(h)
    return math.min(CFG.TRAP_HORDE_MAX, math.floor((h.traps or 0) * CFG.TRAP_HORDE))
end

-- ---------------------------------------------------------------- em cena: estacas
-- zumbis que ja passaram pelo anel (so em memoria: objetos do jogo nao vao para o save)
TP.tried, TP.triedN = {}, 0

local function inRing(h, x, y)
    local m = CFG.RING
    local outside = x < h.x1 or x > h.x2 or y < h.y1 or y > h.y2
    return outside and x >= h.x1 - m - 1 and x <= h.x2 + m and y >= h.y1 - m - 1 and y <= h.y2 + m
end

-- Zumbis no anel podem cair numa estaca. Retorna quantos cairam.
function TP.check(g)
    local h = g.home
    if not h or not h.x1 or (h.traps or 0) <= 0 then return 0 end
    local n = 0
    local list = Rem.zombiesNear(h.x, h.y, math.max(h.x2 - h.x1, h.y2 - h.y1) + CFG.RING + 2)
    for i = 1, #list do
        local zb = list[i]
        if (h.traps or 0) <= 0 then break end
        if not Rem.active[zb] and not zb:isDead() and inRing(h, zb:getX(), zb:getY()) and not TP.tried[zb] then
            TP.tried[zb] = true                        -- (cada zumbi so tem uma chance)
            TP.triedN = TP.triedN + 1
            if ZombRand(100) < CFG.TRAP_CHANCE then
                h.traps = h.traps - 1
                local hp = zb:getHealth() - CFG.TRAP_DAMAGE
                Rem.safe(function()
                    if hp <= 0 then zb:Kill(nil) else zb:setHealth(hp) end
                    zb:playSound("ZombieThumpGeneric")
                end)
                n = n + 1
            end
        end
    end
    return n
end

local nextCheck = 0
Rem.on("sceneUpdate", function(player, now)
    if now < nextCheck then return end
    nextCheck = now + CFG.CHECK_MS
    if TP.triedN > 500 then TP.tried, TP.triedN = {}, 0 end
    for _, g in pairs(Rem.getStore().groups) do
        local h = g.home
        if h and (h.traps or 0) > 0 and h.x1 and Rem.dist2(player:getX(), player:getY(), h.x, h.y) < 60 then
            Rem.safe(TP.check, g)
        end
    end
end)
