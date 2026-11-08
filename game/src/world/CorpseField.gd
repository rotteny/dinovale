# SPDX-License-Identifier: MIT
class_name CorpseField
extends Node2D
## Corpos dos jogadores mortos (M1, etapa 6; `m1-ameaca-e-corpo.md` seção 5). Quando a autoridade decide a morte
## (`WorldAuthority.player_died`), o corpo cai aqui com todos os itens do jogador e fica `DownedRules.body_minutes` de
## mundo rodando; passado o prazo, o corpo e os itens somem (`corpse_expired`). Recuperar é `request_recover_corpse` na
## autoridade. Entra no save (`world.corpses`) com o prazo como INSTANTE do relógio do mundo: com o jogo fechado o
## relógio não corre, então o corpo não vence (decisão D4).
##
## O alforje do domado morto NÃO passa por aqui: segue como item de chão de 300 s (decisão D17).

const MAX_COORD := 1.0e6
## Corpos por jogador e no mundo: dado de fora não é confiável. A morte seguinte substitui o corpo anterior do mesmo dono
## (o jogador só tem um corpo; o anterior só existe se ele morreu sem recuperá-lo).
const MAX_CORPSES := 16
const MAX_ENTRIES := 512

@export var rules: DownedRules = preload("res://data/balance/downed_rules.tres")
var authority: WorldAuthority = null
## Leitor do relógio do mundo, `() -> float` (ADR-006): o corpo guarda ATÉ QUANDO fica (`due_at`), nunca a idade.
var clock: Callable = Callable()

var _corpses: Array[PlayerCorpse] = []


func _physics_process(_delta: float) -> void:
	tick()


## Liga o campo à autoridade: a morte do jogador deixa o corpo. Chame uma vez, depois de definir `authority`.
func attach(world_authority: WorldAuthority) -> void:
	authority = world_authority
	authority.player_died.connect(deposit)


## Some o corpo cujo prazo chegou (só compara instantes) e avisa ao dono.
func tick() -> void:
	var current := _now()
	for corpse: PlayerCorpse in _corpses.duplicate():
		if current >= corpse.due_at:
			var lost := corpse.item_count()
			_remove(corpse)
			if authority != null:
				authority.announce("corpse_expired", {"amount": lost})


func count() -> int:
	return _corpses.size()


func corpses() -> Array[PlayerCorpse]:
	return _corpses.duplicate()


## O corpo de `player_id` (o mais recente), ou null.
func corpse_of(player_id: String) -> PlayerCorpse:
	for index in range(_corpses.size() - 1, -1, -1):
		if _corpses[index].owner_player_id == player_id:
			return _corpses[index]
	return null


## O jogador `player` morreu: o corpo guarda tudo o que ele levava e fica onde ele estava. Sem itens, não há corpo.
## Devolve o corpo ou null.
func deposit(player: Player) -> PlayerCorpse:
	var marks := _hotbar_marks(player.hotbar)
	var entries := _take_all(player)
	if entries.is_empty():
		return null
	# Decisão do dono: uma segunda morte NÃO apaga o corpo anterior. Cada corpo guarda os seus itens e expira no seu prazo;
	# o teto de `MAX_CORPSES` (o mais antigo sai) só protege o save.
	var corpse := _spawn(player.player_id, player.global_position, _now() + rules.body_seconds(), entries, 0)
	corpse.hotbar_slots = marks
	return corpse


## Onde estão os atalhos agora (`{slot, id, iid}`), para devolvê-los ao recuperar o corpo.
func _hotbar_marks(hotbar: HotbarComponent) -> Array[Dictionary]:
	var marks: Array[Dictionary] = []
	for index in HotbarComponent.SLOT_COUNT:
		var entry := hotbar.entry_at(index)
		if not entry.is_empty():
			marks.append({"slot": index, "id": str(entry.get("id", "")), "iid": str(entry.get("iid", ""))})
	return marks


## Tira TUDO que o jogador leva (grade, vestido; os atalhos só apontam) e devolve como entradas de `add_entry`.
func _take_all(player: Player) -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for index in player.inventory.slot_count():
		var slot := player.inventory.get_slot(index)
		if not slot.is_empty():
			entries.append(slot.duplicate(true))
	var worn := SafeRead.dict(player.equipment.to_dict().get("slots"))
	for slot_id: Variant in worn:
		entries.append(SafeRead.dict(worn[slot_id]).duplicate(true))
	player.equipment.from_dict({"slots": {}})
	player.inventory.from_dict({"version": InventoryComponent.FORMAT_VERSION, "next_iid": player.inventory.to_dict()["next_iid"], "slots": []})
	player.hotbar.from_dict({"slots": []})
	return entries


func _now() -> float:
	return float(clock.call()) if clock.is_valid() else 0.0


func _spawn(owner_id: String, point: Vector2, due_at: float, entries: Array[Dictionary], entity_id: int) -> PlayerCorpse:
	var corpse := PlayerCorpse.new()
	corpse.owner_player_id = owner_id
	corpse.position = point
	corpse.due_at = due_at
	corpse.entries = entries
	while _corpses.size() >= MAX_CORPSES:
		_remove(_corpses[0])
	add_child(corpse)
	_corpses.append(corpse)
	corpse.depleted.connect(_remove)
	if authority != null:
		if entity_id <= 0 or authority.register(corpse, entity_id) == 0:
			authority.register(corpse)
	var view := CorpseView.new()
	view.corpse = corpse
	corpse.add_child(view)
	return corpse


func _remove(corpse: PlayerCorpse) -> void:
	if not _corpses.has(corpse):
		return
	_corpses.erase(corpse)
	if authority != null:
		authority.unregister(authority.id_of(corpse))
	corpse.queue_free()


## Para o save: dono, ponto, prazo (instante do relógio do mundo) e o que guarda; o id da entidade acompanha.
func to_list() -> Array:
	var list: Array = []
	for corpse in _corpses:
		var items: Array = []
		for entry in corpse.entries:
			items.append(entry.duplicate(true))
		list.append({
			"id": authority.id_of(corpse) if authority != null else 0,
			"player_id": corpse.owner_player_id,
			"x": corpse.position.x, "y": corpse.position.y,
			"due_at": corpse.due_at,
			"items": items,
			"hotbar": corpse.hotbar_slots.duplicate(true),
		})
	return list


## Restaura a lista salva no lugar dos corpos de agora. Dado de fora: entrada malformada, item desconhecido e excesso são
## descartados; o prazo não passa de `agora + body_minutes` (o relógio já foi reposto). Nunca emite evento de jogo: quem
## venceu some no primeiro `tick`.
func restore_list(list: Array) -> void:
	for corpse: PlayerCorpse in _corpses.duplicate():
		_remove(corpse)
	var current := _now()
	for raw: Variant in list:
		if _corpses.size() >= MAX_CORPSES:
			break
		var data := SafeRead.dict(raw)
		var owner_id := SafeRead.text(data.get("player_id"), "")
		var entries := _clean_entries(SafeRead.list(data.get("items")))
		if owner_id == "" or entries.is_empty():
			continue
		var point := Vector2(SafeRead.number(data.get("x"), 0.0, -MAX_COORD, MAX_COORD),
				SafeRead.number(data.get("y"), 0.0, -MAX_COORD, MAX_COORD))
		var due_at := SafeRead.number(data.get("due_at"), current + rules.body_seconds(), 0.0, current + rules.body_seconds())
		var revived := _spawn(owner_id, point, due_at, entries, SafeRead.integer(data.get("id"), 0, 0, 1 << 30))
		revived.hotbar_slots = _clean_marks(SafeRead.list(data.get("hotbar")))


## Atalhos salvos válidos: posição da barra, tipo conhecido, `iid` de texto curto; sem repetir posição.
func _clean_marks(raw: Array) -> Array[Dictionary]:
	var clean: Array[Dictionary] = []
	var used: Dictionary = {}
	for item: Variant in raw:
		var data := SafeRead.dict(item)
		var slot := SafeRead.integer(data.get("slot"), -1, -1, HotbarComponent.SLOT_COUNT - 1)
		var item_id := SafeRead.text(data.get("id"), "")
		var iid := SafeRead.text(data.get("iid"), "")
		if slot < 0 or used.has(slot) or iid.length() > HotbarComponent.MAX_IID_LENGTH or (iid == "" and not Items.has(item_id)):
			continue
		used[slot] = true
		clean.append({"slot": slot, "id": item_id, "iid": iid})
	return clean


## Entradas válidas: item conhecido, contagem entre 1 e o teto da pilha, individual com `iid` de texto.
func _clean_entries(raw: Array) -> Array[Dictionary]:
	var clean: Array[Dictionary] = []
	for item: Variant in raw:
		if clean.size() >= MAX_ENTRIES:
			break
		var entry := SafeRead.dict(item).duplicate(true)
		var item_id := SafeRead.text(entry.get("id"), "")
		if not Items.has(item_id):
			continue
		if Items.is_individual(item_id):
			if SafeRead.text(entry.get("iid"), "") == "":
				continue
		else:
			entry.erase("iid")
			entry["count"] = SafeRead.integer(entry.get("count"), 0, 0, InventoryComponent.MAX_STACK)
			if entry["count"] <= 0:
				continue
		clean.append(entry)
	return clean
