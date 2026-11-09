# SPDX-License-Identifier: MIT
class_name PieceCatalog
extends RefCounted
## Catálogo das peças de construção: as de `data/build/` (lista fixa, sem varrer pasta). Ordem de entrada = ordem do menu.

const DEFAULT_PIECES: Array[PieceDef] = [
	preload("res://data/build/foundation.tres"),
	preload("res://data/build/wall.tres"),
	preload("res://data/build/door.tres"),
	preload("res://data/build/chest.tres"),
	preload("res://data/build/workbench.tres"),
]

var _pieces: Dictionary[String, PieceDef] = {}
var _order: Array[String] = []


static func with_defaults() -> PieceCatalog:
	var catalog := PieceCatalog.new()
	for piece in DEFAULT_PIECES:
		catalog.add(piece)
	return catalog


## Adiciona (ou troca, pelo id) uma peça válida. Devolve false se for inválida.
func add(piece: PieceDef) -> bool:
	if piece == null or not piece.is_valid():
		return false
	if not _pieces.has(piece.id):
		_order.append(piece.id)
	_pieces[piece.id] = piece
	return true


func find(piece_id: String) -> PieceDef:
	return _pieces.get(piece_id)


## A peça que se constrói gastando o item `item_id` pronto, ou null.
func find_by_item(item_id: String) -> PieceDef:
	for piece_id in _order:
		if _pieces[piece_id].item_id == item_id and item_id != "":
			return _pieces[piece_id]
	return null


## Todas, na ordem do menu.
func all() -> Array[PieceDef]:
	var list: Array[PieceDef] = []
	for piece_id in _order:
		list.append(_pieces[piece_id])
	return list


## Peças que o jogador constrói pelo menu (as de receita; a Bancada sai do inventário).
func buildable() -> Array[PieceDef]:
	var list: Array[PieceDef] = []
	for piece in all():
		if piece.recipe_id != "":
			list.append(piece)
	return list
