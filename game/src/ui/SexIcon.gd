# SPDX-License-Identifier: MIT
class_name SexIcon
extends RefCounted
## Símbolo de sexo do dino (macho #71ddee, fêmea #ef9597) ao lado do "Nv" da placa. A fonte pixel não tem ♂ nem ♀,
## então o símbolo é uma imagem de 9x9 (7x7 com 1 px de contorno). Só apresentação: lê o sexo e nunca o altera.

const MALE: Texture2D = preload("res://assets/ui/icon_sex_male_outline.png")
const FEMALE: Texture2D = preload("res://assets/ui/icon_sex_female_outline.png")
## Folga, em pixels, entre o fim do texto e o símbolo.
const GAP := 1.0


## Ícone do sexo `sex` (`DinoBaseStats.SEX_MALE` ou `SEX_FEMALE`); null para qualquer outro valor.
static func texture_for(sex: String) -> Texture2D:
	if sex == DinoBaseStats.SEX_MALE:
		return MALE
	if sex == DinoBaseStats.SEX_FEMALE:
		return FEMALE
	return null


## Põe `icon` logo depois do texto de `label` (centralizado), na altura da linha. Esconde o ícone se o sexo não é conhecido.
static func place(icon: Sprite2D, label: Label, sex: String) -> void:
	var texture := texture_for(sex)
	icon.texture = texture
	icon.visible = texture != null and label.text != ""
	if not icon.visible:
		return
	var font := label.get_theme_font("font")
	var width := font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x
	var half := texture.get_width() * 0.5
	icon.position = Vector2(roundf(label.position.x + label.size.x * 0.5 + width * 0.5 + GAP + half), label.position.y + 5.0)
