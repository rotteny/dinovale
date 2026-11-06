# SPDX-License-Identifier: MIT
class_name ResourceNodeComponent
extends Node
## Estado de um nó de recurso (MUN-02): cheio ou esgotado, e quanto falta para voltar. Lógica pura,
## sem desenho nem física. `harvest()` é a única porta de saída do recurso; quem pede a coleta
## (o jogador, via `Player.request_gather`) valida alcance e espaço antes.

## Mudou entre cheio e esgotado (a apresentação e a dica reagem).
signal changed

@export var def: ResourceNodeDef

var depleted: bool = false
var respawn_left: float = 0.0


func _physics_process(delta: float) -> void:
	tick(delta)


## Faz o tempo de volta correr. Esgotado que chega a zero volta cheio.
func tick(delta: float) -> void:
	if not depleted or def == null:
		return
	respawn_left -= delta
	if respawn_left <= 0.0:
		depleted = false
		respawn_left = 0.0
		changed.emit()


func is_available() -> bool:
	return def != null and not depleted


## Colhe o nó: devolve as unidades entregues (0 se já estava esgotado) e começa o tempo de volta.
func harvest() -> int:
	if not is_available():
		return 0
	depleted = true
	respawn_left = def.respawn_seconds
	changed.emit()
	return def.yield_amount


func to_dict() -> Dictionary:
	return {"def": def.id if def != null else "", "depleted": depleted, "respawn_left": respawn_left}


## Restaura sem entregar nada. Dado de outro tipo de nó (o mundo mudou) é ignorado: o nó fica como está.
func from_dict(data: Dictionary) -> void:
	if def == null or SafeRead.text(data.get("def"), "") != def.id:
		return
	depleted = SafeRead.flag(data.get("depleted"), false)
	respawn_left = SafeRead.number(data.get("respawn_left"), 0.0, 0.0, def.respawn_seconds) if depleted else 0.0
	changed.emit()
