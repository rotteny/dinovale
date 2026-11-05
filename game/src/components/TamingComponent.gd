class_name TamingComponent
extends Node
## Domesticação: enquanto a criatura selvagem está inconsciente, consome a comida
## ideal em intervalos e preenche `taming_progress`. Em 100% chama
## `DinoStateMachine.mark_tamed()`.
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

const MAX_PROGRESS := 100.0

@export var ideal_food: String = Items.BERRY
## Inventário compartilhado de onde a comida é consumida.
@export var inventory: InventoryComponent
## Segundos entre refeições.
@export var seconds_per_meal: float = 5.0
## Quanto cada refeição preenche (de 100).
@export var progress_per_meal: float = 20.0
## Ligado por setter: o sinal precisa ser conectado quando a máquina é atribuída,
## venha ela da cena ou de código.
@export var state_machine: DinoStateMachine:
	set(value):
		if state_machine != null and state_machine.state_changed.is_connected(_on_state_changed):
			state_machine.state_changed.disconnect(_on_state_changed)
		state_machine = value
		if state_machine != null:
			state_machine.state_changed.connect(_on_state_changed)

var taming_progress: float = 0.0

var _meal_timer: float = 0.0


func _physics_process(delta: float) -> void:
	tick(delta)


func is_active() -> bool:
	return state_machine != null and not state_machine.is_tamed \
			and state_machine.current_id == Enums.DinoStateId.UNCONSCIOUS


func food_available() -> int:
	return inventory.count(ideal_food) if inventory != null else 0


func tick(delta: float) -> void:
	if not is_active() or taming_progress >= MAX_PROGRESS or food_available() <= 0:
		return
	_meal_timer += delta
	while _meal_timer >= seconds_per_meal and food_available() > 0 \
			and taming_progress < MAX_PROGRESS:
		_meal_timer -= seconds_per_meal
		_consume_meal()


## Corrige um save incoerente: progresso só existe para quem está desmaiado ou já
## domesticado. Chame depois de restaurar a máquina.
func reconcile() -> void:
	if state_machine != null and not state_machine.is_tamed and not is_active():
		_reset_progress()


func to_dict() -> Dictionary:
	return {
		"progress": taming_progress,
		"meal_timer": _meal_timer,
	}


## Restaura sem emitir `food_consumed` nem chamar `mark_tamed`. Valida e limita tudo:
## save e RPC são dados não confiáveis. Restaure ANTES da máquina de estados.
func from_dict(data: Dictionary) -> void:
	taming_progress = clampf(float(data.get("progress", taming_progress)), 0.0, MAX_PROGRESS)
	_meal_timer = clampf(float(data.get("meal_timer", 0.0)), 0.0, maxf(seconds_per_meal, 0.0))
	progress_changed.emit(taming_progress, MAX_PROGRESS)


func _consume_meal() -> void:
	if inventory.remove(ideal_food, 1) < 1:
		return
	taming_progress = minf(taming_progress + progress_per_meal, MAX_PROGRESS)
	food_consumed.emit(ideal_food)
	progress_changed.emit(taming_progress, MAX_PROGRESS)
	if taming_progress >= MAX_PROGRESS:
		state_machine.mark_tamed()


func _reset_progress() -> void:
	_meal_timer = 0.0
	if taming_progress != 0.0:
		taming_progress = 0.0
		progress_changed.emit(taming_progress, MAX_PROGRESS)


## Acordou selvagem antes de terminar: zera. Acordar domesticado (UNCONSCIOUS -> TAMED)
## mantém os 100%.
func _on_state_changed(previous: Enums.DinoStateId, current: Enums.DinoStateId) -> void:
	if previous == Enums.DinoStateId.UNCONSCIOUS and current != Enums.DinoStateId.TAMED:
		_reset_progress()
