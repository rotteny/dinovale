#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Exporta o jogo para Linux e Windows (INF-06). Roda da raiz ou de qualquer pasta:
#
#   tools/export.sh [linux|windows|all]     (padrão: all)
#
# Variáveis opcionais:
#   GODOT       binário do Godot (padrão: godot)
#   BUILD_DIR   saída (padrão: game/builds, fora do git)
#
# Requer os export templates da MESMA versão do Godot (Editor > Gerenciar templates de
# exportação). Sem assinatura de binário: não há chave nem senha neste fluxo.
set -euo pipefail

readonly REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly GAME_DIR="$REPO_ROOT/game"
readonly GODOT="${GODOT:-godot}"
readonly BUILD_DIR="${BUILD_DIR:-$GAME_DIR/builds}"
readonly STEP_TIMEOUT_SECONDS=300
readonly GAME_NAME="dinovale"

readonly TARGETS="${1:-all}"

# preset_for/output_for: único lugar que liga o alvo ao preset e ao arquivo.
preset_for() { case "$1" in linux) echo "Linux" ;; windows) echo "Windows" ;; esac; }
output_for() {
  case "$1" in
    linux) echo "$BUILD_DIR/linux/$GAME_NAME.x86_64" ;;
    windows) echo "$BUILD_DIR/windows/$GAME_NAME.exe" ;;
  esac
}

export_target() {
  local target="$1"
  local output
  output="$(output_for "$target")"
  mkdir -p "$(dirname "$output")"
  echo "==> export $target -> ${output#"$REPO_ROOT"/}"
  local log
  log="$(timeout "$STEP_TIMEOUT_SECONDS" "$GODOT" --headless --path "$GAME_DIR" \
    --export-release "$(preset_for "$target")" "$output" 2>&1)" || {
    echo "$log" | tail -20
    echo "FALHOU: export $target"
    return 1
  }
  if grep -Eq '(^|[^A-Za-z])ERROR:|SCRIPT ERROR' <<<"$log"; then
    echo "$log" | grep -E 'ERROR' | head -10
    echo "FALHOU: export $target (ERROR na saída)"
    return 1
  fi
  [[ -s "$output" ]] || { echo "FALHOU: $output não foi gerado"; return 1; }
  [[ -s "${output%.*}.pck" ]] || { echo "FALHOU: ${output%.*}.pck não foi gerado"; return 1; }
}

# Clone limpo não tem o cache de classes (game/.godot/): sem importar antes, o export falha.
import_project() {
  echo "==> import"
  timeout "$STEP_TIMEOUT_SECONDS" "$GODOT" --headless --path "$GAME_DIR" --import >/dev/null 2>&1
}

main() {
  import_project
  case "$TARGETS" in
    linux | windows) export_target "$TARGETS" || exit 1 ;;
    all)
      export_target linux || exit 1
      export_target windows || exit 1
      ;;
    *) echo "uso: tools/export.sh [linux|windows|all]"; exit 2 ;;
  esac
  echo "VERDE: export concluído em ${BUILD_DIR#"$REPO_ROOT"/}"
}

main "$@"
