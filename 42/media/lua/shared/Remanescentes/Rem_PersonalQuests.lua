-- Remanescentes - missoes pessoais: a historia de cada um vira um objetivo.
--
-- Depois que alguem do seu lado conta a historia ("Me fala de voce"), o que ele quer pode
-- virar uma missao ("[Pessoal] Posso te ajudar com aquilo?"):
--   familia  "Quero achar quem sobrou da minha familia": um parente esta vivo, morando com
--            algum grupo do mapa (marcado como "talvez"). Ache, converse ("[Pessoal] ...
--            esta procurando voce.") e ele vem junto. Reencontro: vinculo, moral, amizade.
--   horta    "Vou plantar uma horta": traga sementes (qualquer pacote de sementes) e ele
--            monta uma horta na sua base - comida todo dia, a primeira colheita em uma semana.
--   norte    "Ouvi falar de um lugar ao norte": o lugar e marcado no mapa. Va ate la: nao e
--            o paraiso, mas tem um esconderijo com suprimentos - e ele fica em paz.
-- Se o parente morrer antes, a noticia chega (e pesa).
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_Journal"
require "Remanescentes/Rem_MapMarks"
local Rem = Remanescentes

local PQ = Rem.module("PersonalQuests", {
    FAMILY_DIST = { 150, 1000 },
    NORTH_DIST = 350,
    ARRIVE = 25,
    REUNION_BOND = 25,
    REUNION_MORALE = 30,
    GARDEN_FOOD = 1.0,        -- suprimentos por dia
    GARDEN_DAYS = 7,          -- primeira colheita
    GARDEN_HOUR = 8,
    NORTH_LOOT = 4,
    NORTH_MORALE = 15,
    NORTH_BOND = 15,
})
local CFG = PQ.CFG

PQ.BY_GOAL = { [5] = "family", [6] = "garden", [2] = "north" }
PQ.NORTH_LOOT = { "Base.TinnedBeans", "Base.CannedChili", "Base.Bandage", "Base.Bullets9mmBox", "Base.WaterRationCan",
    "Base.Pills" }

local function line(key, ...) return { key = key, args = { ... } } end
local function base() return Rem.PlayerBase and Rem.PlayerBase.get() or nil end

function PQ.kindOf(rec)
    return rec.story and PQ.BY_GOAL[rec.story.goal] or nil
end

function PQ.canOffer(npc)
    local rec = npc.rec
    return rec.faction == "aliados" and rec.toldStory and PQ.kindOf(rec) ~= nil and not rec.pquest and not rec.pquestDone
end

-- ---------------------------------------------------------------- comecar
local function pickRelative(rec, player)
    local px, py = player:getX(), player:getY()
    local cands = {}
    for _, g in pairs(Rem.getStore().groups) do
        if g.home and not g.player and g.faction ~= "saqueadores" and #g.members > 0 then
            local d = Rem.dist2(px, py, g.home.x, g.home.y)
            if d >= CFG.FAMILY_DIST[1] and d <= CFG.FAMILY_DIST[2] then table.insert(cands, g) end
        end
    end
    table.sort(cands, function(a, b) return a.id < b.id end)
    if #cands == 0 then return nil end
    local g = cands[ZombRand(#cands) + 1]
    for _, id in ipairs(g.members) do
        local p = Rem.getPerson(id)
        if p and not p.onScene and not p.relativeOf then return p, g end
    end
    return nil
end

function PQ.offer(npc, player)
    local rec = npc.rec
    local kind = PQ.kindOf(rec)
    if not kind or rec.pquest then return false, line("IGUI_Rem_PQ_none") end
    if kind == "family" then
        local p, g = pickRelative(rec, player)
        if not p then return false, line("IGUI_Rem_PQ_family_nolead") end
        p.relativeOf = rec.id
        rec.pquest = { kind = "family", pid = p.id, gid = g.id }
        Rem.MapMarks.add({ id = "pquest:" .. rec.id, x = g.home.x, y = g.home.y, symbol = "Question",
            color = Rem.MapMarks.COLORS.quest, text = getText("IGUI_Rem_Map_family", tostring(rec.name)) }, npc)
        Rem.Journal.add("IGUI_Rem_Journal_pq_family", tostring(rec.name), Rem.Journal.groupName(g))
        return true, line("IGUI_Rem_PQ_family_start", Rem.Journal.groupName(g))
    elseif kind == "garden" then
        rec.pquest = { kind = "garden" }
        Rem.Journal.add("IGUI_Rem_Journal_pq_garden", tostring(rec.name))
        return true, line("IGUI_Rem_PQ_garden_start")
    elseif kind == "north" then
        local x, y = math.floor(player:getX()), math.floor(player:getY()) - CFG.NORTH_DIST
        rec.pquest = { kind = "north", x = x, y = y }
        Rem.MapMarks.add({ id = "pquest:" .. rec.id, x = x, y = y, symbol = "Question", color = Rem.MapMarks.COLORS.quest,
            text = getText("IGUI_Rem_Map_north", tostring(rec.name)) }, npc)
        Rem.Journal.add("IGUI_Rem_Journal_pq_north", tostring(rec.name))
        return true, line("IGUI_Rem_PQ_north_start")
    end
    return false, line("IGUI_Rem_PQ_none")
end

local function done(rec)
    rec.pquest, rec.pquestDone = nil, true
    Rem.emit("personalQuestDone", rec)
end

-- ---------------------------------------------------------------- familia
function PQ.seekerOf(npc)
    local id = npc.rec.relativeOf
    local s = id and Rem.getPerson(id)
    if s and s.pquest and s.pquest.kind == "family" and s.pquest.pid == npc.rec.id then return s end
    return nil
end

function PQ.canReunite(npc) return PQ.seekerOf(npc) ~= nil and not Rem.isHostileToPlayer(npc) end

function PQ.reunite(npc)
    local rec = npc.rec
    local seeker = PQ.seekerOf(npc)
    if not seeker then return false, line("IGUI_Rem_PQ_none") end
    -- sai do grupo e vem com voce (ou para a sua base)
    local g = rec.groupId and Rem.getStore().groups[rec.groupId]
    if g then for i = #g.members, 1, -1 do if g.members[i] == rec.id then table.remove(g.members, i) end end end
    rec.groupId, rec.role, rec.job, rec.relativeOf = nil, nil, nil, nil
    rec.faction, rec.recruited, rec.temper, rec.hostileToPlayer = "aliados", true, "defensivo", false
    rec.mode = "follow"
    Rem.applyFriendlyFire(npc)
    local b = base()
    if b and seeker.groupId == b.id then Rem.PlayerBase.join(npc) end
    if Rem.Friends then Rem.Friends.add(seeker, rec, 100) end
    if Rem.Bonds then Rem.Bonds.add(seeker, "quest", CFG.REUNION_BOND) Rem.Bonds.add(rec, "rescued") end
    if Rem.Persona then Rem.Persona.addMorale(seeker, CFG.REUNION_MORALE) end
    Rem.Journal.add("IGUI_Rem_Journal_pq_reunion", tostring(seeker.name), tostring(rec.name))
    done(seeker)
    return true, line("IGUI_Rem_PQ_reunion", tostring(seeker.name))
end

-- O parente morreu antes do reencontro.
Rem.on("personRemoved", function(p)
    if Rem.bulkRemove or not p or not p.relativeOf then return end
    local seeker = Rem.getPerson(p.relativeOf)
    if seeker and seeker.pquest and seeker.pquest.pid == p.id then
        seeker.pquest, seeker.pquestDone = nil, true
        seeker.griefUntil, seeker.griefFor = Rem.worldHours() + 48, tostring(p.name)
        if Rem.Persona then Rem.Persona.addMorale(seeker, -20) end
        Rem.Journal.add("IGUI_Rem_Journal_pq_family_dead", tostring(seeker.name))
    end
end)

-- ---------------------------------------------------------------- horta
local function seedOf(player)
    local items = player:getInventory():getItems()
    for i = 0, items:size() - 1 do
        local it = items:get(i)
        if tostring(it:getFullType()):find("Seed", 1, true) then return it end
    end
    return nil
end

function PQ.canGarden(npc, player)
    local q = npc.rec.pquest
    return q ~= nil and q.kind == "garden" and player ~= nil and seedOf(player) ~= nil
end

function PQ.plant(npc, player)
    local rec = npc.rec
    local b = base()
    if not b then return false, line("IGUI_Rem_PQ_garden_nobase") end
    local seed = seedOf(player)
    if not seed then return false, line("IGUI_Rem_PQ_garden_noseed") end
    player:getInventory():DoRemoveItem(seed)
    b.garden = { since = Rem.worldHours(), by = rec.id }
    if Rem.Persona then Rem.Persona.addMorale(rec, 15) end
    Rem.Journal.add("IGUI_Rem_Journal_pq_garden_planted", tostring(rec.name))
    done(rec)
    return true, line("IGUI_Rem_PQ_garden_planted")
end

-- Colheita diaria (depois da primeira semana).
function PQ.harvest(b)
    local gd = b and b.garden
    if not gd then return 0 end
    local days = (Rem.worldHours() - gd.since) / 24
    if days < CFG.GARDEN_DAYS then return 0 end
    b.supplies = (b.supplies or 0) + CFG.GARDEN_FOOD
    if not gd.firstHarvest then
        gd.firstHarvest = true
        Rem.Journal.add("IGUI_Rem_Journal_pq_harvest")
    end
    return CFG.GARDEN_FOOD
end

-- ---------------------------------------------------------------- norte
function PQ.checkNorth(player)
    local px, py = player:getX(), player:getY()
    for _, rec in pairs(Rem.getStore().people) do
        local q = rec.pquest
        if q and q.kind == "north" and Rem.dist2(px, py, q.x, q.y) <= CFG.ARRIVE then
            for _ = 1, CFG.NORTH_LOOT do Rem.safe(function() player:getInventory():AddItem(Rem.pick(PQ.NORTH_LOOT)) end) end
            if Rem.Persona then Rem.Persona.addMorale(rec, CFG.NORTH_MORALE) end
            if Rem.Bonds then Rem.Bonds.add(rec, "quest", CFG.NORTH_BOND) end
            Rem.Journal.add("IGUI_Rem_Journal_pq_north_found", tostring(rec.name), tostring(CFG.NORTH_LOOT))
            done(rec)
        end
    end
end

local nextCheck = 0
Rem.on("sceneUpdate", function(player, now)
    if now < nextCheck then return end
    nextCheck = now + 3000
    Rem.safe(PQ.checkNorth, player)
end)

Rem.on("worldHour", function()
    if math.floor(getGameTime():getTimeOfDay()) == CFG.GARDEN_HOUR then Rem.safe(PQ.harvest, base()) end
end)

-- ---------------------------------------------------------------- conversa
function PQ.dialogOptions(npc, player)
    local out = {}
    if PQ.canOffer(npc) then table.insert(out, "pq_offer") end
    if PQ.canGarden(npc, player) then table.insert(out, "pq_plant") end
    if PQ.canReunite(npc) then table.insert(out, "pq_reunite") end
    return out
end

function PQ.choose(id, npc, player)
    if id == "pq_offer" then return PQ.offer(npc, player) end
    if id == "pq_plant" then return PQ.plant(npc, player) end
    if id == "pq_reunite" then return PQ.reunite(npc) end
    return false, line("IGUI_Rem_PQ_none")
end
