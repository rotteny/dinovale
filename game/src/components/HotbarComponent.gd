# SPDX-License-Identifier: MIT
class_name HotbarComponent
extends Node
## Barra de atalhos (teclas 1 a 9, GDD 5.2). Cada posição guarda o ID do TIPO de item,
## não um slot do inventário: a quantidade é a soma das pilhas e, sem estoque, o atalho
## continua atribuído (apagado) e volta quando houver. Dado de perfil do jogador: não
## valida estoque. Não conhece UI nem input.

signal changed

const SLOT_COUNT := 9

var _slots: Array[String] = []


func _init() -> void:
	_slots.resize(SLOT_COUNT)
	_slots.fill("")


## Item da posição (0 a 8), ou "" se vazia ou fora da faixa.
func item_at(index: int) -> String:
	return _slots[index] if index >= 0 and index < SLOT_COUNT else ""


## Atribui o tipo de item a uma posição. Item desconhecido ou posição inválida: nada.
## O mesmo item não fica em duas posições: mover tira da antiga. Retorna true se mudou.
func assign(index: int, item_id: String) -> bool:
	if index < 0 or index >= SLOT_COUNT or Items.get_def(item_id) == null or _slots[index] == item_id:
		return false
	var old := slot_of(item_id)
	if old >= 0:
		_slots[old] = ""
	_slots[index] = item_id
	changed.emit()
	return true


func clear(index: int) -> bool:
	if index < 0 or index >= SLOT_COUNT or _slots[index] == "":
		return false
	_slots[index] = ""
	changed.emit()
	return true


## Primeira posição com o item, ou -1.
func slot_of(item_id: String) -> int:
	return _slots.find(item_id) if item_id != "" else -1


## Primeira posição vazia, ou -1.
func first_free() -> int:
	return _slots.find("")


func to_dict() -> Dictionary:
	return {"slots": _slots.duplicate()}


## Restaura sem validar estoque. Valida tipo e item conhecido; repetido fica só na primeira.
## Se `slots` não for um Array, mantém o atual.
func from_dict(data: Dictionary) -> void:
	var saved: Variant = data.get("slots")
	if typeof(saved) != TYPE_ARRAY:
		return
	var restored: Array[String] = []
	restored.resize(SLOT_COUNT)
	restored.fill("")
	var seen: Dictionary = {}
	for i in mini((saved as Array).size(), SLOT_COUNT):
		var item_id := SafeRead.text(saved[i], "")
		if Items.get_def(item_id) != null and not seen.has(item_id):
			restored[i] = item_id
			seen[item_id] = true
	_slots = restored
	changed.emit()
