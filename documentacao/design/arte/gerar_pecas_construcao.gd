## Gerador dos sprites placeholder das pecas de construcao (E8a): fundacao, parede, porta fechada e porta aberta, 16x16.
## Arte propria, CC BY 4.0, sem IA e sem recorte de terceiros. Regenere da raiz do repositorio:
##   godot --headless --script documentacao/design/arte/gerar_pecas_construcao.gd
## Saida: game/assets/sprites/pecas/{foundation,wall,door_closed,door_open}.png (alfa so 0 ou 1). Cores da paleta do pacote
## Ninja Adventure (as mesmas da Bancada). Ancora: o centro da celula; a vista gira o sprite pela rotacao da peca
## (parede e porta desenhadas na horizontal: a rotacao 0 corre leste-oeste).
extends SceneTree

const OUT := "game/assets/sprites/pecas/"
const K := Color("#141b1b")
const TOP_HI := Color("#c8966b")
const TOP := Color("#a3754e")
const LEG := Color("#965340")
const CUT := Color("#fce2ca")


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	_foundation().save_png(OUT + "foundation.png")
	_wall().save_png(OUT + "wall.png")
	_door(false).save_png(OUT + "door_closed.png")
	_door(true).save_png(OUT + "door_open.png")
	quit()


func _blank() -> Image:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	return img


## Piso de tabuas: quatro fileiras com juntas escuras e um prego por tabua.
func _foundation() -> Image:
	var img := _blank()
	_rect(img, 0, 0, 16, 16, K)
	for row in 4:
		_rect(img, 1, row * 4 + 1, 14, 3, TOP if row % 2 == 0 else LEG)
		_rect(img, 1, row * 4 + 1, 14, 1, TOP_HI)
		_rect(img, 3 + row * 3 % 8, row * 4 + 2, 1, 1, K)  # prego
	return img


## Parede de tabuas em pe, corrida de ponta a ponta (a celula inteira, para fechar o vao).
func _wall() -> Image:
	var img := _blank()
	_rect(img, 0, 2, 16, 12, K)
	_rect(img, 0, 3, 16, 10, TOP)
	_rect(img, 0, 3, 16, 1, TOP_HI)
	for x in [4, 8, 12]:
		_rect(img, x, 3, 1, 10, K)  # juntas entre as tabuas
	_rect(img, 2, 6, 1, 2, CUT)  # veio claro
	_rect(img, 10, 8, 1, 2, CUT)
	_rect(img, 0, 12, 16, 1, LEG)
	return img


## Porta: fechada ocupa o vao (batente e folha, macaneta); aberta mostra so o batente e a folha de lado.
func _door(open: bool) -> Image:
	var img := _blank()
	_rect(img, 0, 2, 2, 12, K)  # batente esquerdo
	_rect(img, 14, 2, 2, 12, K)
	_rect(img, 0, 2, 16, 1, K)
	if open:
		_rect(img, 2, 3, 2, 10, K)  # folha aberta, de lado
		_rect(img, 2, 4, 1, 8, TOP)
		_rect(img, 3, 4, 1, 8, LEG)
		return img
	_rect(img, 2, 3, 12, 10, K)
	_rect(img, 3, 4, 10, 8, TOP)
	_rect(img, 3, 4, 10, 1, TOP_HI)
	_rect(img, 8, 4, 1, 8, K)  # fresta entre as duas folhas
	_rect(img, 10, 8, 1, 1, CUT)  # macaneta
	_rect(img, 6, 8, 1, 1, CUT)
	return img


func _rect(img: Image, x: int, y: int, w: int, h: int, color: Color) -> void:
	for ix in w:
		for iy in h:
			img.set_pixel(x + ix, y + iy, color)
