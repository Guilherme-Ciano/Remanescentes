-- Remanescentes - comandos do menu de clique direito (ordens aos sobreviventes e
-- ferramentas de teste), registrados via Rem.registerNpcOption / Rem.registerDebugOption.
--
-- Carregado pelo Rem_Core (no fim dele) para que estas opcoes sejam sempre as primeiras
-- do menu. Nao faz require do Rem_Core: as funcoes do mod (Rem.spawn, Rem.bark...) so
-- sao usadas no clique, quando tudo ja carregou.
require "Remanescentes/Rem_Registry"
Remanescentes = Remanescentes or {}
local Rem = Remanescentes

Rem.Commands = Rem.Commands or {}
local C = Rem.Commands

-- ---------------------------------------------------------------- comandos a um sobrevivente
function C.setMode(npc, mode)
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

function C.setStealth(npc, on)
    npc.rec.stealth = on
    npc.sneaking = nil
    npc.z:setVariable("RemSneak", on)
    Rem.bark(npc, on and "sneak" or "normal", true)
end

function C.showStatus(npc)
    local maxH = npc.rec.maxHealth or 1
    local pct = math.floor(npc.z:getHealth() / maxH * 100)
    Rem.say(npc, "IGUI_Rem_SayStatus", npc.rec.name or "?", tostring(pct))
end

-- ---------------------------------------------------------------- ferramentas de teste
function C.sayToPlayer(text)
    local p = getPlayer()
    if p then p:Say(text) end
end

function C.groupInfo(g, d)
    local members = 0
    for _ in ipairs(g.members) do members = members + 1 end
    return string.format("%s %s [%s] %d pessoas, %s, suprimentos %.1f, a %d tiles",
        g.id, g.name or "", g.faction, members, g.activity, g.supplies or 0, math.floor(d))
end

function C.showNearestGroup()
    local p = getPlayer()
    local g, d = Rem.nearestGroup(p:getX(), p:getY())
    if not g then C.sayToPlayer("Nenhum grupo no mundo.") return end
    C.sayToPlayer(C.groupInfo(g, d))
    Rem.log("mais proximo: " .. C.groupInfo(g, d))
end

function C.listGroups()
    local p = getPlayer()
    Rem.log("---- grupos ----")
    local n = 0
    for _, g in pairs(Rem.getStore().groups) do
        n = n + 1
        Rem.log(C.groupInfo(g, Rem.dist2(p:getX(), p:getY(), g.x, g.y)))
    end
    C.sayToPlayer(n .. " grupos (lista no console.txt)")
end

function C.goToNearestGroup()
    local p = getPlayer()
    local g = Rem.nearestGroup(p:getX(), p:getY())
    if not g then C.sayToPlayer("Nenhum grupo no mundo.") return end
    -- do lado de fora da casa, num quadrado livre e sem zumbis (ajusta quando carregar)
    Rem.teleportNearGroup(p, g)
end

function C.simulateHours(h)
    Rem.simulateWorld(h)
    C.sayToPlayer("Simuladas " .. h .. " horas.")
end

function C.createGroupHere(x, y, faction)
    local g = Rem.createGroup(faction, math.floor(x), math.floor(y), nil, 3)
    if g then C.sayToPlayer("Grupo " .. g.id .. " (" .. faction .. ") criado aqui.") end
end

-- ---------------------------------------------------------------- registro (ordem = menu)
local function friendly(npc) return Rem.isFriendly(npc) end

Rem.registerNpcOption("ContextMenu_Rem_Follow", function(npc) C.setMode(npc, "follow") end, friendly)
Rem.registerNpcOption("ContextMenu_Rem_Stay", function(npc) C.setMode(npc, "stay") end, friendly)
Rem.registerNpcOption("ContextMenu_Rem_Normal", function(npc) C.setStealth(npc, false) end,
    function(npc) return Rem.isFriendly(npc) and npc.rec.stealth == true end)
Rem.registerNpcOption("ContextMenu_Rem_Stealth", function(npc) C.setStealth(npc, true) end,
    function(npc) return Rem.isFriendly(npc) and not npc.rec.stealth end)
Rem.registerNpcOption("ContextMenu_Rem_Info", function(npc) C.showStatus(npc) end)
Rem.registerNpcOption("ContextMenu_Rem_Dismiss", function(npc) Rem.dismiss(npc) end,
    function() return Rem.cfg("DebugMenu", true) == true end)

Rem.registerDebugOption("ContextMenu_Rem_SpawnAlly", function(x, y, z)
    Rem.spawn(x, y, z, { faction = "aliados", mode = "follow" })
end)
Rem.registerDebugOption("ContextMenu_Rem_SpawnCivil", function(x, y, z)
    Rem.spawn(x, y, z, { faction = "civis", mode = "wander" })
end)
Rem.registerDebugOption("ContextMenu_Rem_SpawnRaider", function(x, y, z)
    Rem.spawn(x, y, z, { faction = "saqueadores", mode = "wander" })
end)
Rem.registerDebugOption("ContextMenu_Rem_GroupHereCivil", function(x, y) C.createGroupHere(x, y, "civis") end)
Rem.registerDebugOption("ContextMenu_Rem_GroupHereRaider", function(x, y) C.createGroupHere(x, y, "saqueadores") end)
Rem.registerDebugOption("ContextMenu_Rem_NearestGroup", function() C.showNearestGroup() end)
Rem.registerDebugOption("ContextMenu_Rem_ListGroups", function() C.listGroups() end)
Rem.registerDebugOption("ContextMenu_Rem_GoToGroup", function() C.goToNearestGroup() end)
Rem.registerDebugOption("ContextMenu_Rem_Simulate6", function() C.simulateHours(6) end)
Rem.registerDebugOption("ContextMenu_Rem_RemoveAll", function() Rem.dismissAll() end)
