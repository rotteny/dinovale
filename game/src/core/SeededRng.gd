# SPDX-License-Identifier: MIT
class_name SeededRng
extends RefCounted
## Gerador pseudoaleatório pequeno, determinístico e semeável (xorshift de 32 bits). A seed vem de
## `hash([...])` de ids estáveis (ADR-003), nunca do relógio. Não serve para segurança.

const MASK := 0xFFFFFFFF

var _state: int = 1


## Semeia a partir de partes estáveis (ex.: id do mundo, contador). Mesmas partes, mesma sequência.
func seed_from(parts: Array) -> void:
	_state = hash(parts) & MASK
	if _state == 0:
		_state = 1


## Inteiro em [0, limit). `limit` menor que 1 devolve 0.
func next_below(limit: int) -> int:
	_state ^= (_state << 13) & MASK
	_state ^= _state >> 17
	_state ^= (_state << 5) & MASK
	return _state % limit if limit > 1 else 0
