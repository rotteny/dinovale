# SPDX-License-Identifier: MIT
class_name MessageLog
extends RefCounted
## Log de mensagens do sistema (lógica pura, sem nó). Cada linha: `{text, kind, source, age}`. `source` fica
## pronto para o chat do co-op ("system" hoje; nome do jogador depois). A idade avança por `tick(delta)`.

signal line_added(line: Dictionary)

var rules: MessageRules = preload("res://data/ui/message_rules.tres")
var _lines: Array[Dictionary] = []


func push(text: String, kind: GameMessages.Kind = GameMessages.Kind.INFO, source: String = "system") -> void:
	if text == "":
		return
	if not _lines.is_empty() and _lines[-1]["text"] == text and float(_lines[-1]["age"]) < rules.hold_seconds:
		_lines[-1]["age"] = 0.0  # repetição seguida (recusa a cada clique): renova a linha em vez de empilhar
		return
	var line := {"text": text, "kind": kind, "source": source, "age": 0.0}
	_lines.append(line)
	while _lines.size() > rules.history_max:
		_lines.pop_front()
	line_added.emit(line)


## Traduz um evento do jogo e o registra (código desconhecido não registra).
func push_event(code: String, params: Dictionary = {}) -> void:
	push(GameMessages.text_of(code, params), GameMessages.kind_of(code))


func tick(delta: float) -> void:
	for line in _lines:
		line["age"] = float(line["age"]) + delta


## Histórico completo, da mais antiga para a mais nova.
func history() -> Array[Dictionary]:
	return _lines.duplicate()


## Linhas recentes ainda visíveis no canto (no máximo `visible_lines`), da mais antiga para a mais nova.
func recent() -> Array[Dictionary]:
	var shown: Array[Dictionary] = []
	for line in _lines:
		if float(line["age"]) < rules.hold_seconds + rules.fade_seconds:
			shown.append(line)
	return shown.slice(maxi(shown.size() - rules.visible_lines, 0))


## Opacidade (0 a 1) da linha: inteira durante `hold_seconds`, depois cai linear em `fade_seconds`.
func alpha_of(line: Dictionary) -> float:
	var over := float(line["age"]) - rules.hold_seconds
	return 1.0 if over <= 0.0 else clampf(1.0 - over / rules.fade_seconds, 0.0, 1.0)
