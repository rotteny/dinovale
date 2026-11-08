# SPDX-License-Identifier: MIT
class_name BodyArt
extends RefCounted
## Arte do jogador caído e do corpo: textura, quadros e velocidade da animação, lidos de `corpo.json` (só apresentação).
## Sem o arquivo ou com dado inválido, valem os padrões abaixo e a cena segue funcionando.

const DESCRIPTION_PATH := "res://assets/sprites/jogador/corpo.json"
const DOWNED_TEXTURE: Texture2D = preload("res://assets/sprites/jogador/caido.png")
const CORPSE_TEXTURE: Texture2D = preload("res://assets/sprites/jogador/corpo.png")
## Os dois desenhos têm 2 quadros de 32x32 lado a lado, e a âncora é a mesma do jogador (base do quadro).
const FRAMES := 2
const ANCHOR_OFFSET := Vector2(0.0, -16.0)
const DEFAULT_DOWNED_FPS := 1.0
const DEFAULT_CORPSE_FPS := 2.0
## Direções em que o caído usa `flip_h` (a pose única olha para a esquerda): direita, baixo-direita e cima-direita.
const MIRRORED_FACINGS: Array[int] = [SpriteFacing.RIGHT, SpriteFacing.DOWN_RIGHT, SpriteFacing.UP_RIGHT]


## Quadros por segundo da animação `animation` do arquivo `file` (`caido.png`, `corpo.png`); `fallback` se faltar.
static func fps(file: String, animation: String, fallback: float) -> float:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DESCRIPTION_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return fallback
	var files: Variant = (parsed as Dictionary).get("arquivos")
	var entry: Variant = (files as Dictionary).get(file) if typeof(files) == TYPE_DICTIONARY else null
	var anims: Variant = (entry as Dictionary).get("animacoes") if typeof(entry) == TYPE_DICTIONARY else null
	var anim: Variant = (anims as Dictionary).get(animation) if typeof(anims) == TYPE_DICTIONARY else null
	var value: Variant = (anim as Dictionary).get("fps") if typeof(anim) == TYPE_DICTIONARY else null
	return float(value) if (typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT) and float(value) > 0.0 else fallback


## Quadro da animação de 2 quadros no instante `time`.
static func frame_at(time: float, frames_per_second: float) -> int:
	return int(maxf(time, 0.0) * frames_per_second) % FRAMES


static func is_mirrored(facing: int) -> bool:
	return MIRRORED_FACINGS.has(facing)
