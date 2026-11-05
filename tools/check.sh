#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Verificação única do repositório: o mesmo comando roda local e no CI.
#
#   tools/check.sh
#
# Variáveis opcionais:
#   GODOT         binário do Godot (padrão: godot)
#   GDLINT        binário do gdlint (padrão: gdlint no PATH)
#   REQUIRE_LINT  1 = falha se o gdlint não existir (o CI usa 1)
#
# Etapas extras: todo executável em tools/checks.d/*.sh roda no fim, em ordem
# alfabética (é onde entram os testes de arquitetura).
set -euo pipefail

readonly REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly GAME_DIR="$REPO_ROOT/game"
readonly GODOT="${GODOT:-godot}"
readonly GDLINT="${GDLINT:-gdlint}"
readonly REQUIRE_LINT="${REQUIRE_LINT:-0}"
readonly STEP_TIMEOUT_SECONDS=180
# Erro de script em GDScript não muda o exit code do Godot: a saída é a verdade.
readonly GODOT_PROBLEM_PATTERN='(SCRIPT ERROR|Parse Error|(^|[^A-Za-z])(ERROR|WARNING):)'

readonly LOG_FILE="$(mktemp)"
trap 'rm -f "$LOG_FILE"' EXIT

failed_steps=()

fail_step() {
  echo "FALHOU: $1"
  failed_steps+=("$1")
}

strip_ansi() {
  sed -E 's/\x1b\[[0-9;]*[A-Za-z]//g'
}

show_problem_lines() {
  grep -En "$GODOT_PROBLEM_PATTERN" "$LOG_FILE" | head -20 || true
}

# Roda um comando do Godot; falha por exit code OU por ERROR/WARNING na saída.
run_godot_step() {
  local step_name="$1"
  shift
  echo "==> $step_name"
  local exit_code=0
  timeout "$STEP_TIMEOUT_SECONDS" "$GODOT" --headless --path "$GAME_DIR" "$@" 2>&1 \
    | strip_ansi >"$LOG_FILE" || exit_code=${PIPESTATUS[0]}
  tail -n 5 "$LOG_FILE"
  if [[ "$exit_code" -ne 0 ]]; then
    fail_step "$step_name (exit code $exit_code)"
  elif grep -Eq "$GODOT_PROBLEM_PATTERN" "$LOG_FILE"; then
    show_problem_lines
    fail_step "$step_name (ERROR/WARNING na saída)"
  fi
}

run_lint_step() {
  echo "==> lint (gdlint)"
  if ! command -v "$GDLINT" >/dev/null 2>&1; then
    if [[ "$REQUIRE_LINT" == "1" ]]; then
      fail_step "lint (gdlint não encontrado e REQUIRE_LINT=1)"
    else
      echo "gdlint não encontrado: lint PULADO (pip install gdtoolkit)"
    fi
    return
  fi
  (cd "$GAME_DIR" && "$GDLINT" src tests) || fail_step "lint"
}

run_extra_steps() {
  local extra_script
  for extra_script in "$REPO_ROOT"/tools/checks.d/*.sh; do
    [[ -e "$extra_script" ]] || continue
    echo "==> $(basename "$extra_script")"
    bash "$extra_script" || fail_step "$(basename "$extra_script")"
  done
}

main() {
  run_godot_step "import" --import
  run_godot_step "testes" --script res://tests/run_tests.gd
  run_godot_step "cena do jogo (Main, 120 frames)" res://src/world/Main.tscn --quit-after 120
  run_godot_step "cena inicial (apresentação, 120 frames)" --quit-after 120
  run_lint_step
  run_extra_steps

  if [[ ${#failed_steps[@]} -gt 0 ]]; then
    echo
    echo "VERMELHO: ${#failed_steps[@]} etapa(s) falharam"
    printf '  - %s\n' "${failed_steps[@]}"
    exit 1
  fi
  echo
  echo "VERDE: todas as etapas passaram"
}

main "$@"
