-- Remanescentes - falas curtas ("barks") com cooldown, para os sobreviventes parecerem vivos.
-- Textos em Translate/<LANG>/IG_UI.json, chaves IGUI_Rem_Bark_<categoria>_<n>.
require "Remanescentes/Rem_Core"
local Rem = Remanescentes

-- quantas variacoes existem por categoria e cooldown proprio (ms)
Rem.BARKS = {
    hello  = { n = 4, cd = 0 },
    spot   = { n = 5, cd = 20000 },
    kill   = { n = 5, cd = 15000 },
    hurt   = { urgent = true, n = 4, cd = 8000 },
    flee   = { urgent = true, n = 4, cd = 12000 },
    idle   = { n = 8, cd = 150000 },
    follow = { n = 4, cd = 0 },
    stay   = { n = 3, cd = 0 },
    sneak  = { n = 3, cd = 0 },
    normal = { n = 3, cd = 0 },
    hunted = { urgent = true, n = 3, cd = 20000 },
    threat = { urgent = true, n = 4, cd = 30000 },
    betrayed = { urgent = true, n = 3, cd = 0 },
}
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
    npc.lastBark = now
    npc.barkAt[category] = now
    local key = "IGUI_Rem_Bark_" .. category .. "_" .. tostring(ZombRand(def.n) + 1)
    Rem.safe(function() npc.z:Say(getText(key)) end)
    return true
end
