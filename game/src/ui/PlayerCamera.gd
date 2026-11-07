# SPDX-License-Identifier: MIT
class_name PlayerCamera
extends Camera2D
## Câmera do jogador (GDD 4.2): centrada no personagem, anda junto e só para no limite do mapa
## (`MapBounds`, em dado). Sem suavização: com o viewport de 320x180 qualquer atraso ou posição
## fracionária borra o pixel; a posição é arredondada para pixel inteiro. Só apresentação: lê a
## posição do `Player`, nunca o altera. Instancie FORA do `Player.tscn`.

## Ponto do corpo que fica no centro da tela, relativo aos pés (origem do `Player`, a base do quadro
## de 32x32, pés em y=30): o meio do corpo, não os pés.
const BODY_CENTER := Vector2(0.0, -16.0)

@export var player: Player
@export var bounds: MapBounds = preload("res://data/world/map_bounds.tres")
@export var focus_offset: Vector2 = BODY_CENTER


func _ready() -> void:
	position_smoothing_enabled = false
	rotation_smoothing_enabled = false
	drag_horizontal_enabled = false
	drag_vertical_enabled = false
	ignore_rotation = true
	apply_bounds()
	follow()
	if owner != null and not owner.is_node_ready():
		owner.ready.connect(follow, CONNECT_ONE_SHOT)
	make_current()
	reset_smoothing()


func _process(_delta: float) -> void:
	follow()


## Os limites do `Camera2D` vêm do dado: a engine faz o clamp.
func apply_bounds() -> void:
	limit_left = int(floorf(bounds.rect.position.x))
	limit_top = int(floorf(bounds.rect.position.y))
	limit_right = int(ceilf(bounds.rect.end.x))
	limit_bottom = int(ceilf(bounds.rect.end.y))


func follow() -> void:
	if is_instance_valid(player):
		global_position = (player.global_position + focus_offset).round()


## Centro que a câmera mostra agora (já com o limite aplicado).
func shown_center() -> Vector2:
	return get_screen_center_position()
