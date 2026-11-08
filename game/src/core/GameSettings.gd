# SPDX-License-Identifier: MIT
class_name GameSettings
extends RefCounted
## Configurações mínimas do jogador: tela cheia, mudo e três volumes (Geral, Música, Efeitos). Guardadas em `user://` como JSON
## (ADR-002: dado externo nunca executa código). Arquivo ausente, grande demais, ilegível, que não é
## dicionário ou com valor de tipo errado cai nos padrões (`SafeRead`). A tela cheia só muda pelo
## menu de Configurações.

const PATH := "user://settings.json"
const DEFAULT_VOLUME := 0.8
const DEFAULT_MUSIC_VOLUME := 0.7
const DEFAULT_SFX_VOLUME := 1.0
## Barramentos (`default_bus_layout.tres`): Música e Efeitos saem pelo Master.
const BUS_MASTER := &"Master"
const BUS_MUSIC := &"Music"
const BUS_SFX := &"SFX"
## Ids dos volumes ajustáveis no menu.
const LEVEL_MASTER := "volume"
const LEVEL_MUSIC := "music"
const LEVEL_SFX := "sfx"
const VOLUME_STEP := 0.05
## Passo do ciclo de volume por clique ou Enter; passando de 100% volta a 0.
const VOLUME_CYCLE_STEP := 0.1
const MIN_DB := -80.0
## Arquivo maior que isto é lixo: ignorado sem ler.
const MAX_FILE_BYTES := 4096

var fullscreen: bool = true
## Volume geral, de 0 a 1 (linear).
var volume: float = DEFAULT_VOLUME
## Volume da música e dos efeitos, de 0 a 1 (linear).
var music_volume: float = DEFAULT_MUSIC_VOLUME
var sfx_volume: float = DEFAULT_SFX_VOLUME
## Mudo geral: silencia tudo sem perder os volumes.
var muted: bool = false


## Lê o arquivo; qualquer problema resulta nos padrões.
static func load_from(path: String = PATH) -> GameSettings:
	var settings := GameSettings.new()
	if not FileAccess.file_exists(path):
		return settings
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > MAX_FILE_BYTES:
		return settings
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		return settings
	var data := SafeRead.dict(parser.data)
	settings.fullscreen = SafeRead.flag(data.get("fullscreen"), true)
	settings.volume = SafeRead.number(data.get("volume"), DEFAULT_VOLUME, 0.0, 1.0)
	settings.music_volume = SafeRead.number(data.get("music_volume"), DEFAULT_MUSIC_VOLUME, 0.0, 1.0)
	settings.sfx_volume = SafeRead.number(data.get("sfx_volume"), DEFAULT_SFX_VOLUME, 0.0, 1.0)
	settings.muted = SafeRead.flag(data.get("muted"), false)
	return settings


## Grava o arquivo. Devolve true se gravou.
func save_to(path: String = PATH) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({
		"fullscreen": fullscreen, "volume": volume, "music_volume": music_volume, "sfx_volume": sfx_volume,
		"muted": muted,
	}))
	file.close()
	return true


func set_volume(value: float) -> void:
	volume = _clean(value)


func set_music_volume(value: float) -> void:
	music_volume = _clean(value)


func set_sfx_volume(value: float) -> void:
	sfx_volume = _clean(value)


## Volume (0 a 1) do ajuste `LEVEL_*`; id desconhecido dá 0.
func level(id: String) -> float:
	match id:
		LEVEL_MASTER:
			return volume
		LEVEL_MUSIC:
			return music_volume
		LEVEL_SFX:
			return sfx_volume
	return 0.0


## Muda o volume do ajuste `LEVEL_*`; id desconhecido é ignorado.
func set_level(id: String, value: float) -> void:
	match id:
		LEVEL_MASTER:
			set_volume(value)
		LEVEL_MUSIC:
			set_music_volume(value)
		LEVEL_SFX:
			set_sfx_volume(value)


## Clique ou Enter no volume: sobe um passo e volta a 0 depois de 100%.
func cycle_level(id: String) -> void:
	var next := level(id) + VOLUME_CYCLE_STEP
	set_level(id, 0.0 if snappedf(next, 0.01) > 1.0 else next)


func cycle_volume() -> void:
	cycle_level(LEVEL_MASTER)


static func _clean(value: float) -> float:
	return clampf(snappedf(value, 0.01), 0.0, 1.0)


## Volume em dB para o barramento principal (0 = mudo).
static func volume_to_db(linear: float) -> float:
	return MIN_DB if linear <= 0.0 else maxf(linear_to_db(linear), MIN_DB)


## Aplica na janela e nos barramentos. Barramento que não existe é ignorado (nada quebra).
func apply() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	_apply_bus(BUS_MASTER, volume, muted)
	_apply_bus(BUS_MUSIC, music_volume, false)
	_apply_bus(BUS_SFX, sfx_volume, false)


static func _apply_bus(bus: StringName, linear: float, mute: bool) -> void:
	var index := AudioServer.get_bus_index(bus)
	if index < 0:
		return
	AudioServer.set_bus_volume_db(index, volume_to_db(linear))
	AudioServer.set_bus_mute(index, mute or linear <= 0.0)
