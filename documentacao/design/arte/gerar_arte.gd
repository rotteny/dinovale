## Gerador do estudo visual do Dino Vale (ARTE DE IA PLACEHOLDER, ver ESTILO.md).
## Rode da raiz do repositorio:
##   godot --headless --script documentacao/design/arte/gerar_arte.gd
## Saidas (mesma pasta): mock-vale.png, mock-vale-2x.png, folha-sprites-8x.png
## Paleta unica: constante HEX abaixo. Nenhuma cor fora dela e usada (ha checagem no fim).
extends SceneTree

const OUT := "documentacao/design/arte/"
const T := 16

const HEX := {
	"ink": "#43273A", "white": "#FFFFFF", "cream": "#FFF2CC",
	"ga": "#72BE4A", "gc": "#98D75A", "gd": "#4A9A47", "gsh": "#3F8466",
	"j0": "#1B4D3E", "j1": "#17703B", "j2": "#2FA24B", "j3": "#5CCB4F", "j4": "#9BE05A",
	"d0": "#6B4423", "d1": "#9C6A3A", "d2": "#D19A5C", "d3": "#EBC98C", "dsh": "#A5675A",
	"w0": "#5A3A22", "w1": "#8F5E36", "w2": "#B07A45", "w3": "#D4A062",
	"s0": "#4B514C", "s1": "#7A817B", "s2": "#A9AEA5", "s3": "#D3D5C8",
	"o1": "#E07424", "o2": "#FF9B3D", "o3": "#FFC27A",
	"sl0": "#4A5F96", "sl1": "#7088BE", "sl2": "#A3B8DE",
	"pk0": "#E0657F", "pk1": "#FF8FA3", "pk2": "#FFC1CB",
	"b1": "#3A93CC", "b2": "#5FBDF2",
	"sk0": "#C9825A", "sk1": "#F2B48A",
	"fy": "#FFD23F", "fyd": "#E5A515",
	"hr0": "#8A1F2D", "hr1": "#FF4D6A", "hr2": "#FFB3C1",
	"mt0": "#8F3322", "mt1": "#C8502D", "mt2": "#F08A63",
	"pu0": "#5E3FB0", "pu1": "#9B7BEA", "pu2": "#C3AEF5",
}

var P := {}
var rng := RandomNumberGenerator.new()
var tiles := {}
var spr := {}

# ------------------------------------------------------------ primitivas
func img(w: int, h: int) -> Image:
	var i := Image.create(w, h, false, Image.FORMAT_RGBA8)
	i.fill(Color(0, 0, 0, 0))
	return i

func on(m: Image, x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < m.get_width() and y < m.get_height() and m.get_pixel(x, y).a > 0.5

func put(i: Image, x: int, y: int, c: String) -> void:
	if x >= 0 and y >= 0 and x < i.get_width() and y < i.get_height():
		i.set_pixel(x, y, P[c])

func rct(i: Image, x: int, y: int, w: int, h: int, c: String = "white") -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			put(i, xx, yy, c)

func ell(i: Image, cx: float, cy: float, rx: float, ry: float, c: String = "white") -> void:
	for y in range(int(floor(cy - ry)), int(ceil(cy + ry)) + 1):
		for x in range(int(floor(cx - rx)), int(ceil(cx + rx)) + 1):
			var dx := (x + 0.5 - cx) / rx
			var dy := (y + 0.5 - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				put(i, x, y, c)

func pts(i: Image, list: Array, c: String = "white") -> void:
	for p in list:
		put(i, p[0], p[1], c)

func mirror_pts(list: Array, w: int) -> Array:
	var r := []
	for p in list:
		r.append([w - 1 - p[0], p[1]])
	return r

func blit(dst: Image, src: Image, x: int, y: int) -> void:
	dst.blend_rect(src, Rect2i(0, 0, src.get_width(), src.get_height()), Vector2i(x, y))

## Luz de cima-esquerda: borda superior/esquerda clara, inferior/direita escura.
func shade(dst: Image, m: Image, hi: String, base: String, sh: String, wrap: bool = false) -> void:
	var w := m.get_width()
	var h := m.get_height()
	for y in h:
		for x in w:
			if not on(m, x, y):
				continue
			var s := 0
			s += 0 if _n(m, x, y - 1, wrap) else 1
			s += 0 if _n(m, x - 1, y, wrap) else 1
			s -= 0 if _n(m, x, y + 1, wrap) else 1
			s -= 0 if _n(m, x + 1, y, wrap) else 1
			put(dst, x, y, hi if s > 0 else (sh if s < 0 else base))

func _n(m: Image, x: int, y: int, wrap: bool) -> bool:
	if wrap:
		return on(m, posmod(x, m.get_width()), posmod(y, m.get_height()))
	return on(m, x, y)

func flat(dst: Image, m: Image, c: String) -> void:
	for y in m.get_height():
		for x in m.get_width():
			if on(m, x, y):
				put(dst, x, y, c)

func outcol(c: Color) -> String:
	var h := "#" + c.to_html(false).to_upper()
	for k in ["j1", "j2", "j3", "j4"]:
		if HEX[k] == h:
			return "j0"
	for k in ["w1", "w2", "w3"]:
		if HEX[k] == h:
			return "w0"
	for k in ["s1", "s2", "s3"]:
		if HEX[k] == h:
			return "s0"
	return "ink"

func outline(i: Image) -> Image:
	var o := i.duplicate() as Image
	for y in i.get_height():
		for x in i.get_width():
			if i.get_pixel(x, y).a > 0.5:
				continue
			for d in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]:
				var nx: int = x + d.x
				var ny: int = y + d.y
				if nx >= 0 and ny >= 0 and nx < i.get_width() and ny < i.get_height() and i.get_pixel(nx, ny).a > 0.5:
					put(o, x, y, outcol(i.get_pixel(nx, ny)))
					break
	return o

func ascii_sprite(rows: Array, legend: Dictionary, w: int = 16, h: int = 16, ox: int = 2, oy: int = 1) -> Image:
	var i := img(w, h)
	for y in rows.size():
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			if ch != "." and legend.has(ch):
				put(i, ox + x, oy + y, legend[ch])
	return i

# ------------------------------------------------------------ jogador (16x16)
func player(dir: String) -> Image:
	var lg := {"H": "fy", "h": "fyd", "R": "hr1", "r": "hr0", "L": "w0", "l": "w1", "S": "sk1", "s": "sk0",
		"c": "pk1", "k": "ink", "B": "b2", "b": "b1", "P": "w1", "p": "w0", "F": "w0"}
	var rows: Array
	if dir == "down":
		rows = ["...HHHHHhh..", "..HHHHHHHhh.", "..RRRRRRrr..", "HHHHHHHHHhhh",
			"..LSSSSSSL..", "..SSkSSkSS..", "..SSkSSkSs..", "..ScSSSScs..",
			".BBBBBBBBBbb", ".BBBBBBBBBbb", ".SBBBBBBBbS.", "..PPPPPPPp..", "..PPP..PPp..", "..FFF..FFF.."]
	elif dir == "up":
		rows = ["...HHHHHhh..", "..HHHHHHHhh.", "..RRRRRRrr..", "HHHHHHHHHhhh",
			"..LLLLLLLl..", "..LLLLLLLl..", "..LLlLLLll..", "...LLLLLl...",
			".BBBBBBBBBbb", ".BBRRRRRrBb.", ".SBRRRRRrBS.", "..PrrrrrrPp.", "..PPP..PPp..", "..FFF..FFF.."]
	else:
		rows = ["...HHHHHhh..", "..HHHHHHHhh.", "..RRRRRRRrr.", ".HHHHHHHHHhh",
			"..LLSSSSSS..", "..LLSSSSkS..", "..LLSSSSkS..", "...LSSSScSs.",
			".RRBBBBBBBb.", ".RRBBBBBBBb.", ".rrBBBBBBSs.", "...PPPPPPp..", "...PPP.PPp..", "...FFF.FFFF."]
	return outline(ascii_sprite(rows, lg))

# ------------------------------------------------------------ dino pequeno (16x16, cor laranja)
func small_dino(dir: String) -> Image:
	var i := img(16, 16)
	var m: Image
	if dir == "side":
		m = img(16, 16); ell(m, 3.6, 9.2, 3.0, 2.0); ell(m, 2.0, 7.4, 1.3, 1.6); shade(i, m, "o2", "o2", "o1")
		m = img(16, 16); rct(m, 5, 11, 3, 4); rct(m, 10, 11, 2, 4); flat(i, m, "o1")
		m = img(16, 16); ell(m, 7.5, 9.2, 5.0, 3.6); shade(i, m, "o3", "o2", "o1")
		m = img(16, 16); ell(m, 8.0, 11.3, 3.4, 1.5); flat(i, m, "cream")
		pts(i, [[8, 4], [7, 5], [8, 5], [9, 5], [5, 5], [4, 6], [5, 6], [6, 6]], "fy")
		put(i, 8, 5, "fy"); put(i, 5, 6, "fyd"); put(i, 9, 5, "fyd")
		m = img(16, 16); rct(m, 5, 12, 3, 3); rct(m, 9, 12, 3, 3); shade(i, m, "o3", "o2", "o1")
		m = img(16, 16); ell(m, 10.5, 6.8, 3.6, 3.2); shade(i, m, "o3", "o2", "o1")
		pts(i, [[11, 5], [12, 5], [11, 6], [12, 6]], "ink"); put(i, 11, 5, "white")
		pts(i, [[10, 8], [11, 8]], "pk1"); pts(i, [[13, 8]], "ink")
	elif dir == "down":
		m = img(16, 16); ell(m, 8, 11, 4.2, 3.2); shade(i, m, "o3", "o2", "o1")
		m = img(16, 16); ell(m, 8, 12, 2.4, 1.6); flat(i, m, "cream")
		m = img(16, 16); rct(m, 4, 13, 3, 2); rct(m, 9, 13, 3, 2); shade(i, m, "o3", "o2", "o1")
		pts(i, [[7, 1], [8, 1], [6, 2], [7, 2], [8, 2], [9, 2]], "fy"); pts(i, [[8, 1], [9, 2]], "fyd")
		m = img(16, 16); ell(m, 8, 7, 5.5, 4.5); shade(i, m, "o3", "o2", "o1")
		pts(i, [[5, 6], [6, 6], [5, 7], [6, 7], [9, 6], [10, 6], [9, 7], [10, 7]], "ink")
		put(i, 5, 6, "white"); put(i, 9, 6, "white")
		pts(i, [[4, 8], [11, 8]], "pk1"); pts(i, [[7, 9], [8, 9]], "ink")
	else:
		m = img(16, 16); ell(m, 8, 12.5, 2.2, 2.0); flat(i, m, "o1")
		m = img(16, 16); rct(m, 3, 12, 3, 3); rct(m, 10, 12, 3, 3); shade(i, m, "o3", "o2", "o1")
		m = img(16, 16); ell(m, 8, 9.5, 5.0, 3.6); shade(i, m, "o3", "o2", "o1")
		pts(i, [[7, 7], [8, 7], [7, 10], [8, 10]], "fy"); pts(i, [[8, 7], [8, 10]], "fyd")
		m = img(16, 16); ell(m, 8, 5.8, 4.6, 3.8); shade(i, m, "o3", "o2", "o1")
		pts(i, [[7, 1], [8, 1], [6, 2], [7, 2], [8, 2], [9, 2]], "fy"); pts(i, [[8, 1], [9, 2]], "fyd")
		pts(i, [[7, 5], [8, 5]], "o1")
	return outline(i)

# ------------------------------------------------------------ dino adulto herbivoro (32x32): neutro, calmo, olhar sem brilho
# Corpo azul-ardosia, gola e bossas em tons de terra. Sem bochecha, sem reflexo no olho, boca reta.
const HORN_SIDE := [[29, 10], [28, 11], [29, 11], [27, 12], [28, 12], [26, 13], [27, 13]]
const HORN_SLEEP := [[29, 17], [28, 18], [29, 18], [27, 19], [28, 19], [26, 20], [27, 20]]
const HORN_FRONT := [[11, 10], [10, 9], [11, 9], [10, 8], [9, 7], [10, 7]]

func rim_bumps(i: Image, list: Array) -> void:
	for p in list:
		put(i, p[0], p[1], "cream")

func back_bumps(i: Image, xs: Array, y: int) -> void:
	for bx in xs:
		pts(i, [[bx + 1, y], [bx, y + 1], [bx + 1, y + 1], [bx + 2, y + 1], [bx, y + 2], [bx + 1, y + 2], [bx + 2, y + 2]], "d2")
		pts(i, [[bx + 2, y + 1], [bx + 2, y + 2]], "d1")

func big_dino(dir: String, sleeping: bool = false) -> Image:
	var i := img(32, 32)
	var m: Image
	if dir == "side" and not sleeping:
		m = img(32, 32); ell(m, 6, 20, 5, 3.2); shade(i, m, "sl1", "sl1", "sl0")
		m = img(32, 32); rct(m, 10, 23, 5, 8); rct(m, 21, 23, 5, 8); flat(i, m, "sl0")
		m = img(32, 32); ell(m, 15, 19, 10.5, 7.5); shade(i, m, "sl2", "sl1", "sl0")
		m = img(32, 32); ell(m, 15, 24, 7, 2.5); flat(i, m, "cream")
		back_bumps(i, [8, 13, 18], 9)
		m = img(32, 32); rct(m, 6, 23, 6, 8); rct(m, 18, 23, 6, 8); shade(i, m, "sl2", "sl1", "sl0")
		pts(i, [[6, 30], [7, 30], [8, 30], [18, 30], [19, 30], [20, 30]], "sl0")
		m = img(32, 32); ell(m, 21, 13, 5, 6.5); shade(i, m, "d3", "d2", "d1")
		rim_bumps(i, [[19, 7], [22, 7], [25, 9], [16, 10], [17, 8]])
		m = img(32, 32); ell(m, 24.5, 20, 5.5, 5); shade(i, m, "sl2", "sl1", "sl0")
		pts(i, [[28, 11], [27, 12], [28, 12], [26, 13], [27, 13], [25, 14], [26, 14]], "cream"); pts(i, [[28, 12], [27, 13], [26, 14]], "d3")
		pts(i, [[30, 17], [29, 18], [30, 18]], "cream")
		pts(i, [[26, 18], [26, 19]], "ink"); pts(i, [[27, 22], [28, 22], [29, 22]], "ink")
	elif dir == "side":
		m = img(32, 32); ell(m, 6, 25, 5, 2.8); shade(i, m, "sl1", "sl1", "sl0")
		m = img(32, 32); ell(m, 14.5, 23, 11, 5.8); shade(i, m, "sl2", "sl1", "sl0")
		m = img(32, 32); rct(m, 8, 27, 5, 4); rct(m, 18, 28, 5, 3); shade(i, m, "sl2", "sl1", "sl0")
		back_bumps(i, [8, 13, 18], 15)
		m = img(32, 32); ell(m, 20.5, 20, 4.5, 5.5); shade(i, m, "d3", "d2", "d1")
		rim_bumps(i, [[18, 15], [21, 14], [24, 17]])
		m = img(32, 32); ell(m, 25, 25, 5.5, 4.2); shade(i, m, "sl2", "sl1", "sl0")
		pts(i, HORN_SLEEP, "cream"); pts(i, [[28, 18], [27, 19]], "d3")
		pts(i, [[25, 24], [26, 24], [27, 24]], "ink")
		put(i, 28, 27, "ink")
	elif dir == "down":
		m = img(32, 32); ell(m, 16, 22.5, 10, 6.5); shade(i, m, "sl2", "sl1", "sl0")
		m = img(32, 32); rct(m, 7, 26, 5, 5); rct(m, 20, 26, 5, 5); shade(i, m, "sl2", "sl1", "sl0")
		m = img(32, 32); ell(m, 16, 11, 11, 10); shade(i, m, "d3", "d2", "d1")
		rim_bumps(i, [[8, 6], [11, 3], [15, 2], [16, 2], [20, 3], [23, 6], [6, 11], [25, 11]])
		m = img(32, 32); ell(m, 16, 16.5, 7, 6.2); shade(i, m, "sl2", "sl1", "sl0")
		pts(i, HORN_FRONT, "cream"); pts(i, mirror_pts(HORN_FRONT, 32), "cream")
		pts(i, [[10, 9], [10, 8]], "d3"); pts(i, mirror_pts([[10, 9], [10, 8]], 32), "d3")
		m = img(32, 32); ell(m, 16, 20.5, 3, 2.0); flat(i, m, "cream")
		pts(i, [[15, 14], [16, 14], [15, 15], [16, 15]], "cream"); pts(i, [[16, 14], [16, 15]], "d3")
		pts(i, [[12, 16], [12, 17], [19, 16], [19, 17]], "ink")
		pts(i, [[15, 22], [16, 22]], "ink")
	else:
		m = img(32, 32); ell(m, 16, 27, 3, 2.6); flat(i, m, "sl0")
		m = img(32, 32); rct(m, 6, 26, 6, 5); rct(m, 20, 26, 6, 5); shade(i, m, "sl2", "sl1", "sl0")
		m = img(32, 32); ell(m, 16, 21, 10.5, 7.5); shade(i, m, "sl2", "sl1", "sl0")
		pts(i, [[15, 17], [16, 17], [15, 18], [16, 18], [15, 22], [16, 22], [15, 23], [16, 23]], "d2")
		pts(i, [[16, 18], [16, 23]], "d1")
		m = img(32, 32); ell(m, 16, 11.5, 11, 10.5); shade(i, m, "d3", "d2", "d1")
		for y in range(4, 13):
			put(i, 15, y, "d1"); put(i, 16, y, "d1")
		rim_bumps(i, [[8, 6], [11, 3], [15, 2], [16, 2], [20, 3], [23, 6], [6, 11], [25, 11]])
	return outline(i)

# ------------------------------------------------------------ dino adulto carnivoro (32x32, olhando p/ a direita)
# Silhueta: cabeca avancada, mandibula aberta com dentes, cauda grossa, pose de ataque. Olho amarelo com sobrancelha baixa.
func carn_dino() -> Image:
	var i := img(32, 32)
	var m: Image
	m = img(32, 32); ell(m, 7, 17, 6, 2.6); shade(i, m, "o2", "o1", "mt1")
	m = img(32, 32); ell(m, 19, 22, 3, 3.5); rct(m, 19, 24, 3, 5); rct(m, 17, 28, 7, 3); flat(i, m, "mt1")
	var body := img(32, 32)
	ell(body, 15, 17, 8.5, 5.5)
	shade(i, body, "o2", "o1", "mt1")
	m = img(32, 32); ell(m, 15, 20.5, 6, 2.0); flat(i, m, "d3")
	for x in [8, 11, 14, 17]:
		for y in range(11, 17):
			if on(body, x, y):
				put(i, x, y, "mt0")
	m = img(32, 32); ell(m, 13, 21.5, 4.2, 4.5); rct(m, 12, 25, 3, 3); rct(m, 10, 28, 8, 3); shade(i, m, "o2", "o1", "mt1")
	pts(i, [[18, 29], [18, 30], [19, 30]], "white")
	m = img(32, 32); ell(m, 21, 14, 4, 4); shade(i, m, "o2", "o1", "mt1")
	m = img(32, 32); ell(m, 24.5, 11, 5.5, 3.2); shade(i, m, "o2", "o1", "mt1")
	m = img(32, 32); ell(m, 24, 18.8, 4.6, 1.8); shade(i, m, "o1", "o1", "mt1")
	rct(i, 22, 15, 8, 2, "hr0")
	pts(i, [[24, 16], [25, 16], [26, 16]], "hr1")
	pts(i, [[22, 15], [24, 15], [26, 15], [27, 16], [28, 15], [23, 16], [29, 16], [29, 15]], "white")
	pts(i, [[24, 9], [25, 9], [26, 9], [27, 10]], "mt0")
	pts(i, [[25, 10]], "fy"); pts(i, [[26, 10]], "ink")
	pts(i, [[29, 9]], "ink")
	pts(i, [[17, 18], [18, 18], [18, 19], [19, 19]], "mt1"); pts(i, [[20, 19], [20, 20]], "white")
	return outline(i)

# ------------------------------------------------------------ props
func tree(variant: int) -> Image:
	var i := img(32, 40)
	var m := img(32, 40)
	rct(m, 13, 24, 6, 14); rct(m, 11, 35, 10, 3); shade(i, m, "w3", "w2", "w1")
	var blobs := [[10, 17, 7.5], [22, 17, 7.5], [16, 9, 8.0], [16, 18, 8.0]]
	if variant == 1:
		blobs = [[9, 16, 6.5], [23, 18, 7.0], [14, 8, 7.0], [21, 11, 6.5], [15, 18, 7.5]]
	for b in blobs:
		m = img(32, 40); ell(m, b[0], b[1], b[2], b[2] * 0.92); shade(i, m, "j3", "j2", "j1")
	for p in [[12, 8], [20, 12], [8, 15], [14, 16], [22, 20], [11, 20]]:
		put(i, p[0], p[1], "j4"); put(i, p[0] + 1, p[1], "j4")
	for p in [[16, 14], [10, 12], [23, 15]]:
		put(i, p[0], p[1], "j1")
	return outline(i)

func bush(berries: bool) -> Image:
	var i := img(16, 16)
	for b in [[5, 9, 4.5], [11, 9, 4.5], [8, 6.5, 5.0]]:
		var m := img(16, 16); ell(m, b[0], b[1], b[2], b[2] * 0.9); shade(i, m, "j3", "j2", "j1")
	rct(i, 5, 12, 6, 2, "j1")
	if berries:
		for p in [[5, 8], [9, 6], [11, 10], [7, 11]]:
			pts(i, [[p[0], p[1]], [p[0] + 1, p[1]], [p[0], p[1] + 1], [p[0] + 1, p[1] + 1]], "hr1")
			put(i, p[0], p[1], "hr2"); put(i, p[0] + 1, p[1] + 1, "hr0")
	else:
		pts(i, [[6, 5], [7, 5], [10, 8], [4, 8]], "j4")
	return outline(i)

func chest() -> Image:
	var i := img(16, 16)
	var m := img(16, 16)
	rct(m, 2, 7, 12, 7); shade(i, m, "w3", "w2", "w1")
	m = img(16, 16); rct(m, 2, 3, 12, 5); rct(m, 3, 2, 10, 1); shade(i, m, "w3", "w2", "w1")
	rct(i, 7, 3, 2, 11, "s2"); rct(i, 2, 7, 12, 1, "w0")
	pts(i, [[7, 3], [7, 4], [7, 5], [7, 6]], "s3")
	rct(i, 7, 7, 2, 3, "fy"); put(i, 8, 8, "fyd"); put(i, 8, 9, "fyd")
	return outline(i)

# ------------------------------------------------------------ icones
func icon_heart() -> Image:
	var rows := [".RR.RR.", "RhRRRRR", "RRRRRRr", "RRRRRRr", ".RRRRr.", "..RRr..", "...r..."]
	return outline(ascii_sprite(rows, {"R": "hr1", "h": "hr2", "r": "hr0"}, 9, 9, 1, 1))

func icon_bolt() -> Image:
	var rows := ["...YYY", "..YYY.", ".YYY..", "YYYYYy", "..YYy.", ".YYy..", "YYy..."]
	return outline(ascii_sprite(rows, {"Y": "fy", "y": "fyd"}, 9, 9, 1, 1))

func icon_zzz() -> Image:
	var rows := ["WWWWW", "...ww", "..ww.", ".ww..", "WWWWW"]
	return outline(ascii_sprite(rows, {"W": "pu2", "w": "pu1"}, 9, 9, 1, 2))

func icon_drum() -> Image:
	var i := img(11, 11)
	var m := img(11, 11)
	ell(m, 4.5, 4.5, 3.6, 3.3)
	shade(i, m, "mt2", "mt1", "mt0")
	line(i, 6, 6, 8, 8, "cream", false)
	rct(i, 8, 8, 2, 2, "cream")
	put(i, 9, 9, "d3")
	put(i, 3, 3, "white")
	return outline(i)

func food_berry() -> Image:
	var i := img(16, 16)
	var m := img(16, 16); ell(m, 5.0, 10.0, 3.6, 3.6); shade(i, m, "hr2", "hr1", "hr0")
	m = img(16, 16); ell(m, 10.5, 9.0, 3.4, 3.4); shade(i, m, "hr2", "hr1", "hr0")
	pts(i, [[4, 9], [9, 8]], "white")
	pts(i, [[6, 5], [7, 4], [8, 3], [9, 4], [8, 5], [9, 5]], "j2"); pts(i, [[8, 3], [9, 4]], "j4"); put(i, 7, 6, "j1")
	return outline(i)

func food_meat() -> Image:
	var i := img(16, 16)
	var m := img(16, 16); ell(m, 6.5, 6.5, 4.8, 4.2); shade(i, m, "mt2", "mt1", "mt0")
	pts(i, [[4, 4], [5, 4]], "white")
	pts(i, [[9, 9], [10, 10], [11, 11], [12, 12], [10, 9], [11, 10], [12, 11]], "cream")
	rct(i, 12, 12, 2, 2, "cream"); pts(i, [[14, 12], [12, 14]], "cream"); pts(i, [[12, 14], [13, 13]], "d3")
	return outline(i)

func food_egg() -> Image:
	var i := img(16, 16)
	var m := img(16, 16); ell(m, 8, 8.5, 4.6, 5.6); shade(i, m, "white", "cream", "d3")
	pts(i, [[6, 7], [7, 7], [10, 10], [9, 11], [7, 12], [10, 6]], "sl1"); pts(i, [[6, 7], [10, 10]], "sl0")
	return outline(i)

func food_mushroom() -> Image:
	var i := img(16, 16)
	var m := img(16, 16); rct(m, 6, 8, 4, 5); shade(i, m, "white", "cream", "d3")
	m = img(16, 16); ell(m, 8, 7, 5.5, 4.0); rct(m, 3, 8, 10, 1); shade(i, m, "hr2", "hr1", "hr0")
	pts(i, [[5, 5], [6, 5], [9, 4], [11, 7], [7, 8]], "white")
	return outline(i)

func line(i: Image, x0: int, y0: int, x1: int, y1: int, c: String, thick: bool = false) -> void:
	var n := maxi(absi(x1 - x0), absi(y1 - y0))
	for k in range(n + 1):
		var t := float(k) / maxf(n, 1)
		var x := int(round(lerpf(x0, x1, t)))
		var y := int(round(lerpf(y0, y1, t)))
		put(i, x, y, c)
		if thick:
			put(i, x + 1, y, c)

func fern() -> Image:
	var i := img(16, 16)
	for t in [[2, 7], [4, 3], [8, 2], [12, 3], [14, 7]]:
		line(i, 8, 13, t[0], t[1], "j2", true)
		put(i, t[0], t[1], "j4")
		var mx: int = (8 + t[0]) / 2
		var my: int = (13 + t[1]) / 2
		put(i, mx, my - 1, "j3")
	rct(i, 7, 12, 2, 2, "j1")
	return outline(i)

func rock() -> Image:
	var i := img(12, 9)
	var m := img(12, 9)
	ell(m, 5.5, 4.8, 4.3, 3.0)
	shade(i, m, "s3", "s2", "s1")
	put(i, 7, 5, "s0")
	return outline(i)

func flowers(v: int) -> Image:
	var i := img(14, 11)
	var cols := ["hr1", "fy", "white"] if v == 0 else ["pu1", "pk1", "white"]
	var spots := [[2, 3], [7, 1], [10, 4]]
	for k in 3:
		var p: Array = spots[k]
		line(i, p[0] + 1, p[1] + 2, p[0] + 1, 8, "j2")
		rct(i, p[0], p[1], 3, 2, cols[k])
		put(i, p[0] + 1, p[1], "fy" if cols[k] != "fy" else "white")
	pts(i, [[0, 8], [3, 9], [6, 9], [9, 8], [12, 9]], "j1")
	pts(i, [[1, 7], [4, 8], [8, 7], [11, 8]], "j3")
	return i

func shrooms() -> Image:
	var i := img(12, 10)
	for k in [[5.0, 4.0, 3.5, 2.4, 4, 6, 2, 2], [9.0, 6.5, 2.1, 1.6, 9, 8, 1, 2]]:
		var m := img(12, 10)
		rct(m, k[4], k[5], k[6], k[7])
		shade(i, m, "white", "cream", "d3")
		m = img(12, 10)
		ell(m, k[0], k[1], k[2], k[3])
		shade(i, m, "hr2", "hr1", "hr0")
	pts(i, [[4, 3], [6, 4], [3, 4]], "white")
	return outline(i)

func cycad() -> Image:
	var i := img(32, 40)
	var m := img(32, 40)
	rct(m, 14, 18, 5, 20); rct(m, 12, 35, 9, 3)
	shade(i, m, "w3", "w2", "w1")
	for y in range(20, 36, 3):
		pts(i, [[14, y], [16, y + 1], [18, y]], "w1")
	for t in [[2, 14], [4, 5], [11, 1], [21, 1], [28, 5], [30, 14], [3, 23], [29, 23]]:
		line(i, 16, 17, t[0], t[1], "j2", true)
		line(i, 16, 16, t[0], t[1] - 1, "j3")
		put(i, t[0], t[1], "j4")
		put(i, (16 + t[0]) / 2, (17 + t[1]) / 2 + 1, "j1")
	rct(i, 14, 15, 5, 4, "j2"); rct(i, 14, 15, 5, 1, "j3")
	return outline(i)

# ------------------------------------------------------------ tiles
func grass(v: int) -> Image:
	var i := img(T, T)
	rct(i, 0, 0, T, T, "ga")
	var tuft := func(x: int, y: int, c: String, c2: String) -> void:
		pts(i, [[x, y], [x + 2, y], [x + 1, y + 1]], c); put(i, x + 1, y, c2)
	var flower := func(x: int, y: int, c: String) -> void:
		put(i, x, y, c); put(i, x + 1, y + 1, c); put(i, x, y + 1, "fy" if c != "fy" else "white")
	match v:
		0:
			put(i, 11, 4, "gc"); put(i, 3, 12, "gd"); put(i, 8, 8, "gc")
		1:
			tuft.call(2, 3, "gd", "gc"); tuft.call(10, 10, "gd", "gc"); put(i, 13, 3, "gc"); put(i, 6, 13, "gc")
		2:
			flower.call(4, 11, "white"); flower.call(11, 5, "pk1"); tuft.call(10, 12, "gd", "gc"); put(i, 2, 3, "gc")
		3:
			tuft.call(5, 6, "gd", "gc"); tuft.call(11, 12, "gd", "gc"); tuft.call(1, 12, "gc", "gc"); flower.call(12, 3, "pu2"); put(i, 3, 2, "gc")
	return i

func dirt() -> Image:
	var i := img(T, T)
	rct(i, 0, 0, T, T, "d2")
	for p in [[3, 2], [12, 4], [7, 8], [1, 11], [13, 13], [9, 14], [5, 5]]:
		put(i, p[0], p[1], "d3")
	pts(i, [[9, 2], [10, 2], [4, 9], [14, 9], [8, 12]], "d1")
	return i

func foliage_inner() -> Image:
	var i := img(T, T)
	rct(i, 0, 0, T, T, "j1")
	var r := RandomNumberGenerator.new()
	r.seed = 7
	var cs := [[3, 3], [11, 2], [7, 7], [14, 8], [2, 11], [10, 13], [5, 15]]
	for c in cs:
		var m := img(T, T)
		for oy in [-T, 0, T]:
			for ox in [-T, 0, T]:
				ell(m, c[0] + ox, c[1] + oy, 3.8, 3.4)
		shade(i, m, "j3", "j2", "j1", true)
	for p in [[3, 2], [11, 1], [7, 6], [14, 7], [2, 10], [10, 12]]:
		put(i, p[0], p[1], "j4")
	for p in [[6, 12], [13, 13], [8, 2], [0, 6]]:
		put(i, p[0], p[1], "j0")
	return i

const PROF_PATH_A := [1, 1, 1, 2, 2, 2, 1, 1, 1, 1, 2, 2, 1, 1, 1, 1]
const PROF_PATH_B := [1, 1, 2, 2, 1, 1, 1, 1, 1, 2, 2, 2, 2, 1, 1, 1]
const PROF_FOL := [2, 3, 3, 2, 1, 1, 2, 3, 3, 2, 1, 1, 2, 3, 3, 2]

func _cut(x: int, y: int, o: int, prof: Array, corner: int) -> bool:
	if x < 0: return (o & 8) != 0
	if x >= T: return (o & 2) != 0
	if y < 0: return (o & 1) != 0
	if y >= T: return (o & 4) != 0
	if (o & 1) != 0 and y < prof[x]: return true
	if (o & 4) != 0 and (T - 1 - y) < prof[x]: return true
	if (o & 8) != 0 and x < prof[y]: return true
	if (o & 2) != 0 and (T - 1 - x) < prof[y]: return true
	if (o & 9) == 9 and x + y < corner: return true
	if (o & 3) == 3 and (T - 1 - x) + y < corner: return true
	if (o & 6) == 6 and (T - 1 - x) + (T - 1 - y) < corner: return true
	if (o & 12) == 12 and x + (T - 1 - y) < corner: return true
	return false

## o: bits de lados ABERTOS (1=N 2=L 4=S 8=O). Corte periodico de 16 px: emenda entre tiles.
func autotile(inner: Image, o: int, prof: Array, rim: String, corner: int) -> Image:
	var t := img(T, T)
	for y in T:
		for x in T:
			if _cut(x, y, o, prof, corner):
				continue
			var c := inner.get_pixel(x, y)
			if _cut(x - 1, y, o, prof, corner) or _cut(x + 1, y, o, prof, corner) or _cut(x, y - 1, o, prof, corner) or _cut(x, y + 1, o, prof, corner):
				t.set_pixel(x, y, P[rim])
			else:
				t.set_pixel(x, y, c)
	return t

func foundation() -> Image:
	var i := img(T, T)
	rct(i, 0, 0, T, T, "s2")
	for y in [7, 15]:
		rct(i, 0, y, T, 1, "s0")
	rct(i, 7, 0, 1, 8, "s0"); rct(i, 3, 8, 1, 8, "s0")
	rct(i, 11, 8, 1, 8, "s0")
	for b in [[0, 0, 7], [8, 0, 8], [0, 8, 3], [4, 8, 7], [12, 8, 4]]:
		rct(i, b[0], b[1], b[2], 1, "s3")
		rct(i, b[0], b[1], 1, 6, "s3")
		rct(i, b[0], b[1] + 6 if b[1] == 0 else b[1] + 6, b[2] - 1 if b[2] > 1 else 1, 1, "s1")
	return i

## Telhado (terracota) visto de 3/4. row 0 = cumeeira, row 1 = beiral. side: -1 esq, 0 meio, 1 dir.
func roof(row: int, side: int) -> Image:
	var i := img(T, T)
	rct(i, 0, 0, T, T, "mt1")
	for y in T:
		var band := y / 4
		if y % 4 == 3:
			rct(i, 0, y, T, 1, "mt0")
		else:
			if y % 4 == 0:
				rct(i, 0, y, T, 1, "mt2")
			var gx := (band % 2) * 4 + 3
			for x in [gx, gx + 8]:
				put(i, x % T, y, "mt0")
	if row == 0:
		rct(i, 0, 0, T, 1, "mt0"); rct(i, 0, 1, T, 2, "mt2"); rct(i, 0, 3, T, 1, "mt1")
	else:
		rct(i, 0, 13, T, 1, "mt1"); rct(i, 0, 14, T, 2, "mt0")
	if side == -1:
		rct(i, 0, 0, 1, T, "mt0"); rct(i, 1, 1 if row == 0 else 0, 1, 15, "mt2")
	elif side == 1:
		rct(i, 15, 0, 1, T, "mt0"); rct(i, 14, 1 if row == 0 else 0, 1, 15, "mt1")
	return i

## Frente da casa: tabuas verticais, base de pedra; kind = plain | window | door.
func hut_wall(kind: String) -> Image:
	var i := img(T, T)
	for y in range(0, 13):
		for x in T:
			var c := "w2"
			if x % 4 == 0: c = "w3"
			elif x % 4 == 3: c = "w1"
			put(i, x, y, c)
	for x in [3, 7, 11, 15]:
		rct(i, x, 0, 1, 13, "w0")
	rct(i, 0, 0, T, 2, "w1")   # sombra do beiral sobre a parede
	rct(i, 0, 13, T, 1, "s3"); rct(i, 0, 14, T, 1, "s2"); rct(i, 0, 15, T, 1, "s1")
	if kind == "window":
		rct(i, 3, 3, 10, 8, "w0")
		rct(i, 4, 4, 8, 6, "fy")
		rct(i, 4, 4, 8, 1, "fyd"); rct(i, 7, 4, 2, 6, "w1"); rct(i, 4, 7, 8, 1, "w1")
		rct(i, 2, 11, 12, 1, "w3"); rct(i, 2, 12, 12, 1, "w1")
	elif kind == "door":
		rct(i, 3, 2, 10, 14, "w0")
		rct(i, 4, 3, 8, 13, "w1")
		rct(i, 4, 3, 1, 13, "w2"); rct(i, 8, 3, 1, 13, "w0")
		rct(i, 11, 9, 1, 2, "fy")
		rct(i, 2, 14, 12, 2, "s2"); rct(i, 2, 15, 12, 1, "s1")
	return i

func wall() -> Image:
	var i := img(T, T)
	rct(i, 0, 0, T, 1, "w0"); rct(i, 0, 1, T, 2, "w3"); rct(i, 0, 3, T, 1, "w2"); rct(i, 0, 4, T, 1, "w1")
	for y in range(5, 13):
		for x in T:
			var c := "w2"
			if x % 4 == 0: c = "w3"
			elif x % 4 == 3: c = "w1"
			put(i, x, y, c)
	for x in [3, 7, 11, 15]:
		rct(i, x, 5, 1, 8, "w0")
	rct(i, 0, 13, T, 1, "s3"); rct(i, 0, 14, T, 1, "s2"); rct(i, 0, 15, T, 1, "s1")
	return i

# ------------------------------------------------------------ sombras coloridas (so paleta: troca para tom azulado/rosado, nunca preto)
const SHADOW_MAP := {"ga": "gsh", "gc": "gsh", "gd": "gsh", "d2": "dsh", "d3": "dsh", "d1": "d0", "d0": "d0",
	"w2": "w1", "w3": "w2", "s2": "s1", "s3": "s2"}

func shadow(dst: Image, cx: float, cy: float, rx: float, ry: float) -> void:
	var rev := {}
	for k in SHADOW_MAP:
		rev["#" + P[k].to_html(false).to_upper()] = SHADOW_MAP[k]
	for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
		for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
			var dx := (x + 0.5 - cx) / rx
			var dy := (y + 0.5 - cy) / ry
			if dx * dx + dy * dy <= 1.0 and x >= 0 and y >= 0 and x < dst.get_width() and y < dst.get_height():
				var h := "#" + dst.get_pixel(x, y).to_html(false).to_upper()
				if rev.has(h):
					dst.set_pixel(x, y, P[rev[h]])

# ------------------------------------------------------------ cena
const COLS := 41
const ROWS := 23
const GX := -8   # origem da grade na tela (jogador em tile alinhado, camera centrada nele)
const GY := -4

func rect_map(map: Array, ch: String, c0: int, r0: int, c1: int, r1: int) -> void:
	for r in range(r0, r1 + 1):
		for c in range(c0, c1 + 1):
			if r >= 0 and r < ROWS and c >= 0 and c < COLS:
				map[r][c] = ch

func build_map() -> Array:
	var map := []
	for r in ROWS:
		var row := []
		row.resize(COLS)
		row.fill(".")
		map.append(row)
	for a in [[0, 0, 8, 2], [0, 3, 5, 6], [0, 7, 2, 9], [9, 0, 11, 1], [33, 0, 40, 3], [36, 4, 40, 10], [38, 11, 40, 13],
			[0, 18, 6, 22], [7, 20, 10, 22], [28, 18, 40, 22], [25, 20, 27, 22], [31, 16, 33, 17], [14, 0, 16, 0]]:
		rect_map(map, "f", a[0], a[1], a[2], a[3])
	rect_map(map, "p", 0, 14, 21, 15)
	rect_map(map, "p", 20, 9, 21, 15)
	rect_map(map, "p", 20, 9, 26, 10)
	rect_map(map, "p", 25, 7, 26, 10)
	# base: varanda/fundacao de pedra sob a casa e laje aberta (obra) a direita
	rect_map(map, "s", 23, 6, 31, 6)
	rect_map(map, "s", 30, 5, 31, 5)
	return map

func is_t(map: Array, ch: String, c: int, r: int) -> bool:
	if c < 0 or r < 0 or c >= COLS or r >= ROWS:
		return true
	return map[r][c] == ch

func open_mask(map: Array, ch: String, c: int, r: int) -> int:
	var o := 0
	if not is_t(map, ch, c, r - 1): o |= 1
	if not is_t(map, ch, c + 1, r): o |= 2
	if not is_t(map, ch, c, r + 1): o |= 4
	if not is_t(map, ch, c - 1, r): o |= 8
	return o

func hsh(c: int, r: int) -> int:
	return int(abs(sin(c * 12.9898 + r * 78.233) * 43758.5453)) % 100

func grass_variant(c: int, r: int) -> int:
	var h := hsh(c, r)
	return 0 if h < 38 else (1 if h < 62 else (2 if h < 82 else 3))

func scene() -> Image:
	var map := build_map()
	var s := img(640, 360)
	var fol_in := foliage_inner()
	var dirt_in := dirt()
	var objs := []   # [y_base, Image, x, y, sombra|null, flip]
	var occ := {}
	var occupy := func(c0: int, r0: int, c1: int, r1: int) -> void:
		for rr in range(r0, r1 + 1):
			for cc in range(c0, c1 + 1):
				occ["%d,%d" % [cc, rr]] = true
	for r in ROWS:
		for c in COLS:
			blit(s, tiles["grass%d" % grass_variant(c, r)], GX + c * T, GY + r * T)
	for r in ROWS:
		for c in COLS:
			var x := GX + c * T
			var y := GY + r * T
			var ch: String = map[r][c]
			if ch == "p":
				blit(s, autotile(dirt_in, open_mask(map, "p", c, r), PROF_PATH_A if hsh(c, r) < 50 else PROF_PATH_B, "d1", 4), x, y)
			elif ch == "s":
				blit(s, tiles["found"], x, y)
	for r in ROWS:
		for c in COLS:
			if map[r][c] == "f":
				blit(s, autotile(fol_in, open_mask(map, "f", c, r), PROF_FOL, "j0", 5), GX + c * T, GY + r * T)
	# casa: telhado (2 tiles), frente com janela/porta, base de pedra
	var kinds := ["plain", "window", "door", "window", "plain"]
	for k in 5:
		var c := 23 + k
		var side := -1 if k == 0 else (1 if k == 4 else 0)
		objs.append([GY + 4 * T, tiles["roof_0_%d" % side], GX + c * T, GY + 3 * T, null, false])
		objs.append([GY + 5 * T, tiles["roof_1_%d" % side], GX + c * T, GY + 4 * T, null, false])
		objs.append([GY + 6 * T, tiles["hut_" + kinds[k]], GX + c * T, GY + 5 * T, null, false])
	for c in [28, 29]:
		objs.append([GY + 6 * T, tiles["wall"], GX + c * T, GY + 5 * T, null, false])
	occupy.call(22, 3, 32, 7)
	for t in [[5, 12, 0], [9, 7, 1], [13, 3, 0], [18, 4, 2], [34, 12, 1], [31, 13, 2], [4, 6, 2], [16, 17, 0], [26, 16, 1]]:
		var bx: int = GX + t[0] * T - 8
		var by: int = GY + (t[1] + 1) * T - 40
		objs.append([GY + (t[1] + 1) * T, spr["tree%d" % t[2]], bx, by, [bx + 17, GY + (t[1] + 1) * T - 2, 10, 3], false])
		occupy.call(t[0] - 1, t[1] - 1, t[0] + 1, t[1])
	for b in [[17, 12, true], [23, 16, false], [28, 12, true], [8, 10, false], [12, 15, true], [30, 15, false]]:
		var bx2: int = GX + b[0] * T
		var by2: int = GY + b[1] * T
		objs.append([by2 + T, spr["bush_b" if b[2] else "bush"], bx2, by2, [bx2 + 9, by2 + 14, 6, 2], false])
		occupy.call(b[0], b[1], b[0], b[1])
	var cx: int = GX + 30 * T
	var cy: int = GY + 5 * T
	objs.append([cy + T, spr["chest"], cx, cy, [cx + 9, cy + 14, 6, 2], false])
	# personagens (de frente, 3/4)
	var px: int = GX + 20 * T
	var py: int = GY + 11 * T
	objs.append([py + T, spr["player_down"], px, py, [px + 9, py + 14, 5, 2], false])
	var dx: int = GX + 22 * T
	var dy: int = GY + 12 * T
	objs.append([dy + T, spr["small_down"], dx, dy, [dx + 8, dy + 14, 5, 2], false])
	var bx3: int = GX + 13 * T
	var by3: int = GY + 8 * T
	objs.append([by3 + 2 * T, spr["big_sleep"], bx3, by3, [bx3 + 17, by3 + 29, 13, 3], false])
	var kx: int = GX + 33 * T
	var ky: int = GY + 8 * T
	objs.append([ky + 2 * T, spr["carn"], kx, ky, [kx + 15, ky + 30, 11, 3], true])
	occupy.call(19, 10, 23, 13)
	occupy.call(13, 6, 16, 9)
	occupy.call(32, 7, 35, 9)
	# detalhes pequenos (pedras, flores, samambaias, cogumelos) em grama livre
	var decor := ["d_rock", "d_fl0", "d_fl1", "d_fern", "d_shroom", "d_fl0", "d_fern"]
	var off := {"d_rock": [3, 7], "d_fl0": [2, 5], "d_fl1": [2, 5], "d_fern": [0, 1], "d_shroom": [3, 7]}
	for r in ROWS:
		for c in COLS:
			if map[r][c] != "." or occ.has("%d,%d" % [c, r]):
				continue
			if hsh(c * 3 + 7, r * 5 + 1) >= 22:
				continue
			var kind: String = decor[hsh(c + 11, r + 3) % decor.size()]
			var ox: int = GX + c * T + off[kind][0] + hsh(c, r + 9) % 3
			var oy: int = GY + r * T + off[kind][1]
			objs.append([GY + (r + 1) * T - 1, spr[kind], ox, oy, null, false])
	objs.sort_custom(func(a, b): return a[0] < b[0])
	for o in objs:
		if o[4] != null:
			shadow(s, o[4][0] + 1.5, o[4][1], o[4][2], o[4][3])
		var im: Image = o[1]
		if o[5]:
			im = im.duplicate()
			im.flip_x()
		blit(s, im, o[2], o[3])
	bars_dino(s, bx3 - 4, by3 - 10, 0.72, 0.35)
	blit(s, spr["zzz"], bx3 + 32, by3 + 13)
	blit(s, spr["zzz_small"], bx3 + 37, by3 + 7)
	hud(s)
	return s

## Painel de madeira com papel: moldura 2 px (luz de cima-esquerda), nuvem de papel e pregos.
func paper_panel(dst: Image, x: int, y: int, w: int, h: int) -> void:
	rct(dst, x, y, w, h, "ink")
	rct(dst, x + 1, y + 1, w - 2, h - 2, "w2")
	rct(dst, x + 1, y + 1, w - 2, 1, "w3"); rct(dst, x + 1, y + 1, 1, h - 2, "w3")
	rct(dst, x + 1, y + h - 2, w - 2, 1, "w1"); rct(dst, x + w - 2, y + 1, 1, h - 2, "w1")
	rct(dst, x + 3, y + 3, w - 6, h - 6, "cream")
	rct(dst, x + 3, y + 3, w - 6, 1, "d3"); rct(dst, x + 3, y + 3, 1, h - 6, "d3")
	for p in [[x + 2, y + 2], [x + w - 3, y + 2], [x + 2, y + h - 3], [x + w - 3, y + h - 3]]:
		put(dst, p[0], p[1], "w0")

func bar(dst: Image, x: int, y: int, w: int, pct: float, hi: String, base: String, sh: String) -> void:
	rct(dst, x - 1, y - 1, w + 2, 6, "ink")
	rct(dst, x, y, w, 4, "d3")
	var f := int(round(w * pct))
	if f > 0:
		rct(dst, x, y, f, 1, hi); rct(dst, x, y + 1, f, 2, base); rct(dst, x, y + 3, f, 1, sh)

func bars_dino(dst: Image, x: int, y: int, torpor: float, tame: float) -> void:
	paper_panel(dst, x, y, 40, 26)
	blit(dst, spr["zzz"], x + 5, y + 4)
	bar(dst, x + 17, y + 7, 17, torpor, "pu2", "pu1", "pu0")
	blit(dst, spr["heart"], x + 5, y + 13)
	bar(dst, x + 17, y + 16, 17, tame, "pk2", "pk1", "pk0")

func hud(dst: Image) -> void:
	paper_panel(dst, 3, 3, 84, 44)
	var rows := [["heart", 0.8, "hr2", "hr1", "hr0"], ["bolt", 0.6, "fy", "fy", "fyd"], ["drum", 0.45, "o3", "o2", "o1"]]
	for k in rows.size():
		var r: Array = rows[k]
		var y := 7 + k * 12
		blit(dst, spr[r[0]], 8, y - 1)
		bar(dst, 21, y + 2, 56, r[1], r[2], r[3], r[4])

# ------------------------------------------------------------ folha de sprites 8x
func grass_strip(s: Image, y: int, rows: int, W: int) -> void:
	for ty in rows:
		for tx in range(0, W / T + 1):
			blit(s, tiles["grass%d" % grass_variant(tx + 30, ty + 30)], tx * T, y + ty * T)

func sheet() -> Image:
	var W := 240
	var H := 236
	var s := img(W, H)
	rct(s, 0, 0, W, H, "cream")
	var keys := HEX.keys()
	for k in keys.size():
		rct(s, 4 + (k % 24) * 7, 4 + (k / 24) * 7, 6, 6, keys[k])
	# faixa 1: jogador e filhote, 3 direcoes + espelho (esq.) sobre grama
	grass_strip(s, 28, 2, W)
	var xs := 4
	for d in ["down", "up", "side"]:
		blit(s, spr["player_" + d], xs, 36); xs += 20
	var pl: Image = (spr["player_side"] as Image).duplicate(); pl.flip_x(); blit(s, pl, xs, 36)
	xs = 120
	for d in ["down", "up", "side"]:
		blit(s, spr["small_" + d], xs, 36); xs += 20
	var sm: Image = (spr["small_side"] as Image).duplicate(); sm.flip_x(); blit(s, sm, xs, 36)
	# faixa 2: herbivoro adulto (frente, costas, lado, dormindo), carnivoro adulto, arvores
	grass_strip(s, 64, 3, W)
	blit(s, spr["big_down"], 4, 68)
	blit(s, spr["big_up"], 40, 68)
	blit(s, spr["big_side"], 76, 68)
	blit(s, spr["big_sleep"], 112, 68)
	blit(s, spr["carn"], 148, 68)
	blit(s, spr["tree2"], 190, 62)
	# tiles
	var l1 := [tiles["grass0"], tiles["grass1"], tiles["grass2"], tiles["grass3"], tiles["dirt"], tiles["path_n"], tiles["path_ne"], tiles["foliage"], tiles["fol_n"], tiles["found"]]
	for k in l1.size():
		blit(s, l1[k], 4 + k * 19, 118)
	var l2 := [tiles["wall"], tiles["hut_plain"], tiles["hut_window"], tiles["hut_door"], tiles["roof_0_0"], tiles["roof_1_0"], tiles["roof_0_-1"], tiles["roof_1_1"], spr["chest"], spr["bush"], spr["bush_b"]]
	for k in l2.size():
		blit(s, l2[k], 4 + k * 19, 138)
	var l3 := [spr["berry"], spr["meat"], spr["egg"], spr["mushroom"], spr["heart"], spr["bolt"], spr["zzz"], spr["drum"], spr["d_fern"], spr["d_rock"], spr["d_fl0"], spr["d_fl1"], spr["d_shroom"]]
	for k in l3.size():
		blit(s, l3[k], 4 + k * 19, 158)
	# teste de repeticao: grama 6x3, folhagem 3x3, caminho em curva
	for r in 3:
		for c in 6:
			blit(s, tiles["grass%d" % grass_variant(c + 40, r + 40)], 4 + c * T, 182 + r * T)
	var fi := foliage_inner()
	for r in 3:
		for c in 3:
			var o := 0
			if r == 0: o |= 1
			if c == 2: o |= 2
			if r == 2: o |= 4
			if c == 0: o |= 8
			blit(s, autotile(fi, o, PROF_FOL, "j0", 5), 108 + c * T, 182 + r * T)
	var dn := dirt()
	var layout := ["xx.", ".xx", ".xx"]
	var nb := func(cc: int, rr: int) -> bool:
		return cc >= 0 and rr >= 0 and cc < 3 and rr < 3 and layout[rr][cc] == "x"
	for r in 3:
		for c in 3:
			blit(s, tiles["grass0"], 164 + c * T, 182 + r * T)
			if layout[r][c] != "x":
				continue
			var o2 := 0
			if not nb.call(c, r - 1): o2 |= 1
			if not nb.call(c + 1, r): o2 |= 2
			if not nb.call(c, r + 1): o2 |= 4
			if not nb.call(c - 1, r): o2 |= 8
			blit(s, autotile(dn, o2, PROF_PATH_A if (r + c) % 2 == 0 else PROF_PATH_B, "d1", 4), 164 + c * T, 182 + r * T)
	return s

func check_palette(i: Image, nome: String) -> void:
	var ok := {}
	for k in P:
		ok["#" + P[k].to_html(false).to_upper()] = true
	var bad := {}
	for y in i.get_height():
		for x in i.get_width():
			var c := i.get_pixel(x, y)
			if c.a < 0.5:
				continue
			var h := "#" + c.to_html(false).to_upper()
			if not ok.has(h):
				bad[h] = bad.get(h, 0) + 1
	print("paleta ", nome, ": cores fora = ", bad.size(), " ", bad)

func _init() -> void:
	for k in HEX:
		P[k] = Color.html(HEX[k])
	for v in 4:
		tiles["grass%d" % v] = grass(v)
	tiles["dirt"] = dirt()
	tiles["path_n"] = autotile(dirt(), 1, PROF_PATH_A, "d1", 4)
	tiles["path_ne"] = autotile(dirt(), 3, PROF_PATH_B, "d1", 4)
	tiles["foliage"] = foliage_inner()
	tiles["fol_n"] = autotile(foliage_inner(), 1, PROF_FOL, "j0", 5)
	tiles["found"] = foundation()
	for rw in 2:
		for sd in [-1, 0, 1]:
			tiles["roof_%d_%d" % [rw, sd]] = roof(rw, sd)
	for kd in ["plain", "window", "door"]:
		tiles["hut_" + kd] = hut_wall(kd)
	tiles["wall"] = wall()
	for d in ["down", "up", "side"]:
		spr["player_" + d] = player(d)
		spr["small_" + d] = small_dino(d)
	spr["big_down"] = big_dino("down")
	spr["big_up"] = big_dino("up")
	spr["big_side"] = big_dino("side")
	spr["big_sleep"] = big_dino("side", true)
	spr["tree0"] = tree(0)
	spr["tree1"] = tree(1)
	spr["tree2"] = cycad()
	spr["carn"] = carn_dino()
	spr["d_fern"] = fern()
	spr["d_rock"] = rock()
	spr["d_fl0"] = flowers(0)
	spr["d_fl1"] = flowers(1)
	spr["d_shroom"] = shrooms()
	spr["bush"] = bush(false)
	spr["bush_b"] = bush(true)
	spr["chest"] = chest()
	spr["heart"] = icon_heart()
	spr["bolt"] = icon_bolt()
	spr["zzz"] = icon_zzz()
	var zs := img(5, 5)
	zs.fill(Color(0, 0, 0, 0))
	spr["zzz_small"] = outline(ascii_sprite(["WWW", ".W.", "WWW"], {"W": "pu2"}, 5, 5, 1, 1))
	spr["drum"] = icon_drum()
	spr["berry"] = food_berry()
	spr["meat"] = food_meat()
	spr["egg"] = food_egg()
	spr["mushroom"] = food_mushroom()

	var sc := scene()
	sc.save_png(OUT + "mock-vale.png")
	var sc2 := sc.duplicate() as Image
	sc2.resize(1280, 720, Image.INTERPOLATE_NEAREST)
	sc2.save_png(OUT + "mock-vale-2x.png")
	var sh := sheet()
	check_palette(sc, "cena")
	check_palette(sh, "folha")
	sh.resize(sh.get_width() * 8, sh.get_height() * 8, Image.INTERPOLATE_NEAREST)
	sh.save_png(OUT + "folha-sprites-8x.png")
	print("ok ", HEX.size(), " cores")
	quit()
