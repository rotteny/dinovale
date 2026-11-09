# SPDX-License-Identifier: MIT
class_name HomeRules
extends Resource
## Números da toca, da ronda e da âncora de uma espécie com toca (E3a, `corte-v02/e3-toca-e-vigilia.md`), só dados em
## `res://data/balance/home_rules.tres`. O mundo pode sobrescrever âncora e ronda pelo `ServerRules`.

## Raio máximo do bicho em qualquer situação, em tiles da toca. Alvo novo só dentro dele, e o caçador também.
@export_range(1.0, 128.0) var anchor_tiles: float = 24.0
## Raio da ronda: sem alvo, o passeio só sorteia pontos até aqui, em tiles do centro da toca.
@export_range(1.0, 64.0) var patrol_tiles: float = 10.0
## Velocidade da volta à toca, em pixels por segundo (a de passeio é a do corpo).
@export_range(1.0, 400.0) var return_speed_px_s: float = 60.0
## Faixa de nível (mínimo em x, máximo em y) por toca, pelo id da toca no mapa. Toca ausente usa a faixa do terreno.
@export var den_level_bands: Dictionary[String, Vector2i] = {}


## Faixa da toca `den`, ou `fallback` se não há faixa para ela.
func band_of(den: String, fallback: Vector2i) -> Vector2i:
	return den_level_bands.get(den, fallback)
