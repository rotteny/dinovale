# SPDX-License-Identifier: MIT
class_name CarcassField
extends Node2D
## Carcaças do mundo (recorte mínimo do SOB-06; GDD 5.6 e 5.9b). Dino morto, selvagem ou domado, deixa uma
## carcaça no lugar: um `ResourceNode` com a carne da espécie, coletável à mão (3 s por carne e 1 de dano ao
## personagem por item). Entra no registro da autoridade (a coleta é um `request_gather` como outro qualquer),
## vai ao save e some quando esvazia ou depois de `rules.fresh_seconds`. O morto não volta: o delta dos selvagens
## já o marca como morto, e a carcaça é só uma entidade nova de mundo.
##
## Fora deste recorte (GDD 5.6): couro, carniça (10 a 20 min), sacolinha com o alforje e dono exclusivo por 120 s.

const BASE_DEF: ResourceNodeDef = preload("res://data/resources/carcass_meat.tres")
const SPECIES: Dictionary = {"placeholder_dino": preload("res://data/dino/placeholder_dino.tres")}
const LEVEL_RULES: DinoLevelRules = preload("res://data/balance/dino_level_rules.tres")
## Os pés do dino ficam abaixo do centro do corpo (corpo de 16 px de altura).
const FEET_OFFSET := Vector2(0.0, 8.0)
const MAX_COORD := 1.0e6

## GDD 5.6: quanto a carcaça fica fresca e quantas cabem no mundo.
@export var rules: CarcassRules = preload("res://data/balance/carcass_rules.tres")
## Autoridade do mundo: a carcaça entra no registro e a coleta passa por ela.
var authority: WorldAuthority = null
## Consulta de ocupação do chão (a carcaça nunca esgota e volta: some).
var occupancy: TileOccupancy = null

var _items: Array[Dictionary] = []  # {node, species, level, age, meat}


func _physics_process(delta: float) -> void:
	tick(delta)


## O tempo passa: a carcaça mais velha que `rules.fresh_seconds` some.
func tick(delta: float) -> void:
	for item in _items.duplicate():
		item["age"] = float(item["age"]) + delta
		if float(item["age"]) >= rules.fresh_seconds:
			_remove(item)


func count() -> int:
	return _items.size()


func nodes() -> Array[ResourceNode]:
	var result: Array[ResourceNode] = []
	for item in _items:
		result.append(item["node"] as ResourceNode)
	return result


## Deixa a carcaça de `creature` (morta agora) onde ela estava. Devolve o nó, ou null se a espécie é desconhecida.
func spawn_from(creature: Dino) -> ResourceNode:
	if not is_instance_valid(creature) or not SPECIES.has(creature.stats.id):
		return null
	return _spawn(creature.stats.id, creature.level, creature.global_position + FEET_OFFSET, 0.0, 0)


## Nasce uma carcaça inteira (quem restaura aplica o que sobrou depois); `entity_id` > 0 pede esse id (restaura).
func _spawn(species: String, level: int, point: Vector2, age: float, entity_id: int) -> ResourceNode:
	var stats := SPECIES[species] as DinoBaseStats
	var meat := LEVEL_RULES.carcass_meat(stats.carcass_meat, level)
	var def := BASE_DEF.duplicate() as ResourceNodeDef
	def.id = "carcass_%s" % species
	def.yield_amount = meat
	def.gather_seconds = BASE_DEF.gather_seconds * float(meat)  # 3 s por carne à mão (GDD 5.9b)
	def.texture = stats.carcass_texture
	var node: ResourceNode = ResourceField.NodeScene.instantiate()
	node.node_id = ""
	node.def = def
	node.position = point
	node.occupancy = occupancy
	while _items.size() >= rules.max_carcasses:
		_remove(_items[0])  # a mais antiga sai
	add_child(node)
	var item := {"node": node, "species": species, "level": level, "age": age, "meat": meat}
	_items.append(item)
	node.component.changed.connect(func() -> void: _on_changed(item))
	if authority != null:
		if entity_id <= 0 or authority.register(node, entity_id) == 0:
			authority.register(node)
	var view := ResourceNodeView.new()
	view.node = node
	node.add_child(view)
	return node


func _on_changed(item: Dictionary) -> void:
	var node := item["node"] as ResourceNode
	if is_instance_valid(node) and node.component.depleted:
		_remove.call_deferred(item)  # esvaziada: o corpo some (não volta)


func _remove(item: Dictionary) -> void:
	if not _items.has(item):
		return
	_items.erase(item)
	var node := item["node"] as ResourceNode
	if is_instance_valid(node):
		if authority != null:
			authority.unregister(authority.id_of(node))
		node.queue_free()


## Para o save: espécie, nível, ponto, idade e o que ainda resta (o id da entidade acompanha).
func to_list() -> Array:
	var list: Array = []
	for item in _items:
		var node := item["node"] as ResourceNode
		var entry := {
			"id": authority.id_of(node) if authority != null else 0,
			"species": item["species"], "level": item["level"],
			"x": node.position.x, "y": node.position.y, "age": item["age"],
		}
		if node.component.is_partial():
			entry["left"] = node.component.leftover.duplicate()
		list.append(entry)
	return list


## Restaura a lista salva no lugar das carcaças de agora. Dado de fora: espécie desconhecida, número fora da faixa e
## excesso são descartados; nunca emite evento de jogo.
func restore_list(list: Array) -> void:
	for item in _items.duplicate():
		_remove(item)
	for entry: Variant in list:
		if _items.size() >= rules.max_carcasses:
			break
		var data := SafeRead.dict(entry)
		var species := SafeRead.text(data.get("species"), "")
		if not SPECIES.has(species):
			continue
		var level := LEVEL_RULES.clamp_level(SafeRead.integer(data.get("level"), 10, 1, 1000))
		var point := Vector2(SafeRead.number(data.get("x"), 0.0, -MAX_COORD, MAX_COORD),
				SafeRead.number(data.get("y"), 0.0, -MAX_COORD, MAX_COORD))
		var age := SafeRead.number(data.get("age"), 0.0, 0.0, rules.fresh_seconds - 1.0)
		var node := _spawn(species, level, point, age, SafeRead.integer(data.get("id"), 0, 0, 1 << 30))
		var left := _clean_left(data.get("left"), node.def)
		if not left.is_empty():
			node.component.leave(left)


func _clean_left(raw: Variant, def: ResourceNodeDef) -> Dictionary:
	var kept: Dictionary = {}
	var all := def.total_yields()
	var source := SafeRead.dict(raw)
	for item_id: Variant in source:
		var key := str(item_id)
		if all.has(key):
			var amount := clampi(SafeRead.integer(source[item_id], 0, 0, 1 << 20), 0, all[key])
			if amount > 0:
				kept[key] = amount
	return kept
