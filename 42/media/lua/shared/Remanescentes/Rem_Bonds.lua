-- Remanescentes - vinculo pessoal, memoria e experiencia.
--
-- * Vinculo (rec.bond, -100 a 100): o que VOCE fez por (ou contra) aquela pessoa, alem da
--   fama com o grupo dela. Pesa na atitude (Rem_Reputation), no recrutamento
--   (Rem_Interact) e no cumprimento ("Voce de novo! Ainda te devo uma.").
-- * Memoria (rec.mem): os ultimos feitos, com a hora. Aparecem na Ficha.
--   Feitos (evento "playerDeed", kind, npc, delta): saved, gift, traded, quest, about,
--   recruited, rescued, sieged, hit, threatened.
-- * Experiencia (rec.kills, rec.level): quem mata zumbis vai ficando melhor: mais dano e
--   mais pontaria contra zumbis e outros NPCs (nunca contra voce). Vale para todo mundo,
--   entao um saqueador veterano tambem e mais perigoso para os civis.
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_Barks"
local Rem = Remanescentes

local BD = Rem.module("Bonds", {
    MIN = -100, MAX = 100,
    MEM_MAX = 6,
    TALK_HOURS = 20,            -- conversar conta uma vez a cada tantas horas
    GROUP_SHARE = 0.5,          -- missao/cerco: os outros do grupo ganham essa fracao
    GREET_BOND = 8,             -- vinculo a partir do qual o cumprimento lembra de voce
    GRUDGE_BOND = -15,
    CLOSE_BOND = 40,
    GREET_MEMORY_HOURS = 96,
    LEVELS = { 3, 8, 15, 25, 40 },   -- zumbis mortos para cada nivel
    LEVEL_DAMAGE = 0.08,        -- por nivel
    LEVEL_ACCURACY = 4,         -- por nivel (pontos de chance de acerto)
})
local CFG = BD.CFG

BD.DELTA = { saved = 10, gift = 8, traded = 3, quest = 8, about = 3, talked = 1, recruited = 20,
    rescued = 25, sieged = 12, hit = -25, threatened = -30, armed = 5, allied = 10, fed = 4 }
-- feitos que entram na memoria (conversar nao entra)
BD.REMEMBER = { saved = true, gift = true, traded = true, quest = true, about = true, recruited = true,
    rescued = true, sieged = true, hit = true, threatened = true, armed = true, allied = true, fed = true }
-- cumprimento por lembranca boa (chave da fala)
BD.GREET_BY = { saved = "IGUI_Rem_Talk_hi_saved", rescued = "IGUI_Rem_Talk_hi_saved", sieged = "IGUI_Rem_Talk_hi_saved",
    gift = "IGUI_Rem_Talk_hi_gift", quest = "IGUI_Rem_Talk_hi_quest", traded = "IGUI_Rem_Talk_hi_traded" }
BD.BAD = { hit = true, threatened = true }

Rem.BARKS.levelup = { urgent = true, n = 3, cd = 0 }

local function clamp(v, lo, hi) return math.max(lo, math.min(hi, v)) end

-- ---------------------------------------------------------------- vinculo e memoria
function BD.of(rec) return rec.bond or 0 end

function BD.remember(rec, kind)
    rec.mem = rec.mem or {}
    local hours = Rem.worldHours()
    local last = rec.mem[#rec.mem]
    if last and last.k == kind then
        last.h, last.said = hours, nil      -- a mesma coisa de novo: atualiza a lembranca
    else
        table.insert(rec.mem, { k = kind, h = hours })
        while #rec.mem > CFG.MEM_MAX do table.remove(rec.mem, 1) end
    end
end

-- Muda o vinculo e guarda a lembranca. Retorna o vinculo novo.
function BD.add(rec, kind, delta)
    delta = delta or BD.DELTA[kind] or 0
    rec.bond = clamp((rec.bond or 0) + delta, CFG.MIN, CFG.MAX)
    if BD.REMEMBER[kind] then BD.remember(rec, kind) end
    if Rem.Reputation and Rem.Reputation.apply then Rem.Reputation.apply(rec) end   -- a atitude pode mudar
    Rem.emit("bondChanged", rec, delta, kind)
    Rem.debug(string.format("vinculo %s: %+d (%s) = %d", tostring(rec.name), math.floor(delta), kind, math.floor(rec.bond)))
    return rec.bond
end

-- Conversar com alguem aproxima um pouco (uma vez por dia).
function BD.talked(npc)
    local rec = npc.rec
    local hours = Rem.worldHours()
    if rec.talkedAt and hours - rec.talkedAt < CFG.TALK_HOURS then return false end
    rec.talkedAt = hours
    BD.add(rec, "talked")
    return true
end

Rem.on("playerDeed", function(kind, npc, delta)
    if not npc or not npc.rec or not BD.DELTA[kind] then return end
    local rec = npc.rec
    BD.add(rec, kind, delta)
    -- o que voce faz pelo grupo todo chega nos outros tambem
    if (kind == "quest" or kind == "sieged") and rec.groupId then
        local g = Rem.getStore().groups[rec.groupId]
        for _, id in ipairs(g and g.members or {}) do
            local p = Rem.getPerson(id)
            if p and p ~= rec then BD.add(p, kind, BD.DELTA[kind] * CFG.GROUP_SHARE) end
        end
    end
end)

-- ---------------------------------------------------------------- cumprimento
-- Fala de cumprimento quando a pessoa lembra de voce (ou nil: cumprimento normal).
-- Cada lembranca e citada uma vez.
function BD.greeting(npc)
    local rec = npc.rec
    local bond = rec.bond or 0
    local hours = Rem.worldHours()
    local mem = rec.mem or {}
    if bond <= CFG.GRUDGE_BOND then
        for i = #mem, 1, -1 do
            if BD.BAD[mem[i].k] then return { key = "IGUI_Rem_Talk_hi_grudge", args = {} } end
        end
        return nil
    end
    if bond < CFG.GREET_BOND then return nil end
    for i = #mem, 1, -1 do
        local m = mem[i]
        local key = BD.GREET_BY[m.k]
        if key and not m.said and hours - m.h <= CFG.GREET_MEMORY_HOURS then
            m.said = true
            return { key = key, args = { tostring(rec.name) } }
        end
    end
    if bond >= CFG.CLOSE_BOND then return { key = "IGUI_Rem_Talk_hi_close", args = { tostring(rec.name) } } end
    return nil
end

-- ---------------------------------------------------------------- experiencia
function BD.levelFor(kills)
    local lvl = 0
    for i, need in ipairs(CFG.LEVELS) do
        if kills >= need then lvl = i end
    end
    return lvl
end

function BD.level(rec) return rec.level or 0 end

-- Zumbis que faltam para o proximo nivel (nil no nivel maximo).
function BD.toNext(rec)
    local need = CFG.LEVELS[(rec.level or 0) + 1]
    return need and math.max(0, need - (rec.kills or 0)) or nil
end

function BD.damageMult(npc)
    return 1 + (npc.rec.level or 0) * CFG.LEVEL_DAMAGE
end

function BD.accuracyBonus(npc)
    return (npc.rec.level or 0) * CFG.LEVEL_ACCURACY
end

Rem.on("npcKilledZombie", function(npc)
    local rec = npc.rec
    rec.kills = (rec.kills or 0) + 1
    local lvl = BD.levelFor(rec.kills)
    if lvl > (rec.level or 0) then
        rec.level = lvl
        Rem.bark(npc, "levelup", true)
        Rem.debug(tostring(rec.name) .. " subiu para o nivel " .. lvl .. " (" .. rec.kills .. " zumbis)")
    end
end)
