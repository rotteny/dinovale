# SPDX-License-Identifier: MIT
class_name ResourceField
extends Node2D
## Conjunto dos nós de recurso do mundo: acha os `ResourceNode` filhos, grava e restaura o estado deles
## no save (lista dentro de `world`, por id estável) e responde onde estão (para o sorteio de respawn).

## Nós por id. Montado no primeiro uso a partir dos filhos.
var _by_id: Dictionary = {}
var _indexed: bool = false


func _ready() -> void:
	# O desenho provisório é montado aqui: a entidade (em `entities/`) não conhece a UI.
	for node in nodes():
		var view := ResourceNodeView.new()
		view.node = node
		node.add_child(view)


func nodes() -> Array[ResourceNode]:
	_index()
	var result: Array[ResourceNode] = []
	for node: ResourceNode in _by_id.values():
		result.append(node)
	return result


func node_by_id(node_id: String) -> ResourceNode:
	_index()
	return _by_id.get(node_id) as ResourceNode


## Estado de todos os nós, compatível com JSON, em ordem estável de id.
func to_list() -> Array:
	_index()
	var ids: Array = _by_id.keys()
	ids.sort()
	var list: Array = []
	for node_id: String in ids:
		var state: Dictionary = (_by_id[node_id] as ResourceNode).component.to_dict()
		state["id"] = node_id
		list.append(state)
	return list


## Aplica uma lista salva. Id desconhecido, entrada que não é dicionário e excesso são ignorados;
## nó que não consta fica como está (cheio, no mundo novo).
func restore_list(list: Array) -> void:
	_index()
	var applied := 0
	for entry: Variant in list:
		if applied >= _by_id.size():  # o teto conta só o que foi aplicado: lixo no início não esconde nó válido
			break
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var node := node_by_id(SafeRead.text((entry as Dictionary).get("id"), ""))
		if node != null:
			node.component.from_dict(entry)
			applied += 1


func _index() -> void:
	if _indexed:
		return
	_indexed = true
	for child in get_children():
		var node := child as ResourceNode
		if node != null and node.node_id != "" and not _by_id.has(node.node_id):
			_by_id[node.node_id] = node
