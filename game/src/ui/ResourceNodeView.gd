# SPDX-License-Identifier: MIT
class_name ResourceNodeView
extends Node2D
## Desenho do nó de recurso: o sprite do tipo (cheio ou esgotado), com os pés na origem do nó e a ordem de
## profundidade pelo Y do nó. Sem textura no tipo, cai num volume na cor dele. Só observa o nó; não decide nada.
## Dano (decisão do dono, 08/11): a cada golpe aceito o nó treme (1 a 2 px, 0,15 s), pisca em branco por um quadro, solta
## lascas e mostra um impacto; o desenho ganha marcas (sobreposição de PNG) conforme a fração de vida, em 2 estágios.
## Sem golpes por `hit_reset_seconds` o dano some com um fade; no último golpe o nó tomba ou esfarela antes de sumir.
## Nenhum número nem barra: o estado vem dos sinais do componente (`damaged`, `felled`, `rebuffed`).

## Cor do contorno e do nome do nó ao alcance (claro, para se ler sobre campina, mata e pedra).
const OUTLINE_COLOR := Color(1.0, 0.95, 0.5)
## Sombreados de variante: a mesma árvore em 4 tons, espelhada ou não, escolhidos pelo id do nó (estável).
const VARIANT_TINTS: Array[Color] = [Color(1, 1, 1), Color(0.9, 1.0, 0.86), Color(1.0, 0.95, 0.84), Color(0.88, 0.96, 1.0)]
const VARIANT_KINDS: Array[String] = ["tree", "bush_baga", "bush_sono"]
const SILHOUETTE: Shader = preload("res://src/ui/silhouette.gdshader")
const NAME_GAP := 3.0
const NAME_WIDTH := 160.0
## Altura máxima, sobre os pés, em que o nome fica (cabe na tela de 180 px mesmo com o jogador na borda).
const NAME_MAX_HEIGHT := 26.0
const SHAKE_SECONDS := 0.15
const FLASH_SECONDS := 0.05
const FADE_SECONDS := 0.4
const FALL_SECONDS := 0.5
## Altura sobre os pés (px) do ponto do golpe: o tronco, ou o meio da pedra.
const HIT_HEIGHT := 10.0
const CHIPS_PER_HIT_MIN := 3
const CHIPS_PER_HIT_MAX := 6
const CHIPS_ON_FALL := 9

@export var node: ResourceNode

var _sprite: Sprite2D = null
var _outline: Node2D = null
var _name_label: Label = null
var _damage_overlay: Sprite2D = null
var _flash: Sprite2D = null
var _stage_shown: int = 0
var _shake_tween: Tween = null
var _fade_tween: Tween = null
## Variação só visual (lascas, impacto, lado da queda): semente fixa, nada disso é regra do jogo.
var _rng := SeededRng.new()


func _ready() -> void:
	if not node.is_node_ready():  # o componente do nó só existe depois do _ready dele
		await node.ready
	if node.def != null and node.def.texture != null:
		_sprite = Sprite2D.new()
		_sprite.centered = false
		_apply_variant()
		add_child(_sprite)
	node.component.changed.connect(_refresh)
	if node.def != null and node.def.is_struck():
		_rng.seed_from(["node_view", node.node_id])
		node.component.damaged.connect(_on_damaged)
		node.component.felled.connect(_on_felled)
		node.component.rebuffed.connect(_on_rebuffed)
	_refresh()
	set_process(false)


## Liga ou desliga o destaque do nó ao alcance: contorno claro em volta do desenho e o nome do que rende.
## Só o nó que o jogador está prestes a tocar tem isto; o cenário fixo nunca.
func set_highlight(on: bool) -> void:
	on = on and _sprite != null and node.is_available()
	if on and _outline == null:
		_build_highlight()
	if _outline != null:
		_outline.visible = on
		_name_label.visible = on
		if on:
			_place_highlight()


func is_highlighted() -> bool:
	return _outline != null and _outline.visible


func highlight_text() -> String:
	var yielded := Items.display_name(node.def.item_id)
	return node.def.display_name if yielded == node.def.display_name else "%s: %s" % [node.def.display_name, yielded]


func _build_highlight() -> void:
	_outline = Node2D.new()
	var material := ShaderMaterial.new()
	material.shader = SILHOUETTE
	material.set_shader_parameter("tint", OUTLINE_COLOR)
	for step in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1)]:
		var copy := Sprite2D.new()
		copy.centered = false
		copy.material = material
		copy.position = step
		_outline.add_child(copy)
	add_child(_outline)
	move_child(_outline, 0)  # atrás do desenho: só a borda aparece
	_name_label = Label.new()
	_name_label.theme = UiTheme.get_theme()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.custom_minimum_size.x = NAME_WIDTH
	_name_label.size.x = NAME_WIDTH
	_name_label.add_theme_color_override("font_color", OUTLINE_COLOR)
	_name_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_name_label.add_theme_constant_override("outline_size", 2)
	_name_label.text = highlight_text()
	add_child(_name_label)


func _place_highlight() -> void:
	for copy: Sprite2D in _outline.get_children():
		copy.texture = _sprite.texture
		copy.offset = _sprite.offset
		copy.flip_h = _sprite.flip_h
	var height := minf(_sprite.texture.get_size().y, NAME_MAX_HEIGHT)  # árvore alta: o nome fica na altura do tronco
	_name_label.position = Vector2(-NAME_WIDTH * 0.5, -height - NAME_GAP - _name_label.size.y)


## Espelha e sombreia por id: o bosque não vira um carimbo repetido.
func _apply_variant() -> void:
	if not VARIANT_KINDS.has(node.def.id):
		return
	var h := node.node_id.hash()
	_sprite.flip_h = (h & 1) == 1
	_sprite.modulate = VARIANT_TINTS[(h >> 1) % VARIANT_TINTS.size()]


## Estágio de dano que o desenho mostra (0 = inteiro). Só leitura, para teste e diagnóstico.
func damage_stage_shown() -> int:
	return _stage_shown


## A sobreposição de dano está visível?
func overlay_visible() -> bool:
	return _damage_overlay != null and _damage_overlay.visible and _damage_overlay.modulate.a > 0.0


## O nó está tremendo agora?
func is_shaking() -> bool:
	return _shake_tween != null and _shake_tween.is_valid() and _shake_tween.is_running()


## O flash branco de um quadro está aceso?
func is_flashing() -> bool:
	return _flash != null and _flash.visible


func _on_damaged(health: float, _health_max: float, by_hand: bool) -> void:
	if _sprite == null or health <= 0.0:
		return  # o último golpe é da queda (`_on_felled`)
	_show_stage(node.component.damage_stage())
	_shake(1 + mini(_stage_shown, 1))  # estágio avançado: balança mais
	_flash_once()
	var at := Vector2(_rng.next_below(7) - 3, -HIT_HEIGHT)
	HitEffects.spark(self, at, node.def.chip_color)
	HitEffects.chips(self, at, node.def.chip_color, CHIPS_PER_HIT_MIN + _rng.next_below(CHIPS_PER_HIT_MAX - CHIPS_PER_HIT_MIN + 1), _rng)
	var wood := node.def.material_id == "wood"
	SfxPlayer.play(self, SfxPlayer.TOOL_WOOD if wood and not by_hand else (SfxPlayer.PUNCH_TREE if wood else SfxPlayer.TOOL_STONE),
			node.global_position)
	set_process(_stage_shown > 0)


func _on_rebuffed() -> void:
	if _sprite == null:
		return
	_shake(1)
	HitEffects.spark(self, Vector2(0, -HIT_HEIGHT), node.def.chip_color)
	SfxPlayer.play(self, SfxPlayer.PUNCH_STONE, node.global_position)


## Último golpe: o nó some do mundo no mesmo quadro, então o que cai é uma cópia do desenho (a árvore tomba pelo pé,
## a pedra esfarela), que se apaga sozinha.
func _on_felled() -> void:
	if _sprite == null or node.get_parent() == null:
		return
	var ghost := Node2D.new()
	ghost.position = node.position
	node.get_parent().add_child(ghost)
	for source: Sprite2D in [_sprite, _damage_overlay]:
		if source != null and (source == _sprite or overlay_visible()):
			var copy := Sprite2D.new()
			copy.texture = source.texture
			copy.centered = false
			copy.offset = source.offset
			copy.flip_h = source.flip_h
			copy.modulate = source.modulate
			ghost.add_child(copy)
	var wood := node.def.material_id == "wood"
	var tween := ghost.create_tween()
	if wood:
		var side := 1.0 if _rng.next_below(2) == 0 else -1.0
		tween.tween_property(ghost, "rotation", side * PI * 0.5, FALL_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tween.tween_property(ghost, "modulate:a", 0.0, 0.25)
	else:
		tween.set_parallel(true)
		tween.tween_property(ghost, "scale:y", 0.25, FALL_SECONDS * 0.8)
		tween.tween_property(ghost, "modulate:a", 0.0, FALL_SECONDS * 0.8)
	tween.chain().tween_callback(ghost.queue_free)
	HitEffects.chips(ghost, Vector2(0, -HIT_HEIGHT), node.def.chip_color, CHIPS_ON_FALL, _rng)
	SfxPlayer.play(ghost, SfxPlayer.TREE_FALL if wood else SfxPlayer.ROCK_BREAK, node.global_position)


## Troca o estágio mostrado: marcas de corte ou rachaduras (sobreposição); 0 apaga com um fade.
func _show_stage(stage: int) -> void:
	if stage == _stage_shown:
		return
	_stage_shown = stage
	if _fade_tween != null:
		_fade_tween.kill()
	if _damage_overlay == null:
		_damage_overlay = Sprite2D.new()
		_damage_overlay.centered = false
		add_child(_damage_overlay)
	var overlays := node.def.damage_overlays
	if stage > 0 and stage <= overlays.size():
		_damage_overlay.texture = overlays[stage - 1]
		_damage_overlay.offset = _sprite.offset
		_damage_overlay.flip_h = _sprite.flip_h
		_damage_overlay.modulate.a = 1.0
		_damage_overlay.visible = true
	elif stage == 0:
		_fade_tween = create_tween()
		_fade_tween.tween_property(_damage_overlay, "modulate:a", 0.0, FADE_SECONDS)
		_fade_tween.tween_callback(func() -> void: _damage_overlay.visible = false)


## Tremor de pixel inteiro (±`amplitude` px) por `SHAKE_SECONDS`, no desenho todo (contorno e nome vão junto).
func _shake(amplitude: int) -> void:
	if _shake_tween != null:
		_shake_tween.kill()
	position = Vector2.ZERO
	_shake_tween = create_tween()
	var steps: Array[Vector2] = [Vector2(amplitude, 0), Vector2(-amplitude, 0), Vector2(amplitude, 0), Vector2.ZERO]
	for step in steps:
		_shake_tween.tween_property(self, "position", step, SHAKE_SECONDS / float(steps.size()))


## Silhueta branca por um instante (FLASH_SECONDS, cerca de um quadro).
func _flash_once() -> void:
	if _flash == null:
		_flash = Sprite2D.new()
		_flash.centered = false
		var material := ShaderMaterial.new()
		material.shader = SILHOUETTE
		material.set_shader_parameter("tint", Color.WHITE)
		_flash.material = material
		add_child(_flash)
	_flash.texture = _sprite.texture
	_flash.offset = _sprite.offset
	_flash.flip_h = _sprite.flip_h
	_flash.visible = true
	get_tree().create_timer(FLASH_SECONDS).timeout.connect(func() -> void:
		if is_instance_valid(_flash):
			_flash.visible = false)


## O dano some sozinho (o componente zera a vida perdida por inatividade): a marca esmaece.
func _process(_delta: float) -> void:
	if _stage_shown > 0 and node.component.damage_stage() == 0:
		_show_stage(0)
		set_process(false)


func _refresh() -> void:
	if _damage_overlay != null and node.is_available() and not node.component.has_damage() and _stage_shown > 0:
		_stage_shown = 0
		_damage_overlay.visible = false  # voltou cheio (nó renasceu): sem marca nenhuma
	if _sprite == null:
		queue_redraw()
		return
	var texture := node.def.texture
	_sprite.texture = texture
	var size := texture.get_size()
	_sprite.offset = Vector2(-size.x * 0.5, -size.y)  # pés (base, centro) na origem do nó


func _draw() -> void:
	if _sprite != null or node.def == null:
		return
	var full := node.is_available()
	var color := node.def.color if full else Color(node.def.color, 0.3)
	var size := 10.0 if full else 5.0
	draw_circle(Vector2(0, -size * 0.6), size, color)
	draw_arc(Vector2(0, -size * 0.6), size, 0.0, TAU, 16, Color(0, 0, 0, 0.6 if full else 0.2), 1.0)
