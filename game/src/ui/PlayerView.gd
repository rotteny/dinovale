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
## Dano recebido: número flutuante vermelho e `sound_cue(hurt)`. Fôlego (GDD 5.7): abaixo de
## 25% de stamina, sopros (`pant`) cada vez mais rápidos e agudos; ao zerar, um fôlego longo
## (`gasp`) e uma nuvem de suor. Sem barra: o sinal é só som e nuvem. Os sons de fôlego são
## placeholders sintetizados (`BreathSound`); coloque arquivos em `cue_streams` para trocar.
##
## Som: `sound_cue(attack)` sempre; toca no `AudioStreamPlayer2D` se houver stream em
## `cue_streams`. Os arquivos do pacote são baixos (pico em -10 dBFS), por isso o
## `volume_db` padrão é +6.

signal sound_cue(cue: StringName)

const CUE_ATTACK := &"attack"
const CUE_HURT := &"hurt"
const CUE_PANT := &"pant"
const CUE_GASP := &"gasp"
const PANT_INTERVAL_SLOW := 0.9
const PANT_INTERVAL_FAST := 0.3
const PANT_PITCH_LOW := 0.9
const PANT_PITCH_HIGH := 1.5
const ROW_ATTACK := 4
const ROW_DEAD := 6
const ATTACK_SECONDS := 0.25
const MOVING_SPEED_SQUARED := 1.0

@export var player: Player
@export var cue_streams: Dictionary[StringName, AudioStream] = {}
@export var volume_db: float = 6.0

var _audio := AudioStreamPlayer2D.new()
var _breath := AudioStreamPlayer2D.new()
var _cloud := CPUParticles2D.new()
var _pant_stream: AudioStream = BreathSound.make(0.28, 0.35)
var _gasp_stream: AudioStream = BreathSound.make(0.7, 0.2)
var _pant_clock := 0.0
var _gasp_left := 0.0
var _time := 0.0
var _attack_left := 0.0
var _facing := SpriteFacing.DOWN
var _popups := Node2D.new()


func _ready() -> void:
	z_index = 11
	_audio.volume_db = volume_db
	add_child(_audio)
	add_child(_popups)
	_breath.volume_db = volume_db
	add_child(_breath)
	_setup_cloud()
	add_child(_cloud)
	if player == null:
		return
	player.attacked.connect(_on_attacked)
	# Na `Main` a vista vem antes do jogador na árvore: espera os componentes dele existirem.
	if not player.is_node_ready():
		await player.ready
	player.health.damaged.connect(_on_damaged)
	player.stamina.exhausted.connect(_on_exhausted)
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
	_tick_breath(delta)
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


## Sopros de fôlego abaixo de 25% de stamina: mais rápidos e agudos perto de zerar.
func _tick_breath(delta: float) -> void:
	var stamina := player.stamina
	# O fôlego longo toca inteiro: nenhum sopro o corta.
	_gasp_left = maxf(_gasp_left - delta, 0.0)
	if player.health.is_dead() or not stamina.is_winded():
		_pant_clock = 0.0
		return
	if _gasp_left > 0.0:
		return
	var intensity := stamina.winded_intensity()
	_pant_clock += delta
	if _pant_clock < lerpf(PANT_INTERVAL_SLOW, PANT_INTERVAL_FAST, intensity):
		return
	_pant_clock = 0.0
	_breath.pitch_scale = lerpf(PANT_PITCH_LOW, PANT_PITCH_HIGH, intensity)
	_play_breath(CUE_PANT, _pant_stream)


func _on_exhausted() -> void:
	_cloud.restart()
	_cloud.emitting = true
	_breath.pitch_scale = 1.0
	_pant_clock = 0.0
	var gasp: AudioStream = cue_streams.get(CUE_GASP, _gasp_stream)
	_gasp_left = gasp.get_length()
	_play_breath(CUE_GASP, _gasp_stream)


func _play_breath(cue: StringName, fallback: AudioStream) -> void:
	sound_cue.emit(cue)
	_breath.stream = cue_streams.get(cue, fallback)
	_breath.play()


func _on_damaged(amount: float) -> void:
	FloatingText.spawn(_popups, FloatingText.damage_text(amount), Color(1.0, 0.35, 0.3), Vector2(-6.0, -18.0))
	sound_cue.emit(CUE_HURT)
	var stream: AudioStream = cue_streams.get(CUE_HURT)
	if stream != null:
		_audio.stream = stream
		_audio.play()


func breath_player() -> AudioStreamPlayer2D:
	return _breath


func is_cloud_active() -> bool:
	return _cloud.emitting


func is_panting() -> bool:
	return _breath.playing


## Quantos números de dano ainda estão na tela.
func popup_count() -> int:
	var count := 0
	for child in _popups.get_children():
		if not child.is_queued_for_deletion():
			count += 1
	return count


func _setup_cloud() -> void:
	_cloud.emitting = false
	_cloud.one_shot = true
	_cloud.amount = 8
	_cloud.lifetime = 0.6
	_cloud.explosiveness = 0.9
	_cloud.position = Vector2(0, -8)
	_cloud.direction = Vector2(0, -1)
	_cloud.spread = 70.0
	_cloud.gravity = Vector2.ZERO
	_cloud.initial_velocity_min = 8.0
	_cloud.initial_velocity_max = 18.0
	_cloud.scale_amount_min = 1.5
	_cloud.scale_amount_max = 2.5
	_cloud.color = Color(0.9, 0.95, 1.0, 0.8)
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 0.9))
	fade.set_color(1, Color(1, 1, 1, 0.0))
	_cloud.color_ramp = fade


func _on_attacked() -> void:
	_attack_left = ATTACK_SECONDS
	if player.target != null and is_instance_valid(player.target):
		_facing = SpriteFacing.column_for(player.target.global_position - player.global_position, _facing)
	sound_cue.emit(CUE_ATTACK)
	var stream: AudioStream = cue_streams.get(CUE_ATTACK)
	if stream != null:
		_audio.stream = stream
		_audio.play()
