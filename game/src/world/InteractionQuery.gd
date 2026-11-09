# SPDX-License-Identifier: MIT
class_name InteractionQuery
extends Node
## Consultas de cursor da `WorldAuthority` (só leitura, sem efeito no mundo): a entidade sob o ponto do mouse. A autoridade as
## expõe como fachada; o que se faz com o alvo passa pelos `request_*`.

var authority: WorldAuthority = null


## Entidade interagível (criatura ou nó de recurso visível) sob o ponto do mundo `point`, a mais perto do ponto; null se nenhuma.
## Só consulta (o cursor do mouse escolhe alvo por aqui; o que se faz com ele passa pelos `request_*`).
## `creatures_only` ignora recursos e itens: a criatura viva sob o ponto tem prioridade sobre o resto.
func entity_at(point: Vector2, creatures_only: bool = false) -> Node2D:
	var picked := pick_at(point)
	return picked["creature"] if creatures_only else picked["any"]


## As duas escolhas do mouse numa varredura só: `{"creature": Node2D ou null, "any": Node2D ou null}` (a criatura mais perto
## sob `point` e a entidade mais perto de qualquer tipo). O cursor e o clique usam isto em vez de duas varreduras O(N).
func pick_at(point: Vector2) -> Dictionary:
	authority.pick_queries += 1
	var best: Node2D = null
	var best_distance := INF
	var best_creature: Node2D = null
	var best_creature_distance := INF
	for id: int in authority.entity_ids():
		var node := authority.entity(id) as Node2D
		if node == null or node is Player or node.get("interactable") == null:
			continue
		if node is ResourceNode and not (node as ResourceNode).is_available():
			continue
		if node is Dino and (node as Dino).health.is_dead():
			continue
		if not _pick_rect(node).grow(authority.rules.mouse_pick_radius_px).has_point(point):
			continue
		var distance := node.global_position.distance_to(point)
		if distance < best_distance:
			best_distance = distance
			best = node
		if node is Dino and distance < best_creature_distance:
			best_creature_distance = distance
			best_creature = node
	return {"creature": best_creature, "any": best}


## Retângulo do mundo que "é" a entidade para o mouse: o sprite, ou o ponto dela se ainda não tem desenho.
func _pick_rect(node: Node2D) -> Rect2:
	var sprite := node.get("visual") as Sprite2D
	if sprite != null and sprite.texture != null:
		var local := sprite.get_rect()
		return Rect2(sprite.to_global(local.position), local.size * sprite.global_scale.abs())
	var resource := node as ResourceNode
	if resource != null and resource.def != null and resource.def.texture != null:
		var size := resource.def.texture.get_size()
		return Rect2(node.global_position + Vector2(-size.x * 0.5, -size.y), size)
	return Rect2(node.global_position, Vector2.ZERO)
