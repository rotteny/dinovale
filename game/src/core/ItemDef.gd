# SPDX-License-Identifier: MIT
class_name ItemDef
extends RefCounted
## Definição mínima de um item: dado puro, sem cena nem sprite.

var id: String
var display_name: String
var max_stack: int
## Cor placeholder usada pela UI até existir arte.
var color: Color
## Durabilidade máxima. Maior que 0 = item INDIVIDUAL (arma, ferramenta, armadura): não
## empilha e cada unidade carrega `iid` e durabilidade (GDD 5.9, PRO-15). 0 = empilhável.
## Só o campo: desgaste, quebra e reparo são do PRO-16.
var durability_max: int = 0
## Vaga de equipamento em que o item cabe (`EquipmentLayout`): "" = não é equipável.
## Só item individual tem vaga.
var slot: String = ""


func _init(p_id: String, p_name: String, p_max_stack: int, p_color: Color) -> void:
	id = p_id
	display_name = p_name
	max_stack = maxi(p_max_stack, 1)
	color = p_color
