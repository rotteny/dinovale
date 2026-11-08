# SPDX-License-Identifier: MIT
class_name AttackTargeting
extends RefCounted
## Regra única de escolha do alvo do golpe. O destaque na tela e o pedido `request_attack` usam esta mesma
## função (via `Player.attack_target`), então o golpe vai SEMPRE no dino destacado.
##
## Regra: entre os candidatos ao alcance e do lado para onde o jogador olha (produto escalar com a direção
## do olhar >= `front_dot_min` (`ActionRules`)), vence o mais próximo; empate de distância vai para o mais alinhado com o
## olhar. Histerese: o alvo atual só perde o lugar para um candidato que esteja mais perto por mais de
## `hysteresis_px` (`ActionRules`), para o destaque não piscar entre dois dinos colados. Sem estado e sem nós de cena.

## Abaixo disto o candidato está sobre o jogador: vale como "à frente" (não há direção a comparar).
const OVERLAP_PX := 0.5


## Escolhe o alvo. `candidates` já vem filtrado pelo estado (vivo, selvagem); aqui só entram geometria e histerese.
## `current` é o alvo do quadro anterior (ou null). Devolve null se ninguém está ao alcance e à frente.
static func choose(origin: Vector2, facing: Vector2, reach: float, candidates: Array[Node2D], current: Node2D,
		front_dot_min: float, hysteresis_px: float) -> Node2D:
	var look := _look(facing)
	var best: Node2D = null
	var best_distance := INF
	var best_dot := -INF
	var current_distance := INF
	for candidate in candidates:
		if candidate == null:
			continue
		var distance := _distance_in_front(origin, look, reach, candidate, front_dot_min)
		if distance < 0.0:
			continue
		var dot := _dot(origin, look, candidate)
		if candidate == current:
			current_distance = distance
		if distance < best_distance - 0.001 or (absf(distance - best_distance) <= 0.001 and dot > best_dot):
			best = candidate
			best_distance = distance
			best_dot = dot
	if current_distance < INF and best != current and current_distance <= best_distance + hysteresis_px:
		return current
	return best


## O candidato está à frente de quem olha para `facing`? A autoridade usa isto com a direção que ELA mantém.
static func is_in_front(origin: Vector2, facing: Vector2, candidate: Node2D, front_dot_min: float) -> bool:
	return _distance_in_front(origin, _look(facing), INF, candidate, front_dot_min) >= 0.0


static func _look(facing: Vector2) -> Vector2:
	return facing.normalized() if facing.length_squared() > 0.0001 else Vector2.DOWN


## Distância ao candidato se ele está ao alcance e à frente; -1 se não.
static func _distance_in_front(origin: Vector2, look: Vector2, reach: float, candidate: Node2D, front_dot_min: float) -> float:
	var offset := candidate.global_position - origin
	var distance := offset.length()
	if distance > reach:
		return -1.0
	if distance > OVERLAP_PX and look.dot(offset / distance) < front_dot_min:
		return -1.0
	return distance


static func _dot(origin: Vector2, look: Vector2, candidate: Node2D) -> float:
	var offset := candidate.global_position - origin
	return look.dot(offset.normalized()) if offset.length_squared() > 0.0001 else 1.0
