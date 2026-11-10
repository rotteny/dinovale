# SPDX-License-Identifier: MIT
class_name CarcassField
extends Node2D
## Carcaças do mundo (recorte mínimo do SOB-06; GDD 5.6 e 5.9b). Dino morto, selvagem ou domado, deixa uma
## carcaça no lugar: um `ResourceNode` com a carne da espécie, coletável à mão (3 s por carne e 1 de dano ao
## personagem por item). Entra no registro da autoridade (a coleta é um `request_gather` como outro qualquer),
## vai ao save e some quando esvazia ou depois de `rules.fresh_seconds`. O morto não volta: o delta dos selvagens
## já o marca como morto, e a carcaça é só uma entidade nova de mundo.
##
## Esfolar é `request_skin` (`CarcassService`): carne e couro por espécie e nível, o que não cabe no Peso ou nos slots fica na
## carcaça, e a do dino domado é só do dono por `rules.owner_exclusive_seconds`. Fora deste recorte (GDD 5.6): carniça
## (10 a 20 min) e sacolinha com o alforje.

const BASE_DEF: ResourceNodeDef = preload("res://data/resources/carcass_meat.tres")
const SPECIES: Dictionary = {
	"placeholder_dino": preload("res://data/dino/placeholder_dino.tres"),
	"utahraptor": preload("res://data/dino/utahraptor.tres"),
	"dodo": preload("res://data/dino/dodo.tres"),
}
## Versão do formato de cada carcaça no save: 2 = com couro e dono. Sem a chave (save antigo) a carcaça só tinha carne.
const ENTRY_FORMAT := 2
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
## Leitor do relógio do mundo, `() -> float` (ADR-006): a carcaça guarda QUANDO nasceu (`born_at`), nunca a idade.
var clock: Callable = Callable()

## Espécies extras que deixam carcaça (id -> `DinoBaseStats`), além das de `SPECIES`: o mundo e os testes as acrescentam.
var extra_species: Dictionary = {}

var _items: Array[Dictionary] = []  # {node, species, level, born_at, meat}


func _physics_process(_delta: float) -> void:
	tick()


## Some a carcaça cuja idade (`relógio - born_at`) chegou a `rules.fresh_seconds`. Só compara instantes.
func tick() -> void:
	var current := _now()
	for item in _items.duplicate():
		if current - float(item["born_at"]) >= rules.fresh_seconds:
			_remove(item)


func _now() -> float:
	return float(clock.call()) if clock.is_valid() else 0.0


func count() -> int:
	return _items.size()


func nodes() -> Array[ResourceNode]:
	var result: Array[ResourceNode] = []
	for item in _items:
		result.append(item["node"] as ResourceNode)
	return result


## Deixa a carcaça de `creature` (morta agora) onde ela estava. Devolve o nó, ou null se a espécie é desconhecida.
func spawn_from(creature: Dino) -> ResourceNode:
	if not is_instance_valid(creature) or _stats_of(creature.stats.id) == null:
		return null
	var owner_id := creature.owner_player_id if creature.state_machine.is_tamed else ""
	return _spawn(creature.stats.id, creature.level, creature.global_position + FEET_OFFSET, _now(), 0, owner_id)


func _stats_of(species: String) -> DinoBaseStats:
	if extra_species.has(species):
		return extra_species[species] as DinoBaseStats
	return SPECIES.get(species) as DinoBaseStats


## A carcaça que `creature` (morta agora) deixou: a mais recente da espécie no ponto onde ela caiu. Null se não deixou.
func carcass_of(creature: Dino) -> ResourceNode:
	var point := creature.global_position + FEET_OFFSET
	for index in range(_items.size() - 1, -1, -1):
		var item := _items[index]
		if item["species"] == creature.stats.id and (item["node"] as Node2D).position.distance_to(point) < 1.0:
			return item["node"] as ResourceNode
	return null


## Carne que ainda há na carcaça (o que sobrou, ou a inteira).
func meat_of(node: ResourceNode) -> int:
	return int(node.component.pending_yields().get(node.def.item_id, 0))


## A refeição de um carnívoro: deixa `left` de carne na carcaça (0 = a carcaça some). Só a CARNE muda: o couro e o que
## o jogador já esfolou ficam como estavam. Só `meat_of` ou menos.
func set_meat(node: ResourceNode, left: int) -> void:
	for item in _items:
		if item["node"] == node:
			if left <= 0:
				_remove(item)
			elif left < meat_of(node):
				var rest := node.component.pending_yields()
				rest[node.def.item_id] = left
				node.component.leave(rest)
			return


## Nasce uma carcaça inteira (quem restaura aplica o que sobrou depois); `entity_id` > 0 pede esse id (restaura).
func _spawn(species: String, level: int, point: Vector2, born_at: float, entity_id: int, owner_id: String = "") -> ResourceNode:
	var stats := _stats_of(species)
	var meat := LEVEL_RULES.carcass_meat(stats.carcass_meat, level)
	var leather := LEVEL_RULES.carcass_leather(stats.carcass_leather, level)
	var def := BASE_DEF.duplicate() as ResourceNodeDef
	def.id = "carcass_%s" % species
	def.display_name = "Carcaça de %s" % stats.display_name
	def.yield_amount = meat
	if leather > 0:
		def.extra_yields = {Items.LEATHER: leather}
	# O tempo é por unidade (`item_seconds`: 3 s a carne e 6 s o couro à mão); `gather_seconds` fica como o total à mão.
	def.gather_seconds = 0.0
	for item_id: String in def.total_yields():
		def.gather_seconds += float(BASE_DEF.item_seconds.get(item_id, 0.0)) * float(def.total_yields()[item_id])
	def.texture = stats.carcass_texture
	var node: ResourceNode = ResourceField.NodeScene.instantiate()
	node.node_id = ""
	node.def = def
	node.position = point
	node.carcass_owner = owner_id
	node.exclusive_until = born_at + rules.owner_exclusive_seconds if owner_id != "" else 0.0
	node.occupancy = occupancy
	node.clock = clock
	while _items.size() >= rules.max_carcasses:
		_remove(_items[0])  # a mais antiga sai
	add_child(node)
	var item := {"node": node, "species": species, "level": level, "born_at": born_at, "meat": meat}
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


## Para o save: espécie, nível, ponto, quando nasceu e o que ainda resta (o id da entidade acompanha).
func to_list() -> Array:
	var list: Array = []
	for item in _items:
		var node := item["node"] as ResourceNode
		var entry := {
			"id": authority.id_of(node) if authority != null else 0,
			"species": item["species"], "level": item["level"],
			"x": node.position.x, "y": node.position.y, "born_at": item["born_at"], "format": ENTRY_FORMAT,
		}
		if node.carcass_owner != "":
			entry["owner"] = node.carcass_owner
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
		if _stats_of(species) == null or (data.has("format") and not _valid_format(data["format"])):
			continue  # espécie desconhecida ou `format` de lixo (não é 1 nem 2): descarta a carcaça
		var level := LEVEL_RULES.clamp_level(SafeRead.integer(data.get("level"), 10, 1, 1000))
		var point := Vector2(SafeRead.number(data.get("x"), 0.0, -MAX_COORD, MAX_COORD),
				SafeRead.number(data.get("y"), 0.0, -MAX_COORD, MAX_COORD))
		# `born_at` não passa do relógio (já reposto) e não é mais velho que o prazo: o vencido some no 1º tick.
		var current := _now()
		var born_at := SafeRead.number(data.get("born_at"), current, -MAX_COORD * 1000.0, current)
		if current - born_at >= rules.fresh_seconds:
			continue  # já venceu: não nasce (some na carga, sem esperar o primeiro tick)
		var owner_id := SafeRead.text(data.get("owner"), "")
		if owner_id.length() > WorldAuthority.MAX_ID_LENGTH:
			owner_id = ""
		var node := _spawn(species, level, point, born_at, SafeRead.integer(data.get("id"), 0, 0, 1 << 30), owner_id)
		var left := _clean_left(data.get("left"), node.def)
		if data.has("left") and left.is_empty():
			_remove(_items.back())  # `left` só de lixo, negativo ou zero: não vira uma carcaça inteira por engano
			continue
		# Save antigo (sem `format`): só havia carne. Uma carcaça pela metade não perde o couro que ainda não existia.
		if not left.is_empty() and SafeRead.integer(data.get("format"), 1, 0, 1000) < ENTRY_FORMAT and node.def.extra_yields.has(Items.LEATHER):
			left[Items.LEATHER] = int(node.def.extra_yields[Items.LEATHER])
		if not left.is_empty():
			node.component.leave(left)


## `format` válido: inteiro (o JSON devolve 2.0) entre 1 e `ENTRY_FORMAT`.
func _valid_format(raw: Variant) -> bool:
	if not (raw is int or raw is float):
		return false
	var number := float(raw)
	return number == floorf(number) and number >= 1.0 and number <= float(ENTRY_FORMAT)


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
