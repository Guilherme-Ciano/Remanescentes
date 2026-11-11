-- Remanescentes - conselho da base: com gente suficiente, as decisoes grandes sao votadas.
--
-- Com COUNCIL_MIN moradores ou mais, cada decisao importante passa pelo conselho:
--   newcomer  aceitar alguem novo (visitante, refugiado)
--   prisoner  manter um prisioneiro, ou deixa-lo virar um de nos
--   war       tomar partido numa guerra
--   tribute   pagar saqueadores para deixarem a base em paz
-- Cada morador vota pelo proprio jeito (confianca, agressividade, coragem), pelo moral e
-- pela situacao da base (comida, lotacao). Voce e quem decide no fim - mas contrariar a
-- maioria derruba o moral de quem votou contra; seguir a maioria anima todo mundo.
-- O resultado vai para o Diario e aparece no painel da base.
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_Journal"
local Rem = Remanescentes

local CO = Rem.module("Council", {
    COUNCIL_MIN = 4,
    AGAINST_MORALE = 6,
    FOR_MORALE = 2,
})
local CFG = CO.CFG

CO.KINDS = { "newcomer", "prisoner", "war", "tribute" }

local function t(rec, name) return Rem.trait(rec, name) - 5 end
local function base() return Rem.PlayerBase and Rem.PlayerBase.get() or nil end

local function foodDays(g)
    local n = math.max(1, #g.members)
    return (g.supplies or 0) / n
end

-- O voto de um morador (true = a favor). subject: a pessoa (newcomer/prisoner) ou o grupo.
function CO.opinion(rec, kind, subject, g)
    local s = ((rec.moral or 50) - 50) / 20
    if kind == "newcomer" then
        s = s + t(rec, "confianca") / 2 + ((foodDays(g) >= 2) and 2 or -3) - ((#g.members >= 6) and 1 or 0)
    elseif kind == "prisoner" then
        s = s - 2 + t(rec, "confianca") / 2 - t(rec, "agressividade") / 3
        if subject and subject.talked then s = s + 1 end
    elseif kind == "war" then
        s = s + t(rec, "agressividade") / 2 + t(rec, "coragem") / 3 - 1
    elseif kind == "tribute" then
        s = s - t(rec, "agressividade") / 2 - t(rec, "coragem") / 3 + ((foodDays(g) >= 3) and 1 or -2)
    end
    -- amigos de quem esta chegando votam a favor (Rem_Friends)
    if subject and subject.id and Rem.Friends and Rem.Friends.isFriend(rec, subject) then s = s + 8 end
    return s >= 0
end

-- Vota. Retorna { yes, no, passed } (ou nil sem conselho). A decisao segue (voce decide);
-- o moral sente o resultado.
function CO.vote(kind, subject)
    local g = base()
    if not g then return nil end
    local list = Rem.PlayerBase.members(g)
    if #list < CFG.COUNCIL_MIN then return nil end
    local yes, no, against = 0, 0, {}
    for _, rec in ipairs(list) do
        if rec ~= subject then
            if CO.opinion(rec, kind, subject, g) then yes = yes + 1 else no = no + 1 table.insert(against, rec) end
        end
    end
    local passed = yes >= no
    if passed then
        for _, rec in ipairs(list) do if Rem.Persona then Rem.Persona.addMorale(rec, CFG.FOR_MORALE) end end
        Rem.Journal.add("IGUI_Rem_Journal_council_yes", getText("IGUI_Rem_Council_" .. kind), tostring(yes), tostring(no))
    else
        for _, rec in ipairs(against) do if Rem.Persona then Rem.Persona.addMorale(rec, -CFG.AGAINST_MORALE) end end
        Rem.Journal.add("IGUI_Rem_Journal_council_no", getText("IGUI_Rem_Council_" .. kind), tostring(yes), tostring(no))
    end
    g.lastVote = { kind = kind, yes = yes, no = no, passed = passed, h = Rem.worldHours() }
    Rem.emit("councilVote", kind, yes, no, passed)
    return g.lastVote
end
