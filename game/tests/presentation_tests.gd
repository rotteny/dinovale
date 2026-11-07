# SPDX-License-Identifier: MIT
class_name PresentationTests
extends TestSuite
## "Nv N" do selvagem (`WildLevelTag`) e cursor em pixel art (`PixelCursor`).

const RANGE_PX := 96.0  # 6 tiles de 16 px (DinoLevelRules)


func run() -> void:
	_test_level_tag()
	_test_cursor()


func _tag_for(creature: Dino, viewer: Node2D) -> WildLevelTag:
	var tag := WildLevelTag.new()
	tag.dino = creature
	tag.viewer = viewer
	_root.add_child(tag)
	_track.call(tag)
	return tag


func _test_level_tag() -> void:
	var rules: DinoLevelRules = load("res://data/balance/dino_level_rules.tres")
	_check(is_equal_approx(rules.level_tag_range(), RANGE_PX), "o alcance do Nv vem do Resource: 6 tiles = 96 px")
	var player := _spawn_player()
	var creature := _spawn_dino()
	creature.level = 17
	player.global_position = Vector2.ZERO
	creature.global_position = Vector2(RANGE_PX - 1.0, 0.0)
	var tag := _tag_for(creature, player)
	tag.tick()
	_check(tag.tag_visible() and tag.tag_text() == "Nv 17", "selvagem vivo a 6 tiles: mostra 'Nv 17'")
	creature.global_position = Vector2(RANGE_PX + 1.0, 0.0)
	tag.tick()
	_check(not tag.tag_visible(), "além de 6 tiles: some")
	creature.global_position = Vector2(RANGE_PX - 1.0, 0.0)
	creature.torpor.add_torpor(creature.torpor.max_torpor)
	tag.tick()
	_check(creature.torpor.is_unconscious and not tag.tag_visible(), "desmaiado: a barra de doma já mostra o nível, o Nv de cima some")
	var marker := DinoMarker.new()
	marker.dino = creature
	_root.add_child(marker)
	_track.call(marker)
	creature.torpor.is_unconscious = false  # acordado: só o "domado" pode esconder o Nv aqui
	creature.state_machine.is_tamed = true
	creature.owner_player_id = Player.LOCAL_PLAYER_ID
	tag.tick()
	marker.set_process(false)
	marker._sync()
	_check(not tag.tag_visible() and marker.is_marked(), "domado: o Nv do selvagem some e fica só a placa")
	creature.state_machine.is_tamed = false
	tag.tick()
	_check(tag.tag_visible(), "voltou a selvagem e acordado: volta o Nv")
	creature.health.take_damage(creature.health.max_health * 3.0)
	tag.tick()
	_check(not tag.tag_visible(), "morto: não mostra")
	var other := _spawn_dino()
	var orphan := _tag_for(other, null)
	orphan.tick()
	_check(not orphan.tag_visible(), "sem quem olhar: não mostra")


func _test_cursor() -> void:
	_check(PixelCursor.base_size() == Vector2i(320, 180), "a base do cursor vem do ProjectSettings (320x180)")
	_check(PixelCursor.scale_for(Vector2i(1280, 720)) == 4, "janela 1280x720: escala 4")
	_check(PixelCursor.scale_for(Vector2i(1920, 1080)) == 6, "janela 1920x1080: escala 6")
	_check(PixelCursor.scale_for(Vector2i(1300, 720)) == 4, "janela mais larga que 16:9: vale o menor lado")
	_check(PixelCursor.scale_for(Vector2i(200, 100)) == 1, "janela menor que o jogo: escala 1")
	var base := PixelCursor.TEXTURE.get_image()
	_check(base.get_size() == Vector2i(10, 12), "seta de 10x12 px")
	_check(base.get_pixel(0, 0).to_html(false) == "141b1b" and base.get_pixel(0, 0).a == 1.0, "a ponta é o pixel 0,0, com o contorno #141b1b")
	var big := PixelCursor.scaled_image(base, 4)
	_check(big.get_size() == Vector2i(40, 48), "ampliado 4x: 40x48")
	var solid_ok := true
	var colors := {}
	for y in big.get_height():
		for x in big.get_width():
			var pixel := big.get_pixel(x, y)
			solid_ok = solid_ok and (pixel.a == 0.0 or pixel.a == 1.0)
			if pixel.a == 1.0:
				colors[pixel.to_html(false)] = true
			solid_ok = solid_ok and pixel == base.get_pixel(x / 4, y / 4)
	_check(solid_ok and colors.size() == 3, "ampliado sem suavização: cada pixel vira bloco 4x4, alfa 0/1, só 3 cores")
	_check(PixelCursor.scaled_image(base, 40).get_size() == base.get_size(), "acima do limite do sistema (256 px): fica em 1x")
	var node := PixelCursor.new()
	_root.add_child(node)
	_track.call(node)
	node.apply()  # sem erro de script (o contador de erros do runner reprova); o cursor do SO não se lê de volta
