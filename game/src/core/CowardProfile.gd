# SPDX-License-Identifier: MIT
class_name CowardProfile
extends Resource
## Conduta do Covarde (E13, GDD 6.1b): curioso, deixa o jogador chegar perto, nunca revida e foge ao ser atacado ou quando o
## grupo dá o alarme. Só dados (`res://data/dino/dodo_coward.tres`). Null em `DinoBaseStats.coward` = espécie sem essa conduta.
## A velocidade da fuga é a `chase_speed` da espécie (a mesma que o `DinoFleeState` já usa); a ronda tem número próprio.

@export_group("Curiosidade")
## Vê o jogador a até tantos tiles (elipse da percepção) e vem andar perto dele.
@export_range(1.0, 32.0) var perception_tiles: float = 6.0
## Chega a até tantos tiles do jogador e fica rondando (não encosta).
@export_range(0.5, 16.0) var approach_tiles: float = 3.0
## Velocidade de aproximação e de ronda, em pixels por segundo.
@export_range(1.0, 200.0) var patrol_speed: float = 35.0
## Ronda perto do jogador: cada passeio lateral dura tanto, em segundos (mínimo, máximo), com pausa de igual faixa.
@export var patrol_seconds: Vector2 = Vector2(0.6, 1.5)
@export_group("Fuga")
## Parado de susto antes de correr.
@export_range(0.0, 5.0) var scare_seconds: float = 0.8
## A fuga acaba ao percorrer tantos tiles ou depois de tantos segundos (o que vier primeiro), contados do fim do susto.
@export_range(1.0, 64.0) var flee_max_tiles: float = 16.0
@export_range(1.0, 60.0) var flee_max_seconds: float = 10.0
## Depois da fuga, tantos segundos sem voltar a se aproximar de ninguém (o grupo volta a pastar).
@export_range(0.0, 120.0) var wary_seconds: float = 10.0
@export_group("Alarme do grupo")
## O membro do mesmo bando a até tantos tiles do atingido foge junto, depois do atraso.
@export_range(1.0, 32.0) var alarm_radius_tiles: float = 8.0
@export_range(0.0, 5.0) var alarm_delay_s: float = 0.5


func perception_px(tile_px: float) -> float:
	return perception_tiles * tile_px


func approach_px(tile_px: float) -> float:
	return approach_tiles * tile_px


func flee_max_px(tile_px: float) -> float:
	return flee_max_tiles * tile_px


func alarm_radius_px(tile_px: float) -> float:
	return alarm_radius_tiles * tile_px
