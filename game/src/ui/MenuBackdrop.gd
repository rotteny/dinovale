# SPDX-License-Identifier: MIT
class_name MenuBackdrop
extends Node2D
## Fundo da tela inicial: 5 camadas de céu a primeiro plano (`assets/ui/menu/menu_camada_*.png`, 352x212 = tela de
## 320x180 mais 16 px de margem de cada lado) com parallax leve pelo mouse. Cada camada anda um múltiplo inteiro de
## pixels (nearest, sem escala fracionada) até 16 px, as de trás menos. Sem mouse na janela, volta ao centro.
## Só apresentação: nenhuma regra do jogo mora aqui.

## Camadas de trás para frente e quanto cada uma acompanha o mouse (de `menu_fundo.json`, `parallax_sugerido`).
const LAYERS: Array[Dictionary] = [
	{"texture": preload("res://assets/ui/menu/menu_camada_ceu.png"), "factor": 0.1},
	{"texture": preload("res://assets/ui/menu/menu_camada_longe.png"), "factor": 0.2},
	{"texture": preload("res://assets/ui/menu/menu_camada_meio.png"), "factor": 0.4},
	{"texture": preload("res://assets/ui/menu/menu_camada_perto.png"), "factor": 0.7},
	{"texture": preload("res://assets/ui/menu/menu_camada_frente.png"), "factor": 1.0},
]
## A camada começa em (-16,-16) da tela: é a margem que o deslocamento consome.
const ORIGIN := Vector2(-16.0, -16.0)
const MAX_SHIFT := 16.0
## Rapidez com que o fundo alcança o mouse (por segundo): suaviza o movimento.
const FOLLOW := 5.0

var _sprites: Array[Sprite2D] = []
## Deslocamento atual, de -1 a 1 em cada eixo (0 = centro).
var _offset := Vector2.ZERO


func _ready() -> void:
	for layer in LAYERS:
		var sprite := Sprite2D.new()
		sprite.texture = layer["texture"]
		sprite.centered = false
		sprite.position = ORIGIN
		add_child(sprite)
		_sprites.append(sprite)


func _process(delta: float) -> void:
	tick(delta, _pointer())


## Passo de tempo (testável sem quadros). `pointer` é a posição do mouse em -1..1 (0 = centro da tela).
func tick(delta: float, pointer: Vector2) -> void:
	_offset = _offset.lerp(pointer.clampf(-1.0, 1.0), 1.0 - exp(-FOLLOW * maxf(delta, 0.0)))
	for i in _sprites.size():
		var shift := (_offset * MAX_SHIFT * float(LAYERS[i]["factor"])).round()
		_sprites[i].position = ORIGIN - shift


## Posição de uma camada (para testes).
func layer_position(index: int) -> Vector2:
	return _sprites[index].position


func layer_count() -> int:
	return _sprites.size()


## Mouse em -1..1 dentro da tela; fora dela (ou sem janela, como no headless) vale 0.
func _pointer() -> Vector2:
	var viewport := get_viewport()
	if viewport == null:
		return Vector2.ZERO
	var size := viewport.get_visible_rect().size
	var mouse := viewport.get_mouse_position()
	if size.x <= 0.0 or size.y <= 0.0 or not Rect2(Vector2.ZERO, size).has_point(mouse):
		return Vector2.ZERO
	return (mouse / size - Vector2(0.5, 0.5)) * 2.0
