# SPDX-License-Identifier: MIT
class_name HotbarComponent
extends Node
## Barra de atalhos (teclas 1 a 9, GDD 5.2 e 5.9). Cada posição guarda uma de duas coisas:
##   tipo    `{id}`   item empilhável (comida): mostra a soma das pilhas; sem estoque fica
##                    apagado mas atribuído e volta quando houver;
##   `iid`   `{iid, id?}` item individual (arma, ferramenta): segue o item ao movê-lo no inventário.
##                    `id` é só a dica do tipo (para mostrar o ícone apagado se o item sumir).
## Posição vazia é `{}`. Dado de perfil do jogador: não valida estoque. Não conhece UI nem input.
## Save v2: `{version, slots: [entrada]}`. O v1 (`slots` de strings com o tipo) é migrado.

signal changed

const SLOT_COUNT := 9
const FORMAT_VERSION := 2
const MAX_IID_LENGTH := 32

var _slots: Array[Dictionary] = []


func _init() -> void:
	_slots.resize(SLOT_COUNT)
	_slots.fill({})


## Cópia da entrada da posição (0 a 8): `{}`, `{id}` ou `{iid, id?}`.
func entry_at(index: int) -> Dictionary:
	return _slots[index].duplicate() if index >= 0 and index < SLOT_COUNT else {}


## Tipo de item empilhável da posição, ou "" (vazia, ou item individual).
func item_at(index: int) -> String:
	var entry := entry_at(index)
	return "" if entry.has("iid") else str(entry.get("id", ""))


## Tipo do item da posição, mesmo se for individual (dica do `iid`); "" se vazia ou sem dica.
func type_at(index: int) -> String:
	return str(entry_at(index).get("id", ""))


## `iid` do item individual da posição, ou "".
func iid_at(index: int) -> String:
	return str(entry_at(index).get("iid", ""))


## Atribui um TIPO empilhável a uma posição. Individual (equipamento) é recusado: use
## `assign_iid`. O mesmo tipo não fica em duas posições. Retorna true se mudou.
func assign(index: int, item_id: String) -> bool:
	if Items.get_def(item_id) == null or Items.is_individual(item_id):
		return false
	return _place(index, {"id": item_id})


## Atribui um item individual pelo `iid`; `item_id` (opcional, individual conhecido) fica
## como dica do tipo. Retorna true se mudou.
func assign_iid(index: int, iid: String, item_id: String = "") -> bool:
	if iid == "" or iid.length() > MAX_IID_LENGTH:
		return false
	var entry := {"iid": iid}
	if Items.is_individual(item_id):
		entry["id"] = item_id
	return _place(index, entry)


func clear(index: int) -> bool:
	if index < 0 or index >= SLOT_COUNT or _slots[index].is_empty():
		return false
	_slots[index] = {}
	changed.emit()
	return true


## Primeira posição com o tipo, ou -1.
func slot_of(item_id: String) -> int:
	return _find({"id": item_id}) if item_id != "" and not Items.is_individual(item_id) else -1


## Primeira posição com o `iid`, ou -1.
func slot_of_iid(iid: String) -> int:
	return _find({"iid": iid}) if iid != "" else -1


## Primeira posição vazia, ou -1.
func first_free() -> int:
	return _find({})


func to_dict() -> Dictionary:
	var slots: Array = []
	for slot in _slots:
		slots.append(slot.duplicate())
	return {"version": FORMAT_VERSION, "slots": slots}


## Restaura sem validar estoque. Valida tipo e item conhecido; repetido fica só na primeira.
## Contrato do retorno (SAV-01): `true` = aplicado; `false` = RECUSADO e nada mudou (`slots` não é
## Array, ou versão inválida ou maior que a conhecida). `false` não é carga parcial.
func from_dict(data: Dictionary) -> bool:
	var saved: Variant = data.get("slots")
	if typeof(saved) != TYPE_ARRAY or SafeRead.format_version(data, FORMAT_VERSION) == 0:
		return false
	var restored: Array[Dictionary] = []
	restored.resize(SLOT_COUNT)
	restored.fill({})
	var seen: Array[String] = []
	for i in mini((saved as Array).size(), SLOT_COUNT):
		var entry := _clean(saved[i])
		var key := _key_of(entry)
		if key != "" and not seen.has(key):
			restored[i] = entry
			seen.append(key)
	_slots = restored
	changed.emit()
	return true


## Entrada do save: string (v1, tipo), `{id}` ou `{iid, id?}`. Qualquer outra coisa vira `{}`.
func _clean(raw: Variant) -> Dictionary:
	var item_id := ""
	var iid := ""
	if typeof(raw) == TYPE_STRING:
		item_id = raw
	elif typeof(raw) == TYPE_DICTIONARY:
		item_id = SafeRead.text(raw.get("id"), "")
		iid = SafeRead.text(raw.get("iid"), "")
	if iid != "" and iid.length() <= MAX_IID_LENGTH:
		return {"iid": iid, "id": item_id} if Items.is_individual(item_id) else {"iid": iid}
	if Items.get_def(item_id) != null and not Items.is_individual(item_id):
		return {"id": item_id}
	return {}


## Chave de identidade da entrada ("" = vazia): o `iid` ou o tipo.
func _key_of(entry: Dictionary) -> String:
	if entry.has("iid"):
		return "i:" + str(entry["iid"])
	return "t:" + str(entry["id"]) if entry.has("id") else ""


func _place(index: int, entry: Dictionary) -> bool:
	if index < 0 or index >= SLOT_COUNT or _slots[index] == entry:
		return false
	var old := _find(entry)
	if old >= 0:
		_slots[old] = {}
	_slots[index] = entry
	changed.emit()
	return true


func _find(entry: Dictionary) -> int:
	var key := _key_of(entry)
	for i in SLOT_COUNT:
		if _key_of(_slots[i]) == key:
			return i
	return -1
