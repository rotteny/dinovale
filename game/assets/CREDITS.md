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

<!-- Exemplos, apague ao registrar o primeiro:
| sprites/dino_rex.png | propria | Fulano | - | CC-BY-4.0 | - | 2026-11-05 |
| sounds/passo.ogg | terceiro | Beltrano | https://opengameart.org/... | CC0 | cortado | 2026-11-05 |
| sprites/arvore.png | IA-placeholder | <ferramenta e modelo> | - | pendente | trocar antes do v0.2 | 2026-11-05 |
-->
