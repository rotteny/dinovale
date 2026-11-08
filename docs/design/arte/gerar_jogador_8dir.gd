## PROTOTIPO do jogador em 8 direcoes, por script (partes 3D, `render3d.gd`). Arte propria, CC BY 4.0, sem IA.
## Mesmo tamanho (quadro 32x32) e mesmas animacoes do sprite atual: colunas 0-1 idle, 2-5 walk, 6-8 hit, 9 fall.
## Da raiz do repositorio:
##   godot --headless --script docs/design/arte/gerar_jogador_8dir.gd -- <pasta de saida>
## Saida: jogador8.png (320x256: 10 colunas x 8 linhas) e jogador8.json. NAO grava em game/assets.
## Linhas: down, up, left, right (iguais ao layout antigo) + down_left, down_right, up_left, up_right.
## Homem das cavernas sem camisa, tanga de folhas, cabelo castanho, descalco, sem acessorios (como o atual).
extends SceneTree
const R3 = preload("render3d.gd")
var R = R3.new()

const SKIN := ["sk_xx", "sk_dk", "sk_md", "sk_hi"]
const HAIR := ["h_xx", "h_dk", "h_md", "h_hi"]
const LEAF := ["g_dk", "g_md", "g_hi", "g_lt"]
const FOOT := ["sk_xx", "sk_xx", "sk_dk", "sk_md"]

## pose: dz (respiracao/bob), la/lb (perna x+ / x-: [y, lift]), aa/ab (braco x+ / x-: [y, z]), lean, twist
func build(p: Dictionary) -> void:
	R.clear()
	var dz: float = p.get("dz", 0.0)
	var la: Array = p.get("la", [0.0, 0.0])
	var lb: Array = p.get("lb", [0.0, 0.0])
	var aa: Array = p.get("aa", [0.0, 0.0])
	var ab: Array = p.get("ab", [0.0, 0.0])
	var lean: float = p.get("lean", 0.0)
	# pernas (atras do resto) e pes
	for s in [[1.0, la], [-1.0, lb]]:
		var x: float = 2.0 * s[0]
		var l: Array = s[1]
		R.chain([[x, 0.0, 10.4 + dz * 0.5, 2.3], [x, l[0] * 0.5, 6.2 + l[1] * 0.6, 2.0], [x, l[0], 2.4 + l[1], 1.7]], SKIN)
		R.ell(Vector3(x, l[0] + 0.9, 0.9 + l[1]), Vector3(1.8, 2.7, 1.2), FOOT)
	# tanga de folhas: saia + folhas na barra
	R.ell(Vector3(0, lean * 0.3, 11.2 + dz), Vector3(4.4, 3.5, 2.9), LEAF, {"edge": false})
	for i in 8:
		var a := TAU * i / 8.0
		R.ell(Vector3(cos(a) * 4.0, sin(a) * 3.1 + lean * 0.3, 9.0 + dz + (0.5 if i % 2 == 0 else 0.0)), Vector3(1.7, 1.5, 1.7), LEAF, {"shift": -1 if i % 2 else 0})
	# bracos: ombro, cotovelo, mao
	for s in [[1.0, aa], [-1.0, ab]]:
		var x: float = 5.0 * s[0]
		var a: Array = s[1]
		var hand_y: float = a[0] + lean
		R.chain([[x, lean * 0.6, 18.6 + dz, 1.7], [x + s[0] * 0.3, a[0] * 0.5 + lean * 0.8, 15.8 + dz + a[1] * 0.5, 1.5],
			[x + s[0] * 0.1, hand_y, 13.0 + dz + a[1], 1.4]], SKIN)
	# tronco, cabeca, cabelo
	R.ell(Vector3(0, lean * 0.6, 15.8 + dz), Vector3(3.9, 2.8, 4.1), SKIN)
	R.ell(Vector3(0, 0.3 + lean, 23.4 + dz), Vector3(4.7, 4.2, 4.6), SKIN)
	R.ell(Vector3(0, 0.5 + lean, 25.4 + dz), Vector3(4.9, 4.3, 3.7), HAIR)
	R.ell(Vector3(0, -1.8 + lean, 22.8 + dz), Vector3(4.2, 2.9, 4.0), HAIR)
	# olhos
	for sx in [-1.9, 1.9]:
		R.decal(Vector3(sx, 4.2 + lean, 22.9 + dz), "K")
		R.decal(Vector3(sx, 4.2 + lean, 21.9 + dz), "K")

func pose(col: int) -> Dictionary:
	match col:
		0: return {}
		1: return {"dz": -1.0}
		2: return {"la": [3.2, 0.0], "lb": [-3.2, 0.0], "aa": [-2.6, 0.0], "ab": [2.6, 0.0]}
		3: return {"la": [0.0, 0.0], "lb": [0.0, 1.8], "aa": [0.0, 0.0], "ab": [0.0, 0.0], "dz": -1.0}
		4: return {"la": [-3.2, 0.0], "lb": [3.2, 0.0], "aa": [2.6, 0.0], "ab": [-2.6, 0.0]}
		5: return {"la": [0.0, 1.8], "lb": [0.0, 0.0], "aa": [0.0, 0.0], "ab": [0.0, 0.0], "dz": -1.0}
		6: return {"aa": [-3.0, 3.0], "ab": [1.0, 0.0], "lean": -0.8, "dz": 0.0}
		7: return {"aa": [6.0, 5.5], "ab": [-1.5, 0.0], "lean": 1.6, "la": [1.0, 0.0], "lb": [-2.0, 0.0], "dz": -1.0}
		8: return {"aa": [2.5, 2.5], "ab": [0.0, 0.0], "lean": 0.6}
	return {}

func make_sheet() -> Image:
	var sheet: Image = R.L.img(32 * 10, 32 * 8)
	for row in 8:
		for col in 10:
			var im: Image
			if col == 9:
				build({})
				im = R.render(R.DIR_YAW[row], 90.0, 3.2, 14.0)
			else:
				build(pose(col))
				im = R.render(R.DIR_YAW[row])
			R.L.blit(sheet, im, col * 32, row * 32)
	return sheet

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	assert(args.size() >= 1, "uso: -- <pasta de saida>")
	var dir: String = args[0]
	R.L.save_png_checked(make_sheet(), dir.path_join("jogador8.png"))
	var meta := {
		"ancora": "base do quadro (pes em y=30, folha 32x32); prototipo por script, partes 3D",
		"animacoes": {
			"fall": {"colunas": [9], "fps": 1, "loop": false},
			"hit": {"colunas": [6, 7, 8], "fps": 10, "loop": false},
			"idle": {"colunas": [0, 1], "fps": 2, "loop": true},
			"walk": {"colunas": [2, 3, 4, 5], "fps": 8, "loop": true},
		},
		"arquivo": "jogador8.png",
		"colisao_pes": [12, 8],
		"colunas": 10,
		"linhas": 8,
		"linhas_direcao": R.DIR_NAMES,
		"quadro": [32, 32],
		"direita": "desenhada por script (nao e espelho)",
		"caido": "deitado de costas, cabeca no sentido oposto ao que olhava; uma pose por direcao",
	}
	var f := FileAccess.open(dir.path_join("jogador8.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(meta, "\t", true))
	f.close()
	quit()
