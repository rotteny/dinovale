# SPDX-License-Identifier: MIT
class_name EquipmentSlotDef
extends Resource
## Uma vaga de equipamento (GDD 5.20): dado puro. O item equipável declara o `id` da vaga em `slot`.

@export var id: String = ""
@export var display_name: String = ""
## `slot_visivel` do GDD: a tela só mostra a vaga se for true. No M1 só a Arma.
@export var shown: bool = false
## Se o item da vaga pode ir à barra de atalhos (consumível, arma e ferramenta; roupa não).
@export var hotbar: bool = false
