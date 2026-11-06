## Gerador dos dinos da v0.2: Dodo, Paquicefalo, Parassaurolofo, Utahraptor e Triceratops.
## Arte propria, CC BY 4.0, sem IA e sem recorte de terceiros. Da raiz do repositorio:
##   godot --headless --script docs/design/arte/gerar_dinos.gd
## Saida (um PNG e um JSON por especie) em game/assets/sprites/dinos/:
##   dodo.png (16x16), paquicefalo.png (24x24), parassaurolofo.png (32x32), utahraptor.png (32x32), triceratops.png (48x48)
## Layout IGUAL para as cinco: 11 colunas x 4 linhas, quadro quadrado do porte (GDD 4.2).
##   Linhas (direcao): 0 baixo (de frente), 1 cima (de costas), 2 esquerda, 3 direita (desenhada, nao e espelho cego:
##   o sombreamento segue a luz de cima-esquerda tambem na direita).
##   Colunas: 0-1 parado, 2-5 andar (4), 6-8 golpe (preparo, impacto, volta) ou, no Dodo e no Parassaurolofo,
##   susto (agacha/pula, pula alto com bico aberto, pousa), 9 dormindo (desmaiado), 10 morto (carcaca).
##   Dormindo e morto: desenhados de lado; linhas 0 e 2 olham para a esquerda, 1 e 3 para a direita.
## Ancora: pes na linha S-2; contorno em S-1. Sem sombra pintada. Luz de cima-esquerda.
## Cores: so a paleta do pacote (conferido em arte_lib.gd); contorno #141b1b; alfa 0/1.
extends SceneTree
const Lib = preload("arte_lib.gd")
var L = Lib.new()
const OUT := "game/assets/sprites/dinos/"
const COLS := 11
const ESP := {
	"dodo": {"arq": "dodo", "S": 16, "porte": "Diminuto", "col": [8, 8], "golpe": "scare"},
	"pachy": {"arq": "paquicefalo", "S": 24, "porte": "Pequeno", "col": [12, 12], "golpe": "attack"},
	"para": {"arq": "parassaurolofo", "S": 32, "porte": "Medio", "col": [14, 14], "golpe": "scare"},
	"utah": {"arq": "utahraptor", "S": 32, "porte": "Medio", "col": [14, 14], "golpe": "attack"},
	"trike": {"arq": "triceratops", "S": 48, "porte": "Grande", "col": [28, 24], "golpe": "attack"},
}
var S := 16
var G := 14
var M := false

# ---------------------------------------------------------------- tons
const T_DODO := ["z_hi", "z_md", "z_dk"]
const T_DODO_WING := ["z_md", "z_dk", "deep_hi"]
const T_BEAK := ["yellow", "ring", "orange"]
const T_LEG := ["ring", "orange", "w_dk"]
const T_PACHY := ["w_hi", "w_md", "w_dk"]
const T_DOME := ["cut", "ring", "ring2"]
const T_PARA := ["deep_hi", "deep", "deep_dk"]
const T_CREST := ["f_hi", "pink", "f_dk"]
const T_UTAH := ["clay", "w_dk", "f_dk"]
const T_FEATH := ["yellow", "ring", "orange"]
const T_TRIKE := ["g_sg", "g_gr", "g_dk"]
const T_FRILL := ["w_br", "w_dk", "f_dk"]
const T_HORN := ["cut", "ring2", "w_hi"]

func _init() -> void:
	for sp in ESP:
		build(sp)
	quit()

func build(sp: String) -> void:
	var e: Dictionary = ESP[sp]
	S = e["S"]
	G = S - 2
	var sheet: Image = L.img(S * COLS, S * 4)
	for d in 4:
		var cols := []
		for f in 2: cols.append(["idle", f])
		for f in 4: cols.append(["walk", f])
		for f in 3: cols.append(["hit", f])
		cols.append(["sleep", 0])
		cols.append(["dead", 0])
		for c in cols.size():
			L.blit(sheet, frame(sp, d, cols[c][0], cols[c][1]), c * S, d * S)
	L.save_png_checked(sheet, OUT + e["arq"] + ".png")
	var anims := {
		"idle": {"colunas": [0, 1], "fps": 2, "loop": true},
		"walk": {"colunas": [2, 3, 4, 5], "fps": 8, "loop": true},
		e["golpe"]: {"colunas": [6, 7, 8], "fps": 10, "loop": false},
		"sleep": {"colunas": [9], "fps": 1, "loop": false},
		"dead": {"colunas": [10], "fps": 1, "loop": false},
	}
	var nota_golpe := "reacao de susto: agacha, pula com o bico/boca aberto, pousa. Nao ataca." if e["golpe"] == "scare" else "preparo (cabeca recua), impacto (investida, boca aberta ou chifres a frente), volta."
	var js := {
		"arquivo": e["arq"] + ".png", "especie": e["arq"], "porte": e["porte"], "quadro": [S, S], "colunas": COLS, "linhas": 4,
		"linhas_direcao": ["down", "up", "left", "right"],
		"animacoes": anims,
		"ancora": "base do quadro (pes em y=%d, contorno em y=%d)" % [S - 2, S - 1],
		"colisao_pes": e["col"],
		"layout": "igual nas cinco especies: colunas 0-1 idle, 2-5 walk, 6-8 %s, 9 sleep, 10 dead; linhas down, up, left, right" % e["golpe"],
		"golpe": nota_golpe,
		"sleep_dead": "desenhados de lado (corpo deitado): linhas down e left olham para a esquerda, up e right olham para a direita; dead = de barriga para cima, patas rigidas para o alto, olho em X",
		"direita": "desenhada a parte (nao e espelho cego): a luz continua vindo de cima-esquerda",
		"luz": "cima-esquerda",
		"filhote": "nao incluso (M4)",
	}
	var f := FileAccess.open(OUT + e["arq"] + ".json", FileAccess.WRITE)
	f.store_string(JSON.stringify(js, "\t"))
	f.close()

# ---------------------------------------------------------------- primitivas
func newm() -> Image:
	return L.img(S, S)

func E(m: Image, cx: float, cy: float, rx: float, ry: float) -> void:
	L.m_ell(m, (S - cx) if M else cx, cy, rx, ry)

func R(m: Image, x: float, y: float, w: float, h: float) -> void:
	L.m_rect(m, int((S - x - w) if M else x), int(y), int(w), int(h))

func PG(m: Image, pts: Array) -> void:
	var q := []
	for p in pts:
		q.append(Vector2((S - p[0]) if M else p[0], p[1]))
	L.m_poly(m, q)

func D(p: Image, x: int, y: int, c: String) -> void:
	L.put(p, (S - 1 - x) if M else x, y, c)

## Pinta a mascara em faixas duras com luz de cima-esquerda (nas coordenadas finais).
func part(m: Image, tones: Array, cuts := [-0.35, 0.2, 0.62]) -> Image:
	var x0 := S
	var y0 := S
	var x1 := -1
	var y1 := -1
	for y in S:
		for x in S:
			if L.solid(m, x, y):
				x0 = min(x0, x); x1 = max(x1, x); y0 = min(y0, y); y1 = max(y1, y)
	var p: Image = L.img(S, S)
	if x1 < 0:
		return p
	L.paint(p, m, (x0 + x1 + 1) / 2.0, (y0 + y1 + 1) / 2.0, (x1 - x0 + 1) / 2.0, (y1 - y0 + 1) / 2.0, tones, cuts)
	return p

## Repinta, dentro de p, a area da mascara m com outros tons.
func ovl(p: Image, m: Image, tones: Array, cuts := [-0.35, 0.2, 0.62]) -> void:
	var q := part(m, tones, cuts)
	for y in S:
		for x in S:
			if L.solid(q, x, y) and L.solid(p, x, y):
				p.set_pixel(x, y, q.get_pixel(x, y))

## Carimba a parte com contorno K de 1 px. soft: nao corta o que ja foi pintado (juncoes).
func stamp(dst: Image, p: Image, soft := false) -> void:
	for y in S:
		for x in S:
			if L.solid(p, x, y):
				continue
			if soft and L.solid(dst, x, y):
				continue
			for d in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]:
				if L.solid(p, x + d.x, y + d.y):
					L.put(dst, x, y, "K")
					break
	L.blit(dst, p, 0, 0)

func put_part(dst: Image, m: Image, tones: Array, soft := false, cuts := [-0.35, 0.2, 0.62]) -> Image:
	var p := part(m, tones, cuts)
	stamp(dst, p, soft)
	return p

## Perna de lado: retangulo ate o chao (lift sobe o pe), pe para a frente (esquerda no projeto).
func leg(dst: Image, x: float, y0: float, w: float, lift: int, tones: Array, toe := 2) -> void:
	var m := newm()
	var y1 := G - lift
	R(m, x, y0, w, y1 - y0 + 1)
	if toe > 0:
		R(m, x - toe, y1, toe, 1)
	var p := part(m, tones, [-0.7, 0.5, 9.0])
	stamp(dst, p)

func rim(p: Image, cx: float, cy: float, rx: float, ry: float, a0: float, a1: float, n: int, c: String) -> void:
	for i in n:
		var a := lerpf(a0, a1, float(i) / max(1, n - 1))
		D(p, int(round(cx + cos(a) * rx)), int(round(cy + sin(a) * ry)), c)

# ---------------------------------------------------------------- pose
func pose(anim: String, f: int, scare: bool) -> Dictionary:
	var a := 1 if S <= 24 else (2 if S <= 32 else 3)
	var lf := 1 if a == 1 else 2
	var z := {"b": 0, "nx": 0, "nl": 0, "fx": 0, "fl": 0, "ll": 0, "rl": 0, "sw": 0, "hx": 0, "hy": 0, "open": 0, "jump": 0, "claw": 0, "a": a}
	if anim == "idle":
		z["hy"] = 1 if f == 1 else 0
	elif anim == "walk":
		match f:
			0: z["nx"] = -a; z["fx"] = a; z["rl"] = lf; z["sw"] = -1
			1: z["b"] = -1; z["nl"] = lf; z["rl"] = 1; z["sw"] = 0
			2: z["nx"] = a; z["fx"] = -a; z["ll"] = lf; z["sw"] = 1
			3: z["b"] = -1; z["fl"] = lf; z["ll"] = 1; z["sw"] = 0
	elif anim == "hit":
		if scare:
			match f:
				0: z["b"] = 1; z["hy"] = 1
				1: z["jump"] = a + 1; z["open"] = 1; z["hy"] = -1; z["nl"] = 1; z["fl"] = 1; z["ll"] = 1; z["rl"] = 1
				2: z["jump"] = 1; z["open"] = 0
		else:
			match f:
				0: z["hx"] = a; z["hy"] = -1
				1: z["hx"] = -a * 2; z["hy"] = 1; z["open"] = 1; z["claw"] = 1; z["b"] = 0
				2: z["hx"] = -a; z["hy"] = 0
	return z

func frame(sp: String, d: int, anim: String, f: int) -> Image:
	var e: Dictionary = ESP[sp]
	S = e["S"]
	G = S - 2
	M = (d == 3)
	if anim == "sleep" or anim == "dead":
		M = (d == 1 or d == 3)
		return call(sp + "_lying", anim == "dead")
	var pz := pose(anim, f, e["golpe"] == "scare")
	var img: Image
	if d == 0:
		M = false
		img = call(sp + "_front", pz)
	elif d == 1:
		M = false
		img = call(sp + "_back", pz)
	else:
		img = call(sp + "_side", pz)
	var j: int = pz["jump"]
	if j > 0:
		var o: Image = L.img(S, S)
		L.blit(o, img, 0, -j)
		return o
	return img

# ================================================================ DODO (16)
func dodo_side(z: Dictionary) -> Image:
	var d := newm()
	var b: int = z["b"]
	var hy: int = z["hy"]
	var hx: int = max(0, z["hx"])
	leg(d, 9 + z["fx"], 12 + b, 2, z["fl"], T_LEG, 1)
	# cauda (tufo)
	var mt := newm(); E(mt, 13.2, 5.6 + b, 1.7, 2.3)
	put_part(d, mt, T_DODO, false)
	var mb := newm(); E(mb, 10.2, 8.6 + b, 4.5, 3.7)
	var pb := put_part(d, mb, T_DODO)
	var mw := newm(); E(mw, 10.4, 8.8 + b, 2.6, 1.9)
	if z["jump"] > 0:
		mw = newm(); E(mw, 11.5, 6.8 + b, 2.2, 2.8)
	ovl(pb, mw, T_DODO_WING)
	stamp(d, pb, true)
	leg(d, 7 + z["nx"], 12 + b, 2, z["nl"], T_LEG, 1)
	# cabeca grande
	var mh := newm(); E(mh, 7.0 + hx, 5.0 + b + hy, 3.4, 3.4)
	var ph := put_part(d, mh, T_DODO)
	D(ph, 6 + hx, 3 + b + hy, "K")
	stamp(d, ph, true)
	# bico grande e curvo
	var mk := newm()
	R(mk, 1 + hx, 4 + b + hy, 4, 3)
	if z["open"] == 1:
		R(mk, 2 + hx, 8 + b + hy, 3, 1)
	else:
		R(mk, 1 + hx, 7 + b + hy, 1, 2)
		R(mk, 2 + hx, 7 + b + hy, 3, 1)
	put_part(d, mk, T_BEAK)
	if z["open"] == 1:
		D(d, 2 + hx, 7 + b + hy, "K"); D(d, 3 + hx, 7 + b + hy, "f_dk"); D(d, 4 + hx, 7 + b + hy, "K")
	return d

func dodo_front(z: Dictionary) -> Image:
	var d := newm()
	var b: int = z["b"]
	var sw: int = z["sw"]
	var hy: int = z["hy"]
	var ml := newm(); R(ml, 5 + sw, 12 + b, 2, 3 - z["ll"] - b)
	put_part(d, ml, T_LEG)
	var mr := newm(); R(mr, 9 + sw, 12 + b, 2, 3 - z["rl"] - b)
	put_part(d, mr, T_LEG)
	var mb := newm(); E(mb, 8 + sw, 8.6 + b, 4.6, 3.7)
	var pb := put_part(d, mb, T_DODO)
	for q in [[3, 8], [3, 9], [12, 8], [12, 9]]:
		D(pb, q[0] + sw, q[1] + b, "z_dk")
	stamp(d, pb, true)
	var mh := newm(); E(mh, 8 + sw, 5.2 + b + hy, 3.5, 3.3)
	var ph := put_part(d, mh, T_DODO)
	D(ph, 5 + sw, 4 + b + hy, "K"); D(ph, 10 + sw, 4 + b + hy, "K")
	stamp(d, ph, true)
	var mk := newm(); R(mk, 6 + sw, 6 + b + hy, 4, 2)
	R(mk, 7 + sw, 8 + b + hy, 2, 1)
	put_part(d, mk, T_BEAK)
	if z["open"] == 1:
		D(d, 7 + sw, 8 + b + hy, "K"); D(d, 8 + sw, 8 + b + hy, "f_dk")
	return d

func dodo_back(z: Dictionary) -> Image:
	var d := newm()
	var b: int = z["b"]
	var sw: int = z["sw"]
	var hy: int = z["hy"]
	var ml := newm(); R(ml, 5 + sw, 12 + b, 2, 3 - z["ll"] - b)
	put_part(d, ml, T_LEG)
	var mr := newm(); R(mr, 9 + sw, 12 + b, 2, 3 - z["rl"] - b)
	put_part(d, mr, T_LEG)
	var mb := newm(); E(mb, 8 + sw, 8.6 + b, 4.6, 3.7)
	var pb := put_part(d, mb, T_DODO)
	var mw := newm(); E(mw, 4.2 + sw, 9, 1.4, 2.4); E(mw, 11.8 + sw, 9, 1.4, 2.4)
	ovl(pb, mw, T_DODO_WING)
	stamp(d, pb, true)
	var mh := newm(); E(mh, 8 + sw, 5.2 + b + hy, 3.5, 3.3)
	put_part(d, mh, T_DODO)
	var mt := newm(); E(mt, 8 + sw, 9.6 + b, 2.2, 2.4)
	var pt := put_part(d, mt, T_DODO)
	D(pt, 8 + sw, 8 + b, "z_md"); D(pt, 7 + sw, 10 + b, "z_md")
	stamp(d, pt, true)
	return d

func dodo_lying(dead: bool) -> Image:
	var d := newm()
	var mt := newm(); E(mt, 13.2, 9.2, 1.7, 2.0)
	put_part(d, mt, T_DODO)
	var mb := newm()
	if dead:
		E(mb, 9.5, 10.6, 5, 3.0)
	else:
		E(mb, 9.5, 10.5, 5, 3.3)
	var pb := put_part(d, mb, T_DODO)
	if dead:
		var mw := newm(); E(mw, 9.5, 12, 3.2, 1.0)
		ovl(pb, mw, ["z_hi", "z_hi", "z_hi"])
		stamp(d, pb, true)
		var l1 := newm(); R(l1, 7, 5, 1, 5); R(l1, 6, 5, 1, 1)
		put_part(d, l1, T_LEG)
		var l2 := newm(); R(l2, 11, 4, 1, 6); R(l2, 10, 4, 1, 1)
		put_part(d, l2, T_LEG)
	else:
		var mw := newm(); E(mw, 10.2, 10.4, 2.8, 1.5)
		ovl(pb, mw, T_DODO_WING)
		stamp(d, pb, true)
	var mh := newm(); E(mh, 4.8, 11.2, 3.0, 2.7)
	var ph := put_part(d, mh, T_DODO)
	if dead:
		D(ph, 4, 10, "K"); D(ph, 5, 11, "K"); D(ph, 5, 10, "K"); D(ph, 4, 11, "K")
	else:
		D(ph, 4, 11, "K"); D(ph, 5, 11, "K")
	stamp(d, ph, true)
	var mk := newm(); R(mk, 1, 11, 3, 2)
	if dead:
		R(mk, 0, 10, 1, 1)
	put_part(d, mk, T_BEAK)
	return d

# ================================================================ PAQUICEFALO (24)
func pachy_side(z: Dictionary) -> Image:
	var d := newm()
	var b: int = z["b"]
	var hx: int = z["hx"]
	var hy: int = z["hy"]
	leg(d, 11 + z["fx"], 16 + b, 3, z["fl"], ["w_md", "w_dk", "w_dk"], 2)
	var mt := newm(); PG(mt, [[17.5, 10 + b], [22, 12 + b], [22.5, 14.5 + b], [17, 16.5 + b]])
	put_part(d, mt, T_PACHY, true)
	var mb := newm(); E(mb, 13, 12.6 + b, 5.8, 4.2)
	put_part(d, mb, T_PACHY)
	leg(d, 14 + z["nx"], 16 + b, 3, z["nl"], T_PACHY, 2)
	var ma := newm(); R(ma, 8, 14 + b, 2, 3)
	put_part(d, ma, T_PACHY)
	var mn := newm(); E(mn, 9, 11 + b + hy / 2.0, 2.6, 2.6)
	put_part(d, mn, T_PACHY, true)
	var mh := newm(); E(mh, 6.2 + hx, 10.2 + b + hy, 3.2, 3.0)
	R(mh, 2 + hx, 10 + b + hy, 4, 2)
	var ph := put_part(d, mh, T_PACHY)
	D(ph, 5 + hx, 9 + b + hy, "K")
	if z["open"] == 1:
		D(ph, 3 + hx, 12 + b + hy, "K"); D(ph, 4 + hx, 12 + b + hy, "K")
	stamp(d, ph, true)
	# domo craniano alto e claro, com nodulos
	var md := newm(); E(md, 6.8 + hx, 7.0 + b + hy, 3.4, 2.8)
	var pd := put_part(d, md, T_DOME)
	for q in [[3, 8], [4, 9], [9, 9]]:
		D(pd, q[0] + hx, q[1] + b + hy, "w_hi")
	return d

func pachy_front(z: Dictionary) -> Image:
	var d := newm()
	var b: int = z["b"]
	var sw: int = z["sw"]
	var hy: int = z["hy"]
	var ml := newm(); R(ml, 8 + sw, 17 + b, 3, 6 - z["ll"] - b)
	put_part(d, ml, ["w_md", "w_dk", "w_dk"])
	var mr := newm(); R(mr, 13 + sw, 17 + b, 3, 6 - z["rl"] - b)
	put_part(d, mr, T_PACHY)
	var mb := newm(); E(mb, 12 + sw, 14.2 + b, 5.4, 4.4)
	put_part(d, mb, T_PACHY)
	var ma := newm(); R(ma, 6 + sw, 13 + b, 2, 4); R(ma, 16 + sw, 13 + b, 2, 4)
	put_part(d, ma, T_PACHY, true)
	var mh := newm(); E(mh, 12 + sw, 9.2 + b + hy, 3.7, 3.4)
	var ph := put_part(d, mh, T_PACHY)
	D(ph, 10 + sw, 9 + b + hy, "K"); D(ph, 13 + sw, 9 + b + hy, "K")
	for x in [11, 12]:
		D(ph, x + sw, 11 + b + hy, "w_dk")
	stamp(d, ph, true)
	var md := newm(); E(md, 12 + sw, 6.6 + b + hy, 3.5, 2.7)
	var pd := put_part(d, md, T_DOME)
	for q in [[8, 8], [15, 8]]:
		D(pd, q[0] + sw, q[1] + b + hy, "w_hi")
	return d

func pachy_back(z: Dictionary) -> Image:
	var d := newm()
	var b: int = z["b"]
	var sw: int = z["sw"]
	var hy: int = z["hy"]
	var ml := newm(); R(ml, 8 + sw, 17 + b, 3, 6 - z["ll"] - b)
	put_part(d, ml, ["w_md", "w_dk", "w_dk"])
	var mr := newm(); R(mr, 13 + sw, 17 + b, 3, 6 - z["rl"] - b)
	put_part(d, mr, T_PACHY)
	var mb := newm(); E(mb, 12 + sw, 14.2 + b, 5.4, 4.4)
	put_part(d, mb, T_PACHY)
	var mh := newm(); E(mh, 12 + sw, 9.2 + b + hy, 3.7, 3.4)
	put_part(d, mh, T_PACHY)
	var md := newm(); E(md, 12 + sw, 6.8 + b + hy, 3.5, 2.8)
	var pd := put_part(d, md, T_DOME)
	for q in [[9, 8], [14, 8], [11, 9], [12, 9]]:
		D(pd, q[0] + sw, q[1] + b + hy, "w_hi")
	var mt := newm(); PG(mt, [[10 + sw, 15 + b], [14 + sw, 15 + b], [13.5 + sw, 21 + b], [10.5 + sw, 21 + b]])
	put_part(d, mt, ["w_md", "w_dk", "w_dk"])
	return d

func pachy_lying(dead: bool) -> Image:
	var d := newm()
	var mt := newm(); PG(mt, [[18, 17], [22.5, 19], [22.5, 21], [17, 21]])
	put_part(d, mt, T_PACHY, true)
	var mb := newm()
	if dead:
		E(mb, 13.5, 16.8, 6.2, 3.6)
	else:
		E(mb, 13.5, 17.6, 6.2, 3.8)
	var pb := put_part(d, mb, T_PACHY)
	if dead:
		var mv := newm(); E(mv, 13.5, 19.0, 4.2, 1.6)
		ovl(pb, mv, ["cut", "cut", "ring2"])
		stamp(d, pb, true)
		var l1 := newm(); R(l1, 11, 9, 2, 8); R(l1, 9, 9, 2, 1)
		put_part(d, l1, T_PACHY)
		var l2 := newm(); R(l2, 15, 8, 2, 9); R(l2, 13, 8, 2, 1)
		put_part(d, l2, ["w_md", "w_dk", "w_dk"])
	else:
		stamp(d, pb, true)
		var lg := newm(); R(lg, 10, 20, 5, 2)
		put_part(d, lg, T_PACHY)
	var mh := newm(); E(mh, 6.2, 19.0, 3.2, 2.9); R(mh, 2, 19, 4, 2)
	var ph := put_part(d, mh, T_PACHY)
	if dead:
		D(ph, 5, 18, "K"); D(ph, 6, 19, "K"); D(ph, 6, 18, "K"); D(ph, 5, 19, "K")
	else:
		D(ph, 5, 19, "K"); D(ph, 6, 19, "K")
	stamp(d, ph, true)
	var md := newm(); E(md, 6.8, 16.4, 3.4, 2.6)
	var pd := put_part(d, md, T_DOME)
	D(pd, 4, 17, "w_hi")
	return d

# ================================================================ PARASSAUROLOFO (32)
func para_side(z: Dictionary) -> Image:
	var d := newm()
	var b: int = z["b"]
	var hx: int = z["hx"]
	var hy: int = z["hy"]
	leg(d, 20 + z["nx"], 23 + b, 4, z["nl"], ["deep", "deep_dk", "deep_dk"], 2)
	leg(d, 14 + z["fx"], 23 + b, 3, z["fl"], ["deep", "deep_dk", "deep_dk"], 2)
	var mt := newm(); PG(mt, [[22, 16 + b], [29, 21 + b], [30.5, 23 + b], [29, 24.5 + b], [22, 26.5 + b]])
	put_part(d, mt, T_PARA, true)
	var mb := newm(); E(mb, 17, 21 + b, 9, 5.4)
	put_part(d, mb, T_PARA)
	leg(d, 17 + z["fx"], 23 + b, 5, z["fl"], T_PARA, 2)
	leg(d, 10 + z["nx"], 23 + b, 4, z["nl"], T_PARA, 2)
	var mn := newm(); PG(mn, [[8.5, 20 + b], [8 + hx, 12 + b + hy], [11 + hx, 10 + b + hy], [15.5, 14 + b], [15, 20 + b]])
	put_part(d, mn, T_PARA, true)
	var mh := newm(); E(mh, 7.6 + hx, 9.2 + b + hy, 3.6, 3.0)
	PG(mh, [[1.2 + hx, 9 + b + hy], [5, 8.4 + b + hy], [6, 12.8 + b + hy], [1.2 + hx, 12.2 + b + hy]])
	var ph := put_part(d, mh, T_PARA)
	D(ph, 7 + hx, 8 + b + hy, "K")
	D(ph, 2 + hx, 10 + b + hy, "deep_dk")
	if z["open"] == 1:
		for x in [2, 3, 4]:
			D(ph, x + hx, 12 + b + hy, "K")
	stamp(d, ph, true)
	# crista longa para tras (tubo), com listra
	var mc := newm()
	PG(mc, [[5.5 + hx, 7.5 + b + hy], [7 + hx, 3 + b + hy], [13, 1.2 + b + hy / 2.0], [24, 4.5 + b], [27, 8 + b], [24, 10 + b], [15, 6.4 + b + hy / 2.0], [10 + hx, 9 + b + hy]])
	var pc := put_part(d, mc, T_CREST)
	for q in [[11, 3], [14, 3], [17, 4], [20, 5], [23, 7]]:
		D(pc, q[0], q[1] + b, "f_dk")
	return d

func para_front(z: Dictionary) -> Image:
	var d := newm()
	var b: int = z["b"]
	var sw: int = z["sw"]
	var hy: int = z["hy"]
	# pernas de tras grossas, uma mais escura (fora da luz)
	var ml := newm(); R(ml, 8 + sw, 25 + b, 5, 6 - z["ll"] - b)
	put_part(d, ml, ["deep", "deep_dk", "deep_dk"])
	var mr := newm(); R(mr, 19 + sw, 25 + b, 5, 6 - z["rl"] - b)
	put_part(d, mr, T_PARA)
	# corpo largo com barriga clara
	var mb := newm(); E(mb, 16 + sw, 22 + b, 8.6, 6)
	var pb := put_part(d, mb, T_PARA)
	var mv := newm(); E(mv, 16 + sw, 24 + b, 4.6, 3)
	ovl(pb, mv, ["deep_hi", "deep_hi", "deep"])
	stamp(d, pb, true)
	# bracos curtos a frente do peito
	var ma := newm(); R(ma, 10 + sw, 20 + b, 3, 5); R(ma, 19 + sw, 20 + b, 3, 5)
	put_part(d, ma, ["deep", "deep_dk", "deep_dk"], true)
	# pescoco curto
	var mn := newm(); PG(mn, [[13 + sw, 10 + b], [19 + sw, 10 + b], [21 + sw, 18 + b], [11 + sw, 18 + b]])
	put_part(d, mn, T_PARA, true)
	# crista tubular: sobe atras da cabeca, ponta arredondada, listras
	var mc := newm(); PG(mc, [[14 + sw, 10 + b + hy], [14 + sw, 3.4 + b + hy], [15.2 + sw, 1.4 + b + hy], [17.8 + sw, 1.4 + b + hy], [19 + sw, 3.4 + b + hy], [19 + sw, 10 + b + hy]])
	var pc := put_part(d, mc, T_CREST)
	for y in [4, 6]:
		for x in [15, 16, 17]:
			D(pc, x + sw, y + b + hy, "f_dk")
	# cabeca: cupula com olhos nas laterais
	var mh := newm(); E(mh, 16 + sw, 9.6 + b + hy, 4.8, 3.6)
	var ph := put_part(d, mh, T_PARA)
	D(ph, 13 + sw, 9 + b + hy, "K"); D(ph, 18 + sw, 9 + b + hy, "K")
	stamp(d, ph, true)
	# bico de pato: espatula larga e chata, de outra cor, a frente
	var mk := newm(); E(mk, 16 + sw, 14.4 + b + hy, 5.6, 2.6)
	var pk := put_part(d, mk, ["ring", "orange", "w_dk"])
	D(pk, 14 + sw, 13 + b + hy, "w_dk"); D(pk, 17 + sw, 13 + b + hy, "w_dk")
	if z["open"] == 1:
		for x in [13, 14, 15, 16, 17, 18]:
			D(pk, x + sw, 15 + b + hy, "K")
	return d

func para_back(z: Dictionary) -> Image:
	var d := newm()
	var b: int = z["b"]
	var sw: int = z["sw"]
	var hy: int = z["hy"]
	var ml := newm(); R(ml, 9 + sw, 24 + b, 4, 7 - z["ll"] - b)
	put_part(d, ml, ["deep", "deep_dk", "deep_dk"])
	var mr := newm(); R(mr, 19 + sw, 24 + b, 4, 7 - z["rl"] - b)
	put_part(d, mr, T_PARA)
	var mb := newm(); E(mb, 16 + sw, 21.6 + b, 8.4, 5.6)
	put_part(d, mb, T_PARA)
	var mn := newm(); PG(mn, [[12.5 + sw, 12 + b], [19.5 + sw, 12 + b], [22 + sw, 20 + b], [10 + sw, 20 + b]])
	put_part(d, mn, T_PARA, true)
	var mh := newm(); E(mh, 16 + sw, 9.6 + b + hy, 3.8, 3.2)
	put_part(d, mh, T_PARA)
	var mc := newm(); R(mc, 15 + sw, 2 + b + hy, 3, 8); E(mc, 16.5 + sw, 2.8 + b + hy, 1.8, 1.4)
	var pc := put_part(d, mc, T_CREST)
	D(pc, 15 + sw, 5 + b + hy, "f_dk"); D(pc, 17 + sw, 7 + b + hy, "f_dk")
	var mt := newm(); PG(mt, [[12.5 + sw, 22 + b], [19.5 + sw, 22 + b], [18 + sw, 29 + b], [14 + sw, 29 + b]])
	put_part(d, mt, T_PARA)
	return d

func para_lying(dead: bool) -> Image:
	var d := newm()
	var mt := newm(); PG(mt, [[23, 23], [29, 26], [30.5, 27.5], [30, 29], [23, 29]])
	put_part(d, mt, T_PARA, true)
	var mb := newm()
	if dead:
		E(mb, 17, 22.5, 9, 5.2)
	else:
		E(mb, 17, 24.4, 9, 4.6)
	var pb := put_part(d, mb, T_PARA)
	if dead:
		var mv := newm(); E(mv, 17, 26, 6.5, 2.2)
		ovl(pb, mv, ["z_md", "z_md", "z_dk"])
		stamp(d, pb, true)
		for q in [[11, 13, 8], [16, 11, 10], [21, 12, 9], [7, 16, 6]]:
			var lg := newm(); R(lg, q[0], q[1], 3, q[2])
			put_part(d, lg, ["deep", "deep_dk", "deep_dk"])
	else:
		stamp(d, pb, true)
		for q in [[11, 28, 5], [18, 28, 5]]:
			var lg := newm(); R(lg, q[0], q[1], q[2], 2)
			put_part(d, lg, T_PARA)
	var mn := newm(); E(mn, 10.5, 24.6, 3.4, 3.0)
	put_part(d, mn, T_PARA, true)
	var mh := newm(); E(mh, 7.6, 25.8, 3.6, 2.8)
	PG(mh, [[1.2, 26], [5, 25], [6, 28.8], [1.2, 28.8]])
	var ph := put_part(d, mh, T_PARA)
	if dead:
		D(ph, 7, 24, "K"); D(ph, 8, 25, "K"); D(ph, 8, 24, "K"); D(ph, 7, 25, "K")
	else:
		D(ph, 7, 25, "K"); D(ph, 8, 25, "K")
	stamp(d, ph, true)
	var mc := newm(); PG(mc, [[7, 23.5], [10, 20.5], [17, 19.5], [24, 22], [24, 24], [17, 22], [10.5, 24]])
	var pc := put_part(d, mc, T_CREST)
	for q in [[13, 20], [16, 20], [19, 21]]:
		D(pc, q[0], q[1], "f_dk")
	return d

# ================================================================ UTAHRAPTOR (32)
func utah_side(z: Dictionary) -> Image:
	var d := newm()
	var b: int = z["b"]
	var hx: int = z["hx"]
	var hy: int = z["hy"]
	var tdark := ["w_dk", "f_dk", "f_dk"]
	utah_leg(d, 16 + z["fx"], b, z["fl"], tdark, false)
	# cauda longa e reta, ponta com penas
	var mt := newm(); PG(mt, [[19, 12.5 + b], [26, 12.5 + b], [30.5, 13.5 + b], [30.5, 16 + b], [26, 16.2 + b], [19, 18 + b]])
	var pt := put_part(d, mt, T_UTAH, true)
	for q in [[24, 13], [27, 14]]:
		D(pt, q[0], q[1] + b, "h_xx")
	for q in [[29, 12], [30, 12], [30, 11], [28, 12]]:
		D(d, q[0], q[1] + b, "K")
	for q in [[29, 13], [30, 13], [30, 14]]:
		D(pt, q[0], q[1] + b, "yellow")
	stamp(d, pt, true)
	var mb := newm(); E(mb, 14, 15 + b, 6.2, 3.8)
	var pb := put_part(d, mb, T_UTAH)
	for q in [[11, 13], [11, 14], [14, 12], [14, 13], [17, 12], [17, 13]]:
		D(pb, q[0], q[1] + b, "h_xx")
	for x in [10, 13, 16, 19]:
		D(pb, x, 11 + b, "ring")
	stamp(d, pb, true)
	utah_leg(d, 13 + z["nx"], b, z["nl"], T_UTAH, true)
	var mn := newm(); PG(mn, [[9, 14 + b], [7.5 + hx / 2.0, 9.5 + b + hy], [10.5 + hx / 2.0, 8 + b + hy], [12.5, 13 + b]])
	put_part(d, mn, T_UTAH, true)
	var mh := newm(); PG(mh, [[1 + hx, 9.6 + b + hy], [6, 6.6 + b + hy], [10, 7.6 + b + hy], [10, 11 + b + hy], [5, 11.4 + b + hy], [1 + hx, 11 + b + hy]])
	var ph := put_part(d, mh, T_UTAH)
	D(ph, 7 + hx, 8 + b + hy, "K")
	for q in [[6, 7], [7, 7]]:
		D(ph, q[0] + hx, q[1] + b + hy, "K")
	for q in [[9, 6], [10, 6], [10, 5], [11, 6]]:
		D(ph, q[0] + hx, q[1] + b + hy, "ring")
	stamp(d, ph, true)
	if z["open"] == 1:
		var mj := newm(); PG(mj, [[1 + hx, 12.6 + b + hy], [6, 11.6 + b + hy], [7.5, 14.2 + b + hy], [2 + hx, 14.8 + b + hy]])
		put_part(d, mj, ["f_dk", "f_dk", "f_dk"])
		for x in [2, 4, 6]:
			D(d, x + hx, 12 + b + hy, "white")
	else:
		for x in [2, 4]:
			D(d, x + hx, 11 + b + hy, "white")
	# braco com penas
	var ma := newm(); PG(ma, [[9.5, 14.5 + b], [6.5, 16.5 + b], [5, 18 + b], [8, 18.5 + b], [10.5, 17.5 + b]])
	var pa := put_part(d, ma, T_UTAH)
	for q in [[5, 19], [6, 19], [7, 19], [8, 19], [4, 18]]:
		D(pa, q[0], q[1] + b, "yellow")
	D(pa, 3, 18 + b, "K")
	stamp(d, pa, true)
	return d

func utah_leg(d: Image, x: int, b: int, lift: int, tones: Array, near: bool) -> void:
	var th := newm(); E(th, x + 1.5, 19.5 + b, 3.2, 3.6)
	var pth := put_part(d, th, tones)
	var sh := newm(); R(sh, x + 0.0, 22 + b, 2, G - 22 - b - lift)
	put_part(d, sh, tones, true)
	var ft := newm(); R(ft, x - 3.0, G - lift, 5, 1)
	var pf := put_part(d, ft, tones, true)
	if near and lift == 0:
		pass
	# garra em foice (levantada) no pe
	var cy := G - lift - 1
	D(d, int(x) - 3, cy, "cut")
	D(d, int(x) - 4, cy - 1, "cut")
	D(d, int(x) - 3, cy - 2 if near else cy - 1, "cut" if near else "ring2")
	if near and tones != T_UTAH:
		pass

## Pontos espelhados em torno de x = S/2 (para formas simetricas na vista de frente).
func mirp(pts: Array) -> Array:
	var q := []
	for p in pts:
		q.append([S - p[0], p[1]])
	return q

func utah_front(z: Dictionary) -> Image:
	var d := newm()
	var b: int = z["b"]
	var sw: int = z["sw"]
	var hy: int = z["hy"]
	# pernas: coxa para fora, canela fina, pe com garra em foice levantada (lado de dentro)
	for s in [0, 1]:
		var lift: int = z["ll"] if s == 0 else z["rl"]
		var tn: Array = ["w_dk", "f_dk", "f_dk"] if s == 0 else T_UTAH
		var sx := -1 if s == 0 else 1
		var cx: int = 16 + sx * 4 + sw
		var lg := newm()
		E(lg, cx + sx * 1.2, 21.5 + b, 2.8, 3.6)
		R(lg, cx - 1, 24 + b, 3, G - lift - 24 - b + 1)
		R(lg, cx - 2, G - lift, 5, 1)
		put_part(d, lg, tn)
		D(d, cx - 2, G - lift, "cut"); D(d, cx + 2, G - lift, "cut")
		D(d, cx - sx * 2, G - lift - 2, "cut"); D(d, cx - sx * 2, G - lift - 3, "cut")
	# tronco estreito
	var mb := newm(); E(mb, 16 + sw, 19 + b, 4.6, 6)
	var pb := put_part(d, mb, T_UTAH)
	for q in [[13, 19], [14, 20], [18, 19], [17, 20], [15, 23], [16, 23]]:
		D(pb, q[0] + sw, q[1] + b, "h_xx")
	stamp(d, pb, true)
	# bracos curtos e emplumados, abertos, com garras
	for s in [0, 1]:
		var pts := [[12, 16], [9.5, 16.5], [7.5, 20], [8.5, 22], [10.5, 20.5], [12, 19]]
		if s == 1:
			pts = mirp(pts)
		var ma := newm(); PG(ma, pts)
		var pa := put_part(d, ma, T_UTAH, true)
		for q in [[9, 17], [8, 18], [8, 19]]:
			D(pa, (q[0] if s == 0 else S - 1 - q[0]) + sw, q[1] + b, "yellow")
		D(d, (8 if s == 0 else 23) + sw, 22 + b, "cut"); D(d, (7 if s == 0 else 24) + sw, 22 + b, "cut")
	# cabeca larga: cranio com olhos nas laterais, focinho em cunha para a camera, mandibula
	var mh := newm()
	PG(mh, [[10.5, 8 + b + hy], [12.5, 5 + b + hy], [19.5, 5 + b + hy], [21.5, 8 + b + hy], [20, 11 + b + hy], [18.4, 12.5 + b + hy], [17.6, 16 + b + hy], [14.4, 16 + b + hy], [13.6, 12.5 + b + hy], [12, 11 + b + hy]])
	var ph := put_part(d, mh, T_UTAH)
	D(ph, 13 + sw, 8 + b + hy, "K"); D(ph, 18 + sw, 8 + b + hy, "K")
	D(ph, 12 + sw, 7 + b + hy, "w_dk"); D(ph, 13 + sw, 7 + b + hy, "w_dk"); D(ph, 18 + sw, 7 + b + hy, "w_dk"); D(ph, 19 + sw, 7 + b + hy, "w_dk")
	D(ph, 15 + sw, 11 + b + hy, "f_dk"); D(ph, 16 + sw, 11 + b + hy, "f_dk")
	var mj := newm(); R(mj, 14, 13.6 + b + hy, 4, 2.4)
	ovl(ph, mj, ["w_dk", "f_dk", "f_dk"])
	if z["open"] == 1:
		for x in [15, 16]:
			D(ph, x + sw, 14 + b + hy, "K")
		for x in [14, 17]:
			D(ph, x + sw, 13 + b + hy, "white")
		for x in [15, 16]:
			D(ph, x + sw, 15 + b + hy, "white")
	else:
		D(ph, 14 + sw, 14 + b + hy, "white"); D(ph, 17 + sw, 14 + b + hy, "white")
	stamp(d, ph, true)
	# tufo de penas atras do cranio
	var mf := newm(); PG(mf, [[14, 5.5 + b + hy], [14.6, 2 + b + hy], [17.4, 2 + b + hy], [18, 5.5 + b + hy]])
	put_part(d, mf, T_FEATH, true)
	return d

func utah_back(z: Dictionary) -> Image:
	var d := newm()
	var b: int = z["b"]
	var sw: int = z["sw"]
	var hy: int = z["hy"]
	for q in [[12, z["ll"], ["w_dk", "f_dk", "f_dk"]], [17, z["rl"], T_UTAH]]:
		var lg := newm(); R(lg, q[0] + sw, 22 + b, 3, 8 - q[1] - b)
		put_part(d, lg, q[2])
	var mb := newm(); E(mb, 16 + sw, 17.6 + b, 4.4, 5.2)
	var pb := put_part(d, mb, T_UTAH)
	for q in [[14, 15], [14, 16], [17, 15], [17, 16], [15, 19], [16, 19]]:
		D(pb, q[0] + sw, q[1] + b, "h_xx")
	for y in [14, 17, 20]:
		D(pb, 15 + sw, y + b, "ring"); D(pb, 16 + sw, y + b, "ring")
	stamp(d, pb, true)
	var ma := newm(); R(ma, 10 + sw, 15 + b, 2, 5); R(ma, 20 + sw, 15 + b, 2, 5)
	var pa := put_part(d, ma, T_UTAH, true)
	D(pa, 10 + sw, 19 + b, "yellow"); D(pa, 21 + sw, 19 + b, "yellow")
	stamp(d, pa, true)
	var mh := newm(); E(mh, 16 + sw, 9.4 + b + hy, 3.5, 3.4)
	var ph := put_part(d, mh, T_UTAH)
	for q in [[15, 5], [16, 5], [15, 4], [16, 4]]:
		D(ph, q[0] + sw, q[1] + b + hy, "ring")
	stamp(d, ph, true)
	# cauda comprida vem para a camera
	var mt := newm(); PG(mt, [[13.5 + sw, 21 + b], [18.5 + sw, 21 + b], [17.5 + sw, 30 + b], [14.5 + sw, 30 + b]])
	var pt := put_part(d, mt, T_UTAH)
	for y in [24, 27]:
		D(pt, 15 + sw, y + b, "h_xx"); D(pt, 16 + sw, y + b, "h_xx")
	D(pt, 15 + sw, 29 + b, "yellow"); D(pt, 16 + sw, 29 + b, "yellow")
	return d

func utah_lying(dead: bool) -> Image:
	var d := newm()
	var mt := newm(); PG(mt, [[20, 25], [27, 26], [30.5, 28], [30.5, 29.5], [20, 29.5]])
	var pt := put_part(d, mt, T_UTAH, true)
	for x in [24, 27]:
		D(pt, x, 28, "h_xx")
	var mb := newm()
	if dead:
		E(mb, 15, 22.6, 6.4, 4.4)
	else:
		E(mb, 15, 25.4, 6.4, 3.6)
	var pb := put_part(d, mb, T_UTAH)
	if dead:
		var mv := newm(); E(mv, 15, 25, 4.2, 1.8)
		ovl(pb, mv, ["sk_hi", "sk_hi", "sk_md"])
		stamp(d, pb, true)
		for q in [[12, 11, 12], [17, 10, 13]]:
			var lg := newm(); R(lg, q[0], q[1], 2, q[2])
			put_part(d, lg, T_UTAH)
			D(d, q[0] - 1, q[1], "cut"); D(d, q[0] - 1, q[1] - 1, "cut")
	else:
		for x in [11, 14, 17]:
			D(pb, x, 24, "h_xx"); D(pb, x, 25, "h_xx")
		stamp(d, pb, true)
		var lg := newm(); R(lg, 12, 28, 6, 2)
		put_part(d, lg, T_UTAH)
	var mh := newm(); PG(mh, [[2, 26], [6, 23.6], [10, 24.4], [10, 28.6], [5, 28.8], [2, 28.6]])
	var ph := put_part(d, mh, T_UTAH)
	if dead:
		D(ph, 6, 25, "K"); D(ph, 7, 26, "K"); D(ph, 7, 25, "K"); D(ph, 6, 26, "K")
		D(ph, 3, 28, "white"); D(ph, 5, 28, "white")
	else:
		D(ph, 6, 26, "K"); D(ph, 7, 26, "K")
	stamp(d, ph, true)
	for q in [[9, 23], [10, 23], [10, 22]]:
		D(d, q[0], q[1], "ring")
	return d

# ================================================================ TRICERATOPS (48)
func trike_side(z: Dictionary) -> Image:
	var d := newm()
	var b: int = z["b"]
	var hx: int = z["hx"]
	var hy: int = z["hy"]
	var dkl := ["g_gr", "g_dk", "g_dk"]
	leg(d, 33 + z["nx"], 34 + b, 8, z["nl"], dkl, 3)
	leg(d, 18 + z["fx"], 34 + b, 7, z["fl"], dkl, 3)
	var mt := newm(); PG(mt, [[39, 27 + b], [46, 31 + b], [46.5, 34 + b], [39, 36 + b]])
	put_part(d, mt, T_TRIKE, true)
	var mb := newm(); E(mb, 27, 29 + b, 15, 9.5)
	var pb := put_part(d, mb, T_TRIKE)
	for q in [[24, 21], [28, 20], [32, 21], [36, 23]]:
		D(pb, q[0], q[1] + b, "g_hi")
	stamp(d, pb, true)
	leg(d, 29 + z["fx"], 34 + b, 8, z["fl"], T_TRIKE, 3)
	leg(d, 14 + z["nx"], 34 + b, 7, z["nl"], T_TRIKE, 3)
	for q in [[11, 46], [12, 46], [13, 46]]:
		pass
	# babado (frill) atras da cabeca
	var mf := newm(); PG(mf, [[13 + hx, 32 + b + hy], [10.5 + hx, 22 + b + hy], [14 + hx, 14 + b + hy], [21 + hx, 11.5 + b + hy], [27 + hx, 18 + b + hy], [25 + hx, 29 + b + hy]])
	var pf := put_part(d, mf, T_FRILL)
	for q in [[11, 20], [11, 17], [13, 14], [16, 12], [19, 11], [22, 11], [25, 13], [27, 16], [28, 19]]:
		D(pf, q[0] + hx, q[1] + b + hy, "ring2")
	for q in [[15, 16], [18, 15], [21, 15], [17, 21], [21, 21]]:
		D(pf, q[0] + hx, q[1] + b + hy, "f_dk")
	stamp(d, pf, true)
	# cabeca baixa, bico
	var mh := newm(); E(mh, 10.5 + hx, 31 + b + hy, 6.8, 5.6)
	var ph := put_part(d, mh, T_TRIKE)
	D(ph, 10 + hx, 29 + b + hy, "K"); D(ph, 9 + hx, 29 + b + hy, "K")
	if z["open"] == 1:
		for x in [6, 7, 8, 9]:
			D(ph, x + hx, 34 + b + hy, "K")
	stamp(d, ph, true)
	var mk := newm(); E(mk, 5.6 + hx, 33.4 + b + hy, 3.2, 2.8); PG(mk, [[2.6 + hx, 33 + b + hy], [4 + hx, 31.5 + b + hy], [4 + hx, 36 + b + hy]])
	put_part(d, mk, T_HORN)
	# tres chifres: dois grandes acima dos olhos, um curto no nariz
	var mhf := newm(); PG(mhf, [[11.5 + hx, 27.5 + b + hy], [13.5 + hx, 25.5 + b + hy], [6 + hx, 16 + b + hy], [4.5 + hx, 17.2 + b + hy]])
	put_part(d, mhf, ["ring2", "w_hi", "w_hi"])
	var mhn := newm(); PG(mhn, [[9 + hx, 28.5 + b + hy], [11.5 + hx, 27 + b + hy], [4.2 + hx, 20.5 + b + hy], [3 + hx, 21.8 + b + hy]])
	put_part(d, mhn, T_HORN)
	var mno := newm(); PG(mno, [[5 + hx, 30.5 + b + hy], [8 + hx, 30.8 + b + hy], [3 + hx, 25 + b + hy], [1.6 + hx, 26.4 + b + hy]])
	put_part(d, mno, T_HORN)
	return d

func trike_front(z: Dictionary) -> Image:
	var d := newm()
	var b: int = z["b"]
	var sw: int = z["sw"]
	var hy: int = z["hy"]
	var mf := newm(); E(mf, 24 + sw, 17 + b + hy, 13.5, 11.5)
	var pf := put_part(d, mf, T_FRILL)
	rim(pf, 24 + sw, 17 + b + hy, 12.5, 10.5, PI * 1.02, PI * 1.98, 11, "ring2")
	for q in [[18, 13], [24, 11], [30, 13], [21, 16], [27, 16]]:
		D(pf, q[0] + sw, q[1] + b + hy, "f_dk")
	stamp(d, pf)
	var ml := newm(); R(ml, 11 + sw, 38 + b, 8, 8 - z["ll"] - b)
	put_part(d, ml, ["g_gr", "g_dk", "g_dk"])
	var mr := newm(); R(mr, 29 + sw, 38 + b, 8, 8 - z["rl"] - b)
	put_part(d, mr, T_TRIKE)
	for x in [12, 14, 16]:
		D(d, x + sw, G - z["ll"], "cut")
	for x in [30, 32, 34]:
		D(d, x + sw, G - z["rl"], "cut")
	var mb := newm(); E(mb, 24 + sw, 35.6 + b, 14, 8.6)
	put_part(d, mb, T_TRIKE)
	var mh := newm(); E(mh, 24 + sw, 27.4 + b + hy, 8.4, 6.6)
	var ph := put_part(d, mh, T_TRIKE)
	D(ph, 19 + sw, 26 + b + hy, "K"); D(ph, 28 + sw, 26 + b + hy, "K")
	D(ph, 18 + sw, 25 + b + hy, "K"); D(ph, 29 + sw, 25 + b + hy, "K")
	stamp(d, ph, true)
	var mk := newm(); R(mk, 20.5 + sw, 31 + b + hy, 7, 3); E(mk, 24 + sw, 32 + b + hy, 3.5, 2.2)
	var pk := put_part(d, mk, T_HORN)
	if z["open"] == 1:
		for x in [22, 23, 24, 25]:
			D(pk, x + sw, 33 + b + hy, "K")
	# chifres: dois grandes acima dos olhos e um no nariz
	var mhl := newm(); PG(mhl, [[17 + sw, 25 + b + hy], [20.5 + sw, 25 + b + hy], [15 + sw, 11.5 + b + hy]])
	put_part(d, mhl, ["ring2", "w_hi", "w_hi"])
	var mhr := newm(); PG(mhr, [[27.5 + sw, 25 + b + hy], [31 + sw, 25 + b + hy], [33 + sw, 11.5 + b + hy]])
	put_part(d, mhr, ["ring2", "w_hi", "w_hi"])
	var mn := newm(); PG(mn, [[22 + sw, 28.5 + b + hy], [26 + sw, 28.5 + b + hy], [24 + sw, 33.5 + b + hy]])
	put_part(d, mn, T_HORN)
	return d

func trike_back(z: Dictionary) -> Image:
	var d := newm()
	var b: int = z["b"]
	var sw: int = z["sw"]
	var hy: int = z["hy"]
	var ml := newm(); R(ml, 11 + sw, 38 + b, 8, 8 - z["ll"] - b)
	put_part(d, ml, ["g_gr", "g_dk", "g_dk"])
	var mr := newm(); R(mr, 29 + sw, 38 + b, 8, 8 - z["rl"] - b)
	put_part(d, mr, T_TRIKE)
	var mb := newm(); E(mb, 24 + sw, 33 + b, 14.5, 10.4)
	var pb := put_part(d, mb, T_TRIKE)
	for q in [[18, 25], [24, 24], [30, 25], [21, 28], [27, 28]]:
		D(pb, q[0] + sw, q[1] + b, "g_hi")
	stamp(d, pb, true)
	var mf := newm(); E(mf, 24 + sw, 17 + b + hy, 13.5, 11.5)
	var pf := put_part(d, mf, T_FRILL, true, [-0.1, 0.5, 0.9])
	rim(pf, 24 + sw, 17 + b + hy, 12.5, 10.5, PI * 1.0, PI * 2.0, 11, "ring2")
	for q in [[14, 17], [14, 21], [34, 17], [34, 21], [20, 14], [28, 14], [24, 19]]:
		D(pf, q[0] + sw, q[1] + b + hy, "f_dk")
	stamp(d, pf, true)
	var mt := newm(); PG(mt, [[21 + sw, 36 + b], [27 + sw, 36 + b], [26 + sw, 45 + b], [22 + sw, 45 + b]])
	put_part(d, mt, T_TRIKE)
	return d

func trike_lying(dead: bool) -> Image:
	var d := newm()
	var mt := newm(); PG(mt, [[39, 38], [46, 41], [46.5, 43.5], [39, 45.5]])
	put_part(d, mt, T_TRIKE, true)
	var mb := newm()
	if dead:
		E(mb, 27, 35.4, 15, 8.8)
	else:
		E(mb, 27, 37.4, 15, 7.6)
	var pb := put_part(d, mb, T_TRIKE)
	if dead:
		var mv := newm(); E(mv, 27, 40.6, 11, 3.6)
		ovl(pb, mv, ["z_md", "z_md", "z_dk"])
		stamp(d, pb, true)
		for q in [[16, 20, 14], [22, 19, 15], [32, 19, 15], [38, 21, 13]]:
			var lg := newm(); R(lg, q[0], q[1], 6, q[2])
			put_part(d, lg, T_TRIKE)
			for x in [0, 2, 4]:
				D(d, q[0] + x, q[1], "cut")
	else:
		stamp(d, pb, true)
		for q in [[17, 7], [31, 8]]:
			var lg := newm(); R(lg, q[0], 43, q[1], 3)
			put_part(d, lg, T_TRIKE)
	# babado ereto atras da cabeca
	var mf := newm(); PG(mf, [[14, 42], [12, 33], [15, 27], [21, 25], [25, 31], [24, 41]])
	var pf := put_part(d, mf, T_FRILL)
	for q in [[12, 33], [13, 29], [16, 26], [20, 25], [23, 27], [25, 31]]:
		D(pf, q[0], q[1], "ring2")
	var mh := newm(); E(mh, 10, 41.4, 6.8, 4.6)
	var ph := put_part(d, mh, T_TRIKE)
	if dead:
		D(ph, 10, 39, "K"); D(ph, 11, 40, "K"); D(ph, 11, 39, "K"); D(ph, 10, 40, "K")
	else:
		D(ph, 10, 40, "K"); D(ph, 11, 40, "K"); D(ph, 9, 40, "K")
	stamp(d, ph, true)
	var mk := newm(); E(mk, 5, 43, 3.2, 2.4)
	put_part(d, mk, T_HORN)
	var mhn := newm(); PG(mhn, [[9, 38], [12, 38], [3, 33], [2, 34.6]])
	put_part(d, mhn, ["ring2", "w_hi", "w_hi"])
	var mno := newm(); PG(mno, [[4.5, 41.5], [7, 41.5], [1.5, 38], [1, 39.4]])
	put_part(d, mno, T_HORN)
	return d
