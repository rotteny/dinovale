# SPDX-License-Identifier: MIT
class_name SfxBank
extends Resource
## Banco de efeitos sonoros curtos: id -> stream. Dado em `res://data/audio/sfx_bank.tres`. Id fora do banco toca em silêncio.

@export var streams: Dictionary[StringName, AudioStream] = {}
