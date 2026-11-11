-- Remanescentes - territorio das faccoes e precos de cada regiao.
--
-- Cada grupo com casa controla a area em volta (raio = BASE + PER_MEMBER por pessoa, mais
-- um pouco com cerca/carros). Ao entrar no territorio de alguem, voce fica sabendo
-- ("Territorio de Os Lobos (saqueadores)") e o grupo passa a ser conhecido.
--   * territorio de saqueadores: encontros com saqueadores na rua ficam bem mais comuns;
--   * territorio de milicia/seita/familias: mais gente de passagem, menos saqueadores.
-- Precos (troca, Rem_Interact): cada regiao tem a sua economia.
--   * muitos grupos disputando a mesma area: comida e remedio valem mais (escassez);
--   * grupo em guerra (Rem_War): municao e remedio valem bem mais;
--   * milicia paga mais por municao; seita, por remedio; familias, por comida.
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_Journal"
require "Remanescentes/Rem_Ambient"
local Rem = Remanescentes

local TR = Rem.module("Territory", {
    BASE = 25,
    PER_MEMBER = 6,
    FENCE_BONUS = 10,
    CHECK_MS = 3000,
    RAIDER_WEIGHT = 3,        -- encontros de saqueadores x isso no territorio deles
    SAFE_RAIDER = 0.3,        -- ... e x isso no territorio de grupos que os combatem
    CROWD_RADIUS = 300,
    CROWD_STEP = 0.12,        -- cada grupo a mais por perto: +12% em comida e remedio
    CROWD_MAX = 0.6,
    WAR_AMMO = 1.6,
    WAR_MEDICAL = 1.4,
})
local CFG = TR.CFG

TR.FACTION_TASTE = {
    sobreviventes = { Ammo = 1.3 },
    seita = { FirstAid = 1.3 },
    civis = { Food = 1.2, Water = 1.2 },
    saqueadores = { Ammo = 1.2, Weapon = 1.2 },
}

function TR.radius(g)
    local r = CFG.BASE + #(g.members or {}) * CFG.PER_MEMBER
    local h = g.home
    if h and (h.fenceBuilt or 0) > 0 then r = r + CFG.FENCE_BONUS end
    return r
end

-- Dono do territorio em (x, y): o grupo mais perto cujo raio cobre o ponto (sua base nao).
function TR.ownerAt(x, y)
    local best, bestD = nil, nil
    for _, g in pairs(Rem.getStore().groups) do
        if g.home and not g.player and #g.members > 0 then
            local d = Rem.dist2(x, y, g.home.x, g.home.y)
            if d <= TR.radius(g) and (not bestD or d < bestD) then best, bestD = g, d end
        end
    end
    return best
end

-- ---------------------------------------------------------------- entrar no territorio
TR.current = nil
local nextCheck = 0

function TR.check(player, now)
    if now < nextCheck then return end
    nextCheck = now + CFG.CHECK_MS
    local g = TR.ownerAt(player:getX(), player:getY())
    local id = g and g.id or nil
    if id == TR.current then return g end
    TR.current = id
    if g then
        local s = Rem.getStore()
        s.met = s.met or {}
        s.met[g.id] = true                       -- agora voce sabe que eles existem
        local text = getText("IGUI_Rem_Territory_enter", Rem.Journal.groupName(g), getText("IGUI_Rem_Faction_" .. tostring(g.faction)))
        Rem.safe(function() HaloTextHelper.addText(player, text) end)
        Rem.emit("territoryEntered", g)
    end
    return g
end
Rem.on("sceneUpdate", function(player, now) Rem.safe(TR.check, player, now) end)

-- Encontros na rua (Rem_Ambient): o territorio muda a chance de cada tipo.
if Rem.Ambient and Rem.Ambient.weights then
    local baseWeights = Rem.Ambient.weights
    Rem.Ambient.weights = function(x, y)
        local w = baseWeights(x, y)
        local g = TR.ownerAt(x, y)
        if g and w.raider then
            if g.faction == "saqueadores" then
                w.raider = w.raider * CFG.RAIDER_WEIGHT
            elseif Rem.factionsHostile(g.faction, "saqueadores") then
                w.raider = w.raider * CFG.SAFE_RAIDER
            end
        end
        return w
    end
end

-- ---------------------------------------------------------------- precos
-- Grupos com casa a ate CROWD_RADIUS (incluindo o proprio).
function TR.crowd(g)
    local n = 0
    for _, o in pairs(Rem.getStore().groups) do
        if o.home and #o.members > 0 and Rem.dist2(o.home.x, o.home.y, g.home.x, g.home.y) <= CFG.CROWD_RADIUS then n = n + 1 end
    end
    return n
end

-- Multiplicadores de preco por categoria para o grupo (nil = sem mudanca).
function TR.priceMods(g)
    local m = { Food = 1, Water = 1, FirstAid = 1, Ammo = 1, Weapon = 1 }
    if not g or not g.home then return m end
    local scarce = math.min(CFG.CROWD_MAX, math.max(0, TR.crowd(g) - 1) * CFG.CROWD_STEP)
    m.Food, m.Water, m.FirstAid = m.Food + scarce, m.Water + scarce, m.FirstAid + scarce
    if Rem.War and Rem.War.enemyOf(g) then
        m.Ammo = m.Ammo * CFG.WAR_AMMO
        m.FirstAid = m.FirstAid * CFG.WAR_MEDICAL
    end
    for cat, v in pairs(TR.FACTION_TASTE[g.faction] or {}) do m[cat] = m[cat] * v end
    return m
end
