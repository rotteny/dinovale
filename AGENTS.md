# AGENTS.md: regras para quem mexe no Dino Vale

Godot 4.7 + GDScript. Código em MIT; assets em CC-BY 4.0 (decisão D1). Plano completo em `docs/PLANEJAMENTO.md`.

## Convenções

- **Lógica separada da apresentação.** Componentes (`game/src/components/`) são `Node` puro de lógica: não herdam `CanvasItem` e nunca leem `Input`. Só os corpos (Player, Dino) leem input. A UI só observa sinais.
- **Composição, não herança profunda.** Comportamento novo vira componente.
- **Estado em Dictionary/JSON.** Todo objeto salvável tem `to_dict()`/`from_dict()` com roundtrip testado.
- **Ações como intenção.** Mudança de estado do mundo passa por `request_*` (servidor autoritativo, single-player como host local; D8).
- **Dados em Resource** (`ItemDef`, `SpeciesDef`, `RecipeDef`), com ID estável em string. Nada de número mágico de balanceamento no código.
- **Tipagem estática obrigatória.** Todo parâmetro, retorno e variável com tipo (`var x: int`, `func f(a: float) -> void`). Sem `Variant` implícito onde o tipo é conhecido.
- **Nomes e arquivos:** `PascalCase` para `class_name` e cenas, `snake_case` para funções, variáveis e sinais, `UPPER_SNAKE` para constantes. Um `class_name` por arquivo. Comentários e docs em português; identificadores em inglês.
- **Caminhos de assets** absolutos com `res://`.

## Comandos

Rode sempre da raiz do repositório.

| Para | Comando |
|---|---|
| Verificar tudo (import, testes, lint, arquitetura) | `tools/check.sh` |
| Só os testes headless | `godot --headless --path game --script res://tests/run_tests.gd` |
| Importar o projeto (gera cache de classes) | `godot --headless --path game --import` |

`tools/check.sh` é o mesmo comando local e no CI. Se ele ainda não existir ou estiver quebrado, avise em vez de contornar.

## Definição de pronto

Uma tarefa só está pronta quando:

1. `tools/check.sh` passa, sem erro novo nem aviso novo de import.
2. Há testes para a lógica nova (e para o bug, se for correção), e eles falham sem a mudança.
3. A tipagem está completa nos arquivos tocados.
4. Os critérios de aceite do briefing estão cumpridos, um a um.
5. Assets novos estão registrados em `game/assets/CREDITS.md`.
6. A doc afetada (`README`, `docs/`) foi atualizada, se o comportamento visível mudou.
7. `LEVI` revisou, quando a tarefa mexe em lógica compartilhada, save ou rede.

## Limite de escopo por tarefa

- Uma tarefa, um objetivo. Mexa só nos arquivos listados no briefing. Precisou de outro? Pare e peça.
- Sem refatoração oportunista, sem renomear, sem formatar arquivo que não é seu.
- Não apague nem sobrescreva trabalho de outro agente. Trabalhe em branch ou worktree próprio.
- Sem dependência nova, sem mudar `project.godot`, licença ou CI sem pedido explícito.
- Não faça commit nem push sem pedido. Commits de agente registram a ferramenta usada.
- Achou algo fora do escopo? Registre no relatório final; não corrija.

## Quem faz o quê

| Agente | Responsabilidade |
|---|---|
| `SORA` | Implementação em Godot/GDScript: gameplay, cenas, componentes, save, rede |
| `SHIRO` | Game design: loop, balanceamento, progressão, o diferencial do vínculo com o dino |
| `YATORA` | Arte e som: guia de arte, sprites, tilesets, SFX. Segue a política de arte abaixo |
| `BULMA` | Só a landing em `html/`. Não toca na UI do jogo |
| `LEVI` | Testes, testes de arquitetura, revisão de código antes do merge |
| `KURAMA` | Arquitetura e ADRs (autoridade, formato de save, IDs e registries) |

`SAITAMA` cuida de CI, scripts de build e releases; `NEZUKO`, do gate de segurança de rede.

## Originalidade e assets

- **Conteúdo original.** Nomes, espécies, itens, textos e mecânicas são próprios. Não copie nome, texto, número, ícone ou estrutura de dados de outro jogo. Referência a jogos existentes fica na conversa, nunca em arquivo do repositório.
- **Nomes próprios do Dino Vale.** Termos criados por outros jogos não entram em código, textos, documentos nem commits. Isso vale para itens, criaturas, facções e sistemas; na dúvida, invente outro nome. Palavras comuns de dicionário são permitidas. Não escreva em nenhum arquivo público que o jogo é inspirado em um título específico.
- **Comida de domesticação:** a família se chama **Ração**, com qualidade por letra: **S+, S, A, B, C**, da melhor para a pior. Quantidade de níveis, receitas e efeitos ficam a cargo da `SHIRO`.
- **Todo arquivo em `game/assets/` tem linha em `game/assets/CREDITS.md`:** arquivo, origem, autor, licença, URL, data e, se for o caso, a marca de placeholder.
- **Licenças aceitas:** CC0, CC-BY e arte própria (CC-BY 4.0). Nada com "NC" ou "ND", nem "grátis para uso" sem licença escrita.
- **Arte gerada por IA** só entra como **placeholder**, identificada como tal no `CREDITS.md` (ferramenta, prompt ou data), e deve ser trocada por arte humana ou CC0 antes do lançamento público (decisão D3). Nunca entra como asset final.
- Se não souber a proveniência, o asset não entra.
