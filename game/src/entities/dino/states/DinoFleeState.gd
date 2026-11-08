# SPDX-License-Identifier: MIT
class_name DinoFleeState
extends DinoState
## Fuga da presa (M1 etapa 5b, seção 10.4): o carnívoro que a trava está perto, e ela corre à velocidade brava para longe
## dele, pelo `PathFollower`, até `flee_goal_tiles` à frente (refeito a cada quadro). Selvagem pode preferir o centro do bando
## (`flee_toward`), quando ele não está do lado do carnívoro; o domado foge só para longe, nunca para o dono.
## A ordem de quem foge não muda: ao fim da fuga o domado volta ao TAMED (que reaplica Seguir ou Ficar) e o selvagem, ao
## IDLE. A fuga termina sozinha se a ameaça não é renovada (`machine.renew_flee`) por `hold` segundos.


func enter() -> void:
	machine.follower.forget()
	machine.speed_multiplier = machine.chase_speed_multiplier()


func exit() -> void:
	machine.desired_direction = Vector2.ZERO
	machine.speed_multiplier = 1.0
	machine.flee_hold_left = 0.0


func tick(delta: float) -> void:
	machine.flee_hold_left -= delta
	if machine.flee_hold_left <= 0.0:
		machine.transition_to(Enums.DinoStateId.TAMED if machine.is_tamed else Enums.DinoStateId.IDLE)
		return
	var away := (machine.self_position - machine.flee_from).normalized()
	if away == Vector2.ZERO:
		away = Vector2.RIGHT
	var direction := away
	if machine.flee_toward_known:
		var to_center := machine.flee_toward - machine.self_position
		if to_center.length() > machine.tile_px and to_center.normalized().dot(away) > 0.0:
			direction = to_center.normalized()  # o centro do bando não está do lado do carnívoro: foge para ele
	machine.speed_multiplier = machine.chase_speed_multiplier()
	var goal := machine.self_position + direction * machine.aggression.flee_goal_tiles * machine.tile_px
	machine.desired_direction = machine.follower.update(delta, machine.self_position, goal)
	if machine.follower.stuck:  # encurralado: para, sem desistir da fuga
		machine.follower.clear_stuck()
		machine.desired_direction = Vector2.ZERO
