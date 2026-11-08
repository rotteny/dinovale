## Renderizador de pixel art por PARTES 3D (elipsoides) para as 8 direcoes. Arte propria, CC BY 4.0, sem IA.
## Biblioteca dos geradores `gerar_paquicefalo.gd` (diagonais) e `gerar_jogador_8dir.gd`. Rode da raiz do repositorio.
##
## Como funciona: o personagem e uma lista de elipsoides (e correntes de esferas para membros) no espaco do
## personagem (x = lateral, y = frente, z = para cima, em pixels; pes em z=0). O personagem gira em torno de z
## (yaw) para cada direcao; a camera e fixa, obliqua (como o jogo: vista de frente com leve inclinacao).
## Cada pixel lanca um raio, pega o elipsoide mais proximo da camera e usa a NORMAL: produto com a luz (fixa na
## tela, cima-esquerda, a mesma do ESTILO.md) cortado em 4 tons duros, sem gradiente e sem dithering. A parte que
## fica na frente ganha 1 px do tom escuro do proprio material na borda com a de tras (grupos iguais nao). So o
## contorno externo e #141b1b. Nada e espelhado: cada direcao e sombreada de novo com a luz a esquerda.
##
## Convencao de yaw (graus): 0 = olha para baixo (sul), -90 = direita, 180 = cima, 90 = esquerda.
extends RefCounted
const Lib = preload("arte_lib.gd")
var L = Lib.new()

const S := 32
const TILT := 0.34  # sen da inclinacao da camera (~20 graus): quanto y (profundidade) sobe/desce na tela
const CUTS := [0.30, 0.58, 0.86]
var light := Vector3(-0.5, 0.35, 0.8).normalized()

## Linhas da folha de 8 direcoes (as 4 primeiras sao as de sempre) e o yaw de cada uma.
const DIR_NAMES := ["down", "up", "left", "right", "down_left", "down_right", "up_left", "up_right"]
const DIR_YAW := [0.0, 180.0, 90.0, -90.0, 45.0, -45.0, 135.0, -135.0]

class Part:
	var c: Vector3
	var r: Vector3
	var ramp: Array
	var gid: int
	var shift: int = 0
	var edge: bool = true
	var mat: Callable = Callable()

var parts: Array = []
var decals: Array = []  # [Vector3 (espaco do personagem), nome de cor]
var _gid := 0

func clear() -> void:
	parts = []
	decals = []
	_gid = 0

## Elipsoide: centro e raios no espaco do personagem. opt: shift, edge, mat (Callable(normal, rampa) -> rampa), group.
func ell(c: Vector3, r: Vector3, ramp: Array, opt: Dictionary = {}) -> void:
	var p := Part.new()
	p.c = c
	p.r = r
	p.ramp = ramp
	p.shift = opt.get("shift", 0)
	p.edge = opt.get("edge", true)
	p.mat = opt.get("mat", Callable())
	if opt.has("group"):
		p.gid = opt["group"]
	else:
		_gid += 1
		p.gid = _gid
	parts.append(p)

## Corrente de esferas [x, y, z, raio] (membros): as esferas formam um grupo so (sem borda interna).
func chain(pts: Array, ramp: Array, opt: Dictionary = {}) -> void:
	_gid += 1
	var o := opt.duplicate()
	o["group"] = _gid
	for i in range(pts.size() - 1):
		var a: Array = pts[i]
		var b: Array = pts[i + 1]
		var n := maxi(1, int(ceil(Vector2(b[0] - a[0], b[1] - a[1]).length() + absf(b[2] - a[2]))))
		for k in range(n + 1 if i == pts.size() - 2 else n):
			var t := float(k) / float(n)
			var rr: float = lerpf(a[3], b[3], t)
			ell(Vector3(lerpf(a[0], b[0], t), lerpf(a[1], b[1], t), lerpf(a[2], b[2], t)), Vector3(rr, rr, rr), ramp, o)

func decal(pos: Vector3, color: String) -> void:
	decals.append([pos, color])

## Renderiza o que foi montado. yaw em graus; pitch em graus (deitar, em torno de z=pivot_z); lift sobe tudo em z.
func render(yaw_deg: float, pitch_deg: float = 0.0, lift: float = 0.0, pivot_z: float = 0.0) -> Image:
	var g := Basis(Vector3(0, 0, 1), deg_to_rad(yaw_deg)) * Basis(Vector3(1, 0, 0), deg_to_rad(pitch_deg))
	var gt := g.transposed()
	var d := Vector3(0, 1, TILT)
	var n := S * S
	var tb := PackedFloat32Array()
	tb.resize(n)
	tb.fill(-1e9)
	var pid := PackedInt32Array()
	pid.resize(n)
	pid.fill(-1)
	var tone := PackedInt32Array()
	tone.resize(n)
	var cols: Array = []
	cols.resize(n)
	var ramps: Array = []
	ramps.resize(n)
	var lightn := light
	for i in parts.size():
		var p: Part = parts[i]
		var cw := g * (p.c - Vector3(0, 0, pivot_z)) + Vector3(0, 0, lift)
		var inv := Vector3(1.0 / p.r.x, 1.0 / p.r.y, 1.0 / p.r.z)
		var dl := (gt * d) * inv
		var a := dl.dot(dl)
		var rm := maxf(p.r.x, maxf(p.r.y, p.r.z))
		var syup := cw.z - cw.y * TILT
		for py in range(maxi(0, int(floor(30.0 - syup - rm * 1.5))), mini(S, int(ceil(30.0 - syup + rm * 1.5)) + 1)):
			for px in range(maxi(0, int(floor(16.0 + cw.x - rm))), mini(S, int(ceil(16.0 + cw.x + rm)) + 1)):
				var o := Vector3(px + 0.5 - 16.0, 0.0, 30.0 - (py + 0.5))
				var ol := (gt * (o - cw)) * inv
				var b := ol.dot(dl)
				var c := ol.dot(ol) - 1.0
				var disc := b * b - a * c
				if disc < 0.0:
					continue
				var t := (-b + sqrt(disc)) / a
				var k := py * S + px
				if t <= tb[k]:
					continue
				var nl := (ol + dl * t)  # normal no espaco unitario
				var ng := nl * inv  # gradiente no espaco do personagem
				var nc := ng.normalized()
				var nw := (g * ng).normalized()
				var ramp: Array = p.ramp
				if p.mat.is_valid():
					ramp = p.mat.call(nc, p.ramp)
				var ti := 0
				var dot := nw.dot(lightn)
				for cut in CUTS:
					if dot >= cut:
						ti += 1
				tb[k] = t
				pid[k] = i
				ramps[k] = ramp
				tone[k] = clampi(ti + p.shift, 0, ramp.size() - 1)
	# separacao interna
	for y in S:
		for x in S:
			var k := y * S + x
			if pid[k] < 0:
				continue
			var p: Part = parts[pid[k]]
			var col: String = ramps[k][tone[k]]
			if p.edge:
				for dd in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]:
					var qx: int = x + dd.x
					var qy: int = y + dd.y
					if qx < 0 or qy < 0 or qx >= S or qy >= S:
						continue
					var q := qy * S + qx
					if pid[q] >= 0 and (parts[pid[q]] as Part).gid != p.gid and tb[q] < tb[k] - 1.2:
						col = ramps[k][0]
						break
			cols[k] = col
	var im: Image = L.img(S, S)
	for k in n:
		if pid[k] >= 0:
			L.put(im, k % S, k / S, cols[k])
	for dc in decals:
		var pw: Vector3 = g * ((dc[0] as Vector3) - Vector3(0, 0, pivot_z)) + Vector3(0, 0, lift)
		var px := int(floor(16.0 + pw.x))
		var py := int(floor(30.0 - (pw.z - pw.y * TILT)))
		if px < 0 or py < 0 or px >= S or py >= S:
			continue
		var k := py * S + px
		if pid[k] >= 0 and tb[k] <= pw.y + 1.2:
			L.put(im, px, py, dc[1])
	L.outline(im)
	return im
