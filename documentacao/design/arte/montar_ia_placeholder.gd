## Monta as folhas do jogador e do Paquicefalo a partir de imagens PixelLab (placeholder de IA,
## ver game/assets/CREDITS.md). Movimento por deslocamento de pixels, sem novas geracoes.
## Uso, da raiz do repositorio (pasta com os PNG de 32x32 por direcao):
##   godot --headless --script documentacao/design/arte/montar_ia_placeholder.gd -- <pasta_jogador> <pasta_paqui>
## Saida: game/assets/sprites/jogador/jogador.png e .json (320x128), dinos/paquicefalo.png e .json (352x128).
## Quadro 32x32, base dos pes na linha y=30. Linhas: baixo, cima, esquerda, direita.
## As folhas anteriores (script) ficam em documentacao/design/arte/provisoria-script/.
extends SceneTree

const F := 32
const FEET_Y := 30


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("uso: -- <pasta_jogador> <pasta_paqui>")
		quit(1)
		return
	# jogador: etiquetas corretas
	var player := {0: "south", 1: "north", 2: "west", 3: "east"}
	_build(args[0], player, "res://assets/sprites/jogador/jogador.png", 10, false)
	# paquicefalo: etiquetas deslocadas 45 graus (frente = south-west, costas = north-east,
	# perfil direito = south-east; esquerda = west, que olha para a esquerda)
	var dino := {0: "south-west", 1: "north-east", 2: "west", 3: "south-east"}
	_build(args[1], dino, "res://assets/sprites/dinos/paquicefalo.png", 11, true)
	quit()


func _load(dir: String, name: String) -> Image:
	var im := Image.load_from_file(dir.path_join(name + ".png"))
	im.convert(Image.FORMAT_RGBA8)
	# alfa 0 ou 1
	for y in im.get_height():
		for x in im.get_width():
			var c := im.get_pixel(x, y)
			im.set_pixel(x, y, Color(c.r, c.g, c.b, 1.0) if c.a >= 0.5 else Color(0, 0, 0, 0))
	return _ground(im, 0, 0)


## Coloca o corpo com a base (ultima linha opaca) em FEET_Y. Mantem x.
func _ground(im: Image, shift_x: int, extra_y: int) -> Image:
	var r := im.get_used_rect()
	var out := Image.create(F, F, false, Image.FORMAT_RGBA8)
	var dy := FEET_Y - (r.end.y - 1) + extra_y
	out.blit_rect(im, Rect2i(0, 0, F, F), Vector2i(shift_x, dy))
	return out


## dx/dy: deslocamento; lean: desloca a metade de cima em x; seam>=0: estica 1 px acima da linha seam.
func _move(src: Image, dx: int, dy: int, lean: int = 0, seam: int = -1) -> Image:
	var r := src.get_used_rect()
	var mid := r.position.y + r.size.y / 2
	var out := Image.create(F, F, false, Image.FORMAT_RGBA8)
	for y in F:
		var sy := y - dy
		if seam >= 0:
			sy = (y + 1 if y <= seam - 1 else y) - dy
		if sy < 0 or sy >= F:
			continue
		var l := lean if sy < mid else 0
		for x in F:
			var sx := x - dx - l
			if sx < 0 or sx >= F:
				continue
			var c := src.get_pixel(sx, sy)
			if c.a > 0.0:
				out.set_pixel(x, y, c)
	return out


func _lie(src: Image, clockwise: bool, dark: float) -> Image:
	var im: Image = src.duplicate()
	im.rotate_90(CLOCKWISE if clockwise else COUNTERCLOCKWISE)
	# recentra na horizontal e apoia na linha dos pes
	var r := im.get_used_rect()
	var out := Image.create(F, F, false, Image.FORMAT_RGBA8)
	out.blit_rect(im, r, Vector2i((F - r.size.x) / 2, FEET_Y + 1 - r.size.y))
	if dark < 1.0:
		for y in F:
			for x in F:
				var c := out.get_pixel(x, y)
				if c.a > 0.0:
					out.set_pixel(x, y, Color(c.r * dark, c.g * dark, c.b * dark * 1.05, 1.0))
	return out


func _build(dir: String, names: Dictionary, path: String, cols: int, is_dino: bool) -> void:
	var sheet := Image.create(F * cols, F * 4, false, Image.FORMAT_RGBA8)
	var fwd := [Vector2i(0, 1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(1, 0)]
	for row in 4:
		var base := _load(dir, names[row])
		var r := base.get_used_rect()
		var seam := r.position.y + int(r.size.y * 0.55)
		var f: Vector2i = fwd[row]
		var frames: Array[Image] = []
		frames.append(base)                                   # 0 parado
		frames.append(_move(base, 0, 0, 0, seam))             # 1 respira (estica 1 px)
		frames.append(_move(base, 0, -1, 1))                  # 2 andar
		frames.append(_move(base, 0, 0, 0))                   # 3
		frames.append(_move(base, 0, -1, -1))                 # 4
		frames.append(_move(base, 0, 0, 0))                   # 5
		frames.append(_move(base, -f.x, -f.y, 0))             # 6 golpe: recua 1
		frames.append(_move(base, f.x * 2, f.y * 2, 0))       # 7 avanca 2
		frames.append(_move(base, f.x, f.y, 0))               # 8 volta
		var cw := row == 1 or row == 3
		if is_dino:
			frames.append(_lie(base, cw, 0.8))                # 9 dormindo
			frames.append(_lie(base, not cw, 0.62))           # 10 morto
		else:
			frames.append(_lie(base, cw, 1.0))                # 9 caido
		for c in frames.size():
			sheet.blit_rect(frames[c], Rect2i(0, 0, F, F), Vector2i(c * F, row * F))
	var abs_path := ProjectSettings.globalize_path(path)
	sheet.save_png(abs_path)
	print("ok ", abs_path, " ", sheet.get_size())
