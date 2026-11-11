-- Remanescentes - menu de clique direito: comandar sobreviventes e ferramentas de teste.
-- As opcoes vem dos registros (Rem.registerNpcOption / Rem.registerDebugOption, em
-- Rem_Registry.lua); as padrao estao em Rem_Commands.lua. Aqui so se monta o menu.
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_Factions"
require "Remanescentes/Rem_Spawn"
require "Remanescentes/Rem_Barks"
require "Remanescentes/Rem_World"
local Rem = Remanescentes

-- Sobreviventes (e o zumbi mais perto) em volta do quadrado clicado.
local function npcsNear(square)
    local found = {}
    local zombie = nil
    if not square then return found, nil end
    local cell = getCell()
    for dx = -1, 1 do
        for dy = -1, 1 do
            local sq = cell:getGridSquare(square:getX() + dx, square:getY() + dy, square:getZ())
            if sq then
                local objs = sq:getMovingObjects()
                for i = 0, objs:size() - 1 do
                    local o = objs:get(i)
                    local npc = Rem.active[o]
                    if npc then
                        found[npc.key] = npc
                    elseif not zombie and instanceof(o, "IsoZombie") and not o:isDead() then
                        zombie = o
                    end
                end
            end
        end
    end
    return found, zombie
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

    local near, zombie = npcsNear(square)
    -- Kahlua (a Lua do jogo) nao tem a funcao next()
    local hasNear = false
    for _ in pairs(near) do hasNear = true break end
    local debugMenu = Rem.cfg("DebugMenu", true)
    local playerOpts = Rem.playerOptions or {}
    if not hasNear and not debugMenu and #playerOpts == 0 then return end

    local root = context:addOption(getText("ContextMenu_Rem_Title"), worldobjects, nil)
    local sub = ISContextMenu:getNew(context)
    context:addSubMenu(root, sub)

    if isClient() then
        sub:addOption(getText("ContextMenu_Rem_MPNotSupported"), nil, nil)
        return
    end

    -- opcoes do jogador (diario...)
    for _, o in ipairs(playerOpts) do
        local show = true
        if o.condition then
            local okc, res = pcall(o.condition)
            show = okc and res == true
        end
        if show then
            local fn = o.fn
            sub:addOption(getText(o.labelKey), nil, function() fn(getPlayer()) end)
        end
    end

    -- zumbi perto do clique (ex.: "Aliados: ataquem este!")
    if zombie then
        for _, o in ipairs(Rem.targetOptions or {}) do
            local show = true
            if o.condition then
                local okc, res = pcall(o.condition, zombie)
                show = okc and res == true
            end
            if show then
                local fn = o.fn
                sub:addOption(getText(o.labelKey), nil, function() fn(zombie, getPlayer()) end)
            end
        end
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
    -- agrupadas em sub-submenus (Criar, Mundo e grupos, Passagem, Reputacao, Outros)
    local byGroup, order = {}, {}
    for _, g in ipairs(Rem.DEBUG_GROUPS) do byGroup[g] = {} table.insert(order, g) end
    for _, o in ipairs(Rem.debugOptions) do
        local g = Rem.debugGroupOf(o)
        if not byGroup[g] then byGroup[g] = {} table.insert(order, g) end
        table.insert(byGroup[g], o)
    end
    for _, g in ipairs(order) do
        if #byGroup[g] > 0 then
            local gopt = dbg:addOption(getText("ContextMenu_Rem_Grp_" .. g), nil, nil)
            local gmenu = ISContextMenu:getNew(dbg)
            dbg:addSubMenu(gopt, gmenu)
            for _, o in ipairs(byGroup[g]) do
                local fn = o.fn
                gmenu:addOption(getText(o.labelKey), nil, function() fn(x, y, z, player) end)
            end
        end
    end
end

Events.OnFillWorldObjectContextMenu.Add(onFillWorldMenu)
