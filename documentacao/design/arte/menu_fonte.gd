## Fonte 5x7 minima (so as letras usadas no titulo e nos rotulos de exemplo do menu). Arte propria, CC BY 4.0.
## Usada so pelos geradores do menu (logo e mockup). No jogo o texto dos botoes e a fonte ValeMini, nao esta.
extends RefCounted

const G := {
	"A": ["01110", "10001", "10001", "11111", "10001", "10001", "10001"],
	"C": ["01110", "10001", "10000", "10000", "10000", "10001", "01110"],
	"D": ["11110", "10001", "10001", "10001", "10001", "10001", "11110"],
	"E": ["11111", "10000", "10000", "11110", "10000", "10000", "11111"],
	"G": ["01110", "10001", "10000", "10111", "10001", "10001", "01111"],
	"I": ["11111", "00100", "00100", "00100", "00100", "00100", "11111"],
	"J": ["00111", "00010", "00010", "00010", "00010", "10010", "01100"],
	"L": ["10000", "10000", "10000", "10000", "10000", "10000", "11111"],
	"N": ["10001", "11001", "10101", "10101", "10011", "10001", "10001"],
	"O": ["01110", "10001", "10001", "10001", "10001", "10001", "01110"],
	"P": ["11110", "10001", "10001", "11110", "10000", "10000", "10000"],
	"R": ["11110", "10001", "10001", "11110", "10100", "10010", "10001"],
	"S": ["01111", "10000", "10000", "01110", "00001", "00001", "11110"],
	"T": ["11111", "00100", "00100", "00100", "00100", "00100", "00100"],
	"U": ["10001", "10001", "10001", "10001", "10001", "10001", "01110"],
	"V": ["10001", "10001", "10001", "10001", "10001", "01010", "00100"],
}

## Mascara (Image alfa 0/1, cor branca) do texto em escala inteira `sc`, espaco entre letras `gap` (em px finais).
func mask(text: String, sc: int, gap: int) -> Image:
	var w := 0
	for ch in text:
		w += (5 * sc + gap) if ch != " " else (3 * sc + gap)
	w -= gap
	var m := Image.create(w, 7 * sc, false, Image.FORMAT_RGBA8)
	m.fill(Color(0, 0, 0, 0))
	var x := 0
	for ch in text:
		if ch == " ":
			x += 3 * sc + gap
			continue
		var g: Array = G[ch]
		for r in 7:
			for c in 5:
				if (g[r] as String)[c] == "1":
					for dy in sc:
						for dx in sc:
							m.set_pixel(x + c * sc + dx, r * sc + dy, Color.WHITE)
		x += 5 * sc + gap
	return m
