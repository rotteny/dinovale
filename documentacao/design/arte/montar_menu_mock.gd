## Monta o MOCKUP do menu (fundo + logo + botoes 9-slice + rotulos) em 320x180 e em 4x, e uma tira de estados dos botoes.
## So para o dono ver; os rotulos usam uma fonte 5x7 provisoria (no jogo e a ValeMini). Da raiz do repositorio:
##   godot --headless --script documentacao/design/arte/montar_menu_mock.gd -- <pasta com menu_fundo.png, menu_logo.png e botao_*.png>
## Saida na mesma pasta: menu_mockup.png (320x180), menu_mockup_4x.png (1280x720), botoes_estados_4x.png.
extends SceneTree
const Lib = preload("arte_lib.gd")
const Fonte = preload("menu_fonte.gd")
var L = Lib.new()
var F = Fonte.new()
var dir := ""

func nine(tex: Image, w: int, h: int) -> Image:
	var ml := 6
	var mr := 6
	var mt := 5
	var mb := 6
	var tw := tex.get_width()
	var th := tex.get_height()
	var out := L.img(w, h)
	var xs := [[0, ml, 0, ml], [ml, tw - mr, ml, w - mr], [tw - mr, tw, w - mr, w]]  # [src0, src1, dst0, dst1]
	var ys := [[0, mt, 0, mt], [mt, th - mb, mt, h - mb], [th - mb, th, h - mb, h]]
	for yy in ys:
		for xx in xs:
			var part := tex.get_region(Rect2i(xx[0], yy[0], xx[1] - xx[0], yy[1] - yy[0]))
			var dw: int = xx[3] - xx[2]
			var dh: int = yy[3] - yy[2]
			if part.get_width() != dw or part.get_height() != dh:
				part.resize(dw, dh, Image.INTERPOLATE_NEAREST)
			out.blend_rect(part, Rect2i(Vector2i.ZERO, part.get_size()), Vector2i(xx[2], yy[2]))
	return out

func label(dst: Image, text: String, cx: int, y: int, col: String, sh: String) -> void:
	var m: Image = F.mask(text, 1, 1)
	var x0 := cx - m.get_width() / 2
	for pass_i in 2:
		for yy in m.get_height():
			for xx in m.get_width():
				if m.get_pixel(xx, yy).a > 0.5:
					if pass_i == 0:
						L.put(dst, x0 + xx, y + yy + 1, sh)
					else:
						L.put(dst, x0 + xx, y + yy, col)

const COL := {
	"normal": ["cut", "w_dk"], "hover": ["white", "w_dk"], "pressed": ["cut", "s_xx"], "disabled": ["s_xx", "s_hi"],
}

func button(state: String, text: String, w: int) -> Image:
	var tex := Image.load_from_file(dir.path_join("botao_%s.png" % state))
	var b := nine(tex, w, 20)
	var ty := 5 + (2 if state == "pressed" else 0)
	label(b, text, w / 2, ty, COL[state][0], COL[state][1])
	return b

func _init() -> void:
	dir = OS.get_cmdline_user_args()[0]
	var bg := Image.load_from_file(dir.path_join("menu_fundo.png"))
	bg.convert(Image.FORMAT_RGBA8)
	var logo := Image.load_from_file(dir.path_join("menu_logo.png"))
	bg.blend_rect(logo, Rect2i(Vector2i.ZERO, logo.get_size()), Vector2i((320 - logo.get_width()) / 2, 12))
	var items := [["hover", "JOGAR"], ["disabled", "CONTINUAR"], ["normal", "OPCOES"], ["normal", "SAIR"]]
	for k in items.size():
		var b := button(items[k][0], items[k][1], 96)
		bg.blend_rect(b, Rect2i(Vector2i.ZERO, b.get_size()), Vector2i(112, 72 + k * 24))
	bg.save_png(dir.path_join("menu_mockup.png"))
	bg.resize(1280, 720, Image.INTERPOLATE_NEAREST)
	bg.save_png(dir.path_join("menu_mockup_4x.png"))
	# tira de estados (fundo liso da cor do campo) em 4x
	var strip := L.img(4 * 100 + 8, 28)
	strip.fill(Color("#74a334"))
	var names := ["normal", "hover", "pressed", "disabled"]
	for k in 4:
		var b := button(names[k], "JOGAR", 96)
		strip.blend_rect(b, Rect2i(Vector2i.ZERO, b.get_size()), Vector2i(4 + k * 100, 4))
	strip.resize(strip.get_width() * 4, strip.get_height() * 4, Image.INTERPOLATE_NEAREST)
	strip.save_png(dir.path_join("botoes_estados_4x.png"))
	quit()
