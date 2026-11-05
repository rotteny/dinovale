# SPDX-License-Identifier: MIT
class_name PlayerView
extends Node2D
## Apresentação do jogador: escolhe o quadro do sprite (parado, andar nas 4 direções,
## ataque, morto) pelo que o corpo faz e toca o som do golpe. Só apresentação: lê
## `velocity`, `attacked` e a vida do `Player`; nenhuma regra mora aqui.
## Instancie FORA do `Player.tscn`.
##
## Folha `characters/caveman.png` (16x16, 4 colunas x 7 linhas): linhas 0 a 3 andar
## (a 0 é também o parado), 4 atacar, 6 morto (coluna 0).
##
## Som: `sound_cue(attack)` sempre; toca no `AudioStreamPlayer2D` se houver stream em
## `cue_streams`. Os arquivos do pacote são baixos (pico em -10 dBFS), por isso o
## `volume_db` padrão é +6.

signal sound_cue(cue: StringName)

const CUE_ATTACK := &"attack"
const ROW_ATTACK := 4
const ROW_DEAD := 6
const ATTACK_SECONDS := 0.25
const MOVING_SPEED_SQUARED := 1.0

@export var player: Player
@export var cue_streams: Dictionary[StringName, AudioStream] = {}
@export var volume_db: float = 6.0

var _audio := AudioStreamPlayer2D.new()
var _time := 0.0
var _attack_left := 0.0
var _facing := SpriteFacing.DOWN


func _ready() -> void:
	_audio.volume_db = volume_db
	add_child(_audio)
	if player == null:
		return
	player.attacked.connect(_on_attacked)
	follow()


func _process(delta: float) -> void:
	tick(delta)


## Passo de tempo da apresentação (separado do `_process` para testar sem frames).
func tick(delta: float) -> void:
	if not is_instance_valid(player):
		queue_free()
		return
	follow()
	_time += delta
	_attack_left = maxf(_attack_left - delta, 0.0)
	var sprite := player.visual
	if player.health.is_dead():
		sprite.frame_coords = Vector2i(0, ROW_DEAD)
		return
	var moving := player.velocity.length_squared() > MOVING_SPEED_SQUARED
	if moving:
		_facing = SpriteFacing.column_for(player.velocity, _facing)
	if _attack_left > 0.0:
		sprite.frame_coords = Vector2i(_facing, ROW_ATTACK)
	elif moving:
		sprite.frame_coords = Vector2i(_facing, SpriteFacing.walk_row(_time))
	else:
		sprite.frame_coords = Vector2i(_facing, 0)


func follow() -> void:
	if is_instance_valid(player):
		global_position = player.global_position


func audio_player() -> AudioStreamPlayer2D:
	return _audio


func is_attacking() -> bool:
	return _attack_left > 0.0


func _on_attacked() -> void:
	_attack_left = ATTACK_SECONDS
	if player.target != null and is_instance_valid(player.target):
		_facing = SpriteFacing.column_for(player.target.global_position - player.global_position, _facing)
	sound_cue.emit(CUE_ATTACK)
	var stream: AudioStream = cue_streams.get(CUE_ATTACK)
	if stream != null:
		_audio.stream = stream
		_audio.play()
