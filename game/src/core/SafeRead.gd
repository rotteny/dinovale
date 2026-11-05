# SPDX-License-Identifier: MIT
class_name SafeRead
extends RefCounted
## Leitura defensiva de dados de save e de rede (ADR-002): nunca aborta e nunca
## devolve lixo. Valor ausente, de tipo errado (null, Array, String...), NaN ou INF cai
## no `fallback`; número válido é limitado a [low, high].

## Teto de sanidade para um valor vindo de save e limite de coordenada.
const MAX_SAVED := 1.0e7
const COORD_LIMIT := 1.0e6


static func dict(value: Variant) -> Dictionary:
	return value if typeof(value) == TYPE_DICTIONARY else {}


static func text(value: Variant, fallback: String) -> String:
	return value if typeof(value) == TYPE_STRING else fallback


static func flag(value: Variant, fallback: bool) -> bool:
	return value if typeof(value) == TYPE_BOOL else fallback


static func number(value: Variant, fallback: float, low: float, high: float) -> float:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return fallback
	var result := float(value)
	return clampf(result, low, high) if is_finite(result) else fallback


## Inteiro dentro de [low, high]. Fora da faixa, fracionário ou inválido: `fallback`.
static func integer(value: Variant, fallback: int, low: int, high: int) -> int:
	if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
		return fallback
	var result := float(value)
	if not is_finite(result) or result != floorf(result) or result < low or result > high:
		return fallback
	return int(result)
