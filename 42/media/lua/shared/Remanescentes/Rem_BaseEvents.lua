-- Remanescentes - eventos da sua base: coisas que acontecem com ou sem voce.
--
--   horde     de noite, zumbis testam as defesas. Com voce la: eles aparecem do lado de fora
--             da cerca e os moradores lutam. Longe: defesa (vigias, janelas, cerca, carros,
--             moradores) contra o tamanho da horda; pedacos de cerca caem, alguem pode se
--             ferir ou morrer.
--   visitor   de dia, alguem chega no portao pedindo para ficar. Com voce la: fala com ele
--             ("Pode ficar na nossa base"). Longe: os moradores decidem (se ha comida e
--             lugar, fica).
--   argument  moral baixo: dois moradores brigam (moral cai). Muito baixo: alguem vai embora.
--   thief     de noite, sem vigia: alguem leva comida do estoque. Com vigia: espantado.
--   party     uma obra terminou: comemoram (moral sobe).
-- Tudo vai para o Diario.
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_PlayerBase"
require "Remanescentes/Rem_BaseBuild"
require "Remanescentes/Rem_Ambient"
require "Remanescentes/Rem_Journal"
local Rem = Remanescentes
local PB, BB = Rem.PlayerBase, Rem.BaseBuild
local AM = Rem.Ambient

local BE = Rem.module("BaseEvents", {
    HORDE_CHANCE = 3,          -- (%) por hora de noite
    HORDE_SIZE = { 4, 12 },
    HORDE_COOLDOWN_H = 36,
    VISITOR_CHANCE = 3,        -- (%) por hora de dia
    VISITOR_COOLDOWN_H = 30,
    VISITOR_MS = 240000,
    VISITOR_FOOD_DAYS = 2,
    ARGUE_MORALE = 30,
    ARGUE_CHANCE = 6,          -- (%) por hora, com o moral medio abaixo de ARGUE_MORALE
    ARGUE_LOSS = 6,
    LEAVE_MORALE = 12,
    THIEF_CHANCE = 2,          -- (%) por hora de noite
    THIEF_TAKE = 0.25,         -- fracao da comida levada
    PARTY_MORALE = 10,
    GUNNER_BONUS = 1.0,
    BRAWLER_BONUS = 0.4,
    SPAWN_OUT = 3,             -- zumbis da horda a essa distancia alem da cerca
    RAID_CHANCE = 1,           -- (%) por hora: saqueadores atacam a sua base
    RAID_COOLDOWN_H = 72,
    RAID_RADIUS = 400,         -- precisa haver um bando a essa distancia
    RAID_MAX = 4,
    RAID_MS = 300000,
})
local CFG = BE.CFG

Rem.BARKS.base_horde = { urgent = true, n = 3, cd = 0 }
Rem.BARKS.base_visitor = { urgent = true, n = 3, cd = 30000 }
Rem.BARKS.base_argue = { urgent = true, n = 4, cd = 0 }
Rem.BARKS.base_party = { urgent = true, n = 3, cd = 0 }
Rem.BARKS.base_welcome = { urgent = true, n = 2, cd = 0 }
Rem.BARKS.base_raid = { urgent = true, n = 3, cd = 0 }

local function night()
    local tod = getGameTime():getTimeOfDay()
    return tod >= 21 or tod < 5
end
local function daytime()
    local tod = getGameTime():getTimeOfDay()
    return tod >= 8 and tod < 18
end
local function roll(p) return ZombRand(100) < p end

local function onScene(g)
    local out = {}
    for _, npc in pairs(Rem.active) do
        if npc.rec.groupId == g.id then table.insert(out, npc) end
    end
    table.sort(out, function(a, b) return tostring(a.rec.id) < tostring(b.rec.id) end)
    return out
end

-- ---------------------------------------------------------------- defesa
-- Quantos zumbis a base segura.
function BE.defense(g)
    local h = g.home
    local d = 0
    for _, p in ipairs(PB.members(g)) do
        local v = (p.job == "guard") and 1.5 or 0.6
        -- especialidades: atirador com municao defende mais; brigao tambem
        if p.firearm and (p.ammo or 0) > 0 then v = v + CFG.GUNNER_BONUS end
        if p.archetype == "brigao" then v = v + CFG.BRAWLER_BONUS end
        d = d + v
    end
    if Rem.Alliance then d = d + Rem.Alliance.helpFor(g) end
    if Rem.Fuel then d = d + Rem.Fuel.defenseBonus(g) end                 -- luz do gerador a noite
    local win = (h.windowsTotal and h.windowsTotal > 0) and (h.windowsDone or 0) / h.windowsTotal or 0
    local fence = (h.fenceTotal and h.fenceTotal > 0) and (h.fenceBuilt or 0) / h.fenceTotal or 0
    d = d + win * 3 + fence * 5 + #(h.cars or {}) * 0.5
    return d
end

-- ---------------------------------------------------------------- horda
-- Zumbis aparecem do lado de fora da cerca (com voce la).
function BE.spawnHorde(g, n)
    local h = g.home
    local m = BB.CFG.PERIM_MARGIN + CFG.SPAWN_OUT
    local made = 0
    local side = ZombRand(4)
    for _ = 1, n do
        local x, y
        if side == 0 then x, y = ZombRand(h.x1 - m, h.x2 + m), h.y1 - m
        elseif side == 1 then x, y = ZombRand(h.x1 - m, h.x2 + m), h.y2 - 1 + m
        elseif side == 2 then x, y = h.x1 - m, ZombRand(h.y1 - m, h.y2 + m)
        else x, y = h.x2 - 1 + m, ZombRand(h.y1 - m, h.y2 + m) end
        local ok = Rem.safe(function()
            addZombiesInOutfit(x, y, 0, 1, Rem.pick(Rem.FACTIONS.civis.outfits), 50, false, false, false, false, false, false, 1.0)
        end)
        if ok then made = made + 1 end
    end
    return made
end

function BE.horde(g)
    local n = ZombRand(CFG.HORDE_SIZE[1], CFG.HORDE_SIZE[2] + 1)
    g.lastHorde = Rem.worldHours()
    local people = onScene(g)
    if #people > 0 and Rem.Safehouse.isLoaded(g.home) then
        BE.spawnHorde(g, n)
        Rem.bark(people[1], "base_horde", true)
        Rem.Journal.add("IGUI_Rem_Journal_ev_horde_here", tostring(n))
        return "here"
    end
    -- estacas no caminho seguram parte da horda (Rem_Traps)
    if Rem.Traps then
        local stopped = Rem.Traps.hordeStopped(g.home)
        if stopped > 0 then
            n = math.max(0, n - stopped)
            g.home.traps = math.max(0, (g.home.traps or 0) - stopped)
        end
    end
    local def = BE.defense(g)
    -- vigia (Rem_Watch): acordado avisa a tempo; ninguem vigiando = pegos de surpresa
    if Rem.Watch then
        if Rem.Watch.isNight() and not Rem.Watch.covered(g) then Rem.Journal.add("IGUI_Rem_Journal_watch_surprised") end
        def = Rem.Watch.adjustDefense(g, def)
    end
    if def * 2 >= n then
        local dmg = ZombRand(0, 3)
        if dmg > 0 then BB.damageFence(g, dmg) end
        Rem.Journal.add("IGUI_Rem_Journal_ev_horde_held", tostring(n), tostring(dmg))
        return "held"
    end
    BB.damageFence(g, ZombRand(3, 7))
    local list = PB.members(g)
    local victim = list[ZombRand(#list) + 1]
    if victim and def < n / 3 and roll(50) then
        PB.leave(victim)
        if Rem.Persona then Rem.Persona.mourn(victim) end
        Rem.Journal.add("IGUI_Rem_Journal_ev_horde_dead", tostring(n), tostring(victim.name))
        Rem.removePerson(victim.id)
        return "dead"
    end
    if victim then
        victim.hp = (victim.hp or victim.maxHealth or 2) * 0.5
        if Rem.Wounds then Rem.Wounds.inflict(victim) end
    end
    Rem.Journal.add("IGUI_Rem_Journal_ev_horde_hurt", tostring(n), tostring(victim and victim.name or "?"))
    return "hurt"
end

-- ---------------------------------------------------------------- ataque de saqueadores
-- Bando de saqueadores mais perto da base (com gente para atacar), ou nil.
function BE.raiders(g)
    if Rem.Timeline and Rem.Timeline.raiderFactor() <= 0 then return nil end
    local best, bestD = nil, CFG.RAID_RADIUS
    for _, other in pairs(Rem.getStore().groups) do
        if other.faction == "saqueadores" and other.home and #other.members >= 2 and other.activity == "home"
            and not (Rem.Diplomacy and Rem.Diplomacy.protectedFrom(other)) then          -- pacto ou tributo pago
            local d = Rem.dist2(other.home.x, other.home.y, g.home.x, g.home.y)
            if d < bestD then best, bestD = other, d end
        end
    end
    return best
end

-- Com voce la: eles chegam de verdade, pela rua da frente, e entram atirando.
function BE.raidHere(g, band, player)
    local h = g.home
    local n = math.min(CFG.RAID_MAX, #band.members)
    local made = {}
    for _ = 1, n do
        local sq = AM.spawnPoint(player, 18, 26)
        local npc = sq and AM.makePerson(sq, { faction = "saqueadores", ambient = "base_raid", hostileToPlayer = true })
        if npc then
            npc.rec.raidX, npc.rec.raidY = h.x, h.y
            npc.rec.raidUntil = Rem.nowMs() + CFG.RAID_MS
            npc.rec.fromBand = band.id
            table.insert(made, npc)
        end
    end
    if made[1] then Rem.bark(made[1], "base_raid", true) end
    Rem.Journal.add("IGUI_Rem_Journal_ev_raid_here", Rem.Journal.groupName(band), tostring(#made))
    return made
end

AM.HANDLERS.base_raid = function(npc, ctx, now)
    local rec = npc.rec
    if now > (rec.raidUntil or 0) then
        AM.leave(npc, ctx.player)
        return true
    end
    -- (a briga e do cerebro: inimigo a vista, ele luta; senao, vai para a base)
    Rem.moveTo(npc, rec.raidX, rec.raidY, 0, now, "run")
    return true
end

-- Longe de voce: a defesa decide (moradores, vigias, obras, aliados).
function BE.raid(g, player)
    local band = BE.raiders(g)
    if not band then return nil end
    g.lastRaid = Rem.worldHours()
    local people = onScene(g)
    if #people > 0 and player and Rem.Safehouse.isLoaded(g.home) then
        BE.raidHere(g, band, player)
        return "here"
    end
    local attack = math.min(CFG.RAID_MAX, #band.members) * 1.5 + ZombRandFloat(0, 2)
    local def = BE.defense(g)
    if Rem.Watch then def = Rem.Watch.adjustDefense(g, def) end
    if def >= attack then
        -- repelidos: o bando perde alguem
        local loser = Rem.getPerson(band.members[#band.members])
        if loser then Rem.removePerson(loser.id) end
        Rem.Journal.add("IGUI_Rem_Journal_ev_raid_held", Rem.Journal.groupName(band))
        return "held"
    end
    local take = (g.supplies or 0) / 2
    g.supplies = (g.supplies or 0) - take
    band.supplies = (band.supplies or 0) + take
    BB.damageFence(g, ZombRand(1, 4))
    local list = PB.members(g)
    local victim = list[ZombRand(math.max(1, #list)) + 1]
    if victim then
        PB.leave(victim)
        if Rem.Persona then Rem.Persona.mourn(victim) end
        Rem.removePerson(victim.id)
    end
    Rem.Journal.add("IGUI_Rem_Journal_ev_raid_lost", Rem.Journal.groupName(band), tostring(victim and victim.name or "?"))
    return "lost"
end

-- ---------------------------------------------------------------- visitante
function BE.foodDays(g)
    local n = math.max(1, #g.members)
    return (g.supplies or 0) / n
end

function BE.visitor(g, player)
    g.lastVisitor = Rem.worldHours()
    local h = g.home
    local people = onScene(g)
    if #people > 0 and player and Rem.dist2(player:getX(), player:getY(), h.x, h.y) < 60 then
        -- chega no portao (na frente da porta principal, do lado de fora)
        local d = h.mainDoor or { x = math.floor(h.x), y = h.y2 }
        local dy = (d.y >= h.y2 - 1) and 1 or ((d.y <= h.y1) and -1 or 0)
        local dx = (dy == 0) and ((d.x >= h.x2 - 1) and 1 or -1) or 0
        local m = BB.CFG.PERIM_MARGIN + 2
        local sq = getCell():getGridSquare(d.x + dx * m, d.y + dy * m, 0)
        if not sq or not sq:isFree(false) then sq = AM.spawnPoint(player, 10, 20) end
        if not sq then return nil end
        local npc = AM.makePerson(sq, { faction = "civis", ambient = "visitor" })
        if not npc then return nil end
        npc.rec.spotX, npc.rec.spotY = sq:getX() + 0.5, sq:getY() + 0.5
        npc.rec.visitUntil = Rem.nowMs() + CFG.VISITOR_MS
        Rem.bark(npc, "base_visitor", true)
        Rem.Journal.add("IGUI_Rem_Journal_ev_visitor_here", tostring(npc.rec.name))
        return npc
    end
    -- longe de voce: os moradores decidem
    local name = Rem.pick(Rem.NAMES)
    if #g.members < PB.CFG.MAX_MEMBERS and BE.foodDays(g) >= CFG.VISITOR_FOOD_DAYS then
        local rec = Rem.newPerson({ faction = "aliados", groupId = g.id, mode = "group", name = name,
            x = h.x + ZombRandFloat(-2, 2), y = h.y + ZombRandFloat(-2, 2), z = 0 })
        rec.recruited = true
        rec.job = PB.defaultJob(g)
        rec.role = (rec.job == "guard") and "guarda" or "morador"
        table.insert(g.members, rec.id)
        Rem.Journal.add("IGUI_Rem_Journal_ev_visitor_stayed", tostring(rec.name))
        return rec
    end
    Rem.Journal.add("IGUI_Rem_Journal_ev_visitor_away", name)
    return false
end

-- Aceitar o visitante (conversa: "Pode ficar na nossa base").
function BE.accept(npc)
    local g = PB.get()
    local rec = npc.rec
    if not g or rec.ambient ~= "visitor" then return false, { key = "IGUI_Rem_Base_none", args = {} } end
    if #g.members >= PB.CFG.MAX_MEMBERS then return false, { key = "IGUI_Rem_Base_full", args = { tostring(PB.CFG.MAX_MEMBERS) } } end
    if Rem.Council then Rem.Council.vote("newcomer", rec) end
    rec.faction, rec.recruited = "aliados", true
    rec.transient, rec.ambient, rec.expiresAt, rec.spotX, rec.spotY, rec.visitUntil = nil, nil, nil, nil, nil, nil
    rec.temper = "defensivo"
    rec.hostileToPlayer = false
    Rem.applyFriendlyFire(npc)
    local ok, l = PB.join(npc)
    if ok then
        Rem.bark(npc, "base_welcome", true)
        Rem.emit("playerDeed", "recruited", npc)
    end
    return ok, l
end

-- Visitante esperando no portao (comportamento de gente de passagem).
AM.HANDLERS.visitor = function(npc, ctx, now)
    local rec = npc.rec
    if now > (rec.visitUntil or 0) then
        AM.leave(npc, ctx.player)
        return true
    end
    if Rem.dist2(npc.z:getX(), npc.z:getY(), rec.spotX, rec.spotY) > 1.5 then
        Rem.moveTo(npc, rec.spotX, rec.spotY, 0, now, "walk")
        return true
    end
    Rem.stopMoving(npc)
    if ctx.player then
        Rem.safe(function() npc.z:faceThisObject(ctx.player) end)
        if Rem.dist(npc.z, ctx.player) < 15 then Rem.bark(npc, "base_visitor") end
    end
    return true
end

-- ---------------------------------------------------------------- briga
function BE.morale(g)
    local list = PB.members(g)
    if #list == 0 then return 50 end
    local t = 0
    for _, p in ipairs(list) do t = t + (p.moral or 50) end
    return t / #list
end

function BE.argue(g)
    local list = PB.members(g)
    if #list < 2 then return nil end
    -- rivais (Rem_Friends) brigam primeiro
    local a, b = nil, nil
    if Rem.Friends then a, b = Rem.Friends.rivalPair(list) end
    if not a then
        a = list[ZombRand(#list) + 1]
        b = list[ZombRand(#list) + 1]
        if a == b then b = list[(a == list[1]) and 2 or 1] end
    end
    Rem.emit("baseArgue", a, b)
    a.moral = math.max(0, (a.moral or 50) - CFG.ARGUE_LOSS)
    b.moral = math.max(0, (b.moral or 50) - CFG.ARGUE_LOSS)
    -- com voce la, a briga e falada
    local na, nb = nil, nil
    for _, npc in pairs(Rem.active) do
        if npc.rec == a then na = npc elseif npc.rec == b then nb = npc end
    end
    if na and nb and Rem.Banter then
        Rem.Banter.start(na, nb, Rem.nowMs(), "argue")
    end
    Rem.Journal.add("IGUI_Rem_Journal_ev_argue", tostring(a.name), tostring(b.name))
    -- muito desanimado: vai embora
    local low = ((a.moral or 50) <= (b.moral or 50)) and a or b
    if (low.moral or 50) <= CFG.LEAVE_MORALE and not low.onScene then
        PB.leave(low)
        Rem.Journal.add("IGUI_Rem_Journal_ev_left_morale", tostring(low.name))
        Rem.removePerson(low.id)
        return "left"
    end
    return "argue"
end

-- ---------------------------------------------------------------- ladrao
function BE.thief(g)
    local guards = 0
    for _, p in ipairs(PB.members(g)) do if p.job == "guard" then guards = guards + 1 end end
    -- (com a escala de vigia, so espanta quem esta acordado no posto)
    local covered = guards > 0
    if Rem.Watch then covered = Rem.Watch.covered(g) end
    if covered then
        Rem.Journal.add("IGUI_Rem_Journal_ev_thief_scared")
        return "scared"
    end
    local take = math.max(0.5, (g.supplies or 0) * CFG.THIEF_TAKE)
    if (g.supplies or 0) <= 0 then return nil end
    g.supplies = math.max(0, g.supplies - take)
    Rem.Journal.add("IGUI_Rem_Journal_ev_thief", tostring(math.floor(take * Rem.World.CFG.ITEMS_PER_SUPPLY + 0.5)))
    return "stolen"
end

-- ---------------------------------------------------------------- festa
Rem.on("baseProjectDone", function(g, project)
    for _, p in ipairs(PB.members(g)) do
        if Rem.Persona then Rem.Persona.addMorale(p, CFG.PARTY_MORALE) else p.moral = math.min(100, (p.moral or 50) + CFG.PARTY_MORALE) end
    end
    local people = onScene(g)
    if people[1] then Rem.bark(people[1], "base_party", true) end
    if g.player then Rem.Journal.add("IGUI_Rem_Journal_ev_done_" .. project) end
end)

-- ---------------------------------------------------------------- sorteio por hora
function BE.hourly()
    local g = PB.get()
    if not g or #g.members == 0 then return nil end
    local hours = Rem.worldHours()
    local player = getPlayer()
    if night() and hours - (g.lastHorde or -999) >= CFG.HORDE_COOLDOWN_H and roll(CFG.HORDE_CHANCE) then
        return "horde", BE.horde(g)
    end
    if night() and roll(CFG.THIEF_CHANCE) then return "thief", BE.thief(g) end
    if hours - (g.lastRaid or -999) >= CFG.RAID_COOLDOWN_H and BE.raiders(g) and roll(CFG.RAID_CHANCE) then
        return "raid", BE.raid(g, player)
    end
    if daytime() and hours - (g.lastVisitor or -999) >= CFG.VISITOR_COOLDOWN_H and roll(CFG.VISITOR_CHANCE) then
        return "visitor", BE.visitor(g, player)
    end
    local rivals = Rem.Friends and Rem.Friends.rivalPair(PB.members(g)) ~= nil
    if (BE.morale(g) < CFG.ARGUE_MORALE or rivals) and roll(CFG.ARGUE_CHANCE) then return "argue", BE.argue(g) end
    return nil
end
Rem.on("worldHour", function() Rem.safe(BE.hourly) end)

-- ferramentas de teste
for _, ev in ipairs({ "horde", "visitor", "argue", "thief", "raid" }) do
    Rem.registerDebugOption("ContextMenu_Rem_BaseEv_" .. ev, function(x, y, z, player)
        local g = PB.get()
        if not g then player:Say(getText("IGUI_Rem_Base_none")) return end
        local res = nil
        if ev == "visitor" or ev == "raid" then res = BE[ev](g, player) else res = BE[ev](g) end
        player:Say(ev .. ": " .. tostring(res and (type(res) == "table" and "ok" or res) or "-"))
    end, "world")
end
