# Remanescentes: plano de refinamento ("Dia Zero")

Objetivo: transformar o mod num **Project Zomboid dia zero**. O mundo está vivo: gente comum fugindo, andando sozinha, se trancando em casa. A ameaça humana cresce com o tempo e é **perigosa, mas justa e legível**. Você entende o que está acontecendo, tem chance de reagir, e morrer é consequência de uma escolha sua, não de azar nos primeiros segundos.

---

## 1. Diagnóstico (o que está cru, e a causa no código)

| Problema que você viu | Causa no código |
|---|---|
| **Impossível fugir de um hostil** | O hostil corre com a mesma animação de corrida do jogador e **nunca cansa**. Ele te vê a até 12 tiles, de dia ou de noite, e só "desiste" se você abrir 12 tiles de distância, o que nunca acontece. Não existe memória, procura nem desistência por tempo, nem limite de distância da casa dele. |
| **Atiram a todo custo** | Hostis sempre atiram (`worthTheNoise` só filtra os amigos). Começam com 4–25 balas, e milícia/seita **regeneram munição do nada** (+1/h). Acertam 50–90% e atiram a cada 1,3 s, de 12 tiles. Não avisam antes, não pensam nos zumbis que o tiro atrai, não recarregam. |
| **Morrer em segundos** | O dano no jogador é a arma × 18 numa parte do corpo. Facão: 36–54 por golpe; machado: até 36. Tiro de pistola: 15–25 por acerto, mais bala alojada. O NPC tem 3,0 de vida (um zumbi tem 1–2) e golpeia a cada 1,1 s, sem cansar. |
| **Grupo de 5 saqueadores armados logo no início** | Na 0.4 subi o tamanho dos grupos de saqueadores para 2–6, e 20% dos grupos são de saqueadores desde o dia 1. Cerca de 10% de cada saqueador é atirador (então ~40% dos grupos de 5 têm pelo menos uma arma). Não existe **período de graça** nem progressão por dia: o mundo começa no "mês 3". |
| **Muitos hostis** | Além dos saqueadores, milícia e seita viram hostis por invasão. O saqueador não tem objetivo além de matar: não assalta, não negocia, não foge quando o grupo dele cai. |
| **Ruas vazias** | Só existem os grupos persistentes (12 no mapa todo, entre 60 e 350 tiles do início), que só aparecem a 45 tiles. Não há **população de passagem**: gente andando sozinha, civis fugindo, alguém pedindo ajuda. |
| **"Desigual"** | Os amigos são tímidos (temperamentos novos), mas os hostis são máquinas: veem no escuro, nunca cansam, sempre atiram. A assimetria é o oposto do que deveria ser. |

**Bugs e pontos frágeis que encontrei revisando o código**
1. `canSee()` **falha aberta**: se a checagem de visão der erro, o NPC "vê" (no cérebro e no tiro). O certo é falhar fechada.
2. Visão dos NPCs **ignora a escuridão**. A dos zumbis contra NPCs usa a luz do dia; a dos NPCs contra você, não.
3. Agachado reduz só pela metade o alcance de quem te procura. Não existe "perdeu de vista e foi procurar no último ponto".
4. Munição sem fonte: os atiradores regeneram balas e não gastam o estoque da casa.
5. Perna ferida → o corpo-zumbi pode virar **rastejante** (`isBecomeCrawler`), com animação de zumbi. Não está tratado.
6. NPCs ainda **gemem como zumbi**, e as quedas e o levantar usam animação de zumbi.
7. O raio de cena (45 tiles) e o limite de ativos (12) dão "pop" visível de grupos grandes perto de você.
8. `DebugMenu` vem **ligado** por padrão: certo para teste, errado para o jogador.
9. Faltam opções de sandbox do plano original: dia em que os saqueadores começam, NPCs viram zumbis, intensidade/dificuldade.
10. O dano de NPC no jogador não passa pela proteção das roupas: sempre corte ou bala, ignorando jaqueta e capacete.

---

## 2. Princípios de design (valem para todas as fases)

1. **NPCs são pessoas, não torres.** Têm medo, cansaço, munição contada e instinto de sobrevivência. Um hostil quer *o que você tem*, não necessariamente te matar.
2. **Ameaça legível.** Antes de atacar, o hostil se anuncia (fala, aponta a arma, se aproxima). Você sempre tem um momento para fugir, se esconder, obedecer ou revidar.
3. **Fugir é possível.** Distância, quebrar a linha de visão, entrar num prédio, agachar no escuro e o cansaço deles funcionam.
4. **O barulho importa para todo mundo.** Atirar atrai zumbis; NPCs sabem disso e evitam, a menos que seja questão de vida ou morte.
5. **A ameaça cresce com o tempo.** Dia 0–3: caos civil, quase nenhum saqueador organizado. Depois, grupos se organizam e os recursos somem.
6. **Tudo calibrado e configurável.** Números com origem (comparados com o vanilla), opções de sandbox e um preset "Dia Zero".
7. **Cada fase termina com roteiro de teste no jogo** e critérios de aceite objetivos.

---

## 3. Fases e etapas

### Fase A: Percepção e perseguição (a base de tudo) ✅ 0.5.0 (validada no jogo)
Objetivo: os NPCs percebem e desistem como gente.

| Etapa | O que muda | Critério de aceite no jogo |
|---|---|---|
| A1 Visão humana | Alcance pela luz (noite reduz bastante), pelo seu estado (agachado, parado, correndo) e pelo campo de visão (cone para frente; de costas percebe só colado ou por barulho). `canSee` falha fechada. | À noite, agachado a 8 tiles, um hostil de costas **não te nota**. De dia, correndo na frente dele, nota. |
| A2 Audição | Tiros, gritos e janelas quebradas chamam a atenção (investigar o ponto), sem saber exatamente onde você está. | Tiro a 40 tiles: o NPC olha e vai na direção do som, não direto em você. |
| A3 Memória e procura | Estados: **ver → perseguir → procurar no último ponto visto → desistir**. O interesse decai com o tempo fora de vista. | Quebrou a linha de visão (virou a esquina, entrou num prédio) e ficou fora de vista ~20 s: ele procura e **desiste**. |
| A4 Cansaço | Correr gasta fôlego; sem fôlego, anda. Personalidade e idade mudam o fôlego. | Corrida longa: depois de ~15–25 s o perseguidor passa a andar e você abre distância. |
| A5 Coleira territorial | Cada NPC tem limite de distância da casa/grupo; passou, volta. Saqueador em patrulha tem coleira maior, mas tem. | Fugir uns 60–80 tiles da base: ele **volta**. |

### Fase B: Combate justo e equilibrado ✅ 0.5.0 (validada no jogo)
Objetivo: lutar com humanos é tenso, mas não é loteria.

| Etapa | O que muda | Critério de aceite |
|---|---|---|
| B1 Dano calibrado | Dano no jogador recalibrado a partir do dano de PvP do vanilla, passando pela **proteção das roupas** (`getDefense`/arranhão vs. corte vs. mordida) e por uma dificuldade no sandbox (Fácil/Normal/Difícil). O golpe tem "aviso" (preparação visível). | Normal: um brigão leva de 4 a 6 golpes para te derrubar sem armadura; com jaqueta de couro, mais. |
| B2 Disciplina de tiro | Munição **finita e real** (vem do estoque da base, sem regenerar). Avisa antes de atirar em você ("Parado!"). Só atira com linha de visão limpa, alvo parado/perto e sem aliado na frente. Precisão por arquétipo e personalidade, pior correndo e no escuro. Recarga (pausa). **Pesa os zumbis por perto** antes do barulho. | Atirador com 6 balas vs. você fugindo a 15 tiles à noite: no máximo 1–2 tiros e boa chance de errar. Num grupo, no máximo 1–2 atiradores ativos. |
| B3 Saqueadores com objetivo | Fluxo de **assalto**: cerca, manda largar a mochila/arma ou ir embora → se você obedece, eles pegam e saem; se você foge, perseguem com coleira; se você reage, combate. Moral do grupo: perdeu metade ou o líder caiu → fogem ou se rendem. | Saqueadores "pedindo" antes de matar; fugir ou obedecer funciona; matar o líder espanta o resto. |
| B4 Corpo humano | Impedir NPC rastejante (perna ferida → manca/ajoelha); silenciar os gemidos de zumbi; melhorar a queda e o levantar quando houver clipe humano. (Pesquisa no jar antes.) | Nenhum NPC rasteja ou geme como zumbi. |
| B5 Vida do NPC | Vida/defesa por arquétipo e armadura da roupa, em vez de 3,0 fixo. Ferimentos fazem mancar e fugir. | Um civil cai em 2–3 golpes; um miliciano com colete aguenta mais. |

### Fase C: Dia Zero (linha do tempo + população ambiente) ✅ 0.6.1 (validada no jogo)
Objetivo: a sensação dos primeiros dias do apocalipse.

| Etapa | O que muda | Critério de aceite |
|---|---|---|
| C1 Linha do tempo | Proporções e densidade mudam com os dias: **dias 0–3** quase só civis em pânico, poucos grupos armados; **4–14** grupos se organizam, primeiros saqueadores; **15+** escassez, saqueadores mais comuns, menos gente. Sandbox: "Dia em que os saqueadores começam", "Ritmo do colapso". | No dia 0 é raríssimo ver um hostil armado; no dia 20 encontros hostis são comuns. |
| C2 Zona de graça | Nos primeiros N dias, nenhum grupo hostil é sorteado nem anda a menos de X tiles do seu ponto de início. | Começo de jogo sem emboscada armada. |
| C3 População de passagem | NPCs **transitórios** (não vão para o save) nascem fora da sua vista, cruzam a área e somem: civil sozinho andando ou correndo, família fugindo, gente gritando por socorro com zumbis atrás, alguém batendo numa porta, sobrevivente machucado, saqueador oportunista (raro no início). Densidade pela linha do tempo e pelo tipo de bairro. | Andando 10 minutos pela cidade no dia 1, você vê vários civis passando, fugindo ou morrendo. |
| C4 Mortalidade real | NPC mordido fica **infectado** e **vira zumbi** horas depois, com a mesma roupa (sandbox liga/desliga). Civis morrem e viram parte da horda. | O civil que você salvou mordido aparece zumbificado no dia seguinte. |
| C5 Eventos de rua | Pequenas cenas: dois civis brigando por comida, alguém se trancando em casa, um grupo carregando suprimentos, um tiro ao longe. | Cenas variadas sem repetir a toda hora. |

### Fase D: Mundo persistente mais rico ✅ 0.7.0 (falta validar no jogo)
| Etapa | O que muda |
|---|---|
| D1 Distribuição | Grupos espalhados por zonas urbanas do mapa todo (não só perto do início), com densidade por cidade; ressemeia conforme você explora. |
| D2 Viagens reais | Grupos fora de cena andam em passos curtos por rua (não teleporte de 300 tiles/h), então dá para cruzar com eles no caminho. |
| D3 Bases que evoluem | Fortificam aos poucos, caem para hordas (viram ninho com o loot), crescem recrutando errantes, saqueadores tomam bases de famílias. |
| D4 Relações entre grupos | Alianças, rixas, comércio entre grupos, notícias que correm (reputação regional). |

### Fase E: Interação (Fase 4 do plano original) ✅ 0.8.0 (falta validar no jogo)
Conversar (menu de diálogo curto), trocar (valor pela necessidade do grupo), pedir abrigo, recrutar (Lealdade), comandos de seguidor (seguir, esperar, guardar posição, saquear aqui), missões simples, ameaçar e roubar.

### Fase F: Polimento e lançamento ✅ 0.9.0 (candidata a lançamento; falta validar no jogo)
| Etapa | Feito |
|---|---|
| F1 Revisão do código | Revisão estática de todos os módulos: nada vaza para o global, código morto removido (`canSee` antigo), formatos `%d` sempre com inteiro, mensagens de rotina movidas para o log detalhado. |
| F2 Desempenho | Índice espacial de zumbis (`Rem_Spatial.lua`, células de 8 tiles, refeito no máximo a cada 100 ms): busca de inimigos, percepção, tiro e eventos de rua deixaram de varrer todos os zumbis por NPC. Com 1500 zumbis e 12 NPCs: de 2,29 para 0,71 ms por quadro (`tests/bench/bench.lua`). |
| F3 Sandbox | 27 opções em 4 abas: **Sobreviventes**, **Mundo**, **Zumbis** e **Teste**. Os padrões já são o perfil "Dia Zero" (saqueadores a partir do dia 4, colapso normal, gente na rua 100%). `DebugMenu` desligado por padrão. |
| F4 Ferramentas de teste | Menu dividido em submenus (Criar, Mundo e grupos, Gente de passagem, Reputação, Outros). |
| F5 Interação mais bonita e real | Falas desenhadas pelo mod sobre a cabeça dos NPCs (o `Say` do jogo não funciona em corpo de zumbi). Janela de conversa com retrato (ícone da profissão), **Ficha em janela**, facção colorida, barra de reputação e histórico da conversa; janela de troca com **ícones**, valores, o que o grupo precisa e o saldo; respostas e falas com **variações** e **tom pela personalidade** (medroso, durão), sem repetir a última fala. |
| F6 Compatibilidade | Conferido com o modlist (ZombieBuddy, SmarterStorage, MapSymbolSizeSlider, EquipmentUI, EfficiencySkillMod2, DGVCurtains, HeliEvent, DGVWindows3D): nenhum substitui o que o mod usa. Os ganchos do mod encadeiam o original (mapa do mundo, pesca), e as marcações respeitam a escala do MapSymbolSizeSlider. |
| F7 Pacote | README, CHANGELOG, roteiro de testes por sistema, pasta da Workshop (`workshop/`) com descrição e imagem. Envio só depois da validação no jogo. |

### Fase G: Vida ✅ 0.10.0 (falta validar no jogo)
Pedido: "mais vida aos personagens e eventos, sistemas que fazem sentido, mais personalidade, mais divertido".

| Etapa | Feito |
|---|---|
| G1 Personalidade viva | Jeito, história, humor e moral que saem do estado real; luto; refeições em casa (`Rem_Persona`, `Rem_Routine`). |
| G2 Relação pessoal | Vínculo e memória por pessoa, presentes, cumprimentos que lembram de você, experiência por zumbis mortos (`Rem_Bonds`). |
| G3 Mundo falante | Conversas entre NPCs por assunto e comentários de contexto (`Rem_Banter`). |
| G4 Histórias | Mascate, emboscada, refém, enlutado e cerco com mensageiro (`Rem_Stories`). |
| G5 Confiabilidade | Lição da 0.9.1 (`Say` não funciona em zumbi; `UI3DModel` quebra a interface): todas as chamadas à API conferidas nas classes Java do jogo; sistemas novos só usam chamadas já validadas no jogo ou conferidas. |

### Fase H: Primeiros Dias ✅ 0.11.0 (falta validar no jogo)
Do teste da 0.10: civis só fugiam, zumbis ignoravam os outros sobreviventes, opções sem efeito visível, sistemas que não se conversavam.

| Etapa | Feito |
|---|---|
| H1 Decisão por pessoa | Lutar ou fugir por força × nervo contra o perigo (`Rem_Tactics`); ajudar companheiro atacado. |
| H2 Zumbis de verdade | Troca de alvo por distância; barulho de sobrevivente atrai zumbis para ele. |
| H3 Decisão por grupo | Necessidades → objetivo → trabalho visível (`Rem_Director`): pregar tábuas, limpar a rua, esconder, buscar comida e material; casas abertas nos primeiros dias. |
| H4 Consequências | Linhas de efeito e de motivo na conversa, pedir ajuda, missão de material, Diário com avisos (`Rem_Journal`). |
| H5 Nome | "Primeiros Dias" em tudo o que o jogador vê; ID interno mantido. |

### Fase I: correções e usabilidade ✅ 0.12.0 (falta validar no jogo)
Do teste da 0.11: anotações enormes no mapa, aliado que não saqueava, troca vazia, pânico com aliado por perto, recrutamento fácil.
Feito: tamanhos fixos no mapa (e reajuste das antigas), portas e quadrado livre ao lado do armário, bolsos, correção do pânico, recrutamento por vínculo com limite de aliados, destravar, alcançar, ordens para todos e pela conversa.

Ideias seguintes: rádio, ataques à base do jogador, caravanas entre grupos, aliados com necessidades (fome/sono), pedidos pessoais dos aliados.

---

## 4. Ordem recomendada e por quê

1. **A + B primeiro.** São o que torna o jogo injusto hoje. Sem percepção, desistência e combate calibrado, qualquer conteúdo novo (mais gente na rua) só multiplica a frustração.
2. **C em seguida.** É o coração do "dia zero" e depende de A/B: civis fugindo precisam de percepção boa, e saqueadores raros no início dependem da linha do tempo.
3. **D e E depois**, sobre uma base estável.
4. **F no fim** de cada bloco grande, mais um passe final.

Cada fase vira uma versão (0.5 = A+B, 0.6 = C, 0.7 = D, 0.8 = E), com testes offline, testes de mutação e roteiro no jogo. Não avanço de fase sem você validar no jogo os critérios de aceite da anterior.

---

## 5. Correções rápidas possíveis já (antes da Fase A completa)
Se quiser um alívio imediato enquanto a Fase A é feita:
- `canSee` falhando fechada; visão reduzida à noite.
- Desistência simples: fora de vista por ~15 s ou a mais de 40 tiles de casa → volta.
- Dano no jogador cortado à metade e disciplina mínima de tiro (só a menos de 10 tiles, sem regenerar munição, aviso antes do primeiro tiro).
- Saqueadores de volta a 2–4 por grupo; nenhum grupo hostil a menos de 150 tiles do início nos dois primeiros dias.
