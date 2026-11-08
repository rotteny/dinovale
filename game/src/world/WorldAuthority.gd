# gdlint: ignore=max-public-methods
# SPDX-License-Identifier: MIT
class_name WorldAuthority
extends Node
## Autoridade do mundo (ADR-001): ponto de passagem de todo ato do jogador que muda o mundo. O cliente
## manda intenção (`request_*`) com ids de entidade; aqui se valida e se delega às regras que continuam
## nas entidades e nos componentes. No single-player é o host local, pelo mesmo caminho.
##
## Contrato de cada `request_*`: assinatura só com `int`, `String`, `float`, `bool` ou `Vector2`, nunca
## nó. Ordem da validação: ator existe e está vivo, argumentos válidos, alvo existe (por id), alcance
## pela distância real, regra de domínio (recarga, posse, estado). Negada: NADA muda, devolve o
## `Enums.ActionResult` e emite `action_denied`. O retorno serve a teste e log; a UI não atualiza estado por ele.
##
## Os ids vêm do registro (`register`): o jogador e a criatura da cena têm os ids do save
## (`WorldSnapshot`), e o resto recebe o próximo livre. Nó que morreu deixa de ser resolvido.

## Um pedido foi negado; nada mudou.
signal action_denied(actor_id: int, action: String, result: Enums.ActionResult)
## O alvo aceitou a interação; quem abre a tela ou colhe é o mundo (`Main`).
signal interaction_granted(actor_id: int, target_id: int)
## Algo que o jogador precisa saber aconteceu (log da HUD). `code` é estável (ver `GameMessages.EVENTS`); a UI traduz.
## Toda recusa vira `action_refused` com `reason` (`GameMessages.REASONS`) e `action`.
signal game_event(code: String, params: Dictionary)
## Um item deve aparecer no chão (colheita por golpes derrubou, ou o jogador largou). Quem desenha o chão escuta.
signal items_dropped(item_id: String, amount: int, at: Vector2, dropper_id: String)

const ACTION_ATTACK := "attack"
const ACTION_INTERACT := "interact"
const ACTION_TRANSFER := "transfer_slot"
const ACTION_COMMAND := "command_dino"
const ACTION_USE_ITEM := "use_item"
const ACTION_EQUIP := "equip"
const ACTION_UNEQUIP := "unequip"
const ACTION_GATHER := "gather"
## Motivo da recusa por intervalo entre coletas: sem mensagem no log (o indicador é visual).
const REASON_GATHER_INTERVAL := "gather_interval"
const ACTION_FACE := "face"
const ACTION_PICKUP := "pickup"
const ACTION_DROP := "drop"
## Quantidade de `request_transfer_slot` que significa "a pilha toda".
const TRANSFER_ALL := -1
## Tamanho máximo de `iid` e de nome de vaga aceitos (dado vindo de fora não é confiável).
const ACTION_MOVE := "move"

## Folga no comprimento da direção (ponto flutuante; `get_vector` entrega até 1).
const MOVE_LENGTH_TOLERANCE := 0.001
const MAX_ID_LENGTH := 32
## Nome da ordem mais longo aceito (`Enums.DinoOrder`): corta lixo antes de procurar o nome.
const MAX_ORDER_NAME := 16

@export var rules: ActionRules = preload("res://data/balance/action_rules.tres")

## Itens soltos no chão (opcional: um teste sem chão não os tem). A `Main` o liga; a colheita por golpes e o largar o usam.
## Itens soltos: a `Main` liga `items_dropped` ao campo de chão (`GroundItemField`) e marca `drops_enabled`. A autoridade
## não conhece o campo (evita laço de referência entre scripts, que vaza ao sair).
var drops_enabled: bool = false

## Relógio do mundo (ADR-006). Só esta autoridade o avança, em `_physics_process`; os sistemas recebem `clock.now`.
var clock := WorldClock.new()
## Semente do mundo (a `Main` define): entra no sorteio do intervalo entre coletas.
var world_seed: int = 0

## Aliados do dono de uma criatura, para o dano em área: `Callable(owner_player_id, other_player_id) -> bool`.
## Sem ele, ninguém é aliado.
var ally_check: Callable = Callable()
## PvP do mundo (`ServerRules.pvp`, injetado pelo host): golpe em área acerta domados de OUTRO jogador. A autoridade não lê arquivo.
var pvp_enabled: bool = false

## Chamada do bando (`HerdCall`): a autoridade a alimenta quando um selvagem é golpeado e a avança a cada quadro.
var herd := HerdCall.new()

var _entities: Dictionary = {}
## Por jogador: instante (relógio do mundo) em que pode concluir outra coleta, e quantas já concluiu. Não vão ao save.
var _gather_ready_at: Dictionary = {}
var _gather_count: Dictionary = {}
## Motivo e parâmetros específicos da recusa em andamento (senão vale o padrão do resultado). `_answer` os consome.
var _reason: String = ""
var _reason_params: Dictionary = {}
var _next_id: int = 1
## Último episódio de agressão anunciado por criatura (`entity_id` -> episódio): `dino_hit_player` sai uma vez por episódio.
var _announced_episode: Dictionary = {}
## Último golpe aceito por criatura (`entity_id` -> `ThreatCycle.strike_count`): um golpe do ciclo vale um pedido só.
var _last_strike: Dictionary = {}


func _physics_process(delta: float) -> void:
	clock.advance(delta)
	tick_herd(delta)


## Passo do bando (público e testável sem quadros): os ajudantes escalados entram quando o atraso acaba.
func tick_herd(delta: float) -> void:
	herd.tick(delta)


## Registra `node` no mundo. `entity_id` 0 = o próximo livre. Devolve o id usado, ou 0 se o id pedido já
## é de outro nó. Criatura registrada passa a achar o dono por este registro (`Dino.player_locator`).
func register(node: Node, entity_id: int = 0) -> int:
	if node == null:
		return 0
	var used := entity_id if entity_id > 0 else _next_id
	var holder := entity(used)
	if holder != null and holder != node:
		return 0  # só acontece com id pedido: o próximo livre nunca está em uso
	_entities[used] = node
	_next_id = maxi(_next_id, used + 1)
	if node is Dino:
		(node as Dino).player_locator = player_body
	if node is Dino or node is Player:
		if node.is_node_ready():
			_watch(node)
		else:
			node.ready.connect(_watch.bind(node), CONNECT_ONE_SHOT)
	return used


## Liga os avisos de jogo à morte e à domesticação (os componentes só emitem; quem anuncia é a autoridade).
func _watch(node: Node) -> void:
	var dino := node as Dino
	if dino != null:
		dino.health.died.connect(func() -> void:
			announce("dino_killed", {"species": dino.stats.display_name}))
		dino.taming.level_finalized.connect(func(_level: int) -> void:
			announce("tame_done", {"species": dino.stats.display_name}))
		dino.taming.food_consumed.connect(func(food: String) -> void:
			announce("taming_meal", {"species": dino.stats.display_name, "item": Items.display_name(food),
					"done": dino.taming.meals_eaten(), "total": dino.taming.meals_required()}))
		dino.taming.taming_reset.connect(func() -> void:
			announce("taming_lost", {"species": dino.stats.display_name}))
		dino.state_machine.got_stuck.connect(func() -> void:
			announce("tamed_stuck", {"species": dino.stats.display_name}))
		dino.provoked.connect(func(attacker_id: String) -> void: _on_dino_provoked(dino, attacker_id))
		dino.attack_requested.connect(func(target: Node2D, damage: float, episode: int) -> void:
			_on_dino_attack(dino, target, damage, episode))
	elif node is Player:
		(node as Player).health.died.connect(func() -> void: announce("player_downed"))
		(node as Player).weapon_broke.connect(func(item_id: String) -> void: announce("weapon_broke", {"item": Items.display_name(item_id)}))


## Emite um evento de jogo (também usado pelo host para o que a autoridade não observa).
func announce(code: String, params: Dictionary = {}) -> void:
	game_event.emit(code, params)


## Próximo `entity_id` livre (vai no save: o contador nunca recua nem reutiliza id).
func next_entity_id() -> int:
	return _next_id


## Garante que o próximo id livre não seja menor que `minimum` (ao carregar um save).
func ensure_next_id(minimum: int) -> void:
	_next_id = maxi(_next_id, minimum)


## Corpo do jogador com esse `player_id` no mundo (ou null se não está).
func player_body(player_id: String) -> Node:
	for node: Variant in _entities.values():
		if not is_instance_valid(node):
			continue
		var candidate := node as Player
		if candidate != null and candidate.player_id == player_id and not candidate.is_queued_for_deletion():
			return candidate
	return null


## `player_id` do jogador registrado como `entity_id` ("" se não for jogador).
func player_id_of(entity_id: int) -> String:
	var candidate := entity(entity_id) as Player
	return candidate.player_id if candidate != null else ""


func unregister(entity_id: int) -> void:
	_entities.erase(entity_id)
	_announced_episode.erase(entity_id)
	_last_strike.erase(entity_id)


## Nó vivo do `entity_id`, ou null (id desconhecido, nó liberado ou já saindo do mundo).
func entity(entity_id: int) -> Node:
	var node: Variant = _entities.get(entity_id)
	if node == null or not is_instance_valid(node) or (node as Node).is_queued_for_deletion():
		return null
	return node as Node


## O `entity_id` está registrado (mesmo que o nó já tenha saído)? Serve para provar `unregister`.
func is_registered(entity_id: int) -> bool:
	return _entities.has(entity_id)


## `entity_id` registrado do nó, ou 0.
func id_of(node: Node) -> int:
	if node == null:
		return 0
	for entity_id: int in _entities:
		if _entities[entity_id] == node:
			return entity_id
	return 0


## Golpe da arma em mãos de `actor_id` na criatura `target_id` (dano e torpor vêm da arma).
func request_attack(actor_id: int, target_id: int) -> Enums.ActionResult:
	var actor := _live_player(actor_id)
	var dino := entity(target_id) as Dino
	var problem := _actor_problem(actor_id, actor)
	if problem == Enums.ActionResult.OK:
		problem = _attack_problem(actor, dino)
	if problem == Enums.ActionResult.OK and not actor.strike(dino):
		problem = Enums.ActionResult.REFUSED
	return _answer(actor_id, ACTION_ATTACK, problem)


## Golpe em área de uma criatura (não é intenção de jogador: quem chama é o servidor, quando a IA ataca).
## `attacker_id` precisa ter `area_rules()` (porte Grande com dado). O alvo principal leva o golpe inteiro; os
## secundários, a fração de `AreaAttackRules.fraction` do dano e do torpor, até `max_extra_targets`, os mais
## próximos do principal (empate: id menor). Nunca acerta o dono, os aliados dele nem domados (os de terceiros só com
## `pvp_enabled`, chave de servidor `pvp`, padrão falso); selvagem só acerta jogador; quem está
## sendo domado ou já caiu só leva se for o principal. Devolve `{entity_id: fração}` dos atingidos (vazio se o principal não foi acertado).
func resolve_area_attack(attacker_id: int, target_id: int, damage: float, torpor_amount: float) -> Dictionary:
	var attacker := entity(attacker_id) as Dino
	var main_target := entity(target_id) as Node2D
	var hits: Dictionary = {}
	if attacker == null or main_target == null or main_target == attacker or damage < 0.0 or torpor_amount < 0.0:
		return hits
	var area := attacker.stats.area_rules()
	if area == null or attacker.health.is_dead() or attacker.state_machine.current_id == Enums.DinoStateId.UNCONSCIOUS:
		return hits
	if not _area_hit(attacker, main_target, damage, torpor_amount, 1.0):
		return hits
	hits[target_id] = 1.0
	var tile := float(attacker.level_rules.tile_size)
	var extras: Array = []
	for candidate_id: int in _entities:
		var node := entity(candidate_id) as Node2D
		if node == null or node == attacker or node == main_target or not _area_candidate(attacker, node):
			continue
		var fraction := area.fraction(node.global_position.distance_to(main_target.global_position) / tile)
		if fraction > 0.0:
			extras.append({"id": candidate_id, "fraction": fraction, "distance": node.global_position.distance_to(main_target.global_position)})
	extras.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["distance"] < b["distance"] or (a["distance"] == b["distance"] and a["id"] < b["id"]))
	for extra: Dictionary in extras.slice(0, area.max_extra_targets):
		var node := entity(extra["id"]) as Node2D
		if _area_hit(attacker, node, damage, torpor_amount, extra["fraction"]):
			hits[extra["id"]] = extra["fraction"]
	return hits


## Golpe de uma criatura selvagem ou domada no alvo `target_id`, de um só alvo. Porte Grande com `area_attack` vai pelo
## golpe em área (`resolve_area_attack`, sem torpor); os demais acertam só o principal, pelas MESMAS regras de quem pode
## ser acertado (dono e aliados nunca; dino domado de outro dono só com `pvp_enabled`). Devolve `{entity_id: fração}`.
func resolve_dino_attack(attacker_id: int, target_id: int, damage: float) -> Dictionary:
	var attacker := entity(attacker_id) as Dino
	var target := entity(target_id) as Node2D
	if attacker == null or target == null or target == attacker or damage < 0.0:
		return {}
	if attacker.stats.area_rules() != null:
		return resolve_area_attack(attacker_id, target_id, damage, 0.0)
	if attacker.health.is_dead() or attacker.state_machine.current_id == Enums.DinoStateId.UNCONSCIOUS:
		return {}
	return {target_id: 1.0} if _area_hit(attacker, target, damage, 0.0, 1.0) else {}


## Um selvagem foi golpeado e está bravo: o bando dele é chamado contra o mesmo atacante.
func _on_dino_provoked(dino: Dino, attacker_id: String) -> void:
	var attacker := player_body(attacker_id) as Node2D
	if attacker == null:
		return
	var others: Array[Dino] = []
	for id: Variant in _entities:
		var other := entity(int(id)) as Dino  # `entity` pula nó liberado (o cast direto de um liberado é erro de script)
		if other != null:
			others.append(other)
	herd.raise_call(dino, attacker_id, attacker.global_position, others)


## O bravo pediu um golpe (`Dino.attack_requested`): confere o alcance contra a posição REAL dos dois, aplica o dano e
## anuncia o primeiro golpe que acertou de cada episódio. Recusa: sem perfil na espécie, dano acima do da espécie
## (`base_damage`), dino que não está bravo, fora da fase de golpe, golpe do ciclo já atendido (a recarga) ou fora do alcance.
func _on_dino_attack(dino: Dino, target: Node2D, damage: float, episode: int) -> void:
	var profile := dino.stats.threat_profile
	var attacker_id := id_of(dino)
	var target_id := id_of(target)
	if profile == null or attacker_id == 0 or target_id == 0 or damage > dino.stats.base_damage:
		return
	var cycle := dino.state_machine.threat_cycle
	if cycle == null or not dino.state_machine.is_aggressive or cycle.phase != Enums.ThreatPhase.LUNGE \
			or cycle.cooldown_left < profile.cooldown_s - 0.001 or _last_strike.get(attacker_id, -1) == cycle.strike_count:
		return
	if dino.global_position.distance_to(target.global_position) > profile.attack_reach_px + profile.reach_slack_px:
		return
	_last_strike[attacker_id] = cycle.strike_count
	var hits := resolve_dino_attack(attacker_id, target_id, damage)
	_knock_back(dino, target, profile, hits.has(target_id))
	if hits.has(target_id):
		dino.state_machine.confirm_hit()
	if hits.has(target_id) and target is Player and _announced_episode.get(attacker_id, 0) != episode:
		_announced_episode[attacker_id] = episode
		announce("dino_hit_player", {"species": dino.stats.display_name, "amount": snappedf(damage, 0.1)})


## Empurrão do golpe que acertou: só o jogador, só se ainda está de pé depois do dano, sempre para longe de quem bateu.
func _knock_back(dino: Dino, target: Node2D, profile: ThreatProfile, landed: bool) -> void:
	var player := target as Player
	if not landed or player == null or player.health.is_dead() or profile.knockback_px <= 0.0:
		return
	var away := target.global_position - dino.global_position
	if away.length_squared() > 0.0001:
		player.knock_back(away.normalized() * profile.knockback_px, profile.knockback_seconds)


## O jogador pode ser acertado pela criatura? Vivo, e nem o dono dela nem aliado do dono.
func _hostile_player(attacker: Dino, player: Player) -> bool:
	var owner_id := attacker.owner_player_id
	if player.health.is_dead():
		return false
	if owner_id == "":
		return true
	return player.player_id != owner_id and not (ally_check.is_valid() and ally_check.call(owner_id, player.player_id))


## O nó pode ser SECUNDÁRIO do golpe em área de `attacker`? (O principal só passa pelo `_area_hit`.)
func _area_candidate(attacker: Dino, node: Node) -> bool:
	if node is Player:
		return _hostile_player(attacker, node as Player)
	var dino := node as Dino
	if dino == null or dino.health.is_dead():
		return false
	if not attacker.state_machine.is_tamed:
		return false  # selvagem não acerta selvagem
	if dino.state_machine.is_tamed:
		# Domado do mesmo dono nunca. Domado de OUTRO só com PvP ligado (`pvp_enabled`).
		if not pvp_enabled or dino.owner_player_id == attacker.owner_player_id:
			return false
	return not dino.taming.is_active() and dino.state_machine.current_id != Enums.DinoStateId.UNCONSCIOUS


## Aplica o golpe (já multiplicado por `fraction`) em `node`; false se ele não pode ser acertado.
func _area_hit(attacker: Dino, node: Node, damage: float, torpor_amount: float, fraction: float) -> bool:
	var player := node as Player
	if player != null:
		if not _hostile_player(attacker, player):
			return false
		player.health.take_damage(damage * fraction)
		return true
	var dino := node as Dino
	if dino == null or not attacker.state_machine.is_tamed:
		return false  # selvagem não acerta selvagem (nem o principal)
	if dino.state_machine.is_tamed:  # só com a chave ligada, e só de outro dono: leva dano (sem torpor: já está domado)
		return pvp_enabled and dino.owner_player_id != attacker.owner_player_id and not dino.health.is_dead() \
				and dino.take_damage(damage * fraction, attacker.stats.attacker_kind)
	return dino.receive_hit(damage * fraction, torpor_amount * fraction, attacker.stats.attacker_kind)


## Alvo do golpe de quem está em `origin` olhando para `facing`: a regra única (`AttackTargeting`) com o alcance, o "à frente" e a
## histerese de `ActionRules`, as mesmas que `request_attack` usa para negar. O jogador a consulta para o destaque.
func choose_attack_target(origin: Vector2, facing: Vector2, candidates: Array[Node2D], current: Node2D) -> Node2D:
	return AttackTargeting.choose(origin, facing, rules.reach_px(), candidates, current, rules.front_dot_min, rules.hysteresis_px)


## O candidato está ao alcance do golpe e à frente de quem olha para `facing`? O jogador pergunta aqui: a regra única fica
## na autoridade (o corpo do jogador não lê `rules` dela, o que também evita um laço de referência entre os scripts).
func can_strike_toward(origin: Vector2, facing: Vector2, candidate: Node2D) -> bool:
	return origin.distance_to(candidate.global_position) <= rules.reach_px() \
			and AttackTargeting.is_in_front(origin, facing, candidate, rules.front_dot_min)


## Pede andar na `direction` neste quadro (comprimento no máximo 1; `wants_sprint` = correr). Nega NaN,
## infinito e vetor maior que 1. Jogador morto não anda, em silêncio (não é abuso e vem a cada quadro).
func request_move(actor_id: int, direction: Vector2, wants_sprint: bool = false) -> Enums.ActionResult:
	var actor := _live_player(actor_id)
	var problem := _actor_problem(actor_id, actor)
	if problem == Enums.ActionResult.ACTOR_DEAD:
		return problem
	if problem == Enums.ActionResult.OK and (not is_finite(direction.x) or not is_finite(direction.y)
			or direction.length() > 1.0 + MOVE_LENGTH_TOLERANCE):
		problem = Enums.ActionResult.INVALID_ARGUMENT
	if problem == Enums.ActionResult.OK:
		actor.perform_move(direction, wants_sprint)
	return _answer(actor_id, ACTION_MOVE, problem)


## Vira o jogador para `direction` (unitária) sem andar: o golpe do mouse olha para o cursor antes de pedir o golpe.
## Nega NaN, infinito, vetor nulo ou maior que 1. É o que a autoridade usa como "à frente" no `request_attack`.
func request_face(actor_id: int, direction: Vector2) -> Enums.ActionResult:
	var actor := _live_player(actor_id)
	var problem := _actor_problem(actor_id, actor)
	if problem == Enums.ActionResult.OK and (not is_finite(direction.x) or not is_finite(direction.y)
			or direction.length() < 0.0001 or direction.length() > 1.0 + MOVE_LENGTH_TOLERANCE):
		problem = Enums.ActionResult.INVALID_ARGUMENT
	if problem == Enums.ActionResult.OK:
		actor.perform_face(direction)
	return _answer(actor_id, ACTION_FACE, problem)


## Entidade interagível (criatura ou nó de recurso visível) sob o ponto do mundo `point`, a mais perto do ponto; null se nenhuma.
## Só consulta (o cursor do mouse escolhe alvo por aqui; o que se faz com ele passa pelos `request_*`).
## `creatures_only` ignora recursos e itens: a criatura viva sob o ponto tem prioridade sobre o resto.
func entity_at(point: Vector2, creatures_only: bool = false) -> Node2D:
	var best: Node2D = null
	var best_distance := INF
	for id: Variant in _entities:
		var node := entity(int(id)) as Node2D
		if node == null or node is Player or node.get("interactable") == null:
			continue
		if creatures_only and not node is Dino:
			continue
		if node is ResourceNode and not (node as ResourceNode).is_available():
			continue
		if node is Dino and (node as Dino).health.is_dead():
			continue
		if not _pick_rect(node).grow(rules.mouse_pick_radius_px).has_point(point):
			continue
		var distance := node.global_position.distance_to(point)
		if distance < best_distance:
			best_distance = distance
			best = node
	return best


## Retângulo do mundo que "é" a entidade para o mouse: o sprite, ou o ponto dela se ainda não tem desenho.
func _pick_rect(node: Node2D) -> Rect2:
	var sprite := node.get("visual") as Sprite2D
	if sprite != null and sprite.texture != null:
		var local := sprite.get_rect()
		return Rect2(sprite.to_global(local.position), local.size * sprite.global_scale.abs())
	var resource := node as ResourceNode
	if resource != null and resource.def != null and resource.def.texture != null:
		var size := resource.def.texture.get_size()
		return Rect2(node.global_position + Vector2(-size.x * 0.5, -size.y), size)
	return Rect2(node.global_position, Vector2.ZERO)


## Opções de interação (clique direito) do alvo, as mesmas ações do teclado: cada uma `{id, label, enabled, reason}`.
## `reason` é o código de recusa quando desabilitada (`GameMessages.REASONS`); vazio quando pode. Lista vazia = nada a oferecer.
## A validade é a mesma dos `request_*` (alcance, dono, estado), sem efeito colateral.
func interaction_options(actor_id: int, target_id: int) -> Array[Dictionary]:
	var options: Array[Dictionary] = []
	var actor := _live_player(actor_id)
	var target := entity(target_id)
	if actor == null or target == null or target == actor:
		return options
	var dino := target as Dino
	if dino != null:
		_dino_options(options, actor, dino)
	elif target is ResourceNode and (target as ResourceNode).is_available():
		var node := target as ResourceNode
		var in_range := _within(actor, node, node.def.reach)
		options.append(_option("interact", _capital(node.def.prompt) if node.def.prompt != "" else "Coletar",
				Enums.ActionResult.OK if in_range else Enums.ActionResult.OUT_OF_RANGE))
	return options


func _dino_options(options: Array[Dictionary], actor: Player, dino: Dino) -> void:
	if dino.health.is_dead():
		return
	if dino.state_machine.is_tamed:
		if dino.owner_player_id != actor.player_id:
			return  # o domado de outro não oferece nada (o teclado também não)
		var problem := _command_problem(actor, dino)
		for entry: Array in [["follow", "Seguir", Enums.DinoOrder.FOLLOW], ["stay", "Ficar", Enums.DinoOrder.STAY]]:
			var option := _option(entry[0], entry[1], problem)
			if problem == Enums.ActionResult.OK and dino.state_machine.order == entry[2]:
				option["enabled"] = false
				option["reason"] = "already_ordered"
			options.append(option)
		options.append(_option("inventory", "Inventário", _interact_problem(actor, dino)))
		return
	var reach := Enums.ActionResult.OK if _within(actor, dino, rules.reach_px()) else Enums.ActionResult.OUT_OF_RANGE
	options.append(_option("attack", "Atacar", reach))
	if dino.can_interact():
		options.append(_option("interact", "Abrir inventário", _interact_problem(actor, dino)))


func _capital(text: String) -> String:
	return text.substr(0, 1).to_upper() + text.substr(1)


func _option(id: String, label: String, problem: Enums.ActionResult) -> Dictionary:
	return {"id": id, "label": label, "enabled": problem == Enums.ActionResult.OK,
			"reason": "" if problem == Enums.ActionResult.OK else GameMessages.reason_for(problem)}


## Interagir com `target_id`. Concedida, emite `interaction_granted`; o efeito é de quem a ouve.
func request_interact(actor_id: int, target_id: int) -> Enums.ActionResult:
	var actor := _live_player(actor_id)
	var target := entity(target_id)
	var problem := _actor_problem(actor_id, actor)
	if problem == Enums.ActionResult.OK:
		problem = _interact_problem(actor, target)
	if problem == Enums.ActionResult.OK:
		interaction_granted.emit(actor_id, target_id)
	return _answer(actor_id, ACTION_INTERACT, problem)


## Move o slot `index` do inventário de `from_id` para o de `to_id`. Um dos lados é o ator e o outro, uma
## criatura selvagem inconsciente (a tela compartilhada): do ator para ela é ALIMENTAR (a comida ideal
## faz do ator o candidato a dono se ainda não há um: o primeiro reserva); dela para o ator é recolher. O que não couber fica onde estava.
## `amount`: `TRANSFER_ALL` (a pilha toda) ou 1 a o tamanho da pilha; fora disso é pedido inválido. Se o destino só comporta
## parte, vai a parte e o resto fica na origem (nada se perde nem se duplica).
func request_transfer_slot(actor_id: int, from_id: int, index: int, to_id: int, amount: int = TRANSFER_ALL) -> Enums.ActionResult:
	var actor := _live_player(actor_id)
	var feeding := from_id == actor_id and to_id != actor_id
	var taking := to_id == actor_id and from_id != actor_id
	var dino := entity(to_id if feeding else from_id) as Dino
	var problem := _actor_problem(actor_id, actor)
	if problem == Enums.ActionResult.OK:
		problem = Enums.ActionResult.OK if feeding or taking else Enums.ActionResult.INVALID_ARGUMENT
	if problem == Enums.ActionResult.OK:
		problem = _transfer_problem(actor, dino, index, feeding, amount)
	if problem == Enums.ActionResult.OK:
		var source := actor.inventory if feeding else dino.inventory
		var item_id := str(source.get_slot(index).get("id", ""))
		if source.transfer_slot(index, dino.inventory if feeding else actor.inventory, amount) == 0:
			problem = Enums.ActionResult.REFUSED
			_reason = "no_space"
		elif feeding and not dino.state_machine.is_tamed and item_id == dino.taming.ideal_food and dino.feeder_player_id == "":
			# O primeiro a depositar a comida ideal reserva o dino; os seguintes não tomam a vaga.
			dino.feeder_player_id = actor.player_id
		if feeding and not dino.state_machine.is_tamed and item_id != dino.taming.ideal_food and problem == Enums.ActionResult.OK:
			# Fica lá (não some, não reserva o dino), mas o jogador precisa saber que ele não come isso.
			announce("wrong_food", {"species": dino.stats.display_name, "item": Items.display_name(item_id),
					"ideal": Items.display_name(dino.taming.ideal_food)})
	return _answer(actor_id, ACTION_TRANSFER, problem)


## Manda o domado `target_id` obedecer a ordem `order` (nome em `Enums.DinoOrder`, ex.: "FOLLOW").
## Só o dono, perto, e só com a criatura domesticada e acordada.
func request_command(actor_id: int, target_id: int, order: String) -> Enums.ActionResult:
	var actor := _live_player(actor_id)
	var dino := entity(target_id) as Dino
	var problem := _actor_problem(actor_id, actor)
	if problem == Enums.ActionResult.OK and (order.length() > MAX_ORDER_NAME or not Enums.DinoOrder.has(order)):
		problem = Enums.ActionResult.INVALID_ARGUMENT
	if problem == Enums.ActionResult.OK:
		problem = _command_problem(actor, dino)
	if problem == Enums.ActionResult.OK and not dino.state_machine.set_order(Enums.DinoOrder[order] as Enums.DinoOrder):
		problem = Enums.ActionResult.WRONG_STATE
	if problem == Enums.ActionResult.OK:
		announce("order_given", {"species": dino.stats.display_name, "order": "seguindo" if order == "FOLLOW" else "ficando"})
	return _answer(actor_id, ACTION_COMMAND, problem)


## Domado do jogador `actor_id` mais perto, ao alcance de ordem (id da entidade, 0 se não há). Serve à tecla G.
func nearest_own_tamed(actor_id: int) -> int:
	var actor := _live_player(actor_id)
	if actor == null:
		return 0
	var best := 0
	var best_distance := rules.command_reach_px()
	for entity_id: int in _entities:
		var dino := entity(entity_id) as Dino
		if dino == null or not dino.can_command() or dino.owner_player_id != actor.player_id:
			continue
		var distance := actor.global_position.distance_to(dino.global_position)
		if distance <= best_distance:
			best_distance = distance
			best = entity_id
	return best


## Usar o atalho `slot` (0 a 8) do inventário de `actor_id`: comer ou equipar/desequipar.
func request_use_item(actor_id: int, slot: int) -> Enums.ActionResult:
	var actor := _live_player(actor_id)
	var problem := _actor_problem(actor_id, actor)
	if problem == Enums.ActionResult.OK and (slot < 0 or slot >= HotbarComponent.SLOT_COUNT):
		problem = Enums.ActionResult.INVALID_ARGUMENT
	if problem == Enums.ActionResult.OK:
		problem = actor.perform_use_item(slot)
		if problem == Enums.ActionResult.REFUSED:
			_reason = actor.last_refusal()
	return _answer(actor_id, ACTION_USE_ITEM, problem)


## Equipar o item `iid` da grade de `actor_id` (`slot_id` "" = a vaga do item).
func request_equip(actor_id: int, iid: String, slot_id: String) -> Enums.ActionResult:
	var actor := _live_player(actor_id)
	var problem := _actor_problem(actor_id, actor)
	if problem == Enums.ActionResult.OK and (iid == "" or iid.length() > MAX_ID_LENGTH or slot_id.length() > MAX_ID_LENGTH):
		problem = Enums.ActionResult.INVALID_ARGUMENT
	if problem == Enums.ActionResult.OK:
		problem = _equipment_result(actor.perform_equipment(iid, slot_id))
	return _answer(actor_id, ACTION_EQUIP, problem)


## Tirar o item da vaga `slot_id` de `actor_id` para a grade.
func request_unequip(actor_id: int, slot_id: String) -> Enums.ActionResult:
	var actor := _live_player(actor_id)
	var problem := _actor_problem(actor_id, actor)
	if problem == Enums.ActionResult.OK and slot_id.length() > MAX_ID_LENGTH:
		problem = Enums.ActionResult.INVALID_ARGUMENT
	if problem == Enums.ActionResult.OK:
		problem = _equipment_result(actor.perform_equipment("", slot_id))
	return _answer(actor_id, ACTION_UNEQUIP, problem)


## Colher o nó de recurso `target_id` (o id do alvo, nunca a mira local de quem pede).
func request_gather(actor_id: int, target_id: int) -> Enums.ActionResult:
	var actor := _live_player(actor_id)
	var node := entity(target_id) as ResourceNode
	var problem := _actor_problem(actor_id, actor)
	if problem == Enums.ActionResult.OK:
		problem = Enums.ActionResult.OK if node != null else Enums.ActionResult.UNKNOWN_TARGET
	if problem == Enums.ActionResult.OK and not _within(actor, node, node.def.reach):
		problem = Enums.ActionResult.OUT_OF_RANGE
	if problem == Enums.ActionResult.OK and node.def.is_struck() \
			and not AttackTargeting.is_in_front(actor.global_position, actor.facing, node, rules.front_dot_min):
		problem = Enums.ActionResult.OUT_OF_RANGE  # colher por golpes pede o nó à frente, como o golpe
		_reason = "behind"
	var completes := problem == Enums.ActionResult.OK and node.is_available() and actor.would_complete_gather(node)
	if completes and gather_wait_left(actor_id) > 0.0:
		problem = Enums.ActionResult.COOLDOWN  # intervalo entre coletas concluídas: recusa silenciosa (a HUD cinza avisa)
		_reason = REASON_GATHER_INTERVAL
	if problem == Enums.ActionResult.OK:
		var life_before := actor.health.current_health
		var reason := actor.perform_gather(node)
		problem = _gather_result(reason)
		_report_gather(actor, node, reason, life_before)
		if reason == "" and completes:
			_start_gather_interval(actor_id)
	return _answer(actor_id, ACTION_GATHER, problem)


## Segundos até o jogador poder concluir outra coleta (0 = já pode). O instante vive aqui, no relógio do mundo.
func gather_wait_left(actor_id: int) -> float:
	return maxf(float(_gather_ready_at.get(actor_id, 0.0)) - clock.now(), 0.0)


## Abre o intervalo: sorteio determinístico entre o mínimo e o máximo (semente do mundo, jogador e nº da coleta).
func _start_gather_interval(actor_id: int) -> void:
	var count := int(_gather_count.get(actor_id, 0))
	_gather_count[actor_id] = count + 1
	var rng := SeededRng.new()
	rng.seed_from([world_seed, "gather_interval", actor_id, count])
	var low := minf(rules.gather_interval_min_s, rules.gather_interval_max_s)
	var high := maxf(rules.gather_interval_min_s, rules.gather_interval_max_s)
	_gather_ready_at[actor_id] = clock.now() + rng.next_range(low, high)


## Avisos da coleta: o que entrou, a vida que a mão custou e o motivo de não ter coletado.
func _report_gather(actor: Player, node: ResourceNode, reason: String, life_before: float) -> void:
	if drops_enabled:
		for item_id: String in actor.last_drop:  # derrubou: o recurso cai ao redor do nó, não no inventário
			items_dropped.emit(item_id, int(actor.last_drop[item_id]), node.global_position, actor.player_id)
			announce("resource_dropped", {"item": Items.display_name(item_id), "amount": int(actor.last_drop[item_id])})
	for item_id: String in actor.last_gather:
		announce("item_collected", {"item": Items.display_name(item_id), "amount": int(actor.last_gather[item_id])})
	var hurt := life_before - actor.health.current_health
	if hurt > 0.0:
		announce("hands_hurt", {"amount": snappedf(hurt, 0.1)})
	match reason:
		Player.GATHER_NEEDS_TOOL:
			announce("action_refused", {"action": ACTION_GATHER, "reason": "needs_tool", "tool": node.def.tool_name})
		Player.GATHER_FULL:
			announce("inventory_full")


## Recolher o item de chão `target_id`: vai ao inventário de `actor_id` o que couber; o resto fica no chão. Valida ator,
## alcance, dono (gancho do co-op) e espaço (o Peso entra aqui quando existir). Dois pedidos do mesmo item: o primeiro leva.
func request_pickup(actor_id: int, target_id: int) -> Enums.ActionResult:
	var actor := _live_player(actor_id)
	var item := entity(target_id) as GroundItem
	var problem := _actor_problem(actor_id, actor)
	if problem == Enums.ActionResult.OK:
		problem = Enums.ActionResult.OK if item != null else Enums.ActionResult.UNKNOWN_TARGET
	if problem == Enums.ActionResult.OK and not _within(actor, item, rules.reach_px()):
		problem = Enums.ActionResult.OUT_OF_RANGE
	if problem == Enums.ActionResult.OK and item.reserved_against(actor.player_id, clock.now()):
		problem = Enums.ActionResult.NOT_OWNER
	if problem == Enums.ActionResult.OK and actor.inventory.room_for(item.item_id) <= 0:
		problem = Enums.ActionResult.REFUSED
		_reason = "inventory_full"
	if problem == Enums.ActionResult.OK:
		var item_id := item.item_id
		var taken := item.take(actor.inventory.room_for(item_id))
		actor.inventory.add(item_id, taken)
		announce("item_collected", {"item": Items.display_name(item_id), "amount": taken})
	return _answer(actor_id, ACTION_PICKUP, problem)


## Largar no chão `amount` (TRANSFER_ALL = tudo) do slot `index` do inventário de `actor_id`, aos pés dele. Só pilha
## (equipamento individual não se larga por aqui). Nada some: o que sai do inventário vira item de chão.
func request_drop(actor_id: int, index: int, amount: int = TRANSFER_ALL) -> Enums.ActionResult:
	var actor := _live_player(actor_id)
	var problem := _actor_problem(actor_id, actor)
	if problem == Enums.ActionResult.OK and not drops_enabled:
		problem = Enums.ActionResult.REFUSED
	var slot := actor.inventory.get_slot(index) if problem == Enums.ActionResult.OK else {}
	if problem == Enums.ActionResult.OK and (slot.is_empty() or slot.has("iid")):
		problem = Enums.ActionResult.INVALID_ARGUMENT
	if problem == Enums.ActionResult.OK and amount != TRANSFER_ALL and (amount < 1 or amount > int(slot["count"])):
		problem = Enums.ActionResult.INVALID_ARGUMENT
	if problem == Enums.ActionResult.OK:
		var item_id := str(slot["id"])
		var count := int(slot["count"]) if amount == TRANSFER_ALL else amount
		var removed := actor.inventory.take_from_slot(index, count)
		items_dropped.emit(item_id, removed, actor.global_position, actor.player_id)
	return _answer(actor_id, ACTION_DROP, problem)


func _equipment_result(reason: String) -> Enums.ActionResult:
	if reason == "":
		return Enums.ActionResult.OK
	if reason == EquipmentComponent.REFUSED_FULL:
		_reason = "inventory_full"
	elif reason == EquipmentComponent.REFUSED_WRONG_SLOT:
		_reason = "wrong_slot"
	return Enums.ActionResult.COOLDOWN if reason == Player.COOLDOWN else Enums.ActionResult.REFUSED


func _gather_result(reason: String) -> Enums.ActionResult:
	match reason:
		"":
			return Enums.ActionResult.OK
		Player.COOLDOWN:
			return Enums.ActionResult.COOLDOWN
		Player.GATHER_DEPLETED:
			_reason = "depleted"
			return Enums.ActionResult.WRONG_STATE
		Player.GATHER_NEEDS_TOOL:
			return Enums.ActionResult.OK  # o toque aconteceu (a mão doeu); só não coletou: a recusa vai no sinal do jogador
	_reason = "inventory_full" if reason == Player.GATHER_FULL else ""
	return Enums.ActionResult.REFUSED


func _live_player(actor_id: int) -> Player:
	var actor := entity(actor_id) as Player
	return actor if actor != null and not actor.health.is_dead() else null


## Por que o ator não serve (OK = serve): não é um jogador registrado, ou está morto.
func _actor_problem(actor_id: int, actor: Player) -> Enums.ActionResult:
	if actor != null:
		return Enums.ActionResult.OK
	return Enums.ActionResult.ACTOR_DEAD if entity(actor_id) is Player else Enums.ActionResult.UNKNOWN_ACTOR


func _attack_problem(actor: Player, dino: Dino) -> Enums.ActionResult:
	if dino == null:
		return Enums.ActionResult.UNKNOWN_TARGET
	if dino.health.is_dead() or dino.state_machine.is_tamed:
		return Enums.ActionResult.INVALID_TARGET
	var weapon := actor.current_weapon()
	var reach := weapon.reach_tiles * rules.tile_size if weapon.reach_tiles > 0.0 else rules.reach_px()  # a arma, se tem alcance próprio
	if not _within(actor, dino, reach):
		return Enums.ActionResult.OUT_OF_RANGE
	# "À frente" é regra da autoridade, pela direção do corpo que ELA mantém (a última aceita em `request_move`).
	if not AttackTargeting.is_in_front(actor.global_position, actor.facing, dino, rules.front_dot_min):
		_reason = "behind"
		return Enums.ActionResult.OUT_OF_RANGE
	return Enums.ActionResult.OK if actor.can_strike() else Enums.ActionResult.COOLDOWN


func _interact_problem(actor: Player, target: Node) -> Enums.ActionResult:
	if target == null or target == actor:
		return Enums.ActionResult.UNKNOWN_TARGET
	var area := target.get("interactable") as InteractableArea
	if area == null:
		return Enums.ActionResult.INVALID_TARGET
	if not _within(actor, target, rules.reach_px()):
		return Enums.ActionResult.OUT_OF_RANGE
	var pet := target as Dino
	if pet != null and pet.state_machine.is_tamed:
		# O domado abre o inventário (alforje) só para o dono; aliado e outro jogador levam NOT_OWNER.
		return Enums.ActionResult.OK if pet.owner_player_id == actor.player_id else Enums.ActionResult.NOT_OWNER
	return Enums.ActionResult.OK if area.can_interact() else Enums.ActionResult.WRONG_STATE


func _transfer_problem(actor: Player, dino: Dino, index: int, feeding: bool, amount: int) -> Enums.ActionResult:
	if dino == null:
		return Enums.ActionResult.UNKNOWN_TARGET
	if dino.health.is_dead():
		return Enums.ActionResult.INVALID_TARGET
	if not _within(actor, dino, rules.reach_px()):
		return Enums.ActionResult.OUT_OF_RANGE
	if not dino.can_interact() and not _is_owned_by(dino, actor):  # selvagem inconsciente, ou o domado do próprio jogador
		return _closed_inventory_problem(dino, actor.player_id)
	return _transfer_amount_problem(actor, dino, index, feeding, amount)


## A posição e a quantidade pedidas existem na origem? (`TRANSFER_ALL` = o stack inteiro.)
func _transfer_amount_problem(actor: Player, dino: Dino, index: int, feeding: bool, amount: int) -> Enums.ActionResult:
	var source := actor.inventory if feeding else dino.inventory
	if index < 0 or index >= source.slot_count():
		return Enums.ActionResult.INVALID_ARGUMENT
	var stack := int(source.get_slot(index).get("count", 0))
	if amount != TRANSFER_ALL and (amount < 1 or amount > stack):
		return Enums.ActionResult.INVALID_ARGUMENT
	return Enums.ActionResult.OK


func _is_owned_by(dino: Dino, actor: Player) -> bool:
	return dino.state_machine.is_tamed and dino.owner_player_id == actor.player_id


func _command_problem(actor: Player, dino: Dino) -> Enums.ActionResult:
	if dino == null:
		return Enums.ActionResult.UNKNOWN_TARGET
	if dino.health.is_dead():
		return Enums.ActionResult.INVALID_TARGET
	if not _within(actor, dino, rules.command_reach_px()):
		return Enums.ActionResult.OUT_OF_RANGE
	if not dino.state_machine.is_tamed:
		return Enums.ActionResult.WRONG_STATE
	if dino.owner_player_id != actor.player_id:
		return Enums.ActionResult.NOT_OWNER
	return Enums.ActionResult.OK


## O inventário da criatura não abre: é de outro (domesticada), ou a criatura está acordada.
func _closed_inventory_problem(dino: Dino, player_id: String) -> Enums.ActionResult:
	if dino.state_machine.is_tamed and dino.owner_player_id != player_id:
		return Enums.ActionResult.NOT_OWNER
	return Enums.ActionResult.WRONG_STATE


func _within(actor: Node2D, target: Node, reach: float) -> bool:
	var other := target as Node2D
	return other != null and actor.global_position.distance_to(other.global_position) <= reach


## Fecha o pedido: OK passa direto; o resto é negado e avisado.
func _answer(actor_id: int, action: String, result: Enums.ActionResult) -> Enums.ActionResult:
	if result != Enums.ActionResult.OK:
		action_denied.emit(actor_id, action, result)
	if result != Enums.ActionResult.OK and _reason != REASON_GATHER_INTERVAL:  # o intervalo não enche o log
		var params := _reason_params.duplicate()
		params["action"] = action
		params["reason"] = _reason if _reason != "" else GameMessages.reason_for(result)
		game_event.emit("action_refused", params)
	_reason = ""
	_reason_params = {}
	return result
