# SPDX-License-Identifier: MIT
class_name SizeClassRules
extends Resource
## Colisão dos pés por porte (GDD 4.2, tabela de portes), só dados em `res://data/balance/size_classes.tres`. Só os pés
## colidem com o mundo; a caixa de golpe e de alvo (hurtbox) é outra, por espécie (`DinoBaseStats.hitbox_size`).
## Os valores são [premissa] do GDD: passagem mínima = ceil((colisão + 2) / 16) tiles.

@export var foot_small: Vector2 = Vector2(12.0, 12.0)
@export var foot_medium: Vector2 = Vector2(14.0, 14.0)
@export var foot_large: Vector2 = Vector2(28.0, 24.0)


## Pés (largura, altura em pixels) do porte.
func foot_of(size: Enums.DinoSize) -> Vector2:
	if size == Enums.DinoSize.SMALL:
		return foot_small
	if size == Enums.DinoSize.LARGE:
		return foot_large
	return foot_medium
