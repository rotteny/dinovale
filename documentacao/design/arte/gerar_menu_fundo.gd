## Gerador do FUNDO DO MENU (ilha/vale ensolarado) em 5 camadas + composicao + logo. Arte propria, CC BY 4.0, sem IA.
## Da raiz do repositorio:
##   godot --headless --script documentacao/design/arte/gerar_menu_fundo.gd -- <pasta de saida>
## Saida: menu_fundo.png (320x180, composicao), menu_camada_{ceu,longe,meio,perto,frente}.png (352x212 = 320x180 + margem de
## 16 px em cada lado, para o parallax deslocar sem mostrar borda; a camada comeca em (-16,-16) da tela), menu_logo.png, menu_fundo.json.
## Le (so le) os sprites de dinos e cenario de game/assets/sprites; NAO grava em game/assets. Cores: so a paleta do pacote
## (conferido por arte_lib.save_png_checked). Luz de cima-esquerda. Ruido com semente fixa: saida identica a cada execucao.
extends SceneTree
const Lib = preload("arte_lib.gd")
const Fonte = preload("menu_fonte.gd")
var L = Lib.new()
var F = Fonte.new()
var rng := RandomNumberGenerator.new()

const W := 320
const H := 180
const M := 16
const LW := W + 2 * M
const LH := H + 2 * M
const SPR := "game/assets/sprites/"
const HORIZON := 98
const BAYER := [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

# ---------------------------------------------------------------- base (coordenadas de TELA; a camada tem margem)
func layer() -> Image:
	return L.img(LW, LH)

func px(i: Image, x: int, y: int, c: String) -> void:
	L.put(i, x + M, y + M, c)

func has(i: Image, x: int, y: int) -> bool:
	return L.solid(i, x + M, y + M)

func bay(x: int, y: int) -> int:
	return BAYER[(y & 3) * 4 + (x & 3)]

## Faixa de transicao ordenada de `a` (em cima) para `b` (embaixo) em `rows` linhas.
func dither_band(i: Image, y0: int, rows: int, a: String, b: String) -> void:
	for r in rows:
		var thr := (float(r) + 0.5) / rows * 16.0
		for x in range(-M, W + M):
			px(i, x, y0 + r, b if bay(x, y0 + r) < thr else a)

func interp(pts: Array, x: int) -> int:
	for k in range(pts.size() - 1):
		var a: Array = pts[k]
		var b: Array = pts[k + 1]
		if x >= a[0] and x <= b[0]:
			return int(round(lerpf(a[1], b[1], float(x - a[0]) / float(b[0] - a[0]))))
	return int((pts[0] as Array)[1] if x < (pts[0] as Array)[0] else (pts[pts.size() - 1] as Array)[1])

## Silhueta de relevo ate `bottom`: corpo, 2 px de luz nas faces que sobem para a direita (viradas a esquerda/sol) e
## sombra nas que descem.
func ridge(i: Image, pts: Array, body: String, hi: String, sh: String, bottom: int, edge: int = 2) -> void:
	for x in range(-M, W + M):
		if x < (pts[0] as Array)[0] or x > (pts[pts.size() - 1] as Array)[0]:
			continue
		var t := interp(pts, x)
		var slope := interp(pts, x + 2) - interp(pts, x - 2)  # <0: sobe para a direita (face de luz)
		for y in range(t, bottom):
			var c := body
			if y - t < edge:
				c = hi if slope <= 0 else sh
			px(i, x, y, c)

func disc(i: Image, cx: float, cy: float, r: float, c: String) -> void:
	for y in range(int(cy - r) - 1, int(cy + r) + 2):
		for x in range(int(cx - r) - 1, int(cx + r) + 2):
			if (x + 0.5 - cx) * (x + 0.5 - cx) + (y + 0.5 - cy) * (y + 0.5 - cy) <= r * r:
				px(i, x, y, c)

## Esfera com 4 tons duros (luz cima-esquerda). rampa: do escuro ao claro.
func ball(i: Image, cx: float, cy: float, rx: float, ry: float, ramp: Array, over: bool = true) -> void:
	for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
		for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
			var dx := (x + 0.5 - cx) / rx
			var dy := (y + 0.5 - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				var lit := 0.5 + 0.5 * (-0.55 * dx - 0.7 * dy) / 1.0 - 0.18 * (dx * dx + dy * dy)
				var k := 0 if lit < 0.28 else (1 if lit < 0.52 else (2 if lit < 0.78 else 3))
				px(i, x, y, ramp[mini(k, ramp.size() - 1)])

# ---------------------------------------------------------------- CEU
func cloud(i: Image, cx: int, cy: int, w: int) -> void:
	var blobs := [[0.0, 0.0, 0.32, 0.5], [-0.28, 0.1, 0.24, 0.36], [0.27, 0.12, 0.26, 0.38], [-0.08, -0.14, 0.2, 0.4], [0.12, -0.1, 0.18, 0.34]]
	var tmp := {}
	for b in blobs:
		var rx: float = b[2] * w
		var ry: float = b[3] * w * 0.55
		var bx: float = cx + b[0] * w
		var by: float = cy + b[1] * w * 0.55
		for y in range(int(by - ry) - 1, int(by + ry) + 2):
			for x in range(int(bx - rx) - 1, int(bx + rx) + 2):
				var dx := (x + 0.5 - bx) / rx
				var dy := (y + 0.5 - by) / ry
				if dx * dx + dy * dy <= 1.0:
					tmp[Vector2i(x, y)] = true
	var base_y := cy + int(w * 0.12)
	for p in tmp:
		var c := "foam"
		if not tmp.has(p + Vector2i(0, -1)) or (not tmp.has(p + Vector2i(-1, -1)) and not tmp.has(p + Vector2i(-1, 0))):
			c = "white"
		elif p.y >= base_y + int(w * 0.06):
			c = "z_dk"
		elif p.y >= base_y:
			c = "foam2"
		px(i, p.x, p.y, c)

func gull(i: Image, x: int, y: int) -> void:
	for p in [[0, 0], [1, 1], [2, 2], [3, 1], [4, 0], [-1, -1], [5, -1], [6, 0], [7, 1], [8, 2], [9, 1], [10, 0], [11, -1]]:
		if p[0] <= 4 or p[0] >= 5:
			px(i, x + p[0], y + p[1], "K")
	for p in [[3, 2], [4, 2], [5, 2], [4, 3]]:
		px(i, x + p[0], y + p[1], "K")

func make_sky() -> Image:
	var s := layer()
	L.rect(s, 0, 0, LW, LH, "shal")
	L.rect(s, 0, M + 44, LW, LH, "foam2")
	dither_band(s, 40, 5, "shal", "foam2")
	L.rect(s, 0, M + 78, LW, LH, "foam")
	dither_band(s, 74, 5, "foam2", "foam")
	L.rect(s, 0, M + 92, LW, LH, "sand_hi")
	dither_band(s, 90, 5, "foam", "sand_hi")
	# sol (lado esquerdo, abaixo da area do titulo) com halo e raios curtos
	var sx := 52.0
	var sy := 66.0
	for y in range(int(sy) - 24, int(sy) + 25):
		for x in range(int(sx) - 24, int(sx) + 25):
			var d := sqrt((x + 0.5 - sx) * (x + 0.5 - sx) + (y + 0.5 - sy) * (y + 0.5 - sy))
			if d > 10.0 and d < 22.0 and bay(x, y) < (22.0 - d) / 12.0 * 9.0:
				px(s, x, y, "white")
	for k in 12:
		var a := TAU * k / 12.0
		var r0 := 14.0 if k % 2 == 0 else 14.0
		var r1 := 19.0 if k % 2 == 0 else 16.0
		for r in range(int(r0), int(r1) + 1):
			px(s, int(round(sx + cos(a) * r)), int(round(sy + sin(a) * r)), "yellow")
	disc(s, sx, sy, 10.0, "ring")
	disc(s, sx - 0.6, sy - 0.6, 9.2, "yellow")
	ball(s, sx - 1.0, sy - 1.0, 6.5, 6.5, ["yellow", "yellow", "white", "white"])
	cloud(s, 30, 24, 44)
	cloud(s, 296, 20, 50)
	cloud(s, 92, 60, 28)
	cloud(s, 232, 58, 30)
	gull(s, 20, 46)
	gull(s, 280, 44)
	gull(s, 292, 54)
	return s

# ---------------------------------------------------------------- LONGE: mar, serras e vulcao
const BRACHIO := [
	"..............####....",
	".............######...",
	".............#######..",
	".............####.....",
	"............###......",
	"............###......",
	"............###......",
	"...#########.###.....",
	"..###########.#......",
	".############........",
	"##############.......",
	"#.##...##..##........",
	"#.##...##..##........",
]

func silhouette(i: Image, art: Array, x: int, y: int, c: String, flip: bool = false) -> void:
	for r in art.size():
		var row: String = art[r]
		for k in row.length():
			if row[k] == "#":
				px(i, x + (row.length() - 1 - k if flip else k), y + r, c)

func make_far() -> Image:
	var s := layer()
	# mar (so aparece onde a serra desce; o miolo central fica aberto para o mar)
	var bands := [["shal_md", 4], ["shal", 5], ["deep_hi", 5], ["deep", 20]]
	var y := HORIZON
	for b in bands:
		for r in b[1]:
			for x in range(-M, W + M):
				px(s, x, y + r, b[0])
		y += b[1]
	for k in 30:  # brilho do sol no mar, coluna sob o sol
		px(s, 44 + rng.randi_range(0, 18), HORIZON + rng.randi_range(0, 12), "white")
	for k in 22:  # espuma/ondas em tracos curtos
		var wx := rng.randi_range(-8, 330)
		var wy := HORIZON + 3 + rng.randi_range(0, 11)
		for q in rng.randi_range(2, 4):
			px(s, wx + q, wy, "foam" if wy < HORIZON + 8 else "shal")
	# ilhotas distantes
	ridge(s, [[-20, 99], [128, 99], [134, 95], [146, 93], [158, 95], [166, 99], [400, 99]], "o_hi", "shal", "o_md", HORIZON + 2, 1)
	# serra distante (bruma)
	var far_pts := [[-20, 90], [6, 82], [26, 88], [60, 77], [84, 86], [112, 96], [130, 99], [206, 99], [222, 90], [244, 98], [330, 98]]
	ridge(s, far_pts, "z_md", "foam", "z_dk", HORIZON + 2, 1)
	# serra media: azul-ardosia
	var mid_pts := [[-20, 96], [10, 90], [34, 96], [70, 88], [96, 98], [110, 104], [214, 104], [232, 96], [300, 92], [336, 98]]
	ridge(s, mid_pts, "deep_hi", "shal", "deep_hi", 116, 2)
	# vulcao (pedra quente, cratera laranja e fumaca)
	var vol := [[206, 106], [232, 90], [244, 74], [250, 68], [268, 68], [274, 74], [288, 90], [310, 104], [336, 106]]
	ridge(s, vol, "s_md", "s_hi", "s_dk", 118, 3)
	for x in range(251, 268):
		px(s, x, 68, "orange")
		px(s, x, 69, "f_red")
	for x in range(252, 266):
		px(s, x, 67, "ring")
	for p in [[253, 70], [253, 71], [254, 72], [254, 73], [255, 75], [255, 76], [256, 78]]:  # lava na face
		px(s, p[0], p[1], "orange" if p[1] % 2 == 0 else "f_red")
	for p in [[270, 74], [271, 75], [272, 77]]:
		px(s, p[0], p[1], "s_xx")
	# fumaca em bolas (luz de cima-esquerda)
	ball(s, 258, 60, 6, 5, ["s_hi", "foam2", "foam", "white"])
	ball(s, 266, 52, 7, 5, ["s_hi", "foam2", "foam", "white"])
	ball(s, 275, 44, 6, 4, ["foam2", "foam", "white", "white"])
	ball(s, 285, 38, 4, 3, ["foam2", "foam", "white", "white"])
	# braquiossauro distante na serra (silhueta ardosia)
	silhouette(s, BRACHIO, 14, 75, "deep_dk")
	silhouette(s, BRACHIO, 22, 77, "deep_dk")
	return s

# ---------------------------------------------------------------- MEIO: colinas e arvores
func round_tree(i: Image, cx: int, base: int, r: int) -> void:
	L.rect(i, cx - 1 + M, base - 3 + M, 2, 4, "w_dk")
	ball(i, cx, base - r - 1, r, r * 0.92, ["g_dk", "g_md", "g_hi", "g_lt"])
	ball(i, cx - r * 0.55, base - r * 0.6, r * 0.55, r * 0.5, ["g_dk", "g_md", "g_hi", "g_lt"])
	ball(i, cx + r * 0.6, base - r * 0.55, r * 0.5, r * 0.45, ["g_dk", "g_md", "g_md", "g_hi"])

func small_pine(i: Image, cx: int, base: int, h: int) -> void:
	for r in h:
		var half := 1 + (r * 3) / (h * 2) * 2 + r / 3
		half = mini(half, h / 3 + 2)
		for x in range(-half, half + 1):
			var c := "g_md"
			if x < -half / 3:
				c = "g_hi"
			elif x > half / 3:
				c = "g_dk"
			px(i, cx + x, base - h + r, c)
	L.rect(i, cx - 1 + M, base + M, 2, 2, "w_dk")

func make_mid() -> Image:
	var s := layer()
	var hill_a := [[-20, 116], [20, 108], [60, 113], [104, 119], [150, 121], [200, 118], [244, 111], [290, 106], [336, 112]]
	ridge(s, hill_a, "g_dk", "g_md", "g_dk", 190, 2)
	for tx in [10, 26, 34, 52, 232, 252, 276, 300, 314]:
		small_pine(s, tx, interp(hill_a, tx) + 3, 11 + (tx % 5))
	silhouette(s, BRACHIO, 204, interp(hill_a, 216) - 11, "g_dk")
	var hill_b := [[-20, 128], [30, 122], [76, 127], [130, 133], [190, 133], [236, 126], [284, 121], [336, 126]]
	ridge(s, hill_b, "g_md", "g_hi", "g_md", 190, 2)
	for t in [[16, 7], [44, 6], [104, 5], [170, 5], [222, 6], [250, 7], [304, 6]]:
		round_tree(s, t[0], interp(hill_b, t[0]) + 4, t[1])
	return s

# ---------------------------------------------------------------- PERTO: campo, props e dinos
func spr(i: Image, path: String, src: Rect2i, x: int, y: int, flip: bool = false) -> void:
	var sh := Image.load_from_file(SPR + path)
	assert(sh != null, path)
	var f := sh.get_region(src)
	if flip:
		f.flip_x()
	i.blend_rect(f, Rect2i(Vector2i.ZERO, f.get_size()), Vector2i(x + M, y + M))

func shadow(i: Image, cx: int, y: int, w: int) -> void:
	for dy in 3:
		var half := w / 2 - (1 if dy != 1 else 0) * 2
		for x in range(cx - half, cx + half + 1):
			if has(i, x, y + dy):
				px(i, x, y + dy, "g_md")

## Dino (frame S, linha `row` 0 baixo/1 cima/2 esquerda/3 direita, coluna `col`), pes em feet_y.
func dino(i: Image, file: String, S: int, row: int, col: int, x: int, feet_y: int) -> void:
	shadow(i, x + S / 2, feet_y - 1, int(S * 0.72))
	spr(i, "dinos/%s.png" % file, Rect2i(col * S, row * S, S, S), x, feet_y - (S - 2))

func flower(i: Image, x: int, y: int) -> void:
	var cols := ["f_red", "yellow", "pink", "white", "bloom", "orange"]
	var c: String = cols[rng.randi_range(0, cols.size() - 1)]
	if rng.randf() < 0.45:
		px(i, x, y, c)
		px(i, x - 1, y, c)
		px(i, x + 1, y, c)
		px(i, x, y - 1, c)
		px(i, x, y + 1, c)
		px(i, x, y, "yellow" if c != "yellow" else "orange")
	else:
		px(i, x, y, c)
		px(i, x, y + 1, "g_dk")

func tuft(i: Image, x: int, y: int) -> void:
	px(i, x, y, "g_dk")
	px(i, x - 1, y - 1, "g_dk")
	px(i, x + 1, y - 1, "g_md")
	px(i, x, y - 2, "g_md")

func bush(i: Image, x: int, y: int, berries: bool) -> void:  # y = base
	shadow(i, x + 8, y - 1, 14)
	spr(i, "recursos/bush_food.png" if berries else "recursos/bush_sleep.png", Rect2i(0, 0, 16, 16), x, y - 15)

func make_near() -> Image:
	var s := layer()
	var meadow := [[-20, 136], [50, 133], [110, 138], [170, 140], [230, 136], [290, 132], [340, 134]]
	ridge(s, meadow, "g_hi", "g_lt", "g_lt", 200, 3)
	# gradiente do campo: claro no horizonte, mais escuro e verde embaixo (faixas duras + tramas)
	for x in range(-M, W + M):
		var t := interp(meadow, x)
		for y in range(t + 3, H + M):
			var d := y - t
			if d < 14 and bay(x, y) < (14 - d) * 16 / 14 * 0.6:
				px(s, x, y, "g_lt")
			if y > 158 and bay(x, y) < (y - 158) * 16 / 22:
				px(s, x, y, "g_md")
	# trilha de terra? nao: o centro fica limpo para os botoes. Manchas de flores e tufos pelos lados.
	for k in 260:
		var x := rng.randi_range(-M, W + M - 1)
		var y := rng.randi_range(interp(meadow, x) + 5, H + M - 2)
		if x > 100 and x < 220 and y < 176 and rng.randf() < 0.85:
			continue
		if rng.randf() < 0.55:
			tuft(s, x, y)
		else:
			flower(s, x, y)
	# lagoinha pequena a esquerda, embaixo
	# arvores de moldura
	spr(s, "recursos/tree_collect_80.png", Rect2i(0, 0, 48, 80), 4, 60)
	spr(s, "recursos/tree_collect_80.png", Rect2i(0, 0, 48, 80), 272, 56, true)
	# atras (feet menor = mais ao fundo)
	bush(s, 98, 150, true)
	dino(s, "utahraptor", 32, 2, 0, 214, 146)
	bush(s, 238, 150, false)
	dino(s, "parassaurolofo", 32, 3, 0, 76, 154)
	dino(s, "paquicefalo", 32, 3, 0, 46, 170)
	dino(s, "dodo", 16, 3, 0, 90, 172)
	dino(s, "triceratops", 48, 2, 0, 252, 172)
	bush(s, 30, 174, true)
	spr(s, "recursos/rock_stone_32.png", Rect2i(0, 0, 32, 32), 2, 130 + 20)
	# borboletas
	for b in [[96, 118], [232, 124], [60, 110]]:
		px(s, b[0], b[1], "yellow")
		px(s, b[0] + 1, b[1] - 1, "pink")
		px(s, b[0] - 1, b[1] - 1, "pink")
	return s

# ---------------------------------------------------------------- FRENTE: folhagem (frondes) nos cantos
func frond(i: Image, ox: float, oy: float, ang_deg: float, length: float, width: float, droop: float) -> void:
	var a := deg_to_rad(ang_deg)
	var d := Vector2(cos(a), sin(a))
	var n := Vector2(-d.y, d.x)
	if n.y > 0.0:
		n = -n  # n aponta para "cima" (luz)
	var steps := int(length * 3)
	for k in steps + 1:
		var t := float(k) / steps
		var pos := Vector2(ox, oy) + d * length * t + Vector2(0, droop * t * t * length)
		var hw := width * pow(sin(PI * clampf(t * 0.92 + 0.04, 0.0, 1.0)), 0.7)
		var side := 0.0
		while side <= hw + 0.01:
			for sg in [1.0, -1.0]:
				var s: float = side * sg
				var q: Vector2 = pos + n * s
				var c := "g_md"
				if s > hw * 0.35:
					c = "g_hi" if t < 0.75 else "g_md"
				elif s < -hw * 0.45:
					c = "g_dk"
				if absf(s) < 0.45:
					c = "g_dk" if t > 0.1 else "g_md"
				var xx := int(floor(q.x))
				var yy := int(floor(q.y))
				if xx >= -M and yy >= -M and xx < W + M and yy < H + M:
					px(i, xx, yy, c)
			side += 0.4

func outline(i: Image, c: String) -> void:
	var mark := []
	for y in LH:
		for x in LW:
			if not L.solid(i, x, y):
				for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					if L.solid(i, x + o.x, y + o.y):
						mark.append(Vector2i(x, y))
						break
	for p in mark:
		L.put(i, p.x, p.y, c)

func make_front() -> Image:
	var s := layer()
	# canto inferior esquerdo (para cima e para a direita) e direito (espelhado): baixos, para nao cobrir os dinos
	for f in [[-6, 188, -84, 46, 8, 0.2], [-6, 188, -66, 48, 8, 0.2], [-6, 188, -48, 44, 7, 0.2], [-6, 188, -30, 38, 7, 0.25]]:
		frond(s, f[0], f[1], f[2], f[3], f[4], f[5])
	for f in [[326, 188, -96, 46, 8, 0.2], [326, 188, -114, 48, 8, 0.2], [326, 188, -132, 44, 7, 0.2], [326, 188, -150, 38, 7, 0.25]]:
		frond(s, f[0], f[1], f[2], f[3], f[4], f[5])
	# cantos superiores: folhas pendentes
	for f in [[-8, -6, 18, 52, 7, 0.2], [-8, -6, 42, 48, 7, 0.25], [-8, -6, 66, 40, 6, 0.2], [4, -8, 84, 30, 5, 0.2]]:
		frond(s, f[0], f[1], f[2], f[3], f[4], f[5])
	for f in [[328, -6, 162, 52, 7, 0.2], [328, -6, 138, 48, 7, 0.25], [328, -6, 114, 40, 6, 0.2], [316, -8, 96, 30, 5, 0.2]]:
		frond(s, f[0], f[1], f[2], f[3], f[4], f[5])
	outline(s, "K")
	return s

# ---------------------------------------------------------------- LOGO
func make_logo() -> Image:
	var sc := 3
	var m1 = F.mask("DINO", sc, 3)
	var m2 = F.mask("VALE", sc, 3)
	var gap := 12
	var tw: int = m1.get_width() + gap + m2.get_width()
	var th: int = 7 * sc
	var pad := 4
	var out := L.img(tw + pad * 2, th + pad * 2 + 3)
	var mask := Image.create(tw, th, false, Image.FORMAT_RGBA8)
	mask.fill(Color(0, 0, 0, 0))
	mask.blit_rect(m1, Rect2i(Vector2i.ZERO, m1.get_size()), Vector2i.ZERO)
	mask.blit_rect(m2, Rect2i(Vector2i.ZERO, m2.get_size()), Vector2i(m1.get_width() + gap, 0))
	var solid := func(x: int, y: int) -> bool: return x >= 0 and y >= 0 and x < tw and y < th and mask.get_pixel(x, y).a > 0.5
	# sombra/extrusao K: 3 linhas para baixo; contorno K de 1 px; depois o miolo em 3 faixas quentes
	for y in range(-1, th + 4):
		for x in range(-1, tw + 1):
			var near := false
			for dy in range(-1, 4):
				for dx in range(-1, 2):
					if solid.call(x + dx, y - dy if dy > 1 else y + dy) and (dy <= 1 or dx == 0):
						near = true
			if near:
				L.put(out, x + pad, y + pad, "K")
	# extrusao em tom madeira escura (abaixo do miolo)
	for y in th:
		for x in tw:
			if solid.call(x, y):
				if not solid.call(x, y + 1) or not solid.call(x, y + 2):
					L.put(out, x + pad, y + pad + 2, "w_dk")
	for y in th:
		for x in tw:
			if solid.call(x, y):
				var c := "orange"
				if y < 6:
					c = "yellow"
				elif y >= 14:
					c = "f_red"
				if not solid.call(x, y - 1):
					c = "cut"
				elif not solid.call(x - 1, y) and y < 14:
					c = "sand_hi"
				L.put(out, x + pad, y + pad, c)
	# folhinhas brotando no "I"
	var ix: int = 4 * 3 + 3 + 3 + 5 * 3 + 3  # inicio do "I" do DINO: depois de D (15+3)
	ix = 18 + 7 + pad
	var leaf := ["..gg....", ".gGGg.gg", "gGGGGgGGg", ".gGGgGGg.", "...gdGg..", "....dd..."]
	for r in leaf.size():
		for k in (leaf[r] as String).length():
			var ch: String = leaf[r][k]
			var c := ""
			if ch == "g":
				c = "g_md"
			elif ch == "G":
				c = "g_hi"
			elif ch == "d":
				c = "g_dk"
			if c != "":
				L.put(out, ix + k - 3, pad - 6 + r + 1, c)
	return out

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	assert(args.size() >= 1, "uso: -- <pasta de saida>")
	var dir: String = args[0]
	rng.seed = 5
	var layers := {"ceu": make_sky(), "longe": make_far(), "meio": make_mid(), "perto": make_near(), "frente": make_front()}
	var comp := L.img(W, H)
	for k in ["ceu", "longe", "meio", "perto", "frente"]:
		var im: Image = layers[k]
		L.save_png_checked(im, dir.path_join("menu_camada_%s.png" % k))
		comp.blend_rect(im, Rect2i(M, M, W, H), Vector2i.ZERO)
	L.save_png_checked(comp, dir.path_join("menu_fundo.png"))
	L.save_png_checked(make_logo(), dir.path_join("menu_logo.png"))
	var info := {
		"tela": [W, H], "camadas": ["ceu", "longe", "meio", "perto", "frente"], "tamanho_camada": [LW, LH], "origem_camada": [-M, -M],
		"parallax_sugerido": {"ceu": 0.1, "longe": 0.2, "meio": 0.4, "perto": 0.7, "frente": 1.0},
		"area_segura_titulo": [56, 8, 208, 48], "area_segura_botoes": [108, 64, 104, 108],
		"observacao": "camada comeca em (-16,-16) da tela; deslocar no maximo 16 px; nearest; sem escala fracionada",
	}
	var f := FileAccess.open(dir.path_join("menu_fundo.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(info, "\t"))
	f.close()
	quit()
