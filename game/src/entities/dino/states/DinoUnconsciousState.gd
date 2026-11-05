# SPDX-License-Identifier: MIT
class_name DinoUnconsciousState
extends DinoState
## Desmaiado. A saída vem de fora: `TorporComponent.woke_up` ou
## `DinoStateMachine.mark_tamed()`.


func enter() -> void:
	machine.desired_direction = Vector2.ZERO
