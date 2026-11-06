# SPDX-License-Identifier: MIT
class_name RespawnRules
extends Resource
## Números do respawn do jogador (GDD 12.2 e 12.4), só dados. Valores em
## `res://data/balance/respawn_rules.tres` (os padrões abaixo só valem para um recurso novo e vazio).
## Quem usa: `Main`, `Player` e `DeathScreen`.
##
## Desvio do GDD 12.2, regra 4 ("proteção de 3 s, invulnerável, SEM ATACAR"): a proteção aqui só torna
## o jogador invulnerável; ele pode atacar e colher durante ela. Fica para o playtest decidir.

## Regiões oferecidas na tela de morte, na ordem em que aparecem. A primeira vem pré-selecionada.
@export var regions: Array[RespawnRegion] = []
## Ponto usado quando `regions` está vazia: a tela de morte nunca fica sem opção (GDD 12.2).
@export var default_fallback_point: Vector2 = Vector2(160, 300)
## Atraso, em segundos, antes de a tela de morte aceitar uma escolha: o Espaço do ataque também é
## `ui_accept`, e quem morre apertando-o não pode renascer sem ver a tela.
@export_range(0.0, 5.0) var accept_delay: float = 0.6
## Lado do tile do mapa, em pixels (o ponto sorteado é o centro de um tile).
@export_range(4, 64) var tile_size: int = 16
## Sorteios antes de usar o ponto reserva da região [proposta, GDD 12.2].
@export_range(1, 200) var max_attempts: int = 30
## Distância mínima de dino selvagem ao ponto sorteado, em pixels (8 tiles) [proposta]. Ainda não
## há classe de agressividade nos dados do dino: vale para todo selvagem.
@export_range(0.0, 1000.0) var min_distance_from_wild: float = 128.0
## Distância mínima de um nó de recurso ao ponto sorteado, em pixels.
@export_range(0.0, 200.0) var min_distance_from_resource: float = 24.0
## Raio livre de colisão exigido em volta do ponto, em pixels.
@export_range(1.0, 32.0) var clearance_radius: float = 8.0
## Proteção depois de renascer, em segundos (GDD 12.4).
@export_range(0.0, 30.0) var protection_seconds: float = 3.0
## Vida e fome ao renascer, como fração do máximo (GDD 12.4: vida 100%, fome 50%).
@export_range(0.01, 1.0) var health_ratio: float = 1.0
@export_range(0.0, 1.0) var hunger_ratio: float = 0.5


## Regiões oferecidas: as dos dados (sem nulos) ou, se não houver nenhuma, uma região única de
## emergência no `default_fallback_point`. Nunca vazia.
func available_regions() -> Array[RespawnRegion]:
	var list: Array[RespawnRegion] = []
	for region: RespawnRegion in regions:
		if region != null:
			list.append(region)
	if list.is_empty():
		var emergency := RespawnRegion.new()
		emergency.id = "inicio"
		emergency.display_name = "Início"
		emergency.fallback_point = default_fallback_point
		list.append(emergency)
	return list


## Região pelo id; null se não existe.
func region_by_id(region_id: String) -> RespawnRegion:
	for region in available_regions():
		if region.id == region_id:
			return region
	return null


## Ids na ordem da lista.
func region_ids() -> Array[String]:
	var ids: Array[String] = []
	for region in available_regions():
		ids.append(region.id)
	return ids
