-- Remanescentes - prisioneiros: quem se rende pode ser levado para a sua base.
--
-- Conversa com quem se rendeu (Rem_Mugging):
--   "[Prisioneiro] Voce vem comigo."   ele anda na sua frente (perto de voce), sem armas e
--                                      sem brigar (foge de zumbi colado).
--   "[Prisioneiro] Fica preso aqui."   dentro da sua base: fica sentado num canto, vigiado.
--   "[Prisioneiro] Onde fica o seu bando?"  interrogatorio (uma vez a cada tantas horas).
--       Cada tentativa amolece; arma na mao e fome ajudam; coragem atrapalha. Quando ele
--       fala: o esconderijo do bando vai para o mapa e o Diario, e se eles planejavam
--       atacar a sua base, voce fica sabendo (o ataque atrasa).
--   "[Prisioneiro] Seu bando vai pagar por voce."  resgate: o bando manda comida e
--       municao para a sua base e ele volta para eles (reputacao com eles sobe um pouco).
--   "[Prisioneiro] Quer ficar do nosso lado?"  depois de uns dias preso e bem tratado
--       (moral), ele pode virar um de voces.
--   "[Prisioneiro] Pode ir embora."  solto (o bando dele lembra do gesto).
-- Preso come do estoque da base. Sem vigia acordado (Rem_Watch) e com fome, ele pode fugir
-- - e conta ao bando onde fica a sua base.
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_Barks"
require "Remanescentes/Rem_Journal"
require "Remanescentes/Rem_MapMarks"
require "Remanescentes/Rem_PlayerBase"
local Rem = Remanescentes
local PB = Rem.PlayerBase

local PR = Rem.module("Prisoners", {
    ESCORT_DIST = 2.5,
    PRIORITY = 85,            -- antes de recuar (90) e de seguir voce (100)
    INTERROGATE_HOURS = 6,
    TALK_BASE = 20,           -- (%) chance base de falar
    TALK_PER_TRY = 15,
    TALK_ARMED = 15,
    TALK_HUNGRY = 10,
    TALK_COURAGE = 3,         -- por ponto de coragem
    RAID_DELAY_H = 72,        -- ele contou o plano: o ataque a sua base atrasa
    RANSOM_ITEMS = 5,
    RANSOM_REP = 5,
    RELEASE_REP = 8,
    RECRUIT_HOURS = 48,
    RECRUIT_MORALE = 45,
    ESCAPE_BASE = 1,          -- (%) por hora
    ESCAPE_UNWATCHED = 4,     -- a mais sem vigia acordado
    ESCAPE_HUNGRY = 4,        -- a mais sem comida na base
    HOLD_MARGIN = 2,
})
local CFG = PR.CFG

Rem.BARKS.prisoner_taken = { urgent = true, n = 3, cd = 0 }
Rem.BARKS.prisoner_idle = { n = 4, cd = 120000 }
Rem.BARKS.prisoner_talk = { urgent = true, n = 2, cd = 0 }
Rem.BARKS.prisoner_silent = { urgent = true, n = 3, cd = 0 }

PR.RANSOM_LOOT = { "Base.TinnedBeans", "Base.TinnedSoup", "Base.CannedChili", "Base.WaterRationCan",
    "Base.Bullets9mmBox", "Base.ShotgunShellsBox", "Base.Bandage" }

local function line(key, ...) return { key = key, args = { ... } } end
local function hours() return Rem.worldHours() end

function PR.isPrisoner(rec) return rec.prisoner ~= nil end
function PR.canTake(npc) return npc.rec.surrendered == true and not npc.rec.prisoner end

function PR.bandOf(rec)
    local id = rec.bandId
    local g = id and Rem.getStore().groups[id]
    if g and #g.members > 0 then return g end
    return nil
end

local function base() return PB.get() end

local function inBase(npc, g)
    local h = g and g.home
    if not h or not h.x1 then return false end
    local x, y, m = npc.z:getX(), npc.z:getY(), CFG.HOLD_MARGIN
    return x >= h.x1 - m and x <= h.x2 + m and y >= h.y1 - m and y <= h.y2 + m
end

function PR.list(g)
    local out = {}
    for _, id in ipairs(g.prisoners or {}) do
        local p = Rem.getPerson(id)
        if p then table.insert(out, p) end
    end
    return out
end

local function dropFromBase(rec)
    local g = base()
    if not g or not g.prisoners then return end
    for i = #g.prisoners, 1, -1 do if g.prisoners[i] == rec.id then table.remove(g.prisoners, i) end end
end

local function armed(player)
    local w = nil
    pcall(function() w = player:getPrimaryHandItem() end)
    return w ~= nil and instanceof(w, "HandWeapon")
end

-- ---------------------------------------------------------------- levar
function PR.take(npc)
    local rec = npc.rec
    if not PR.canTake(npc) then return false, line("IGUI_Rem_Prisoner_cant") end
    -- sai do bando (o grupo dele nao o move mais pelo mundo) e do encontro de assalto
    local bandId = rec.groupId or rec.fromBand
    if rec.groupId then
        local g = Rem.getStore().groups[rec.groupId]
        for i = #(g and g.members or {}), 1, -1 do if g.members[i] == rec.id then table.remove(g.members, i) end end
    end
    if Rem.Mugging then
        local E = Rem.Mugging.of(npc)
        for k, e in pairs(Rem.Mugging.enc) do if e == E then Rem.Mugging.enc[k] = nil end end
    end
    rec.bandId = bandId
    rec.groupId, rec.role, rec.job = nil, nil, nil
    rec.transient, rec.ambient, rec.expiresAt = nil, nil, nil
    rec.surrendered = nil
    rec.prisoner = "escort"
    rec.mode = "prisoner"
    rec.hostileToPlayer = false
    rec.takenAt = hours()
    Rem.cancelAttack(npc)
    Rem.clearRest(npc)
    Rem.applyFriendlyFire(npc)
    Rem.bark(npc, "prisoner_taken", true)
    Rem.Journal.add("IGUI_Rem_Journal_prisoner_taken", tostring(rec.name))
    return true, line("IGUI_Rem_Prisoner_taken")
end

-- Prender na base (ele precisa estar dentro dela).
function PR.hold(npc)
    local rec = npc.rec
    local g = base()
    if not g then return false, line("IGUI_Rem_Base_none") end
    if not inBase(npc, g) then return false, line("IGUI_Rem_Prisoner_notbase") end
    if rec.prisoner ~= "held" and Rem.Council then Rem.Council.vote("prisoner", rec) end
    rec.prisoner = "held"
    rec.heldSince = rec.heldSince or hours()
    local spot = Rem.Safehouse.indoorSpot(rec, g.home)
    rec.indoorSpot = nil
    rec.cell = spot or { x = math.floor(npc.z:getX()), y = math.floor(npc.z:getY()), z = math.floor(npc.z:getZ()) }
    g.prisoners = g.prisoners or {}
    local already = false
    for _, id in ipairs(g.prisoners) do if id == rec.id then already = true end end
    if not already then table.insert(g.prisoners, rec.id) end
    Rem.Journal.add("IGUI_Rem_Journal_prisoner_held", tostring(rec.name))
    return true, line("IGUI_Rem_Prisoner_held")
end

-- ---------------------------------------------------------------- interrogar
function PR.talkChance(npc, player)
    local rec = npc.rec
    local c = CFG.TALK_BASE + (rec.interrogations or 0) * CFG.TALK_PER_TRY - Rem.trait(rec, "coragem") * CFG.TALK_COURAGE
    if player and armed(player) then c = c + CFG.TALK_ARMED end
    if (rec.fome or 0) >= 60 then c = c + CFG.TALK_HUNGRY end
    return math.max(5, math.min(95, c))
end

function PR.interrogate(npc, player)
    local rec = npc.rec
    if rec.talked then return true, PR.revealLine(rec) end
    local h = hours()
    if rec.interrogatedAt and h - rec.interrogatedAt < CFG.INTERROGATE_HOURS then
        return false, line("IGUI_Rem_Prisoner_tooSoon", tostring(math.ceil(CFG.INTERROGATE_HOURS - (h - rec.interrogatedAt))))
    end
    rec.interrogatedAt = h
    local chance = PR.talkChance(npc, player)
    rec.interrogations = (rec.interrogations or 0) + 1
    if ZombRand(100) >= chance then
        Rem.bark(npc, "prisoner_silent", true)
        return false, line("IGUI_Rem_Prisoner_silent")
    end
    rec.talked = true
    Rem.bark(npc, "prisoner_talk", true)
    local band = PR.bandOf(rec)
    if band then
        Rem.getStore().knownGroups = Rem.getStore().knownGroups or {}
        Rem.getStore().knownGroups[band.id] = true
        Rem.MapMarks.markGroup(band, npc)
        -- planejavam atacar a sua base? agora voce sabe (e eles perdem a surpresa)
        local g = base()
        if g and Rem.BaseEvents and Rem.BaseEvents.raiders(g) == band then
            g.lastRaid = h + CFG.RAID_DELAY_H - Rem.BaseEvents.CFG.RAID_COOLDOWN_H
            rec.toldRaid = true
        end
        Rem.Journal.add("IGUI_Rem_Journal_prisoner_talked", tostring(rec.name), Rem.Journal.groupName(band))
    end
    return true, PR.revealLine(rec)
end

function PR.revealLine(rec)
    local band = PR.bandOf(rec)
    if not band then return line("IGUI_Rem_Prisoner_noband") end
    local p = getPlayer()
    local d, dir = 0, "N"
    if p then
        d = math.floor(Rem.dist2(p:getX(), p:getY(), band.home.x, band.home.y) / 10) * 10
        dir = Rem.Interact.direction(p:getX(), p:getY(), band.home.x, band.home.y) or "N"
    end
    if rec.toldRaid then
        return line("IGUI_Rem_Prisoner_talk_raid", Rem.Journal.groupName(band), tostring(d), getText("IGUI_Rem_Dir_" .. dir))
    end
    return line("IGUI_Rem_Prisoner_talk", Rem.Journal.groupName(band), tostring(d), getText("IGUI_Rem_Dir_" .. dir))
end

-- ---------------------------------------------------------------- resgate, soltar, recrutar
local function sendHome(npc, rec)
    local band = PR.bandOf(rec)
    dropFromBase(rec)
    rec.prisoner, rec.cell = nil, nil
    if band then
        rec.groupId, rec.mode = band.id, "group"
        table.insert(band.members, rec.id)
        rec.bandId = nil
        if npc then
            Rem.Reputation.apply(rec)
            Rem.applyFriendlyFire(npc)
        else
            rec.x, rec.y, rec.z, rec.pid = band.home.x, band.home.y, 0, nil
        end
        return band
    end
    if npc and Rem.Interact then
        local p = getPlayer()
        if p then Rem.Interact.release(npc, p) return nil end
    end
    Rem.removePerson(rec.id)
    return nil
end

function PR.canRansom(npc) return npc.rec.prisoner == "held" and PR.bandOf(npc.rec) ~= nil end

function PR.ransom(npc)
    local rec = npc.rec
    local band = PR.bandOf(rec)
    local g = base()
    if not band or not g then return false, line("IGUI_Rem_Prisoner_noband") end
    g.pendingList = g.pendingList or {}
    local food = 0
    for _ = 1, CFG.RANSOM_ITEMS do
        local ft = Rem.pick(PR.RANSOM_LOOT)
        table.insert(g.pendingList, ft)
        if not ft:find("Box") and ft ~= "Base.Bandage" then food = food + 1 end
    end
    g.supplies = (g.supplies or 0) + food / Rem.World.CFG.ITEMS_PER_SUPPLY
    Rem.changeRep(band.id, CFG.RANSOM_REP, "resgate")
    Rem.Journal.add("IGUI_Rem_Journal_prisoner_ransom", tostring(rec.name), Rem.Journal.groupName(band), tostring(CFG.RANSOM_ITEMS))
    sendHome(npc, rec)
    return true, line("IGUI_Rem_Prisoner_ransom", Rem.Journal.groupName(band))
end

function PR.release(npc)
    local rec = npc.rec
    local band = PR.bandOf(rec)
    if band then Rem.changeRep(band.id, CFG.RELEASE_REP, "soltou um dos nossos") end
    Rem.Journal.add("IGUI_Rem_Journal_prisoner_released", tostring(rec.name))
    sendHome(npc, rec)
    return true, line("IGUI_Rem_Prisoner_released")
end

function PR.recruitHint(npc)
    local rec = npc.rec
    local held = rec.heldSince and (hours() - rec.heldSince) or 0
    return line("IGUI_Rem_Hint_prisoner", tostring(math.floor(held)), tostring(CFG.RECRUIT_HOURS),
        tostring(math.floor(rec.moral or 50)), tostring(CFG.RECRUIT_MORALE))
end

function PR.recruit(npc)
    local rec = npc.rec
    local held = rec.heldSince and (hours() - rec.heldSince) or 0
    if rec.prisoner ~= "held" or held < CFG.RECRUIT_HOURS or (rec.moral or 50) < CFG.RECRUIT_MORALE then
        return false, line("IGUI_Rem_Prisoner_notyet")
    end
    if Rem.Council then Rem.Council.vote("prisoner", rec) end
    dropFromBase(rec)
    rec.prisoner, rec.cell, rec.bandId = nil, nil, nil
    rec.faction, rec.recruited = "aliados", true
    rec.temper = "defensivo"
    rec.hostileToPlayer = false
    rec.mode = "group"
    Rem.applyFriendlyFire(npc)
    local ok = PB.join(npc)
    if not ok then rec.mode = "follow" end
    Rem.Journal.add("IGUI_Rem_Journal_prisoner_joined", tostring(rec.name))
    Rem.emit("playerDeed", "recruited", npc)
    return true, line("IGUI_Rem_Prisoner_joined")
end

-- ---------------------------------------------------------------- conversa
function PR.dialogOptions(npc, player)
    local rec = npc.rec
    local out = {}
    if rec.surrendered and not rec.prisoner then table.insert(out, "prisoner_take") return out end
    if not rec.prisoner then return out end
    local g = base()
    if rec.prisoner == "escort" and g and inBase(npc, g) then table.insert(out, "prisoner_hold") end
    table.insert(out, "prisoner_interrogate")
    if PR.canRansom(npc) then table.insert(out, "prisoner_ransom") end
    if rec.prisoner == "held" then table.insert(out, "prisoner_recruit") end
    table.insert(out, "prisoner_release")
    return out
end

function PR.choose(id, npc, player)
    if id == "prisoner_take" then return PR.take(npc) end
    if id == "prisoner_hold" then return PR.hold(npc) end
    if id == "prisoner_interrogate" then return PR.interrogate(npc, player) end
    if id == "prisoner_ransom" then return PR.ransom(npc) end
    if id == "prisoner_recruit" then return PR.recruit(npc) end
    if id == "prisoner_release" then return PR.release(npc) end
    return false, line("IGUI_Rem_Talk_bye")
end

-- ---------------------------------------------------------------- comportamento
function PR.behavior(npc, ctx, now)
    local rec = npc.rec
    if not rec.prisoner then return false end
    local player = ctx.player
    if rec.prisoner == "escort" then
        if player and Rem.dist(npc.z, player) > CFG.ESCORT_DIST then
            local d = Rem.dist(npc.z, player)
            Rem.clearRest(npc)
            Rem.moveTo(npc, player:getX(), player:getY(), player:getZ(), now, (d > 8) and "run" or "walk")
        else
            Rem.stopMoving(npc)
            Rem.idle(npc, now)
        end
        return true
    end
    -- preso na base: sentado no canto dele
    local c = rec.cell
    if c and Rem.dist2(npc.z:getX(), npc.z:getY(), c.x + 0.5, c.y + 0.5) > 1.2 then
        Rem.clearRest(npc)
        Rem.moveTo(npc, c.x + 0.5, c.y + 0.5, c.z or 0, now, "walk")
        return true
    end
    Rem.stopMoving(npc)
    Rem.setRest(npc, "sit")
    if player and Rem.dist(npc.z, player) < 6 then Rem.bark(npc, "prisoner_idle") end
    return true
end
Rem.registerBehavior({ name = "prisoner", priority = CFG.PRIORITY, run = PR.behavior })

-- Preso levado por voce e que ficou para tras (voce correu, pegou um carro): reaparece perto.
Rem.on("sceneUpdate", function(player, now)
    for _, rec in pairs(Rem.getStore().people) do
        if rec.prisoner == "escort" and not rec.onScene and rec.x and Rem.Companion
            and Rem.dist2(player:getX(), player:getY(), rec.x, rec.y) > Rem.Companion.CFG.PAPER_DIST then
            local sq = Rem.Companion.placeNear(player)
            if sq then rec.x, rec.y, rec.z, rec.pid = sq:getX() + 0.5, sq:getY() + 0.5, sq:getZ(), nil end
        end
    end
end)

-- ---------------------------------------------------------------- a cada hora: comer, fugir
function PR.escapeChance(g)
    local c = CFG.ESCAPE_BASE
    if not (Rem.Watch and Rem.Watch.covered(g)) then c = c + CFG.ESCAPE_UNWATCHED end
    if (g.supplies or 0) <= 0 then c = c + CFG.ESCAPE_HUNGRY end
    return c
end

function PR.escape(g, rec)
    local band = PR.bandOf(rec)
    Rem.Journal.add("IGUI_Rem_Journal_prisoner_escaped", tostring(rec.name))
    -- conta ao bando onde fica a sua base: o proximo ataque pode vir logo
    if band then g.lastRaid = nil end
    local npc = nil
    for _, a in pairs(Rem.active) do if a.rec == rec then npc = a end end
    sendHome(npc, rec)
end

function PR.hourly()
    local g = base()
    if not g then return end
    local list = PR.list(g)
    for _, rec in ipairs(list) do
        -- come do estoque (como um morador)
        if (g.supplies or 0) > 0 then
            g.supplies = math.max(0, g.supplies - 1 / 24)
            rec.fome = math.max(0, (rec.fome or 0) - 6)
            if Rem.Persona then Rem.Persona.addMorale(rec, 1) end
        else
            rec.fome = math.min(100, (rec.fome or 0) + 3)
            if Rem.Persona then Rem.Persona.addMorale(rec, -2) end
        end
        -- (com voce olhando, ninguem foge)
        if not rec.onScene and ZombRand(100) < PR.escapeChance(g) then PR.escape(g, rec) end
    end
end
Rem.on("worldHour", function() Rem.safe(PR.hourly) end)

-- morreu (zumbi, briga): sai da lista
Rem.on("personRemoved", function(rec) if rec and rec.prisoner then dropFromBase(rec) end end)
