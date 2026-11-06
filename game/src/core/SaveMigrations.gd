# SPDX-License-Identifier: MIT
class_name SaveMigrations
extends RefCounted
## Migrações do envelope do save (ADR-002): funções puras encadeadas, de `Dictionary` para
## `Dictionary`, uma por salto de versão (`v1_to_v2`, ...). Congeladas no tempo: não leem registry,
## cena nem classe de jogo, porque esses mudam. Rodam em memória; o arquivo só é regravado no
## próximo save. Cada versão tem uma fixture em `tests/fixtures/saves/vN.json` que nunca é removida.

## Aninhamento acima disto não é save: é ataque ou lixo. Dado real tem uns 8 níveis.
const MAX_DEPTH := 32

## Versão do FORMATO do envelope (não é a versão do jogo). Só sobe quando o formato muda.
const CURRENT_VERSION := 1


## O dado não aninha além de `MAX_DEPTH`? (Copiar um dado mais fundo estoura a recursão da engine.)
static func is_shallow(value: Variant, depth: int = 0) -> bool:
	if depth > MAX_DEPTH:
		return false
	if typeof(value) == TYPE_DICTIONARY:
		for item: Variant in (value as Dictionary).values():
			if not is_shallow(item, depth + 1):
				return false
	elif typeof(value) == TYPE_ARRAY:
		for item: Variant in value:
			if not is_shallow(item, depth + 1):
				return false
	return true


## Tabela de saltos: chave N = função que leva da versão N para N+1. Vazia enquanto a v1 é a atual.
static func steps() -> Dictionary:
	return {}


## Leva `data` até `target` encadeando os saltos de `table`. Devolve uma cópia; o original não muda.
## Falta de um salto no caminho, ou um salto que não devolve dicionário, resulta em `{}` (recusa).
static func migrate(data: Dictionary, target: int = CURRENT_VERSION, table: Dictionary = steps()) -> Dictionary:
	if not is_shallow(data):
		return {}
	var result := data.duplicate(true)
	var version := SafeRead.integer(result.get("format_version"), 0, 1, target)
	if version == 0:
		return {}
	while version < target:
		var step: Variant = table.get(version)
		if typeof(step) != TYPE_CALLABLE or not (step as Callable).is_valid():
			return {}
		var next: Variant = (step as Callable).call(result)
		if typeof(next) != TYPE_DICTIONARY:
			return {}
		result = next
		version += 1
		result["format_version"] = version
	result["format_version"] = version
	return result
