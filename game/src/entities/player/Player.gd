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
## Dano de coleta por ferramenta e material (dado; decisão do dono, 08/11).
const GATHER_DAMAGE: GatherDamageTable = preload("res://data/balance/gather_damage.tres")
## Motivos de recusa de `request_gather`.
const GATHER_NO_TARGET := "no_target"
const GATHER_DEPLETED := "depleted"
const GATHER_FULL := "full"
## Nada coube porque passaria do Peso máximo (vale mesmo se os slots também estão cheios).
const GATHER_WEIGHT := "weight"
const GATHER_BLOCKED := "blocked"
const GATHER_TOO_FAR := "too_far"
## Tocou um nó que exige ferramenta sem ela: o toque machuca a mão e não coleta nada.
const GATHER_NEEDS_TOOL := "needs_tool"
## `skin_unit`: a unidade pedida já não está na carcaça (outro ator a levou); nada foi entregue.
const SKIN_NOTHING_LEFT := "nothing_left"
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
## Caído e corpo (M1, etapa 6): duração do desmaio, vida do caído, torpor e minutos do corpo.
@export var downed_rules: DownedRules = preload("res://data/balance/downed_rules.tres")
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
## O que um save de inventário maior não coube (entradas prontas): a carga o deixa aqui e quem tem o mundo
## (`WorldSnapshot.return_spilled`) o larga no chão, aos pés. Nunca é salvo: ou caiu no chão (que é salvo) ou a carga foi desfeita.
var migration_spill: Array[Dictionary] = []
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
var _last_equipped: String = ""
## Direção e corrida do quadro, guardadas por `perform_move` e consumidas pela física.
var _move_direction: Vector2 = Vector2.ZERO
var _move_sprint: bool = false
## Motivo da última recusa de uma regra (`perform_*`); "" quando o pedido valeu. Só devolve texto ao chamador.
var _last_refusal: String = ""
## Empurrão em curso (a autoridade o pede): o que falta andar, em pixels, e a velocidade. Para no primeiro obstáculo.
var _knock_left: Vector2 = Vector2.ZERO
var _knock_speed: float = 0.0

## Sprite: só a apresentação (`PlayerView`) escolhe o quadro.
@onready var visual: Sprite2D = $Visual
@onready var health: HealthComponent = $HealthComponent
@onready var stamina: StaminaComponent = $StaminaComponent
@onready var hunger: HungerComponent = $HungerComponent
@onready var inventory: InventoryComponent = $InventoryComponent
@onready var hotbar: HotbarComponent = $HotbarComponent
@onready var equipment: EquipmentComponent = $EquipmentComponent
@onready var downed: DownedComponent = $DownedComponent
## Nível, XP e Saber (E6). Quem concede o XP é a autoridade; o jogador só guarda.
@onready var progression: ProgressionComponent = $ProgressionComponent
@onready var detector: Area2D = $InteractionDetector


func _ready() -> void:
	_apply_hitbox()
	inventory.capacity = Items.slots.player_slots  # slots (GDD 5.21) e cinto: valem antes de qualquer `add` abaixo
	inventory.belt_size = Items.slots.belt_slots
	inventory.weight_limit = Items.CARRY.capacity_kg  # Peso (GDD 5.1)
	inventory.worn = equipment  # o que está nas vagas de equipamento pesa, mesmo fora dos slots
	hunger.decay_per_second = rules.hunger_decay_idle
	hunger.recovery_per_second = rules.hunger_recovery_per_second
	downed.rules = downed_rules
	stamina.rules = rules
	health.died.connect(_on_health_zeroed)
	detector.area_entered.connect(_on_area_entered)
	detector.area_exited.connect(_on_area_exited)
	# O save é restaurado depois do _ready (from_dict exige o nó na árvore) e sobrescreve isto.
	for item_id: Variant in starting_items:
		if item_id is String:
			inventory.add(item_id, int(starting_items[item_id]))
			hotbar.assign(hotbar.first_free(), item_id)
	for item_id in initial_equipment():
		if inventory.add(item_id, 1) == 0:
			hotbar.assign_iid(hotbar.first_free(), newest_iid(item_id), item_id)
	equipment.changed.connect(_on_equipment_changed)


## Equipamento com que o jogador nasce: o do jogo normal mais, em desenvolvimento, os itens de teste (Lança, Bastão).
func initial_equipment() -> Array[String]:
	var ids: Array[String] = starting_equipment.duplicate()
	if dev_items:
		ids.append_array(rules.dev_starting_equipment)
	return ids


func _physics_process(delta: float) -> void:
	tick(delta)
	step_knockback(delta)
	# O pedido de movimento vale por um quadro: sem pedido novo (controlador ausente, pedido negado), para.
	velocity = apply_input(_move_direction, _move_sprint, delta)
	_move_direction = Vector2.ZERO
	_move_sprint = false
	update_dino_collision()
	move_and_slide()


## Empurrão de `offset` pixels em `seconds` (só a autoridade chama; quem já caiu não é empurrado). Substitui o anterior.
func knock_back(offset: Vector2, seconds: float) -> void:
	if is_incapacitated() or seconds <= 0.0:
		return
	_knock_left = offset
	_knock_speed = offset.length() / seconds


## Anda o empurrão deste quadro; encostou em obstáculo, o que falta se perde. Público para testar sem quadros.
func step_knockback(delta: float) -> void:
	if _knock_left == Vector2.ZERO:
		return
	var step := _knock_left.limit_length(_knock_speed * delta)
	collision_mask = 1  # o empurrão sai de cima de quem bateu: só o terreno o barra (dinos não)
	var blocked := move_and_collide(step) != null
	collision_mask = 1 | Dino.BODY_LAYER
	if blocked or step.length_squared() >= _knock_left.length_squared():
		_knock_left = Vector2.ZERO
	else:
		_knock_left -= step


## Quanto do empurrão ainda falta andar (zero = parado). Para teste e diagnóstico.
func knockback_left() -> Vector2:
	return _knock_left


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
	health.tick(delta)
	if not health.is_dead(): downed.tick(delta, hunger.is_starving())
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
	if is_incapacitated():
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
	if area.entity is GroundItem or area.entity is PlayerCorpse:
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
	if input_locked or is_incapacitated() or authority == null:
		return false
	var direction := point - global_position
	if direction.length() > 1.0:
		authority.request_face(authority.id_of(self), direction.normalized())
	mouse_point = point
	mouse_aim_active = true
	var creature_under := authority.entity_at(point, true)  # a criatura sob o cursor sempre tem prioridade
	var under := authority.entity_at(point)
	var node := under as ResourceNode
	if node != null and node.def.is_struck() and _mouse_pick(_dino_candidates()) == null:
		return _strike_target(node)  # o cursor está numa árvore ou rocha e não numa criatura
	if creature_under == null and under != null:
		return _click_use(under)  # moita, nó de coleta direta ou item no chão: o mesmo pedido do E (sem golpe no vazio)
	var wild := creature_under as Dino
	if wild != null and not wild.state_machine.is_tamed and not wild.health.is_dead() and _update_attack_target() == null:
		# Nada ao alcance, mas há uma criatura sob o cursor: o pedido vai e a autoridade explica a recusa (fora de alcance).
		return authority.request_attack(authority.id_of(self), authority.id_of(wild)) == Enums.ActionResult.OK
	return _strike_target()


## Clique num alvo que não se golpeia (e o E): recolhe item, recupera corpo ou interage, pelos pedidos da autoridade.
func _click_use(under: Node2D) -> bool:
	var actor_id := authority.id_of(self)
	var target_id := authority.id_of(under)
	if under is GroundItem:
		return authority.request_pickup(actor_id, target_id) == Enums.ActionResult.OK
	if under is PlayerCorpse:
		return authority.request_recover_corpse(actor_id, target_id) == Enums.ActionResult.OK
	return authority.request_interact(actor_id, target_id) == Enums.ActionResult.OK


## Executa uma opção do menu do mouse (`WorldAuthority.interaction_options`) sobre a entidade `target_id`.
func run_option(option_id: String, target_id: int) -> bool:
	if input_locked or is_incapacitated() or authority == null:
		return false
	var actor_id := authority.id_of(self)
	match option_id:
		"interact", "inventory":
			return authority.request_interact(actor_id, target_id) == Enums.ActionResult.OK
		"recover":
			return authority.request_recover_corpse(actor_id, target_id) == Enums.ActionResult.OK
		"follow", "stay":
			return authority.request_command(actor_id, target_id, option_id.to_upper()) == Enums.ActionResult.OK
		"attack":
			var target := authority.entity(target_id) as Node2D
			return target != null and attack_at(target.global_position)
	return false


## Intenção "interagir com o alvo": pede à autoridade. Retorna true se aceitou (`interaction_granted` avisa quem abre tela).
func try_interact() -> bool:
	if input_locked or is_incapacitated() or target == null or authority == null:
		return false
	# O E nunca dá ordem a dino (decisão do dono, 08/11): as ordens saem do menu e da tecla G.
	return _click_use(target.entity)


## O alvo do E é um domado meu? (a tecla abre o menu em vez de interagir)
func target_is_own_tamed() -> bool:
	var dino := target.entity as Dino if target != null else null
	return dino != null and dino.can_command() and dino.owner_player_id == player_id


## Tecla G: alterna Seguir/Ficar do domado meu mais perto, ao alcance. Retorna true se a autoridade aceitou.
func toggle_nearest_order() -> bool:
	if input_locked or is_incapacitated() or authority == null:
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
	if input_locked or is_incapacitated() or authority == null:
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
	_wear_held_weapon()  # cada golpe aceito gasta 1 de durabilidade
	attacked.emit()
	return true


## Gasta 1 de durabilidade da arma em mãos; se ela quebra, sai do atalho e avisa (`weapon_broke`).
func _wear_held_weapon() -> void:
	var held_iid := equipment.iid_in(EquipmentLayout.WEAPON)
	var broken := equipment.wear(EquipmentLayout.WEAPON, 1)
	if broken != "":
		var slot := hotbar.slot_of_iid(held_iid)
		if slot >= 0:
			hotbar.clear(slot)
		weapon_broke.emit(broken)


## Dano que o jogador causa a si mesmo com as mãos (Soco em dino, colheita de árvore e de carcaça, toque em
## pedra). NUNCA leva a vida abaixo de `rules.hand_damage_floor`: o Soco não mata (sem morte boba nem softlock).
func _hurt_hands(amount: float) -> void:
	health.take_damage_down_to(amount, rules.hand_damage_floor)


## Motivo da última recusa de uma regra do jogador ("" = nenhuma).
func last_refusal() -> String:
	return _last_refusal


## Dano de coleta por golpe do que está em mãos (ou da mão) contra o material do nó, pela tabela de dados.
## O atributo Dano do jogador NÃO multiplica a coleta (decisão: só a ferramenta e o material contam, por ora).
func gather_damage_on(def: ResourceNodeDef) -> float:
	return GATHER_DAMAGE.damage(def.material_id, str(equipment.item_in(EquipmentLayout.WEAPON).get("id", "")))


## Esta coleta CONCLUIRIA o nó (a que o intervalo de coleta barra)? Toque: sempre. Golpe: só o que zera a vida;
## golpe intermediário e golpe sem dano nunca concluem.
func would_complete_gather(node: ResourceNode) -> bool:
	if node == null or node.def == null:
		return false
	if not node.def.is_struck():
		return true
	var damage := gather_damage_on(node.def)
	return damage > 0.0 and node.component.current_health() - damage <= 0.0


## Segundos até poder concluir outra coleta (a autoridade guarda o instante; 0 = já pode).
func gather_interval_left() -> float:
	return authority.gather_wait_left(authority.id_of(self)) if authority != null else 0.0


## A coleta concluiria agora mas o intervalo ainda não passou? (a HUD pinta a dica de cinza)
func gather_blocked_now(node: ResourceNode) -> bool:
	return node != null and gather_interval_left() > 0.0 and would_complete_gather(node)


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
	if node.def.is_struck():
		return _strike_resource(node)
	return _gather_by_touch(node)


## Antes de colher: recarga, alvo válido e a ferramenta. "" = pode colher. Nó de golpes sem dano (a mão na rocha)
## machuca a mão, não tira vida e devolve `GATHER_NEEDS_TOOL`; nó de toque que EXIGE ferramenta faz o mesmo.
func _gather_gate(node: ResourceNode) -> String:
	var struck := node != null and node.def != null and node.def.is_struck()
	# Colher por golpes usa a recarga do golpe da arma em mãos; a colheita de um toque, a própria.
	if (struck and not can_strike()) or (not struck and _gather_timer > 0.0):
		_last_refusal = COOLDOWN
		return COOLDOWN
	var reason := _gather_refusal(node)
	if reason != "":
		return _refuse_gather(reason)
	var needs_tool := gather_damage_on(node.def) <= 0.0 if struck else node.def.tool_required and not _has_tool(node.def.tool_item_id)
	if needs_tool:
		# A ferramenta vem antes do espaço: a pedra sem Picareta machuca a mão mesmo com o inventário cheio.
		_hurt_hands(node.def.touch_self_damage)
		_gather_timer = node.def.touch_seconds
		if struck:
			_attack_timer = current_weapon().cooldown  # o mesmo ritmo do golpe: clicar sem parar não machuca sem parar
		node.component.rebuff()
		return _refuse_gather(GATHER_NEEDS_TOOL)
	return ""


## Um golpe num nó de vida (árvore, rocha, minério): tira o dano da ferramenta contra o material. Os que não zeram só
## tiram vida; o que zera derruba o nó e o recurso vai ao CHÃO (`last_drop`: a autoridade o espalha), nunca direto ao
## inventário. Sem ferramenta, o golpe final custa a vida da mão uma vez (não por golpe).
func _strike_resource(node: ResourceNode) -> String:
	_attack_timer = current_weapon().cooldown
	hunger.spend(rules.hunger_cost_gather_strike)
	var damage := gather_damage_on(node.def)
	var by_hand := not _has_tool(node.def.tool_item_id)
	if node.component.current_health() - damage > 0.0:
		node.component.register_damage(damage, by_hand)
		return ""
	last_drop = node.component.pending_yields()
	node.component.register_damage(damage, by_hand)
	node.harvest()
	if by_hand:
		_hurt_hands(node.def.hand_self_damage)
	_gather_timer = 0.0
	return ""


## Colheita de um toque (arbusto, pedra avulsa; a carcaça é `skin_unit`): entrega direto no inventário, o que couber.
func _gather_by_touch(node: ResourceNode) -> String:
	var def := node.def
	var wanted := node.component.pending_yields()
	var delivered := _deliver(wanted)
	if delivered.is_empty():
		return _refuse_gather(_full_reason(wanted))  # nada coube: o nó fica como estava, sem custo
	var left := node.component.pending_yields()
	for item_id: String in delivered:
		left[item_id] = int(left[item_id]) - int(delivered[item_id])
		if left[item_id] <= 0:
			left.erase(item_id)
	if left.is_empty():
		node.harvest()
	else:
		node.component.leave(left)  # o que sobra fica no nó (sem esgotar)
	if not _has_tool(def.tool_item_id) and left.is_empty():
		_hurt_hands(def.hand_self_damage)  # o custo é por colheita COMPLETA, não por tentativa parcial
	hunger.spend(rules.hunger_cost_gather_strike)
	last_gather = delivered.duplicate()
	for item_id: String in delivered:
		gathered.emit(item_id, delivered[item_id])
	return ""


## Esfolar é por tempo (E10): o `CarcassService` pede UMA unidade por vez. Qual item vem a seguir: o primeiro, na ordem do
## nó (carne, depois couro), que ainda cabe no Peso e nos slots. "" = nada do que resta cabe.
func next_skin_item(node: ResourceNode) -> String:
	var pending := node.component.pending_yields()
	for item_id: String in node.def.total_yields():
		if int(pending.get(item_id, 0)) > 0 and inventory.room_for(item_id) >= 1:
			return item_id
	return ""


## Por que nada do que resta na carcaça cabe: `GATHER_WEIGHT` (o Peso vem primeiro) ou `GATHER_FULL`.
func skin_refusal(node: ResourceNode) -> String:
	return _full_reason(node.component.pending_yields())


## Segundos para esfolar uma unidade de `item_id` agora: o tempo à mão do dado vezes o fator da lâmina em mãos.
func skin_seconds(node: ResourceNode, item_id: String) -> float:
	return float(node.def.item_seconds.get(item_id, node.def.gather_seconds)) * current_weapon().skin_seconds_factor


## Entrega UMA unidade de `item_id` da carcaça. Sem lâmina, a mão perde `hand_self_damage` por item entregue; com a Lança
## ela gasta 1 de durabilidade quando a carcaça se esvazia (GDD 5.6: por carcaça, não por item). "" = entregou.
func skin_unit(node: ResourceNode, item_id: String) -> String:
	var left := node.component.pending_yields()
	if int(left.get(item_id, 0)) < 1:
		return SKIN_NOTHING_LEFT  # outro ator esfolou esta unidade antes: não entrega nada (sem duplicar)
	if inventory.room_for(item_id) < 1:
		return _full_reason({item_id: 1})
	inventory.add(item_id, 1)
	left[item_id] = int(left[item_id]) - 1
	if int(left[item_id]) <= 0:
		left.erase(item_id)
	if left.is_empty():
		node.harvest()
	else:
		node.component.leave(left)
	if current_weapon().cuts_carcass:
		if left.is_empty():
			_wear_held_weapon()
	else:
		_hurt_hands(node.def.hand_self_damage)
	last_gather = {item_id: 1}
	gathered.emit(item_id, 1)
	return ""


## Por que nada do que o nó dá coube: o Peso (se algum item passaria do limite) ou os slots.
func _full_reason(wanted: Dictionary) -> String:
	for item_id: String in wanted:
		if inventory.refusal_for(item_id) == "weight_limit":
			return GATHER_WEIGHT
	return GATHER_FULL


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


func _on_health_zeroed() -> void:
	if authority == null: perform_death()  # sem autoridade, vida 0 é morte


## Morto ou caído: não age. Só a autoridade muda isto.
func is_incapacitated() -> bool:
	return health.is_dead() or downed.is_downed


## Cai (só a autoridade chama): `from_health` = vida 0 de pé vira a vida do caído; o torpor por fome mantém a vida.
func perform_down(from_health: bool) -> void:
	if health.is_dead() and from_health: health.revive(downed_rules.downed_health / health.max_health)
	downed.enter()
	health.cancel_regen()  # a cura da carne assada não continua com o jogador caído
	_stop_acting()


## Acorda (só a autoridade chama): vida mínima `wake_min_health`, torpor `wake_torpor`, graça sem dano.
func perform_wake() -> void:
	downed.wake()
	health.heal(maxf(downed_rules.wake_min_health - health.current_health, 0.0))
	health.grant_protection(downed_rules.wake_grace_seconds)


## Morre de vez (só a autoridade chama): o que digeria se perde e o desmaio acaba.
func perform_death() -> void:
	downed.clear()
	hunger.clear_pending()
	health.cancel_regen()  # a cura da comida não atravessa a morte
	_stop_acting()


func _stop_acting() -> void:
	_move_direction = Vector2.ZERO
	_move_sprint = false
	_knock_left = Vector2.ZERO
	velocity = Vector2.ZERO
	if attack_target != null:
		attack_target = null
		attack_target_changed.emit(null)


## Renasce em `point` (GDD 12.4): vida e fome nas frações das regras, torpor zerado, fôlego cheio, proteção por
## alguns segundos. Os itens ficaram no corpo. Só vale para quem está morto; devolve se renasceu.
func respawn_at(point: Vector2, respawn_rules: RespawnRules) -> bool:
	if not health.is_dead():
		return false
	position = point
	velocity = Vector2.ZERO
	health.revive(respawn_rules.health_ratio)
	hunger.set_ratio(respawn_rules.hunger_ratio)
	downed.clear()
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
	if input_locked or is_incapacitated() or authority == null:
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
	health.start_regen(rules.food_regen_of(item_id), rules.food_regen_seconds)  # a assada cura (a crua e a baga: 0, não mexe)
	ate.emit(item_id)
	_eat_timer = rules.food_cooldown
	return Enums.ActionResult.OK


## Por que o item do atalho não vira comida agora ("" = pode comer): não é comida, ou a fome (contando a fila) já está cheia.
func _food_problem(item_id: String, restore: float) -> String:
	if restore <= 0.0:
		return "not_food" if Items.has(item_id) else "nothing_to_use"
	return "" if hunger.can_queue(restore) else "not_hungry"


## A grade passa a ter o tamanho que a bolsa da vaga dá (sem bolsa, só os slots base). Quem esvazia as vagas por fora (o corpo
## ao morrer, a carga do save) chama depois de mexer. Devolve quantas pilhas faltam esvaziar (0 = ajustou).
func fit_grid_to_bag() -> int:
	return inventory.resize_grid(equipment.grid_size())


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
		ensure_hotbar_slot(iid)
	_last_refusal = reason
	return reason


## O equipado precisa de atalho para ter o destaque na barra: sem atalho, vai ao primeiro livre
## (barra cheia: fica sem; o que já tem atalho não muda).
func ensure_hotbar_slot(iid: String) -> void:
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
	return not is_incapacitated() and _equip_timer <= 0.0  # a tela trava o corpo (`input_locked`), mas é por ela que se equipa


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


func newest_iid(item_id: String) -> String:
	for i in range(inventory.slot_count() - 1, -1, -1):
		var slot := inventory.get_slot(i)
		if slot.get("id", "") == item_id and slot.has("iid"):
			return slot["iid"]
	return ""


func to_dict() -> Dictionary:
	return PlayerSave.capture(self)


## Chame depois de adicionar à árvore. Silencioso: carregar não é evento de jogo. Devolve `true` se aplicou e `false`
## se RECUSOU sem mudar nada (o contrato completo, a carga em duas fases e as migrações estão em `PlayerSave.apply_saved_state`).
func from_dict(data: Dictionary) -> bool:
	return PlayerSave.apply_saved_state(self, data)


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
