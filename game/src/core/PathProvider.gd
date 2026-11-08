# SPDX-License-Identifier: MIT
class_name PathProvider
extends RefCounted
## Interface de navegação (M1, seção 1): quem anda não conhece o algoritmo. Este arquivo só define o contrato e uma
## implementação vazia (sem caminho nenhum); a real é `GridPathProvider`. Tudo em células da grade do mapa.

## Uma célula mudou (nó derrubado ou renascido, bloqueio temporário): todo caminho que passa por ela deve ser refeito.
signal cell_invalidated(cell: Vector2i)

## Números da navegação (tile, folgas, teto de pedidos).
var rules: NavigationRules = preload("res://data/balance/navigation_rules.tres")


## Caminho de `from` até `to` para um corpo do porte `size_class`; `extra_clearance` soma folga ao porte.
func request_path(_from: Vector2i, _to: Vector2i, _size_class: Enums.DinoSize, _extra_clearance: int = 0) -> PathResult:
	return PathResult.new()


## A linha reta entre as duas células cabe para o porte? (consulta barata, sem busca)
func has_line(_from: Vector2i, _to: Vector2i, _size_class: Enums.DinoSize, _extra_clearance: int = 0) -> bool:
	return false


## A célula está bloqueada (terreno ou obstáculo), sem contar a folga do porte?
func is_blocked(_cell: Vector2i) -> bool:
	return false


## Avisa que a célula mudou. Quem segura um caminho que passa por ela o refaz.
func invalidate(cell: Vector2i) -> void:
	cell_invalidated.emit(cell)


## Bloqueia a célula por `seconds` de jogo (o dino que travou marca o que está à frente).
func block_temporarily(_cell: Vector2i, _seconds: float) -> void:
	pass


## Começa um quadro de simulação: zera o teto de pedidos e deixa o tempo correr.
func begin_frame(_delta: float) -> void:
	pass


func cell_of(point: Vector2) -> Vector2i:
	return Vector2i(floori(point.x / rules.tile_px), floori(point.y / rules.tile_px))


func center_of(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * float(rules.tile_px)
