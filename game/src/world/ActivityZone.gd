# SPDX-License-Identifier: MIT
class_name ActivityZone
extends RefCounted
## Regra pura da zona ativa (MUN-05): dado a distância de cada dino ao jogador mais próximo, diz se ele fica
## ATIVO (IA e física), DISTANTE (só anda em dado) ou DORMENTE. Sem nó, sem física: testável com números.
## Os fixados pelo estado (perseguindo, fugindo, domado, desacordado) ficam ativos pelo estado, não pelo raio.

enum Mode { ACTIVE, FAR, DORMANT }


## Modo de cada dino. `distances_px[i]` é a distância ao jogador mais próximo; `pinned[i]` (1 = fixado pelo
## estado). Ativos: os fixados mais os que estão dentro do raio ativo, no máximo `rules.max_active` ao todo
## (cada fixado ocupa uma vaga; os não fixados dentro do raio disputam o resto, os mais perto primeiro; quem
## perde a vaga vira distante). Além do raio distante, dorme. `priority[i]` (1 = carnívoro; opcional) ganha a vaga antes da
## distância: um bando de herbívoros perto não deixa o caçador calmo a 10 tiles fora da tela.
static func classify(distances_px: PackedFloat32Array, pinned: PackedByteArray, rules: ZoneRules,
		priority: PackedByteArray = PackedByteArray()) -> Array[Mode]:
	var modes: Array[Mode] = []
	modes.resize(distances_px.size())
	var active_px := rules.active_radius_tiles * rules.tile_size
	var far_px := rules.far_radius_tiles * rules.tile_size
	var contenders: Array[int] = []
	var taken := 0
	for i in distances_px.size():
		if pinned[i] != 0:
			modes[i] = Mode.ACTIVE
			taken += 1
		elif distances_px[i] <= active_px:
			modes[i] = Mode.ACTIVE
			contenders.append(i)
		elif distances_px[i] <= far_px:
			modes[i] = Mode.FAR
		else:
			modes[i] = Mode.DORMANT
	var free_slots := maxi(rules.max_active - taken, 0)
	if contenders.size() > free_slots:
		contenders.sort_custom(func(a: int, b: int) -> bool:
			var pa := priority[a] if a < priority.size() else 0
			var pb := priority[b] if b < priority.size() else 0
			if pa != pb:
				return pa > pb
			return distances_px[a] < distances_px[b] or (distances_px[a] == distances_px[b] and a < b))
		for rank in range(free_slots, contenders.size()):
			modes[contenders[rank]] = Mode.FAR
	return modes
