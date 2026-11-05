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

<!-- Exemplos, apague ao registrar o primeiro:
| sprites/dino_rex.png | propria | Fulano | - | CC-BY-4.0 | - | 2026-11-05 |
| sounds/passo.ogg | terceiro | Beltrano | https://opengameart.org/... | CC0 | cortado | 2026-11-05 |
| sprites/arvore.png | IA-placeholder | <ferramenta e modelo> | - | pendente | trocar antes do v0.2 | 2026-11-05 |
-->
