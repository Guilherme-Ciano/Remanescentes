-- Remanescentes - menu de clique direito: comandar sobreviventes e ferramentas de teste.
-- As opcoes vem dos registros (Rem.registerNpcOption / Rem.registerDebugOption, em
-- Rem_Registry.lua); as padrao estao em Rem_Commands.lua. Aqui so se monta o menu.
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
    -- Kahlua (a Lua do jogo) nao tem a funcao next()
    local hasNear = false
    for _ in pairs(near) do hasNear = true break end
    local debugMenu = Rem.cfg("DebugMenu", true)
    if not hasNear and not debugMenu then return end

    local root = context:addOption(getText("ContextMenu_Rem_Title"), worldobjects, nil)
    local sub = ISContextMenu:getNew(context)
    context:addSubMenu(root, sub)

    if isClient() then
        sub:addOption(getText("ContextMenu_Rem_MPNotSupported"), nil, nil)
        return
    end

    -- sobreviventes perto do clique (opcoes registradas, filtradas pela condicao)
    for _, npc in pairs(near) do
        local label = (npc.rec.name or "?") .. "  [" .. getText("IGUI_Rem_Faction_" .. tostring(npc.rec.faction)) .. "]"
        local opt = sub:addOption(label, nil, nil)
        local npcMenu = ISContextMenu:getNew(sub)
        sub:addSubMenu(opt, npcMenu)
        for _, o in ipairs(Rem.npcOptions) do
            local show = true
            if o.condition then
                local okc, res = pcall(o.condition, npc)
                show = okc and res == true
                if not okc then Rem.log("ERRO na condicao de " .. o.labelKey .. ": " .. tostring(res)) end
            end
            if show then
                npcMenu:addOption(getText(o.labelKey), npc, o.fn)
            end
        end
    end

    if not debugMenu then return end
    local x, y, z = square:getX() + 0.5, square:getY() + 0.5, square:getZ()

    local dopt = sub:addOption(getText("ContextMenu_Rem_Debug"), nil, nil)
    local dbg = ISContextMenu:getNew(sub)
    sub:addSubMenu(dopt, dbg)
    local player = getPlayer()
    for _, o in ipairs(Rem.debugOptions) do
        local fn = o.fn
        dbg:addOption(getText(o.labelKey), nil, function() fn(x, y, z, player) end)
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldMenu)
