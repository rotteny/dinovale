# SPDX-License-Identifier: MIT
class_name ProgressionComponent
extends Node
## Nível, XP e Saber do jogador (E6, PRO-11). Só estado e regra: não conhece HUD, mundo nem quem concede o XP (a
## autoridade chama `grant_xp`; a HUD ouve os sinais). Números em `ProgressionRules`. O Saber guardado é o GASTO: o total
## deriva do nível (`rules.saber_until`), então uma curva ajustada não deixa o save com Saber inventado.

## O XP ou o nível mudou (também ao restaurar um save: a HUD se redesenha). `needed` é 0 no teto.
signal xp_changed(level: int, xp: int, needed: int)
## Subiu de nível. Um sinal só por concessão, mesmo que ela cruze vários níveis: `level` é o nível de chegada e
## `saber_gained`, o Saber somado de todos os níveis cruzados. Carregar um save NUNCA emite isto.
signal leveled_up(level: int, saber_gained: int)
## O Saber livre mudou (gasto ou ganho).
signal saber_changed(free: int)

const FORMAT_VERSION := 1
## Teto de uma concessão: dado externo não confiável não pode girar o laço por um valor absurdo.
const MAX_GRANT := 1000000

@export var rules: ProgressionRules = preload("res://data/balance/progression_rules.tres")

var level: int = 1
var xp: int = 0
var saber_spent: int = 0


func xp_needed() -> int:
	return rules.xp_to_next(level)


func is_max_level() -> bool:
	return level >= rules.level_max


func saber_total() -> int:
	return rules.saber_until(level)


func saber_free() -> int:
	return maxi(saber_total() - saber_spent, 0)


## Concede XP (a AUTORIDADE chama; nada na apresentação). Devolve quantos níveis subiu. No teto o XP não acumula.
func grant_xp(amount: int) -> int:
	if amount <= 0 or is_max_level():
		return 0
	var left := mini(amount, MAX_GRANT)
	var gained_levels := 0
	var saber_gained := 0
	while left > 0 and not is_max_level():
		var missing := xp_needed() - xp
		if left < missing:
			xp += left
			left = 0
		else:
			left -= missing
			level += 1
			xp = 0
			gained_levels += 1
			saber_gained += rules.saber_at(level)
	xp_changed.emit(level, xp, xp_needed())
	if gained_levels > 0:
		leveled_up.emit(level, saber_gained)
		saber_changed.emit(saber_free())
	return gained_levels


## XP de uma coleta concluída.
func grant_gather() -> int:
	return grant_xp(rules.xp_per_gather)


## XP de uma fabricação (gancho para a E7a).
func grant_craft() -> int:
	return grant_xp(rules.xp_per_craft)


## XP de domar um dino que ficou em `final_level`.
func grant_tame(final_level: int) -> int:
	return grant_xp(rules.tame_xp(final_level))


## Gasta Saber (a E7b chama ao aprender receita). `false` e nada muda se não houver o bastante.
func spend_saber(amount: int) -> bool:
	if amount <= 0 or amount > saber_free():
		return false
	saber_spent += amount
	saber_changed.emit(saber_free())
	return true


func to_dict() -> Dictionary:
	return {"version": FORMAT_VERSION, "level": level, "xp": xp, "saber_spent": saber_spent}


## Restaura sem emitir `leveled_up` (carregar não é evento de jogo). Campo ausente ou inválido fica como está; número fora da
## faixa é LIMITADO (nível acima do teto vira o teto, XP acima do que o nível pede fica no limite, Saber gasto acima do total
## cai no total): ajustar a curva depois não pune quem já tinha salvo.
func from_dict(data: Dictionary) -> void:
	level = int(SafeRead.number(data.get("level"), level, 1.0, rules.level_max))
	var needed := xp_needed()
	xp = int(SafeRead.number(data.get("xp"), xp, 0.0, maxi(needed - 1, 0))) if needed > 0 else 0
	saber_spent = int(SafeRead.number(data.get("saber_spent"), saber_spent, 0.0, saber_total()))
	saber_spent = clampi(saber_spent, 0, saber_total())  # o valor de antes (padrão de dado inválido) também tem de caber no nível lido
	xp = mini(xp, maxi(needed - 1, 0))  # o XP de antes pode não caber no nível lido
	xp_changed.emit(level, xp, needed)
	saber_changed.emit(saber_free())
