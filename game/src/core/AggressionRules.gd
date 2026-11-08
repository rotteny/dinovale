# SPDX-License-Identifier: MIT
class_name AggressionRules
extends Resource
## Números do estado de agressão (M1, `m1-ameaca-e-corpo.md` seção 2), só dados. Valores em
## `res://data/balance/aggression_rules.tres`. Quem usa: `DinoAggressiveState` (relógio e atalhos de acalmar),
## `DinoView` e `WildLevelTag` (sinal visual). A velocidade brava é da espécie (`DinoBaseStats.chase_speed`), a
## desistência por distância e tempo do Agressivo também (`chase_give_up_tiles`, `chase_max_seconds`).

@export_group("Acalmar")
## O dino volta ao natural depois de tanto tempo sem dar nem receber dano ("cerca de 8 s"). Sem rancor.
@export_range(1.0, 60.0) var calm_seconds: float = 8.0
## Atalho (decisão provisória D2): o alvo fica a mais de tantos tiles por tanto tempo e o dino se acalma.
@export_range(1.0, 64.0) var far_tiles: float = 12.0
@export_range(0.5, 30.0) var far_seconds: float = 5.0
@export_group("Fuga")
## Passivo com a vida abaixo desta fração do máximo foge do atacante em vez de revidar (GDD 6.7).
@export_range(0.05, 0.9) var flee_health_ratio: float = 0.25
## Só volta ao natural depois de tantos segundos E com o atacante a mais de tantos tiles.
@export_range(1.0, 60.0) var flee_resume_seconds: float = 10.0
@export_range(1.0, 32.0) var flee_resume_tiles: float = 10.0
## Distância, em tiles, do ponto de fuga à frente do dino (longe do atacante), refeito a cada quadro.
@export_range(2.0, 24.0) var flee_goal_tiles: float = 6.0
@export_group("Sinal visual")
## "!" sobre a cabeça enquanto bravo, e a cor de perigo que o "Nv" assume (a mesma do número de dano).
@export var mark_text: String = "!"
@export var mark_color: Color = Color(0.95, 0.15, 0.12)
@export var alert_color: Color = Color(1.0, 0.45, 0.4)
## "!" de quem caça outro dino: laranja, para o jogador não achar que o caçador ocupado vem para ele (vermelho = bravo com você).
@export var hunt_mark_color: Color = Color(1.0, 0.6, 0.1)
## Tempo do fade ao entrar e ao sair do estado, em segundos.
@export_range(0.05, 3.0) var fade_seconds: float = 0.4


func far_px(tile_px: float) -> float:
	return far_tiles * tile_px
