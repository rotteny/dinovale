#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Testes de arquitetura (INF-03): varredura estática de game/src, sem Godot.
# Regras vêm do ADR-001 (R-A a R-F) e do ADR-002 (dado não confiável, from_dict).
#
# Cada regra lê um índice do código SEM comentários (tools/lib/arch_index.awk):
#   caminho<TAB>linha<TAB>função<TAB>código
#
# Allowlist exata: uma exceção que passou a não ser necessária também falha, então
# nunca sobra lixo. Exceção temporária leva o ID da tarefa que a remove.
#
# Variável opcional:
#   ARCH_GAME_DIR  raiz do projeto Godot a varrer (padrão: <repo>/game). Serve para
#                  provar que cada regra fica vermelha sem sujar o código real.
set -euo pipefail
# Permite `comando | judge ...` alterar o contador no shell principal.
shopt -s lastpipe

readonly REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
readonly GAME_DIR="${ARCH_GAME_DIR:-$REPO_ROOT/game}"
readonly INDEX_AWK="$REPO_ROOT/tools/lib/arch_index.awk"
readonly SAVEABLE_TABLE="$GAME_DIR/tests/saveable_table.gd"

readonly SIMULATION_DIRS='src/(core|components|entities)/'
readonly SAFE_COMPONENT_BASES=" Node RefCounted Object Resource "
readonly NON_REPLAYABLE_SIGNALS='died|knocked_out|food_consumed|starved'
readonly MUTATORS='transfer|transfer_slot|add|remove|take_damage|apply_torpor|mark_tamed'

INDEX="$(mktemp)"
trap 'rm -f "$INDEX"' EXIT
total_violations=0

# ---------------------------------------------------------------- infraestrutura

build_index() {
  find "$GAME_DIR/src" -name '*.gd' | sort \
    | xargs awk -v root="$GAME_DIR" -f "$INDEX_AWK" >"$INDEX"
}

# index_grep ESCOPO CODIGO: linhas do índice cujo caminho casa ESCOPO (PCRE) e cujo
# código casa CODIGO (PCRE).
index_grep() {
  grep -P "^(?:$1)[^\t]*\t[^\t]*\t[^\t]*\t.*?(?:$2)" "$INDEX" || true
}

report() {
  echo "  FALHA [$1] $2"
  total_violations=$((total_violations + 1))
}

# judge REGRA DICA [caminho=MOTIVO ...]: lê violações (formato do índice) no stdin.
# Violação fora da allowlist falha; item da allowlist sem violação também.
judge() {
  local rule="$1" hint="$2"
  shift 2
  local -A allowed=() used=() seen=()
  local entry path line function_name code
  local violations_before=$total_violations
  for entry in "$@"; do
    allowed["${entry%%=*}"]="${entry#*=}"
  done
  while IFS=$'\t' read -r path line function_name code; do
    [[ -n "$path" && -z "${seen[$path:$line]+set}" ]] || continue
    seen["$path:$line"]=1
    if [[ -n "${allowed[$path]+set}" ]]; then
      used["$path"]=1
    else
      report "$rule" "$path:$line: $code -> $hint"
    fi
  done
  for path in "${!allowed[@]}"; do
    if [[ -z "${used[$path]+set}" ]]; then
      report "$rule" "exceção obsoleta: $path não viola mais; remova da allowlist (${allowed[$path]})"
    fi
  done
  [[ $total_violations -eq $violations_before ]] && echo "  ok   [$rule]"
  return 0
}

# ----------------------------------------------------------------------- regras

# R-D / ADR-001: componente não herda CanvasItem (nem por cadeia de class_name).
rule_components_are_not_canvas_items() {
  declare -A extends_of=() class_of=()
  local path line function_name code
  while IFS=$'\t' read -r path line function_name code; do
    case "$code" in
      "extends "*) extends_of["$path"]="${code#extends }" ;;
      "class_name "*) class_of["${code#class_name }"]="$path" ;;
    esac
  done <"$INDEX"

  for path in "${!extends_of[@]}"; do
    [[ "$path" == src/components/* ]] || continue
    local base="${extends_of[$path]}" depth=0
    while [[ -n "${class_of[$base]+set}" && $depth -lt 20 ]]; do
      base="${extends_of[${class_of[$base]}]:-Object}"
      depth=$((depth + 1))
    done
    if [[ "$SAFE_COMPONENT_BASES" != *" $base "* ]]; then
      printf '%s\t1\t-\textends %s (base %s)\n' "$path" "${extends_of[$path]}" "$base"
    fi
  done | judge "componente sem CanvasItem" \
    "componente é lógica pura; herde de Node (ou ajuste SAFE_COMPONENT_BASES)" \
    "src/components/InteractableArea.gd=permanente, ADR-001: sensor físico, Area2D, não desenha"
}

# R-D: simulação só em _physics_process, com delta. Sem relógio de parede.
rule_simulation_has_no_wall_clock() {
  index_grep "$SIMULATION_DIRS" '(?<![\w])_process\b|(?<![\w.])Time\.|\bOS\.get_ticks\w*' \
    | judge "simulação sem _process/Time/OS.get_ticks" \
      "use _physics_process(delta); relógio de parede quebra o servidor e o teste"
}

# R-F: lógica não conhece UI.
rule_logic_does_not_know_ui() {
  local ui_classes
  ui_classes="$(awk -F'\t' '$1 ~ /^src\/ui\// && $4 ~ /^class_name /' "$INDEX" \
    | cut -f4 | sed 's/^class_name //' | paste -sd'|')"
  {
    index_grep "$SIMULATION_DIRS" "res://src/ui/${ui_classes:+|\\b($ui_classes)\\b}"
    grep -rnP 'src/ui/' --include='*.tscn' "$GAME_DIR"/src/{core,components,entities} 2>/dev/null \
      | awk -F: -v root="$GAME_DIR" '{ p = substr($1, length(root) + 2); print p "\t" $2 "\t-\t" $3 }' || true
  } | judge "lógica sem dependência de UI" \
    "core/components/entities não referenciam src/ui/; a UI observa sinais"
}

# ADR-002: dado externo nunca executa código nem carrega recurso arbitrário.
rule_no_unsafe_deserialization() {
  index_grep 'src/' '\b(bytes_to_var_with_objects|str_to_var|dict_to_inst)\b|\bget_var\(\s*true\b|\bConfigFile\b|(?<![\w])(?:load|load_threaded_request)\(\s*(?!"res://)' \
    | judge "sem desserialização insegura" \
      "só JSON; load() só com literal res:// (nunca user://); ConfigFile proibido (o formato executa código; configuração em JSON)"
}

# Créditos (CC-BY exige atribuição): o preset de exportação versionado tem de incluir CREDITS.md,
# que o Godot não exporta sozinho (não é recurso). Sem segredo nem caminho local no arquivo.
rule_export_includes_credits() {
  local preset="$GAME_DIR/export_presets.cfg"
  local rule="exportação inclui os créditos"
  local before=$total_violations
  if [[ ! -f "$preset" ]]; then
    report "$rule" "game/export_presets.cfg não existe (versione o preset)"
  else
    grep -qP '^include_filter="[^"]*assets/CREDITS\.md' "$preset" \
      || report "$rule" "include_filter do preset sem assets/CREDITS.md"
    grep -nP '/home/|/Users/|[A-Za-z]:\\|^(script_encryption_key|keystore\S*|.*password\S*|.*_key)\s*=\s*"[^"]' "$preset" \
      | { while IFS= read -r hit; do report "$rule" "segredo ou caminho local no preset: ${hit%%=*}"; done; } || true
  fi
  [[ $total_violations -eq $before ]] && echo "  ok   [$rule]"
  return 0
}

# Asset de apresentação (imagem) não entra na lógica: quem mostra o ícone é a UI.
rule_no_presentation_assets_in_logic() {
  index_grep 'src/(core|components|entities)/' '\b(preload|load)\(\s*"[^"]*\.(png|jpe?g|webp|svg|bmp)"' \
    | judge "sem asset de imagem em core/components/entities" \
      "o mapa item -> ícone fica em src/ui (ItemIcons)"
}

# R-B: referência entre máquinas ou em save usa ID estável.
rule_no_instance_ids_in_data() {
  {
    index_grep 'src/' '\b(get_instance_id|instance_from_id)\b'
    index_grep 'src/' '\b(NodePath|get_path)\b' | awk -F'\t' '$3 == "to_dict"'
  } | judge "sem get_instance_id em dados" \
    "use o ID estável da entidade (ADR-003), nunca instance_id nem NodePath"
}

# R-E: Input só em PlayerController e src/ui/.
rule_input_only_in_controller_and_ui() {
  index_grep 'src/(?!ui/)(?!.*PlayerController\.gd)' \
    '\bInput\b|\bInputEvent\w*|\bfunc _(unhandled_)?(key_)?input\b' \
    | judge "Input só em PlayerController e src/ui" \
      "mova a leitura de input para o PlayerController (ADR-001, NET-01)" \
      "src/entities/player/Player.gd=remover em NET-01 (extrai read_direction e _unhandled_input para PlayerController)"
}

# R-F: a UI observa, não muda estado.
rule_ui_does_not_call_mutators() {
  index_grep 'src/ui/' "\.($MUTATORS)\("  \
    | judge "UI sem mutadores" \
      "a UI pede por request_*; não chama transfer/add/remove/take_damage direto" \
      "src/ui/InventoryScreen.gd=remover em NET-01 (passa a chamar request_transfer_slot)"
}

# R-C: sem RNG global; RNG local só com seed derivada.
rule_no_global_rng() {
  {
    index_grep 'src/' '(?<![\w.])(randf|randi|randf_range|randi_range|randfn|randomize|rand_from_seed)\('
    index_grep 'src/' '\.(shuffle|pick_random)\('
    index_grep 'src/' '\bRandomNumberGenerator\.new\('
  } | judge "RNG sem seed derivada" \
    "derive o RNG da seed do mundo e do ID da entidade (ADR-003); nada de RNG global" \
    "src/entities/dino/DinoStateMachine.gd=remover na tarefa de seed derivada (ADR-001 NET-01 / ADR-003: hash([seed, entity_id]))"
}

# Todo script com to_dict consta na tabela de roundtrip por JSON, e só ele.
rule_every_saveable_is_in_roundtrip_table() {
  local saveables tabled
  saveables="$(index_grep 'src/' 'func to_dict\b' | cut -f1 | sort -u)"
  tabled="$(sed -n '/SAVEABLES-BEGIN/,/SAVEABLES-END/p' "$SAVEABLE_TABLE" \
    | grep -oP '"res://\K[^"]+\.gd' | sort -u)"
  {
    comm -23 <(echo "$saveables") <(echo "$tabled") \
      | awk 'NF { print $0 "\t1\t-\tto_dict fora da tabela game/tests/saveable_table.gd" }'
    comm -13 <(echo "$saveables") <(echo "$tabled") \
      | awk 'NF { print $0 "\t1\t-\tentrada da tabela sem to_dict (script removido ou renomeado)" }'
  } | judge "saveable na tabela de roundtrip" \
    "adicione o script a SCRIPTS e um caso em build() de game/tests/saveable_table.gd"
}

# ADR-002: restaurar não é evento de jogo. from_dict nunca emite (nem por helper)
# os sinais que disparam consequência. Chamadas são resolvidas por nome, em todo src/.
rule_from_dict_does_not_emit_game_events() {
  local emit_pattern="\b($NON_REPLAYABLE_SIGNALS)\.emit\(|emit_signal\(\s*[\"'](${NON_REPLAYABLE_SIGNALS})[\"']"
  local emitters changed name
  emitters="$(index_grep 'src/' "$emit_pattern" | cut -f3 | sort -u | grep -vx -e '-' -e 'from_dict' || true)"
  changed=1
  while [[ $changed -eq 1 ]]; do
    changed=0
    while IFS= read -r name; do
      [[ -n "$name" && "$name" != "from_dict" && "$name" != "-" ]] || continue
      grep -qx "$name" <<<"$emitters" && continue
      if calls_any "$name" "$emitters"; then
        emitters+=$'\n'"$name"
        changed=1
      fi
    done < <(cut -f3 "$INDEX" | sort -u)
  done

  {
    index_grep 'src/' "$emit_pattern" | awk -F'\t' '$3 == "from_dict"'
    local emitter
    while IFS= read -r emitter; do
      [[ -n "$emitter" ]] || continue
      grep -P "\t[^\t]*\tfrom_dict\t(?!func ).*?(?<![\w])$emitter\(" "$INDEX" || true
    done <<<"$emitters"
  } | judge "from_dict não emite eventos de jogo" \
    "$NON_REPLAYABLE_SIGNALS: restaurar não é evento; emita só *_changed"
}

# calls_any FUNCAO EMISSORES: a função chama algum emissor?
calls_any() {
  local function_name="$1" emitter
  while IFS= read -r emitter; do
    [[ -n "$emitter" ]] || continue
    if awk -F'\t' -v f="$function_name" '$3 == f' "$INDEX" \
        | grep -qP "^(?:[^\t]*\t){3}(?!func ).*?(?<![\w])$emitter\("; then
      return 0
    fi
  done <<<"$2"
  return 1
}

main() {
  [[ -f "$SAVEABLE_TABLE" ]] || { echo "FALHA: tabela $SAVEABLE_TABLE não existe"; exit 1; }
  build_index
  rule_components_are_not_canvas_items
  rule_simulation_has_no_wall_clock
  rule_logic_does_not_know_ui
  rule_no_unsafe_deserialization
  rule_no_presentation_assets_in_logic
  rule_export_includes_credits
  rule_no_instance_ids_in_data
  rule_input_only_in_controller_and_ui
  rule_ui_does_not_call_mutators
  rule_no_global_rng
  rule_every_saveable_is_in_roundtrip_table
  rule_from_dict_does_not_emit_game_events

  if [[ $total_violations -gt 0 ]]; then
    echo "arquitetura: $total_violations violação(ões)"
    exit 1
  fi
  echo "arquitetura: todas as regras passaram"
}

main "$@"
