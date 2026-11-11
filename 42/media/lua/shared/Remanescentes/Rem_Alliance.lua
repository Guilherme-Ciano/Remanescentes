-- Remanescentes - aliancas: grupos amigos que ficam do seu lado.
--
-- Na conversa com alguem de um grupo (nao saqueadores): "Vamos nos aliar." Aceitam com
-- reputacao ALLY_REP+ (e um vinculo pessoal ajuda: cada ponto de vinculo vale 0,5 de
-- reputacao). Aliados:
--   * trocam sem margem (preco justo);
--   * mandam gente ajudar quando sua base e atacada (hordas e saqueadores): cada grupo
--     aliado a ate HELP_RADIUS da sua base soma HELP_DEFENSE na defesa;
--   * dividem comida: uma vez por dia, quem tem de sobra manda um pouco para a sua base;
--   * pedem socorro quando sao cercados (Rem_Stories).
-- A alianca acaba se a reputacao cair abaixo de BREAK_REP (bater, ameacar, matar alguem
-- deles) - e eles nao esquecem.
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_Journal"
local Rem = Remanescentes

local AL = Rem.module("Alliance", {
    ALLY_REP = 60,
    BOND_WEIGHT = 0.5,
    BREAK_REP = 20,
    HELP_RADIUS = 500,
    HELP_DEFENSE = 1.5,
    SHARE_SURPLUS = 4,        -- suprimentos por pessoa acima disso: dividem
    SHARE_ITEMS = 3,          -- itens de comida mandados por dia
    SHARE_HOUR = 10,          -- hora do dia em que a comida chega
    NO_ALLY = { saqueadores = true, errantes = true },
})
local CFG = AL.CFG

Rem.BARKS.ally_yes = { urgent = true, n = 2, cd = 0 }

local function line(key, ...) return { key = key, args = { ... } } end
local function groupOf(rec) return rec.groupId and Rem.getStore().groups[rec.groupId] or nil end

function AL.isAllied(g) return g ~= nil and g.allied == true end

function AL.canAsk(npc)
    local rec = npc.rec
    local g = groupOf(rec)
    if not g or g.player or g.allied or CFG.NO_ALLY[g.faction] then return false end
    return not Rem.isHostileToPlayer(npc)
end

-- Quanto falta (reputacao efetiva x necessaria).
function AL.score(npc)
    return (Rem.repOf(npc.rec) or 0) + (npc.rec.bond or 0) * CFG.BOND_WEIGHT
end

function AL.propose(npc)
    local g = groupOf(npc.rec)
    if not AL.canAsk(npc) then return false, line("IGUI_Rem_Ally_no") end
    if AL.score(npc) < CFG.ALLY_REP then return false, line("IGUI_Rem_Ally_notyet") end
    g.allied = true
    g.alliedSince = Rem.worldHours()
    Rem.Journal.add("IGUI_Rem_Journal_ally", Rem.Journal.groupName(g))
    if Rem.MapMarks then Rem.MapMarks.markGroup(g, npc) end
    Rem.bark(npc, "ally_yes", true)
    Rem.emit("playerDeed", "allied", npc)
    return true, line("IGUI_Rem_Ally_yes", Rem.Journal.groupName(g))
end

function AL.hint(npc)
    return line("IGUI_Rem_Hint_ally", tostring(math.floor(AL.score(npc))), tostring(CFG.ALLY_REP))
end

-- Defesa extra para a sua base: grupos aliados por perto mandam gente.
function AL.helpFor(base)
    if not base or not base.player or not base.home then return 0 end
    local n = 0
    for _, g in pairs(Rem.getStore().groups) do
        if g.allied and #g.members >= 2 and g.home and Rem.dist2(g.home.x, g.home.y, base.home.x, base.home.y) <= CFG.HELP_RADIUS then
            n = n + 1
        end
    end
    return n * CFG.HELP_DEFENSE
end

-- A alianca cai junto com a reputacao.
Rem.on("reputationChanged", function(key, old, new)
    local g = Rem.getStore().groups[key]
    if g and g.allied and new < CFG.BREAK_REP then
        g.allied = nil
        g.brokeAlliance = Rem.worldHours()
        Rem.Journal.add("IGUI_Rem_Journal_ally_broken", Rem.Journal.groupName(g))
    end
end)

-- Uma vez por dia: quem tem comida de sobra manda um pouco para a sua base.
function AL.share()
    local base = Rem.PlayerBase and Rem.PlayerBase.get()
    if not base then return 0 end
    local sent = 0
    local list = {}
    for _, g in pairs(Rem.getStore().groups) do if g.allied then table.insert(list, g) end end
    table.sort(list, function(a, b) return tostring(a.id) < tostring(b.id) end)
    for _, g in ipairs(list) do
        local n = math.max(1, #g.members)
        if (g.supplies or 0) > n * CFG.SHARE_SURPLUS then
            local items = CFG.SHARE_ITEMS
            local ips = Rem.World.CFG.ITEMS_PER_SUPPLY
            g.supplies = g.supplies - items / ips
            base.pendingList = base.pendingList or {}
            for _ = 1, items do table.insert(base.pendingList, Rem.pick(Rem.PlayerBase.SCAV_LOOT_FOOD)) end
            base.supplies = (base.supplies or 0) + items / ips
            Rem.Journal.add("IGUI_Rem_Journal_ally_share", Rem.Journal.groupName(g), tostring(items))
            sent = sent + items
        end
    end
    return sent
end

Rem.on("worldHour", function()
    if math.floor(getGameTime():getTimeOfDay()) == CFG.SHARE_HOUR then Rem.safe(AL.share) end
end)
