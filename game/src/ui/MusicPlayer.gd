# SPDX-License-Identifier: MIT
class_name MusicPlayer
extends Node
## Música de fundo no barramento `Music`: UMA faixa em loop, com crossfade curto na troca (dois players, um sobe e o
## outro desce). `play_track` toca uma faixa; `follow_world` faz a faixa de dia e a de noite seguirem o `WorldClock`.
## O volume é do jogador (Música, em Configurações). Só apresentação: observa o relógio e nunca decide nada do jogo.

signal track_changed(stream: AudioStream)

const TRACK_MENU: AudioStream = preload("res://assets/audio/musica/musica_menu.wav")
const TRACK_DAY: AudioStream = preload("res://assets/audio/musica/musica_dia.wav")
const TRACK_NIGHT: AudioStream = preload("res://assets/audio/musica/musica_noite.wav")
## Silêncio do player que sai do ar (dB), para não deixar o fim do fade audível.
const SILENT_DB := -60.0
## Passos do mixer a esperar depois de parar a música na saída da árvore, e o teto de espera (ms). O mixer só solta o
## stream que parou nos passos seguintes dele; sair do programa antes disso deixa a faixa "em uso" e o Godot acusa
## vazamento no log de saída (intermitente, por isso se conta passo do mixer em vez de dormir um tempo fixo).
const EXIT_MIXER_STEPS := 3
const EXIT_MAX_WAIT_MSEC := 300

@export var rules: MusicRules = preload("res://data/balance/music_rules.tres")
@export var day_track: AudioStream = TRACK_DAY
@export var night_track: AudioStream = TRACK_NIGHT

var _players: Array[AudioStreamPlayer] = [AudioStreamPlayer.new(), AudioStreamPlayer.new()]
var _active: int = 0
var _track: AudioStream = null
## Segundos que faltam do crossfade em curso (0 = nenhum).
var _fade_left: float = 0.0
var _clock: WorldClock = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # a música segue na pausa
	for player in _players:
		player.bus = GameSettings.BUS_MUSIC
		player.finished.connect(_on_finished.bind(player))  # rede de segurança: formato sem loop próprio recomeça daqui
		add_child(player)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		for player in _players:  # nunca entrou na árvore: os players não têm dono para liberá-los
			if is_instance_valid(player) and player.get_parent() == null:
				player.free()


func _exit_tree() -> void:
	if _track == null:
		return
	for player in _players:
		player.stop()
	var steps := 0
	var waited := 0
	var last := AudioServer.get_time_since_last_mix()
	while steps < EXIT_MIXER_STEPS and waited < EXIT_MAX_WAIT_MSEC:
		OS.delay_msec(2)
		waited += 2
		var now := AudioServer.get_time_since_last_mix()
		if now < last:  # o contador zera a cada passo do mixer
			steps += 1
		last = now


func _process(delta: float) -> void:
	tick(delta)


## Passo de tempo (separado do `_process` para testar sem frames): segue o relógio e avança o crossfade.
func tick(delta: float) -> void:
	if _clock != null:
		var wanted := night_track if rules.is_night(_clock.now()) else day_track
		if wanted != _track:
			play_track(wanted)
	if _fade_left <= 0.0:
		return
	_fade_left = maxf(_fade_left - delta, 0.0)
	var done := 1.0 if rules.crossfade_seconds <= 0.0 else 1.0 - _fade_left / rules.crossfade_seconds
	_players[_active].volume_db = _fade_db(done)
	var old := _players[1 - _active]
	old.volume_db = _fade_db(1.0 - done)
	if _fade_left <= 0.0:
		old.stop()
		old.stream = null


## Faz a faixa seguir o relógio do mundo: dia ou noite conforme `WorldClock.now()`. `null` solta o relógio.
func follow_world(clock: WorldClock) -> void:
	_clock = clock
	if clock != null:
		tick(0.0)


## Toca `stream` em loop. A mesma faixa já tocando não reinicia; null equivale a `stop_track`. Se havia outra faixa
## no ar, ela desce enquanto a nova sobe (`MusicRules.crossfade_seconds`).
func play_track(stream: AudioStream) -> void:
	if stream == null:
		stop_track()
		return
	if stream == _track and _players[_active].playing:
		return
	var crossfade := _players[_active].playing and rules.crossfade_seconds > 0.0
	var old := _players[_active]
	_active = 1 - _active
	_track = stream
	_enable_loop(stream)
	var fresh := _players[_active]
	fresh.stream = stream
	if crossfade:
		fresh.volume_db = SILENT_DB
		_fade_left = rules.crossfade_seconds
	else:
		old.stop()
		old.stream = null
		fresh.volume_db = 0.0
		_fade_left = 0.0
	fresh.play()
	track_changed.emit(stream)


func stop_track() -> void:
	_track = null
	_fade_left = 0.0
	for player in _players:
		player.stop()
		player.stream = null
		player.volume_db = 0.0
	track_changed.emit(null)


func current_track() -> AudioStream:
	return _track


func is_playing() -> bool:
	return _players[_active].playing


## Há um crossfade em curso?
func is_crossfading() -> bool:
	return _fade_left > 0.0


## O player da faixa atual.
func audio_player() -> AudioStreamPlayer:
	return _players[_active]


func _fade_db(ratio: float) -> float:
	return SILENT_DB if ratio <= 0.001 else maxf(linear_to_db(ratio), SILENT_DB)


## Liga o loop nativo (sem emenda) nos formatos que o têm.
func _enable_loop(stream: AudioStream) -> void:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	elif stream is AudioStreamWAV:
		_loop_wav(stream as AudioStreamWAV)


## WAV de 8 ou 16 bits: laço do começo ao fim. Outros formatos (ADPCM) recomeçam pelo `finished`.
func _loop_wav(wav: AudioStreamWAV) -> void:
	if wav.loop_mode != AudioStreamWAV.LOOP_DISABLED:
		return
	var bytes_per_sample := 0
	if wav.format == AudioStreamWAV.FORMAT_8_BITS:
		bytes_per_sample = 1
	elif wav.format == AudioStreamWAV.FORMAT_16_BITS:
		bytes_per_sample = 2
	if bytes_per_sample == 0:
		return
	var frame_bytes := bytes_per_sample * (2 if wav.stereo else 1)
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = wav.data.size() / frame_bytes


func _on_finished(player: AudioStreamPlayer) -> void:
	if _track != null and player == _players[_active]:
		player.play()
