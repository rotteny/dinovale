# SPDX-License-Identifier: MIT
class_name SaveTests
extends DinoLevelTests
## SAV-01, UIX-03 e SOB-04: arquivo de save (envelope, escrita atômica, `.bak`, versão, arquivo ruim),
## fixture v1, roundtrip do mundo, gatilhos do `SaveScheduler`, Continuar/Novo jogo e fome do jogador.
## Todo save de teste vai para `ROOT` (user://test_saves), apagado no fim da suíte.

const ROOT := "user://test_saves/run"
const FIXTURE_V1 := "res://tests/fixtures/saves/v1.json"
const R := SaveManager.Reason

var _seq: int = 0


static func remove_tree(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for sub in dir.get_directories():
		remove_tree(path.path_join(sub))
	for file_name in dir.get_files():
		DirAccess.remove_absolute(path.path_join(file_name))
	DirAccess.remove_absolute(path)


func run() -> void:
	_test_migrations()
	_test_world_id()
	_test_fixture_v1()
	_test_roundtrip_identical()
	_test_hostile_files()
	_test_future_version()
	_test_backup_fallback()
	_test_write_failure_keeps_previous()
	_test_corrupt_main_is_preserved()
	_test_size_limit()
	_test_save_data_files()
	_test_rotation_preserves_unread_files()
	_test_life_field_and_dead_state()
	_test_deep_nesting()
	await _test_autosave_interval()
	await _test_pause_does_not_count()
	await _test_coalescing()
	await _test_triggers_on_main()
	await _test_write_failure_is_not_fatal()
	await _test_retry_after_failure()
	await _test_failure_notice_and_queue_bounded()
	_test_saving_indicator()
	await _test_continue_in_main()
	await _test_continue_failure()
	await _test_title_single_player()
	await _test_hunger_and_warning()
	await _test_save_timing()


# ----------------------------------------------------------------------------- auxiliares

func _manager() -> SaveManager:
	_seq += 1
	return SaveManager.new(ROOT, "t%d" % _seq)


func _envelope(label: String = "a") -> Dictionary:
	return SaveManager.make_envelope({"map_id": "main"}, [{"player_id": "local", "entity_id": 1, "state": {}}], [],
			"0.1.0", label)


func _write_raw(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _read_raw(path: String) -> String:
	return FileAccess.get_file_as_string(path)


func _fresh_pair() -> Array:
	var player: Player = PlayerScene.instantiate()
	var dino: Dino = DinoScene.instantiate()
	_root.add_child(player)
	_root.add_child(dino)
	_track.call(player)
	_track.call(dino)
	for node: Node in [player, dino, player.hunger, player.stamina, dino.torpor, dino.taming, dino.state_machine]:
		node.set_physics_process(false)
	return [player, dino]


func _main(world: String, level: int = 20, no_menu: bool = false) -> Main:
	var main: Main = MAIN_SCENE.instantiate()
	main.world_id = world
	main.dino_level = level
	if no_menu:
		main.menu_scene = ""  # a carga que falha trocaria a cena do teste
	_root.add_child(main)
	_track.call(main)
	for node: Node in [main.player, main.player.hunger, main.player.stamina, main.dino, main.dino.torpor, main.dino.taming,
			main.dino.state_machine, main.scheduler]:
		node.set_physics_process(false)
	return main


func _canonical(data: Dictionary) -> String:
	return JSON.stringify(data, "", true)


func _accept_into(pair: Array) -> Callable:
	return func(data: Dictionary) -> bool: return WorldSnapshot.restore(data, pair[0], pair[1])


func _step_a(data: Dictionary) -> Dictionary:
	var next := data.duplicate(true)
	next["a"] = 1
	return next


func _step_b(data: Dictionary) -> Dictionary:
	var next := data.duplicate(true)
	next["b"] = int(data.get("a", 0)) + 1
	return next


func _step_bad(_data: Dictionary) -> Variant:
	return "oops"


# ----------------------------------------------------------------------------- arquivo

func _test_migrations() -> void:
	var table := {1: _step_a, 2: _step_b}
	var input := {"format_version": 1, "x": 5}
	var out := SaveMigrations.migrate(input, 3, table)
	_check(out.get("format_version") == 3 and out.get("a") == 1 and out.get("b") == 2 and out.get("x") == 5,
			"migrações encadeiam v1 -> v2 -> v3 e guardam o resto")
	_check(input == {"format_version": 1, "x": 5}, "migração é pura: a entrada não muda")
	_check(SaveMigrations.migrate({"format_version": 2, "x": 5}, 3, table).get("b") == 1, "parte da versão do arquivo")
	_check(SaveMigrations.migrate({"format_version": 1}, 3, {1: _step_a}).is_empty(), "salto que falta no caminho: recusa")
	_check(SaveMigrations.migrate({"format_version": 1}, 2, {1: _step_bad}).is_empty(), "salto que não devolve dicionário: recusa")
	_check(SaveMigrations.migrate({"format_version": 4}, 3, table).is_empty(), "versão maior que o alvo: recusa")
	_check(SaveMigrations.migrate({"format_version": "x"}, 3, table).is_empty() and SaveMigrations.migrate({}, 3, table).is_empty(),
			"versão ausente ou inválida: recusa")
	var current := _envelope()
	_check(SaveMigrations.migrate(current) == current, "na versão atual não há nada a migrar")


func _test_world_id() -> void:
	_check(SaveManager.is_valid_world_id("main") and SaveManager.is_valid_world_id("mundo-2_b"), "ids de mundo válidos")
	_check(not SaveManager.is_valid_world_id("../x") and not SaveManager.is_valid_world_id("") and not SaveManager.is_valid_world_id("A")
			and not SaveManager.is_valid_world_id("a/b") and not SaveManager.is_valid_world_id("x".repeat(65)),
			"id de mundo com caminho ou fora do padrão é inválido")
	var sneaky := SaveManager.new(ROOT, "../fora")
	_check(sneaky.main_path() == ROOT + "/main/world.json", "id inválido cai no mundo padrão (sem sair da pasta)")


func _test_fixture_v1() -> void:
	var manager := SaveManager.new(ROOT)
	var outcome := manager.read_file(FIXTURE_V1)
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE_V1))
	_check(outcome.status == SaveManager.Status.OK and (raw as Dictionary).get("format_version") == 1
			and outcome.data.get("format_version") == SaveMigrations.CURRENT_VERSION, "fixture v1 carrega e é migrada para a versão atual")
	_check((outcome.data["world"]["resource_nodes"] as Array).is_empty() and outcome.data["world"]["respawn_count"] == 0,
			"a migração v1 para v2 acrescenta os campos novos vazios")
	var pair := _fresh_pair()
	var player: Player = pair[0]
	var dino: Dino = pair[1]
	_check(WorldSnapshot.restore(outcome.data, player, dino), "fixture v1 é aplicada ao mundo")
	_check(player.position == Vector2(120.5, 88.0) and player.health.current_health == 70.0
			and is_equal_approx(player.hunger.current_hunger, 40.0), "fixture: posição, vida e fome do jogador")
	_check(player.inventory.count("berry") == 7 and player.equipment.iid_in(EquipmentLayout.WEAPON) == "p1"
			and player.hotbar.slot_of_iid("p1") == 3, "fixture: inventário, equipamento individual e barra")
	_check(dino.level == 28 and dino.health.current_health == 159.0 and dino.inventory.count("berry") == 5
			and dino.state_machine.current_id == Enums.DinoStateId.UNCONSCIOUS, "fixture: nível, vida, comida e sono do dino")
	_check(is_equal_approx(dino.taming.efficiency, 87.8279069767442) and is_equal_approx(dino.taming.taming_progress, 28.571428571428),
			"fixture: Eficiência e progresso da domesticação")


func _test_roundtrip_identical() -> void:
	var pair := _fresh_pair()
	var player: Player = pair[0]
	var dino: Dino = pair[1]
	player.position = Vector2(12.25, 34.5)
	player.health.take_damage(30.0)
	player.hunger.current_hunger = 33.0
	player.inventory.remove("berry", 3)
	player.request_use_item(3)
	dino.level = 24
	dino.inventory.add("berry", 6)
	dino.torpor.add_torpor(100000.0)
	dino.take_damage(2.0, TamingRules.ATTACKER_PLAYER)
	dino.taming.tick(11.0)
	var saved := WorldSnapshot.capture(player, dino, "0.1.0", "t")
	var manager := _manager()
	_check(manager.write(saved), "grava o mundo")
	var other := _fresh_pair()
	var outcome := manager.load_first(_accept_into(other))
	_check(outcome.status == SaveManager.Status.OK and not outcome.from_backup, "carrega o que gravou")
	var again := WorldSnapshot.capture(other[0], other[1], "0.1.0", "t")
	_check(_canonical(again) == _canonical(saved), "roundtrip: estado idêntico (jogador, dino com nível e Eficiência, mundo)")
	var from_file := manager.read_file(manager.main_path()).data
	var parsed: Dictionary = JSON.parse_string(JSON.stringify(saved))
	var same_file := true
	for key in ["world", "players", "entities"]:
		same_file = same_file and _canonical({"k": from_file[key]}) == _canonical({"k": parsed[key]})
	_check(same_file, "o arquivo guarda exatamente o que foi capturado")
	var restored: Dino = other[1]
	_check(restored.level == 24 and restored.taming.efficiency < 100.0 and restored.taming.taming_progress > 0.0,
			"nível e Eficiência voltam")


func _test_hostile_files() -> void:
	var manager := _manager()
	var path := manager.main_path()
	var bad: Array[String] = [
		"", "[1,2]", '"oi"', "null", "{", "{}", '{"format_version":"x"}', '{"format_version":0}', '{"format_version":1.5}',
		'{"format_version":-3}', '{"format_version":1}',
		'{"format_version":1,"world":[],"players":[],"entities":[]}',
		'{"format_version":1,"world":{},"players":[1],"entities":[]}',
		'{"format_version":1,"world":{},"players":[],"entities":[{"id":1,"type":"dino"}]}',
		'{"format_version":1,"world":{},"players":[],"entities":[{"id":-1,"type":"dino","state":{}}]}',
		'{"format_version":1,"world":{},"players":[{"state":{}}],"entities":[]}',
		"[".repeat(5000), "\u0001garbage\u0002",
	]
	var all_corrupt := true
	for text in bad:
		_write_raw(path, text)
		var outcome := manager.read_file(path)
		if outcome.status != SaveManager.Status.CORRUPT or outcome.message == "":
			all_corrupt = false
			printerr("  arquivo ruim não recusado: ", text.left(60))
	_check(all_corrupt, "arquivos ruins (vazio, tipo errado, versão inválida, faltando campo, aninhamento) são recusados sem abortar")
	_check(manager.load_first(func(_d: Dictionary) -> bool: return true).status == SaveManager.Status.CORRUPT
			and _read_raw(path) == "\u0001garbage\u0002", "sem saída: avisa e o arquivo continua como estava")
	var binary := FileAccess.open(path, FileAccess.WRITE)
	binary.store_buffer(PackedByteArray([123, 0, 255, 0, 125]))
	binary.close()
	_check(manager.read_file(path).status == SaveManager.Status.CORRUPT, "binário com NUL: recusado")
	_check(manager.read_file(ROOT + "/nao_existe.json").status == SaveManager.Status.NONE, "ausente é NONE")


func _test_future_version() -> void:
	var manager := _manager()
	_check(manager.write(_envelope("antigo")) and manager.write(_envelope("recente")), "prepara principal e cópia")
	var future := _envelope("futuro")
	future["format_version"] = SaveMigrations.CURRENT_VERSION + 1
	var future_text := JSON.stringify(future)
	_write_raw(manager.main_path(), future_text)
	var calls: Array[int] = [0]
	var outcome := manager.load_first(func(_d: Dictionary) -> bool:
		calls[0] += 1
		return true)
	_check(outcome.status == SaveManager.Status.FUTURE_VERSION and outcome.message.contains("mais nova") and calls[0] == 0,
			"versão maior que a do jogo: recusa explícita, sem aplicar nada")
	_check(not outcome.from_backup and _read_raw(manager.main_path()) == future_text, "recusa não cai no .bak e não toca no arquivo")
	_check(manager.probe().status == SaveManager.Status.FUTURE_VERSION, "o menu enxerga a recusa")


func _test_backup_fallback() -> void:
	var manager := _manager()
	_check(manager.write(_envelope("um")), "primeiro save")
	_check(not FileAccess.file_exists(manager.backup_path()), "primeiro save não cria .bak")
	_check(manager.write(_envelope("dois")), "segundo save")
	_check(manager.read_file(manager.backup_path()).data.get("saved_at") == "um"
			and manager.read_file(manager.main_path()).data.get("saved_at") == "dois", ".bak guarda a versão anterior")
	_check(manager.write(_envelope("tres")) and manager.read_file(manager.backup_path()).data.get("saved_at") == "dois",
			"o .bak anterior é trocado, sem acumular")
	_write_raw(manager.temp_path(), "lixo de uma queda no meio da escrita")
	_check(manager.load_first(func(_d: Dictionary) -> bool: return true).data.get("saved_at") == "tres", ".tmp que sobrou é ignorado")
	var text := _read_raw(manager.main_path())
	_write_raw(manager.main_path(), text.left(text.length() / 2))
	var truncated := _read_raw(manager.main_path())
	var outcome := manager.load_first(func(_d: Dictionary) -> bool: return true)
	_check(outcome.status == SaveManager.Status.OK and outcome.from_backup and outcome.data.get("saved_at") == "dois"
			and outcome.message != "", "principal truncado: carrega o .bak e avisa")
	_check(_read_raw(manager.main_path()) == truncated, "o arquivo truncado não é apagado nem reescrito")
	var refused := manager.load_first(func(data: Dictionary) -> bool: return data.get("saved_at") != "dois")
	_check(refused.status == SaveManager.Status.CORRUPT, "o jogo recusa o .bak também: sem saída")
	_write_raw(manager.backup_path(), "{")
	var none := manager.load_first(func(_d: Dictionary) -> bool: return true)
	_check(none.status == SaveManager.Status.CORRUPT and none.message.contains("mantidos")
			and FileAccess.file_exists(manager.main_path()) and FileAccess.file_exists(manager.backup_path()),
			"principal e cópia ruins: avisa e não apaga nada")
	var gone := _manager()
	_check(gone.load_first(func(_d: Dictionary) -> bool: return true).status == SaveManager.Status.NONE and not gone.has_files(),
			"sem arquivo algum: NONE")
	_check(manager.write(_envelope("quatro")) and manager.probe().status == SaveManager.Status.OK, "dá para gravar por cima de tudo ruim")


func _test_write_failure_keeps_previous() -> void:
	var manager := _manager()
	_check(manager.write(_envelope("bom")), "save bom")
	var before := _read_raw(manager.main_path())
	DirAccess.make_dir_recursive_absolute(manager.temp_path())  # o .tmp é uma pasta: não dá para abrir para escrita
	_check(not manager.write(_envelope("novo")) and manager.last_error != "", "falha de escrita devolve false com o motivo")
	_check(_read_raw(manager.main_path()) == before and manager.read_file(manager.main_path()).status == SaveManager.Status.OK
			and not FileAccess.file_exists(manager.backup_path()), "o save anterior continua intacto")
	DirAccess.remove_absolute(manager.temp_path())
	_check(manager.write(_envelope("novo")) and manager.last_error == "", "passada a falha, grava normalmente")
	_check(not manager.write({}) and manager.last_error.contains("inválido"), "envelope inválido nem chega ao disco")
	_check(manager.read_file(manager.main_path()).data.get("saved_at") == "novo", "envelope inválido não mexeu no save")


func _test_corrupt_main_is_preserved() -> void:
	var manager := _manager()
	manager.write(_envelope("um"))
	manager.write(_envelope("dois"))
	_write_raw(manager.main_path(), "{truncado")
	_check(manager.write(_envelope("tres")), "grava por cima de um principal danificado")
	_check(manager.read_file(manager.backup_path()).data.get("saved_at") == "um", "a cópia boa não é trocada pelo arquivo danificado")
	_check(_read_raw(manager.main_path() + SaveManager.REJECTED_SUFFIX) == "{truncado", "o arquivo danificado é guardado ao lado, não apagado")


func _test_size_limit() -> void:
	var manager := _manager()
	manager.max_bytes = 100
	_check(not manager.write(_envelope("x".repeat(500))) and manager.last_error.contains("limite") and not manager.has_files(),
			"gravar além do limite é recusado antes de criar arquivo")
	_write_raw(manager.main_path(), JSON.stringify(_envelope("x".repeat(500))))
	var outcome := manager.read_file(manager.main_path())
	_check(outcome.status == SaveManager.Status.CORRUPT and outcome.message.contains("grande"),
			"ler arquivo acima do limite: recusa antes do parse")
	_check(SaveManager.MAX_FILE_BYTES == 64 * 1024 * 1024, "limite padrão de 64 MiB (ADR-002)")


func _test_save_data_files() -> void:
	var rules: SaveRules = load("res://data/balance/save_rules.tres")
	_check(is_equal_approx(rules.autosave_interval_seconds, 300.0), "intervalo do autosave: 300 s, em dado")


# ----------------------------------------------------------------------------- gatilhos

func _scheduler(interval: float, world: String, physics: bool = false) -> SaveScheduler:
	var pair := _fresh_pair()
	_seq += 1
	var scheduler := SaveScheduler.new()
	scheduler.rules = SaveRules.new()
	scheduler.rules.autosave_interval_seconds = interval
	scheduler.player = pair[0]
	scheduler.dino = pair[1]
	scheduler.manager = SaveManager.new(ROOT, world)
	_root.add_child(scheduler)
	_track.call(scheduler)
	scheduler.set_physics_process(physics)  # depois de entrar: o _ready liga sozinho
	return scheduler


func _test_autosave_interval() -> void:
	var tree := _root.get_tree()
	var scheduler := _scheduler(10.0, "auto")
	var reasons: Array[int] = []
	scheduler.saved.connect(func(reason: SaveManager.Reason, _ok: bool, _m: String) -> void: reasons.append(reason))
	scheduler.tick(9.9)
	await tree.process_frame
	_check(scheduler.saves_done == 0 and is_equal_approx(scheduler.elapsed(), 9.9), "antes do intervalo não salva")
	scheduler.tick(0.2)
	_check(scheduler.saves_done == 0, "o save é agendado para o fim do quadro, não no meio do tick")
	await tree.process_frame
	_check(scheduler.saves_done == 1 and reasons == [R.AUTOSAVE] and scheduler.elapsed() == 0.0
			and scheduler.manager.probe().status == SaveManager.Status.OK, "passado o intervalo: autosave, relógio zerado, arquivo válido")
	scheduler.tick(5.0)
	scheduler.tick(5.0)
	await tree.process_frame
	_check(scheduler.saves_done == 2, "o intervalo recomeça depois de cada save")
	_check(scheduler.save_now(R.MANUAL) and scheduler.elapsed() == 0.0, "um save manual também zera a contagem")


func _test_pause_does_not_count() -> void:
	var tree := _root.get_tree()
	var scheduler := _scheduler(1000.0, "pausa", true)
	await tree.physics_frame
	await tree.physics_frame
	var running := scheduler.elapsed()
	_check(running > 0.0, "jogando, o relógio do autosave anda (%f)" % running)
	tree.paused = true
	await tree.physics_frame
	var frozen := scheduler.elapsed()
	for _i in 6:
		await tree.physics_frame
	var held := is_equal_approx(scheduler.elapsed(), frozen)
	tree.paused = false
	_check(held, "pausado não conta")
	for _i in 3:
		await tree.physics_frame
	_check(scheduler.elapsed() > frozen, "ao despausar volta a contar")
	scheduler.set_physics_process(false)


func _test_coalescing() -> void:
	var tree := _root.get_tree()
	var scheduler := _scheduler(1000.0, "coalesce")
	var events: Array[int] = []
	scheduler.saved.connect(func(reason: SaveManager.Reason, _ok: bool, _m: String) -> void: events.append(reason))
	scheduler.request(R.AUTOSAVE)
	scheduler.request(R.PLAYER_DEATH)
	scheduler.request(R.TAMED_DINO_DEATH)
	scheduler.request(R.AUTOSAVE)
	_check(scheduler.saves_done == 0, "nada grava antes do fim do quadro")
	await tree.process_frame
	_check(scheduler.saves_done == 1 and events == [R.PLAYER_DEATH], "gatilhos seguidos viram um save só, com o motivo de maior prioridade")
	scheduler.request(R.AUTOSAVE)
	_check(scheduler.save_now(R.BED) and scheduler.saves_done == 2 and events.back() == R.BED,
			"Salvar na hora leva junto o que estava agendado")
	await tree.process_frame
	_check(scheduler.saves_done == 2, "o agendamento que sobrou não grava de novo")
	scheduler.frozen = true
	scheduler.request(R.AUTOSAVE)
	scheduler.request(R.PLAYER_DEATH)
	_check(not scheduler.save_now(R.MANUAL) and not scheduler.save_now(R.EXIT_MENU), "congelado: nenhum gatilho grava")
	await tree.process_frame
	_check(scheduler.saves_done == 2, "congelado: nada foi gravado")
	scheduler.frozen = false
	_check(scheduler.save_now(R.MANUAL), "descongelado, grava de novo")
	# Rajada (GDD 12.1): morte a menos de 10 s do último save espera o prazo e vira um save só, sem se perder.
	var done := scheduler.saves_done
	var pair_player: Player = scheduler.player
	scheduler.tick(1.0)
	scheduler.request(R.PLAYER_DEATH)
	scheduler.request(R.TAMED_DINO_DEATH)
	await tree.process_frame
	_check(scheduler.saves_done == done, "morte a 1 s do último save espera o prazo")
	pair_player.health.take_damage(10000.0)  # o estado muda enquanto espera: o save leva o de AGORA
	scheduler.tick(5.0)
	_check(scheduler.saves_done == done, "aos 6 s ainda dentro do prazo")
	scheduler.tick(4.0)
	_check(scheduler.saves_done == done + 1 and events.back() == R.PLAYER_DEATH, "fechado o prazo, as duas mortes viram um save só")
	var written := scheduler.manager.read_file(scheduler.manager.main_path()).data["players"][0] as Dictionary
	_check(written["life"] == WorldSnapshot.LIFE_DEAD_PENDING_CHOICE, "o save adiado leva o estado de morto: o último estado vai para o disco")
	scheduler.tick(1.0)
	scheduler.request(R.PLAYER_DEATH)
	_check(scheduler.save_now(R.QUIT) and scheduler.saves_done == done + 2, "sair ignora o prazo e leva junto o que estava esperando")
	scheduler.tick(20.0)
	_check(scheduler.saves_done == done + 2, "nada sobra pendente depois de sair")


func _test_triggers_on_main() -> void:
	var tree := _root.get_tree()
	# Salvar da pausa
	var main := _main("trig_pause")
	var button := main.pause.column().button_of(PauseMenu.SAVE)
	_check(button != null, "a pausa tem Salvar")
	button.pressed.emit()
	_check(main.save_manager.probe().status == SaveManager.Status.OK and main.pause.status_text() == "Jogo salvo.",
			"Salvar da pausa grava e avisa na própria pausa")
	# Cama (só o ponto de entrada)
	var bed := _main("trig_bed")
	var bed_reasons: Array[int] = []
	bed.scheduler.saved.connect(func(reason: SaveManager.Reason, _ok: bool, _m: String) -> void: bed_reasons.append(reason))
	_check(bed.save_game(R.BED) and bed_reasons == [R.BED] and bed.save_manager.probe().status == SaveManager.Status.OK,
			"o motivo Cama grava (a Cama em si ainda não existe)")
	# Morte do jogador
	var dying := _main("trig_death")
	var death_reasons: Array[int] = []
	dying.scheduler.saved.connect(func(reason: SaveManager.Reason, _ok: bool, _m: String) -> void: death_reasons.append(reason))
	dying.player.health.take_damage(10000.0)
	_check(dying.player.health.is_dead() and dying.scheduler.saves_done == 0, "o jogador morreu; o save só sai no fim do quadro")
	await tree.process_frame
	_check(death_reasons == [R.PLAYER_DEATH], "morte do jogador grava")
	var on_disk := dying.save_manager.read_file(dying.save_manager.main_path()).data
	var entry: Dictionary = on_disk["players"][0]
	_check(entry["life"] == WorldSnapshot.LIFE_DEAD_PENDING_CHOICE and (entry["state"]["health"]["current"] as float) == 0.0,
			"o arquivo guarda a verdade: morto, escolha pendente")
	var loaded := _fresh_pair()
	_check(dying.save_manager.load_first(_accept_into(loaded)).status == SaveManager.Status.OK, "o save da morte carrega")
	var still_dead: Player = loaded[0]
	_check(still_dead.health.is_dead() and still_dead.inventory.count("berry") == 10,
			"carregar save de morte não desfaz a morte e mantém o inventário")
	GameSession.continue_requested = true
	var resumed := _main("trig_death")
	_check(resumed.pending_death_choice and resumed.player.health.is_dead() and resumed.death_screen.is_open,
			"Continuar com save de morto abre a tela de morte")
	var alive_save := _main("trig_alive")
	alive_save.save_game()
	GameSession.continue_requested = true
	_check(not _main("trig_alive").pending_death_choice, "save de jogador vivo não sinaliza nada")
	# Dino selvagem morre: sem save
	var wild := _main("trig_wild")
	wild.dino.health.take_damage(100000.0)
	await tree.process_frame
	_check(wild.scheduler.saves_done == 0 and not wild.save_manager.has_files(), "dino selvagem que morre não dispara save")
	# Dino domado morre
	var tamed := _main("trig_tamed")
	tamed.dino.torpor.add_torpor(100000.0)
	tamed.dino.state_machine.mark_tamed()
	tamed.dino.health.take_damage(100000.0)
	await tree.process_frame
	_check(tamed.scheduler.saves_done == 1, "dino domado que morre grava")
	var saved := tamed.save_manager.read_file(tamed.save_manager.main_path())
	_check(saved.status == SaveManager.Status.OK and (saved.data["entities"] as Array).is_empty(),
			"o save é tirado depois de o dino sair do mundo: ele não volta ao carregar")
	GameSession.continue_requested = true
	var again := _main("trig_tamed")
	await tree.process_frame
	_check(not is_instance_valid(again.dino) or again.dino.is_queued_for_deletion(), "Continuar: o dino que morreu não reaparece")
	# Morte e autosave no mesmo instante: um save só, e coerente
	var both := _main("trig_both")
	both.scheduler.tick(100000.0)
	both.player.health.take_damage(10000.0)
	await tree.process_frame
	_check(both.scheduler.saves_done == 1 and both.save_manager.probe().status == SaveManager.Status.OK,
			"morte e autosave no mesmo quadro: um save só, válido")


func _test_write_failure_is_not_fatal() -> void:
	var tree := _root.get_tree()
	var main := _main("fail")
	_check(main.save_game(), "save inicial")
	var before := _read_raw(main.save_manager.main_path())
	DirAccess.make_dir_recursive_absolute(main.save_manager.temp_path())
	main.scheduler.request(R.AUTOSAVE)
	await tree.process_frame
	var notice := main.hud.notice_label()
	_check(notice.visible and notice.text.contains("Não foi possível salvar"), "autosave que falha avisa na HUD")
	_check(main.is_inside_tree() and _read_raw(main.save_manager.main_path()) == before, "o jogo segue e o arquivo anterior fica intacto")
	main._on_menu_requested()
	_check(main.pause.status_text().contains("Não foi possível salvar") and tree.current_scene == null,
			"voltar ao menu com a escrita falhando não fecha a partida e avisa na pausa")
	main._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	_check(main._quit_failed_once and main.hud.notice_label().text.contains("Feche de novo"),
			"fechar a janela com a escrita falhando avisa e mantém a janela")
	DirAccess.remove_absolute(main.save_manager.temp_path())
	_check(main.save_game() and main.scheduler.last_message == "Jogo salvo.", "passada a falha, salvar volta a funcionar")
	_check(not main._quit_failed_once, "um save que deu certo zera o 'fechar de novo'")


func _test_continue_in_main() -> void:
	var tree := _root.get_tree()
	var first := _main("cont", 31)
	first.player.position = Vector2(77.0, 88.0)
	first.player.hunger.current_hunger = 33.0
	first.player.inventory.remove("berry", 3)
	first.dino.health.take_damage(12.0)
	first.dino.inventory.add("fern", 2)
	_check(first.save_game(), "salva o primeiro jogo")
	first.player.hunger.current_hunger = 30.0
	_check(first.save_game(), "segundo save (o primeiro vira .bak)")
	GameSession.continue_requested = true
	var second := _main("cont")
	await tree.process_frame
	_check(not GameSession.continue_requested, "o pedido de continuar vale uma vez")
	_check(second.player.position == Vector2(77.0, 88.0) and is_equal_approx(second.player.hunger.current_hunger, 30.0)
			and second.player.inventory.count("berry") == 7 and second.dino.level == 31 and second.dino.inventory.count("fern") == 2
			and second.dino.health.current_health == second.dino.health.max_health - 12.0 and not second.scheduler.frozen,
			"Continuar: jogador, dino e nível voltam ao que foi salvo")
	_check(is_equal_approx(second.hud.hunger_bar().value(), 30.0), "a HUD mostra o estado restaurado")
	var fresh := _main("cont")
	_check(fresh.player.inventory.count("berry") == 10 and fresh.dino.level == 20, "sem pedido de continuar, começa do zero")
	# principal truncado: cai no .bak
	var text := _read_raw(second.save_manager.main_path())
	_write_raw(second.save_manager.main_path(), text.left(text.length() / 3))
	GameSession.continue_requested = true
	var rescued := _main("cont")
	_check(is_equal_approx(rescued.player.hunger.current_hunger, 33.0) and rescued.hud.notice_label().visible
			and rescued.hud.notice_label().text.contains("cópia anterior"), "Continuar com principal truncado usa o .bak e avisa na HUD")


func _dir_files(manager: SaveManager) -> Array[String]:
	var names: Array[String] = []
	var dir := DirAccess.open(manager.main_path().get_base_dir())
	if dir != null:
		for file_name in dir.get_files():
			names.append(file_name)
	names.sort()
	return names


func _preserved(manager: SaveManager) -> Array[String]:
	var texts: Array[String] = []
	for file_name in _dir_files(manager):
		if file_name.begins_with("world.json.rejected"):
			texts.append(_read_raw(manager.main_path().get_base_dir().path_join(file_name)))
	return texts


func _test_continue_failure() -> void:
	var refused := JSON.stringify(SaveManager.make_envelope({"map_id": "main"},
			[{"player_id": "local", "entity_id": 1, "state": {"inventory": 5}}], [], "0.1.0", "x"))
	var cases := [["bad", "{lixo", "Nenhum save utilizável"], ["future", JSON.stringify({"format_version": 99}), "mais nova"],
			["refused", refused, "Nenhum save utilizável"]]
	for case in cases:
		var manager := SaveManager.new(ROOT, case[0])
		_write_raw(manager.main_path(), case[1])
		GameSession.continue_requested = true
		var main := _main(case[0], 20, true)
		var notice := GameSession.take_notice()
		_check(main.scheduler.frozen and notice.contains(case[2]), "%s: Continuar que falha pede voltar ao título com o motivo" % case[0])
		_check(not main.save_game() and not main.scheduler.save_now(R.QUIT), "%s: nada grava" % case[0])
		main.scheduler.request(R.AUTOSAVE)
		main.player.health.take_damage(10000.0)
		await _root.get_tree().process_frame
		_check(_read_raw(manager.main_path()) == case[1] and _dir_files(manager) == ["world.json"],
				"%s: o arquivo recusado sobrevive idêntico e nada novo foi gravado" % case[0])
	GameSession.notice = "O jogo recusou o save."
	var title := _title(ROOT + "/title_notice")
	await _root.get_tree().process_frame
	_check(title.notice_text() == "O jogo recusou o save." and GameSession.notice == "", "o título mostra o motivo uma vez")


func _test_rotation_preserves_unread_files() -> void:
	var manager := _manager()
	var future := JSON.stringify({"format_version": 99, "marca": "futuro"})
	_write_raw(manager.main_path(), future)
	_check(manager.write(_envelope("um")) and manager.write(_envelope("dois")), "dois saves por cima de um principal de versão futura")
	_check(manager.read_file(manager.main_path()).data.get("saved_at") == "dois"
			and manager.read_file(manager.backup_path()).data.get("saved_at") == "um", "o rodízio segue normal com saves válidos")
	_check(_preserved(manager) == [future], "o save futuro continua guardado, fora do rodízio")
	_write_raw(manager.backup_path(), "{bak-ruim")
	_check(manager.write(_envelope("tres")), "grava com o .bak danificado")
	var kept := _preserved(manager)
	_check(kept.size() == 2 and kept.has("{bak-ruim") and kept.has(future),
			"o .bak danificado vai para nome preservado sem sobrescrever o anterior")
	_check(manager.read_file(manager.backup_path()).data.get("saved_at") == "dois", "o principal válido virou o novo .bak")
	_write_raw(manager.backup_path(), future)
	_check(manager.write(_envelope("quatro")) and _preserved(manager).size() == 3, "um .bak de versão futura também é preservado")


func _test_life_field_and_dead_state() -> void:
	for value: Variant in [5, null, [1], {"a": 1}, true, 1.5, "xyz", -1]:
		var pair := _fresh_pair()
		var data := SaveManager.make_envelope({}, [{"player_id": "local", "entity_id": 1, "life": value, "state": {}}], [], "0.1.0", "x")
		_check(WorldSnapshot.restore(data, pair[0], pair[1]) and not (pair[0] as Player).health.is_dead()
				and not WorldSnapshot.was_dead_pending_choice(data), "life %s não aborta e vale vivo" % str(value))
	var odd := SaveManager.make_envelope({}, [5, {"player_id": 7}], [3], "0.1.0", "x")
	_check(not WorldSnapshot.restore(odd, _fresh_pair()[0], null) and not WorldSnapshot.was_dead_pending_choice(odd),
			"entradas que não são dicionário não abortam")
	var pair := _fresh_pair()
	var dead_state := {"health": {"current": 0.0}}
	var dead := SaveManager.make_envelope({}, [{"player_id": "local", "entity_id": 1, "state": dead_state}], [], "0.1.0", "x")
	_check(WorldSnapshot.was_dead_pending_choice(dead) and WorldSnapshot.restore(dead, pair[0], pair[1])
			and (pair[0] as Player).health.is_dead(),
			"vida 0 sem life: carrega morto (a escolha de respawn é a saída)")
	var player: Player = pair[0]
	player.hunger.from_dict({"current": 50.0, "max": 1.0e308})
	player.stamina.from_dict({"current": 20.0, "max": 1.0e308})
	_check(player.hunger.max_hunger == 100.0 and player.stamina.max_stamina == 100.0 and is_equal_approx(player.hunger.current_hunger, 50.0),
			"o max salvo de fome e stamina é ignorado")


func _test_deep_nesting() -> void:
	var manager := _manager()
	var deep := '{"format_version":1,"world":' + "[".repeat(100) + "]".repeat(100) + ',"players":[],"entities":[]}'
	_write_raw(manager.main_path(), deep)
	var outcome := manager.read_file(manager.main_path())
	_check(outcome.status == SaveManager.Status.CORRUPT and outcome.message.contains("aninhada"), "aninhamento excessivo é recusado")
	var nested: Variant = 1
	for _i in 40:
		nested = [nested]
	_check(SaveMigrations.migrate({"format_version": 1, "x": nested}).is_empty(), "migrar dado fundo demais devolve recusa")


# ----------------------------------------------------------------------------- menu

func _action(name: String) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = true
	return event


func _title(save_root: String) -> TitleScreen:
	var title: TitleScreen = load("res://src/ui/TitleScreen.tscn").instantiate()
	title.auto_perform = false
	title.settings_path = ROOT + "/title_settings.json"
	title.save_root = save_root
	_root.add_child(title)
	_track.call(title)
	return title


func _test_title_single_player() -> void:
	var tree := _root.get_tree()
	var root := ROOT + "/title"
	remove_tree(root)
	var title := _title(root)
	await tree.process_frame
	var chosen: Array[String] = []
	title.action_chosen.connect(func(id: String) -> void: chosen.append(id))
	title._input(_action("ui_accept"))
	var single := title.single_menu()
	_check(title.view == "single" and single.button_of(TitleScreen.CONTINUE).disabled and single.selected_id() == TitleScreen.NEW_GAME
			and title.notice_text() == "", "sem save: Continuar desabilitado, Novo jogo selecionado")
	title._input(_action("ui_accept"))
	_check(chosen == [TitleScreen.NEW_GAME] and title.view == "single", "sem save, Novo jogo começa direto (sem confirmação)")
	# com save válido
	_check(SaveManager.new(root).write(_envelope("jogo")), "cria um save")
	var title2 := _title(root)
	await tree.process_frame
	var chosen2: Array[String] = []
	title2.action_chosen.connect(func(id: String) -> void: chosen2.append(id))
	title2._input(_action("ui_accept"))
	_check(not title2.single_menu().button_of(TitleScreen.CONTINUE).disabled and title2.single_menu().selected_id() == TitleScreen.CONTINUE,
			"com save válido: Continuar habilitado e selecionado")
	title2._input(_action("ui_accept"))
	_check(chosen2 == [TitleScreen.CONTINUE], "Continuar pede para continuar")
	chosen2.clear()
	title2._input(_action("ui_down"))
	var opened := Time.get_ticks_msec()
	title2._input(_action("ui_accept"))
	_check(title2.view == "confirm" and chosen2.is_empty() and title2.confirm_text() == TitleScreen.NEW_GAME_WARNING
			and title2.confirm_menu().selected_id() == TitleScreen.CANCEL, "Novo jogo com save pede confirmação, com Cancelar selecionado")
	title2._input(_action("ui_down"))
	title2._input(_action("ui_accept"))
	_check(chosen2.is_empty() and title2.view == "confirm", "o segundo clique de um duplo clique cai na guarda e é ignorado")
	_check(title2.confirm_guard_msec == 500, "a guarda é de 500 ms (maior que a janela de duplo clique de alguns sistemas)")
	while Time.get_ticks_msec() - opened < 350:  # relógio real, o mesmo da guarda
		await tree.process_frame
	title2._input(_action("ui_accept"))
	_check(chosen2.is_empty() and title2.view == "confirm", "aos 350 ms a guarda ainda vale")
	while Time.get_ticks_msec() - opened < 560:
		await tree.process_frame
	title2._input(_action("ui_accept"))
	_check(chosen2 == [TitleScreen.NEW_GAME], "passada a guarda, Começar do zero vale")
	chosen2.clear()
	title2._show("single")
	title2._input(_action("ui_down"))
	title2._input(_action("ui_accept"))
	title2._input(_action("ui_accept"))  # Cancelar
	_check(title2.view == "single" and chosen2.is_empty(), "Cancelar volta sem apagar nada")
	title2._input(_action("ui_down"))
	title2._input(_action("ui_accept"))
	title2._input(_action("ui_cancel"))
	_check(title2.view == "single", "Esc na confirmação volta a Um jogador")
	title2._input(_action("ui_cancel"))
	_check(title2.view == "menu", "Esc em Um jogador volta ao menu")
	_check(SaveManager.new(root).probe().status == SaveManager.Status.OK, "nada disso mexeu no save")
	# principal danificado, cópia boa
	var manager := SaveManager.new(root)
	manager.write(_envelope("segundo"))
	_write_raw(manager.main_path(), "{")
	var title3 := _title(root)
	await tree.process_frame
	title3._input(_action("ui_accept"))
	_check(not title3.single_menu().button_of(TitleScreen.CONTINUE).disabled and title3.notice_text().contains("cópia anterior"),
			"principal danificado com .bak bom: Continuar vale e avisa")
	# nada utilizável
	_write_raw(manager.backup_path(), "{")
	var title4 := _title(root)
	await tree.process_frame
	title4._input(_action("ui_accept"))
	_check(title4.single_menu().button_of(TitleScreen.CONTINUE).disabled and title4.notice_text().contains("Nenhum save utilizável"),
			"nada utilizável: Continuar desabilitado e o motivo na tela")
	title4._input(_action("ui_accept"))
	_check(title4.view == "confirm" and title4.confirm_text() == TitleScreen.UNREADABLE_WARNING,
			"Novo jogo sobre save ilegível pergunta, e diz que ele será guardado")
	remove_tree(root)


# ----------------------------------------------------------------------------- SOB-04

func _test_hunger_and_warning() -> void:
	var pair := _fresh_pair()
	var player: Player = pair[0]
	var rules: PlayerRules = player.rules
	_check(is_equal_approx(rules.hunger_decay_per_second, 0.2) and is_equal_approx(player.hunger.decay_per_second, 0.2),
			"fome do jogador a 0,2/s, vinda do dado")
	player.hunger.tick(499.0)
	_check(player.hunger.current_hunger > 0.0 and not player.hunger.is_starving(), "aos 499 s ainda há saciedade")
	player.hunger.tick(1.0)
	_check(player.hunger.current_hunger <= 0.001, "barra cheia esvazia em 500 s")
	_check(rules.is_hungry(25.0, 100.0) and not rules.is_hungry(26.0, 100.0) and rules.is_hungry(0.0, 100.0) and not rules.is_hungry(5.0, 0.0),
			"o limiar do aviso (25%) vem do dado")
	_check(rules.hunger_warning_ratio * 100.0 / rules.hunger_decay_per_second >= 100.0, "o aviso vem ao menos 100 s antes do dano")
	var main := _main("hunger")
	var label := main.hud.hunger_warning_label()
	_check(not label.visible, "cheio: sem aviso")
	main.player.hunger.from_dict({"current": 30.0})
	_check(not label.visible, "30%: sem aviso")
	var damage: Array[float] = [0.0]
	main.player.health.damaged.connect(func(amount: float) -> void: damage[0] += amount)
	main.player.hunger.from_dict({"current": 25.0})
	_check(label.visible and label.text == PlayerHud.HUNGRY_TEXT and damage[0] == 0.0, "a 25%: aviso, antes de qualquer dano")
	main.player.hunger.from_dict({"current": 0.0})
	_check(label.visible and label.text == PlayerHud.STARVING_TEXT, "zerada: aviso de que está morrendo")
	main.player.hunger.eat(50.0)
	_check(not label.visible, "comer apaga o aviso")


func _test_save_timing() -> void:
	var main := _main("timing")
	var worst := 0
	var total := 0
	var count := 30
	for _i in count:
		main.save_game()
		worst = maxi(worst, main.scheduler.last_duration_usec)
		total += main.scheduler.last_duration_usec
	var size := _read_raw(main.save_manager.main_path()).length()
	print("TEMPO DE SAVE: média %d us, pior %d us, %d bytes (%d saves)" % [total / count, worst, size, count])
	_check(worst < 250000, "um save leva bem menos que um quadro perceptível de engasgo (pior %d us)" % worst)


func _test_retry_after_failure() -> void:
	var tree := _root.get_tree()
	var scheduler := _scheduler(1000.0, "retry")
	var events: Array = []
	scheduler.saved.connect(func(reason: SaveManager.Reason, ok: bool, _m: String) -> void: events.append([reason, ok]))
	DirAccess.make_dir_recursive_absolute(scheduler.manager.temp_path())  # a escrita vai falhar
	scheduler.request(R.PLAYER_DEATH)
	await tree.process_frame
	_check(scheduler.saves_done == 0 and events == [[R.PLAYER_DEATH, false]], "a escrita falhou e avisou")
	scheduler.tick(5.0)
	_check(events.size() == 1, "não martela o disco: espera a pausa mínima")
	DirAccess.remove_absolute(scheduler.manager.temp_path())  # o disco voltou
	scheduler.tick(4.0)
	_check(scheduler.saves_done == 0, "ainda dentro da espera")
	scheduler.tick(2.0)
	_check(scheduler.saves_done == 1 and events.back() == [R.PLAYER_DEATH, true],
			"passada a espera, o pedido que falhou é refeito (sem esperar o intervalo de 1000 s)")
	scheduler.tick(30.0)
	_check(scheduler.saves_done == 1, "e não sobra pedido pendente")


func _test_saving_indicator() -> void:
	var main := _main("saving")
	var label := main.hud.saving_label()
	_check(not label.visible and label.text == PlayerHud.SAVING_TEXT, "sem salvar, o indicador não aparece")
	main.save_game(R.BED)
	_check(label.visible, "salvou: o indicador aparece")
	main.hud.tick(0.5)
	_check(label.visible, "e fica por 1 s")
	main.hud.tick(0.6)
	_check(not label.visible, "some sozinho depois de 1 s")
	main.save_game(R.EXIT_MENU)
	_check(not label.visible, "ao voltar ao menu não pisca (a cena está saindo)")


func _test_failure_notice_and_queue_bounded() -> void:
	var tree := _root.get_tree()
	var scheduler := _scheduler(1.0, "bounded")
	DirAccess.make_dir_recursive_absolute(scheduler.manager.temp_path())
	for _i in 300:
		scheduler.tick(1.0)
		await tree.process_frame
	_check(scheduler.saves_done == 0 and scheduler.pending_count() == 1,
			"durante uma falha longa a fila não cresce (%d)" % scheduler.pending_count())
	var main := _main("notice_once")
	var notice := main.hud.notice_label()
	DirAccess.make_dir_recursive_absolute(main.save_manager.temp_path())
	main.scheduler.request(R.AUTOSAVE)
	await tree.process_frame
	_check(notice.visible and notice.text.contains("Não foi possível salvar"), "a primeira falha avisa")
	notice.visible = false
	for _i in 3:
		main.scheduler.tick(11.0)  # cada retentativa falha de novo, com a mesma mensagem
	_check(not notice.visible and main.scheduler.saves_done == 0, "retentativas que falham não repetem o aviso")
	DirAccess.remove_absolute(main.save_manager.temp_path())
	main.scheduler.tick(11.0)
	_check(main.scheduler.saves_done == 1, "o disco voltou: a retentativa grava")
	DirAccess.make_dir_recursive_absolute(main.save_manager.temp_path())
	main.scheduler.save_now(R.MANUAL)
	_check(notice.visible, "depois de um sucesso, a próxima sequência de falhas avisa de novo")
	DirAccess.remove_absolute(main.save_manager.temp_path())
