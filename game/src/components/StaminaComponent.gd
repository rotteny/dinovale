class_name StaminaComponent
extends Node
## Fôlego de uma entidade. Gasta enquanto ela corre e regenera quando não corre.
## Ao zerar, entra em exaustão: só volta a correr depois de recuperar
## `resume_threshold`, para o jogador não ficar piscando entre correr e parar.
## Não conhece input: o corpo diz se está correndo em cada `tick`.

signal stamina_changed(current: float, maximum: float)
signal exhausted
signal recovered

@export var max_stamina: float = 100.0:
	set(value):
		max_stamina = maxf(value, 1.0)
		current_stamina = minf(current_stamina, max_stamina)
## Gasto por segundo correndo.
@export var drain_per_second: float = 25.0
## Regeneração por segundo quando não está correndo.
@export var regen_per_second: float = 15.0
## Em exaustão, só volta a correr ao chegar neste valor.
@export var resume_threshold: float = 20.0

var current_stamina: float = 100.0
var is_exhausted: bool = false


## Quem não tem stamina (ou está exausto) não corre.
func can_sprint() -> bool:
	return current_stamina > 0.0 and not is_exhausted


## `draining` = true gasta; false regenera. O corpo só passa true se estiver
## de fato correndo (e não apenas com a tecla apertada).
func tick(delta: float, draining: bool = false) -> void:
	if draining:
		_set_current(current_stamina - drain_per_second * delta)
	else:
		_set_current(current_stamina + regen_per_second * delta)
	_update_exhaustion()


func to_dict() -> Dictionary:
	return {
		"current": current_stamina,
		"max": max_stamina,
		"is_exhausted": is_exhausted,
	}


## Restaura sem emitir `exhausted` nem `recovered`: carregar um save não é um evento.
func from_dict(data: Dictionary) -> void:
	max_stamina = float(data.get("max", max_stamina))
	current_stamina = clampf(float(data.get("current", current_stamina)), 0.0, max_stamina)
	is_exhausted = bool(data.get("is_exhausted", is_exhausted)) or current_stamina <= 0.0
	if current_stamina >= resume_threshold:
		is_exhausted = false
	stamina_changed.emit(current_stamina, max_stamina)


func _set_current(value: float) -> void:
	var clamped := clampf(value, 0.0, max_stamina)
	if clamped == current_stamina:
		return
	current_stamina = clamped
	stamina_changed.emit(current_stamina, max_stamina)


func _update_exhaustion() -> void:
	if not is_exhausted and current_stamina <= 0.0:
		is_exhausted = true
		exhausted.emit()
	elif is_exhausted and current_stamina >= minf(resume_threshold, max_stamina):
		is_exhausted = false
		recovered.emit()
