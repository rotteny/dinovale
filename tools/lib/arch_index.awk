# SPDX-License-Identifier: MIT
# Indexa código GDScript sem comentários, uma linha por instrução:
#
#   caminho<TAB>linha<TAB>função<TAB>código
#
# "função" é a função de nível superior que contém a linha ("-" fora de função).
# Comentários (# e ##) saem; um # dentro de string é preservado.
# Uso: awk -v root=/caminho/game -f arch_index.awk arquivo.gd...

function strip_comment(text,    i, ch, quote, out) {
  quote = ""
  out = ""
  for (i = 1; i <= length(text); i++) {
    ch = substr(text, i, 1)
    if (quote != "") {
      out = out ch
      if (ch == "\\") {
        i++
        out = out substr(text, i, 1)
      } else if (ch == quote) {
        quote = ""
      }
    } else if (ch == "\"" || ch == "'") {
      quote = ch
      out = out ch
    } else if (ch == "#") {
      break
    } else {
      out = out ch
    }
  }
  return out
}

function relative_path(path) {
  return substr(path, length(root) + 2)
}

FNR == 1 { current_function = "" }

{
  code = strip_comment($0)
  if (code ~ /^[ \t]*$/) next

  if (code ~ /^(static[ \t]+)?func[ \t]/) {
    code_name = code
    sub(/^(static[ \t]+)?func[ \t]+/, "", code_name)
    sub(/[^A-Za-z0-9_].*$/, "", code_name)
    current_function = code_name
  } else if (code !~ /^[ \t]/) {
    current_function = ""
  }

  sub(/^[ \t]+/, "", code)
  sub(/[ \t]+$/, "", code)
  printf "%s\t%d\t%s\t%s\n", relative_path(FILENAME), FNR, (current_function == "" ? "-" : current_function), code
}
