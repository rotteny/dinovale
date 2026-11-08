# SPDX-License-Identifier: MIT
class_name HungerTests
extends AuthorityTests
## Fome do jogador: taxa por estado de movimento, comida que sobe aos poucos (fila de fome pendente), só baga e carne
## crua são comida, morte zera a fila, save preserva o pendente, barra mostra o trecho pendente.

const BUSH_DEF: ResourceNodeDef = preload("res://data/resources/bush_baga.tres")


func run() -> void:
	_test_rates_by_state()
	_test_action_costs()
	_test_gradual_eating()
	_test_queue_adds_without_speeding_up()
	_test_full_does_not_spend_item()
	_test_only_berry_and_meat_are_food()
	_test_death_clears_queue()
	_test_save_roundtrip()
	_test_pending_bar()
	_test_adjacent_bushes_have_no_delay()
	_release_worlds()


## Jogador pronto para comer: fome em `level` (0..100), sem queda, com 3 de cada comida na vaga de atalho.
func _eater(level: float) -> Player:
	var player := _player_at(Vector2.ZERO)
	player.hunger.set_physics_process(false)
	player.hunger.decay_per_second = 0.0
	player.hunger.set_ratio(level / 100.0)
	for slot in 3:
		player.hotbar.assign(6 + slot, [Items.BERRY, Items.MEAT, Items.FERN][slot])
	player.inventory.add(Items.BERRY, 3)
	player.inventory.add(Items.MEAT, 3)
	player.inventory.add(Items.FERN, 3)
	return player


func _use(player: Player, slot: int) -> Enums.ActionResult:
	player.tick(1.0)  # passa a recarga de comer
	return player.perform_use_item(slot)


func _test_rates_by_state() -> void:
	var player := _player_at(Vector2.ZERO)
	var rules := player.rules
	player.apply_input(Vector2.ZERO, false, 0.0)
	_check(is_equal_approx(player.hunger.decay_per_second, 0.04), "parado: 0,04/s")
	player.apply_input(Vector2.RIGHT, false, 0.0)
	_check(is_equal_approx(player.hunger.decay_per_second, 0.06), "andando: 0,06/s")
	player.apply_input(Vector2.RIGHT, true, 0.0)
	_check(is_equal_approx(player.hunger.decay_per_second, 0.15), "correndo: 0,15/s")
	_check(rules.hunger_decay_idle < rules.hunger_decay_walk and rules.hunger_decay_walk < rules.hunger_decay_run,
			"parado < andando < correndo")
	player.stamina.current_stamina = 0.0
	player.stamina.is_exhausted = true
	player.apply_input(Vector2.RIGHT, true, 0.0)
	_check(is_equal_approx(player.hunger.decay_per_second, 0.06), "sem fôlego ele não corre: taxa de andar")


func _test_action_costs() -> void:
	var player := _player_at(Vector2.ZERO)
	player.hunger.set_physics_process(false)
	var before := player.hunger.current_hunger
	player.hunger.spend(player.rules.hunger_cost_attack)
	_check(is_equal_approx(before - player.hunger.current_hunger, 0.4), "golpe de ataque custa 0,4 de fome")
	player.hunger.set_ratio(0.0)
	player.hunger.spend(5.0)
	_check(player.hunger.current_hunger == 0.0, "a fome nunca fica negativa")


func _test_gradual_eating() -> void:
	var player := _eater(50.0)
	_check(_use(player, 6) == Enums.ActionResult.OK, "comer baga é aceito")
	_check(is_equal_approx(player.hunger.current_hunger, 50.0) and is_equal_approx(player.hunger.pending, 10.0),
			"a fome não sobe de uma vez: entra na fila (+10)")
	player.hunger.tick(1.25)
	_check(is_equal_approx(player.hunger.current_hunger, 55.0), "em 1,25 s subiu 5 (4/s)")
	player.hunger.tick(1.25)
	_check(is_equal_approx(player.hunger.current_hunger, 60.0) and player.hunger.pending == 0.0, "a baga sobe +10 em 2,5 s")
	_use(player, 7)
	player.hunger.tick(7.5)
	_check(is_equal_approx(player.hunger.current_hunger, 90.0), "a carne crua sobe +30 em 7,5 s")
	var decaying := _eater(50.0)
	decaying.hunger.decay_per_second = 1.0
	_use(decaying, 6)
	decaying.hunger.tick(2.5)
	_check(is_equal_approx(decaying.hunger.current_hunger, 57.5), "a queda continua durante a recuperação (+10 -2,5)")


func _test_queue_adds_without_speeding_up() -> void:
	var player := _eater(20.0)
	_use(player, 6)
	_use(player, 6)
	_check(is_equal_approx(player.hunger.pending, 20.0), "duas comidas entram na fila (+20)")
	player.hunger.tick(2.5)
	_check(is_equal_approx(player.hunger.current_hunger, 30.0) and is_equal_approx(player.hunger.pending, 10.0),
			"comer mais não acelera a taxa: em 2,5 s subiu só 10")


func _test_full_does_not_spend_item() -> void:
	var player := _eater(100.0)
	var before := player.inventory.count(Items.BERRY)
	_check(_use(player, 6) == Enums.ActionResult.REFUSED and player.last_refusal() == "not_hungry"
			and player.inventory.count(Items.BERRY) == before, "cheio: recusa e não gasta o item")
	var queued := _eater(90.0)
	_use(queued, 7)  # +30 mas só cabem 10
	_check(is_equal_approx(queued.hunger.pending, 10.0), "a fila não passa do que falta para encher")
	var meat := queued.inventory.count(Items.MEAT)
	var berries := queued.inventory.count(Items.BERRY)
	_check(_use(queued, 6) == Enums.ActionResult.REFUSED and queued.inventory.count(Items.BERRY) == berries,
			"fome + fila no máximo: a baga não é gasta")
	_check(queued.inventory.count(Items.MEAT) == meat, "a carne já engolida não volta")


func _test_only_berry_and_meat_are_food() -> void:
	var player := _eater(30.0)
	var rules := player.rules
	_check(is_equal_approx(rules.hunger_restore_of(Items.BERRY), 10.0) and is_equal_approx(rules.hunger_restore_of(Items.MEAT), 30.0)
			and rules.hunger_restore_of(Items.FERN) == 0.0, "dados: baga 10, carne 30, samambaia fora")
	var before := player.inventory.count(Items.FERN)
	_check(_use(player, 8) == Enums.ActionResult.REFUSED and player.last_refusal() == "not_food"
			and player.inventory.count(Items.FERN) == before and player.hunger.pending == 0.0,
			"samambaia: recusa, não gasta e não entra na fila")
	_check(GameMessages.reason_text("not_food", {}) == "Isso não é comida.", "o log diz que não é comida")
	_check(Items.has(Items.FERN), "a samambaia segue existindo como item (comida de dino)")


func _test_death_clears_queue() -> void:
	var player := _eater(40.0)
	_use(player, 7)
	_check(player.hunger.pending > 0.0, "há fila antes de morrer")
	TestWorld.kill(player)
	_check(player.hunger.pending == 0.0, "morrer zera a fila")


func _test_save_roundtrip() -> void:
	var player := _eater(40.0)
	_use(player, 7)
	player.hunger.tick(2.0)
	var saved := player.hunger.to_dict()
	var other := _eater(100.0)
	other.hunger.from_dict(saved)
	_check(is_equal_approx(other.hunger.pending, player.hunger.pending) and other.hunger.pending > 0.0
			and is_equal_approx(other.hunger.current_hunger, player.hunger.current_hunger), "save e load preservam o pendente")
	var old := saved.duplicate()
	old.erase("pending")
	other.hunger.from_dict(old)
	_check(other.hunger.pending == 0.0, "save antigo sem o campo = 0")
	var hostile := saved.duplicate()
	hostile["pending"] = 1.0e9
	other.hunger.from_dict(hostile)
	_check(other.hunger.current_hunger + other.hunger.pending <= other.hunger.max_hunger, "pendente hostil é limitado")


func _test_pending_bar() -> void:
	var bar := StatBar.new("Fome", Color.YELLOW)
	_track.call(bar)
	bar.set_pending(40.0, 10.0, 100.0)
	_check(bar.pending_visible(), "a barra mostra o trecho pendente")
	bar.set_pending(40.0, 0.0, 100.0)
	_check(not bar.pending_visible(), "sem fila, sem trecho")


## Intervalo entre coletas concluídas (decisão do dono, 08/11): entre `gather_interval_min_s` e `_max_s`, sorteado de
## forma determinística. A segunda coleta imediata é recusada (sem mensagem no log) e passa depois do intervalo.
func _test_adjacent_bushes_have_no_delay() -> void:
	var bush_def: ResourceNodeDef = BUSH_DEF
	var player := _player_at(Vector2.ZERO)
	var first := _bush(bush_def, Vector2(10, 0))
	var second := _bush(bush_def, Vector2(0, 10))
	var authority := TestWorld.arm(player, [], _track)
	authority.register(first)
	authority.register(second)
	var actor_id := authority.id_of(player)
	var logged: Array[String] = []
	authority.game_event.connect(func(code: String, _params: Dictionary) -> void: logged.append(code))
	var one := authority.request_gather(actor_id, authority.id_of(first))
	var wait := authority.gather_wait_left(actor_id)
	_check(one == Enums.ActionResult.OK and wait >= authority.rules.gather_interval_min_s - 0.001
			and wait <= authority.rules.gather_interval_max_s + 0.001, "a coleta concluída abre um intervalo de 1 a 2 s (%.2f)" % wait)
	logged.clear()
	var two := authority.request_gather(actor_id, authority.id_of(second))
	_check(two == Enums.ActionResult.COOLDOWN and second.is_available(), "a segunda coleta imediata é recusada e não gasta o nó")
	_check(not logged.has("action_refused"), "a recusa do intervalo não enche o log")
	authority.clock.advance(authority.rules.gather_interval_min_s - 0.2)
	_check(authority.request_gather(actor_id, authority.id_of(second)) == Enums.ActionResult.COOLDOWN, "antes do intervalo, ainda recusa")
	authority.clock.advance(authority.rules.gather_interval_max_s)
	_check(authority.request_gather(actor_id, authority.id_of(second)) == Enums.ActionResult.OK and not second.is_available(),
			"passado o intervalo, a coleta vale")
	_check(authority.request_gather(actor_id, authority.id_of(first)) != Enums.ActionResult.OK, "nó esgotado não coleta de novo")
	_test_interval_is_deterministic()


## O sorteio do intervalo só depende da semente do mundo, do jogador e do contador: dois mundos iguais dão os mesmos tempos.
func _test_interval_is_deterministic() -> void:
	var waits: Array[Array] = []
	for world_seed in [7, 7, 8]:
		var player := _player_at(Vector2.ZERO)
		var authority := TestWorld.arm(player, [], _track)
		authority.world_seed = world_seed
		var actor_id := authority.id_of(player)
		var seen: Array[float] = []
		for index in 3:
			var bush := _bush(BUSH_DEF, Vector2(10, 0))
			authority.register(bush)
			authority.request_gather(actor_id, authority.id_of(bush))
			seen.append(authority.gather_wait_left(actor_id))
			authority.clock.advance(3.0)
		waits.append(seen)
	_check(waits[0] == waits[1], "mesma semente, mesmos intervalos")
	_check(waits[0] != waits[2], "outra semente, outros intervalos")


func _bush(def: ResourceNodeDef, point: Vector2) -> ResourceNode:
	var node: ResourceNode = preload("res://src/entities/resource/ResourceNode.tscn").instantiate()
	node.def = def
	node.position = point
	_root.add_child(node)
	_track.call(node)
	return node
