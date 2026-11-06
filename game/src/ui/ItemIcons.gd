# SPDX-License-Identifier: MIT
class_name ItemIcons
extends RefCounted
## Ícone de cada item (pacote Ninja Adventure, placeholder: a semente vermelha faz de
## baga). Só apresentação: `Items`/`ItemDef` em `src/core` não conhecem textura.

const _BRANCH: Texture2D = preload("res://assets/third_party/ninja-adventure/items/res_branch.png")
const _GRASS: Texture2D = preload("res://assets/third_party/ninja-adventure/items/res_grass.png")
const _ICONS: Dictionary[String, Texture2D] = {
	Items.BERRY: preload("res://assets/third_party/ninja-adventure/items/food_seed3.png"),
	Items.MEAT: preload("res://assets/third_party/ninja-adventure/items/food_meat.png"),
	Items.SLEEP_STAFF: _BRANCH,
	Items.FERN: _GRASS,
	# Materiais dos nós de recurso: ícones repetidos do pacote até haver arte própria.
	Items.WOOD: _BRANCH,
	Items.STONE: preload("res://assets/third_party/ninja-adventure/items/res_rock.png"),
	Items.FIBER: _GRASS,
}


## Ícone do item, ou null se não houver.
static func icon_of(item_id: String) -> Texture2D:
	return _ICONS.get(item_id)
