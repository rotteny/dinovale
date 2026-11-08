## Gerador do Paquicefalo por PARTES (corpo, pescoco, cabeca com domo, cauda, pernas, bracos).
## Arte propria, CC BY 4.0, sem IA e sem recorte de terceiros. Da raiz do repositorio:
##   godot --headless --script documentacao/design/arte/gerar_paquicefalo.gd -- <pasta de saida>
## Saida na pasta: paquicefalo.png (352x256, quadro 32x32, 8 direcoes: linhas 0-3 como a folha atual, 4-7 as diagonais), paquicefalo.json
## (o jogo nao usa sprite de domado: "sem sprite novo", GDD 6.11; o parametro `tame` fica no codigo, desligado).
## NAO grava em game/assets: o dono aprova antes de trocar.
##
## Como o volume e feito: cada parte e um elipsoide (ou corrente de circulos) com NORMAL por pixel; a luz vem de
## cima e levemente da esquerda (a mesma do guia ESTILO.md) e o produto normal x luz e cortado em 4 tons duros
## (sem gradiente, sem dithering). A parte que fica por cima ganha 1 px de tom escuro do proprio material na
## borda com a parte de baixo (separa as partes sem encher o desenho de contorno preto). So o contorno externo
## e #141b1b. A vista da direita e a da esquerda espelhada na GEOMETRIA, mas sombreada de novo com a luz a esquerda.
##
## Layout (igual nas cinco especies): colunas 0-1 parado, 2-5 andar, 6-8 golpe, 9 dormindo, 10 morto;
## linhas down, up, left, right, down_left, down_right, up_left, up_right. Pes em y=30, contorno em y=31.
## As 4 diagonais (linhas 4-7) sao montadas em 3D (`render3d.gd`, mesmas partes e poses, luz a esquerda);
## dormindo e morto nas diagonais reusam o quadro deitado de lado (esquerda para *_left, direita para *_right).
extends SceneTree
const Lib = preload("arte_lib.gd")
const R3 = preload("render3d.gd")
var L = Lib.new()
var R = R3.new()

const S := 32
const COLS := 11
const LIGHT := Vector3(-0.45, -0.6, 0.66)
const CUTS := [0.30, 0.58, 0.86]  # limites dos 4 tons

# rampas: do mais escuro ao mais claro (nomes de arte_lib.C, todos da paleta do pacote)
const BACK := ["s_xx", "w_dk", "w_br", "orange"]  # mais saturado e contrastado que a v1 (que ficava palida)
const BELLY := ["w_hi", "sand_dk", "sand", "cut"]
const DOME := ["w_hi", "ring2", "sand", "cut"]  # osso/creme (calota do paquicefalo), nao capacete azul
const FACE := ["s_dk", "w_dk", "w_br", "clay"]
const FACE_F := ["w_dk", "w_br", "clay", "sk_hi"]  # rosto de frente mais claro: olhos e focinho precisam ler
const DORSAL := ["s_xx", "s_dk", "w_dk", "clay"]
const CLAW := ["s_xx", "s_dk", "s_md", "s_hi"]

# ------------------------------------------------------------------ formas (devolvem pixels com normal)
## Elipsoide com rotacao; cada item: [x, y, intensidade, nx, ny]
func ell(cx: float, cy: float, rx: float, ry: float, rot: float = 0.0) -> Array:
	var out := []
	var cs := cos(rot)
	var sn := sin(rot)
	var r := maxf(rx, ry)
	for y in range(int(floor(cy - r)), int(ceil(cy + r)) + 1):
		for x in range(int(floor(cx - r)), int(ceil(cx + r)) + 1):
			var dx := x + 0.5 - cx
			var dy := y + 0.5 - cy
			var lx := (dx * cs + dy * sn) / rx
			var ly := (-dx * sn + dy * cs) / ry
			var d2 := lx * lx + ly * ly
			if d2 > 1.0:
				continue
			var nz := sqrt(1.0 - d2)
			var nxw := lx * cs - ly * sn
			var nyw := lx * sn + ly * cs
			out.append([x, y, Vector3(nxw, nyw, nz).dot(LIGHT.normalized()), nxw, nyw])
	return out

## Corrente de circulos [cx, cy, r]: cada pixel pega o circulo em que esta mais ao centro.
func chain(cs: Array) -> Array:
	var best := {}
	for c in cs:
		var r: float = c[2]
		for y in range(int(floor(c[1] - r)), int(ceil(c[1] + r)) + 1):
			for x in range(int(floor(c[0] - r)), int(ceil(c[0] + r)) + 1):
				var dx: float = (x + 0.5 - c[0]) / r
				var dy: float = (y + 0.5 - c[1]) / r
				var d2 := dx * dx + dy * dy
				if d2 > 1.0:
					continue
				var k := Vector2i(x, y)
				if not best.has(k) or best[k][0] > d2:
					best[k] = [d2, dx, dy]
	var out := []
	for k in best:
		var b: Array = best[k]
		var nz := sqrt(maxf(0.0, 1.0 - b[0]))
		out.append([k.x, k.y, Vector3(b[1], b[2], nz).dot(LIGHT.normalized()), b[1], b[2]])
	return out

## Perna digitigrada: quadril -> joelho (dobrado para tras) -> tornozelo; o pe e quem recebe a pose.
func leg(hx: float, hy: float, fx: float, fy: float, side_f: float, thick: float) -> Array:
	var kx := (hx + fx) * 0.5 - side_f * 1.6
	var ky := (hy + fy) * 0.5
	return chain([[hx, hy, thick], [(hx + kx) * 0.5, (hy + ky) * 0.5, thick * 0.78], [kx, ky, thick * 0.62],
		[(kx + fx) * 0.5, (ky + fy) * 0.5, 1.45], [fx, fy, 1.4]])

# ------------------------------------------------------------------ montagem do quadro
class Frame:
	var parts: Array = []
	var dots: Array = []
	func add(shape: Array, ramp: Array, opt: Dictionary = {}) -> void:
		parts.append({"s": shape, "ramp": ramp, "opt": opt})
	func dot(x: int, y: int, c: String) -> void:
		dots.append([x, y, c])

func render(fr: Frame) -> Image:
	var col := {}
	var rmp := {}
	var pid := {}
	var edge_ok := {}
	for i in fr.parts.size():
		var p: Dictionary = fr.parts[i]
		var opt: Dictionary = p["opt"]
		var shift: int = opt.get("shift", 0)
		for it in p["s"]:
			var k := Vector2i(it[0], it[1])
			var t := 0
			for c in CUTS:
				if it[2] >= c:
					t += 1
			var ramp: Array = p["ramp"]
			if opt.has("mat"):
				ramp = opt["mat"].call(it[3], it[4], k.x, k.y, ramp)
			t = clampi(t + shift, 0, ramp.size() - 1)
			col[k] = ramp[t]
			rmp[k] = ramp
			pid[k] = i
			edge_ok[k] = opt.get("edge", true)
	# separacao interna: borda da parte de cima sobre a de baixo vira o tom 0 do material
	var fix := {}
	for k in pid:
		if not edge_ok[k]:
			continue
		for d in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]:
			var q: Vector2i = k + d
			if pid.has(q) and pid[q] < pid[k]:
				fix[k] = rmp[k][0]
				break
	for k in fix:
		col[k] = fix[k]
	var im: Image = L.img(S, S)
	for k in col:
		L.put(im, k.x, k.y, col[k])
	for d in fr.dots:
		if L.solid(im, d[0], d[1]):
			L.put(im, d[0], d[1], d[2])
	L.outline(im)
	return im

# ------------------------------------------------------------------ materiais (regiao por normal)
func mat_body(nx: float, ny: float, _x: int, y: int, ramp: Array) -> Array:
	# barriga clara embaixo; listras escuras no dorso (descem 1 tom)
	if ny > 0.45:
		return BELLY
	if ny < -0.45:
		return DORSAL  # faixa escura no dorso: recorta a silhueta contra a grama
	return ramp

func mat_belly_front(nx: float, ny: float, _x: int, _y: int, ramp: Array) -> Array:
	if ny > -0.25 and absf(nx) < 0.62:
		return BELLY
	return ramp

# ------------------------------------------------------------------ vista LATERAL (f=-1 olha a esquerda, +1 a direita)
func side(p: Dictionary, f: float, tame: bool) -> Image:
	var fr := Frame.new()
	var bx: float = p.get("bx", 0.0)
	var bob: float = p.get("bob", 0.0)
	var lean: float = p.get("lean", 0.0)
	var hdx: float = p.get("hdx", 0.0)
	var hdy: float = p.get("hdy", 0.0)
	var tail: float = p.get("tail", 0.0)
	var arm: float = p.get("arm", 0.0)
	var nf: Array = p.get("near", [0.0, 0.0])
	var ff: Array = p.get("far", [0.0, 0.0])
	var ox := 16.0 - f * 1.5  # u=0 fica um pouco atras do centro: cabeca e focinho ocupam o lado da frente
	var U := func(u: float) -> float: return ox + f * u
	var by := 19.4 + bob

	# cauda (atras de tudo): sai da base do corpo, cai e termina em ponta fina
	var tc := [
		[U.call(-5.5 + bx), by - 0.5, 3.3],
		[U.call(-8.0 + bx * 0.8), by + 0.3, 2.8],
		[U.call(-10.0 + bx * 0.6), by + 1.2 + tail * 0.4, 2.2],
		[U.call(-11.8 + bx * 0.5), by + 2.0 + tail * 0.8, 1.6],
		[U.call(-13.2 + bx * 0.4), by + 2.4 + tail, 1.0],
	]
	fr.add(chain(tc), BACK, {"mat": mat_tail})
	# perna de tras (longe): tom abaixado
	var hy := 24.0
	fr.add(leg(U.call(-2.8), hy, U.call(-2.8 + ff[0]), 28.6 + ff[1], f, 3.0), BACK, {"shift": -1, "edge": false})
	fr.add(foot(U.call(-2.8 + ff[0] + 1.3), 29.2 + ff[1], f), CLAW, {"shift": -1})
	# braco de tras
	fr.add(chain([[U.call(4.6 + bx - arm), 22.6 + bob, 1.4], [U.call(5.4 + bx - arm * 1.4), 24.2 + bob, 1.2]]), BACK, {"shift": -1})
	# corpo
	fr.add(ell(U.call(0.5 + bx), by + 1.2, 8.2, 5.7, f * lean), BACK, {"mat": mat_body})
	# pescoco
	fr.add(chain([[U.call(4.4 + bx), by - 1.0, 3.6], [U.call(6.2 + bx + hdx * 0.5), by - 4.0 + hdy * 0.5, 3.4]]), BACK, {"edge": false})
	# cabeca: cranio + focinho comprido + domo pequeno no alto/atras + nodulos na nuca
	var hx: float = 7.6 + bx + hdx
	var hyy: float = 12.8 + bob + hdy
	fr.add(ell(U.call(hx), hyy + 0.4, 6.0, 5.3), FACE)
	fr.add(ell(U.call(hx + 4.2), hyy + 2.2, 4.0, 2.9), FACE, {"edge": false})
	fr.add(ell(U.call(hx - 1.6), hyy - 3.4, 3.6, 2.5), DOME)
	for n in [[-4.6, 0.2], [-4.9, 2.6]]:
		fr.add(ell(U.call(hx + n[0]), hyy + n[1], 1.15, 1.15), DOME, {"shift": 1})
	# narina, olho (1x2 px; domado ganha brilho e bochecha) e boca
	fr.dot(int(floor(U.call(hx + 7.2))), int(hyy + 1.8), "s_xx")
	var ex := int(floor(U.call(hx + 3.4)))
	fr.dot(int(floor(U.call(hx + 3.4 - 1.0))), int(hyy + 1.4), "sand")
	fr.dot(ex, int(hyy + 1.4), "K")
	fr.dot(ex, int(hyy + 2.4), "K")
	if tame:
		fr.dot(int(floor(U.call(hx + 1.6))), int(hyy + 0.8), "white")
		fr.dot(int(floor(U.call(hx + 3.8))), int(hyy + 3.4), "pink")
	for m in range(int(p.get("mouth", 0.0)) + 2):
		fr.dot(int(floor(U.call(hx + 4.6 + m))), int(hyy + 4.4), "K")
	# braco da frente
	fr.add(chain([[U.call(5.0 + bx + arm), 22.4 + bob, 1.5], [U.call(5.9 + bx + arm * 1.4), 24.2 + bob, 1.3]]), BACK, {"edge": false})
	fr.dot(int(floor(U.call(6.4 + bx + arm * 1.4))), int(25.2 + bob), "s_xx")
	# perna da frente (perto)
	fr.add(leg(U.call(0.6), hy, U.call(0.6 + nf[0]), 28.6 + nf[1], f, 3.4), BACK, {})
	fr.add(foot(U.call(0.6 + nf[0] + 1.4), 29.2 + nf[1], f), CLAW, {})
	return render(fr)

func mat_tail(nx: float, ny: float, _x: int, _y: int, ramp: Array) -> Array:
	return BELLY if ny > 0.55 else ramp

## Pe: elipse baixa com 3 dedos (pixels de garra) na ponta.
func foot(cx: float, cy: float, f: float) -> Array:
	return ell(cx, cy, 2.4, 1.3)

# ------------------------------------------------------------------ vista FRONTAL (down) e DE COSTAS (up)
func front(p: Dictionary, tame: bool) -> Image:
	var fr := Frame.new()
	var bob: float = p.get("bob", 0.0)
	var hdy: float = p.get("hdy", 0.0)
	var sway: float = p.get("sway", 0.0)
	var nf: Array = p.get("near", [0.0, 0.0])  # perna esquerda (x menor)
	var ff: Array = p.get("far", [0.0, 0.0])   # perna direita
	var arm: float = p.get("arm", 0.0)
	# pernas
	fr.add(chain([[12.6, 24.0, 3.1], [12.4, 27.0 + nf[1] * 0.5, 2.1], [12.2, 28.8 + nf[1], 1.5]]), BACK, {})
	fr.add(ell(12.0 + nf[0], 29.3 + nf[1], 3.0, 1.35), CLAW, {})
	fr.add(chain([[19.4, 24.0, 3.1], [19.6, 27.0 + ff[1] * 0.5, 2.1], [19.8, 28.8 + ff[1], 1.5]]), BACK, {})
	fr.add(ell(20.0 + ff[0], 29.3 + ff[1], 3.0, 1.35), CLAW, {})
	# corpo
	fr.add(ell(16.0 + sway, 21.6 + bob, 6.2, 5.2), BACK, {"mat": mat_belly_front})
	# bracos
	fr.add(chain([[9.6 + sway, 21.4 + bob + arm, 1.4], [9.4 + sway, 23.2 + bob + arm, 1.1]]), BACK, {})
	fr.add(chain([[22.4 + sway, 21.4 + bob - arm, 1.4], [22.6 + sway, 23.2 + bob - arm, 1.1]]), BACK, {})
	fr.dot(9, int(24.4 + bob + arm), "s_xx")
	fr.dot(22, int(24.4 + bob - arm), "s_xx")
	# cabeca ESTREITA com focinho que avanca e domo de osso no alto; olhos nas laterais do cranio
	var hy := 14.2 + bob + hdy
	fr.add(ell(16.0 + sway, hy, 6.0, 5.6), FACE_F)
	fr.add(ell(16.0 + sway, hy + 3.6, 3.4, 2.7), FACE_F, {"edge": false, "shift": 1})
	fr.add(ell(16.0 + sway, hy - 3.9, 4.6, 2.5), DOME)
	# anel de nodulos laranja na base do domo (sem "orelhas" nas laterais)
	for nx in [-4.6, -2.3, 0.0, 2.3, 4.6]:
		fr.dot(int(floor(16.0 + sway + nx)), int(hy - 1.6 + absf(nx) * 0.25), "orange")
	var ey := int(hy + 0.6)
	for ex in [11.0, 20.0]:
		fr.dot(int(ex + sway), ey, "K")
		fr.dot(int(ex + sway), ey + 1, "K")
		var inner := 1 if ex < 15.0 else -1
		fr.dot(int(ex + sway) + inner, ey, "K")
		fr.dot(int(ex + sway) + inner, ey + 1, "K")
		fr.dot(int(ex + sway) + inner, ey, "white")  # brilho: o olho tem que ler no tamanho real
		fr.dot(int(ex + sway) - inner, ey - 1, "w_dk")  # sobrancelha
	fr.dot(int(15.0 + sway), int(hy + 3.0), "s_xx")
	fr.dot(int(16.0 + sway), int(hy + 3.0), "s_xx")
	for m in range(14, 18):
		fr.dot(int(m + sway), int(hy + 5.0 + p.get("mouth", 0.0)), "K")
	return render(fr)

func back(p: Dictionary) -> Image:
	var fr := Frame.new()
	var bob: float = p.get("bob", 0.0)
	var hdy: float = p.get("hdy", 0.0)
	var sway: float = p.get("sway", 0.0)
	var tail: float = p.get("tail", 0.0)
	var nf: Array = p.get("near", [0.0, 0.0])
	var ff: Array = p.get("far", [0.0, 0.0])
	fr.add(chain([[12.6, 24.0, 3.1], [12.4, 27.0 + nf[1] * 0.5, 2.1], [12.2, 28.8 + nf[1], 1.5]]), BACK, {"shift": -1})
	fr.add(ell(12.0 + nf[0], 29.3 + nf[1], 3.0, 1.35), CLAW, {"shift": -1})
	fr.add(chain([[19.4, 24.0, 3.1], [19.6, 27.0 + ff[1] * 0.5, 2.1], [19.8, 28.8 + ff[1], 1.5]]), BACK, {"shift": -1})
	fr.add(ell(20.0 + ff[0], 29.3 + ff[1], 3.0, 1.35), CLAW, {"shift": -1})
	# corpo com listras no dorso
	fr.add(ell(16.0 + sway, 20.6 + bob, 7.0, 5.6), BACK, {"mat": mat_back_stripes})
	# pescoco e cabeca (so o domo, cranio redondo de costas)
	var hy := 12.4 + bob + hdy
	fr.add(ell(16.0 + sway, hy + 3.4, 5.4, 4.4), BACK)
	fr.add(ell(16.0 + sway, hy + 0.6, 5.2, 4.2), DOME)
	for n in [[-6.4, 3.4], [6.4, 3.4], [-4.0, 5.4], [4.0, 5.4], [0.0, 6.0]]:
		fr.add(ell(16.0 + sway + n[0], hy + n[1], 1.25, 1.25), DOME, {"shift": 1})
	# cauda vinda para perto da camera, sobre o corpo
	var tx := 16.0 + sway + tail
	fr.add(chain([[16.0 + sway, 22.0 + bob, 3.6], [16.0 + sway + tail * 0.4, 25.0 + bob, 3.0], [tx, 27.6, 2.2], [tx + tail * 0.5, 29.0, 1.3]]), BACK, {})
	return render(fr)

func mat_back_stripes(nx: float, ny: float, x: int, y: int, ramp: Array) -> Array:
	# faixas escuras horizontais no dorso (2 tons abaixo nao existe: usa rampa deslocada por mascara)
	if ny > 0.55:
		return BELLY
	if false:
		return STRIPE
	return ramp

const STRIPE := ["s_xx", "w_xx", "w_dk", "w_br"]

# ------------------------------------------------------------------ DORMINDO e MORTO (de lado; f = para onde olha)
func lying(f: float, dead: bool, tame: bool) -> Image:
	var fr := Frame.new()
	var ox := 16.0
	var U := func(u: float) -> float: return ox + f * u
	# cauda enrolada para tras
	fr.add(chain([[U.call(-7.0), 26.4, 3.0], [U.call(-10.5), 27.0, 2.4], [U.call(-13.2), 26.2, 1.8], [U.call(-14.6), 24.4, 1.2]]), BACK, {"mat": mat_tail})
	# pernas encolhidas (ou para o ar quando morto)
	if dead:
		fr.add(chain([[U.call(-3.0), 24.0, 2.4], [U.call(-2.0), 21.0, 1.8], [U.call(-2.4), 18.6, 1.4]]), BACK, {"shift": -1})
		fr.add(chain([[U.call(1.5), 24.0, 2.4], [U.call(2.6), 21.0, 1.8], [U.call(2.2), 18.4, 1.4]]), BACK, {})
	else:
		fr.add(ell(U.call(-1.0), 28.4, 3.4, 1.9), BACK, {"shift": -1})
	# corpo deitado
	fr.add(ell(U.call(0.0), 25.4, 8.6, 4.8 if not dead else 4.4), BELLY if dead else BACK, {"mat": (mat_body if not dead else mat_dead_belly)})
	# braco
	fr.add(chain([[U.call(5.0), 25.2, 1.5], [U.call(7.2), 27.0, 1.3]]), BACK, {})
	# cabeca apoiada no chao a frente
	var hx := 9.4
	var hy := 25.0 if not dead else 24.0
	fr.add(ell(U.call(hx), hy + 0.6, 4.8, 4.4), FACE)
	fr.add(ell(U.call(hx + 3.0), hy + 2.2, 3.0, 2.0), FACE, {"edge": false})
	fr.add(ell(U.call(hx - 0.6), hy - 1.6, 4.3, 3.4), DOME)
	for n in [[-3.6, 0.4], [-3.2, 2.4]]:
		fr.add(ell(U.call(hx + n[0]), hy + n[1], 1.2, 1.2), DOME, {"shift": 1})
	var ex := int(floor(U.call(hx + 3.4)))
	if dead:
		fr.dot(ex, int(hy + 0.0), "K")
		fr.dot(int(floor(U.call(hx + 3.4))), int(hy + 1.0), "K")
		fr.dot(ex, int(hy + 1.0), "K")
		fr.dot(int(floor(U.call(hx + 3.4))), int(hy + 0.0), "K")
		fr.dot(int(floor(U.call(hx + 4.4))), int(hy + 4.4), "pink")
	else:
		fr.dot(ex, int(hy + 1.0), "K")
		fr.dot(int(floor(U.call(hx + 3.4))), int(hy + 1.0), "K")
		if tame:
			fr.dot(int(floor(U.call(hx + 4.4))), int(hy + 2.6), "pink")
	return render(fr)

func mat_dead_belly(nx: float, ny: float, _x: int, _y: int, ramp: Array) -> Array:
	return BELLY if ny < 0.1 else BACK

# ------------------------------------------------------------------ poses
func pose(col: int) -> Dictionary:
	match col:
		0: return {}
		1: return {"bob": 1.0, "hdy": 0.0, "tail": 1.0, "mouth": 0.0}
		2: return {"near": [3.0, 0.0], "far": [-3.0, 0.0], "tail": -1.0, "arm": 1.0, "sway": -0.5}
		3: return {"near": [0.0, 0.0], "far": [0.0, -2.0], "bob": -1.0, "tail": 0.0, "arm": 0.0}
		4: return {"near": [-3.0, 0.0], "far": [3.0, 0.0], "tail": 1.0, "arm": -1.0, "sway": 0.5}
		5: return {"near": [0.0, -2.0], "far": [0.0, 0.0], "bob": -1.0, "tail": 0.0, "arm": 0.0}
		6: return {"bob": 1.0, "bx": -1.0, "hdx": -1.0, "hdy": -1.0, "lean": -0.12, "near": [-1.0, 0.0], "far": [1.0, 0.0], "tail": 1.0, "arm": -1.0}
		7: return {"bob": 1.0, "bx": 1.0, "hdx": 1.5, "hdy": 1.5, "lean": 0.16, "near": [-2.0, 0.0], "far": [-3.0, 0.0], "tail": -1.0, "arm": 1.0, "mouth": 1.0}
		8: return {"bob": 0.0, "bx": 1.0, "hdx": 1.0, "hdy": 0.0, "lean": 0.06, "near": [-1.0, 0.0], "far": [-1.0, 0.0], "tail": 0.0}
	return {}

## Para frente e costas o golpe vira cabecada para baixo/cima na tela: pose propria.
func pose_fb(col: int, up: bool) -> Dictionary:
	var p := pose(col)
	if col >= 6 and col <= 8:
		var k: float = [-1.0, 2.0, 1.0][col - 6]
		p = {"bob": [1.0, 1.0, 0.0][col - 6], "hdy": k if not up else -k * 0.5, "tail": 0.0, "near": [0.0, 0.0], "far": [0.0, 0.0], "mouth": 0.0}
		if col == 7:
			p["mouth"] = 1.0
	elif col >= 2 and col <= 5:
		p["near"] = [0.0, [0.0, 0.0, 0.0, -2.0][col - 2] if col != 2 else 0.0]
		p["far"] = [0.0, [0.0, -2.0, 0.0, 0.0][col - 2] if col != 4 else 0.0]
		p["near"] = [0.0, [0.0, 0.0, 0.0, -2.0][col - 2]]
		p["far"] = [0.0, [0.0, -2.0, 0.0, 0.0][col - 2]]
		p["sway"] = 0.0
		p["tail"] = [-2.0, 0.0, 2.0, 0.0][col - 2]
	return p


# ------------------------------------------------------------------ DIAGONAIS (partes 3D; f = frente, z = altura)
func Z(sy: float) -> float:
	return 30.0 - sy

func fw(u: float) -> float:
	return u - 1.5

func mat_body3(n: Vector3, ramp: Array) -> Array:
	if n.z < -0.25:
		return BELLY
	if n.z > 0.6:
		return DORSAL
	return ramp

func mat_tail3(n: Vector3, ramp: Array) -> Array:
	return BELLY if n.z < -0.4 else ramp

func diag(p: Dictionary, yaw: float, tame: bool) -> Image:
	R.clear()
	var bx: float = p.get("bx", 0.0)
	var bob: float = p.get("bob", 0.0)
	var hdx: float = p.get("hdx", 0.0)
	var hdy: float = p.get("hdy", 0.0)
	var tail: float = p.get("tail", 0.0)
	var arm: float = p.get("arm", 0.0)
	var nf: Array = p.get("near", [0.0, 0.0])
	var ff: Array = p.get("far", [0.0, 0.0])
	var by := 19.4 + bob
	# cauda
	R.chain([[0, fw(-5.5 + bx), Z(by - 0.5), 3.3], [0, fw(-8.0 + bx * 0.8), Z(by + 0.3), 2.8], [0, fw(-10.0 + bx * 0.6), Z(by + 1.2 + tail * 0.4), 2.2],
		[0, fw(-11.8 + bx * 0.5), Z(by + 2.0 + tail * 0.8), 1.6], [0, fw(-13.2 + bx * 0.4), Z(by + 2.4 + tail), 1.0]], BACK, {"mat": mat_tail3})
	# pernas (biped: uma de cada lado) e pes
	for s in [[-1.0, ff, -1], [1.0, nf, 0]]:
		var lg: Array = s[1]
		var x: float = 3.2 * s[0]
		var hu := -1.2
		var fu: float = hu + lg[0]
		var ku: float = (hu + fu) * 0.5 - 1.6
		R.chain([[x, fw(hu), Z(24.0), 3.2], [x, fw((hu + ku) * 0.5), Z(25.6), 2.5], [x, fw(ku), Z(26.8 + lg[1] * 0.5), 2.0],
			[x, fw((ku + fu) * 0.5), Z(27.9 + lg[1]), 1.45], [x, fw(fu), Z(28.6 + lg[1]), 1.4]], BACK, {"shift": s[2]})
		R.ell(Vector3(x, fw(fu + 1.3), Z(29.2 + lg[1])), Vector3(1.9, 2.8, 1.3), CLAW, {"shift": s[2]})
	# bracos
	for s in [[-1.0, -arm], [1.0, arm]]:
		R.chain([[5.3 * s[0], fw(5.0 + bx + s[1]), Z(22.4 + bob), 1.5], [5.4 * s[0], fw(5.9 + bx + s[1] * 1.4), Z(24.2 + bob), 1.3]], BACK)
	# corpo, pescoco
	R.ell(Vector3(0, fw(0.5 + bx), Z(by + 1.2)), Vector3(5.8, 8.2, 5.7), BACK, {"mat": mat_body3})
	R.chain([[0, fw(4.4 + bx), Z(by - 1.0), 3.6], [0, fw(6.2 + bx + hdx * 0.5), Z(by - 4.0 + hdy * 0.5), 3.4]], BACK, {"edge": false})
	# cabeca
	var hx: float = 7.6 + bx + hdx
	var hyy: float = 12.8 + bob + hdy
	R.ell(Vector3(0, fw(hx), Z(hyy + 0.4)), Vector3(5.0, 6.0, 5.3), FACE)
	R.ell(Vector3(0, fw(hx + 4.2), Z(hyy + 2.2)), Vector3(3.2, 4.0, 2.9), FACE, {"edge": false})
	R.ell(Vector3(0, fw(hx - 1.6), Z(hyy - 3.4)), Vector3(4.3, 3.7, 2.6), DOME)
	for n in [[-2.8, -4.6, 0.2], [2.8, -4.6, 0.2], [0.0, -5.0, 1.6]]:
		R.ell(Vector3(n[0], fw(hx + n[1]), Z(hyy + n[2])), Vector3(1.15, 1.15, 1.15), DOME, {"shift": 1})
	for nx in [-3.4, -1.7, 0.0, 1.7, 3.4]:
		R.ell(Vector3(nx, fw(hx + 2.4 - absf(nx) * 0.35), Z(hyy - 1.4 + absf(nx) * 0.2)), Vector3(0.9, 0.9, 0.9), ["w_br", "orange", "orange", "orange"], {"edge": false})
	# olhos (na lateral do cranio), narinas
	for sx in [-1.0, 1.0]:
		var e := Vector3(0.79 * 5.0 * sx, fw(hx + 0.52 * 6.0), Z(hyy + 0.4) - 0.3 * 5.3)
		R.decal(e, "K")
		R.decal(e + Vector3(0, 0, -1.0), "K")
		R.decal(Vector3(0.9 * sx, fw(hx + 7.4), Z(hyy + 1.8)), "s_xx")
	return R.render(yaw)

func make_sheet(tame: bool) -> Image:
	var sheet: Image = L.img(S * COLS, S * 8)
	for row in 8:
		for col in COLS:
			var im: Image
			if col == 9 or col == 10:
				# down/left olham a esquerda; up/right a direita (convencao do gerador anterior)
				im = lying(-1.0 if (row == 0 or row == 2 or row == 4 or row == 6) else 1.0, col == 10, tame)
			elif row >= 4:
				im = diag(pose(col), R.DIR_YAW[row], tame)
			else:
				match row:
					0: im = front(pose_fb(col, false), tame)
					1: im = back(pose_fb(col, true))
					2: im = side(pose(col), -1.0, tame)
					_: im = side(pose(col), 1.0, tame)
			L.blit(sheet, im, col * S, row * S)
	return sheet

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	assert(args.size() >= 1, "uso: -- <pasta de saida>")
	var dir: String = args[0]
	L.save_png_checked(make_sheet(false), dir.path_join("paquicefalo.png"))
	var meta := {
		"ancora": "base do quadro (pes em y=30, contorno em y=31, folha 32x32); montado por partes por script",
		"animacoes": {
			"attack": {"colunas": [6, 7, 8], "fps": 10, "loop": false},
			"dead": {"colunas": [10], "fps": 1, "loop": false},
			"idle": {"colunas": [0, 1], "fps": 2, "loop": true},
			"sleep": {"colunas": [9], "fps": 1, "loop": false},
			"walk": {"colunas": [2, 3, 4, 5], "fps": 8, "loop": true},
		},
		"arquivo": "paquicefalo.png",
		"colisao_pes": [12, 12],
		"colunas": COLS,
		"direita": "desenhada por script (geometria espelhada, sombreada de novo com a luz a esquerda)",
		"especie": "paquicefalo",
		"filhote": "nao incluso (M4)",
		"golpe": "cabecada desenhada nos quadros 6-8 (cabeca e tronco avancam 2 a 3 px); sem deslocamento extra em codigo",
		"layout": "igual nas cinco especies: colunas 0-1 idle, 2-5 walk, 6-8 attack, 9 sleep, 10 dead; linhas down, up, left, right, down_left, down_right, up_left, up_right",
		"linhas": 8,
		"linhas_direcao": R.DIR_NAMES,
		"luz": "cima-esquerda",
		"porte": "Pequeno",
		"quadro": [S, S],
		"sleep_dead": "desenhados de lado, deitados (down/left olham esquerda, up/right direita); morto de barriga para cima",
	}
	var f := FileAccess.open(dir.path_join("paquicefalo.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(meta, "\t", true))
	f.close()
	quit()
