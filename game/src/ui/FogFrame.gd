# SPDX-License-Identifier: MIT
class_name FogFrame
extends ColorRect
## Névoa leve nas bordas da tela (moldura de ~2 tiles). Só visual: não captura clique
## (`mouse_filter` ignora), não tem física nem estado de jogo. Fica no `CanvasLayer` da UI,
## abaixo da HUD, então a HUD continua nítida. O desenho é o shader `fog_frame.gdshader`.

const SHADER := preload("res://src/ui/fog_frame.gdshader")
const TILE_SIZE := 16

## Largura da moldura, em tiles.
@export var width_tiles: float = 2.0
## Opacidade máxima, na borda extrema (0 a 1).
@export_range(0.0, 1.0) var max_alpha: float = 0.28
@export_range(1, 8) var steps: int = 4

var _material := ShaderMaterial.new()
var _mask: Image = null


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	color = Color.WHITE
	_material.shader = SHADER
	material = _material
	resized.connect(_refresh)
	_refresh()


func _refresh() -> void:
	var frame := Vector2i(maxi(int(size.x), 1), maxi(int(size.y), 1))
	_mask = build_mask(frame, width_tiles * TILE_SIZE, steps)
	_material.set_shader_parameter("mask", ImageTexture.create_from_image(_mask))
	_material.set_shader_parameter("max_alpha", max_alpha)


## Profundidade da névoa no pixel `pixel` de um quadro de `frame`: 0 no miolo e 1 na borda extrema, em
## `steps` degraus iguais dentro de `width_px` da borda.
static func depth_at(pixel: Vector2i, frame: Vector2i, width_px: float, steps: int) -> float:
	var to_edge := mini(mini(pixel.x, frame.x - 1 - pixel.x), mini(pixel.y, frame.y - 1 - pixel.y))
	var depth := clampf(1.0 - float(to_edge) / width_px, 0.0, 1.0)
	return ceilf(depth * float(steps)) / float(steps)


## Máscara (canal vermelho = profundidade) do quadro inteiro.
static func build_mask(frame: Vector2i, width_px: float, steps: int) -> Image:
	var image := Image.create(frame.x, frame.y, false, Image.FORMAT_RGBA8)
	for y in frame.y:
		for x in frame.x:
			var depth := depth_at(Vector2i(x, y), frame, width_px, steps)
			image.set_pixel(x, y, Color(depth, depth, depth, 1.0))
	return image


func shader_material() -> ShaderMaterial:
	return _material


## Opacidade final (0 a `max_alpha`) no pixel: a mesma conta do shader sobre a máscara.
func alpha_at(pixel: Vector2i) -> float:
	return _mask.get_pixelv(pixel).r * max_alpha
