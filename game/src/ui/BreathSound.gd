# SPDX-License-Identifier: MIT
class_name BreathSound
extends RefCounted
## Sons de fôlego PLACEHOLDER, sintetizados (ruído filtrado com envelope), para o ofegar
## existir antes de haver áudio de verdade. Determinístico (sem RNG). Troque por arquivo
## em `cue_streams` do `PlayerView` (chaves `pant` e `gasp`).

const RATE := 22050


## Sopro curto (`pant`) ou fôlego longo (`gasp`).
static func make(seconds: float, low_pass: float) -> AudioStreamWAV:
	var count := int(RATE * seconds)
	var data := PackedByteArray()
	data.resize(count * 2)
	var state := 12345
	var smooth := 0.0
	for i in count:
		state = (state * 1103515245 + 12345) & 0x7fffffff
		var noise := float(state % 2001) / 1000.0 - 1.0
		smooth += (noise - smooth) * low_pass
		var t := float(i) / count
		var envelope := sin(PI * t) * (1.0 - 0.4 * t)
		data.encode_s16(i * 2, int(clampf(smooth * envelope * 0.9, -1.0, 1.0) * 32767.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = data
	return stream
