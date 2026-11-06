## Biblioteca comum dos geradores da escala nova (jogador, terreno, cenario).
## Arte propria, CC BY 4.0, sem IA. Rode sempre da raiz do repositorio.
## Paleta: so as cores de game/assets/third_party/ninja-adventure/palette.png
## (verificadas em save_png_checked); contorno #141b1b; alfa so 0 ou 1.
extends RefCounted

const PALETTE_FILE := "game/assets/third_party/ninja-adventure/palette.png"

# Nomes de cor usados pelos geradores (todos da paleta do pacote).
const C := {
	"K": "#141b1b",
	# verdes
	"g_hi": "#74a334", "g_lt": "#adbc3a", "g_ol": "#a8a129", "g_md": "#56864c", "g_dk": "#345a52",
	"g_gr": "#5f7160", "g_sg": "#8d977f", "g_pl": "#abc2bc",
	# madeira e terra
	"w_hi": "#c8966b", "w_md": "#a3754e", "w_dk": "#965340", "w_xx": "#816855", "w_br": "#bd7959",
	"cut": "#fce2ca", "ring": "#f1c471", "ring2": "#d2b37d",
	"clay": "#d3865f", "orange": "#ef914f",
	# pele
	"sk_hi": "#f2ad7d", "sk_md": "#d3865f", "sk_dk": "#bd7959", "sk_xx": "#965340",
	# cabelo
	"h_hi": "#90775e", "h_md": "#816855", "h_dk": "#695953", "h_xx": "#4e484a",
	# pedra (cinza quente)
	"s_hi": "#b3957f", "s_md": "#8e7c73", "s_dk": "#695953", "s_xx": "#4e484a",
	# minerio (ardosia fria + veios ciano)
	"o_hi": "#548789", "o_md": "#4a5270", "o_dk": "#3b3643", "v_hi": "#8feff1", "v_md": "#71ddee",
	# areia
	"sand_hi": "#ffe18d", "sand": "#eecf9b", "sand_dk": "#d2b37d", "sand_xx": "#c8966b",
	# agua
	"deep": "#2d697b", "deep_hi": "#548789", "deep_dk": "#4a5270",
	"shal": "#79b8ce", "shal_hi": "#8feff1", "shal_md": "#71ddee", "foam": "#f2eaf1", "foam2": "#b8dce5",
	# flores e frutas
	"f_red": "#d14b34", "f_hi": "#ffcba9", "f_dk": "#8f3e56", "pink": "#ef9597", "yellow": "#ffe18d",
	"z_hi": "#f2eaf1", "z_md": "#b8dce5", "z_dk": "#79b8ce", "z_xx": "#a5608b", "bloom": "#d3a2c0",
	"white": "#ffffff",
}

var P := {}
var _pal := {}

func _init() -> void:
	for k in C:
		P[k] = Color(C[k])
	var pi := Image.load_from_file(PALETTE_FILE)
	assert(pi != null, "palette.png nao encontrada: rode da raiz do repositorio")
	for y in pi.get_height():
		for x in pi.get_width():
			var c := pi.get_pixel(x, y)
			if c.a > 0.5:
				_pal[c.to_html(false)] = true

# ---------------------------------------------------------------- imagem
func img(w: int, h: int) -> Image:
	var i := Image.create(w, h, false, Image.FORMAT_RGBA8)
	i.fill(Color(0, 0, 0, 0))
	return i

func put(i: Image, x: int, y: int, c: String) -> void:
	if x >= 0 and y >= 0 and x < i.get_width() and y < i.get_height():
		i.set_pixel(x, y, P[c])

func pts(i: Image, list: Array, c: String) -> void:
	for p in list:
		put(i, p[0], p[1], c)

func rect(i: Image, x: int, y: int, w: int, h: int, c: String) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			put(i, xx, yy, c)

func solid(m: Image, x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < m.get_width() and y < m.get_height() and m.get_pixel(x, y).a > 0.5

## Confere alfa 0/1 e paleta; grava o PNG. Aborta com mensagem se algo sair da regra.
func save_png_checked(i: Image, path: String) -> void:
	for y in i.get_height():
		for x in i.get_width():
			var c := i.get_pixel(x, y)
			assert(c.a == 0.0 or c.a == 1.0, "alfa fracionado em %s (%d,%d)" % [path, x, y])
			if c.a == 1.0 and not _pal.has(c.to_html(false)):
				push_error("cor fora da paleta em %s (%d,%d): %s" % [path, x, y, c.to_html(false)])
				assert(false)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	i.save_png(path)

# ---------------------------------------------------------------- mascaras
func m_ell(m: Image, cx: float, cy: float, rx: float, ry: float) -> void:
	for y in range(int(floor(cy - ry)), int(ceil(cy + ry)) + 1):
		for x in range(int(floor(cx - rx)), int(ceil(cx + rx)) + 1):
			var dx := (x + 0.5 - cx) / rx
			var dy := (y + 0.5 - cy) / ry
			if dx * dx + dy * dy <= 1.0 and x >= 0 and y >= 0 and x < m.get_width() and y < m.get_height():
				m.set_pixel(x, y, Color.WHITE)

func m_rect(m: Image, x: int, y: int, w: int, h: int) -> void:
	for yy in range(y, y + h):
		for xx in range(x, x + w):
			if xx >= 0 and yy >= 0 and xx < m.get_width() and yy < m.get_height():
				m.set_pixel(xx, yy, Color.WHITE)

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

## Pinta a mascara em faixas duras (sem gradiente): t cresce da luz (cima-esquerda) para baixo-direita.
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

## Contorno externo de 1 px (4-vizinhos) em K.
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

## Hash inteiro deterministico 0..1 (para ruido reproduzivel).
func hash2(x: int, y: int, seed_: int) -> float:
	var h: int = (x * 374761393 + y * 668265263 + seed_ * 1442695041) & 0xffffffff
	h = ((h ^ (h >> 15)) * 2246822519) & 0xffffffff
	h = ((h ^ (h >> 13)) * 3266489917) & 0xffffffff
	h = h ^ (h >> 16)
	return float(h & 0xffff) / 65535.0

## Copia src em dst na posicao (sem mistura de alfa: so pixels opacos).
func blit(dst: Image, src: Image, ox: int, oy: int) -> void:
	for y in src.get_height():
		for x in src.get_width():
			var c := src.get_pixel(x, y)
			if c.a > 0.5 and x + ox >= 0 and y + oy >= 0 and x + ox < dst.get_width() and y + oy < dst.get_height():
				dst.set_pixel(x + ox, y + oy, c)

func flip_h(i: Image) -> Image:
	var o := i.duplicate() as Image
	o.flip_x()
	return o
