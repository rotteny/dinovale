# SPDX-License-Identifier: MIT
class_name ResourceNodeDef
extends Resource
## Um tipo de nó de recurso (MUN-02): o que dá, quanto, quanto custa colher e quando volta. Só
## dados em `res://data/resources/`. Números marcados [premissa] saem do GDD e são para testar jogando.

## Id estável em string (vai para o save).
@export var id: String = ""
@export var display_name: String = ""
## Item que o nó entrega (`Items`).
@export var item_id: String = ""
## Unidades entregues por coleta.
@export_range(1, 100) var yield_amount: int = 1
## Tempo da ação de colher, em segundos: o jogador fica sem colher outra coisa por este tempo.
@export_range(0.0, 60.0) var gather_seconds: float = 3.0
## Segundos de jogo até o nó esgotado voltar cheio (o relógio só corre com o mundo rodando).
@export_range(1.0, 3600.0) var respawn_seconds: float = 240.0
## Alcance da coleta, em pixels, do jogador ao centro do nó (validado em `Player.request_gather`).
@export_range(1.0, 200.0) var reach: float = 32.0
## Texto da dica de interação ("E para ...").
@export var prompt: String = "colher"
## Cor do desenho provisório até existir arte.
@export var color: Color = Color.WHITE
