# Remanescentes

Mod de Project Zomboid (Build 42.20+, **single player**) que povoa o mundo com sobreviventes humanos: grupos que moram em prédios reais, saem para saquear, passam fome, brigam entre facções e lutam contra os zumbis (e contra você, se forem saqueadores).

**Versão 0.3.0**: Fases 2 (combate real) e 3 (mundo vivo).

## Como funciona

### Corpo: um zumbi "humano"
Cada sobrevivente em cena é um `IsoZombie` com:
- `setUseless(true)`: desliga a IA de zumbi. O `PathFindState` ignora essa flag, então o movimento é forçado por `PathFindBehavior2` + `bPathfind`;
- pele humana (`MaleBody0X`/`FemaleBody0X`), roupa limpa e arma na mão;
- animações humanas via `AnimSets/zombie/*/Rem*.xml`, geradas por `tools/gen_animsets.sh` e ativadas pela variável `RemNPC`. A velocidade vem do root motion da animação (andar, correr, agachado);
- um cérebro em Lua (`Rem_Brain.lua`).

### Combate real
- **Zumbi → NPC:** o zumbi recebe `setTarget(npc)` e usa a IA de ataque inteira. Zumbis têm `bodyDamage == null`, e o acerto do `AttackState` chamaria `getBodyDamage().AddRandomDamageFromZombie()`. Esse trecho só roda se o atacante tiver dentes, então quem mira um NPC fica `setNoTeeth(true)` e o mod aplica o dano ao ler `getAttackOutcome() == "success"`. Se o alvo muda (ex.: para você), os dentes voltam no mesmo tick. `noTeeth` não é salvo.
- **NPC → zumbi / NPC / jogador:** animação de ataque do jogador. Dano no zumbi via vida; no NPC via vida; no jogador via `BodyPart:AddDamage` + `setCut(true, true)` (corte **sem** infecção).
- **Jogador → NPC hostil:** dano normal do jogo (`setAvoidDamage(false)`). Aliados são protegidos.

### Mundo em duas camadas
- **No papel** (`ModData`): `people`, `groups`, `looted`. A cada hora, `Rem.simulateWorld` faz os grupos consumirem suprimentos, saírem para saquear prédios reais (`getMetaGrid():getBuildings()`), viajarem, voltarem, morrerem de fome ou em saques, e os saqueadores atacarem outros grupos.
- **Em cena:** quem está a menos de 45 tiles de você ganha corpo (`Rem.materialize`); a mais de 70, volta ao papel (`Rem.dematerialize`). No load, corpos salvos no chunk são re-associados pelo `persistentOutfitID`.
- **Prédios saqueados:** `OnFillContainer` esvazia os contêineres na primeira vez que o jogo gera o loot.

## Estrutura
```
42/mod.info
42/media/sandbox-options.txt
42/media/AnimSets/zombie/{idle,pathfind,walktoward}/Rem*.xml   (gerados)
42/media/lua/shared/Remanescentes/
  Rem_Core.lua        config, log, dados persistentes, migração da 0.2
  Rem_Factions.lua    facções e hostilidade
  Rem_Spawn.lua       pessoa, corpo, materializar/desmaterializar, re-associar, morte
  Rem_Brain.lua       IA de cada NPC em cena
  Rem_Combat.lua      golpes do NPC, dano em zumbi/NPC/jogador
  Rem_Perception.lua  visão/audição dos zumbis, ataque real e simulado
  Rem_World.lua       grupos, semeadura, simulação horária, cena, saque
  Rem_Barks.lua       falas
42/media/lua/client/Remanescentes/
  Rem_ContextMenu.lua comandos e ferramentas de teste
  Rem_Compat.lua      proteção do handler de pesca vanilla
42/media/lua/shared/Translate/{EN,PTBR}/*.json
tools/gen_animsets.sh
tests/run_tests.lua   testes offline (lua5.1)
```

## Testar
Veja [TESTING.md](TESTING.md).

## Roadmap
1. ✅ Protótipo: spawn, seguir, lutar, persistir
2. ✅ 1.5: correr/furtivo, percepção dos zumbis, barulho, fuga, falas
3. ✅ Fase 2: combate real zumbi × NPC, NPC × NPC, hostis × jogador (falta validar no jogo)
4. ✅ Fase 3: mundo em duas camadas, grupos, simulação, saques (falta validar no jogo)
5. Fase 4: encontros (moradores em casas, safehouses barricadas, grupos saqueando nas ruas)
6. Fase 5: necessidades e rotina própria em cena (comer, dormir, barricar)
7. Fase 6: reputação, diálogo, pedidos (água, comida), troca, recrutamento
