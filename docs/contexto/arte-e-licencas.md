# Arte, som e licenças

**Leia quando:** for adicionar, trocar ou remover qualquer arquivo em `game/assets/` ou `html/`, gerar arte, ou mexer em créditos e licença.

Fontes de verdade: `game/assets/CREDITS.md` (política e inventário), `ASSETS-LICENSE` (o que cada licença cobre), `docs/design/arte/ESTILO.md` (guia visual), `docs/design/arte/teste-ia-dinos.md`.

## Regras

- **Todo arquivo em `game/assets/` tem linha em `game/assets/CREDITS.md` no mesmo commit que o adiciona:** arquivo, origem, autor, licença, URL, data e, se for o caso, a marca de placeholder. Valores de Origem: `propria`, `terceiro`, `IA-placeholder`.
- **Licenças aceitas:** CC0, CC BY e arte própria (CC BY 4.0). Fontes mantêm a OFL. Nada com "NC" ou "ND", nem "grátis para uso" sem licença escrita.
- **Terceiros só CC0 ou CC BY**, em `game/assets/third_party/<pacote>/`, cada pacote com o próprio texto de licença. Terceiros não ficam sob a licença do projeto. Só cite pacotes que já estão no repositório.
- **Arte e som gerados por IA só entram como placeholder**, com origem `IA-placeholder` em `CREDITS.md` (ferramenta e data; prompt, se houver). Ficam **fora da CC BY** (`ASSETS-LICENSE`) e **precisam ser trocados por arte humana ou CC0 antes do lançamento público (v0.2)**. O inventário da troca é `grep IA-placeholder game/assets/CREDITS.md`. Nunca entram como asset final.
- **Se não souber a proveniência, o asset não entra.**
- Use o fluxo de arte em `docs/design/arte/` e respeite o guia `ESTILO.md` (grade 16x16, 4 direções). Antes de gerar arte, confira o registro de teste e os limites já documentados lá.
- **Não versione pacote de arte que não pode ser redistribuído.** Assets de terceiros só entram se a licença permitir redistribuição no repositório público.
