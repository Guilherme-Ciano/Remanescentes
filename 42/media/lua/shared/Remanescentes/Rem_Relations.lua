-- Remanescentes - Fase D4: relacoes entre grupos.
--
-- Cada par de grupos tem uma relacao de -100 a +100 (comeca por faccao: inimigas -60,
-- mesma faccao +30, o resto 0).
--   * rixas: quem ataca perde relacao com a vitima (e com os aliados dela). Saqueadores
--     escolhem como alvo grupos com quem tem relacao ruim; milicias fortes fazem
--     expedicoes punitivas contra saqueadores;
--   * aliancas: aliados (>= 50) por perto ajudam a defender quando um grupo e atacado;
--   * troca: uma vez por dia, grupos que se dao bem e estao perto dividem suprimentos (o
--     mais rico ajuda o mais pobre) e a relacao melhora;
--   * noticias: o que voce faz com um grupo (reputacao, Rem_Reputation) chega aos aliados
--     dele pela metade.
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_Factions"
require "Remanescentes/Rem_World"
local Rem = Remanescentes

local REL = Rem.module("Relations", {
    MIN = -100, MAX = 100,
    ALLY_AT = 50, ENEMY_AT = -50,
    HOSTILE_DEFAULT = -60, SAME_FACTION = 30,
    TRADE_RADIUS = 200, TRADE_AT = 20, TRADE_GAP = 3, TRADE_AMOUNT = 1.5, TRADE_GAIN = 5,
    RAID_LOSS = 30, ALLY_RAID_LOSS = 15,
    ALLY_HELP_RADIUS = 200, ALLY_HELP = 0.5,     -- cada aliado perto vale meio defensor
    NEWS_RADIUS = 300, NEWS_MIN = 10, NEWS_FACTOR = 0.5,
})
local CFG = REL.CFG

local function rel()
    local s = Rem.getStore()
    s.relations = s.relations or {}
    return s.relations
end

local function key(a, b)
    if a.id < b.id then return a.id .. "|" .. b.id end
    return b.id .. "|" .. a.id
end

function REL.default(a, b)
    if Rem.factionsHostile(a.faction, b.faction) then return CFG.HOSTILE_DEFAULT end
    if a.faction == b.faction then return CFG.SAME_FACTION end
    return 0
end

function Rem.relation(a, b)
    if a == b then return CFG.MAX end
    local v = rel()[key(a, b)]
    if v == nil then return REL.default(a, b) end
    return v
end

function Rem.changeRelation(a, b, delta)
    if a == b then return end
    local v = math.max(CFG.MIN, math.min(CFG.MAX, Rem.relation(a, b) + delta))
    rel()[key(a, b)] = v
    return v
end

-- Grupos com quem g se da bem (>= ALLY_AT) a ate radius tiles.
function REL.allies(g, radius)
    local out = {}
    for _, other in pairs(Rem.getStore().groups) do
        if other ~= g and Rem.relation(g, other) >= CFG.ALLY_AT
            and Rem.dist2(g.x, g.y, other.x, other.y) <= (radius or CFG.ALLY_HELP_RADIUS) then
            table.insert(out, other)
        end
    end
    return out
end

-- Forca extra de defesa vinda dos aliados (usado em Rem_World.resolveRaid).
function Rem.allyHelp(victim)
    local help = 0
    for _, a in ipairs(REL.allies(victim, CFG.ALLY_HELP_RADIUS)) do
        help = help + #a.members * CFG.ALLY_HELP
    end
    return help
end

-- ---------------------------------------------------------------- rixas
Rem.on("raidResolved", function(attacker, victim)
    Rem.changeRelation(attacker, victim, -CFG.RAID_LOSS)
    for _, a in ipairs(REL.allies(victim, CFG.NEWS_RADIUS)) do
        if a ~= attacker then Rem.changeRelation(attacker, a, -CFG.ALLY_RAID_LOSS) end
    end
end)

-- ---------------------------------------------------------------- troca (diaria)
function REL.trade()
    local list = {}
    for _, g in pairs(Rem.getStore().groups) do
        if g.activity == "home" and #g.members > 0 then table.insert(list, g) end
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    local traded = 0
    for i = 1, #list do
        for j = i + 1, #list do
            local a, b = list[i], list[j]
            if Rem.relation(a, b) >= CFG.TRADE_AT and Rem.dist2(a.x, a.y, b.x, b.y) <= CFG.TRADE_RADIUS then
                local sa, sb = a.supplies or 0, b.supplies or 0
                if math.abs(sa - sb) > CFG.TRADE_GAP then
                    local rich, poor = (sa > sb) and a or b, (sa > sb) and b or a
                    rich.supplies = rich.supplies - CFG.TRADE_AMOUNT
                    poor.supplies = (poor.supplies or 0) + CFG.TRADE_AMOUNT
                    Rem.changeRelation(a, b, CFG.TRADE_GAIN)
                    traded = traded + 1
                    Rem.debug("troca: " .. rich.id .. " ajudou " .. poor.id)
                end
            end
        end
    end
    return traded
end

-- ---------------------------------------------------------------- noticias
Rem.on("reputationChanged", function(rkey, old, new, reason)
    if type(reason) == "string" and reason:sub(1, 7) == "noticia" then return end
    local g = Rem.getStore().groups[rkey]
    local delta = (new or 0) - (old or 0)
    if not g or math.abs(delta) < CFG.NEWS_MIN then return end
    for _, a in ipairs(REL.allies(g, CFG.NEWS_RADIUS)) do
        local d = delta * CFG.NEWS_FACTOR
        d = (d > 0) and math.floor(d) or math.ceil(d)
        if d ~= 0 then Rem.changeRep(a.id, d, "noticia de " .. g.id) end
    end
end)

Rem.on("groupRemoved", function(g)
    local r = rel()
    local gone = {}
    for k in pairs(r) do
        if k:sub(1, #g.id + 1) == g.id .. "|" or k:sub(-(#g.id + 1)) == "|" .. g.id then table.insert(gone, k) end
    end
    for _, k in ipairs(gone) do r[k] = nil end
end)

Events.EveryDays.Add(function() if Rem.isAuthority() then Rem.safe(REL.trade) end end)

Rem.registerDebugOption("ContextMenu_Rem_Relations", function(x, y, z, player)
    local g = Rem.nearestGroup(player:getX(), player:getY())
    if not g then return end
    local parts = {}
    for _, o in pairs(Rem.getStore().groups) do
        if o ~= g and Rem.dist2(g.x, g.y, o.x, o.y) < CFG.NEWS_RADIUS then
            table.insert(parts, o.id .. "(" .. o.faction .. ")=" .. Rem.relation(g, o))
        end
    end
    Rem.log("relacoes de " .. g.id .. ": " .. table.concat(parts, ", "))
    player:Say(g.id .. ": " .. #parts .. " grupos por perto (lista no console)")
end)
