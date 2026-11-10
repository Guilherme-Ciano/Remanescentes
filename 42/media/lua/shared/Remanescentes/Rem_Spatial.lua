-- Remanescentes - indice espacial dos zumbis carregados (desempenho).
--
-- Antes, cada sobrevivente percorria a lista INTEIRA de zumbis varias vezes por segundo
-- (inimigos, percepcao, multidao, barulho). Agora a lista e agrupada em celulas de CELL
-- tiles no maximo a cada MAX_AGE_MS (ou quando o numero de zumbis muda), e cada consulta
-- olha so as celulas em volta.
require "Remanescentes/Rem_Core"
local Rem = Remanescentes

local SP = Rem.module("Spatial", {
    CELL = 8,
    MAX_AGE_MS = 100,
})
local CFG = SP.CFG

local buckets, builtAt, builtCount = {}, -1, -1

local function key(cx, cy) return cx * 100000 + cy end

function SP.rebuild(now)
    buckets = {}
    local list = getCell():getZombieList()
    local n = list:size()
    local cell = CFG.CELL
    for i = 0, n - 1 do
        local z = list:get(i)
        if not z:isDead() then
            local k = key(math.floor(z:getX() / cell), math.floor(z:getY() / cell))
            local b = buckets[k]
            if not b then b = {} buckets[k] = b end
            b[#b + 1] = z
        end
    end
    builtAt, builtCount = now, n
end

function SP.invalidate() builtAt = -1 end

-- Zumbis (inclusive corpos de sobreviventes) a ate r tiles de (x, y). Lista nova.
function Rem.zombiesNear(x, y, r)
    local now = Rem.nowMs()
    local size = getCell():getZombieList():size()
    if now - builtAt > CFG.MAX_AGE_MS or now < builtAt or size ~= builtCount then SP.rebuild(now) end
    local out = {}
    local cell = CFG.CELL
    local cx1, cx2 = math.floor((x - r) / cell), math.floor((x + r) / cell)
    local cy1, cy2 = math.floor((y - r) / cell), math.floor((y + r) / cell)
    local r2 = r * r
    for cx = cx1, cx2 do
        for cy = cy1, cy2 do
            local b = buckets[key(cx, cy)]
            if b then
                for i = 1, #b do
                    local z = b[i]
                    local dx, dy = z:getX() - x, z:getY() - y
                    if dx * dx + dy * dy <= r2 and not z:isDead() then out[#out + 1] = z end
                end
            end
        end
    end
    return out
end
