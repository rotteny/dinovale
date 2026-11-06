# Testes e validação

**Leia quando:** for rodar, escrever ou consertar teste, lint, CI, ou antes de declarar uma tarefa pronta.

Fonte de verdade para rodar o projeto: `game/README.md` (seção Como rodar). O CI está em `.github/workflows/check.yml`.

## Comandos (da raiz do repositório)

| Para | Comando |
|---|---|
| Verificar tudo | `tools/check.sh` |
| Só os testes headless | `godot --headless --path game --script res://tests/run_tests.gd` |
| Importar o projeto (gera o cache de classes em `game/.godot/`) | `godot --headless --path game --import` |
| Rodar o jogo | `godot --path game` |

`tools/check.sh` roda: import, testes, cena do jogo (`Main`, 120 quadros), cena inicial (120 quadros), lint e `tools/checks.d/*.sh` (testes de arquitetura). Falha por código de saída **ou** por `ERROR`/`WARNING` na saída da engine. Se ele não existir ou estiver quebrado, avise em vez de contornar. Variáveis: `GODOT` (binário), `GDLINT` (binário do lint), `REQUIRE_LINT=1` (reprova se não houver gdlint; o CI usa).

## Requisitos

- **Godot 4.7** ou mais novo (o CI usa a 4.7.2). Os testes usam `Logger`, que não existe em versões antigas.
- **gdlint** (pacote `gdtoolkit`, versão do CI: 4.5.0). Instale num ambiente isolado:

```bash
python3 -m venv ~/.venvs/gdtoolkit && ~/.venvs/gdtoolkit/bin/pip install "gdtoolkit==4.5.0"
export GDLINT=~/.venvs/gdtoolkit/bin/gdlint
REQUIRE_LINT=1 tools/check.sh   # sem REQUIRE_LINT o lint é pulado com aviso
```

## Rodar o jogo, além dos testes

Os testes headless não pegam problema de tela, input, foco, tela cheia ou sensação de jogo. Mudou cena, UI, input, câmera, save ou menu? Abra `godot --path game`, exercite o fluxo alterado (incluindo salvar, sair e continuar, se for o caso) e diga no relatório o que viu. Sem poder abrir o jogo (ambiente sem tela), diga isso explicitamente em vez de afirmar que funciona.

## O que escrever

- Teste para a lógica nova e, em correção, um teste que **falha sem a mudança**. Testes ficam em `game/tests/` e entram em `run_tests.gd`.
- Todo saveable novo entra em `game/tests/saveable_table.gd` (roundtrip por JSON).
- Teste de arquitetura novo ou exceção em `tools/checks.d/10-arquitetura.sh`: exceção leva o id da tarefa que a remove; exceção que deixou de ser necessária também reprova.
- Lógica compartilhada, save ou rede pede revisão independente (ver `contribuicao.md`).
