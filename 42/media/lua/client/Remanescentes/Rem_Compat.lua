-- Remanescentes - compatibilidade com codigo vanilla que assume "personagem = jogador".
--
-- Ao dar uma arma ao sobrevivente (setPrimaryHandItem), o jogo dispara OnEquipPrimary.
-- O handler de pesca vanilla chama player:getPlayerNum(), que nao existe em IsoZombie,
-- e gera um erro no console. Ignoramos personagens que nao sao IsoPlayer.
require "Fishing/FishingHandler"

if Fishing and Fishing.Handler and Fishing.Handler.handleFishing then
    local original = Fishing.Handler.handleFishing
    Fishing.Handler.handleFishing = function(player, item, ...)
        if not instanceof(player, "IsoPlayer") then return end
        return original(player, item, ...)
    end
end
