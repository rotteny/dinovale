# Ordem de execução da v0.2 "Primeiro Vale": proposta do SHIKAMARU

Base: proposta de corte da `SHIRO` (revisão 2, 61 tarefas), tabela 4.3 e caminho crítico 4.13-F do `documentacao/PLANEJAMENTO.md`, estado da branch (rodada C = `6380243`, em correção). Nada no repositório foi alterado. Sem horas e sem estimativa de tempo de projeto; "min" e "s" abaixo são tempo de jogo.

Decisões do dono tomadas como fixas: 4 slots base; uma vaga de bolsa (+4 Cesto, +8 Mochila; vale a equipada); Peso fica (50 kg, impede pegar acima de 100%, sem lentidão); dino sem sela com 4 slots; Neutro ajuda em combate; montaria sem sela em Médio ou maior; ficha de RPG no inventário; dia e noite e chuva; torpor como ameaça; fome leve; sem estações e sem sanidade.

## 0. Como ler

- **Uma etapa = uma entrega jogável**, implementada pelo `SORA`, revisada pelo `LEVI`, commit local, e o dono joga antes da próxima começar. Etapas com a/b são divisões de uma tarefa grande do plano em duas entregas: a experiência (B com 3 revisões, C juntando demais) diz que isso custa menos do que reprovar.
- Regra de tamanho: **no máximo 2 tarefas de código por etapa**, e nunca duas que mexam no mesmo par (inventário + save, entrada + câmera) sem ser a mesma funcionalidade.
- **Save:** o repositório nunca foi pushado, então nenhum jogador tem save v4. Recomendo **v5 aberto durante toda a v0.2**: cada etapa acrescenta campos ao v5 com default no `from_dict`; existe uma só migração (v4 para v5) e uma fixture v5 que cresce. Isso evita 8 migrações e 8 revisões de migração. Os ids SAV-02 e SAV-03 deixam de ser etapas e fecham na E18 (consolidação + QA-03). O `SORA` confirma contra `documentacao/contexto/save.md` antes da E6.
- Semear espécie no `lunata.json` (MUN-03) acontece **na etapa da espécie**, não numa etapa só: resolve a circularidade MUN-03 <-> CRI-06c/CRI-06 (seção 5).
- Dados: todo número novo nasce em `Resource`/JSON com a marca [premissa] da `SHIRO`. O playtest ajusta dado, não código.

## 1. Etapas

### Bloco A: antes do playtest QA-01a (ameaça e torpor)

**E0. Rodada C fechada.**
Objetivo: a ilha, o Soco, a zona ativa e o save v4 aprovados pelo `LEVI` e testados pelo dono, com commit.
Tarefas: correções pendentes de `6380243` (MUN-03 parte 1, MUN-05, Soco do SOB-06, save v4). Nada mais entra.
Dono testa: anda a ilha inteira, Paquicéfalos nas três faixas, Soco funciona, fecha e abre com save.
Dependências: nenhuma. Bloqueia tudo.
Risco: tentação de "aproveitar e já" colocar coisa da E1. Não.

**E1. Regras em dados e Utahraptor na ilha.**
Objetivo: `ServerRules` lido pelo host local e o Utahraptor semeado nas 6 tocas com as regiões de respawn em dados.
Tarefas: ARQ-05 (desenho do `KURAMA`, código do `SORA`), MUN-03 parte 2 (6 tocas na Mata-baixa, Utahraptor 6 a 11, `respawn_regioes`; Dodo e Triceratops entram nas E13 e E15).
Dono testa: Utahraptors perto das tocas na Mata-baixa te perseguem; o `ServerRules` tem as chaves do GDD 13 e trocar uma delas muda o jogo sem recompilar.
Dependências: E0.
Risco: Utahraptor sem navegação trava em árvore (aceito por uma etapa); ARQ-05 virar refatoração geral de "tirar número do código" (limitar às chaves que as etapas seguintes usam).

**E2. Navegação dos dinos.**
Objetivo: o Agressivo e o Semi contornam água, rocha e árvore; desistem após 5 s sem caminho.
Tarefas: MUN-04 (`AStarGrid2D` em 16 px com obstáculos do terreno; o gancho do `BuildGrid` fica para a E8b), INF-09 (`LEVI`: orçamento de CPU com 32 ativos e 360 no mundo).
Dono testa: ser perseguido por entre árvores e ao redor de lagoa sem o dino atravessar nada; fps estável na Mata-baixa.
Dependências: E1.
Risco: custo de CPU do pathfinding com 32 ativos. Mitigação: recalcular caminho só a cada 0,5 s e só para quem persegue.

**E3a. Toca, âncora e ronda (refúgio A).**
Objetivo: o Utahraptor vive ao redor da toca (âncora de 24 tiles, ronda de 10) e a Campina é núcleo seguro.
Tarefas: CRI-12 parte 1.
Dono testa: atravessar a Campina sem encontro; na Mata-baixa, os encontros acontecem perto das tocas; o dino que persegue volta para a toca depois.
Dependências: E2.
Risco: faixa de nível e âncora deixarem a Mata-baixa vazia longe das tocas (ajuste de dado).

**E3b. Carnívoro ataca o dormindo.**
Objetivo: a vigília da doma tem ameaça real.
Tarefas: CRI-12 parte 2 (ronco de 8 tiles, +4 com Rubra; checagem de 0,5 s; "!" de 1,5 s; alvo mais próximo; provocar muda o alvo; perdas da tabela 11.1 sobre o Paquicéfalo dormindo).
Dono testa: começar uma doma de Paquicéfalo na Mata-baixa e defender o dormindo com o Bastão; provocar o Utahraptor para tirá-lo do dormindo.
Dependências: E3a.
Risco: é a tarefa de IA mais sensível da v0.2; a `LEVI` precisa de teste determinístico de cena (herdado do INF-09). Possível 2ª revisão: aceitar.

**E4. Fome leve e desmaio por torpor.**
Objetivo: fome zero não mata; leva ao desmaio, e o desmaiado é alvo.
Tarefas: SOB-07 (fome 0,1/s; `HungerComponent` sem dano; sinal `hunger_zero`; +2/s líquido no torpor; estado inconsciente com duração em dado; comer corta; sinais nas faixas), SOB-15 (jogador inconsciente entra na lista de alvos do CRI-12; dano da espécie sobre o caído).
Dono testa: com `player_rules.tres` acelerado, deixar a fome zerar, desmaiar perto de uma toca e ser mordido; comer na janela e não desmaiar.
Dependências: E3b.
Risco: SOB-15 é "provisório" e não tem aceite na proposta da `SHIRO`. Aceite que proponho: desmaio de 8 s ao lado de um Utahraptor L20 tira 40 a 48 de vida e não mata; de 20 s abre a tela de morte. Os dois valores em dado; o QA-01a escolhe.

**E5. Corpo e respawn por região.**
Objetivo: morrer é barato e claro: o corpo guarda tudo por 10 min e a tela de morte oferece "Local aleatório" (ilha inteira, regiões como reserva; provisório, GDD 12.2).
Tarefas: SOB-02 (corpo com itens, 10 min), SOB-12 (tela com lista única; só "Local aleatório" agora (sorteio na ilha inteira, regiões em dados como reserva); Cama e Saco entram na E12; sorteio com 30 tentativas, distância de Agressivo/Semi, ponto reserva, proteção de 3 s; `RespawnPicker`/`RespawnRules` já existem).
Dono testa: morrer e renascer longe de Utahraptor, voltar e pegar tudo do corpo; morrer com o corpo já no chão (limite).
Dependências: E4.
Risco: estado de morto no save (o gatilho formal é do SAV-04b, E18); aqui só o corpo precisa persistir.
Nota: é a única etapa do bloco A que poderia ir para depois do QA-01a (renascer só na Campina, como no M1), se o dono aceitar testar sem corpo. Mantenho antes: ser devorado sem consequência não testa a ameaça.

### >>> QA-01a: playtest curto com 3 pessoas (ver seção 2) <<<

### Bloco B: fabricar e construir

**E6. XP, nível e Saber.**
Objetivo: o jogador cresce por coletar e domar e acumula Saber.
Tarefas: PRO-11 (curva; XP +1 coletar, +2 fabricar [entra na E7a], `15 + 3 x nível` domar; Saber 1 por nível, +1 nos 5, 10, 15, 20; sem pontos de atributo), UIX-12 (barra fina "Nv N", selo de Saber, aviso de 3 s).
Dono testa: coletar e domar sobe nível; selo aparece com Saber sobrando; fecha e abre e o nível fica.
Dependências: E5 (nenhuma técnica; é a ordem).
Risco: curva [premissa]; a dependência PRO-11 <- PRO-09 do plano está morta (era o "+3 kg por ponto", sem pontos não existe).

**E7a. Fabricar à mão, Bancada e Lança.**
Objetivo: fabricar existe: `RecipeDef`, craft à mão das receitas conhecidas, Bancada como peça e craft nela a 2 tiles (4 s).
Tarefas: PRO-04, CRI-13 (Lança: dano 12, durabilidade 80 como dado inerte até a E-durabilidade; Dodo morre em 2 golpes).
Dono testa: fazer Lança, Machado, Picareta, Bastão de reposição à mão; colocar a Bancada (nesta etapa, conhecida provisória) e fabricar nela; matar um Paquicéfalo com a Lança.
Dependências: E6.
Risco: a Bancada é peça colocada antes do `BuildGrid` (E8a): colocar como entidade simples agora e migrar para o grid na E8a. Aceitar o retrabalho pequeno em troca de fabricar cedo.

**E7b. Receitas finais e tela de Saber.**
Objetivo: 17 receitas em dados, gate por Saber, tela P com aba Receitas.
Tarefas: PRO-05 (8 conhecidas: Lança, Machado, Picareta, Fogueira, Bastão, Cesto, Baú, Mochila; 9 aprendidas com 7 Saber: Bancada, Abrigo x3, Saco, Cama, Ração C/B/A), PRO-13 (`aprender_receita`, bloqueio na bancada, tela P, efeito de coleta de Machado e Picareta; Saber em lista plana, D18).
Dono testa: aprender Bancada com 1 Saber; receita travada mostra o que falta; L6 tem 7 Saber e aprende tudo.
Dependências: E7a.
Risco: receitas que apontam para peças e itens que ainda não existem (Fogueira, Baú, Cesto, Mochila, Saco, Cama, Rações). Ficam nos dados com o item, mas sem efeito até a etapa de cada um. O `LEVI` aceita "receita produz item" sem exigir o uso.

**E8a. Construir: fundação, parede e porta.**
Objetivo: o jogador levanta um abrigo e ele sobrevive ao save.
Tarefas: CON-01 (`BuildGrid` em Dictionary por `Vector2i`, validação no servidor, `to_dict`), CON-03 (ghost e menu de peças), CON-02 parte 1 (fundação, parede, porta; remoção e drop; Bancada migra para o grid).
Dono testa: construir o abrigo mínimo (32 madeira, 4 pedra, 1 fibra), abrir e fechar a porta, remover uma parede e receber o material, fechar e abrir.
Dependências: E7b.
Risco: três ids numa etapa; são a mesma funcionalidade (grid + UI + 3 peças). Se o `LEVI` reprovar, dividir em grid+ghost+fundação / parede+porta.

**E8b. Abrigo que protege e Baú.**
Objetivo: parede e porta fechada bloqueiam o Utahraptor; o Baú guarda e devolve.
Tarefas: MUN-04 gancho (obstáculos do `BuildGrid` no `AStarGrid2D`; aceite: anel de 8 peças bloqueia o carnívoro), CON-02 parte 2 + PRO-06 (Baú como peça e container reusando o `InventoryComponent`; conhecido, Saber 0).
Dono testa: dormir dentro do abrigo com um Utahraptor rondando; guardar madeira no Baú, fechar e abrir.
Dependências: E8a.
Risco: dino já dentro do anel quando a última parede fecha (fica preso, bate em nada porque CON-05 saiu): documentar como conhecido.

**E9. Dia e noite.**
Objetivo: a noite existe e muda a ameaça.
Tarefas: SOB-03 (ciclo 12 min: 7 dia, 1 entardecer, 3 noite, 1 amanhecer; tinta por faixa; luz de 5 tiles ao redor do jogador; percepção do Agressivo x1,5 à noite; hora no save; duração no `ServerRules`). A luz da Fogueira entra na E12.
Dono testa: ver o ciclo inteiro; à noite, ser percebido de mais longe perto de uma toca; passar a noite dentro do abrigo; fechar e abrir no meio da noite.
Dependências: E8b (a noite só faz sentido com abrigo).
Risco: tinta sobre a UI e sobre sprites de 16 px tirar a legibilidade; luz como `PointLight2D` x `CanvasModulate` é decisão do `SORA`, registrar.

### Bloco C: carregar (Peso, slots, bolsas)

**E10. Peso e carcaça.**
Objetivo: o que se carrega tem massa, e matar rende carne e couro.
Tarefas: PRO-09 (`peso` no `ItemDef`, 50 kg, impede pegar acima de 100%, sem lentidão, recusa "Peso máximo" sem gastar o nó; ferramentas fora dos slots contam no Peso), SOB-06 (carcaça à mão em 3 s por carne e 6 s por couro, com Lança mais rápido; fresca por 10 min; o que não cabe fica na carcaça; sem sacolinha; o Soco já existe).
Dono testa: abrigo mínimo (38 kg) cabe numa viagem; o segundo abrigo não; matar e esfolar um Paquicéfalo e um Utahraptor.
Dependências: E7a (Lança), E5 (corpo, mesma base da carcaça).
Risco: Peso já pode existir em parte na branch ("limita custo da carga", `255e2be`); o `SORA` confere antes de criar em dobro.

**E11a. Quatro slots, cinto e Descartar.**
Objetivo: o slot é o limite; ferramentas ficam fora dele; dá para se livrar de uma pilha.
Tarefas: CRI-42 parte 1 (limite de 4 no inventário; vaga Arma + cinto de 4 posições fora dos slots; barra de atalhos mostra só entradas existentes, teclas 1 a 9; recusa "Inventário cheio" sem gastar o nó; se Peso e slot batem juntos, diz Peso), SOB-16 (Descartar pilha com confirmação).
Dono testa: a coleta do minuto 0 a 5 estoura os 4 slots e obriga a fabricar no meio; abrigo mínimo cabe nos 4 exatos; descartar uma pilha longe do Baú.
Dependências: E10, E8b (o Baú precisa existir quando os 4 slots chegarem, senão o dono testa a versão que a `SHIRO` chama de "quebra o jogo").
Risco: o maior da v0.2 em UI (grade, barra, HUD do UIX-16, save). Esperar uma 2ª revisão. Não juntar com a E11b.

**E11b. Bolsas: Cesto e Mochila.**
Objetivo: uma vaga de bolsa; vale a equipada; descer ou tirar só se couber.
Tarefas: CRI-42 parte 2 (vaga Bolsa visível na tela; Cesto de fibra 12 fibra à mão, +4; Mochila de couro 6 couro + 4 fibra à mão, +8; subir sempre; descer ou tirar recusa com "Esvazie N pilhas"; a bolsa nova só é consumida ao entrar na vaga; o corpo leva a bolsa; bolsa equipada no save).
Dono testa: Cesto aos 5 min, Mochila depois de 6 couros; tentar tirar a Mochila cheia; morrer com a Mochila e recuperar no corpo.
Dependências: E11a, E10 (couro).
Risco: regra de troca com compactação de pilhas tem casos de borda (pilhas parciais); o `LEVI` cobre com teste de unidade antes de o dono testar.

### Bloco D: base e sustento

**E12. Base: Fogueira, Saco de dormir e Cama.**
Objetivo: a base tem luz, comida assada e ponto de renascer.
Tarefas: PRO-18 (Fogueira assa: 2 s por carne, 1 madeira para 4; cozida +35 fome, +10 vida em 10 s; luz de 4 tiles à noite), SOB-13 (Saco 8 fibra, 1 uso; Cama 12 fibra + 8 madeira na Bancada, limite 3, espera 60 s persistida; corpo com marcador na borda e limite de 3 corpos; entradas na tela de morte da E5). ART-09 (`YATORA`, em paralelo, antes).
Dono testa: assar carne à noite com a Fogueira iluminando; morrer e renascer na Cama; Saco some depois de usado.
Dependências: E11b (receitas de fibra competem pelos slots: testar o ciclo completo), E9 (luz).
Risco: duas peças + respawn numa etapa. Se pesar: PRO-18 sozinha primeiro.

**E13. Dodo.**
Objetivo: a primeira doma e a carne fácil.
Tarefas: CRI-06c **reescrita** (Dodo Covarde: vem até 3 tiles, ronda, foge sem revidar; vida 24; L3 a 10; carcaça 2 carne 1 couro; **domável**: dorme por Soco/torpor e é alimentado como o Paquicéfalo; 140 na Mata-baixa; respawn 10 min), MUN-03 parte 3 (semear). ART-17 Dodo 16x16 (`YATORA`, antes).
Dono testa: caçar 6 Dodos para a Mochila; domar um Dodo com baga.
Dependências: E10 (carcaça), E7a (Lança).
Risco: a proposta não diz quantos Socos (torpor 10 cada) derrubam um Dodo: a `SHIRO` entrega o torpor máximo do Dodo antes da etapa. A reescrita do CRI-06c no plano não foi feita; o `SORA` recebe o texto desta etapa, não o da tabela 4.3.

**E14a. Ração.**
Objetivo: a fabricação recorrente da doma.
Tarefas: PRO-07 (Ração C, B, A Verde e Rubra e crua; Tubérculo-lanoso e Sal-de-veio como nós; qualidade por refeição; `racao_minima`; fórmula de tempo de domar da 5.14; `domar_velocidade` e `eficiencia_drena_tempo` no `ServerRules`; peso da Ração em dado, hoje sem número).
Dono testa: fazer Ração C na Bancada e domar um Utahraptor L15 (25 carne + Ração); Ração abaixo da mínima rende metade.
Dependências: E7b, E13 (carne em volume).
Risco: a tarefa mais densa de dados do bloco; a `SHIRO` fornece o peso da Ração e confirma os nós de Tubérculo e Sal na ilha (rodada C "com recursos": conferir).

**E14b. Observar, alimentar pela tecla e regressão.**
Objetivo: a vigília dá informação e cobra presença.
Tarefas: CRI-14 (Observar 2 s a 6 tiles com nível previsto; JSON de leitura versionado), UIX-15 (atalho de Ração no dino mais próximo a 3 tiles, com razão do bloqueio), CRI-15 (regressão 1%/s após um intervalo sem comida, configurável).
Dono testa: Observar antes de domar e comparar com o painel; alimentar pela tecla; sair 10 s e perder 5%.
Dependências: E14a.
Risco: duplicação com "Alimentar" do menu do domado (E16b): ver seção 5, escolher um só.

**E15. Triceratops.**
Objetivo: a doma grande e a Pedreira habitada.
Tarefas: CRI-06 (Semi-agressivo: aviso 1,5 s, investida, desiste; estados Aviso e Fugindo; todo dino foge abaixo de 25% de vida; L18 a 24; 8 na Pedreira), MUN-03 fecha (população final 266). ART-17 Triceratops 48x48 (`YATORA`, antes).
Dono testa: provocar a investida e fugir; domar um com Ração A.
Dependências: E14a (Ração A), E2.
Risco: colisão de 48 px no pathfinding de 16 px (travar em canto); primeiro candidato a corte (seção 5).

### Bloco E: vínculo e montaria

**E16a. Afeto e batismo.**
Objetivo: o domado tem vínculo medido e nome.
Tarefas: CRI-07 (Afeto inicial `round(E/5)`; +4 com Ração B ou melhor, +1 simples; -1/min sem cuidado; -10 se ferido por você; **um limiar: obedece acima de 25**; `afeto_decai` no `ServerRules`), CRI-27 (nome até 20 caracteres, `request_rename_dino`, nas barras e no painel, no save).
Dono testa: domado recém-feito ignora ordem (Afeto até 20); duas Rações B e obedece; nomear.
Dependências: E14a.
Risco: com E <= 100 o Afeto inicial nunca passa de 20, então **montar e obedecer exigem alimentar depois da doma**. É coerente com "o vínculo é o diferencial", mas é uma barreira a mais antes da montaria; a `SHIRO` confirma que é intencional.

**E16b. Menu do domado e alforje.**
Objetivo: interagir com o domado por menu; o dino carrega 4 slots.
Tarefas: CRI-43 (menu: Seguir/Ficar, Alforje, Alimentar [ou não, seção 5], Montar/Desmontar como ganchos inertes até a E19a; alforje de 4 slots reusando o container do Baú, `accepts_individual = false`, Peso da espécie; no save).
Dono testa: mandar seguir e ficar; guardar 4 pilhas no Paquicéfalo e levar para a base.
Dependências: E16a, E11b (grade de slots pronta).
Risco: "até 4 por porte" (1 diminuto, 2 pequeno) da `SHIRO` contra "4 slots" do dono. Recomendo 4 para todos na v0.2 (palavra do dono); a tabela por porte é uma linha de dado depois.

**E17. Neutro e domado ferido.**
Objetivo: o domado revida e protege o dono caído; ninguém morre para sempre.
Tarefas: CRI-08 reescrita (evento de agressão: quem feriu quem; estado Revidando com navegação; persegue até 8 tiles e volta; sem fogo amigo; nunca ataca selvagem inconsciente; Dodo foge em vez de revidar), SOB-05 (domado com vida 0 some 5 min e volta à base; `dino_ferido_minutos`; timer no save).
Dono testa: desmaiar de fome ao lado de uma toca com um Utahraptor domado em Seguir e sobreviver; ver o domado sumir e voltar.
Dependências: E16a, E4 (SOB-15), E3b.
Risco: três IAs se cruzando (selvagem que ataca o caído, domado que revida, "nunca ataca inconsciente"): o bug emergente mais provável da v0.2. Teste de cena determinístico obrigatório.

**E18. Gatilhos de save e testes de morte.**
Objetivo: fechar o save v5 e cobrir todos os casos de morte e respawn.
Tarefas: SAV-04b (deitar na Cama salva; morte salva o estado de morto; domado sumido salva; rajada em 10 s vira um save; `autosave_segundos`), QA-03 (`LEVI`: casos do GDD 12.4), SAV-02/SAV-03 consolidadas (fixture v5 completa, migração v4 para v5 testada).
Dono testa: morrer, fechar sem escolher região, abrir e ver a tela de escolha; fechar e abrir com a Cama em espera.
Dependências: E17 (último estado persistente antes da montaria), E12.
Risco: o gatilho "morte de dino domado" do plano não existe mais (SOB-05 não mata): vira "domado sumiu".

**E19a. Montar o Utahraptor.**
Objetivo: a primeira montaria.
Tarefas: CRI-45 parte 1 (só Utahraptor: `montaria: livre` na espécie; requisitos dono, Afeto >= 25, acordado, não ferido; `request_mount`/`request_dismount` validados; WASD move o dino, câmera segue, jogador sai do mundo; velocidade x1,3, sem Stamina; sem ataque montado, jogador imune, dano vai ao dino; desmontar por menu em 0,3 s em tile livre; não entra no abrigo; ao salvar e carregar desmonta; 4 deslocamentos em dados). ART-18 pose sentada 4 direções placeholder (`YATORA`, antes).
Dono testa: cruzar a ilha montado; tentar entrar no abrigo; fechar montado e abrir a pé.
Dependências: E17 (SOB-05 para o desmonte à força vir na E19b), E16b (menu).
Risco: entrada, câmera e colisão juntas; o cavaleiro de 1 px fora do balanço do quadro é aceitável, mais que isso vira deslocamento por quadro (32 valores em dado).

**E19b. Triceratops montável e quedas.**
Objetivo: a montaria grande e as duas formas de cair.
Tarefas: CRI-45 parte 2 (Triceratops `montaria: livre`, 4 deslocamentos; desmonte à força: dino com vida 0 derruba e atordoa 1 s, dino some 5 min; **desmaio por torpor derruba**; colisão do Grande montado).
Dono testa: montar o Triceratops entre árvores da Pedreira; desmaiar de fome montado e cair.
Dependências: E19a, E15.
Risco: 48 px travando em canto; segundo candidato a corte, junto da E15.

### >>> QA-01 rodada 1 (3 a 5 pessoas): slots, montaria, noite, Dodo como primeira doma, Neutro <<<

### Bloco F: polimento, arte e release

**E20. Ficha e HUD final.**
Objetivo: a ficha de RPG e o HUD fechados.
Tarefas: UIX-09 (ficha só de leitura na tela P: jogador com nome, Nv/XP, Saber, Vida, Fome, torpor, dano, velocidades, slots/limite e bolsa; dino com nome, espécie, Nv, Eficiência, Vida, Dano, Afeto, alforje n/4, "Neutro", "montável"), UIX-04 (tooltips e acabamento do HUD; o UIX-16 já refez o grosso).
Dono testa: a ficha bate com o que o jogo faz (dano, velocidade); tooltips de durabilidade/fome.
Dependências: E19b (todos os números existem).
Risco: baixo. Candidata a absorver a durabilidade (ver E-extra abaixo).

**E-extra (encaixe livre, entre E12 e E20). Durabilidade e quebra.**
Tarefas: PRO-16 (Lança 80, Bastão 120, Machado 150, Picareta 120; em zero fica quebrada; sem reparo; barra no tooltip; aviso a 20%).
Dono testa: quebrar uma Lança e refazer.
Dependências: E7a. Independente do resto; entra onde o `LEVI` tiver folga. Terceiro candidato a corte (seção 5).

**E21. Chuva e tutorial.**
Objetivo: o clima e as dicas por evento.
Tarefas: SOB-11 (chuva de 2 min a cada ~8 min; visual e som; clima no save; frequência no `ServerRules`), UIX-05 (dicas por evento: baga, Bastão, Observar, fome, desmaio, noite, slots; sem tela de texto). ART-03 loop de chuva (`YATORA`, antes).
Dono testa: chover de noite com a Fogueira; jogar um save novo e ver cada dica uma vez.
Dependências: E20 (tutorial é o último a nascer porque cita tudo).
Risco: baixo. Chuva é decisão do dono; não é o "primeiro corte" que a `SHIRO` propôs (seção 5).

**E22. Arte e som finais (integração).**
Objetivo: trocar placeholders pela arte final e registrar tudo no `CREDITS.md`.
Tarefas: ART-02, ART-03, ART-06 (artista, D12), ART-16, ART-17 final, ART-18 final (pose por espécie se o sprite final tiver cabeça ou cauda sobre o dorso: 8 sprites).
Dono testa: nenhum `IA-placeholder` no `CREDITS.md`; item 7 do `ESTILO.md` por porte.
Dependências: entrega do artista (seção 3).
Risco: o artista entra depois do QA-01a (R42) e é o único insumo fora do controle dos agentes. Ver critério de MVP (seção 4).

**E23. Fechamento e release.**
Objetivo: push na main e tag.
Tarefas: QA-01 rodada 2, COM-05 (glossário e varredura de nomes), COM-03 (README do jogador, CHANGELOG), COM-04 (landing honesta), INF-08 (`SAITAMA`: binários, checksums, changelog por tag).
Dono testa: a lista da seção 4.
Dependências: tudo.
Risco: QA-01 rodada 2 devolver ajuste de dado que reabre revisão; só dado muda depois dela, nunca código novo.

**Contagem:** 24 etapas numeradas (E0 a E23) mais a E-extra, 7 delas em a/b: 32 entregas testáveis. Antes do QA-01a: E0 a E5 (8 entregas contando a/b).

## 2. QA-01a: o primeiro playtest com outras pessoas

**Onde cai:** depois da E5, antes de qualquer tarefa de fabricar ou construir. É a 8ª entrega depois da rodada C.

**O que precisa estar pronto:** rodada C (E0), `ServerRules` e Utahraptor nas tocas (E1), navegação (E2), âncora e ataque ao dormindo (E3a, E3b), fome leve e desmaio com o caído como alvo (E4), corpo e respawn por região (E5). Mais: binários exportados pelo CI (INF-06/07, já existem), roteiro e formulário do COM-02 adaptados pela `SHIRO`, 3 pessoas.

**O que o QA-01a responde (e só isso):** (1) a vigília da doma tem tensão ou o loop muda antes de seguir (decisão registrada, como no plano); (2) duração do desmaio: 8 s ou 20 s; (3) fome a 0,1/s é lenta demais numa sessão de 30 min; (4) Campina como núcleo seguro funciona; (5) o corpo de 10 min é suficiente.

**O que ele não responde:** slots, bolsas, montaria, noite, Dodo como primeira doma, Neutro. A proposta da `SHIRO` diz que o QA-01a "ganha as perguntas de torpor, noite, montaria e slots", mas montaria depende de CRI-07, CRI-43, CRI-45 (e CRI-06 para o Triceratops) e slots dependem de PRO-04/05, CON-02 e PRO-06: isso empurraria o playtest para depois da E19b. Essas perguntas vão para a **QA-01 rodada 1** (depois da E19b), que já está no escopo (QA-01 tem 2 rodadas; nenhuma tarefa nova).

**Antes do QA-01a nada de:** fabricar, construir, noite. Noite sem abrigo é só punição e contaminaria a resposta da pergunta 1.

## 3. O que depende de pessoas ou de arte e roda em paralelo

| Item | Quem | Pronto antes de | Observação |
|---|---|---|---|
| ARQ-05 desenho do `ServerRules` | `KURAMA` | E1 | lista das chaves do GDD 13 que as etapas E1 a E21 usam |
| Reescrita do CRI-06c (Dodo domável) e torpor máximo do Dodo | `SHIRO` | E13 | sem isso o `SORA` implementa o Dodo do plano (sem domar) |
| Peso da Ração; nós de Tubérculo-lanoso e Sal-de-veio na ilha | `SHIRO` | E14a | hoje "usei 0" |
| Confirmação do Afeto inicial <= 20 (montar exige alimentar) | `SHIRO` | E16a | |
| Roteiro e formulário do QA-01a; 3 testadores | `SHIRO` + dono | QA-01a | |
| ART-09 Saco e Cama (2 sprites, 2 ícones) | `YATORA` | E12 | |
| ART-17 Dodo 16x16 | `YATORA` | E13 | placeholder até o artista |
| ART-17 Triceratops 48x48 | `YATORA` | E15 | placeholder |
| ART-18 pose sentada 4 direções | `YATORA` | E19a | placeholder; final depende do sprite do artista |
| ART-02 ícones (17 receitas, fome, torpor, Fogueira, Cesto, Mochila) | `YATORA` | progressivo: E7b, E11b, E12 | até lá, ícone genérico |
| ART-03 SFX (sem aviso de quebra; com loop de chuva) | `YATORA` | E21 | |
| ART-16 6 formações rochosas | `YATORA` | E22 | independente de código |
| ART-06 dinos finais | artista (D12) + dono | E22 | começa depois do QA-01a (R42); briefing por porte do `ESTILO.md` está desatualizado: `YATORA` atualiza antes de briefar |
| COM-04 landing | `BULMA` + dono | E23 | pode começar já |
| COM-05 glossário e varredura de nomes | dono + `SHIRO` | E23 | pode começar já; a varredura final só no fim |
| COM-03 README e CHANGELOG | `BULMA` + dono | E23 | depois do QA-01 rodada 1 |
| INF-08 release por tag | `SAITAMA` | E23 | pode ser preparado em paralelo e só disparado no fim |
| QA-01 rodadas 1 e 2: 3 a 5 testadores | dono + `LEVI` + `SHIRO` | depois da E19b e na E23 | agendar com antecedência; é o gargalo humano |

Tudo de arte é placeholder até o artista; nada bloqueia código, exceto a pose sentada (E19a) que precisa existir para a montaria ser legível.

## 4. Critério objetivo de "MVP fechado" (push na main)

Todos os itens abaixo verificáveis; nenhum "quase":

1. **Escopo:** cada uma das 61 tarefas tem aceite aprovado pelo `LEVI` em commit, ou corte registrado pelo dono no `PLANEJAMENTO.md` (decisão com D numerada). Zero tarefa "em andamento".
2. **Validação:** `tools/check.sh` verde no commit candidato; export de binários pelo CI sem erro; INF-09 com 60 fps e 32 dinos ativos no hardware mínimo.
3. **Loop completo por terceiro:** na QA-01 rodada 2, pelo menos 2 de 3 testadores, em save novo e sem ajuda, completam os seis verbos numa sessão: coletar, fabricar a Lança, construir o abrigo mínimo, passar uma noite inteira vivo, domar um Dodo, domar e montar um Utahraptor. Sem crash e sem save corrompido.
4. **Save:** fixture v5 completa; migração v4 para v5 testada; roundtrip de todo `to_dict`/`from_dict`; QA-03 com todos os casos do GDD 12.4.
5. **Dados:** nenhum número de balanceamento em código (teste de arquitetura); todo [premissa] da `SHIRO` tem valor em `Resource`/JSON e foi revisto depois da QA-01 rodada 2.
6. **Arte:** `game/assets/CREDITS.md` sem linha `IA-placeholder`, ou decisão do dono registrada aceitando placeholder específico na v0.2 (regra 8 do `AGENTS.md`). Toda linha com autor e licença.
7. **Nomes:** COM-05 passado: varredura sem termo alheio (lista do glossário) em todos os arquivos; teste automatizado se a lista existir.
8. **Bugs:** lista do `LEVI` sem item Must aberto; itens Should documentados no CHANGELOG como conhecidos.
9. **Documentos:** README do jogador, CHANGELOG, landing (COM-03, COM-04) revisados pelo dono; `PLANEJAMENTO.md` com o M2 fechado.
10. **Release:** INF-08 gera tag `v0.2.0` com binários e checksums a partir do commit da main.

O item 6 é o único que depende de alguém de fora. Se o artista atrasar, o dono decide entre esperar ou registrar a exceção; o push não acontece com placeholder sem decisão escrita.

## 5. Crítica: 61 ainda é muito? O que mais cortar, e o que está quebrado na proposta

**Sim, é muito para "uma entrega jogável por etapa".** O peso não está no número: está em 3 pacotes (slots, montaria, dia e noite) que tocam entrada, câmera, inventário, UI e save ao mesmo tempo, como a própria `SHIRO` diz. Os cortes dela (pontos, validade, Cocho, Stamina, dano em parede, Preparado, Parassaurolofo) tiraram sistemas de número; o que ficou é sistema de interação, que é o que reprova em revisão.

### 5.1 O que eu cortaria a mais, sem tocar nas decisões do dono

Em ordem de alívio:

| # | Corte | Sai | O que o jogo perde | Toca decisão do dono? |
|---|---|---|---|---|
| 1 | **Triceratops para a v0.3** | CRI-06, E19b (metade do CRI-45), ART-17 Triceratops, Ração A, 8 deslocamentos viram 4 | a doma grande e a segunda montaria; a Pedreira passa a ter tocas de Utahraptor de nível alto (faixa 15 a 35 já existe) | não: "montaria em Médio ou maior" vale com o Utahraptor (Médio). Toca a recomendação de elenco da `SHIRO` (decisão 1 dela), ainda não tomada pelo dono |
| 2 | **Durabilidade para a v0.3** | PRO-16, barra no tooltip, ícones e sons de quebra | ferramenta não quebra; a fabricação recorrente fica só na Ração | não |
| 3 | **UIX-15 (atalho de Ração no dino)** | UIX-15 | alimenta pelo menu do domado (CRI-43) e pelo painel de domar que já existe; o plano 4.13-I já o marcava cortável | não |
| 4 | **ART-16 formações rochosas** | ART-16 | marcos ficam com o placeholder da rodada C | não (se o placeholder for CC0 do pacote, não fere a regra 8) |
| 5 | **CRI-27 batismo** | CRI-27 | dino sem nome próprio até a v0.3 | não |
| 6 | **UIX-04 diluída** | UIX-04 como tarefa | tooltips entram na E20 com a ficha; o UIX-16 já fez o HUD | não |
| 7 | **UIX-05 reduzida a 4 dicas** | 3 dicas | só as que o QA-01 rodada 1 mostrar como confusas | não |

Com 1 a 6: 61 vira 55 e some uma etapa inteira (E15), meia (E19b) e a E-extra. **O corte 1 é o único que muda a sensação do jogo**; os outros são quase só contagem. Se o dono só aceitar um, que seja o 1, e decidido antes da E14a (Ração A é só para ele).

**O que não dá para cortar sem reverter decisão:** chuva (SOB-11), alforje do dino, Mochila, ficha, Neutro, dia e noite, Peso. A `SHIRO` propõe "primeiro a chuva" como gatilho de corte; **conflita com a decisão "dia e noite e chuva"**. O gatilho de corte válido é o Triceratops (montável e espécie), não a chuva.

### 5.2 Conflitos e dependências quebradas na proposta da `SHIRO`

1. **QA-01a com perguntas de montaria e slots** (seção 1, linha QA-01a; seção 6): incompatível com "QA-01a <- CRI-12" e com o pedido de playtest cedo. Resolvido na seção 2: essas perguntas vão para a QA-01 rodada 1.
2. **"Cortar a chuva primeiro"** (seção 6 e decisão 6 dela) contra a decisão do dono. Ver acima.
3. **MUN-03 circular:** "falta semear Dodo, Utahraptor e Triceratops", mas CRI-06c e CRI-06 dependem de MUN-03 e as espécies dependem de existir. Resolvido: semear na etapa de cada espécie (E1, E13, E15).
4. **Dependências do plano que morreram com o corte** e precisam sair da tabela 4.3 quando o dono aprovar: PRO-09 <- CRI-08 (Carregar saiu); PRO-11 <- PRO-09 (sem pontos, sem "+3 kg"); SOB-06 <- CRI-08 (sacolinha saiu); CRI-43 <- PRO-14b (Cocho saiu); PRO-18 <- PRO-17 e SOB-07 <- PRO-17 (validade saiu); QA-01a <- SOB-08 (Stamina saiu); SAV-04b <- SOB-13 vira "<- SOB-13 ou depois". Nenhuma impede a ordem acima; todas enganam quem ler a tabela.
5. **ARQ-05 sem posição:** está no FICA sem ordem, mas CRI-12, SOB-05, SOB-12, CRI-27, SOB-03 e CRI-07 leem o `ServerRules`. Tem de ser a E1.
6. **Alimentar duas vezes:** UIX-15 "única forma" de alimentar o domado e CRI-43 com "Alimentar" no menu. Uma só; recomendo cortar UIX-15 (5.1, item 3). Se o dono preferir a tecla, tirar do menu.
7. **Alforje: "4 slots" (dono) contra "até 4 por porte: 1, 2, 4" (`SHIRO` 4.7):** recomendo 4 para todos na v0.2; a tabela por porte é dado e pode entrar depois sem código.
8. **SOB-15 e SOB-16 "provisórios"** não têm linha na tabela 4.3, não têm aceite nem dependências. Propus aceite do SOB-15 na E4; o SOB-16 é "Descartar pilha com confirmação, validado no servidor, nunca em item da vaga Arma". Precisam entrar no `PLANEJAMENTO.md` quando o dono aprovar (não fiz: sem editar o repositório).
9. **CRI-06c:** o texto da tabela 4.3 diz "sem torpor e sem domar"; a proposta diz "primeira doma". A reescrita não existe em nenhum documento, e o torpor máximo do Dodo (quantos Socos até dormir) não foi dado. Bloqueia a E13 até a `SHIRO` entregar.
10. **Save:** SAV-02 fala em "save v2" e SAV-03 em "v5"; a branch está em v4. Oito etapas criam estado persistente. Sem a regra "v5 aberto" da seção 0, cada uma vira migração e revisão. Confirmar contra `documentacao/contexto/save.md`.
11. **SAV-04b gatilho "morte de dino domado":** com SOB-05, domado não morre. Vira "domado sumiu".
12. **Afeto inicial `round(E/5)` <= 20 e limiar único 25:** nenhum domado obedece nem monta logo após a doma; precisa de 2 Rações B. Pode ser intenção (vínculo), mas a proposta não diz. Confirmar antes da E16a.
13. **ART-18 depende do sprite final do artista** (cabeça ou cauda sobre o dorso muda a pose para 8 sprites): o cavaleiro não fica final antes do ART-06. O critério de MVP (item 6) precisa de decisão do dono sobre aceitar placeholder aí, ou o push espera o artista.
14. **Barra de atalhos** "só entradas existentes" com teclas 1 a 9, cinto de 4 e vaga Arma: a proposta não diz a ordem das entradas (cinto primeiro? slots primeiro?). Definir no spec da E11a antes do `SORA`; é o tipo de ambiguidade que gera 2ª revisão.
15. **Fogueira "luz de 4 tiles"** está no SOB-03, mas a Fogueira é do PRO-18: a luz entra na E12, não na E9. Só ordem, sem conflito.
16. **E8b, dino preso dentro do abrigo recém-fechado:** com CON-05 fora, ele não quebra parede e não sai. Caso conhecido a documentar, não a resolver na v0.2.

### 5.3 Os 3 maiores riscos da ordem

1. **Slots (E11a/E11b):** a mudança mais ampla de UI e inventário, e o maior risco de design da `SHIRO` (frustrar em vez de desafiar). Mitigação: dividido em dois, Baú antes, números em dado, QA-01 rodada 1 logo depois da montaria.
2. **Montaria (E19a/E19b):** entrada, câmera, colisão de 48 px e uma pose de arte que só fica final com o artista; e pode não valer a pena (+36% sobre correr). Mitigação: Utahraptor primeiro; Triceratops é o corte número 1.
3. **Arte final do artista como bloqueio do push:** regra 8 proíbe placeholder de IA na v0.2 e o artista só entra depois do QA-01a. Mitigação: briefing por porte atualizado pelo `YATORA` logo após o QA-01a; decisão escrita do dono sobre exceções antes da E22.

Risco de execução logo atrás: **E17 (Neutro + SOB-15 + CRI-12)**, três IAs se cruzando; é onde eu esperaria a próxima "etapa B".
