# SPDX-License-Identifier: MIT
class_name MapBounds
extends Resource
## Limite do mapa em pixels do mundo, só dado (`res://data/world/map_bounds.tres`). A câmera para
## quando a borda da tela encosta aqui; o mapa novo (etapa B) troca o valor no `.tres`, sem código.

## Retângulo do mapa: origem e tamanho em pixels.
@export var rect: Rect2 = Rect2(0.0, 0.0, 4096.0, 4096.0)


## Menor retângulo (em pixels) que a câmera pode mostrar: o mapa tem de caber nele ao menos.
func fits_view(view_size: Vector2) -> bool:
	return rect.size.x >= view_size.x and rect.size.y >= view_size.y


## Centro da câmera para seguir `target` sem mostrar nada fora do mapa. Mapa menor que a tela
## num eixo: centra o mapa nesse eixo. É a mesma conta que o `Camera2D` faz com `limit_*`.
func clamp_center(target: Vector2, view_size: Vector2) -> Vector2:
	var half := view_size * 0.5
	var low := rect.position + half
	var high := rect.end - half
	return Vector2(
			clampf(target.x, low.x, high.x) if low.x <= high.x else rect.get_center().x,
			clampf(target.y, low.y, high.y) if low.y <= high.y else rect.get_center().y)
