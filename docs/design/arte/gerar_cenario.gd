## Gerador do cenario na escala nova: arvores 48x80, rochas de 32 px, formacoes rochosas.
## Arte propria, CC BY 4.0, sem IA e sem recorte de terceiros. Da raiz do repositorio:
##   godot --headless --script docs/design/arte/gerar_cenario.gd
## Saida: game/assets/sprites/recursos/  tree_collect_80.png (48x80, coletavel), tree_decor_80.png (48x80, decorativa),
##                                        rock_stone_32.png, rock_ore_32.png (32x32) e os *_empty_32.png (esgotado)
##        game/assets/sprites/cenario/    formacao_a.png (64x80), formacao_b.png (96x48), formacao_c.png (64x48).
## Sem construcao humana. Ancora: base do quadro (arvore: tronco em x 18..29 ao pe; colisao 12x8 no pe do tronco).
## Luz de cima-esquerda; contorno #141b1b; so cores da paleta do pacote (conferido ao gravar).
extends SceneTree
const Lib = preload("arte_lib.gd")
var L = Lib.new()
const OREC := "game/assets/sprites/recursos/"
const OUTC := "game/assets/sprites/cenario/"

func _init() -> void:
	L.save_png_checked(tree_collect(), OREC + "tree_collect_80.png")
	L.save_png_checked(tree_decor(), OREC + "tree_decor_80.png")
	L.save_png_checked(rock_stone(), OREC + "rock_stone_32.png")
	L.save_png_checked(rock_stone_empty(), OREC + "rock_stone_empty_32.png")
	L.save_png_checked(rock_ore(), OREC + "rock_ore_32.png")
	L.save_png_checked(rock_ore_empty(), OREC + "rock_ore_empty_32.png")
	L.save_png_checked(formation_a(), OUTC + "formacao_a.png")
	L.save_png_checked(formation_b(), OUTC + "formacao_b.png")
	L.save_png_checked(formation_c(), OUTC + "formacao_c.png")
	quit()

func trunk(i: Image, x0: int, x1: int, y0: int, y1: int, flare_y: int, tones: Array) -> void:
	var tr: Image = L.img(i.get_width(), i.get_height())
	L.m_rect(tr, x0, y0, x1 - x0 + 1, y1 - y0 + 1)
	L.m_rect(tr, x0 - 2, flare_y, x1 - x0 + 5, y1 - flare_y + 1)
	L.paint(i, tr, (x0 + x1) / 2.0 - 1.0, (y0 + y1) / 2.0, (x1 - x0) / 2.0 + 2, (y1 - y0) / 2.0, tones, [-0.45, 0.25, 0.7])

# ---------------------------------------------------------------- arvore coletavel 48x80
## Pinheiro de 4 camadas, verde-amarelado claro, com entalhe de corte claro no tronco.
func tree_collect() -> Image:
	var i: Image = L.img(48, 80)
	trunk(i, 20, 27, 62, 78, 72, ["w_hi", "w_md", "w_dk", "w_dk"])
	# camadas de baixo para cima (a de cima fica na frente)
	var tiers := [[41, 66, 4.0, 22.0], [29, 52, 3.0, 18.0], [17, 40, 2.0, 14.0], [3, 28, 1.0, 10.0]]
	for t in tiers:
		var m: Image = L.img(48, 80)
		var y0: int = t[0]
		var y1: int = t[1]
		for y in range(y0, y1 + 1):
			var f := float(y - y0) / float(y1 - y0)
			var hw: float = lerpf(t[2], t[3], f)
			for x in range(int(floor(24.0 - hw)), int(ceil(24.0 + hw))):
				if abs(x + 0.5 - 24.0) <= hw:
					m.set_pixel(x, y, Color.WHITE)
		for x in 48:
			if L.solid(m, x, y1) and (x / 3) % 2 == 0:
				m.set_pixel(x, y1, Color(0, 0, 0, 0))
		L.paint(i, m, 22.0, float(y0 + y1) / 2.0, 30.0, float(y1 - y0) / 2.0 + 1.0, ["g_lt", "g_ol", "g_hi", "g_md"], [-0.45, 0.15, 0.55])
		for y in range(y0 + 3, y1 + 2):
			for x in 48:
				if L.solid(m, x, y) and not L.solid(m, x, y + 1):
					L.put(i, x, y, "g_md")
	# entalhe de corte no tronco: marca de que e coletavel
	L.pts(i, [[21, 68], [22, 68], [23, 68], [21, 69], [22, 69], [23, 69], [24, 69], [22, 70], [23, 70]], "cut")
	L.pts(i, [[21, 71], [22, 71], [23, 71], [24, 71]], "w_xx")
	# folhas de detalhe
	L.pts(i, [[24, 10], [20, 22], [28, 23], [16, 34], [32, 35], [12, 46], [36, 47], [24, 44], [22, 58], [30, 59], [18, 55]], "g_dk")
	L.pts(i, [[22, 8], [18, 20], [14, 32], [10, 44], [8, 58]], "g_hi")
	L.outline(i)
	return i

# ---------------------------------------------------------------- arvore decorativa 48x80
## Copa larga, redonda e escura (verde-azulado), tronco grosso, flores lilas. Sem entalhe, sem tom claro.
func tree_decor() -> Image:
	var i: Image = L.img(48, 80)
	trunk(i, 19, 28, 50, 78, 70, ["w_md", "w_dk", "w_xx", "w_xx"])
	var lumps := [
		[24.0, 40.0, 22.0, 15.0],
		[12.0, 34.0, 11.0, 14.0], [36.0, 34.0, 11.0, 14.0],
		[24.0, 25.0, 17.0, 16.0],
		[15.0, 17.0, 10.0, 11.0], [33.0, 17.0, 10.0, 11.0],
		[24.0, 11.0, 12.0, 9.0],
	]
	var m: Image = L.img(48, 80)
	for l in lumps:
		L.m_ell(m, l[0], l[1], l[2], l[3])
	L.paint(i, m, 24.0, 30.0, 99.0, 24.0, ["g_md", "g_md", "g_dk", "g_dk"], [0.2, 0.62, 9.0])
	var clumps := [[14, 16, 7], [26, 9, 7], [36, 18, 7], [21, 24, 7], [32, 30, 7], [9, 33, 6], [41, 36, 6], [22, 40, 7], [34, 46, 6], [13, 45, 6], [24, 54, 6], [8, 22, 5]]
	for c in clumps:
		var cm: Image = L.img(48, 80)
		L.m_ell(cm, c[0], c[1], c[2], c[2] * 0.85)
		for y in 80:
			for x in 48:
				if L.solid(cm, x, y) and L.solid(m, x, y):
					var below: bool = not L.solid(cm, x, y + 1)
					var up: bool = not L.solid(cm, x, y - 1)
					var left: bool = not L.solid(cm, x - 1, y)
					if below and (x + y) % 3 != 0:
						L.put(i, x, y, "g_dk")
					elif up and left:
						L.put(i, x, y, "g_hi")
	L.pts(i, [[20, 28], [21, 29], [30, 33], [31, 34], [14, 36], [38, 30], [26, 44], [27, 44], [16, 22], [34, 24]], "g_dk")
	L.pts(i, [[17, 20], [31, 21], [24, 34], [37, 38], [11, 32], [26, 14], [19, 44]], "bloom")
	L.outline(i)
	return i

# ---------------------------------------------------------------- rochas 32x32
## Pedra: monte largo e baixo, cinza quente, rachaduras e brilho no canto.
func rock_stone() -> Image:
	var i: Image = L.img(32, 32)
	var m: Image = L.img(32, 32)
	L.m_ell(m, 16.0, 22.0, 14.5, 8.0)
	L.m_ell(m, 11.0, 18.0, 9.0, 7.5)
	L.m_ell(m, 22.0, 20.0, 8.0, 6.5)
	L.paint(i, m, 15.0, 19.0, 15.0, 11.0, ["s_hi", "s_hi", "s_md", "s_dk"], [-0.25, 0.15, 0.6])
	# faceta clara e rachaduras
	L.pts(i, [[6, 14], [7, 13], [8, 13], [9, 13], [10, 13], [11, 14], [5, 15], [6, 15]], "cut")
	L.pts(i, [[15, 16], [16, 17], [16, 18], [17, 19], [17, 20], [18, 21], [18, 22], [19, 23]], "s_xx")
	L.pts(i, [[9, 21], [10, 21], [10, 22], [11, 23]], "s_xx")
	L.pts(i, [[22, 15], [23, 16], [23, 17], [24, 17]], "s_xx")
	L.pts(i, [[3, 25], [4, 25], [27, 26], [28, 26]], "s_dk")
	L.outline(i)
	return i

func rock_stone_empty() -> Image:
	var i: Image = L.img(32, 32)
	for r in [[7, 24, 4.5, 3.0], [16, 26, 4.0, 2.6], [24, 24, 5.0, 3.2], [12, 21, 2.6, 1.8]]:
		var m: Image = L.img(32, 32)
		L.m_ell(m, r[0], r[1], r[2], r[3])
		L.paint(i, m, r[0], r[1], r[2] + 1, r[3] + 1, ["s_hi", "s_md", "s_dk", "s_dk"], [-0.3, 0.2, 0.7])
	L.outline(i)
	return i

## Minerio: aglomerado de cristais altos e pontudos, ardosia fria com veios ciano grossos.
func rock_ore() -> Image:
	var i: Image = L.img(32, 32)
	var base: Image = L.img(32, 32)
	L.m_ell(base, 16.0, 26.0, 14.0, 4.5)
	L.paint(i, base, 14.0, 25.0, 14.0, 5.0, ["o_hi", "o_md", "o_dk", "o_dk"], [-0.4, 0.2, 0.7])
	var spikes := [
		[Vector2(3, 28), Vector2(4, 18), Vector2(7, 12), Vector2(10, 17), Vector2(11, 28)],
		[Vector2(19, 28), Vector2(21, 15), Vector2(26, 8), Vector2(28, 14), Vector2(29, 28)],
		[Vector2(8, 29), Vector2(10, 14), Vector2(14, 3), Vector2(17, 1), Vector2(20, 9), Vector2(23, 29)],
	]
	for s in spikes:
		var m: Image = L.img(32, 32)
		L.m_poly(m, s)
		L.paint(i, m, 15.0, 15.0, 16.0, 15.0, ["o_hi", "o_md", "o_md", "o_dk"], [-0.55, 0.2, 0.6])
		var o2: Image = L.img(32, 32)
		o2.copy_from(i)
	# veios grossos (2 px)
	L.pts(i, [[13, 6], [14, 6], [14, 7], [14, 8], [15, 8], [15, 9], [15, 10], [16, 10], [16, 11], [17, 11], [17, 12], [17, 13], [18, 13], [18, 14], [18, 15]], "v_hi")
	L.pts(i, [[13, 7], [13, 8], [14, 9], [14, 10], [15, 11], [15, 12], [16, 12], [16, 13]], "v_md")
	L.pts(i, [[5, 19], [6, 19], [6, 20], [7, 20], [7, 21], [8, 21], [8, 22], [9, 22]], "v_hi")
	L.pts(i, [[5, 20], [6, 21], [7, 22]], "v_md")
	L.pts(i, [[24, 16], [24, 17], [25, 17], [25, 18], [25, 19], [26, 19], [26, 20], [26, 21]], "v_hi")
	L.pts(i, [[23, 17], [24, 18], [24, 19]], "v_md")
	L.pts(i, [[12, 22], [13, 22], [13, 23], [14, 23], [15, 23], [16, 24], [17, 24]], "v_md")
	# brilhos claros
	L.pts(i, [[15, 4], [8, 14], [26, 11], [12, 18]], "z_hi")
	L.outline(i)
	return i

func rock_ore_empty() -> Image:
	var i: Image = L.img(32, 32)
	for r in [[7, 24, 4.5, 3.2], [16, 26, 4.0, 2.8], [24, 24, 5.0, 3.4], [12, 21, 2.6, 2.0]]:
		var m: Image = L.img(32, 32)
		L.m_ell(m, r[0], r[1], r[2], r[3])
		L.paint(i, m, r[0], r[1], r[2] + 1, r[3] + 1, ["o_hi", "o_md", "o_dk", "o_dk"], [-0.3, 0.2, 0.7])
	L.pts(i, [[16, 25]], "v_md")
	L.outline(i)
	return i

# ---------------------------------------------------------------- formacoes rochosas
## Pinta uma lista de formas rochosas (de tras para a frente), com estratos, brilho e musgo opcional.
func rockform(w: int, h: int, shapes: Array, moss: bool, seed_: int) -> Image:
	var i: Image = L.img(w, h)
	var k := 0
	for sh in shapes:
		var m: Image = L.img(w, h)
		if sh["tipo"] == "poly":
			L.m_poly(m, sh["pts"])
		else:
			L.m_ell(m, sh["c"].x, sh["c"].y, sh["r"].x, sh["r"].y)
		var cx := 0.0
		var cy := 0.0
		var n := 0
		var minx := 999
		var maxx := 0
		var miny := 999
		var maxy := 0
		for y in h:
			for x in w:
				if L.solid(m, x, y):
					minx = min(minx, x); maxx = max(maxx, x); miny = min(miny, y); maxy = max(maxy, y)
		cx = (minx + maxx) / 2.0
		cy = (miny + maxy) / 2.0
		var rx := (maxx - minx) / 2.0 + 1.0
		var ry := (maxy - miny) / 2.0 + 1.0
		var tones: Array = sh.get("tons", ["s_hi", "s_md", "s_dk", "s_dk"])
		L.paint(i, m, cx - rx * 0.1, cy - ry * 0.1, rx, ry, tones, [-0.2, 0.2, 0.6])
		# estratos: linhas escuras curtas e inclinadas
		for y in range(miny + 2, maxy):
			for x in range(minx, maxx + 1):
				if L.solid(m, x, y) and L.solid(m, x, y - 1) and (y * 3 + x) % 9 == 0 and L.hash2(x, y, seed_ + k) < 0.3 and L.solid(m, x + 1, y):
					L.put(i, x, y, "s_xx")
					if L.solid(m, x + 1, y) and L.hash2(x, y, seed_ + 9) < 0.7:
						L.put(i, x + 1, y, "s_xx")
		# arestas claras no topo esquerdo
		for y in range(miny, maxy):
			for x in range(minx, maxx):
				if L.solid(m, x, y) and not L.solid(m, x, y - 1) and not L.solid(m, x - 1, y - 1) and L.hash2(x, y, seed_ + 5) < 0.5:
					L.put(i, x, y, "cut")
		# musgo nas superficies de cima
		if moss and sh.get("musgo", true):
			for y in range(miny, maxy):
				for x in range(minx, maxx + 1):
					if L.solid(m, x, y):
						var depth := 0
						while not L.solid(m, x, y - 1 - depth) and false:
							depth += 1
						var top := true
						for d in range(1, 4):
							if L.solid(m, x, y - d) and false:
								top = false
						var near := (not L.solid(m, x, y - 1)) or (not L.solid(m, x, y - 2)) or (not L.solid(m, x, y - 3) and L.hash2(x, y, seed_ + 2) < 0.7)
						if near and L.hash2(x, y, seed_ + 3) < 0.55 and y < cy + ry * 0.2:
							L.put(i, x, y, "g_md" if L.hash2(x, y, seed_ + 4) < 0.6 else "g_hi")
		k += 1
	L.outline(i)
	return i

func P(a: Array) -> Array:
	var o := []
	for p in a:
		o.append(Vector2(p[0], p[1]))
	return o

## A: espigoes altos (marco). 64x80.
func formation_a() -> Image:
	var shapes := [
		{"tipo": "poly", "pts": P([[30, 78], [29, 44], [33, 24], [37, 6], [40, 2], [45, 16], [50, 38], [54, 78]]), "tons": ["s_md", "s_dk", "s_xx", "s_xx"]},
		{"tipo": "poly", "pts": P([[4, 78], [6, 52], [13, 36], [19, 24], [24, 28], [28, 46], [32, 78]]), "tons": ["s_hi", "s_md", "s_dk", "s_dk"]},
		{"tipo": "poly", "pts": P([[40, 78], [42, 56], [49, 48], [57, 52], [61, 64], [62, 78]]), "tons": ["s_hi", "s_md", "s_md", "s_dk"]},
		{"tipo": "ell", "c": Vector2(30, 75), "r": Vector2(26, 5), "tons": ["s_md", "s_md", "s_dk", "s_dk"]},
	]
	return rockform(64, 80, shapes, true, 11)

## B: crista larga e baixa (obstaculo). 96x48.
func formation_b() -> Image:
	var shapes := [
		{"tipo": "poly", "pts": P([[2, 46], [3, 32], [10, 22], [19, 26], [28, 12], [40, 6], [49, 14], [60, 9], [72, 16], [82, 24], [91, 32], [93, 46]]), "tons": ["s_hi", "s_md", "s_dk", "s_dk"]},
		{"tipo": "ell", "c": Vector2(22, 41), "r": Vector2(14, 6), "tons": ["s_hi", "s_md", "s_dk", "s_dk"]},
		{"tipo": "ell", "c": Vector2(66, 41), "r": Vector2(17, 6), "tons": ["s_hi", "s_md", "s_dk", "s_xx"]},
		{"tipo": "ell", "c": Vector2(45, 43), "r": Vector2(9, 4), "tons": ["s_md", "s_dk", "s_dk", "s_xx"], "musgo": false},
	]
	return rockform(96, 48, shapes, false, 23)

## C: monte de matacoes. 64x48.
func formation_c() -> Image:
	var shapes := [
		{"tipo": "ell", "c": Vector2(32, 21), "r": Vector2(15, 13), "tons": ["s_hi", "s_md", "s_dk", "s_dk"]},
		{"tipo": "ell", "c": Vector2(18, 34), "r": Vector2(17, 12), "tons": ["s_hi", "s_md", "s_dk", "s_dk"]},
		{"tipo": "ell", "c": Vector2(44, 33), "r": Vector2(17, 13), "tons": ["s_hi", "s_md", "s_dk", "s_xx"]},
		{"tipo": "ell", "c": Vector2(9, 41), "r": Vector2(8, 5), "tons": ["s_hi", "s_md", "s_dk", "s_dk"], "musgo": false},
		{"tipo": "ell", "c": Vector2(56, 42), "r": Vector2(7, 4), "tons": ["s_hi", "s_md", "s_dk", "s_dk"], "musgo": false},
	]
	return rockform(64, 48, shapes, true, 37)
