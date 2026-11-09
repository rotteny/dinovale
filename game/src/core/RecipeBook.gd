# SPDX-License-Identifier: MIT
class_name RecipeBook
extends RefCounted
## Livro de receitas do mundo (E7a): as de `data/recipes/` (lista fixa, sem varrer pasta) e a pergunta "o jogador conhece?".
## Hoje conhecida = `known_at_start`; a E7b troca isto por "aprendida com Saber" sem mudar quem pergunta.

const DEFAULT_RECIPES: Array[RecipeDef] = [
	preload("res://data/recipes/wooden_spear.tres"),
	preload("res://data/recipes/axe_stone.tres"),
	preload("res://data/recipes/pickaxe_stone.tres"),
	preload("res://data/recipes/sleep_staff.tres"),
	preload("res://data/recipes/workbench.tres"),
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
	if recipe == null or not recipe.is_valid():
		return false
	if not _recipes.has(recipe.id):
		_order.append(recipe.id)
	_recipes[recipe.id] = recipe
	return true


## Receita pelo id, ou null.
func find(recipe_id: String) -> RecipeDef:
	return _recipes.get(recipe_id)


## Todas, na ordem em que entraram.
func all() -> Array[RecipeDef]:
	var list: Array[RecipeDef] = []
	for recipe_id in _order:
		list.append(_recipes[recipe_id])
	return list


## As que o jogador conhece (para a tela de fabricação).
func known() -> Array[RecipeDef]:
	var list: Array[RecipeDef] = []
	for recipe in all():
		if is_known(recipe):
			list.append(recipe)
	return list


func is_known(recipe: RecipeDef) -> bool:
	return recipe != null and recipe.known_at_start
