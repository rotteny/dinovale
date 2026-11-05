# SPDX-License-Identifier: MIT
class_name DinoTamedState
extends DinoState
## Domesticado e parado, aguardando ordens. Seguir e ficar entram no roadmap.


func enter() -> void:
	machine.desired_direction = Vector2.ZERO
