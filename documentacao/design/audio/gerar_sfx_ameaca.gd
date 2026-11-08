## Gerador dos 5 efeitos sonoros de ameaca e golpe dos dinos (M1) por SINTESE em codigo. Original, CC BY 4.0, sem
## amostras de terceiros, sem IA. Da raiz do repositorio:
##   godot --headless --script documentacao/design/audio/gerar_sfx_ameaca.gd -- <pasta de saida>
## Saida: paqui_bufada, paqui_cabecada, raptor_rosnado, raptor_mordida, dino_dor (.wav, mono,
## 16 bits, 44100 Hz, pico em -3 dBFS, fade-out de 8 ms) e LEIA.md (descricao, duracao e pico medidos, linhas do
## CREDITS). NAO grava em game/assets. Ruido com semente fixa: a saida e identica a cada execucao.
## Receita geral: transiente de ruido (clique) + corpo tonal com queda de afinacao (peso) + ruido filtrado com
## envelope (material), saturacao leve (tanh) para dar murro.
extends SceneTree

const RATE := 44100
const PEAK := 0.7079  # -3 dBFS
const FADE := 0.008

var rng := RandomNumberGenerator.new()

# ---------------------------------------------------------------- blocos
func buf(dur: float) -> PackedFloat32Array:
	var b := PackedFloat32Array()
	b.resize(int(dur * RATE))
	return b

func noise(dur: float) -> PackedFloat32Array:
	var b := buf(dur)
	for i in b.size():
		b[i] = rng.randf_range(-1.0, 1.0)
	return b

func lp(b: PackedFloat32Array, fc: float) -> PackedFloat32Array:
	var a := 1.0 - exp(-TAU * fc / RATE)
	var y := 0.0
	var o := b.duplicate()
	for i in o.size():
		y += a * (o[i] - y)
		o[i] = y
	return o

func hp(b: PackedFloat32Array, fc: float) -> PackedFloat32Array:
	var l := lp(b, fc)
	var o := b.duplicate()
	for i in o.size():
		o[i] = b[i] - l[i]
	return o

func bp(b: PackedFloat32Array, f_lo: float, f_hi: float) -> PackedFloat32Array:
	return hp(lp(b, f_hi), f_lo)

## envelope exponencial com ataque curto
func env(b: PackedFloat32Array, decay: float, attack := 0.001) -> PackedFloat32Array:
	var o := b.duplicate()
	for i in o.size():
		var t := float(i) / RATE
		o[i] *= minf(t / attack, 1.0) * exp(-t / decay)
	return o

## tom com glissando exponencial f0 -> f1. forma: 0 seno, 1 triangulo, 2 serra
func tone(dur: float, f0: float, f1: float, shape := 0) -> PackedFloat32Array:
	var b := buf(dur)
	var ph := 0.0
	for i in b.size():
		var t := float(i) / RATE
		var f := f0 * pow(f1 / f0, t / dur)
		ph = fmod(ph + f / RATE, 1.0)
		match shape:
			0: b[i] = sin(TAU * ph)
			1: b[i] = 4.0 * absf(ph - 0.5) - 1.0
			_: b[i] = 2.0 * ph - 1.0
	return b

func add(dst: PackedFloat32Array, src: PackedFloat32Array, at: float, gain: float) -> void:
	var o := int(at * RATE)
	for i in src.size():
		if o + i >= 0 and o + i < dst.size():
			dst[o + i] += src[i] * gain

func tick(freq: float, decay: float) -> PackedFloat32Array:
	# pedrisco/lasca: estalo curtissimo, ruido passa-faixa em torno de freq
	var n := noise(decay * 6.0)
	return env(bp(n, freq * 0.6, freq * 1.5), decay, 0.0004)

func sat(b: PackedFloat32Array, drive: float) -> void:
	for i in b.size():
		b[i] = tanh(b[i] * drive)

# ---------------------------------------------------------------- sons
## ressonador de um polo (formante): realca a banda em torno de fc
func formant(b: PackedFloat32Array, fc: float, q: float) -> PackedFloat32Array:
	return bp(b, fc / q, fc * q)

## voz rascante: serra com afinacao f(t), tremolo de rosnado (am_hz) e jitter; devolve antes do filtro
func growl(dur: float, f0: float, f1: float, am_hz: float, am_depth: float, jit: float) -> PackedFloat32Array:
	var b := buf(dur)
	var ph := 0.0
	var wob := 0.0
	for i in b.size():
		var t := float(i) / RATE
		wob += (rng.randf_range(-1, 1) - wob) * 0.002
		var f := (f0 + (f1 - f0) * (t / dur)) * (1.0 + jit * wob)
		ph = fmod(ph + f / RATE, 1.0)
		var am := 1.0 - am_depth * (0.5 + 0.5 * sin(TAU * am_hz * t))
		b[i] = (2.0 * ph - 1.0) * am
	return b

## Bufada: dois sopros de ar pelo nariz (ruido passa-faixa com ataque rapido e queda), o segundo mais forte,
## com um fio grave de ar vibrando nas narinas.
func paqui_bufada() -> PackedFloat32Array:
	var b := buf(0.50)
	for s in [[0.0, 0.20, 0.75], [0.25, 0.25, 1.0]]:
		var d: float = s[1]
		var sopro := bp(noise(d), 500, 3200)
		for i in sopro.size():
			var t := float(i) / RATE / d
			sopro[i] *= pow(sin(PI * minf(t * 1.0, 1.0)), 0.6) * exp(-t * 1.6) * minf(t * 14.0, 1.0)
		add(b, sopro, s[0], s[2])
		var nar := lp(growl(d, 150, 110, 55.0, 0.8, 0.05), 420)       # narinas vibrando
		add(b, env(nar, d * 0.5, 0.01), s[0], 0.35 * s[2])
		add(b, env(hp(noise(d), 4500), d * 0.3, 0.004), s[0], 0.22 * s[2])   # chiado
	sat(b, 1.3)
	return b

## Cabecada: crânio osso contra algo duro: estalo seco, tom oco curto (caixa de osso, ~300 Hz, queda leve) e thump grave.
func paqui_cabecada() -> PackedFloat32Array:
	var b := buf(0.27)
	add(b, env(hp(noise(0.03), 1800), 0.004, 0.0002), 0.0, 0.8)           # estalo do osso
	add(b, env(tone(0.27, 330, 255), 0.05, 0.0006), 0.0, 0.95)            # oco: ressonancia da calota
	add(b, env(tone(0.27, 610, 520, 1), 0.028, 0.0006), 0.0, 0.35)        # parcial mais agudo, "toc"
	add(b, env(tone(0.27, 120, 55), 0.07, 0.001), 0.0, 0.8)               # peso do corpo atras
	add(b, env(lp(noise(0.1), 700), 0.03), 0.0, 0.5)
	sat(b, 1.7)
	return b

## Rosnado: voz grave rascante com tremolo de ~26 Hz, afinacao oscilante que cai, formantes de boca aberta,
## sopro de ar e um fim que afunda. Cresce nos primeiros 120 ms.
func raptor_rosnado() -> PackedFloat32Array:
	var b := buf(0.62)
	var v := growl(0.62, 118, 82, 26.0, 0.75, 0.10)
	var voz := formant(v, 420, 1.5)
	voz = add_mix(voz, formant(v, 1150, 1.4), 0.55)
	voz = lp(voz, 2400)
	for i in voz.size():
		var t := float(i) / RATE
		var cresce := minf(t / 0.12, 1.0)
		var cai := 1.0 - 0.7 * smoothstep(0.42, 0.62, t)
		voz[i] *= cresce * cai
	add(b, voz, 0.0, 1.0)
	add(b, lp(growl(0.62, 59, 41, 26.0, 0.5, 0.1), 160), 0.0, 0.7)         # corpo sub-grave
	var ar := bp(noise(0.62), 1500, 5500)
	for i in ar.size():
		var t := float(i) / RATE
		ar[i] *= (0.5 + 0.5 * sin(TAU * 26.0 * t)) * minf(t / 0.1, 1.0) * (1.0 - smoothstep(0.45, 0.62, t))
	add(b, ar, 0.0, 0.16)                                                  # ar na garganta
	sat(b, 1.8)
	return b

func add_mix(a: PackedFloat32Array, c: PackedFloat32Array, g: float) -> PackedFloat32Array:
	var o := a.duplicate()
	for i in o.size():
		o[i] += c[i] * g
	return o

## Mordida: mandibulas que se fecham no ar (sopro curto), estalo dos dentes e o baque do maxilar, com um
## segundo fecho menor logo depois (o "tec-tec" de dente contra dente).
func raptor_mordida() -> PackedFloat32Array:
	var b := buf(0.26)
	var ar := bp(noise(0.08), 900, 4200)
	for i in ar.size():
		var t := float(i) / RATE / 0.08
		ar[i] *= sin(PI * minf(t, 1.0)) * 0.9
	add(b, ar, 0.0, 0.5)                                                   # mandibula cortando o ar
	add(b, env(hp(noise(0.04), 2500), 0.006, 0.0003), 0.07, 1.0)           # estalo dos dentes
	add(b, env(bp(noise(0.08), 400, 1800), 0.018, 0.0005), 0.07, 0.7)      # carne/couro
	add(b, env(tone(0.2, 150, 70), 0.04, 0.001), 0.07, 0.9)                # baque do maxilar
	add(b, env(hp(noise(0.03), 3000), 0.004, 0.0002), 0.135, 0.55)         # dente contra dente
	add(b, env(tone(0.12, 220, 130, 1), 0.02, 0.0005), 0.135, 0.3)
	sat(b, 1.5)
	return b

## Dor generica: ganido curto e agudo que sobe e cai, com vibrato rapido e formante de boca aberta; serve a qualquer dino.
func dino_dor() -> PackedFloat32Array:
	var b := buf(0.30)
	var v := buf(0.30)
	var ph := 0.0
	for i in v.size():
		var t := float(i) / RATE
		var u := t / 0.30
		var f := 300.0 + 260.0 * sin(PI * minf(u * 1.6, 1.0)) * (1.0 - u * 0.5) - 90.0 * u
		f *= 1.0 + 0.035 * sin(TAU * 34.0 * t)
		ph = fmod(ph + f / RATE, 1.0)
		v[i] = 2.0 * ph - 1.0
	var voz := add_mix(formant(v, 700, 1.4), formant(v, 1700, 1.4), 0.5)
	for i in voz.size():
		var t := float(i) / RATE
		voz[i] *= minf(t / 0.015, 1.0) * exp(-t / 0.16)
	add(b, voz, 0.0, 1.0)
	add(b, env(bp(noise(0.3), 1800, 5000), 0.05, 0.004), 0.0, 0.12)        # ar do choro
	sat(b, 1.5)
	return b

# ---------------------------------------------------------------- saida
func finish(b: PackedFloat32Array) -> PackedFloat32Array:
	var nf := int(FADE * RATE)
	for i in nf:
		b[b.size() - 1 - i] *= float(i) / nf
	var pk := 0.0
	for s in b:
		pk = maxf(pk, absf(s))
	for i in b.size():
		b[i] = b[i] / pk * PEAK
	return b

func save(path: String, b: PackedFloat32Array) -> Array:
	var bytes := PackedByteArray()
	bytes.resize(b.size() * 2)
	var pk := 0
	for i in b.size():
		var v := clampi(int(round(b[i] * 32767.0)), -32768, 32767)
		pk = maxi(pk, absi(v))
		bytes.encode_s16(i * 2, v)
	var st := AudioStreamWAV.new()
	st.format = AudioStreamWAV.FORMAT_16_BITS
	st.mix_rate = RATE
	st.stereo = false
	st.data = bytes
	st.save_to_wav(path)
	return [float(b.size()) / RATE * 1000.0, 20.0 * log(pk / 32767.0) / log(10.0)]

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var out := (args[0] if args.size() > 0 else "sfx_saida") as String
	DirAccess.make_dir_recursive_absolute(out)
	var lista := [
		["paqui_bufada", "Paquicefalo, ameaca: dois sopros de ar pelo nariz, o segundo mais forte", paqui_bufada()],
		["paqui_cabecada", "Paquicefalo, golpe: impacto oco de cranio com estalo de osso", paqui_cabecada()],
		["raptor_rosnado", "Utahraptor, ameaca: rosnado grave rascante que cresce e afunda", raptor_rosnado()],
		["raptor_mordida", "Utahraptor, golpe: estalo de mandibula com baque e dente contra dente", raptor_mordida()],
		["dino_dor", "dor generica de dino: ganido curto que sobe e cai", dino_dor()],
	]
	var md := "# SFX de ameaca e golpe dos dinos, M1 (Dino Vale)\n\nGerados por `documentacao/design/audio/gerar_sfx_ameaca.gd` (mono, 16 bits, 44100 Hz). Regenerar, da raiz do repositorio:\n`godot --headless --script documentacao/design/audio/gerar_sfx_ameaca.gd -- <pasta>`\n\n| arquivo | descricao | duracao | pico |\n|---|---|---|---|\n"
	var cred := ""
	for it in lista:
		rng.seed = hash(it[0])
		# regenera com a semente por arquivo: chama de novo para a saida depender so do nome
		var b: PackedFloat32Array = call(it[0])
		var m := save("%s/%s.wav" % [out, it[0]], finish(b))
		md += "| %s.wav | %s | %d ms | %.2f dBFS |\n" % [it[0], it[1], int(round(m[0])), m[1]]
		cred += "| game/assets/audio/sfx/%s.wav | propria | autoria do projeto, gerado por `documentacao/design/audio/gerar_sfx_ameaca.gd` (sem IA, sem recorte de terceiros); %s, por sintese em codigo (mono, 16 bits, 44100 Hz) | - | CC-BY-4.0 | pendente de aprovacao do dono; pico em -3 dBFS | 2026-11-08 |\n" % [it[0], it[1]]
		print("%s: %d ms, pico %.2f dBFS" % [it[0], int(round(m[0])), m[1]])
	md += "\n## Linhas para `game/assets/CREDITS.md`\n\nO caminho `audio/sfx/` e sugestao; ajuste ao destino real.\n\n" + cred
	var f := FileAccess.open(out + "/LEIA.md", FileAccess.WRITE)
	f.store_string(md)
	f.close()
	quit()
