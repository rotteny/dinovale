# SPDX-License-Identifier: MIT
class_name ItemIcons
extends RefCounted
## Ícone de cada item (pacote Ninja Adventure, placeholder: a semente vermelha faz de
## baga). Só apresentação: `Items`/`ItemDef` em `src/core` não conhecem textura.

const _ICONS: Dictionary[String, Texture2D] = {
	Items.BERRY: preload("res://assets/third_party/ninja-adventure/items/food_seed3.png"),
	Items.MEAT: preload("res://assets/third_party/ninja-adventure/items/food_meat.png"),
	Items.SLEEP_STAFF: preload("res://assets/third_party/ninja-adventure/items/res_branch.png"),
	Items.FERN: preload("res://assets/third_party/ninja-adventure/items/res_grass.png"),
}


## Ícone do item, ou null se não houver.
static func icon_of(item_id: String) -> Texture2D:
	return _ICONS.get(item_id)
