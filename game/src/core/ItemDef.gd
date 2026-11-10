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
## Vai ao cinto do jogador (fora dos slots da grade): ferramenta e arma. Só item individual (com durabilidade) pode.
var belt: bool = false
## Peso de UMA unidade, em kg (GDD 5.1). Vem de `CarryRules.item_weights`; o catálogo o preenche. Equipamento
## individual pesa o mesmo na grade e nas vagas de equipamento (as vagas não ocupam slot, mas contam no Peso).
var weight: float = 0.0


func _init(p_id: String, p_name: String, p_max_stack: int, p_color: Color) -> void:
	id = p_id
	display_name = p_name
	max_stack = maxi(p_max_stack, 1)
	color = p_color


## Peso de uma unidade em gramas inteiras: a conta de carga é em inteiros, sem erro de ponto flutuante (0,05 kg x 3).
func weight_grams() -> int:
	return roundi(weight * 1000.0)
