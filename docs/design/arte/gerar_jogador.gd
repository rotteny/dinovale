## Gerador do jogador 16x32 (homem das cavernas, sem camisa, tanga de folhas, sem acessorios).
## Arte propria, CC BY 4.0, sem IA e sem recorte de terceiros. Da raiz do repositorio:
##   godot --headless --script docs/design/arte/gerar_jogador.gd
## Saida: game/assets/sprites/jogador/jogador.png  (folha 160x128, quadro 16x32, 10 colunas x 4 linhas)
##        game/assets/sprites/jogador/jogador.json (nomes dos quadros e das animacoes, para o SORA)
## Linhas (direcao): 0 baixo, 1 cima, 2 esquerda, 3 direita.
## Walk de frente/costas: 4 quadros distintos (passada alternada, bracos contrarios). Golpe para cima: braco some atras da cabeca.
## Colunas: 0-1 parado, 2-5 andar (4), 6-8 golpe (3: preparo, impacto, volta), 9 caido.
## Ancora: base do quadro (pes em y=30, contorno em y=31). Luz de cima-esquerda tambem na direita.
## Sem equipamento: o equipamento vem em camadas depois, no mesmo quadro de 16x32.
extends SceneTree
const Lib = preload("arte_lib.gd")
var L = Lib.new()
const OUT := "game/assets/sprites/jogador/"
const FW := 16
const FH := 32
var M := false  # espelha o desenho (direita); o sombreamento segue as coordenadas finais

func _init() -> void:
	var sheet: Image = L.img(FW * 10, FH * 4)
	var dirs := ["down", "up", "left", "right"]
	var names := []
	for d in 4:
		var cols := []
		for f in 2: cols.append(["idle", f])
		for f in 4: cols.append(["walk", f])
		for f in 3: cols.append(["hit", f])
		cols.append(["fall", 0])
		for c in cols.size():
			var fr: Image = frame(d, cols[c][0], cols[c][1])
			L.blit(sheet, fr, c * FW, d * FH)
	L.save_png_checked(sheet, OUT + "jogador.png")
	var js := {
		"arquivo": "jogador.png", "quadro": [FW, FH], "colunas": 10, "linhas": 4,
		"linhas_direcao": dirs,
		"animacoes": {"idle": {"colunas": [0, 1], "fps": 2, "loop": true}, "walk": {"colunas": [2, 3, 4, 5], "fps": 8, "loop": true},
			"hit": {"colunas": [6, 7, 8], "fps": 10, "loop": false}, "fall": {"colunas": [9], "fps": 1, "loop": false}},
		"ancora": "base do quadro (pes em y=30)", "colisao_pes": [12, 8], "direita": "desenhada a parte (nao e espelho)",
		"caido": "baixo: de costas (cabeca para a camera); cima: de bruços; esquerda/direita: de lado, perfil, joelhos dobrados",
	}
	var f := FileAccess.open(OUT + "jogador.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(js, "\t"))
	f.close()
	quit()

# ---------------------------------------------------------------- primitivas de parte
func fx(x: int, w: int) -> int:
	return 16 - (x + w) if M else x

## Retangulo sombreado (luz cima-esquerda). Coordenadas de projeto (olhando para a esquerda).
func sh(p: Image, x: int, y: int, w: int, h: int, hi: String, md: String, dk: String) -> void:
	var X := fx(x, w)
	for yy in h:
		for xx in w:
			var c := md
			var top := yy == 0 and h >= 3
			var bot := yy == h - 1 and h >= 3
			var lef := xx == 0 and w >= 3
			var rig := xx == w - 1 and w >= 3
			if bot or rig:
				c = dk
			elif top or lef:
				c = hi
			L.put(p, X + xx, y + yy, c)

func dot(p: Image, x: int, y: int, c: String) -> void:
	L.put(p, 15 - x if M else x, y, c)

func clear(p: Image, x: int, y: int) -> void:
	var X := 15 - x if M else x
	if X >= 0 and X < p.get_width() and y >= 0 and y < p.get_height():
		p.set_pixel(X, y, Color(0, 0, 0, 0))

## Carimba a parte sobre o quadro com contorno K de 1 px ao redor.
func stamp(dst: Image, p: Image, soft := false) -> void:
	for y in p.get_height():
		for x in p.get_width():
			if p.get_pixel(x, y).a > 0.5:
				continue
			if soft and L.solid(dst, x, y):
				continue  # contorno "macio": nao corta as partes ja pintadas
			for d in [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]:
				if L.solid(p, x + d.x, y + d.y):
					L.put(dst, x, y, "K")
					break
	L.blit(dst, p, 0, 0)

func newp() -> Image:
	return L.img(FW, FH)

func skin(p: Image, x: int, y: int, w: int, h: int, far := false) -> void:
	if far:
		sh(p, x, y, w, h, "sk_md", "sk_dk", "sk_dk")
	else:
		sh(p, x, y, w, h, "sk_hi", "sk_md", "sk_dk")

# ---------------------------------------------------------------- partes
func leg(dst: Image, x: int, top: int, bot: int, far := false, toe := 0) -> void:
	var p := newp()
	skin(p, x, top, 3, bot - top + 1, far)
	if toe != 0:
		dot(p, x + (-1 if toe < 0 else 3), bot, "sk_md" if not far else "sk_dk")
	stamp(dst, p)

func torso(dst: Image, d: int, b: int) -> void:
	var p := newp()
	if d < 2:
		skin(p, 4, 13 + b, 8, 8)
		if d == 0:
			for q in [[5, 17], [6, 17], [9, 17], [10, 17]]:
				dot(p, q[0], q[1] + b, "sk_dk")
			dot(p, 7, 14 + b, "sk_dk"); dot(p, 8, 14 + b, "sk_dk")
			for q in [[5, 15], [6, 15], [9, 15]]:
				dot(p, q[0], q[1] + b, "sk_hi")
			dot(p, 7, 18 + b, "sk_dk"); dot(p, 8, 18 + b, "sk_dk")
		else:
			for q in [[5, 15], [6, 15], [9, 15], [10, 15], [7, 16], [8, 16], [7, 17], [8, 17]]:
				dot(p, q[0], q[1] + b, "sk_dk")
	else:
		skin(p, 5, 13 + b, 6, 8)
		dot(p, 5, 16 + b, "sk_hi"); dot(p, 5, 17 + b, "sk_dk")
	stamp(dst, p)

func skirt(dst: Image, d: int, b: int) -> void:
	var p := newp()
	if d < 2:
		sh(p, 4, 19 + b, 8, 1, "g_dk", "g_dk", "g_dk")
		sh(p, 3, 20 + b, 10, 4, "g_hi", "g_md", "g_dk")
		# pontas das folhas
		for x in [3, 4, 6, 7, 8, 9, 11, 12]:
			L.put(p, x, 24 + b, "g_md")
		L.put(p, 3, 24 + b, "g_hi"); L.put(p, 4, 24 + b, "g_hi")
		L.put(p, 11, 24 + b, "g_dk"); L.put(p, 12, 24 + b, "g_dk")
		# nervuras
		for y in [21, 22, 23]:
			L.put(p, 5, y + b, "g_dk"); L.put(p, 10, y + b, "g_dk")
		L.put(p, 7, 22 + b, "g_hi"); L.put(p, 8, 22 + b, "g_md")
	else:
		sh(p, 5, 19 + b, 6, 1, "g_dk", "g_dk", "g_dk")
		sh(p, 4, 20 + b, 8, 4, "g_hi", "g_md", "g_dk")
		for x in [4, 5, 7, 8, 10, 11]:
			L.put(p, x, 24 + b, "g_md")
		L.put(p, 4, 24 + b, "g_hi"); L.put(p, 5, 24 + b, "g_hi")
		L.put(p, 10, 24 + b, "g_dk"); L.put(p, 11, 24 + b, "g_dk")
		for y in [21, 22, 23]:
			L.put(p, 6, y + b, "g_dk"); L.put(p, 9, y + b, "g_dk")
	stamp(dst, p)

func arm_v(dst: Image, x: int, top: int, len_: int, far := false) -> void:
	var p := newp()
	skin(p, x, top, 2, len_, far)
	L.put(p, fx(x, 2), top + len_ - 1, "sk_md" if not far else "sk_dk")
	stamp(dst, p)

func head(dst: Image, d: int, b: int) -> void:
	var p := newp()
	if d == 0:
		skin(p, 3, 2 + b, 10, 10)
		for q in [[3, 2], [12, 2], [3, 11], [12, 11]]:
			clear(p, q[0], q[1] + b)
		for x in range(3, 13):
			for y in range(2, 5):
				L.put(p, x, y + b, "h_hi" if (y == 2 or x == 3) else ("h_dk" if (y == 4 or x == 12) else "h_md"))
		for x in [3, 4, 5, 8, 11, 12]:
			L.put(p, x, 5 + b, "h_dk")
		for x in [3, 12]:
			L.put(p, x, 6 + b, "h_dk")
		clear(p, 3, 2 + b); clear(p, 12, 2 + b)
		for x in [5, 6, 9]:
			L.put(p, x, 1 + b, "h_md")
		L.put(p, 5, 1 + b, "h_hi")
		# rosto
		for x in [4, 5, 6, 9, 10, 11]:
			L.put(p, x, 6 + b, "sk_dk")
		L.put(p, 5, 7 + b, "K"); L.put(p, 10, 7 + b, "K")
		L.put(p, 7, 8 + b, "sk_dk"); L.put(p, 8, 8 + b, "sk_xx")
		L.put(p, 7, 10 + b, "sk_xx"); L.put(p, 8, 10 + b, "sk_xx")
	elif d == 1:
		skin(p, 3, 2 + b, 10, 10)
		for q in [[3, 2], [12, 2], [3, 11], [12, 11]]:
			clear(p, q[0], q[1] + b)
		for x in range(3, 13):
			for y in range(2, 10):
				L.put(p, x, y + b, "h_hi" if (y == 2 or x == 3) else ("h_dk" if (y >= 8 or x == 12) else "h_md"))
		clear(p, 3, 2 + b); clear(p, 12, 2 + b)
		L.put(p, 7, 9 + b, "sk_dk"); L.put(p, 8, 9 + b, "sk_dk"); L.put(p, 4, 9 + b, "sk_md"); L.put(p, 11, 9 + b, "sk_dk")
		for x in [5, 6, 9, 10]:
			L.put(p, x, 1 + b, "h_md")
		L.put(p, 5, 1 + b, "h_hi")
		# mechas
		for q in [[6, 5], [7, 6], [9, 4], [8, 7], [5, 7]]:
			L.put(p, q[0], q[1] + b, "h_dk")
	else:
		# perfil: olha para a esquerda (projeto); direita espelha as coordenadas
		skin(p, 4, 2 + b, 9, 10)
		for q in [[4, 2], [12, 2], [4, 11], [12, 11]]:
			clear(p, q[0], q[1] + b)
		for x in range(4, 13):
			for y in range(2, 5):
				L.put(p, fx(x, 1), y + b, "h_hi" if (y == 2 or x == 4) else ("h_dk" if y == 4 else "h_md"))
		for x in range(9, 13):
			for y in range(5, 10):
				L.put(p, fx(x, 1), y + b, "h_md" if (x < 12 and y < 9) else "h_dk")
		for x in [4, 5, 6]:
			dot(p, x, 5 + b, "h_dk" if x == 6 else "h_md")
		clear(p, 4, 2 + b); clear(p, 12, 2 + b)
		for x in [6, 7, 10]:
			dot(p, x, 1 + b, "h_md")
		dot(p, 6, 1 + b, "h_hi")
		# rosto
		dot(p, 5, 6 + b, "sk_dk"); dot(p, 6, 6 + b, "sk_dk"); dot(p, 7, 6 + b, "sk_dk")
		dot(p, 6, 7 + b, "K")
		dot(p, 3, 8 + b, "sk_md"); dot(p, 4, 8 + b, "sk_md")  # nariz sai do contorno
		dot(p, 5, 10 + b, "sk_xx"); dot(p, 6, 10 + b, "sk_xx")
		dot(p, 9, 7 + b, "sk_dk"); dot(p, 9, 8 + b, "sk_md")  # orelha
	stamp(dst, p)

# ---------------------------------------------------------------- quadros
## Parametros de pose por direcao e animacao.
func frame(d: int, anim: String, f: int) -> Image:
	M = (d == 3)
	var dst: Image = L.img(FW, FH)
	if anim == "fall":
		return fall(d)
	var b := 0          # deslocamento do corpo
	var hb := 0         # deslocamento extra so da cabeca (respirar)
	var lift_l := 0     # perna esquerda levantada (frente/costas) ou deslocamento x (lado)
	var lift_r := 0
	var arm_l := 0
	var arm_r := 0
	var sx_n := 0       # lado: perna e braco proximos
	var sx_f := 0
	var ax_n := 0
	var ax_f := 0
	var lift_n := 0
	var lift_f := 0
	if anim == "idle":
		hb = 1 if f == 1 else 0
	elif anim == "walk":
		match f:
			0: lift_r = 2; arm_l = 2; arm_r = -2; sx_n = 2; sx_f = -2; ax_n = -2; ax_f = 2
			1: b = -1; lift_n = 1; ax_n = 0; ax_f = 0; lift_r = 1; arm_l = 1; arm_r = -1
			2: lift_l = 2; arm_l = -2; arm_r = 2; sx_n = -2; sx_f = 2; ax_n = 2; ax_f = -2
			3: b = -1; lift_f = 1; lift_l = 1; arm_l = -1; arm_r = 1
	if anim == "hit":
		return hit(d, f)
	# ---- ordem de pintura
	if d < 2:
		leg(dst, 4, 25 + b, 30 - lift_l)
		leg(dst, 9, 25 + b, 30 - lift_r)
		torso(dst, d, b)
		skirt(dst, d, b)
		arm_v(dst, 1, 14 + b + arm_l, 8)
		arm_v(dst, 13, 14 + b + arm_r, 8)
		head(dst, d, b + hb)
	else:
		# lado (projeto: olhando para a esquerda): perna/braco distantes primeiro
		arm_side(dst, 8 + ax_f, 14 + b, true)
		leg(dst, 8 + sx_f, 25 + b, 30 - lift_f, true, -1)
		leg(dst, 5 + sx_n, 25 + b, 30 - lift_n, false, -1)
		torso(dst, d, b)
		skirt(dst, d, b)
		arm_side(dst, 6 + ax_n, 14 + b, false)
		head(dst, d, b + hb)
	return dst

func arm_side(dst: Image, x: int, y: int, far: bool) -> void:
	var p := newp()
	skin(p, x, y, 3, 8, far)
	L.put(p, fx(x, 3) + (0 if not M else 2), y + 7, "sk_md" if not far else "sk_dk")
	stamp(dst, p, not far)

func hit(d: int, f: int) -> Image:
	M = (d == 3)
	var dst: Image = L.img(FW, FH)
	# f0 preparo (braco para tras e para cima), f1 impacto (esticado a frente, corpo inclina), f2 volta
	var b := 1 if f == 1 else 0
	if d == 0:
		leg(dst, 4, 25, 30); leg(dst, 9, 25, 30)
		torso(dst, 0, b); skirt(dst, 0, b)
		arm_v(dst, 1, 14 + b, 8)
		match f:
			0: arm_v(dst, 13, 8, 7)
			1:
				var p := newp(); skin(p, 9, 15 + b, 3, 8); skin(p, 10, 22 + b, 4, 4)
				stamp(dst, p)
			2: arm_v(dst, 13, 16, 8)
		head(dst, 0, b)
	elif d == 1:
		# de costas, o golpe vai para longe da camera: f0 cotovelo para fora e punho no alto, f1 ombro sobe,
		# corpo avanca 1 px e o punho aparece ao lado da cabeca, f2 braco baixa em diagonal
		var bb := -1 if f == 1 else 0
		leg(dst, 4, 25, 30); leg(dst, 9 + (1 if f == 1 else 0), 25, 30 - (1 if f == 1 else 0))
		arm_v(dst, 1, 14 + bb, 8)
		match f:
			0:
				var a0 := newp(); skin(a0, 12, 14, 4, 3); skin(a0, 13, 7, 3, 8); stamp(dst, a0)
			1:
				var a1 := newp(); skin(a1, 11, 4, 3, 12); stamp(dst, a1)
			2:
				var a2 := newp(); skin(a2, 13, 13, 2, 9); skin(a2, 14, 19, 2, 4); stamp(dst, a2)
		torso(dst, 1, bb); skirt(dst, 1, bb)
		head(dst, 1, bb)
		if f == 1:
			var p := newp(); skin(p, 12, 2, 4, 5); L.put(p, 12, 2, "sk_hi"); L.put(p, 13, 2, "sk_hi"); stamp(dst, p)
	else:
		arm_side(dst, 9, 14, true)
		leg(dst, 8 + (1 if f == 1 else 0), 25, 30, true, -1)
		leg(dst, 5 - (1 if f == 1 else 0), 25, 30, false, -1)
		torso(dst, d, b); skirt(dst, d, b)
		match f:
			0:
				var p := newp(); skin(p, 9, 10, 3, 7); stamp(dst, p, true)
			1:
				var p := newp(); skin(p, 0, 15, 9, 3); skin(p, 0, 14, 3, 5); stamp(dst, p, true)
			2:
				var p := newp(); skin(p, 5, 15, 5, 3); stamp(dst, p, true)
		head(dst, d, b)
	return dst

## Caido: de costas (cabeca para a camera) em baixo/esquerda/direita; de bruços em cima.
func fall(d: int) -> Image:
	M = (d == 3)
	var dst: Image = L.img(FW, FH)
	if d == 1:
		# de bruços: cabeca longe (em cima), solas dos pes perto da camera
		var h := newp()
		skin(h, 3, 10, 10, 8)
		for x in range(3, 13):
			for y in range(10, 17):
				L.put(h, x, y, "h_hi" if (y == 10 or x == 3) else ("h_dk" if (y >= 15 or x == 12) else "h_md"))
		for q in [[3, 10], [12, 10], [3, 17], [12, 17]]:
			h.set_pixel(q[0], q[1], Color(0, 0, 0, 0))
		L.put(h, 5, 17, "sk_dk"); L.put(h, 10, 17, "sk_dk"); L.put(h, 7, 17, "sk_md"); L.put(h, 8, 17, "sk_md")
		var t := newp(); skin(t, 4, 18, 8, 6)
		for q in [[5, 20], [6, 20], [9, 20], [10, 20], [7, 21], [8, 21]]:
			L.put(t, q[0], q[1], "sk_dk")
		stamp(dst, t)
		stamp(dst, h)
		var ar := newp(); skin(ar, 1, 16, 2, 8); stamp(dst, ar)
		var al := newp(); skin(al, 13, 16, 2, 8); stamp(dst, al)
		var sk := newp()
		sh(sk, 3, 24, 10, 4, "g_hi", "g_md", "g_dk")
		for x in [3, 4, 6, 7, 8, 9, 11, 12]:
			L.put(sk, x, 27, "g_md")
		L.put(sk, 5, 25, "g_dk"); L.put(sk, 10, 25, "g_dk")
		stamp(dst, sk)
		leg(dst, 4, 28, 30); leg(dst, 9, 28, 30)
		return dst
	if d >= 2:
		return fall_side(d)
	# de costas no chao: pernas em cima, cabeca embaixo (perto da camera)
	var s := 0 if d == 0 else -1
	leg(dst, 4, 9, 15); leg(dst, 9, 9, 15)
	for x in [4, 5, 6, 9, 10, 11]:
		L.put(dst, x, 9, "sk_dk")  # solas
	var sk2 := newp()
	sh(sk2, 3, 15, 10, 4, "g_hi", "g_md", "g_dk")
	for x in [3, 4, 6, 7, 8, 9, 11, 12]:
		L.put(sk2, x, 14, "g_md")
	L.put(sk2, 5, 17, "g_dk"); L.put(sk2, 10, 17, "g_dk")
	stamp(dst, sk2)
	var t2 := newp(); skin(t2, 4, 19, 8, 6)
	for q in [[5, 22], [6, 22], [9, 22], [10, 22]]:
		L.put(t2, q[0], q[1], "sk_dk")
	stamp(dst, t2)
	var ar2 := newp(); skin(ar2, 1, 19, 2, 7); stamp(dst, ar2)
	var al2 := newp(); skin(al2, 13, 18, 2, 5); stamp(dst, al2)
	# cabeca de frente, olhos fechados
	var h2 := newp()
	skin(h2, 3, 22, 10, 9)
	for q in [[3, 22], [12, 22], [3, 30], [12, 30]]:
		h2.set_pixel(q[0], q[1], Color(0, 0, 0, 0))
	for x in range(3, 13):
		for y in range(22, 25):
			L.put(h2, x, y, "h_hi" if (y == 22 or x == 3) else ("h_dk" if (y == 24 or x == 12) else "h_md"))
	h2.set_pixel(3, 22, Color(0, 0, 0, 0)); h2.set_pixel(12, 22, Color(0, 0, 0, 0))
	for x in [3, 4, 5, 8, 11, 12]:
		L.put(h2, x, 25, "h_dk")
	for x in [4, 5, 6, 9, 10, 11]:
		L.put(h2, x, 26, "sk_dk")
	L.put(h2, 5, 27, "K"); L.put(h2, 6, 27, "K"); L.put(h2, 9, 27, "K"); L.put(h2, 10, 27, "K")
	L.put(h2, 7, 28, "sk_dk"); L.put(h2, 8, 28, "sk_xx")
	L.put(h2, 7, 30, "sk_xx"); L.put(h2, 8, 30, "sk_xx")
	if d != 0:
		# rosto virado para o lado: olhos deslocados 1 px
		pass
	stamp(dst, h2)
	return dst

## Caido de lado (esquerda/direita): corpo de perfil, joelhos dobrados, rosto de perfil virado para o lado.
## Mesma ordem vertical do caido de costas (pernas em cima, cabeca perto da camera), mas estreito e de perfil.
func fall_side(d: int) -> Image:
	M = (d == 3)
	var dst: Image = L.img(FW, FH)
	var lf := newp(); skin(lf, 6, 7, 3, 8, true); stamp(dst, lf)
	dot(dst, 5, 14, "sk_dk")
	var ln := newp(); skin(ln, 3, 9, 3, 7); stamp(dst, ln)
	var sk := newp()
	sh(sk, 4, 15, 8, 4, "g_hi", "g_md", "g_dk")
	for x in [4, 5, 7, 8, 10, 11]:
		L.put(sk, fx(x, 1), 18, "g_md")
	stamp(dst, sk)
	var t := newp(); skin(t, 5, 18, 6, 5)
	dot(t, 5, 20, "sk_hi"); dot(t, 5, 21, "sk_dk")
	stamp(dst, t)
	head(dst, d, 19)
	var ar := newp(); skin(ar, 4, 19, 3, 6); dot(ar, 5, 24, "sk_md"); stamp(dst, ar, true)
	return dst
