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


func _ready() -> void:
	var window := get_window()
	if window != null:
		window.size_changed.connect(apply)
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
	Input.set_custom_mouse_cursor(ImageTexture.create_from_image(image), Input.CURSOR_ARROW, HOTSPOT * used)
