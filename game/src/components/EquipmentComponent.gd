# SPDX-License-Identifier: MIT
class_name EquipmentComponent
extends Node
## Vagas de equipamento (PRO-22, GDD 5.20). O item equipado SAI da grade do `inventory` e fica
## na vaga, inteiro (`{id, iid, durab, durab_max}`, o mesmo formato do individual). Só cabe na
## vaga declarada em `ItemDef.slot`. Lógica pura, sem UI nem input: quem pede (tecla, tela, rede)
## chama `equip`/`unequip`, que validam e devolvem o motivo da recusa ("" = ok). A recarga de
## 0,3 s é de quem pede (o `Player`).
##
## Save `{version: 1, slots: {vaga: entrada}}`. A entrada inteira vai no save porque o item não
## está mais na grade (o GDD guarda `{vaga: iid}`; aqui o `iid` é a chave dentro da entrada).

## Mudou o que está em alguma vaga (também em `from_dict`; não é evento de jogo).
signal changed

const FORMAT_VERSION := 1
## Motivos de recusa devolvidos por `equip` e `unequip`.
const REFUSED_MISSING := "missing"
const REFUSED_UNKNOWN_SLOT := "unknown_slot"
const REFUSED_WRONG_SLOT := "wrong_slot"
const REFUSED_EMPTY_SLOT := "empty_slot"
const REFUSED_FULL := "full"

@export var layout: EquipmentLayout = preload("res://data/equipment/layout.tres")
## A grade de onde o item sai e para onde volta.
@export var inventory: InventoryComponent

var _worn: Dictionary = {}


## Texto da recusa para o jogador, ou "" (vaga errada recusa sem mensagem, GDD 5.20).
static func refusal_message(reason: String) -> String:
	return "Inventário cheio" if reason == REFUSED_FULL else ""


## Cópia do item da vaga, ou `{}`.
func item_in(slot_id: String) -> Dictionary:
	var entry: Variant = _worn.get(slot_id)
	return (entry as Dictionary).duplicate() if entry is Dictionary else {}


func iid_in(slot_id: String) -> String:
	return str(item_in(slot_id).get("iid", ""))


## Vaga que guarda este `iid`, ou "".
func slot_of_iid(iid: String) -> String:
	if iid == "":
		return ""
	for slot_id: String in _worn:
		if _worn[slot_id]["iid"] == iid:
			return slot_id
	return ""


func has_iid(iid: String) -> bool:
	return slot_of_iid(iid) != ""


## Cópia do item equipado com este `iid`, ou `{}`.
func find_iid(iid: String) -> Dictionary:
	return item_in(slot_of_iid(iid))


## Quantos do tipo estão equipados (cada vaga guarda 1).
func count(item_id: String) -> int:
	var total := 0
	for slot_id: String in _worn:
		if _worn[slot_id]["id"] == item_id:
			total += 1
	return total


## Equipa o item `iid` que está na grade. `slot_id` "" = a vaga declarada pelo item. Vaga ocupada:
## troca (o item antigo volta à grade, no espaço que o novo liberou). Devolve "" ou o motivo.
func equip(iid: String, slot_id: String = "") -> String:
	var item := inventory.find_iid(iid)
	if item.is_empty():
		return REFUSED_MISSING
	var target := slot_id if slot_id != "" else Items.slot_of(item["id"])
	if not layout.has_slot(target):
		return REFUSED_UNKNOWN_SLOT
	if Items.slot_of(item["id"]) != target:
		return REFUSED_WRONG_SLOT
	var origin := inventory.index_of_iid(iid)
	var entry := inventory.remove_iid(iid)
	var old := item_in(target)
	if not old.is_empty() and not inventory.put_individual_at(origin, old):  # o antigo volta ao slot de onde o novo saiu
		inventory.add_entry(entry)  # não deveria ocorrer: o slot do novo acabou de vagar
		return REFUSED_FULL
	_worn[target] = entry
	changed.emit()
	return ""


## Tira o item da vaga para a grade. Sem posição livre na grade, recusa e nada muda.
func unequip(slot_id: String) -> String:
	if not layout.has_slot(slot_id):
		return REFUSED_UNKNOWN_SLOT
	var item := item_in(slot_id)
	if item.is_empty():
		return REFUSED_EMPTY_SLOT
	if inventory.add_entry(item) != 0:
		return REFUSED_FULL
	_worn.erase(slot_id)
	changed.emit()
	return ""


## Gasta `amount` de durabilidade do item da vaga. Chegando a 0 ele QUEBRA: sai da vaga e some (não volta ao inventário).
## Devolve o id do item que quebrou, ou "" (nada quebrou, vaga vazia ou item sem durabilidade).
func wear(slot_id: String, amount: int = 1) -> String:
	var entry: Variant = _worn.get(slot_id)
	if entry == null or not (entry as Dictionary).has("durab") or amount <= 0:
		return ""
	var item: Dictionary = entry
	item["durab"] = maxi(int(item["durab"]) - amount, 0)
	if int(item["durab"]) > 0:
		changed.emit()
		return ""
	var broken := str(item["id"])
	_worn.erase(slot_id)
	changed.emit()
	return broken


func to_dict() -> Dictionary:
	var slots := {}
	for slot_id: String in _worn:
		slots[slot_id] = (_worn[slot_id] as Dictionary).duplicate()
	return {"version": FORMAT_VERSION, "slots": slots}


## Restaura sem evento de jogo. CONTRATO DO RETORNO (SAV-01): `true` = aplicado; `false` = RECUSADO
## e nada mudou (nem o `next_iid` da grade). Recusa: versão inválida ou maior; `slots` ausente ou
## que não é dicionário; vaga desconhecida; item que não é individual conhecido ou não cabe na
## vaga; `iid` repetido entre vagas ou igual ao de um item da grade (`grid`, por padrão o
## `inventory`): o mesmo item não pode estar em dois lugares. Nada some calado: item inválido
## recusa o bloco todo. `iid` ausente ou inválido ganha um novo da grade, só ao aplicar;
## durabilidade ausente cai no padrão cheio.
func from_dict(data: Dictionary, grid: InventoryComponent = inventory) -> bool:
	var parsed: Variant = _parse(data, grid)
	if parsed == null:
		return false
	for slot_id: String in parsed:
		if parsed[slot_id]["iid"] == "":
			parsed[slot_id]["iid"] = grid.issue_iid()
	_worn = parsed
	changed.emit()
	return true


## Responde se `from_dict(data, grid)` seria aplicado, sem mudar nada.
func can_load(data: Dictionary, grid: InventoryComponent = inventory) -> bool:
	return _parse(data, grid) != null


## Valida e limpa sem tocar em `grid`: a limpeza roda numa cópia vazia (`preview`), então nenhum
## contador da grade real muda. Devolve `{vaga: entrada}` (entrada sem `iid` válido fica com "" até
## aplicar) ou `null` se recusado.
func _parse(data: Dictionary, grid: InventoryComponent) -> Variant:
	var saved: Variant = data.get("slots")
	if SafeRead.format_version(data, FORMAT_VERSION) == 0 or typeof(saved) != TYPE_DICTIONARY:
		return null
	var scratch := grid.preview()
	var result: Variant = _parse_slots(saved, grid, scratch)
	scratch.free()
	return result


func _parse_slots(saved: Dictionary, grid: InventoryComponent, scratch: InventoryComponent) -> Variant:
	var result := {}
	var seen := {}
	for slot_id: Variant in saved:
		var raw: Variant = saved[slot_id]
		if typeof(slot_id) != TYPE_STRING or not layout.has_slot(slot_id) or typeof(raw) != TYPE_DICTIONARY:
			return null
		var entry := scratch.clean_individual_entry(raw)
		if entry.is_empty() or Items.slot_of(entry["id"]) != slot_id:
			return null
		if entry["iid"] != SafeRead.text(raw.get("iid"), ""):
			entry["iid"] = ""  # ausente ou inválido: a grade emite um novo ao aplicar
		elif seen.has(entry["iid"]) or grid.has_iid(entry["iid"]):
			return null
		else:
			seen[entry["iid"]] = true
		result[slot_id] = entry
	return result
