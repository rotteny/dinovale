# SPDX-License-Identifier: MIT
class_name NavigationWorld
extends Node
## Liga o mundo à grade de navegação (`GridPathProvider`): monta a grade do mapa uma vez e acompanha cada nó de recurso
## por sinal. Árvore ou rocha derrubada libera as células dela; ao renascer, bloqueia de novo. Nunca refaz o mapa
## inteiro depois da carga. `_physics_process` só delega a `tick` (o quadro da grade zera o teto de pedidos).

## A grade que os dinos usam. Vazia até `setup`.
var provider: GridPathProvider = null

var _blocking: Dictionary = {}  # ResourceNode -> Rect2 que ele cobre agora (só os que estão bloqueando)
var _build_grid: BuildGrid = null  # só o campo guarda a grade: a grade guarda o Callable do nó, sem ciclo de referência
var _build_tile: float = 16.0
var _build_blocked: Dictionary = {}  # Vector2i (célula da BuildGrid) -> Rect2 que a peça sólida cobre agora


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


## Passa a marcar como bloqueada, na grade dos dinos, a célula de cada peça sólida da `BuildGrid` (parede, porta fechada,
## Bancada), e a liberar quando ela sai, é trocada por um save ou a porta abre. A porta aberta libera o caminho.
func watch_build(build_grid: BuildGrid, tile: float) -> void:
	_build_grid = build_grid
	_build_tile = tile
	for cell in build_grid.cells():
		_sync_build_cell(cell)
	build_grid.piece_added.connect(_sync_build_cell)
	build_grid.piece_removed.connect(_on_build_piece_removed)
	build_grid.door_changed.connect(_sync_build_cell)


func _on_build_piece_removed(cell: Vector2i, _piece: Dictionary) -> void:
	_sync_build_cell(cell)


func _sync_build_cell(cell: Vector2i) -> void:
	if provider == null or _build_grid == null:
		return
	var was_blocking := _build_blocked.has(cell)
	var now_blocking := _build_grid.blocks(cell)
	if was_blocking == now_blocking:
		return
	if now_blocking:
		var rect := Rect2(Vector2(cell) * _build_tile, Vector2(_build_tile, _build_tile))
		_build_blocked[cell] = rect
		provider.add_obstacle(rect)
	else:
		provider.remove_obstacle(_build_blocked[cell] as Rect2)
		_build_blocked.erase(cell)
