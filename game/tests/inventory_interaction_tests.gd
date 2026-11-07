# SPDX-License-Identifier: MIT
class_name InventoryInteractionTests
extends TestSuite
## Inventário (pilhas, transferência, sinais, save), regra de interação, ataque e mira.


func run() -> void:
	_test_inventory_stacks_and_capacity()
	_test_inventory_remove_and_count()
	_test_inventory_transfer()
	_test_inventory_signals()
	_test_inventory_save_is_validated()
	_test_inventory_capacity_setter()
	_test_taming_without_inventory()
	_test_can_interact_rule()
	_test_input_actions_for_interaction()
	_test_attack_rules()
	_test_player_inventory_and_save()


func _make_inventory(slots: int, stack: int = 99) -> InventoryComponent:
	var inventory: InventoryComponent = _track.call(InventoryComponent.new())
	inventory.capacity = slots
	inventory.max_stack = stack
	return inventory


func _test_inventory_stacks_and_capacity() -> void:
	var inv := _make_inventory(3, 20)
	_check(inv.add("berry", 25) == 0, "25 baga cabem em 3 slots de 20")
	_check(inv.get_slot(0) == {"id": "berry", "count": 20, "expira_em": 0.0}
			and inv.get_slot(1) == {"id": "berry", "count": 5, "expira_em": 0.0},
			"pilha enche e transborda para o próximo slot")
	_check(inv.add("berry", 10) == 0 and inv.get_slot(1)["count"] == 15, "completa a pilha existente antes de abrir slot")
	_check(inv.add("meat", 3) == 0 and inv.get_slot(2) == {"id": "meat", "count": 3, "expira_em": 0.0}, "item diferente usa slot livre")
	_check(inv.add("berry", 10) == 5 and inv.count("berry") == 40, "cheio: devolve o que não coube e guarda o resto")
	_check(inv.add("fern", 1) == 1, "sem slot livre, outro item não entra")
	_check(inv.add("pedra", 5) == 5 and inv.count("pedra") == 0, "item desconhecido é rejeitado")
	_check(inv.add("berry", 0) == 0 and inv.add("berry", -3) == 0, "quantidade <= 0 não faz nada")
	var small := _make_inventory(2, 4)
	_check(small.add("fern", 10) == 2 and small.count("fern") == 8, "max_stack do inventário limita a pilha")
	_check(Items.max_stack("meat") == 10, "pilha máxima do item também vale")
	var meat := _make_inventory(2, 99)
	_check(meat.add("meat", 25) == 5, "pilha máxima do item (10) limita o inventário")
	_check(inv.get_slot(99).is_empty() and inv.get_slot(-1).is_empty(), "slot fora do intervalo é vazio")
	var copy := inv.get_slot(0)
	copy["count"] = 1
	_check(inv.get_slot(0)["count"] == 20, "get_slot devolve cópia")


func _test_inventory_remove_and_count() -> void:
	var inv := _make_inventory(4, 10)
	inv.add("berry", 25)
	_check(inv.count("berry") == 25, "count soma as pilhas")
	_check(inv.remove("berry", 12) == 12 and inv.count("berry") == 13, "remove atravessa pilhas")
	_check(inv.remove("berry", 100) == 13 and inv.is_empty(), "remove devolve só o que existia")
	_check(inv.remove("berry", 1) == 0 and inv.remove("berry", -1) == 0, "remover o que não há ou negativo é 0")
	inv.add("berry", 3)
	inv.add("meat", 2)
	inv.remove("berry", 3)
	_check(inv.get_slot(0).is_empty() and inv.count("meat") == 2, "slot esvaziado fica livre e o outro item permanece")


func _test_inventory_transfer() -> void:
	var a := _make_inventory(4, 10)
	var b := _make_inventory(2, 10)
	a.add("berry", 25)
	a.add("meat", 5)
	var total := a.count("berry") + b.count("berry")
	_check(a.transfer(b, "berry", 8) == 8, "transfere a quantidade pedida")
	_check(a.count("berry") == 17 and b.count("berry") == 8, "origem perdeu e destino ganhou o mesmo")
	_check(a.transfer(b, "berry", 100) == 12, "só move o que o destino comporta (12 de espaço)")
	_check(a.count("berry") == 5 and b.count("berry") == 20, "destino cheio, sobra na origem")
	_check(a.count("berry") + b.count("berry") == total, "nada some nem duplica")
	_check(a.transfer(b, "meat", 5) == 0 and a.count("meat") == 5, "destino sem slot livre: nada se perde")
	_check(a.transfer(a, "berry", 1) == 0 and a.count("berry") == 5, "transferir para si mesmo não faz nada")
	_check(a.transfer(null, "berry", 1) == 0, "sem destino não faz nada")
	_check(a.transfer(b, "berry", 0) == 0 and a.transfer(b, "fern", 3) == 0, "zero e item ausente")
	b.remove("berry", 20)
	var first := 0
	while a.get_slot(first).is_empty():
		first += 1
	var in_slot: int = a.get_slot(first)["count"]
	_check(a.transfer_slot(first, b) == in_slot and a.transfer_slot(99, b) == 0,
			"transfer_slot move o slot inteiro; slot inexistente é 0")
	_check(a.count("berry") + b.count("berry") == 5, "conservação depois de transfer_slot")


func _test_inventory_signals() -> void:
	var a := _make_inventory(2, 10)
	var b := _make_inventory(2, 10)
	var hits := [0, 0]
	a.changed.connect(func() -> void: hits[0] += 1)
	b.changed.connect(func() -> void: hits[1] += 1)
	a.add("berry", 5)
	_check(hits[0] == 1, "add emite changed uma vez")
	a.add("berry", 0)
	a.remove("meat", 1)
	a.add("pedra", 1)
	_check(hits[0] == 1, "operação sem efeito não emite")
	a.transfer(b, "berry", 3)
	_check(hits[0] == 2 and hits[1] == 1, "transfer emite uma vez em cada lado")
	var full := _make_inventory(1, 1)
	full.add("berry", 1)
	a.transfer(full, "berry", 1)
	_check(hits[0] == 2, "transfer bloqueada não emite")
	a.from_dict(a.to_dict())
	_check(hits[0] == 3, "from_dict emite changed (a UI redesenha)")


func _test_inventory_save_is_validated() -> void:
	var inv := _make_inventory(4, 20)
	inv.add("berry", 25)
	inv.add("meat", 3)
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(inv.to_dict()))
	var copy := _make_inventory(4, 20)
	copy.from_dict(parsed)
	_check(copy.to_dict() == inv.to_dict(), "inventário idêntico depois do JSON")
	_check(copy.count("berry") == 25 and copy.get_slot(2).get("id") == "meat", "posições dos slots preservadas")
	var hostile := _make_inventory(2, 20)
	hostile.add("meat", 1)
	_check(not hostile.from_dict({"slots": [{"id": "berry", "count": 99999999}]}) and hostile.count("meat") == 1
			and hostile.count("berry") == 0, "contagem absurda que não cabe: carga recusada, nada muda")
	hostile.from_dict({"slots": [{"id": "berry", "count": 30}]})
	_check(hostile.get_slot(0)["count"] == 20 and hostile.get_slot(1)["count"] == 10, "pilha acima do teto é dividida, não cortada")
	hostile.from_dict({"slots": [{"id": "pedra", "count": 5}, {"id": "meat", "count": 1}]})
	_check(hostile.get_slot(0).is_empty() and hostile.count("meat") == 1, "id desconhecido é descartado")
	_check(not hostile.from_dict({"slots": [{"id": "meat", "count": 1}, {"id": "fern", "count": 1}, {"id": "berry", "count": 3}]})
			and hostile.count("fern") == 0 and hostile.count("meat") == 1, "item válido além da capacidade: recusa a carga inteira")
	hostile.from_dict({"slots": []})
	for bad: Variant in [{"slots": "lixo"}, {"slots": [null, 3, "x", [], {"id": 7, "count": 1}]},
			{"slots": [{"id": "berry", "count": -4}]}, {"slots": [{"id": "berry", "count": "9"}]},
			{"slots": [{"id": "berry", "count": INF}]}, {"slots": [{"id": "berry", "count": NAN}]}, {}]:
		hostile.from_dict(bad)
		_check(hostile.is_empty(), "save inválido vira inventário vazio: %s" % str(bad))


func _test_inventory_capacity_setter() -> void:
	var inv := _make_inventory(6, 10)
	inv.add("berry", 25)
	inv.capacity = 2
	_check(inv.capacity == 3 and inv.count("berry") == 25, "reduzir capacidade não descarta itens")
	inv.capacity = 500
	_check(inv.capacity == InventoryComponent.MAX_CAPACITY and inv.slot_count() == inv.capacity, "capacidade é limitada")
	inv.capacity = 0
	_check(inv.capacity == 3, "capacidade mínima respeita o que está ocupado")


func _test_taming_without_inventory() -> void:
	var machine := _make_machine()
	var taming: TamingComponent = _track.call(TamingComponent.new())
	taming.state_machine = machine
	machine.torpor.add_torpor(100.0)
	taming.tick(100.0)
	_check(taming.taming_progress == 0.0 and taming.food_available() == 0, "sem inventário não domestica nem quebra")


# --- Interação ---


func _test_can_interact_rule() -> void:
	var dino := _spawn_dino()
	_check(not dino.can_interact(), "selvagem acordado não pode ser aberto")
	_check(not dino.interactable.can_interact(), "a área reflete a regra da entidade")
	dino.torpor.add_torpor(100.0)
	_check(dino.can_interact() and dino.interactable.can_interact(), "selvagem inconsciente pode ser aberto")
	dino.state_machine.mark_tamed()
	_check(not dino.can_interact(), "domesticado não pode ser aberto")
	dino.torpor.add_torpor(100.0)
	_check(not dino.can_interact(), "domesticado inconsciente também não")
	var area: InteractableArea = _track.call(InteractableArea.new())
	_check(area.can_interact(), "sem regra, a área está sempre disponível")
	var events: Array[bool] = []
	var wild := _spawn_dino()
	wild.interactable.availability_changed.connect(func(v: bool) -> void: events.append(v))
	wild.torpor.add_torpor(100.0)
	wild.torpor.tick(1000.0)
	wild.interactable.refresh()
	_check(events == [true, false], "availability_changed só emite quando muda")


func _test_input_actions_for_interaction() -> void:
	for action in ["interact", "attack", "inventory"]:
		_check(InputMap.has_action(action) and not InputMap.action_get_events(action).is_empty(),
				"ação %s existe no projeto" % action)


func _test_attack_rules() -> void:
	var player := _spawn_player()
	var dino := _spawn_dino()
	dino.set_physics_process(false)
	TestWorld.arm(player, [dino], _track)
	_check(not player.attack(), "sem alvo não ataca")
	player.target = dino.interactable
	player._in_range.append(dino.interactable)
	_check(player.attack(), "golpe acerta o alvo")
	_check(is_equal_approx(dino.torpor.current_torpor, player.current_weapon().torpor), "aplica o torpor da arma")
	_check(not player.attack(), "recarga impede golpe seguido")
	player.tick(player.current_weapon().cooldown)
	_check(player.attack(), "depois da recarga ataca de novo")
	player.tick(1.0)
	player.input_locked = true
	_check(not player.attack() and not player.try_interact(), "com a tela aberta não ataca nem interage")
	player.input_locked = false
	dino.torpor.add_torpor(100.0)
	dino.state_machine.mark_tamed()
	_check(dino.state_machine.is_tamed and not dino.apply_torpor(10.0), "domesticado não recebe torpor")
	player.tick(1.0)
	_check(not player.attack(), "ataque não afeta domesticado")
	player.health.take_damage(1000.0)
	_check(not player.attack() and not player.try_interact(), "jogador morto não age")


func _test_player_inventory_and_save() -> void:
	var player := _spawn_player()
	_check(player.inventory.count("berry") == 10 and player.inventory.count("meat") == 4,
			"jogador começa com comida")
	player.inventory.remove("berry", 3)
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(player.to_dict()))
	var copy := _spawn_player()
	copy.from_dict(parsed)
	_check(copy.inventory.count("berry") == 7, "inventário do jogador restaurado")
	_check(copy.to_dict() == player.to_dict(), "save do jogador idêntico depois do JSON")
