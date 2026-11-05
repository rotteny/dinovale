# SPDX-License-Identifier: MIT
class_name Items
extends RefCounted
## Catálogo de itens. Ids são strings estáveis (é o que vai para o save).
## `berry` é a comida ideal do dino atual; `meat` e `fern` são comidas não ideais.

const BERRY := "berry"
const MEAT := "meat"
const FERN := "fern"

static var _defs: Dictionary = {}


static func has(item_id: String) -> bool:
	return _catalog().has(item_id)


## Retorna null para id desconhecido.
static func get_def(item_id: String) -> ItemDef:
	return _catalog().get(item_id) as ItemDef


static func max_stack(item_id: String) -> int:
	var def := get_def(item_id)
	return def.max_stack if def != null else 0


static func display_name(item_id: String) -> String:
	var def := get_def(item_id)
	return def.display_name if def != null else item_id


static func color_of(item_id: String) -> Color:
	var def := get_def(item_id)
	return def.color if def != null else Color.MAGENTA


static func all_ids() -> Array:
	return _catalog().keys()


static func _catalog() -> Dictionary:
	if _defs.is_empty():
		for def: ItemDef in [
			ItemDef.new(BERRY, "Baga", 20, Color(0.85, 0.2, 0.35)),
			ItemDef.new(MEAT, "Carne", 10, Color(0.75, 0.35, 0.25)),
			ItemDef.new(FERN, "Samambaia", 30, Color(0.3, 0.7, 0.3)),
		]:
			_defs[def.id] = def
	return _defs
