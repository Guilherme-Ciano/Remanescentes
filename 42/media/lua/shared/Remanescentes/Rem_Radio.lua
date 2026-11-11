-- Remanescentes - o radio de pilha: o mundo falando no ar.
--
-- Com um radio no inventario (qualquer item "Radio": de pilha, walkie-talkie...), de tempos
-- em tempos voce pega uma transmissao (aparece na tela e no Diario como "Radio: ..."):
--   militar   nos primeiros dias: avisos oficiais; a barreira militar e citada (e marcada no
--             mapa). Depois, so chiado.
--   socorro   um grupo cercado ou passando fome pede ajuda (o grupo vai para o mapa).
--   bando     saqueadores se gabando no ar - e entregando onde estao.
--   rumor     alguem fala de algo que viu (uma caravana, um lugar abandonado...).
--   conversa  gente comum: medo, saudade, piadas ruins. Ninguem esta sozinho.
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_Journal"
require "Remanescentes/Rem_MapMarks"
local Rem = Remanescentes

local RD = Rem.module("Radio", {
    EVERY_HOURS = 3,
    CHANCE = 60,
    MILITARY_DAYS = 6,
    STATIC_DAYS = 12,         -- depois disso, o militar so chia
    RANGE = 900,              -- grupos a ate isso podem aparecer
    CHATTER_N = 6,
    MILITARY_N = 4,
})
local CFG = RD.CFG

function RD.hasRadio(player)
    if not player then return false end
    local found = false
    pcall(function()
        local items = player:getInventory():getItems()
        for i = 0, items:size() - 1 do
            if tostring(items:get(i):getFullType()):find("Radio", 1, true) or tostring(items:get(i):getFullType()):find("WalkieTalkie", 1, true) then
                found = true
                break
            end
        end
    end)
    return found
end

local function day()
    local t = Rem.getStore().timeline
    if not t or not t.startHours then return 0 end
    return (Rem.worldHours() - t.startHours) / 24
end

local function near(player, filter)
    local list = {}
    for _, g in pairs(Rem.getStore().groups) do
        if g.home and not g.player and #g.members > 0 and filter(g)
            and Rem.dist2(player:getX(), player:getY(), g.home.x, g.home.y) <= CFG.RANGE then
            table.insert(list, g)
        end
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

local function reveal(g)
    local s = Rem.getStore()
    s.knownGroups = s.knownGroups or {}
    s.knownGroups[g.id] = true
    Rem.MapMarks.markGroup(g, nil)
end

-- ---------------------------------------------------------------- tipos de transmissao
RD.KINDS = {}

function RD.KINDS.military(player)
    local d = day()
    if d >= CFG.STATIC_DAYS then return "IGUI_Rem_Radio_static" end
    if d >= CFG.MILITARY_DAYS then return nil end
    local cp = Rem.Military and Rem.Military.get()
    if cp and cp.state == "manned" then return "IGUI_Rem_Radio_checkpoint" end
    return "IGUI_Rem_Radio_military_" .. tostring(ZombRand(1, CFG.MILITARY_N + 1))
end

function RD.KINDS.distress(player)
    local s = Rem.getStore().siege
    local g = s and Rem.getStore().groups[s.group]
    if not g then
        local list = near(player, function(x) return x.faction ~= "saqueadores" and (x.supplies or 0) < #x.members end)
        g = list[1]
    end
    if not g then return nil end
    reveal(g)
    return "IGUI_Rem_Radio_distress", Rem.Journal.groupName(g)
end

function RD.KINDS.raiders(player)
    local list = near(player, function(x) return x.faction == "saqueadores" end)
    if #list == 0 then return nil end
    local g = list[ZombRand(#list) + 1]
    reveal(g)
    return "IGUI_Rem_Radio_raiders", Rem.Journal.groupName(g)
end

function RD.KINDS.rumor(player)
    local cv = Rem.Caravans and Rem.Caravans.list()[1]
    if cv then
        local from = Rem.getStore().groups[cv.from]
        return "IGUI_Rem_Radio_rumor_caravan", from and Rem.Journal.groupName(from) or "?"
    end
    for _, w in ipairs(Rem.War and Rem.War.list() or {}) do
        local a, b = Rem.getStore().groups[w.a], Rem.getStore().groups[w.b]
        if a and b then return "IGUI_Rem_Radio_rumor_war", Rem.Journal.groupName(a), Rem.Journal.groupName(b) end
    end
    return nil
end

function RD.KINDS.chatter()
    return "IGUI_Rem_Radio_chatter_" .. tostring(ZombRand(1, CFG.CHATTER_N + 1))
end

RD.ORDER = { "military", "distress", "raiders", "rumor", "chatter" }

-- Pega uma transmissao (kind forcado opcional). Retorna o tipo e a entrada do diario.
function RD.listen(player, kind)
    local kinds = {}
    if kind then kinds = { kind } else
        -- comeca num tipo sorteado e tenta os seguintes ate um ter algo a dizer
        local start = ZombRand(#RD.ORDER) + 1
        for i = 0, #RD.ORDER - 1 do table.insert(kinds, RD.ORDER[((start - 1 + i) % #RD.ORDER) + 1]) end
    end
    for _, k in ipairs(kinds) do
        local key, a, b = RD.KINDS[k](player)
        if key then
            local e = Rem.Journal.add(key, a or "", b or "")
            Rem.emit("radioHeard", k, key)
            return k, e
        end
    end
    return nil
end

function RD.hourly()
    local player = getPlayer()
    if not RD.hasRadio(player) then return end
    local s = Rem.getStore()
    local h = math.floor(Rem.worldHours())
    if s.radioLastH and h - s.radioLastH < CFG.EVERY_HOURS then return end
    s.radioLastH = h
    if ZombRand(100) < CFG.CHANCE then RD.listen(player) end
end
Rem.on("worldHour", function() Rem.safe(RD.hourly) end)
