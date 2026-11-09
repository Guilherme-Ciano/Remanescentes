-- Remanescentes - menu de clique direito: criar e comandar sobreviventes (testes).
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_Spawn"
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

local function setMode(npc, mode, player)
    npc.rec.mode = mode
    if mode == "stay" then
        npc.rec.homeX = math.floor(npc.z:getX())
        npc.rec.homeY = math.floor(npc.z:getY())
        npc.rec.homeZ = math.floor(npc.z:getZ())
        Rem.say(npc, "IGUI_Rem_SayStay")
    else
        Rem.say(npc, "IGUI_Rem_SayFollow")
    end
end

local function showStatus(npc)
    local maxH = npc.rec.maxHealth or 1
    local pct = math.floor(npc.z:getHealth() / maxH * 100)
    Rem.say(npc, "IGUI_Rem_SayStatus", npc.rec.name or "?", tostring(pct))
end

local function onFillWorldMenu(playerNum, context, worldobjects, test)
    if test then return end
    if not Rem.cfg("DebugMenu", true) then return end
    local square = nil
    for _, obj in ipairs(worldobjects) do
        square = obj:getSquare()
        if square then break end
    end
    if not square then return end

    local root = context:addOption(getText("ContextMenu_Rem_Title"), worldobjects, nil)
    local sub = ISContextMenu:getNew(context)
    context:addSubMenu(root, sub)

    if isClient() then
        sub:addOption(getText("ContextMenu_Rem_MPNotSupported"), nil, nil)
        return
    end

    local player = getSpecificPlayer(playerNum)
    local x, y, z = square:getX() + 0.5, square:getY() + 0.5, square:getZ()

    -- comandos para sobreviventes perto do clique
    for _, npc in pairs(npcsNear(square)) do
        local opt = sub:addOption(npc.rec.name or "?", nil, nil)
        local npcMenu = ISContextMenu:getNew(sub)
        sub:addSubMenu(opt, npcMenu)
        npcMenu:addOption(getText("ContextMenu_Rem_Follow"), npc, setMode, "follow", player)
        npcMenu:addOption(getText("ContextMenu_Rem_Stay"), npc, setMode, "stay", player)
        npcMenu:addOption(getText("ContextMenu_Rem_Info"), npc, showStatus)
        npcMenu:addOption(getText("ContextMenu_Rem_Dismiss"), npc, Rem.dismiss)
    end

    sub:addOption(getText("ContextMenu_Rem_Spawn"), nil, function() Rem.spawn(x, y, z, { mode = "follow" }) end)
    sub:addOption(getText("ContextMenu_Rem_SpawnBat"), nil, function()
        Rem.spawn(x, y, z, { mode = "follow", item = "Base.BaseballBat", wtype = "bat" })
    end)
    sub:addOption(getText("ContextMenu_Rem_SpawnKnife"), nil, function()
        Rem.spawn(x, y, z, { mode = "follow", item = "Base.HuntingKnife", wtype = "1h" })
    end)
    sub:addOption(getText("ContextMenu_Rem_RemoveAll"), nil, Rem.dismissAll)
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldMenu)
