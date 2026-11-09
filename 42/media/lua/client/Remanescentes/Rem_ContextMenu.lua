-- Remanescentes - menu de clique direito: comandar sobreviventes e ferramentas de teste.
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_Factions"
require "Remanescentes/Rem_Spawn"
require "Remanescentes/Rem_Barks"
require "Remanescentes/Rem_World"
local Rem = Remanescentes

local function npcsNear(square)
    local found = {}
    if not square then return found end
    local cell = getCell()
    for dx = -1, 1 do
        for dy = -1, 1 do
            local sq = cell:getGridSquare(square:getX() + dx, square:getY() + dy, square:getZ())
            if sq then
                local objs = sq:getMovingObjects()
                for i = 0, objs:size() - 1 do
                    local npc = Rem.active[objs:get(i)]
                    if npc then found[npc.key] = npc end
                end
            end
        end
    end
    return found
end

-- ---------------------------------------------------------------- comandos a um sobrevivente
local function setMode(npc, mode)
    npc.rec.mode = mode
    if mode == "stay" then
        npc.rec.homeX = math.floor(npc.z:getX())
        npc.rec.homeY = math.floor(npc.z:getY())
        npc.rec.homeZ = math.floor(npc.z:getZ())
        Rem.bark(npc, "stay", true)
    elseif mode == "follow" then
        Rem.bark(npc, "follow", true)
    end
end

local function setStealth(npc, on)
    npc.rec.stealth = on
    npc.sneaking = nil
    npc.z:setVariable("RemSneak", on)
    Rem.bark(npc, on and "sneak" or "normal", true)
end

local function showStatus(npc)
    local maxH = npc.rec.maxHealth or 1
    local pct = math.floor(npc.z:getHealth() / maxH * 100)
    Rem.say(npc, "IGUI_Rem_SayStatus", npc.rec.name or "?", tostring(pct))
end

-- ---------------------------------------------------------------- ferramentas de teste
local function sayToPlayer(text)
    local p = getPlayer()
    if p then p:Say(text) end
end

local function groupInfo(g, d)
    local members = 0
    for _ in ipairs(g.members) do members = members + 1 end
    return string.format("%s %s [%s] %d pessoas, %s, suprimentos %.1f, a %d tiles",
        g.id, g.name or "", g.faction, members, g.activity, g.supplies or 0, math.floor(d))
end

local function showNearestGroup()
    local p = getPlayer()
    local g, d = Rem.nearestGroup(p:getX(), p:getY())
    if not g then sayToPlayer("Nenhum grupo no mundo.") return end
    sayToPlayer(groupInfo(g, d))
    Rem.log("mais proximo: " .. groupInfo(g, d))
end

local function listGroups()
    local p = getPlayer()
    Rem.log("---- grupos ----")
    local n = 0
    for _, g in pairs(Rem.getStore().groups) do
        n = n + 1
        Rem.log(groupInfo(g, Rem.dist2(p:getX(), p:getY(), g.x, g.y)))
    end
    sayToPlayer(n .. " grupos (lista no console.txt)")
end

local function goToNearestGroup()
    local p = getPlayer()
    local g = Rem.nearestGroup(p:getX(), p:getY())
    if not g then sayToPlayer("Nenhum grupo no mundo.") return end
    -- para perto, nao em cima
    p:teleportTo(math.floor(g.x) + 12, math.floor(g.y) + 12, 0)
end

local function simulateHours(h)
    Rem.simulateWorld(h)
    sayToPlayer("Simuladas " .. h .. " horas.")
end

local function createGroupHere(x, y, faction)
    local g = Rem.createGroup(faction, math.floor(x), math.floor(y), nil, 3)
    if g then sayToPlayer("Grupo " .. g.id .. " (" .. faction .. ") criado aqui.") end
end

-- ---------------------------------------------------------------- menu
local function onFillWorldMenu(playerNum, context, worldobjects, test)
    if test then return end
    local square = nil
    for _, obj in ipairs(worldobjects) do
        square = obj:getSquare()
        if square then break end
    end
    if not square then return end

    local near = npcsNear(square)
    local hasNear = next(near) ~= nil
    local debugMenu = Rem.cfg("DebugMenu", true)
    if not hasNear and not debugMenu then return end

    local root = context:addOption(getText("ContextMenu_Rem_Title"), worldobjects, nil)
    local sub = ISContextMenu:getNew(context)
    context:addSubMenu(root, sub)

    if isClient() then
        sub:addOption(getText("ContextMenu_Rem_MPNotSupported"), nil, nil)
        return
    end

    -- sobreviventes perto do clique (amigos aceitam ordens)
    for _, npc in pairs(near) do
        local label = (npc.rec.name or "?") .. "  [" .. getText("IGUI_Rem_Faction_" .. tostring(npc.rec.faction)) .. "]"
        local opt = sub:addOption(label, nil, nil)
        local npcMenu = ISContextMenu:getNew(sub)
        sub:addSubMenu(opt, npcMenu)
        if Rem.isFriendly(npc) then
            npcMenu:addOption(getText("ContextMenu_Rem_Follow"), npc, setMode, "follow")
            npcMenu:addOption(getText("ContextMenu_Rem_Stay"), npc, setMode, "stay")
            if npc.rec.stealth then
                npcMenu:addOption(getText("ContextMenu_Rem_Normal"), npc, setStealth, false)
            else
                npcMenu:addOption(getText("ContextMenu_Rem_Stealth"), npc, setStealth, true)
            end
        end
        npcMenu:addOption(getText("ContextMenu_Rem_Info"), npc, showStatus)
        if debugMenu then npcMenu:addOption(getText("ContextMenu_Rem_Dismiss"), npc, Rem.dismiss) end
    end

    if not debugMenu then return end
    local x, y, z = square:getX() + 0.5, square:getY() + 0.5, square:getZ()

    local dopt = sub:addOption(getText("ContextMenu_Rem_Debug"), nil, nil)
    local dbg = ISContextMenu:getNew(sub)
    sub:addSubMenu(dopt, dbg)
    dbg:addOption(getText("ContextMenu_Rem_SpawnAlly"), nil, function()
        Rem.spawn(x, y, z, { faction = "aliados", mode = "follow" })
    end)
    dbg:addOption(getText("ContextMenu_Rem_SpawnCivil"), nil, function()
        Rem.spawn(x, y, z, { faction = "civis", mode = "wander" })
    end)
    dbg:addOption(getText("ContextMenu_Rem_SpawnRaider"), nil, function()
        Rem.spawn(x, y, z, { faction = "saqueadores", mode = "wander" })
    end)
    dbg:addOption(getText("ContextMenu_Rem_GroupHereCivil"), x, createGroupHere, y, "civis")
    dbg:addOption(getText("ContextMenu_Rem_GroupHereRaider"), x, createGroupHere, y, "saqueadores")
    dbg:addOption(getText("ContextMenu_Rem_NearestGroup"), nil, showNearestGroup)
    dbg:addOption(getText("ContextMenu_Rem_ListGroups"), nil, listGroups)
    dbg:addOption(getText("ContextMenu_Rem_GoToGroup"), nil, goToNearestGroup)
    dbg:addOption(getText("ContextMenu_Rem_Simulate6"), 6, simulateHours)
    dbg:addOption(getText("ContextMenu_Rem_RemoveAll"), nil, Rem.dismissAll)
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldMenu)
