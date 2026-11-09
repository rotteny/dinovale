# SPDX-License-Identifier: MIT
class_name BuildRules
extends Resource
## Regras da construção (E8a, CON-01 a CON-03). Valores em `res://data/balance/build_rules.tres`. O GDD só fixa a grade
## de 16 px e os custos; o resto abaixo é [premissa] e fica aqui, em dado, para a SHIRO ajustar sem tocar no código.

## Lado do tile da grade, em pixels (GDD 8).
@export_range(4.0, 64.0) var tile_px: float = 16.0
## Distância máxima (em tiles) do jogador ao centro da célula para construir ou remover. [premissa]
@export_range(0.5, 8.0) var reach_tiles: float = 3.0
## Distância máxima (em tiles) do jogador à porta para abri-la ou fechá-la. [premissa]
@export_range(0.5, 8.0) var door_reach_tiles: float = 2.0
## Quanto do material volta ao remover uma peça, em %. O GDD não diz; 100 [premissa], sem ganho possível (só volta o que se pagou).
@export_range(0, 100) var refund_percent: int = 100
## Raio (em células, Chebyshev) em que a fundação serve de apoio a parede e porta: 1 = a fundação ao lado, inclusive na diagonal. [premissa]
@export_range(0, 4) var support_radius: int = 1
## Teto de peças no mundo (dado de fora não é confiável: save e pedido).
@export_range(1, 100000) var max_pieces: int = 4096
## Porta, remoção e Baú (abrir e transferir) valem para qualquer jogador (premissa do solo/co-op sem trava de dono; o M3
## decide). Falso: só o dono da peça mexe. É uma regra só, a de `BuildService._may_change`.
@export var shared_pieces: bool = true
## Pode construir dentro do núcleo seguro (refúgio do nascimento)? Falso, como a Bancada desde a E7a. [premissa]
@export var build_in_safe_core: bool = false
