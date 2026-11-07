# SPDX-License-Identifier: MIT
class_name ResourceNodeView
extends Node2D
## Desenho do nó de recurso: o sprite do tipo (cheio ou esgotado), com os pés na origem do nó e a ordem de
## profundidade pelo Y do nó. Sem textura no tipo, cai num volume na cor dele. Só observa o nó; não decide nada.

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

@export var node: ResourceNode

var _sprite: Sprite2D = null
var _outline: Node2D = null
var _name_label: Label = null


func _ready() -> void:
	if not node.is_node_ready():  # o componente do nó só existe depois do _ready dele
		await node.ready
	if node.def != null and node.def.texture != null:
		_sprite = Sprite2D.new()
		_sprite.centered = false
		_apply_variant()
		add_child(_sprite)
	node.component.changed.connect(_refresh)
	_refresh()


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


func _refresh() -> void:
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
