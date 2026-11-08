# SPDX-License-Identifier: MIT
class_name CursorSource
extends Node
## Quem sabe qual ação o clique esquerdo teria sob o ponteiro agora (para o cursor contextual). A lógica é do
## `PlayerController`; a UI (`CursorView`) só conhece esta base leve, para não puxar o jogador inteiro com ela.

## `{"action": StringName, "in_reach": bool}`: o padrão é "nada sob o ponteiro".
func current_cursor() -> Dictionary:
	return {"action": &"padrao", "in_reach": true}
