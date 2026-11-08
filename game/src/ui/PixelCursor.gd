# SPDX-License-Identifier: MIT
class_name PixelCursor
extends Node
## Cursor do mouse em pixel art. O jogo é 320x180 ampliado por inteiro (stretch `viewport`, escala `integer`),
## mas o cursor do sistema é desenhado em pixels da JANELA: por isso a imagem de 1x é ampliada aqui, por vizinho
## mais próximo, pelo mesmo fator da janela, e reaplicada quando ela muda de tamanho. O hotspot é a ponta da seta
## (pixel 0, 0). Só apresentação: coloque um nó destes em cada cena que pode ser a primeira.

const TEXTURE: Texture2D = preload("res://assets/sprites/ui/cursor.png")
const HOTSPOT := Vector2i.ZERO
## O sistema aceita cursor de até 256x256.
const MAX_CURSOR_PIXELS := 256
## Formas do cursor que recebem a seta em pixel art: qualquer `Control` com outra forma (mão, texto, ...) também a mostra.
const SHAPES: Array[Input.CursorShape] = [
	Input.CURSOR_ARROW, Input.CURSOR_IBEAM, Input.CURSOR_POINTING_HAND, Input.CURSOR_CROSS, Input.CURSOR_WAIT,
	Input.CURSOR_BUSY, Input.CURSOR_DRAG, Input.CURSOR_CAN_DROP, Input.CURSOR_FORBIDDEN, Input.CURSOR_VSIZE,
	Input.CURSOR_HSIZE, Input.CURSOR_BDIAGSIZE, Input.CURSOR_FDIAGSIZE, Input.CURSOR_MOVE, Input.CURSOR_VSPLIT,
	Input.CURSOR_HSPLIT, Input.CURSOR_HELP,
]

## Última ampliação aplicada e quantas vezes `apply` rodou (para teste: o cursor do sistema não se lê de volta).
var applied_scale: int = 0
var apply_count: int = 0


func _ready() -> void:
	var window := get_window()
	if window != null:
		window.size_changed.connect(apply)
	apply()
	# De novo no fim do quadro: no Windows o tamanho final da janela (tela cheia) só vale depois do primeiro quadro.
	apply.call_deferred()


## O sistema pode zerar o cursor ao devolver o foco à janela: aplica de novo.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		apply()


## Tamanho base do jogo, o do projeto (`display/window/size`).
static func base_size() -> Vector2i:
	return Vector2i(int(ProjectSettings.get_setting("display/window/size/viewport_width", 320)),
			int(ProjectSettings.get_setting("display/window/size/viewport_height", 180)))


## Fator inteiro de ampliação do jogo para uma janela desse tamanho (o mesmo do `integer` do stretch).
static func scale_for(window_size: Vector2i) -> int:
	var base := base_size()
	return maxi(mini(window_size.x / maxi(base.x, 1), window_size.y / maxi(base.y, 1)), 1)


## A imagem de 1x ampliada `factor` vezes sem suavização, ou a de 1x se passaria do limite do sistema.
static func scaled_image(base: Image, factor: int) -> Image:
	var image := base.duplicate() as Image
	var safe := maxi(factor, 1)
	if maxi(image.get_width(), image.get_height()) * safe > MAX_CURSOR_PIXELS:
		return image
	if safe > 1:
		image.resize(image.get_width() * safe, image.get_height() * safe, Image.INTERPOLATE_NEAREST)
	return image


func apply() -> void:
	var window := get_window()
	var factor := scale_for(window.size) if window != null else 1
	var image := scaled_image(TEXTURE.get_image(), factor)
	var used := image.get_width() / TEXTURE.get_width()
	var texture := ImageTexture.create_from_image(image)
	for shape in SHAPES:
		Input.set_custom_mouse_cursor(texture, shape, HOTSPOT * used)
	applied_scale = used
	apply_count += 1
