-- Remanescentes - habilidades que crescem com o trabalho.
--
-- Cada pessoa da sua base (e quem segue voce) aprende fazendo (rec.skills, nivel 0 a 5):
--   carpintaria  fortificando (obras): rende mais nas obras (+10% por nivel)
--   coleta       saindo para buscar (duplas): traz mais e corre menos risco
--   vigia        no posto: cochila menos e ve mais longe (alarme)
--   medicina     cuidando dos feridos (tarefa "enfermaria"): cura e trata ferimentos mais rapido
-- Manter as mesmas pessoas nas mesmas tarefas compensa. Subir de nivel vai para o Diario.
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_Barks"
require "Remanescentes/Rem_Journal"
local Rem = Remanescentes

local SK = Rem.module("Skills", {
    LEVELS = { 4, 12, 25, 45, 70 },   -- experiencia para cada nivel
    BUILD_XP = 0.5,                   -- por hora fortificando (de dia)
    GUARD_XP = 0.4,                   -- por hora no posto
    HEAL_XP = 0.5,                    -- por hora na enfermaria com alguem ferido
    HEAL_IDLE_XP = 0.1,
    TRIP_XP = 3,                      -- por saida (cada um da dupla)
    BUILD_BONUS = 0.1,                -- por nivel
    TRIP_ITEMS = 0.5,                 -- itens a mais por nivel (o melhor da dupla)
    TRIP_RISK = 0.15,                 -- risco / (1 + nivel * isso)
    WATCH_DOZE = 6,                   -- (%) a menos de cochilar por nivel
    WATCH_RANGE = 1,                  -- tiles a mais de alarme por nivel
    HEAL_BONUS = 0.01,                -- cura a mais por hora por nivel
    WOUND_BONUS = 0.25,               -- ferimentos saram isso mais rapido por nivel
})
local CFG = SK.CFG

SK.LIST = { "carpintaria", "coleta", "vigia", "medicina" }
-- de qual profissao cada um ja comeca sabendo um pouco
-- (engenheiro, medico e furtivo ja tem bonus proprio pelo arquetipo)
SK.START = {
    vigia = { atirador = 1 },
}

Rem.BARKS.skill_up = { urgent = true, n = 3, cd = 0 }

local function daytime()
    local tod = getGameTime():getTimeOfDay()
    return tod >= 7 and tod < 19
end

function SK.levelFor(xp)
    local lvl = 0
    for i, need in ipairs(CFG.LEVELS) do if xp >= need then lvl = i end end
    return lvl
end

function SK.ensure(rec)
    if rec.skills then return rec.skills end
    rec.skills = {}
    for _, s in ipairs(SK.LIST) do
        local start = SK.START[s] and SK.START[s][rec.archetype or ""] or 0
        rec.skills[s] = (start > 0) and CFG.LEVELS[start] or 0
    end
    return rec.skills
end

function SK.level(rec, skill)
    if not rec then return 0 end
    return SK.levelFor(SK.ensure(rec)[skill] or 0)
end

-- Ganha experiencia. Retorna o nivel novo se subiu.
function SK.gain(rec, skill, xp)
    local sk = SK.ensure(rec)
    local before = SK.levelFor(sk[skill] or 0)
    sk[skill] = (sk[skill] or 0) + xp
    local after = SK.levelFor(sk[skill])
    if after > before then
        Rem.Journal.add("IGUI_Rem_Journal_skill_up", tostring(rec.name), getText("IGUI_Rem_Skill_" .. skill), tostring(after))
        for _, npc in pairs(Rem.active) do if npc.rec == rec then Rem.bark(npc, "skill_up", true) end end
        return after
    end
    return nil
end

-- Melhor habilidade (para o painel e a ficha): nome, nivel (ou nil).
function SK.best(rec)
    local best, lvl = nil, 0
    for _, s in ipairs(SK.LIST) do
        local l = SK.level(rec, s)
        if l > lvl then best, lvl = s, l end
    end
    return best, lvl
end

-- "carpintaria 2, coleta 1" (so o que a pessoa ja sabe)
function SK.summary(rec)
    local parts = {}
    for _, s in ipairs(SK.LIST) do
        local l = SK.level(rec, s)
        if l > 0 then table.insert(parts, getText("IGUI_Rem_Skill_" .. s) .. " " .. tostring(l)) end
    end
    return table.concat(parts, ", ")
end

-- ---------------------------------------------------------------- efeitos
function SK.buildMult(rec) return 1 + SK.level(rec, "carpintaria") * CFG.BUILD_BONUS end

function SK.tripBest(rec, partner)
    return math.max(SK.level(rec, "coleta"), partner and SK.level(partner, "coleta") or 0)
end

function SK.tripItems(rec, partner) return math.floor(SK.tripBest(rec, partner) * CFG.TRIP_ITEMS) end
function SK.tripRiskDiv(rec, partner) return 1 + SK.tripBest(rec, partner) * CFG.TRIP_RISK end
function SK.dozeLess(rec) return SK.level(rec, "vigia") * CFG.WATCH_DOZE end
function SK.watchRange(rec) return SK.level(rec, "vigia") * CFG.WATCH_RANGE end

-- ---------------------------------------------------------------- aprender

Rem.on("tripDone", function(g, rec, partner)
    if not g or not g.player then return end
    if rec then SK.gain(rec, "coleta", CFG.TRIP_XP) end
    if partner then SK.gain(partner, "coleta", CFG.TRIP_XP) end
end)

function SK.hourly()
    local PB = Rem.PlayerBase
    local g = PB and PB.get()
    if not g then return end
    local hurt = false
    for _, p in ipairs(PB.members(g)) do
        if (p.hp and p.maxHealth and p.hp < p.maxHealth) or p.wound then hurt = true end
    end
    for _, p in ipairs(PB.members(g)) do
        if p.job == "build" and daytime() then SK.gain(p, "carpintaria", CFG.BUILD_XP)
        elseif p.job == "guard" and (p.role == "guarda") then SK.gain(p, "vigia", CFG.GUARD_XP)
        elseif p.job == "heal" then SK.gain(p, "medicina", hurt and CFG.HEAL_XP or CFG.HEAL_IDLE_XP) end
    end
end
Rem.on("worldHour", function() Rem.safe(SK.hourly) end)
