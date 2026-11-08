## Gerador dos 7 efeitos sonoros de golpe/coleta por SINTESE em codigo. Original, CC BY 4.0, sem amostras de
## terceiros, sem IA. Da raiz do repositorio:
##   godot --headless --script documentacao/design/audio/gerar_sfx_coleta.gd -- <pasta de saida>
## Saida: soco_arvore, golpe_madeira, golpe_pedra, soco_pedra, arvore_cai, rocha_quebra, item_cai (.wav, mono,
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
func soco_arvore() -> PackedFloat32Array:
	var b := buf(0.20)
	add(b, env(tone(0.2, 165, 52), 0.055), 0.0, 1.0)              # corpo grave, peso
	add(b, env(tone(0.2, 240, 110, 1), 0.03), 0.0, 0.35)          # tronco oco
	add(b, env(lp(noise(0.2), 650), 0.05), 0.0, 0.9)              # abafado
	add(b, env(lp(noise(0.05), 2800), 0.006, 0.0003), 0.0, 0.8)   # impacto seco
	sat(b, 1.6)
	return b

func golpe_madeira() -> PackedFloat32Array:
	var b := buf(0.26)
	add(b, env(tone(0.26, 430, 300), 0.045), 0.0, 0.85)           # "toc"
	add(b, env(tone(0.26, 880, 760), 0.022), 0.0, 0.4)            # parcial da madeira
	add(b, env(tone(0.26, 130, 70), 0.06), 0.0, 0.7)              # peso do machado
	add(b, env(bp(noise(0.06), 1500, 5000), 0.009, 0.0003), 0.0, 1.0)  # estalo
	for t in [0.03, 0.055, 0.085, 0.12]:                          # lascas
		add(b, tick(rng.randf_range(2500, 5500), 0.004), t + rng.randf_range(0, 0.01), rng.randf_range(0.25, 0.5))
	sat(b, 1.5)
	return b

func golpe_pedra() -> PackedFloat32Array:
	var b := buf(0.27)
	add(b, env(tone(0.27, 2050, 2000), 0.05), 0.0, 0.55)          # clique metalico, parciais inarmonicos
	add(b, env(tone(0.27, 3040, 3000), 0.035), 0.0, 0.4)
	add(b, env(tone(0.27, 4380, 4300), 0.02), 0.0, 0.28)
	add(b, env(tone(0.27, 150, 90), 0.04), 0.0, 0.6)              # thud
	add(b, env(hp(noise(0.03), 2500), 0.004, 0.0002), 0.0, 1.0)   # clique
	for i in 7:                                                    # pedriscos saltando
		add(b, tick(rng.randf_range(3000, 7000), 0.005), 0.045 + i * 0.026 + rng.randf_range(0, 0.012), rng.randf_range(0.2, 0.55))
	sat(b, 1.4)
	return b

func soco_pedra() -> PackedFloat32Array:
	var b := buf(0.24)
	add(b, env(tone(0.24, 200, 85), 0.03), 0.0, 1.0)              # impacto curto e seco
	add(b, env(bp(noise(0.05), 1200, 4200), 0.01, 0.0003), 0.0, 0.9)
	add(b, env(hp(noise(0.02), 3000), 0.003, 0.0002), 0.0, 0.5)
	# "ai": voz curta, serra filtrada com queda e vibrato leve, entra logo depois do soco
	var v := tone(0.16, 340, 190, 2)
	for i in v.size():
		v[i] *= 1.0 + 0.25 * sin(TAU * 38.0 * float(i) / RATE)
	v = lp(v, 1100)
	add(b, env(v, 0.07, 0.006), 0.025, 0.55)
	sat(b, 1.6)
	return b

func arvore_cai() -> PackedFloat32Array:
	var b := buf(1.3)
	# rangido: serra grave com afinacao instavel e "trava-solta" (tremolo), cresce ate o estalo
	var cr := buf(0.5)
	var ph := 0.0
	var wob := 0.0
	for i in cr.size():
		var t := float(i) / RATE
		wob += (rng.randf_range(-1, 1) - wob) * 0.0008
		var f := 150.0 + 90.0 * (t / 0.5) + 70.0 * wob + 12.0 * sin(TAU * 7.0 * t)
		ph = fmod(ph + f / RATE, 1.0)
		var stick := 0.55 + 0.45 * sin(TAU * (22.0 + 20.0 * t) * t)
		cr[i] = (2.0 * ph - 1.0) * stick * pow(t / 0.5, 1.3)
	cr = lp(cr, 900)
	add(b, cr, 0.0, 0.55)
	add(b, env(bp(noise(0.07), 1200, 5000), 0.012, 0.0004), 0.42, 0.9)   # estalo do tronco
	add(b, env(bp(noise(0.5), 300, 2000), 0.12), 0.44, 0.35)             # rachadura
	# queda: sopro de folhas crescendo ate o chao
	var sw := bp(noise(0.62), 1800, 6500)
	for i in sw.size():
		var t := float(i) / RATE / 0.62
		sw[i] *= pow(t, 1.6) * 0.8 + 0.1
	add(b, sw, 0.40, 0.55)
	# batida no chao em 0.98 s
	add(b, env(tone(0.3, 95, 38), 0.11), 0.98, 1.0)
	add(b, env(lp(noise(0.3), 800), 0.08), 0.98, 0.9)
	add(b, env(bp(noise(0.3), 1500, 6000), 0.09), 0.98, 0.45)            # folhas
	for i in 14:                                                          # folhas e galhos assentando
		add(b, tick(rng.randf_range(2000, 6000), 0.006), 1.0 + rng.randf_range(0.0, 0.28), rng.randf_range(0.1, 0.35))
	sat(b, 1.3)
	return b

func rocha_quebra() -> PackedFloat32Array:
	var b := buf(0.85)
	add(b, env(hp(noise(0.06), 1800), 0.008, 0.0003), 0.0, 1.0)           # estalo da fratura
	add(b, env(tone(0.3, 120, 60), 0.07), 0.0, 0.7)
	add(b, env(bp(noise(0.8), 250, 1500), 0.14), 0.01, 0.55)              # esfarelar
	for i in 46:                                                          # pedrinhas: densas no inicio, rareando
		var u := pow(rng.randf(), 1.8)
		var f := rng.randf_range(1800, 7000)
		add(b, tick(f, rng.randf_range(0.004, 0.009)), 0.03 + u * 0.7, rng.randf_range(0.15, 0.6) * (1.0 - 0.6 * u))
	sat(b, 1.4)
	return b

func item_cai() -> PackedFloat32Array:
	var b := buf(0.16)
	add(b, env(tone(0.16, 330, 135), 0.04, 0.002), 0.0, 0.9)              # plop
	add(b, env(tone(0.16, 660, 280, 1), 0.02, 0.002), 0.0, 0.25)
	add(b, env(lp(noise(0.03), 1800), 0.004, 0.0005), 0.0, 0.4)           # toque no chao
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
		["soco_arvore", "mao nua em tronco: baque abafado com impacto seco", soco_arvore()],
		["golpe_madeira", "machado em madeira: toc com estalo de lasca", golpe_madeira()],
		["golpe_pedra", "ferramenta em pedra ou minerio: clique metalico com pedriscos", golpe_pedra()],
		["soco_pedra", "mao em pedra: impacto seco e curto com gemido de dor", soco_pedra()],
		["arvore_cai", "rangido do tronco, estalo, queda com folhas e batida no chao", arvore_cai()],
		["rocha_quebra", "rocha esfarelando, pedrinhas caindo", rocha_quebra()],
		["item_cai", "item caindo no chao: plop leve", item_cai()],
	]
	var md := "# SFX de golpe e coleta (Dino Vale)\n\nGerados por `documentacao/design/audio/gerar_sfx_coleta.gd` (mono, 16 bits, 44100 Hz). Regenerar, da raiz do repositorio:\n`godot --headless --script documentacao/design/audio/gerar_sfx_coleta.gd -- <pasta>`\n\n| arquivo | descricao | duracao | pico |\n|---|---|---|---|\n"
	var cred := ""
	for it in lista:
		rng.seed = hash(it[0])
		# regenera com a semente por arquivo: chama de novo para a saida depender so do nome
		var b: PackedFloat32Array = call(it[0])
		var m := save("%s/%s.wav" % [out, it[0]], finish(b))
		md += "| %s.wav | %s | %d ms | %.2f dBFS |\n" % [it[0], it[1], int(round(m[0])), m[1]]
		cred += "| game/assets/audio/sfx/%s.wav | propria | autoria do projeto, gerado por `documentacao/design/audio/gerar_sfx_coleta.gd` (sem IA, sem recorte de terceiros); %s, por sintese em codigo (mono, 16 bits, 44100 Hz) | - | CC-BY-4.0 | pendente de aprovacao do dono; pico em -3 dBFS | 2026-11-08 |\n" % [it[0], it[1]]
		print("%s: %d ms, pico %.2f dBFS" % [it[0], int(round(m[0])), m[1]])
	md += "\n## Linhas para `game/assets/CREDITS.md`\n\nO caminho `audio/sfx/` e sugestao; ajuste ao destino real.\n\n" + cred
	var f := FileAccess.open(out + "/LEIA.md", FileAccess.WRITE)
	f.store_string(md)
	f.close()
	quit()
