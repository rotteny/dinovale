## Gerador do sprite placeholder da Bancada (E7a): 16x16, mesa de tabuas com pernas e um entalhe.
## Arte propria, CC BY 4.0, sem IA e sem recorte de terceiros. Regenere da raiz do repositorio:
##   godot --headless --script documentacao/design/arte/gerar_bancada.gd
## Saida: game/assets/sprites/pecas/workbench.png (alfa so 0 ou 1). Cores da paleta do pacote Ninja Adventure.
## Ancora: o centro do tile (o no `Workbench` fica no centro do tile; o desenho cabe nos 16x16).
extends SceneTree

const OUT := "game/assets/sprites/pecas/"
const K := Color("#141b1b")
const TOP_HI := Color("#c8966b")
const TOP := Color("#a3754e")
const LEG := Color("#965340")
const CUT := Color("#fce2ca")


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_rect(img, 1, 3, 14, 7, K)  # contorno do tampo
	_rect(img, 2, 4, 12, 5, TOP)
	_rect(img, 2, 4, 12, 1, TOP_HI)  # luz de cima
	_rect(img, 3, 10, 2, 4, K)  # pernas
	_rect(img, 11, 10, 2, 4, K)
	_rect(img, 3, 10, 1, 3, LEG)
	_rect(img, 11, 10, 1, 3, LEG)
	_rect(img, 5, 6, 2, 1, CUT)  # entalhe na madeira
	_rect(img, 9, 7, 3, 1, K)
	img.save_png(OUT + "workbench.png")
	quit()


func _rect(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	for ix in w:
		for iy in h:
			img.set_pixel(x + ix, y + iy, color)
