# SPDX-License-Identifier: MIT
class_name PlayerController
extends CursorSource
## Controlador do jogador local (cliente): a ÚNICA leitura de `Input` do jogo fora da `src/ui/`.
## Lê o teclado, vira intenção e a entrega à autoridade (ADR-001): o movimento vai como
## `request_move`; interagir, atacar e os atalhos, pelos pedidos do `Player`. Não conhece física
## nem regra de movimento: a autoridade valida e o corpo aplica. Um jogador remoto não tem controlador.

## Corpo que este controlador dirige.
## Ação da tecla G (Seguir/Ficar do domado mais perto), criada por código para não mexer em `project.godot`.
## Intervalo mínimo entre duas consultas do cursor ao mundo.
const CURSOR_POLL_SECONDS := 0.05
const TOGGLE_FOLLOW := &"toggle_follow"

## Ações do cursor (`cursor_action`): o nome é o do arquivo da imagem em `assets/ui/cursores/`.
const CURSOR_DEFAULT := &"padrao"
const CURSOR_HAND := &"mao"
const CURSOR_AXE := &"machado"
const CURSOR_PICKAXE := &"picareta"
const CURSOR_ATTACK := &"ataque"
const CURSOR_INTERACT := &"interagir"

@export var player: Player
## Ponto de passagem das ações; a direção sai por ele, nunca direto no corpo.
@export var authority: WorldAuthority

## Menu de opções do clique direito no mundo: a `Main` liga a UI por estes dois ganchos (a lógica não conhece a tela).
## `menu_opener(tela, título, id_do_alvo, opções) -> bool` abre; `menu_closer()` fecha. Sem eles o clique direito não faz nada.
var menu_opener: Callable = Callable()
var menu_closer: Callable = Callable()

var _actor_id: int = 0
## O mouse é o dispositivo em uso (mexeu ou clicou): o contorno e o golpe preferem o que está sob o cursor.
## Qualquer tecla de ação ou de movimento devolve ao automático.
var _mouse_in_use: bool = false
## Última consulta do cursor ao mundo (`Time.get_ticks_msec`) e o resultado: a consulta é O(N) e o mouse mexe a cada quadro.
var _cursor_polled_at: float = -1000.0
var _cursor_cache: Dictionary = {}


## O cursor contextual agora: só com o mouse em uso (com o teclado, volta ao padrão); sobre a UI, o padrão.
func current_cursor() -> Dictionary:
	if player == null or not _mouse_in_use:
		return super.current_cursor()
	var now := authority.clock.now() if authority != null else 0.0  # relógio do mundo, não de parede (ADR-006)
	if now - _cursor_polled_at < CURSOR_POLL_SECONDS and not _cursor_cache.is_empty():
		return _cursor_cache  # no máximo uma consulta ao mundo a cada 50 ms; o resultado vale para ação e alcance
	_cursor_polled_at = now
	_cursor_cache = cursor_state(player.get_global_mouse_position(), pointer_over_ui())
	return _cursor_cache


func _init() -> void:
	# Roda antes do corpo no quadro de física, para o pedido valer no mesmo passo.
	process_physics_priority = -1


func _physics_process(_delta: float) -> void:
	tick()


## Lê o input do quadro e pede o movimento. Chamável sem esperar frame (testes).
func tick() -> void:
	if player == null or authority == null:
		return
	var direction := read_direction()
	authority.request_move(_id(), direction, Input.is_action_pressed("sprint"))
	if direction != Vector2.ZERO:
		_mouse_in_use = false
	if _mouse_in_use and not pointer_over_ui():
		player.mouse_point = player.get_global_mouse_position()  # a câmera anda: o cursor aponta para outro ponto do mundo
		player.mouse_aim_active = true
	elif not _mouse_in_use:
		player.mouse_aim_active = false


## `get_vector` já devolve comprimento no máximo 1, então a diagonal não é mais rápida que o eixo.
func read_direction() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


## Cria a ação da tecla G se ainda não existe (chamar de novo não duplica).
static func ensure_actions() -> void:
	if InputMap.has_action(TOGGLE_FOLLOW):
		return
	InputMap.add_action(TOGGLE_FOLLOW)
	var event := InputEventKey.new()
	event.physical_keycode = KEY_G
	InputMap.action_add_event(TOGGLE_FOLLOW, event)


func _ready() -> void:
	ensure_actions()


## Única leitura de input de ações. Só dispara fora de telas.
func _unhandled_input(event: InputEvent) -> void:
	if player == null:
		return
	ensure_actions()  # idempotente; garante a tecla G mesmo sem o `_ready` (testes)
	if event is InputEventMouseMotion:
		_mouse_in_use = true
	elif event is InputEventMouseButton and event.pressed:
		world_click(event.button_index, player.get_global_mouse_position(), event.position, pointer_over_ui())
	elif event.is_action_pressed("interact"):
		_mouse_in_use = false
		if event is InputEventKey and event.shift_pressed:
			open_target_options()  # Shift+E = o menu de opções do alvo (inventário do domado, Seguir, Ficar...)
		elif player.target_is_own_tamed():
			open_target_options()  # E num domado meu abre o menu: ordem nunca sai direto da tecla
		else:
			player.try_interact()
	elif event.is_action_pressed(TOGGLE_FOLLOW):
		_mouse_in_use = false
		player.toggle_nearest_order()
	elif event.is_action_pressed("attack"):
		_mouse_in_use = false
		player.attack_with_key()
	else:
		for slot in HotbarComponent.SLOT_COUNT:
			if event.is_action_pressed("hotbar_%d" % (slot + 1)):
				player.request_use_item(slot)
				break


## O ponteiro está sobre algum controle da UI (inventário, HUD, menus)? Clique ali nunca vira ação no mundo.
func pointer_over_ui() -> bool:
	return is_inside_tree() and get_viewport().gui_get_hovered_control() != null


## Clique do mouse no mundo, já em coordenadas do mundo (`world_point`) e da tela (`screen_point`, onde o menu abre).
## Esquerdo = golpe (vira para o cursor e prefere a criatura sob ele); direito = menu de opções do que está sob o cursor.
## Sobre a UI não faz nada. Devolve se o pedido à autoridade valeu. Chamável sem janela (testes).
func world_click(button: int, world_point: Vector2, screen_point: Vector2, over_ui: bool) -> bool:
	if player == null or authority == null or over_ui:
		return false
	_mouse_in_use = true
	if menu_closer.is_valid():
		menu_closer.call()
	if button == MOUSE_BUTTON_LEFT:
		return player.attack_at(world_point)
	if button == MOUSE_BUTTON_RIGHT and not player.input_locked:
		return open_options(world_point, screen_point)
	return false


## Que ação o clique esquerdo teria sob `world_point`, e se o jogador a alcança. Só consulta (sem pedido, sem estado). A criatura
## sob o cursor tem prioridade, como em `Player.attack_at`; sobre a UI, ou sem nada, é o padrão. `{"action": StringName,
## "in_reach": bool}`. Alcance: o mesmo da autoridade (`rules.reach_px()`), distância entre o jogador e o alvo.
func cursor_state(world_point: Vector2, over_ui: bool = false) -> Dictionary:
	var none := {"action": CURSOR_DEFAULT, "in_reach": true}
	if player == null or authority == null or over_ui:
		return none
	var picked := authority.pick_at(world_point)  # uma varredura só (criatura e qualquer entidade)
	var target: Node2D = picked["creature"] if picked["creature"] != null else picked["any"]
	if target == null:
		return none
	var action := _cursor_action_of(target)
	if action == CURSOR_DEFAULT:
		return none
	var in_reach := player.global_position.distance_to(target.global_position) <= authority.rules.reach_px()
	return {"action": action, "in_reach": in_reach}


func cursor_action(world_point: Vector2, over_ui: bool = false) -> StringName:
	return cursor_state(world_point, over_ui)["action"]


func cursor_in_reach(world_point: Vector2, over_ui: bool = false) -> bool:
	return cursor_state(world_point, over_ui)["in_reach"]


func _cursor_action_of(target: Node2D) -> StringName:
	var dino := target as Dino
	if dino != null:
		if not dino.state_machine.is_tamed:
			return CURSOR_ATTACK
		return CURSOR_INTERACT if dino.owner_player_id == player.player_id else CURSOR_DEFAULT
	var resource := target as ResourceNode
	if resource != null and resource.def.is_struck():
		match resource.def.material_id:
			"wood":
				return CURSOR_AXE
			"stone", "ore":
				return CURSOR_PICKAXE
	return CURSOR_HAND if target is ResourceNode or target is GroundItem else CURSOR_DEFAULT


## Abre o menu de opções do que está sob `world_point`. Falso se não há nada ou nada a oferecer.
func open_options(world_point: Vector2, screen_point: Vector2) -> bool:
	var target := authority.entity_at(world_point)
	if target == null or not menu_opener.is_valid():
		return false
	var target_id := authority.id_of(target)
	var options := authority.interaction_options(_id(), target_id)
	return bool(menu_opener.call(screen_point, _title_of(target), target_id, options))


## Menu de opções do alvo da interação (`player.target`), junto de onde ele está na tela. Teclado: Shift+E.
func open_target_options() -> bool:
	if player.target == null or not is_instance_valid(player.target.entity) or player.input_locked:
		return false
	var node := player.target.entity as Node2D
	return open_options(node.global_position, node.get_global_transform_with_canvas().origin)


func _title_of(target: Node) -> String:
	if target is Dino:
		return (target as Dino).stats.display_name
	if target is ResourceNode:
		return (target as ResourceNode).def.display_name
	return ""


## Id do jogador na autoridade, guardado: só procura de novo se o registro mudou.
func _id() -> int:
	if _actor_id == 0 or authority.entity(_actor_id) != player:
		_actor_id = authority.id_of(player)
	return _actor_id
