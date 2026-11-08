## Preview ampliado (nao e asset do jogo) das colunas novas de uma folha de dino. Da raiz do repositorio:
##   godot --headless --script documentacao/design/arte/montar_ameaca_preview.gd -- <folha.png> <quadro> <col_ini> <n_cols> <linha_ini> <n_linhas> <zoom> <saida.png>
## Cada celula e um quadro sobre fundo de grama (#a8a129), ampliado com vizinho mais proximo; grade de 1 px entre quadros.
extends SceneTree
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var sheet := Image.load_from_file(a[0])
	var q := int(a[1])
	var c0 := int(a[2]); var nc := int(a[3]); var r0 := int(a[4]); var nr := int(a[5]); var z := int(a[6])
	var cw := q * z + 2
	var out := Image.create(cw * nc, cw * nr, false, Image.FORMAT_RGBA8)
	out.fill(Color("141b1b"))
	for r in nr:
		for c in nc:
			var cell := Image.create(q, q, false, Image.FORMAT_RGBA8)
			cell.fill(Color("a8a129"))
			var fr := sheet.get_region(Rect2i((c0 + c) * q, (r0 + r) * q, q, q))
			cell.blend_rect(fr, Rect2i(0, 0, q, q), Vector2i(0, 0))
			cell.resize(q * z, q * z, Image.INTERPOLATE_NEAREST)
			out.blit_rect(cell, Rect2i(0, 0, q * z, q * z), Vector2i(c * cw + 1, r * cw + 1))
	out.save_png(a[7])
	quit()
