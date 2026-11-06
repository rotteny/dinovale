# Estilo de código (GDScript)

**Leia quando:** for escrever ou revisar qualquer `.gd`.

O `gdlint` (config em `game/.gdlintrc`) cobre nomes, ordem da classe, tamanho de linha (140) e de arquivo (1000). Rode via `tools/check.sh` (ver `testes-e-validacao.md`).

- **Tipagem estática obrigatória.** Todo parâmetro, retorno e variável com tipo (`var x: int`, `func f(a: float) -> void`). Sem `Variant` implícito onde o tipo é conhecido.
- **Nomes:** `PascalCase` para `class_name` e cenas; `snake_case` para funções, variáveis e sinais; `UPPER_SNAKE` para constantes. Um `class_name` por arquivo.
- **Idioma:** comentários e docs em português; identificadores em inglês.
- **Caminhos de assets sempre absolutos com `res://`.**
- **Cabeçalho:** `# SPDX-License-Identifier: MIT` nos scripts.
- **Arquivos gerados pela engine:** `.uid` (ao lado de cada `.gd`) e `.import` (ao lado de cada asset importado) **são versionados**; commit os que a Godot gerar para arquivos novos. `game/.godot/` não é versionado.
- Sem refatoração oportunista, sem renomear e sem formatar arquivo que não é da tarefa.
