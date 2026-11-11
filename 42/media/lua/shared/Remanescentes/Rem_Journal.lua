-- Remanescentes - diario: o que aconteceu no mundo por sua causa (ou apesar de voce).
--
-- store.journal = { { h = horas do mundo, key = chave do texto, args = { ... } }, ... }
-- Entram no diario (e aparecem como aviso na tela) so coisas de quem voce conhece: seus
-- aliados e os grupos conhecidos (marcados no mapa, revelados, ou com quem voce ja
-- ganhou/perdeu reputacao ou criou vinculo). A janela fica em client/Rem_JournalUI.lua (clique direito -> Diario).
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_MapMarks"
local Rem = Remanescentes

local JN = Rem.module("Journal", { MAX = 40 })

local function entries()
    local s = Rem.getStore()
    s.journal = s.journal or {}
    return s.journal
end

function JN.entries() return entries() end

-- Voce conhece este grupo?
function JN.knows(g)
    if not g then return false end
    if g.player then return true end
    local s = Rem.getStore()
    if s.knownGroups and s.knownGroups[g.id] then return true end
    if s.met and s.met[g.id] then return true end
    return Rem.MapMarks.find("group:" .. g.id) ~= nil or Rem.MapMarks.find("shelter:" .. g.id) ~= nil
end

-- Voce "conhece" um grupo quando ja mexeu na fama com ele ou criou vinculo com alguem de la.
local function meet(id)
    local s = Rem.getStore()
    if not id or not s.groups[id] then return end
    s.met = s.met or {}
    s.met[id] = true
end
Rem.on("reputationChanged", function(key, old, new) if old ~= new then meet(key) end end)
Rem.on("bondChanged", function(rec) meet(rec.groupId) end)

function JN.groupName(g)
    return tostring(g and (g.name or g.id) or "?")
end

-- Registra (e avisa na tela). Retorna a entrada.
function JN.add(key, ...)
    local list = entries()
    local e = { h = Rem.worldHours(), key = key, args = { ... } }
    table.insert(list, e)
    while #list > JN.CFG.MAX do table.remove(list, 1) end
    local player = getPlayer()
    if player then
        Rem.safe(function() HaloTextHelper.addText(player, JN.text(e)) end)
    end
    Rem.debug("diario: " .. key)
    Rem.emit("journalAdded", e)
    return e
end

function JN.text(e)
    return getText(e.key, unpack(e.args or {}))
end

-- ---------------------------------------------------------------- o que entra
Rem.on("playerDeed", function(kind, npc)
    if not npc or not npc.rec then return end
    local name = tostring(npc.rec.name)
    if kind == "recruited" then JN.add("IGUI_Rem_Journal_recruited", name)
    elseif kind == "rescued" then JN.add("IGUI_Rem_Journal_rescued", name)
    elseif kind == "quest" then
        local g = npc.rec.groupId and Rem.getStore().groups[npc.rec.groupId]
        JN.add("IGUI_Rem_Journal_quest", JN.groupName(g))
    end
end)

Rem.on("npcDied", function(npc)
    local rec = npc.rec
    if rec.faction == "aliados" then
        JN.add("IGUI_Rem_Journal_ally_died", tostring(rec.name))
        return
    end
    local g = rec.groupId and Rem.getStore().groups[rec.groupId]
    if g and JN.knows(g) then JN.add("IGUI_Rem_Journal_member_died", tostring(rec.name), JN.groupName(g)) end
end)

Rem.on("siegeTold", function(g) JN.add("IGUI_Rem_Journal_siege", JN.groupName(g)) end)
Rem.on("siegeEnded", function(g, won, s)
    if won then JN.add("IGUI_Rem_Journal_siege_won", JN.groupName(g))
    elseif JN.knows(g) then JN.add("IGUI_Rem_Journal_siege_lost", JN.groupName(g)) end
end)

Rem.on("groupRemoved", function(g)
    if g and g.home and not Rem.bulkRemove and JN.knows(g) then JN.add("IGUI_Rem_Journal_group_gone", JN.groupName(g)) end
end)

Rem.on("baseTaken", function(g, victim)
    if victim and JN.knows(victim) then JN.add("IGUI_Rem_Journal_base_taken", JN.groupName(victim)) end
end)

Rem.on("homeWorked", function(g)
    local h = g.home
    if JN.knows(g) and h and h.windowsTotal and h.windowsTotal > 0 and h.windowsDone == h.windowsTotal and not h.sealedNoted then
        h.sealedNoted = true
        JN.add("IGUI_Rem_Journal_sealed", JN.groupName(g))
    end
end)
