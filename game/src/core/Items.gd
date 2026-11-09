# SPDX-License-Identifier: MIT
class_name Items
extends RefCounted
## Catálogo de itens. Ids são strings estáveis (é o que vai para o save).
## `berry` é a comida ideal do dino atual; `meat` e `fern` são comidas não ideais.

const BERRY := "berry"
const MEAT := "meat"
const FERN := "fern"
const SLEEP_STAFF := "sleep_staff"
const WOODEN_SPEAR := "wooden_spear"
## Materiais dos nós de recurso (MUN-02). No M1 ainda não há receita que os consuma.
const WOOD := "wood"
const STONE := "stone"
const FIBER := "fiber"
## Fruta do arbusto-do-sono (Cochilo): item de 0,1 kg que nunca vale como refeição (GDD 5.5). Sem consumidor ainda.
const SLEEP_FRUIT := "sleep_fruit"
## Graveto: material da Lança e das flechas (GDD 5.9). Ainda sem nó que o dê (a fonte entra com o resto do conteúdo).
const STICK := "stick"
## Ferramentas de pedra (ids que a tabela de dano de coleta e os nós de recurso já usam).
const AXE_STONE := "axe_stone"
const PICKAXE_STONE := "pickaxe_stone"
## Peça que se coloca no mundo (E7a): vira a entidade `Workbench` por `WorldAuthority.request_place`.
const WORKBENCH := "workbench"
## Itens das receitas da E7b que AINDA NÃO TÊM USO (entram como item, sem efeito; cada um ganha o efeito na etapa dele).
const CAMPFIRE := "campfire"
const FIBER_BASKET := "fiber_basket"
const CHEST := "chest"
const LEATHER_BACKPACK := "leather_backpack"
const SLEEPING_BAG := "sleeping_bag"
const BED := "bed"
const FOUNDATION := "foundation"
const WALL := "wall"
const DOOR := "door"
const RATION_C := "ration_c"
const RATION_B := "ration_b"
const RATION_A := "ration_a"
## Materiais só de receita (sem fonte no mundo ainda): couro (carcaça), tubérculo e sal-de-veio (Ração B e A).
const LEATHER := "leather"
const TUBER := "tuber"
const VEIN_SALT := "vein_salt"
## Itens que `request_place` sabe colocar.
const PLACEABLE: Array[String] = [WORKBENCH]

## Arma de cada item de arma (o id da arma é o id do item).
const WEAPONS: Dictionary[String, WeaponDef] = {
	SLEEP_STAFF: preload("res://data/weapons/sleep_staff.tres"),
	WOODEN_SPEAR: preload("res://data/weapons/wooden_spear.tres"),
}

## Peso de cada item e capacidade de carga (dados).
const CARRY: CarryRules = preload("res://data/balance/carry_rules.tres")

## Vagas de equipamento (dados).
const EQUIPMENT: EquipmentLayout = preload("res://data/equipment/layout.tres")

static var _defs: Dictionary = {}


static func has(item_id: String) -> bool:
	return _catalog().has(item_id)


## Retorna null para id desconhecido.
static func get_def(item_id: String) -> ItemDef:
	return _catalog().get(item_id) as ItemDef


static func max_stack(item_id: String) -> int:
	var def := get_def(item_id)
	return def.max_stack if def != null else 0


## Item individual (equipamento): não empilha, tem `iid` e durabilidade.
static func is_individual(item_id: String) -> bool:
	var def := get_def(item_id)
	return def != null and def.durability_max > 0


## Vaga do item ("" se não é equipável).
static func slot_of(item_id: String) -> String:
	var def := get_def(item_id)
	return def.slot if def != null else ""


## Pode ir à barra de atalhos: o que não é equipável, ou o equipável cuja vaga permite (roupa não).
static func hotbar_allowed(item_id: String) -> bool:
	var slot := slot_of(item_id)
	if slot == "":
		return true
	var def := EQUIPMENT.slot_def(slot)
	return def != null and def.hotbar


## Peso de uma unidade em gramas (0 para id desconhecido).
static func weight_grams(item_id: String) -> int:
	var def := get_def(item_id)
	return def.weight_grams() if def != null else 0


static func durability_max(item_id: String) -> int:
	var def := get_def(item_id)
	return def.durability_max if def != null else 0


## Arma que o item dá quando equipado, ou null se não é arma.
static func weapon_of(item_id: String) -> WeaponDef:
	return WEAPONS.get(item_id)


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
			ItemDef.new(SLEEP_STAFF, "Bastão-de-sono", 1, Color(0.55, 0.4, 0.8)),
			ItemDef.new(WOODEN_SPEAR, "Lança de madeira", 1, Color(0.6, 0.45, 0.25)),
			ItemDef.new(WOOD, "Madeira", 20, Color(0.55, 0.38, 0.2)),
			ItemDef.new(STONE, "Pedra", 20, Color(0.6, 0.6, 0.65)),
			ItemDef.new(FIBER, "Fibra", 40, Color(0.75, 0.7, 0.4)),
			ItemDef.new(SLEEP_FRUIT, "Cochilo", 20, Color(0.75, 0.8, 0.95)),
			ItemDef.new(STICK, "Graveto", 40, Color(0.5, 0.36, 0.2)),
			ItemDef.new(AXE_STONE, "Machado de pedra", 1, Color(0.55, 0.55, 0.6)),
			ItemDef.new(PICKAXE_STONE, "Picareta de pedra", 1, Color(0.5, 0.5, 0.58)),
			ItemDef.new(WORKBENCH, "Bancada comum", 1, Color(0.6, 0.42, 0.22)),
			# E7b [premissa de pilha, `catalogo.md`: peça de mobília 1, material 20, Ração 20].
			ItemDef.new(CAMPFIRE, "Fogueira", 1, Color(0.85, 0.45, 0.15)),
			ItemDef.new(FIBER_BASKET, "Cesto de fibra", 1, Color(0.7, 0.65, 0.35)),
			ItemDef.new(CHEST, "Baú", 1, Color(0.5, 0.35, 0.18)),
			ItemDef.new(LEATHER_BACKPACK, "Mochila de couro", 1, Color(0.55, 0.32, 0.2)),
			ItemDef.new(SLEEPING_BAG, "Saco de dormir", 1, Color(0.45, 0.5, 0.7)),
			ItemDef.new(BED, "Cama", 1, Color(0.7, 0.5, 0.5)),
			ItemDef.new(FOUNDATION, "Fundação de madeira", 20, Color(0.6, 0.45, 0.28)),
			ItemDef.new(WALL, "Parede de madeira", 20, Color(0.58, 0.4, 0.24)),
			ItemDef.new(DOOR, "Porta de madeira", 5, Color(0.52, 0.36, 0.2)),
			ItemDef.new(RATION_C, "Ração C", 20, Color(0.65, 0.7, 0.4)),
			ItemDef.new(RATION_B, "Ração B", 20, Color(0.6, 0.72, 0.35)),
			ItemDef.new(RATION_A, "Ração A", 20, Color(0.55, 0.75, 0.3)),
			ItemDef.new(LEATHER, "Couro", 20, Color(0.6, 0.4, 0.3)),
			ItemDef.new(TUBER, "Tubérculo", 20, Color(0.7, 0.55, 0.4)),
			ItemDef.new(VEIN_SALT, "Sal-de-veio", 20, Color(0.85, 0.85, 0.9)),
		]:
			def.weight = CARRY.weight_of(def.id)
			_defs[def.id] = def
		# Durabilidade do Bastão: 120 (GDD 5.9). Só o campo; nada gasta ainda.
		_defs[SLEEP_STAFF].durability_max = 120
		_defs[SLEEP_STAFF].slot = EquipmentLayout.WEAPON
		_defs[WOODEN_SPEAR].durability_max = 80  # GDD 5.4; como o Bastão, só o campo (nada gasta ainda)
		_defs[WOODEN_SPEAR].slot = EquipmentLayout.WEAPON
		# Machado e Picareta (GDD 5.9: 150 e 120): empunhados na vaga da arma, como a coleta já espera; só o campo.
		_defs[AXE_STONE].durability_max = 150
		_defs[AXE_STONE].slot = EquipmentLayout.WEAPON
		_defs[PICKAXE_STONE].durability_max = 120
		_defs[PICKAXE_STONE].slot = EquipmentLayout.WEAPON
	return _defs
