# SPDX-License-Identifier: MIT
class_name EdgeMarker
extends RefCounted
## Marcador na borda da tela (E12, SOB-13): lógica pura de onde um alvo fora da vista aparece. Sem nó e sem textura: quem
## desenha (`CorpseMarker`) passa o ponto do alvo em coordenadas de tela e o tamanho da tela.


## `{visible, position, angle}`. Alvo DENTRO da tela (descontada a `margin` da borda) não precisa de marcador: `visible` falso.
## Fora, o marcador fica na borda interna (a `margin` da borda), na reta do centro da tela até o alvo, apontando para ele
## (`angle` em radianos, 0 = para a direita).
static func place(target: Vector2, view_size: Vector2, margin: float) -> Dictionary:
	var inner := Rect2(Vector2(margin, margin), (view_size - Vector2(margin, margin) * 2.0).max(Vector2.ZERO))
	if inner.has_point(target):
		return {"visible": false, "position": target, "angle": 0.0}
	var center := view_size * 0.5
	var direction := target - center
	var half := inner.size * 0.5
	var scale_x := half.x / absf(direction.x) if direction.x != 0.0 else INF
	var scale_y := half.y / absf(direction.y) if direction.y != 0.0 else INF
	var scale := minf(scale_x, scale_y)
	return {"visible": true, "position": center + direction * scale, "angle": direction.angle()}
