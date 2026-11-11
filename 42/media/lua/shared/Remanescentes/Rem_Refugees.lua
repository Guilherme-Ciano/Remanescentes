-- Remanescentes - refugiados: quando uma base cai, nem todo mundo morre.
--
-- Uma base que cai para a horda (Rem_Evolution) ou um grupo pequeno que perde um ataque e
-- nao se sustenta mais: quem escapa vira refugiado e vai procurar abrigo.
--   * destino: o grupo amigo mais perto com lugar (mesma faccao ou faccao nao hostil);
--     ou a SUA base, se eles confiavam em voce (reputacao ou alianca com o grupo antigo);
--   * no caminho, longe de voce, andam no papel; perto de voce, andam de verdade pela rua -
--     e voce pode chamar: "[Refugiado] Venha para a nossa base.";
--   * chegando: o grupo de destino recebe (cresce); na sua base, os moradores decidem
--     (precisa ter lugar e comida).
-- Tudo vai para o Diario quando voce conhece o grupo.
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_Journal"
require "Remanescentes/Rem_PlayerBase"
local Rem = Remanescentes
local PB = Rem.PlayerBase

local RF = Rem.module("Refugees", {
    ESCAPE = 40,              -- (%) cada morador de uma base que caiu
    SPEED = 120,              -- tiles por hora (fora de cena)
    ARRIVE = 10,
    MAX_TARGET = 700,
    BASE_REP = 20,            -- reputacao com o grupo antigo para virem para a sua base (familias comecam em 10)
    JOIN_MAX = 8,
    FOOD_DAYS = 1,
    DISSOLVE_AT = 2,          -- grupo que perdeu um ataque e ficou com ate tantos: se desfaz
    PRIORITY = 280,
    STEP = 30,                -- em cena: andam ate um ponto a tantos tiles na direcao do destino
    LOST_HOURS = 12,          -- sem destino: somem pelo mundo depois disso
})
local CFG = RF.CFG

Rem.BARKS.refugee = { n = 3, cd = 90000 }
Rem.BARKS.refugee_thanks = { urgent = true, n = 2, cd = 0 }

local function groups() return Rem.getStore().groups end
local function known(g) return g and Rem.Journal.knows(g) end

function RF.list()
    local out = {}
    for _, rec in pairs(Rem.getStore().people) do if rec.mode == "refugee" then table.insert(out, rec) end end
    table.sort(out, function(a, b) return tostring(a.id) < tostring(b.id) end)
    return out
end

-- ---------------------------------------------------------------- destino
function RF.pickTarget(rec, x, y, old)
    local best, bestD = nil, nil
    for _, g in pairs(groups()) do
        if g ~= old and g.home and not g.player and #g.members > 0 and #g.members < CFG.JOIN_MAX
            and not Rem.factionsHostile(rec.faction, g.faction) and g.faction ~= "saqueadores" then
            local d = Rem.dist2(x, y, g.home.x, g.home.y)
            if d <= CFG.MAX_TARGET and (not bestD or d < bestD) then best, bestD = g, d end
        end
    end
    -- a sua base, se confiavam em voce
    local base = PB.get()
    local trust = rec.refugeeTrust
    if base and trust and not rec.refusedByBase then
        local d = Rem.dist2(x, y, base.home.x, base.home.y)
        if d <= CFG.MAX_TARGET and (not bestD or d < bestD * 1.5) then
            return { gid = base.id, x = base.home.x, y = base.home.y }
        end
    end
    if best then return { gid = best.id, x = best.home.x, y = best.home.y } end
    return nil
end

-- Quem escapa de g vira refugiado. chance: (%) de cada um escapar. Retorna a lista.
function RF.flee(g, chance)
    local out = {}
    local hx, hy = g.home and g.home.x or g.x, g.home and g.home.y or g.y
    local trust = (g.allied == true) or (Rem.getRep(g.id) >= CFG.BASE_REP)
    for i = #g.members, 1, -1 do
        local rec = Rem.getPerson(g.members[i])
        if rec and not rec.onScene and ZombRand(100) < (chance or CFG.ESCAPE) then
            table.remove(g.members, i)
            rec.groupId, rec.role, rec.job = nil, nil, nil
            rec.mode = "refugee"
            rec.refugeeOf = Rem.Journal.groupName(g)
            rec.refugeeTrust = trust
            rec.refugeeSince = Rem.worldHours()
            rec.x, rec.y, rec.z, rec.pid = hx + ZombRandFloat(-3, 3), hy + ZombRandFloat(-3, 3), 0, nil
            rec.refTarget = RF.pickTarget(rec, hx, hy, g)
            table.insert(out, rec)
        end
    end
    if #out > 0 and known(g) then Rem.Journal.add("IGUI_Rem_Journal_refugees", tostring(#out), Rem.Journal.groupName(g)) end
    if #out > 0 then Rem.emit("refugeesFled", g, out) end
    return out
end

-- ---------------------------------------------------------------- chegar
local function joinGroup(rec, g)
    rec.mode, rec.refTarget = "group", nil
    rec.groupId = g.id
    rec.faction = g.faction
    table.insert(g.members, rec.id)
end

function RF.arrive(rec)
    local t = rec.refTarget
    local g = t and groups()[t.gid]
    if g and g.player then
        local food = Rem.BaseEvents and Rem.BaseEvents.foodDays(g) or (g.supplies or 0)
        if #g.members < PB.CFG.MAX_MEMBERS and food >= CFG.FOOD_DAYS then
            rec.faction, rec.recruited, rec.temper, rec.hostileToPlayer = "aliados", true, "defensivo", false
            rec.mode, rec.refTarget = "group", nil
            rec.groupId = g.id
            rec.job = PB.defaultJob(g)
            if PB.assignRole then PB.assignRole(rec) end
            table.insert(g.members, rec.id)
            Rem.Journal.add("IGUI_Rem_Journal_refugee_base", tostring(rec.name), tostring(rec.refugeeOf))
            Rem.emit("playerBaseMember", g, rec, "refugee")
            return "base"
        end
        rec.refusedByBase = true
        Rem.Journal.add("IGUI_Rem_Journal_refugee_away", tostring(rec.name))
        rec.refTarget = RF.pickTarget(rec, rec.x or g.home.x, rec.y or g.home.y, g)
        return "away"
    end
    if g and #g.members < CFG.JOIN_MAX then
        joinGroup(rec, g)
        if known(g) then Rem.Journal.add("IGUI_Rem_Journal_refugee_joined", tostring(rec.name), Rem.Journal.groupName(g)) end
        return "joined"
    end
    -- o destino sumiu ou lotou: procura outro
    rec.refTarget = RF.pickTarget(rec, rec.x or 0, rec.y or 0, g)
    return "retarget"
end

-- ---------------------------------------------------------------- a cada hora
function RF.hourly()
    -- grupos pequenos que perderam um ataque: se desfazem
    local dissolve = {}
    for id, g in pairs(groups()) do if g.dissolve then table.insert(dissolve, id) end end
    table.sort(dissolve)
    for _, id in ipairs(dissolve) do
        local g = groups()[id]
        g.dissolve = nil
        RF.flee(g, 100)
        if #g.members == 0 then
            groups()[id] = nil
            local s = Rem.getStore()
            s.abandoned = s.abandoned or {}
            if g.home and g.home.bid then s.abandoned[g.home.bid] = Rem.worldHours() end
            Rem.emit("groupRemoved", g)
        end
    end
    local hours = Rem.worldHours()
    for _, rec in ipairs(RF.list()) do
        if not rec.onScene then
            local t = rec.refTarget
            if not t then
                if hours - (rec.refugeeSince or hours) >= CFG.LOST_HOURS then Rem.removePerson(rec.id) end
            else
                local x, y = rec.x or t.x, rec.y or t.y
                local d = Rem.dist2(x, y, t.x, t.y)
                if d <= CFG.ARRIVE + CFG.SPEED then
                    rec.x, rec.y = t.x, t.y
                    RF.arrive(rec)
                else
                    rec.x, rec.y = x + (t.x - x) / d * CFG.SPEED, y + (t.y - y) / d * CFG.SPEED
                    rec.pid = nil
                end
            end
        end
    end
end
Rem.on("worldHour", function() Rem.safe(RF.hourly) end)

Rem.on("raidResolved", function(attacker, victim, winner)
    if victim and winner ~= victim and not victim.player and #victim.members > 0 and #victim.members <= CFG.DISSOLVE_AT then
        victim.dissolve = true
    end
end)

-- ---------------------------------------------------------------- em cena
function RF.behavior(npc, ctx, now)
    local rec = npc.rec
    if rec.mode ~= "refugee" then return false end
    local t = rec.refTarget
    if not t then
        Rem.idle(npc, now)
        return true
    end
    local d = Rem.distXY(npc.z, t.x, t.y)
    if d <= CFG.ARRIVE then
        RF.arrive(rec)
        return true
    end
    local step = math.min(d, CFG.STEP)
    local tx = npc.z:getX() + (t.x - npc.z:getX()) / d * step
    local ty = npc.z:getY() + (t.y - npc.z:getY()) / d * step
    Rem.moveTo(npc, tx, ty, 0, now, "walk")
    if ctx.player and Rem.dist(npc.z, ctx.player) < 12 then Rem.bark(npc, "refugee") end
    return true
end
Rem.registerBehavior({ name = "refugee", priority = CFG.PRIORITY, run = RF.behavior })

-- Conversa: chamar para a sua base.
function RF.canInvite(npc)
    return npc.rec.mode == "refugee" and PB.get() ~= nil and not Rem.isHostileToPlayer(npc)
end

function RF.invite(npc)
    local rec = npc.rec
    local g = PB.get()
    if not g then return false, { key = "IGUI_Rem_Base_none", args = {} } end
    if #g.members >= PB.CFG.MAX_MEMBERS then return false, { key = "IGUI_Rem_Base_full", args = { tostring(PB.CFG.MAX_MEMBERS) } } end
    if Rem.Council then Rem.Council.vote("newcomer", rec) end
    rec.faction, rec.recruited, rec.temper, rec.hostileToPlayer = "aliados", true, "defensivo", false
    rec.refTarget, rec.mode = nil, "follow"
    Rem.applyFriendlyFire(npc)
    local ok, l = PB.join(npc)
    if ok then
        Rem.bark(npc, "refugee_thanks", true)
        Rem.emit("playerDeed", "recruited", npc)
    end
    return ok, l
end
