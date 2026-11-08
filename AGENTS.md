# AGENTS.md: guia para quem trabalha no Dino Vale com uma IA

Este arquivo é um **índice curto**. O detalhe fica em `documentacao/contexto/`; leia só o arquivo do assunto em que vai mexer.

## O que é

Jogo 2D de sobrevivência e domesticação de dinossauros, em Godot 4.7 + GDScript. O diferencial é o vínculo com o dino domado. Código em MIT; arte e som próprios em CC BY 4.0 (`ASSETS-LICENSE`). Repositório público. Estado e rumo: `documentacao/PLANEJAMENTO.md`; desenho do jogo: `documentacao/design/GDD.md`; como rodar e como o código se organiza: `game/README.md`.

## Validação (rode da raiz do repositório)

```bash
tools/check.sh
```

É o mesmo comando local e no CI: import, testes, cena do jogo e cena inicial por 120 quadros, lint e testes de arquitetura. Teste verde não prova que o jogo funciona: **rode o jogo** (`godot --path game`) quando mexer em cena, UI, input ou save. Detalhes, instalação do gdlint e como rodar uma etapa só: `documentacao/contexto/testes-e-validacao.md`.

## Regras inegociáveis

1. **Lógica fora da apresentação.** Componentes não herdam `CanvasItem` nem leem `Input`; a UI só observa sinais.
2. **Mudança de estado do mundo é intenção** (`request_*`), validada pela autoridade (servidor; o single-player é o host local).
3. **Dado externo só em JSON.** `ConfigFile` é proibido em `game/src/` (ADR-002). `from_dict` nunca aborta no meio e, quando pode recusar, devolve `bool`.
4. **Números de balanceamento em `Resource`**, nunca no código; ids estáveis em string.
5. **Tipagem estática completa** e comentários em português, identificadores em inglês.
6. **`.uid` e `.import` são versionados**; `.godot/` não.
7. **Conteúdo original.** Termos, números e listas de outros jogos não entram em arquivo do repositório (única exceção: a seção "Inspirações" do `README.md`).
8. **Todo arquivo em `game/assets/` tem linha em `game/assets/CREDITS.md`.** Terceiros só CC0 ou CC BY. Arte de IA só como `IA-placeholder`, a trocar antes da v0.2. Origem desconhecida não entra.
9. **Uma tarefa, um objetivo.** Sem refatoração oportunista, sem dependência nova, sem mexer em `project.godot`, licença ou CI sem pedido; sem commit nem push sem pedido.
10. **Repositório público:** nada de e-mail, caminho local, credencial, dado pessoal nem conversa interna em arquivo, commit ou PR.

## Se vai mexer em X, leia Y

| Se vai mexer em | Leia |
|---|---|
| Componentes, entidades, cenas, autoridade, ids, registries | `documentacao/contexto/arquitetura.md` |
| Convenções de nome, tipagem, GDScript, `res://` | `documentacao/contexto/estilo-de-codigo.md` |
| Save, `to_dict`/`from_dict`, migração, autosave, morte e respawn | `documentacao/contexto/save.md` |
| Rodar testes, gdlint, `tools/check.sh`, CI, testes de arquitetura | `documentacao/contexto/testes-e-validacao.md` |
| Sprites, sons, tilesets, ícones, `CREDITS.md`, licenças | `documentacao/contexto/arte-e-licencas.md` |
| Regras de jogo, balanceamento, nomes e textos do jogo, originalidade | `documentacao/contexto/game-design.md` |
| Escopo da tarefa, definição de pronto, papéis, revisão, commits | `documentacao/contexto/contribuicao.md` |
| Decisões recentes do dono e etapas da v0.2 | `documentacao/design/corte-v02/` (`decisoes-0611-0711.md` primeiro) |
| Landing em `docs/` | `documentacao/contexto/contribuicao.md` (papéis) e `README.md` |
