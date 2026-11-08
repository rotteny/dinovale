## Gerador dos BOTOES do menu (madeira com pregos, 9-slice) em 4 estados. Arte propria, CC BY 4.0, sem IA.
## Da raiz do repositorio:
##   godot --headless --script docs/design/arte/gerar_menu_botoes.gd -- <pasta de saida>
## Saida: botao_{normal,hover,pressed,disabled}.png (24x20 cada) e botoes.json (margens 9-slice e cores de texto).
## 9-slice: margens esq/dir 6, topo 5, base 6; o miolo (12x9) e liso, entao estica sem borrar. Largura/altura livres
## (altura >= 20; o pressionado "afunda" 2 px: o topo do desenho comeca 2 px abaixo e o degrau de baixo fica de 1 px).
## Paleta: so a do pacote (arte_lib.save_png_checked). Luz de cima-esquerda. NAO grava em game/assets.
extends SceneTree
const Lib = preload("arte_lib.gd")
var L = Lib.new()

# estado -> {hi, body, shade, lip, nail, top (linha do contorno de cima), face_h}
const ST := {
	"normal": {"hi": "w_hi", "body": "w_md", "shade": "w_dk", "lip": "w_xx", "nail": "s_hi", "top": 0, "bottom": 16},
	"hover": {"hi": "cut", "body": "w_hi", "shade": "w_md", "lip": "w_dk", "nail": "yellow", "top": 0, "bottom": 16},
	"pressed": {"hi": "w_md", "body": "w_dk", "shade": "w_xx", "lip": "w_xx", "nail": "s_hi", "top": 2, "bottom": 17},
	"disabled": {"hi": "s_hi", "body": "s_md", "shade": "s_dk", "lip": "s_dk", "nail": "s_dk", "top": 0, "bottom": 16},
}
const W := 24
const H := 20

func draw(state: String) -> Image:
	var s: Dictionary = ST[state]
	var i := L.img(W, H)
	var t: int = s["top"]
	var b: int = s["bottom"]
	# contorno da face
	for y in range(t, b + 1):
		for x in W:
			var corner := (y == t or y == b) and (x == 0 or x == W - 1)
			if corner:
				continue
			if y == t or y == b or x == 0 or x == W - 1:
				L.put(i, x, y, "K")
			else:
				L.put(i, x, y, s["body"])
	# luz: linha de cima e coluna da esquerda; sombra: linha de baixo e coluna da direita
	for x in range(1, W - 1):
		L.put(i, x, t + 1, s["hi"])
		L.put(i, x, b - 1, s["shade"])
	for y in range(t + 1, b):
		L.put(i, 1, y, s["hi"])
		L.put(i, W - 2, y, s["shade"])
	L.put(i, W - 2, t + 1, s["hi"])
	L.put(i, 1, b - 1, s["shade"])
	# degrau (lip) abaixo da face, ate o contorno de baixo (y = H-1)
	for y in range(b + 1, H):
		for x in W:
			if y == H - 1:
				if x != 0 and x != W - 1:
					L.put(i, x, y, "K")
			elif x == 0 or x == W - 1:
				L.put(i, x, y, "K")
			else:
				L.put(i, x, y, s["lip"])
	# pregos nos cantos (dentro das margens do 9-slice)
	var ny0 := t + 3
	var ny1 := b - 2
	for p in [[3, ny0], [W - 4, ny0], [3, ny1], [W - 4, ny1]]:
		L.put(i, p[0], p[1], s["nail"])
	return i

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	assert(args.size() >= 1, "uso: -- <pasta de saida>")
	for st in ST:
		L.save_png_checked(draw(st), (args[0] as String).path_join("botao_%s.png" % st))
	var info := {
		"tamanho_textura": [W, H], "nine_slice_margens": {"esquerda": 6, "direita": 6, "topo": 5, "base": 6},
		"altura_minima": 20, "largura_sugerida": 96, "espacamento_sugerido": 4,
		"filtro": "nearest", "axis_stretch": "stretch (miolo liso)",
		"content_margin_sugerida": {
			"normal": {"topo": 0, "base": 3}, "hover": {"topo": 0, "base": 3},
			"pressed": {"topo": 2, "base": 1}, "disabled": {"topo": 0, "base": 3},
		},
		"cor_texto": {
			"normal": {"texto": "#fce2ca", "sombra": "#965340"}, "hover": {"texto": "#ffffff", "sombra": "#965340"},
			"pressed": {"texto": "#fce2ca", "sombra": "#4e484a"}, "disabled": {"texto": "#4e484a", "sombra": "#b3957f"},
		},
		"fonte": "ValeMini 8 px (a do jogo); sombra de texto com offset (0,1)",
	}
	var f := FileAccess.open((args[0] as String).path_join("botoes.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(info, "\t"))
	f.close()
	quit()
