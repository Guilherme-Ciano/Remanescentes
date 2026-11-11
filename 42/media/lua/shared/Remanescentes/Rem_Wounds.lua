-- Remanescentes - ferimentos que duram dias.
--
-- Um golpe forte (zumbi, saqueador), uma saida que deu errado ou uma horda na base podem
-- deixar um ferimento (rec.wound = { kind, untilH }):
--   perna  manca: so anda (nao corre) e nao sai para buscar ate sarar
--   braco  bate mais fraco e rende metade nas obras
--   corte  sangra: nao recupera a vida sozinho e o moral cai
-- Sara com o tempo. Mais rapido descansando, e muito mais rapido na base com alguem na
-- ENFERMARIA (tarefa "heal") ou um medico - cada nivel de medicina (Rem_Skills) ajuda.
-- O ferimento aparece no humor ("ferido"), na Ficha e no painel da base.
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_Barks"
require "Remanescentes/Rem_Journal"
local Rem = Remanescentes

local WD = Rem.module("Wounds", {
    HOURS = { perna = 72, braco = 48, corte = 24 },
    KINDS = { "perna", "braco", "corte" },
    HEAVY_HIT = 0.3,          -- golpe de pelo menos isso da vida maxima...
    HEAVY_CHANCE = 30,        -- (%) ...pode deixar ferimento
    ARM_DAMAGE = 0.7,
    ARM_WORK = 0.5,
    REST_EXTRA = 0.5,         -- horas a mais saradas por hora descansando
    MEDIC_EXTRA = 1,          -- por hora, com enfermaria/medico na base
    CUT_MORALE = 1,
})
local CFG = WD.CFG

Rem.BARKS.wounded = { urgent = true, n = 3, cd = 0 }
Rem.BARKS.healed = { urgent = true, n = 2, cd = 0 }

local function activeOf(rec)
    for _, npc in pairs(Rem.active) do if npc.rec == rec then return npc end end
    return nil
end

function WD.has(rec, kind)
    local w = rec.wound
    return w ~= nil and (kind == nil or w.kind == kind)
end

function WD.hoursLeft(rec)
    if not rec.wound then return 0 end
    return math.max(0, rec.wound.untilH - Rem.worldHours())
end

-- Fere (tipo sorteado, ou o dado). Um ferimento pior nao e trocado por um mais leve.
function WD.inflict(rec, kind)
    kind = kind or CFG.KINDS[ZombRand(#CFG.KINDS) + 1]
    local untilH = Rem.worldHours() + CFG.HOURS[kind]
    if rec.wound and rec.wound.untilH >= untilH then return rec.wound end
    rec.wound = { kind = kind, untilH = untilH }
    local npc = activeOf(rec)
    if npc then Rem.bark(npc, "wounded", true) end
    if rec.faction == "aliados" then Rem.Journal.add("IGUI_Rem_Journal_wounded", tostring(rec.name), getText("IGUI_Rem_Wound_" .. kind)) end
    return rec.wound
end

function WD.heal(rec)
    rec.wound = nil
    local npc = activeOf(rec)
    if npc then Rem.bark(npc, "healed", true) end
end

-- ---------------------------------------------------------------- efeitos
function WD.blocksTrips(rec) return WD.has(rec, "perna") end
function WD.damageMult(rec) return WD.has(rec, "braco") and CFG.ARM_DAMAGE or 1 end
function WD.workMult(rec) return WD.has(rec, "braco") and CFG.ARM_WORK or 1 end
function WD.noRegen(rec) return WD.has(rec, "corte") end

-- ---------------------------------------------------------------- golpes fortes (em cena)
Rem.on("npcDamaged", function(npc, amount)
    local rec = npc.rec
    if rec.transient then return end
    local maxH = rec.maxHealth or 1
    if amount >= maxH * CFG.HEAVY_HIT and ZombRand(100) < CFG.HEAVY_CHANCE and not npc.z:isDead() then
        WD.inflict(rec)
    end
end)

-- ---------------------------------------------------------------- a cada hora: sarar
-- Quem cuida dos feridos na sua base: tarefa enfermaria ou arquetipo medico.
function WD.careOf(g)
    local best = nil
    if not g then return nil end
    for _, id in ipairs(g.members) do
        local p = Rem.getPerson(id)
        if p and (p.job == "heal" or p.archetype == "medico") and not WD.has(p) then
            if not best or (Rem.Skills and Rem.Skills.level(p, "medicina") > Rem.Skills.level(best, "medicina")) then best = p end
        end
    end
    return best
end

function WD.hourly()
    local store = Rem.getStore()
    local healed = {}
    for _, rec in pairs(store.people) do
        local w = rec.wound
        if w then
            local g = rec.groupId and store.groups[rec.groupId]
            local extra = 0
            if g and g.player then
                local care = WD.careOf(g)
                if care and care ~= rec then
                    extra = CFG.MEDIC_EXTRA * (1 + (Rem.Skills and Rem.Skills.level(care, "medicina") * Rem.Skills.CFG.WOUND_BONUS or 0))
                end
                if rec.job == "rest" then extra = extra + CFG.REST_EXTRA end
            end
            w.untilH = w.untilH - extra
            if w.kind == "corte" and Rem.Persona then Rem.Persona.addMorale(rec, -CFG.CUT_MORALE) end
            if Rem.worldHours() >= w.untilH then table.insert(healed, rec) end
        end
    end
    table.sort(healed, function(a, b) return tostring(a.id) < tostring(b.id) end)
    for _, rec in ipairs(healed) do WD.heal(rec) end
end
Rem.on("worldHour", function() Rem.safe(WD.hourly) end)
