-- Remanescentes - traumas e vicios de quem anda com voce e de quem mora na sua base.
--
-- rec.trauma = { kind, level } (level 1 a 3; chega a 0 = superou):
--   panico   depois de ver um amigo morrer: na briga a coragem some (foge mais facil)
--   escuro   depois de se ferir de noite: no posto de vigia a noite, cochila/se distrai e
--            perde moral
--   bebida   alguns ja chegam com o vicio; outros comecam no luto. A noite bebe: o moral
--            sobe na hora, a comida da base vai junto, e no dia seguinte esta um caco; de
--            vigia, pode "cochilar" no posto
-- Superar: conversa ("[Conversa] Como voce esta, de verdade?", uma vez por dia, com
-- vinculo) ou dias de moral alto. Pegar e superar vai para o Diario.
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_Barks"
require "Remanescentes/Rem_Journal"
require "Remanescentes/Rem_Wounds"
require "Remanescentes/Rem_Friends"
local Rem = Remanescentes

local TM = Rem.module("Traumas", {
    KINDS = { "panico", "escuro", "bebida" },
    START_LEVEL = 3,
    PANIC_CHANCE = 40,        -- (%) ao perder um amigo
    DARK_CHANCE = 20,         -- (%) ao se ferir de noite
    DRINK_START = 8,          -- (%) ja chega bebendo (ao vir morar na base)
    DRINK_GRIEF = 15,         -- (%) comeca a beber no luto
    PANIC_NERVE = 0.6,
    DARK_DOZE = 25,
    DRINK_DOZE = 15,
    DARK_MORALE = 2,          -- por hora de vigia no escuro
    DRINK_HOUR = 21,
    DRINK_MORALE = 8,
    DRINK_TIRED = 25,
    DRINK_FOOD = 0.5,
    TALK_HOURS = 20,
    TALK_BOND = 10,
    GOOD_MORALE = 70,         -- dias com moral assim podem curar sozinhos
    GOOD_DAY_CHANCE = 30,
})
local CFG = TM.CFG

Rem.BARKS.trauma_panic = { urgent = true, n = 3, cd = 60000 }
Rem.BARKS.trauma_dark = { n = 3, cd = 120000 }
Rem.BARKS.trauma_drink = { urgent = true, n = 3, cd = 0 }

local function line(key, ...) return { key = key, args = { ... } } end
local function activeOf(rec)
    for _, npc in pairs(Rem.active) do if npc.rec == rec then return npc end end
    return nil
end
local function night()
    local tod = getGameTime():getTimeOfDay()
    return tod >= 21 or tod < 6
end

function TM.has(rec, kind)
    local t = rec.trauma
    return t ~= nil and t.level > 0 and (kind == nil or t.kind == kind)
end

-- Pega um trauma (so um por vez; um novo nao troca o que ja tem).
function TM.give(rec, kind)
    if rec.trauma or rec.faction ~= "aliados" then return false end
    rec.trauma = { kind = kind, level = CFG.START_LEVEL }
    Rem.Journal.add("IGUI_Rem_Journal_trauma", tostring(rec.name), getText("IGUI_Rem_Trauma_" .. kind))
    return true
end

function TM.ease(rec, n)
    local t = rec.trauma
    if not t then return false end
    t.level = t.level - (n or 1)
    if t.level <= 0 then
        rec.trauma = nil
        Rem.Journal.add("IGUI_Rem_Journal_trauma_over", tostring(rec.name), getText("IGUI_Rem_Trauma_" .. t.kind))
        return true
    end
    return false
end

-- ---------------------------------------------------------------- efeitos
function TM.nerveMult(rec) return TM.has(rec, "panico") and CFG.PANIC_NERVE or 1 end

function TM.dozeExtra(rec)
    if TM.has(rec, "escuro") then return CFG.DARK_DOZE end
    if TM.has(rec, "bebida") then return CFG.DRINK_DOZE end
    return 0
end

-- ---------------------------------------------------------------- de onde vem
local function mine(rec)
    return rec.faction == "aliados" and not rec.transient
end

Rem.on("mourned", function(dead)
    if not dead or not dead.rel then return end
    for id, v in pairs(dead.rel) do
        local p = Rem.getPerson(id)
        if p and mine(p) and Rem.Friends and v >= Rem.Friends.CFG.FRIEND then
            if ZombRand(100) < CFG.PANIC_CHANCE then TM.give(p, "panico")
            elseif ZombRand(100) < CFG.DRINK_GRIEF then TM.give(p, "bebida") end
        end
    end
end)

if Rem.Wounds then
    local inflict = Rem.Wounds.inflict
    Rem.Wounds.inflict = function(rec, kind)
        local w = inflict(rec, kind)
        if w and night() and mine(rec) and ZombRand(100) < CFG.DARK_CHANCE then TM.give(rec, "escuro") end
        return w
    end
end

Rem.on("playerBaseMember", function(g, rec)
    if rec and not rec.traumaRolled then
        rec.traumaRolled = true
        if ZombRand(100) < CFG.DRINK_START then TM.give(rec, "bebida") end
    end
end)

-- ---------------------------------------------------------------- a cada hora
function TM.hourly()
    local tod = math.floor(getGameTime():getTimeOfDay())
    local base = Rem.PlayerBase and Rem.PlayerBase.get()
    for _, rec in pairs(Rem.getStore().people) do
        local t = rec.trauma
        if t and t.level > 0 then
            local lit = Rem.Fuel and base and Rem.Fuel.lit(base)                  -- (com luz, o escuro pesa menos)
            if t.kind == "escuro" and not lit and Rem.Watch and Rem.Watch.onWatch(rec) and Rem.Persona then
                Rem.Persona.addMorale(rec, -CFG.DARK_MORALE)
                local npc = activeOf(rec)
                if npc then Rem.bark(npc, "trauma_dark") end
            elseif t.kind == "bebida" and tod == CFG.DRINK_HOUR then
                if Rem.Persona then Rem.Persona.addMorale(rec, CFG.DRINK_MORALE) end
                rec.cansaco = math.min(100, (rec.cansaco or 0) + CFG.DRINK_TIRED)
                if base and rec.groupId == base.id then base.supplies = math.max(0, (base.supplies or 0) - CFG.DRINK_FOOD) end
                local npc = activeOf(rec)
                if npc then Rem.bark(npc, "trauma_drink", true) end
            end
            -- dias bons ajudam a superar (uma vez por dia, de manha)
            if tod == 8 and (rec.moral or 50) >= CFG.GOOD_MORALE and ZombRand(100) < CFG.GOOD_DAY_CHANCE then TM.ease(rec) end
        end
    end
end
Rem.on("worldHour", function() Rem.safe(TM.hourly) end)

-- Panico na briga: fala (o cerebro ja foge mais facil pela coragem baixa).
Rem.on("npcDamaged", function(npc)
    if TM.has(npc.rec, "panico") then Rem.bark(npc, "trauma_panic") end
end)

-- ---------------------------------------------------------------- conversa
function TM.canTalk(npc)
    local rec = npc.rec
    if not TM.has(rec) or rec.faction ~= "aliados" then return false end
    return not rec.traumaTalkAt or Rem.worldHours() - rec.traumaTalkAt >= CFG.TALK_HOURS
end

function TM.talk(npc)
    local rec = npc.rec
    local t = rec.trauma
    if not t then return false, line("IGUI_Rem_Trauma_fine") end
    rec.traumaTalkAt = Rem.worldHours()
    if (rec.bond or 0) < CFG.TALK_BOND then
        return false, line("IGUI_Rem_Trauma_closed_" .. t.kind)
    end
    local kind = t.kind
    local over = TM.ease(rec)
    if Rem.Persona then Rem.Persona.addMorale(rec, 3) end
    if over then return true, line("IGUI_Rem_Trauma_over_" .. kind) end
    return true, line("IGUI_Rem_Trauma_talk_" .. kind)
end

function TM.hint(npc)
    return line("IGUI_Rem_Hint_bond", tostring(math.floor(npc.rec.bond or 0)), tostring(CFG.TALK_BOND))
end
