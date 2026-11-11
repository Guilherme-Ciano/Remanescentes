-- Remanescentes - falas curtas ("barks") com cooldown, para os sobreviventes parecerem vivos.
-- Textos em Translate/<LANG>/IG_UI.json, chaves IGUI_Rem_Bark_<categoria>_<n>.
require "Remanescentes/Rem_Core"
local Rem = Remanescentes

-- quantas variacoes existem por categoria e cooldown proprio (ms)
Rem.BARKS = {
    hello  = { n = 6, cd = 0 },
    spot   = { n = 6, cd = 20000 },
    kill   = { n = 6, cd = 15000 },
    hurt   = { urgent = true, n = 5, cd = 8000 },
    flee   = { urgent = true, n = 5, cd = 12000 },
    idle   = { n = 10, cd = 150000 },
    follow = { n = 5, cd = 0 },
    stay   = { n = 4, cd = 0 },
    sneak  = { n = 3, cd = 0 },
    normal = { n = 3, cd = 0 },
    hunted = { urgent = true, n = 4, cd = 20000 },
    threat = { urgent = true, n = 5, cd = 30000 },
    betrayed = { urgent = true, n = 3, cd = 0 },
    -- tom pela personalidade (Rem.bark escolhe sozinho): durao (agressivo) e assustado (medroso)
    spot_tough = { n = 4, cd = 20000 }, spot_scared = { n = 4, cd = 20000 },
    kill_tough = { n = 4, cd = 15000 }, kill_scared = { n = 3, cd = 15000 },
    hurt_tough = { urgent = true, n = 3, cd = 8000 }, hurt_scared = { urgent = true, n = 3, cd = 8000 },
    flee_scared = { urgent = true, n = 3, cd = 12000 },
    idle_tough = { n = 4, cd = 150000 }, idle_scared = { n = 4, cd = 150000 },
}

local TONE = { agressivo = "tough", medroso = "scared" }
local B = Rem.module("Barks", {
    GLOBAL_CD = 6000,  -- tempo minimo entre quaisquer duas falas do mesmo sobrevivente
})

-- force=true ignora cooldowns (respostas a comandos do jogador)
function Rem.bark(npc, category, force)
    if not npc or not npc.z then return false end
    if not force and not Rem.cfg("Barks", true) then return false end
    local def = Rem.BARKS[category]
    if not def then return false end
    local now = Rem.nowMs()
    npc.barkAt = npc.barkAt or {}
    if not force then
        -- falas urgentes (ferido, fugindo, perseguido) furam o intervalo global
        if not def.urgent and now - (npc.lastBark or -B.CFG.GLOBAL_CD) < B.CFG.GLOBAL_CD then return false end
        if now - (npc.barkAt[category] or -def.cd) < def.cd then return false end
    end
    -- versao da fala pelo jeito/humor da pessoa (Rem.barkVariant, definido em Rem_Persona):
    -- devolve outra categoria, nil (segue o normal) ou false (fica calado desta vez)
    local cat = category
    local alt = nil
    if Rem.barkVariant then alt = Rem.barkVariant(npc, category, force) end
    if alt == false then
        npc.barkAt[category] = now
        return false
    end
    npc.lastBark = now
    npc.barkAt[category] = now
    local tone = Rem.temperOf and TONE[Rem.temperOf(npc)]
    if alt and Rem.BARKS[alt] then
        cat = alt
        def = Rem.BARKS[cat]
    elseif tone and Rem.BARKS[category .. "_" .. tone] then
        -- tom pela personalidade, se houver a versao da fala
        cat = category .. "_" .. tone
        def = Rem.BARKS[cat]
    end
    local i = ZombRand(def.n) + 1
    local prefix = "IGUI_Rem_Bark_" .. cat .. "_"
    if prefix .. i == npc.lastBarkKey and def.n > 1 then   -- nao repete a mesma frase em seguida
        i = i % def.n + 1
    end
    local key = prefix .. i
    npc.lastBarkKey = key
    Rem.safe(function() Rem.speak(npc, getText(key)) end)
    return true
end
