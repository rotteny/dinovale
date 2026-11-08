# SPDX-License-Identifier: MIT
class_name ResourceField
extends Node2D
## Conjunto dos nós de recurso do mundo: monta os `ResourceNode` a partir do mapa estático (`populate`), acha
## os que já são filhos, grava e restaura o estado no save e responde onde estão (sorteio de respawn).
##
## O save leva SÓ os nós esgotados (id, tipo, instante de volta): o mapa é estático e o resto nasce cheio (v4).

const NodeScene: PackedScene = preload("res://src/entities/resource/ResourceNode.tscn")

## Consulta de ocupação do chão: o nó que voltaria sobre alguém espera. Opcional (sem ela, volta sempre).
var occupancy: TileOccupancy = null

## Nós por id. Montado no primeiro uso a partir dos filhos.
## Regras do servidor para os nós criados por `populate` (1,0 = as do dado). Defina antes de `populate`.
var yield_multiplier: float = 1.0
var respawn_rate: float = 1.0
## Leitor do relógio do mundo, `() -> float` (ADR-006); passa aos nós criados aqui. Defina antes de `populate`.
var clock: Callable = Callable()

var _by_id: Dictionary = {}
var _indexed: bool = false
var _waiting: Dictionary = {}  # ResourceNode esgotado -> true: só estes são olhados
var _next_check: float = INF  # nenhum esgotado vence antes disto (o resto do tempo `tick` não faz nada)


func _physics_process(_delta: float) -> void:
	tick()


## Acorda os nós esgotados cujo prazo venceu (ADR-006). Só compara o relógio com o menor prazo; sem esgotado vencido,
## não faz nada. Público para os testes e para o servidor, que não esperam quadros.
func tick() -> void:
	if _waiting.is_empty() or not clock.is_valid() or float(clock.call()) < _next_check:
		return
	var next := INF
	for node: ResourceNode in _waiting.keys():
		if not is_instance_valid(node):
			_waiting.erase(node)
			continue
		node.component.tick()
		if node.component.depleted:
			next = minf(next, node.component.next_check_at())
	_next_check = next


func _ready() -> void:
	# O desenho é montado aqui: a entidade (em `entities/`) não conhece a UI.
	for node in nodes():
		_attach_view(node)


## Cria um nó por posição do mapa, para cada tipo que a v0.2 instancia (`WorldRules.node_defs`). O id é
## o do mapa (`map.node_ids`, ADR-007: opaco e estável entre revisões). Devolve
## quantos nós criou. Chame uma vez, antes de registrar na autoridade.
func populate(map: IslandMap, rules: WorldRules) -> int:
	_index()
	var created := 0
	var kinds: Array = map.nodes.keys()
	kinds.sort()
	for kind: String in kinds:
		var def := rules.node_def_of(kind)
		if def == null:
			continue
		var cells: Array = map.nodes[kind]
		var ids: Array = map.node_ids.get(kind, [])
		for i in cells.size():
			var cell: Vector2i = cells[i]
			var node: ResourceNode = NodeScene.instantiate()
			node.node_id = ids[i]
			node.clock = clock
			node.def = def
			node.position = map.center_of(cell)
			node.yield_multiplier = yield_multiplier
			node.respawn_rate = respawn_rate
			if kind == "loose_stone" and i < map.loose_core_count:  # o exportador põe as do núcleo primeiro
				node.respawn_override = rules.loose_core_respawn_seconds
			add_node(node)
			created += 1
	return created


## Põe `node` no campo (filho, índice e desenho). Id repetido ou vazio é recusado (false).
func add_node(node: ResourceNode) -> bool:
	_index()
	if node.node_id == "" or _by_id.has(node.node_id):
		return false
	_by_id[node.node_id] = node
	_track(node)
	if node.occupancy == null:
		node.occupancy = occupancy
	add_child(node)
	if is_node_ready():
		_attach_view(node)
	return true


func nodes() -> Array[ResourceNode]:
	_index()
	var result: Array[ResourceNode] = []
	for node: ResourceNode in _by_id.values():
		result.append(node)
	return result


func node_count() -> int:
	_index()
	return _by_id.size()


func node_by_id(node_id: String) -> ResourceNode:
	_index()
	return _by_id.get(node_id) as ResourceNode


## Nós esgotados ou de colheita parcial, compatível com JSON, em ordem estável de id. Nó inteiro não entra: é o
## estado do mapa novo.
func to_list() -> Array:
	_index()
	var ids: Array = _by_id.keys()
	ids.sort()
	var list: Array = []
	for node_id: String in ids:
		var node: ResourceNode = _by_id[node_id]
		if not node.component.depleted and not node.component.is_partial() and not node.component.has_hits():
			continue
		var state: Dictionary = node.component.to_dict()
		state["id"] = node_id
		list.append(state)
	return list


## Aplica uma lista salva: os listados ficam como o save diz e TODOS os outros voltam cheios (a lista só
## leva esgotados). Id desconhecido, entrada que não é dicionário e excesso são ignorados (o mapa antigo
## tinha outros ids).
func restore_list(list: Array) -> void:
	_index()
	var chosen: Dictionary = {}  # id -> entrada
	for entry: Variant in list:
		if chosen.size() >= _by_id.size():  # o teto conta só o que vale: lixo no início não esconde nó válido
			break
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var node_id := SafeRead.text((entry as Dictionary).get("id"), "")
		if _by_id.has(node_id) and not chosen.has(node_id):
			chosen[node_id] = entry
	for node in nodes():
		if chosen.has(node.node_id):
			node.component.from_dict(chosen[node.node_id])
		elif node.component.depleted or node.component.is_partial():
			node.component.from_dict({"def": node.def.id, "depleted": false})


## Liga o nó ao campo: o relógio (se ele não trouxe um) e o aviso de cheio/esgotado.
func _track(node: ResourceNode) -> void:
	node.state_changed.connect(_on_node_changed)
	if not node.clock.is_valid():
		node.clock = clock


## Esgotou: entra na lista de quem espera (e puxa a próxima olhada); voltou: sai.
func _on_node_changed(node: ResourceNode) -> void:
	if node.component.depleted:
		_waiting[node] = true
		_next_check = minf(_next_check, node.component.next_check_at())
	else:
		_waiting.erase(node)


func _attach_view(node: ResourceNode) -> void:
	var view := ResourceNodeView.new()
	view.node = node
	node.add_child(view)


func _index() -> void:
	if _indexed:
		return
	_indexed = true
	for child in get_children():
		var node := child as ResourceNode
		if node != null and node.node_id != "" and not _by_id.has(node.node_id):
			_by_id[node.node_id] = node
			_track(node)
