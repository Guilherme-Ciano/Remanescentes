-- Remanescentes - a sua faccao: nome, pactos e tributo.
--
--   * Nome: de um nome ao seu grupo (clique direito -> "Dar um nome ao seu grupo", ou no
--     painel da base). Aparece no mapa, no Diario e nas falas de quem ouve falar de voces.
--   * Pacto de respeito: com um grupo que nao te odeia ("[Diplomacia] Vamos respeitar o
--     territorio um do outro."): a relacao entre o grupo deles e o seu sobe e eles nunca
--     atacam a sua base enquanto o pacto durar (acaba se a reputacao despencar).
--   * Tributo: saqueador rendido ou preso leva o recado ("[Diplomacia] Diga ao seu bando:
--     pagamos para nos deixarem em paz."): sai comida do estoque e o bando nao ataca a sua
--     base por TRIBUTE_DAYS dias. Depois, eles voltam a cobrar. (O conselho vota.)
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_Journal"
require "Remanescentes/Rem_Relations"
local Rem = Remanescentes

local DP = Rem.module("Diplomacy", {
    PACT_REP = 0,             -- reputacao minima para um pacto
    PACT_RELATION = 30,
    PACT_BREAK = -20,
    TRIBUTE = 4,              -- suprimentos
    TRIBUTE_DAYS = 7,
    NAME_MAX = 30,
})
local CFG = DP.CFG

local function line(key, ...) return { key = key, args = { ... } } end
local function base() return Rem.PlayerBase and Rem.PlayerBase.get() or nil end
local function groupOf(rec) return rec.groupId and Rem.getStore().groups[rec.groupId] or nil end

-- ---------------------------------------------------------------- nome
function DP.name()
    local g = base()
    return g and g.name or nil
end

function DP.rename(name)
    local g = base()
    if not g or type(name) ~= "string" then return false end
    name = name:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%%", "")
    if name == "" then return false end
    if #name > CFG.NAME_MAX then name = name:sub(1, CFG.NAME_MAX) end
    g.name = name
    g.named = true
    local m = Rem.MapMarks and Rem.MapMarks.find("playerbase:" .. tostring(g.home.bid))
    if m then m.text = name end
    Rem.Journal.add("IGUI_Rem_Journal_named", name)
    Rem.emit("factionNamed", name)
    return true
end

-- ---------------------------------------------------------------- pacto
function DP.hasPact(g) return g ~= nil and g.pact == true end

-- Tributo pago e ainda valendo.
function DP.paid(g) return g ~= nil and g.tributeUntil ~= nil and Rem.worldHours() < g.tributeUntil end

-- Este grupo deixa a sua base em paz?
function DP.protectedFrom(g) return DP.hasPact(g) or DP.paid(g) end

function DP.canPact(npc)
    local g = groupOf(npc.rec)
    return g ~= nil and base() ~= nil and not g.player and not g.pact and not g.allied and g.faction ~= "saqueadores"
        and not Rem.isHostileToPlayer(npc) and not npc.rec.prisoner
end

function DP.pact(npc)
    local g = groupOf(npc.rec)
    local b = base()
    if not g or not b then return false, line("IGUI_Rem_Base_none") end
    if Rem.getRep(g.id) < CFG.PACT_REP then return false, line("IGUI_Rem_Pact_no") end
    g.pact = true
    Rem.changeRelation(g, b, CFG.PACT_RELATION)
    Rem.Journal.add("IGUI_Rem_Journal_pact", Rem.Journal.groupName(g))
    return true, line("IGUI_Rem_Pact_yes", tostring(b.name))
end

function DP.pactHint(npc)
    local g = groupOf(npc.rec)
    return line("IGUI_Rem_Hint_rep", tostring(math.floor(g and Rem.getRep(g.id) or 0)), tostring(CFG.PACT_REP))
end

-- Pacto acaba se voce fizer algo grave contra eles.
Rem.on("reputationChanged", function(key, old, new)
    local g = Rem.getStore().groups[key]
    if g and g.pact and new < CFG.PACT_BREAK then
        g.pact = nil
        Rem.Journal.add("IGUI_Rem_Journal_pact_broken", Rem.Journal.groupName(g))
    end
end)

-- ---------------------------------------------------------------- tributo
local function bandOf(rec)
    local id = rec.bandId or rec.groupId or rec.fromBand
    local g = id and Rem.getStore().groups[id]
    if g and g.faction == "saqueadores" and #g.members > 0 then return g end
    return nil
end

function DP.canTribute(npc)
    local rec = npc.rec
    return (rec.surrendered or rec.prisoner) and base() ~= nil and bandOf(rec) ~= nil and not DP.paid(bandOf(rec))
end

function DP.tribute(npc)
    local b = base()
    local band = bandOf(npc.rec)
    if not b or not band then return false, line("IGUI_Rem_Prisoner_noband") end
    if (b.supplies or 0) < CFG.TRIBUTE then return false, line("IGUI_Rem_Tribute_poor", tostring(CFG.TRIBUTE)) end
    if Rem.Council then Rem.Council.vote("tribute", band) end
    b.supplies = b.supplies - CFG.TRIBUTE
    band.supplies = (band.supplies or 0) + CFG.TRIBUTE
    band.tributeUntil = Rem.worldHours() + CFG.TRIBUTE_DAYS * 24
    band.tributeNoted = nil
    Rem.Journal.add("IGUI_Rem_Journal_tribute", Rem.Journal.groupName(band), tostring(CFG.TRIBUTE_DAYS))
    return true, line("IGUI_Rem_Tribute_ok", tostring(CFG.TRIBUTE_DAYS))
end

-- O prazo acabou: eles voltam a cobrar.
function DP.hourly()
    for _, g in pairs(Rem.getStore().groups) do
        if g.tributeUntil and Rem.worldHours() >= g.tributeUntil and not g.tributeNoted then
            g.tributeNoted = true
            g.tributeUntil = nil
            Rem.Journal.add("IGUI_Rem_Journal_tribute_over", Rem.Journal.groupName(g))
        end
    end
end
Rem.on("worldHour", function() Rem.safe(DP.hourly) end)

-- ---------------------------------------------------------------- conversa
function DP.dialogOptions(npc)
    local out = {}
    if DP.canPact(npc) then table.insert(out, "pact") end
    if DP.canTribute(npc) then table.insert(out, "tribute") end
    return out
end

-- Relacoes da sua faccao (para o painel): pactos, tributos, aliados, inimigos.
function DP.summary()
    local pacts, paid, allies = {}, {}, {}
    for _, g in pairs(Rem.getStore().groups) do
        if g.pact then table.insert(pacts, Rem.Journal.groupName(g)) end
        if DP.paid(g) then table.insert(paid, Rem.Journal.groupName(g)) end
        if g.allied then table.insert(allies, Rem.Journal.groupName(g)) end
    end
    table.sort(pacts) table.sort(paid) table.sort(allies)
    return { pacts = pacts, paid = paid, allies = allies }
end
