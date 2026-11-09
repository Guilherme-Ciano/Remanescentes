# Como testar o Remanescentes (0.3.0)

## 1. Testes automáticos (fora do jogo, ~1 segundo)
```bash
cd ~/Zomboid/mods/Remanescentes && lua5.1 tests/run_tests.lua
```
Simulam a API do jogo e verificam spawn, movimento, combate (inclusive o ataque real dos zumbis e a troca de alvo), hostis, NPC × NPC, mundo vivo (semeadura, simulação, saque, casas vazias), materialização, save/load e migração da 0.2.
**Não** testam animações nem o motor real: isso só dentro do jogo.

## 2. Preparar o jogo
1. Opções de inicialização da Steam: `-debug` (mantendo o `-javaagent` do ZombieBuddy, se usar).
2. **Use um save NOVO de teste.** Saves da 0.2 funcionam (os sobreviventes são migrados como aliados), mas o primeiro teste deve ser limpo.
3. Mods → ative **Remanescentes**.
4. Sandbox → página **Remanescentes**: deixe o padrão. A opção "Ataque dos zumbis aos sobreviventes" começa em **Real (experimental)**.

Tudo de teste fica em: clique direito no chão → **Remanescentes → Ferramentas de teste**.

## 3. Roteiro: combate real (Fase 2)

| # | Ação | Esperado | Se der errado |
|---|---|---|---|
| A | "Criar aliado" e levar até 2-3 zumbis | Os zumbis **vão até ele, dão o bote e atacam com a animação normal de ataque**. Ele faz a animação de levar golpe e perde vida | Anote o que viu e troque para "Simulado" no sandbox |
| B | Durante o A, aparecer na frente dos zumbis | Os zumbis podem **trocar para você**, e aí **mordem normalmente** | **Crítico:** se um zumbi te atacar e nunca ferir, me avise na hora |
| C | "Criar saqueador hostil" a uns 8 tiles | Ele te ameaça ("Ei! Larga tuas coisas!"), vem e ataca. Você leva **corte ou arranhão sangrando**, sem infecção (Saúde → sem "infectado") | — |
| D | Bater no saqueador | Ele **leva dano de verdade** e morre como qualquer zumbi | — |
| E | Criar um aliado e um saqueador perto um do outro | **Lutam entre si** | — |
| F | Bater no aliado | Não sofre dano (só com "Fogo amigo" ligado; aí, após 3 golpes, ele vira inimigo) | — |

## 4. Roteiro: mundo vivo (Fase 3)

| # | Ação | Esperado |
|---|---|---|
| G | Esperar ~5 s após carregar e usar "Listar todos os grupos" | `console.txt` lista uns 12 grupos com facção, número de pessoas e atividade |
| H | "Teleportar perto do grupo mais próximo" | Você aparece a uns 17 tiles da casa. Em 1-2 s, **os moradores aparecem** e ficam andando dentro ou perto da casa |
| I | Se for saqueador: chegar perto | Eles te veem e atacam |
| J | Afastar-se uns 80+ tiles e voltar | Somem e reaparecem **onde estavam**, com a mesma vida |
| K | "Simular 6 horas" algumas vezes perto de um grupo de civis | Com comida baixa, saem para **saquear um prédio real** (atividade "scavenge"), voltam ("return") e ficam em casa ("home") |
| L | Ir até um prédio que um grupo saqueou (ver no console) | **Armários e geladeiras quase vazios** (só vale para contêineres que você ainda não tinha aberto) |
| M | Salvar e carregar perto de um grupo | Ninguém duplica. Quem estava em cena volta como humano |
| N | Jogar normalmente alguns dias | Grupos somem (fome, saques, ataques de saqueadores) e novos aparecem |

## 5. Se algo der errado
```bash
grep -n "Remanescentes\|STACK TRACE" ~/Zomboid/console.txt | tail -60
```
- Ligue "Log detalhado" no sandbox para ver percepção, saques, materialização etc.
- **Desativar o mod é seguro:** sobreviventes em cena viram zumbis comuns com roupa de civil. Zumbis "sem dentes" voltam ao normal ao carregar, porque essa flag não é salva.
- Me mande: o que fez, o que esperava, o que aconteceu, as linhas do console e, se der, um print.

## 6. Limitações conhecidas
- **Só single player.**
- Os sobreviventes podem **gemer como zumbi** (sons ainda não desligados).
- Reações de **queda/levantar** ainda são de zumbi. A de levar golpe é humana.
- Sem armas de fogo, diálogo, troca, pedidos ou safehouses barricadas: isso fica para as Fases 4-6.
- A simulação fora de cena é abstrata: grupos "viajam" em linha reta pelo mapa.
