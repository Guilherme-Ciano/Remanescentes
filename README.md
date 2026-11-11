# Primeiros Dias

*(nome interno e pasta do mod: `Remanescentes`; o ID não muda para não quebrar saves e opções)*

Mod de Project Zomboid (Build 42.20+, **single player**) que povoa o mundo com sobreviventes humanos: grupos que moram em prédios reais, saem para saquear, passam fome, brigam entre facções e lutam contra os zumbis (e contra você, se forem saqueadores).

**Versão 0.22.0** (candidata a lançamento). Histórico em [CHANGELOG.md](CHANGELOG.md).

## Destaques
- **A sua base:** defina um prédio como base, mande aliados morar lá e dê uma tarefa a cada um (fortificar, vigiar, buscar suprimentos, buscar material, descansar). Eles fecham janelas e portas, erguem uma cerca em volta, bloqueiam as ruas com carros queimados, saem em duplas, e a base vive eventos (hordas, visitantes, brigas, ladrões). Continua evoluindo enquanto você explora.
- **Alianças, armas e especialidades:** feche alianças com grupos que confiam em você (ajudam a defender sua base e mandam comida), dê suas armas e munição aos aliados, e aproveite a especialidade de cada um (engenheiro constrói mais rápido, médico cura, furtivo volta vivo).
- **As facções também constroem:** famílias, milícias, saqueadores e a seita fortificam as próprias bases com o tempo (tábuas, cercas, arame farpado, carros nas ruas, barril, gerador), saem em duplas para buscar material, e sofrem hordas. Uma base fortificada resiste a ataques e hordas; uma aberta cai.
- **Grupos que pensam:** cada grupo avalia comida, saúde e segurança e escolhe um objetivo: buscar suprimentos, fechar as janelas (você vê pregarem tábua por tábua), limpar os zumbis da rua, se esconder de uma horda, cuidar dos feridos.
- **Lutar ou fugir de verdade:** cada pessoa pesa o perigo contra a própria coragem, a vida, o moral e quem está do lado dela. Civis encaram um zumbi, fogem de vários, e se defendem juntos.
- **Zumbis caçam todo mundo:** barulho de sobrevivente atrai zumbis para ele, e um zumbi atrás de você troca para quem estiver mais perto.
- **Suas ações aparecem:** a conversa mostra o que mudou (reputação, vínculo, mapa) e por que um pedido foi recusado; o **Diário** reúne aliados, grupos conhecidos, pedidos e acontecimentos.
- **Gente de verdade no apocalipse:** famílias, milícias, saqueadores, uma seita e errantes, cada um com nome, idade, profissão, personalidade e roupa coerente.
- **Safehouses vivas:** casas barricadas por dentro, porta que os moradores abrem e trancam, estoque real nos armários, guarda, cozinheiro, gente dormindo à noite, placas, fogueira e gerador.
- **Saques de verdade:** os grupos saem, abrem armários e trazem o que acharam; o estoque enche e esvazia.
- **Combate justo:** eles te veem pela luz e pela postura, procuram, cansam e desistem; atiradores avisam antes de atirar e têm munição contada; saqueadores assaltam antes de brigar e fogem quando o líder cai.
- **Dia Zero:** os primeiros dias são de caos civil (gente fugindo, pedindo socorro, pregando tábuas); os saqueadores crescem com o tempo; mordidos viram zumbis.
- **Mundo persistente:** grupos pelo mapa todo conforme você explora, bases que fortificam, caem para hordas ou são tomadas, rixas e alianças entre grupos.
- **Personagens com vida:** jeito próprio, história, humor, luto, refeições em casa; conversam entre si e comentam o que acontece.
- **Vínculo pessoal:** cada um lembra do que você fez por ele (ou contra ele); dá para dar presentes, e seus aliados ganham experiência.
- **Histórias:** mascates, emboscadas, reféns para libertar e grupos amigos pedindo socorro quando uma horda cerca a casa.
- **Interação:** conversa com retrato e ficha, troca com valores pela necessidade do grupo, abrigo, recrutamento, comandos de seguidor, missões, ameaças, e marcações coloridas no seu mapa.

## Instalação
1. Inscreva-se na Workshop (ou copie a pasta `Remanescentes` para `~/Zomboid/mods/`).
2. No menu principal → **Mods** → ative **Remanescentes**. Requer **Build 42.20+**. Só **single player**.
3. Em **Sandbox**, as abas **Remanescentes: Sobreviventes / Mundo / Zumbis / Teste** trazem as opções (os padrões já são o perfil "Dia Zero").
4. Para as ferramentas de teste (criar NPCs, teleportar até grupos, simular tempo): aba **Teste** → "Ferramentas de teste no clique direito".

**Funciona em save já existente.** Desativar o mod é seguro: sobreviventes em cena viram zumbis comuns com roupa de civil.

## Opções de sandbox
| Aba | Opção | Padrão |
|---|---|---|
| Sobreviventes | Dificuldade (Fácil/Normal/Difícil) | Normal |
| | Dano deles em você / nos zumbis | 1,0 / 1,0 |
| | Vida dos sobreviventes | 2,0 |
| | Fogem com a vida abaixo de | 30% |
| | Saqueadores assaltam antes de atacar | sim |
| | Você pode ferir seus aliados | não |
| | Sobreviventes falam | sim |
| | Máximo perto de você | 12 |
| Mundo | Ritmo do colapso (Lento/Normal/Rápido) | Normal |
| | Dia em que os saqueadores começam | 4 |
| | Máximo de grupos no mundo / densidade | 40 / 100% |
| | Grupos de saqueadores | 20% |
| | Gente na rua | 100% |
| | Safehouses fortificadas | sim |
| | Bases caindo para hordas | 100% |
| | Chance de morte num saque / loot que sobra | 8% / 15% |
| Zumbis | Ataque dos zumbis aos sobreviventes (Real/Simulado) | Real |
| | Dano dos zumbis neles / visão contra eles | 0,15 / 10 tiles |
| | Barulho dos sobreviventes | 1,0 |
| | Viram zumbis / chance de infecção por acerto | sim / 25% |
| Teste | Ferramentas de teste no clique direito / Log detalhado | não / não |

## Compatibilidade
- Não substitui arquivos do jogo nem classes inteiras. Os únicos ganchos em funções vanilla **encadeiam o original**: `ISWorldMap.ShowWorldMap` (desenhar as marcações) e o handler de pesca (ignora personagens que não são jogador). Eventos são só adicionados (`Events.*.Add`).
- Conferido com: ZombieBuddy, SmarterStorage, Map Symbol Size Slider (as marcações seguem a escala escolhida), Equipment UI, Efficiency Skill, DGV Curtains, DGV Windows 3D, Heli Event.
- Mods que mexem na IA dos zumbis (`OnZombieUpdate`, `setUseless`) ou nos AnimSets de zumbi podem conflitar, porque os sobreviventes usam corpo de zumbi.
- Desempenho: um índice espacial de zumbis (`Rem_Spatial.lua`) mantém o custo baixo mesmo com hordas grandes (12 NPCs e 1500 zumbis: ~0,7 ms por quadro).

## Como funciona

### Corpo: um zumbi "humano"
Cada sobrevivente em cena é um `IsoZombie` com:
- `setUseless(true)`: desliga a IA de zumbi. O `PathFindState` ignora essa flag, então o movimento é forçado por `PathFindBehavior2` + `bPathfind`;
- pele humana (`MaleBody0X`/`FemaleBody0X`), roupa limpa e arma na mão;
- animações humanas via `AnimSets/zombie/*/Rem*.xml`, geradas por `tools/gen_animsets.sh` e ativadas pela variável `RemNPC`. A velocidade vem do root motion da animação (andar, correr, agachado);
- um cérebro em Lua (`Rem_Brain.lua`).

### Temperamento: quando vale a pena lutar
Cada facção encara zumbis de um jeito (`temper` em `Rem_Factions.lua`):

| Facção | Temperamento | Comportamento |
|---|---|---|
| Aliados | defensivo | Lutam só contra ameaças: zumbi colado, zumbi que os percebeu, zumbi atacando você por perto. Entram em qualquer briga que **você** começar (10 s depois de você acertar um zumbi). Não se afastam mais de 8 tiles de você por um zumbi. Recuam se cercados por 5+. |
| Civis | medroso | Fogem de ameaças a até 6 tiles; só batem se estiverem encurralados. |
| Sobreviventes | cauteloso | Lutam contra ameaças, recuam se cercados por 4+. |
| Saqueadores | agressivo | Atacam qualquer zumbi que vejam. |

Zumbi distraído passando longe é ignorado por todos, exceto pelos saqueadores.

### Ficha, personalidade e reputação (Fase 2)
- **Ficha** (`Rem_Profile.lua`, gerada no evento `personCreated` e salva na pessoa): idade, profissão do jogo (`base:policeofficer`...) com roupa coerente, arquétipo (brigão, atirador, furtivo, médico, engenheiro), personalidade de 0 a 10 (agressividade, confiança, coragem, ganância, lealdade) e estado (fome, cansaço, moral, munição).
- **Temperamento** = o da facção, ajustado pela personalidade nos extremos (covarde vira medroso; miliciano esquentado vira agressivo).
- **Atitude** (`Rem_Reputation.lua`) = reputação do grupo − dureza da personalidade → hostil / neutro / amigável.
- **Reputação por grupo (−100 a +100):** golpear −10 (o grupo fica com raiva), matar −40, invadir base territorial depois do aviso −10, ser visto mexendo no estoque −15; matar um zumbi que caçava um membro +2, matar saqueador perto +3.
- **Milícia e seita são territoriais:** mandam você embora da base; se insistir, atacam. Saqueadores são hostis. Civis são amigáveis e medrosos. Errantes dependem da personalidade e mudam de acampamento.
- Só os seus **aliados** (seguidores) são protegidos dos seus golpes; ferir qualquer outro tem consequência.

### Safehouses (Fase 3)
Quando a casa de um grupo carrega perto de você (uma vez): janelas e portas externas **barricadas por dentro** (mais em milícia/seita e com engenheiro), porta principal **trancada**, **estoque real** nos armários coerente com o grupo (famílias: comida e remédio; milícia: armas e munição; saqueadores: itens roubados e drogas; seita: loot raro), o resto da casa vazio, **corpos de zumbis empilhados** na frente e **luz acesa à noite**. Moradores têm **papéis**: guarda na porta (posto do lado de dentro), cozinheiro na cozinha de dia, moradores **sentam** para descansar de dia e **dormem deitados** à noite. O **médico** cura companheiros (e faz curativo em você, se for seu aliado).

- **Saves antigos:** grupos sem o retângulo da casa recuperam o prédio pelo ID (ou pela posição) quando você chega perto. Ferramenta "Recriar grupos do mundo" troca os grupos de um save antigo por novos.
- **Casa que o jogo já barricou:** ao virar safehouse, os zumbis de dentro somem (os moradores limparam) e a porta principal perde as tábuas.
- **Entrada garantida:** a porta externa mais ao sul (de preferência sem tábuas) é a principal: fechada, **nunca barricada**; trancada para você, a menos que o grupo seja amigável. Sem porta externa, a janela mais ao sul fica sem tábuas. Moradores **destrancam, abrem, passam, fecham e trancam** de novo (`Rem_Safehouse.manageDoors`).
- **Saque real** (`Rem_Scavenge.lua`): o grupo sai quando a comida acaba **e de tempos em tempos** para aumentar o estoque. O guarda fica em casa. Em cena, os outros vão até o prédio, **abrem armários de verdade** (o loot é gerado como quando você abre), pegam comida, água, remédio e munição primeiro, carregam (salvo no save) e **guardam no estoque** ao voltar. Fora de cena o saque é abstrato e os itens aparecem no estoque quando a casa carrega.
- **Estoque vivo:** o grupo **come** do estoque (itens somem conforme os suprimentos caem); o que você leva do estoque **baixa os suprimentos** do grupo.
- **Sinais de vida** (`Rem_Signals.lua`): **placa** de madeira na frente ("TEMOS COMIDA. VENHA EM PAZ" nas famílias, "FICA LONGE. ATIRAMOS." na milícia, "ARREPENDA-SE" na seita, e às vezes "TEMOS COMIDA" como armadilha de saqueadores; você lê ao chegar perto), **poste com caveira** (saqueadores, seita), **barril de chuva** (o do jogo), **gerador** (milícia e seita, liga à noite com gente em casa) e **fogueira acesa no quintal** de dia (fogueira do jogo, contida).

### Atiradores (`Rem_Ranged.lua`)
Quem tem arma de fogo e munição saca, **mira e atira** (animação de pistola/rifle do jogador e o som real da arma). O tiro **faz barulho de verdade** (pistola 100, espingarda 200, rifle 170 tiles) e atrai zumbis; por isso amigos só atiram em zumbi quando vale o barulho (cercados, feridos, ou você já está brigando). Chance de acerto cai com a distância; espingarda dispara chumbos. Mantêm distância (recuam), usam a faca quando colados, avisam quando a munição acaba. Em você: **ferimento a bala** (bala alojada), sem infecção. Milícia e seita recarregam munição em casa.

### Interação (Fase E, `Rem_Interact.lua` + janelas em `client/Rem_DialogUI.lua`)
Clique direito num sobrevivente → **Conversar** (qualquer um que não seja hostil; rendidos também).
- **Janela de conversa:** retrato com o ícone da profissão sobre a cor da facção, nome, profissão, idade, arquétipo, facção (na cor da facção), atitude e uma barra de reputação; à direita, o histórico da conversa e as opções numeradas. O NPC também fala em voz alta (texto sobre a cabeça, desenhado pelo mod). A janela fecha se ele se afastar ou ficar hostil.
- **Falas com personalidade:** respostas e falas têm várias versões e mudam de tom (medroso gagueja e pede paz; durão é seco e ameaça), sem repetir a mesma frase em seguida.
- **Conversa:** a resposta muda com a atitude e a personalidade. "Como vão as coisas?" conta do que o grupo precisa (ferido, comida, munição). "Sabe de outros grupos?" diz a direção e a distância de um grupo que você ainda não conhece (só se confiarem em você: reputação 20+).
- **Troca** (janela com ícones, valor de cada item, o que o grupo está precisando, totais e saldo; clique para marcar): eles oferecem o **estoque real** da casa (ou o que a pessoa de passagem carrega). O valor depende da **necessidade** do grupo (com ferido, remédio vale o dobro; com fome, comida e água valem mais; sem munição, munição). Eles cobram uma margem que cai com a reputação. Troca justa sobe a reputação.
- **Abrigo:** reputação 50+ (ou 20+ e uma troca no mesmo dia) → você pode ficar uns dias: a porta fica aberta para você e a milícia não te expulsa.
- **Recrutar:** lealdade + reputação decidem (errantes e gente de passagem aceitam mais fácil; grupos pequenos seguram os seus). Quem aceita vira seu aliado. **Comandos de seguidor:** seguir, esperar, **guardar posição**, **saquear o prédio aqui perto** (abre os armários e traz para você), **liberar**.
- **Missões:** conforme a necessidade: trazer comida/água, remédio ou munição; **limpar os zumbis da rua** (mortes suas perto da casa contam); **achar alguém que sumiu** (ele espera longe; fale com ele e ele volta para casa). Recompensa: o melhor item do estoque, ou a localização de outro grupo; +15 de reputação.
- **Marcam no seu mapa** (`Rem_MapMarks.lua`, desenho em `client/Rem_MapMarksUI.lua`): ao revelar um grupo, dar uma missão com lugar ou te abrigar, o NPC diz "Deixa eu marcar no seu mapa" e o mapa do mundo ganha um **círculo na cor da facção** (verde família, azul milícia, vermelho saqueadores, roxo seita, amarelo errantes, laranja missão), o símbolo (casa, caveira, ?, alvo) e uma anotação escrita. Fica salvo; cada lugar é marcado uma vez; você pode apagar com a borracha do mapa.
- **Ameaçar** (com arma na mão): quem tem pouca coragem entrega o melhor que tem (reputação −30); quem tem coragem reage e o grupo te ataca.

### A sua base (`Rem_PlayerBase.lua`, 0.14.0)
A base é um grupo especial seu (aliados, `g.player = true`): usa a casa, o estoque, as portas, a luz à noite, a rotina, as refeições, o cérebro do grupo e os cercos, mas não é "preparada" como a casa de um NPC (sem tábuas prontas, placas ou loot) e não sai inteira para saquear.

| Tarefa | O que faz |
|---|---|
| Fortificar | Prega tábuas nas janelas abertas: 2 tábuas por janela, 2 janelas por dia por pessoa; precisa de material |
| Vigiar | Fica na porta principal (papel de guarda); +1 na defesa contra ataques |
| Buscar | De dia, a cada 5 h: revira um prédio a 12–90 tiles (em cena de verdade; longe de você, 2 a 5 itens e 0 a 2 de material, 15% de voltar ferido, metade da "Chance de morte num saque" de não voltar) |
| Descansar | Fica em casa; recupera vida 8%/h longe de você (os outros 3%) |

- **Estoque:** até 4 contêineres (geladeira, prateleiras e balcões primeiro). Comida/água no estoque = suprimentos (2 itens por pessoa-dia); eles comem e os itens somem. Tábua = 1 de material, prego = 1, caixa de pregos = 3: são tirados do estoque e viram material. Nada além de comida é removido.
- **Riscos:** 24 h sem comida = aviso; 72 h = um morador vai embora. Ataques de saqueadores somam `vigias × 1 + fração de janelas fechadas × 2` na defesa.
- **Limites:** 8 moradores na base, 4 aliados andando com você.

### Alianças, armas e especialidades (0.17.0)
- **Equipar** (`Rem_Gear.lua`): arma da sua mão → aliado (a dele volta para você); armas de fogo de `Rem_Ranged.GUNS` com até 2 caixas de munição (15 tiros cada).
- **Especialidades:** engenheiro ×1,5 nas obras; médico +5%/h de cura para cada ferido da base; furtivo na dupla: risco ÷ 2; atirador com munição +1 na defesa; brigão +0,4.
- **Alianças** (`Rem_Alliance.lua`): `reputação + vínculo × 0,5 ≥ 60`. Troca a preço justo; +1,5 de defesa por grupo aliado a até 500 tiles; às 10 h, quem tem mais de 4 suprimentos por pessoa manda 3 itens de comida; acaba com reputação < 20.
- **Ataques à sua base:** bando de saqueadores a até 400 tiles, 1%/h, a cada 72 h no máximo. Longe: ataque = `min(4, tamanho) × 1,5 + 0–2` contra a defesa da base.

### Os primeiros dias: gerador, perímetro, militares, rádio, raros (0.22.0)
- **Gasolina** (`Rem_Fuel.lua`): o gerador da base liga das 19 h às 6 h com gasolina (estoque até 200; tanque 100). Longe de você gasta 1,5/h ligado; em cena, o gerador de verdade gasta e o estoque acompanha. Luz: +1 de defesa e +1 de moral/h à noite. Tarefa nova "buscar gasolina" (dupla; 10–25 por saída fora de cena, 4–9 por carro sifonado em cena).
- **Perímetro** (`Rem_Traps.lua`): obras novas "latas de alarme" (até 8; com 4+, alarme +4 tiles e, sem vigia, defesa ×0,85 em vez de ×0,6) e "estacas" (até 10; seguram 0,4 zumbi da horda cada, até 4, e se gastam; em cena, zumbi no anel entre a casa e a cerca: 35% de cair, 1,2 de dano).
- **Militares** (`Rem_Military.lua`): facção nova "militares". Nos dias 0–4, uma barreira a 45–80 tiles (mapa) com 3 soldados atiradores que mandam você se afastar. No dia 5 somem; ao chegar, 3–6 zumbis de farda e 6 itens no chão.
- **Rádio** (`Rem_Radio.lua`): com qualquer item "Radio"/"WalkieTalkie" no inventário, a cada 3 h (60%): militar (até o dia 6; chiado depois do 12), socorro, saqueadores, rumores (caravanas, guerras) e conversa. Grupos citados vão para o mapa.
- **Eventos raros** (`Rem_RareEvents.lua`): uma vez por campanha, 6% ao dia: médico pede abrigo (dia 3+), comboio militar abandonado (dia 6+; carros queimados, zumbis, 8 itens), convite da seita (dia 8+; +10 de reputação).

### Fama, política e cicatrizes da alma (0.21.0)
- **Fama** (`Rem_Fame.lua`): apelidos por feitos: salvar 5 pessoas, matar 8 saqueadores, matar 2 inocentes, 4 missões, 8 trocas, 3 ameaças, 2 caravanas defendidas, 5 moradores. Cada apelido muda a atitude inicial de quem te conhece (ex.: salvador +12; quem mata gente −25, saqueadores +10; caçador −20 com saqueadores, que se rendem com 45% de vida em vez de 30%). Quem nunca te viu comenta a sua fama uma vez.
- **Traumas** (`Rem_Traumas.lua`): pânico (40% ao perder um amigo; coragem ×0,6), medo do escuro (20% ao se ferir de noite; vigia noturno: +25% de cochilo e −2 de moral/h), bebida (8% já chegam com o vício, 15% no luto; às 21 h: moral +8, cansaço +25, −0,5 de comida; vigia: +15% de cochilo). Nível 3 → 0: conversa diária com vínculo ≥ 10, ou dias com moral ≥ 70 (30%).
- **Missões pessoais** (`Rem_PersonalQuests.lua`): família (parente vivo num grupo a 150–1000 tiles), horta (qualquer item com "Seed"; +1 suprimento por dia a partir do 7º dia), lugar ao norte (350 tiles; esconderijo com 4 itens).
- **Conselho** (`Rem_Council.lua`): a partir de 4 moradores, votam em recém-chegados, prisioneiros, guerra e tributo. Maioria a favor: moral +2 para todos; contra: −6 para quem votou contra.
- **Sua facção** (`Rem_Diplomacy.lua`): nome do grupo (caixa de texto); pacto de respeito (reputação ≥ 0; relação +30; acaba com reputação < −20); tributo a saqueadores (4 suprimentos = 7 dias sem ataques).

### Mundo em movimento: território, guerra, refugiados, caravanas (0.20.0)
- **Território** (`Rem_Territory.lua`): raio = 25 + 6 por pessoa (+10 com cerca). Entrar mostra "Território de X (facção)" e o grupo fica conhecido. Encontros com saqueadores na rua ×3 no território deles e ×0,3 no de quem os combate.
- **Preços por região:** cada grupo a mais a até 300 tiles soma 12% em comida e remédio (até 60%); em guerra, munição ×1,6 e remédio ×1,4; milícia paga ×1,3 por munição, seita ×1,3 por remédio, famílias ×1,2 por comida, saqueadores ×1,2 por munição e armas.
- **Guerra** (`Rem_War.lua`): grupos com casa, 3+ pessoas, até 400 tiles e relação ≤ −80 entram em guerra (verificado por dia). De dia, cada lado ataca o outro (6%/h). "[Guerra] Estou do lado de vocês.": +15 com eles, −25 com o inimigo; +5 por inimigo deles que você mata; +20 se o seu lado vencer. Trégua depois de 6 dias sem ataques com a relação acima de −40 (+4 por dia sem ataque).
- **Refugiados** (`Rem_Refugees.lua`): 40% de cada morador escapa quando a base cai; grupo com até 2 pessoas que perde um ataque se desfaz. Vão para o grupo amigo mais perto com lugar (até 700 tiles, 120 tiles/h) ou para a sua base se a reputação com o grupo antigo era ≥ 20 (ou eram aliados). Na sua base, ficam se houver lugar e 1 dia de comida por pessoa. Em cena: "[Refugiado] Venha para a nossa base."
- **Caravanas** (`Rem_Caravans.lua`): por dia, grupo com mais de 3 suprimentos por pessoa (35%) manda 3 suprimentos para um grupo amigo (relação ≥ 20, 60–450 tiles) ou para a sua base, se aliados. 150 tiles/h; saqueadores inimigos a até 250 tiles: emboscada 3%/h. Perto de você (45 tiles), a dupla aparece com 4 itens nos bolsos; 30% de emboscada em cena; defender rende +12 de reputação.

### Pessoas com história: habilidades, laços, cicatrizes (0.19.0)
- **Habilidades** (`Rem_Skills.lua`): carpintaria, coleta, vigia e medicina, nível 0–5 (experiência 4/12/25/45/70). Fortificar de dia +0,5/h; no posto +0,4/h; enfermaria +0,5/h com ferido (0,1 sem); cada saída +3 para os dois. Efeitos por nível: obras +10%; saída +0,5 item e risco ÷ (1 + 0,15 × nível); vigia −6% de cochilo e +1 tile de alarme; medicina cura e sara ferimentos mais rápido. Atirador começa com vigia 1.
- **Relações** (`Rem_Friends.lua`): de −100 a 100 entre cada par. Saída juntos +6, conversa +2, briga −10, por dia morando juntos +2 (ou −2 com agressividade muito diferente). Amigos (≥ 30) saem juntos e correm 20% menos risco; a morte de um amigo pesa mais (luto 48 h, moral −15 a mais). Rivais (≤ −30) não saem juntos se houver outro e brigam mais.
- **Ferimentos** (`Rem_Wounds.lua`): perna (72 h: só anda, não sai para buscar), braço (48 h: dano ×0,7, obras ×0,5), corte (24 h: não recupera vida, moral −1/h). Vêm de golpes fortes (≥ 30% da vida, 30%), saídas que dão errado e hordas. **Enfermaria**: nova tarefa "Cuida dos feridos"; com ela (ou um médico) na base, cada hora sara uma hora a mais (+25% por nível de medicina); descansando, +0,5.
- **Revistar corpos** (`Rem_Spoils.lua`): hostil morto perto de você → quem segue você revista (3,5 s) quando a briga acaba: munição da própria arma vai para o pente; armas, munição, comida e remédio vêm para o seu inventário.
- **Crônica** (`Rem_Chronicle.lua`): 16 marcos únicos (primeira noite, primeiro aliado, base, cerca pronta, primeiro alarme, primeiro adeus, primeiro prisioneiro, aliança, amizade, horda repelida, uma semana, um mês...) aparecem na tela e na seção Crônica do Diário. `Rem.Chronicle.unlock(chave)` para outros mods.

### Vida no grupo: necessidades, vigia, combate, prisioneiros (0.18.0)
- **Necessidades** (`Rem_Needs.lua`): fome e cansaço de 0 a 100 para quem segue você e quem mora na base. Fome +3/h (morador com comida no estoque: −6/h); cansaço +2,5/h acordado, +1,5 trabalhando pesado, +3 de vigia, −12/h dormindo. Quem segue você come dos bolsos a partir de 50 e pede comida a partir de 60; "[Comida] Toma, come isto." usa a primeira comida da sua mochila (−55 de fome, vínculo +4). "[Descanso] Tira um cochilo." deita ali por 4 h. Fome ≥ 80 ou cansaço ≥ 80: dano ×0,85 / ×0,8 e −10 de pontaria cada. Fome ≥ 90 com moral ≤ 10: vai embora.
- **Vigia** (`Rem_Watch.lua`): a noite tem 3 turnos (21–24, 0–3, 3–6) e os vigias revezam; o de folga dorme. Vigia com cansaço ≥ 90 pode cochilar no posto (35%/h). Em cena, o vigia dá **alarme** quando vê zumbis ou hostis a até 10 tiles das paredes: todos acordam e vão para a porta. Longe: noite coberta = defesa +2; sem vigia acordado = defesa ×0,6. O ladrão só é espantado por vigia acordado.
- **Ordens de combate** (`Rem_Orders.lua`): segurar fogo (só se defende colado, não atira), atacar à vontade (vai atrás de todo zumbi a vista, coleira 2×), lutar do seu jeito, recuar para a base (corre para lá sem parar para brigar e fica esperando). Pela conversa ou para todos no clique direito. **Alvo marcado**: clique direito num zumbi ou num hostil → "Aliados: ataquem este!" (20 s).
- **Prisioneiros** (`Rem_Prisoners.lua`): quem se rendeu pode ser levado ("Você vem comigo."), preso na base, interrogado (chance 20% + 15% por tentativa − 3% por ponto de coragem; arma na mão +15%, fome +10%; a cada 6 h), resgatado pelo bando (5 itens), recrutado (48 h preso e moral ≥ 45) ou solto (bando +8 de reputação). Quem fala marca o bando no mapa e, se eles planejavam atacar, o ataque atrasa 3 dias. Preso come do estoque; sem vigia acordado e sem comida pode fugir e contar ao bando onde fica a base.
- **Painel da base** (`Rem_BasePanel.lua`): clique direito → "Painel da base". Estoque, material, defesa, moral, obra atual, escala de vigia da noite, prisioneiros; um botão por morador (clicar troca a tarefa, mesmo com ele longe).
- **Para outros mods:** `Rem.registerTargetOption(chave, fn(zumbi, jogador), condicao)` adiciona opções sobre o zumbi clicado.

### Bases das facções (`Rem_GroupLife.lua`, 0.16.0)
| Facção | Obras |
|---|---|
| Sua base | janelas, portas, reforço, cerca, arame farpado, barril, carros, gerador |
| Famílias | janelas, portas, reforço, cerca, barril |
| Milícia | todas |
| Saqueadores | janelas, portas, arame farpado, carros |
| Seita | janelas, portas, reforço, cerca, barril |
| Errantes | nenhuma |

- **Mestre de obras (por hora):** guarda = o papel de guarda; com material < 6 e obra por fazer, uma dupla em "buscar material"; com material ≥ 2, metade dos outros fortifica; o resto descansa.
- **Defesa:** `obras = janelas × 2 + cerca × 3 + arame × 1 + carros × 0,5 (até 2)`. Soma na defesa contra ataques de saqueadores e reduz a chance diária de cair para uma horda (até 90% menos).
- **Hordas nos NPCs:** 1% por hora de noite (a cada 48 h no máximo), só longe de você.
- **Sandbox:** "Obras dos grupos (porcentagem)".
- **Extensão:** `Rem.BaseBuild.registerProject("nome", { cost = 1, after = "perimeter", factions = { civis = true }, plan = function(g, h) return { { x, y, z, left = 1 } } end, apply = function(g, h, t) return true end })`; `Rem.registerFaction("nome", { ..., base = { projects = { "windows", "perimeter" } } })`.

### Base viva (`Rem_BaseBuild.lua`, `Rem_BaseEvents.lua`, 0.15.0)
**Fila de obras:** janelas (2 tábuas) → portas dos fundos (2) → reforço até 4 → cerca de madeira a 3 tiles das paredes, com passagem de 3 tiles na frente da porta principal (sprites `carpentry_02_40/41`, vida 250) → até 4 carros queimados a 4 tiles além da cerca (`addVehicleDebug`, modelos `*Burnt`). Passo: 6 s; custo: tábua 1, cerca 2, carro 0 (4 passos). 8 passos por dia por pessoa fortificando; longe de você, ⌈8/12⌉ por hora de dia por pessoa.

**Saídas:** tarefas "buscar suprimentos" e "buscar material", sempre em dupla (mesma tarefa, ou alguém descansando). Fora de cena: suprimentos 2–5 itens (+2 em dupla) e 0–2 de material; material 3–7. Risco de morte: "Chance de morte num saque" ÷ 2 sozinho, ÷ 4 em dupla.

| Evento | Quando | Efeito |
|---|---|---|
| Horda | Noite, 3%/h, no máximo a cada 36 h | Com você: 4–12 zumbis do lado de fora da cerca. Longe: defesa (vigia 1,5; morador 0,6; janelas 3; cerca 5; carro 0,5) × 2 ≥ horda aguenta (0–2 pedaços de cerca caem); senão 3–6 caem e alguém se fere, ou morre se a defesa < horda/3 |
| Visitante | Dia, 3%/h, a cada 30 h | Com você: no portão, aceite na conversa. Longe: fica se houver 2 dias de comida e lugar |
| Briga | Moral médio < 30, 6%/h | Moral −6 dos dois; com moral ≤ 12, alguém vai embora |
| Ladrão | Noite, 2%/h | Sem vigia: leva 25% da comida; com vigia: espantado |
| Festa | Obra terminada | Moral +10 de todos |

### O cérebro do grupo (`Rem_Director.lua`, 0.11.0)
Cada grupo com casa mede três necessidades de 0 a 1 e escolhe um objetivo, que aparece no que os moradores fazem, no que respondem e nas missões que pedem.

| Objetivo | Quando | O que você vê |
|---|---|---|
| Esconder | Mais zumbis colados nas paredes (até 5 tiles) do que os defensores aguentam | Todos para dentro, agachados; "Shh. São muitos." |
| Limpar a rua | Zumbis em volta da casa (até 14 tiles) que eles aguentam. Muitos, mas longe das paredes: a vida segue | O guarda e o mais valente saem para matar |
| Cuidar dos feridos | Um terço ou mais do grupo ferido/infectado | Ficam em casa; o médico trabalha |
| Buscar suprimentos | Comida para menos de ~1 dia por pessoa, ou sem material para as janelas | Saem para saquear um prédio |
| Reforçar a casa | 25%+ das janelas abertas e material no estoque | Um morador prega tábuas: 2 por janela, até 3 janelas por dia. Longe de você também: as tábuas aparecem quando você voltar |
| Rotina | Nada urgente | Papéis, refeições, conversa |

- **Material** (tábuas e pregos): cada grupo começa com 2 a 6; cada saque traz 4; cada tábua gasta 1. Sem material eles pedem a missão "trazer tábuas e pregos".
- **Primeiros dias:** no dia 0 as casas nascem com só 15% das tábuas de antes; a fortificação inicial cresce até o dia 6. O resto é trabalho que acontece na sua frente.

### Lutar ou fugir (`Rem_Tactics.lua`, 0.11.0)
`aguenta = força × nervo × 2 zumbis`. Força: ele (1) + 0,7 por amigo a até 7 tiles + 1 por você, se for seu amigo. Nervo: temperamento (medroso 0,8; cauteloso 1,1; defensivo 1,2; agressivo 1,6) × (0,4 + coragem/10) × vida × moral × experiência, × 1,3 defendendo a casa. Perigo: zumbis em volta ou atrás dele; cada humano hostil vale 2. Foge se o perigo passa do que aguenta; quem fugiu só volta com folga de 30%. Também vão ajudar um companheiro que está sendo atacado a até 7 tiles. Civis agora têm coragem de 1 a 8 (antes 0 a 4); com 6+ deixam de ser "medrosos".

### Zumbis × sobreviventes (0.11.0)
- Um zumbi atrás de você troca para um sobrevivente que esteja a até 8 tiles dele e a menos de 75% da distância até você (antes: só colado, a 3 tiles).
- Todo barulho de sobrevivente (golpe, tiro, corrida, martelo) faz 70% dos zumbis livres a até 14 tiles irem atrás **dele**.
- Campo de visão dos zumbis contra sobreviventes mais largo; lembram do alvo por 20 s.

### Conversa com consequência e Diário (0.11.0)
- Depois de cada escolha a conversa mostra, entre colchetes, o que mudou: reputação com o grupo, vínculo com a pessoa, lugar marcado no mapa. Pedido recusado mostra o que falta ("reputação 5; precisa de 20").
- "Como vão as coisas?" responde o que o grupo está fazendo agora.
- **Pedir ajuda:** com vínculo 25+ (ou reputação 50+) a pessoa te dá comida, ou remédio se você estiver ferido; uma vez por dia, e custa 5 de vínculo.
- **Diário** (clique direito → Primeiros Dias → Diário, sempre disponível): dia do colapso, seus aliados (nível e humor), grupos conhecidos (reputação, quantos são, o que estão fazendo, distância e direção), pedidos em aberto e os últimos acontecimentos. Acontecimentos novos também aparecem como aviso na tela.

### Usabilidade (0.12.0)
- **Portas** (`Rem_Doors.lua`): o corpo dos sobreviventes é um zumbi e zumbi não abre porta. Quem quer andar e não sai do lugar abre a porta fechada à frente (trancada só por dentro; com tábuas, nunca) e fecha as externas depois de passar. Travado sem porta por 4 s: um passo para o lado.
- **Companheiros** (`Rem_Companion.lua`): aliado a mais de 30 tiles por 7 s reaparece a 5–9 tiles de você; ordens para todos no clique direito; ordens na conversa.
- **Bolsos:** cada pessoa leva 1 a 3 itens comuns mais um do arquétipo (médico: remédio; atirador: munição...). Entram na troca, no "pedir ajuda" e no que ela entrega sob ameaça.
- **Recrutar:** `disposição = lealdade×4 + confiança×2 + reputação×0,4 + vínculo×1,5`, +15 se está sozinha no mundo, +25 se você acabou de libertá-la, −25 se tem casa, −30 se o grupo ficaria com 1–2. Aceita com 95+. Máximo de 4 aliados.
- **Pânico** (`client/Rem_Calm.lua`): desfaz o susto que o jogo aplica quando um sobrevivente amigo entra na conta de "zumbis visíveis".
- **Mapa:** símbolo 0,5, círculo 0,95, anotação 0,36 (um símbolo normal do jogo é 0,666), independentes da escala global.

### Vida dos personagens (0.10.0)
- **Jeito, história e humor** (`Rem_Persona.lua`): cada pessoa tem um jeito (falante, ranzinza, otimista, de fé, piadista, de poucas palavras, sempre em alerta), uma história (quem perdeu, o que quer) e um humor que sai do estado real dela: com dor, passando mal, de luto, com fome, de bom humor, sem ânimo, em paz. O moral (0–100) sobe com casa abastecida, refeições e zumbis mortos; cai com fome e mortes. Quando alguém morre, o grupo dele sente: falam o nome na hora e ficam de luto por 24 h.
- **Vínculo e memória** (`Rem_Bonds.lua`): além da reputação com o grupo, cada pessoa tem um vínculo com você (−100 a 100) e lembra dos últimos feitos. Tabela: salvou dos zumbis +10, presente +4 a +15, troca +3, missão +8 (metade para o resto do grupo), contou a história +3, recrutado +20, libertado +25, casa defendida +12, golpe −25, ameaça −30. O vínculo entra na atitude (peso 0,6), no recrutamento e nos cumprimentos.
- **Experiência:** 3, 8, 15, 25 e 40 zumbis mortos dão os níveis 1 a 5; cada nível vale +8% de dano e +4 pontos de pontaria contra zumbis e outros NPCs.
- **Conversas** (`Rem_Banter.lua`): a cada ~9 s há 40% de chance de dois sobreviventes parados (a até 5 tiles um do outro e 16 de você) conversarem. Comentários de contexto: noite (21 h), amanhecer (6 h), chuva, você com saúde abaixo de 50%, 12+ zumbis a 20 tiles, 4 zumbis mortos por você em 20 s, arma apontada para um neutro.
- **Rotina** (`Rem_Routine.lua`): almoço (12–13 h) e jantar (19–20 h) na cozinha, se houver comida.

### Histórias (`Rem_Stories.lua`)
- **Mascate** (a partir do dia 1): para a até 7 tiles de você por 90 s; Conversar → Quero trocar.
- **Alguém de luto:** fica sentado por alguns minutos.
- **Emboscada** (só depois do dia dos saqueadores, fora da zona de graça): a pista é não haver zumbis em volta do "ferido". Chegar a 5 tiles ou feri-lo revela todos; segue o assalto normal.
- **Refém:** fica livre quando não há captor a 30 tiles (mortos, rendidos ou em fuga). Se você estiver a até 12 tiles: +25 de vínculo, +8 com os civis, e ele espera 75 s para você chamá-lo.
- **Cerco:** grupos conhecidos (marcados no mapa ou revelados), com reputação 15+, entre 60 e 450 tiles de você; 3% de chance por hora, no máximo um por vez e um a cada 48 h. Prazo de 10 h. A horda (8 a 14) aparece em volta da casa quando você chega a 45 tiles; vencido quando sobra no máximo 1 zumbi a 16 tiles: +20 de reputação e vínculo com todos. Sem ajuda: 1 ou 2 mortos, ou a casa cai, se o grupo já era pequeno.

### Mundo persistente (Fase D)
- **Regiões** (`Rem_Regions.lua`): o mapa é dividido em regiões de 300×300 tiles. Quando você chega perto de uma região nova, ela ganha grupos pelo número de prédios (cidade: vários; campo: às vezes um errante), até o máximo do sandbox. O mundo todo fica povoado conforme você explora.
- **Viagens em passos:** fora de cena os grupos andam a cada 10 min de jogo (300 tiles/h), então dá para cruzar com eles no caminho.
- **Bases que evoluem** (`Rem_Evolution.lua`, uma vez por dia): fortificam aos poucos (engenheiro acelera; você vê as tábuas novas quando volta); podem **cair para uma horda** (grupos pequenos e pouco fortificados caem mais): os moradores viram zumbis e a casa vira **ninho**, com estoque e barricadas intactos; grupos com fartura **recrutam errantes**; saqueadores que acabam com um grupo **tomam a base** dele.
- **Relações entre grupos** (`Rem_Relations.lua`): de -100 a +100 por par. Ataques criam rixas (com a vítima e os aliados dela); aliados por perto ajudam a defender; grupos amigos dividem suprimentos; milícias fortes fazem expedições punitivas contra saqueadores; o que você faz com um grupo chega aos aliados dele pela metade.

### Dia Zero (Fase C)
- **Linha do tempo** (`Rem_Timeline.lua`): o apocalipse começa no dia 0 (mais os "Meses desde o apocalipse" do sandbox do jogo), no ritmo do sandbox "Ritmo do colapso". **Dias 0–3:** caos civil, milícias se formando, **nenhum saqueador organizado** (até o "Dia em que os saqueadores começam", padrão 4). Depois os saqueadores crescem aos poucos, novos grupos deles se formam e as ruas vão esvaziando.
- **Zona de graça:** nos 3 primeiros dias nada hostil nasce a menos de 150 tiles de onde você começou.
- **Gente de passagem** (`Rem_Ambient.lua`): nascem fora da sua vista, cruzam a área e somem (não ficam no save): civil andando, **civil fugindo com zumbis atrás**, família, **ferido pedindo socorro** (salvá-lo sobe a reputação com os civis), alguém batendo numa porta, alguém **pregando tábuas** numa janela (barricada de verdade), **briga por comida**, catadores com suprimentos, saqueadores rondando (só depois do dia deles) e **tiros ao longe** que atraem zumbis para lá. Mais gente nos primeiros dias e na cidade; sandbox "Gente na rua".
- **Mordidos viram zumbis** (`Rem_Infection.lua`): cada acerto de zumbi pode infectar (padrão 25%); o infectado avisa, passa mal e vira zumbi de 2 a 12 h depois, com a mesma roupa. Morto por zumbis, o corpo levanta. Sandbox liga/desliga.

### Percepção e perseguição (Fase A, `Rem_Awareness.lua`)
- **Visão:** alcance pela luz (à noite cai para ~35%), pela sua postura (agachado 50%, parado 80%, correndo 130%) e pelo campo de visão (de lado, metade; de costas, só colado). Se a checagem de visão falhar, o NPC **não** vê.
- **Atenção gradual:** te notar leva tempo (mais rápido de perto). Estados: desconfiado ("Tem alguém aí?") → perseguindo → procurando no último ponto ("Cadê você?") → desiste ("Sumiu. Deixa pra lá.").
- **Audição:** tiros, gritos e vidro quebrando (`OnWorldSound`) fazem hostis investigarem o ponto do som.
- **Fôlego:** correr cansa (10 a 25 s, conforme a idade); ferido, manca. **Coleira:** longe de casa (45 tiles; saqueadores 70), desiste e volta.

### Combate justo (Fase B)
- **Dano calibrado** (golpe de facão: no máximo 24, antes 54). A **roupa protege** (defesa do jogo por parte do corpo; bloqueou = só hematoma). Golpe em você com mais preparação e intervalo. **Dificuldade** no sandbox (Fácil/Normal/Difícil).
- **Vida por arquétipo e roupa:** brigão 100%, atirador 85%, médico/furtivo 75%; farda/colete +25%.
- **Tiro disciplinado:** munição finita (só repõe com caixas do estoque de casa), **aviso antes do primeiro tiro** em você ("Parado!", 2,5 s para reagir), alcance contra você de 10 (pistola) / 16 (rifle) tiles e menor no escuro, precisão pelo arquétipo, pior se você corre e no escuro, não atira com aliado na frente, não atira em você com 4+ zumbis por perto (a menos que esteja desesperado), pente e recarga, no máximo 2 atiradores do grupo em você.
- **Assalto** (`Rem_Mugging.lua`): saqueadores exigem a mochila e a arma; obedecer ou ir embora evita a briga (eles pegam o que você largou e vão embora); reagir ou enrolar vira briga. Líder morto ou metade do grupo morto → o resto **foge**; ferido e encurralado se **rende**.
- **Corpo humano** (`Rem_Body.lua`): não vira rastejante; gemido de zumbi cortado.

### Combate real
- **Zumbi → NPC:** o zumbi recebe `setTarget(npc)` e usa a IA de ataque inteira. Zumbis têm `bodyDamage == null`, e o acerto do `AttackState` chamaria `getBodyDamage().AddRandomDamageFromZombie()`. Esse trecho só roda se o atacante tiver dentes, então quem mira um NPC fica `setNoTeeth(true)` e o mod aplica o dano ao ler `getAttackOutcome() == "success"`. Se o alvo muda (ex.: para você), os dentes voltam no mesmo tick. `noTeeth` não é salvo.
- **Zumbi atrás de você → NPC:** se um sobrevivente estiver a até 3 tiles do zumbi e pelo menos 2 tiles mais perto que você, o zumbi troca para ele (ex.: saqueador brigando com você). Se voltar para você, os dentes voltam na hora, e ele não troca de novo por 4 s.
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
  Rem_Core.lua        config, log, dados persistentes, migracao da 0.2, Rem.module (CFG)
  Rem_Events.lua      barramento de eventos interno (Rem.on/off/emit)
  Rem_Registry.lua    registros: comportamentos do cerebro e opcoes de menu
  Rem_Commands.lua    opcoes padrao do menu (ordens e ferramentas de teste)
  Rem_Factions.lua    faccoes (Rem.registerFaction) e hostilidade
  Rem_Spawn.lua       pessoa, corpo, materializar/desmaterializar, re-associar, morte
  Rem_Movement.lua    postura, pathfind, hangAround/idle/flee, destino do grupo
  Rem_Brain.lua       loop e decisao de cada NPC em cena (combate + comportamentos)
  Rem_Behaviors.lua   comportamentos padrao: follow 100, stay 200, group 300, wander 900
  Rem_Combat.lua      golpes do NPC, dano em zumbi/NPC/jogador
  Rem_Perception.lua  visao/audicao dos zumbis, ataque real e simulado
  Rem_World.lua       grupos, semeadura, simulacao horaria fora de cena, saque
  Rem_Scene.lua       cena (dar/tirar corpo perto do jogador) e teleporte seguro
  Rem_Barks.lua       falas
  Rem_Profile.lua     ficha: identidade, profissao, arquetipo, personalidade, estado; seita e errantes
  Rem_Reputation.lua  reputacao por grupo, atitude, territorio, roubo, cumprimentos
  Rem_Safehouse.lua   barricadas, tranca, estoque, corpos, luz, portas, dentro de casa a noite
  Rem_Roles.lua       papeis dos moradores (guarda, cozinheiro, morador), sentar, medico
  Rem_Scavenge.lua    saque real (abrir armarios, carregar, guardar) e estoque vivo
  Rem_Ranged.lua      tiro dos atiradores
  Rem_Signals.lua     placa, caveira, barril de chuva, gerador, fogueira
  Rem_Awareness.lua   visao, atencao, audicao, memoria/procura, folego, coleira (Fase A)
  Rem_Mugging.lua     assalto, moral, rendicao (Fase B3)
  Rem_Body.lua        sem rastejar, sem gemido de zumbi (Fase B4)
  Rem_Timeline.lua    dia do apocalipse, saqueadores/milicias pelo tempo, zona de graca (C1-C2)
  Rem_Ambient.lua     gente de passagem e eventos de rua (C3, C5)
  Rem_Infection.lua   mordidos viram zumbis, corpos levantam (C4)
  Rem_Regions.lua     grupos por regiao conforme voce explora (D1)
  Rem_Evolution.lua   bases fortificam, caem para hordas, recrutam (D3)
  Rem_Relations.lua   relacoes, rixas, aliancas, troca, noticias (D4)
  Rem_Interact.lua    conversa, troca, abrigo, recrutar, comandos, missoes, ameacar (Fase E)
  Rem_MapMarks.lua    marcacoes no mapa do jogador (grupos, missoes, abrigo)
  Rem_Spatial.lua     indice espacial de zumbis (Rem.zombiesNear)
  Rem_Persona.lua     jeito, historia, humor, moral e luto
  Rem_Bonds.lua       vinculo pessoal, memoria e experiencia
  Rem_Banter.lua      conversas entre NPCs e comentarios de contexto
  Rem_Stories.lua     mascate, enlutado, emboscada, refem, cerco com mensageiro
  Rem_Routine.lua     hora de comer
  Rem_Tactics.lua     lutar ou fugir: forca x nervo contra o perigo
  Rem_Director.lua    cerebro do grupo: necessidades, objetivo, pregar tabuas, limpar, esconder
  Rem_Journal.lua     diario: acontecimentos de quem voce conhece
  Rem_Doors.lua       abrir portas quando trava; destravar
  Rem_Companion.lua   aliados: alcancar voce, ordens para todos e pela conversa
  Rem_Look.lua        aparencia humana: limpa o sangue depois das brigas, pele humana
  Rem_PlayerBase.lua  a sua base: moradores, tarefas, estoque, saidas em dupla, vida longe de voce
  Rem_BaseBuild.lua   obras da base: janelas, portas, reforco, cerca, carros queimados
  Rem_BaseEvents.lua  eventos da base: horda, visitante, briga, ladrao, festa
  Rem_GroupLife.lua   bases das faccoes: mestre de obras, duplas de material, hordas
  Rem_Gear.lua        dar arma e municao aos aliados
  Rem_Alliance.lua    aliancas com grupos: ajuda, comida, defesa
  Rem_Needs.lua       fome e cansaco dos aliados e moradores
  Rem_Watch.lua       escala de vigia da noite e alarme da base
  Rem_Orders.lua      ordens de combate e alvo marcado
  Rem_Prisoners.lua   prisioneiros: levar, prender, interrogar, resgate
  Rem_Skills.lua      habilidades que crescem com o trabalho
  Rem_Friends.lua     amizades e rivalidades entre moradores
  Rem_Wounds.lua      ferimentos que duram dias; enfermaria
  Rem_Spoils.lua      aliados revistam os corpos depois da briga
  Rem_Chronicle.lua   marcos da campanha (cronica no diario)
  Rem_Territory.lua   territorio das faccoes e precos por regiao
  Rem_War.lua         guerra entre faccoes; escolher um lado
  Rem_Refugees.lua    refugiados de bases que caem
  Rem_Caravans.lua    caravanas de troca entre grupos
  Rem_Fame.lua        fama do jogador (apelidos)
  Rem_Traumas.lua     traumas e vicios
  Rem_PersonalQuests.lua  missoes pessoais (familia, horta, lugar ao norte)
  Rem_Council.lua     conselho da base (votacoes)
  Rem_Diplomacy.lua   sua faccao: nome, pactos, tributo
  Rem_Fuel.lua        gasolina para o gerador da base
  Rem_Traps.lua       latas de alarme e estacas no perimetro
  Rem_Military.lua    a barreira militar dos primeiros dias
  Rem_Radio.lua       radio de pilha: transmissoes
  Rem_RareEvents.lua  eventos raros (medico, comboio, seita)
42/media/lua/client/Remanescentes/
  Rem_ContextMenu.lua monta o menu a partir dos registros
  Rem_Compat.lua      protecao do handler de pesca vanilla
  Rem_DialogUI.lua    janelas de conversa e de troca (Fase E)
  Rem_BasePanel.lua   painel da base (resumo, vigia, tarefas por morador)
  Rem_MapMarksUI.lua  desenha as marcacoes no mapa do mundo
  Rem_JournalUI.lua   janela do diario
  Rem_Calm.lua        o jogador nao entra em panico por causa dos amigos
  Rem_SpeechUI.lua    desenha as falas sobre a cabeca dos NPCs (Say nao funciona em zumbi)
42/media/lua/shared/Translate/{EN,PTBR}/*.json
tools/gen_animsets.sh
tests/run_tests.lua   ponto de entrada dos testes offline (lua5.1)
tests/mocks.lua       mocks da API do jogo e utilitarios de teste
tests/test_*.lua      testes por tema (carregados automaticamente, em ordem alfabetica)
tests/bench/bench.lua medicao de desempenho (lua5.1 tests/bench/bench.lua [zumbis])
```

## Extensao (para modulos novos)
- **Eventos:** `Rem.on("npcDied", function(npc) ... end)`, `Rem.off`, `Rem.emit`. Emitidos: `npcActivated`, `npcDeactivated`, `npcDied`, `personCreated(rec, opts)`, `personRemoved`, `groupCreated(g, def)`, `groupRemoved`, `worldHour(hour)`, `sceneUpdate(player, now)`, `worldSeeded(player)`.
- **Comportamentos:** `Rem.registerBehavior({ name = "comer", priority = 250, run = function(npc, ctx, now) ... return true end })`. Rodam depois do combate, em ordem de prioridade; `ctx = { enemy, dist, temper, player }`. Utilitarios: `Rem.hangAround`, `Rem.idle`, `Rem.flee`, `Rem.moveTo`, `Rem.groupGoal`, `Rem.travelGait`, `Rem.baseGait`.
- **Faccoes:** `Rem.registerFaction("nome", { hostileToPlayer, enemies, temper, outfits, groupNames })`.
- **Menu:** `Rem.registerDebugOption(chave, function(x, y, z, player) end, grupo)` (grupos: `spawn`, `world`, `ambient`, `reputation`, `other`) e `Rem.registerNpcOption(chave, function(npc) end, condicao)`.
- **Feitos do jogador:** `Rem.emit("playerDeed", tipo, npc, delta)` muda o vínculo e a memória (tipos em `Rem.Bonds.DELTA`); `Rem.on("npcKilledZombie", function(npc, zumbi) end)`.
- **Eventos de rua:** `AM.SPAWN.tipo = function(player, sq) return { npcs } end`, `AM.WEIGHTS.tipo = peso`, `AM.HANDLERS.tipo = function(npc, ctx, now) return true end`, `AM.WEIGHT_MOD.tipo = function(peso, x, y) return peso end`, `AM.registerDebugKind("tipo")`.
- **Falas pelo jeito/humor:** `Rem.barkVariant(npc, categoria, force)` devolve outra categoria, `nil` ou `false` (calado).
- **Zumbis por perto:** `Rem.zombiesNear(x, y, raio)` (índice espacial; não varra `getZombieList()` por NPC).
- **Falas:** `Rem.BARKS.categoria = { n = 3, cd = 5000 }` + chaves `IGUI_Rem_Bark_categoria_1..n`; versões `categoria_tough`/`categoria_scared` são usadas pelo tom da personalidade.
- **Ajustes:** `Rem.Brain.CFG`, `Rem.World.CFG`, `Rem.Scene.CFG`, `Rem.Perception.CFG`, `Rem.Combat.CFG`, `Rem.Barks.CFG`, `Rem.Spawn.CFG`.

## Testar
Veja [TESTING.md](TESTING.md).

## Roadmap
Segue o plano original do mod (cada fase jogável) e o [plano de refinamento](docs/PLANO_REFINAMENTO.md):

1. ✅ **Protótipo:** sobrevivente com roupa e arma que luta contra zumbis.
2. ✅ **Hostil/amigável:** personalidade, reputação, falas.
3. ✅ **Safehouses:** bases com entrada, estoque vivo, papéis, sinais de vida.
4. ✅ **Interação:** conversa, troca, abrigo, recrutamento, comandos, missões, ameaças, marcações no mapa.
5. ✅ **Mundo vivo:** regiões, viagens, bases que evoluem, relações entre grupos, Dia Zero, mordidos virando zumbis.
6. ✅ **Polimento (0.9.0):** desempenho, sandbox em abas, janelas novas, falas com personalidade. Falta a validação no jogo antes da 1.0.
7. ✅ **Vida (0.10.0):** jeito, história, humor, luto, vínculo e memória, presentes, experiência, conversas entre NPCs, mascate, emboscada, refém, cerco. Falta validar no jogo.
8. ✅ **Primeiros Dias (0.11.0):** grupos que decidem (necessidades e objetivos), lutar ou fugir por pessoa, zumbis que caçam sobreviventes, conversa com consequências, diário. Falta validar no jogo.

Ideias para depois da 1.0: rádio, ataques à sua base, caravanas, emboscadas na estrada, multiplayer.
