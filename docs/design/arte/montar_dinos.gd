## Conferencia visual dos dinos (nao e asset do jogo). Da raiz do repositorio:
##   godot --headless --script docs/design/arte/montar_dinos.gd -- <arquivo.png de saida>
## Folha com humano 16x32 + os cinco dinos (parado, esquerda e frente), em 1x e 4x, sobre Campina e Pedreira.
extends SceneTree
const Lib = preload("arte_lib.gd")
var L = Lib.new()
const ARQ := ["dodo", "paquicefalo", "parassaurolofo", "utahraptor", "triceratops"]
const SZ := [16, 24, 32, 32, 48]
const CELL := 52

func _init() -> void:
	var out: String = OS.get_cmdline_user_args()[0]
	var ter := Image.load_from_file("game/assets/sprites/cenario/terreno.png")
	var items := {}
	for dr in [2, 0]:
		var row := []
		var pl := Image.load_from_file("game/assets/sprites/jogador/jogador.png")
		row.append(pl.get_region(Rect2i(0, dr * 32, 16, 32)))
		for i in 5:
			var im := Image.load_from_file("game/assets/sprites/dinos/%s.png" % ARQ[i])
			row.append(im.get_region(Rect2i(0, dr * SZ[i], SZ[i], SZ[i])))
		items[dr] = row
	var W := CELL * 6 * 4
	var H := 0
	var panels := []
	for terr_row in [3, 5]:
		var bg := Image.create(W, 20 + 70 + 2 * (48 * 4 + 16), false, Image.FORMAT_RGBA8)
		for y in range(0, bg.get_height(), 16):
			for x in range(0, bg.get_width(), 16):
				bg.blit_rect(ter, Rect2i((x / 16 * 5 + y / 16 * 3) % 8 * 16, terr_row * 16, 16, 16), Vector2i(x, y))
		# 1x
		for k in [2, 0]:
			var ox := 8 + (0 if k == 2 else 6 * CELL + 16)
			for i in 6:
				var it: Image = items[k][i]
				L.blit(bg, it, ox + i * CELL, 20 + 48 - it.get_height())
		# 4x
		var y4 := 90
		for k in [2, 0]:
			for i in 6:
				var it: Image = items[k][i].duplicate()
				it.resize(it.get_width() * 4, it.get_height() * 4, Image.INTERPOLATE_NEAREST)
				L.blit(bg, it, i * CELL * 4 + 8, y4 + 192 - it.get_height())
			y4 += 48 * 4 + 16
		panels.append(bg)
	var sheet := Image.create(W, panels[0].get_height() * 2, false, Image.FORMAT_RGBA8)
	sheet.blit_rect(panels[0], Rect2i(0, 0, W, panels[0].get_height()), Vector2i(0, 0))
	sheet.blit_rect(panels[1], Rect2i(0, 0, W, panels[1].get_height()), Vector2i(0, panels[0].get_height()))
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	sheet.save_png(out)
	quit()
