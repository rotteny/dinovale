# SPDX-License-Identifier: MIT
class_name NavigationWorld
extends Node
## Liga o mundo à grade de navegação (`GridPathProvider`): monta a grade do mapa uma vez e acompanha cada nó de recurso
## por sinal. Árvore ou rocha derrubada libera as células dela; ao renascer, bloqueia de novo. Nunca refaz o mapa
## inteiro depois da carga. `_physics_process` só delega a `tick` (o quadro da grade zera o teto de pedidos).

## A grade que os dinos usam. Vazia até `setup`.
var provider: GridPathProvider = null

var _blocking: Dictionary = {}  # ResourceNode -> Rect2 que ele cobre agora (só os que estão bloqueando)


func _physics_process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	if provider != null:
		provider.begin_frame(delta)


## Monta a grade com terreno, cenário e os nós de recurso de `field` (opcional) e passa a ouvir o estado deles.
func setup(map: IslandMap, world_rules: WorldRules, nav_rules: NavigationRules, field: ResourceField) -> void:
	provider = GridPathProvider.from_map(map, world_rules, nav_rules, false)  # carga em massa aberta: fecha uma vez só
	if field != null:
		for node in field.nodes():
			_sync(node)
			node.state_changed.connect(_sync)
	provider.end_bulk()


## O nó bloqueia o corpo agora? (a mesma regra da colisão dos pés: cheio ou parcial, não esgotado)
static func blocks_now(node: ResourceNode) -> bool:
	return node.def != null and node.def.blocks_when_full and node.def.foot_size != Vector2.ZERO \
			and node.component.is_available()


## Só a virada (cheio <-> esgotado) mexe na grade: o aviso vem a cada golpe, mas a grade só muda quando o nó some ou volta.
func _sync(node: ResourceNode) -> void:
	var was_blocking := _blocking.has(node)
	var now_blocking := blocks_now(node)
	if was_blocking == now_blocking:
		return
	if now_blocking:
		var rect := GridPathProvider.obstacle_rect(node.def.foot_size, node.global_position)
		_blocking[node] = rect
		provider.add_obstacle(rect)
	else:
		provider.remove_obstacle(_blocking[node] as Rect2)
		_blocking.erase(node)
