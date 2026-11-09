# SPDX-License-Identifier: MIT
class_name GridLine
extends RefCounted
## Células que um segmento de reta atravessa numa grade quadrada (passo a passo de Amanatides e Woo). Serve a quem precisa
## saber se há parede entre dois pontos: a mordida do bravo (`BuildGrid.segment_blocked`) e a linha de visada da
## navegação (`GridPathProvider.line_blocked`). Lógica pura, sem nó.

## Limite de células por segmento: o alcance de golpe e a visada são de poucos tiles; um ponto absurdo não trava o jogo.
const MAX_CELLS := 256


## As células de `from` a `to` (pontos em pixels do mundo), a primeira e a última incluídas, na ordem em que o segmento as
## cruza. Ponto não finito ou `tile` não positivo: lista vazia. Passa do teto: para nele.
static func cells(from: Vector2, to: Vector2, tile: float) -> Array[Vector2i]:
	var list: Array[Vector2i] = []
	if tile <= 0.0 or not from.is_finite() or not to.is_finite():
		return list
	var cell := Vector2i(floori(from.x / tile), floori(from.y / tile))
	var last := Vector2i(floori(to.x / tile), floori(to.y / tile))
	list.append(cell)
	var delta := to - from
	var step := Vector2i(int(signf(delta.x)), int(signf(delta.y)))
	var t_max := Vector2(INF, INF)
	var t_delta := Vector2(INF, INF)
	if step.x != 0:
		var next_x := float(cell.x + (1 if step.x > 0 else 0)) * tile
		t_max.x = (next_x - from.x) / delta.x
		t_delta.x = tile / absf(delta.x)
	if step.y != 0:
		var next_y := float(cell.y + (1 if step.y > 0 else 0)) * tile
		t_max.y = (next_y - from.y) / delta.y
		t_delta.y = tile / absf(delta.y)
	while cell != last and list.size() < MAX_CELLS:
		if t_max.x < t_max.y:
			cell.x += step.x
			t_max.x += t_delta.x
		else:
			cell.y += step.y
			t_max.y += t_delta.y
		list.append(cell)
	return list
