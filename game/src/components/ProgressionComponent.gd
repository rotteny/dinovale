# SPDX-License-Identifier: MIT
class_name ProgressionComponent
extends Node
## Nível, XP e Saber do jogador (E6, PRO-11). Só estado e regra: não conhece HUD, mundo nem quem concede o XP (a
## autoridade chama `grant_xp`; a HUD ouve os sinais). Números em `ProgressionRules`. O Saber guardado é o GASTO: o total
## deriva do nível (`rules.saber_until`), então uma curva ajustada não deixa o save com Saber inventado.

## O XP ou o nível mudou (também ao restaurar um save: a HUD se redesenha). `needed` é 0 no teto.
signal xp_changed(level: int, xp: int, needed: int)
## Subiu de nível. Um sinal só por concessão, mesmo que ela cruze vários níveis: `level` é o nível de chegada e
## `saber_gained`, o Saber somado de todos os níveis cruzados. Carregar um save NUNCA emite isto.
signal leveled_up(level: int, saber_gained: int)
## O Saber livre mudou (gasto ou ganho).
signal saber_changed(free: int)
## Aprendeu uma receita (e as do mesmo grupo). Carregar um save NUNCA emite isto.
signal recipe_learned(recipe_id: String)

const FORMAT_VERSION := 2
## Teto de uma concessão: dado externo não confiável não pode girar o laço por um valor absurdo.
const MAX_GRANT := 1000000
## Teto da lista de receitas lida de um save (dado externo): bem acima das 17 do jogo, abaixo de algo que pese.
const MAX_SAVED_RECIPES := 64
## Motivos das recusas de `learn` (chaves de `GameMessages.REASONS`).
const REASON_UNKNOWN := "unknown_recipe"
const REASON_NOT_LEARNABLE := "recipe_not_learnable"
const REASON_ALREADY := "recipe_already_learned"
const REASON_NO_SABER := "no_saber"

@export var rules: ProgressionRules = preload("res://data/balance/progression_rules.tres")

var level: int = 1
var xp: int = 0
## Livro de receitas contra o qual o custo é conferido (a autoridade põe o dela ao registrar o jogador).
var recipe_book: RecipeBook = RecipeBook.with_defaults()
## Ids das receitas aprendidas com Saber (as conhecidas de início não entram). Ordem de aprendizado.
var learned: Array[String] = []
## Saber gasto: DERIVADO das receitas aprendidas (cada grupo conta uma vez). Só leitura.
var saber_spent: int:
	get:
		return recipe_book.cost_of(learned)


func xp_needed() -> int:
	return rules.xp_to_next(level)


func is_max_level() -> bool:
	return level >= rules.level_max


func saber_total() -> int:
	return rules.saber_until(level)


func saber_free() -> int:
	return maxi(saber_total() - saber_spent, 0)


## Concede XP (a AUTORIDADE chama; nada na apresentação). Devolve quantos níveis subiu. No teto o XP não acumula.
func grant_xp(amount: int) -> int:
	if amount <= 0 or is_max_level():
		return 0
	var left := mini(amount, MAX_GRANT)
	var gained_levels := 0
	var saber_gained := 0
	while left > 0 and not is_max_level():
		var missing := xp_needed() - xp
		if left < missing:
			xp += left
			left = 0
		else:
			left -= missing
			level += 1
			xp = 0
			gained_levels += 1
			saber_gained += rules.saber_at(level)
	xp_changed.emit(level, xp, xp_needed())
	if gained_levels > 0:
		leveled_up.emit(level, saber_gained)
		saber_changed.emit(saber_free())
	return gained_levels


## XP de uma coleta concluída.
func grant_gather() -> int:
	return grant_xp(rules.xp_per_gather)


## XP de uma fabricação (gancho para a E7a).
func grant_craft() -> int:
	return grant_xp(rules.xp_per_craft)


## XP de domar um dino que ficou em `final_level`.
func grant_tame(final_level: int) -> int:
	return grant_xp(rules.tame_xp(final_level))


## O jogador conhece a receita? Conhecida de início (custo 0) ou aprendida.
func knows(recipe: RecipeDef) -> bool:
	return recipe != null and (recipe.is_known_at_start() or learned.has(recipe.id))


## Aprende `recipe_id` gastando Saber (a AUTORIDADE chama). Devolve "" se aprendeu, ou o motivo da recusa (nada muda).
## Aprender uma receita de grupo ensina o grupo todo, pagando o custo uma vez.
func learn(recipe_id: String) -> String:
	var recipe := recipe_book.find(recipe_id)
	if recipe == null:
		return REASON_UNKNOWN
	if recipe.is_known_at_start():
		return REASON_NOT_LEARNABLE
	if learned.has(recipe.id):
		return REASON_ALREADY
	if recipe.saber_cost > saber_free():
		return REASON_NO_SABER
	for member in recipe_book.group_of(recipe):
		if not learned.has(member.id):
			learned.append(member.id)
	recipe_learned.emit(recipe.id)
	saber_changed.emit(saber_free())
	return ""


func to_dict() -> Dictionary:
	return {"version": FORMAT_VERSION, "level": level, "xp": xp, "recipes": learned.duplicate()}


## Restaura sem emitir `leveled_up` nem `recipe_learned` (carregar não é evento de jogo). Campo ausente ou inválido fica como
## está; número fora da faixa é LIMITADO (nível acima do teto vira o teto, XP acima do que o nível pede fica no limite).
## As receitas valem na ordem salva, só as que existem, são aprendíveis e cabem no Saber do nível; o resto é descartado.
## Save v1 guardava `saber_spent` sem receitas: o campo é ignorado (0 gasto, nada inventado).
func from_dict(data: Dictionary) -> void:
	level = int(SafeRead.number(data.get("level"), level, 1.0, rules.level_max))
	var needed := xp_needed()
	xp = int(SafeRead.number(data.get("xp"), xp, 0.0, maxi(needed - 1, 0))) if needed > 0 else 0
	_restore_recipes(SafeRead.list(data.get("recipes")))
	xp = mini(xp, maxi(needed - 1, 0))  # o XP de antes pode não caber no nível lido
	xp_changed.emit(level, xp, needed)
	saber_changed.emit(saber_free())


## Receitas do save: validadas uma a uma (nunca aborta). Substitui as de agora (o save é a fonte da verdade).
func _restore_recipes(saved: Array) -> void:
	learned = []
	for entry: Variant in saved.slice(0, MAX_SAVED_RECIPES):
		if typeof(entry) != TYPE_STRING:
			continue
		var recipe := recipe_book.find(str(entry))
		if recipe == null or recipe.is_known_at_start() or learned.has(recipe.id):
			continue
		var candidate: Array[String] = learned.duplicate()
		for member in recipe_book.group_of(recipe):
			if not candidate.has(member.id):
				candidate.append(member.id)
		if recipe_book.cost_of(candidate) <= saber_total():
			learned = candidate
