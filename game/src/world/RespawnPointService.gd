# SPDX-License-Identifier: MIT
class_name RespawnPointService
extends Node
## Pontos de renascer da base (E12, SOB-13), filho da `WorldAuthority`: as Camas e o Saco de dormir do JOGADOR, vistos pela tela
## de morte. As peças vivem na `BuildGrid` (dono, célula, espera): aqui só se lê a grade, então peça destruída ou recolhida
## SAI DA LISTA NA HORA, também com a tela aberta, e uma Cama de outro jogador nunca aparece (só o dono renasce nela).
## A espera da Cama (`bed_wait_seconds`, por Cama) é um instante do relógio do mundo guardado na peça (`ready_at`): só corre
## com o mundo rodando e vai ao save com a grade. O Saco é consumido (`commit`) só depois de o jogador estar posto no mundo.
## Quem renasce é o corpo do jogador (a `Main`); esta classe só diz as opções, valida a escolha e registra o uso.

const KIND_BED := "bed"
const KIND_BAG := "bag"
const BED_PIECE := "bed"
const BAG_PIECE := "sleeping_bag"
## Raios de busca de um tile livre ao lado da peça (a Cama é sólida: o jogador nasce junto dela, não nela).
const LANDING_RINGS := 2

var authority: WorldAuthority = null
var rules: CampRules = preload("res://data/balance/camp_rules.tres")


## As opções do jogador `player_id`, na ordem da grade (Camas e depois o Saco): `{id, kind, cell, name, position, distance_tiles,
## enabled, wait_left, reason}`. `from` é onde o corpo caiu (a distância de cada linha). Cama em espera ou sem lugar ao lado:
## `enabled` falso com o motivo em `reason`.
func options(player_id: String, from: Vector2) -> Array[Dictionary]:
	var grid := authority.build.grid
	var cells := grid.cells()
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	var beds: Array[Dictionary] = []
	var bags: Array[Dictionary] = []
	for cell in cells:
		var piece := grid.piece_at(cell)
		if str(piece.get("owner", "")) != player_id:
			continue
		match str(piece.get("piece", "")):
			BED_PIECE:
				beds.append(_option(KIND_BED, "Cama %d" % (beds.size() + 1), cell, from))
			BAG_PIECE:
				bags.append(_option(KIND_BAG, "Saco de dormir", cell, from))
	return beds + bags


## Id da opção na tela e no pedido: "bed:x:y" ou "bag:x:y" (a célula da peça).
static func option_id(kind: String, cell: Vector2i) -> String:
	return "%s:%d:%d" % [kind, cell.x, cell.y]


## Valida a escolha `choice` (id de `options`) do jogador. `{ok, reason, option}`: dado de fora, então id mal formado, peça que
## sumiu, de outro dono, em espera ou sem lugar ao lado são recusas (o motivo vai ao log).
func resolve(player_id: String, choice: String, from: Vector2) -> Dictionary:
	if choice.length() > WorldAuthority.MAX_ID_LENGTH:
		return {"ok": false, "reason": "point_gone", "option": {}}
	for option in options(player_id, from):
		if option["id"] == choice:
			return {"ok": bool(option["enabled"]), "reason": str(option["reason"]), "option": option}
	return {"ok": false, "reason": "point_gone", "option": {}}


## O jogador já está no mundo: o Saco é consumido e a Cama entra em espera. Só a `Main` chama, depois de renascer.
func commit(option: Dictionary) -> void:
	var cell: Vector2i = option["cell"]
	if option["kind"] == KIND_BAG:
		authority.build.grid.remove(cell)
	else:
		authority.build.grid.set_ready_at(cell, authority.clock.now() + rules.bed_wait_seconds)


## Quanto falta da espera da Cama em `cell` (0 = pronta), em segundos de mundo rodando.
func wait_left(cell: Vector2i) -> float:
	var instant := authority.build.grid.ready_at(cell)
	# O instante de um save adulterado nunca passa de agora + a espera: no máximo ela recomeça.
	return clampf(instant - authority.clock.now(), 0.0, rules.bed_wait_seconds)


func _option(kind: String, label: String, cell: Vector2i, from: Vector2) -> Dictionary:
	var tile := float(authority.rules.tile_size)
	var landing: Variant = _landing(cell)
	var wait := wait_left(cell) if kind == KIND_BED else 0.0
	var reason := ""
	if landing == null:
		reason = "point_blocked"
	elif wait > 0.0:
		reason = "point_waiting"
	var center := (Vector2(cell) + Vector2(0.5, 0.5)) * tile
	return {"id": option_id(kind, cell), "kind": kind, "cell": cell, "name": label,
			"position": landing if landing != null else center, "distance_tiles": roundi(from.distance_to(center) / tile),
			"enabled": reason == "", "wait_left": wait, "reason": reason}


## O ponto (centro de tile) onde largar quem renasce: o Saco não tem corpo, então vale a própria célula; a Cama e os demais,
## o tile livre mais perto ao redor. Null se não há nenhum.
func _landing(cell: Vector2i) -> Variant:
	var tile := float(authority.rules.tile_size)
	var def := authority.build.grid.def_at(cell)
	if def != null and not def.blocks_body:
		return (Vector2(cell) + Vector2(0.5, 0.5)) * tile
	for ring in range(1, LANDING_RINGS + 1):
		for dy in range(-ring, ring + 1):
			for dx in range(-ring, ring + 1):
				if maxi(absi(dx), absi(dy)) == ring and authority.build.is_free_cell(cell + Vector2i(dx, dy)):
					return (Vector2(cell + Vector2i(dx, dy)) + Vector2(0.5, 0.5)) * tile
	return null
