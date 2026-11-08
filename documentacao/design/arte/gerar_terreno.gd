## Gerador do tileset de terreno da ilha (tile 16x16), arte propria, CC BY 4.0, sem IA.
##   godot --headless --script documentacao/design/arte/gerar_terreno.gd
## Saida: game/assets/sprites/cenario/terreno.png (256x400) e terreno.json (mapa de tiles para o SORA).
##
## Terrenos, do mais baixo para o mais alto (ordem de empilhar em camadas):
##   0 agua funda, 1 agua rasa, 2 praia (areia), 3 Campina, 4 Mata-baixa, 5 Pedreira, 6 trilha (so por cima).
## Linhas 0 a 6: 16 variacoes de tile cheio por terreno (colunas 0-7 lisas, 8-15 com detalhe).
## Linhas 7 a 24: 6 conjuntos "blob" de 47 tiles (agua rasa, praia, Campina, Mata-baixa, Pedreira, trilha),
##   2 conjuntos por faixa de 6 linhas (8 colunas cada). Cada conjunto desenha o terreno so no seu formato:
##   FORA e transparente, entao o terreno de baixo aparece. Empilhe uma camada por terreno: a camada do terreno T
##   recebe o blob dos vizinhos com rank >= T. O tile de miolo (mascara 255) e a variacao 0 do tile cheio.
## Mascara de 8 bits dos vizinhos que tambem pertencem ao conjunto:
##   N=1 NE=2 L=4 SE=8 S=16 SO=32 O=64 NO=128; diagonal so conta com as duas arestas vizinhas presentes.
## A textura de cada terreno e periodica em 16 px: tiles adjacentes (inclusive agua) ladrilham sem emenda.
extends SceneTree
const Lib = preload("arte_lib.gd")
var L = Lib.new()
const OUT := "game/assets/sprites/cenario/"
const T := 16
const NAMES := ["agua_funda", "agua_rasa", "praia", "campina", "mata_baixa", "pedreira", "trilha"]
const RING := ["", "shal_hi", "foam", "g_hi", "g_md", "s_dk", "w_md"]
const INSET := [0, 2.0, 2.0, 2.0, 2.0, 2.0, 2.0]
const RAD := 5.0
const WA := [0, 0, 1, 1, 1, 0, 0, 0, 1, 1, 0, 0, 0, 1, 1, 0]
const WB := [1, 0, 0, 0, 1, 1, 0, 0, 0, 1, 1, 1, 0, 0, 0, 1]

var tex := {}   # "t_v" -> Array[16][16] de nomes de cor
var masks47: Array = []

func _init() -> void:
	canon_masks()
	for t in 7:
		for v in 16:
			tex["%d_%d" % [t, v]] = make_tex(t, v)
	var sheet: Image = L.img(16 * T, 25 * T)
	for t in 7:
		for v in 16:
			L.blit(sheet, tile_full(t, v), v * T, t * T)
	var sets := [1, 2, 3, 4, 5, 6]
	var js := {"tile": T, "colunas_folha": 16, "linhas_folha": 25, "terrenos": NAMES, "variacoes_cheias": 16,
		"linha_variacoes": "linha = indice do terreno; colunas 0-7 lisas, 8-15 com detalhe",
		"mascara": "N=1 NE=2 L=4 SE=8 S=16 SO=32 O=64 NO=128 (diagonal so com as duas arestas)", "conjuntos": {}}
	for k in sets.size():
		var t: int = sets[k]
		var ox := (k % 2) * 8
		var oy := 7 + (k / 2) * 6
		var map := {}
		for i in masks47.size():
			var m: int = masks47[i]
			L.blit(sheet, tile_blob(t, m), (ox + i % 8) * T, (oy + i / 8) * T)
			map[str(m)] = [ox + i % 8, oy + i / 8]
		js["conjuntos"][NAMES[t]] = {"rank": t, "mascara_para_tile": map}
	L.save_png_checked(sheet, OUT + "terreno.png")
	var f := FileAccess.open(OUT + "terreno.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(js, "\t"))
	f.close()
	quit()

# ---------------------------------------------------------------- mascaras blob
func canon(m: int) -> int:
	var r := m & (1 | 4 | 16 | 64)
	if (m & 2) and (m & 1) and (m & 4): r |= 2
	if (m & 8) and (m & 4) and (m & 16): r |= 8
	if (m & 32) and (m & 16) and (m & 64): r |= 32
	if (m & 128) and (m & 64) and (m & 1): r |= 128
	return r

func canon_masks() -> void:
	var seen := {}
	for m in 256:
		seen[canon(m)] = true
	masks47 = seen.keys()
	masks47.sort()
	assert(masks47.size() == 47)

# ---------------------------------------------------------------- texturas (16x16 periodicas)
func make_tex(t: int, v: int) -> Array:
	var a := []
	var base: String = ["deep", "shal", "sand", "g_lt", "g_hi", "s_md", "w_hi"][t]
	for y in T:
		var row := []
		for x in T:
			row.append(base)
		a.append(row)
	var sd := t * 101 + v * 17 + 3
	var kind := (v - 8) % 4 if v >= 8 else -1
	match t:
		0: tex_deep(a, sd, kind)
		1: tex_shallow(a, sd, kind)
		2: tex_sand(a, sd, kind)
		3: tex_campina(a, sd, kind)
		4: tex_mata(a, sd, kind)
		5: tex_pedreira(a, sd, kind)
		6: tex_trilha(a, sd, kind)
	return a

func sp(a: Array, x: int, y: int, c: String) -> void:
	if x >= 0 and y >= 0 and x < T and y < T:
		a[y][x] = c

func rnd(sd: int, i: int) -> float:
	return L.hash2(i, i * 7 + 1, sd)

func scatter(a: Array, sd: int, n: int, c: String, margin := 1) -> void:
	for i in n:
		var x := margin + int(rnd(sd, i * 2) * (T - 2 * margin))
		var y := margin + int(rnd(sd, i * 2 + 1) * (T - 2 * margin))
		sp(a, x, y, c)

func tex_deep(a: Array, sd: int, kind: int) -> void:
	for r in 4:
		var y := r * 4 + 1 + int(rnd(sd, r) * 2)
		var x := int(rnd(sd, r + 10) * 9) + 1
		for k in 3:
			sp(a, x + k, y, "deep_hi")
		sp(a, x + 1, y + 1, "deep_dk")
		sp(a, x + 2, y + 1, "deep_dk")
	if kind >= 0:
		sp(a, 3 + kind * 3, 4, "shal"); sp(a, 12 - kind * 2, 11, "shal")
		scatter(a, sd, 2, "deep_dk")

func tex_shallow(a: Array, sd: int, kind: int) -> void:
	for r in 4:
		var y := r * 4 + 1 + int(rnd(sd, r) * 2)
		var x := int(rnd(sd, r + 10) * 9) + 1
		for k in 3:
			sp(a, x + k, y, "shal_hi")
		sp(a, x + 1, y + 1, "shal_md"); sp(a, x + 2, y + 1, "shal_md")
	scatter(a, sd + 5, 2, "foam2")
	if kind >= 0:
		sp(a, 4 + kind * 2, 3, "foam"); sp(a, 11 - kind, 9, "foam")
		if kind % 2 == 1:
			sp(a, 7, 13, "deep_hi"); sp(a, 8, 13, "deep_hi")

func tex_sand(a: Array, sd: int, kind: int) -> void:
	scatter(a, sd, 9, "sand_dk")
	scatter(a, sd + 9, 3, "sand_hi")
	if kind == 0:  # concha
		sp(a, 7, 7, "foam"); sp(a, 8, 7, "foam"); sp(a, 7, 8, "pink"); sp(a, 8, 8, "sand_dk")
	elif kind == 1:  # pedrinhas
		sp(a, 4, 9, "s_hi"); sp(a, 5, 9, "s_hi"); sp(a, 4, 10, "s_dk"); sp(a, 5, 10, "s_dk"); sp(a, 11, 4, "s_hi"); sp(a, 11, 5, "s_dk")
	elif kind == 2:  # alga seca
		for p in [[5, 6], [6, 6], [7, 7], [8, 7], [9, 6]]:
			sp(a, p[0], p[1], "g_md")
		sp(a, 8, 6, "g_dk")
	elif kind == 3:  # marolas na areia
		for p in [[2, 4], [3, 4], [4, 4], [9, 11], [10, 11], [11, 11], [12, 11]]:
			sp(a, p[0], p[1], "sand_dk")

func tex_campina(a: Array, sd: int, kind: int) -> void:
	scatter(a, sd, 10, "g_ol")
	for i in 4:
		var x := 2 + int(rnd(sd + 3, i * 2) * 11)
		var y := 3 + int(rnd(sd + 3, i * 2 + 1) * 11)
		sp(a, x, y, "g_hi"); sp(a, x - 1, y - 1, "g_hi"); sp(a, x + 1, y - 1, "g_hi")
	if kind == 0:  # flores rosa
		for p in [[4, 5], [11, 10], [8, 13]]:
			sp(a, p[0], p[1], "pink"); sp(a, p[0] + 1, p[1], "white")
	elif kind == 1:  # flores amarelas
		for p in [[10, 4], [3, 11]]:
			sp(a, p[0], p[1], "yellow"); sp(a, p[0], p[1] + 1, "g_hi")
	elif kind == 2:  # pedras
		sp(a, 6, 8, "s_hi"); sp(a, 7, 8, "s_hi"); sp(a, 6, 9, "s_dk"); sp(a, 7, 9, "s_dk")
	elif kind == 3:  # touceira
		for p in [[7, 6], [8, 6], [6, 7], [9, 7], [7, 7], [8, 7]]:
			sp(a, p[0], p[1], "g_md")
		sp(a, 7, 5, "g_hi"); sp(a, 8, 5, "g_hi")

func tex_mata(a: Array, sd: int, kind: int) -> void:
	scatter(a, sd, 8, "g_md")
	scatter(a, sd + 4, 3, "g_ol")
	for i in 3:
		var x := 2 + int(rnd(sd + 3, i * 2) * 11)
		var y := 3 + int(rnd(sd + 3, i * 2 + 1) * 11)
		sp(a, x, y, "g_md"); sp(a, x + 1, y, "g_md")
	if kind == 0:  # folhas secas
		sp(a, 5, 6, "clay"); sp(a, 6, 6, "clay"); sp(a, 6, 7, "orange"); sp(a, 11, 11, "clay"); sp(a, 10, 12, "w_md")
	elif kind == 1:  # cogumelo
		sp(a, 9, 8, "f_red"); sp(a, 10, 8, "f_red"); sp(a, 9, 9, "foam"); sp(a, 10, 9, "foam")
	elif kind == 2:  # galho
		for p in [[4, 10], [5, 10], [6, 9], [7, 9]]:
			sp(a, p[0], p[1], "w_md")
		sp(a, 4, 11, "w_dk")
	elif kind == 3:  # musgo escuro
		for p in [[6, 5], [7, 5], [8, 5], [6, 6], [7, 6], [10, 11], [11, 11]]:
			sp(a, p[0], p[1], "g_dk")

func tex_pedreira(a: Array, sd: int, kind: int) -> void:
	scatter(a, sd, 8, "s_dk")
	scatter(a, sd + 4, 6, "s_hi")
	if kind == 0:  # seixos
		sp(a, 5, 6, "s_hi"); sp(a, 6, 6, "s_hi"); sp(a, 5, 7, "s_xx"); sp(a, 6, 7, "s_xx"); sp(a, 7, 7, "s_xx")
	elif kind == 1:  # rachadura
		for p in [[3, 4], [4, 5], [5, 5], [6, 6], [7, 7], [8, 7], [9, 8], [10, 9]]:
			sp(a, p[0], p[1], "s_xx")
	elif kind == 2:  # cascalho claro
		for p in [[9, 3], [10, 3], [4, 11], [5, 11], [5, 12], [12, 10]]:
			sp(a, p[0], p[1], "s_hi")
		sp(a, 9, 4, "s_dk"); sp(a, 10, 4, "s_dk")
	elif kind == 3:  # mancha escura
		for p in [[6, 5], [7, 5], [5, 6], [6, 6], [7, 6], [8, 6], [6, 7], [7, 7]]:
			sp(a, p[0], p[1], "s_dk")

func tex_trilha(a: Array, sd: int, kind: int) -> void:
	scatter(a, sd, 9, "w_md")
	scatter(a, sd + 2, 4, "ring2")
	if kind == 0:
		sp(a, 5, 8, "s_hi"); sp(a, 6, 8, "s_hi"); sp(a, 5, 9, "s_dk")
	elif kind == 1:
		for p in [[3, 5], [4, 5], [10, 11], [11, 11]]:
			sp(a, p[0], p[1], "w_dk")
	elif kind == 2:
		for p in [[7, 3], [7, 4], [8, 4]]:
			sp(a, p[0], p[1], "g_md")

# ---------------------------------------------------------------- tiles
func tile_full(t: int, v: int) -> Image:
	var im: Image = L.img(T, T)
	var a: Array = tex["%d_%d" % [t, v]]
	for y in T:
		for x in T:
			L.put(im, x, y, a[y][x])
	return im

func region(m: int) -> Array:
	# retorna, para cada (x,y) em [-1,16], se pertence ao blob (true/false)
	var cells := {}
	var bits := {Vector2i(1, 0): 1, Vector2i(2, 0): 2, Vector2i(2, 1): 4, Vector2i(2, 2): 8, Vector2i(1, 2): 16, Vector2i(0, 2): 32, Vector2i(0, 1): 64, Vector2i(0, 0): 128}
	for c in bits:
		cells[c] = (m & bits[c]) != 0
	cells[Vector2i(1, 1)] = true
	return [cells]

func tile_blob(t: int, m: int) -> Image:
	var cells: Dictionary = region(m)[0]
	var e: float = INSET[t]
	# D e limiar para q em [-R-1, 16+R+1)
	var lo := -int(RAD) - 2
	var hi := T + int(RAD) + 2
	var inE := {}
	for y in range(lo, hi):
		for x in range(lo, hi):
			var X := x + T
			var Y := y + T
			var cx := X / T
			var cy := Y / T
			var d := 999.0
			for c in cells:
				if cells[c]:
					continue
				var dx := maxf(maxf(c.x * T - (X + 0.5), 0.0), (X + 0.5) - (c.x * T + T))
				var dy := maxf(maxf(c.y * T - (Y + 0.5), 0.0), (Y + 0.5) - (c.y * T + T))
				d = minf(d, sqrt(dx * dx + dy * dy))
			var xm := posmod(x, T)
			var ym := posmod(y, T)
			var wob: float = 0.55 * (WA[xm] + WB[ym])
			if d >= e + RAD + wob:
				inE[Vector2i(x, y)] = true
	var A := {}
	var r := int(RAD)
	for y in range(-1, T + 1):
		for x in range(-1, T + 1):
			var ok := false
			for dy in range(-r, r + 1):
				for dx in range(-r, r + 1):
					if dx * dx + dy * dy <= RAD * RAD and inE.has(Vector2i(x + dx, y + dy)):
						ok = true
						break
				if ok:
					break
			if ok:
				A[Vector2i(x, y)] = true
	var im: Image = L.img(T, T)
	var ring: String = RING[t]
	var tx: Array = tex["%d_0" % t]
	for y in T:
		for x in T:
			if not A.has(Vector2i(x, y)):
				continue
			var edge := false
			for d in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]:
				if not A.has(Vector2i(x + d.x, y + d.y)):
					edge = true
			var c: String = tx[y][x]
			if edge:
				c = ring
				if t == 2:  # espuma quebrada na beira da areia
					c = "foam" if L.hash2(posmod(x, T), posmod(y, T), 77) < 0.65 else "foam2"
			L.put(im, x, y, c)
	return im
