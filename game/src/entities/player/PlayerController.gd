# SPDX-License-Identifier: MIT
class_name PlayerController
extends Node
## Controlador do jogador local (cliente): a ÚNICA leitura de `Input` do jogo fora da `src/ui/`.
## Lê o teclado, vira intenção e a entrega à autoridade (ADR-001): o movimento vai como
## `request_move`; interagir, atacar e os atalhos, pelos pedidos do `Player`. Não conhece física
## nem regra de movimento: a autoridade valida e o corpo aplica. Um jogador remoto não tem controlador.

## Corpo que este controlador dirige.
@export var player: Player
## Ponto de passagem das ações; a direção sai por ele, nunca direto no corpo.
@export var authority: WorldAuthority

var _actor_id: int = 0


func _init() -> void:
	# Roda antes do corpo no quadro de física, para o pedido valer no mesmo passo.
	process_physics_priority = -1


func _physics_process(_delta: float) -> void:
	tick()


## Lê o input do quadro e pede o movimento. Chamável sem esperar frame (testes).
func tick() -> void:
	if player == null or authority == null:
		return
	authority.request_move(_id(), read_direction(), Input.is_action_pressed("sprint"))


## `get_vector` já devolve comprimento no máximo 1, então a diagonal não é mais rápida que o eixo.
func read_direction() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


## Única leitura de input de ações. Só dispara fora de telas.
func _unhandled_input(event: InputEvent) -> void:
	if player == null:
		return
	if event.is_action_pressed("interact"):
		player.try_interact()
	elif event.is_action_pressed("attack"):
		player.attack()
	else:
		for slot in HotbarComponent.SLOT_COUNT:
			if event.is_action_pressed("hotbar_%d" % (slot + 1)):
				player.request_use_item(slot)
				break


## Id do jogador na autoridade, guardado: só procura de novo se o registro mudou.
func _id() -> int:
	if _actor_id == 0 or authority.entity(_actor_id) != player:
		_actor_id = authority.id_of(player)
	return _actor_id
