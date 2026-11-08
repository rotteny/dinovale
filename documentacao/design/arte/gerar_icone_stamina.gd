## Gerador do icone de stamina (raio 12x12, ciano) para a barra de Stamina da HUD.
## Arte propria, CC BY 4.0, sem IA e sem recorte de terceiros. Da raiz do repositorio:
##   godot --headless --script documentacao/design/arte/gerar_icone_stamina.gd -- <pasta-de-saida>
## Tambem grava icon_stamina_8.png (8x8 nativo). Sem argumento, grava em game/assets/sprites/ui/icon_stamina.png.
## Contorno #141b1b, 3 tons (brilho cima/esquerda, base, sombra baixo/direita), alfa 0/1, so paleta do pacote.
extends SceneTree
const Lib = preload("arte_lib.gd")
var L = Lib.new()

const MAP := [
	"......KKKKK.",
	".....KhhvvK.",
	"....KhhvvdK.",
	"...KhhvvdK..",
	"..KhhvvvvdK.",
	".KhhvvvvvvK.",
	".KKKKKvvdK..",
	"....KvvdK...",
	"....KvdK....",
	"...KvdK.....",
	"...KdK......",
	"...KK.......",
]
# Variante nativa 8x8 (sem reducao fracionaria), mesmo desenho do icon_bolt do pacote proprio, em ciano.
const MAP8 := [
	"...KKKK.",
	"..KhvvK.",
	".KhvvK..",
	"KhvvvvvK",
	"KKKKvvK.",
	"...KvK..",
	"..KdK...",
	"..KK....",
]
const KEY := {"K": "K", "h": "v_hi", "v": "v_md", "d": "o_hi"}

func _init() -> void:
	var im: Image = L.img(12, 12)
	for y in 12:
		assert(MAP[y].length() == 12, "linha %d" % y)
		for x in 12:
			var ch: String = MAP[y][x]
			if ch != ".":
				L.put(im, x, y, KEY[ch])
	var im8: Image = L.img(8, 8)
	for y in 8:
		for x in 8:
			var c8: String = MAP8[y][x]
			if c8 != ".":
				L.put(im8, x, y, KEY[c8])
	var args := OS.get_cmdline_user_args()
	var path := "game/assets/sprites/ui/icon_stamina.png" if args.is_empty() else args[0].path_join("icon_stamina.png")
	L.save_png_checked(im, path)
	L.save_png_checked(im8, path.replace("icon_stamina.png", "icon_stamina_8.png"))
	quit()
