# SPDX-License-Identifier: MIT
class_name SpriteFacing
extends RefCounted
## Folhas de sprite do pacote: coluna 0 = baixo, 1 = cima, 2 = esquerda, 3 = direita;
## cada linha é um quadro da animação. Só apresentação.

const DOWN := 0
const UP := 1
const LEFT := 2
const RIGHT := 3
const WALK_FPS := 8.0
const WALK_FRAMES := 4


## Coluna da direção dominante; `fallback` se não há direção.
static func column_for(direction: Vector2, fallback: int) -> int:
	if direction.length_squared() < 0.0001:
		return fallback
	if absf(direction.x) > absf(direction.y):
		return RIGHT if direction.x > 0.0 else LEFT
	return DOWN if direction.y > 0.0 else UP


## Quadro (linha) do ciclo de andar para o tempo acumulado.
static func walk_row(time: float) -> int:
	return int(time * WALK_FPS) % WALK_FRAMES
