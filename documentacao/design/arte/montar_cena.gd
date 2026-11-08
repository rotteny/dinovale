## Conferencia visual da escala nova (nao e asset do jogo). Monta a cena de 320x180 ampliada 4x,
## a folha do jogador em 1x e 4x e o teste de ladrilhamento do terreno. Da raiz do repositorio:
##   godot --headless --script documentacao/design/arte/montar_cena.gd -- <pasta de saida>
## Gera: cena.png (1280x720), jogador.png, ladrilho.png na pasta indicada.
extends SceneTree
const Lib = preload("arte_lib.gd")
var L = Lib.new()
const T := 16
const MAP := [
	"pppppppppppppppppppp",
	"pppppppppppppppppppp",
	"pppppppppppmmpppppmm",
	"pppmmmmmmmmmmmmpmmmm",
	"mmmmmmmccmmmmmmmmccc",
	"cccccccccccccccccccc",
	"ccccccccccccccbbcccc",
	"bbbbccbbbbbbbbbbbbbb",
	"sssbbbssbbbbbbssssss",
	"ssssssssssssssDsssss",
	"DDDDsssssssssDDDDDDD",
	"DDDDDDDDDDDDDDDDDDDD",
]
const TRAIL := [[6, 7], [6, 6], [6, 5], [7, 5], [7, 4], [8, 4], [8, 3], [9, 3], [9, 2]]
const RANK := {"D": 0, "s": 1, "b": 2, "c": 3, "m": 4, "p": 5}
var sheet: Image
var js: Dictionary
var outdir := ""

func _init() -> void:
	outdir = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(outdir)
	sheet = Image.load_from_file("game/assets/sprites/cenario/terreno.png")
	js = JSON.parse_string(FileAccess.get_file_as_string("game/assets/sprites/cenario/terreno.json"))
	scene()
	player_sheet()
	tiling()
	quit()

func rank_at(cx: int, cy: int) -> int:
	cx = clampi(cx, 0, 19); cy = clampi(cy, 0, MAP.size() - 1)
	return RANK[MAP[cy][cx]]

func tile_img(col: int, row: int) -> Image:
	return sheet.get_region(Rect2i(col * T, row * T, T, T))

func variant(r: int, cx: int, cy: int) -> Image:
	var h := L.hash2(cx, cy, 5 + r)
	var v := int(L.hash2(cx, cy, 9) * 8)
	if h > 0.82:
		v = 8 + int(L.hash2(cx, cy, 13) * 8)
	return tile_img(v, r)

func mask_of(inset: Callable, cx: int, cy: int) -> int:
	var m := 0
	var dirs := [[0, -1, 1], [1, -1, 2], [1, 0, 4], [1, 1, 8], [0, 1, 16], [-1, 1, 32], [-1, 0, 64], [-1, -1, 128]]
	for d in dirs:
		if inset.call(cx + d[0], cy + d[1]):
			m |= d[2]
	var r := m & (1 | 4 | 16 | 64)
	if (m & 2) and (m & 1) and (m & 4): r |= 2
	if (m & 8) and (m & 4) and (m & 16): r |= 8
	if (m & 32) and (m & 16) and (m & 64): r |= 32
	if (m & 128) and (m & 64) and (m & 1): r |= 128
	return r

func draw_layers(dst: Image, cols: int, rows: int, rankf: Callable) -> void:
	for cy in rows:
		for cx in cols:
			L.blit(dst, variant(0, cx, cy) if rankf.call(cx, cy) >= 0 else L.img(T, T), cx * T, cy * T)
	for r in range(1, 6):
		var nm: String = js["terrenos"][r]
		var map: Dictionary = js["conjuntos"][nm]["mascara_para_tile"]
		for cy in rows:
			for cx in cols:
				if rankf.call(cx, cy) < r:
					continue
				var inr := func(x: int, y: int) -> bool: return rankf.call(x, y) >= r
				var m := mask_of(inr, cx, cy)
				var im: Image
				if m == 255:
					im = variant(r, cx, cy)
				else:
					var p: Array = map[str(m)]
					im = tile_img(p[0], p[1])
				L.blit(dst, im, cx * T, cy * T)

func place(dst: Image, path: String, fx: int, fy: int, anchor := true) -> void:
	var im := Image.load_from_file(path)
	var ox := fx - im.get_width() / 2
	var oy := fy - im.get_height() + 1
	L.blit(dst, im, ox, oy)

func scene() -> void:
	var w := 320
	var h := 192
	var im: Image = L.img(w, h)
	draw_layers(im, 20, 12, func(x: int, y: int) -> int: return rank_at(x, y))
	# trilha natural (camada acima do chao)
	var tmap: Dictionary = js["conjuntos"]["trilha"]["mascara_para_tile"]
	var tset := {}
	for t in TRAIL:
		tset[Vector2i(t[0], t[1])] = true
	for t in TRAIL:
		var inr := func(x: int, y: int) -> bool: return tset.has(Vector2i(x, y))
		var m := mask_of(inr, t[0], t[1])
		var p: Array = tmap[str(m)]
		L.blit(im, tile_img(p[0], p[1]), t[0] * T, t[1] * T)
	# objetos e jogadores ordenados por y do pe
	var objs := []
	var R := "game/assets/sprites/recursos/"
	var C := "game/assets/sprites/cenario/"
	objs.append([R + "tree_collect_80.png", 36, 76])
	objs.append([R + "tree_collect_80.png", 268, 80])
	objs.append([R + "tree_collect_80.png", 300, 104])
	objs.append([R + "tree_collect_80.png", 160, 104])
	objs.append([R + "rock_stone_32.png", 150, 40])
	objs.append([R + "rock_ore_32.png", 178, 34])
	objs.append([R + "rock_stone_32.png", 100, 104])
	objs.append([C + "formacao_a.png", 250, 52])
	objs.append([C + "formacao_b.png", 90, 46])
	objs.append([C + "formacao_c.png", 232, 124])
	var pl := Image.load_from_file("game/assets/sprites/jogador/jogador.png")
	var players := [[206, 46, 2, 3], [112, 72, 0, 4], [62, 94, 3, 2], [208, 126, 1, 5], [24, 124, 0, 7]]
	# (x pe, y pe, direcao, coluna): pedreira, mata, campina, praia ...
	var order := []
	for o in objs:
		order.append({"y": o[2], "o": o})
	for p in players:
		order.append({"y": p[1], "p": p})
	order.sort_custom(func(a, b): return a["y"] < b["y"])
	for e in order:
		if e.has("o"):
			place(im, e["o"][0], e["o"][1], e["o"][2])
		else:
			var p: Array = e["p"]
			var fr := pl.get_region(Rect2i(p[3] * 16, p[2] * 32, 16, 32))
			L.blit(im, fr, p[0] - 8, p[1] - 31)
	var crop := im.get_region(Rect2i(0, 0, 320, 180))
	crop.resize(1280, 720, Image.INTERPOLATE_NEAREST)
	crop.save_png(outdir + "/cena.png")

func player_sheet() -> void:
	var pl := Image.load_from_file("game/assets/sprites/jogador/jogador.png")
	var w := 640
	var im := Image.create(w, 128 + 12 + 512, false, Image.FORMAT_RGBA8)
	im.fill(Color("#adbc3a"))
	var bg := pl.duplicate() as Image
	im.blend_rect(pl, Rect2i(0, 0, 160, 128), Vector2i(4, 4))
	var big := pl.duplicate() as Image
	big.resize(640, 512, Image.INTERPOLATE_NEAREST)
	im.blend_rect(big, Rect2i(0, 0, 640, 512), Vector2i(0, 140))
	im.save_png(outdir + "/jogador.png")

func tiling() -> void:
	# cada terreno em bloco 10x6 com variacoes sorteadas (4 por linha), ampliado 2x
	var cols := 10
	var rows := 6
	var pw := cols * T + 4
	var ph := rows * T + 4
	var im := Image.create(4 * pw, 2 * ph, false, Image.FORMAT_RGBA8)
	im.fill(Color("#141b1b"))
	for t in 7:
		for cy in rows:
			for cx in cols:
				var v := int(L.hash2(cx, cy, 31 + t) * 8)
				if L.hash2(cx, cy, 3 + t) > 0.8:
					v = 8 + int(L.hash2(cx, cy, 4) * 8)
				im.blend_rect(tile_img(v, t), Rect2i(0, 0, T, T), Vector2i((t % 4) * pw + cx * T, (t / 4) * ph + cy * T))
	im.resize(im.get_width() * 2, im.get_height() * 2, Image.INTERPOLATE_NEAREST)
	im.save_png(outdir + "/ladrilho.png")
