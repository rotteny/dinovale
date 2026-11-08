## Ferramenta de conferencia: amplia (vizinho mais proximo) uma ou mais folhas, empilhadas, sobre fundo de grama.
## godot --headless --script docs/design/arte/ampliar_folha.gd -- <saida.png> <escala> <colunas ou "all"> <folha1.png:largura_quadro:altura_quadro> [folha2...]
## colunas: lista separada por virgula (ex.: 0,2,3,4,7,9). So para olhar; nao e asset.
extends SceneTree
func _init() -> void:
	var a := OS.get_cmdline_user_args()
	var scale := int(a[1])
	var imgs := []
	var tw := 0
	var th := 0
	for i in range(3, a.size()):
		var sp: PackedStringArray = a[i].split(":")
		var im := Image.load_from_file(sp[0])
		var fw := int(sp[1])
		var fh := int(sp[2])
		var cols: Array = []
		if a[2] == "all":
			for c in im.get_width() / fw: cols.append(c)
		else:
			for c in a[2].split(","): cols.append(int(c))
		imgs.append([im, fw, fh, cols])
		tw = maxi(tw, cols.size() * fw)
		th += im.get_height() + 2
	var out := Image.create(tw, th, false, Image.FORMAT_RGBA8)
	out.fill(Color("#56864c"))
	var y := 0
	for it in imgs:
		var im: Image = it[0]
		for r in im.get_height() / it[2]:
			for ci in it[3].size():
				var src := im.get_region(Rect2i(it[3][ci] * it[1], r * it[2], it[1], it[2]))
				var dstx: int = ci * it[1]
				out.blend_rect(src, Rect2i(0, 0, it[1], it[2]), Vector2i(dstx, y + r * it[2]))
		y += im.get_height() + 2
	out.resize(tw * scale, th * scale, Image.INTERPOLATE_NEAREST)
	out.save_png(a[0])
	quit()
