-- Remanescentes - a cronica da sua campanha: marcos que viram capitulos no Diario.
--
-- Cada marco acontece uma vez so e fica guardado com o dia: "A primeira noite", "Alguem
-- do seu lado", "Um lugar para chamar de casa", "A cerca ficou pronta", "O primeiro
-- adeus"... Aparece na tela quando acontece e no topo do Diario (secao Cronica).
-- Para outros mods: Rem.Chronicle.unlock("meu_marco") (com IGUI_Rem_Chapter_meu_marco).
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_Journal"
local Rem = Remanescentes

local CH = Rem.module("Chronicle", {
    BIG_BASE = 5,
})
local CFG = CH.CFG

-- ordem em que aparecem na lista de marcos possiveis (traducao: IGUI_Rem_Chapter_<k>)
CH.ALL = { "night1", "first_ally", "base", "first_work", "fence", "alarm", "first_loss", "prisoner", "alliance",
    "friends", "horde_held", "raid_held", "siege", "five", "war", "caravan", "refugee", "fame", "named", "reunion", "harvest", "checkpoint", "convoy", "doctor", "week1", "month1" }

-- entradas do diario que marcam um capitulo
CH.FROM_JOURNAL = {
    IGUI_Rem_Journal_prisoner_taken = "prisoner", IGUI_Rem_Journal_ally = "alliance",
    IGUI_Rem_Journal_alarm_zombies = "alarm", IGUI_Rem_Journal_alarm_people = "alarm",
    IGUI_Rem_Journal_ev_raid_held = "raid_held", IGUI_Rem_Journal_ev_horde_held = "horde_held",
    IGUI_Rem_Journal_friends = "friends", IGUI_Rem_Journal_siege_won = "siege",
    IGUI_Rem_Journal_fame = "fame", IGUI_Rem_Journal_named = "named", IGUI_Rem_Journal_pq_reunion = "reunion",
    IGUI_Rem_Journal_pq_harvest = "harvest",
    IGUI_Rem_Journal_checkpoint_found = "checkpoint", IGUI_Rem_Journal_rare_convoy_found = "convoy",
    IGUI_Rem_Journal_rare_doctor = "doctor",
    IGUI_Rem_Journal_war_side = "war", IGUI_Rem_Journal_caravan_saved = "caravan", IGUI_Rem_Journal_refugee_base = "refugee",
}

function CH.list()
    local s = Rem.getStore()
    s.chronicle = s.chronicle or {}
    return s.chronicle
end

function CH.has(k)
    for _, e in ipairs(CH.list()) do if e.k == k then return true end end
    return false
end

-- Abre um capitulo (uma vez). Retorna a entrada ou nil.
function CH.unlock(k)
    if CH.has(k) then return nil end
    local e = { k = k, h = Rem.worldHours() }
    table.insert(CH.list(), e)
    -- aparece na tela (nao entra na lista de acontecimentos: tem secao propria no Diario)
    local player = getPlayer()
    if player then
        Rem.safe(function() HaloTextHelper.addText(player, getText("IGUI_Rem_Journal_chapter", getText("IGUI_Rem_Chapter_" .. k))) end)
    end
    Rem.emit("chapter", k)
    return e
end

-- Dia da campanha (1 = o primeiro) de uma hora do mundo.
function CH.dayOf(h)
    local start = (Rem.getStore().timeline and Rem.getStore().timeline.startHours) or 0
    return math.max(1, math.floor((h - start) / 24) + 1)
end

-- ---------------------------------------------------------------- de onde vem
Rem.on("journalAdded", function(e)
    local k = e and CH.FROM_JOURNAL[e.key]
    if k then CH.unlock(k) end
end)
Rem.on("playerDeed", function(kind) if kind == "recruited" then CH.unlock("first_ally") end end)
Rem.on("playerBaseSet", function() CH.unlock("base") end)
Rem.on("baseProjectDone", function(g, project)
    if not g or not g.player then return end
    CH.unlock("first_work")
    if project == "perimeter" then CH.unlock("fence") end
end)
Rem.on("mourned", function(dead) if dead and dead.faction == "aliados" then CH.unlock("first_loss") end end)
Rem.on("playerBaseMember", function(g) if g and #g.members >= CFG.BIG_BASE then CH.unlock("five") end end)

function CH.hourly()
    local t = Rem.getStore().timeline
    if not t or not t.startHours then return end
    local day = (Rem.worldHours() - t.startHours) / 24      -- dias passados (sem acelerar)
    if day >= 1 then CH.unlock("night1") end
    if day >= 7 then CH.unlock("week1") end
    if day >= 30 then CH.unlock("month1") end
end
Rem.on("worldHour", function() Rem.safe(CH.hourly) end)
