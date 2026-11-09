# Remanescentes

Mod para Project Zomboid (Build 42.20+) que adiciona sobreviventes humanos ao mundo.

**Fase atual: 1, protótipo.** Sobreviventes que lutam contra zumbis, seguem o jogador ou guardam posição, e persistem no save.

## Como funciona
Cada sobrevivente é um `IsoZombie` com:
- `setUseless(true)`: desliga a visão, a audição e a perseguição de zumbi (confirmado no bytecode: `spottedNew`, `RespondToSound` e `WalkTowardState` checam essa flag; `PathFindState` não, então o pathfinding continua funcionando);
- roupa humana (`addZombiesInOutfit`) e arma na mão;
- animações humanas: `42/media/AnimSets/zombie/*/Rem*.xml`, ativadas pela variável `RemNPC`. Têm `m_ConditionPriority` 50/60, acima dos nós vanilla (até 10);
- um cérebro em Lua (`Rem_Brain.lua`) e combate simulado (`Rem_Combat.lua`), já que os zumbis do jogo só atacam jogadores.

A persistência fica em ModData global (`Remanescentes.npcs`), com chave `persistentOutfitID`. Quando o chunk recarrega, o zumbi é reconhecido no `OnZombieUpdate` e volta a ser sobrevivente.

## Estrutura
```
42/mod.info
42/media/sandbox-options.txt
42/media/AnimSets/zombie/{idle,pathfind,walktoward}/Rem*.xml
42/media/lua/shared/Remanescentes/Rem_Core.lua      config, log, registro
42/media/lua/shared/Remanescentes/Rem_Spawn.lua     criar, ativar, restaurar, morte
42/media/lua/shared/Remanescentes/Rem_Brain.lua     IA (OnTick, a cada 250ms)
42/media/lua/shared/Remanescentes/Rem_Combat.lua    ataque, dano, aggro dos zumbis
42/media/lua/client/Remanescentes/Rem_ContextMenu.lua  menu de teste
42/media/lua/shared/Translate/{EN,PTBR}/*.json
tests/run_tests.lua                                 testes offline (lua5.1)
```

## Testar
Veja [TESTING.md](TESTING.md).

## Roadmap
1. ✅ Protótipo: spawn, seguir, lutar e persistir (falta validar no jogo)
2. Personalidade, reputação, hostis atacando o jogador, falas
3. Safehouses geradas com loot e moradores
4. Troca, recrutamento, comandos de seguidor
5. Mundo vivo: simulação diária, missões, rádio, ataques
