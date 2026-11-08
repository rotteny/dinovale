# Arte, som e licenças

**Leia quando:** for adicionar, trocar ou remover qualquer arquivo em `game/assets/` ou `docs/`, gerar arte, ou mexer em créditos e licença.

Fontes de verdade: `game/assets/CREDITS.md` (política e inventário), `ASSETS-LICENSE` (o que cada licença cobre), `documentacao/design/arte/ESTILO.md` (guia visual), `documentacao/design/arte/teste-ia-dinos.md`.

## Regras

- **Todo arquivo em `game/assets/` tem linha em `game/assets/CREDITS.md` no mesmo commit que o adiciona:** arquivo, origem, autor, licença, URL, data e, se for o caso, a marca de placeholder. Valores de Origem: `propria`, `terceiro`, `IA-placeholder`.
- **Licenças aceitas:** CC0, CC BY e arte própria (CC BY 4.0). Fontes mantêm a OFL. Nada com "NC" ou "ND", nem "grátis para uso" sem licença escrita.
- **Terceiros só CC0 ou CC BY**, em `game/assets/third_party/<pacote>/`, cada pacote com o próprio texto de licença. Terceiros não ficam sob a licença do projeto. Só cite pacotes que já estão no repositório.
- **Arte e som gerados por IA só entram como placeholder**, com origem `IA-placeholder` em `CREDITS.md` (ferramenta e data; prompt, se houver). Ficam **fora da CC BY** (`ASSETS-LICENSE`) e **precisam ser trocados por arte humana ou CC0 antes do lançamento público (v0.2)**. O inventário da troca é `grep IA-placeholder game/assets/CREDITS.md`. Nunca entram como asset final.
- **Sprites do jogador** (`game/assets/sprites/jogador/`) deixaram de ser `IA-placeholder` em 08/11: o dono aprovou a folha de 8 direções feita por script (`documentacao/design/arte/gerar_jogador_8dir.gd`), arte própria CC BY 4.0. O Paquicéfalo também é arte própria por script, em 8 direções (`gerar_paquicefalo.gd`). A dúvida da licença Open RAIL-M da PixelLab fica sem objeto enquanto nenhum arquivo de `game/assets/` vier dela; não gere mais arte lá sem checar `documentacao/design/arte/teste-ia-dinos.md`.
- **Pacotes pagos que proíbem redistribuição não servem** (o repositório é público). A pesquisa achou só dois pacotes compatíveis e parciais; o caminho que resolve é **encomendar arte a um artista**. Pacote CC0 de dinos está para ser avaliado, não adotado.
- **Se não souber a proveniência, o asset não entra.**
- Use o fluxo de arte em `documentacao/design/arte/` e respeite o guia `ESTILO.md` (grade 16x16; 4 direções, e 8 no jogador e no Paquicéfalo). Antes de gerar arte, confira o registro de teste e os limites já documentados lá.
- **Não versione pacote de arte que não pode ser redistribuído.** Assets de terceiros só entram se a licença permitir redistribuição no repositório público.
- **Música e menu** (08/11): as três faixas (`game/assets/audio/musica/`) são sintetizadas por `documentacao/design/audio/*.gd` e importadas em PCM com loop; o fundo, o logo e os botões do menu (`game/assets/ui/menu/`) e os ícones de sexo (`game/assets/ui/`) vêm de `documentacao/design/arte/gerar_menu_*.gd` e `gerar_icones_sexo.gd`. Todos próprios, CC BY 4.0, uma linha por arquivo no `CREDITS.md`.
