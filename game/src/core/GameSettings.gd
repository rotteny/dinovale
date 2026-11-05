# SPDX-License-Identifier: MIT
class_name GameSettings
extends RefCounted
## Configurações mínimas do jogador: tela cheia e volume geral. Guardadas em `user://` como JSON
## (ADR-002: dado externo nunca executa código). Arquivo ausente, grande demais, ilegível, que não é
## dicionário ou com valor de tipo errado cai nos padrões (`SafeRead`). A tela cheia só muda pelo
## menu de Configurações.

const PATH := "user://settings.json"
const DEFAULT_VOLUME := 0.8
const VOLUME_STEP := 0.05
## Passo do ciclo de volume por clique ou Enter; passando de 100% volta a 0.
const VOLUME_CYCLE_STEP := 0.1
const MIN_DB := -80.0
## Arquivo maior que isto é lixo: ignorado sem ler.
const MAX_FILE_BYTES := 4096

var fullscreen: bool = true
## Volume geral, de 0 a 1 (linear).
var volume: float = DEFAULT_VOLUME


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
	return settings


## Grava o arquivo. Devolve true se gravou.
func save_to(path: String = PATH) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify({"fullscreen": fullscreen, "volume": volume}))
	file.close()
	return true


func set_volume(value: float) -> void:
	volume = clampf(snappedf(value, 0.01), 0.0, 1.0)


## Clique ou Enter no volume: sobe um passo e volta a 0 depois de 100%.
func cycle_volume() -> void:
	var next := volume + VOLUME_CYCLE_STEP
	set_volume(0.0 if snappedf(next, 0.01) > 1.0 else next)


## Volume em dB para o barramento principal (0 = mudo).
static func volume_to_db(linear: float) -> float:
	return MIN_DB if linear <= 0.0 else maxf(linear_to_db(linear), MIN_DB)


## Aplica na janela e no áudio.
func apply() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
	AudioServer.set_bus_volume_db(0, volume_to_db(volume))
	AudioServer.set_bus_mute(0, volume <= 0.0)
