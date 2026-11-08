# Mapa de uso: Ninja Adventure (CC0)

Pacote de Pixel-Boy e AAA, https://pixel-boy.itch.io/ninja-adventure-asset-pack, licença CC0 (`LICENSE.txt` nesta pasta). Registro em `game/assets/CREDITS.md`. Importado em 05/11/2026 só com o necessário ao MVP (103 arquivos).

Todos os caminhos abaixo são relativos a `res://assets/third_party/ninja-adventure/`.

Regras de importação: filtro **nearest**, sem mipmap, escala inteira apenas. Grade do mundo: **16x16**. Todo PNG tem fundo transparente. "Coluna" e "linha" contam a partir de 0, em quadros inteiros. Direções, quando existem: coluna 0 = baixo (frente), 1 = cima (costas), 2 = esquerda, 3 = direita (conferido olhando os quadros).

Marcações: **[verificado]** = comparei com os arquivos do pacote ou vi o quadro; **[não verificado]** = deduzido, confira ao ligar.

## Personagens

| Uso | Arquivo | Quadro | Quadros | Direções | Observação |
|---|---|---|---|---|---|
| Jogador (padrão) | `characters/caveman.png` (64x112) | 16x16 | 4 colunas x 7 linhas | 4 (colunas) | Linhas **[verificado por igualdade de pixels com as animações separadas do pacote]**: 0 parado, 0 a 3 andar (a linha 0 é também o parado), 4 atacar, 5 pular, 6 morto (só a coluna 0 é a pose de morto; as outras colunas da linha 6 são poses extras não identificadas). Âncora: pés na base do quadro. |
| Jogador (alternativa) | `characters/cavegirl.png` (64x112) | 16x16 | idem | idem | Mesmo layout do Caveman **[não verificado linha a linha]**. |

Cabeça grande, contorno escuro de 1 px. O jogador tem 16 px de altura (1 tile).

## Bichos: PLACEHOLDER de dino e bichos pequenos

Nenhum é dino de verdade, exceto o Grey Trex, que é um dino chibi. **Todos os usos abaixo são placeholder de dino** até haver dinos encomendados (ver `documentacao/design/arte/ESTILO.md`).

| Uso sugerido | Arquivo | Quadro | Quadros | Direções | Observação |
|---|---|---|---|---|---|
| Filhote herbívoro (placeholder) | `animals/reptile.png` (64x64) | 16x16 | 4 colunas x 4 linhas | 4 (colunas); linhas = 4 quadros de andar | Azul com chifrinhos laranja. Não tem dormir, ferido nem ataque. |
| Filhote carnívoro (placeholder) | `animals/grey_trex.png` (64x64) | 16x16 | 4x4 | 4; 4 quadros de andar | Cinza, dentes à mostra. Único dino de verdade do pacote. |
| Filhote/bicho verde (placeholder) | `animals/lizard.png` (64x64) | 16x16 | 4x4 | 4; 4 quadros de andar | Verde. As colunas 2 e 3 (lados) parecem espelhadas entre si **[não verificado]**. |
| Bicho pequeno | `animals/frog.png` (32x16) | 16x16 | 2 | só 2 poses | Quadro 0 de frente, quadro 1 de lado **[verificado olhando]**. |
| Bicho pequeno | `animals/chicken_brown.png` (32x16) | 16x16 | 2 | só perfil (virado para a direita) | 2 quadros de andar. Sem outras direções. |
| Bicho pequeno | `animals/pig_pink.png` (32x16) | 16x16 | 2 | só perfil (virado para a direita) | 2 quadros de andar. Sem outras direções. |

Faltam para qualquer bicho: **dormir, ferido, atacar**. Enquanto não houver arte, o jogo pode indicar sono com `ui/emote_sleep.png` sobre o sprite parado (não girar sprite por valor fracionário).

## Mundo: tiles e cenário

### `tilesets/tileset_floor.png` (352x417, tile 16x16)

Coordenadas em tiles (coluna, linha). Conferido por montagem de cena (ver `documentacao/design/arte/pacotes/mock-pacotes-2x.png`).

- **Grama**: base (0,12); variações com tufos (1..4,12) e (2,11), (3,11). Sorteio ponderado (maioria base) evita padrão visível.
- **Caminho de terra sobre a grama** (conjunto à esquerda do arquivo, colunas 0 a 9, linhas 7 a 11):
  - Miolo cheio: (1,8).
  - Cantos externos e bordas, bloco 3x3: topo-esq (0,7), topo (1,7), topo-dir (2,7), esq (0,8), dir (2,8), base-esq (0,9), base (1,9), base-dir (2,9).
  - Faixa vertical (1 de largura): topo (3,7), meio (3,8), base (3,9). Faixa horizontal (1 de altura): esq (0,10), meio (1,10), dir (2,10). Ilha de 1 tile: (3,10).
  - **Cantos internos** (diagonal ausente): sem diagonal baixo-dir (5,8); baixo-esq (6,8); cima-dir (5,9); cima-esq (6,9).
  - Decoração de terra: (0,11) graveto, (1,11) pedrinha.
  - Regra usada no mock: com os 4 vizinhos de lado presentes, escolher o miolo ou o canto interno pela diagonal ausente; senão, o 3x3, as faixas ou a ilha, conforme os lados ausentes. É a lógica de `montar.gd` (`_dirt_tile`). **Para o Godot, é um conjunto de blocos pronto para virar TileSet com terreno, mas não verifiquei todas as combinações de bits** (por exemplo, duas diagonais ausentes ao mesmo tempo usam só um canto interno).
- Há mais terrenos no arquivo (areia/laranja, neve/branco, versões escuras): não usados.

### `tilesets/tileset_nature.png` (384x336)

Recortes em pixels (x, y, largura, altura), conferidos na cena:

- Árvore verde: (48, 288, 48, 48). Base do tronco na linha inferior; colisão só no tronco.
- Aglomerado de folhagem (bordas densas): (64, 32, 64, 48).
- Tufo de grama alta: (48,160,16,16), (64,160), (80,160), (112,160), todos 16x16.
- Arbusto redondo: (16,160,16,16), (32,160), (48,160).
- Flores: (0,176) girassol, (16,176) girassol, (48,176) flor vermelha, (96,176) flor branca, todas 16x16.
- Pedras pequenas: (272,208), (288,208), (304,208), 16x16 **[escolhidas por olho; confira]**.
- Há muito mais (árvores outono, neve, pedras grandes, troncos, cristais): não usado.

### `tilesets/tileset_house.png` (528x368)

- **Casa de palha** = 2 recortes empilhados (o pacote entrega telhado e frente como peças separadas): telhado (400, 112, 64, 48) e frente com porta (400, 191, 64, 33); a frente é desenhada 48 px abaixo do topo do telhado. A porta fica a cerca de 24 px da borda esquerda da casa. Tamanho final montado: 64x81.
- O arquivo tem muitas outras construções (cabanas, cercas, barracas, móveis); não usadas.

## Itens

Todos com fundo transparente, um quadro só. Tamanhos reais (nem todos são 16x16).

| Uso | Arquivo | Tamanho |
|---|---|---|
| Baú pequeno | `items/chest_small.png` | 32x16: **2 quadros 16x16, 0 fechado, 1 aberto** [verificado] |
| Baú grande | `items/chest_big.png` | 32x14: 2 quadros (fechado/aberto) **[não verificado]** |
| Moeda | `items/coin_gold.png` | 7x7 |
| Carne (comida carnívoro) | `items/food_meat.png` | 15x15 |
| Peixe | `items/food_fish.png` | 16x16 |
| Noz | `items/food_nut.png` | 15x15 |
| Sementes | `items/food_seed1.png`, `food_seed2.png`, `food_seed3.png` | 8x8 |
| Mel | `items/food_honey.png` | 16x16 |
| Recursos | `items/res_branch.png`, `res_rock.png`, `res_grass.png`, `res_feather.png` | 16x16 |
| Água | `items/res_water.png` | 14x14 |
| Ferramentas | `items/tool_axe.png`, `tool_pickaxe.png`, `tool_shovel.png`, `tool_hammer.png`, `tool_sickle.png` | 16x16 |

Os nomes de itens do jogo (incluindo a **Ração** S+/S/A/B/C) são da `SHIRO`; estes são só ícones. Não há ícone específico de Ração no pacote.

## Interface

Todos os painéis são 9-slice. **Margem usada no mock: 6 px** (painéis 16x16); confirme ao montar o `StyleBoxTexture`.

| Uso | Arquivo | Tamanho | Observação |
|---|---|---|---|
| Painel de HUD (madeira) | `ui/panel_a.png`, `panel_b.png`, `panel_c.png` | 16x16 | 3 variações. `panel_a` usado no mock (laranja). |
| Miolo de painel | `ui/panel_interior.png` | 16x16 | |
| Fundo | `ui/bg_a.png`, `ui/bg_b.png` | 16x16 | |
| Foco | `ui/focus.png` | 8x8 | |
| Botão | `ui/button_normal.png`, `button_hover.png`, `button_pressed.png`, `button_disabled.png` | 16x8 | 9-slice |
| Célula de inventário | `ui/inventory_cell.png` | 16x16 | |
| Caixa de diálogo | `ui/dialog_box.png` | 300x58 | 9-slice **[não verificado como é cortada]** |
| Barra mini (sobre o dino) | `ui/bar_mini_under.png` + `ui/bar_mini_progress.png` | 18x4 | O progresso é o mesmo tamanho do fundo; para mostrar a fração, **recortar a largura** do progresso (sem escalar). **Só há vermelho**: duas barras (vida/confiança) ficam da mesma cor. |
| Barra retangular | `ui/bar_rect_wood.png` (34x56), `bar_rect_health.png`, `bar_rect_white.png` (22x40) | | Vertical, recorte pela altura. Posição do progresso dentro do fundo **[não verificado]** |
| Esferas | `ui/sphere_wood.png` (32x32), `sphere_over.png` (32x32), `sphere_health.png`, `sphere_yellow.png`, `sphere_green.png` (22x22) | | Esfera = fundo + progresso + tampa (`over`). Cores vermelho, amarelo e verde: servem para vida, energia e fome **[não verificado o encaixe]**. |
| Ícone de vida | `ui/icon_heart.png` | 14x12 | |
| Corações | `ui/hearts_strip.png` | 80x16 | Faixa; quadros de 16x16 provavelmente 5 **[não verificado]** |
| Emotes (balão) | `ui/emote_exclaim.png`, `emote_exclaim_red.png`, `emote_question.png`, `emote_question_red.png`, `emote_heart.png`, `emote_sleep.png` | 14x13 | `emote_sleep` é o "zz" (dormindo); `emote_exclaim_red` serve de alerta de perigo; `emote_heart` de vínculo. 1 quadro cada. |
| Paleta | `palette.png` | 10x9 | Uma amostra de cada cor da paleta do pacote (referência de estilo) |

Não há ícone de energia (raio): o mock usou a pena (`items/res_feather.png`) como improviso.

## Efeitos (dano e ambiente)

| Uso | Arquivo | Tamanho | Quadros |
|---|---|---|---|
| Garra / mordida (dano do carnívoro) | `fx/claw.png` | 128x32 | **4 quadros de 32x32** |
| Garra dupla | `fx/claw_double.png` | 128x32 | 4 de 32x32 |
| Corte | `fx/cut.png` | 128x32 | 4 de 32x32 |
| Corte curvo | `fx/slash_curved.png` | 128x32 | 4 de 32x32 |
| Fumaça / poeira | `fx/smoke.png` | 192x32 | 6 de 32x32 |
| Pedacinhos de pedra | `fx/particle_rock.png` | 80x16 | 5 de 16x16 (os pedaços têm tamanhos variados) |
| Folhinhas | `fx/particle_leaf.png` | 72x7 | 6 de 12x7 **[não verificado]** |
| Grama | `fx/particle_grass.png` | 72x13 | 6 de 12x13 **[não verificado]** |

Os quadros de `claw`, `claw_double`, `cut` e `slash_curved` apontam para a direita, curvados (**[verificado]**). Para outras direções, girar em múltiplos de 90 graus ou espelhar; não há versões por direção.

## Sons (WAV, 44,1 kHz, 16 bits, estéreo)

Todos têm pico em cerca de -10 dBFS (0,32 do máximo), ou seja, ficam baixos: o jogo deve compensar em volume. Duração conferida pelo carregamento no Godot; **ninguém ouviu os arquivos** (ver abaixo).

| Pasta | Arquivos (duração em s) | Uso sugerido |
|---|---|---|
| `sounds/hit/` | hit1 0,34, hit3 0,40, hit5 0,33, hit6 0,33, impact 0,24, impact2 0,31 | golpe recebido/dado |
| `sounds/voice/` | voice1 0,36, voice2 0,21, voice3 0,16, voice4 0,11, voice5 0,33, voice6 0,33 | dor/grito curto; **não sei se são dor, esforço ou fala** |
| `sounds/swing/` | slash 0,34, slash2 0,44, slash3 0,37, whoosh 0,33, whoosh2 0,44 | ataque no ar, mordida, passada |
| `sounds/ui/` | accept2 0,65, accept4 0,25, cancel2 0,31, move2 0,10, move4 0,20, menu8 0,18 | menu, confirmar, cancelar, mover foco |
| `sounds/pickup/` | coin 0,29, coin2 0,33, powerup1 0,47 | coletar item |
| `sounds/misc/` | heal 0,31, alert3 0,25, grass 0,36, grass2 0,36 | alimentar/curar, alerta, passos ou colher na grama (**grass e grass2 são muito baixos**: pico 0,07 e 0,04) |

O pacote tem mais sons e 37 músicas; **não foram importados**. Não há som de dino (rugido, ronco de sono, mordida): precisa de fonte nova.
