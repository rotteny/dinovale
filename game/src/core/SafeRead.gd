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


## Versão do formato de um dado salvo: ausente = 1 (save antigo, sem campo); presente tem de ser
## inteiro em [1, known]. Inválida (texto, NaN, 0, negativa, fracionária) ou maior que a conhecida
## devolve 0 = recusar (não dá para interpretar com segurança, então nada é aplicado).
static func format_version(data: Dictionary, known: int) -> int:
	if not data.has("version"):
		return 1
	return SafeRead.integer(data["version"], 0, 1, known)


## Bloco salvo (`key` em `data`) estruturalmente válido? Ausente vale (save parcial). Presente tem de
## ser dicionário, e bloco com `version` sem `slots` é corrupção. Não olha o conteúdo de `slots`.
static func block_valid(data: Dictionary, key: String) -> bool:
	if not data.has(key):
		return true
	var block: Variant = data[key]
	if typeof(block) != TYPE_DICTIONARY:
		return false
	return not (block as Dictionary).has("version") or (block as Dictionary).has("slots")
