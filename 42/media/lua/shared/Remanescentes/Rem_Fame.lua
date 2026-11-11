-- Remanescentes - fama: o que voce faz vira o seu apelido.
--
-- O mod conta os seus feitos (store.fame): gente salva, saqueadores mortos, inocentes
-- mortos, missoes, trocas, ameacas, caravanas defendidas, prisioneiros soltos. Quando um
-- feito passa do limite, voce ganha um apelido ("o que salva gente", "o cacador de
-- saqueadores", "o que mata gente"...). O apelido mais forte e a sua fama:
--   * quem nunca te viu ja chega sabendo ("Voce e o tal que salva gente?");
--   * muda a primeira impressao (atitude, Rem_Reputation): salvar gente abre portas; matar
--     inocentes fecha; saqueadores odeiam o cacador deles (e se rendem mais facil);
--   * aparece no Diario.
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_Journal"
local Rem = Remanescentes

local FM = Rem.module("Fame", {
    GREET_HOURS = 0,          -- (cada pessoa comenta a sua fama uma vez)
})
local CFG = FM.CFG

-- titulo = { conta, limite, peso (forca do apelido), atitude por faccao }
FM.TITLES = {
    { id = "salvador", count = "saved", need = 5, weight = 3, mod = { default = 12, saqueadores = 0 } },
    { id = "cacador", count = "raiders", need = 8, weight = 3, mod = { default = 8, saqueadores = -20 } },
    { id = "assassino", count = "innocents", need = 2, weight = 5, mod = { default = -25, saqueadores = 10 } },
    { id = "vizinho", count = "quests", need = 4, weight = 2, mod = { default = 10 } },
    { id = "mercador", count = "traded", need = 8, weight = 1, mod = { default = 5 } },
    { id = "ameaca", count = "threatened", need = 3, weight = 2, mod = { default = -12, saqueadores = 5 } },
    { id = "protetor", count = "caravans", need = 2, weight = 2, mod = { default = 10, saqueadores = -10 } },
    { id = "lider", count = "people", need = 5, weight = 1, mod = { default = 5 } },
}

local DEED_COUNT = { saved = "saved", rescued = "saved", sieged = "saved", quest = "quests", traded = "traded",
    threatened = "threatened" }

function FM.store()
    local s = Rem.getStore()
    s.fame = s.fame or { counts = {}, titles = {} }
    return s.fame
end

function FM.count(kind) return FM.store().counts[kind] or 0 end

local function titleDef(id)
    for _, t in ipairs(FM.TITLES) do if t.id == id then return t end end
    return nil
end

-- Soma um feito. Retorna o titulo novo, se ganhou um.
function FM.add(kind, n)
    local f = FM.store()
    f.counts[kind] = (f.counts[kind] or 0) + (n or 1)
    for _, t in ipairs(FM.TITLES) do
        if t.count == kind and not f.titles[t.id] and f.counts[kind] >= t.need then
            f.titles[t.id] = Rem.worldHours()
            Rem.Journal.add("IGUI_Rem_Journal_fame", getText("IGUI_Rem_Fame_" .. t.id))
            Rem.emit("fameTitle", t.id)
            return t.id
        end
    end
    return nil
end

-- O apelido mais forte (id) ou nil.
function FM.title()
    local best, bestW = nil, 0
    for id in pairs(FM.store().titles) do
        local t = titleDef(id)
        if t and t.weight > bestW then best, bestW = id, t.weight end
    end
    return best
end

-- Quanto a fama muda a primeira impressao desta pessoa.
function FM.attitudeMod(rec)
    local total = 0
    for id in pairs(FM.store().titles) do
        local t = titleDef(id)
        if t then
            local v = t.mod[rec.faction]
            if v == nil then v = t.mod.default or 0 end
            total = total + v
        end
    end
    return total
end

-- Primeira conversa com alguem que ja ouviu falar de voce.
function FM.greeting(npc)
    local rec = npc.rec
    if rec.faction == "aliados" or rec.heardFame then return nil end
    local id = FM.title()
    if not id then return nil end
    rec.heardFame = true
    return { key = "IGUI_Rem_Fame_hi_" .. id, args = {} }
end

-- ---------------------------------------------------------------- de onde vem
Rem.on("playerDeed", function(kind)
    local c = DEED_COUNT[kind]
    if c then FM.add(c) end
end)

-- (Rem_Reputation avisa quem voce matou e se a pessoa era hostil naquela hora)
Rem.on("playerKilled", function(npc, wasHostile)
    local rec = npc.rec
    if rec.surrendered or rec.prisoner then FM.add("innocents") return end      -- matar quem se rendeu
    if Rem.factionDef(rec.faction).hostileToPlayer then FM.add("raiders")
    elseif not wasHostile then FM.add("innocents") end
end)

Rem.on("journalAdded", function(e)
    if e and e.key == "IGUI_Rem_Journal_caravan_saved" then FM.add("caravans") end
end)

Rem.on("playerBaseMember", function(g)
    local f = FM.store()
    local n = #g.members
    if n > (f.counts.people or 0) then FM.add("people", n - (f.counts.people or 0)) end
end)
