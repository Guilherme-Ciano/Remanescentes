# Como testar o Remanescentes (Fase 1)

## 1. Testes automáticos (fora do jogo, ~1 segundo)
Na pasta do mod:
```bash
lua5.1 tests/run_tests.lua
```
Simula a API do jogo e verifica spawn, seguir, combate, morte, save/load e remoção.
**Não** testa animações nem o motor real: isso só dentro do jogo.

## 2. Preparar o jogo
1. Steam → Project Zomboid → Propriedades → Opções de inicialização: adicione `-debug` (sem apagar o que já existe, como o `-javaagent` do ZombieBuddy).
2. **Use um save NOVO só para teste** (Sandbox). Assim nada do seu save principal corre risco.
3. Menu principal → Mods → ative **Remanescentes**.
   - Primeiro teste: se possível, desative os mods Viewpoint, que mexem em modelos e animações. Depois teste com eles ligados.
4. Opções de sandbox → página **Remanescentes**: para o primeiro teste, deixe a "Chance de surgir" em 0 e use o menu.

## 3. Roteiro de teste no jogo
Clique direito no chão → **Remanescentes**:

| # | Ação | Esperado | Anote |
|---|---|---|---|
| 1 | "Criar sobrevivente (taco)" | Aparece uma pessoa com roupa civil, segurando o taco, e diz "Ei! Não atira…" | Tem cara de humano? Segura a arma? |
| 2 | Andar uns 10 tiles | Ele te segue andando como humano (não arrastando como zumbi) | Animação de andar está certa? Velocidade? |
| 3 | Chegar perto de zumbis | Ele grita "Zumbi!", vai até eles, golpeia com animação de taco e mata em alguns golpes | Animação de ataque, som, dano |
| 4 | Ficar parado perto de vários zumbis | Zumbis vão atrás DELE, causam dano; ele pode morrer e solta o taco | Ele morre? Corpo fica? Mensagem "X morreu" |
| 5 | Bater nele com uma arma | Por padrão, não sofre dano | — |
| 6 | Clique direito nele → "Fique aqui", e se afastar | Ele fica e defende a posição | — |
| 7 | Salvar, sair, carregar | Ele continua lá e continua humano | **Importante**: virou zumbi comum? |
| 8 | Afastar 200+ tiles e voltar | Ele continua humano | — |
| 9 | "Criar sobrevivente (faca)" | Animação de uma mão | — |
| 10 | "Remover todos" | Somem todos | — |
| 11 | Chance de surgir = 100, esperar 10-20 min de jogo | Aparecem errantes a 25-40 tiles | — |

## 4. Se algo der errado
- Erros e logs ficam em `~/Zomboid/console.txt`:
  ```bash
  grep -n "Remanescentes\|STACK TRACE\|ERROR" ~/Zomboid/console.txt | tail -50
  ```
- Para logs detalhados, ligue "Log detalhado" no sandbox.
- **Desativar o mod é seguro**: os sobreviventes viram zumbis comuns com roupa de civil. O save não quebra.
- Mande para mim: o que fez, o que esperava, o que aconteceu, e as linhas do console.

## 5. Limitações conhecidas da Fase 1 (a confirmar no jogo)
- **Só single player.** Em multiplayer o menu avisa e o cérebro não roda.
- Podem ainda **gemer como zumbi**: os sons de zumbi ainda não foram desligados.
- Animações de levar golpe, cair e levantar ainda são as de zumbi.
- Velocidade de andar depende do motor (animação humana sobre um zumbi). Ajustamos depois do teste.
- Sem armas de fogo, sem hostis e sem safehouses: isso fica para as Fases 2 e 3.
