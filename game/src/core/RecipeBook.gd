# SPDX-License-Identifier: MIT
class_name RecipeBook
extends RefCounted
## Livro de receitas do mundo: as de `data/recipes/` (lista fixa, sem varrer pasta). Quem CONHECE cada uma é o jogador
## (`ProgressionComponent.knows`): conhecida = custo 0 ou aprendida com Saber (E7b).

const DEFAULT_RECIPES: Array[RecipeDef] = [
	preload("res://data/recipes/wooden_spear.tres"),
	preload("res://data/recipes/axe_stone.tres"),
	preload("res://data/recipes/pickaxe_stone.tres"),
	preload("res://data/recipes/campfire.tres"),
	preload("res://data/recipes/sleep_staff.tres"),
	preload("res://data/recipes/fiber_basket.tres"),
	preload("res://data/recipes/chest.tres"),
	preload("res://data/recipes/leather_backpack.tres"),
	preload("res://data/recipes/workbench.tres"),
	preload("res://data/recipes/foundation.tres"),
	preload("res://data/recipes/wall.tres"),
	preload("res://data/recipes/door.tres"),
	preload("res://data/recipes/sleeping_bag.tres"),
	preload("res://data/recipes/bed.tres"),
	preload("res://data/recipes/ration_c.tres"),
	preload("res://data/recipes/ration_b.tres"),
	preload("res://data/recipes/ration_a.tres"),
]

var _recipes: Dictionary[String, RecipeDef] = {}
var _order: Array[String] = []


## Livro com as receitas do jogo.
static func with_defaults() -> RecipeBook:
	var book := RecipeBook.new()
	for recipe in DEFAULT_RECIPES:
		book.add(recipe)
	return book


## Adiciona (ou troca, pelo id) uma receita válida. Devolve false se a receita é inválida.
func add(recipe: RecipeDef) -> bool:
	if recipe == null or not recipe.is_valid() or _group_cost_conflicts(recipe):
		return false
	if not _recipes.has(recipe.id):
		_order.append(recipe.id)
	_recipes[recipe.id] = recipe
	return true


## Receita de grupo com custo de Saber diferente do dos outros membros do grupo? (aprender o grupo cobra UM custo: com custos
## diferentes o jogador pagaria o do primeiro membro; por isso o livro recusa.)
func _group_cost_conflicts(recipe: RecipeDef) -> bool:
	if recipe.learn_group == "":
		return false
	for other: RecipeDef in _recipes.values():
		if other.id != recipe.id and other.learn_group == recipe.learn_group and other.saber_cost != recipe.saber_cost:
			return true
	return false


## Receita pelo id, ou null.
func find(recipe_id: String) -> RecipeDef:
	return _recipes.get(recipe_id)


## Todas, na ordem em que entraram.
func all() -> Array[RecipeDef]:
	var list: Array[RecipeDef] = []
	for recipe_id in _order:
		list.append(_recipes[recipe_id])
	return list


## As que `progression` conhece (para a tela de fabricação), na ordem do livro.
func known_by(progression: ProgressionComponent) -> Array[RecipeDef]:
	var list: Array[RecipeDef] = []
	for recipe in all():
		if progression.knows(recipe):
			list.append(recipe)
	return list


## O grupo de aprendizado de `recipe`: ela e as de mesmo `learn_group` (só ela, se não tem grupo), na ordem do livro.
func group_of(recipe: RecipeDef) -> Array[RecipeDef]:
	var members: Array[RecipeDef] = []
	if recipe == null:
		return members
	if recipe.learn_group == "":
		members.append(recipe)
		return members
	for other in all():
		if other.learn_group == recipe.learn_group:
			members.append(other)
	return members


## Saber gasto por uma lista de receitas aprendidas: o custo de cada uma, com cada grupo contado uma vez. Id que o livro
## não conhece, ou de receita que já nasce conhecida, não custa nada.
func cost_of(learned_ids: Array[String]) -> int:
	var total := 0
	var paid_groups := {}
	for recipe_id in learned_ids:
		var recipe := find(recipe_id)
		if recipe == null or recipe.is_known_at_start():
			continue
		if recipe.learn_group != "":
			if paid_groups.has(recipe.learn_group):
				continue
			paid_groups[recipe.learn_group] = true
		total += recipe.saber_cost
	return total


## Receitas ordenadas por custo de Saber (D18: lista plana), na ordem do livro dentro do mesmo custo.
func by_cost() -> Array[RecipeDef]:
	var list := all()
	var indexed: Array = []
	for position in list.size():
		indexed.append([list[position].saber_cost, position])
	indexed.sort()
	var sorted: Array[RecipeDef] = []
	for pair: Array in indexed:
		sorted.append(list[int(pair[1])])
	return sorted
