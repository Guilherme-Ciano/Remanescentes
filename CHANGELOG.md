# Changelog

Todas as versões do Remanescentes. Datas no formato do commit; "falta validar" = testado offline, ainda não confirmado dentro do jogo.

## 0.9.0: polimento e candidata a lançamento (Fase F)
**Interação mais bonita e real**
- Janela de conversa nova: retrato 3D do NPC (com a roupa dele), nome, profissão, idade, arquétipo, facção na cor da facção, atitude e barra de reputação; histórico da conversa (você em azul, ele na cor da facção); opções numeradas e botão "tchau" separado. O NPC também fala em voz alta. Fecha sozinha se ele se afastar ou ficar hostil.
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
