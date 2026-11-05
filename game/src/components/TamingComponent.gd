# SPDX-License-Identifier: MIT
class_name TamingComponent
extends Node
## Domesticação: enquanto a criatura selvagem está inconsciente, consome a comida
## ideal em intervalos e preenche `taming_progress`. Em 100% chama
## `DinoStateMachine.mark_tamed()`.
##
## Eficiência (0 a 100): começa em 100 quando a criatura dorme e só cai: por segundo
## dormindo, por refeição e por ataque recebido dormindo (`apply_attack`). Ao
## domesticar, o nível sobe pela fórmula de `DinoLevelRules.final_level`; com 0% ainda
## domestica, sem bônus. Se a criatura morre no meio, a domesticação falha.
##
## Regras:
## - Só avança com criatura selvagem e inconsciente.
## - Comida que não é a ideal nunca é consumida.
## - Sem comida ideal o progresso para (e não regride, nem o relógio da refeição).
## - Se a criatura acordar antes de terminar, o progresso e o relógio zeram. A
##   comida que sobrou PERMANECE no inventário: o que foi consumido já foi gasto,
##   o resto continua lá para a próxima tentativa.
##
## Não guarda estoque próprio: consome do `inventory` compartilhado da criatura,
## onde o jogador deposita a comida.

signal progress_changed(current: float, maximum: float)
signal food_consumed(item_id: String)
signal efficiency_changed(efficiency: float)
## Nível atual da criatura e o nível que ela teria se domesticasse agora.
signal level_preview_changed(level: int, preview: int)
## Domesticação concluída: o nível final já foi calculado.
signal level_finalized(final_level: int)
## A criatura morreu durante a domesticação: a comida consumida está perdida.
signal taming_failed

const MAX_PROGRESS := 100.0
const MAX_EFFICIENCY := 100.0

@export var ideal_food: String = Items.BERRY
## Inventário compartilhado de onde a comida é consumida.
@export var inventory: InventoryComponent
## Segundos entre refeições.
@export var seconds_per_meal: float = 5.0
@export var rules: TamingRules = preload("res://data/balance/taming_rules.tres")
@export var level_rules: DinoLevelRules = preload("res://data/balance/dino_level_rules.tres")
@export var stats: DinoBaseStats = preload("res://data/dino/placeholder_dino.tres")
## Quem fornece a vida: a morte da criatura falha a domesticação.
@export var health: HealthComponent:
	set(value):
		if health != null and health.died.is_connected(_on_died):
			health.died.disconnect(_on_died)
		health = value
		if health != null:
			health.died.connect(_on_died)
## Ligado por setter: o sinal precisa ser conectado quando a máquina é atribuída,
## venha ela da cena ou de código.
@export var state_machine: DinoStateMachine:
	set(value):
		if state_machine != null and state_machine.state_changed.is_connected(_on_state_changed):
			state_machine.state_changed.disconnect(_on_state_changed)
		state_machine = value
		if state_machine != null:
			state_machine.state_changed.connect(_on_state_changed)

## Nível da criatura. Quem a compõe (o `Dino`) o mantém; domesticar o substitui pelo final.
var level: int = 10:
	set(value):
		level = level_rules.clamp_level(value)
		_emit_preview()

var taming_progress: float = 0.0
var efficiency: float = MAX_EFFICIENCY
var has_failed: bool = false

var _meal_timer: float = 0.0


func _physics_process(delta: float) -> void:
	tick(delta)


func is_active() -> bool:
	return _is_wild_and_asleep() and not (health != null and health.is_dead())


## Refeições totais para domesticar neste nível.
func meals_required() -> int:
	return level_rules.meals_required(stats.base_meals, stats.difficulty, level)


## Nível que a criatura teria se a domesticação terminasse agora.
func preview_level() -> int:
	return level_rules.clamp_level(level_rules.final_level(level, efficiency))


func food_available() -> int:
	return inventory.count(ideal_food) if inventory != null else 0


func tick(delta: float) -> void:
	if not is_active() or taming_progress >= MAX_PROGRESS:
		return
	_lose_efficiency(rules.time_drain_per_second * delta)
	if food_available() <= 0:
		return
	_meal_timer += delta
	while _meal_timer >= seconds_per_meal and food_available() > 0 \
			and taming_progress < MAX_PROGRESS and is_active():
		_meal_timer -= seconds_per_meal
		_consume_meal()


## Ataque recebido com a criatura dormindo e selvagem: derruba a Eficiência por
## `fixo[atacante] + 0,5 x % da vida máxima perdida`. Acordada, não faz nada.
## Atacante desconhecido é ignorado. Retorna quanto de Eficiência caiu.
func apply_attack(attacker_kind: String, health_lost_percent: float) -> float:
	if not is_active() or not rules.knows_attacker(attacker_kind):
		return 0.0
	return _lose_efficiency(rules.attack_loss(attacker_kind, health_lost_percent))


## Corrige um save incoerente: progresso só existe para quem está desmaiado ou já
## domesticado. Chame depois de restaurar a máquina.
func reconcile() -> void:
	if state_machine == null or state_machine.is_tamed:
		return
	if not is_active():
		_reset_progress()
	elif taming_progress >= MAX_PROGRESS:
		# 100% dormindo e selvagem não acontece em jogo (a última refeição domestica). Em
		# vez de travar sem poder concluir, volta à penúltima refeição: a próxima conclui.
		var total := maxi(meals_required(), 1)
		taming_progress = MAX_PROGRESS * (total - 1) / total
		progress_changed.emit(taming_progress, MAX_PROGRESS)


func to_dict() -> Dictionary:
	return {
		"progress": taming_progress,
		"meal_timer": _meal_timer,
		"efficiency": efficiency,
	}


## Restaura sem emitir `food_consumed` nem chamar `mark_tamed`. Valida e limita tudo:
## save e RPC são dados não confiáveis. Restaure ANTES da máquina de estados.
func from_dict(data: Dictionary) -> void:
	taming_progress = SafeRead.number(data.get("progress"), taming_progress, 0.0, MAX_PROGRESS)
	_meal_timer = SafeRead.number(data.get("meal_timer"), 0.0, 0.0, maxf(seconds_per_meal, 0.0))
	efficiency = SafeRead.number(data.get("efficiency"), MAX_EFFICIENCY, 0.0, MAX_EFFICIENCY)
	progress_changed.emit(taming_progress, MAX_PROGRESS)
	efficiency_changed.emit(efficiency)
	_emit_preview()


func _consume_meal() -> void:
	if inventory.remove(ideal_food, 1) < 1:
		return
	var total := meals_required()
	var eaten := mini(roundi(taming_progress * total / MAX_PROGRESS) + 1, total)
	taming_progress = MAX_PROGRESS * eaten / total
	food_consumed.emit(ideal_food)
	progress_changed.emit(taming_progress, MAX_PROGRESS)
	_lose_efficiency(rules.meal_loss(ideal_food))
	if taming_progress >= MAX_PROGRESS:
		_finish()


## Fecha a domesticação: o nível final sai da Eficiência de agora.
func _finish() -> void:
	var final_level := preview_level()
	if not state_machine.mark_tamed():
		return
	level = final_level
	level_finalized.emit(level)


## Retorna quanto caiu de fato (limitado a 0). Valor negativo recupera (limitado a 100)
## e o retorno é negativo.
func _lose_efficiency(amount: float) -> float:
	var change := minf(amount, efficiency) if amount > 0.0 else maxf(amount, efficiency - MAX_EFFICIENCY)
	if change == 0.0:
		return 0.0
	efficiency -= change
	efficiency_changed.emit(efficiency)
	_emit_preview()
	return change


func _emit_preview() -> void:
	level_preview_changed.emit(level, preview_level())


func _reset_progress() -> void:
	_meal_timer = 0.0
	if taming_progress != 0.0:
		taming_progress = 0.0
		progress_changed.emit(taming_progress, MAX_PROGRESS)
	if efficiency != MAX_EFFICIENCY:
		efficiency = MAX_EFFICIENCY
		efficiency_changed.emit(efficiency)
		_emit_preview()


func _is_wild_and_asleep() -> bool:
	return state_machine != null and not state_machine.is_tamed \
			and state_machine.current_id == Enums.DinoStateId.UNCONSCIOUS


func _on_died() -> void:
	if not _is_wild_and_asleep():
		return
	has_failed = true
	_reset_progress()
	taming_failed.emit()


## Acordou selvagem antes de terminar: zera. Acordar domesticado (UNCONSCIOUS -> TAMED)
## mantém os 100%.
func _on_state_changed(previous: Enums.DinoStateId, current: Enums.DinoStateId) -> void:
	if previous == Enums.DinoStateId.UNCONSCIOUS and current != Enums.DinoStateId.TAMED:
		_reset_progress()
