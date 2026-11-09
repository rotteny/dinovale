# SPDX-License-Identifier: MIT
class_name GroundItemField
extends Node2D
## Itens soltos no chão: onde cai o que a colheita por golpes derruba e o que o jogador larga. Cada pilha é um `GroundItem`
## registrado na autoridade (recolher é `request_pickup`). Vai ao save, some em `due_at` (relógio do mundo, ADR-006) e tem
## teto por área. A posição de cada pilha vem da semente do mundo (determinística, sem `randf`).
##
## Visual: o `GroundItemView` de cada pilha. Sacolinha do domado morto (GDD 5.6) não existe ainda; quando existir, pode
## usar esta mesma entidade (um item de chão por entrada do alforje), sem mudar o save.

const MAX_COORD := 1.0e6
const MAX_AMOUNT := 9999

@export var rules: GroundItemRules = preload("res://data/balance/ground_item_rules.tres")
## Autoridade do mundo: cada pilha entra no registro dela e o recolher passa por ela.
var authority: WorldAuthority = null
## Leitor do relógio do mundo, `() -> float`: o item guarda QUANDO some (`due_at`), nunca a idade.
var clock: Callable = Callable()
## Semente do mundo: a disposição das pilhas deriva dela.
var world_seed: int = 0
## Jogador local: andar por cima do item o recolhe (pedido à autoridade). Opcional (servidor sem jogador local).
var player: Player = null

var _items: Array[GroundItem] = []


func _physics_process(_delta: float) -> void:
	tick()


## Some o que venceu e recolhe, pelo pedido à autoridade, o que está sob os pés do jogador. Só compara instantes.
func tick() -> void:
	var current := _now()
	for item in _items.duplicate():
		if current >= item.due_at:
			_remove(item)
	if player == null or authority == null or player.health.is_dead():
		return
	var actor_id := authority.id_of(player)
	for item in _items.duplicate():
		# Só tenta quando cabe: recolher sozinho com a mochila cheia ficaria negado a cada quadro.
		if item.global_position.distance_to(player.global_position) <= rules.auto_pickup_px \
				and player.inventory.room_for(item.item_id) > 0:
			authority.request_pickup(actor_id, authority.id_of(item))


func count() -> int:
	return _items.size()


func items() -> Array[GroundItem]:
	return _items.duplicate()


## Total de `item_id` no chão (teste e diagnóstico).
func total_of(item_id: String) -> int:
	var total := 0
	for item in _items:
		if item.item_id == item_id:
			total += item.amount
	return total


## Espalha `amount` de `item_id` em pilhas de até `rules.pile_max`, a 4 a 12 px de `origin`. `dropper_id` é quem largou
## (gancho do co-op). Devolve as pilhas criadas.
## `ignore_area_cap` (alforje do domado morto) deixa o drop passar do teto por área: nada se perde por causa dele.
func spawn_scatter(item_id: String, amount: int, origin: Vector2, dropper_id: String = "",
		ignore_area_cap: bool = false) -> Array[GroundItem]:
	var created: Array[GroundItem] = []
	if not Items.has(item_id) or Items.is_individual(item_id) or amount <= 0:
		return created
	var left := mini(amount, MAX_AMOUNT)
	var index := 0
	while left > 0:
		var pile := mini(left, rules.pile_max)
		left -= pile
		var item := _spawn(item_id, pile, origin + _offset(origin, item_id, index), _now() + rules.despawn_seconds, 0, ignore_area_cap)
		item.owner_player_id = dropper_id
		item.owner_until = _now() + rules.owner_seconds
		created.append(item)
		index += 1
	return created


## Solta um item individual (com `iid` e durabilidade) a 4 a 12 px de `origin`; recolher o devolve com a mesma durabilidade.
## Devolve o item de chão, ou null se a entrada não é de um individual conhecido.
func spawn_entry(entry: Dictionary, origin: Vector2, ignore_area_cap: bool = false) -> GroundItem:
	var clean := _clean_entry(entry)
	if clean.is_empty():
		return null
	var item := _spawn(str(clean["id"]), 1, origin + _offset(origin, str(clean["id"]), 0),
			_now() + rules.despawn_seconds, 0, ignore_area_cap)
	item.entry = clean
	return item


## Entrada de individual válida (id conhecido e individual, `iid` de texto, `durab` inteiro limitado) ou `{}`.
func _clean_entry(raw: Variant) -> Dictionary:
	var data := SafeRead.dict(raw)
	var item_id := SafeRead.text(data.get("id"), "")
	var iid := SafeRead.text(data.get("iid"), "")
	if not Items.has(item_id) or not Items.is_individual(item_id) or iid == "" or iid.length() > InventoryComponent.MAX_IID_LENGTH:
		return {}
	var clean := {"id": item_id, "iid": iid}
	if data.has("durab"):
		clean["durab"] = SafeRead.integer(data.get("durab"), 0, 0, 1 << 20)
	return clean


## Deslocamento da pilha `index` em volta de `origin`: ângulo e distância saem da semente do mundo, do ponto e do item.
func _offset(origin: Vector2, item_id: String, index: int) -> Vector2:
	var rng := SeededRng.new()
	rng.seed_from([world_seed, "ground", roundi(origin.x), roundi(origin.y), item_id, index])
	var angle := float(rng.next_below(3600)) / 3600.0 * TAU
	var distance := lerpf(rules.scatter_min_px, rules.scatter_max_px, float(rng.next_below(1001)) / 1000.0)
	return Vector2.from_angle(angle) * distance


func _spawn(item_id: String, amount: int, point: Vector2, due_at: float, entity_id: int, ignore_area_cap: bool = false) -> GroundItem:
	var item := GroundItem.new()
	item.setup(item_id, amount)
	item.position = point
	item.due_at = due_at
	if not ignore_area_cap:
		_enforce_area_cap(point)
	add_child(item)
	_items.append(item)
	item.depleted.connect(_remove)
	if authority != null:
		if authority.register(item, maxi(entity_id, 0)) == 0:
			authority.register(item)
	var view := GroundItemView.new()
	view.item = item
	item.add_child(view)
	return item


## Teto por área: se a célula do ponto já está cheia, o mais antigo dela some.
func _enforce_area_cap(point: Vector2) -> void:
	var cell := _cell(point)
	var same: Array[GroundItem] = []
	for item in _items:
		if _cell(item.position) == cell:
			same.append(item)
	while same.size() >= rules.max_per_area:
		var oldest := same[0]
		for item in same:
			if item.due_at < oldest.due_at:
				oldest = item
		same.erase(oldest)
		_remove(oldest)


func _cell(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / rules.area_px), floori(point.y / rules.area_px))


func _remove(item: GroundItem) -> void:
	if not _items.has(item):
		return
	_items.erase(item)
	if is_instance_valid(item):
		if authority != null:
			authority.unregister(authority.id_of(item))
		item.queue_free()


func _now() -> float:
	return float(clock.call()) if clock.is_valid() else 0.0


## Para o save: item, quantidade, ponto, prazo e dono; o id da entidade acompanha.
func to_list() -> Array:
	var list: Array = []
	for item in _items:
		var entry := {
			"id": authority.id_of(item) if authority != null else 0, "item": item.item_id, "amount": item.amount,
			"x": item.position.x, "y": item.position.y, "due_at": item.due_at,
		}
		if not item.entry.is_empty():
			entry["entry"] = item.entry.duplicate()
		if item.owner_player_id != "":
			entry["owner"] = item.owner_player_id
			entry["owner_until"] = item.owner_until
		list.append(entry)
	return list


## Restaura a lista salva no lugar dos itens de agora. Dado de fora: item desconhecido, quantidade e número fora da faixa e
## excesso são descartados; nunca emite evento de jogo. O mesmo id não vira dois itens.
func restore_list(list: Array) -> void:
	for item in _items.duplicate():
		_remove(item)
	var current := _now()
	for entry: Variant in list:
		var data := SafeRead.dict(entry)
		var item_id := SafeRead.text(data.get("item"), "")
		var amount := SafeRead.integer(data.get("amount"), 0, 0, MAX_AMOUNT)
		var individual := _clean_entry(data.get("entry")) if data.has("entry") else {}
		if not Items.has(item_id) or amount <= 0 or (Items.is_individual(item_id) and individual.is_empty()) \
				or (not Items.is_individual(item_id) and data.has("entry")):
			continue
		var point := Vector2(SafeRead.number(data.get("x"), 0.0, -MAX_COORD, MAX_COORD),
				SafeRead.number(data.get("y"), 0.0, -MAX_COORD, MAX_COORD))
		# O prazo não passa do que um item novo teria (relógio já reposto); vencido some no 1º tick.
		var due_at := SafeRead.number(data.get("due_at"), current, 0.0, current + rules.despawn_seconds)
		# Id fora da faixa vira 0 (o próximo livre): um id no teto empurraria o contador e o próximo load seria recusado.
		var saved_id := SafeRead.integer(data.get("id"), 0, 0, SaveMigrations.MAX_ENTITY_ID - 1)
		var item := _spawn(item_id, 1 if not individual.is_empty() else amount, point, due_at, saved_id)
		item.entry = individual
		item.owner_player_id = SafeRead.text(data.get("owner"), "")
		item.owner_until = SafeRead.number(data.get("owner_until"), 0.0, 0.0, current + rules.owner_seconds)
