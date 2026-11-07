# SPDX-License-Identifier: MIT
class_name WildPopulation
extends Node2D
## Os dinos selvagens do mapa (além do do tutorial): nascem dos pontos de `spawns` do mapa, com o nível da
## faixa do bioma. O save tem duas partes:
## - DELTA por id de spawn (`world.wild`, ids do mapa, ADR-007), só do selvagem SEM dono: `{id, state}` se mudou (torpor,
##   comida, doma em andamento, ferido), `{id, dead: true}` se morreu, `{id, tamed: true}` se virou domado ou ganhou
##   dono (o id fica consumido: não nasce de novo). Vale por id de qualquer revisão do mapa; id que o mapa não tem é
##   ignorado, e estado de OUTRA espécie também (o selvagem nasce novo).
## - ENTIDADES (`entities`, tipo `tamed_dino`): domado ou com dono, e o recriado por outra revisão do mapa
##   (doma em andamento com comida). Não dependem de índice: são recriados ao carregar com o estado salvo.
## `restore` é tudo ou nada: dado malformado devolve false e nada fica mudado (o `SaveManager` tenta a cópia
## anterior). Não dispara evento de jogo.

## Um selvagem morreu; `tamed` diz se era domado (gatilho de save `TAMED_DINO_DEATH`).
signal creature_died(creature: Dino, tamed: bool)

const DINO_SCENE: PackedScene = preload("res://src/entities/dino/Dino.tscn")
const TYPE_TAMED := "tamed_dino"
## Teto de entradas lidas de um save (dado de fora não é confiável).
const MAX_ENTRIES := 1024
## Espécies do mapa, na ordem em que nascem (a ordem não importa mais para o save: o id vem do mapa).
const SPECIES: Array[DinoBaseStats] = [
	preload("res://data/dino/placeholder_dino.tres"),
	preload("res://data/dino/utahraptor.tres"),
]
const FALLBACK_ID_BASE := 1 << 20
## Tamanho máximo do id de spawn aceito de um save (o do mapa tem poucos caracteres).
const MAX_ID_LENGTH := 32

## Para registrar quem é recriado (a criatura registrada acha o dono por aqui).
var authority: WorldAuthority
## Selvagens que o último `restore` trouxe de volta (delta aplicado ou recriado): o chamador acerta o dono.
var last_restored: Array[Dino] = []
## Os que o último `restore` recriou a partir de entidade (o chamador põe na zona).
var last_adopted: Array[Dino] = []

## Quem os agressivos perseguem (devolve `Array` de `Node2D`); o mundo preenche.
var target_locator: Callable = Callable()
## Regras de doma deste mundo (cópia com as chaves do `ServerRules`); null = as do `preload` de cada dino.
var taming_rules: TamingRules = null

var _by_id: Dictionary = {}  # id de spawn -> Dino
var _id_of: Dictionary = {}  # Dino -> id de spawn
var _dead: Dictionary = {}  # id de spawn -> true
var _taken: Dictionary = {}  # id de spawn -> true
var _adopted: Array = []  # Dino (pode ter sido liberado: sempre passar por `adopted()`)
var _ids: Dictionary = {}  # Dino -> id gravado na entidade (0 = qualquer livre)


## Cria os selvagens de cada espécie (no máximo `limit` por espécie), pulando a célula do tutorial e as repetidas.
## Cada um leva o id do ponto no mapa (`map.spawn_ids`); nível e sexo saem de fluxos próprios semeados por esse id
## (ADR-007): acrescentar ou tirar um ponto nunca muda os outros. Devolve a lista.
func populate(map: IslandMap, rules: WorldRules, skip_cell: Vector2i, limit: int) -> Array[Dino]:
	var created: Array[Dino] = []
	for kind in SPECIES:
		var cells: Array = map.spawns.get(kind.spawn_key, [])
		var ids: Array = map.spawn_ids.get(kind.spawn_key, [])
		var seen := {}
		var count := 0
		for i in cells.size():
			var cell: Vector2i = cells[i]
			if count >= limit:
				break
			if cell == skip_cell or seen.has(cell):
				continue
			seen[cell] = true
			var spawn_id: String = ids[i]
			var band := rules.level_band_of(map.terrain_at(cell))
			var creature := _make_creature(kind)
			creature.level = roll_level(band, map.seed_value, spawn_id)
			creature.sex = kind.roll_sex(map.seed_value, spawn_id)
			creature.position = map.center_of(cell)
			add_child(creature)
			_apply_rules(creature)
			_by_id[spawn_id] = creature
			_id_of[creature] = spawn_id
			creature.health.died.connect(_on_died.bind(creature))
			created.append(creature)
			count += 1
	return created


## Nível do selvagem do ponto `spawn_id` na faixa `band` (x = mínimo, y = máximo): fluxo `["wild", semente, id, "level"]`.
static func roll_level(band: Vector2i, map_seed: int, spawn_id: String) -> int:
	var rng := SeededRng.new()
	rng.seed_from(["wild", map_seed, spawn_id, "level"])
	return band.x + rng.next_below(band.y - band.x + 1)


## Espécie pelo id salvo; desconhecido (ou ausente, save antigo) cai na primeira.
static func species_by_id(species_id: String) -> DinoBaseStats:
	for kind in SPECIES:
		if kind.id == species_id:
			return kind
	return SPECIES[0]


func _make_creature(kind: DinoBaseStats) -> Dino:
	var creature: Dino = DINO_SCENE.instantiate()
	creature.stats = kind
	creature.target_locator = target_locator
	return creature


## As regras de doma do mundo (só depois de entrar na árvore: o componente é filho).
func _apply_rules(creature: Dino) -> void:
	if taming_rules != null:
		creature.taming.rules = taming_rules


## Id do ponto do mapa de onde `creature` nasceu ("" para o recriado de entidade).
func spawn_id_of(creature: Dino) -> String:
	return _id_of.get(creature, "")


func creature_at(spawn_id: String) -> Dino:
	var creature: Variant = _by_id.get(spawn_id)
	if not is_instance_valid(creature) or (creature as Dino).is_queued_for_deletion():
		return null
	return creature as Dino


## Morto ou consumido (virou domado): o id não nasce de novo.
func is_dead(spawn_id: String) -> bool:
	return _dead.has(spawn_id)


func is_taken(spawn_id: String) -> bool:
	return _taken.has(spawn_id)


## Os recriados de entidade (sem índice no mapa), vivos.
func adopted() -> Array[Dino]:
	_adopted = _adopted.filter(func(creature: Variant) -> bool: return _alive(creature))
	var alive: Array[Dino] = []
	for creature: Variant in _adopted:
		alive.append(creature as Dino)
	return alive


## Domado ou com dono: vive como entidade no save, não pelo índice.
func is_owned(creature: Dino) -> bool:
	return creature.state_machine.is_tamed or creature.owner_player_id != ""


## Selvagem sem dono que saiu do estado de nascimento.
func is_changed(creature: Dino) -> bool:
	return creature.feeder_player_id != "" \
			or creature.taming.taming_progress > 0.0 or creature.torpor.current_torpor > 0.0 \
			or creature.torpor.is_unconscious or not creature.inventory.is_empty() \
			or creature.health.current_health < creature.health.max_health


## Delta para o save, em ordem de id.
func to_list() -> Array:
	var list: Array = []
	var ids: Array = _by_id.keys()
	ids.sort()
	for spawn_id: String in ids:
		if _dead.has(spawn_id):
			list.append({"id": spawn_id, "dead": true})
			continue
		if _taken.has(spawn_id):
			list.append({"id": spawn_id, "tamed": true})
			continue
		var creature := creature_at(spawn_id)
		if creature == null or creature.health.is_dead():
			continue
		if is_owned(creature):
			list.append({"id": spawn_id, "tamed": true})
		elif is_changed(creature):
			list.append({"id": spawn_id, "state": creature.to_dict()})
	return list


## Entidades para o save: todo domado ou com dono (do mapa ou recriado) e todo recriado, vivos.
func entities() -> Array:
	var list: Array = []
	var next_fallback := FALLBACK_ID_BASE
	var members: Array[Dino] = []
	for child in get_children():
		var creature := child as Dino
		if creature != null and _alive(creature) and not creature.health.is_dead() \
				and (is_owned(creature) or _adopted.has(creature)):
			members.append(creature)
	for creature in members:
		var id := authority.id_of(creature) if authority != null else 0
		if id <= 0:
			id = next_fallback
			next_fallback += 1
		list.append({"id": id, "type": TYPE_TAMED, "state": creature.to_dict()})
	return list


## Aplica o save, tudo ou nada. `list` é `world.wild` como veio (qualquer coisa), `saved_entities` é `entities`.
## O delta vale por id de spawn, de qualquer revisão do mapa; id que o mapa não tem é ignorado (exceto estado com
## doma em andamento ou comida: vira entidade, para nenhum item se perder), e estado de outra espécie também (o
## selvagem nasce novo). As entidades valem sempre.
func restore(list: Variant, saved_entities: Array) -> bool:
	last_restored = []
	last_adopted = []
	var entries: Variant = _read_list(list)
	if entries == null:
		return false
	var applied: Array = []  # [creature, estado antes]
	var created: Array[Dino] = []
	var plan: Array = []  # [entrada, criatura] do que vale (id do mapa e espécie certa)
	var ok := true
	for entry: Dictionary in (entries as Array):
		var creature := creature_at(str(entry["id"]))
		if creature == null:
			if entry.has("state") and _holds_items(entry["state"]):
				ok = _adopt(entry["state"], created)
				if not ok:
					break
			continue
		if entry.has("state") and _other_species(creature, entry["state"]):
			continue  # outra espécie no mesmo id: ignora a entrada, o selvagem nasce novo
		plan.append([entry, creature])
		if entry.has("dead") or entry.has("tamed") or _state_is_dead(entry["state"]):
			continue  # morto não passa por `from_dict` (a morte não se desfaz): só é marcado depois de tudo conferido
		applied.append([creature, creature.to_dict()])
		if not creature.from_dict(entry["state"]):
			ok = false
			break
	if ok:
		var count := 0
		for saved: Variant in saved_entities:
			if typeof(saved) != TYPE_DICTIONARY or str((saved as Dictionary).get("type", "")) != TYPE_TAMED:
				continue
			count += 1
			var state := SafeRead.dict((saved as Dictionary).get("state"))
			ok = count <= MAX_ENTRIES and not state.is_empty() \
					and _adopt(state, created, SafeRead.integer((saved as Dictionary).get("id"), 0, 0, 1 << 52))
			if not ok:
				break
	if not ok:
		for pair: Array in applied:
			(pair[0] as Dino).from_dict(pair[1])
		for creature in created:
			creature.free()
		return false
	for pair: Array in plan:
		var entry: Dictionary = pair[0]
		var spawn_id := str(entry["id"])
		if entry.has("dead") or _state_is_dead(entry.get("state")):
			_dead[spawn_id] = true
		elif entry.has("tamed"):
			_taken[spawn_id] = true
		else:
			var back := creature_at(spawn_id)
			if back != null:
				last_restored.append(back)
			continue
		var gone := creature_at(spawn_id)
		if gone != null:
			gone.queue_free()
	_register(created)
	last_restored.append_array(created)
	last_adopted = created
	return true


## O estado diz uma espécie que não é a de `creature`? (sem `species` não diz nada: save antigo)
func _other_species(creature: Dino, state: Variant) -> bool:
	var saved := SafeRead.text(SafeRead.dict(state).get("species"), "")
	return saved != "" and saved != creature.stats.id


## Entradas já conferidas, ou null se o dado é malformado (forma, tipo e id texto de tamanho razoável). Id sem criatura
## no mapa de hoje (o ponto foi aposentado, ou o limite da população baixou) é só ignorado: não é defeito do save.
func _read_list(list: Variant) -> Variant:
	if list == null:
		return []
	if typeof(list) != TYPE_ARRAY or (list as Array).size() > MAX_ENTRIES:
		return null
	var seen := {}
	var entries: Array = []
	for entry: Variant in list:
		var clean: Variant = _clean_entry(entry)
		if clean == null or seen.has((clean as Dictionary)["id"]):
			return null
		seen[(clean as Dictionary)["id"]] = true
		entries.append(clean)
	return entries


## Uma entrada do delta com o id texto, ou null se malformada: exatamente um de `dead`, `tamed` (true) ou `state`.
func _clean_entry(entry: Variant) -> Variant:
	if typeof(entry) != TYPE_DICTIONARY:
		return null
	var raw: Variant = (entry as Dictionary).get("id")
	var kinds := 0
	for key: String in ["dead", "tamed"]:
		if (entry as Dictionary).has(key):
			kinds += 1 if (entry as Dictionary)[key] == true else 99
	if (entry as Dictionary).has("state"):
		kinds += 1 if typeof((entry as Dictionary)["state"]) == TYPE_DICTIONARY else 99
	var valid_id := typeof(raw) == TYPE_STRING and not (raw as String).is_empty() and (raw as String).length() <= MAX_ID_LENGTH
	if kinds != 1 or not valid_id:
		return null
	return (entry as Dictionary).duplicate()


func _holds_items(state: Dictionary) -> bool:
	if _state_is_dead(state):
		return false
	return SafeRead.number(SafeRead.dict(state.get("taming")).get("taming_progress"), 0.0, 0.0, 100.0) > 0.0 \
			or not SafeRead.dict(state.get("inventory")).is_empty() and _inventory_has_items(state.get("inventory"))


func _inventory_has_items(inventory: Variant) -> bool:
	for slot: Variant in SafeRead.list(SafeRead.dict(inventory).get("slots")):
		if typeof(slot) == TYPE_DICTIONARY and not (slot as Dictionary).is_empty():
			return true
	return false


## Vida 0 (ou menos) no estado salvo: é uma criatura morta, mesmo sem a marca de morte.
func _state_is_dead(state: Variant) -> bool:
	if typeof(state) != TYPE_DICTIONARY:
		return false
	var health := SafeRead.dict((state as Dictionary).get("health"))
	return health.has("current") and SafeRead.number(health.get("current"), 1.0, -1.0, SafeRead.MAX_SAVED) <= 0.0


## Cria o `Dino` do estado salvo. Estado morto é ignorado (true); estado recusado devolve false.
func _adopt(state: Dictionary, created: Array[Dino], saved_id: int = 0) -> bool:
	if _state_is_dead(state):
		return true
	var creature := _make_creature(species_by_id(SafeRead.text(state.get("species"), "")))
	add_child(creature)
	_apply_rules(creature)
	var usable := state
	if SafeRead.text(state.get("species"), "") != creature.stats.id:  # espécie desconhecida: cai na primeira, como sempre
		usable = state.duplicate()
		usable.erase("species")
	if not creature.from_dict(usable):
		creature.free()
		return false
	created.append(creature)
	_ids[creature] = saved_id
	return true



func _register(created: Array[Dino]) -> void:
	for creature in created:
		_adopted.append(creature)
		creature.health.died.connect(_on_died.bind(creature))
		if authority != null:
			var wanted: int = _ids.get(creature, 0)
			if wanted <= 0 or authority.register(creature, wanted) == 0:
				authority.register(creature)
	_ids.clear()


func _alive(creature: Variant) -> bool:
	return is_instance_valid(creature) and not (creature as Dino).is_queued_for_deletion()


func _on_died(creature: Dino) -> void:
	var spawn_id: String = _id_of.get(creature, "")
	if spawn_id != "":
		_dead[spawn_id] = true
	creature_died.emit(creature, creature.state_machine.is_tamed)
