# SPDX-License-Identifier: MIT
class_name ThreatProfile
extends Resource
## Ciclo de ameaça e golpe de uma espécie (M1, `m1-ameaca-e-corpo.md` seções 2 a 4), só dados. Valores em
## `res://data/dino/*_threat.tres`; quem os usa é o `ThreatCycle`. Sem perfil na espécie, o bravo só persegue.

@export_group("Ameaça")
## Pausa de ameaça na entrada do episódio (só nela, não a cada investida).
@export_range(0.1, 5.0) var threat_seconds: float = 0.8
## Alvo a mais de tantos tiles: a ameaça é feita CORRENDO em direção a ele, sem parar.
@export_range(0.0, 32.0) var run_threat_tiles: float = 4.0
@export_group("Rodeio")
@export_range(0.5, 16.0) var circle_radius_tiles: float = 2.5
## Sorteio (mín, máx) do tempo de rodeio de cada ciclo, em segundos.
@export var circle_seconds: Vector2 = Vector2(0.5, 1.0)
## Velocidade do rodeio em fração da velocidade brava.
@export_range(0.1, 1.0) var circle_speed_factor: float = 0.6
@export_group("Golpe")
## Aviso parado antes de investir.
@export_range(0.05, 3.0) var windup_s: float = 0.3
## Investida em px/s; 0 = sem arranque próprio, usa a velocidade brava da espécie.
@export_range(0.0, 600.0) var lunge_speed_px_s: float = 0.0
## Tempo máximo da investida; sem contato até aqui, o golpe erra e a recarga corre inteira.
@export_range(0.05, 3.0) var lunge_max_s: float = 0.5
## Alcance do golpe, em pixels (distância efetiva centro a centro).
@export_range(4.0, 128.0) var attack_reach_px: float = 30.0
## Folga que a autoridade dá ao alcance ao conferir as posições reais (o quadro entre o golpe e o pedido).
@export_range(0.0, 16.0) var reach_slack_px: float = 4.0
## Dano ao jogador por golpe. A autoridade o aplica.
@export_range(0.0, 500.0) var damage: float = 8.0
## Recarga entre golpes, contada do golpe.
@export_range(0.1, 30.0) var cooldown_s: float = 1.5
## Pausa depois do golpe antes de voltar a rodear (a recarga ainda pode segurar o próximo).
@export_range(0.0, 3.0) var recover_s: float = 0.3
## Empurrão do golpe, em pixels (sem uso até a etapa 5).
@export_range(0.0, 128.0) var knockback_px: float = 0.0
## Ataca quem já caiu (decisão: a morte vem de dino sobre o caído).
@export var attacks_downed: bool = true
@export_group("Apresentação")
## Animações da folha (`<espécie>.json`) e sons do `SfxBank` de cada fase.
@export var threat_animation: StringName = &"threat"
@export var strike_animation: StringName = &"bite"
@export var threat_sound: StringName = &"raptor_rosnado"
@export var strike_sound: StringName = &"raptor_mordida"
@export_group("")


func circle_radius_px(tile_px: float) -> float:
	return circle_radius_tiles * tile_px
