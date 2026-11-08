## Gerador dos cursores contextuais: padrao, mao, machado, picareta, ataque, interagir.
## Arte propria, CC BY 4.0, sem IA e sem recorte de terceiros. Da raiz do repositorio:
##   godot --headless --script documentacao/design/arte/gerar_cursores.gd -- <pasta_de_saida>
## Para cada cursor: grade nativa 16x16 (contorno #141b1b de 1 px, alfa 0/1, so paleta do pacote),
## variante "fora de alcance" (_fora: dessaturada em cinzas da paleta, contorno claro; sem alfa
## fracionado, porque o cursor do SO nao deve depender de blend) e copias 32x32 e 48x48 por escala
## inteira (vizinho mais proximo). Saida: <nome>_<tam>.png, <nome>_fora_<tam>.png, cursores.json
## (hotspot na grade de 16 e em cada tamanho) e preview.png (4x sobre grama, areia e agua).
extends SceneTree
const Lib = preload("arte_lib.gd")
var L = Lib.new()

# Rampa [claro, medio, escuro] por letra de preenchimento; o contorno K e automatico.
const RAMPS := {
	"s": ["sk_hi", "sk_md", "sk_dk"],   # pele (mao)
	"w": ["w_hi", "w_md", "w_dk"],      # madeira
	"t": ["z_hi", "z_md", "o_hi"],      # metal azulado
	"r": ["pink", "f_red", "f_dk"],     # vermelho (ameaca)
	"g": ["g_lt", "g_hi", "g_md"],      # pata
}
const ORDEM := ["padrao", "mao", "machado", "picareta", "ataque", "interagir"]
const HOTSPOT := {
	"padrao": [0, 0], "mao": [8, 9], "machado": [13, 4],
	"picareta": [2, 4], "ataque": [1, 1], "interagir": [8, 9],
}
const MASKS := {
	"mao": [
		"................",
		"................",
		"......ss........",
		"......ss.ss.....",
		"...ss.ss.ss.....",
		"...ss.ss.ss.ss..",
		"...ss.ss.ss.ss..",
		"...ssssssssssss.",
		"..sssssssssssss.",
		".sssssssssssss..",
		".sssssssssssss..",
		"..ssssssssssss..",
		"...ssssssssss...",
		"....ssssssss....",
		"................",
		"................",
	],
	"machado": [
		"................",
		"........ttt.....",
		".......tttttt...",
		".......ttttttt..",
		"......wttttttt..",
		"......wttttttt..",
		".....wwtttttt...",
		".....ww.tttt....",
		"....ww...tt.....",
		"...ww...........",
		"..ww............",
		".ww.............",
		".w..............",
		"................",
		"................",
		"................",
	],
	"picareta": [
		"................",
		"......tttt......",
		"...tttttttttt...",
		"..tttttttttttt..",
		".ttt...ww...ttt.",
		".tt...ww.....tt.",
		"......ww........",
		".....ww.........",
		"....ww..........",
		"...ww...........",
		"..ww............",
		".ww.............",
		".w..............",
		"................",
		"................",
		"................",
	],
	"ataque": [
		"................",
		".t..............",
		".tt.............",
		".ttt............",
		"..ttt...........",
		"...ttw..........",
		"....wrr.........",
		".....wrr........",
		"......ww........",
		".......ww.......",
		"........ww......",
		".........ww.....",
		"..........ww....",
		"...........ww...",
		"............w...",
		"................",
	],
	"interagir": [
		"................",
		"................",
		".....gg..gg.....",
		".....gg..gg.....",
		".....gg..gg.....",
		"..gg.gg..gg.gg..",
		"..gg........gg..",
		"..gg.gggggg.gg..",
		"....gggggggg....",
		"...gggggggggg...",
		"...gggggggggg...",
		"...gggggggggg...",
		"....gggggggg....",
		".....gggggg.....",
		"................",
		"................",
	],
}
# Seta: pixels explicitos (K contorno, w miolo, s sombra), ponta em 0,0.
const ARROW := [
	"K...............",
	"KK..............",
	"KwK.............",
	"KwwK............",
	"KwwsK...........",
	"KwwwsK..........",
	"KwwwwsK.........",
	"KwwwwKKKK.......",
	"KwKwsK..........",
	"KK.KwsK.........",
	"K..KwsK.........",
	"....KKK.........",
	"................",
	"................",
	"................",
	"................",
]

func _build(nome: String) -> Image:
	var im: Image = L.img(16, 16)
	if nome == "padrao":
		var key := {"K": "K", "w": "white", "s": "z_md"}
		for y in 16:
			for x in 16:
				var ch: String = ARROW[y][x]
				if ch != ".":
					L.put(im, x, y, key[ch])
		return im
	var m: Array = MASKS[nome]
	var fill := L.img(16, 16)
	for y in 16:
		assert(m[y].length() == 16, "%s linha %d" % [nome, y])
		for x in 16:
			if m[y][x] != ".":
				L.put(fill, x, y, "white")
	for y in 16:
		for x in 16:
			var ch: String = m[y][x]
			if ch == ".":
				continue
			var r: Array = RAMPS[ch]
			var luz: bool = not _on(m, x - 1, y) or not _on(m, x, y - 1)
			var sombra: bool = not _on(m, x + 1, y) or not _on(m, x, y + 1)
			var tom: int = 1
			if sombra and not luz:
				tom = 2
			elif luz and not sombra:
				tom = 0
			L.put(im, x, y, r[tom])
	L.outline(im)
	return im

func _on(m: Array, x: int, y: int) -> bool:
	return x >= 0 and y >= 0 and x < 16 and y < 16 and m[y][x] != "."

## Dessatura: luminancia -> cinzas da paleta; contorno vira cinza escuro (menos contraste).
func _fora(src: Image) -> Image:
	var o: Image = L.img(16, 16)
	for y in 16:
		for x in 16:
			var c := src.get_pixel(x, y)
			if c.a < 0.5:
				continue
			if c.to_html(false) == "141b1b":
				L.put(o, x, y, "s_xx")
				continue
			var lum := c.get_luminance()
			L.put(o, x, y, "g_pl" if lum > 0.7 else ("g_sg" if lum > 0.45 else "g_gr"))
	return o

func _up(i: Image, k: int) -> Image:
	var c := i.duplicate() as Image
	c.resize(16 * k, 16 * k, Image.INTERPOLATE_NEAREST)
	return c

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "cursores"
	var meta := {"grade": 16, "tamanhos": [16, 32, 48], "cursores": {}}
	var todos: Array = []
	for nome in ORDEM:
		var n := _build(nome)
		var f := _fora(n)
		todos.append([n, f])
		var hs: Array = HOTSPOT[nome]
		var h := {}
		for k in [1, 2, 3]:
			h[str(16 * k)] = [hs[0] * k, hs[1] * k]
			L.save_png_checked(_up(n, k), "%s/%s_%d.png" % [out, nome, 16 * k])
			L.save_png_checked(_up(f, k), "%s/%s_fora_%d.png" % [out, nome, 16 * k])
		meta["cursores"][nome] = {"hotspot_16": hs, "hotspot_por_tamanho": h,
			"arquivo": "%s_{tam}.png" % nome, "arquivo_fora": "%s_fora_{tam}.png" % nome}
	var jf := FileAccess.open(out + "/cursores.json", FileAccess.WRITE)
	jf.store_string(JSON.stringify(meta, "  ") + "\n")
	jf.close()
	_preview(todos, out + "/preview.png")
	quit()

func _bg(w: int, h: int, tipo: int) -> Image:
	var b := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var cores: Array = [["g_ol", "g_lt", "g_hi"], ["sand", "sand_hi", "sand_dk"], ["shal", "shal_hi", "deep_hi"]][tipo]
	for y in h:
		for x in w:
			var v: float = L.hash2(x / 4, y / 4, tipo + 7)
			b.set_pixel(x, y, L.P[cores[0] if v < 0.7 else (cores[1] if v < 0.88 else cores[2])])
	return b

func _preview(todos: Array, path: String) -> void:
	var cell := 80
	var w := cell * todos.size() * 2
	var h := cell * 3
	var p := Image.create(w, h, false, Image.FORMAT_RGBA8)
	for t in 3:
		p.blit_rect(_bg(w, cell, t), Rect2i(0, 0, w, cell), Vector2i(0, t * cell))
		for i in todos.size():
			for v in 2:
				var s4 := _up(todos[i][v], 4)
				var ox: int = (i * 2 + v) * cell + 8
				p.blend_rect(s4, Rect2i(0, 0, 64, 64), Vector2i(ox, t * cell + 8))
	p.save_png(path)
