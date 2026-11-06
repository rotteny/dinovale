# SPDX-License-Identifier: MIT
class_name HudHotbarTests
extends DinoLevelTests
## Testes da HUD nova (vida, fome, XP, atalhos), da barra de atalhos 1 a 9, do uso de
## item, do ofegar (GDD 5.7) e do dano recebido pelo jogador. Reaproveita os auxiliares
## de `DinoLevelTests`.


func run() -> void:
	_test_hotbar_component()
	_test_hotbar_save_is_validated()
	_test_player_save_carries_hotbar()
	_test_player_rules_data()
	_test_use_item_eating()
	_test_use_item_with_sleeping_dino_in_reach()
	_test_hotbar_keys_and_input_map()
	_test_hud_layout_and_xp_hook()
	_test_inventory_assigns_hotbar()
	_test_winded_and_sprint_stop()
	_test_player_view_breath_and_damage()
	_test_review_low_points()


func _player() -> Player:
	var player := _spawn_player()
	player.set_physics_process(false)
	return player


## Põe o dino ao alcance de verdade: o alvo sobrevive ao `tick` (que reescolhe o alvo).
func _aim(player: Player, dino: Dino) -> void:
	player._in_range.clear()
	player._in_range.append(dino.interactable)
	player.update_target()


func _action(name: String) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = true
	return event


func _test_hotbar_component() -> void:
	var bar: HotbarComponent = _track.call(HotbarComponent.new())
	var changes := [0]
	bar.changed.connect(func() -> void: changes[0] += 1)
	_check(bar.first_free() == 0 and bar.item_at(0) == "", "barra nasce vazia")
	_check(bar.assign(2, Items.BERRY) and bar.item_at(2) == Items.BERRY and changes[0] == 1, "atribui o tipo de item")
	_check(not bar.assign(2, Items.BERRY) and changes[0] == 1, "repetir a mesma atribuição não muda")
	_check(not bar.assign(9, Items.BERRY) and not bar.assign(-1, Items.BERRY) and not bar.assign(0, "inexistente"),
			"posição inválida e item desconhecido são recusados")
	bar.assign(5, Items.BERRY)
	_check(bar.item_at(2) == "" and bar.item_at(5) == Items.BERRY, "o mesmo item não fica em duas posições")
	_check(bar.slot_of(Items.BERRY) == 5 and bar.slot_of("") == -1 and bar.first_free() == 0, "slot_of e first_free")
	_check(bar.clear(5) and not bar.clear(5) and bar.item_at(5) == "", "limpar")
	_check(bar.item_at(-1) == "" and bar.item_at(99) == "", "leitura fora da faixa devolve vazio")


func _test_hotbar_save_is_validated() -> void:
	var bar: HotbarComponent = _track.call(HotbarComponent.new())
	bar.assign(1, Items.MEAT)
	var copy: HotbarComponent = _track.call(HotbarComponent.new())
	copy.from_dict(JSON.parse_string(JSON.stringify(bar.to_dict())))
	_check(copy.item_at(1) == Items.MEAT and copy.item_at(0) == "", "atalhos vão e voltam pelo JSON")
	var heard := [0]
	copy.changed.connect(func() -> void: heard[0] += 1)
	copy.from_dict({"slots": ["fern"]})
	_check(heard[0] == 1 and copy.item_at(0) == Items.FERN, "from_dict emite changed (a barra se redesenha)")
	copy.from_dict({"slots": "lixo"})
	_check(heard[0] == 1, "save inválido não emite changed")
	copy.from_dict(bar.to_dict())
	_check(copy.item_at(1) == Items.MEAT, "slots que não é Array mantém o atual")
	copy.from_dict({"slots": [null, 5, ["x"], "inexistente", "fern", "fern", "berry", "meat", "berry", "fern", "berry", "extra"]})
	_check(copy.item_at(0) == "" and copy.item_at(3) == "" and copy.item_at(4) == Items.FERN
			and copy.item_at(5) == "" and copy.item_at(6) == Items.BERRY and copy.item_at(7) == Items.MEAT,
			"entradas inválidas, repetidas e desconhecidas são descartadas")
	_check(copy.to_dict()["slots"].size() == HotbarComponent.SLOT_COUNT, "excesso além de 9 é cortado")
	var player := _player()
	player.from_dict({"hotbar": 5})
	_check(player.hotbar.item_at(0) == Items.BERRY, "Player: hotbar inválido mantém os atalhos iniciais")
	player.from_dict({"hotbar": {"slots": ["fern"]}})
	_check(player.hotbar.item_at(0) == Items.FERN and player.hotbar.item_at(1) == "", "Player restaura a barra do save")


## O `Player.to_dict` leva a barra: sem a chave, o restaurado ficaria com os atalhos iniciais.
func _test_player_save_carries_hotbar() -> void:
	var original := _player()
	original.hotbar.assign(8, Items.MEAT)
	var restored := _player()
	restored.from_dict(JSON.parse_string(JSON.stringify(original.to_dict())))
	_check(restored.hotbar.item_at(8) == Items.MEAT and restored.hotbar.item_at(1) == "" and restored.hotbar.item_at(0) == Items.BERRY,
			"a barra de atalhos vai e volta pelo save do jogador")


func _test_player_rules_data() -> void:
	var player := _player()
	var rules: PlayerRules = load("res://data/balance/player_rules.tres")
	_check(player.rules == rules and is_equal_approx(rules.hunger_decay_per_second, 0.2) and rules.food_cooldown == 0.5
			and rules.winded_ratio == 0.25, "dados: queda de fome 0,2/s, recarga 0,5 s, ofego 25%")
	_check(is_equal_approx(player.hunger.decay_per_second, 0.2), "o jogador aplica a queda de fome dos dados")
	var custom: Player = PlayerScene.instantiate()
	custom.rules = rules.duplicate()
	custom.rules.winded_ratio = 0.5
	custom.rules.hunger_decay_per_second = 0.3
	_root.add_child(custom)
	_track.call(custom)
	custom.set_physics_process(false)
	_check(custom.stamina.rules == custom.rules and custom.hunger.decay_per_second == 0.3,
			"regras trocadas na cena chegam à stamina e à fome")
	_check(rules.hunger_restore_of(Items.BERRY) == 25.0 and rules.hunger_restore_of("inexistente") == 0.0, "saciedade vem dos dados")
	var stamina: StaminaComponent = _track.call(StaminaComponent.new())
	stamina.rules = rules.duplicate()
	stamina.rules.winded_ratio = 0.5
	stamina.current_stamina = 40.0
	_check(stamina.is_winded(), "o limiar de ofego vem dos dados")


func _test_use_item_eating() -> void:
	var player := _player()
	_check(player.hotbar.item_at(0) == Items.BERRY and player.hotbar.item_at(1) == Items.MEAT,
			"atalhos iniciais seguem os itens iniciais")
	var eaten: Array[String] = []
	player.ate.connect(func(id: String) -> void: eaten.append(id))
	_check(not player.request_use_item(0), "fome cheia: não come, não gasta")
	_check(player.inventory.count(Items.BERRY) == 10 and eaten.is_empty(), "nada foi consumido")
	player.hunger.current_hunger = 50.0
	_check(player.request_use_item(0), "come a baga do atalho 1")
	_check(is_equal_approx(player.hunger.current_hunger, 75.0) and player.inventory.count(Items.BERRY) == 9
			and eaten == [Items.BERRY], "baga: +25 de fome, -1 no estoque")
	_check(not player.request_use_item(1), "recarga de 0,5 s depois de comer")
	player.tick(0.5)
	_check(player.request_use_item(1) and is_equal_approx(player.hunger.current_hunger, 100.0),
			"passada a recarga, come a carne (limitado a 100)")
	player.hunger.current_hunger = 10.0
	player.tick(0.5)
	_check(not player.request_use_item(4) and not player.request_use_item(-1) and not player.request_use_item(9),
			"posição vazia ou fora da faixa não faz nada")
	player.inventory.remove(Items.FERN, 3)
	player.tick(0.5)
	_check(not player.request_use_item(2) and player.hotbar.item_at(2) == Items.FERN,
			"sem estoque: não usa e o atalho continua atribuído")
	player.inventory.add(Items.FERN, 1)
	_check(player.request_use_item(2) and is_equal_approx(player.hunger.current_hunger, 25.0), "estoque volta, o atalho volta a valer")
	player.tick(0.5)
	player.input_locked = true
	_check(not player.request_use_item(0), "tela aberta: não usa")
	player.input_locked = false
	player.health.take_damage(1000.0)
	_check(not player.request_use_item(0), "jogador morto: não usa")


## Decisão do dono: a tecla sempre faz o jogador consumir, mesmo com dino dormindo no alvo.
func _test_use_item_with_sleeping_dino_in_reach() -> void:
	var player := _player()
	player.hunger.current_hunger = 10.0
	var dino := _sleeping_dino_at(10)
	_aim(player, dino)
	_check(player.target == dino.interactable and dino.interactable.can_interact(), "preparo: dino dormindo é o alvo")
	_check(player.request_use_item(0), "a tecla com dino dormindo no alvo come")
	_check(is_equal_approx(player.hunger.current_hunger, 35.0) and player.inventory.count(Items.BERRY) == 9
			and dino.inventory.count(Items.BERRY) == 0, "o jogador come a baga; nada vai para o dino")
	player.tick(0.5)
	_check(player.target == dino.interactable, "o alvo continua depois do tick")
	player.hunger.current_hunger = player.hunger.max_hunger
	_check(not player.request_use_item(0) and player.inventory.count(Items.BERRY) == 9 and dino.inventory.count(Items.BERRY) == 0,
			"fome cheia com dino no alvo: não gasta e não entrega")
	player.hunger.current_hunger = 20.0
	player.tick(0.5)
	var awake := _spawn_dino()
	awake.set_physics_process(false)
	_aim(player, awake)
	_check(player.request_use_item(0) and awake.inventory.count(Items.BERRY) == 0, "dino acordado no alvo: também come")
	# Item que não é comida (sem saciedade) não faz nada.
	player.tick(0.5)
	_check(not player.request_use_item(8), "posição vazia: nada")
	# Item sem saciedade nos dados não é comida: a tecla não o gasta.
	player.tick(0.5)
	var shared_rules := player.rules
	player.rules = shared_rules.duplicate(true)
	player.rules.hunger_restore.erase(Items.FERN)
	_check(shared_rules.hunger_restore.has(Items.FERN), "o teste não altera o recurso compartilhado dos dados")
	player.hunger.current_hunger = 10.0
	_check(not player.request_use_item(2) and player.inventory.count(Items.FERN) == 3 and player.hunger.current_hunger == 10.0,
			"item não comestível não é gasto pela tecla")


func _test_hotbar_keys_and_input_map() -> void:
	var player := _player()
	player.hunger.current_hunger = 10.0
	player._unhandled_input(_action("hotbar_2"))
	_check(player.inventory.count(Items.MEAT) == 3 and is_equal_approx(player.hunger.current_hunger, 50.0),
			"tecla 2 usa o atalho da posição 2 (carne)")
	player.tick(0.5)
	player._unhandled_input(_action("hotbar_9"))
	_check(player.inventory.count(Items.MEAT) == 3, "tecla 9 (vazia) não faz nada")
	# Mapa de entrada: as 9 teclas existem e nenhuma outra ação usa a mesma tecla.
	var taken: Dictionary = {}
	for action in InputMap.get_actions():
		if str(action).begins_with("ui_"):
			continue
		for event in InputMap.action_get_events(action):
			if event is InputEventKey:
				taken[event.physical_keycode] = taken.get(event.physical_keycode, []) + [str(action)]
	var clean := true
	for number in range(1, 10):
		var users: Array = taken.get(KEY_0 + number, [])
		clean = clean and users == ["hotbar_%d" % number]
	_check(clean, "teclas 1 a 9 só pertencem aos atalhos (sem conflito com o resto do mapa)")


func _test_hud_layout_and_xp_hook() -> void:
	var player := _player()
	var hud := PlayerHud.new()
	hud.player = player
	_root.add_child(hud)
	_track.call(hud)
	var bars: Array[StatBar] = []
	var pending: Array[Node] = [hud]
	var stamina_tooltips := 0
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		pending.append_array(node.get_children())
		if node is StatBar:
			bars.append(node)
		if node is Control and (node as Control).tooltip_text == "Stamina":
			stamina_tooltips += 1
	_check(bars.size() == 3 and stamina_tooltips == 0 and not ("_stamina_bar" in hud), "HUD só tem 3 barras (vida, fome, XP): sem stamina")
	_check(hud.xp_label().text == "Nv 1" and hud.xp_bar().value() == 0.0, "XP: ponto de ligação mostra Nv 1 e XP 0")
	hud.set_experience(3, 40.0, 100.0)
	_check(hud.xp_label().text == "Nv 3" and hud.xp_bar().value() == 40.0 and hud.xp_bar().max_value() == 100.0,
			"set_experience liga a barra")
	var bar := hud.hotbar_bar()
	_check(bar.count_text(0) == "10" and bar.count_text(1) == "4" and bar.count_text(5) == "", "atalhos mostram a quantidade")
	_check(not bar.is_dimmed(0) and not bar.is_dimmed(5), "com estoque ou sem atribuição, não apaga")
	player.inventory.remove(Items.FERN, 3)
	_check(bar.count_text(2) == "0" and bar.is_dimmed(2) and player.hotbar.item_at(2) == Items.FERN,
			"sem estoque: apagado mas atribuído")
	player.inventory.add(Items.FERN, 2)
	_check(bar.count_text(2) == "2" and not bar.is_dimmed(2), "volta quando há estoque")
	player.hotbar.assign(8, Items.FERN)
	_check(bar.count_text(8) == "2" and bar.count_text(2) == "" and bar.slot_button(8).icon != null, "atribuir mostra ícone e soma")


func _test_inventory_assigns_hotbar() -> void:
	var player := _player()
	var screen := InventoryScreen.new()
	screen.hotbar = player.hotbar
	_root.add_child(screen)
	_track.call(screen)
	var requests: Array = []
	screen.hotbar_assign_requested.connect(func(slot: int, item_id: String, iid: String) -> void: requests.append([slot, item_id, iid]))
	screen.open_with(player.inventory, null, null, "")
	var cell := screen.slot_button(true, 0).text
	_check(cell.begins_with("Baga") and cell.contains("[1] "), "a célula mostra a tecla do atalho")
	_check(player.hotbar.changed.is_connected(screen._refresh), "aberta, a tela escuta hotbar.changed")
	player.hotbar.assign(4, Items.BERRY)
	_check(screen.slot_button(true, 0).text.contains("[5] "), "e redesenha a tecla quando a barra muda")
	player.hotbar.assign(0, Items.BERRY)
	screen.assign_to_hotbar(1, 6)
	_check(requests == [[6, Items.MEAT, ""]], "pedido de atribuição por teclado leva o tipo do item do slot")
	requests.clear()
	screen.slot_button(true, 1).grab_focus()
	_check(screen.cursor_slot() == 1, "o foco define o item sob o cursor")
	screen._unhandled_input(_action("hotbar_4"))
	_check(requests == [[3, Items.MEAT, ""]], "tecla 4 com o foco no slot 1 atribui a carne à posição 4")
	requests.clear()
	var staff_iid: String = player.inventory.get_slot(3)["iid"]
	screen.assign_to_hotbar(3, 7)
	_check(requests == [[7, Items.SLEEP_STAFF, staff_iid]], "o Bastão vai por iid (a barra segue o item)")
	requests.clear()
	screen.toggle_hotbar(5)
	_check(requests.is_empty(), "slot vazio não gera pedido")
	player.hotbar.clear(2)
	screen.toggle_hotbar(2)
	_check(requests == [[2, Items.FERN, ""]], "botão direito: primeira posição livre")
	requests.clear()
	screen.toggle_hotbar(0)
	_check(requests == [[0, "", ""]], "botão direito num item já atribuído pede para tirar")
	screen.close()
	_check(not player.hotbar.changed.is_connected(screen._refresh), "fechada, a tela solta o hotbar.changed")
	screen.assign_to_hotbar(0, 1)
	_check(requests.size() == 1, "fechada, a tela não pede nada")
	# O mundo liga o pedido ao componente (como a `Main`).
	var wired := Main.new()
	wired.player = player
	wired._on_hotbar_assign_requested(8, Items.BERRY, "")
	_check(player.hotbar.item_at(8) == Items.BERRY and player.hotbar.item_at(0) == "", "a Main aplica a atribuição")
	wired._on_hotbar_assign_requested(8, "", "")
	_check(player.hotbar.item_at(8) == "", "e a limpeza")
	wired.free()


func _test_winded_and_sprint_stop() -> void:
	var stamina: StaminaComponent = _track.call(StaminaComponent.new())
	_check(not stamina.is_winded() and stamina.winded_intensity() == 0.0, "cheio: sem fôlego curto")
	stamina.current_stamina = 25.0
	_check(not stamina.is_winded(), "exatamente 25%: ainda não")
	stamina.current_stamina = 24.0
	_check(stamina.is_winded(), "abaixo de 25%: ofegante")
	stamina.current_stamina = 12.5
	_check(is_equal_approx(stamina.winded_intensity(), 0.5), "intensidade cresce até zerar")
	stamina.current_stamina = 0.0
	_check(is_equal_approx(stamina.winded_intensity(), 1.0), "zerado: intensidade 1")
	# Zerar: para de correr e só volta depois de ~1,3 s.
	var player := _player()
	var ticks := 0
	while player.stamina.can_sprint() and ticks < 100:
		player.apply_input(Vector2.RIGHT, true, 0.1)
		ticks += 1
	_check(player.stamina.is_exhausted and player.stamina.current_stamina == 0.0, "sprint zera e exaure (%d ticks)" % ticks)
	var walking := player.apply_input(Vector2.RIGHT, true, 0.1)
	_check(walking.length() == player.walk_speed, "exausto: anda a velocidade de caminhada mesmo apertando correr")
	var waited := 0.1
	while not player.stamina.can_sprint() and waited < 5.0:
		player.apply_input(Vector2.RIGHT, true, 0.1)
		waited += 0.1
	_check(waited >= 1.3 and waited <= 1.6, "volta a correr em cerca de 1,3 s (%.1f s)" % waited)


func _test_player_view_breath_and_damage() -> void:
	var player := _player()
	var view := PlayerView.new()
	view.player = player
	_root.add_child(view)
	_track.call(view)
	var cues: Array[StringName] = []
	view.sound_cue.connect(func(cue: StringName) -> void: cues.append(cue))
	# Dano recebido: número flutuante e sinal de som.
	player.health.take_damage(7.0)
	_check(view.popup_count() == 1 and cues == [PlayerView.CUE_HURT], "dano recebido: número flutuante e som")
	var text: Label = view._popups.get_child(0)
	_check(text.text == "-7", "o número mostra o dano (-7)")
	# Acima de 25%: silêncio.
	player.stamina.current_stamina = 30.0
	cues.clear()
	for i in 30:
		view.tick(0.1)
	_check(cues.is_empty(), "acima de 25% não ofega")
	# Abaixo de 25%: sopros, mais rápidos e agudos perto de zerar.
	player.stamina.current_stamina = 20.0
	for i in 30:
		view.tick(0.1)
	var slow_count := cues.count(PlayerView.CUE_PANT)
	var slow_pitch: float = view.breath_player().pitch_scale
	cues.clear()
	player.stamina.current_stamina = 4.0
	for i in 30:
		view.tick(0.1)
	var fast_count := cues.count(PlayerView.CUE_PANT)
	_check(slow_count >= 2 and fast_count > slow_count, "sopros ficam mais frequentes (%d -> %d em 3 s)" % [slow_count, fast_count])
	_check(view.breath_player().pitch_scale > slow_pitch, "e mais agudos")
	_check(view.breath_player().stream != null, "o placeholder de fôlego existe")
	# Deixa o relógio dos sopros adiantado (logo depois de um sopro) para provar o zeramento.
	var seen := cues.size()
	var guard := 0
	while cues.size() == seen and guard < 100:
		view.tick(0.05)
		guard += 1
	for i in 5:
		view.tick(0.05)
	# Ao zerar: fôlego longo e nuvem.
	_check(not view.is_cloud_active(), "antes de zerar, sem nuvem")
	cues.clear()
	player.stamina.tick(10.0, true)
	_check(cues.has(PlayerView.CUE_GASP) and view.is_cloud_active(), "zerou: fôlego longo e nuvem de suor")
	var gasp_stream := view.breath_player().stream
	cues.clear()
	var gasp_length := gasp_stream.get_length()
	var held := true
	for i in int(gasp_length * 10.0) - 1:
		view.tick(0.1)
		held = held and view.breath_player().stream == gasp_stream
	_check(held and not cues.has(PlayerView.CUE_PANT) and gasp_length > 0.5,
			"o fôlego longo toca inteiro (%.1f s), sem sopro por cima" % gasp_length)
	cues.clear()
	view.tick(0.1)
	view.tick(0.1)
	_check(not cues.has(PlayerView.CUE_PANT), "o relógio dos sopros recomeça do zero depois do fôlego longo")
	for i in 20:
		view.tick(0.1)
	_check(cues.has(PlayerView.CUE_PANT), "depois do fôlego longo, os sopros voltam")
	player.health.take_damage(1000.0)
	cues.clear()
	for i in 30:
		view.tick(0.1)
	_check(not cues.has(PlayerView.CUE_PANT), "morto não ofega")
	view.cue_streams.clear()
	view.breath_player().stop()
	view.breath_player().stream = null


## Pontos baixos do `LEVI`: save lixo com dino dormindo, Player e barras.
func _test_review_low_points() -> void:
	# 1) Dino dormindo com progresso e relógio de refeição reais, e um save lixo por cima.
	var dino := _sleeping_dino_at(10)
	dino.inventory.add(dino.taming.ideal_food, 3)
	dino.taming.tick(dino.taming.seconds_per_meal * 1.5)
	var progress := dino.taming.taming_progress
	_check(progress > 0.0 and dino.taming.to_dict()["meal_timer"] > 0.0, "preparo: dormindo com progresso e relógio")
	dino.from_dict({"taming": {"progress": NAN, "meal_timer": INF, "efficiency": null}, "torpor": {"current": [1], "pause_clock": "x"},
			"state_machine": "x", "health": {"current": null}})
	_check(is_equal_approx(dino.taming.taming_progress, progress) and is_finite(dino.taming.taming_progress),
			"progress inválido mantém o valor e continua finito")
	_check(dino.taming.to_dict()["meal_timer"] == 0.0 and is_finite(dino.taming.to_dict()["meal_timer"]), "meal_timer inválido vai a 0")
	_check(dino.state_machine.current_id == Enums.DinoStateId.UNCONSCIOUS and dino.torpor.is_unconscious, "segue dormindo e coerente")
	# 2) Player com position que não é Dictionary e starvation_timer inválido.
	var player := _player()
	var start := player.position
	player.from_dict({"position": [1, 2], "health": {"current": 33.0}, "hunger": {"current": 40.0, "starvation_timer": "x"}})
	_check(player.position == start and is_equal_approx(player.health.current_health, 33.0), "position não Dictionary: vida restaurada")
	_check(player.hunger.to_dict()["starvation_timer"] == 0.0 and is_equal_approx(player.hunger.current_hunger, 40.0),
			"starvation_timer inválido vai a 0")
	player.from_dict({"position": 5, "hunger": {"starvation_timer": NAN}})
	_check(player.position == start and player.hunger.to_dict()["starvation_timer"] == 0.0, "position número e timer NaN")
	# 3) follow() com o dino só marcado para remoção.
	var victim := _spawn_dino()
	victim.set_physics_process(false)
	var bars := _spawn_bars(victim)
	victim.queue_free()
	_check(victim.is_queued_for_deletion() and is_instance_valid(victim), "dino marcado mas ainda válido")
	_check(not bars.follow() and bars.is_queued_for_deletion(), "follow() agenda a remoção das barras e devolve false")
