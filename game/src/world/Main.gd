# SPDX-License-Identifier: MIT
class_name Main
extends Node2D
## Cena principal: liga o mundo à UI. Quando o jogador interage com uma criatura,
## abre o inventário compartilhado; enquanto a tela está aberta o jogador não anda.
## Também liga o save: "Continuar" (pedido em `GameSession`) restaura o último jogo; o `SaveScheduler`
## salva no intervalo, na morte do jogador e na de um dino domado e ao escolher o respawn; voltar ao menu e
## fechar a janela salvam direto. A pausa não oferece Salvar: o jogador não escolhe quando salvar. O jogo nunca pergunta antes de salvar.

@export var player: Player
@export var screen: InventoryScreen
@export var dino: Dino
## Autoridade do mundo (ADR-001): toda ação do jogador passa por ela, também no single-player.
@export var authority: WorldAuthority
## Pausa (Esc quando nenhuma tela está aberta). Opcional: um servidor ou teste pode não ter UI.
@export var pause: PauseMenu
## Cena da apresentação, para "Voltar ao menu"; vazio = a pausa só tem Continuar.
@export_file("*.tscn") var menu_scene: String = ""
## HUD, só para os avisos do save (opcional).
@export var hud: PlayerHud
## Mundo do save: pasta `<raiz>/<world_id>/` (ver `GameSession.save_root`).
@export var world_id: String = GameSession.DEFAULT_WORLD
## Nível fixo da criatura da cena (sem biomas nem sorteio por enquanto).
@export var dino_level: int = 20
## Tela de morte (opcional: um servidor ou teste pode não ter UI).
@export var death_screen: DeathScreen
## Nós de recurso do mundo (opcional); o estado deles vai no save.
@export var resources: ResourceField
@export var respawn_rules: RespawnRules = preload("res://data/balance/respawn_rules.tres")

## O jogador morreu e ainda não escolheu onde renascer (GDD 12.4). Vale para a morte em jogo e para o
## save carregado de um jogador morto: nos dois a tela de morte está aberta e só a escolha tira daqui.
var pending_death_choice: bool = false
var save_manager: SaveManager
var scheduler: SaveScheduler

## `entity_id` da criatura cuja tela compartilhada está aberta (0 = nenhuma).
var _screen_target_id: int = 0
var _quit_failed_once: bool = false
var _last_failure_notice: String = ""
## O Continuar falhou: esta partida não existe de verdade (a cena volta ao título) e não grava nada.
var _load_failed: bool = false
## Quantos respawns o mundo já fez: semente do sorteio de ponto (vai no save).
var _respawn_count: int = 0


func _ready() -> void:
	dino.level = dino_level
	get_tree().auto_accept_quit = false  # o fechar da janela passa pelo save (_notification)
	screen.player_inventory = player.inventory
	screen.hotbar = player.hotbar
	screen.equipment = player.equipment
	screen.equip_requested.connect(func(iid: String) -> void: player.request_equip(iid))
	screen.unequip_requested.connect(func(slot_id: String) -> void: player.request_unequip(slot_id))
	player.equip_refused.connect(screen.show_refusal)
	screen.hotbar_assign_requested.connect(_on_hotbar_assign_requested)
	screen.opened.connect(func() -> void: player.input_locked = true)
	screen.closed.connect(func() -> void: player.input_locked = false)
	_register_entities()
	screen.transfer_requested.connect(_on_transfer_requested)
	authority.interaction_granted.connect(_on_interaction_granted)
	authority.action_denied.connect(_on_action_denied)
	save_manager = SaveManager.new(GameSession.save_root, world_id)
	scheduler = SaveScheduler.new()
	scheduler.player = player
	scheduler.dino = dino
	scheduler.manager = save_manager
	scheduler.field = resources
	scheduler.authority = authority
	scheduler.saved.connect(_on_saved)
	add_child(scheduler)
	player.health.died.connect(_on_player_died)
	player.gathered.connect(_on_player_gathered)
	player.gather_refused.connect(_on_gather_refused)
	if death_screen != null:
		death_screen.rules = respawn_rules
		death_screen.region_chosen.connect(request_respawn)
	dino.health.died.connect(_on_dino_died)
	if pause != null:
		pause.set_menu_available(menu_scene != "")
		pause.menu_requested.connect(_on_menu_requested)
	if GameSession.take_continue():
		_continue_saved_game()


## O jogador e a criatura da cena entram no registro com os ids do save; os nós de recurso, com o próximo livre.
func _register_entities() -> void:
	player.authority = authority
	# Registro que falha (id em uso) deixa o jogo sem aquela entidade para a autoridade: erro alto, não calado.
	if authority.register(player, WorldSnapshot.PLAYER_ENTITY_ID) != WorldSnapshot.PLAYER_ENTITY_ID:
		push_error("Main: o id do jogador já está em uso no registro.")
	if authority.register(dino, WorldSnapshot.DINO_ENTITY_ID) != WorldSnapshot.DINO_ENTITY_ID:
		push_error("Main: o id da criatura já está em uso no registro.")
	if resources != null:
		for node in resources.nodes():
			if authority.register(node) == 0:
				push_error("Main: nó de recurso sem id no registro.")


## Gravar agora (menu, sair e testes; a Cama usa `SaveManager.Reason.BED`). Falhou: o motivo fica em
## `scheduler.last_message` e o save anterior continua.
func save_game(reason: SaveManager.Reason) -> bool:
	return scheduler.save_now(reason)


func _continue_saved_game() -> void:
	var outcome := save_manager.load_first(
			func(data: Dictionary) -> bool: return WorldSnapshot.restore(data, player, dino, resources))
	if outcome.status == SaveManager.Status.OK:
		_respawn_count = WorldSnapshot.respawn_count_of(outcome.data)
		scheduler.respawn_count = _respawn_count
		authority.ensure_next_id(WorldSnapshot.next_entity_id_of(outcome.data))
		if WorldSnapshot.was_dead_pending_choice(outcome.data):
			_enter_death()  # carregar um morto reabre a escolha; não desfaz a morte
		_notify(outcome.message)
		return
	# Continuar que falha não abre jogo novo nem grava nada: volta ao título com o motivo, e o arquivo
	# que o jogo recusou fica exatamente como estava.
	_load_failed = true
	scheduler.frozen = true
	GameSession.notice = outcome.message if outcome.message != "" else "Nenhum jogo salvo."
	if menu_scene != "":
		get_tree().change_scene_to_file.call_deferred(menu_scene)


func _on_player_died() -> void:
	_enter_death()
	scheduler.request(SaveManager.Reason.PLAYER_DEATH)


## Estado de morto: a escolha de respawn fica pendente e a tela abre. Não emite nada nem salva.
func _enter_death() -> void:
	pending_death_choice = true
	screen.close()
	screen.locked = true  # morto não abre inventário (nem pelo atalho nem por uma criatura)
	if death_screen != null:
		death_screen.open(player.global_position)


## Intenção "renascer na região `region_id`": o servidor (aqui, o host local) valida e executa. Devolve ""
## se renasceu ou o motivo da recusa. Sorteia o ponto (GDD 12.2), restaura vida, fome e proteção
## (12.4) e salva. O inventário não é tocado: o corpo com os itens é do M2 (SOB-02).
func request_respawn(region_id: String) -> String:
	if not pending_death_choice or not player.health.is_dead():
		return "not_dead"
	var region := respawn_rules.region_by_id(region_id)
	if region == null:
		return "unknown_region"
	var rng := SeededRng.new()
	rng.seed_from([world_id, _respawn_count])
	var picked := RespawnPicker.pick(region, respawn_rules, rng, _is_free_point, _wild_positions())
	if not player.respawn_at(picked["position"], respawn_rules):
		return "failed"
	_respawn_count += 1
	scheduler.respawn_count = _respawn_count
	pending_death_choice = false
	screen.locked = false
	screen.close()
	if death_screen != null:
		death_screen.close()
	scheduler.request(SaveManager.Reason.RESPAWN)
	return ""


## Ponto livre de colisão e longe de nós de recurso.
func _is_free_point(point: Vector2) -> bool:
	var shape := CircleShape2D.new()
	shape.radius = respawn_rules.clearance_radius
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = shape
	query.transform = Transform2D(0.0, point)
	query.collision_mask = 1
	if not get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
		return false
	if resources != null:
		for node in resources.nodes():
			if node.global_position.distance_to(point) < respawn_rules.min_distance_from_resource:
				return false
	return true


func _wild_positions() -> Array[Vector2]:
	var positions: Array[Vector2] = []
	if is_instance_valid(dino) and not dino.is_queued_for_deletion() and not dino.state_machine.is_tamed:
		positions.append(dino.global_position)
	return positions


func _on_player_gathered(item_id: String, amount: int) -> void:
	_notify("+%d %s" % [amount, Items.display_name(item_id)], 1.5)


func _on_gather_refused(reason: String) -> void:
	var texts := {Player.GATHER_DEPLETED: "Já foi colhido.", Player.GATHER_FULL: "Inventário cheio.",
			Player.GATHER_TOO_FAR: "Longe demais."}
	_notify(str(texts.get(reason, "")), 1.5)


func _notify(text: String, seconds: float = PlayerHud.NOTICE_SECONDS) -> void:
	if hud != null and text != "":
		hud.show_notice(text, seconds)


## Só domado: um selvagem que morre não é salvo. A criatura já saiu do mundo (`queue_free` do próprio
## dino roda antes, pela ordem das conexões), então o save a deixa de fora e ela não volta ao carregar.
func _on_dino_died() -> void:
	if dino.state_machine.is_tamed:
		scheduler.request(SaveManager.Reason.TAMED_DINO_DEATH)


## Falha de escrita avisa na HUD e o jogo segue; sucesso é silencioso (a pausa mostra o dela).
func _on_saved(reason: SaveManager.Reason, ok: bool, message: String) -> void:
	if not ok:
		if message != _last_failure_notice:  # só na primeira falha da sequência, ou se a mensagem mudar
			_last_failure_notice = message
			_notify(message, 6.0)
		return
	_last_failure_notice = ""
	_quit_failed_once = false
	if hud != null and reason != SaveManager.Reason.EXIT_MENU and reason != SaveManager.Reason.QUIT:
		hud.show_saving()


## Voltar ao menu salva e volta direto. Se a escrita falhar, a partida não fecha: o aviso aparece
## na pausa e o save anterior continua.
func _on_menu_requested() -> void:
	if not _load_failed and not save_game(SaveManager.Reason.EXIT_MENU):
		pause.show_status(scheduler.last_message)
		return
	get_tree().paused = false
	get_tree().change_scene_to_file(menu_scene)


## Fechar a janela salva antes de sair. Se a escrita falhar, a janela fica aberta com o aviso na HUD;
## um segundo pedido de fechar sai mesmo assim (decisão explícita do jogador).
func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_CLOSE_REQUEST or save_manager == null:
		return
	if _load_failed or save_game(SaveManager.Reason.QUIT) or _quit_failed_once:
		get_tree().quit()
	else:
		_quit_failed_once = true
		_notify(scheduler.last_message + " Feche de novo para sair mesmo assim.", 8.0)


func _exit_tree() -> void:
	get_tree().auto_accept_quit = true


## A tela pede, o mundo muda a barra do jogador ("" limpa a posição).
func _on_hotbar_assign_requested(slot: int, item_id: String, iid: String) -> void:
	if item_id == "":
		player.hotbar.clear(slot)
	elif iid != "":
		player.hotbar.assign_iid(slot, iid, item_id)
	else:
		player.hotbar.assign(slot, item_id)


func _on_interaction_granted(actor_id: int, target_id: int) -> void:
	var target := authority.entity(target_id)
	if target is ResourceNode:
		authority.request_gather(actor_id, target_id)  # o alvo é o que a interação concedeu, não a mira local
		return
	var target_dino := target as Dino
	if target_dino != null:
		_screen_target_id = target_id
		screen.open_with(player.inventory, target_dino.inventory, target_dino.interactable, "Criatura")


## A tela pede mover o slot; a autoridade valida e executa (alcance, estado da criatura, espaço).
func _on_transfer_requested(from_player: bool, index: int) -> void:
	var player_id := authority.id_of(player)
	var from_id := player_id if from_player else _screen_target_id
	var to_id := _screen_target_id if from_player else player_id
	authority.request_transfer_slot(player_id, from_id, index, to_id)


func _on_action_denied(_actor_id: int, action: String, result: Enums.ActionResult) -> void:
	if action == WorldAuthority.ACTION_TRANSFER:
		screen.show_transfer_refusal(result)
	elif action == WorldAuthority.ACTION_GATHER and result == Enums.ActionResult.OUT_OF_RANGE:
		_on_gather_refused(Player.GATHER_TOO_FAR)
	elif action == WorldAuthority.ACTION_COMMAND and result == Enums.ActionResult.NOT_OWNER:
		_notify("Esse dino não é seu.", 1.5)
