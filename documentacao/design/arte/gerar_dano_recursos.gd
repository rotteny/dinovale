## Gerador das sobreposicoes de dano dos nos de recurso (arvore, rocha, minerio): marcas de corte no tronco e
## rachaduras, 2 estagios cada. Arte propria, CC BY 4.0, sem IA e sem recorte de terceiros. Da raiz do repositorio:
##   godot --headless --script documentacao/design/arte/gerar_dano_recursos.gd
## Saida: game/assets/sprites/recursos/  tree_damage_1.png, tree_damage_2.png (48x80),
##                                        rock_damage_1.png, rock_damage_2.png, ore_damage_1.png, ore_damage_2.png (32x32)
## Mesmo tamanho e ancora do sprite do no; as rachaduras so caem sobre pixels solidos do sprite base.
## Contorno #141b1b e claro de corte da paleta do pacote (conferido ao gravar); alfa so 0 ou 1.
extends SceneTree
const Lib = preload("arte_lib.gd")
var L = Lib.new()
const OREC := "game/assets/sprites/recursos/"

func _init() -> void:
	L.save_png_checked(tree_damage(1), OREC + "tree_damage_1.png")
	L.save_png_checked(tree_damage(2), OREC + "tree_damage_2.png")
	var rock_cracks := {
		1: [[[15, 10], [17, 14], [15, 18], [16, 22]]],
		2: [[[15, 10], [17, 14], [15, 18], [16, 22]], [[17, 14], [21, 16], [23, 20]],
			[[15, 18], [11, 20], [9, 24]], [[15, 10], [12, 7]]]}
	var ore_cracks := {
		1: [[[16, 8], [14, 13], [17, 18], [15, 23]]],
		2: [[[16, 8], [14, 13], [17, 18], [15, 23]], [[14, 13], [10, 15], [8, 19]],
			[[17, 18], [21, 20], [23, 25]], [[16, 8], [19, 5]]]}
	for stage in [1, 2]:
		L.save_png_checked(cracks("rock_stone_32.png", rock_cracks[stage]), OREC + "rock_damage_%d.png" % stage)
		L.save_png_checked(cracks("rock_ore_32.png", ore_cracks[stage]), OREC + "ore_damage_%d.png" % stage)
	quit()

## Entalhes de machado no tronco (x 20..27, y 62..78): um no estagio 1, tres no 2 (alternando os lados).
func tree_damage(stage: int) -> Image:
	var i: Image = L.img(48, 80)
	notch(i, 20, 66, 1)
	if stage >= 2:
		notch(i, 27, 71, -1)
		notch(i, 19, 75, 1)
	return i

## Cunha de 3 linhas que entra do lado `x_edge` para dentro (dir 1 = para a direita): fundo escuro e fio claro.
func notch(i: Image, x_edge: int, y: int, dir: int) -> void:
	var widths := [2, 4, 2]
	for row in 3:
		for k in widths[row]:
			L.put(i, x_edge + dir * k, y + row, "K")
	L.put(i, x_edge + dir * 1, y + 1, "cut")
	L.put(i, x_edge + dir * 2, y + 1, "cut")

## Rachaduras: polilinhas de contorno sobre o sprite base, so onde ele e solido.
func cracks(base_file: String, lines: Array) -> Image:
	var base := Image.load_from_file(OREC + base_file)
	assert(base != null, "sprite base nao encontrado: " + base_file)
	var i: Image = L.img(base.get_width(), base.get_height())
	for line in lines:
		for s in range(line.size() - 1):
			segment(i, base, line[s][0], line[s][1], line[s + 1][0], line[s + 1][1])
	return i

func segment(i: Image, base: Image, x0: int, y0: int, x1: int, y1: int) -> void:
	var steps := maxi(absi(x1 - x0), absi(y1 - y0))
	for n in steps + 1:
		var t := float(n) / float(maxi(steps, 1))
		var x := roundi(lerpf(x0, x1, t))
		var y := roundi(lerpf(y0, y1, t))
		if x >= 0 and y >= 0 and x < base.get_width() and y < base.get_height() and base.get_pixel(x, y).a > 0.5:
			L.put(i, x, y, "K")
