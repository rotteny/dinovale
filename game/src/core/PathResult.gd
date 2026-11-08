# SPDX-License-Identifier: MIT
class_name PathResult
extends RefCounted
## Resposta de um pedido de caminho (`PathProvider.request_path`). Lógica pura.

## OK: `cells` vale (vazio = já está no destino). NO_PATH: nenhum caminho com a folga pedida. TOO_FAR: o pedido passou
## de `NavigationRules.max_request_tiles`. DEFERRED: o teto de pedidos do quadro estourou; pergunte de novo no próximo.
enum Status { OK, NO_PATH, TOO_FAR, DEFERRED }

var status: Status = Status.NO_PATH
## Células do primeiro passo até o destino (a célula de origem não entra, salvo se ela precisou ser trocada por uma livre).
var cells: Array[Vector2i] = []
## Célula de destino de fato (o destino pedido pode ter sido trocado pela livre mais próxima).
var goal_cell: Vector2i = Vector2i.ZERO


func is_ok() -> bool:
	return status == Status.OK


## O caminho passa por esta célula, ou a até `margin` tiles dela? (decide se um `invalidate` obriga a replanejar)
func touches(cell: Vector2i, margin: int = 0) -> bool:
	if margin <= 0:
		return cells.has(cell)
	for step in cells:
		if maxi(absi(step.x - cell.x), absi(step.y - cell.y)) <= margin:
			return true
	return false
