# SPDX-License-Identifier: MIT
class_name AttackTargetTests
extends TestSuite
## Alvo do golpe (regra única `AttackTargeting`, usada pelo destaque e pelo ataque), contorno do alvo e a
## configuração de áudio (volumes, mudo, barramentos, música).

const REACH := 48.0
const RULES: ActionRules = preload("res://data/balance/action_rules.tres")


func run() -> void:
	_test_rule()
	_test_hysteresis()
	_test_player_attack_follows_highlight()
	_test_outline()
	_test_audio_settings()
	await _test_music_player()
	await _root.get_tree().process_frame  # o playback da música só é solto num quadro depois; sem isto vaza na saída


func _node_at(x: float, y: float) -> Node2D:
	var node := Node2D.new()
	node.position = Vector2(x, y)
	_track.call(node)
	_root.add_child(node)
	return node


func _pick(facing: Vector2, candidates: Array[Node2D], current: Node2D = null) -> Node2D:
	return AttackTargeting.choose(Vector2.ZERO, facing, REACH, candidates, current, RULES.front_dot_min, RULES.hysteresis_px)


func _test_rule() -> void:
	var near := _node_at(10.0, 0.0)
	var glued := _node_at(14.0, 0.0)
	var behind := _node_at(-6.0, 0.0)
	var far := _node_at(80.0, 0.0)
	var all: Array[Node2D] = [glued, near, behind, far]
	_check(_pick(Vector2.RIGHT, all) == near, "alvo: dois dinos colados, vence o mais próximo (qualquer ordem)")
	_check(_pick(Vector2.LEFT, all) == behind, "alvo: ao virar para a esquerda, o alvo é o que está àquele lado")
	_check(_pick(Vector2.UP, [near, glued] as Array[Node2D]) != null, "alvo: quem está a 90 graus ainda conta")
	_check(_pick(Vector2.RIGHT, [behind, far] as Array[Node2D]) == null, "alvo: atrás ou fora do alcance não é alvo")
	_check(_pick(Vector2.RIGHT, [] as Array[Node2D]) == null, "alvo: ninguém, nada")
	var same_a := _node_at(0.0, 20.0)
	var same_b := _node_at(14.0, 14.0)
	_check(_pick(Vector2.RIGHT, [same_a, same_b] as Array[Node2D]) == same_b, "alvo: empate de distância vai para o mais alinhado ao olhar")
	var on_top := _node_at(0.0, 0.0)
	_check(_pick(Vector2.LEFT, [on_top] as Array[Node2D]) == on_top, "alvo: dino sobre o jogador vale como à frente")
	_check(_pick(Vector2.ZERO, [_node_at(0.0, 10.0)] as Array[Node2D]) != null, "alvo: sem direção de olhar, vale a de baixo")


func _test_hysteresis() -> void:
	var a := _node_at(10.0, 0.0)
	var b := _node_at(12.0, 0.0)
	var both: Array[Node2D] = [a, b]
	_check(_pick(Vector2.RIGHT, both, b) == b, "histerese: o alvo atual fica se o rival é só um pouco mais perto")
	_check(_pick(Vector2.RIGHT, both, a) == a, "histerese: e vice-versa (sem troca ping-pong)")
	b.position.x = 20.0
	a.position.x = 12.0
	_check(_pick(Vector2.RIGHT, both, b) == a, "histerese: rival bem mais perto toma o lugar")
	var gone_current := _node_at(-30.0, 0.0)
	_check(_pick(Vector2.RIGHT, both, gone_current) == a, "histerese: alvo atual que saiu da frente é abandonado")
	# Troca de direção: o alvo antigo some do lado e o novo assume sem esperar.
	var left := _node_at(-12.0, 0.0)
	var right := _node_at(12.0, 0.0)
	var two: Array[Node2D] = [left, right]
	var chosen := _pick(Vector2.RIGHT, two)
	_check(chosen == right and _pick(Vector2.LEFT, two, chosen) == left, "troca de direção: o destaque segue o olhar")


func _wild_pair() -> Dictionary:
	var player := _spawn_player()
	var first := _spawn_dino()
	var second := _spawn_dino()
	for dino in [first, second]:
		(dino as Dino).set_physics_process(false)
	player.global_position = Vector2.ZERO
	var authority := player.authority
	authority.register(first)
	authority.register(second)
	return {"player": player, "first": first, "second": second, "authority": authority}


func _test_player_attack_follows_highlight() -> void:
	var world := _wild_pair()
	var player: Player = world["player"]
	var first: Dino = world["first"]
	var second: Dino = world["second"]
	var seen: Array = []
	player.attack_target_changed.connect(func(dino: Dino) -> void: seen.append(dino))
	first.global_position = Vector2(14.0, 0.0)
	second.global_position = Vector2(10.0, 0.0)
	player._in_range = [first.interactable, second.interactable]
	player.perform_move(Vector2.RIGHT, false)
	player.tick(0.0)
	_check(player.attack_target == second and seen == [second], "ataque: o destaque vai no mais próximo e o sinal avisa uma vez")
	player.tick(0.0)
	_check(seen.size() == 1, "ataque: sem mudança, sem sinal repetido")
	var first_health := first.health.current_health
	var second_health := second.health.current_health
	_check(player.attack(), "ataque: acerta")
	_check(second.health.current_health < second_health and first.health.current_health == first_health,
			"ataque: o golpe vai SEMPRE no dino destacado, nunca no vizinho")
	# Dino destacado morre: o destaque passa ao outro sem o jogador se mexer.
	player.tick(5.0)
	second.health.take_damage(1000.0)
	player.tick(0.0)
	_check(player.attack_target == first, "ataque: o alvo morto sai e o vizinho assume")
	player.tick(5.0)
	_check(player.attack() and first.health.current_health < first_health, "ataque: o golpe segue o novo destaque")
	# Domado não é alvo (a autoridade o negaria).
	first.state_machine.is_tamed = true
	player.tick(0.0)
	_check(player.attack_target == null, "ataque: domado não é destacado")
	# Olhar para o lado oposto sem ninguém ali: sem alvo, o golpe não acerta ninguém.
	first.state_machine.is_tamed = false
	player.perform_move(Vector2.LEFT, false)
	player.tick(0.0)
	_check(player.attack_target == null and not player.attack(), "ataque: ninguém à frente, nada é atingido")
	# A autoridade continua validando: alvo fora do alcance é negado.
	var authority: WorldAuthority = world["authority"]
	first.global_position = Vector2(REACH * 3.0, 0.0)
	_check(authority.request_attack(1, authority.id_of(first)) == Enums.ActionResult.OUT_OF_RANGE, "autoridade: alvo longe segue negado")
	# "À frente" é da autoridade: golpe direto num dino ATRÁS (pela direção que ela mantém) é negado e nada muda.
	_check(authority.request_move(1, Vector2.LEFT) == Enums.ActionResult.OK, "preparo: o corpo vira para a esquerda pela autoridade")
	first.global_position = player.global_position + Vector2(20.0, 0.0)
	var before := first.health.current_health
	_check(authority.request_attack(1, authority.id_of(first)) == Enums.ActionResult.OUT_OF_RANGE and first.health.current_health == before,
			"autoridade: golpe direto em dino atrás é recusado, sem dano")
	first.global_position = player.global_position + Vector2(-20.0, 0.0)
	player.tick(5.0)
	_check(authority.request_attack(1, authority.id_of(first)) == Enums.ActionResult.OK, "autoridade: o mesmo dino à frente é aceito")


func _test_outline() -> void:
	var world := _wild_pair()
	var player: Player = world["player"]
	var first: Dino = world["first"]
	var second: Dino = world["second"]
	var outline: AttackTargetOutline = _track.call(AttackTargetOutline.new())
	outline.player = player
	_root.add_child(outline)
	first.global_position = Vector2(10.0, 0.0)
	second.global_position = Vector2(30.0, 0.0)
	player._in_range = [first.interactable, second.interactable]
	player.perform_move(Vector2.RIGHT, false)
	player.tick(0.0)
	_check(outline.highlighted() == first and outline.outline_visible(), "contorno: aparece no dino-alvo")
	var copies := 0
	for child in first.visual.get_children():
		if child is Sprite2D and (child as Sprite2D).material is ShaderMaterial:
			copies += 1
	_check(copies >= 4, "contorno: 4 cópias da silhueta no sprite do alvo")
	var material := first.visual.get_child(first.visual.get_child_count() - 1).get("material") as ShaderMaterial
	_check(material != null and material.get_shader_parameter("tint") == AttackTargetOutline.OUTLINE_COLOR, "contorno: na cor de destaque")
	player.perform_move(Vector2.LEFT, false)
	player.tick(0.0)
	_check(outline.highlighted() == null and not outline.outline_visible(), "contorno: some quando não há alvo")
	var leftovers := first.visual.get_children().filter(func(c: Node) -> bool: return not c.is_queued_for_deletion())
	_check(leftovers.is_empty(), "contorno: nenhuma cópia fica no sprite do dino")


func _test_audio_settings() -> void:
	_check(AudioServer.get_bus_index(GameSettings.BUS_MUSIC) >= 0 and AudioServer.get_bus_index(GameSettings.BUS_SFX) >= 0,
			"áudio: barramentos Music e SFX existem (default_bus_layout)")
	var path := "user://test_audio_%d.json" % OS.get_process_id()
	var settings := GameSettings.new()
	settings.set_volume(0.5)
	settings.set_music_volume(0.3)
	settings.set_sfx_volume(0.9)
	settings.muted = true
	_check(settings.save_to(path), "áudio: grava")
	var loaded := GameSettings.load_from(path)
	_check(is_equal_approx(loaded.volume, 0.5) and is_equal_approx(loaded.music_volume, 0.3)
			and is_equal_approx(loaded.sfx_volume, 0.9) and loaded.muted, "áudio: roundtrip JSON de três volumes e mudo")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string('{"music_volume": "alto", "sfx_volume": 9, "muted": "sim"}')
	file.close()
	var hostile := GameSettings.load_from(path)
	_check(hostile.music_volume == GameSettings.DEFAULT_MUSIC_VOLUME and hostile.sfx_volume == 1.0 and not hostile.muted,
			"áudio: valor hostil cai no padrão ou é limitado")
	DirAccess.remove_absolute(path)
	var old_master := AudioServer.get_bus_volume_db(0)
	var music := AudioServer.get_bus_index(GameSettings.BUS_MUSIC)
	var sfx := AudioServer.get_bus_index(GameSettings.BUS_SFX)
	settings.apply()
	_check(AudioServer.is_bus_mute(0) and is_equal_approx(AudioServer.get_bus_volume_db(music), GameSettings.volume_to_db(0.3))
			and is_equal_approx(AudioServer.get_bus_volume_db(sfx), GameSettings.volume_to_db(0.9)),
			"áudio: apply liga mudo e volumes por barramento")
	settings.muted = false
	settings.set_music_volume(0.0)
	settings.apply()
	_check(not AudioServer.is_bus_mute(0) and AudioServer.is_bus_mute(music) and not AudioServer.is_bus_mute(sfx),
			"áudio: sem mudo, música a 0 silencia só a música")
	settings.set_level(GameSettings.LEVEL_SFX, 0.95)
	settings.cycle_level(GameSettings.LEVEL_SFX)
	_check(settings.sfx_volume == 0.0 and settings.level("x") == 0.0, "áudio: ciclo por ajuste e id desconhecido")
	settings.set_volume(1.0)
	settings.set_music_volume(1.0)
	settings.set_sfx_volume(1.0)
	settings.apply()
	AudioServer.set_bus_volume_db(0, old_master)
	AudioServer.set_bus_mute(0, false)
	var view: PlayerView = _track.call(PlayerView.new())
	view.player = _spawn_player()
	_root.add_child(view)
	_check(view.audio_player().bus == GameSettings.BUS_SFX and view.breath_player().bus == GameSettings.BUS_SFX,
			"áudio: sons do jogador saem pelo SFX")
	var dino_view: DinoView = _track.call(DinoView.new())
	_root.add_child(dino_view)
	_check(dino_view.audio_player().bus == GameSettings.BUS_SFX, "áudio: sons do dino saem pelo SFX")


func _test_music_player() -> void:
	var music: MusicPlayer = _track.call(MusicPlayer.new())
	_root.add_child(music)
	var changes: Array = []
	music.track_changed.connect(func(stream: AudioStream) -> void: changes.append(stream))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = 8000
	wav.data = PackedByteArray([0, 0, 0, 0, 0, 0, 0, 0])
	music.play_track(wav)
	_check(music.current_track() == wav and music.audio_player().bus == GameSettings.BUS_MUSIC, "música: toca no barramento Music")
	_check(wav.loop_mode == AudioStreamWAV.LOOP_FORWARD and wav.loop_end == 4, "música: a faixa entra em loop")
	music.play_track(wav)
	_check(changes.size() == 1, "música: a mesma faixa não reinicia")
	music.stop_track()
	_check(music.current_track() == null and not music.is_playing() and changes.size() == 2, "música: parar limpa a faixa")
	music.play_track(null)
	_check(music.current_track() == null, "música: faixa nula não toca")
	music.free()
