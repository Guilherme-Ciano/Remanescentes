# Como testar o Primeiros Dias (0.17.0)

> **Casas barricadas do próprio jogo ≠ safehouses do mod.** O B42 já gera casas com tábuas **por fora** e cheias de zumbis (histórias aleatórias). As safehouses do mod têm tábuas **por dentro**, uma porta principal sem tábuas, moradores humanos e, quase sempre, placa, corpos empilhados e fogueira. Para achar uma: **Ferramentas de teste → "Info do grupo mais próximo"** e **"Teleportar perto do grupo mais próximo"**.
>
> **Save antigo (de antes da 0.4):** os grupos antigos agora são preparados quando você chega perto. Se quiser grupos novos com tudo desde o início, use **"Recriar grupos do mundo"**.

## 1. Testes automáticos (fora do jogo, ~1 segundo)
```bash
cd ~/Zomboid/mods/Remanescentes && lua5.1 tests/run_tests.lua
```
Simulam a API do jogo (1080 verificações) e verificam spawn, movimento, combate (inclusive o ataque real dos zumbis e a troca de alvo), hostis, NPC × NPC, mundo vivo (semeadura, simulação, saque, casas vazias), materialização, save/load e migração da 0.2.
Também verificam o contrato de extensão (eventos, comportamentos, facções, opções de menu). Novos testes: basta criar `tests/test_<tema>.lua`. Desempenho: `lua5.1 tests/bench/bench.lua 1500` (ms por quadro com 1500 zumbis).
**Não** testam animações nem o motor real: isso só dentro do jogo.

## 2. Preparar o jogo
1. Opções de inicialização da Steam: `-debug` (mantendo o `-javaagent` do ZombieBuddy, se usar).
2. **Use um save NOVO de teste.** Saves da 0.2 funcionam (os sobreviventes são migrados como aliados), mas o primeiro teste deve ser limpo.
3. Mods → ative **Remanescentes**.
4. Sandbox → abas **Remanescentes: Sobreviventes / Mundo / Zumbis / Teste**: deixe o padrão, **exceto** na aba **Teste**: ligue **"Ferramentas de teste no clique direito"** (vem desligada desde a 0.9.0) e, se quiser ver o que acontece por trás, **"Log detalhado"**.

Tudo de teste fica em: clique direito no chão → **Remanescentes → Ferramentas de teste**, dividido em submenus: **Criar**, **Mundo e grupos**, **Gente de passagem**, **Reputação** e **Outros**.

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

## 4j. Roteiro: interação (Fase E, 0.8.0)
Ache um grupo de civis ("Teleportar perto do grupo mais próximo"). Clique direito num morador → **Conversar**.

| # | Ação | Esperado |
|---|---|---|
| I1 | Abrir a conversa | Janela com nome, profissão, facção, atitude e reputação; cumprimento conforme a atitude; o NPC **para e olha para você** |
| I2 | "Como vão as coisas?" com alguém do grupo ferido | Fala que precisa de remédio |
| I3 | "Sabe de outros grupos?" (reputação baixa e depois alta; use "Reputação +25") | Primeiro desconfia; depois diz direção e distância de outro grupo |
| I4 | "Quero trocar" | Janela de troca: à esquerda suas coisas, à direita o estoque deles com valores; marque itens e veja o saldo; troca injusta é recusada; troca justa move os itens (os seus vão para o armário deles) |
| I5 | "Posso ficar com vocês?" com reputação alta | Aceitam; a porta principal fica destrancada para você |
| I6 | "Quer vir comigo?" com alguém leal (Ficha) e reputação alta | Vira aliado e passa a te seguir |
| I7 | Clique direito no aliado → **Guardar esta posição** / **Saquear o prédio aqui perto** | Fica de guarda no lugar / vai, abre armários e volta te entregando os itens |
| I8 | "Precisam de ajuda?" | Recebe uma missão conforme a necessidade; "Sobre o que vocês pediram..." entrega/conclui e dá recompensa |
| I9 | Missão "alguém sumiu" | Vá na direção dita, fale com ele ("Sua família tá te esperando") e ele volta para casa; depois conclua com o grupo |
| I10 | "[Ameaçar]" com um machado na mão | Medroso entrega coisas; corajoso reage e o grupo ataca |
| I11 | Depois de "Sabe de outros grupos?" (com resposta), abrir o mapa (M) | "Deixa eu marcar no seu mapa" + aviso "Local marcado"; no mapa: **círculo colorido** pela facção, símbolo e anotação com quem contou |
| I12 | Pegar a missão "alguém sumiu" e abrir o mapa | Um **?** laranja onde a pessoa está, e a casa do grupo marcada |
| I13 | Ganhar abrigo e abrir o mapa | A casa marcada como "Abrigo" |
| I14 | Fechar e abrir o mapa / salvar e carregar | As marcações continuam, sem duplicar |

## 4k. Roteiro: janelas e falas novas (Fase F, 0.9.0)
Ache civis ou crie um ("Criar" → civil). Clique direito → **Conversar**.

| # | Ação | Esperado |
|---|---|---|
| F1 | Abrir a conversa | Janela larga: à esquerda o **retrato** (ícone da profissão sobre a cor da facção), nome, profissão e idade, arquétipo, a **facção na cor dela**, a atitude colorida e uma **barra de reputação**; à direita o histórico e as opções numeradas, "tchau" separado embaixo |
| F2 | Clicar em algumas opções | O histórico mostra "Você:" em azul e a resposta na cor da facção; o NPC **também fala em voz alta** (texto sobre a cabeça) |
| F3 | Repetir "Como vão as coisas?" e despedir-se algumas vezes | As respostas **variam**; um NPC medroso (Ficha: coragem baixa) fala assustado; um agressivo fala seco |
| F4 | Afastar-se uns 7 tiles com a janela aberta | A janela **fecha sozinha** |
| F5 | "Quero trocar" | Cada item com **ícone** e valor; em cima o que o grupo está precisando e a margem que cobram; embaixo totais e saldo. Itens marcados ficam verdes (seus) e laranja (deles) |
| F6 | Marcar só coisas deles | Botão **Trocar desabilitado** (saldo negativo); marcando coisas suas suficientes, habilita |
| F7 | Ficar perto de vários NPCs por alguns minutos (combate, ocioso) | Falas variadas, sem a **mesma frase duas vezes seguidas**; saqueadores falam como durões, civis medrosos falam assustados |
| F8 | Novo jogo → Sandbox | 4 abas com títulos "Remanescentes: ...", textos com acento e explicação em cada opção |
| F9 | Jogar perto de uma horda grande (100+ zumbis) com vários NPCs | Sem queda de FPS perceptível causada pelos NPCs |
| F10 | Ativar junto com o seu modlist | Nenhum erro novo no console; o mapa (M) com Map Symbol Size Slider mostra as marcações na escala escolhida |
| F11 | Clique direito num NPC → **Ficha** | Janela com retrato, profissão, idade, arquétipo, atitude e reputação, barras de vida e moral, munição (atiradores) e as 5 barras de personalidade |
| F12 | Ficar perto de NPCs por um minuto; clique direito → **Status** | As falas aparecem **sobre a cabeça deles**, na cor da facção, com contorno, e somem depois de alguns segundos. O Status aparece do mesmo jeito |

## 4l. Roteiro: vida dos personagens e histórias (0.10.0)
Ligue as ferramentas de teste e o "Log detalhado" (console: `vinculo ...`, `conversa (...)`, `emboscada revelada`, `cerco: ...`).

| # | Ação | Esperado |
|---|---|---|
| V1 | Ficar parado perto de um grupo em casa por 2–3 minutos | Dois moradores **conversam entre si** (um fala, o outro responde, sobre a cabeça de cada um); falas à toa diferentes de pessoa para pessoa |
| V2 | Clique direito → **Ficha** em várias pessoas | Cada uma com **jeito** e **humor**; barra de **vínculo com você**; "Experiência: nível 0"; lembranças vazias |
| V3 | Conversar → **"Me fala de você."** | Conta quem era, quem perdeu e o que quer (um desconfiado se recusa até você fazer algo por ele). A história passa a aparecer na Ficha |
| V4 | Conversar → **"Toma, fica com isso."** com comida ou bandagem no inventário | Ele agradece; o item sai do seu inventário; vínculo sobe (Ficha: "Você deu um presente"). De novo em seguida: "Você já me deu bastante hoje" |
| V5 | Matar um zumbi que está atacando um civil, sair e voltar | Ao conversar: "É você! Ainda te devo a vida."; de passagem ele cumprimenta como amigo |
| V6 | Bater num civil, esperar a raiva passar e conversar | "Você. Ainda lembro do que você fez."; Ficha mostra a lembrança em vermelho |
| V7 | Deixar um morador morrer perto dos outros | Alguém grita o nome dele; Ficha dos outros: humor **De luto (nome)** |
| V8 | Estar numa safehouse com comida ao meio-dia ou às 19 h | Moradores (menos o guarda) vão para a cozinha e **sentam para comer** |
| V9 | Andar com um aliado: anoitecer, chover, ficar ferido, matar 4 zumbis seguidos, chegar perto de uma horda | Ele **comenta** cada situação |
| V10 | Deixar um aliado matar 3 zumbis | "Tô pegando o jeito disso."; Ficha: nível 1 |
| V11 | Apontar a arma (botão direito) para um neutro a poucos tiles | "Ei! Abaixa isso!" |
| V12 | Ferramentas → Gente de passagem → **Mascate** | Um errante cruza a área; chegando perto, para e oferece troca; a janela de troca mostra o que ele carrega |
| V13 | Gente de passagem → **Emboscada** (use "Dia em que os saqueadores começam" = 0) | Alguém sentado pedindo socorro **sem zumbis em volta**; a 5 tiles: "Agora!" e os comparsas escondidos aparecem exigindo suas coisas |
| V14 | Gente de passagem → **Refém** | Um civil sentado com dois saqueadores. Matando os dois: ele levanta, agradece e fica perto; Conversar → "Quer vir comigo?" → aceita |
| V15 | Gente de passagem → **Alguém de luto** | Sentado, falas de luto; aceita conversa e presente |
| V16 | Ferramentas → Mundo e grupos → **Cerco ao grupo mais próximo**, estando perto da casa | Zumbis aparecem **em volta** da casa (não dentro); moradores pedem ajuda; ao limpar: "A casa aguentou por sua causa", reputação +20 |
| V17 | (jogo normal) Ter um grupo amigo marcado no mapa e ficar a algumas quadras | Em algum momento um **mensageiro** corre até você, pede ajuda e marca a casa no mapa |

## 4m. Roteiro: decisões e consequências (0.11.0)
**Save novo** (a fortificação gradual vale para casas ainda não visitadas). Ligue as ferramentas de teste e o "Log detalhado" (console: `objetivo = ...`).

| # | Ação | Esperado |
|---|---|---|
| D1 | Dia 0–1: "Teleportar perto do grupo mais próximo" | A casa tem **poucas ou nenhuma** tábua nas janelas |
| D2 | Ficar olhando a casa de dia por alguns minutos | Um morador vai até uma janela e **prega tábuas** (som de martelo, "Segura a tábua aí."); a janela fica barricada. No máximo 3 janelas por dia |
| D3 | Ferramentas → Mundo e grupos → **"Objetivo do grupo mais próximo"** | Mostra o objetivo, as necessidades, o material e as janelas fechadas/total |
| D4 | Atrair 1–2 zumbis para perto da casa | O guarda e mais um **saem para matá-los** ("Tem zumbi na rua.") e voltam |
| D5 | Atrair uma horda (15+) | Todos entram, ficam agachados: "Shh. São muitos." Quando a horda passa, voltam à rotina |
| D6 | Conversar → "Como vão as coisas?" em cada situação | A resposta muda: reforçando, limpando a rua, escondidos, sem material, buscando comida |
| D7 | Com o grupo sem material: "Precisam de ajuda?" | Pedem **tábuas e pregos**; entregando, voltam a pregar |
| D8 | Criar um civil e levar **um** zumbi até ele | A maioria **luta**; os covardes (Ficha: coragem baixa) fogem |
| D9 | Levar 4+ zumbis até um civil sozinho | Foge |
| D10 | Família de passagem (3–4) com 2 zumbis | Ficam e lutam juntos; um ajuda o outro |
| D11 | Correr com zumbis atrás e passar perto de um NPC | Parte dos zumbis **troca para ele** |
| D12 | Um NPC batendo/atirando com zumbis soltos por perto | Os zumbis vão **atrás dele** |
| D13 | Conversar e pedir abrigo/informação/recrutar sem reputação | Recusa, e uma linha cinza diz o que falta |
| D14 | Dar um presente, trocar, entregar missão | Linhas verdes: "Reputação com ...: +2 (agora 12)", "Vínculo com ...: +12" |
| D15 | Com vínculo 25+: "Tô precisando de ajuda." | Ele te dá comida (ou remédio se você estiver ferido); de novo no mesmo dia: "Não abusa." |
| D16 | Clique direito em qualquer lugar → Primeiros Dias → **Diário** | Dia do colapso, aliados, grupos conhecidos com o que estão fazendo, pedidos e acontecimentos |
| D17 | Deixar morrer alguém de um grupo conhecido / recrutar alguém | Aviso na tela e entrada nova no Diário |

## 4n. Roteiro: correções e usabilidade (0.12.0)

| # | Ação | Esperado |
|---|---|---|
| U1 | Abrir o mapa num save que já tinha marcações enormes | Elas voltam a um tamanho pequeno; marcações novas já nascem pequenas |
| U2 | Com um aliado, ao lado de uma casa **com a porta fechada**: clique direito nele → "Saquear o prédio aqui perto" (ou Conversar → "[Ordem] Vasculha o prédio") | Ele **abre a porta**, entra, para ao lado de cada armário, revira, volta e te entrega; fecha a porta externa ao sair. Se não achar nada: "Não achei nada que preste." |
| U3 | Durante o U2, afastar-se bastante | Ele larga o saque e vem atrás de você |
| U4 | Trocar com um aliado, com alguém de passagem e com um morador em casa | Sempre aparece algo do lado dele (bolsos; em casa, também o estoque) |
| U5 | Andar com um aliado ao lado por alguns minutos, sem zumbis | Sem o moodle de pânico. Com zumbis de verdade o pânico sobe normalmente |
| U6 | Pedir para um desconhecido te seguir | Recusa; a linha cinza diz a disposição e que o que pesa é o vínculo. Depois de salvá-lo, dar um presente e ouvir a história: aceita |
| U7 | Recrutar o 5º aliado | "Você já anda com gente demais." |
| U8 | Correr (ou pegar um carro) e deixar o aliado para trás | Em alguns segundos ele reaparece perto: "Espera! Quase te perdi." |
| U9 | Clique direito no chão → Primeiros Dias → "Aliados: todos esperem aqui" / "todos comigo" | Todos obedecem de uma vez |
| U10 | Mandar um aliado seguir você por dentro de uma casa com portas internas fechadas | Ele abre as portas e passa; se ficar preso num canto, dá um passo para o lado e continua |

## 4o. Roteiro: correções do segundo teste (0.13.0)

| # | Ação | Esperado |
|---|---|---|
| X1 | Clique direito → Primeiros Dias → **Diário** | Abre com texto (dia, aliados, grupos com direção e distância, pedidos, acontecimentos) e o contador de erros do jogo não sobe |
| X2 | Brigar com zumbis ao lado de um aliado e depois ficar calmo uns 15 s | O sangue some do rosto e da roupa dele; ele não fica com "cara de zumbi" |
| X3 | Andar com 2–3 aliados por dentro de uma casa (portas, paredes, cômodos), sem zumbis | Sem o moodle de pânico. Com zumbis de verdade chegando, o pânico sobe normalmente |
| X4 | Abrir o mapa num save com marcações sobrepostas | Elas são redesenhadas lado a lado em volta de cada casa, com um círculo só |
| X5 | Pegar abrigo e uma missão "limpar a rua" no mesmo grupo e abrir o mapa | Casa, abrigo e missão ficam lado a lado, sem se cobrir |
| X6 | Ferramentas → "Objetivo do grupo mais próximo" numa casa com zumbis passando na rua | O objetivo não fica trocando entre "hide" e "clear"; com janelas abertas e material: "fortify" |
| X7 | Anotar quantas janelas a casa tem com tábuas, ir para longe por 1–2 dias de jogo e voltar | Mais janelas com tábuas (até 3 por dia, se tinham material) |

## 4p. Roteiro: a sua base (0.14.0)
Tenha 2–3 aliados ("Criar aliado" nas ferramentas, ou recrute). Escolha uma casa vazia com janelas.

| # | Ação | Esperado |
|---|---|---|
| B1 | Dentro da casa: clique direito → Primeiros Dias → **"Definir este prédio como base"** | "Esta é a nossa base agora. (N armários de estoque)"; marcação "Sua base" no mapa; Diário com a seção "Sua base" |
| B2 | Clique direito → **"Aliados: todos para a base"** | Todos vão para a casa. No Diário: um fortificando, um de vigia, um buscando suprimentos |
| B3 | Conversar com um morador | Opções "[Base] Fortifica a casa / Fica de vigia / Busca suprimentos / Descansa em casa" e "[Ordem] Vem comigo" |
| B4 | Deixar algumas tábuas e pregos (ou uma caixa de pregos) na geladeira/prateleira da base | Somem do armário em alguns segundos; o material da base sobe (Diário / "Objetivo do grupo mais próximo") |
| B5 | Ficar na base de dia | O morador de "fortificar" prega tábuas nas janelas (martelo); o vigia fica do lado da porta |
| B6 | De dia, esperar o coletor | Ele sai, entra num prédio perto, revira os armários, volta e guarda tudo no estoque da base |
| B7 | Deixar comida no estoque e passar um dia | Parte da comida some (eles comem). Suas ferramentas e armas continuam lá |
| B8 | Ir explorar longe por 1–2 dias e voltar | Diário com buscas ("voltou com N itens"); itens novos no estoque; janelas novas com tábuas (se havia material) |
| B9 | Deixar a base sem comida por 3 dias | Aviso de fome no Diário; depois alguém vai embora |
| B10 | "[Ordem] Vem comigo" com um morador | Ele sai da base e volta a te seguir (se você tiver menos de 4 aliados) |
| B11 | Definir outra casa como base | A base muda de lugar; os moradores vão para a nova |

## 4q. Roteiro: base viva (0.15.0)
Base com 3–4 moradores. Deixe tábuas e caixas de pregos no estoque (ou mande buscar material). Use "Simular 6 horas" e as ferramentas "Base: ..." em Mundo e grupos.

| # | Ação | Esperado |
|---|---|---|
| L1 | Um morador em "fortificar", de dia, com material | Ele vai de janela em janela pregando 2 tábuas; depois as portas dos fundos; depois reforça até 4 |
| L2 | Continuar (ou voltar depois de um tempo) | Começa a **cerca de madeira** em volta da casa, com uma passagem na frente da porta principal |
| L3 | Com a cerca pronta | Comemoram; Diário: "A cerca em volta da base está pronta!" |
| L4 | Depois da cerca | **Carros queimados** aparecem nas ruas em volta, primeiro a rua da frente |
| L5 | Dois moradores em "buscar material" (ou um nele e outro descansando) | Saem **juntos**; um revira os móveis de um prédio perto (barulho de desmontar), o outro acompanha; voltam com tábuas/pregos que viram material |
| L6 | Só um morador em busca, sem ninguém descansando | Ele não sai: "Sozinho eu não saio. Alguém vem comigo?" (e o Diário explica) |
| L7 | Ferramentas → "Base: horda na cerca" com você lá | Zumbis aparecem do lado de fora da cerca; os moradores lutam |
| L8 | "Base: visitante no portão" | Alguém na frente da porta pedindo para ficar; Conversar → "Pode ficar na nossa base" → vira morador |
| L9 | "Base: briga entre moradores" | Dois discutem em voz alta; moral cai |
| L10 | "Base: ladrão à noite" com e sem vigia | Sem vigia: some comida; com vigia: "espantou alguém" |
| L11 | Ir longe por 2–3 dias e voltar | Diário cheio (saídas em dupla, obras, talvez horda/visitante); obras novas na casa e em volta |

## 4r. Roteiro: as facções também constroem (0.16.0)
Save novo. Ligue "Log detalhado". Use "Teleportar perto do grupo mais próximo" e "Simular 6 horas"/"Simular 1 dia".

| # | Ação | Esperado |
|---|---|---|
| F1 | Ficar uma tarde perto de uma casa de família | Um morador prega tábuas nas janelas; outro fica na porta. Se o material acabar, dois saem juntos para buscar e voltam |
| F2 | Conversar → "Como vão as coisas?" | "Estamos trabalhando na casa: ..." (a obra atual) ou que falta material |
| F3 | Visitar uma milícia depois de alguns dias | Cerca de madeira em volta, **arame farpado** do lado de fora, **carros queimados** nas ruas, às vezes um gerador |
| F4 | Visitar uma base de saqueadores | Arame farpado e carros bloqueando as ruas (sem cerca de família) |
| F5 | Simular vários dias longe de um grupo conhecido e voltar | A casa está mais fortificada; o Diário mostra a obra de cada grupo e notícias ("terminou: cerca", "uma horda atacou a casa de ...") |
| F6 | Sandbox "Obras dos grupos" = 0 | Os NPCs não constroem nada |

## 4s. Roteiro: alianças, armas e ataques (0.17.0)

| # | Ação | Esperado |
|---|---|---|
| A1 | Segurando um machado, conversar com um aliado → "[Equipar] Usa esta arma." | Ele aparece com o machado na mão; a arma antiga dele vai para o seu inventário |
| A2 | Segurando uma pistola, com caixas de 9 mm na mochila | Ele recebe a pistola e até 2 caixas; atira nos zumbis |
| A3 | Ficha de um engenheiro "fortificando" vs um morador comum | O engenheiro avança mais rápido nas obras |
| A4 | Grupo com reputação alta → "Vamos nos aliar." | Aceitam; Diário: "Você fechou uma aliança"; troca sem margem; "(aliado)" no Diário |
| A5 | Ter um aliado com comida sobrando | Às 10 h chega comida na sua base (Diário) |
| A6 | Ferramentas → "Base: ataque de saqueadores", com você na base (depois do dia dos saqueadores, com um bando por perto) | Saqueadores chegam correndo para a base; os moradores lutam |
| A7 | Bater em alguém de um grupo aliado | A aliança acaba (Diário) |

## 4t. Roteiro: vida no grupo (0.18.0)

| # | Ação | Esperado |
|---|---|---|
| V1 | Andar umas 20 h de jogo com um aliado sem comida nos bolsos | Ele pede comida; "Como vão as coisas?" fala da fome; Ficha mostra "faminto" |
| V2 | Conversar → "[Comida] Toma, come isto." com uma lata na mochila | A lata some da mochila; ele agradece; a fome cai (Painel/Ficha) |
| V3 | Aliado cansado → "[Descanso] Tira um cochilo." | Ele deita ali; com um zumbi chegando perto, levanta e briga |
| V4 | Base com 2 vigias, à noite, abrir o "Painel da base" | Escala com os dois revezando; o de folga dorme dentro de casa, o do turno fica na porta |
| V5 | Ferramentas → "Base: alarme do vigia" (ou um zumbi chegando à noite) | O vigia grita; quem dormia levanta e vai para a porta; Diário registra |
| V6 | Aliado → "[Combate] Segura o fogo." perto de zumbis | Ele não atira nem corre atrás; só bate em quem encostar |
| V7 | Clique direito num zumbi → "Aliados: ataquem este!" | Os aliados vão nele |
| V8 | Com base definida → "Todos: recuem para a base" | Os aliados correm para a base e ficam esperando lá |
| V9 | Fazer um saqueador se render → "[Prisioneiro] Você vem comigo." → levar para a base → "Fica preso aqui." | Ele anda atrás de você sem brigar; depois fica sentado num canto da base |
| V10 | Interrogar até ele falar | O bando aparece no mapa e no Diário |
| V11 | Painel → clicar num morador | A tarefa dele muda (fortificar → vigiar → buscar → material → descansar) |

## 4u. Roteiro: pessoas com história (0.19.0)

| # | Ação | Esperado |
|---|---|---|
| P1 | Deixar um morador fortificando um dia inteiro | Diário: "está melhor em carpintaria (nível 1)"; Ficha mostra "Habilidades" |
| P2 | Dois moradores na tarefa de busca por alguns dias | Diário: "viraram amigos"; a Ficha lista o amigo |
| P3 | Aliado leva um golpe forte de um saqueador | Às vezes: "se feriu: perna ferida"; ele passa a só andar; painel mostra [perna ferida] |
| P4 | Painel → colocar alguém em "na enfermaria" | Os ferimentos dos outros saram mais rápido (Ficha: dias para sarar caem) |
| P5 | Matar um saqueador com um aliado armado por perto | Quando a briga acaba, o aliado vai até o corpo, revista e traz as coisas para você |
| P6 | Definir a base, recrutar, terminar a cerca | Na tela: "Novo capítulo: ..."; Diário → seção Crônica com o dia de cada um |

## 4v. Roteiro: mundo em movimento (0.20.0)

| # | Ação | Esperado |
|---|---|---|
| M1 | Andar até perto da casa de um grupo | Aparece "Território de ... (facção)"; o grupo entra no Diário |
| M2 | Ferramentas → "Mundo: guerra entre os dois grupos mais perto" | Diário: "Guerra: X contra Y"; conversar com um deles → "Estamos em guerra com..." e "[Guerra] Estou do lado de vocês." |
| M3 | Troca com um grupo em guerra, oferecendo munição | A munição vale bem mais que antes |
| M4 | Ferramentas → "Passagem: caravana perto de você" | Uma dupla aparece andando; conversar → trocar mostra a mercadoria nos bolsos |
| M5 | Ficar perto até uma emboscada (ou repetir M4) e matar os saqueadores | Diário: "Você defendeu a caravana de ..."; reputação com o grupo sobe |
| M6 | Deixar uma base de NPC cair (Ferramentas de horda, ou esperar) | Diário: "N sobreviventes de X fugiram"; depois, "encontrou abrigo em ..." |
| M7 | Cruzar com um refugiado na rua, com base definida | "[Refugiado] Venha para a nossa base." → ele vira morador |

## 4w. Roteiro: fama, política e cicatrizes (0.21.0)

| # | Ação | Esperado |
|---|---|---|
| F1 | Salvar 5 pessoas de zumbis | "Começam a falar de você como quem salva gente"; um desconhecido comenta na primeira conversa |
| F2 | Clique direito → "Dar um nome ao seu grupo" | Caixa de texto; o nome aparece no painel e no Diário |
| F3 | Com 4+ moradores, aceitar um visitante | Diário: "O conselho apoiou" ou "foi contra"; painel mostra a votação |
| F4 | Conversar com um grupo que confia em você → "[Diplomacia] Vamos respeitar..." | Diário: "Pacto de respeito com ..." |
| F5 | Saqueador rendido → "[Diplomacia] Diga ao seu bando: pagamos..." | Sai comida do estoque; Diário: dias sem ataques |
| F6 | Ouvir a história de um aliado (goal família/horta/norte) → "[Pessoal] Posso te ajudar com aquilo?" | Marca no mapa / pede sementes; concluir dá Diário e capítulo |
| F7 | Morador com trauma → "[Conversa] Como você está, de verdade?" com vínculo | O nível do trauma cai; um dia ele supera |

## 4x. Roteiro: os primeiros dias (0.22.0)

| # | Ação | Esperado |
|---|---|---|
| H1 | Começar um jogo novo e abrir o mapa | "Barreira militar" marcada perto; Diário: "O Exército montou uma barreira..." |
| H2 | Ir até a barreira | 3 soldados com armas; chegando perto, "Área em quarentena! Volte para casa!"; atiram nos zumbis |
| H3 | Voltar à barreira depois do dia 5 | Soldados sumiram; zumbis de farda e itens no chão; Diário e capítulo da Crônica |
| H4 | Carregar um rádio de pilha por algumas horas | "Rádio: ..." na tela e no Diário; grupos citados aparecem no mapa |
| H5 | Base com gerador montado e um morador em "Busca gasolina" | Diário: gasolina trazida; à noite o gerador liga e a casa acende; painel mostra "Gasolina" |
| H6 | Deixar os moradores fortificando depois da cerca e do arame | Obras "latas de alarme" e "estacas"; painel mostra os números |
| H7 | Ferramentas → "Raro: comboio militar abandonado" e ir até o ponto | Carros queimados, zumbis de farda, itens no chão |

## 5. Se algo der errado
```bash
grep -n "Remanescentes\|STACK TRACE" ~/Zomboid/console.txt | tail -60
```
- Ligue "Log detalhado" no sandbox para ver percepção, saques, materialização etc.
- **Desativar o mod é seguro:** sobreviventes em cena viram zumbis comuns com roupa de civil. Zumbis "sem dentes" voltam ao normal ao carregar, porque essa flag não é salva.
- Me mande: o que fez, o que esperava, o que aconteceu, as linhas do console e, se der, um print.

## 6. Limitações conhecidas
- **Só single player.**
- Reações de **queda/levantar** ainda são de zumbi. A de levar golpe é humana.
- Tiro de NPC não tem projétil visível nem flash; o acerto é calculado (chance pela distância).
- Gente de passagem que estava em cena num save e cujo tempo acabou pode voltar ao carregar como um zumbi comum com roupa limpa (o corpo fica no chunk).
- Placas não têm texto desenhado no mundo (o jogo não suporta): o texto aparece sobre você ao chegar perto. A "fumaça" é uma fogueira acesa.
- A pose de dormir usa a animação de dormir na cama do jogador, no chão.
- Portas trancadas pelas safehouses ficam trancadas para você também (como no jogo: arrombe, quebre uma janela ou ganhe a confiança deles e peça abrigo).
- A simulação fora de cena é abstrata: grupos "viajam" em linha reta pelo mapa.
