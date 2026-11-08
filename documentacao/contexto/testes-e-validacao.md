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

**Uma suíte só:** `godot --headless --path game --script res://tests/run_tests.gd -- --suite=ServerRules` (nome da classe, com ou sem o sufixo `Tests`). No fim o runner imprime o tempo de cada suíte, da mais lenta para a mais rápida, e toda falha sai como `FALHOU: <teste> [suíte <nome>]`.

**Rode o `tools/check.sh` em primeiro plano** e espere o fim: cada passo tem limite de 180 s (`STEP_TIMEOUT_SECONDS`; o de testes tem `TESTS_TIMEOUT_SECONDS`, padrão 600), a saída é a verdade (erro de script em GDScript não muda o código de saída) e rodá-lo em segundo plano ou cortá-lo por tempo externo esconde falha. Não declare pronto com base num passo isolado.

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

- Teste para a lógica nova e, em correção, um teste que **falha sem a mudança**. Os testes são **divididos em arquivos por assunto** em `game/tests/` (`*_tests.gd`, uma classe cada, por exemplo `server_rules_tests.gd`, `utahraptor_tests.gd`, `save_tests.gd`); toda classe nova entra em sequência em `game/tests/run_tests.gd`. Prefira um arquivo novo ao inchaço de um existente.
- Todo saveable novo entra em `game/tests/saveable_table.gd` (roundtrip por JSON).
- Teste de arquitetura novo ou exceção em `tools/checks.d/10-arquitetura.sh`: exceção leva o id da tarefa que a remove; exceção que deixou de ser necessária também reprova.
- Lógica compartilhada, save ou rede pede revisão independente (ver `contribuicao.md`).
