## Gerador das 2 faixas de musica de fundo (dia e noite) por SINTESE em codigo. Original, CC BY 4.0, sem amostras
## nem trechos de terceiros, sem IA. Da raiz do repositorio:
##   godot --headless --script documentacao/design/audio/gerar_musica.gd -- <pasta de saida>
## Saida: musica_dia.wav, musica_noite.wav (mono, 16 bits, 22050 Hz). NAO grava em game/assets.
##
## LOOP PERFEITO: cada faixa tem um numero inteiro de compassos e todo som (notas que ainda soam, eco, pad)
## e escrito com indice circular (modulo N): o final da cauda cai no comeco. O filtro final e passado duas voltas
## para o estado inicial bater com o final. Importe no Godot com loop = Forward (loop_begin 0, loop_end = fim).
##
## Dia:   100 BPM, Do maior, 16 compassos de 8 colcheias (marimba na melodia, violao-pluck em arpejo, baixo, bumbo e
##        chocalho leves, pad suave). Progressao simples em I-V-vi-IV; melodia pentatonica escrita a mao.
## Noite: 60 BPM, La menor, 8 compassos: pad longo, sino de caixinha de musica esparso, baixo continuo, eco e grilos.
## Ruido (chocalho, grilos) usa semente fixa: a saida e identica a cada execucao.
extends SceneTree

const RATE := 22050
const TAU_F := TAU

var rng := RandomNumberGenerator.new()

# ---------------------------------------------------------------- notas
func midi(n: String) -> int:
	var base := {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}[n[0]] as int
	var i := 1
	if n[i] == "#":
		base += 1
		i += 1
	elif n[i] == "b":
		base -= 1
		i += 1
	return base + 12 * (int(n.substr(i)) + 1)

func hz(m: float) -> float:
	return 440.0 * pow(2.0, (m - 69.0) / 12.0)

## "E5 - G5 - . ..." -> [[slot, midi, duracao_em_slots]]
func parse(bars: Array) -> Array:
	var out := []
	for b in bars.size():
		var toks: PackedStringArray = (bars[b] as String).split(" ", false)
		var i := 0
		while i < toks.size():
			var t := toks[i]
			if t == "-" or t == "_":
				i += 1
				continue
			var d := 1
			while i + d < toks.size() and toks[i + d] == "-":
				d += 1
			out.append([b * 8 + i, midi(t), d])
			i += 1
	return out

# ---------------------------------------------------------------- instrumentos (somam em buf, com indice circular)
func put(buf: PackedFloat32Array, start: int, length: int, fn: Callable) -> void:
	var n := buf.size()
	for i in length:
		buf[(start + i) % n] += fn.call(float(i) / RATE)

func marimba(buf: PackedFloat32Array, start: int, m: float, amp: float) -> void:
	var f := hz(m)
	put(buf, start, int(RATE * 0.9), func(t: float) -> float:
		var a := minf(t / 0.003, 1.0)
		return amp * a * (sin(TAU_F * f * t) * exp(-t * 6.0) + 0.28 * sin(TAU_F * f * 4.0 * t) * exp(-t * 22.0)))

func pluck(buf: PackedFloat32Array, start: int, m: float, amp: float) -> void:
	var f := hz(m)
	put(buf, start, int(RATE * 0.7), func(t: float) -> float:
		var a := minf(t / 0.002, 1.0)
		return amp * a * exp(-t * 6.5) * (sin(TAU_F * f * t) + 0.5 * sin(TAU_F * f * 2.0 * t) * exp(-t * 6.0) + 0.22 * sin(TAU_F * f * 3.0 * t) * exp(-t * 10.0)))

func bass(buf: PackedFloat32Array, start: int, length: float, m: float, amp: float) -> void:
	var f := hz(m)
	put(buf, start, int(RATE * (length + 0.25)), func(t: float) -> float:
		var a := minf(t / 0.01, 1.0)
		var rel := clampf((length + 0.25 - t) / 0.25, 0.0, 1.0)
		return amp * a * rel * exp(-t * 1.1) * (sin(TAU_F * f * t) + 0.35 * sin(TAU_F * f * 2.0 * t)))

func drone(buf: PackedFloat32Array, start: int, length: float, m: float, amp: float) -> void:
	var f := hz(m)
	put(buf, start, int(RATE * (length + 1.5)), func(t: float) -> float:
		var a := clampf(t / 1.2, 0.0, 1.0)
		var rel := clampf((length + 1.5 - t) / 1.5, 0.0, 1.0)
		return amp * a * rel * (sin(TAU_F * f * t) + 0.2 * sin(TAU_F * f * 2.0 * t)))

func pad(buf: PackedFloat32Array, start: int, length: float, m: float, amp: float, atk: float, rel_s: float) -> void:
	var f := hz(m)
	var total := length + rel_s
	put(buf, start, int(RATE * total), func(t: float) -> float:
		var a := clampf(t / atk, 0.0, 1.0)
		var rel := clampf((total - t) / rel_s, 0.0, 1.0)
		var v := sin(TAU_F * f * 0.997 * t) + sin(TAU_F * f * t) + sin(TAU_F * f * 1.003 * t) + 0.3 * sin(TAU_F * f * 2.0 * t)
		return amp * a * rel * v / 3.0)

func bell(buf: PackedFloat32Array, start: int, m: float, amp: float) -> void:
	var f := hz(m)
	put(buf, start, int(RATE * 3.6), func(t: float) -> float:
		var a := minf(t / 0.002, 1.0)
		return amp * a * (sin(TAU_F * f * t) * exp(-t * 1.9) + 0.35 * sin(TAU_F * f * 2.76 * t) * exp(-t * 4.5) + 0.15 * sin(TAU_F * f * 5.4 * t) * exp(-t * 9.0)))

func kick(buf: PackedFloat32Array, start: int, amp: float) -> void:
	put(buf, start, int(RATE * 0.22), func(t: float) -> float:
		var ph := TAU_F * (45.0 * t + 65.0 * (1.0 - exp(-t * 28.0)) / 28.0)
		return amp * sin(ph) * exp(-t * 16.0))

func shaker(buf: PackedFloat32Array, start: int, amp: float) -> void:
	var prev := 0.0
	var n := buf.size()
	for i in int(RATE * 0.07):
		var t := float(i) / RATE
		var x := rng.randf_range(-1.0, 1.0)
		buf[(start + i) % n] += amp * (x - prev) * 0.5 * exp(-t * 55.0) * minf(t / 0.002, 1.0)
		prev = x

func cricket(buf: PackedFloat32Array, start: int, amp: float) -> void:
	for k in 3:
		put(buf, start + int(k * 0.085 * RATE), int(RATE * 0.05), func(t: float) -> float:
			return amp * sin(TAU_F * 4300.0 * t) * (0.55 + 0.45 * sin(TAU_F * 45.0 * t)) * sin(PI * t / 0.05))

# ---------------------------------------------------------------- pos-processamento (tudo circular)
func echo(buf: PackedFloat32Array, delay: int, gain: float, taps: int) -> void:
	var dry := buf.duplicate()
	var n := buf.size()
	for k in range(1, taps + 1):
		var g := pow(gain, k)
		var off := delay * k
		for i in n:
			buf[i] += g * dry[((i - off) % n + n) % n]

func lowpass_loop(buf: PackedFloat32Array, cutoff: float) -> void:
	var a := 1.0 - exp(-TAU_F * cutoff / RATE)
	var y := 0.0
	for pass_i in 2:
		for i in buf.size():
			y += a * (buf[i] - y)
			buf[i] = y

func finish(buf: PackedFloat32Array, name: String, dir: String, peak: float) -> void:
	var pk := 0.0
	for v in buf:
		pk = maxf(pk, absf(v))
	var sc := peak / pk
	var bytes := PackedByteArray()
	bytes.resize(buf.size() * 2)
	var sumsq := 0.0
	for i in buf.size():
		var v := clampf(buf[i] * sc, -1.0, 1.0)
		sumsq += v * v
		bytes.encode_s16(i * 2, int(round(v * 32767.0)))
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = RATE
	st.stereo = false
	st.data = bytes
	st.loop_mode = AudioStreamWAV.LOOP_FORWARD
	st.loop_begin = 0
	st.loop_end = buf.size()
	var path := dir.path_join(name)
	st.save_to_wav(path)
	# emenda: salto entre a ultima e a primeira amostra versus o maior passo entre amostras vizinhas
	var maxstep := 0.0
	for i in range(1, buf.size()):
		maxstep = maxf(maxstep, absf(buf[i] - buf[i - 1]) * sc)
	var seam := absf(buf[0] - buf[buf.size() - 1]) * sc
	print("%s: %.1f s, pico %.2f (%.1f dBFS), RMS %.3f (%.1f dBFS), emenda %.5f (maior passo %.5f)" % [
		name, buf.size() / float(RATE), peak, 20.0 * log(peak) / log(10.0), sqrt(sumsq / buf.size()),
		20.0 * log(sqrt(sumsq / buf.size())) / log(10.0), seam, maxstep])

# ---------------------------------------------------------------- DIA
const CH := {
	"C": [36, [60, 64, 67]], "G": [43, [59, 62, 67]], "Am": [45, [57, 60, 64]],
	"F": [41, [57, 60, 65]], "Em": [40, [59, 64, 67]],
}

func day(dir: String) -> void:
	rng.seed = 7
	var bpm := 100.0
	var eighth := int(RATE * 60.0 / bpm / 2.0)
	var bars := 16
	var buf := PackedFloat32Array()
	buf.resize(bars * 8 * eighth)
	var chords := ["C", "G", "Am", "F", "C", "G", "F", "C", "Am", "F", "C", "G", "Am", "F", "G", "C"]
	var melody := [
		"E5 - G5 - E5 - D5 -", "D5 - E5 - G4 - - -", "A4 - C5 - E5 - D5 C5", "A4 - - - C5 - - -",
		"E5 - G5 - A5 - G5 -", "E5 - D5 - B4 - D5 -", "C5 - A4 - C5 - D5 -", "C5 - - - - - _ _",
		"E5 D5 C5 - A4 - C5 -", "C5 - D5 - E5 - C5 -", "G5 - E5 - G5 - A5 -", "G5 - E5 - D5 - B4 -",
		"A4 C5 E5 - D5 - C5 -", "A4 - C5 - F5 - E5 -", "D5 - E5 - D5 - B4 -", "C5 - E5 - G4 - C5 -",
	]
	var swing := int(eighth * 0.12)
	for b in bars:
		var ch: Array = CH[chords[b]]
		var t0 := b * 8 * eighth
		bass(buf, t0, eighth * 3.0 / RATE, ch[0], 0.30)
		bass(buf, t0 + 4 * eighth, eighth * 3.0 / RATE, ch[0] + (7 if b % 2 == 0 else 0), 0.22)
		pad(buf, t0, eighth * 8.0 / RATE, ch[1][1], 0.07, 0.5, 0.6)
		pad(buf, t0, eighth * 8.0 / RATE, ch[1][2], 0.05, 0.5, 0.6)
		var order := [0, 2, 1, 2, 0, 2, 1, 2]
		for s in 8:
			var st := t0 + s * eighth + (swing if s % 2 == 1 else 0)
			pluck(buf, st, ch[1][order[s]] - 5, 0.11 if s % 2 == 0 else 0.08)
			if s % 2 == 1:
				shaker(buf, st, 0.07)
			if s == 0 or s == 4:
				kick(buf, t0 + s * eighth, 0.30)
	for n in parse(melody):
		var s: int = n[0]
		marimba(buf, s * eighth + (swing if s % 2 == 1 else 0), n[1], 0.28)
	echo(buf, int(eighth * 3), 0.28, 3)
	lowpass_loop(buf, 5200.0)
	finish(buf, "musica_dia.wav", dir, 0.55)

# ---------------------------------------------------------------- NOITE
func night(dir: String) -> void:
	rng.seed = 11
	var bpm := 60.0
	var eighth := int(RATE * 60.0 / bpm / 2.0)
	var bars := 8
	var buf := PackedFloat32Array()
	buf.resize(bars * 8 * eighth)
	var chords := ["Am", "F", "C", "Em", "Am", "F", "G", "Am"]
	var melody := [
		"E5 - - - A5 - - -", "C5 - - - A4 - - -", "E5 - - G5 - E5 - -", "B4 - - - G4 - - -",
		"A4 - C5 - E5 - - -", "F5 - E5 - C5 - - -", "D5 - - - B4 - D5 -", "A4 - - - - - - -",
	]
	for b in bars:
		var ch: Array = CH[chords[b]]
		var t0 := b * 8 * eighth
		var len_s := eighth * 8.0 / RATE
		drone(buf, t0, len_s, ch[0] + 12, 0.16)
		for k in 3:
			pad(buf, t0, len_s, ch[1][k], 0.10, 1.4, 1.8)
		pad(buf, t0, len_s, ch[1][0] - 12, 0.07, 1.4, 1.8)
	for n in parse(melody):
		bell(buf, (n[0] as int) * eighth, n[1], 0.26)
	# grilos: poucos e baixos, em posicoes fixas
	for pos in [5, 19, 33, 52]:
		cricket(buf, pos * eighth, 0.025)
	echo(buf, int(eighth * 3), 0.42, 4)
	lowpass_loop(buf, 4200.0)
	finish(buf, "musica_noite.wav", dir, 0.36)

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	assert(args.size() >= 1, "uso: -- <pasta de saida>")
	day(args[0])
	night(args[0])
	quit()
