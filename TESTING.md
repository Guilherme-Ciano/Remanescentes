# Como testar o Remanescentes (0.7.0)

> **Casas barricadas do próprio jogo ≠ safehouses do mod.** O B42 já gera casas com tábuas **por fora** e cheias de zumbis (histórias aleatórias). As safehouses do mod têm tábuas **por dentro**, uma porta principal sem tábuas, moradores humanos e, quase sempre, placa, corpos empilhados e fogueira. Para achar uma: **Ferramentas de teste → "Info do grupo mais próximo"** e **"Teleportar perto do grupo mais próximo"**.
>
> **Save antigo (de antes da 0.4):** os grupos antigos agora são preparados quando você chega perto. Se quiser grupos novos com tudo desde o início, use **"Recriar grupos do mundo"**.

## 1. Testes automáticos (fora do jogo, ~1 segundo)
```bash
cd ~/Zomboid/mods/Remanescentes && lua5.1 tests/run_tests.lua
```
Simulam a API do jogo e verificam spawn, movimento, combate (inclusive o ataque real dos zumbis e a troca de alvo), hostis, NPC × NPC, mundo vivo (semeadura, simulação, saque, casas vazias), materialização, save/load e migração da 0.2.
Também verificam o contrato de extensão (eventos, comportamentos, facções, opções de menu). Novos testes: basta criar `tests/test_<tema>.lua`.
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
| F2 | Brigar com um saqueador perto de zumbis que estão vindo atrás de você | Os zumbis que passam colados no saqueador **trocam para ele** | — |

## 3b. Roteiro: temperamento (0.3.1)

| # | Ação | Esperado |
|---|---|---|
| T1 | Andar com um aliado perto de zumbis distraídos (andando à toa, sem vir até vocês) | Ele **não** vai até eles; continua te seguindo |
| T2 | Um zumbi vem até você ou até ele | Ele **se defende / te defende** |
| T3 | Você acerta um zumbi | O aliado **entra na briga** com os zumbis perto de você |
| T4 | Criar um **civil** e deixar um zumbi vê-lo | O civil **foge correndo**; só bate se ficar encurralado |
| T5 | Criar um **saqueador** perto de zumbis distraídos | Ele vai para cima deles |

## 4. Roteiro: mundo vivo (Fase 3)

| # | Ação | Esperado |
|---|---|---|
| G | Esperar ~5 s após carregar e usar "Listar todos os grupos" | `console.txt` lista uns 12 grupos com facção, número de pessoas e atividade |
| H | "Teleportar perto do grupo mais próximo" | Você aparece **do lado de fora** da casa (lado sul, ~5 tiles da parede), num lugar livre e sem zumbis colados. Pode haver um pequeno "pulo" de ajuste logo depois do teleporte, quando o lugar carrega. Em 1-2 s, **os moradores aparecem** dentro ou perto da casa. Se o grupo estiver fora (saque), você aparece perto de onde ele está |
| I | Se for saqueador: chegar perto | Eles te veem e atacam |
| J | Afastar-se uns 80+ tiles e voltar | Somem e reaparecem **onde estavam**, com a mesma vida |
| K | "Simular 6 horas" algumas vezes perto de um grupo de civis | Com comida baixa, saem para **saquear um prédio real** (atividade "scavenge"), voltam ("return") e ficam em casa ("home") |
| L | Ir até um prédio que um grupo saqueou (ver no console) | **Armários e geladeiras quase vazios** (só vale para contêineres que você ainda não tinha aberto) |
| M | Salvar e carregar perto de um grupo | Ninguém duplica. Quem estava em cena volta como humano |
| N | Jogar normalmente alguns dias | Grupos somem (fome, saques, ataques de saqueadores) e novos aparecem |

## 4b. Roteiro: ficha e reputação (Fase 2, 0.4.0)
Ligue **"Log detalhado"** no sandbox para ver as mudanças de reputação no console.

| # | Ação | Esperado |
|---|---|---|
| P1 | Criar alguns civis e aliados; clique direito → nome → **Ficha** | Mostra nome, idade, profissão, arquétipo, atitude e reputação. A **roupa combina com a profissão** (policial de farda, médico de jaleco) |
| P2 | Chegar perto de civis/milicianos | **Cumprimentam** de acordo com a atitude ("Oi! Bom ver alguém vivo." / "Tô de olho em você.") |
| P3 | Bater num civil | Ele **leva dano** (não é mais imune), grita, e o grupo dele **te ataca por ~1 min**; depois acalma |
| P4 | Matar um zumbi que estava atacando um civil | Ele agradece ("Valeu pela ajuda!") |
| P5 | Teleportar para uma **milícia** (Info do grupo mais próximo mostra a facção) e entrar no terreno | "Ei! Aqui é nosso. Vai embora!"; se ficar ~10 s, **atacam**. Saindo e esperando ~1 min, voltam a ser neutros |
| P6 | Bater no seu **aliado** | Continua protegido (só com "Fogo amigo" ligado) |

## 4c. Roteiro: safehouses (Fase 3, 0.4.0)
Use um **save novo** (casas já carregadas em saves antigos são preparadas quando você chega perto, mas o loot vanilla que você já abriu não volta).

| # | Ação | Esperado |
|---|---|---|
| S0 | No save que você já tinha: **"Recriar grupos do mundo"**, depois **"Teleportar perto do grupo mais próximo"** | Console: `mundo semeado: N grupos`. Você aparece do lado de fora de uma casa |
| S1 | "Teleportar perto do grupo mais próximo" | Janelas com **tábuas por dentro**, porta da frente **sem tábuas** (trancada se o grupo não for amigável com você), **corpos de zumbis** amontoados na frente, **sem zumbis dentro** (os moradores limparam). Se a casa escolhida já era barricada pelo jogo, as tábuas da porta principal somem |
| S2 | Olhar os moradores | Um **guarda** fica na porta; de dia um **cozinheiro** fica na cozinha |
| S3 | Ficar até a noite (ou usar o menu de tempo do debug) | **Luz acesa** dentro da casa; moradores **dentro de casa** |
| S4 | Entrar (arrombar ou janela) e abrir armários | Poucos contêineres com **estoque coerente** com o grupo; o resto vazio |
| S5 | Pegar algo do estoque **na frente** de um morador | "Ladrão! Larga isso!", reputação −15 e o grupo te ataca |
| S6 | "Preparar casa do grupo mais próximo" (ferramenta de teste) perto de uma casa carregada | Refaz barricadas/estoque e mostra quantas janelas, portas e itens |
| S7 | Ferir um morador e deixar um **médico** do grupo por perto | O médico vai até ele e cura ("Deixa eu ver esse ferimento.") |
| S8 | Olhar em volta da casa | **Placa** de madeira perto da porta (chegue perto: o texto aparece sobre você), às vezes **poste com caveira**, **barril de chuva**, **gerador**; de dia, **fogueira acesa** no quintal |
| S9 | Ver um morador passando pela porta principal | **Abre**, passa, e depois de uns segundos **fecha e tranca**. A porta principal nunca tem tábuas |
| S10 | À noite | Moradores vão para um canto e **deitam para dormir**; de manhã levantam. De dia, às vezes um **senta** no chão |
| S11 | "Simular 6 horas" até um grupo sair para saquear (Info do grupo: "scavenge") e **segui-los** | O guarda fica; os outros entram no prédio, **param em cada armário**, "Achei umas coisas aqui."; o armário fica com menos coisas |
| S12 | Seguir na volta | Em casa: "Trouxe suprimentos!"; o **estoque fica maior** |
| S13 | Voltar alguns dias depois | O estoque **diminuiu** (eles comem) ou **aumentou** (saquearam fora da tela) |

## 4d. Roteiro: atiradores (0.4.1)
Crie NPCs até sair um **atirador** (Ficha mostra o arquétipo), ou um policial/veterano.

| # | Ação | Esperado |
|---|---|---|
| R1 | Aliado atirador perto de **um** zumbi | Usa a **faca** (não quer atrair mais zumbis) |
| R2 | Aliado atirador com **3+ zumbis** vindo | Saca a arma, **mira e atira** com som de tiro; mais zumbis aparecem atraídos pelo barulho |
| R3 | Saqueador atirador te vê a uns 8 tiles | Atira em você; acerto deixa **bala alojada** (Saúde) |
| R4 | Chegar perto dele (2-3 tiles) | Ele **recua** para atirar; colado, usa a faca |
| R5 | Deixar ele atirar até acabar | "Acabou a munição!" e passa para a faca |

## 4e. Roteiro: NPC derrubado (0.4.3)

| # | Ação | Esperado |
|---|---|---|
| K1 | Empurrar/derrubar um saqueador e bater nele no chão | Ele **não te acerta** enquanto está no chão, levantando ou cambaleando |
| K2 | Derrubá-lo no meio de um golpe dele | O golpe **não conta** |
| K3 | Parar de bater e se afastar | Ele **levanta** sozinho em alguns segundos e volta a lutar |

## 4f. Roteiro: percepção e perseguição (Fase A, 0.5.0)
Use um saqueador: **Ferramentas de teste → Criar saqueador hostil**, a uns 10–15 tiles, ou um grupo de saqueadores. Desligue **"Saqueadores assaltam antes de atacar"** no sandbox se quiser testar a perseguição pura.

| # | Ação | Esperado |
|---|---|---|
| PA1 | De noite, agachado, passar a ~8 tiles **atrás** dele | Não te nota |
| PA2 | De dia, de frente, a ~12 tiles, andando | Leva um instante, fica desconfiado ("Tem alguém aí?") e depois vem |
| PA3 | Atirar/quebrar vidro longe dele | Ele vai **investigar o lugar do som**, não direto em você |
| PA4 | Ser perseguido e **virar uma esquina / entrar num prédio** | "Cadê você?", procura um pouco no último ponto e **desiste** ("Sumiu. Deixa pra lá.") |
| PA5 | Fugir correndo em linha reta | Depois de 10–25 s ele **cansa** ("Não aguento mais correr...") e passa a andar; você abre distância |
| PA6 | Fugir para longe da casa dele (~70 tiles) | Ele **volta** |

## 4g. Roteiro: combate justo (Fase B, 0.5.0)

| # | Ação | Esperado |
|---|---|---|
| CB1 | Apanhar de um brigão sem armadura | Você aguenta **vários golpes** (não morre em 2-3); com jaqueta de couro/capacete, alguns golpes só dão hematoma |
| CB2 | Ser visto por um saqueador **atirador** | "Parado! Não se mexe!" e ele mira por uns 2 s **antes** do primeiro tiro: dá para se esconder |
| CB3 | Correr de um atirador à noite | Raramente acerta; a mais de ~6 tiles no escuro nem atira |
| CB4 | Contar os tiros | Ele para para recarregar depois de alguns tiros; acaba a munição e vai na faca |
| CB5 | Encontrar saqueadores com mochila e arma | "Larga a mochila e a arma! Agora!" e não atacam por ~15 s |
| CB6 | Largar a arma e a mochila no chão (CB5) | "Isso. Agora some daqui." Eles pegam suas coisas e vão embora. Não te atacam por 5 min |
| CB7 | Em vez disso, ir embora (CB5) | Deixam você ir |
| CB8 | Matar o líder de um grupo de saqueadores | Os outros **fogem** ("Recua! Recua!"); um muito ferido perto de você se **rende** e senta ("Não atira!") |
| CB9 | Ouvir os NPCs de perto | Sem gemido de zumbi; nenhum rastejando com a perna ferida |

## 4h. Roteiro: Dia Zero (Fase C, 0.6.0)
**Save novo**, sandbox padrão ("Meses desde o apocalipse" = 0). Ligue **"Log detalhado"** para ver no console `passagem: <tipo>` e `tiro ao longe`.

| # | Ação | Esperado |
|---|---|---|
| DZ1 | Andar ~10 min pela cidade no dia 1 | Vários civis passando: andando, **fugindo com zumbis atrás**, famílias, alguém pedindo socorro ou batendo numa porta; às vezes tiros ao longe |
| DZ2 | Primeiros 3 dias perto de onde você começou | **Nenhum saqueador** (nem grupo, nem de passagem) |
| DZ3 | Salvar um ferido pedindo socorro (matar os zumbis em volta e chegar perto) | "Valeu pela ajuda!" e ele vai embora; a reputação dos civis sobe (Ficha de um civil) |
| DZ4 | Ver um civil **pregando tábuas** numa janela | A janela fica de fato barricada |
| DZ5 | Ver uma **briga por comida** | Dois civis brigam; quando um apanha muito, foge e acaba |
| DZ6 | Deixar um aliado ser mordido (ou Ferramentas → passagem "fugindo" e deixar os zumbis pegarem) | "Fui mordido..."; horas depois "Não tô me sentindo bem..."; depois ele **vira zumbi** com a mesma roupa |
| DZ7 | Um NPC morto por zumbis | O corpo **levanta** como zumbi uns 20–60 s depois |
| DZ8 | Avançar o tempo até o dia ~8–15 (ou "Dia em que os saqueadores começam" = 0) | Saqueadores começam a aparecer (rondando, grupos novos); menos gente comum na rua |
| DZ9 | Ferramentas de teste → "Passagem: ..." | Força cada tipo de evento para conferir |

## 4i. Roteiro: mundo persistente (Fase D, 0.7.0)
Save novo, "Log detalhado" ligado (console: `regiao ...`, `troca:`, `caiu para os zumbis`, `recrutou`, `tomou a base`).

| # | Ação | Esperado |
|---|---|---|
| W1 | Começar numa cidade e "Listar todos os grupos" | Vários grupos perto (cidade); poucos/nenhum se você começou no campo |
| W2 | Viajar para outra cidade (mais de 300 tiles) | Console: `regiao X,Y (N predios): K grupos`; a cidade nova tem moradores |
| W3 | Seguir um grupo saindo para saquear fora da tela (Info do grupo: "scavenge") | Ele aparece **no caminho** quando você chega perto, em vez de "teletransportar" |
| W4 | "Simular 1 dia (bases evoluem)" algumas vezes perto de uma safehouse e voltar | Mais janelas com tábuas |
| W5 | "Simular 1 dia" várias vezes num grupo pequeno, longe | Às vezes `caiu para os zumbis`; indo lá: **zumbis dentro**, estoque e tábuas intactos |
| W6 | "Relações do grupo mais próximo" | Console lista os vizinhos com a relação (saqueadores negativos, mesma facção positivos) |
| W7 | Bater num membro de um grupo que tem aliado perto | A reputação com o aliado também cai (pela metade) |

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
- Tiro de NPC não tem projétil visível nem flash; o acerto é calculado (chance pela distância).
- Sem diálogo, troca, recrutamento e missões (Fase E do plano).
- Gente de passagem que estava em cena num save e cujo tempo acabou pode voltar ao carregar como um zumbi comum com roupa limpa (o corpo fica no chunk).
- Placas não têm texto desenhado no mundo (o jogo não suporta): o texto aparece sobre você ao chegar perto. A "fumaça" é uma fogueira acesa.
- A pose de dormir usa a animação de dormir na cama do jogador, no chão.
- Portas trancadas pelas safehouses ficam trancadas para você também (como no jogo: arrombe, quebre uma janela ou ganhe a confiança deles, na Fase 4).
- A simulação fora de cena é abstrata: grupos "viajam" em linha reta pelo mapa.
