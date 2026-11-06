# Créditos dos assets

Todo arquivo de arte, som ou fonte em `game/assets/` e `html/` deve ter uma
linha aqui **no mesmo commit** que o adiciona. Arquivo sem linha não entra.

Licença dos assets próprios: CC BY 4.0 (ver `/ASSETS-LICENSE`). Código: MIT.

## Política

- Terceiros: somente CC0 ou CC BY (4.0 ou anterior). Guarde o link da fonte.
- Arte e som gerados por IA: **somente como placeholder**, marcado com
  origem `IA-placeholder`. Antes do lançamento público (v0.2) todo
  `IA-placeholder` deve ser trocado por arte humana ou CC0. Esta tabela é o
  inventário dessa troca: `grep IA-placeholder game/assets/CREDITS.md`.
- Origem desconhecida não é aceita.

## Valores permitidos

| Coluna | Valores |
|---|---|
| Origem | `propria` (autoria do projeto), `terceiro`, `IA-placeholder` |
| Licença | `CC-BY-4.0`, `CC0`, `OFL-1.1` (fontes) ou a licença CC BY do terceiro |

## Registro

| Arquivo | Origem | Autor / ferramenta | Fonte (URL) | Licença | Alterações | Data |
|---|---|---|---|---|---|---|
| html/assets/*.svg (20 arquivos: logo, favicon, selva, cenas, folhas, mecânicas, etc.) | IA-placeholder | gerados por `html/tools/gen_art.py`, escrito por agente de IA (Claude) | - | CC-BY-4.0 | - | 2026-11-05 |
| html/assets/fonts/fredoka-700.ttf | terceiro | The Fredoka Project Authors | https://github.com/hafontia/Fredoka-One | OFL-1.1 (`html/assets/fonts/OFL-Fredoka.txt`) | - | 2026-11-05 |
| html/assets/fonts/atkinson-400.ttf, atkinson-700.ttf | terceiro | Braille Institute of America, Inc. (Atkinson Hyperlegible) | - | OFL-1.1 (`html/assets/fonts/OFL-Atkinson-Hyperlegible.txt`) | - | 2026-11-05 |
| game/assets/third_party/ninja-adventure/LICENSE.txt, README.md | terceiro | Pixel-Boy e AAA (pacote Ninja Adventure) | https://pixel-boy.itch.io/ninja-adventure-asset-pack | CC0 | texto CC0 1.0 e README do pacote, copiados sem alteração | 2026-11-05 |
| game/assets/third_party/ninja-adventure/tilesets/ (3 arquivos: tileset_floor, tileset_nature, tileset_house) | terceiro | Pixel-Boy e AAA (pacote Ninja Adventure) | https://pixel-boy.itch.io/ninja-adventure-asset-pack | CC0 | renomeados; sem alteração de pixel. Origem: Backgrounds/Tilesets/TilesetFloor, TilesetNature, TilesetHouse | 2026-11-05 |
| game/assets/third_party/ninja-adventure/characters/ (2: caveman, cavegirl) | terceiro | Pixel-Boy e AAA (pacote Ninja Adventure) | https://pixel-boy.itch.io/ninja-adventure-asset-pack | CC0 | renomeados. Origem: Actor/Character/Caveman e Cavegirl, SpriteSheet.png | 2026-11-05 |
| game/assets/third_party/ninja-adventure/animals/ (6: reptile, lizard, grey_trex, frog, chicken_brown, pig_pink) | terceiro | Pixel-Boy e AAA (pacote Ninja Adventure) | https://pixel-boy.itch.io/ninja-adventure-asset-pack | CC0 | renomeados. **Usados como placeholder de dino/bicho pequeno**, não são dinos de verdade. Origem: Actor/Monster e Actor/Animal | 2026-11-05 |
| game/assets/third_party/ninja-adventure/items/ (20: baús, moeda, comidas, recursos, ferramentas) | terceiro | Pixel-Boy e AAA (pacote Ninja Adventure) | https://pixel-boy.itch.io/ninja-adventure-asset-pack | CC0 | renomeados. Origem: Items/Treasure, Food, Resource, Tool | 2026-11-05 |
| game/assets/third_party/ninja-adventure/ui/ (31: painéis, botões, barras, corações, emotes, caixa de diálogo) | terceiro | Pixel-Boy e AAA (pacote Ninja Adventure) | https://pixel-boy.itch.io/ninja-adventure-asset-pack | CC0 | renomeados. Origem: Ui/Theme/Theme Wood, Ui/Receptacle, Ui/Dialog, Ui/Emote | 2026-11-05 |
| game/assets/third_party/ninja-adventure/fx/ (8: claw, claw_double, cut, slash_curved, smoke, particle_rock/grass/leaf) | terceiro | Pixel-Boy e AAA (pacote Ninja Adventure) | https://pixel-boy.itch.io/ninja-adventure-asset-pack | CC0 | renomeados. Origem: FX/Attack, FX/Smoke, FX/Particle | 2026-11-05 |
| game/assets/third_party/ninja-adventure/palette.png | terceiro | Pixel-Boy e AAA (pacote Ninja Adventure) | https://pixel-boy.itch.io/ninja-adventure-asset-pack | CC0 | renomeado. Origem: Palette.png | 2026-11-05 |
| game/assets/third_party/ninja-adventure/sounds/ (30 WAV: hit, voice, swing, ui, pickup, misc) | terceiro | Pixel-Boy e AAA (pacote Ninja Adventure) | https://pixel-boy.itch.io/ninja-adventure-asset-pack | CC0 | renomeados para minúsculas e agrupados em subpastas; áudio sem alteração. Origem: Audio/Sounds/*. Não ouvidos por quem importou; ver MAPA.md | 2026-11-05 |
| game/assets/sprites/recursos/tree_collect.png (32x48), tree_collect_stump.png (16x16) | propria | autoria do projeto, gerados por `docs/design/arte/gerar_recursos.gd` (sem IA, sem recorte de terceiros); arvore coletavel (pinheiro de camadas, tronco com entalhe) e toco esgotado | - | CC-BY-4.0 | usa so cores da paleta do pacote Ninja Adventure; ids genericos nos nomes | 2026-11-06 |
| game/assets/sprites/recursos/tree_decor.png (48x48) | propria | autoria do projeto, gerados por `docs/design/arte/gerar_recursos.gd` (sem IA, sem recorte de terceiros); arvore decorativa nao coletavel (copa larga, redonda e escura) | - | CC-BY-4.0 | usa so cores da paleta do pacote Ninja Adventure; ids genericos nos nomes | 2026-11-06 |
| game/assets/sprites/recursos/bush_food.png, bush_sleep.png, bush_empty.png (16x16) | propria | autoria do projeto, gerados por `docs/design/arte/gerar_recursos.gd` (sem IA, sem recorte de terceiros); arbusto fibroso: fruta comestivel (bolas vermelhas), fruta do sono (luas claras em C), colhido | - | CC-BY-4.0 | usa so cores da paleta do pacote Ninja Adventure; ids genericos nos nomes | 2026-11-06 |
| game/assets/sprites/recursos/rock_stone.png, rock_stone_empty.png, rock_ore.png, rock_ore_empty.png (16x16) | propria | autoria do projeto, gerados por `docs/design/arte/gerar_recursos.gd` (sem IA, sem recorte de terceiros); rocha de pedra (monte baixo, cinza quente) e de minerio (cristal alto, veios ciano grossos com brilhos), revisados em 06/11, e estados esgotados | - | CC-BY-4.0 | usa so cores da paleta do pacote Ninja Adventure; ids genericos nos nomes | 2026-11-06 |
| game/assets/sprites/recursos/pebble_a.png, pebble_b.png, icon_stone.png (16x16) | propria | autoria do projeto, gerados por `docs/design/arte/gerar_recursos.gd` (sem IA, sem recorte de terceiros); pedras avulsas coletadas a mao (2 variacoes) e icone de item de pedra | - | CC-BY-4.0 | usa so cores da paleta do pacote Ninja Adventure; ids genericos nos nomes | 2026-11-06 |
| game/assets/sprites/recursos/icon_fruit_food.png, icon_fruit_sleep.png (16x16) | propria | autoria do projeto, gerados por `docs/design/arte/gerar_recursos.gd` (sem IA, sem recorte de terceiros); icones de item das duas frutas | - | CC-BY-4.0 | usa so cores da paleta do pacote Ninja Adventure; ids genericos nos nomes | 2026-11-06 |
| game/assets/sprites/jogador/jogador.png (160x128, quadro 16x32), jogador.json | propria | autoria do projeto, gerados por `docs/design/arte/gerar_jogador.gd` (sem IA, sem recorte de terceiros); homem das cavernas sem camisa, tanga de folhas, sem acessorios; 4 direcoes (direita desenhada a parte), parado 2, andar 4, golpe 3, caido 1 | - | CC-BY-4.0 | so cores da paleta do pacote registrado acima; conferido por script ao gravar | 2026-11-06 |
| game/assets/sprites/cenario/terreno.png (256x400, tile 16x16), terreno.json | propria | autoria do projeto, gerados por `docs/design/arte/gerar_terreno.gd` (sem IA, sem recorte de terceiros); agua funda e rasa, praia, Campina, Mata-baixa, Pedreira, trilha; 16 variacoes cheias por terreno e 6 conjuntos de transicao de 47 tiles | - | CC-BY-4.0 | so cores da paleta do pacote registrado acima; conferido por script ao gravar | 2026-11-06 |
| game/assets/sprites/cenario/formacao_a.png (64x80), formacao_b.png (96x48), formacao_c.png (64x48) | propria | autoria do projeto, gerados por `docs/design/arte/gerar_cenario.gd` (sem IA, sem recorte de terceiros); formacoes rochosas naturais (espigoes, crista, matacoes) | - | CC-BY-4.0 | so cores da paleta do pacote registrado acima | 2026-11-06 |
| game/assets/sprites/recursos/tree_collect_80.png, tree_decor_80.png (48x80), rock_stone_32.png, rock_ore_32.png, rock_stone_empty_32.png, rock_ore_empty_32.png (32x32) | propria | autoria do projeto, gerados por `docs/design/arte/gerar_cenario.gd` (sem IA, sem recorte de terceiros); escala nova: arvore coletavel (pinheiro com entalhe) e decorativa (copa redonda), pedra e minerio de 32 px e estados esgotados | - | CC-BY-4.0 | so cores da paleta do pacote registrado acima; os de 16 e 32x48 anteriores seguem ate o SORA trocar | 2026-11-06 |
| game/assets/sprites/dinos/ (5 PNG + 5 JSON: dodo 16x16, paquicefalo 24x24, parassaurolofo 32x32, utahraptor 32x32, triceratops 48x48) | propria | autoria do projeto, gerados por `docs/design/arte/gerar_dinos.gd` (sem IA, sem recorte de terceiros); 11 colunas x 4 linhas (parado 2, andar 4, golpe ou susto 3, dormindo, morto), 4 direcoes, silhueta propria por especie; arte de script, tratar como placeholder revisado ate passar por artista | - | CC-BY-4.0 | so cores da paleta do pacote registrado acima; conferido por script ao gravar | 2026-11-07 |
| game/assets/sprites/ui/ (icon_feather, icon_shield, icon_bolt, icon_target, icon_weight; 8x8) | propria | autoria do projeto, gerados por `docs/design/arte/gerar_ui.gd` (sem IA, sem recorte de terceiros); pena branca, escudo verde, raio vermelho, alvo e peso | - | CC-BY-4.0 | so cores da paleta do pacote registrado acima; conferido por script ao gravar | 2026-11-07 |
| game/assets/sprites/jogador/jogador.png, jogador.json (revisao) | propria | `docs/design/arte/gerar_jogador.gd`; andar de frente/costas com 4 quadros distintos, golpe para cima refeito, caido de lado (esquerda/direita) | - | CC-BY-4.0 | substitui a versao de 06/11 | 2026-11-07 |

<!-- Exemplos, apague ao registrar o primeiro:
| sprites/dino_rex.png | propria | Fulano | - | CC-BY-4.0 | - | 2026-11-05 |
| sounds/passo.ogg | terceiro | Beltrano | https://opengameart.org/... | CC0 | cortado | 2026-11-05 |
| sprites/arvore.png | IA-placeholder | <ferramenta e modelo> | - | pendente | trocar antes do v0.2 | 2026-11-05 |
-->
