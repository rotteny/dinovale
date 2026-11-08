# SPDX-License-Identifier: MIT
class_name Main
extends Node2D
## Cena principal: liga o mundo à UI. Quando o jogador interage com uma criatura,
## abre o inventário compartilhado; enquanto a tela está aberta o jogador não anda.
## Também liga o save: "Continuar" (pedido em `GameSession`) restaura o último jogo; o `SaveScheduler`
## salva no intervalo, na morte do jogador e na de um dino domado e ao escolher o respawn; voltar ao menu e
## fechar a janela salvam direto. A pausa não oferece Salvar: o jogador não escolhe quando salvar. O jogo nunca pergunta antes de salvar.

## Aviso ao carregar um save de outra revisão do mapa (recursos e selvagens do mapa nascem de novo).
const MAP_CHANGED_NOTICE := "O mapa mudou desde este save: recursos e selvagens voltaram ao início. " \
		+ "Domados e a doma em andamento foram mantidos."

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
## Controlador do jogador local (opcional): recebe o menu de opções do clique direito.
@export var controller: PlayerController
@export var respawn_rules: RespawnRules = preload("res://data/balance/respawn_rules.tres")
## Quais nós, cenário e níveis a ilha usa (dado). O mapa em si é `IslandMap` (estático, fora do save).
@export var world_rules: WorldRules = preload("res://data/world/world_rules.tres")
## Navegação dos dinos (grade, folgas, "ficou preso"). Dado em `data/balance/navigation_rules.tres`.
@export var navigation_rules: NavigationRules = preload("res://data/balance/navigation_rules.tres")

## Semente deste mundo (sorteio dos bandos, ADR-007). 0 = sorteia ao criar o mundo novo (ou usa `GameSession.world_seed_override`);
## o Continuar a troca pela salva. Quem quiser um mundo reproduzível (teste, servidor) a fixa antes de entrar na árvore.
@export var world_seed: int = 0

## A ilha Lunata: onde está cada coisa. Só leitura; o jogo não a gera nem a salva.
var map: IslandMap

## O jogador morreu e ainda não escolheu onde renascer (GDD 12.4). Vale para a morte em jogo e para o
## save carregado de um jogador morto: nos dois a tela de morte está aberta e só a escolha tira daqui.
var pending_death_choice: bool = false
var save_manager: SaveManager
var scheduler: SaveScheduler

## Regras do servidor deste mundo (ADR-004), lidas uma vez ao carregar. `respawn_rules`, `world_rules` e `taming_rules`
## passam a ser as cópias com as chaves aplicadas; as Resources do `preload` nunca são alteradas.
var server_rules: ServerRules
var taming_rules: TamingRules

## Grade de navegação (M1): a zona a entrega a cada dino; o estado dos nós de recurso chega a ela por sinal.
var navigation: NavigationWorld
## Zona ativa dos dinos (MUN-05) e o grupo onde os selvagens do mapa moram.
var zone: DinoZone
var wild: WildPopulation
## Carcaças dos dinos mortos (recorte do SOB-06).
var carcasses: CarcassField
## Caça dos carnívoros (M1 etapa 5b): escolhe alvo, avisa a presa, come e descansa. Só a autoridade (este mundo) a roda.
var predation: PredationSystem
## Itens soltos no chão (a colheita por golpes derruba aqui; o jogador também larga).
var ground: GroundItemField
## Log do sistema (eventos da autoridade traduzidos em um lugar só) e a vista dele no canto de baixo.
var message_log: MessageLog
var message_log_view: MessageLogView
## Consulta única de ocupação do chão (jogador e dinos hoje; a grade de construção depois).
var occupancy := TileOccupancy.new()
## Música do jogo (canal `Music`): faixa de dia ou de noite conforme o `WorldClock`, com crossfade.
var music: MusicPlayer

## `entity_id` da criatura cuja tela compartilhada está aberta (0 = nenhuma).
var _screen_target_id: int = 0
var _quit_failed_once: bool = false
var _last_failure_notice: String = ""
var _wild_views: Dictionary = {}  # Dino -> [DinoView, DinoStatusBars, DinoMarker, WildLevelTag] dos selvagens ativos
var _gather_notice: String = ""
var _gather_notice_frame: int = -1
var _drop_sound_frame: int = -1
## O Continuar falhou: esta partida não existe de verdade (a cena volta ao título) e não grava nada.
var _load_failed: bool = false
## Quantos respawns o mundo já fez: semente do sorteio de ponto (vai no save).
var _respawn_count: int = 0


func _ready() -> void:
	_load_server_rules()
	music = MusicPlayer.new()
	add_child(music)
	music.follow_world(authority.clock)
	var target_outline := AttackTargetOutline.new()  # contorno no dino que o golpe vai atingir
	target_outline.player = player
	add_child(target_outline)
	map = IslandMap.default_map()
	if world_seed <= 0:
		world_seed = GameSession.world_seed_override if GameSession.world_seed_override > 0 else WorldSnapshot.new_world_seed()
	player.player_id = WorldSnapshot.new_player_id()  # mundo novo: id aleatório (o Continuar o troca pelo salvo)
	_place_on_island()
	dino.level = dino_level
	get_tree().auto_accept_quit = false  # o fechar da janela passa pelo save (_notification)
	screen.player_inventory = player.inventory
	screen.hotbar = player.hotbar
	screen.equipment = player.equipment
	screen.equip_requested.connect(func(iid: String) -> void: player.request_equip(iid))
	screen.unequip_requested.connect(func(slot_id: String) -> void: player.request_unequip(slot_id))
	player.equip_refused.connect(screen.show_refusal)
	screen.hotbar_assign_requested.connect(_on_hotbar_assign_requested)
	_wire_mouse_ui()
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
	scheduler.wild = wild
	scheduler.carcasses = carcasses
	scheduler.ground = ground
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


## Lê `server_rules.json` do mundo (ou o caminho de `--server-rules=`) e aplica as chaves sobre cópias das regras.
## Só o host chama isto (ADR-004). Arquivo ruim nunca impede o mundo de abrir: avisa e usa os padrões.
func _load_server_rules() -> void:
	var defaults := ServerRulesDefaults.new(respawn_rules, world_rules, dino.taming.rules)
	var world_dir := GameSession.save_root.path_join(
			world_id if SaveManager.is_valid_world_id(world_id) else GameSession.DEFAULT_WORLD)
	var path := ServerRules.path_for(world_dir, OS.get_cmdline_user_args())
	server_rules = ServerRules.load_file(path, defaults)
	for problem in server_rules.problems:
		push_warning("ServerRules: %s" % problem)
	respawn_rules = server_rules.apply_respawn(respawn_rules)
	world_rules = server_rules.apply_world(world_rules)
	taming_rules = server_rules.apply_taming(dino.taming.rules)
	dino.taming.rules = taming_rules
	authority.pvp_enabled = server_rules.pvp


## Quem os agressivos perseguem: os jogadores (um hoje).
func _chase_targets() -> Array:
	return [player]


## Início do jogador e a criatura do tutorial no ponto do mapa, e os nós de recurso nascem do dado do mapa.
## Mapa inválido (arquivo ruim) deixa a cena como está: o erro fica no log, o jogo não aborta.
func _place_on_island() -> void:
	if not map.is_valid():
		push_error("Main: o mapa %s não carregou." % IslandMap.DEFAULT_PATH)
		return
	player.position = map.start_point()
	dino.position = map.center_of(map.landmarks.get("paquicefalo_tutorial", map.start_cell))
	occupancy.add_source(func() -> Array: return [player])
	occupancy.add_source(func() -> Array: return zone.dinos() if zone != null else [dino])
	if resources != null:
		resources.occupancy = occupancy
		resources.yield_multiplier = server_rules.collect_multiplier
		resources.respawn_rate = server_rules.resource_respawn_rate
		resources.clock = authority.clock.now
		resources.populate(map, world_rules)
	navigation = NavigationWorld.new()
	navigation.name = "Navigation"
	add_child(navigation)
	navigation.setup(map, world_rules, navigation_rules, resources)
	_build_zone()


## A zona ativa e os bandos selvagens (a criatura da cena é o do tutorial e entra na zona também). A posição dos bandos sai
## da semente do mundo e das vagas do mapa (`WildLayout`); o nível, do bioma onde o membro nasce (faixa em
## `WorldRules.level_bands`). O save leva só o delta deles e as vagas não intactas (`WildPopulation`); o resto é recalculado.
func _build_zone() -> void:
	zone = DinoZone.new()
	zone.name = "DinoZone"
	zone.map = map
	zone.navigation = navigation.provider
	zone.foci = [player]
	add_child(zone)
	carcasses = CarcassField.new()
	carcasses.name = "Carcasses"
	carcasses.y_sort_enabled = true
	carcasses.authority = authority
	carcasses.occupancy = occupancy
	carcasses.clock = authority.clock.now
	add_child(carcasses)
	ground = GroundItemField.new()
	ground.name = "GroundItems"
	ground.y_sort_enabled = true
	ground.authority = authority
	ground.clock = authority.clock.now
	ground.world_seed = world_seed
	ground.player = player
	authority.drops_enabled = true
	authority.world_seed = world_seed
	authority.items_dropped.connect(func(item_id: String, amount: int, at: Vector2, dropper_id: String) -> void:
		ground.spawn_scatter(item_id, amount, at, dropper_id)
		_play_drop_sound(at))
	add_child(ground)
	wild = WildPopulation.new()
	wild.name = "Wild"
	wild.y_sort_enabled = true
	wild.taming_rules = taming_rules
	wild.target_locator = _chase_targets
	wild.clock = authority.clock.now
	add_child(wild)
	zone.register(dino, false)
	var tutorial_cell: Vector2i = map.landmarks.get("paquicefalo_tutorial", Vector2i(-1, -1))
	dino.sex = dino.stats.roll_sex(map.seed_value, "tutorial")
	if tutorial_cell != Vector2i(-1, -1):  # o bando do tutorial é fixo e conta para a distância dos outros
		wild.fixed_centers.append(WildLayout.placed_center(tutorial_cell, dino.stats.spawn_key, dino.stats.min_group_spacing_tiles))
	var scene_marker := get_node_or_null("DinoMarker") as DinoMarker
	if scene_marker != null:
		scene_marker.viewer = player
	var scene_view := get_node_or_null("DinoView") as DinoView
	if scene_view != null:
		scene_view.viewer = player
	for creature in wild.populate(map, world_rules, world_seed):
		zone.register(creature, false)
	wild.group_spawned.connect(_on_group_spawned)
	zone.mode_applied.connect(_on_zone_mode_applied)
	wild.authority = authority
	wild.creature_died.connect(_on_wild_died)
	predation = PredationSystem.new()
	predation.name = "Predation"
	predation.zone = zone
	predation.carcasses = carcasses
	predation.ground = ground
	predation.authority = authority
	add_child(predation)
	zone.reclassify()


## Um bando renasceu: os membros entram no registro da autoridade e na zona (o respawn é só da autoridade).
func _on_group_spawned(creatures: Array[Dino]) -> void:
	for creature in creatures:
		if authority.register(creature) == 0:
			push_error("Main: selvagem sem id no registro.")
		zone.register(creature, false)
	zone.reclassify()


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
	if wild != null:
		for creature in wild.get_children():
			if authority.register(creature) == 0:
				push_error("Main: selvagem sem id no registro.")


## Gravar agora (menu, sair e testes; a Cama usa `SaveManager.Reason.BED`). Falhou: o motivo fica em
## `scheduler.last_message` e o save anterior continua.
func save_game(reason: SaveManager.Reason) -> bool:
	return scheduler.save_now(reason)


func _continue_saved_game() -> void:
	var outcome := save_manager.load_first(
			func(data: Dictionary) -> bool: return WorldSnapshot.restore(data, player, dino, resources, wild, carcasses, authority, ground))
	if outcome.status == SaveManager.Status.OK:
		world_seed = wild.world_seed  # o save pode ter outra semente: a disposição dos bandos já foi refeita por ela
		ground.world_seed = world_seed
		authority.world_seed = world_seed
		_respawn_count = WorldSnapshot.respawn_count_of(outcome.data)
		scheduler.respawn_count = _respawn_count
		authority.ensure_next_id(WorldSnapshot.next_entity_id_of(outcome.data))
		_keep_on_island(WorldSnapshot.has_legacy_coordinates(outcome.data))
		if zone != null:
			for creature in wild.last_created:  # o save mudou a semente ou o bando de uma vaga: os membros novos entram no mundo
				authority.register(creature)
				zone.register(creature, false)
			for creature in wild.last_adopted:
				zone.register(creature, false)  # os domados recriados do save entram na zona
			zone.reclassify()  # o jogador e os dinos mudaram de lugar
		if WorldSnapshot.was_dead_pending_choice(outcome.data):
			_enter_death()  # carregar um morto reabre a escolha; não desfaz a morte
		if WorldSnapshot.same_map_revision(outcome.data):
			_notify(outcome.message)
		else:  # um aviso só: o da cópia anterior (.bak), se houve, junto com o do mapa
			_notify((outcome.message + " " if outcome.message != "" else "") + MAP_CHANGED_NOTICE, 8.0)
		return
	# Continuar que falha não abre jogo novo nem grava nada: volta ao título com o motivo, e o arquivo
	# que o jogo recusou fica exatamente como estava.
	_load_failed = true
	scheduler.frozen = true
	GameSession.notice = outcome.message if outcome.message != "" else "Nenhum jogo salvo."
	if menu_scene != "":
		get_tree().change_scene_to_file.call_deferred(menu_scene)


## Depois de carregar: posição fora da ilha (o mapa antigo tinha outro tamanho e outra origem; um save
## corrompido também) vai ao ponto seguro, e a criatura que ficou fora vem para perto do jogador. Nada se
## perde: só a posição muda. `legacy` = o save é de um mapa anterior: as coordenadas dele não valem em
## lugar nenhum, mesmo que caiam em terra por acaso.
func _keep_on_island(legacy: bool) -> void:
	if not map.is_valid():
		return
	if legacy or not map.is_walkable_at(player.position):
		player.position = map.safe_point()
	if is_instance_valid(dino) and not dino.is_queued_for_deletion() and (legacy or not map.is_walkable_at(dino.position)):
		dino.position = map.nearest_walkable_point(player.position + Vector2(24.0, 0.0), 6, map.safe_point())
	if wild != null:  # domado recriado do save (o salvo no mar, ou de outro mapa, volta para perto do jogador)
		for creature in wild.adopted():
			if legacy or not map.is_walkable_at(creature.position):
				creature.position = map.nearest_walkable_point(player.position + Vector2(24.0, 0.0), 6, map.safe_point())


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
	if map.is_valid() and not map.is_land(map.cell_of(point)):  # nem no mar nem na água rasa (GDD: proibido nascer ali)
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
	if wild != null:
		for creature in wild.get_children():
			if is_instance_valid(creature) and not creature.is_queued_for_deletion() and not (creature as Dino).state_machine.is_tamed:
				positions.append((creature as Dino).global_position)
	return positions


## Uma colheita pode render mais de um item no mesmo quadro (arbusto: fruta e fibra): o aviso junta os dois.
func _on_player_gathered(item_id: String, amount: int) -> void:
	var part := "+%d %s" % [amount, Items.display_name(item_id)]
	var frame := Engine.get_process_frames()
	_gather_notice = _gather_notice + "  " + part if frame == _gather_notice_frame else part
	_gather_notice_frame = frame
	_notify(_gather_notice, 1.5)


## Uma queda de itens soa uma vez, não por item (o sinal sai por item, todos no mesmo quadro).
func _play_drop_sound(at: Vector2) -> void:
	var frame := Engine.get_process_frames()
	if frame != _drop_sound_frame:
		_drop_sound_frame = frame
		SfxPlayer.play(self, SfxPlayer.ITEM_DROP, at)


func _on_gather_refused(reason: String) -> void:
	var texts := {Player.GATHER_DEPLETED: "Já foi colhido.", Player.GATHER_FULL: "Inventário cheio.",
			Player.GATHER_TOO_FAR: "Longe demais.", Player.GATHER_NEEDS_TOOL: "Só a Picareta quebra pedra."}
	_notify(str(texts.get(reason, "")), 1.5)


func _notify(text: String, seconds: float = PlayerHud.NOTICE_SECONDS) -> void:
	if hud != null and text != "":
		hud.show_notice(text, seconds)


## Só domado: um selvagem que morre não é salvo. A criatura já saiu do mundo (`queue_free` do próprio
## dino roda antes, pela ordem das conexões), então o save a deixa de fora e ela não volta ao carregar.
func _on_wild_died(creature: Dino, tamed: bool) -> void:
	carcasses.spawn_from(creature)  # o corpo fica no lugar (a criatura some no mesmo quadro)
	_detach_wild_views(creature)  # morto não guarda view nem chave
	if tamed:
		scheduler.request(SaveManager.Reason.TAMED_DINO_DEATH)


## Apresentação dos selvagens só enquanto ativos (teto de 32 + os fixados): view e barras nascem ao entrar na
## zona ativa e saem ao deixá-la, para o custo em nós seguir o teto e não os 108.
func _on_zone_mode_applied(creature: Dino, mode: ActivityZone.Mode) -> void:
	if creature == dino:
		return
	if mode == ActivityZone.Mode.ACTIVE:
		_attach_wild_views(creature)
	else:
		_detach_wild_views(creature)


func _attach_wild_views(creature: Dino) -> void:
	for key: Variant in _wild_views.keys():  # nenhuma chave de dino que já saiu do mundo
		if not is_instance_valid(key) or (key as Dino).is_queued_for_deletion():
			_detach_wild_views(key)
	if _wild_views.has(creature) or not is_instance_valid(creature):
		return
	var view := DinoView.new()
	view.dino = creature
	view.viewer = player
	var template := get_node_or_null("DinoView") as DinoView
	if template != null:
		view.cue_streams = template.cue_streams
		view.volume_db = template.volume_db
	var bars := DinoStatusBars.new()
	bars.dino = creature
	var marker := DinoMarker.new()
	marker.dino = creature
	marker.viewer = player
	add_child(view)
	add_child(bars)
	add_child(marker)  # só aparece se o dino for domado do jogador local
	var tag := WildLevelTag.new()
	tag.dino = creature
	tag.viewer = player
	add_child(tag)  # só aparece enquanto o dino for selvagem, vivo e perto
	_wild_views[creature] = [view, bars, marker, tag]


func _detach_wild_views(creature: Variant) -> void:
	for node: Node in _wild_views.get(creature, []):
		if is_instance_valid(node):
			node.queue_free()
	_wild_views.erase(creature)


func _on_dino_died() -> void:
	if not is_instance_valid(dino):
		return
	carcasses.spawn_from(dino)
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


## Menu do clique direito (no CanvasLayer da UI) e o arrastar da barra de atalhos. O menu executa pelo `Player`.
func _wire_mouse_ui() -> void:
	if controller != null:
		var menu := InteractionMenu.new()
		screen.get_parent().add_child(menu)
		controller.menu_opener = menu.open_for
		controller.menu_closer = menu.close
		menu.option_chosen.connect(func(option_id: String, target_id: int) -> void: player.run_option(option_id, target_id))
	message_log = MessageLog.new()
	message_log_view = MessageLogView.new()
	message_log_view.messages = message_log
	screen.get_parent().add_child(message_log_view)
	authority.game_event.connect(message_log.push_event)
	authority.owner_event.connect(func(owner_id: String, code: String, params: Dictionary) -> void:
		if owner_id == player.player_id:  # aviso do domado é só do dono (no co-op, cada um lê os seus)
			message_log.push_event(code, params))
	if hud != null:
		var bar := hud.hotbar_bar()
		bar.assign_requested.connect(_on_hotbar_assign_requested)
		bar.swap_requested.connect(func(first: int, second: int) -> void: player.hotbar.swap(first, second))
		bar.clear_requested.connect(func(slot: int) -> void: player.hotbar.clear(slot))


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
		# Domado do jogador: a tela não segue a disponibilidade da área (ela é do selvagem inconsciente).
		var tamed := target_dino.state_machine.is_tamed
		screen.open_with(player.inventory, target_dino.inventory, null if tamed else target_dino.interactable,
				target_dino.stats.display_name if tamed else _taming_title(target_dino))


## Título da tela do selvagem derrubado: o que ele come e a doma em andamento ("Come: Carne - 3/8, próxima em 2s").
func _taming_title(creature: Dino) -> String:
	var taming := creature.taming
	var text := "%s\nCome: %s" % [creature.stats.display_name, Items.display_name(taming.ideal_food)]
	var wait := taming.seconds_to_next_meal()
	text += "  %d/%d" % [taming.meals_eaten(), taming.meals_required()]
	if wait > 0.0:
		text += "  (próxima em %ds)" % ceili(wait)
	return text


## A tela pede mover o slot; a autoridade valida e executa (alcance, estado da criatura, espaço).
func _on_transfer_requested(from_player: bool, index: int, amount: int) -> void:
	var player_id := authority.id_of(player)
	var from_id := player_id if from_player else _screen_target_id
	var to_id := _screen_target_id if from_player else player_id
	authority.request_transfer_slot(player_id, from_id, index, to_id, amount)


func _on_action_denied(_actor_id: int, action: String, result: Enums.ActionResult) -> void:
	if action == WorldAuthority.ACTION_TRANSFER:
		screen.show_transfer_refusal(result)
	elif action == WorldAuthority.ACTION_GATHER and result == Enums.ActionResult.OUT_OF_RANGE:
		_on_gather_refused(Player.GATHER_TOO_FAR)
	elif (action == WorldAuthority.ACTION_COMMAND or action == WorldAuthority.ACTION_INTERACT) \
			and result == Enums.ActionResult.NOT_OWNER:
		_notify("Esse dino não é seu.", 1.5)
