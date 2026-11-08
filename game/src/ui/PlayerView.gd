# SPDX-License-Identifier: MIT
class_name PlayerView
extends Node2D
## Apresentação do jogador: escolhe o quadro do sprite (parado, andar nas 4 direções,
## ataque, morto) pelo que o corpo faz e toca o som do golpe. Só apresentação: lê
## `velocity`, `attacked` e a vida do `Player`; nenhuma regra mora aqui.
## Instancie FORA do `Player.tscn`.
##
## Folha `sprites/jogador/jogador.png` (quadros de 32x32, 10 colunas x 4 linhas), descrita por
## `jogador.json`: a linha é a direção (baixo, cima, esquerda, direita) e as colunas são as
## animações `idle`, `walk`, `hit` (golpe, sem laço) e `fall` (caído). Os pés ficam em y=30 do quadro.
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
const SHEET_PATH := "res://assets/sprites/jogador/jogador.json"
const ANIM_IDLE := "idle"
const ANIM_WALK := "walk"
const ANIM_HIT := "hit"
const ANIM_FALL := "fall"
const MOVING_SPEED_SQUARED := 1.0
## Duração do golpe se a folha não tiver `hit`.
const FALLBACK_ATTACK_SECONDS := 0.25

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
## Tempo andando sem parar: o ciclo de passos recomeça no primeiro quadro a cada partida.
var _walk_time := 0.0
var _attack_left := 0.0
var _sheet: SpriteSheetDef = SpriteSheetDef.from_json_file(SHEET_PATH)
## Segundos do golpe em curso (a duração vem da folha: colunas do `hit` / fps).
var _attack_seconds := maxf(_sheet.duration(ANIM_HIT), FALLBACK_ATTACK_SECONDS)
var _facing := SpriteFacing.DOWN
var _popups := Node2D.new()


func _ready() -> void:
	z_index = 11
	_audio.volume_db = volume_db
	_audio.bus = GameSettings.BUS_SFX
	add_child(_audio)
	add_child(_popups)
	_breath.volume_db = volume_db
	_breath.bus = GameSettings.BUS_SFX
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
	_walk_time = _walk_time + delta if player.velocity.length_squared() > MOVING_SPEED_SQUARED else 0.0
	_attack_left = maxf(_attack_left - delta, 0.0)
	_tick_breath(delta)
	var sprite := player.visual
	if player.is_incapacitated():  # morto ou caído: o quadro de queda
		_show_frame(sprite, _sheet.column_at(ANIM_FALL, 0.0))
		return
	var moving := player.velocity.length_squared() > MOVING_SPEED_SQUARED
	if moving:
		_facing = SpriteFacing.facing_for(player.velocity, _facing, _sheet.rows)
	var column := 0
	if _attack_left > 0.0:
		column = _sheet.column_at(ANIM_HIT, _attack_seconds - _attack_left)
	elif moving:
		column = _sheet.column_at(ANIM_WALK, _walk_time)
	else:
		column = _sheet.column_at(ANIM_IDLE, _time)
	_show_frame(sprite, column)


## Mostra o quadro `column` na linha da direção (mesma ordem de `SpriteFacing`). Folha do JSON inválida ou
## de outro tamanho que o sprite da cena: fica no primeiro quadro da direção, nunca fora da folha.
## Troca a folha (testes e folhas de outras skins).
func use_sheet(sheet: SpriteSheetDef) -> void:
	_sheet = sheet
	_attack_seconds = maxf(_sheet.duration(ANIM_HIT), FALLBACK_ATTACK_SECONDS)


func _show_frame(sprite: Sprite2D, column: int) -> void:
	var usable := SpriteFacing.fit_sheet(sprite, _sheet)
	sprite.frame_coords = Vector2i(
			clampi(column if usable else 0, 0, sprite.hframes - 1), clampi(_facing, 0, sprite.vframes - 1))


func follow() -> void:
	if is_instance_valid(player):
		global_position = player.global_position


func audio_player() -> AudioStreamPlayer2D:
	return _audio


## Duração do golpe, em segundos (vem da folha).
func attack_seconds() -> float:
	return _attack_seconds


func is_attacking() -> bool:
	return _attack_left > 0.0


## Sopros de fôlego abaixo de 25% de stamina: mais rápidos e agudos perto de zerar.
func _tick_breath(delta: float) -> void:
	var stamina := player.stamina
	# O fôlego longo toca inteiro: nenhum sopro o corta.
	_gasp_left = maxf(_gasp_left - delta, 0.0)
	if player.is_incapacitated() or not stamina.is_winded():
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
	_attack_left = _attack_seconds
	if player.target != null and is_instance_valid(player.target):
		_facing = SpriteFacing.facing_for(player.target.global_position - player.global_position, _facing, _sheet.rows)
	sound_cue.emit(CUE_ATTACK)
	var stream: AudioStream = cue_streams.get(CUE_ATTACK)
	if stream != null:
		_audio.stream = stream
		_audio.play()
