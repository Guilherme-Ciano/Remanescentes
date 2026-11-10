# Remanescentes

Mod de Project Zomboid (Build 42.20+, **single player**) que povoa o mundo com sobreviventes humanos: grupos que moram em prédios reais, saem para saquear, passam fome, brigam entre facções e lutam contra os zumbis (e contra você, se forem saqueadores).

**Versão 0.9.0** (candidata a lançamento). Histórico em [CHANGELOG.md](CHANGELOG.md).

## Destaques
- **Gente de verdade no apocalipse:** famílias, milícias, saqueadores, uma seita e errantes, cada um com nome, idade, profissão, personalidade e roupa coerente.
- **Safehouses vivas:** casas barricadas por dentro, porta que os moradores abrem e trancam, estoque real nos armários, guarda, cozinheiro, gente dormindo à noite, placas, fogueira e gerador.
- **Saques de verdade:** os grupos saem, abrem armários e trazem o que acharam; o estoque enche e esvazia.
- **Combate justo:** eles te veem pela luz e pela postura, procuram, cansam e desistem; atiradores avisam antes de atirar e têm munição contada; saqueadores assaltam antes de brigar e fogem quando o líder cai.
- **Dia Zero:** os primeiros dias são de caos civil (gente fugindo, pedindo socorro, pregando tábuas); os saqueadores crescem com o tempo; mordidos viram zumbis.
- **Mundo persistente:** grupos pelo mapa todo conforme você explora, bases que fortificam, caem para hordas ou são tomadas, rixas e alianças entre grupos.
- **Interação:** conversa com retrato 3D, troca com valores pela necessidade do grupo, abrigo, recrutamento, comandos de seguidor, missões, ameaças, e marcações coloridas no seu mapa.

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
- **Janela de conversa:** retrato 3D do NPC com a roupa dele, nome, profissão, idade, arquétipo, facção (na cor da facção), atitude e uma barra de reputação; à direita, o histórico da conversa e as opções numeradas. O NPC também fala em voz alta (texto sobre a cabeça). A janela fecha se ele se afastar ou ficar hostil.
- **Falas com personalidade:** respostas e falas têm várias versões e mudam de tom (medroso gagueja e pede paz; durão é seco e ameaça), sem repetir a mesma frase em seguida.
- **Conversa:** a resposta muda com a atitude e a personalidade. "Como vão as coisas?" conta do que o grupo precisa (ferido, comida, munição). "Sabe de outros grupos?" diz a direção e a distância de um grupo que você ainda não conhece (só se confiarem em você: reputação 20+).
- **Troca** (janela com ícones, valor de cada item, o que o grupo está precisando, totais e saldo; clique para marcar): eles oferecem o **estoque real** da casa (ou o que a pessoa de passagem carrega). O valor depende da **necessidade** do grupo (com ferido, remédio vale o dobro; com fome, comida e água valem mais; sem munição, munição). Eles cobram uma margem que cai com a reputação. Troca justa sobe a reputação.
- **Abrigo:** reputação 50+ (ou 20+ e uma troca no mesmo dia) → você pode ficar uns dias: a porta fica aberta para você e a milícia não te expulsa.
- **Recrutar:** lealdade + reputação decidem (errantes e gente de passagem aceitam mais fácil; grupos pequenos seguram os seus). Quem aceita vira seu aliado. **Comandos de seguidor:** seguir, esperar, **guardar posição**, **saquear o prédio aqui perto** (abre os armários e traz para você), **liberar**.
- **Missões:** conforme a necessidade: trazer comida/água, remédio ou munição; **limpar os zumbis da rua** (mortes suas perto da casa contam); **achar alguém que sumiu** (ele espera longe; fale com ele e ele volta para casa). Recompensa: o melhor item do estoque, ou a localização de outro grupo; +15 de reputação.
- **Marcam no seu mapa** (`Rem_MapMarks.lua`, desenho em `client/Rem_MapMarksUI.lua`): ao revelar um grupo, dar uma missão com lugar ou te abrigar, o NPC diz "Deixa eu marcar no seu mapa" e o mapa do mundo ganha um **círculo na cor da facção** (verde família, azul milícia, vermelho saqueadores, roxo seita, amarelo errantes, laranja missão), o símbolo (casa, caveira, ?, alvo) e uma anotação escrita. Fica salvo; cada lugar é marcado uma vez; você pode apagar com a borracha do mapa.
- **Ameaçar** (com arma na mão): quem tem pouca coragem entrega o melhor que tem (reputação −30); quem tem coragem reage e o grupo te ataca.

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
42/media/lua/client/Remanescentes/
  Rem_ContextMenu.lua monta o menu a partir dos registros
  Rem_Compat.lua      protecao do handler de pesca vanilla
  Rem_DialogUI.lua    janelas de conversa e de troca (Fase E)
  Rem_MapMarksUI.lua  desenha as marcacoes no mapa do mundo
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

Ideias para depois da 1.0: rádio, ataques à sua base, caravanas, emboscadas na estrada, multiplayer.
