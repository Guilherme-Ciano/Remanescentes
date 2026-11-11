-- Remanescentes - guerra entre faccoes.
--
-- Dois grupos com casa, perto um do outro e com a relacao no fundo do poco (Rem_Relations
-- <= WAR_AT) entram em guerra:
--   * atacam um ao outro com frequencia (fora de cena, pelo Rem_World; perto de voce os
--     ataques acontecem de verdade, gente contra gente);
--   * as noticias vao para o Diario se voce conhece um dos lados;
--   * municao e remedio valem bem mais nas trocas com quem esta em guerra (Rem_Territory).
-- Voce pode escolher um lado ("[Guerra] Estou do lado de voces."): a reputacao com eles
-- sobe e com o inimigo cai. Cada inimigo deles que voce mata conta a mais. Se o seu lado
-- vencer, eles nao esquecem.
-- A guerra acaba quando um lado some, ou numa tregua depois de alguns dias sem ataques
-- (a relacao volta a subir aos poucos).
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_Journal"
require "Remanescentes/Rem_Relations"
local Rem = Remanescentes

local WR = Rem.module("War", {
    WAR_AT = -80,
    RADIUS = 400,
    MIN_MEMBERS = 3,
    RAID_CHANCE = 6,          -- (%) por hora (de dia), para cada lado em casa
    TRUCE_DAYS = 6,
    TRUCE_RECOVER = 4,        -- relacao que volta por dia de guerra
    TRUCE_AT = -40,
    SIDE_REP = 15,
    SIDE_ENEMY_REP = -25,
    KILL_REP = 5,
    WIN_REP = 20,
    NO_WAR = { errantes = true },
})
local CFG = WR.CFG

local function wars()
    local s = Rem.getStore()
    s.wars = s.wars or {}
    return s.wars
end

local function key(a, b)
    if a.id < b.id then return a.id .. "|" .. b.id end
    return b.id .. "|" .. a.id
end

local function groups() return Rem.getStore().groups end

function WR.list()
    local out = {}
    for k, w in pairs(wars()) do table.insert(out, w) end
    table.sort(out, function(x, y) return x.key < y.key end)
    return out
end

function WR.between(a, b) return wars()[key(a, b)] end

-- Inimigo de guerra de g (o primeiro), ou nil.
function WR.enemyOf(g)
    if not g then return nil end
    for _, w in ipairs(WR.list()) do
        if w.a == g.id then return groups()[w.b] end
        if w.b == g.id then return groups()[w.a] end
    end
    return nil
end

local function known(g) return g and Rem.Journal.knows(g) end

local function eligible(g)
    return g.home and not g.player and #g.members >= CFG.MIN_MEMBERS and not CFG.NO_WAR[g.faction]
end

-- ---------------------------------------------------------------- declarar e acabar
function WR.declare(a, b)
    local k = key(a, b)
    if wars()[k] then return wars()[k] end
    local w = { key = k, a = a.id, b = b.id, since = Rem.worldHours(), lastRaid = Rem.worldHours() }
    wars()[k] = w
    if known(a) or known(b) then
        Rem.Journal.add("IGUI_Rem_Journal_war", Rem.Journal.groupName(a), Rem.Journal.groupName(b))
    end
    Rem.emit("warDeclared", a, b)
    return w
end

function WR.finish(w, winner, reason)
    wars()[w.key] = nil
    local a, b = groups()[w.a], groups()[w.b]
    if reason == "truce" then
        if known(a) or known(b) then
            Rem.Journal.add("IGUI_Rem_Journal_war_truce", Rem.Journal.groupName(a), Rem.Journal.groupName(b))
        end
    elseif winner then
        if known(winner) then Rem.Journal.add("IGUI_Rem_Journal_war_won", Rem.Journal.groupName(winner)) end
        -- voce estava do lado de quem venceu
        if w.side == winner.id then Rem.changeRep(winner.id, CFG.WIN_REP, "vencemos a guerra juntos") end
    end
    Rem.emit("warEnded", w, winner, reason)
end

function WR.daily()
    local list = {}
    for _, g in pairs(groups()) do if eligible(g) then table.insert(list, g) end end
    table.sort(list, function(x, y) return x.id < y.id end)
    for i = 1, #list do
        for j = i + 1, #list do
            local a, b = list[i], list[j]
            if Rem.relation(a, b) <= CFG.WAR_AT and Rem.dist2(a.home.x, a.home.y, b.home.x, b.home.y) <= CFG.RADIUS then
                WR.declare(a, b)
            end
        end
    end
    -- tregua: dias sem ataque fazem a raiva baixar
    local hours = Rem.worldHours()
    for _, w in ipairs(WR.list()) do
        local a, b = groups()[w.a], groups()[w.b]
        if a and b then
            if hours - (w.lastRaid or w.since) >= 24 then Rem.changeRelation(a, b, CFG.TRUCE_RECOVER) end
            if hours - (w.lastRaid or w.since) >= CFG.TRUCE_DAYS * 24 and Rem.relation(a, b) > CFG.TRUCE_AT then
                WR.finish(w, nil, "truce")
            end
        end
    end
end
Events.EveryDays.Add(function() if Rem.isAuthority() then Rem.safe(WR.daily) end end)

-- Um lado sumiu: o outro venceu.
Rem.on("groupRemoved", function(g)
    for _, w in ipairs(WR.list()) do
        if w.a == g.id or w.b == g.id then
            local other = groups()[(w.a == g.id) and w.b or w.a]
            WR.finish(w, other, "won")
        end
    end
end)

Rem.on("raidResolved", function(attacker, victim, winner)
    local w = attacker and victim and WR.between(attacker, victim)
    if not w then return end
    w.lastRaid = Rem.worldHours()
    if known(attacker) or known(victim) then
        Rem.Journal.add("IGUI_Rem_Journal_war_battle", Rem.Journal.groupName(attacker), Rem.Journal.groupName(victim),
            Rem.Journal.groupName(winner))
    end
end)

-- ---------------------------------------------------------------- ataques
-- Por hora (de dia): cada lado em casa pode partir para cima do outro.
function WR.hourly()
    local tod = getGameTime():getTimeOfDay()
    if tod < 7 or tod > 19 then return end
    for _, w in ipairs(WR.list()) do
        local a, b = groups()[w.a], groups()[w.b]
        if a and b then
            for _, pair in ipairs({ { a, b }, { b, a } }) do
                local g, enemy = pair[1], pair[2]
                if g.activity == "home" and #g.members >= 2 and ZombRand(100) < CFG.RAID_CHANCE then
                    g.activity = "raid"
                    g.target = { x = enemy.home.x, y = enemy.home.y, z = 0, victim = enemy.id }
                    g.arrivedAt = nil
                    Rem.debug("guerra: " .. g.id .. " ataca " .. enemy.id)
                    break
                end
            end
        end
    end
end
Rem.on("worldHour", function() Rem.safe(WR.hourly) end)

-- ---------------------------------------------------------------- escolher um lado
function WR.canSide(npc)
    local g = npc.rec.groupId and groups()[npc.rec.groupId]
    if not g or Rem.isHostileToPlayer(npc) then return false end
    local enemy = WR.enemyOf(g)
    if not enemy then return false end
    return WR.between(g, enemy).side == nil
end

function WR.side(npc)
    local g = npc.rec.groupId and groups()[npc.rec.groupId]
    local enemy = WR.enemyOf(g)
    if not enemy then return false, { key = "IGUI_Rem_War_none", args = {} } end
    local w = WR.between(g, enemy)
    if Rem.Council then Rem.Council.vote("war", g) end
    w.side = g.id
    Rem.changeRep(g.id, CFG.SIDE_REP, "do nosso lado na guerra")
    Rem.changeRep(enemy.id, CFG.SIDE_ENEMY_REP, "do lado do inimigo")
    Rem.Journal.add("IGUI_Rem_Journal_war_side", Rem.Journal.groupName(g), Rem.Journal.groupName(enemy))
    return true, { key = "IGUI_Rem_War_side_ok", args = { Rem.Journal.groupName(enemy) } }
end

-- Voce matou alguem do inimigo do seu lado: conta a mais.
Rem.on("npcDied", function(npc)
    local by = nil
    pcall(function() by = npc.z:getAttackedBy() end)
    if not by or not Rem.isPlayerObj(by) then return end
    local g = npc.rec.groupId and groups()[npc.rec.groupId]
    if not g then return end
    for _, w in ipairs(WR.list()) do
        if w.side and (w.a == g.id or w.b == g.id) and w.side ~= g.id then
            Rem.changeRep(w.side, CFG.KILL_REP, "matou um inimigo nosso")
        end
    end
end)

-- "Como vao as coisas?" de quem esta em guerra.
function WR.status(npc)
    local g = npc.rec.groupId and groups()[npc.rec.groupId]
    local enemy = WR.enemyOf(g)
    if not enemy then return nil end
    return { key = "IGUI_Rem_War_status", args = { Rem.Journal.groupName(enemy) } }
end

Rem.registerDebugOption("ContextMenu_Rem_WarNearest", function(x, y, z, player)
    local list = {}
    for _, g in pairs(groups()) do if eligible(g) then table.insert(list, g) end end
    table.sort(list, function(p, q) return Rem.dist2(x, y, p.home.x, p.home.y) < Rem.dist2(x, y, q.home.x, q.home.y) end)
    if #list < 2 then player:Say("-") return end
    Rem.changeRelation(list[1], list[2], -200)
    WR.declare(list[1], list[2])
    player:Say("guerra: " .. list[1].id .. " x " .. list[2].id)
end, "world")
