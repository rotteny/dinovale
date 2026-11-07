# SPDX-License-Identifier: MIT
class_name SeededRng
extends RefCounted
## Gerador pseudoaleatório pequeno, determinístico e semeável (xorshift de 32 bits). A seed vem de um FNV-1a próprio
## sobre as partes (ids estáveis, ADR-003), nunca do relógio e nunca de `hash()` da engine, que não promete o mesmo
## valor entre versões do Godot. Não serve para segurança.

const MASK := 0xFFFFFFFF
const FNV_OFFSET := 0x811C9DC5
const FNV_PRIME := 0x01000193

var _state: int = 1


## Semeia a partir de partes estáveis (ex.: id do mundo, contador). Mesmas partes, mesma sequência.
func seed_from(parts: Array) -> void:
	_state = hash_parts(parts)
	if _state == 0:
		_state = 1


## FNV-1a de 32 bits sobre os bytes UTF-8 de cada parte, escrita como `<tipo>:<valor>|` (5 e "5" não colidem; 5 e 5.0
## também não). Estável entre versões e plataformas.
static func hash_parts(parts: Array) -> int:
	var result := FNV_OFFSET
	for part: Variant in parts:
		for byte: int in ("%d:%s|" % [typeof(part), str(part)]).to_utf8_buffer():
			result = ((result ^ byte) * FNV_PRIME) & MASK
	return result


## Inteiro em [0, limit). `limit` menor que 1 devolve 0.
func next_below(limit: int) -> int:
	_state ^= (_state << 13) & MASK
	_state ^= _state >> 17
	_state ^= (_state << 5) & MASK
	return _state % limit if limit > 1 else 0
