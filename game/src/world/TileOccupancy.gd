# SPDX-License-Identifier: MIT
class_name TileOccupancy
extends RefCounted
## Ponto único de consulta de ocupação do chão: "tem alguém (ou algo) neste retângulo?". Hoje responde por
## quem tem corpo e se move (o jogador e os dinos); a grade de construção (`BuildGrid`) entra aqui como mais uma
## fonte, sem que quem pergunta (o renascer de um nó de recurso, a construção) precise mudar.
##
## Uma fonte é um `Callable` sem argumentos que devolve os corpos (`Node2D`) que ocupam espaço agora.

## Folga em volta do retângulo: o corpo conta como ocupando se a caixa de colisão dele entra na área do tile
## aumentada disto (o corpo encostado na borda de fora do tile não segura o nó).
const BODY_MARGIN := 1.0

var _sources: Array[Callable] = []


## Registra uma fonte de corpos (`func() -> Array`). Fonte inválida é ignorada.
func add_source(source: Callable) -> void:
	if source.is_valid():
		_sources.append(source)


## O retângulo (em pixels do mundo) está livre de corpos?
func is_free(rect: Rect2) -> bool:
	var zone := rect.grow(BODY_MARGIN)
	for source in _sources:
		if not source.is_valid():
			continue
		for body: Variant in source.call():
			if is_instance_valid(body) and (body as Node2D).is_inside_tree() and _touches(zone, body as Node2D):
				return false
	return true


## O tile `cell` (de lado `tile`) está livre?
func is_cell_free(cell: Vector2i, tile: float) -> bool:
	return is_free(Rect2(Vector2(cell) * tile, Vector2(tile, tile)))


## A caixa de colisão do corpo toca a área? Sem caixa, vale o ponto do corpo.
## Limitações: só a PRIMEIRA `CollisionShape2D` filha conta, e rotação e escala dela (ou do corpo) são ignoradas:
## a caixa é o `get_rect()` da forma deslocado pela posição global do nó da forma.
func _touches(zone: Rect2, body: Node2D) -> bool:
	for child in body.get_children():
		var shape_node := child as CollisionShape2D
		if shape_node != null and shape_node.shape != null and not shape_node.disabled:
			var local := shape_node.shape.get_rect()
			return zone.intersects(Rect2(shape_node.global_position + local.position, local.size))
	return zone.has_point(body.global_position)
