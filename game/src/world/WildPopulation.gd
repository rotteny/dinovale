# SPDX-License-Identifier: MIT
class_name WildPopulation
extends Node2D
## Os dinos selvagens do mapa (além do do tutorial): bandos que nascem das VAGAS do mapa (`IslandMap.spawn_slots`), em posição
## sorteada pela semente do mundo (`WildLayout`, ADR-007 emenda de 07/11), com o nível da faixa do bioma. Cada membro tem o id
## `<vaga>.<geração>.<k>`. Quando o último membro selvagem de um bando morre ou é domado, o bando espera
## `group_respawn_seconds` e renasce inteiro em outro lugar (`tick`, só a autoridade). O save tem três partes:
## - DELTA por id de membro (`world.wild`), só do selvagem SEM dono: `{id, state}` se mudou (torpor, comida, doma em andamento,
##   ferido), `{id, dead: true}` se morreu, `{id, tamed: true}` se virou domado ou ganhou dono (o id fica consumido). Id que o mapa
##   de hoje não gera (outra semente, geração, vaga aposentada) é ignorado, e estado de OUTRA espécie também.
## - GRUPOS (`world.wild_groups`), só das vagas não intactas: `{slot, gen, center, due_at, tries}`; a vaga intacta é recalculada.
## - ENTIDADES (`entities`, tipo `tamed_dino`): domado ou com dono, e o recriado por outra revisão do mapa (doma em andamento com
##   comida). Não dependem de id de vaga: são recriados ao carregar com o estado salvo.
## `restore` é tudo ou nada: dado malformado devolve false e nada fica mudado (o `SaveManager` tenta a cópia
## anterior). Não dispara evento de jogo.

## Um selvagem morreu; `tamed` diz se era domado (gatilho de save `TAMED_DINO_DEATH`).
signal creature_died(creature: Dino, tamed: bool)
## Um bando renasceu (respawn, só na autoridade): o mundo registra os membros e os põe na zona.
signal group_spawned(creatures: Array[Dino])

const DINO_SCENE: PackedScene = preload("res://src/entities/dino/Dino.tscn")
const TYPE_TAMED := "tamed_dino"
## Teto de entradas lidas de um save (dado de fora não é confiável).
const MAX_ENTRIES := 1024
## Espécies que o jogo conhece (a vaga de espécie fora daqui, como o Triceratops hoje, é ignorada sem erro).
const SPECIES: Array[DinoBaseStats] = [
	preload("res://data/dino/placeholder_dino.tres"),
	preload("res://data/dino/utahraptor.tres"),
	preload("res://data/dino/dodo.tres"),
]
const FALLBACK_ID_BASE := 1 << 20
## Tamanho máximo do id de spawn aceito de um save (o do mapa tem poucos caracteres).
const MAX_ID_LENGTH := 32
## Semente de mundo: 52 bits (o JSON guarda número como real de 64 bits, que só é exato até 2^53).
const MAX_SEED := (1 << 52) - 1
const MAX_GENERATION := 1 << 31


## O estado de uma vaga de bando neste mundo.
class Slot extends RefCounted:
	var def: Dictionary = {}
	var kind: DinoBaseStats = null
	var gen: int = 0
	## Centro do bando da geração atual (`WildLayout.NO_CELL` = a vaga não achou lugar neste mundo).
	var center: Vector2i = WildLayout.NO_CELL
	## Ids dos membros da geração atual (os que nasceram; vivos ou não).
	var member_ids: Array[String] = []
	## Esperando renascer: o último membro selvagem saiu. `due_at` é o instante do relógio do mundo; `tries` conta as falhas.
	var waiting: bool = false
	var due_at: float = 0.0
	var tries: int = 0
	## Quando a próxima vaga vazia de um bando com vivos renasce (relógio do mundo); -1 = nada a repor. Vai ao save.
	var regen_due_at: float = -1.0

## Semente do mundo (sorteio de bandos). Fora do save de mundos antigos, vale a semente do mapa.
var world_seed: int = 0
## Centros fixos que contam para a distância dos bandos (o do tutorial): `WildLayout.placed_center`.
var fixed_centers: Array[Dictionary] = []
## Relógio do mundo (`authority.clock.now`); sem ele o respawn não corre sozinho.
var clock: Callable = Callable()
## Os que o último `restore` criou por mudar a vaga (outra semente ou geração): o chamador os registra e põe na zona.
var last_created: Array[Dino] = []

## Para registrar quem é recriado (a criatura registrada acha o dono por aqui).
var authority: WorldAuthority
## Selvagens que o último `restore` trouxe de volta (delta aplicado ou recriado): o chamador acerta o dono.
var last_restored: Array[Dino] = []
## Os que o último `restore` recriou a partir de entidade (o chamador põe na zona).
var last_adopted: Array[Dino] = []

## Quem os agressivos perseguem (devolve `Array` de `Node2D`); o mundo preenche.
var target_locator: Callable = Callable()
## Piso do bando e reposição de membros (`PredationRules`): a caçada nunca esvazia um bando sem volta.
var predation_rules: PredationRules = preload("res://data/balance/predation_rules.tres")
## Regras de doma deste mundo (cópia com as chaves do `ServerRules`); null = as do `preload` de cada dino.
var taming_rules: TamingRules = null
## Regras de nascimento do jogador deste mundo: com a margem da predação formam o núcleo seguro (`SafeCore`) dos caçadores.
var respawn_rules: RespawnRules = preload("res://data/balance/respawn_rules.tres")
## Regras da toca deste mundo (cópia com as chaves do `ServerRules`); null = as do perfil `home` de cada espécie.
var home_rules: HomeRules = null

var _map: IslandMap = null
var _rules: WorldRules = null
var _layout: WildLayout = null
var _safe_core: SafeCore = null
var _layout0: Dictionary = {}  # id da vaga -> centro da geração 0 (com a semente atual)
var _slots: Dictionary = {}  # id da vaga -> Slot
var _order: Array[String] = []  # ids das vagas, em ordem crescente
var _by_id: Dictionary = {}  # id de spawn -> Dino
var _id_of: Dictionary = {}  # Dino -> id de spawn
var _dead: Dictionary = {}  # id de spawn -> true
var _taken: Dictionary = {}  # id de spawn -> true
var _adopted: Array = []  # Dino (pode ter sido liberado: sempre passar por `adopted()`)
var _ids: Dictionary = {}  # Dino -> id gravado na entidade (0 = qualquer livre)


## Cria os bandos da geração 0: o centro de cada vaga sai de `WildLayout` com `seed_value` e os membros dentro do raio de
## coesão. Vaga de espécie desconhecida é ignorada; vaga sem lugar fica vazia (aviso, sem relaxar nada). Nível e sexo saem de
## fluxos próprios semeados pelo id do membro (ADR-007): acrescentar ou tirar uma vaga nunca muda as outras. Devolve a lista.
func populate(map: IslandMap, rules: WorldRules, seed_value: int) -> Array[Dino]:
	_map = map
	_rules = rules
	world_seed = seed_value
	_layout = WildLayout.new(map, rules, seed_value, SPECIES)
	_safe_core = SafeCore.new(respawn_rules, predation_rules.spawn_safe_margin_tiles, float(map.tile))
	var empty: Array[String] = []
	_layout0 = _layout.layout(fixed_centers, empty)
	for id in empty:
		push_warning("WildPopulation: a vaga %s não achou lugar neste mundo." % id)
	var created: Array[Dino] = []
	_slots.clear()
	_order.clear()
	for def in map.spawn_slots:
		var kind := _layout.species_of(def)
		if kind == null:
			continue
		var slot := Slot.new()
		slot.def = def
		slot.kind = kind
		_slots[def["id"]] = slot
		_order.append(def["id"])
		if _layout0.has(def["id"]):
			slot.center = _layout0[def["id"]]
			created.append_array(_spawn_group(slot))
	return created


## Cria e registra os membros da geração atual da vaga (centro já definido).
func _spawn_group(slot: Slot) -> Array[Dino]:
	var created: Array[Dino] = []
	var cells := _layout.members_of(slot.def, slot.gen, slot.center)
	var ks: Array = cells.keys()
	ks.sort()
	for k: int in ks:
		var member_id := member_id_of(slot.def["id"], slot.gen, k)
		var creature := _build_member(slot.kind, _layout, member_id, cells[k], slot.def)
		_register_member(slot, member_id, creature)
		created.append(creature)
	return created


## Faixa de nível do membro: a da toca da vaga (`HomeRules.den_level_bands`) se há; senão a do terreno do tile.
func _band_of(kind: DinoBaseStats, def: Dictionary, cell: Vector2i) -> Vector2i:
	var terrain_band := kind.spawn_level_band(_rules.level_band_of(_map.terrain_at(cell)))
	var den := str(def.get("den", ""))
	if den == "" or kind.home == null or _layout.den_cell_of(def) == WildLayout.NO_CELL:
		return terrain_band
	return _home_rules_of(kind).band_of(den, terrain_band)


func _home_rules_of(kind: DinoBaseStats) -> HomeRules:
	return home_rules if home_rules != null else kind.home.rules


func _build_member(kind: DinoBaseStats, layout: WildLayout, member_id: String, cell: Vector2i, def: Dictionary = {}) -> Dino:
	var band := _band_of(kind, def, cell)
	var creature := _make_creature(kind)
	creature.level = roll_level(band, layout.world_seed, member_id)
	creature.sex = kind.roll_sex(layout.world_seed, member_id)
	creature.position = _map.center_of(cell)
	add_child(creature)
	_apply_rules(creature)
	_bind_den(creature, kind, def)
	return creature


## Liga o membro à toca da vaga e ao núcleo seguro: a ronda, a volta e a âncora saem daí (E3a).
func _bind_den(creature: Dino, kind: DinoBaseStats, def: Dictionary) -> void:
	if kind.predation != null:
		creature.state_machine.safe_core = _safe_core
	var den := _layout.den_cell_of(def)
	if kind.home != null and den != WildLayout.NO_CELL:
		creature.state_machine.bind_home(_map.center_of(den), _home_rules_of(kind))


func _register_member(slot: Slot, member_id: String, creature: Dino) -> void:
	if not slot.member_ids.has(member_id):
		slot.member_ids.append(member_id)
	_by_id[member_id] = creature
	_id_of[creature] = member_id
	creature.herd_id = herd_of(member_id)
	creature.health.died.connect(_on_died.bind(creature))


## Id do membro `k` da geração `gen` da vaga: `g7.0.2`.
static func member_id_of(slot_id: String, gen: int, k: int) -> String:
	return "%s.%d.%d" % [slot_id, gen, k]


## Bando de um id de membro (`g7.0.2` -> `g7.0`): vaga e geração. Gerações diferentes nunca são o mesmo bando.
static func herd_of(member_id: String) -> String:
	var parts := member_id.split(".")
	parts.remove_at(parts.size() - 1)
	return ".".join(parts)


## Nível do selvagem de id `member_id` na faixa `band` (x = mínimo, y = máximo): fluxo `["wild", semente, id, "level"]`.
static func roll_level(band: Vector2i, world_seed_value: int, member_id: String) -> int:
	var rng := SeededRng.new()
	rng.seed_from(["wild", world_seed_value, member_id, "level"])
	return band.x + rng.next_below(band.y - band.x + 1)


## Ids de todos os membros da geração atual, em ordem de vaga e de `k` (testes e relatórios).
func member_ids() -> Array[String]:
	var ids: Array[String] = []
	for id in _order:
		ids.append_array((_slots[id] as Slot).member_ids)
	return ids


## Estado da vaga para teste e relatório: `{gen, center, waiting, due_at, tries, members}`; vazio se a vaga não existe aqui.
func slot_info(slot_id: String) -> Dictionary:
	var slot: Slot = _slots.get(slot_id)
	if slot == null:
		return {}
	return {"gen": slot.gen, "center": slot.center, "waiting": slot.waiting, "due_at": slot.due_at, "tries": slot.tries,
			"members": slot.member_ids.duplicate(), "region": slot.def["region"], "species": slot.def["species"]}


func slot_ids() -> Array[String]:
	return _order.duplicate()


## Centro da vaga na geração 0 com a semente atual (`NO_CELL` se não achou lugar).
func layout_center(slot_id: String) -> Vector2i:
	return _layout0.get(slot_id, WildLayout.NO_CELL)


func _physics_process(_delta: float) -> void:
	if clock.is_valid():
		tick(clock.call())


## Passo da autoridade (público, testável sem quadros): bando sem membro selvagem marca o prazo de renascer
## (`due_at = agora + group_respawn_seconds`, ADR-006); vencido o prazo, tenta o sorteio de um centro novo. Nunca roda no
## `from_dict`/`restore`: o primeiro tick depois da carga resolve o que venceu.
func tick(now: float) -> void:
	if _layout == null:
		return
	for id in _order:
		var slot: Slot = _slots[id]
		if slot.center == WildLayout.NO_CELL:
			continue
		if not slot.waiting:
			if _wild_alive(slot) == 0:
				slot.waiting = true
				slot.due_at = now + slot.kind.group_respawn_seconds
				slot.tries = 0
		elif now >= slot.due_at:
			_try_respawn(slot, now)
		if not slot.waiting:
			_regen(slot, now)


## Reposição de membros (D11): bando com 1 ou mais vivos e vaga vazia (morto, não domado) repõe UM membro a cada
## `member_regen_seconds`, só com nenhum jogador a menos de `group_respawn_player_clearance_tiles` do ponto dele. O membro volta
## com o mesmo id, no mesmo lugar e vida cheia. Domado morto é perda permanente (o id foi consumido).
func _regen(slot: Slot, now: float) -> void:
	var vacant := _vacant_members(slot)
	if vacant.is_empty() or _wild_alive(slot) == 0:
		slot.regen_due_at = -1.0
		return
	if slot.regen_due_at < 0.0:
		slot.regen_due_at = now + predation_rules.member_regen_seconds
		return
	if now < slot.regen_due_at:
		return
	var cells := _layout.members_of(slot.def, slot.gen, slot.center)
	var member_id := vacant[0]
	var k := member_id.get_slice(".", 2).to_int()
	if not cells.has(k):
		_taken[member_id] = true  # o mapa de hoje não tem esta posição: some de vez, sem erro
		return
	var cell: Vector2i = cells[k]
	if _near_player(cell, _rules.group_respawn_player_clearance_tiles):
		return  # espera o jogador sair: a reposição só acontece fora da vista
	_dead.erase(member_id)
	var creature := _build_member(slot.kind, _layout, member_id, cell, slot.def)
	_register_member(slot, member_id, creature)
	slot.regen_due_at = now + predation_rules.member_regen_seconds if vacant.size() > 1 else -1.0
	group_spawned.emit([creature] as Array[Dino])


## Ids da geração atual que estão vazios: mortos selvagens (domado morto e domado não entram).
func _vacant_members(slot: Slot) -> Array[String]:
	var vacant: Array[String] = []
	for member_id in slot.member_ids:
		if _dead.has(member_id) and not _taken.has(member_id):
			vacant.append(member_id)
	return vacant


func _near_player(cell: Vector2i, tiles: float) -> bool:
	for player_cell in _player_cells():
		if Vector2(player_cell - cell).length() < tiles:
			return true
	return false


## Membros da geração atual ainda vivos e selvagens (sem dono).
func _wild_alive(slot: Slot) -> int:
	var count := 0
	for member_id in slot.member_ids:
		var creature := creature_at(member_id)
		if creature != null and not creature.health.is_dead() and not is_owned(creature):
			count += 1
	return count


func _try_respawn(slot: Slot, now: float) -> void:
	var clearance := _rules.group_respawn_player_clearance_tiles
	if slot.tries >= _rules.group_respawn_relax_after_tries:
		clearance = _rules.group_respawn_relaxed_clearance_tiles  # só a distância do jogador relaxa
	var next_gen := slot.gen + 1
	var center := _layout.pick_center(slot.def, next_gen, slot.tries, _live_centers(slot), _player_cells(), clearance)
	if center == WildLayout.NO_CELL:
		slot.tries += 1
		slot.due_at = now + _rules.group_respawn_retry_seconds
		return
	_forget_members(slot)
	slot.gen = next_gen
	slot.center = center
	slot.waiting = false
	slot.tries = 0
	group_spawned.emit(_spawn_group(slot))


## Centros dos bandos vivos (de todas as vagas menos `except`) e os fixos.
func _live_centers(except: Slot) -> Array[Dictionary]:
	var placed: Array[Dictionary] = fixed_centers.duplicate()
	for id in _order:
		var other: Slot = _slots[id]
		if other != except and other.center != WildLayout.NO_CELL and not other.waiting and _wild_alive(other) > 0:
			placed.append(WildLayout.placed_center(other.center, other.kind.spawn_key, other.kind.min_group_spacing_tiles))
	return placed


func _player_cells() -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if target_locator.is_valid():
		for node: Variant in target_locator.call():
			if is_instance_valid(node):
				cells.append(_map.cell_of((node as Node2D).global_position))
	return cells


## Esquece os ids da geração que acabou (os domados dela seguem como entidade).
func _forget_members(slot: Slot) -> void:
	for member_id in slot.member_ids:
		_by_id.erase(member_id)
		_dead.erase(member_id)
		_taken.erase(member_id)
	slot.member_ids.clear()


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
	return creature.feeder_player_id != "" or creature.sated_until > _now() \
			or creature.taming.taming_progress > 0.0 or creature.torpor.current_torpor > 0.0 \
			or creature.torpor.is_unconscious or not creature.inventory.is_empty() \
			or creature.health.current_health < creature.health.max_health


## Delta para o save, em ordem de vaga e de membro (só a geração atual de cada vaga).
func to_list() -> Array:
	var list: Array = []
	for id in _order:
		for member_id in (_slots[id] as Slot).member_ids:
			var entry: Variant = _delta_entry(member_id)
			if entry != null:
				list.append(entry)
	return list


## A entrada do delta do membro, ou null se ele está como nasceu (ou já sumiu sem marca).
func _delta_entry(spawn_id: String) -> Variant:
	if _taken.has(spawn_id):
		return {"id": spawn_id, "tamed": true}  # consumido (domado, vivo ou morto): nunca é reposto
	if _dead.has(spawn_id):
		return {"id": spawn_id, "dead": true}
	var creature := creature_at(spawn_id)
	if creature == null or creature.health.is_dead():
		return null
	if is_owned(creature):
		return {"id": spawn_id, "tamed": true}
	if is_changed(creature):
		return {"id": spawn_id, "state": creature.to_dict()}
	return null


## `world.wild_groups` para o save: só as vagas não intactas (geração acima de 0, esperando renascer, ou com membro no delta).
## `center` vai quando a geração é maior que 0 ou algum membro está no delta (a vaga não pode se mexer depois de tocada);
## `due_at` e `tries` só enquanto espera. A vaga intacta da geração 0 é recalculada pela semente: custo zero no save.
func groups_to_list() -> Array:
	var list: Array = []
	for id in _order:
		var slot: Slot = _slots[id]
		if slot.center == WildLayout.NO_CELL:
			continue
		var touched := slot.regen_due_at >= 0.0
		for member_id in slot.member_ids:
			if touched:
				break
			if _delta_entry(member_id) != null:
				touched = true
		if slot.gen == 0 and not slot.waiting and not touched:
			continue
		var entry := {"slot": id, "gen": slot.gen, "center": [slot.center.x, slot.center.y]}
		if slot.waiting:
			entry["due_at"] = slot.due_at
			entry["tries"] = slot.tries
		if slot.regen_due_at >= 0.0:
			entry["regen_due_at"] = slot.regen_due_at
		list.append(entry)
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
func restore(list: Variant, saved_entities: Array, groups: Variant = [], saved_seed: int = -1, now: float = 0.0) -> bool:
	last_restored = []
	last_adopted = []
	last_created = []
	var entries: Variant = _read_list(list)
	if entries == null:
		return false
	var seed_value := world_seed if saved_seed < 0 or _map == null else saved_seed
	var same_seed := seed_value == world_seed
	var layout := _layout if same_seed else WildLayout.new(_map, _rules, seed_value, SPECIES)
	var centers0 := _layout0 if same_seed else layout.layout(fixed_centers)
	var targets := _plan_slots(groups, layout, centers0, now)
	var changed := {}  # id da vaga -> alvo: a vaga muda de geração, de centro ou de espera, e seus membros são refeitos
	var fresh: Dictionary = {}  # id do membro -> Dino criado agora (só entra no mundo se tudo der certo)
	var made: Array[Dino] = []
	for slot_id: String in targets:
		var slot: Slot = _slots[slot_id]
		var target: Dictionary = targets[slot_id]
		if same_seed and target["gen"] == slot.gen and target["center"] == slot.center and target["waiting"] == slot.waiting:
			continue
		changed[slot_id] = target
		if target["waiting"] or target["center"] == WildLayout.NO_CELL:
			continue
		var cells := layout.members_of(slot.def, target["gen"], target["center"])
		var ks: Array = cells.keys()
		ks.sort()
		for k: int in ks:
			var member_id := member_id_of(slot_id, target["gen"], k)
			var creature := _build_member(slot.kind, layout, member_id, cells[k], slot.def)
			fresh[member_id] = creature
			made.append(creature)
	var applied: Array = []  # [creature, estado antes]
	var created: Array[Dino] = []
	var plan: Array = []  # [entrada, criatura] do que vale (id do mapa e espécie certa)
	var ok := true
	for entry: Dictionary in (entries as Array):
		var spawn_id := str(entry["id"])
		var creature: Dino = fresh.get(spawn_id) if changed.has(_slot_of(spawn_id)) else creature_at(spawn_id)
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
		if not made.has(creature):
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
		for creature in made:
			creature.free()
		return false
	_commit_slots(changed, fresh, layout, centers0, seed_value)
	for slot_id: String in targets:
		(_slots[slot_id] as Slot).regen_due_at = float((targets[slot_id] as Dictionary).get("regen_due_at", -1.0))
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
	for restored in last_restored:  # a saciedade do save nunca passa de agora + o teto da espécie (dado de fora)
		restored.cap_sated(now)
	for creature in made:
		if is_instance_valid(creature) and not creature.is_queued_for_deletion():
			last_created.append(creature)
	return true


func _now() -> float:
	return float(clock.call()) if clock.is_valid() else 0.0


## Id da vaga de um id de membro (`g7.0.2` -> `g7`).
static func _slot_of(member_id: String) -> String:
	return member_id.get_slice(".", 0)


## Ordem dos membros: vaga (na ordem das vagas), geração e `k`, NUMÉRICOS ("g39.0.2" vem antes de "g39.0.10", que o texto trocaria).
func _member_before(a: String, b: String) -> bool:
	var slot_a := _order.find(_slot_of(a))
	var slot_b := _order.find(_slot_of(b))
	if slot_a != slot_b:
		return slot_a < slot_b
	var parts_a := a.split(".")
	var parts_b := b.split(".")
	var gen_a := parts_a[1].to_int() if parts_a.size() > 1 else 0
	var gen_b := parts_b[1].to_int() if parts_b.size() > 1 else 0
	if gen_a != gen_b:
		return gen_a < gen_b
	return parts_a[parts_a.size() - 1].to_int() < parts_b[parts_b.size() - 1].to_int()


## O alvo de cada vaga depois do save: `{id: {gen, center, waiting, due_at, tries}}`. Entrada de `groups` mal formada, de vaga
## desconhecida, de centro fora da região (ou do mapa) ou repetida é descartada, e a vaga volta à disposição da semente. Nada
## aqui muda o mundo.
func _plan_slots(groups: Variant, layout: WildLayout, centers0: Dictionary, now: float) -> Dictionary:
	var read := {}
	for item: Variant in SafeRead.list(groups).slice(0, MAX_ENTRIES):
		var entry := SafeRead.dict(item)
		var slot_id := SafeRead.text(entry.get("slot"), "")
		if not _slots.has(slot_id) or read.has(slot_id):
			continue
		var slot: Slot = _slots[slot_id]
		var gen := SafeRead.integer(entry.get("gen"), -1, 0, MAX_GENERATION)
		var pair := SafeRead.list(entry.get("center"))
		var center := WildLayout.NO_CELL
		if pair.size() == 2:
			center = Vector2i(SafeRead.integer(pair[0], -1, -1, 1 << 20), SafeRead.integer(pair[1], -1, -1, 1 << 20))
		var den_center := layout.den_cell_of(slot.def)
		if den_center != WildLayout.NO_CELL:
			if gen < 0:
				continue
			center = den_center  # bando de toca vive na toca: o centro sorteado de um save de antes das tocas é trocado por ela
		elif pair.is_empty() and gen == 0 and centers0.has(slot_id):
			center = centers0[slot_id]  # sem centro gravado (vaga só com membro no delta): vale o da semente
		elif gen < 0 or not layout.center_is_valid(slot.def, center):
			continue
		var waiting := entry.has("due_at")
		read[slot_id] = {"gen": gen, "center": center, "waiting": waiting,
				"due_at": SafeRead.number(entry.get("due_at"), 0.0, 0.0, now + slot.kind.group_respawn_seconds),
				"tries": SafeRead.integer(entry.get("tries"), 0, 0, 1000),
				"regen_due_at": SafeRead.number(entry.get("regen_due_at"), -1.0, -1.0, now + predation_rules.member_regen_seconds)}
	var targets := {}
	for slot_id in _order:
		targets[slot_id] = read.get(slot_id, {"gen": 0, "center": centers0.get(slot_id, WildLayout.NO_CELL),
				"waiting": false, "due_at": 0.0, "tries": 0, "regen_due_at": -1.0})
	return targets


## Troca o estado das vagas refeitas (depois de tudo conferido): os membros antigos saem, os novos entram, e a semente passa a valer.
func _commit_slots(changed: Dictionary, fresh: Dictionary, layout: WildLayout, centers0: Dictionary, seed_value: int) -> void:
	_layout = layout
	_layout0 = centers0
	world_seed = seed_value
	for slot_id: String in changed:
		var slot: Slot = _slots[slot_id]
		var target: Dictionary = changed[slot_id]
		for member_id in slot.member_ids:
			var old := creature_at(member_id)
			if old != null and not is_owned(old):
				old.queue_free()
		_forget_members(slot)
		slot.gen = target["gen"]
		slot.center = target["center"]
		slot.waiting = target["waiting"]
		slot.due_at = target["due_at"]
		slot.tries = target["tries"]
	var ids: Array = fresh.keys()
	ids.sort_custom(_member_before)
	for member_id: String in ids:
		_register_member(_slots[_slot_of(member_id)], member_id, fresh[member_id])


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
	var slot: Slot = _slots.get(_slot_of(spawn_id))
	if slot != null and slot.member_ids.has(spawn_id):
		_dead[spawn_id] = true  # só a geração atual guarda a marca: a que acabou já foi esquecida
		if creature.state_machine.is_tamed or creature.owner_player_id != "":
			_taken[spawn_id] = true  # domado morto: o id fica consumido, sem reposição
	creature_died.emit(creature, creature.state_machine.is_tamed)
