# Changelog

Todas as versões do Remanescentes. Datas no formato do commit; "falta validar" = testado offline, ainda não confirmado dentro do jogo.

## 0.22.0: os primeiros dias (gerador, perímetro, militares, rádio, eventos raros)
- **Gasolina para o gerador** (`Rem_Fuel`): o gerador da base agora gasta combustível. À noite os moradores ligam (a casa acende de verdade com você lá) e de dia desligam. Luz dá defesa e moral, e alivia quem tem medo do escuro. Tarefa nova: "[Base] Busca gasolina para o gerador." (em dupla). Quando a gasolina acaba, o Diário avisa.
- **Latas de alarme e estacas** (`Rem_Traps`): duas obras novas no perímetro.
  - As latas fazem o vigia perceber de mais longe e, mesmo sem vigia acordado, a base não é tão pega de surpresa.
  - As estacas derrubam zumbis que entram entre a cerca e a casa, e longe de você seguram parte da horda.
  - A milícia também faz as duas; os saqueadores fazem estacas.
- **Os militares dos primeiros dias** (`Rem_Military`): nova facção.
  - Nos primeiros dias, uma barreira de quarentena perto de onde você começou (no mapa), com soldados armados que mandam você se afastar e só dão notícias oficiais.
  - No dia 5 eles somem sem explicação, e a barreira fica para trás com soldados que viraram zumbis e a carga no chão.
- **Rádio de pilha** (`Rem_Radio`): com um rádio no inventário, de tempos em tempos você pega uma transmissão:
  - avisos militares, até virarem só chiado;
  - pedidos de socorro e saqueadores se gabando (os dois revelam onde os grupos estão);
  - rumores de caravanas e guerras;
  - gente comum falando.
- **Eventos raros** (`Rem_RareEvents`), uma vez por campanha cada:
  - um médico de verdade pedindo abrigo na base;
  - um comboio militar abandonado, com carros queimados, zumbis de farda e carga;
  - um convite da seita.
- **Crônica:** três marcos novos (a barreira abandonada, o comboio perdido, um médico na base).
- Ferramentas de teste: os três eventos raros.

## 0.21.0: fama, política e cicatrizes
- **Fama** (`Rem_Fame`): o que você faz vira apelido ("quem salva gente", "o terror dos saqueadores", "quem mata gente", "o bom vizinho"...). Quem nunca te viu já chega sabendo, e a primeira impressão muda. Saqueadores se rendem mais cedo para o terror deles. O Diário diz o que falam de você.
- **Sua facção** (`Rem_Diplomacy`):
  - Dê um nome ao seu grupo (clique direito ou painel da base).
  - Feche **pactos de respeito** com grupos que confiam em você: eles nunca atacam a sua base.
  - Pague **tributo** a um bando de saqueadores pelo rendido ou prisioneiro: dias de paz, e depois eles voltam a cobrar.
- **Conselho da base** (`Rem_Council`): com 4 moradores ou mais, quem chega, prisioneiros, guerra e tributo vão a votação. Você decide no fim, mas contrariar a maioria pesa no moral. O painel mostra a última votação.
- **Missões pessoais** (`Rem_PersonalQuests`): a história de cada um vira objetivo ("[Pessoal] Posso te ajudar com aquilo?"):
  - **Família**: um parente vivo em outro grupo; o reencontro traz a pessoa para a base.
  - **Horta**: traga sementes e a base ganha comida todo dia.
  - **Lugar ao norte**: um esconderijo marcado no mapa.
- **Traumas e vícios** (`Rem_Traumas`):
  - **Pânico** depois de perder um amigo (foge da briga).
  - **Medo do escuro** depois de se ferir à noite (se distrai na vigia).
  - **Bebida** (anima, cansa, gasta comida e falha no posto).
  - Supera-se conversando ("[Conversa] Como você está, de verdade?") ou com dias bons. Aparece na Ficha e no painel.
- **Crônica:** quatro marcos novos (fama, nome do grupo, reencontro, primeira colheita).

## 0.20.0: mundo em movimento (território, guerra, refugiados, caravanas)
- **Território das facções** (`Rem_Territory`): cada grupo controla a área em volta da casa. Ao entrar, aparece "Território de ..." e o grupo passa a ser conhecido. No território dos saqueadores, encontros com eles ficam bem mais comuns; perto de milícias, bem mais raros.
- **Preços por região:** comida e remédio valem mais onde muitos grupos disputam a mesma área; quem está em guerra paga muito mais por munição e remédio; cada facção tem o seu gosto (milícia, munição; seita, remédio; famílias, comida).
- **Guerra entre facções** (`Rem_War`): grupos vizinhos que se odeiam entram em guerra e se atacam com frequência. As batalhas vão para o Diário.
  - Você pode escolher um lado ("[Guerra] Estou do lado de vocês."). Cada inimigo deles que você mata conta, e se o seu lado vencer, eles lembram.
  - A guerra acaba quando um lado some, ou numa trégua depois de dias sem ataques.
- **Refugiados** (`Rem_Refugees`): quando uma base cai para a horda (ou um grupo pequeno perde um ataque), quem escapa vai procurar abrigo num grupo amigo, ou na sua base, se confiavam em você. Perto de você eles andam pela rua e dá para chamá-los: "[Refugiado] Venha para a nossa base.".
- **Caravanas de troca** (`Rem_Caravans`): grupos com comida sobrando mandam duplas carregadas para grupos amigos, e os aliados mandam para a sua base.
  - No caminho, saqueadores podem emboscar.
  - Perto de você, a dupla aparece de verdade, carregando a mercadoria (dá para trocar). Às vezes a emboscada acontece na sua frente: defenda a caravana e o grupo fica te devendo.
- **Crônica:** três marcos novos: escolher um lado numa guerra, defender uma caravana, abrigar um refugiado.
- Ferramentas de teste: "Mundo: guerra entre os dois grupos mais perto" e "Passagem: caravana perto de você".

## 0.19.0: pessoas com história (habilidades, laços, cicatrizes)
- **Habilidades por tarefa** (`Rem_Skills`): carpintaria, coleta, vigia e medicina crescem com o trabalho (nível 0 a 5). Quem fortifica rende mais nas obras; o coletor experiente traz mais e corre menos risco; o vigia experiente cochila menos e vê mais longe; quem cuida dos feridos cura mais rápido. Subir de nível vai para o Diário. Aparece na Ficha e no painel da base.
- **Amizades e rivalidades** (`Rem_Friends`): sair em dupla, conversar e morar junto aproxima; brigas e jeitos que não combinam afastam.
  - Amigos preferem sair juntos e correm menos risco.
  - Rivais não saem juntos e brigam mais.
  - A morte de um amigo pesa muito mais.
  - Amizades e rivalidades novas vão para o Diário, e a Ficha mostra amigos e rivais.
- **Ferimentos que duram** (`Rem_Wounds`):
  - **Perna**: manca e não sai para buscar.
  - **Braço**: bate mais fraco e rende metade nas obras.
  - **Corte**: não recupera a vida e o moral cai.
  - Vêm de golpes fortes, saídas que dão errado e hordas, e saram em dias.
- **Enfermaria**: nova tarefa da base, "[Base] Cuida dos feridos.". Com alguém nela (ou um médico), os ferimentos saram bem mais rápido. Em cena, ela vai até os feridos para tratar.
- **Revistar corpos** (`Rem_Spoils`): depois da briga, quem segue você revista os hostis mortos. A munição da arma dele vai para o pente; armas, munição, comida e remédio vêm para você.
- **Crônica** (`Rem_Chronicle`): os marcos da sua campanha (a primeira noite, a cerca pronta, o primeiro adeus, uma semana de pé...) aparecem na tela uma vez e ficam na nova seção Crônica do Diário.

## 0.18.0: vida no grupo (necessidades, vigia, combate, prisioneiros, painel)
- **Necessidades dos aliados** (`Rem_Needs`): quem segue você e quem mora na sua base sente **fome** e **cansaço**.
  - Morador come do estoque da base e dorme à noite; quem fortifica ou sai para buscar cansa mais.
  - Quem segue você come o que tem nos bolsos, depois pede comida. Na conversa: "[Comida] Toma, come isto." (usa a primeira comida da sua mochila; ele lembra disso) e "[Descanso] Tira um cochilo." (deita ali mesmo por 4 horas).
  - Com fome ou exausto: o moral cai, ele bate mais fraco e erra mais. Humor novo: **cansado**. Com fome demais e o moral no chão, ele vai embora.
  - Qualquer um que esteja dormindo acorda quando um inimigo chega perto.
- **Escala de vigia** (`Rem_Watch`): a noite é dividida em 3 turnos e os vigias revezam; o de folga dorme. Sozinho, o vigia passa a noite em claro e pode cochilar no posto.
  - **Alarme**: em cena, o vigia grita quando vê zumbis ou gente hostil chegando; todos acordam e vão para a porta. Vai para o Diário.
  - Longe de você: vigia acordado avisa a tempo (mais defesa contra hordas e saqueadores à noite, ladrão espantado); ninguém vigiando = pegos de surpresa (menos defesa).
- **Ordens de combate** (`Rem_Orders`): "[Combate] Segura o fogo.", "Ataca à vontade.", "Lute do seu jeito." e "Recua para a base!", na conversa ou para todos no clique direito. **Alvo marcado**: clique direito num zumbi ou num hostil → "Aliados: ataquem este!".
- **Prisioneiros e interrogatório** (`Rem_Prisoners`): quem se rende pode virar prisioneiro. Leve para a base, prenda, e pergunte "Onde fica o seu bando?". Quando fala, o esconderijo vai para o mapa e, se eles planejavam atacar a sua base, o ataque atrasa. Também dá para pedir **resgate** ao bando (comida e munição no estoque), **recrutar** depois de uns dias bem tratado, ou **soltar** (o bando lembra). Preso mal vigiado e com fome pode fugir e contar onde vocês estão.
- **Painel da base** (`Rem_BasePanel`): clique direito → "Painel da base". Estoque, defesa, moral, obra atual, escala de vigia e prisioneiros num só lugar; clicar num morador troca a tarefa dele, mesmo com ele longe.
- Ferramentas de teste: "Base: alarme do vigia".
- Para outros mods: `Rem.registerTargetOption` (opções sobre o zumbi clicado).

## 0.17.0: sistemas mais amplos
- **Equipar aliados** (`Rem_Gear`): na conversa com quem anda com você ou mora na sua base, "[Equipar] Usa esta arma." passa a arma da sua mão para ele (de verdade: sai do seu inventário; a dele volta para você). Duas mãos usa as animações de taco, uma mão as de faca. Arma de fogo que ele sabe usar vem com até 2 caixas da sua munição; "[Equipar] Toma munição." reabastece. A arma cai com o corpo se ele morrer.
- **Especialidades:** o arquétipo agora muda o rendimento.
  - Engenheiro faz 1,5× mais nas obras.
  - Médico na base acelera a recuperação de todos os feridos.
  - Alguém furtivo na dupla corta pela metade o risco de uma saída.
  - Quem tem arma de fogo e munição defende mais a base; brigão também ajuda.
- **Alianças** (`Rem_Alliance`): "Vamos nos aliar." com grupos que confiam em você (reputação 60+, e o vínculo com quem você conversa ajuda). Aliados trocam sem margem, mandam gente quando sua base é atacada (até 500 tiles), mandam comida quando têm de sobra, e aparecem como "aliado" no Diário. Saqueadores e errantes não se aliam. A aliança acaba se a reputação cair abaixo de 20.
- **Saqueadores atacam a sua base:** depois do dia dos saqueadores, um bando a até 400 tiles pode atacar (1% por hora, no máximo a cada 3 dias). Com você lá, eles chegam de verdade correndo para a base. Longe, a defesa decide (moradores, vigias, armas, obras, aliados): repelidos (o bando perde alguém) ou invadem (levam metade da comida, matam alguém, derrubam cerca).

## 0.16.0: as facções também constroem
O sistema da sua base vale para todos os grupos do mod.
- **Obras por facção** (`Rem_BaseBuild`): cada grupo com casa trabalha na própria base, com o mesmo trabalho de verdade (tábuas, cerca, carros), conforme a facção:
  - Famílias (civis): janelas, portas, reforço, cerca, barril de chuva.
  - Milícia: tudo, inclusive arame farpado, carros nas ruas e gerador.
  - Saqueadores: janelas, portas, arame farpado e carros bloqueando as ruas (sem cerca de família).
  - Seita: janelas, portas, reforço, cerca, barril.
  - Errantes: nada (estão de passagem).
- **Projetos novos** (para todos, inclusive a sua base): **arame farpado** num anel do lado de fora da cerca (o do jogo, vida 100), **barril de chuva** e **gerador**.
- **Mestre de obras** (`Rem_GroupLife`): a cada hora cada grupo divide o trabalho: o guarda fica na porta, uma **dupla sai para buscar material** quando ele está acabando, metade dos outros fortifica, o resto descansa. As duplas de NPC saem de verdade quando você está por perto (arrancam tábuas e pregos, voltam com o parceiro).
- **Longe de você** as obras dos NPCs continuam (até em casas que você nunca viu; aplicadas no que couber quando a casa carregar), as duplas trazem material, e **hordas testam as bases deles**: cerca cai, gente morre.
- **As obras importam:** cerca, janelas, arame e carros contam na defesa contra ataques de saqueadores e na chance de uma base cair para uma horda. Uma base fortificada resiste onde uma aberta cai.
- **Conversa:** "Como vão as coisas?" diz a obra atual ("Estamos trabalhando na casa: cerca em volta da casa") ou que falta material.
- **Diário:** a obra de cada grupo que você conhece, e notícias quando eles terminam algo ou são atacados por hordas.
- **Sandbox:** "Obras dos grupos (porcentagem)" na aba Mundo (0 desliga, 100 é o ritmo da sua base).
- **Para outros mods:** `Rem.BaseBuild.registerProject(nome, { cost, after, factions, plan, apply })` adiciona obras; `Rem.registerFaction(nome, { base = { projects = { ... } } })` escolhe as obras de uma facção.
- O cérebro do grupo (`Rem_Director`) não prega mais tábuas por conta própria: todas as obras passam por `Rem_BaseBuild`.

## 0.15.0: base viva (obras, duplas, eventos)
**Obras** (`Rem_BaseBuild`): quem tem a tarefa "fortificar" trabalha numa fila de projetos, em ordem, na sua frente:
1. tábuas nas janelas (2 por janela);
2. tábuas nas portas externas que não são a principal;
3. reforço até 4 tábuas em cada janela e porta;
4. **cerca de madeira** em volta da casa, a 3 tiles das paredes, com uma passagem na frente da porta principal (mesmos sprites e vida da cerca de carpintaria do jogo; zumbis podem derrubar);
5. **carros queimados** arrastados para as ruas em volta, como barricada (até 4, um em cada lado, a rua da porta primeiro; modelos queimados de verdade do jogo).
Cada passo leva 6 s, faz barulho e gasta material (tábua 1, cerca 2; arrastar carro não gasta, mas leva 4 passos). Até 8 passos por dia por pessoa. Longe de você os passos continuam e aparecem quando a casa carregar.

**Saídas em dupla:** ninguém sai sozinho. Buscar suprimentos e a nova tarefa **buscar material** saem com um parceiro da mesma tarefa, ou com alguém descansando; sem parceiro, esperam ("Sozinho eu não saio") e o Diário explica. O parceiro acompanha e briga junto. Saída de material arranca tábuas, pregos e chapas dos móveis dos prédios em volta (barulho!) e traz para o estoque, que vira material. Em dupla o risco de morte é metade; quando dá errado, um volta com a notícia.

**Eventos** (`Rem_BaseEvents`):
- **Horda** de noite: com você lá, os zumbis aparecem do lado de fora da cerca e os moradores lutam; longe, a defesa (vigias, janelas, cerca, carros, moradores) decide: aguentou, cerca derrubada, feridos ou mortos.
- **Visitante** de dia: com você lá, alguém no portão pedindo para ficar ("Pode ficar na nossa base" na conversa); longe, os moradores aceitam se houver comida e lugar.
- **Briga** com moral baixo (a briga é falada entre os dois); moral no fundo: alguém vai embora.
- **Ladrão** de noite: sem vigia, leva comida; com vigia, é espantado.
- **Festa** quando uma obra termina: moral sobe.
- Conversas novas entre moradores sobre as obras.

**Diário:** linha de obras (projeto atual, cerca pronta/total, carros na rua) e todos os eventos.

**Correção:** quem saía sozinho e morria aparecia no Diário como "voltou sozinho".

## 0.14.0: a sua base
Um lugar seu que continua vivo enquanto você explora (`Rem_PlayerBase`).
- **Definir a base:** clique direito dentro de um prédio → Primeiros Dias → "Definir este prédio como base". Os melhores armários da casa (até 4) viram o estoque, e a porta externa mais perto vira a porta principal. Marca no mapa e entra no Diário. Dá para mudar de lugar depois.
- **Mandar aliados:** pela conversa ("[Ordem] Vai para a nossa base"), pelo clique direito no aliado ("Mandar para a base") ou todos de uma vez ("Aliados: todos para a base"). Até 8 moradores; quem mora na base não conta no limite de 4 que andam com você. Para chamar de volta: "[Ordem] Vem comigo".
- **Tarefas** (pela conversa com o morador):
  - **Fortificar:** prega tábuas nas janelas abertas, 2 janelas por dia por pessoa, gastando material.
  - **Vigiar:** fica na porta; conta na defesa contra ataques de saqueadores.
  - **Buscar suprimentos:** de dia, a cada 5 horas, sai para revirar um prédio em volta da base (até 90 tiles) e traz o que achar para o estoque. Pode voltar ferido, ou não voltar. Quando tudo em volta já foi revirado, avisa.
  - **Descansar:** fica em casa e se recupera mais rápido.
  Quem chega pega sozinho a tarefa que está faltando (fortificar, vigiar, buscar).
- **Estoque de verdade:** comida e água nos armários do estoque são o que eles comem (e somem conforme comem); o resto (suas ferramentas, armas) nunca é mexido. Tábuas, pregos e caixas de pregos que você deixar lá viram material para fortificar.
- **Longe de você** a base segue: comem, pregam tábuas (que aparecem quando a casa carregar), saem para buscar, se recuperam. Sem comida por um dia: aviso; por três dias: alguém vai embora. Saqueadores podem atacar a base (vigias e janelas fechadas ajudam a resistir); a base nunca é tomada.
- **Escolha de prédios corrigida (vale também para os grupos de NPC):** sortear entre todos os prédios do mapa quase nunca achava um perto de um ponto; agora há um índice de prédios por região. Grupos de NPC passam a achar onde saquear com muito mais frequência.
- **Diário:** nova seção "Sua base" com moradores (tarefa e humor), comida em dias, material, janelas fechadas, distância e direção; e os acontecimentos (buscas, feridos, mortes, fome, ataques).

## 0.13.0: correções do segundo teste no jogo
- **Diário vazio e cheio de erros:** na Lua do jogo, `-1 % 8` dá `-1` (na Lua normal dá `7`), então a direção de grupos a oeste/norte virava `nil` e o diário quebrava a cada atualização (192 erros no console). A direção agora é normalizada à mão, e se o diário falhar por qualquer motivo a janela mostra um aviso em vez de ficar vazia.
- **Aliados com cara de zumbi:** era sangue acumulado das brigas no rosto e na roupa (o corpo deles é um zumbi e suja a cada golpe). Agora quem está calmo há 15 s se limpa, e a pele humana é reaplicada se o jogo trocar para a de zumbi (`Rem_Look`).
- **Aliados ainda assustavam:** o jogo sobe o pânico toda vez que a conta de "zumbis visíveis" aumenta, e aliados entram e saem dessa conta o tempo todo (andando, atrás de parede, de outro cômodo). A correção agora compara com os zumbis de verdade em volta: se a conta subiu e não chegou nenhum zumbi (ou sobrevivente hostil), o susto é desfeito.
- **Anotações do mapa sobrepostas:** várias marcações na mesma casa (o grupo, o abrigo, a missão de limpar a rua, o pedido de socorro) ficavam no mesmo ponto. Agora ficam lado a lado em volta do lugar, com um só círculo. As marcações já desenhadas são apagadas e redesenhadas no lugar certo na primeira vez que você abrir o mapa.
- **A base nunca evoluía:** o grupo vivia alternando entre "esconder" e "limpar a rua" por causa de qualquer zumbi passando na rua, e nunca chegava a trabalhar; e longe de você nada avançava. Agora só se escondem com uma horda colada nas paredes; zumbis longe da casa não interrompem o trabalho. E o trabalho continua na sua ausência: de dia, até 3 janelas por dia, gastando material; as tábuas aparecem quando a casa carregar perto de você.
- **Erro de luz no console:** a luz das casas à noite tentava remover uma luz que ainda não existia (`IllegalStateException`).

## 0.12.0: correções do teste no jogo e usabilidade
**Problemas relatados**
- **Anotações no mapa enormes:** o tamanho seguia a escala global dos símbolos (com o Map Symbol Size Slider alto ficava gigante) e o círculo era 2,2× maior ainda. Agora os tamanhos são fixos e pequenos, as anotações são curtas, e as marcações já desenhadas são reajustadas na primeira vez que você abrir o mapa.
- **Aliado mandado saquear não ia a lugar nenhum:** três causas. O corpo dele é um zumbi, e zumbi não abre porta; ele ia para o centro do prédio, que pode ser parede; e tentava pisar no quadrado do armário, que é sólido. Agora quem trava numa porta fechada **abre e passa** (trancada só por dentro; porta externa é fechada de volta), vai direto para o quadrado livre ao lado do armário, desiste de um armário que não alcança, volta se demorar demais ou se você se afastar, e avisa quando não achou nada.
- **Janela de troca vazia:** quem não estava em casa (aliados, gente de passagem) não tinha nada. Agora todo mundo leva alguma coisa **nos bolsos**, coerente com o que é, e a troca junta estoque da casa, carga e bolsos. Sem nada mesmo, a janela avisa.
- **Jogador sempre assustado com aliado por perto:** o jogo conta o corpo do aliado como zumbi visível e sobe o pânico. O susto causado por sobreviventes amigos agora é desfeito no mesmo quadro; zumbis de verdade e hostis continuam assustando.
- **Recrutar fácil demais:** agora o que mais pesa é o vínculo com a pessoa. Um estranho não segue você na primeira conversa; quem tem casa e grupo precisa de um vínculo forte. Limite de 4 aliados.

**Outras melhorias**
- **Destravar:** sobrevivente parado sem conseguir andar dá um passo para o lado e tenta de novo.
- **Alcançar:** aliado que ficou para trás por alguns segundos reaparece perto de você.
- **Ordens para todos:** "Aliados: todos comigo" e "todos esperem aqui" no clique direito.
- **Ordens pela conversa:** seguir, esperar, guardar, vasculhar o prédio, liberar.
- Saques dos grupos também usam o quadrado livre ao lado do armário.

**Testes:** 846 verificações; 34 mutações no código novo, todas pegas.

## 0.11.0: Primeiros Dias (grupos que decidem, ações que importam)
O mod passa a se chamar **Primeiros Dias** (o ID interno continua `Remanescentes`, para não quebrar saves).

**Do teste no jogo: "os cidadãos só fogem"**
- Lutar ou fugir deixou de vir só da facção. Cada pessoa compara o perigo com o que aguenta: coragem, vida, moral, experiência, quem está do lado dela e se está defendendo a casa (`Rem_Tactics`). Um civil comum encara um zumbi, foge de três; três juntos se defendem; perto de casa todos são mais valentes.
- Civis têm coragem de 1 a 8 (antes 0 a 4). Vão ajudar o companheiro que está sendo atacado.

**"Os zumbis não ligam para os outros sobreviventes"**
- Zumbi atrás de você troca para o sobrevivente que estiver mais perto dele (antes só se estivesse colado).
- Barulho de sobrevivente atrai zumbis livres para ele, não só para o lugar do som.

**"Um monte de coisas que não se conversam"**
- **Cérebro do grupo** (`Rem_Director`): comida, saúde e segurança viram um objetivo: buscar suprimentos, reforçar a casa, limpar a rua, se esconder de uma horda, cuidar dos feridos. O objetivo comanda o que os moradores fazem, o que respondem e a missão que pedem.
- **Trabalho visível:** um morador prega tábuas nas janelas abertas, uma por uma, gastando material; saques trazem material; você pode trazer tábuas e pregos.
- **Primeiros dias:** no dia 0 as casas ainda não estão fechadas; a fortificação inicial cresce até o dia 6.

**"A maioria das opções não leva a nada"**
- A conversa mostra o que cada escolha mudou (reputação, vínculo, mapa) e, nas recusas, o que falta.
- "Como vão as coisas?" diz o que o grupo está fazendo.
- **Pedir ajuda:** quem gosta de você te dá comida ou remédio.
- **Diário:** aliados, grupos conhecidos com o que estão fazendo, pedidos em aberto e acontecimentos; avisos na tela quando algo acontece com quem você conhece.

**Testes**
- 781 verificações; 49 mutações nos sistemas de decisão, 47 pegas (as 2 restantes são caminhos redundantes).

## 0.10.0: vida (personagens, vínculos, conversas e histórias)
**Personagens com vida própria**
- **Jeito:** cada pessoa é falante, ranzinza, otimista, de fé, piadista, de poucas palavras ou sempre em alerta. Muda o que ela resmunga quando está à toa.
- **História:** quem ela perdeu e o que ainda quer. Ela conta em "Me fala de você" (os desconfiados só contam para quem já fez algo por eles).
- **Humor e moral:** com dor, passando mal, de luto, com fome, de bom humor, sem ânimo ou em paz. Sai do estado real da pessoa e do grupo; o moral sobe com a casa abastecida, refeições e zumbis mortos, e cai com fome e mortes.
- **Luto:** quando alguém do grupo (ou da família de passagem, ou um aliado seu) morre, os outros falam o nome dele na hora e ficam de luto por um dia.
- **Hora de comer:** no almoço e no jantar, quem está em casa (menos o guarda) senta na cozinha para comer junto.

**Vínculo pessoal e memória**
- Cada pessoa guarda um **vínculo com você** (−100 a 100) e as últimas **lembranças** do que você fez: salvou dos zumbis, deu um presente, trocou, ajudou o grupo, libertou, defendeu a casa, bateu, ameaçou.
- O vínculo pesa na atitude (alguém pode gostar de você mesmo com o grupo neutro, ou guardar rancor), no recrutamento e nos cumprimentos ("É você! Ainda te devo a vida.").
- **Presente:** nova opção na conversa. Você dá o item mais útil para eles agora (comida, água, remédio, munição); um por pessoa a cada 6 horas.
- **Experiência:** quem mata zumbis sobe de nível (até 5): mais dano e pontaria contra zumbis e outros NPCs, nunca contra você. Seus aliados melhoram com o tempo.

**Conversas e comentários**
- **Sobreviventes conversam entre si:** dois parados perto de você trocam duas falas sobre a situação (luto, fome, noite, zumbis, piada, fé, o que acham de você). Saqueadores têm os assuntos deles.
- **Comentam o que acontece:** noite caindo, amanhecer, chuva, você ferido, horda por perto, uma sequência de zumbis mortos por você; e um neutro reclama se você apontar a arma para ele.

**Histórias novas**
- **Mascate:** errante com a mochila cheia que para e oferece troca.
- **Emboscada:** um "ferido" pedindo socorro sem nenhum zumbi em volta, com comparsas escondidos. Chegou perto: "Agora!".
- **Refém:** saqueadores guardando um civil rendido. Livre, ele agradece e se oferece para seguir você.
- **Alguém de luto:** sentado sozinho; conversar ou dar um presente cria vínculo.
- **Cerco:** um grupo amigo que você conhece é atacado por uma horda. Um mensageiro corre até você, pede ajuda e marca a casa no mapa. Limpe a horda para salvar o grupo; sem ajuda, eles perdem gente ou a casa cai.

**Ficha e conversa**
- A Ficha mostra jeito, humor, vínculo, experiência, lembranças e a história (depois que ela contar).
- A resposta da conversa substitui a fala solta que estava sobre a cabeça do NPC.

**Código e testes**
- Módulos novos: `Rem_Persona`, `Rem_Bonds`, `Rem_Banter`, `Rem_Stories`, `Rem_Routine`. Eventos novos: `playerDeed`, `npcKilledZombie`. Eventos de rua agora são extensíveis (`AM.HANDLERS`, `AM.WEIGHT_MOD`).
- Os métodos do jogo chamados pelo mod foram conferidos contra as classes Java e a biblioteca Lua da 42.22 (existência do método; os casos de risco, um a um).
- Testes: 690 verificações; 41 mutações nos sistemas novos, todas pegas.

## 0.9.1: correções do teste no jogo
- **Falas nunca apareciam:** o `Say()` do jogo não faz nada em zumbis, e o corpo dos NPCs é um zumbi. Agora o mod desenha as falas sobre a cabeça deles (`Rem_SpeechUI.lua`): na cor da facção, com contorno, até 2 linhas, somem aos poucos. Vale para falas, conversa, Status e avisos.
- **Janelas vazias:** o retrato 3D da conversa lançava um erro no desenho a cada quadro e derrubava a interface inteira (janela sem opções). Trocado por um retrato 2D com o ícone da profissão do jogo sobre a cor da facção.
- **Ficha em janela própria:** retrato, profissão, idade, arquétipo, atitude e reputação, vida, moral, munição e as 5 barras de personalidade.

## 0.9.0: polimento e candidata a lançamento (Fase F)
**Interação mais bonita e real**
- Janela de conversa nova: retrato do NPC, nome, profissão, idade, arquétipo, facção na cor da facção, atitude e barra de reputação; histórico da conversa (você em azul, ele na cor da facção); opções numeradas e botão "tchau" separado. O NPC também fala em voz alta. Fecha sozinha se ele se afastar ou ficar hostil.
- Janela de troca nova: ícone e valor de cada item, o que o grupo está precisando, a margem que cobram, totais e saldo; o botão de aceitar só liga quando a troca é aceitável.
- Respostas da conversa com várias versões e tom pela personalidade (medroso, frio/durão).
- Falas no mundo com mais variações e tom pela personalidade (durão e medroso para avistar, matar, ferido, fugir, ocioso), sem repetir a última fala.

**Desempenho**
- Índice espacial de zumbis (`Rem_Spatial.lua`): busca de inimigos, percepção, tiro e eventos de rua não varrem mais todos os zumbis por NPC. 12 NPCs e 1500 zumbis: de 2,29 para 0,71 ms por quadro.

**Sandbox e ferramentas**
- 27 opções em 4 abas: Sobreviventes, Mundo, Zumbis, Teste. Textos revisados (com acentos) em PT-BR e EN.
- Ferramentas de teste desligadas por padrão e agrupadas em submenus (Criar, Mundo e grupos, Gente de passagem, Reputação, Outros).

**Correções e revisão**
- Saqueador que exige suas coisas recua se você chega perto demais, em vez de colar em você.
- Números de reputação e idade sempre inteiros nas mensagens.
- Mensagens de rotina (infecção, spawn, mundo, evolução) só aparecem com "Log detalhado".
- Código morto removido; nenhuma variável vaza para o global.
- Compatibilidade conferida com o modlist de teste (veja o README).
- Testes: 520+ verificações, estáveis em 30 execuções seguidas; testes de mutação nas falas e janelas.

## 0.8.1: marcações no mapa
- Ao revelar um grupo, dar uma missão com lugar ou te abrigar, o NPC marca no seu mapa: círculo na cor da facção, símbolo e anotação. Fica salvo e não duplica.

## 0.8.0: interação (Fase E)
- Conversar, trocar (estoque real, valor pela necessidade), pedir abrigo, recrutar (lealdade + reputação), comandos de seguidor (seguir, esperar, guardar posição, saquear aqui, liberar), missões (trazer itens, limpar a rua, achar quem sumiu) e ameaçar.

## 0.7.0: mundo persistente (Fase D)
- Grupos por região conforme você explora; viagens em passos fora de cena; bases que fortificam, caem para hordas, recrutam e são tomadas por saqueadores; relações, rixas e alianças entre grupos.

## 0.6.1
- Ninguém nasce pelado: roupa sempre existe para o gênero; corpos pelados de saves antigos são vestidos.

## 0.6.0: Dia Zero (Fase C)
- Linha do tempo do apocalipse, zona de graça no início, gente de passagem na rua, eventos de rua (pedido de socorro, tábuas, briga por comida, tiros ao longe) e mordidos virando zumbis.

## 0.5.0: percepção e combate justo (Fases A e B)
- Visão pela luz, postura e campo de visão; atenção gradual; audição; procura e desistência; fôlego e coleira.
- Dano calibrado com proteção da roupa; vida por arquétipo; tiro disciplinado (aviso, munição contada, alcance menor no escuro); assalto, moral e rendição; sem rastejar e sem gemido de zumbi.

## 0.4.x: ficha, reputação e safehouses (Fases 2 e 3)
- Ficha, personalidade, atitude e reputação por grupo; território de milícia e seita.
- Safehouses com entrada garantida, portas que os moradores abrem e trancam, estoque real, saque de verdade, papéis (guarda, cozinheiro, médico), sono, sinais de vida; atiradores; NPC derrubado não ataca.

## 0.3.0: combate real, facções e mundo vivo
## 0.2.0: grupos no papel e simulação horária
## 0.1.0: protótipo (Fase 1)
- Sobrevivente com roupa e arma, que luta contra zumbis.
