# SPDX-License-Identifier: MIT
class_name CreditsText
extends RefCounted
## Texto da tela de Créditos, montado a partir de `assets/CREDITS.md` (a única fonte): a linha de
## licenças do projeto e, para cada autor/licença/fonte distintos da tabela de registro, os arquivos.
## Nada é escrito à mão aqui, então o texto não diverge do arquivo.

const SOURCE := "res://assets/CREDITS.md"
const LICENSE_PREFIX := "Licença dos assets próprios"
## Mostrada no lugar do texto quando o arquivo não veio na exportação (falta no filtro de include).
const UNAVAILABLE := "Créditos indisponíveis: o arquivo assets/CREDITS.md não está nesta versão do jogo."


static func load_text() -> String:
	if not FileAccess.file_exists(SOURCE):
		return UNAVAILABLE
	return from_markdown(FileAccess.get_file_as_string(SOURCE))


static func from_markdown(markdown: String) -> String:
	var lines: Array[String] = []
	var groups: Dictionary = {}
	var in_registry := false
	var in_comment := false
	for raw in markdown.split("\n"):
		var line := raw.strip_edges()
		# Comentário HTML (os exemplos do arquivo) não é crédito.
		if line.begins_with("<!--"):
			in_comment = true
		if in_comment:
			in_comment = not line.contains("-->")
			continue
		if line.begins_with(LICENSE_PREFIX):
			lines.append(_plain(line))
		elif line.begins_with("## Registro"):
			in_registry = true
		elif in_registry and line.begins_with("|"):
			var cells := _cells(line)
			if cells.size() >= 6 and cells[0] != "Arquivo" and not cells[0].begins_with("---"):
				var key := "%s\t%s\t%s\t%s" % [cells[2], cells[4], cells[3], cells[1]]
				if not groups.has(key):
					groups[key] = []
				groups[key].append(cells[0])
	lines.append("")
	for key: String in groups:
		var parts := key.split("\t")
		lines.append("%s" % parts[0])
		lines.append("  Licença: %s" % parts[1])
		lines.append("  Origem: %s" % parts[3])
		if parts[2] != "-":
			lines.append("  Fonte: %s" % parts[2])
		lines.append("  Arquivos: %s" % "; ".join(groups[key]))
		lines.append("")
	var text := "\n".join(lines).strip_edges()
	return text if text != "" else UNAVAILABLE


static func _cells(line: String) -> Array[String]:
	var result: Array[String] = []
	for cell in line.trim_prefix("|").trim_suffix("|").split("|"):
		result.append(_plain(cell.strip_edges()))
	return result


static func _plain(text: String) -> String:
	return text.replace("`", "").replace("**", "")
