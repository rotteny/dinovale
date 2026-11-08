# SPDX-License-Identifier: MIT
class_name GameSession
extends RefCounted
## Estado mínimo que atravessa a troca de cena entre o menu e o jogo: onde ficam os saves e se
## o jogador pediu "Continuar". Estático e sem nó: não é autoload. O pedido vale uma vez
## (`take_continue`), para que um jogo novo nunca herde o "Continuar" anterior.

const DEFAULT_SAVE_ROOT := "user://saves"
const DEFAULT_WORLD := "main"

## Pasta que contém uma subpasta por mundo. Os testes apontam para um caminho descartável.
static var save_root: String = DEFAULT_SAVE_ROOT
static var continue_requested: bool = false
## Semente de mundo fixa para o mundo novo (0 = sorteia). Só testes e servidor dedicado a usam.
static var world_seed_override: int = 0
## Recado para o título mostrar uma vez (ex.: o Continuar falhou e a Main voltou ao menu).
static var notice: String = ""


## Lê e zera o recado.
static func take_notice() -> String:
	var text := notice
	notice = ""
	return text


## Lê e zera o pedido de continuar.
static func take_continue() -> bool:
	var requested := continue_requested
	continue_requested = false
	return requested
