# gdlint: ignore=max-public-methods
# SPDX-License-Identifier: MIT
class_name Player
extends CharacterBody2D
## Corpo do jogador: aplica a velocidade à física e compõe os atributos. As regras ficam nos
## componentes. Não lê `Input`: o `PlayerController` pede o movimento à autoridade (`request_move`) e
## a regra (`apply_input`) recebe a direção pronta, testável sem input real.
##
## Interação: o detector (Area2D) enxerga as `InteractableArea` no alcance e o
## `target` é a mais próxima, só uma sugestão de mira. `try_interact` e `attack` são a intenção do
## jogador, chamáveis sem teclado: ela vira `WorldAuthority.request_*` com ids (ADR-001), que valida
## alcance, recarga e posse. `strike` e os `perform_*` são o efeito, aplicado só pela autoridade. Sem
## `authority` o jogador não age sobre o mundo. `input_locked` (ligado pela tela de inventário) congela o jogador.

## Alvo mudou (ou null). Serve ao prompt e ao painel da criatura.
signal target_changed(target: InteractableArea)
## O dino que o próximo golpe atinge mudou (ou null). A apresentação o destaca.
signal attack_target_changed(dino: Dino)
signal input_lock_changed(locked: bool)
## O golpe acertou uma criatura (a apresentação anima e toca o som).
signal attacked
## Comeu um item (quem mostra o efeito é a apresentação).
signal ate(item_id: String)
## O item na vaga Arma mudou (`iid` do equipado, "" = mãos livres).
signal equipped_changed(iid: String)
## A arma em mãos quebrou (durabilidade zerou) e saiu da vaga; o jogador fica de mãos vazias.
signal weapon_broke(item_id: String)
## Um pedido de equipar ou tirar foi recusado (`EquipmentComponent.REFUSED_*`); a tela mostra o aviso.
signal equip_refused(reason: String)
## Coletou de um nó de recurso (a apresentação mostra o ganho).
signal gathered(item_id: String, amount: int)
## Um pedido de coleta foi recusado (`GATHER_*`); recarga é silenciosa.
signal gather_refused(reason: String)

## Versão do formato do save do jogador. 1 = antigo (sem campo; item em mãos em `equipped`, na grade);
## 2 = vagas de equipamento (`equipment`).
const FORMAT_VERSION := 2
const COOLDOWN := "cooldown"
## Motivos de recusa de `request_gather`.
const GATHER_NO_TARGET := "no_target"
const GATHER_DEPLETED := "depleted"
const GATHER_FULL := "full"
const GATHER_BLOCKED := "blocked"
const GATHER_TOO_FAR := "too_far"
## Tocou um nó que exige ferramenta sem ela: o toque machuca a mão e não coleta nada.
const GATHER_NEEDS_TOOL := "needs_tool"
## A autoridade negou o pedido antes de a regra rodar (ator morto, argumento inválido, sem autoridade).
const DENIED := "denied"
## `player_id` do personagem local (ADR-003): o dono do dino aponta para ele, não para o nó.
const LOCAL_PLAYER_ID := "local"

## Ponto de passagem das ações (ADR-001); a `Main` o liga. Sem ele, interagir e atacar não fazem nada.
@export var authority: WorldAuthority
## Identidade do personagem (ADR-003): vai no save e é o que o dino domado guarda como dono.
@export var player_id: String = LOCAL_PLAYER_ID
@export var walk_speed: float = 70.0
@export var sprint_speed: float = 120.0
## Números do jogador (fome, recarga de comida e de troca, ofego) vindos dos dados.
@export var rules: PlayerRules = preload("res://data/balance/player_rules.tres")
## Golpe de mãos livres (Soco): dano, torpor e recarga vêm dos dados (`res://data/weapons/`).
@export var unarmed: WeaponDef = preload("res://data/weapons/punch.tres")
## Equipamento inicial do jogo normal: nenhum (as armas vêm da fabricação, M3). O de desenvolvimento está em
## `PlayerRules.dev_starting_equipment` e só entra com `dev_items`.
@export var starting_equipment: Array[String] = []
## Comida inicial para poder testar o ciclo de domesticação (id -> quantidade).
@export var starting_items: Dictionary = {Items.BERRY: 10, Items.MEAT: 4, Items.FERN: 3}

## Aplica o equipamento de desenvolvimento no `_ready`. Padrão: build de debug ou `--dev`; o teste troca antes de entrar na árvore.
var dev_items: bool = PlayerRules.dev_items_allowed(OS.is_debug_build(), OS.get_cmdline_args() + OS.get_cmdline_user_args())

var target: InteractableArea = null
## Dino que o golpe atinge agora (regra `AttackTargeting`); o destaque e `attack()` leem este mesmo valor.
var attack_target: Dino = null
## Direção do olhar (unitária): a última direção de movimento pedida. Começa para baixo.
var facing: Vector2 = Vector2.DOWN
## `iid` do item na vaga Arma; "" = mãos livres (Soco). O item equipado NÃO está na grade.
var equipped_iid: String:
	get:
		return equipment.iid_in(EquipmentLayout.WEAPON)
## O que a última coleta entregou (item -> unidades); vazio se nada entrou. A autoridade o lê para avisar.
var last_gather: Dictionary = {}
## O que a última colheita por golpes soltou no chão (item -> unidades); a autoridade o espalha em itens de chão.
var last_drop: Dictionary = {}
## O mouse está em uso e `mouse_point` é o cursor no mundo: o alvo do golpe prefere a criatura sob ele. Quem lê o
## mouse (o controlador) liga `mouse_aim_active` e atualiza `mouse_point`; andar ou golpear por tecla desliga.
var mouse_aim_active: bool = false
var mouse_point: Vector2 = Vector2.ZERO
var input_locked: bool = false:
	set(value):
		if input_locked != value:
			input_locked = value
			input_lock_changed.emit(value)

var _in_range: Array[InteractableArea] = []
var _attack_timer: float = 0.0
var _eat_timer: float = 0.0
var _equip_timer: float = 0.0
var _gather_timer: float = 0.0
var _repeat_node: ResourceNode = null
var _repeat_timer: float = 0.0
var _last_equipped: String = ""
## Direção e corrida do quadro, guardadas por `perform_move` e consumidas pela física.
var _move_direction: Vector2 = Vector2.ZERO
var _move_sprint: bool = false
## Motivo da última recusa de uma regra (`perform_*`); "" quando o pedido valeu. Só devolve texto ao chamador.
var _last_refusal: String = ""

## Sprite: só a apresentação (`PlayerView`) escolhe o quadro.
@onready var visual: Sprite2D = $Visual
@onready var health: HealthComponent = $HealthComponent
@onready var stamina: StaminaComponent = $StaminaComponent
@onready var hunger: HungerComponent = $HungerComponent
@onready var inventory: InventoryComponent = $InventoryComponent
@onready var hotbar: HotbarComponent = $HotbarComponent
@onready var equipment: EquipmentComponent = $EquipmentComponent
@onready var detector: Area2D = $InteractionDetector


func _ready() -> void:
	_apply_hitbox()
	hunger.decay_per_second = rules.hunger_decay_idle
	hunger.recovery_per_second = rules.hunger_recovery_per_second
	health.died.connect(hunger.clear_pending)
	stamina.rules = rules
	hunger.starved.connect(health.take_damage)
	detector.area_entered.connect(_on_area_entered)
	detector.area_exited.connect(_on_area_exited)
	# O save é restaurado depois do _ready (from_dict exige o nó na árvore) e sobrescreve isto.
	for item_id: Variant in starting_items:
		if item_id is String:
			inventory.add(item_id, int(starting_items[item_id]))
			hotbar.assign(hotbar.first_free(), item_id)
	for item_id in initial_equipment():
		if inventory.add(item_id, 1) == 0:
			hotbar.assign_iid(hotbar.first_free(), _newest_iid(item_id), item_id)
	equipment.changed.connect(_on_equipment_changed)


## Equipamento com que o jogador nasce: o do jogo normal mais, em desenvolvimento, os itens de teste (Lança, Bastão).
func initial_equipment() -> Array[String]:
	var ids: Array[String] = starting_equipment.duplicate()
	if dev_items:
		ids.append_array(rules.dev_starting_equipment)
	return ids


func _physics_process(delta: float) -> void:
	tick(delta)
	# O pedido de movimento vale por um quadro: sem pedido novo (controlador ausente, pedido negado), para.
	velocity = apply_input(_move_direction, _move_sprint, delta)
	_move_direction = Vector2.ZERO
	_move_sprint = false
	update_dino_collision()
	move_and_slide()


## O jogador nunca fica preso entre dinos: enquanto o corpo se sobrepõe ao de algum dino (perseguição, bando, nascimento
## em cima), a colisão contra dinos fica desligada para ele sair em qualquer direção; livre, ela volta. O terreno segue
## valendo. Público para testar.
func update_dino_collision() -> void:
	var mine := overlap_rect()  # só penetração de verdade: encostar (folga da física) ainda barra
	var overlapping := false
	for node in get_tree().get_nodes_in_group(Dino.GROUP):
		var other := node as Dino
		if other != null and not other.is_queued_for_deletion() and mine.intersects(other.body_rect()):
			overlapping = true
			break
	collision_mask = 1 if overlapping else (1 | Dino.BODY_LAYER)


## Retângulo do corpo do jogador no mundo.
func overlap_rect() -> Rect2:
	var size := rules.hitbox_size
	var center: Vector2 = ($CollisionShape2D as Node2D).global_position
	return Rect2(center - size * 0.5, size)


## Passo de tempo da parte de interação: recarga do golpe e escolha do alvo.
func tick(delta: float) -> void:
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	_eat_timer = maxf(_eat_timer - delta, 0.0)
	_equip_timer = maxf(_equip_timer - delta, 0.0)
	_gather_timer = maxf(_gather_timer - delta, 0.0)
	_repeat_timer = maxf(_repeat_timer - delta, 0.0)
	health.tick(delta)
	update_target()
	_update_attack_target()


## Efeito do pedido de movimento: guarda a direção do quadro (já validada). Só a autoridade chama
## (`WorldAuthority.request_move`). A tela aberta trava o corpo: a direção vira zero.
func perform_move(direction: Vector2, wants_sprint: bool) -> void:
	_move_direction = Vector2.ZERO if input_locked else direction
	if _move_direction.length_squared() > 0.0001:
		facing = _move_direction.normalized()
		mouse_aim_active = false  # andar pelo teclado devolve a mira à escolha automática
	_move_sprint = wants_sprint and not input_locked


## Efeito do pedido de virar (só a autoridade chama): muda o olhar sem andar.
func perform_face(direction: Vector2) -> void:
	if direction.length_squared() > 0.0001:
		facing = direction.normalized()


## Regra de movimento: converte direção + pedido de corrida na velocidade do frame
## e gasta/regenera a stamina. Só corre quem está se movendo e tem stamina.
func apply_input(direction: Vector2, wants_sprint: bool, delta: float) -> Vector2:
	if health.is_dead():
		return Vector2.ZERO
	direction = direction.limit_length(1.0)
	var moving := direction != Vector2.ZERO
	var sprinting := wants_sprint and moving and stamina.can_sprint()
	# A fome desce conforme o movimento que a autoridade validou (parado, andando, correndo); nunca lido do Input.
	hunger.decay_per_second = rules.hunger_decay_run if sprinting else (rules.hunger_decay_walk if moving else rules.hunger_decay_idle)
	stamina.tick(delta, sprinting)
	return direction * (sprint_speed if sprinting else walk_speed)


## Escolhe o interagível mais próximo no alcance e avisa se mudou.
func update_target() -> void:
	var best: InteractableArea = null
	var best_distance := INF
	var best_priority := 99
	for area in _in_range:
		if not is_instance_valid(area) or not area.can_prompt() or _is_others_tamed(area):
			continue
		var priority := interact_priority(area)
		var distance := global_position.distance_squared_to(area.global_position)
		if priority < best_priority or (priority == best_priority and distance < best_distance):
			best_distance = distance
			best_priority = priority
			best = area
	if best != target:
		target = best
		target_changed.emit(target)


## Prioridade do alvo do E (menor vence): item no chão, nó de recurso, estrutura/objeto, criatura. Entre iguais, o mais perto.
static func interact_priority(area: InteractableArea) -> int:
	if area.entity is GroundItem:
		return 0
	if area.entity is ResourceNode:
		return 1
	if area.entity is Dino:
		return 3
	return 2


## É o domado (com dono) de OUTRO jogador? Esse não é alvo: a tecla nada faria nele e ele não pode tomar o lugar de um nó de recurso.
func _is_others_tamed(area: InteractableArea) -> bool:
	var dino := area.entity as Dino
	return dino != null and dino.can_command() and dino.owner_player_id != player_id


## Recalcula o alvo do golpe pela regra única (`AttackTargeting`) e avisa se mudou. Só entram dinos vivos e
## selvagens (os que `request_attack` aceitaria), ao alcance da autoridade e do lado para onde o jogador olha.
func _update_attack_target() -> Dino:
	if authority == null:
		return attack_target  # sem autoridade o jogador não age sobre o mundo: nada a destacar
	var candidates := _dino_candidates()
	var chosen := _mouse_pick(candidates)
	if chosen == null:
		chosen = authority.choose_attack_target(global_position, facing, candidates, attack_target) as Dino
	if chosen != attack_target:
		attack_target = chosen
		attack_target_changed.emit(attack_target)
	return attack_target


## Dinos vivos e selvagens que o detector enxerga (os que `request_attack` aceitaria).
func _dino_candidates() -> Array[Node2D]:
	var candidates: Array[Node2D] = []
	for area in _in_range:
		var dino := area.entity as Dino if is_instance_valid(area) else null
		if dino != null and not dino.health.is_dead() and not dino.state_machine.is_tamed:
			candidates.append(dino)
	return candidates


## Criatura sob o cursor (mouse em uso) que o golpe alcança: ao alcance da autoridade e à frente da direção do cursor.
## Fora do alcance ou sem mouse, null (vale a escolha automática).
func _mouse_pick(candidates: Array[Node2D]) -> Dino:
	if not mouse_aim_active:
		return null
	var under := authority.entity_at(mouse_point) as Dino
	if under == null or not candidates.has(under):
		return null
	return under if authority.can_strike_toward(global_position, mouse_point - global_position, under) else null


## Intenção "golpear onde o mouse clicou": vira para o cursor (pedido de virar à autoridade, sem andar) e golpeia a
## criatura sob ele; sem ela ao alcance, vale a escolha automática. A autoridade valida alcance, frente e recarga.
func attack_at(point: Vector2) -> bool:
	if input_locked or health.is_dead() or authority == null:
		return false
	var direction := point - global_position
	if direction.length() > 1.0:
		authority.request_face(authority.id_of(self), direction.normalized())
	mouse_point = point
	mouse_aim_active = true
	var under := authority.entity_at(point) as ResourceNode
	if under != null and under.def.is_struck() and _mouse_pick(_dino_candidates()) == null:
		return _strike_target(under)  # o cursor está numa árvore ou rocha e não numa criatura
	var wild := authority.entity_at(point) as Dino
	if wild != null and not wild.state_machine.is_tamed and not wild.health.is_dead() and _update_attack_target() == null:
		# Nada ao alcance, mas há uma criatura sob o cursor: o pedido vai e a autoridade explica a recusa (fora de alcance).
		return authority.request_attack(authority.id_of(self), authority.id_of(wild)) == Enums.ActionResult.OK
	return _strike_target()


## Executa uma opção do menu do mouse (`WorldAuthority.interaction_options`) sobre a entidade `target_id`.
func run_option(option_id: String, target_id: int) -> bool:
	if input_locked or health.is_dead() or authority == null:
		return false
	var actor_id := authority.id_of(self)
	match option_id:
		"interact", "inventory":
			return authority.request_interact(actor_id, target_id) == Enums.ActionResult.OK
		"follow", "stay":
			return authority.request_command(actor_id, target_id, option_id.to_upper()) == Enums.ActionResult.OK
		"attack":
			var target := authority.entity(target_id) as Node2D
			return target != null and attack_at(target.global_position)
	return false


## Intenção "interagir com o alvo": pede à autoridade (ou, num domado seu, troca a ordem Seguir/Ficar).
## Retorna true se a autoridade aceitou. Quem abre a tela ou colhe ouve `interaction_granted`.
func try_interact() -> bool:
	if input_locked or health.is_dead() or target == null or authority == null:
		return false
	var actor_id := authority.id_of(self)
	var target_id := authority.id_of(target.entity)
	if target.entity is GroundItem:  # item no chão: o E o pega (prioridade 1 do E)
		return authority.request_pickup(actor_id, target_id) == Enums.ActionResult.OK
	# A tecla E nunca dá ordem a dino (decisão do dono, 08/11): as ordens saem do menu e da tecla G (`toggle_nearest_order`).
	return authority.request_interact(actor_id, target_id) == Enums.ActionResult.OK


## O alvo do E é um domado meu? (a tecla abre o menu em vez de interagir)
func target_is_own_tamed() -> bool:
	var dino := target.entity as Dino if target != null else null
	return dino != null and dino.can_command() and dino.owner_player_id == player_id


## Tecla G: alterna Seguir/Ficar do domado meu mais perto, ao alcance. Retorna true se a autoridade aceitou.
func toggle_nearest_order() -> bool:
	if input_locked or health.is_dead() or authority == null:
		return false
	var actor_id := authority.id_of(self)
	var dino_id := authority.nearest_own_tamed(actor_id)
	var dino := authority.entity(dino_id) as Dino
	if dino == null:
		return false
	var next := Enums.DinoOrder.STAY if dino.state_machine.order == Enums.DinoOrder.FOLLOW else Enums.DinoOrder.FOLLOW
	return authority.request_command(actor_id, dino_id, Enums.DinoOrder.find_key(next)) == Enums.ActionResult.OK


## Intenção "golpear o dino destacado" (`attack_target`): a autoridade valida alcance, recarga e
## alvo, e chama `strike`. Retorna true se acertou.
func attack() -> bool:
	return _strike_target()


## Golpe pedido pelo teclado ou controle: devolve a mira à escolha automática.
func attack_with_key() -> bool:
	mouse_aim_active = false
	return _strike_target()


func _strike_target(preferred_node: ResourceNode = null) -> bool:
	if input_locked or health.is_dead() or authority == null:
		return false
	var dino := _update_attack_target()
	if preferred_node != null:
		return _strike_node(preferred_node)
	if dino == null:
		# Sem criatura para golpear: o golpe vai no nó de recurso que a interação mira (árvore, rocha, minério).
		var node := target.entity as ResourceNode if target != null else null
		return node != null and node.def.is_struck() and _strike_node(node)
	return authority.request_attack(authority.id_of(self), authority.id_of(dino)) == Enums.ActionResult.OK


## Um golpe no nó de recurso: a autoridade valida alcance, frente e recarga e chama `perform_gather`.
func _strike_node(node: ResourceNode) -> bool:
	return authority.request_gather(authority.id_of(self), authority.id_of(node)) == Enums.ActionResult.OK


## Pronto para golpear? (a recarga é do jogador; a autoridade a consulta)
func can_strike() -> bool:
	return _attack_timer <= 0.0


## Efeito do golpe da arma em mãos: dano e torpor vêm da arma, nunca do pedido. Só a autoridade chama.
## Recarga e `attacked` só valem se algo foi aplicado. O Soco também machuca quem o dá (`self_damage` da
## arma, GDD 5.9b), parando no piso de vida das regras.
func strike(dino: Dino) -> bool:
	var weapon := current_weapon()
	if not dino.receive_hit(weapon.damage, weapon.torpor, TamingRules.ATTACKER_PLAYER, player_id):
		return false
	_attack_timer = weapon.cooldown
	hunger.spend(rules.hunger_cost_attack)
	_hurt_hands(weapon.self_damage)
	var held_iid := equipment.iid_in(EquipmentLayout.WEAPON)
	var broken := equipment.wear(EquipmentLayout.WEAPON, 1)  # cada golpe aceito gasta 1 de durabilidade
	if broken != "":
		var slot := hotbar.slot_of_iid(held_iid)
		if slot >= 0:
			hotbar.clear(slot)
		weapon_broke.emit(broken)
	attacked.emit()
	return true


## Dano que o jogador causa a si mesmo com as mãos (Soco em dino, colheita de árvore e de carcaça, toque em
## pedra). NUNCA leva a vida abaixo de `rules.hand_damage_floor`: o Soco não mata (sem morte boba nem softlock).
func _hurt_hands(amount: float) -> void:
	health.take_damage_down_to(amount, rules.hand_damage_floor)


## Motivo da última recusa de uma regra do jogador ("" = nenhuma).
func last_refusal() -> String:
	return _last_refusal


## Anti-spam da coleta: o mesmo nó pedido de novo dentro de `seconds` é barrado; outro nó nunca espera.
func mark_gather(node: ResourceNode, seconds: float) -> void:
	_repeat_node = node
	_repeat_timer = seconds


func gather_repeat_blocked(node: ResourceNode) -> bool:
	return _repeat_timer > 0.0 and _repeat_node == node


## Segundos que faltam para poder colher de novo: só a carcaça tem espera; nó de toque devolve 0.
func gather_cooldown_left() -> float:
	return _gather_timer


## A ferramenta `item_id` está em mãos (na vaga da arma)? Id vazio nunca está. A HUD usa para a dica do que falta.
func has_tool_in_hand(item_id: String) -> bool:
	return _has_tool(item_id)


func _has_tool(item_id: String) -> bool:
	return item_id != "" and str(equipment.item_in(EquipmentLayout.WEAPON).get("id", "")) == item_id


## Intenção "colher o nó de recurso na mira": só o pede à autoridade, com o id do alvo. Devolve "" se
## coletou ou o motivo da recusa (`GATHER_*`, ou "cooldown", silenciosa).
func request_gather() -> String:
	if input_locked or authority == null:
		return GATHER_BLOCKED
	var node := target.entity as ResourceNode if target != null else null
	var result := authority.request_gather(authority.id_of(self), authority.id_of(node))
	match result:
		Enums.ActionResult.OK:
			return ""
		Enums.ActionResult.UNKNOWN_TARGET, Enums.ActionResult.INVALID_TARGET:
			return GATHER_NO_TARGET
		Enums.ActionResult.OUT_OF_RANGE:
			return GATHER_TOO_FAR
		Enums.ActionResult.UNKNOWN_ACTOR, Enums.ActionResult.ACTOR_DEAD:
			return GATHER_BLOCKED
	return _last_refusal


## Efeito da coleta (só a autoridade chama, depois de validar ator, alvo e alcance). Devolve "" se coletou
## ou o motivo da recusa. Recusa por falta de espaço NÃO gasta o nó. A recarga é o tempo de ação do tipo de nó.
## Sem a ferramenta do nó, a colheita é a do Soco (dano a si mesmo por colheita, `hand_self_damage`); nó que
## EXIGE ferramenta (a pedra) só leva um toque: machuca a mão, não coleta e devolve `GATHER_NEEDS_TOOL`.
func perform_gather(node: ResourceNode) -> String:
	_last_refusal = ""
	last_gather = {}
	last_drop = {}
	var refusal := _gather_gate(node)
	if refusal != "":
		return refusal
	var hits_needed := node.def.hits_needed(_has_tool(node.def.tool_item_id))
	if hits_needed > 1:
		return _strike_resource(node, hits_needed)
	return _gather_by_touch(node)


## Antes de colher: recarga, alvo válido e o toque em nó que EXIGE ferramenta (machuca a mão e não coleta). "" = pode colher.
func _gather_gate(node: ResourceNode) -> String:
	var hits_needed := 1
	if node != null and node.def != null:
		hits_needed = node.def.hits_needed(_has_tool(node.def.tool_item_id))
	# Colher por golpes usa a recarga do golpe da arma em mãos; a colheita de um toque, a própria.
	if (hits_needed > 1 and not can_strike()) or (hits_needed <= 1 and _gather_timer > 0.0):
		_last_refusal = COOLDOWN
		return COOLDOWN
	var reason := _gather_refusal(node)
	if reason != "":
		return _refuse_gather(reason)
	if node.def.tool_required and not _has_tool(node.def.tool_item_id):
		# A ferramenta vem antes do espaço: a pedra sem Picareta machuca a mão mesmo com o inventário cheio.
		_hurt_hands(node.def.touch_self_damage)
		_gather_timer = node.def.touch_seconds
		return _refuse_gather(GATHER_NEEDS_TOOL)
	return ""


## Um golpe num nó de vários golpes (árvore, rocha, minério). Os que não quebram só somam progresso; o último derruba o
## nó e o recurso vai ao CHÃO (`last_drop`: a autoridade o espalha), nunca direto ao inventário. Sem ferramenta, o
## último golpe custa a vida da mão uma vez (não por golpe).
func _strike_resource(node: ResourceNode, hits_needed: int) -> String:
	_attack_timer = current_weapon().cooldown
	hunger.spend(rules.hunger_cost_gather_strike)
	if node.component.current_hits() + 1 < hits_needed:
		node.component.register_hit(hits_needed)
		return ""
	last_drop = node.component.pending_yields()
	node.component.reset_hits()
	node.harvest()
	if not _has_tool(node.def.tool_item_id):
		_hurt_hands(node.def.hand_self_damage)
	_gather_timer = 0.0
	return ""


## Colheita de um toque (arbusto, pedra avulsa, carcaça): entrega direto no inventário, o que couber.
func _gather_by_touch(node: ResourceNode) -> String:
	var def := node.def
	var delivered := _deliver(node.component.pending_yields())
	if delivered.is_empty():
		return _refuse_gather(GATHER_FULL)  # nada coube: o nó fica como estava, sem custo
	var left := node.component.pending_yields()
	for item_id: String in delivered:
		left[item_id] = int(left[item_id]) - int(delivered[item_id])
		if left[item_id] <= 0:
			left.erase(item_id)
	var delivered_units := 0
	for item_id: String in delivered:
		delivered_units += int(delivered[item_id])
	if left.is_empty():
		node.harvest()
	else:
		node.component.leave(left)  # o que sobra fica no nó (sem esgotar)
	var with_tool := _has_tool(def.tool_item_id)
	if not with_tool and def.hand_damage_per_item:
		_hurt_hands(def.hand_self_damage * delivered_units)  # carcaça: 1 por item entregue, parcial ou não
	elif not with_tool and left.is_empty():
		_hurt_hands(def.hand_self_damage)  # o custo é por colheita COMPLETA, não por tentativa parcial
	_gather_timer = _gather_cost(def, delivered_units)
	hunger.spend(rules.hunger_cost_gather_strike)
	last_gather = delivered.duplicate()
	for item_id: String in delivered:
		gathered.emit(item_id, delivered[item_id])
	return ""


## Recarga da coleta: só a carcaça tem (GDD 5.9b: 3 s por carne, proporcional às unidades entregues). Nó de toque
## (arbusto, pedra avulsa, fibra) NÃO trava o próximo: o jogador colhe o vizinho na hora (decisão do dono, 08/11).
func _gather_cost(def: ResourceNodeDef, delivered_units: int) -> float:
	if not def.hand_damage_per_item:
		return 0.0
	return def.gather_seconds * float(delivered_units) / float(maxi(_total_units(def), 1))


func _total_units(def: ResourceNodeDef) -> int:
	var total := 0
	for amount: int in def.total_yields().values():
		total += amount
	return total


## Põe no inventário o que couber de `wanted` (item -> unidades), na ordem do dicionário, contando as vagas em
## conjunto (cada item que entra ocupa vaga para o próximo). Devolve só o que entrou.
func _deliver(wanted: Dictionary) -> Dictionary:
	var delivered: Dictionary = {}
	for item_id: String in wanted:
		var amount := mini(int(wanted[item_id]), inventory.room_for(item_id))
		if amount > 0:
			inventory.add(item_id, amount)
			delivered[item_id] = amount
	return delivered


## Motivo de o nó não poder ser colhido agora ("" = pode): alvo e esgotado. O espaço é decidido ao entregar
## (entrega o que couber); o alcance é da autoridade.
func _gather_refusal(node: ResourceNode) -> String:
	if node == null:
		return GATHER_NO_TARGET
	if not node.is_available():
		return GATHER_DEPLETED
	return ""


func _refuse_gather(reason: String) -> String:
	_last_refusal = reason
	gather_refused.emit(reason)
	return reason


## Renasce em `point` (GDD 12.4): vida e fome nas frações das regras, fôlego cheio, proteção por
## alguns segundos. O inventário, a barra e as vagas ficam como estavam (o corpo com os itens é
## SOB-02, M2). Só vale para quem está morto; devolve se renasceu.
func respawn_at(point: Vector2, respawn_rules: RespawnRules) -> bool:
	if not health.is_dead():
		return false
	position = point
	velocity = Vector2.ZERO
	health.revive(respawn_rules.health_ratio)
	hunger.set_ratio(respawn_rules.hunger_ratio)
	stamina.from_dict({"current": stamina.max_stamina, "is_exhausted": false})
	health.grant_protection(respawn_rules.protection_seconds)
	# `_in_range` fica: o detector devolve o que continuar sobreposto e o `area_exited` tira o resto.
	if target != null:
		target = null
		target_changed.emit(null)
	return true


## Arma em mãos: a do item equipado, ou o Soco com as mãos livres.
func current_weapon() -> WeaponDef:
	var weapon := Items.weapon_of(str(equipment.item_in(EquipmentLayout.WEAPON).get("id", "")))
	return weapon if weapon != null else unarmed


## Intenção "usar o atalho `slot`" (0 a 8): quem lê a tecla só pede, e a autoridade (`request_use_item`
## com o id do ator) valida e chama `perform_use_item`. Comida: o jogador SEMPRE a consome (come 1 e
## recupera fome), mesmo com uma criatura dormindo ao alcance (decisão do dono); não gasta se a fome está
## cheia; a criatura recebe comida só pela tela do inventário dela. Equipamento (atalho por `iid`):
## SELECIONA; apertar a tecla do que já está em mãos desequipa (mãos livres, Soco). Só arma troca o
## equipado; comer não mexe nele. Sem estoque, sem efeito.
## Retorna true se algo foi consumido ou trocado.
func request_use_item(slot: int) -> bool:
	if input_locked or health.is_dead() or authority == null:
		return false
	return authority.request_use_item(authority.id_of(self), slot) == Enums.ActionResult.OK


## Efeito do atalho (só a autoridade chama, com o ator vivo e `slot` válido).
func perform_use_item(slot: int) -> Enums.ActionResult:
	_last_refusal = ""
	var iid := hotbar.iid_at(slot)
	if iid != "":
		if _equip_timer > 0.0:
			return Enums.ActionResult.COOLDOWN
		return Enums.ActionResult.OK if _toggle_equipped(iid) else Enums.ActionResult.REFUSED
	if _eat_timer > 0.0:
		return Enums.ActionResult.COOLDOWN
	var item_id := hotbar.item_at(slot)
	var restore := rules.hunger_restore_of(item_id)
	var problem := _food_problem(item_id, restore)
	if problem != "":
		_last_refusal = problem
		return Enums.ActionResult.REFUSED
	if inventory.remove(item_id, 1) < 1:
		_last_refusal = "nothing_to_use"
		return Enums.ActionResult.REFUSED
	hunger.queue_food(restore)
	ate.emit(item_id)
	_eat_timer = rules.food_cooldown
	return Enums.ActionResult.OK


## Por que o item do atalho não vira comida agora ("" = pode comer): não é comida, ou a fome (contando a fila) já está cheia.
func _food_problem(item_id: String, restore: float) -> String:
	if restore <= 0.0:
		return "not_food" if Items.has(item_id) else "nothing_to_use"
	return "" if hunger.can_queue(restore) else "not_hungry"


## Item pelo `iid`, na grade ou em uma vaga de equipamento; `{}` se não existe.
func find_item(iid: String) -> Dictionary:
	var item := inventory.find_iid(iid)
	return item if not item.is_empty() else equipment.find_iid(iid)


## Pedido de equipar o item `iid` da grade (vaga "" = a do item): passa pela autoridade. Devolve "" se
## equipou ou o motivo da recusa (`EquipmentComponent.REFUSED_*`, "cooldown" ou "denied").
func request_equip(iid: String, slot_id: String = "") -> String:
	if authority == null:
		return DENIED
	_last_refusal = DENIED
	var result := authority.request_equip(authority.id_of(self), iid, slot_id)
	return "" if result == Enums.ActionResult.OK else _last_refusal


## Efeito de equipar ou desequipar (só a autoridade chama, e `_toggle_equipped`): `iid` vazio tira da vaga
## `slot_id` o que estiver nela; senão equipa o item `iid` (`slot_id` "" = a vaga do item). Recarga de 0,3 s.
## Devolve "" ou o motivo; recusa avisa por `equip_refused`, exceto a recarga, que é silenciosa.
func perform_equipment(iid: String, slot_id: String = "") -> String:
	var reason := COOLDOWN
	if _can_equip_now():
		reason = equipment.equip(iid, slot_id) if iid != "" else equipment.unequip(slot_id)
	reason = _after_equip_request(reason)
	if reason == "" and iid != "":
		_ensure_hotbar_slot(iid)
	_last_refusal = reason
	return reason


## O equipado precisa de atalho para ter o destaque na barra: sem atalho, vai ao primeiro livre
## (barra cheia: fica sem; o que já tem atalho não muda).
func _ensure_hotbar_slot(iid: String) -> void:
	var item := find_item(iid)
	if item.is_empty() or hotbar.slot_of_iid(iid) >= 0 or hotbar.first_free() < 0:
		return
	hotbar.assign_iid(hotbar.first_free(), iid, item["id"])


## Pedido de tirar o item da vaga para a grade (grade sem posição livre: recusa "full"), pela autoridade.
func request_unequip(slot_id: String) -> String:
	if authority == null:
		return DENIED
	_last_refusal = DENIED
	var result := authority.request_unequip(authority.id_of(self), slot_id)
	return "" if result == Enums.ActionResult.OK else _last_refusal


func _can_equip_now() -> bool:
	return not health.is_dead() and _equip_timer <= 0.0  # a tela trava o corpo (`input_locked`), mas é por ela que se equipa


func _after_equip_request(reason: String) -> String:
	if reason == "":
		_equip_timer = rules.equip_cooldown
	elif reason != COOLDOWN:
		equip_refused.emit(reason)
	return reason


## A tecla do atalho: o que está na vaga é tirado; o que está na grade é equipado (troca).
func _toggle_equipped(iid: String) -> bool:
	var item := find_item(iid)
	if item.is_empty() or Items.slot_of(item["id"]) != EquipmentLayout.WEAPON:
		return false
	var reason := perform_equipment("", EquipmentLayout.WEAPON) if equipment.has_iid(iid) else perform_equipment(iid)
	return reason == ""


func _on_equipment_changed() -> void:
	var now := equipped_iid
	if now != _last_equipped:
		_last_equipped = now
		equipped_changed.emit(now)


func _newest_iid(item_id: String) -> String:
	for i in range(inventory.slot_count() - 1, -1, -1):
		var slot := inventory.get_slot(i)
		if slot.get("id", "") == item_id and slot.has("iid"):
			return slot["iid"]
	return ""


func to_dict() -> Dictionary:
	var data := {
		"version": FORMAT_VERSION,
		"position": {"x": position.x, "y": position.y},
		"health": health.to_dict(),
		"stamina": stamina.to_dict(),
		"hunger": hunger.to_dict(),
		"inventory": inventory.to_dict(),
		"hotbar": hotbar.to_dict(),
		"equipment": equipment.to_dict(),
	}
	if health.protection_left > 0.0:  # só o jogador faz a proteção correr: só ele a salva
		data["protection"] = health.protection_left
	return data


## Chame depois de adicionar à árvore. Silencioso: não emite `died` nem `starved`.
##
## CONTRATO DO RETORNO (para o SAV-01): `true` = aplicado; `false` = RECUSADO e NADA mudou
## (posição, vida, fome, inventário, barra, vagas). O SaveManager deve tratar `false` como save
## inválido ou incompatível, nunca seguir com carga parcial. Carga em duas fases: primeiro valida
## sem aplicar; só depois toca em qualquer campo. Recusa: versão do jogador, do inventário, da barra
## ou das vagas inválida ou maior; bloco `inventory`, `hotbar` ou `equipment` que existe e não é
## dicionário, ou com `version` e sem `slots` (corrupção); `slots` que não é do tipo certo;
## inventário que não cabe; vagas inválidas; e a migração de formato antigo (inventário v1) cujo
## inventário está cheio demais para receber o equipamento inicial. Essa última recusa é PERMANENTE
## para o arquivo (só migração fora do jogo, ou o dono do arquivo, resolve): abrir espaço
## descartaria itens do jogador. `{}` é save parcial válido e não muda nada.
## Save parcial: sem `inventory` mantém inventário e barra; com `inventory` e sem `hotbar`, a barra
## é esvaziada (os `iid` antigos não valem). Vagas: com `equipment` valem as dele; sem `equipment`
## e com `inventory`, ficam vazias (o item equipado de um save antigo vem de `equipped`, que está na
## grade: MIGRAÇÃO, move para a vaga Arma se for arma); sem os dois, não mudam.
func from_dict(data: Dictionary) -> bool:
	if not _shape_is_valid(data):
		return false
	var saved_inventory := SafeRead.dict(data.get("inventory"))
	var saved_hotbar := SafeRead.dict(data.get("hotbar"))
	var saved_equipment := SafeRead.dict(data.get("equipment"))
	var replaces_inventory := saved_inventory.has("slots")
	var legacy := replaces_inventory and SafeRead.format_version(saved_inventory, InventoryComponent.FORMAT_VERSION) == 1
	var has_equipment := data.has("equipment")
	if not _load_is_valid(saved_inventory, saved_equipment, replaces_inventory, has_equipment, legacy):
		return false
	var saved_position := SafeRead.dict(data.get("position"))
	position = Vector2(
		SafeRead.number(saved_position.get("x"), position.x, -SafeRead.COORD_LIMIT, SafeRead.COORD_LIMIT),
		SafeRead.number(saved_position.get("y"), position.y, -SafeRead.COORD_LIMIT, SafeRead.COORD_LIMIT)
	)
	health.from_dict(SafeRead.dict(data.get("health")))
	health.protection_left = SafeRead.number(data.get("protection"), 0.0, 0.0, HealthComponent.MAX_PROTECTION)
	stamina.from_dict(SafeRead.dict(data.get("stamina")))
	hunger.from_dict(SafeRead.dict(data.get("hunger")))
	if replaces_inventory:
		inventory.from_dict(saved_inventory)
	if has_equipment:
		equipment.from_dict(saved_equipment)
	elif replaces_inventory:
		equipment.from_dict({"slots": {}})
	if not hotbar.from_dict(saved_hotbar) and replaces_inventory:
		hotbar.from_dict({"slots": []})
	# Migração: o item "em mãos" do save antigo está na grade; vai para a vaga Arma se for arma.
	if not has_equipment and data.has("equipped"):
		var migrated := SafeRead.text(data["equipped"], "")
		if equipment.equip(migrated, EquipmentLayout.WEAPON) == "":
			_ensure_hotbar_slot(migrated)
	if legacy:
		_grant_starting_equipment()
	return true


## Forma do save: versões conhecidas, blocos que são dicionários, `slots` da barra no tipo certo e
## vagas sempre junto do inventário (vagas sozinhas tirariam da vaga um item que a grade não recebe).
func _shape_is_valid(data: Dictionary) -> bool:
	if SafeRead.format_version(data, FORMAT_VERSION) == 0:
		return false
	for key in ["inventory", "hotbar", "equipment"]:
		if not SafeRead.block_valid(data, key):
			return false
	var saved_inventory := SafeRead.dict(data.get("inventory"))
	var saved_hotbar := SafeRead.dict(data.get("hotbar"))
	var saved_equipment := SafeRead.dict(data.get("equipment"))
	var versions_ok := SafeRead.format_version(saved_inventory, InventoryComponent.FORMAT_VERSION) != 0 \
			and SafeRead.format_version(saved_hotbar, HotbarComponent.FORMAT_VERSION) != 0 \
			and SafeRead.format_version(saved_equipment, EquipmentComponent.FORMAT_VERSION) != 0
	var hotbar_ok := not saved_hotbar.has("slots") or typeof(saved_hotbar["slots"]) == TYPE_ARRAY
	return versions_ok and hotbar_ok and (not data.has("equipment") or saved_inventory.has("slots"))


## Primeira fase: o inventário do save cabe, as vagas valem contra esse inventário e, no formato
## antigo, ainda sobra espaço para o equipamento inicial. Não muda nada.
func _load_is_valid(saved_inventory: Dictionary, saved_equipment: Dictionary, replaces_inventory: bool,
		has_equipment: bool, legacy: bool) -> bool:
	var scratch := inventory.preview()
	var ok := true
	if replaces_inventory:
		ok = scratch.from_dict(saved_inventory)
	else:
		ok = scratch.from_dict(inventory.to_dict())
	if ok and has_equipment:
		ok = equipment.can_load(saved_equipment, scratch)
	if ok and legacy:
		for item_id in initial_equipment():
			var owned := scratch.count(item_id) + (equipment.count(item_id) if not replaces_inventory else 0)
			if owned == 0 and scratch.add(item_id, 1) > 0:
				ok = false
	scratch.free()
	return ok


## Save de formato antigo: garante o equipamento inicial no inventário e na barra. O que já
## existe (na grade ou na vaga) não é duplicado. Sem espaço, o item não entra.
func _grant_starting_equipment() -> void:
	for item_id in initial_equipment():
		if inventory.count(item_id) + equipment.count(item_id) == 0:
			inventory.add(item_id, 1)
		var iid := _newest_iid(item_id)
		if iid != "" and hotbar.slot_of_iid(iid) < 0 and hotbar.first_free() >= 0:
			hotbar.assign_iid(hotbar.first_free(), iid, item_id)


## Caixa de colisão vinda dos dados (`PlayerRules.hitbox_size`), nunca da cena.
func _apply_hitbox() -> void:
	var shape := RectangleShape2D.new()
	shape.size = rules.hitbox_size
	$CollisionShape2D.shape = shape
	$CollisionShape2D.position = rules.hitbox_offset


func _on_area_entered(area: Area2D) -> void:
	if area is InteractableArea and not _in_range.has(area):
		_in_range.append(area)


func _on_area_exited(area: Area2D) -> void:
	_in_range.erase(area)
	if area == target:
		target = null
		target_changed.emit(null)
