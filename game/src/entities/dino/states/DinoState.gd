# SPDX-License-Identifier: MIT
class_name DinoState
extends RefCounted
## Base dos estados. Estados são lógica pura: leem e escrevem na máquina, sem
## tocar em física, sprite ou animação.

var machine: DinoStateMachine


func enter() -> void:
	pass


func exit() -> void:
	pass


func tick(_delta: float) -> void:
	pass
