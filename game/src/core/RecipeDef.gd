# SPDX-License-Identifier: MIT
class_name RecipeDef
extends Resource
## Receita de fabricação (E7a): dado puro. Vem de `res://data/recipes/`. Ids são strings estáveis (o que o save e os
## pedidos levam). Os números (material, tempo) vivem no `.tres`, nunca no código.

## Estação em que a receita se faz: à mão (em qualquer lugar) ou na Bancada (a 2 tiles ou menos).
const STATION_HAND := "hand"
const STATION_WORKBENCH := "workbench"

@export var id: String = ""
@export var display_name: String = ""
## Material consumido: id do item -> quantidade.
@export var inputs: Dictionary[String, int] = {}
@export var output_id: String = ""
@export_range(1, 999) var output_amount: int = 1
## Segundos de fabricação.
@export_range(0.1, 600.0) var seconds: float = 3.0
@export var station: String = STATION_HAND
## Conhecida desde o início. Provisório na E7a: na E7b o resto passa a ser aprendido com Saber.
@export var known_at_start: bool = true


## A receita é coerente com o catálogo? (ids de item existentes, quantidades positivas, estação válida.)
func is_valid() -> bool:
	if id == "" or inputs.is_empty() or not Items.has(output_id) or output_amount < 1:
		return false
	if station != STATION_HAND and station != STATION_WORKBENCH:
		return false
	for item_id: String in inputs:
		if not Items.has(item_id) or Items.is_individual(item_id) or int(inputs[item_id]) < 1:
			return false
	return true


## O que falta no `inventory` para fazer a receita: item -> quanto falta (vazio = tem tudo).
func missing_from(inventory: InventoryComponent) -> Dictionary:
	var lacking := {}
	for item_id: String in inputs:
		var short := int(inputs[item_id]) - inventory.count(item_id)
		if short > 0:
			lacking[item_id] = short
	return lacking
