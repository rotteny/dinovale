# SPDX-License-Identifier: MIT
class_name HerdCall
extends RefCounted
## Chamada do bando (M1, `m1-ameaca-e-corpo.md` seção 3). Quando um selvagem é golpeado, os do mesmo bando (`Dino.herd_id`)
## acordados, vivos e sem dono, a até `call_radius_tiles` dele, viram candidatos; entram os `max_helpers` mais próximos do
## atacante (descontados os ajudantes que o bando já tem), `call_delay_s` depois e contra o mesmo atacante. Lógica pura:
## quem decide o mundo é a autoridade, que a alimenta com os dinos e a avança (`tick`). Nenhum ajudante é chamado de novo
## enquanto está bravo, e o domado (ou de outro dono) nunca ajuda.

var rules: HerdCallRules = preload("res://data/balance/herd_call_rules.tres")

## Chamadas à espera do atraso: `{dino, attacker_id, left}`.
var _pending: Array[Dictionary] = []


## Abre a chamada pelo golpe em `struck` (bando "" = sem bando, nada acontece). `others` são todos os dinos do mundo;
## `attacker_at` é onde o atacante está. Devolve quantos ajudantes foram escalados.
func raise_call(struck: Dino, attacker_id: String, attacker_at: Vector2, others: Array[Dino], attacker: Node2D = null) -> int:
	if struck.herd_id == "" or struck.owner_player_id != "" or struck.state_machine.is_tamed:
		return 0
	var tile := float(struck.level_rules.tile_size)
	var picks: Array[Dino] = []
	for other in others:
		if _can_help(other, struck, tile):
			picks.append(other)
	picks.sort_custom(func(a: Dino, b: Dino) -> bool:
		return a.global_position.distance_squared_to(attacker_at) < b.global_position.distance_squared_to(attacker_at))
	var slots := rules.max_helpers - helpers_of(struck.herd_id, others)
	var count := 0
	for pick in picks:
		if count >= slots:
			break
		_pending.append({"dino": pick, "attacker_id": attacker_id, "attacker": attacker, "left": rules.call_delay_s})
		count += 1
	return count


## Ajudantes do bando agora: bravos por chamada e os já escalados que esperam o atraso.
func helpers_of(herd_id: String, others: Array[Dino]) -> int:
	var count := 0
	for other in others:
		if is_instance_valid(other) and other.herd_id == herd_id and other.state_machine.is_helper:
			count += 1
	for entry in _pending:
		var waiting := entry["dino"] as Dino
		if is_instance_valid(waiting) and waiting.herd_id == herd_id and not waiting.state_machine.is_helper:
			count += 1
	return count


func pending_count() -> int:
	return _pending.size()


## Passa o tempo: quem cumpriu o atraso entra (se ainda puder: dormiu, morreu ou foi domado nesse meio tempo, não entra).
func tick(delta: float) -> void:
	var waiting: Array[Dictionary] = []
	for entry in _pending:
		entry["left"] = float(entry["left"]) - delta
		if float(entry["left"]) > 0.0:
			waiting.append(entry)
			continue
		var dino := entry["dino"] as Dino
		if is_instance_valid(dino) and not dino.is_queued_for_deletion():
			var attacker := entry.get("attacker") as Node2D if is_instance_valid(entry.get("attacker")) else null
			dino.join_call(entry["attacker_id"], rules.helper_max_seconds, attacker)
	_pending = waiting


func _can_help(other: Dino, struck: Dino, tile_px: float) -> bool:
	if other == struck or not is_instance_valid(other) or other.is_queued_for_deletion() or other.herd_id != struck.herd_id:
		return false
	if other.health.is_dead() or other.owner_player_id != "" or other.state_machine.is_tamed:
		return false
	if other.state_machine.current_id == Enums.DinoStateId.UNCONSCIOUS or other.state_machine.is_aggressive:
		return false
	for entry in _pending:
		if entry["dino"] == other:
			return false
	return other.global_position.distance_to(struck.global_position) <= rules.radius_px(tile_px)
