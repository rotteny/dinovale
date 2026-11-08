# SPDX-License-Identifier: MIT
class_name SfxPlayer
extends RefCounted
## Toca efeitos sonoros curtos no bus SFX, com o tom variando ±8% para não soar repetido. Só apresentação: quem
## chama é a view que observa o sinal. Arquivo ausente (ainda não gerado) fica em silêncio, sem erro nem aviso.

const BANK: SfxBank = preload("res://data/audio/sfx_bank.tres")
## Ids dos sons de coleta (o arquivo está em `assets/audio/sfx/`, ligado no banco).
const PUNCH_TREE := &"soco_arvore"
const TOOL_WOOD := &"golpe_madeira"
const TOOL_STONE := &"golpe_pedra"
const PUNCH_STONE := &"soco_pedra"
const TREE_FALL := &"arvore_cai"
const ROCK_BREAK := &"rocha_quebra"
const ITEM_DROP := &"item_cai"
## Dor do dino ao levar dano; os sons de ameaça e de golpe de cada espécie vêm do `ThreatProfile`.
const DINO_HURT := &"dino_dor"
## Variação do tom (fração): 0,08 = de 92% a 108%.
const PITCH_SPREAD := 0.08

static var _rng := SeededRng.new()
## Quantos sons foram pedidos (e tocados) desde o início: o teste confere sem ouvir.
static var played_count: int = 0
static var last_played: StringName = &""
static var last_pitch: float = 1.0


## Fixa a semente da variação de tom (teste e replay).
static func seed_pitch(value: int) -> void:
	_rng.seed_from(["sfx", value])


## O arquivo do som existe no projeto?
static func has(id: StringName) -> bool:
	return _stream(id) != null


## Toca `id` em `at` (coordenada global), como filho de `anchor`, que o dono. Sem arquivo: não faz nada.
## Devolve se tocou.
static func play(anchor: Node, id: StringName, at: Vector2) -> bool:
	var stream := _stream(id)
	if stream == null or anchor == null or not anchor.is_inside_tree():
		return false
	var voice := AudioStreamPlayer2D.new()
	voice.stream = stream
	voice.bus = GameSettings.BUS_SFX
	voice.pitch_scale = 1.0 + _rng.next_range(-PITCH_SPREAD, PITCH_SPREAD)
	voice.finished.connect(voice.queue_free)
	anchor.add_child(voice)
	voice.global_position = at
	voice.play()
	played_count += 1
	last_played = id
	last_pitch = voice.pitch_scale
	return true


static func _stream(id: StringName) -> AudioStream:
	return BANK.streams.get(id) as AudioStream
