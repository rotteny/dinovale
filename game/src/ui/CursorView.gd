# SPDX-License-Identifier: MIT
class_name CursorView
extends Node
## Cursor do mouse em pixel art que muda com a ação sob o ponteiro (mão, machado, picareta, ataque, interagir; apagado
## quando o alvo está fora do alcance). Só apresentação: QUAL ação existe vem da lógica (`PlayerController.cursor_state`);
## aqui só se escolhe a imagem e se chama `Input.set_custom_mouse_cursor`. O tamanho segue a altura da janela (até 800 px:
## 32; acima: 48; 16 só de reserva se a imagem faltar). Sem controlador (tela de título), com o teclado em uso ou sobre a
## UI, vale o `padrao`. A consulta roda quando o mouse mexe e a cada `poll_seconds` (o mundo muda sem o mouse mexer).

const DIR := "res://assets/ui/cursores/"
const HOTSPOTS_PATH := DIR + "cursores.json"
const SIZE_SMALL := 16
const SIZE_MEDIUM := 32
const SIZE_LARGE := 48
## Altura da janela (px) até onde vale o cursor de 32; acima dela, o de 48.
const MEDIUM_MAX_WINDOW_HEIGHT := 800
const ACTIONS: Array[StringName] = [&"padrao", &"mao", &"machado", &"picareta", &"ataque", &"interagir"]
## Todas as imagens, por caminho (`preload` literal: `load` com caminho montado é proibido pela regra de arquitetura).
const TEXTURES: Dictionary[String, Texture2D] = {
	"res://assets/ui/cursores/padrao_16.png": preload("res://assets/ui/cursores/padrao_16.png"),
	"res://assets/ui/cursores/padrao_32.png": preload("res://assets/ui/cursores/padrao_32.png"),
	"res://assets/ui/cursores/padrao_48.png": preload("res://assets/ui/cursores/padrao_48.png"),
	"res://assets/ui/cursores/padrao_fora_16.png": preload("res://assets/ui/cursores/padrao_fora_16.png"),
	"res://assets/ui/cursores/padrao_fora_32.png": preload("res://assets/ui/cursores/padrao_fora_32.png"),
	"res://assets/ui/cursores/padrao_fora_48.png": preload("res://assets/ui/cursores/padrao_fora_48.png"),
	"res://assets/ui/cursores/mao_16.png": preload("res://assets/ui/cursores/mao_16.png"),
	"res://assets/ui/cursores/mao_32.png": preload("res://assets/ui/cursores/mao_32.png"),
	"res://assets/ui/cursores/mao_48.png": preload("res://assets/ui/cursores/mao_48.png"),
	"res://assets/ui/cursores/mao_fora_16.png": preload("res://assets/ui/cursores/mao_fora_16.png"),
	"res://assets/ui/cursores/mao_fora_32.png": preload("res://assets/ui/cursores/mao_fora_32.png"),
	"res://assets/ui/cursores/mao_fora_48.png": preload("res://assets/ui/cursores/mao_fora_48.png"),
	"res://assets/ui/cursores/machado_16.png": preload("res://assets/ui/cursores/machado_16.png"),
	"res://assets/ui/cursores/machado_32.png": preload("res://assets/ui/cursores/machado_32.png"),
	"res://assets/ui/cursores/machado_48.png": preload("res://assets/ui/cursores/machado_48.png"),
	"res://assets/ui/cursores/machado_fora_16.png": preload("res://assets/ui/cursores/machado_fora_16.png"),
	"res://assets/ui/cursores/machado_fora_32.png": preload("res://assets/ui/cursores/machado_fora_32.png"),
	"res://assets/ui/cursores/machado_fora_48.png": preload("res://assets/ui/cursores/machado_fora_48.png"),
	"res://assets/ui/cursores/picareta_16.png": preload("res://assets/ui/cursores/picareta_16.png"),
	"res://assets/ui/cursores/picareta_32.png": preload("res://assets/ui/cursores/picareta_32.png"),
	"res://assets/ui/cursores/picareta_48.png": preload("res://assets/ui/cursores/picareta_48.png"),
	"res://assets/ui/cursores/picareta_fora_16.png": preload("res://assets/ui/cursores/picareta_fora_16.png"),
	"res://assets/ui/cursores/picareta_fora_32.png": preload("res://assets/ui/cursores/picareta_fora_32.png"),
	"res://assets/ui/cursores/picareta_fora_48.png": preload("res://assets/ui/cursores/picareta_fora_48.png"),
	"res://assets/ui/cursores/ataque_16.png": preload("res://assets/ui/cursores/ataque_16.png"),
	"res://assets/ui/cursores/ataque_32.png": preload("res://assets/ui/cursores/ataque_32.png"),
	"res://assets/ui/cursores/ataque_48.png": preload("res://assets/ui/cursores/ataque_48.png"),
	"res://assets/ui/cursores/ataque_fora_16.png": preload("res://assets/ui/cursores/ataque_fora_16.png"),
	"res://assets/ui/cursores/ataque_fora_32.png": preload("res://assets/ui/cursores/ataque_fora_32.png"),
	"res://assets/ui/cursores/ataque_fora_48.png": preload("res://assets/ui/cursores/ataque_fora_48.png"),
	"res://assets/ui/cursores/interagir_16.png": preload("res://assets/ui/cursores/interagir_16.png"),
	"res://assets/ui/cursores/interagir_32.png": preload("res://assets/ui/cursores/interagir_32.png"),
	"res://assets/ui/cursores/interagir_48.png": preload("res://assets/ui/cursores/interagir_48.png"),
	"res://assets/ui/cursores/interagir_fora_16.png": preload("res://assets/ui/cursores/interagir_fora_16.png"),
	"res://assets/ui/cursores/interagir_fora_32.png": preload("res://assets/ui/cursores/interagir_fora_32.png"),
	"res://assets/ui/cursores/interagir_fora_48.png": preload("res://assets/ui/cursores/interagir_fora_48.png"),
}
## Formas do cursor do sistema que recebem a imagem (qualquer `Control` com outra forma também a mostra).
const SHAPES: Array[Input.CursorShape] = [
	Input.CURSOR_ARROW, Input.CURSOR_IBEAM, Input.CURSOR_POINTING_HAND, Input.CURSOR_CROSS, Input.CURSOR_WAIT,
	Input.CURSOR_BUSY, Input.CURSOR_DRAG, Input.CURSOR_CAN_DROP, Input.CURSOR_FORBIDDEN, Input.CURSOR_VSIZE,
	Input.CURSOR_HSIZE, Input.CURSOR_BDIAGSIZE, Input.CURSOR_FDIAGSIZE, Input.CURSOR_MOVE, Input.CURSOR_VSPLIT,
	Input.CURSOR_HSPLIT, Input.CURSOR_HELP,
]

## Quem sabe a ação sob o ponteiro (o `PlayerController`). Null (tela de título) = sempre `padrao`.
@export var source: CursorSource
@export_range(0.05, 2.0) var poll_seconds: float = 0.2

## Último estado aplicado e quantas vezes o cursor do sistema foi trocado (o sistema não se lê de volta; serve a teste).
var applied_action: StringName = &""
var applied_in_reach: bool = true
var applied_size: int = 0
var apply_count: int = 0

var _hotspots: Dictionary = {}
var _dirty: bool = true
var _since_poll: float = 0.0


func _ready() -> void:
	_hotspots = load_hotspots()
	var window := get_window()
	if window != null:
		window.size_changed.connect(_mark_dirty)
	refresh()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_dirty = true


func _process(delta: float) -> void:
	_since_poll += delta
	if _dirty or _since_poll >= poll_seconds:
		refresh()


## O sistema pode zerar o cursor ao devolver o foco à janela: aplica de novo.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		applied_size = 0
		apply(applied_action if applied_action != &"" else &"padrao", applied_in_reach)


## Lado do cursor para uma janela dessa altura: 32 até 800 px, 48 acima (decisão do dono; 64 ficaria enorme).
static func size_for(window_height: int) -> int:
	return SIZE_MEDIUM if window_height <= MEDIUM_MAX_WINDOW_HEIGHT else SIZE_LARGE


## Caminho da imagem de uma ação: `padrao_32.png`, ou `mao_fora_32.png` (variante apagada, fora do alcance).
static func image_path(action: StringName, in_reach: bool, size: int) -> String:
	return "%s%s%s_%d.png" % [DIR, action, "" if in_reach else "_fora", size]


## Hotspots por ação e por tamanho (`cursores.json`, o do gerador): `{ação: {"16": [x, y], ...}}`. Vazio se o arquivo faltar.
static func load_hotspots() -> Dictionary:
	var file := FileAccess.open(HOTSPOTS_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	var table: Dictionary = {}
	if parsed is Dictionary and (parsed as Dictionary).get("cursores") is Dictionary:
		for action: Variant in (parsed as Dictionary)["cursores"]:
			var entry: Variant = ((parsed as Dictionary)["cursores"] as Dictionary)[action]
			if entry is Dictionary and (entry as Dictionary).get("hotspot_por_tamanho") is Dictionary:
				table[StringName(str(action))] = (entry as Dictionary)["hotspot_por_tamanho"]
	return table


## O ponto de ancoragem (ponta, centro da mão) da ação nesse tamanho, em pixels da imagem.
func hotspot_of(action: StringName, size: int) -> Vector2i:
	var by_size: Variant = _hotspots.get(action)
	if by_size is Dictionary:
		var point: Variant = (by_size as Dictionary).get(str(size))
		if point is Array and (point as Array).size() == 2:
			return Vector2i(int((point as Array)[0]), int((point as Array)[1]))
	return Vector2i.ZERO


## Consulta a ação sob o ponteiro e troca o cursor se mudou. Público para testar sem quadros.
func refresh() -> void:
	_dirty = false
	_since_poll = 0.0
	var action: StringName = &"padrao"
	var in_reach := true
	if source != null:
		var state := source.current_cursor()
		action = state["action"]
		in_reach = state["in_reach"]
	apply(action, in_reach)


## Põe o cursor da ação, no tamanho da janela atual. Não faz nada se já é o que está aplicado.
func apply(action: StringName, in_reach: bool) -> void:
	var window := get_window()
	var size := size_for(window.size.y) if window != null else SIZE_MEDIUM
	if action == applied_action and in_reach == applied_in_reach and size == applied_size:
		return
	var texture := _texture_for(action, in_reach, size)
	if texture == null:  # imagem faltando: cai no tamanho de reserva
		size = SIZE_SMALL
		texture = _texture_for(action, in_reach, size)
	if texture == null:
		return
	var hotspot := hotspot_of(action, size)
	for shape in SHAPES:
		Input.set_custom_mouse_cursor(texture, shape, hotspot)
	applied_action = action
	applied_in_reach = in_reach
	applied_size = size
	apply_count += 1


## O cursor do sistema recebe uma cópia em memória (como o `Input` guarda a imagem até sair, a textura da cena não fica presa).
func _texture_for(action: StringName, in_reach: bool, size: int) -> Texture2D:
	var source: Texture2D = TEXTURES.get(image_path(action, in_reach, size))
	return ImageTexture.create_from_image(source.get_image()) if source != null else null


func _mark_dirty() -> void:
	applied_size = 0
	_dirty = true
