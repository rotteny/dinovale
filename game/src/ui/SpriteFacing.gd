# SPDX-License-Identifier: MIT
class_name SpriteFacing
extends RefCounted
## Linhas de direção das folhas de sprite: 0 = baixo, 1 = cima, 2 = esquerda, 3 = direita e, nas folhas de 8 direções,
## 4 = baixo-esquerda, 5 = baixo-direita, 6 = cima-esquerda, 7 = cima-direita; cada coluna é um quadro da animação.
## Folha de 4 linhas continua válida (cai na direção cardinal dominante). Só apresentação.

const DOWN := 0
const UP := 1
const LEFT := 2
const RIGHT := 3
const DOWN_LEFT := 4
const DOWN_RIGHT := 5
const UP_LEFT := 6
const UP_RIGHT := 7
## Linhas de uma folha de 8 direções.
const EIGHT_DIRECTIONS := 8
## Largura de cada setor (45 graus) e folga extra (graus) para trocar de setor: anda em arco sem o sprite piscar.
const SECTOR_DEGREES := 45.0
const HYSTERESIS_DEGREES := 8.0
## Ângulo (graus, y para baixo, 0 = direita) do centro de cada linha, na ordem das linhas.
const ROW_ANGLES: Array[float] = [90.0, 270.0, 180.0, 0.0, 135.0, 45.0, 225.0, 315.0]
const WALK_FPS := 8.0
const WALK_FRAMES := 4


## Coluna da direção dominante; `fallback` se não há direção.
static func column_for(direction: Vector2, fallback: int) -> int:
	if direction.length_squared() < 0.0001:
		return fallback
	if absf(direction.x) > absf(direction.y):
		return RIGHT if direction.x > 0.0 else LEFT
	return DOWN if direction.y > 0.0 else UP


## Quadro (linha) do ciclo de andar para o tempo acumulado.
static func walk_row(time: float) -> int:
	return int(time * WALK_FPS) % WALK_FRAMES


## Linha da direção para uma folha de `rows` linhas. Com 8 linhas usa o setor de 45 graus do movimento, com histerese:
## `fallback` (a linha de antes) só é trocada se o ângulo passar do limite do setor dela por `HYSTERESIS_DEGREES`.
## Sem direção devolve `fallback`. Com menos de 8 linhas cai na direção cardinal (`column_for`).
static func facing_for(direction: Vector2, fallback: int, rows: int) -> int:
	if rows < EIGHT_DIRECTIONS:
		return column_for(direction, fallback if fallback < RIGHT + 1 else DOWN)
	if direction.length_squared() < 0.0001:
		return fallback
	var angle := fposmod(rad_to_deg(atan2(direction.y, direction.x)), 360.0)
	if fallback >= 0 and fallback < EIGHT_DIRECTIONS:
		if _angle_gap(angle, ROW_ANGLES[fallback]) <= SECTOR_DEGREES * 0.5 + HYSTERESIS_DEGREES:
			return fallback
	var best := 0
	var best_gap := 360.0
	for row in EIGHT_DIRECTIONS:
		var gap := _angle_gap(angle, ROW_ANGLES[row])
		if gap < best_gap:
			best_gap = gap
			best = row
	return best


## Ajusta `hframes`/`vframes` do sprite à folha descrita pelo JSON, se a textura tem o tamanho dela. Devolve se pode usar.
static func fit_sheet(sprite: Sprite2D, sheet: SpriteSheetDef) -> bool:
	if not sheet.is_valid() or sprite.texture == null:
		return false
	if sprite.texture.get_size() != Vector2(sheet.frame_size * Vector2i(sheet.columns, sheet.rows)):
		return false
	sprite.hframes = sheet.columns
	sprite.vframes = sheet.rows
	return true


static func _angle_gap(a: float, b: float) -> float:
	var gap := absf(fposmod(a - b, 360.0))
	return minf(gap, 360.0 - gap)
