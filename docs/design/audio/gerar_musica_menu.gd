## Gerador da faixa do MENU PRINCIPAL ("Tema do Vale") por SINTESE em codigo. Original, CC BY 4.0, sem amostras
## nem trechos de terceiros, sem IA. Da raiz do repositorio:
##   godot --headless --script docs/design/audio/gerar_musica_menu.gd -- <pasta de saida>
## Saida: musica_menu.wav (mono, 16 bits, 22050 Hz, mesmo formato de musica_dia/noite). NAO grava em game/assets.
##
## LOOP PERFEITO: numero inteiro de compassos e todo som (notas, eco, prato) escrito com indice circular (modulo N);
## filtro final em duas voltas. No Godot: loop = Forward (loop_begin 0, loop_end = fim).
##
## Tema: 124 BPM, Re maior, 16 compassos de 8 colcheias (~31 s). Mais cheia e marcante que dia/noite: flauta na melodia
## (vibrato leve), marimba em oitava na secao B, arpejo de violao, baixo sincopado, bumbo, caixa, chocalho, tons de
## "tambor" nas viradas (compassos 4, 8, 12, 16) e prato na volta do loop. Secao A (1-8): tema; secao B (9-16): sobe e
## termina na dominante (La) para voltar ao Re do compasso 1 sem emenda. Melodia escrita a mao, em Re maior.
## Ruido usa semente fixa: a saida e identica a cada execucao.
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

# ---------------------------------------------------------------- instrumentos extras do menu
func flute(buf: PackedFloat32Array, start: int, length: float, m: float, amp: float) -> void:
	var f := hz(m)
	var total := length + 0.18
	put(buf, start, int(RATE * total), func(t: float) -> float:
		var a := clampf(t / 0.035, 0.0, 1.0)
		var rel := clampf((total - t) / 0.18, 0.0, 1.0)
		var pm := (f * 0.006 / 5.2) * clampf(t / 0.25, 0.0, 1.0) * sin(TAU_F * 5.2 * t)
		var ph := TAU_F * f * t + pm
		var v := sin(ph) + 0.32 * sin(2.0 * ph) + 0.1 * sin(3.0 * ph)
		return amp * a * rel * v)

func snare(buf: PackedFloat32Array, start: int, amp: float) -> void:
	var prev := 0.0
	var n := buf.size()
	for i in int(RATE * 0.16):
		var t := float(i) / RATE
		var x := rng.randf_range(-1.0, 1.0)
		var hp := x - prev * 0.6
		prev = x
		buf[(start + i) % n] += amp * (hp * exp(-t * 26.0) + 0.5 * sin(TAU_F * 190.0 * t) * exp(-t * 30.0)) * minf(t / 0.001, 1.0)

func tom(buf: PackedFloat32Array, start: int, f0: float, amp: float) -> void:
	put(buf, start, int(RATE * 0.35), func(t: float) -> float:
		var ph := TAU_F * (f0 * 0.7 * t + f0 * 0.3 * (1.0 - exp(-t * 14.0)) / 14.0)
		return amp * sin(ph) * exp(-t * 9.0) * minf(t / 0.002, 1.0))

func crash(buf: PackedFloat32Array, start: int, amp: float) -> void:
	var prev := 0.0
	var n := buf.size()
	for i in int(RATE * 1.4):
		var t := float(i) / RATE
		var x := rng.randf_range(-1.0, 1.0)
		var hp := x - prev * 0.85
		prev = x
		buf[(start + i) % n] += amp * hp * exp(-t * 3.2) * minf(t / 0.002, 1.0)

# ---------------------------------------------------------------- MENU
const CHM := {
	"D": [38, [62, 66, 69]], "A": [45, [61, 64, 69]], "Bm": [47, [62, 66, 71]],
	"G": [43, [62, 67, 71]], "Em": [40, [59, 64, 67]],
}

func menu(dir: String) -> void:
	rng.seed = 23
	var bpm := 124.0
	var eighth := int(RATE * 60.0 / bpm / 2.0)
	var bars := 16
	var buf := PackedFloat32Array()
	buf.resize(bars * 8 * eighth)
	var chords := ["D", "A", "Bm", "G", "D", "A", "G", "A", "Bm", "G", "D", "A", "Bm", "G", "Em", "A"]
	var melody := [
		"A4 - D5 - F#5 - A5 -", "A5 - G5 F#5 E5 - C#5 -", "D5 - F#5 - B5 - A5 F#5", "G5 - - - D5 - B4 -",
		"A4 - D5 - F#5 - A5 -", "B5 - A5 F#5 E5 - F#5 E5", "D5 - G5 - B5 - A5 G5", "F#5 - E5 - C#5 - - -",
		"F#5 - F#5 - D5 - F#5 -", "G5 - B5 - G5 - D5 -", "F#5 - A5 - F#5 - D5 -", "E5 - A5 - E5 - C#5 -",
		"B5 - - A5 F#5 - A5 B5", "D6 - - B5 G5 - B5 -", "E5 - G5 - B5 - A5 G5", "A5 - G5 F#5 E5 - C#5 E5",
	]
	for b in bars:
		var ch: Array = CHM[chords[b]]
		var t0 := b * 8 * eighth
		var sec_b := b >= 8
		# baixo sincopado
		bass(buf, t0, eighth * 2.0 / RATE, ch[0], 0.34)
		bass(buf, t0 + 3 * eighth, eighth * 1.0 / RATE, ch[0] + 12, 0.20)
		bass(buf, t0 + 4 * eighth, eighth * 2.0 / RATE, ch[0] + 7, 0.28)
		bass(buf, t0 + 6 * eighth, eighth * 2.0 / RATE, ch[0] + (12 if b % 2 == 0 else 7), 0.22)
		# pad: so na secao B (da corpo)
		if sec_b:
			for k in 3:
				pad(buf, t0, eighth * 8.0 / RATE, ch[1][k], 0.05, 0.4, 0.5)
		# arpejo de violao
		var order := [0, 1, 2, 1, 0, 1, 2, 1] if not sec_b else [0, 2, 1, 2, 0, 2, 1, 2]
		for s in 8:
			var st := t0 + s * eighth
			pluck(buf, st, ch[1][order[s]] - 5, 0.10 if s % 2 == 0 else 0.07)
			if s % 2 == 1:
				shaker(buf, st, 0.08)
		# percussao
		kick(buf, t0, 0.34)
		kick(buf, t0 + 4 * eighth, 0.30)
		if sec_b:
			kick(buf, t0 + 3 * eighth, 0.22)
			kick(buf, t0 + 6 * eighth, 0.24)
		snare(buf, t0 + 2 * eighth, 0.16)
		snare(buf, t0 + 6 * eighth, 0.20)
		if b % 4 == 3:  # virada de tons
			tom(buf, t0 + 5 * eighth, 190.0, 0.30)
			tom(buf, t0 + 6 * eighth, 150.0, 0.30)
			tom(buf, t0 + 7 * eighth, 115.0, 0.32)
		if b == 0 or b == 8:
			crash(buf, t0, 0.12)
	for n in parse(melody):
		var s: int = n[0]
		var len_s := (n[2] as int) * eighth / RATE * 0.95
		flute(buf, s * eighth, len_s, n[1], 0.24)
		if s >= 64:  # secao B: marimba dobra a melodia
			marimba(buf, s * eighth, n[1] - 12, 0.14)
	echo(buf, int(eighth * 3), 0.25, 3)
	lowpass_loop(buf, 5600.0)
	finish(buf, "musica_menu.wav", dir, 0.55)

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	assert(args.size() >= 1, "uso: -- <pasta de saida>")
	menu(args[0])
	quit()
