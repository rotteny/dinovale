# SPDX-License-Identifier: MIT
class_name ResourceNodeDef
extends Resource
## Um tipo de nó de recurso (MUN-02): o que dá, quanto, quanto custa colher, quando volta, como se desenha
## e onde colide. Só dados em `res://data/resources/`. Números marcados [premissa] saem do GDD e são para
## testar jogando.

## Id estável em string (vai para o save).
@export var id: String = ""
@export var display_name: String = ""
## Item que o nó entrega (`Items`).
@export var item_id: String = ""
## Unidades entregues por coleta.
@export_range(1, 100) var yield_amount: int = 1
## Itens a mais entregues na MESMA colheita (o arbusto dá a fruta e a fibra): id do item -> unidades.
@export var extra_yields: Dictionary[String, int] = {}
## Tempo da ação de colher, em segundos: o jogador fica sem colher outra coisa por este tempo.
@export_range(0.0, 60.0) var gather_seconds: float = 3.0
## Segundos de jogo até o nó esgotado voltar cheio (o relógio só corre com o mundo rodando).
@export_range(1.0, 3600.0) var respawn_seconds: float = 240.0
## Alcance da coleta, em pixels, do jogador ao centro do nó (validado pela autoridade).
@export_range(1.0, 200.0) var reach: float = 32.0
## Texto da dica de interação ("E para ...").
@export var prompt: String = "colher"
## Cor do desenho provisório quando não há textura.
@export var color: Color = Color.WHITE
## Ferramenta do nó (id de item na vaga da arma). Em mãos, a colheita é a do Soco. Item ainda inexistente
## no catálogo simplesmente nunca está em mãos.
@export var tool_item_id: String = ""
## Nome da ferramenta para os textos (dica e log); a ferramenta pode ainda não existir como item.
@export var tool_name: String = ""
## A ferramenta é obrigatória: sem ela o toque não coleta nada (a pedra e o minério; GDD 5.9b).
@export var tool_required: bool = false
## Dano ao jogador por colheita completa feita no Soco (a árvore: 1; GDD 5.9b). Zero: colher sem machucar.
@export_range(0.0, 20.0) var hand_self_damage: float = 0.0
## O dano da mão vale POR ITEM entregue (a carcaça: 1 por item; GDD 5.6 e 5.9b), não por colheita completa. O tempo
## de `gather_seconds` também se reparte por item.
@export var hand_damage_per_item: bool = false
## Dano ao jogador por toque quando a ferramenta obrigatória falta (a pedra: 1). O toque não coleta.
@export_range(0.0, 20.0) var touch_self_damage: float = 0.0
## Recarga do toque sem ferramenta, em segundos.
@export_range(0.0, 10.0) var touch_seconds: float = 0.6
## Textura do nó (`res://assets/sprites/recursos/`); o esgotado some, não tem desenho. A origem do nó são os pés: a imagem
## sobe dali, centrada no x. Sem textura, o nó se desenha por `color`.
@export var texture: Texture2D
## Caixa de colisão dos pés, em pixels, apoiada na origem (`Vector2.ZERO` = sem colisão). GDD 4.2: só os pés.
@export var foot_size: Vector2 = Vector2.ZERO
@export var blocks_when_full: bool = true
## [premissa, a SHIRO revisa] Golpes para colher à mão (0 ou 1 = um toque). Decisão do dono (08/11): árvore e rocha
## pedem alguns golpes; arbusto e pedra avulsa seguem de um toque.
@export_range(0, 50) var hits_by_hand: int = 0
## [premissa] Golpes para colher com a ferramenta do nó (`tool_item_id`); 0 ou 1 = um toque.
@export_range(0, 50) var hits_with_tool: int = 0
## [premissa] Segundos sem golpe depois dos quais o progresso do nó volta a zero.
@export_range(1.0, 120.0) var hit_reset_seconds: float = 10.0


## Tudo que a colheita entrega (item -> unidades), o principal primeiro.
func total_yields() -> Dictionary[String, int]:
	var all: Dictionary[String, int] = {item_id: yield_amount}
	for extra_id: String in extra_yields:
		all[extra_id] = all.get(extra_id, 0) + extra_yields[extra_id]
	return all


## O nó pode ser colhido sem a ferramenta (com a mão)?
func hand_can_gather() -> bool:
	return not tool_required


## Golpes que a colheita pede (com ou sem a ferramenta do nó); 1 = um toque só.
func hits_needed(with_tool: bool) -> int:
	return maxi(hits_with_tool if with_tool else hits_by_hand, 1)


## O nó se colhe por vários golpes (de alguma forma)?
func is_struck() -> bool:
	return hits_by_hand > 1 or hits_with_tool > 1
