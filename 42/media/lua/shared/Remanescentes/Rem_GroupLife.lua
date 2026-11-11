-- Remanescentes - os grupos de NPC tambem constroem as bases deles (o mesmo sistema da sua).
--
-- Mestre de obras (a cada hora): cada grupo com casa divide o trabalho entre os moradores,
-- conforme a faccao (Rem_BaseBuild.projectsFor), o material e o tamanho do grupo:
--   guard      o guarda da porta (papel "guarda")
--   build      quem fortifica (metade dos outros, se houver material e obra por fazer)
--   materials  uma dupla saindo para buscar tabua e prego (se o material esta acabando)
--   rest       o resto (rotina da casa)
-- Fome continua sendo do grupo todo (Rem_World: saem juntos para saquear).
-- Longe de voce: obras (Rem_BaseBuild), saidas de material em dupla, e hordas que testam
-- as defesas (cercas caem, gente morre; base sem defesa cai mais facil - Rem_Evolution).
-- Voce ve o resultado quando passar por la: tabuas, cercas, arame farpado, carros na rua.
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_BaseBuild"
require "Remanescentes/Rem_PlayerBase"
require "Remanescentes/Rem_BaseEvents"
require "Remanescentes/Rem_Journal"
local Rem = Remanescentes
local BB, PB, BE = Rem.BaseBuild, Rem.PlayerBase, Rem.BaseEvents

local GL = Rem.module("GroupLife", {
    BUILD_SHARE = 0.5,         -- fracao dos moradores (fora o guarda) que fortifica
    MAT_LOW = 6,               -- material abaixo disso: uma dupla sai para buscar
    MAT_ENOUGH = 2,            -- material para alguem fortificar
    HORDE_CHANCE = 1,          -- (%) por hora de noite, por grupo de NPC
    HORDE_COOLDOWN_H = 48,
})
local CFG = GL.CFG

local function night()
    local tod = getGameTime():getTimeOfDay()
    return tod >= 21 or tod < 5
end

local function work(h)
    if not h.plan then return true end      -- (ainda nao sabe: supoe que ha obra)
    for _, n in pairs(h.plan) do if n > 0 then return true end end
    return false
end

-- Divide as tarefas do grupo. Retorna { build = n, materials = n, guard = n, rest = n }.
function GL.assignJobs(g)
    local count = { build = 0, materials = 0, guard = 0, rest = 0 }
    if g.player or not g.home or not g.home.x1 or #BB.projectsFor(g) == 0 then return count end
    local list = {}
    for _, id in ipairs(g.members) do
        local p = Rem.getPerson(id)
        if p and p.mode == "group" then table.insert(list, p) end
    end
    table.sort(list, function(a, b) return tostring(a.id) < tostring(b.id) end)
    local others = {}
    for _, p in ipairs(list) do
        if p.role == "guarda" then
            p.job = "guard"
            count.guard = count.guard + 1
        else
            table.insert(others, p)
        end
    end
    local mats = Rem.Director.materials(g)
    local pending = work(g.home)
    local wantMat = (pending and mats < CFG.MAT_LOW and #others >= 2) and 2 or 0
    local wantBuild = (pending and mats >= CFG.MAT_ENOUGH) and math.max(1, math.floor((#others - wantMat) * CFG.BUILD_SHARE)) or 0
    for _, p in ipairs(others) do
        if wantMat > 0 then
            p.job, wantMat = "materials", wantMat - 1
        elseif wantBuild > 0 then
            p.job, wantBuild = "build", wantBuild - 1
        else
            p.job = "rest"
        end
        count[p.job] = count[p.job] + 1
    end
    return count
end

-- Saidas de material de quem esta longe de voce (em dupla).
function GL.trips(g)
    local hours = Rem.worldHours()
    local tod = getGameTime():getTimeOfDay()
    if tod < 7 or tod >= 19 then return 0 end
    local n = 0
    for _, id in ipairs(g.members) do
        local rec = Rem.getPerson(id)
        if rec and rec.job == "materials" and not rec.onScene and PB.ready(rec, hours) then
            local partner = PB.partnerFor(g, rec, false)
            if partner then
                PB.tripOffscene(g, rec, partner, "materials")
                n = n + 1
            end
        end
    end
    return n
end

-- Quem estava numa saida quando voce foi embora volta para a rotina.
function GL.resetTrips(g)
    for _, id in ipairs(g.members) do
        local rec = Rem.getPerson(id)
        if rec and not rec.onScene and (rec.mode == "scav" or rec.mode == "escort") then
            for _, ft in ipairs(rec.carry or {}) do
                local v = PB.CFG.MATERIAL_ITEMS[ft]
                if v then g.materials = Rem.Director.materials(g) + v else g.pendingItems = (g.pendingItems or 0) + 1 end
            end
            rec.carry = nil
            if rec.lootTarget and rec.lootTarget.bid then Rem.getStore().looted[rec.lootTarget.bid] = Rem.worldHours() end
            rec.mode, rec.lootTarget, rec.escortOf, rec.partnerId, rec.tripKind = "group", nil, nil, nil, nil
            rec.lastTrip = Rem.worldHours()
        end
    end
end

-- Horda testando a base de um grupo de NPC (longe de voce).
function GL.horde(g)
    g.lastHorde = Rem.worldHours()
    local n = ZombRand(BE.CFG.HORDE_SIZE[1], BE.CFG.HORDE_SIZE[2] + 1)
    local def = BE.defense(g)
    local known = Rem.Journal.knows(g)
    if def * 2 >= n then
        local dmg = ZombRand(0, 3)
        if dmg > 0 then BB.damageFence(g, dmg) end
        return "held"
    end
    BB.damageFence(g, ZombRand(3, 7))
    local list = {}
    for _, id in ipairs(g.members) do
        local p = Rem.getPerson(id)
        if p and not p.onScene then table.insert(list, p) end
    end
    local victim = list[ZombRand(math.max(1, #list)) + 1]
    if victim and def < n / 3 and ZombRand(100) < 50 then
        if Rem.Persona then Rem.Persona.mourn(victim) end
        Rem.removePerson(victim.id)
        if known then Rem.Journal.add("IGUI_Rem_Journal_npc_horde_dead", Rem.Journal.groupName(g), tostring(victim.name)) end
        return "dead"
    end
    if victim then victim.hp = (victim.hp or victim.maxHealth or 2) * 0.5 end
    if known then Rem.Journal.add("IGUI_Rem_Journal_npc_horde", Rem.Journal.groupName(g)) end
    return "hurt"
end

function GL.hourly()
    local hours = Rem.worldHours()
    local list = {}
    for _, g in pairs(Rem.getStore().groups) do
        if not g.player and g.home and g.home.x1 and #g.members > 0 then table.insert(list, g) end
    end
    table.sort(list, function(a, b) return tostring(a.id) < tostring(b.id) end)
    for _, g in ipairs(list) do
        GL.resetTrips(g)
        if g.activity == "home" then
            GL.assignJobs(g)
            GL.trips(g)
            local away = true
            for _, id in ipairs(g.members) do
                local p = Rem.getPerson(id)
                if p and p.onScene then away = false end
            end
            if away and night() and hours - (g.lastHorde or -999) >= CFG.HORDE_COOLDOWN_H and ZombRand(100) < CFG.HORDE_CHANCE then
                GL.horde(g)
            end
        end
    end
end
Rem.on("worldHour", function() Rem.safe(GL.hourly) end)

-- obra terminada num grupo que voce conhece: noticia
Rem.on("baseProjectDone", function(g, project)
    if not g.player and Rem.Journal.knows(g) then
        Rem.Journal.add("IGUI_Rem_Journal_npc_done", Rem.Journal.groupName(g), getText("IGUI_Rem_Project_" .. project))
    end
end)
