## Gerador do cursor do mouse: seta de 10x12 px, ponta no pixel (0, 0) (o hotspot do jogo).
## Arte propria, CC BY 4.0, sem IA e sem recorte de terceiros. Da raiz do repositorio:
##   godot --headless --script documentacao/design/arte/gerar_cursor.gd
## Saida: game/assets/sprites/ui/cursor.png (10x12, escala 1x do jogo de 320x180; o jogo amplia por inteiro
## na hora de aplicar, ver `PixelCursor`). Contorno #141b1b, miolo branco com sombra azulada, alfa 0/1.
extends SceneTree
const Lib = preload("arte_lib.gd")
var L = Lib.new()
const OUT := "game/assets/sprites/ui/cursor.png"

# '.' transparente; cada letra e uma cor de arte_lib.C
const MAP := [
	"K.........",
	"KK........",
	"KwK.......",
	"KwwK......",
	"KwwsK.....",
	"KwwwsK....",
	"KwwwwsK...",
	"KwwwwKKKK.",
	"KwKwsK....",
	"KK.KwsK...",
	"K..KwsK...",
	"....KKK...",
]
const KEY := {"K": "K", "w": "white", "s": "z_md"}

func _init() -> void:
	var im: Image = L.img(10, 12)
	for y in MAP.size():
		assert(MAP[y].length() == 10, "linha %d com %d colunas" % [y, MAP[y].length()])
		for x in 10:
			var ch: String = MAP[y][x]
			if ch != ".":
				L.put(im, x, y, KEY[ch])
	L.save_png_checked(im, OUT)
	quit()
