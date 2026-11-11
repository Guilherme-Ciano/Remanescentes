-- Remanescentes - reputacao e atitude com o jogador (Fase 2).
--
-- Cada grupo tem uma reputacao com o jogador de -100 a +100 (store.reputation[groupId]).
-- Pessoas sem grupo (criadas pelo menu de teste) usam a reputacao da faccao ("f:<faccao>").
--
-- Atitude = reputacao - "dureza" da personalidade:
--   dureza = (agressividade-5)*4 + (ganancia-5)*2 - (confianca-5)*3
--   <= -40 hostil | >= 20 amigavel | senao neutro
-- Hostil ataca ao ver. Neutro de grupo territorial (milicia, seita) manda voce ir embora
-- se entrar na base; se insistir, o grupo te ataca. Aliados (seus seguidores) ficam de fora.
--
-- O que muda a reputacao:
--   golpear um membro -10 (e o grupo fica com raiva) | matar um membro -40
--   matar um zumbi que cacava um membro +2           | matar um saqueador perto +3
--   invadir base territorial depois do aviso -10     | ser visto mexendo no estoque -15
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_Factions"
require "Remanescentes/Rem_Spawn"
require "Remanescentes/Rem_Barks"
require "Remanescentes/Rem_Combat"
require "Remanescentes/Rem_Perception"
require "Remanescentes/Rem_Profile"
local Rem = Remanescentes

Rem.Reputation = Rem.Reputation or {}
local R = Rem.Reputation

R.CFG = {
    MIN = -100, MAX = 100,
    HOSTILE_AT = -40,
    BOND_WEIGHT = 0.6,
    GREET_BOND = 15,            -- vinculo (ou rancor) a partir do qual o cumprimento e pessoal          -- quanto o vinculo pessoal (rec.bond) pesa na atitude
    FRIENDLY_AT = 20,
    HIT = -10, KILL = -40, HELP = 2, KILL_RAIDER = 3, TRESPASS = -10, THEFT = -15,
    RAIDER_NEWS_RADIUS = 100,     -- grupos a essa distancia ficam sabendo que voce matou um saqueador
    WARN_GRACE_MS = 10000,        -- tempo para sair depois do aviso
    ANGER_MS = 60000,             -- raiva dura isso depois que voce sai / para de brigar
    PERIMETER = 4,                -- tiles em volta da casa que contam como "base"
    GREET_RADIUS = 6,
    GREET_CD_MS = 120000,
    THEFT_SIGHT = 12,
}

R.DEFAULT = { civis = 10, sobreviventes = 0, saqueadores = -60, seita = -10, errantes = 0, aliados = 50 }
R.TERRITORIAL = { sobreviventes = true, seita = true }

-- estado de runtime por grupo: warnedAt, angryUntil
R.state = R.state or {}

-- ---------------------------------------------------------------- falas novas
Rem.BARKS.greet_friendly = { n = 4, cd = 120000 }
Rem.BARKS.greet_neutral = { n = 4, cd = 120000 }
Rem.BARKS.greet_cold = { n = 3, cd = 120000 }
Rem.BARKS.greet_bond = { n = 3, cd = 120000 }
Rem.BARKS.greet_grudge = { n = 3, cd = 120000 }
Rem.BARKS.warn = { urgent = true, n = 4, cd = 8000 }
Rem.BARKS.angry = { urgent = true, n = 3, cd = 15000 }
Rem.BARKS.thief = { urgent = true, n = 3, cd = 15000 }
Rem.BARKS.thanks = { n = 3, cd = 60000 }

-- ---------------------------------------------------------------- reputacao
local function repKey(rec)
    if rec.groupId then return rec.groupId end
    return "f:" .. tostring(rec.faction)
end

local function factionOfKey(key)
    if key:sub(1, 2) == "f:" then return key:sub(3) end
    local g = Rem.getStore().groups[key]
    return g and g.faction or "civis"
end

local function repTable()
    local store = Rem.getStore()
    store.reputation = store.reputation or {}
    return store.reputation
end

-- Reputacao inicial: tabela R.DEFAULT; faccao desconhecida (registrada por outro modulo)
-- comeca hostil se a definicao dela for hostil ao jogador.
function R.defaultFor(faction)
    if R.DEFAULT[faction] ~= nil then return R.DEFAULT[faction] end
    return Rem.factionDef(faction).hostileToPlayer and -60 or 0
end

function Rem.getRep(key)
    local t = repTable()
    if t[key] == nil then t[key] = R.defaultFor(factionOfKey(key)) end
    return t[key]
end

function Rem.repOf(rec)
    return Rem.getRep(repKey(rec))
end

-- Muda a reputacao de um grupo (ou faccao "f:x") e reaplica a atitude dos membros.
function Rem.changeRep(key, delta, reason)
    if not key then return end
    local old = Rem.getRep(key)
    local new = math.max(R.CFG.MIN, math.min(R.CFG.MAX, old + delta))
    repTable()[key] = new
    Rem.debug(string.format("reputacao %s: %d -> %d (%s)", key, math.floor(old), math.floor(new), tostring(reason)))
    Rem.emit("reputationChanged", key, old, new, reason)
    R.refreshKey(key)
    return new
end

-- ---------------------------------------------------------------- atitude
function R.harshness(rec)
    local function t(n) return Rem.trait(rec, n) - 5 end
    return t("agressividade") * 4 + t("ganancia") * 2 - t("confianca") * 3
end

function Rem.attitudeOf(rec)
    if rec.faction == "aliados" then return "amigavel" end
    -- o que voce fez por (ou contra) esta pessoa pesa alem da fama com o grupo (Rem_Bonds)
    local score = Rem.repOf(rec) - R.harshness(rec) + (rec.bond or 0) * R.CFG.BOND_WEIGHT
        + (Rem.Fame and Rem.Fame.attitudeMod(rec) or 0)              -- o que dizem de voce (Rem_Fame)
    if score <= R.CFG.HOSTILE_AT then return "hostil" end
    if score >= R.CFG.FRIENDLY_AT then return "amigavel" end
    return "neutro"
end

local function isAngry(key, now)
    local st = R.state[key]
    return st ~= nil and st.angryUntil ~= nil and now < st.angryUntil
end

-- Aplica a atitude na pessoa (rec.hostileToPlayer e o que o cerebro usa).
function R.apply(rec, now)
    if rec.faction == "aliados" or rec.betrayed or rec.disguised then return end
    if rec.surrendered or rec.prisoner then rec.hostileToPlayer = false return end   -- rendido (Rem_Mugging), preso (Rem_Prisoners)
    now = now or Rem.nowMs()
    rec.attitude = Rem.attitudeOf(rec)
    rec.hostileToPlayer = (rec.attitude == "hostil") or isAngry(repKey(rec), now)
end

local function activeOf(rec)
    for _, npc in pairs(Rem.active) do
        if npc.rec == rec then return npc end
    end
    return nil
end

function R.refreshKey(key)
    local now = Rem.nowMs()
    for _, rec in pairs(Rem.getStore().people) do
        if repKey(rec) == key then
            local was = rec.hostileToPlayer
            R.apply(rec, now)
            if was ~= rec.hostileToPlayer then
                local npc = activeOf(rec)
                if npc then
                    Rem.applyFriendlyFire(npc)
                    if rec.hostileToPlayer then Rem.bark(npc, "angry", true) end
                end
            end
        end
    end
end

-- Grupo fica com raiva do jogador por um tempo (te ataca mesmo sendo neutro).
function Rem.angerGroup(key, ms)
    local st = R.state[key] or {}
    R.state[key] = st
    st.angryUntil = Rem.nowMs() + (ms or R.CFG.ANGER_MS)
    R.refreshKey(key)
end

-- Protecao contra golpes do jogador: so seus aliados (seguidores). Neutros e amigaveis
-- de outros grupos podem ser feridos, e isso tem consequencia (reputacao).
function Rem.applyFriendlyFire(npc)
    local protect = npc.rec.faction == "aliados" and Rem.isFriendly(npc) and not Rem.cfg("FriendlyFire", false)
    npc.z:setAvoidDamage(protect)
end

-- ---------------------------------------------------------------- eventos de reputacao
Rem.on("personCreated", function(rec) R.apply(rec) end)

Rem.on("npcActivated", function(npc)
    R.apply(npc.rec)
    Rem.applyFriendlyFire(npc)
end)

-- Jogador golpeou um sobrevivente que nao era hostil.
Events.OnHitZombie.Add(function(zombie, attacker)
    local npc = Rem.active[zombie]
    if not npc or not Rem.isPlayerObj(attacker) then return end
    local rec = npc.rec
    if not rec.hostileToPlayer then Rem.emit("playerDeed", "hit", npc) end
    if rec.faction == "aliados" or rec.hostileToPlayer then return end
    local key = repKey(rec)
    Rem.changeRep(key, R.CFG.HIT, "golpe")
    Rem.angerGroup(key)
end)

local function killedByPlayer(zombie)
    local ok, by = pcall(function() return zombie:getAttackedBy() end)
    return ok and by ~= nil and Rem.isPlayerObj(by)
end

Rem.on("npcDied", function(npc)
    if not killedByPlayer(npc.z) then return end
    local rec = npc.rec
    -- (avisa antes de mexer na reputacao: depois disso a vitima ja "estava com raiva")
    Rem.emit("playerKilled", npc, Rem.isHostileToPlayer(npc))
    if Rem.isHostileToPlayer(npc) then
        -- matou alguem hostil (saqueador): quem e inimigo dele perto aprova
        local x, y = npc.z:getX(), npc.z:getY()
        for gid, g in pairs(Rem.getStore().groups) do
            if g.id ~= rec.groupId and Rem.factionsHostile(g.faction, rec.faction)
                and Rem.dist2(x, y, g.x, g.y) < R.CFG.RAIDER_NEWS_RADIUS then
                Rem.changeRep(gid, R.CFG.KILL_RAIDER, "matou inimigo")
            end
        end
    elseif rec.faction ~= "aliados" then
        local key = repKey(rec)
        Rem.changeRep(key, R.CFG.KILL, "matou membro")
        Rem.angerGroup(key, R.CFG.ANGER_MS * 5)
    end
end)

-- Jogador matou um zumbi que estava atras de um sobrevivente: ajuda.
Events.OnZombieDead.Add(function(zombie)
    if Rem.active[zombie] then return end
    local h = Rem.hunting and Rem.hunting[zombie]
    if not h or not h.npc or not killedByPlayer(zombie) then return end
    local rec = h.npc.rec
    if not rec.hostileToPlayer then Rem.emit("playerDeed", "saved", h.npc) end
    if rec.faction == "aliados" or rec.hostileToPlayer then return end
    Rem.changeRep(repKey(rec), R.CFG.HELP, "ajudou")
    Rem.bark(h.npc, "thanks")
end)

-- ---------------------------------------------------------------- territorio e cumprimentos
local function insideBase(g, x, y)
    local h = g.home
    if not h or not h.x1 then return false end
    local p = R.CFG.PERIMETER
    return x >= h.x1 - p and x <= h.x2 + p and y >= h.y1 - p and y <= h.y2 + p
end

local function nearestMemberOnScene(g, player)
    local best, bestD = nil, math.huge
    for _, npc in pairs(Rem.active) do
        if npc.rec.groupId == g.id then
            local d = Rem.dist(npc.z, player)
            if d < bestD then best, bestD = npc, d end
        end
    end
    return best
end

function R.checkTerritory(player, now)
    local px, py = player:getX(), player:getY()
    for gid, g in pairs(Rem.getStore().groups) do
        local st = R.state[gid] or {}
        R.state[gid] = st
        if R.TERRITORIAL[g.faction] and not (Rem.Interact and Rem.Interact.isGuest(g)) then
            local inside = insideBase(g, px, py)
            local guard = inside and nearestMemberOnScene(g, player)
            local anyRec = nil
            for _, id in ipairs(g.members) do
                anyRec = Rem.getPerson(id)
                if anyRec then break end
            end
            local neutral = anyRec ~= nil and Rem.attitudeOf(anyRec) == "neutro"
            if inside and guard and neutral and not isAngry(gid, now) then
                if not st.warnedAt then
                    st.warnedAt = now
                    Rem.bark(guard, "warn", true)
                elseif now - st.warnedAt > R.CFG.WARN_GRACE_MS then
                    Rem.changeRep(gid, R.CFG.TRESPASS, "invasao")
                    Rem.angerGroup(gid)
                    st.warnedAt = nil
                end
            elseif not inside then
                st.warnedAt = nil
            end
        end
    end
    -- raiva acaba sozinha; reaplica a atitude quando expira (grupos e faccoes "f:x")
    for key, st in pairs(R.state) do
        if st.angryUntil and now >= st.angryUntil then
            st.angryUntil = nil
            R.refreshKey(key)
        end
    end
end

function R.greet(player, now)
    for _, npc in pairs(Rem.active) do
        local rec = npc.rec
        if rec.faction ~= "aliados" and not rec.hostileToPlayer and Rem.dist(npc.z, player) <= R.CFG.GREET_RADIUS
            and now - (npc.greetAt or -R.CFG.GREET_CD_MS) >= R.CFG.GREET_CD_MS then
            npc.greetAt = now
            local cat = "greet_neutral"
            local bond = rec.bond or 0
            if bond >= R.CFG.GREET_BOND then cat = "greet_bond"            -- lembra de voce (Rem_Bonds)
            elseif bond <= -R.CFG.GREET_BOND then cat = "greet_grudge"
            elseif rec.attitude == "amigavel" then cat = "greet_friendly"
            elseif Rem.trait(rec, "agressividade") >= 7 then cat = "greet_cold" end
            Rem.bark(npc, cat)
        end
    end
end

-- Estoque: alguem do grupo te viu mexendo no estoque da casa? (contagem: Rem_Safehouse)
local function stashCount(h)
    return Rem.Safehouse and Rem.Safehouse.stashCount and Rem.Safehouse.stashCount(h) or nil
end

function R.checkTheft(player)
    for gid, g in pairs(Rem.getStore().groups) do
        local h = g.home
        if h and h.stash and not g.player and insideBase(g, player:getX(), player:getY()) then
            local n = stashCount(h)
            if n then
                if h.stashCount and n < h.stashCount then
                    local witness = nil
                    for _, npc in pairs(Rem.active) do
                        if npc.rec.groupId == gid and Rem.dist(npc.z, player) <= R.CFG.THEFT_SIGHT then
                            local ok, sees = pcall(function() return npc.z:CanSee(player) end)
                            if not ok or sees then witness = npc break end
                        end
                    end
                    if witness then
                        Rem.bark(witness, "thief", true)
                        Rem.changeRep(gid, R.CFG.THEFT, "roubo")
                        Rem.angerGroup(gid)
                    end
                end
                h.stashCount = n
            end
        end
    end
end

Rem.on("sceneUpdate", function(player, now)
    Rem.safe(R.checkTerritory, player, now)
    Rem.safe(R.greet, player, now)
    Rem.safe(R.checkTheft, player)
end)

-- ---------------------------------------------------------------- menu
Rem.registerNpcOption("ContextMenu_Rem_Profile", function(npc)
    local rec = npc.rec
    Rem.safe(function()
        if Rem.showProfile then return Rem.showProfile(npc) end   -- janela (client/Rem_DialogUI.lua)
        Rem.speak(npc, Rem.profileText(rec) .. "  |  " .. getText("IGUI_Rem_Att_" .. tostring(rec.attitude or Rem.attitudeOf(rec)))
            .. " (" .. tostring(math.floor(Rem.repOf(rec))) .. ")")
    end)
end)

local function nudgeNearest(delta)
    return function(x, y, z, player)
        local g = Rem.nearestGroup(player:getX(), player:getY())
        if not g then return end
        local new = Rem.changeRep(g.id, delta, "teste")
        player:Say(g.id .. ": " .. tostring(new))
    end
end
Rem.registerDebugOption("ContextMenu_Rem_RepUp", nudgeNearest(25))
Rem.registerDebugOption("ContextMenu_Rem_RepDown", nudgeNearest(-25))
