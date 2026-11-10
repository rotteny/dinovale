# SPDX-License-Identifier: MIT
class_name EquipmentLayout
extends Resource
## As vagas de equipamento, em ordem de definição (dados em `res://data/equipment/`).

## Vaga que recebe qualquer item de mão (arma ou ferramenta).
const WEAPON := "weapon"
## Vaga da bolsa (Cesto, Mochila): o item equipado aumenta a grade do jogador (`SlotRules.bag_slots`).
const BAG := "bag"

@export var slots: Array[EquipmentSlotDef] = []


func has_slot(slot_id: String) -> bool:
	return slot_def(slot_id) != null


func slot_def(slot_id: String) -> EquipmentSlotDef:
	for def in slots:
		if def.id == slot_id:
			return def
	return null


func ids() -> Array[String]:
	var result: Array[String] = []
	for def in slots:
		result.append(def.id)
	return result


## Vagas que a tela mostra.
func shown_slots() -> Array[EquipmentSlotDef]:
	return slots.filter(func(def: EquipmentSlotDef) -> bool: return def.shown)
