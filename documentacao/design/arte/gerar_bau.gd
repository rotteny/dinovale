## Gerador do sprite placeholder do Bau (E8b), 16x16. Arte propria, CC BY 4.0, sem IA e sem recorte de terceiros.
## Regenere da raiz do repositorio:
##   godot --headless --script documentacao/design/arte/gerar_bau.gd
## Saida: game/assets/sprites/pecas/chest.png (alfa so 0 ou 1). Cores da paleta do pacote Ninja Adventure (as mesmas da
## Bancada e das pecas de construcao). Ancora: o centro da celula; o Bau nao gira (rotacao ignorada).
extends SceneTree

const OUT := "game/assets/sprites/pecas/"
const K := Color("#141b1b")
const TOP_HI := Color("#c8966b")
const TOP := Color("#a3754e")
const LEG := Color("#965340")
const CUT := Color("#fce2ca")


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_chest().save_png(OUT + "chest.png")
	quit()


## Caixa de tabuas com tampa arqueada, cinta e fecho claro.
func _chest() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	_rect(img, 1, 3, 14, 11, K)  # contorno
	_rect(img, 2, 4, 12, 4, TOP_HI)  # tampa
	_rect(img, 2, 5, 12, 3, TOP)
	_rect(img, 2, 9, 12, 4, TOP)  # corpo
	_rect(img, 2, 11, 12, 2, LEG)
	_rect(img, 1, 8, 14, 1, K)  # fresta da tampa
	_rect(img, 4, 4, 1, 9, K)  # cintas
	_rect(img, 11, 4, 1, 9, K)
	_rect(img, 7, 7, 2, 3, K)  # fecho
	_rect(img, 7, 8, 2, 1, CUT)
	return img


func _rect(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	for ix in w:
		for iy in h:
			img.set_pixel(x + ix, y + iy, color)
