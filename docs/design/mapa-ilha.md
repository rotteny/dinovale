# Mapa do MVP: a ilha em meia-lua

Autora: `SHIRO`, 06/11/2026 (refeito com a ilha irregular e grande). Complementa `GDD.md` (4, 4.1, 5.1, 12.2, 12.4) e o plano (MUN-01, MUN-02, MUN-03, INF-09, SOB-12). **[proposta] é minha e depende do dono.** [calculado] saiu de `mapa_sim.py` (biblioteca padrão; `python3 mapa_sim.py 256 tudo`; o lado é parâmetro). [jogar] só playtest responde. [premissa] é número sem medição.

**Originalidade.** A forma é uma meia-lua (diferença de dois discos) deformada por ruído fractal com semente fixa; os lugares e nomes são escolhas minhas pela regra de jogo. Não consultei mapa de nenhum jogo.

## 1. Nome da ilha (decisão do dono, 06/11)

**Lunata** (latim para "em forma de lua"). **Nome decidido pelo dono (06/11).** Os lugares usam "Lunata".

## 2. Tamanho, forma e peso (o que mudou: a ilha é grande e irregular)

**Forma.** Meia-lua aberta para o leste, **sem curva regular**: a conta é `min(R1 - d1, d2 - R2) + 0,09 x S x ruído`, com ruído fractal de 5 oitavas (onda base S/5, até ~S/80 de detalhe) e uma queda suave perto da borda para manter a margem de mar. O ruído recorta a costa (reentrâncias, pontas, penínsulas) e, **por cima**, 9 ilhotas (21 a 128 tiles) em água funda, de 6 a 22 tiles da costa: cenário, sem acesso na 0.2 (gancho para barco). Razão costa/raiz(área) de 7,4 contra 3,5 do disco perfeito. A semente fica no dado; a máscara sai de `python3 mapa_sim.py 256 mascara`.

**Tamanho fixo: 256x256 (decisão do dono, 06/11).** O mapa é **um só, contínuo**: sem quadrantes, sem troca de tela e sem teleporte; o que está longe do personagem não é desenhado nem pensado (zona ativa abaixo). [calculado, `mapa_sim.py 256`]:

| Medida | Valor |
|---|---|
| Terra | **21.383 tiles (33%)**; ilha principal 20.902, 9 ilhotas |
| Maior trajeto a pé (início até a ponta norte) | 282 tiles = **64 s** (54 s com sprints) |
| Dinos | **360** (1 a cada ~59 tiles de terra), ver seção 5 |
| Nós de recurso | ~732 coletáveis |
| Tiles por camada | 65.536 |

Trajeto = do início à ponta mais distante pelo arco, a 70 px/s (4,375 tiles/s). O "~30 s" da ilha de 128 vira **~1 min**: a linha reta por cima da enseada é de 164 tiles, mas passa por água funda, então o arco é obrigatório. A câmera de 320x180 não muda o tempo de caminhada, só mostra menos do caminho de uma vez: a ponta norte está a **1 min e 4 s a pé** do início, e o campo de visão cobre ~4,6 s de caminhada na horizontal. As ilhas de 192 e 384 que o texto anterior comparava saíram (decisão do dono); o gerador segue aceitando qualquer lado.

**Margem de mar até a borda do mapa [calculado].** A câmera fica **centrada e anda com o personagem; só para quando chega ao limite do mapa**. Para que nunca pare na prática, o ponto mais afastado que o personagem alcança (terra, praia ou raso) precisa estar a pelo menos meia tela da borda: **10 tiles na horizontal e 5,6 na vertical**. O gerador impõe `MARGEM` = 15 tiles de borda até a terra firme (a terra pode chegar a 15, o raso anda 3 além, a água funda bloqueia): resulta em **12 tiles mínimos do caminhável à borda (esquerda 12, topo 12, direita 14, base 14)**, 1,2 meia largura e 2,1 meia altura. Antes da regra a ponta leste chegava a 0 da borda e o norte a 3. A faixa de 12 tiles (e o resto do mar funda, 40.733 tiles) existe **dentro** do mapa de 256; não há mar desenhado além dele. **Pós-MVP, sem marco e fora da 0.2 (dono, 06/11):** barcos e dinos que cruzam o mar. Como o mar é parte da grade (não há água fora dela) e a colisão da água funda é um dado do anel de 2 tiles, a travessia depois só troca essa regra e abre rotas às ilhotas e a outras ilhas; a boca leste da enseada e as 9 ilhotas já são o gancho.

**Peso [calculado, `mapa_sim.py peso`; bytes são premissa]:** O mapa tem 65.536 células x 3 camadas x ~32 B = **6,3 MB**; grade do `AStarGrid2D` de 65.536 pontos ~**6,6 MB**, montada em 0,07 a 0,2 s; save: nós esgotados ~9 KB, dinos ~54 KB (360), máscara 8 KB. Memória de dinos: 360 x ~0,5 KB = ~180 KB na RAM e ~54 KB no save (150 B cada); nós 9 KB. **Total ~13 MB, sem chunking de terreno**: o `TileMapLayer` só desenha o que a câmera vê e nada aqui chega perto de memória que obrigue a dividir. **Dois ajustes no desenho, ambos de dado:** (1) colisão da água funda **só no anel de 2 tiles junto ao raso** (~4 mil tiles), não nos 40 mil tiles de mar, que são inalcançáveis; (2) o cenário (só as formações rochosas fixas) vai na camada de tiles; os nós coletáveis são `Node2D`. **Medido em 06/11 com 1.326 nós (1.029 árvores):** carga 299 ms (era 260 com 578 nós), +83 MB de memória estática no total (era +62), física 4,6 ms por quadro (era 2,5), save de 4,3 ms, 12 mil nós na árvore; não pesou o bastante para criar o nó só perto do jogador (se um dia pesar: criar na zona ativa, mantendo o id estável e os esgotados no save).

**60 fps e o plano.** O que pesa são os dinos, não os tiles. **O plano precisa de um item novo, que não é chunking:** uma **zona ativa por raio** (`MUN-05`, proposta): dino a até **16 tiles** do jogador tem IA e física completas (tela de 320x180: meia diagonal 11,5 + 4,5 de margem; era 24 a 640x360); de 16 a **40** tiles fica **distante** (sem física, posição em dado, passeio a cada 2 s); acima disso **dorme**. Quem persegue (Agressivo, até 20 tiles) ou foge fica ativo pelo estado, não pelo raio (só dados no save). Teto `dinos_ativos_max` = 32: passado dele, os mais distantes viram distantes. [calculado] **no 256 com 360 dinos (1 a cada 59 tiles): 13,5 ativos em média e ~27 no pior caso (2x a média), abaixo do teto de 32; ~71 distantes**; a 186 dinos seriam 7 e ~14. **Precisa jogar:** 27 ativos sobem a 32 em manada perto de toca. [premissa, medir no INF-09] 25 µs por dino ativo por quadro = 0,8 ms de 16,7 ms; refazer caminho no máximo 1 vez por segundo por dino, ~0,2 ms por A* de 100 tiles em C++ = 0,04 ms por quadro; percepção a cada 0,5 s com grade de 8 tiles: centenas de checagens por segundo. **INF-09 muda de "8 dinos" para "32 dinos ativos, percepção a cada 0,5 s, 60 fps no hardware mínimo".** **O chunking do MUN-10 continua no M4**: só é necessário para mundo bem maior que 256 ou para várias ilhas.

Esboço do mapa de 256 (1 caractere = 4 tiles de largura x 8 de altura; norte em cima; a enseada é o vazio à direita do arco; `o` ilhotas). Legenda: `:` Campina, `%` Mata-baixa, `#` Pedreira, `,` praia, `~` água rasa, branco água funda; `@` início, `p` Paquicéfalo do tutorial, `q` Paquicéfalos do Limiar, `A` Arco-da-Enseada, `L` Pedra-do-Aviso, `U` toca de Utahraptor (6), `D` zona de Dodo (6), `T` Triceratops (8), `s` Sal-de-veio, `G` Portal-de-Pedra.

```

               oooo~                            ~o~
               oooo~    ~~~~~,,,,,,~~   ~~~    ~ooo~
            ~oo~  ~,,,,,,########s###,,,#s#,,,~ ~~~
            ~oo~,,##T################T######T##T,,,~~~
             ~,##########T###############,###########,,
           ~~,#################T#####,~oooo,,,,~~,,#T,,oo~
   oo     ,####T#################,,~ooooooo~      ~~~~ ~oo~
   oo~~,,,%%%%%%%%%%%%%U%%%%%%%,~  ~oo~
   ~~ ,%%%%%%%%U%%%%%%%%%%%%%%~
    ~,%%%%%%%%%%%%%%%%%%%%%%%,
    ~%%%%%%%%%%%%%D%%%%%%%%%%~
    ,%%D%%%%%%%%%%%%%%%D%%%%,~
   ~,%%%%%%%%%%%%%%%U%%%%%%%,
    ,%%%%%U%%%%%%%%%%%%%%D%%~
     ~,%%%%%%%%%%%%%%%%%%%%~
      ~U%%%%D%%%%%%%%%%%%%,~
     ~,%%%%%%%%%%%%%%%%%%~
     ~,%%%%%%%%%%U%%%%D%,~
      ~,%%%%%%%%%%%q%%%L,~
       ,::::::::::::::::::,
       ~,:::::::::::::::::,,                            ~ooo
        ,:::::::::::::::::::,~~                         ~ooo~
        ~::::::::::::::::::::Ap,,,,,,,~               ~~~,:,~
         ,:::::::::::::::::::::::::@:::,,,,~~~~~~~,,,,,::::~
          ~:::::::::::::::::::::::::::::::::::::::::::G::,,
           ~,,::::::::::::::::::::::::::::::::::::::::::,~
              ~~~~~~,::::::::::::::::::::::::::::::::,,~
                     ~~~~,,:::::::::::::::::::::::oo~~
                           ~,,,,::::::::::,,,,,~~~ooo
                                ~~~~~~~~~~        ~~
```

Faixas de bioma (retângulos para `respawn_regioes`; o desenho de tiles mistura as bordas): **Pedreira y<64, Mata-baixa 64 a 159, Campina y>=160** (terra: 4.608, 8.108 e 8.667 tiles; sorteável 3.991, 7.876 e 8.145). Com a borda irregular de ruído, a terra medida no `lunata.json` é Pedreira 3.661, Mata-baixa 7.610 e Campina 8.012 tiles; as contagens de nós da seção 8 são as reais do arquivo.

## 3. Mar, câmera e névoa

| Camada | Regra [proposta] |
|---|---|
| **Praia** (terra a até 2 tiles do mar; 2.100 tiles) | Caminhável, velocidade normal, pode construir; sem nó de recurso e sem spawn. |
| **Água rasa** (até 3 tiles além da praia; 3.420 tiles) | **Caminhável sem lentidão por jogador e dinos** (não vira refúgio contra o Utahraptor). Proibido construir, spawn, nó e respawn. |
| **Água funda** (40.733 tiles; o personagem para nela, a pelo menos 12 tiles da borda) | **Bloqueia** (colisão só no anel de 2 tiles junto ao raso). **Sem nado na 0.2** (GDD 6.1). Mar sem lógica. |

**Decidido (dono): água rasa sem lentidão.** **Risco [jogar]:** Covarde fugindo contra a água funda para e vira presa fácil.

**Câmera e névoa [decisão do dono, revista 06/11]:** a câmera **fica centrada no personagem, anda junto e só para quando atinge o limite do mapa** (`limit_*` do Camera2D = os 256 x 256 tiles). **Viewport 320x180 (20 x 11,25 tiles), 4x em 1280x720 e 6x em 1920x1080.** Não há mar desenhado além da borda; a margem de 12 tiles de mar dentro do mapa (seção 2) garante que a câmera não pare na prática. A **névoa é um efeito leve nas bordas da tela** (moldura translúcida de ~2 tiles presa à câmera), não de exploração; não muda o MUN-03.

## 4. Regra de mundo: sem construção humana no cenário [decisão do dono]

GDD 4.1. Só natureza e formações rochosas; casa, vila, ruína, estrada, cerca, ponte, poço, baú e placa só se o **jogador** construir. **Trilhas naturais** (terra batida por bicho, 1 a 2 tiles, borda orgânica) valem; estrada, não. Marcos [proposta]:

| Marco | Onde (tile em B) | Papel |
|---|---|---|
| **Arco-da-Enseada** (arco de pedra) | (119,185), praia, 26 tiles de caminho do início | primeiro marco |
| **Pedra-do-Aviso** (pilar solitário) | (92,158), a 26 tiles da toca U1, logo fora da âncora | fim do refúgio, visível de longe |
| **Portal-de-Pedra** (duas formações de ~8 tiles) | (216,207), pescoço de 22 tiles da ponta sul, vão de 4 | curral natural (seção 7) |
| **Cabo-Salgado** (rochedo e veios de sal) | ponta norte da Pedreira | destino da Pedreira |
| **Gruta** (natural) | Mata-baixa | local do fóssil, se o 20.8 entrar |

Formação rochosa = obstáculo com colisão que molda visão e fuga. Saem no MUN-01 a **casa e o baú decorativos** de `Terrain.tscn` (feito pelo `SORA`; não toquei em `game/`).

## 5. Início, biomas, respawn e dinos

**Início [proposta]:** Campina sul, praia da Enseada-Quieta, (140,196).

**Respawn (`respawn_regioes`):** retângulos acima. Pontos reserva iniciais [proposta, ajustar no MUN-03]: Campina (124,200), na Campina e a mais de 8 tiles de qualquer paquicéfalo (o exportador reserva essa folga); Mata-baixa (98,132), a 33 tiles da toca mais próxima; Pedreira (120,25), a 27 de um Triceratops. [calculado, 3.000 simulações, 6 tocas com bando de 1 a 2, ronda de 10, 30 sorteios, distâncias do 12.2] um sorteio é recusado em 2% (Campina), 55% (Mata-baixa) e 41% (Pedreira); **o ponto reserva sai em 0,00% dos casos nas três** (a ilha grande dilui as tocas: as regiões têm 4.000 a 8.300 tiles, o 12.2 calculava ~4.900).

**Dinos (elenco fechado da 0.2, sem espécie nova) [proposta]:** **360, 1 a cada ~59 tiles de terra, ~3,8 no campo de visão de 320x180** (a 186 seriam 1,9).

| Espécie | Faixa de tamanho | Qtde | Onde |
|---|---|---|---|
| **Dodo** | diminuto (16 px) | 140 | 10 zonas de 14 (grupos de 3 a 5, Covarde domável: fogem juntos a 8 tiles, GDD 6.1b) na Mata-baixa, entre elas: (88,144) dentro da ronda de U1, (92,96), (48,128), (72,88), (28,100), (100,116); respawn 10 min |
| **Paquicéfalo** | pequeno (24 px) | 108 | núcleo 20 (teto L8, tutorial em (123,188)), Campina 40 e Limiar 12 (L9 a 12), Mata-baixa 36; grupos de 1 a 3 |
| **Parassaurolofo** | médio (32 px) | 94 | 20 manadas de 3 a 5 na Mata-baixa, espaçadas >= 14 tiles |
| **Triceratops** | grande (48 px) | 8 | Pedreira, solitários L18 a 24 em (60,56), (80,36), (100,44), (124,52), (150,32), (176,36), (191,39), (208,48) |
| **Utahraptor** | médio (32 px), ameaça | 6 a 11 | 6 tocas na Mata-baixa: U1 sentinela (1); U2 a U6 bandos de 1 a 2 |

Faixas por porte (GDD 4.2), 360 dinos (Dodo 140, Paquicéfalo 108, Parassaurolofo 94, Triceratops 8, Utahraptor 10): **diminuto 39% (140), pequeno 30% (108), médio 29% (104), grande 2% (8)**, muito grande e gigante 0%. A pirâmide é a de uma ilha de herbívoros pequenos com poucos gigantes; o grande tem 8 indivíduos (a ameaça e o tutorial de domar grande). **Seis portes, quatro com espécie:** o dono definiu seis (GDD 4.2); os dois maiores só existem na tabela, sem espécie na 0.2; some a variação de tamanho **por nível** (escala visual 0,85 a 1,15 do sprite). **Decidido (dono): mais faixas de tamanho de dino entram depois do MVP**, sem marco: o Listro (M4) e espécies novas nos portes Muito grande e Gigante da tabela do GDD 4.2.

**CPU:** a zona ativa (seção 2) é o que mantém o custo: só ~13,5 dinos pensam em média (raio 16), ~27 no pior caso, os de 16 a 40 tiles só andam em dado, o resto dorme.

## 6. Refúgio x vigília (H1): opção A, decisão do dono (06/11)

O dono quer um refúgio; o H1 do plano exige o Utahraptor atacando o dino dormindo (CRI-12). As duas coisas cabem se o refúgio for **uma zona**. **Decidido: opção A.** As opções B e C ficam só como registro do que foi descartado:

| | **A (decidida)** | B (descartada) | C (descartada) |
|---|---|---|---|
| Ideia | **Núcleo seguro + Limiar de risco** | Sem zona segura | Carnívoro só na Pedreira |
| Regra | raio **16** do início sem toca nem spawn de Agressivo; Utahraptor com **âncora de 24** da toca (ronda 10) | tocas dentro da Campina | Utahraptor só na ponta norte |
| H1 | Paquicéfalos do **Limiar** a 11 tiles da toca U1: ele fica a <= 8 tiles do dormindo em **23% do tempo** de ronda | tensão em todo domar | **H1 morre** no Paquicéfalo |
| Mudança no plano | âncora no CRI-12 | nenhuma | nenhuma |

[calculado] a toca mais próxima (U1) está a 86 tiles do início, e a borda da âncora a **62 tiles** do início: o refúgio real é o sul inteiro da Campina, bem maior que o raio 16 (que fica como mínimo de regra, nunca escala com o mapa). Sair da âncora de U1 a partir do Limiar custa 13 tiles = 3,0 s a pé; o Utahraptor (5,6 tiles/s) para na âncora. Sem a âncora o núcleo seria só aviso: a perseguição do 6.7 vai a 20 tiles ou 15 s (~84 tiles). **U1 é o primeiro Utahraptor domável:** a 92 tiles do início (21 s), com a zona de Dodo ao lado. `nucleo_seguro_raio` configurável (0 liga a opção B). **[jogar]:** se 23% basta para a vigília e se 62 tiles de refúgio deixam a Campina vazia de perigo por tempo demais.

## 7. A enseada e o curral natural

- **Orientação:** a ponta norte vê-se do início por cima da água (164 tiles); o jogador sabe aonde vai.
- **Obrigar o arco:** a água funda no meio faz do trajeto uma jornada (64 s) com Campina, Mata e Pedreira em ordem de perigo.
- **Refúgio:** o início fica na praia dela; é o trecho de mar sem ameaça.
- **Curral natural (Ponta-Manso):** o Portal-de-Pedra deixa um vão de 4 tiles num pescoço de 22 e fecha **304 tiles** de terra firme com água dos três lados: **3 Cercas + 1 Portão = 10 madeira (2 por peça; Portão 4) = 27 s de coleta**, contra 73 peças e 147 madeira (6,5 min) para um curral de mesma área em campo aberto [calculado]. Fica a 81 tiles de caminho do início (19 s), dentro do refúgio.
- **Gancho futuro:** a boca para o leste é a saída por barco do mapa completo; na 0.2 não existe.

## 8. Recursos, nós, Soco e começo do jogo

**Valores do código** (`game/data/resources/*.tres`): árvore 3 madeira em 8 s, volta em **480 s**; pedra 4 em 10 s, **600 s**; baga 3 em 9 s, 240 s. O GDD 10 dizia 5 e 8 min: adotei os do código. As contagens são as da ilha de 128 multiplicadas pela terra de cada bioma (Campina x4,33, Mata x4,10, Pedreira x3,47).

| Nó (id) | Rende por colheita | Total na ilha (B, contagem real do `lunata.json`) |
|---|---|---|
| Árvore coletável (`tree`) | 3 madeira, 8 s, volta em 480 s | **1.029** (todas as árvores; 1 a cada 19 tiles de terra) |
| **Arbusto de baga** (`bush`, variante `baga`) | 3 Baga **+ 2 Fibra**, 12 s, volta em 240 s | 91 |
| **Arbusto-do-sono** (`bush`, variante `sono`) | 3 Cochilo **+ 2 Fibra**, 16 s, volta em 420 s | 40 |
| Pedra (`rock`), **só com Picareta** | 4 pedra, 10 s, volta em 600 s | 142 |
| **Pedra avulsa** (`loose_stone`) | 1 pedra, 1 s, **à mão, sem dano**; volta em 300 s (núcleo) ou 600 s | 24 |
| Samambaia (`fern`, novo) | 3, 12 s, 240 s | 76 |
| Tubérculo (`tuber`, novo) | 2, 16 s, 420 s | 51 |
| Sal-de-veio (`salt_vein`, novo) | 2, 20 s, 480 s | 28 (Pedreira) |
| **Pedra de minério / filão de ferro** (`iron_seam`, **M4**) | 2 minério por colheita de 14 s, mais 1 pedra e 1 sílex; volta em 900 s; a Picareta rende 4 minério por colheita (GDD 5.9c) | 18 (Pedreira, flanco leste; M4, o jogo não instancia) |

**Árvores (decisão do dono, 06/11): TODAS são coletáveis**, para liberar área de construção; não há árvore de cenário (a antiga proporção de 1 coletável para 3 de cenário saiu, e `tree_decor` saiu do mapa e do exportador). O total por bioma é o de antes (coletáveis mais as de cenário de então): **1.029 árvores**, em bosquetes de 2 a 4, nenhuma sobre o início. A variedade visual vem das variantes da própria árvore (espelhada e em 4 tons, pelo id do nó). **Só as formações rochosas seguem fixas**, como marcos (obstáculo com colisão, sem interação): a distinção que o jogador precisa fazer é rocha coletável contra formação fixa. O nó coletável ao alcance ganha **contorno claro e o nome do que rende** ("Árvore: Madeira", "Pedra"); a formação fixa nunca ganha nada. Coletado, **todo nó some por inteiro** (desenho e colisão: o tile fica livre para construir) e volta pelo respawn do tipo **só se o lugar estiver livre** (jogador e dinos; consulta única `TileOccupancy`, que a grade de construção usará); ocupado, espera esgotado e tenta de novo a cada 0,5 s, sem se perder do save. A colheita parcial ainda não some.

**Arbusto único (decisão do dono).** Um nó rende fibra e a fruta do seu tipo. Colhido por inteiro, **some** (como os outros nós; revisão de 06/11, o desfolhado deixou de existir) e volta cheio, fruta e fibra juntas, num só relógio e só com o lugar livre; a colheita parcial não some. Com Peso cheio (regra da 0.2) o que sobra fica no arbusto. A planta de fibra separada deixa de existir. Fibra: 270 por passada no mapa inteiro (135 arbustos x 2) contra a demanda de 23 no kit inicial.

**Frutas.** **Baga** (comestível) continua: é o nome do `racao.md` (Ração Verde = Baga + Samambaia; Baga crua para o Paquicéfalo). A outra se chama **Cochilo** (decisão do dono, 06/11; vira verbo; o arbusto pode ser a Cochileira). Palavra comum da língua, como o `catalogo.md` pede. A Baga conta como refeição, o Cochilo não (GDD 5.5); cores e silhuetas distintas; "Preparado de sono" e afins ficam (são o efeito). O renome nos documentos só depois da escolha.

**Soco e pedras avulsas (decisão do dono; números meus).**
- **Soco na árvore:** coleta (3 madeira em 8 s, **0,375 madeira/s, metade do Machado de pedra** com 0,75/s) e causa **1 de dano ao personagem por colheita completa** [proposta; por golpe seriam ~13 por árvore]. Stamina 4/s (32 por árvore, regenera 15/s: não esgota). Soco no arbusto: coleta sem dano (colher à mão).
- **Soco na pedra (nó `rock`):** 1 de dano por toque, **não coleta**; mensagem "só a Picareta quebra pedra". Exige `ferramenta_minima` no nó.
- **Pedra avulsa:** fica no chão, pega-se à mão (1 s, sem dano, sem ferramenta). São a base do Machado (2 pedra) e da Picareta (3 pedra).
- **Soco em dino (decisão do dono, 06/11: opção B).** Dino vivo: dano 1 e torpor 10 nele e 1 de dano ao personagem; carcaça coletável à mão (3 s por carne, 6 s por couro) com 1 de dano por item (GDD 5.9b e 5.6). Entra no SOB-06.
- **O Soco pode matar o personagem? Não:** o dano a si mesmo **para em 10 de vida** (o Soco continua funcionando, sem dano). Sem morte boba e sem softlock.
- **Coleta por golpe ou por E?** **Segue por E** (segurar, barra de coleta, `request_gather`): a animação é de soco; o dano é 1 por colheita completa e 1 por toque em pedra. Por golpe mudaria a API, o ritmo (13 golpes por árvore) e o dano.
- **Quantas pedras avulsas, onde, e voltam?** **24 [calculado]:** 10 no núcleo (voltam em 300 s) e 14 na trilha até a ponta (1 a cada 30 tiles de caminho = 10, mais 4 na entrada da Pedreira; voltam em 600 s). Precisa-se de 5 para o primeiro Machado e a primeira Picareta. **Sem softlock:** 3 madeira + 3 pedra + 1 fibra (Picareta) e 3 + 2 + 1 (Machado) = 6 madeira (2 árvores no Soco), 5 pedras avulsas, 2 fibra (**1 arbusto rende 2**). Pior caso: gastar as avulsas na Fogueira, Bancada e abrigo antes da Picareta (11 pedras) só **atrasa** até 5 min (as 10 do núcleo voltam); as 3 pedras de nó no núcleo já existem depois da Picareta.

**Primeiros 5 minutos [calculado, `mapa_sim.py inicio`, premissas de tempo no script]:** 0:12 cinco pedras avulsas; 0:25 arbusto (3 baga, 2 fibra); 0:44 duas árvores no Soco (6 madeira, -2 de vida); 0:52 Machado e Picareta prontos; 1:43 32 madeira com o Machado; 1:49 4 pedra do nó; 2:28 abrigo construído; 3:07 Fogueira e Bancada; 3:36 fibra para o Saco. A Picareta chega em menos de 1 min; o abrigo, em ~2,5 min (o GDD 8 dizia 3 a 4).

**Kit e Peso (regra da 0.2):** 59 madeira + 16 pedra + 23 fibra = 84 kg para 50 kg de capacidade: duas viagens; o abrigo (38 kg) vai numa. Nada depende da carga em faixas, do Largar, da bolsinha ou do corpo de dino (M4b, GDD 5.1b).

**Fontes M4 (decisão do dono, GDD 5.9c; fora da 0.2):** a **árvore** rende também palha (2 por colheita, 4 com a Picareta) e a **pedra comum** também sílex (1 por colheita, 2 com a Picareta), sem nó novo nem lugar novo no mapa; a quitina vem só de inseto gigante (cavernas, pós-1.0). Na 0.2 as árvores e pedras seguem como no código. **Minério (M4 a M5):** 18 barras = 36 minério + 18 carvão; os 28 filões dão 56 por passada: **1 passada** (antes 3). Instanciados só no M4; na 0.2 não existem.

## 9. Impacto no plano (v0.2)

O projeto não contabiliza horas (D31); esta seção lista só o que muda em cada tarefa do plano.

| Tarefa | Mudança |
|---|---|
| **MUN-01** | terreno por máscara, autotile de costa (praia/raso/fundo), colisão do anel, margem de mar dentro do mapa (máscara de borda), retirar casa e baú |
| **MUN-03** | biomas, 6 tocas, população por espécie e tamanho (360 dinos), geração dos nós (todas as árvores coletáveis) e do cenário (só formações) por semente, regiões, critério "início a ponta em ~1 min" |
| **MUN-02** | arbusto único, `ferramenta_minima`, Soco (dano, mensagem, piso de 10 de vida), pedra avulsa |
| **CRI-12** | âncora de 24 tiles e ronda |
| **MUN-05 (novo)** | zona ativa por raio (ativo, distante, dormente, teto 32) |
| **INF-09** | 32 dinos ativos em vez de 8 |
| **SOB-06** | Soco em dino com dano ao personagem e carcaça coletável à mão (GDD 5.9b, opção B) |
| **Câmera e névoa** | câmera centrada com limite no mapa (`limit_*`) e névoa de borda; viewport 320x180 |
| **Escala 320x180 (novo)** | HUD, atalhos, inventário e menus refeitos para 20x11 tiles (a maior parte); percepção elíptica do Agressivo e sinal de borda; colisão e caminho por porte; portão duplo; silhueta atrás de sprite grande; ajustes |
| **`YATORA`** | tiles de costa (3 transições), cenário (variantes da árvore coletável, 6 formações, arbusto cheio, pedra avulsa, ilhotas; sem árvore de cenário nem arbusto desfolhado), névoa |
| **`YATORA`, escala (novo)** | jogador 16x32 redesenhado com animações; Dodo, Paquicéfalo, Utahraptor, Parassaurolofo, Triceratops (todos com andar, parado, dormir, ferido e ataque onde há); árvore 48x80; quadro de referência dos 6 portes |

Contra o relatório da ilha de 128, a de 256 acrescenta população, zona ativa, tiles de costa e o Soco. **Cortes se faltar escopo:** ilhotas e névoa (arte do `YATORA`). Fora da 0.2 (M4b, GDD 5.1b): carga em faixas, Largar e bolsinha, corpo de dino e a arte deles; o corpo do jogador na 0.2 só muda de 20 para 10 min.

## 10. Calculado x jogar x dono

**Calculado:** forma, áreas e trajetos; peso em memória (premissa de bytes); população e raios de ativação; núcleo, âncora e lente de 23%; respawn; curral; kit; começo do jogo; pedras avulsas.
**Jogar / medir:** 25 µs por dino (INF-09); 1 min de arco é longo ou curto; 62 tiles de refúgio; 23% de ronda; respawn previsível na Mata; fuga contra água funda; coletável contra formação fixa se lê em 320x180 (contorno e nome); cenário sem casa deixa o mundo vazio; x0,375 de madeira no Soco cansa.
**Dono:** sem decisão aberta neste documento. Fechadas em 06/11: ilha Lunata (nome decidido), tamanho 256, Cochilo, refúgio A, Triceratops Grande, percepção em elipse e sinais do Utahraptor, fósseis no lugar dos fósseis, água rasa sem lentidão, mais faixas de tamanho depois do MVP.
