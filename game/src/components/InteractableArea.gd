# SPDX-License-Identifier: MIT
class_name InteractableArea
extends Area2D
## Marca uma entidade como interagível. A área só diz "estou aqui, no alcance";
## a REGRA de quando se pode interagir fica na entidade, que injeta `availability`
## (um Callable sem argumentos que devolve bool). Sem regra, sempre disponível.
##
## Quem muda o estado da entidade chama `refresh()`: se a disponibilidade mudou,
## sai `availability_changed`, e a UI (prompt, painel aberto) reage.

signal availability_changed(available: bool)

## Camada de física exclusiva dos interagíveis (bit 2). O detector do jogador a usa como máscara.
const PHYSICS_LAYER := 2

## Entidade dona desta área (ex.: o Dino).
@export var entity: Node
@export var prompt: String = "interagir"

var availability: Callable = Callable()

var _last_available: bool = true


func _init() -> void:
	collision_layer = PHYSICS_LAYER
	collision_mask = 0
	monitoring = false
	monitorable = true


func can_interact() -> bool:
	return not availability.is_valid() or bool(availability.call())


## Reavalia a regra e emite `availability_changed` só se mudou.
func refresh() -> void:
	var now := can_interact()
	if now != _last_available:
		_last_available = now
		availability_changed.emit(now)
