-- Remanescentes - relacoes entre as pessoas da sua base (e de quem segue voce).
--
-- rec.rel[outroId], de -100 a 100:
--   * sobe: saindo em dupla (cobrem um ao outro), conversando, morando juntos (um pouco
--     por dia, se o jeito combina);
--   * desce: brigas (Rem_BaseEvents), e um pouco por dia quando o jeito nao combina
--     (um esquentado e um medroso, por exemplo).
-- Amigos (>= FRIEND): preferem sair juntos e correm menos risco juntos; a morte de um
--   pesa muito mais no outro (luto mais longo, moral no chao).
-- Rivais (<= RIVAL): nunca saem juntos (se houver outro parceiro) e brigam mais.
-- Ficar amigo / virar rival vai para o Diario.
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_Journal"
local Rem = Remanescentes

local FR = Rem.module("Friends", {
    FRIEND = 30,
    RIVAL = -30,
    TRIP = 6,
    BANTER = 2,
    ARGUE = -10,
    DAILY_MATCH = 2,          -- por dia morando juntos, jeitos parecidos
    DAILY_CLASH = -2,         -- por dia, jeitos muito diferentes
    CLASH_DIFF = 5,           -- diferenca de agressividade que nao combina
    FRIEND_RISK = 0.8,        -- dupla de amigos: risco da saida x isso
    FRIEND_GRIEF_H = 48,
    FRIEND_GRIEF_MORALE = 15, -- a mais no luto de um amigo
})
local CFG = FR.CFG

local function clamp(v) return math.max(-100, math.min(100, v)) end

function FR.of(a, b)
    if not a or not b or a == b then return 0 end
    return (a.rel and a.rel[b.id]) or 0
end

function FR.isFriend(a, b) return FR.of(a, b) >= CFG.FRIEND end
function FR.isRival(a, b) return FR.of(a, b) <= CFG.RIVAL end

-- Muda a relacao dos dois (simetrica). Avisa quando cruza um limite.
function FR.add(a, b, delta)
    if not a or not b or a == b then return 0 end
    local before = FR.of(a, b)
    local v = clamp(before + delta)
    a.rel = a.rel or {}
    b.rel = b.rel or {}
    a.rel[b.id], b.rel[a.id] = v, v
    local tracked = a.faction == "aliados" and b.faction == "aliados"
    if tracked and before < CFG.FRIEND and v >= CFG.FRIEND then
        Rem.Journal.add("IGUI_Rem_Journal_friends", tostring(a.name), tostring(b.name))
    elseif tracked and before > CFG.RIVAL and v <= CFG.RIVAL then
        Rem.Journal.add("IGUI_Rem_Journal_rivals", tostring(a.name), tostring(b.name))
    end
    return v
end

-- Amigos e rivais de alguem (que ainda existem), por nome.
function FR.list(rec)
    local friends, rivals = {}, {}
    for id, v in pairs(rec.rel or {}) do
        local p = Rem.getPerson(id)
        if p then
            if v >= CFG.FRIEND then table.insert(friends, tostring(p.name))
            elseif v <= CFG.RIVAL then table.insert(rivals, tostring(p.name)) end
        end
    end
    table.sort(friends)
    table.sort(rivals)
    return friends, rivals
end

-- Parceiro de saida: quem ele mais gosta (amigos primeiro; rival so se nao houver outro).
function FR.pickPartner(rec, candidates)
    local best, bestV = nil, nil
    for _, p in ipairs(candidates) do
        local v = FR.of(rec, p)
        if bestV == nil or v > bestV then best, bestV = p, v end
    end
    return best
end

-- Risco de uma saida em dupla (multiplicador).
function FR.tripRisk(rec, partner)
    if partner and FR.isFriend(rec, partner) then return CFG.FRIEND_RISK end
    return 1
end

-- Par de rivais na lista (para as brigas), ou nil.
function FR.rivalPair(list)
    for i = 1, #list do
        for j = i + 1, #list do
            if FR.isRival(list[i], list[j]) then return list[i], list[j] end
        end
    end
    return nil
end

-- ---------------------------------------------------------------- o que muda a relacao
Rem.on("tripDone", function(g, rec, partner) if rec and partner then FR.add(rec, partner, CFG.TRIP) end end)
Rem.on("banterStarted", function(a, b, topic)
    if topic == "argue" then return end
    FR.add(a.rec, b.rec, CFG.BANTER)
end)
Rem.on("baseArgue", function(a, b) FR.add(a, b, CFG.ARGUE) end)

-- Uma vez por dia: quem mora junto se aproxima (ou se estranha).
function FR.daily(g)
    local PB = Rem.PlayerBase
    local list = PB.members(g)
    for i = 1, #list do
        for j = i + 1, #list do
            local a, b = list[i], list[j]
            local diff = math.abs(Rem.trait(a, "agressividade") - Rem.trait(b, "agressividade"))
            FR.add(a, b, (diff >= CFG.CLASH_DIFF) and CFG.DAILY_CLASH or CFG.DAILY_MATCH)
        end
    end
end

Rem.on("worldHour", function()
    local tod = math.floor(getGameTime():getTimeOfDay())
    if tod ~= 20 then return end
    local g = Rem.PlayerBase and Rem.PlayerBase.get()
    if g then Rem.safe(FR.daily, g) end
end)

-- ---------------------------------------------------------------- luto de amigo
-- (Rem_Persona.mourn avisa "mourned" quando alguem morre de verdade)
Rem.on("mourned", function(dead)
    if not dead or not dead.rel then return end
    local hours = Rem.worldHours()
    for id, v in pairs(dead.rel) do
        local p = Rem.getPerson(id)
        if p and p ~= dead and v >= CFG.FRIEND then
            p.griefUntil = hours + CFG.FRIEND_GRIEF_H
            p.griefFor = tostring(dead.name)
            if Rem.Persona then Rem.Persona.addMorale(p, -CFG.FRIEND_GRIEF_MORALE) end
        end
    end
end)

-- quem saiu da historia sai das relacoes dos outros
Rem.on("personRemoved", function(gone)
    if Rem.bulkRemove or not gone or not gone.rel then return end
    for id in pairs(gone.rel) do
        local p = Rem.getPerson(id)
        if p and p.rel then p.rel[gone.id] = nil end
    end
end)
