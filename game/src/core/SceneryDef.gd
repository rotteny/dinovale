# SPDX-License-Identifier: MIT
class_name SceneryDef
extends Resource
## Um tipo de cenário sem interação (árvore decorativa, formação rochosa): textura e colisão dos pés. Dado
## em `res://data/world/scenery/`. Vira tile de `TileMapLayer` (não é nó): o motor só desenha o que a câmera vê.

@export var id: String = ""
@export var texture: Texture2D
## Caixa de colisão dos pés, em pixels, apoiada no pé do desenho (GDD 4.2: só os pés colidem).
@export var foot_size: Vector2 = Vector2.ZERO
