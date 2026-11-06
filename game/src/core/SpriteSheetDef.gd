# SPDX-License-Identifier: MIT
class_name SpriteSheetDef
extends RefCounted
## Folha de sprite descrita por JSON (formato do `jogador.json`): quadro, linhas por direção e
## animações como lista de colunas com fps. Só dados e conta de quadro; quem desenha é a
## apresentação. Lê com `SafeRead`: arquivo ausente ou torto devolve uma definição vazia
## (`is_valid()` falso), nunca aborta.

var frame_size: Vector2i = Vector2i.ZERO
var columns: int = 0
var rows: int = 0
## Ordem das linhas: o índice da direção (`SpriteFacing.DOWN`, `UP`, `LEFT`, `RIGHT`) é o da linha.
var direction_rows: Array[String] = []
## Caixa de colisão nos pés (largura, altura), em pixels.
var feet_collision: Vector2i = Vector2i.ZERO
## nome -> {"columns": Array[int], "fps": float, "loop": bool}
var animations: Dictionary = {}


static func from_json_file(path: String) -> SpriteSheetDef:
	var sheet := SpriteSheetDef.new()
	if not FileAccess.file_exists(path):
		return sheet
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK:
		return sheet
	sheet.load_dict(SafeRead.dict(parser.data))
	return sheet


func load_dict(data: Dictionary) -> void:
	var frame := SafeRead.list(data.get("quadro"))
	if frame.size() == 2:
		frame_size = Vector2i(SafeRead.integer(frame[0], 0, 0, 4096), SafeRead.integer(frame[1], 0, 0, 4096))
	var feet := SafeRead.list(data.get("colisao_pes"))
	if feet.size() == 2:
		feet_collision = Vector2i(SafeRead.integer(feet[0], 0, 0, 4096), SafeRead.integer(feet[1], 0, 0, 4096))
	columns = SafeRead.integer(data.get("colunas"), 0, 0, 1024)
	rows = SafeRead.integer(data.get("linhas"), 0, 0, 1024)
	direction_rows.clear()
	for name: Variant in SafeRead.list(data.get("linhas_direcao")):
		direction_rows.append(SafeRead.text(name, ""))
	animations.clear()
	var raw := SafeRead.dict(data.get("animacoes"))
	for key: Variant in raw:
		var entry := SafeRead.dict(raw[key])
		var cols: Array[int] = []
		for column: Variant in SafeRead.list(entry.get("colunas")):
			var index := SafeRead.integer(column, -1, -1, 1023)
			if index >= 0 and index < columns:
				cols.append(index)
		if cols.is_empty():
			continue
		animations[str(key)] = {
			"columns": cols,
			"fps": SafeRead.number(entry.get("fps"), 1.0, 0.1, 120.0),
			"loop": SafeRead.flag(entry.get("loop"), true),
		}


func is_valid() -> bool:
	return frame_size.x > 0 and frame_size.y > 0 and columns > 0 and rows > 0 \
			and direction_rows.size() == rows and not animations.is_empty()


func has_animation(name: String) -> bool:
	return animations.has(name)


## Coluna do quadro de `name` após `seconds` de animação. Em laço, repete; sem laço, fica no último.
func column_at(name: String, seconds: float) -> int:
	var anim := SafeRead.dict(animations.get(name))
	var cols: Array = anim.get("columns", [])
	if cols.is_empty():
		return 0
	var index := int(maxf(seconds, 0.0) * float(anim["fps"]))
	index = index % cols.size() if anim["loop"] else mini(index, cols.size() - 1)
	return cols[index]


## Duração de uma passada da animação, em segundos.
func duration(name: String) -> float:
	var anim := SafeRead.dict(animations.get(name))
	var cols: Array = anim.get("columns", [])
	return float(cols.size()) / float(anim["fps"]) if not cols.is_empty() else 0.0


## Linha da direção pelo nome do JSON ("down", "up", "left", "right"); -1 se não existe.
func row_of(direction: String) -> int:
	return direction_rows.find(direction)
