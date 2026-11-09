# SPDX-License-Identifier: MIT
class_name DinoLevelRules
extends Resource
## Regras de nível do dino, só dados e funções puras (sem estado). Os atributos
## base da criatura valem para `base_level`; cada atributo muda linearmente com a
## distância até ele, com piso. Valores em `res://data/balance/dino_level_rules.tres`.

const _EPSILON := 1e-9

@export var base_level: int = 10
@export var min_level: int = 1
## Teto de nível no mundo (50 selvagem x 1,5 de bônus de domesticação).
@export var max_level: int = 75
## Vida máxima e dano.
@export var health_slope: float = 0.04
@export var health_floor: float = 0.5
@export var torpor_slope: float = 0.02
@export var torpor_floor: float = 0.7
## Refeições para domesticar.
@export var meals_slope: float = 0.015
@export var meals_floor: float = 0.85
## Rendimento da carcaça por nível (GDD 5.6: o mesmo fator do Peso, piso 0,7).
@export var carcass_slope: float = 0.03
@export var carcass_floor: float = 0.7
## Bônus de nível com 100% de Eficiência (0,5 = +50%).
@export var taming_bonus: float = 0.5
## O nível final nunca passa de `taming_cap x nível selvagem`.
@export var taming_cap: float = 1.5
## Distância (em tiles) até a qual o jogador vê o "Nv N" sobre o selvagem.
@export var level_tag_range_tiles: float = 6.0
@export_range(4, 64) var tile_size: int = 16


## Alcance do "Nv N" do selvagem, em pixels do mundo.
func level_tag_range() -> float:
	return level_tag_range_tiles * float(tile_size)


func clamp_level(level: int) -> int:
	return clampi(level, min_level, max_level)


func health_factor(level: int) -> float:
	return _factor(level, health_slope, health_floor)


func torpor_factor(level: int) -> float:
	return _factor(level, torpor_slope, torpor_floor)


func meals_factor(level: int) -> float:
	return _factor(level, meals_slope, meals_floor)


## Carne da carcaça: `base x (1 + 0,03 (L - 10))`, piso 0,7 da base, arredondada, no mínimo 1.
func carcass_meat(base_meat: int, level: int) -> int:
	return maxi(roundi(float(base_meat) * _factor(level, carcass_slope, carcass_floor)), 1)


## Couro da carcaça: o mesmo fator da carne, mas base 0 = espécie sem couro (sem o mínimo de 1).
func carcass_leather(base_leather: int, level: int) -> int:
	if base_leather <= 0:
		return 0
	return maxi(roundi(float(base_leather) * _factor(level, carcass_slope, carcass_floor)), 1)


func max_health(base: float, level: int) -> float:
	return base * health_factor(level)


func damage(base: float, level: int) -> float:
	return base * health_factor(level)


func max_torpor(base: float, level: int) -> float:
	return base * torpor_factor(level)


## `ceil(base x dificuldade x fator)`, no mínimo 1.
func meals_required(base_meals: int, difficulty: float, level: int) -> int:
	var raw := float(base_meals) * difficulty * meals_factor(level)
	return maxi(ceili(raw - _EPSILON), 1)


## Nível ao fim da domesticação: bônus linear de 0 a `taming_bonus` pela Eficiência
## (0 a 100), arredondado ao mais próximo com meio para cima (com tolerância para o erro
## de ponto flutuante, ex.: 50 x 1,13 = 56,5 vira 57), limitado por `taming_cap`.
## Função pura: o teto do mundo (`max_level`) é aplicado por quem a usa (`clamp_level`).
## Com 0% de Eficiência devolve o próprio nível.
func final_level(level: int, efficiency: float) -> int:
	var ratio := clampf(efficiency, 0.0, 100.0) / 100.0
	var boosted := floori(level * (1.0 + taming_bonus * ratio) + 0.5 + _EPSILON)
	var cap := floori(taming_cap * level + 0.5 + _EPSILON)
	return maxi(mini(boosted, cap), level)


func _factor(level: int, slope: float, floor_value: float) -> float:
	return maxf(1.0 + slope * float(level - base_level), floor_value)
