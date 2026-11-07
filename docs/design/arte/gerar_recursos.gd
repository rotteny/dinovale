## Gerador dos sprites de nos de recurso (arvores, arbustos, rochas, pedras avulsas, icones).
## Arte propria, CC BY 4.0, sem IA e sem recorte do pacote. Regenere da raiz do repositorio:
##   godot --headless --script docs/design/arte/gerar_recursos.gd
## Saida: game/assets/sprites/recursos/*.png (alfa so 0 ou 1).
## Paleta: so cores da paleta do pacote Ninja Adventure (ESTILO.md), contorno #141b1b.
## Luz de cima, levemente a esquerda. Ancora de todos os sprites: base do quadro.
extends SceneTree

const OUT := "game/assets/sprites/recursos/"

const C := {
	"K": "#141b1b",
	# verdes
	"g_hi": "#74a334", "g_lt": "#adbc3a", "g_ol": "#a8a129", "g_md": "#56864c", "g_dk": "#345a52",
	# madeira
	"w_hi": "#c8966b", "w_md": "#a3754e", "w_dk": "#965340", "w_xx": "#816855",
	"cut": "#fce2ca", "ring": "#f1c471", "ring2": "#d2b37d",
	# pedra (cinza quente)
	"s_hi": "#b3957f", "s_md": "#8e7c73", "s_dk": "#695953", "s_xx": "#4e484a",
	# minerio (ardosia fria + veios ciano)
	"o_hi": "#548789", "o_md": "#4a5270", "o_dk": "#3b3643", "v_hi": "#8feff1", "v_md": "#71ddee",
	# frutas
	"f_red": "#d14b34", "f_hi": "#ffcba9", "f_dk": "#8f3e56",
	"z_hi": "#f2eaf1", "z_md": "#b8dce5", "z_dk": "#79b8ce", "z_xx": "#a5608b",
	"bloom": "#d3a2c0",
}

var P := {}

func _init() -> void:
	for k in C:
		P[k] = Color(C[k])
	DirAccess.make_dir_recursive_absolute(OUT)
	save(tree_collect(), "tree_collect")
	save(tree_collect_stump(), "tree_collect_stump")
	var b := bush_base()
	save(bush_with(b, "food"), "bush_food")
	save(bush_with(b, "sleep"), "bush_sleep")
	save(bush_with(b, "empty"), "bush_empty")
	save(rock_stone(), "rock_stone")
	save(rock_stone_empty(), "rock_stone_empty")
	save(rock_ore(), "rock_ore")
	save(rock_ore_empty(), "rock_ore_empty")
	save(pebble_a(), "pebble_a")
	save(pebble_b(), "pebble_b")
	save(icon_stone(), "icon_stone")
	save(icon_food(), "icon_fruit_food")
	save(icon_sleep(), "icon_fruit_sleep")
	quit()

# ---------------------------------------------------------------- primitivas
func img(w: int, h: int) -> Image:
	var i := Image.create(w, h, false, Image.FORMAT_RGBA8)
	i.fill(Color(0, 0, 0, 0))
	return i

func save(i: Image, name: String) -> void:
	for y in i.get_height():
		for x in i.get_width():
			var a := i.get_pixel(x, y).a
			assert(a == 0.0 or a == 1.0)
	i.save_png(OUT + name + ".png")

func put(i: Image, x: int, y: int, c: String) -> void:
	if x >= 0 and y >= 0 and x < i.get_width() and y < i.get_height():
		i.set_pixel(x, y, P[c])

func solid(m: Image, x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < m.get_width() and y < m.get_height() and m.get_pixel(x, y).a > 0.5

## Mascara: elipse.
func m_ell(m: Image, cx: float, cy: float, rx: float, ry: float) -> void:
	for y in range(int(floor(cy - ry)), int(ceil(cy + ry)) + 1):
		for x in range(int(floor(cx - rx)), int(ceil(cx + rx)) + 1):
			var dx := (x + 0.5 - cx) / rx
			var dy := (y + 0.5 - cy) / ry
			if dx * dx + dy * dy <= 1.0:
				m.set_pixel(x, y, Color.WHITE) if x >= 0 and y >= 0 and x < m.get_width() and y < m.get_height() else null

func m_rect(m: Image, x: int, y: int, w: int, h: int) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			if xx >= 0 and yy >= 0 and xx < m.get_width() and yy < m.get_height():
				m.set_pixel(xx, yy, Color.WHITE)

## Mascara: poligono (teste ponto-em-poligono no centro do pixel).
func m_poly(m: Image, poly: Array) -> void:
	for y in m.get_height():
		for x in m.get_width():
			var px := x + 0.5
			var py := y + 0.5
			var inside := false
			var j := poly.size() - 1
			for k in poly.size():
				var a: Vector2 = poly[k]
				var b: Vector2 = poly[j]
				if (a.y > py) != (b.y > py) and px < (b.x - a.x) * (py - a.y) / (b.y - a.y) + a.x:
					inside = not inside
				j = k
			if inside:
				m.set_pixel(x, y, Color.WHITE)

## Pinta a mascara em faixas duras: t < lo claro, < mid base, < hi sombra, senao escuro.
## t cresce da luz (cima-esquerda) para a sombra (baixo-direita).
func paint(dst: Image, m: Image, cx: float, cy: float, rx: float, ry: float, tones: Array, cuts: Array = [-0.35, 0.2, 0.62]) -> void:
	for y in m.get_height():
		for x in m.get_width():
			if not solid(m, x, y):
				continue
			var t := ((x + 0.5 - cx) / rx) * 0.45 + ((y + 0.5 - cy) / ry) * 0.65
			var n := 0
			for c in cuts:
				if t >= c:
					n += 1
			put(dst, x, y, tones[min(n, tones.size() - 1)])

func outline(i: Image) -> void:
	var src := i.duplicate() as Image
	for y in i.get_height():
		for x in i.get_width():
			if src.get_pixel(x, y).a > 0.5:
				continue
			for d in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]:
				if solid(src, x + d.x, y + d.y):
					put(i, x, y, "K")
					break

func pts(i: Image, list: Array, c: String) -> void:
	for p in list:
		put(i, p[0], p[1], c)

# ---------------------------------------------------------------- arvore coletavel
## 32x48: copa alta em 3 camadas pontudas, verde-amarelado claro, tronco longo
## com entalhe de corte claro. Silhueta estreita e pontuda (a decorativa e larga e redonda).
func tree_collect() -> Image:
	var i := img(32, 48)
	# tronco
	var tr := img(32, 48)
	m_rect(tr, 13, 34, 6, 13)
	m_rect(tr, 12, 44, 8, 3) # raiz abre na base
	paint(i, tr, 15, 40, 4, 8, ["w_hi", "w_md", "w_dk", "w_dk"], [-0.45, 0.25, 0.7])
	# copa: 3 camadas, de baixo para cima (a de cima fica na frente)
	var tiers := [[22, 37, 3.0, 14.0], [13, 28, 2.5, 11.0], [3, 18, 1.0, 8.0]]
	for t in tiers:
		var m := img(32, 48)
		var y0: int = t[0]
		var y1: int = t[1]
		for y in range(y0, y1 + 1):
			var f := float(y - y0) / float(y1 - y0)
			var hw: float = lerpf(t[2], t[3], f)
			for x in range(int(floor(16.0 - hw)), int(ceil(16.0 + hw))):
				if abs(x + 0.5 - 16.0) <= hw:
					m.set_pixel(x, y, Color.WHITE)
		# barra de baixo ondulada
		for x in range(0, 32):
			var wob := 1 if (x / 3) % 2 == 0 else 0
			if solid(m, x, y1) and wob == 1:
				m.set_pixel(x, y1, Color(0, 0, 0, 0))
		var cx := 16.0
		paint(i, m, cx - 2.0, float(y0 + y1) / 2.0, 26.0, float(y1 - y0) / 2.0 + 1.0, ["g_lt", "g_ol", "g_hi", "g_md"], [-0.45, 0.15, 0.55])
		# contorno da camada para separar das outras
		var oc := img(32, 48)
		oc.copy_from(i)
		for y in range(y0, y1 + 2):
			for x in 32:
				if solid(m, x, y) and not solid(m, x, y + 1) and y > y0 + 2:
					put(i, x, y, "g_md")
	# entalhe de corte no tronco (marca de que e coletavel)
	pts(i, [[14, 38], [15, 38], [14, 39], [15, 39], [16, 39]], "cut")
	pts(i, [[14, 40], [15, 40], [16, 40]], "w_xx")
	# folhas de detalhe
	pts(i, [[16, 8], [14, 16], [18, 17], [12, 25], [20, 26], [9, 33], [23, 33], [16, 31]], "g_dk")
	outline(i)
	return i

func tree_collect_stump() -> Image:
	var i := img(16, 16)
	var side := img(16, 16)
	m_rect(side, 3, 8, 10, 6)
	m_ell(side, 8, 13, 5, 2.0)
	paint(i, side, 7, 11, 5, 4, ["w_md", "w_dk", "w_dk", "w_xx"], [0.0, 0.35, 0.9])
	var top := img(16, 16)
	m_ell(top, 8, 8, 5.5, 3.5)
	paint(i, top, 8, 8, 5, 3.5, ["ring", "ring", "ring2", "ring2"], [0.5, 0.7, 9.0])
	# aneis do toco
	pts(i, [[6, 8], [7, 7], [8, 7], [9, 7], [10, 8], [9, 9], [8, 9], [7, 9]], "ring2")
	pts(i, [[8, 8]], "w_md")
	# lascas de madeira ao lado
	pts(i, [[1, 13], [2, 13]], "w_md")
	pts(i, [[14, 13]], "w_md")
	outline(i)
	return i

# ---------------------------------------------------------------- arvore decorativa
## 48x48: copa larga, redonda e escura (verde-azulado), tronco curto e grosso
## escondido, flores lilas. Sem entalhe, sem cor clara: nao coletavel.

func bush_base() -> Image:
	var i := img(16, 16)
	var m := img(16, 16)
	m_ell(m, 8.0, 10.5, 7.0, 4.8)
	# laminas (fibras) de alturas diferentes
	for b in [[2, 4], [4, 2], [6, 3], [9, 1], [11, 3], [13, 5]]:
		var x: int = b[0]
		var top: int = b[1]
		for y in range(top, 9):
			m.set_pixel(x, y, Color.WHITE)
	paint(i, m, 8.0, 9.0, 8.0, 7.0, ["g_hi", "g_md", "g_md", "g_dk"], [-0.45, 0.0, 0.55])
	# fios claros nas laminas
	pts(i, [[4, 3], [9, 2], [13, 6], [2, 5]], "g_hi")
	pts(i, [[5, 12], [8, 13], [11, 12], [3, 11]], "g_dk")
	return i

func bush_with(base: Image, kind: String) -> Image:
	var i := base.duplicate() as Image
	if kind == "food":
		# 3 frutas redondas, vermelhas, com brilho claro e sombra escura
		for p in [[4, 9], [10, 8], [7, 12]]:
			var x: int = p[0]
			var y: int = p[1]
			pts(i, [[x, y - 1], [x - 1, y], [x, y], [x + 1, y], [x, y + 1], [x + 1, y - 1]], "f_red")
			pts(i, [[x - 1, y - 1]], "f_hi")
			pts(i, [[x + 1, y + 1]], "f_dk")
	elif kind == "sleep":
		# 3 luas (formato de C) pequenas e claras, com halo escuro: lidas por forma e brilho
		var moon := [[1, 0], [2, 0], [0, 1], [1, 1], [0, 2], [1, 2], [1, 3], [2, 3]]
		for p in [[2, 6], [9, 5], [6, 10]]:
			for q in moon:
				for dx in range(-1, 2):
					for dy in range(-1, 2):
						put(i, p[0] + q[0] + dx, p[1] + q[1] + dy, "g_dk")
			for q in moon:
				put(i, p[0] + q[0], p[1] + q[1], "z_hi" if q[0] == 0 or q[1] == 0 else "z_md")
			put(i, p[0] + 2, p[1] + 3, "z_dk")
	else:
		# colhido: gravetos secos no lugar das frutas
		pts(i, [[5, 9], [10, 8], [8, 12]], "w_dk")
	outline(i)
	return i

# ---------------------------------------------------------------- rochas
## Pedra: monte baixo, largo e arredondado, cinza quente claro, SEM nenhuma cor fria.
## Leitura de relance: massa horizontal (15x10), topo liso, uma unica rachadura.
func rock_stone() -> Image:
	var i := img(16, 16)
	var m := img(16, 16)
	m_ell(m, 8.0, 10.5, 7.5, 4.6)
	m_ell(m, 5.5, 9.0, 4.5, 3.6)
	paint(i, m, 8.0, 9.5, 8.0, 5.5, ["s_hi", "s_hi", "s_md", "s_dk"], [-0.2, 0.15, 0.6])
	pts(i, [[8, 9], [9, 10], [9, 11], [10, 12]], "s_dk") # rachadura
	pts(i, [[4, 7], [5, 7], [6, 7]], "cut")
	outline(i)
	return i

func rock_stone_empty() -> Image:
	var i := img(16, 16)
	for r in [[3, 11, 3.0, 2.0], [8, 12, 2.5, 1.8], [12, 11, 2.5, 2.0]]:
		var m := img(16, 16)
		m_ell(m, r[0], r[1], r[2], r[3])
		paint(i, m, r[0], r[1], r[2] + 1, r[3] + 1, ["s_hi", "s_md", "s_dk", "s_dk"], [-0.3, 0.2, 0.7])
	outline(i)
	return i

## Minerio: cristal alto e pontudo (16 de altura, 2 picos), corpo ardosia/azul-petroleo
## e veios ciano GROSSOS (2 px) mais brilhos claros: a veia brilha em 1x, sem depender so de matiz.
func rock_ore() -> Image:
	var i := img(16, 16)
	var m := img(16, 16)
	m_poly(m, [Vector2(1, 15), Vector2(1, 11), Vector2(3, 7), Vector2(5, 8), Vector2(6, 3), Vector2(8, 1), Vector2(10, 4), Vector2(11, 7), Vector2(13, 5), Vector2(15, 10), Vector2(15, 15)])
	paint(i, m, 8.0, 8.0, 8.0, 7.0, ["o_hi", "o_md", "o_md", "o_dk"], [-0.55, 0.25, 0.65])
	# veios grossos
	pts(i, [[3, 10], [4, 10], [4, 9], [5, 9], [5, 10], [6, 10], [6, 11], [7, 11]], "v_hi")
	pts(i, [[8, 5], [8, 6], [8, 7], [9, 7], [9, 8], [10, 8], [10, 9], [11, 9], [11, 10], [12, 10]], "v_hi")
	pts(i, [[7, 12], [8, 12], [8, 13], [9, 13], [10, 13]], "v_md")
	pts(i, [[3, 11], [5, 11], [9, 9], [9, 6], [12, 11]], "v_md")
	# brilhos
	pts(i, [[8, 4], [4, 8], [12, 8], [7, 13]], "z_hi")
	outline(i)
	return i

func rock_ore_empty() -> Image:
	var i := img(16, 16)
	for r in [[3, 11, 3.0, 2.2], [8, 12, 2.5, 1.8], [12, 11, 2.5, 2.2]]:
		var m := img(16, 16)
		m_ell(m, r[0], r[1], r[2], r[3])
		paint(i, m, r[0], r[1], r[2] + 1, r[3] + 1, ["o_hi", "o_md", "o_dk", "o_dk"], [-0.3, 0.2, 0.7])
	# uma lasca de veio apagado, so 1 pixel (o no foi esgotado)
	pts(i, [[8, 11]], "v_md")
	outline(i)
	return i

# ---------------------------------------------------------------- pedras avulsas e icone
## Pedra avulsa (coletada a mao): bem menor que rock_stone (7x5 e 9x6 contra 15x10), clara,
## com brilho; nao parece pedregulho esgotado (aquele e um trio baixo e escuro).
func pebble_a() -> Image:
	var i := img(16, 16)
	var m := img(16, 16)
	m_ell(m, 8.0, 12.0, 3.6, 2.6)
	paint(i, m, 8.0, 12.0, 4.0, 3.0, ["cut", "s_hi", "s_md", "s_dk"], [-0.3, 0.1, 0.6])
	outline(i)
	return i

func pebble_b() -> Image:
	var i := img(16, 16)
	var m := img(16, 16)
	m_poly(m, [Vector2(4, 14), Vector2(4, 11), Vector2(6, 9), Vector2(9, 9), Vector2(11, 11), Vector2(11, 14)])
	paint(i, m, 7.5, 11.5, 4.0, 3.0, ["cut", "s_hi", "s_md", "s_dk"], [-0.3, 0.1, 0.6])
	var c := img(16, 16)
	m_rect(c, 12, 12, 3, 2)
	paint(i, c, 13.0, 13.0, 2.0, 1.5, ["s_hi", "s_md", "s_dk", "s_dk"], [-0.2, 0.3, 0.8])
	outline(i)
	return i

func icon_stone() -> Image:
	var i := img(16, 16)
	var m := img(16, 16)
	m_poly(m, [Vector2(2, 12), Vector2(2, 8), Vector2(5, 4), Vector2(10, 3), Vector2(13, 6), Vector2(14, 11), Vector2(11, 13), Vector2(5, 13)])
	paint(i, m, 8.0, 8.0, 6.0, 5.0, ["cut", "s_hi", "s_md", "s_dk"], [-0.5, 0.0, 0.55])
	pts(i, [[8, 8], [9, 9], [9, 10]], "s_dk")
	outline(i)
	return i

# ---------------------------------------------------------------- icones 16x16
func icon_food() -> Image:
	var i := img(16, 16)
	var m := img(16, 16)
	m_ell(m, 8.0, 9.0, 5.5, 5.5)
	paint(i, m, 8.0, 9.0, 6.0, 6.0, ["f_red", "f_red", "f_dk", "f_dk"], [0.15, 0.45, 9.0])
	pts(i, [[5, 6], [6, 6], [5, 7], [11, 11]], "f_hi")
	pts(i, [[10, 12], [9, 13], [8, 13]], "f_dk")
	# cabinho e folha
	pts(i, [[8, 3], [8, 4]], "w_dk")
	pts(i, [[9, 3], [10, 2], [11, 2], [10, 3]], "g_md")
	pts(i, [[9, 2]], "g_hi")
	outline(i)
	return i

func icon_sleep() -> Image:
	var i := img(16, 16)
	var m := img(16, 16)
	# vagem em meia-lua (sinal de sono), azul claro
	m_ell(m, 8.0, 8.0, 5.5, 6.5)
	var cut := img(16, 16)
	m_ell(cut, 11.0, 6.5, 4.8, 5.5)
	for y in 16:
		for x in 16:
			if solid(cut, x, y):
				m.set_pixel(x, y, Color(0, 0, 0, 0))
	paint(i, m, 7.0, 8.0, 6.0, 7.0, ["z_hi", "z_md", "z_dk", "z_dk"], [-0.45, 0.1, 0.55])
	pts(i, [[4, 8], [4, 9], [5, 12]], "z_xx")
	pts(i, [[6, 3], [7, 3]], "z_hi")
	outline(i)
	return i
