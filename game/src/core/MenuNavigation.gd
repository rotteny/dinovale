# SPDX-License-Identifier: MIT
class_name MenuNavigation
extends RefCounted
## Seleção de um menu vertical: lógica pura, sem UI. Itens `{id, enabled}`; o desabilitado nunca
## é selecionado nem ativado, e o movimento dá a volta nas pontas.

var _items: Array[Dictionary] = []
var _index: int = -1


func _init(items: Array[Dictionary] = []) -> void:
	set_items(items)


## Troca os itens e seleciona o primeiro habilitado (-1 se nenhum).
func set_items(items: Array[Dictionary]) -> void:
	_items = items.duplicate(true)
	_index = _first_enabled_from(0, 1)


## Volta a seleção para o primeiro item habilitado (reabrir um menu).
func reset() -> void:
	_index = _first_enabled_from(0, 1)


func count() -> int:
	return _items.size()


func index() -> int:
	return _index


func current_id() -> String:
	return str(_items[_index]["id"]) if _index >= 0 else ""


func is_enabled(i: int) -> bool:
	return i >= 0 and i < _items.size() and bool(_items[i].get("enabled", true))


## Anda `step` (+1 desce, -1 sobe) até o próximo habilitado, dando a volta. Sem habilitado: nada.
func move(step: int) -> void:
	if _items.is_empty() or step == 0:
		return
	var direction := 1 if step > 0 else -1
	var start := _index if _index >= 0 else (0 if direction > 0 else _items.size() - 1)
	var next := _first_enabled_from(posmod(start + direction, _items.size()), direction)
	if next >= 0:
		_index = next


## Seleciona o item `i` (mouse). Desabilitado ou fora do intervalo: ignora. Devolve se mudou.
func select(i: int) -> bool:
	if not is_enabled(i) or i == _index:
		return false
	_index = i
	return true


## Id do item selecionado, ou "" se nada está selecionado ou ele está desabilitado.
func activate() -> String:
	return current_id() if is_enabled(_index) else ""


func _first_enabled_from(start: int, direction: int) -> int:
	for n in _items.size():
		var i := posmod(start + n * direction, _items.size())
		if is_enabled(i):
			return i
	return -1
