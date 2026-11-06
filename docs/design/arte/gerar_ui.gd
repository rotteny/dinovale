## Gerador dos icones 8x8 da interface: pena (branca), escudo (verde), raio (vermelho), alvo e peso.
## Arte propria, CC BY 4.0, sem IA e sem recorte de terceiros. Da raiz do repositorio:
##   godot --headless --script docs/design/arte/gerar_ui.gd
## Saida: game/assets/sprites/ui/icon_feather.png, icon_shield.png, icon_bolt.png, icon_target.png, icon_weight.png (8x8)
## Formas distintas alem da cor: pena = faixa diagonal; escudo = brasao com ponta embaixo; raio = zigue-zague;
## alvo = circulo com aneis; peso = massa com alca vazada. Contorno #141b1b, alfa 0/1, so paleta do pacote.
extends SceneTree
const Lib = preload("arte_lib.gd")
var L = Lib.new()
const OUT := "game/assets/sprites/ui/"

# '.' transparente; cada letra e uma cor de arte_lib.C
const ICONS := {
	"icon_feather": {
		"map": [
			"....KKK.",
			"...KwwzK",
			"..KwwwzK",
			".KwwwzK.",
			"KwwwzK..",
			"KwwzKK..",
			"KqKK....",
			"KK......",
		],
		"key": {"K": "K", "w": "white", "z": "z_md", "q": "ring2"},
	},
	"icon_shield": {
		"map": [
			".KKKKKK.",
			"KhhgggdK",
			"KhglldgK",
			"KhglldgK",
			"KgglldgK",
			".KggggK.",
			"..KgdK..",
			"...KK...",
		],
		"key": {"K": "K", "h": "g_hi", "g": "g_md", "d": "g_dk", "l": "g_lt"},
	},
	"icon_bolt": {
		"map": [
			"...KKKK.",
			"..KhrrK.",
			".KhrrK..",
			"KhrrrrrK",
			"KKKKrrK.",
			"...KrK..",
			"..KrK...",
			"..KK....",
		],
		"key": {"K": "K", "h": "orange", "r": "f_red"},
	},
	"icon_target": {
		"map": [
			"..KKKK..",
			".KwwwwK.",
			"KwrrrrwK",
			"KwrwwrwK",
			"KwrwwrwK",
			"KwrrrrwK",
			".KwwwwK.",
			"..KKKK..",
		],
		"key": {"K": "K", "w": "white", "r": "f_red"},
	},
	"icon_weight": {
		"map": [
			"..KKKK..",
			".KhssdK.",
			".Ks..dK.",
			"KKs..dKK",
			"KhssssdK",
			"KsssssdK",
			".KsssdK.",
			"..KKKK..",
		],
		"key": {"K": "K", "h": "s_hi", "s": "s_md", "d": "s_dk"},
	},
}

func _init() -> void:
	for n in ICONS:
		var ic: Dictionary = ICONS[n]
		var im: Image = L.img(8, 8)
		var rows: Array = ic["map"]
		for y in 8:
			assert(rows[y].length() == 8, "%s linha %d com %d colunas" % [n, y, rows[y].length()])
			for x in 8:
				var ch: String = rows[y][x]
				if ch != ".":
					L.put(im, x, y, ic["key"][ch])
		L.save_png_checked(im, OUT + n + ".png")
	quit()
