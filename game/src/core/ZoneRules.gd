# SPDX-License-Identifier: MIT
class_name ZoneRules
extends Resource
## Zona ativa por raio (MUN-05, `mapa-ilha.md` 2): só o que está perto do jogador pensa. Só dados em
## `res://data/world/zone_rules.tres`; os raios são os da tela de 320x180 (meia diagonal 11,5 + 4,5 de margem).

## Até este raio, em tiles, o dino tem IA e física completas (ativo).
@export_range(1.0, 200.0) var active_radius_tiles: float = 16.0
## Deste raio até este, o dino é "distante": sem física, só anda em dado a cada `far_step_seconds`. Além dele, dorme.
@export_range(1.0, 400.0) var far_radius_tiles: float = 40.0
## Teto de dinos ativos ao mesmo tempo: passado dele, os mais distantes viram "distantes". Quem está fixado
## pelo estado (domado, desacordado, em doma) fica ativo e não conta contra os outros.
@export_range(1, 256) var max_active: int = 32
## De quanto em quanto tempo o mundo reclassifica os dinos (a distância não muda a cada quadro).
@export_range(0.05, 5.0) var reevaluate_seconds: float = 0.25
## Intervalo do passeio de um dino distante (só dado), e o tamanho do passo em tiles.
@export_range(0.1, 30.0) var far_step_seconds: float = 2.0
@export_range(0.5, 16.0) var far_step_tiles: float = 2.0
@export_range(4, 64) var tile_size: int = 16
