## Icones de sexo (macho e femea) por script. Arte propria, CC BY 4.0, sem IA. Da raiz do repositorio:
##   godot --headless --script docs/design/arte/gerar_icones_sexo.gd -- <pasta de saida>
## Saida: icon_sex_male.png e icon_sex_female.png (7x7, so o simbolo) e as variantes *_outline.png (9x9: o mesmo
## simbolo com 1 px de contorno #141b1b ao redor, para ler sobre qualquer fundo). Formas distintas alem da cor:
## macho = anel com seta no canto superior direito; femea = anel com cruz embaixo. Cores: macho #71ddee, femea #ef9597.
## NAO grava em game/assets: o dono aprova antes.
extends SceneTree
const Lib = preload("arte_lib.gd")
var L = Lib.new()

const MALE := [
	"....XXX",
	"......X",
	".XXX.XX",
	"X...X.X",
	"X...X..",
	"X...X..",
	".XXX...",
]
const FEMALE := [
	"..XXX..",
	".X...X.",
	".X...X.",
	"..XXX..",
	"...X...",
	"..XXX..",
	"...X...",
]

func glyph(rows: Array, color: String, outline: bool) -> Image:
	var pad := 1 if outline else 0
	var im: Image = L.img(7 + pad * 2, 7 + pad * 2)
	var solid := {}
	for y in 7:
		for x in 7:
			if (rows[y] as String)[x] == "X":
				solid[Vector2i(x, y)] = true
	if outline:
		for k in solid:
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]:
				var q: Vector2i = k + d
				if not solid.has(q):
					L.put(im, q.x + pad, q.y + pad, "K")
	for k in solid:
		L.put(im, k.x + pad, k.y + pad, color)
	return im

func _init() -> void:
	var dir: String = OS.get_cmdline_user_args()[0]
	L.save_png_checked(glyph(MALE, "v_md", false), dir.path_join("icon_sex_male.png"))
	L.save_png_checked(glyph(FEMALE, "pink", false), dir.path_join("icon_sex_female.png"))
	L.save_png_checked(glyph(MALE, "v_md", true), dir.path_join("icon_sex_male_outline.png"))
	L.save_png_checked(glyph(FEMALE, "pink", true), dir.path_join("icon_sex_female_outline.png"))
	# previa 8x sobre grama e sobre fundo escuro
	var pv: Image = L.img(9 * 2 + 6, 9)
	pv.fill(Color("#a8a129"))
	for i in 2:
		var g := Image.load_from_file(dir.path_join(["icon_sex_male_outline.png", "icon_sex_female_outline.png"][i]))
		pv.blend_rect(g, Rect2i(0, 0, 9, 9), Vector2i(2 + i * 12, 0))
	pv.resize(pv.get_width() * 8, pv.get_height() * 8, Image.INTERPOLATE_NEAREST)
	pv.save_png(dir.path_join("icones-sexo-8x.png"))
	quit()
