-- Remanescentes - necessidades de quem anda com voce e de quem mora na sua base.
--
-- Fome (rec.fome) e cansaco (rec.cansaco), de 0 a 100, sobem com as horas:
--   * morador da sua base: come do estoque da base (sem comida, a fome sobe); dorme a noite
--     (quem esta de vigia nao dorme - Rem_Watch); quem sai para buscar cansa mais.
--   * quem segue voce: come o que tiver nos bolsos; depois pede ("Tem alguma coisa para
--     comer?"). Voce da comida na conversa ("[Comida] Toma, come isto."). Descansa quando
--     voce dorme, quando fica esperando a noite, ou quando voce manda ("[Descanso] Tira um
--     cochilo."; deita ali mesmo por algumas horas).
-- Fome e cansaco altos derrubam o moral e a forca na briga (dano e pontaria). Com fome
-- demais e o moral no chao, quem segue voce vai embora.
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_Barks"
require "Remanescentes/Rem_Journal"
local Rem = Remanescentes

local ND = Rem.module("Needs", {
    HUNGER_RATE = 3,          -- por hora (sem comer: ~1 dia e meio ate 100)
    BASE_EAT = 6,             -- por hora, morador com comida no estoque
    POCKET_EAT_AT = 50,       -- come dos bolsos a partir disso
    FOOD_VALUE = 55,          -- quanto um item de comida tira da fome
    TIRED_RATE = 2.5,         -- por hora acordado
    WORK_TIRED = 1.5,         -- a mais por hora para quem trabalha pesado (buscas, obras)
    WATCH_TIRED = 3,          -- a mais por hora de vigia
    SLEEP_RECOVER = 12,       -- por hora dormindo
    REST_RECOVER = 5,         -- por hora descansando de dia (tarefa "descansar")
    NAP_HOURS = 4,
    ASK_FOOD_AT = 60,
    ASK_SLEEP_AT = 75,
    ASK_HOURS = 4,            -- pede de novo depois de tantas horas
    HUNGRY_MORALE = 2,        -- moral perdido por hora com fome >= ASK_FOOD_AT
    STARVING = 90,
    STARVING_MORALE = 4,
    TIRED_MORALE = 1,
    WEAK_HUNGER = 80,         -- a partir disso: mais fraco na briga
    WEAK_TIRED = 80,
    WEAK_HUNGER_MULT = 0.85,
    WEAK_TIRED_MULT = 0.8,
    WEAK_ACCURACY = 10,       -- pontos de pontaria perdidos (cada um)
    DESERT_MORALE = 10,       -- moral ate isso e fome >= STARVING: vai embora
    FEED_BOND = 4,
    FEED_MORALE = 4,
    NAP_PRIORITY = 95,        -- antes de seguir voce (100)
    SHOW_FEED_AT = 25,        -- a opcao de dar comida aparece com fome a partir disso
    SHOW_NAP_AT = 50,
})
local CFG = ND.CFG

Rem.BARKS.need_food = { urgent = true, n = 3, cd = 0 }
Rem.BARKS.need_sleep = { urgent = true, n = 3, cd = 0 }
Rem.BARKS.ate = { urgent = true, n = 3, cd = 0 }
Rem.BARKS.desert = { urgent = true, n = 2, cd = 0 }
Rem.BARKS.wake = { urgent = true, n = 2, cd = 15000 }

local function line(key, ...) return { key = key, args = { ... } } end
local function clamp(v) return math.max(0, math.min(100, v)) end
local function night()
    local tod = getGameTime():getTimeOfDay()
    return tod >= 22 or tod < 6
end

local function activeOf(rec)
    for _, npc in pairs(Rem.active) do if npc.rec == rec then return npc end end
    return nil
end

local function isFood(item)
    local food, cat = false, ""
    pcall(function() food = item:isFood() end)
    pcall(function() cat = item:getDisplayCategory() or "" end)
    return food or cat == "Food"
end

-- ---------------------------------------------------------------- quem tem necessidades
function ND.tracked(rec)
    return rec.faction == "aliados" and not rec.transient and not rec.prisoner
end

function ND.baseOf(rec)
    if not rec.groupId then return nil end
    local g = Rem.getStore().groups[rec.groupId]
    if g and g.player then return g end
    return nil
end

function ND.isFollower(rec) return ND.tracked(rec) and not rec.groupId end

function ND.hunger(rec) return rec.fome or 0 end
function ND.tired(rec) return rec.cansaco or 0 end

-- Esta dormindo agora? (morador a noite sem vigia, ou cochilo mandado por voce)
function ND.sleeping(rec)
    if rec.napUntil and Rem.worldHours() < rec.napUntil then return true end
    local g = ND.baseOf(rec)
    if g and night() and not (Rem.Watch and Rem.Watch.onWatch(rec)) and rec.mode == "group" then
        return not (g.alarmUntilH and Rem.worldHours() < g.alarmUntilH)
    end
    return false
end

-- ---------------------------------------------------------------- efeitos
-- Multiplicador de dano (Rem_Combat) e pontos de pontaria a menos (Rem_Ranged).
function ND.damageMult(rec)
    local m = 1
    if ND.hunger(rec) >= CFG.WEAK_HUNGER then m = m * CFG.WEAK_HUNGER_MULT end
    if ND.tired(rec) >= CFG.WEAK_TIRED then m = m * CFG.WEAK_TIRED_MULT end
    return m
end

function ND.accuracyPenalty(rec)
    local p = 0
    if ND.hunger(rec) >= CFG.WEAK_HUNGER then p = p + CFG.WEAK_ACCURACY end
    if ND.tired(rec) >= CFG.WEAK_TIRED then p = p + CFG.WEAK_ACCURACY end
    return p
end

-- ---------------------------------------------------------------- comer
-- Come algo dos bolsos. Retorna true se comeu.
function ND.eatPocket(rec)
    for i, ft in ipairs(rec.pockets or {}) do
        local item = nil
        pcall(function() item = instanceItem(ft) end)
        if item and isFood(item) then
            table.remove(rec.pockets, i)
            rec.fome = clamp(ND.hunger(rec) - CFG.FOOD_VALUE)
            return true
        end
    end
    return false
end

local function playerFood(player)
    local items = player:getInventory():getItems()
    for i = 0, items:size() - 1 do
        local it = items:get(i)
        local skip = false
        pcall(function() skip = it:isEquipped() or it:isFavorite() end)
        if not skip and isFood(it) then return it end
    end
    return nil
end

function ND.canFeed(npc, player)
    return ND.tracked(npc.rec) and ND.hunger(npc.rec) >= CFG.SHOW_FEED_AT and player ~= nil and playerFood(player) ~= nil
end

-- Voce da comida (a primeira que tiver na mochila). Retorna ok, fala.
function ND.feed(npc, player)
    local rec = npc.rec
    local item = player and playerFood(player)
    if not item then return false, line("IGUI_Rem_Needs_nofood") end
    if ND.hunger(rec) < CFG.SHOW_FEED_AT then return false, line("IGUI_Rem_Needs_notHungry") end
    local name = item:getDisplayName()
    player:getInventory():DoRemoveItem(item)
    rec.fome = clamp(ND.hunger(rec) - CFG.FOOD_VALUE)
    rec.askedFoodAt = nil
    if Rem.Persona then Rem.Persona.addMorale(rec, CFG.FEED_MORALE) end
    Rem.bark(npc, "ate", true)
    Rem.emit("playerDeed", "fed", npc)
    return true, line("IGUI_Rem_Needs_fed", name)
end

-- ---------------------------------------------------------------- dormir
function ND.canNap(npc)
    return ND.isFollower(npc.rec) and ND.tired(npc.rec) >= CFG.SHOW_NAP_AT and not npc.rec.napUntil
end

function ND.nap(npc)
    local rec = npc.rec
    if ND.tired(rec) < CFG.SHOW_NAP_AT then return false, line("IGUI_Rem_Needs_notTired") end
    rec.napUntil = Rem.worldHours() + CFG.NAP_HOURS
    Rem.stopMoving(npc)
    Rem.setRest(npc, "sleep")
    return true, line("IGUI_Rem_Needs_nap", tostring(CFG.NAP_HOURS))
end

function ND.wake(npc)
    npc.rec.napUntil = nil
    if npc.rest == "sleep" then
        Rem.clearRest(npc)
        Rem.bark(npc, "wake", true)
    end
end

-- Cochilo mandado por voce: deita ali mesmo.
function ND.napBehavior(npc, ctx, now)
    local rec = npc.rec
    if not rec.napUntil then return false end
    if Rem.worldHours() >= rec.napUntil then
        ND.wake(npc)
        return false
    end
    Rem.stopMoving(npc)
    Rem.setRest(npc, "sleep")
    return true
end
Rem.registerBehavior({ name = "nap", priority = CFG.NAP_PRIORITY, run = ND.napBehavior })

-- ---------------------------------------------------------------- a cada hora
local function playerAsleep()
    local p = getPlayer()
    local asleep = false
    if p then pcall(function() asleep = p:isAsleep() end) end
    return asleep
end

-- Uma hora na vida de uma pessoa. Retorna "left" se foi embora.
function ND.hour(rec, ctx)
    local g = ND.baseOf(rec)
    local hunger, tired = ND.hunger(rec), ND.tired(rec)
    -- fome
    if g then
        if (g.supplies or 0) > 0 then hunger = hunger - CFG.BASE_EAT else hunger = hunger + CFG.HUNGER_RATE end
    else
        hunger = hunger + CFG.HUNGER_RATE
    end
    rec.fome = clamp(hunger)
    if not g and rec.fome >= CFG.POCKET_EAT_AT then ND.eatPocket(rec) end
    -- cansaco
    local watching = Rem.Watch and Rem.Watch.onWatch(rec)
    if ND.sleeping(rec) or (not g and (ctx.playerAsleep or (ctx.night and rec.mode == "stay"))) then
        tired = tired - CFG.SLEEP_RECOVER
    elseif g and rec.job == "rest" and not ctx.night then
        tired = tired - CFG.REST_RECOVER
    else
        tired = tired + CFG.TIRED_RATE
        if watching then tired = tired + CFG.WATCH_TIRED end
        if g and (rec.job == "build" or rec.mode == "scav" or rec.mode == "escort") then tired = tired + CFG.WORK_TIRED end
    end
    rec.cansaco = clamp(tired)
    -- moral
    if Rem.Persona then
        if rec.fome >= CFG.STARVING then Rem.Persona.addMorale(rec, -CFG.STARVING_MORALE)
        elseif rec.fome >= CFG.ASK_FOOD_AT then Rem.Persona.addMorale(rec, -CFG.HUNGRY_MORALE) end
        if rec.cansaco >= CFG.ASK_SLEEP_AT then Rem.Persona.addMorale(rec, -CFG.TIRED_MORALE) end
    end
    -- quem segue voce pede (e, no limite, vai embora)
    if not g then
        local npc = activeOf(rec)
        local hours = Rem.worldHours()
        if npc and rec.fome >= CFG.ASK_FOOD_AT and hours - (rec.askedFoodAt or -999) >= CFG.ASK_HOURS then
            rec.askedFoodAt = hours
            Rem.bark(npc, "need_food", true)
        elseif npc and rec.cansaco >= CFG.ASK_SLEEP_AT and hours - (rec.askedSleepAt or -999) >= CFG.ASK_HOURS then
            rec.askedSleepAt = hours
            Rem.bark(npc, "need_sleep", true)
        end
        if rec.fome >= CFG.STARVING and (rec.moral or 50) <= CFG.DESERT_MORALE then
            ND.desert(rec, npc)
            return "left"
        end
    end
    return nil
end

function ND.desert(rec, npc)
    Rem.Journal.add("IGUI_Rem_Journal_deserted", tostring(rec.name))
    if npc then
        Rem.bark(npc, "desert", true)
        local p = getPlayer()
        if p and Rem.Interact then Rem.Interact.release(npc, p) return end
    end
    Rem.removePerson(rec.id)
end

function ND.hourly()
    local ctx = { night = night(), playerAsleep = playerAsleep() }
    local list = {}
    for _, rec in pairs(Rem.getStore().people) do
        if ND.tracked(rec) then table.insert(list, rec) end
    end
    table.sort(list, function(a, b) return tostring(a.id) < tostring(b.id) end)
    for _, rec in ipairs(list) do ND.hour(rec, ctx) end
end
Rem.on("worldHour", function() Rem.safe(ND.hourly) end)
