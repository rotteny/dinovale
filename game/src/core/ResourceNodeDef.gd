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
## Material do nó para a tabela de dano (`GatherDamageTable`): "wood", "stone" ou "ore".
@export var material_id: String = ""
## [premissa] Vida do nó de vários golpes (árvore, rocha, minério); 0 = colhe de um toque. Cada golpe aceito tira o
## dano da ferramenta contra o material (decisão do dono, 08/11). Zerou: o nó cai e solta os itens no chão.
@export_range(0.0, 1000.0) var health_max: float = 0.0
## [premissa] Segundos sem golpe depois dos quais a vida do nó volta ao máximo.
@export_range(1.0, 120.0) var hit_reset_seconds: float = 10.0
## Frações de vida em que o desenho passa ao estágio 1 e ao estágio 2 de dano (fração <= limite). Só a apresentação.
@export var damage_stage_thresholds: PackedFloat32Array = PackedFloat32Array([0.67, 0.34])
## Sobreposições de dano (marcas de corte, rachaduras), uma por estágio, mesmo tamanho e âncora da textura.
@export var damage_overlays: Array[Texture2D] = []
## Cor das lascas que saltam a cada golpe (a do material: madeira, pedra, minério).
@export var chip_color: Color = Color.WHITE


## Tudo que a colheita entrega (item -> unidades), o principal primeiro.
func total_yields() -> Dictionary[String, int]:
	var all: Dictionary[String, int] = {item_id: yield_amount}
	for extra_id: String in extra_yields:
		all[extra_id] = all.get(extra_id, 0) + extra_yields[extra_id]
	return all


## O nó pode ser colhido sem a ferramenta (com a mão)?
func hand_can_gather() -> bool:
	return not tool_required


## O nó se colhe por vida e golpes (e não por um toque)?
func is_struck() -> bool:
	return health_max > 0.0
