-- Remanescentes - Fase B4: o corpo-zumbi se comporta como corpo humano.
--
-- * Nunca vira rastejante: o motor transforma zumbis com a perna ferida em rastejantes
--   (setBecomeCrawler / crawling). Para um sobrevivente isso vira "manca" (Rem_Awareness:
--   ferido nao corre), nao rastejar com animacao de zumbi.
-- * Sem gemido de zumbi: o gerenciador de vozes do jogo (ZombieVocalsManager) toca o som
--   <prefixo>Voice<letra> do zumbi a cada ~500 ms. A cada tick, se esse som estiver
--   tocando num sobrevivente, ele e parado pelo nome.
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_Spawn"
local Rem = Remanescentes

local BD = Rem.module("Body", {
    CRAWL_CHECK_MS = 250,
})

function BD.keepWalking(npc)
    local z = npc.z
    Rem.safe(function()
        if z:isBecomeCrawler() then z:setBecomeCrawler(false) end
        if z:isCrawling() then
            z:setCrawler(false)
            z:setCanWalk(true)
        end
    end)
end

function BD.silence(npc)
    local z = npc.z
    local name = npc.voiceName
    if not name then
        local ok, n = pcall(function() return z:getVoiceSoundName() end)
        if not ok or not n then return end
        name = n
        npc.voiceName = n
    end
    local ok, em = pcall(function() return z:getEmitter() end)
    if ok and em and em:isPlaying(name) then em:stopSoundByName(name) end
end

Rem.on("npcActivated", function(npc)
    Rem.safe(function()
        npc.z:setCanWalk(true)
        npc.z:setBecomeCrawler(false)
    end)
end)

local nextCrawl = 0
Events.OnTick.Add(function()
    if not Rem.isAuthority() or Rem.activeCount == 0 then return end
    local now = Rem.nowMs()
    local crawlCheck = now >= nextCrawl
    if crawlCheck then nextCrawl = now + BD.CFG.CRAWL_CHECK_MS end
    for _, npc in pairs(Rem.active) do
        Rem.safe(BD.silence, npc)
        if crawlCheck then BD.keepWalking(npc) end
    end
end)
