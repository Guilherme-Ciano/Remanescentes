-- Remanescentes - personalidade viva: jeito, historia, humor, moral e luto.
--
-- * Jeito (rec.quirk): falante, ranzinza, otimista, religioso, piadista, calado ou nervoso.
--   Sorteado pela personalidade; muda as falas de quando a pessoa esta a toa.
-- * Historia (rec.story): quem ela perdeu e o que ainda quer. Ela conta em "Me fala de voce"
--   (se confiar em voce); contar cria vinculo (Rem_Bonds).
-- * Humor (PS.mood): ferido, doente, de luto, com fome, animado, abatido ou calmo. Sai do
--   estado real da pessoa e do grupo, aparece na Ficha e muda o que ela resmunga.
-- * Moral (rec.moral, 0-100): sobe com a casa abastecida e zumbis mortos, cai com fome e
--   com a morte de companheiros.
-- * Luto: quando alguem do grupo (ou da familia de passagem, ou um aliado seu) morre, os
--   outros sentem: falam o nome de quem morreu e ficam de luto por um dia.
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_Profile"
require "Remanescentes/Rem_Barks"
require "Remanescentes/Rem_Spawn"
local Rem = Remanescentes

local PS = Rem.module("Persona", {
    GRIEF_HOURS = 24,
    GRIEF_MORALE = 15,
    GRIEF_RADIUS = 25,          -- quem esta a essa distancia do corpo fala na hora
    GRIEF_SPEAKERS = 2,
    HUNGRY_PER_HEAD = 1,        -- suprimentos por pessoa abaixo disso: fome
    MOOD_BARK_CHANCE = 60,      -- (%) fala ociosa sai do humor, se nao estiver calmo
    QUIRK_BARK_CHANCE = 55,     -- (%) senao, sai do jeito
    QUIET_SKIP = 3,             -- calado: fala 1 vez a cada tantas
    MORALE_REST = 60,           -- em casa, abastecido, o moral volta para ca
    MORALE_KILL = 1,
    MORALE_QUEST = 8,
    MORALE_GIFT = 5,
    ABOUT_TRUST = 3,            -- confianca ate isso: so conta a historia para quem conhece
    ABOUT_BOND = 10,
})
local CFG = PS.CFG

PS.QUIRKS = { "falante", "ranzinza", "otimista", "religioso", "piadista", "calado", "nervoso" }
PS.STORY_LOST = 8
PS.STORY_GOAL = 8
PS.MOOD_BARK = { ferido = "idle_ferido", doente = "idle_ferido", luto = "idle_luto", faminto = "idle_faminto",
    animado = "idle_animado", abatido = "idle_abatido", cansado = "idle_cansado" }

for _, q in ipairs(PS.QUIRKS) do
    if q ~= "calado" then Rem.BARKS["idle_" .. q] = { n = 4, cd = 150000 } end
end
for _, cat in ipairs({ "idle_ferido", "idle_luto", "idle_faminto", "idle_animado", "idle_abatido", "idle_cansado" }) do
    Rem.BARKS[cat] = { n = 3, cd = 150000 }
end
Rem.BARKS.grief = { urgent = true, n = 4, cd = 0 }

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

-- ---------------------------------------------------------------- jeito e historia
function PS.rollQuirk(rec)
    local function t(n) return Rem.trait(rec, n) end
    local w = {
        falante = 6 + t("confianca"),
        ranzinza = 4 + t("agressividade") * 1.5,
        otimista = 4 + t("confianca"),
        religioso = (rec.faction == "seita") and 40 or 5,
        piadista = 8,
        calado = 6 + (10 - t("confianca")),
        nervoso = 2 + (10 - t("coragem")) * 2,
    }
    local total = 0
    for _, q in ipairs(PS.QUIRKS) do total = total + w[q] end
    local r = ZombRandFloat(0, total)
    for _, q in ipairs(PS.QUIRKS) do
        r = r - w[q]
        if r <= 0 then return q end
    end
    return PS.QUIRKS[#PS.QUIRKS]
end

function PS.ensure(rec)
    if not rec.quirk then rec.quirk = PS.rollQuirk(rec) end
    if not rec.story then
        rec.story = { lost = ZombRand(1, PS.STORY_LOST + 1), goal = ZombRand(1, PS.STORY_GOAL + 1) }
    end
    return rec
end

Rem.on("personCreated", function(rec) PS.ensure(rec) end)
Rem.on("npcActivated", function(npc) PS.ensure(npc.rec) end)   -- pessoas de saves antigos

-- ---------------------------------------------------------------- humor
local function groupOfRec(rec)
    return rec.groupId and Rem.getStore().groups[rec.groupId] or nil
end

function PS.hungry(rec)
    -- fome de cada um (Rem_Needs: quem segue voce e quem mora na sua base)
    if (rec.fome or 0) >= 60 then return true end
    local g = groupOfRec(rec)
    return g ~= nil and (g.supplies or 0) < #g.members * CFG.HUNGRY_PER_HEAD
end

-- npc e opcional (com corpo, a vida vem dele).
function PS.mood(rec, npc)
    if rec.sick then return "doente" end
    local frac = npc and Rem.healthFraction(npc) or ((rec.hp or 1) / (rec.maxHealth or 1))
    if frac < 0.5 or rec.wound then return "ferido" end
    if rec.griefUntil and Rem.worldHours() < rec.griefUntil then return "luto" end
    if PS.hungry(rec) then return "faminto" end
    if (rec.cansaco or 0) >= 75 then return "cansado" end
    local m = rec.moral or 50
    if m >= 75 then return "animado" end
    if m <= 25 then return "abatido" end
    return "calmo"
end

function PS.addMorale(rec, delta)
    rec.moral = clamp((rec.moral or 50) + delta, 0, 100)
    return rec.moral
end

-- Qual versao da fala usar (gancho de Rem.bark). So mexe nas falas ociosas.
function PS.barkVariant(npc, category, force)
    if category ~= "idle" then return nil end
    local rec = PS.ensure(npc.rec)
    if rec.quirk == "calado" and not force and ZombRand(CFG.QUIET_SKIP) ~= 0 then return false end
    local mood = PS.MOOD_BARK[PS.mood(rec, npc)]
    if mood and ZombRand(100) < CFG.MOOD_BARK_CHANCE then return mood end
    local quirk = "idle_" .. tostring(rec.quirk)
    if Rem.BARKS[quirk] and ZombRand(100) < CFG.QUIRK_BARK_CHANCE then return quirk end
    return nil
end
Rem.barkVariant = PS.barkVariant

-- ---------------------------------------------------------------- "Me fala de voce"
-- Resposta pronta (ja final): quem era, quem perdeu, o que quer. Quem desconfia de todo
-- mundo so conta para quem ja fez algo por ele.
function PS.about(npc)
    local rec = PS.ensure(npc.rec)
    local trusting = rec.faction == "aliados" or Rem.trait(rec, "confianca") > CFG.ABOUT_TRUST
        or (rec.bond or 0) >= CFG.ABOUT_BOND
    if not trusting then return { key = "IGUI_Rem_About_refuse", args = {} } end
    local intro = rec.professionUI and getText("IGUI_Rem_Story_intro", getText(rec.professionUI))
        or getText("IGUI_Rem_Story_intro_none")
    local l = { key = "IGUI_Rem_About", final = true, args = { intro,
        getText("IGUI_Rem_Story_lost_" .. tostring(rec.story.lost)),
        getText("IGUI_Rem_Story_goal_" .. tostring(rec.story.goal)) } }
    if not rec.toldStory then
        rec.toldStory = true
        Rem.emit("playerDeed", "about", npc)
    end
    return l
end

-- ---------------------------------------------------------------- moral
Rem.on("npcKilledZombie", function(npc) PS.addMorale(npc.rec, CFG.MORALE_KILL) end)

Rem.on("playerDeed", function(kind, npc)
    if not npc or not npc.rec then return end
    if kind == "gift" then
        PS.addMorale(npc.rec, CFG.MORALE_GIFT)
    elseif kind == "quest" or kind == "sieged" then
        local g = groupOfRec(npc.rec)
        for _, id in ipairs(g and g.members or {}) do
            local p = Rem.getPerson(id)
            if p then PS.addMorale(p, CFG.MORALE_QUEST) end
        end
    end
end)

-- A cada hora: fome derruba, casa abastecida recupera, luto pesa.
function PS.hourly()
    local hours = Rem.worldHours()
    for _, rec in pairs(Rem.getStore().people) do
        if not rec.transient then
            local m = rec.moral or 50
            if PS.hungry(rec) then
                m = m - 2
            elseif m < CFG.MORALE_REST then
                m = m + 1
            end
            if rec.griefUntil then
                if hours < rec.griefUntil then m = m - 1 else rec.griefUntil, rec.griefFor = nil, nil end
            end
            rec.moral = clamp(m, 0, 100)
        end
    end
end
Rem.on("worldHour", function() Rem.safe(PS.hourly) end)

-- ---------------------------------------------------------------- luto
local function close(dead, rec)
    if rec == dead then return false end
    if dead.groupId and rec.groupId == dead.groupId then return true end
    if dead.faction == "aliados" and rec.faction == "aliados" then return true end
    if rec.followId and rec.followId == dead.id then return true end                 -- lider da familia
    if dead.followId and (rec.id == dead.followId or rec.followId == dead.followId) then return true end
    return false
end

function PS.mourn(dead, x, y)
    local hours = Rem.worldHours()
    local name = tostring(dead.name or "?")
    local speakers = 0
    for _, rec in pairs(Rem.getStore().people) do
        if close(dead, rec) then
            rec.griefUntil = hours + CFG.GRIEF_HOURS
            rec.griefFor = name
            PS.addMorale(rec, -CFG.GRIEF_MORALE)
        end
    end
    Rem.emit("mourned", dead)      -- (amigos sentem mais: Rem_Friends; cronica: Rem_Chronicle)
    if not x then return 0 end
    for _, npc in pairs(Rem.active) do
        if speakers < CFG.GRIEF_SPEAKERS and close(dead, npc.rec) and Rem.canAct(npc)
            and Rem.distXY(npc.z, x, y) <= CFG.GRIEF_RADIUS then
            speakers = speakers + 1
            Rem.say(npc, "IGUI_Rem_Bark_grief_" .. tostring(ZombRand(1, Rem.BARKS.grief.n + 1)), name)
        end
    end
    return speakers
end

Rem.on("npcDied", function(npc)
    local x, y = nil, nil
    pcall(function() x, y = npc.z:getX(), npc.z:getY() end)
    Rem.safe(PS.mourn, npc.rec, x, y)
end)
