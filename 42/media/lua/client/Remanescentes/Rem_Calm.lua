-- Remanescentes - o jogador nao entra em panico por causa dos proprios amigos.
--
-- O corpo dos sobreviventes e um zumbi, e o jogo conta todo zumbi visivel a ate 7 tiles
-- (IsoPlayer.updateLOS -> Stats.numVisibleZombies); cada vez que a conta sobe, o panico sobe
-- (BodyDamage.UpdatePanicState). Com um aliado andando do seu lado, o jogador vivia
-- assustado. O campo que tiraria o corpo da conta (IsoZombie.ghost) nao e acessivel por Lua.
-- Entao, a cada quadro: quando o numero de "zumbis" visiveis subiu porque sobreviventes
-- AMIGOS entraram na conta, o panico que subiu por causa deles e devolvido. Zumbis de
-- verdade e sobreviventes hostis continuam assustando normalmente.
require "Remanescentes/Rem_Core"
require "Remanescentes/Rem_Spatial"
local Rem = Remanescentes

local CM = Rem.module("Calm", {
    RADIUS = 7.5,     -- o jogo conta zumbis a menos de 7 tiles
})

-- Quantos zumbis DE VERDADE (e sobreviventes hostis) estao no raio que o jogo conta.
function CM.realCount(player)
    local n = 0
    local pz = math.floor(player:getZ())
    local list = Rem.zombiesNear(player:getX(), player:getY(), CM.CFG.RADIUS)
    for i = 1, #list do
        local zb = list[i]
        local npc = Rem.active[zb]
        if (not npc or Rem.isHostileToPlayer(npc)) and not zb:isDead() and math.floor(zb:getZ()) == pz then
            n = n + 1
        end
    end
    return n
end

-- Sobreviventes amigos no raio (so para os testes e o log).
function CM.friendlyCount(player)
    local n = 0
    local pz = math.floor(player:getZ())
    for zb, npc in pairs(Rem.active) do
        if not Rem.isHostileToPlayer(npc) and math.floor(zb:getZ()) == pz
            and Rem.dist(zb, player) < CM.CFG.RADIUS then
            n = n + 1
        end
    end
    return n
end

local last = nil

-- O jogo sobe o panico sempre que a conta de "zumbis visiveis" aumenta de um quadro para
-- o outro. Aliados entram e saem dessa conta o tempo todo (andando, atras de parede, de
-- outro comodo). Se a conta subiu mas os zumbis de verdade em volta nao aumentaram, o
-- susto foi por causa dos amigos: desfaz. Se subiram, desfaz so a parte que nao e deles.
-- Retorna o panico corrigido (ou nil se nada mudou).
function CM.update(player)
    local stats = player:getStats()
    local raw = stats:getNumVisibleZombies()
    local panic = stats:get(CharacterStat.PANIC)
    local real = CM.realCount(player)
    local fixed = nil
    if last and panic > last.panic and raw > last.raw then
        local dTotal = raw - last.raw
        local dReal = math.max(0, real - last.real)
        local share = math.max(0, 1 - dReal / dTotal)      -- parte do susto que nao foi zumbi de verdade
        if share > 0 then
            fixed = last.panic + (panic - last.panic) * (1 - share)
            stats:set(CharacterStat.PANIC, fixed)
            panic = fixed
        end
    end
    last = { raw = raw, real = real, panic = panic }
    return fixed
end

function CM.reset() last = nil end

local failures = 0
Events.OnPlayerUpdate.Add(function(player)
    if failures >= 5 or Rem.activeCount == 0 then
        if Rem.activeCount == 0 then last = nil end
        return
    end
    local ok, err = pcall(CM.update, player)
    if not ok then
        failures = failures + 1
        Rem.log("ERRO no ajuste de panico: " .. tostring(err) .. (failures >= 5 and " (desligado)" or ""))
    end
end)
