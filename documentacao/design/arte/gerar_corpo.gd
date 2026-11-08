## Gerador do jogador CAIDO, do CORPO com bolsa de itens e do icone 8x8 de corpo.
## Arte propria, CC BY 4.0, sem IA. Da raiz do repositorio:
##   godot --headless --script documentacao/design/arte/gerar_corpo.gd -- <pasta_de_saida>
## Saida: caido.png (2 quadros 32x32, respiracao), corpo.png (2 quadros 32x32, brilho),
##        icone_corpo.png (8x8), corpo.json, preview-corpo-4x.png.
## Pose unica, de lado (cabeca a esquerda, de costas no chao). Direita/diagonais da direita: flip_h.
## Paleta: so cores do pacote (conferida em save_png_checked). Contorno #141b1b gerado por passada
## automatica, alfa 0/1, luz de cima a esquerda, sem gradiente.
extends SceneTree
const Lib = preload("arte_lib.gd")
var L = Lib.new()
const FW := 32
const FH := 32
const JOGADOR := "game/assets/sprites/jogador/jogador.png"

# Tons de cada material: [claro, medio, escuro]
const VIVO := {"skin": ["sk_hi", "sk_md", "sk_dk"], "hair": ["h_hi", "h_md", "h_dk"], "cloth": ["g_md", "g_dk", "g_dk"], "eye": "h_xx"}
const MORTO := {"skin": ["sk_xx", "w_xx", "h_dk"], "hair": ["h_dk", "h_xx", "h_xx"], "cloth": ["g_dk", "g_dk", "o_dk"], "eye": "K"}

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("uso: godot --headless --script documentacao/design/arte/gerar_corpo.gd -- <pasta_de_saida>")
		quit(1)
		return
	var out: String = args[0].trim_suffix("/") + "/"
	var cai: Array = [body(VIVO, 0, 0, 0), body(VIVO, 1, 0, 0)]
	var cor: Array = []
	for f in 2:
		var im: Image = L.img(FW, FH)
		blit(im, body(MORTO, 0, 0, -8))
		bag(im)
		sparkle(im, f)
		cor.append(im)
	var ico: Image = icon()
	L.save_png_checked(sheet(cai), out + "caido.png")
	L.save_png_checked(sheet(cor), out + "corpo.png")
	L.save_png_checked(ico, out + "icone_corpo.png")
	var d := {
		"quadro": [FW, FH],
		"ancora": "base do quadro; o corpo apoiado no chao em y=29, contorno em y=30",
		"direcoes": "pose unica de lado, cabeca a esquerda; para direita, baixo-direita e cima-direita use flip_h=true; as demais usam sem espelho",
		"arquivos": {
			"caido.png": {"colunas": 2, "linhas": 1, "animacoes": {"respirar": {"colunas": [0, 1], "fps": 1.0, "loop": true}}},
			"corpo.png": {"colunas": 2, "linhas": 1, "animacoes": {"brilho": {"colunas": [0, 1], "fps": 2.0, "loop": true}}, "ocupa_px": "x 0-29, y 9-30"},
			"icone_corpo.png": {"quadro": [8, 8], "colunas": 1, "nota": "caveira; legivel como marcador de corpo no minimapa"},
		},
		"nota_tamanho": "a folha atual do jogador tem quadro 32x32 (nao 16x32); este gerador segue o 32x32 real",
		"gerador": "documentacao/design/arte/gerar_corpo.gd",
	}
	var f := FileAccess.open(out + "corpo.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(d, "\t") + "\n")
	f.close()
	preview(cai, cor, ico, out + "preview-corpo-4x.png")
	print("ok: ", out)
	quit()

func sheet(frames: Array) -> Image:
	var s: Image = L.img(FW * frames.size(), FH)
	for i in frames.size():
		blit(s, frames[i], i * FW)
	return s

func blit(dst: Image, src: Image, ox := 0) -> void:
	for y in src.get_height():
		for x in src.get_width():
			var c := src.get_pixel(x, y)
			if c.a > 0.5:
				dst.set_pixel(x + ox, y, c)

## Pinta pixel por pixel numa mascara de cor: t 0 claro, 1 medio, 2 escuro.
func put3(i: Image, x: int, y: int, tones: Array, t: int) -> void:
	L.put(i, x, y, tones[t])

## Passada de contorno: todo vizinho (4) transparente de pixel opaco vira K.
func outline(i: Image) -> void:
	var m := i.duplicate() as Image
	for y in FH:
		for x in FW:
			if m.get_pixel(x, y).a < 0.5:
				for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					if L.solid(m, x + d.x, y + d.y):
						i.set_pixel(x, y, L.P["K"])
						break

## Jogador deitado de costas, de lado: cabeca esquerda, pernas direita.
## b = quadro de respiracao (0 normal, 1 peito subido 1 px). dy desloca na vertical.
func body(M: Dictionary, b: int, dx: int, dy: int) -> Image:
	var i: Image = L.img(FW, FH)
	var c := 24 + dy           # linha central do corpo
	var x0 := 1 + dx
	var sk: Array = M["skin"]
	var hr: Array = M["hair"]
	var cl: Array = M["cloth"]
	# tronco: ombros largos, cintura estreita (x 9-19), faixa vertical por coluna
	var half := {9: 5, 10: 5, 11: 5, 12: 5, 13: 4, 14: 4, 15: 4, 16: 3, 17: 3, 18: 3, 19: 3}
	for k in half:
		var h: int = half[k]
		var top: int = c - h
		if b == 1 and k >= 11 and k <= 15:
			top -= 1       # peito sobe 1 px
		for y in range(top, c + h):
			var t := 0 if y <= top + 1 else (2 if y >= c + h - 2 else 1)
			put3(i, x0 + k, y, sk, t)
	# braco de baixo, junto ao corpo, e mao
	for k in range(10, 17):
		put3(i, x0 + k, c + 2, sk, 1)
		put3(i, x0 + k, c + 3, sk, 2)
	put3(i, x0 + 17, c + 3, sk, 1)
	# tanga (x 17-21)
	for k in range(17, 22):
		for y in range(c - 3, c + 3):
			put3(i, x0 + k, y, cl, 0 if y <= c - 2 else (1 if y < c + 1 else 2))
	L.pts(i, [[x0 + 18, c - 1], [x0 + 20, c]], cl[0])
	# pernas: duas, com 1 px de vao (x 22-29)
	for k in range(22, 28):
		for y in range(c - 3, c):
			put3(i, x0 + k, y, sk, 0 if y == c - 3 else 1)
		for y in range(c + 1, c + 4):
			put3(i, x0 + k, y, sk, 1 if y == c + 1 else 2)
	L.pts(i, [[x0 + 28, c - 2], [x0 + 28, c + 2]], sk[2])
	# cabeca (circulo ~9 px, x 0-8)
	for y in range(c - 6, c + 6):
		for x in range(x0 - 1, x0 + 10):
			var ddx := x + 0.5 - (x0 + 4.5)
			var ddy := y + 0.5 - float(c)
			if ddx * ddx + ddy * ddy <= 22.0:
				var s2 := ddx + ddy
				put3(i, x, y, sk, 0 if s2 < -2.5 else (1 if s2 < 3.0 else 2))
				# cabelo: topo e lado esquerdo
				if ddy < -2.0 or ddx < -2.4:
					put3(i, x, y, hr, 0 if (ddy < -3.4 and ddx < 0) else (1 if ddy < 0 else 2))
	# olho fechado e boca (rosto virado para cima)
	L.pts(i, [[x0 + 4, c], [x0 + 5, c], [x0 + 7, c]], M["eye"])
	L.pts(i, [[x0 + 6, c + 2], [x0 + 5, c + 2]], sk[2])
	outline(i)
	return i

## Trouxa de couro amarrada, ao lado do corpo (x 17-27, y 20-29).
func bag(i: Image) -> void:
	var cx := 22.0
	var cy := 25.0
	var tone := ["w_hi", "w_md", "w_dk"]
	var tmp: Image = L.img(FW, FH)
	for y in range(19, 30):
		for x in range(15, 29):
			var ddx := (x + 0.5 - cx) / 6.0
			var ddy := (y + 0.5 - cy) / 4.6
			if ddx * ddx + ddy * ddy <= 1.0:
				var s := (x + 0.5 - cx) * 0.55 + (y + 0.5 - cy)
				L.put(tmp, x, y, tone[0] if s < -2.2 else (tone[1] if s < 1.6 else tone[2]))
	# pescoco amarrado e ponta franzida
	L.rect(tmp, 21, 20, 3, 2, "w_md")
	L.put(tmp, 20, 19, "w_hi")
	L.put(tmp, 24, 19, "w_md")
	L.put(tmp, 22, 18, "w_hi")
	L.put(tmp, 23, 18, "w_md")
	L.rect(tmp, 21, 21, 3, 1, "ring2")   # corda
	L.put(tmp, 22, 21, "cut")
	# bojo de item (pedra clara) e costura
	L.pts(tmp, [[19, 25], [20, 25], [19, 26]], "w_br")
	L.pts(tmp, [[24, 27], [25, 27]], "w_xx")
	outline(tmp)
	blit(i, tmp)

## Brilho de 2 quadros: cruz de 3x3 alterna entre dois pontos; o outro vira ponto simples.
func sparkle(i: Image, f: int) -> void:
	var a := Vector2i(26, 20)
	var b := Vector2i(16, 27)
	var big: Vector2i = a if f == 0 else b
	var small: Vector2i = b if f == 0 else a
	L.put(i, big.x, big.y, "white")
	L.pts(i, [[big.x - 1, big.y], [big.x + 1, big.y], [big.x, big.y - 1], [big.x, big.y + 1]], "yellow")
	L.put(i, small.x, small.y, "yellow")

func icon() -> Image:
	var map := [
		".KKKKKK.",
		"KwwwwwwK",
		"KwKwwKwK",
		"KwKwwKwK",
		".KwwwwK.",
		".KwKKwK.",
		".KwwwwK.",
		"..KKKK..",
	]
	var key := {"K": "K", "w": "z_hi"}
	var im: Image = L.img(8, 8)
	for y in 8:
		for x in 8:
			var ch: String = map[y][x]
			if ch != ".":
				L.put(im, x, y, key[ch])
	# sombra do lado direito (luz a esquerda)
	L.pts(im, [[6, 1], [6, 2], [6, 3], [5, 4], [5, 6]], "z_md")
	return im

func preview(cai: Array, cor: Array, ico: Image, path: String) -> void:
	var ref := Image.load_from_file(JOGADOR)
	var bgs := [["g_ol", "g_lt", "g_md"], ["sand", "sand_hi", "sand_dk"]]
	var cellw := 40
	var rowh := 40
	var out: Image = L.img(cellw * 8, rowh * 2)
	for r in 2:
		var bg: Array = bgs[r]
		for y in rowh:
			for x in cellw * 8:
				L.put(out, x, r * rowh + y, bg[0])
		# tufos/graos fixos, so para dar leitura de chao
		for k in 60:
			var px := (k * 37 + r * 11) % (cellw * 8)
			var py := (k * 23 + r * 7) % rowh
			L.put(out, px, r * rowh + py, bg[1] if k % 3 else bg[2])
		var seq: Array = []
		var base := r * rowh + 4
		var refq: Image = ref.get_region(Rect2i(0, 0, 32, 32)) if ref else L.img(32, 32)
		var items: Array = [refq, cai[0], cai[1], mirror(cai[0]), cor[0], cor[1], mirror(cor[0])]
		for k in items.size():
			stampimg(out, items[k], k * cellw + 4, base)
		stampimg(out, ico, 7 * cellw + 16, base + 12)
	out.resize(out.get_width() * 4, out.get_height() * 4, Image.INTERPOLATE_NEAREST)
	out.save_png(path)

func stampimg(dst: Image, src: Image, ox: int, oy: int) -> void:
	for y in src.get_height():
		for x in src.get_width():
			var c := src.get_pixel(x, y)
			if c.a > 0.5:
				dst.set_pixel(ox + x, oy + y, c)

func mirror(src: Image) -> Image:
	var m := src.duplicate() as Image
	m.flip_x()
	return m
