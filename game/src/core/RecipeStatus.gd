# SPDX-License-Identifier: MIT
class_name RecipeStatus
extends RefCounted
## Estado de uma receita para um jogador (E7b): conhecida, aprendível (tem Saber) ou travada (falta Saber). Regra pura: a tela
## só a lê, e quem decide aprender é a autoridade (`WorldAuthority.request_learn_recipe`).

enum State { KNOWN, LEARNABLE, LOCKED }


static func of(recipe: RecipeDef, progression: ProgressionComponent) -> State:
	if progression.knows(recipe):
		return State.KNOWN
	return State.LEARNABLE if saber_missing(recipe, progression) == 0 else State.LOCKED


## Quanto Saber falta para aprender `recipe` (0 = tem o bastante ou já conhece).
static func saber_missing(recipe: RecipeDef, progression: ProgressionComponent) -> int:
	if progression.knows(recipe):
		return 0
	return maxi(recipe.saber_cost - progression.saber_free(), 0)


## O que a lista mostra ao lado do nome: o que falta, ou o que custa.
static func label(recipe: RecipeDef, progression: ProgressionComponent) -> String:
	match of(recipe, progression):
		State.KNOWN:
			return "Conhecida"
		State.LEARNABLE:
			return "Aprender: %d Saber" % recipe.saber_cost
	return "Travada: faltam %d Saber (custa %d)" % [saber_missing(recipe, progression), recipe.saber_cost]
