# SPDX-License-Identifier: MIT
class_name DinoBaseStats
extends Resource
## Atributos base de uma criatura, no nível base (`DinoLevelRules.base_level`).
## Precursor do `SpeciesDef` (ADR-003): quando ele existir, estes campos migram para lá.

@export var id: String = "placeholder_dino"
## Nome da espécie, como o jogador lê (placa do domado).
@export var display_name: String = "Dino"
## Folha do sprite descrita por JSON (quadro, colunas por animação, linhas por direção).
@export_file("*.json") var sheet_path: String = "res://assets/sprites/dinos/paquicefalo.json"
@export var base_health: float = 100.0
## Dano do ataque do dino (sem uso até existir carnívoro).
@export var base_damage: float = 4.0
@export var base_torpor: float = 100.0
## Refeições para domesticar no nível base, com dificuldade 1,0.
@export var base_meals: int = 5
@export var difficulty: float = 1.0
## Carne da carcaça no nível base (GDD 5.6; o couro ainda não existe no catálogo).
@export var carcass_meat: int = 4
## Quadro "morto" da espécie (coluna 10 da folha): o desenho da carcaça.
@export var carcass_texture: Texture2D
## Caixa de colisão do corpo, em pixels (largura, altura). O corpo a lê ao nascer.
@export var hitbox_size: Vector2 = Vector2(24.0, 16.0)
