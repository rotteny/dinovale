# SPDX-License-Identifier: MIT
class_name PlayerRules
extends Resource
## Números do jogador, só dados (AGENTS.md: nada de balanceamento no código). Valores em
## `res://data/balance/player_rules.tres`. Quem usa: `Player`, `StaminaComponent`, `Items`.

## Equipamento inicial SÓ DE DESENVOLVIMENTO (decisão do dono, 08/11): aparece em build de debug (editor, `godot --path game`)
## ou com `--dev`; na exportação release o jogador começa sem eles. A fabricação (receita, Fogueira) é do M3.
@export var dev_starting_equipment: Array[String] = []


## Queda de saciedade por segundo do JOGADOR, conforme o estado de movimento que a autoridade validou
## (decisão do dono, 08/11) [premissa, a SHIRO revisa]: parado 0,04/s (~42 min de cheio a zero), andando 0,06/s
## (~28 min), correndo 0,15/s (~11 min). Os 0,1/s do GDD são do dino domado e ficam nos dados dele.
@export var hunger_decay_idle: float = 0.04
@export var hunger_decay_walk: float = 0.06
@export var hunger_decay_run: float = 0.15
## [premissa] Custo extra de saciedade por ação aceita pela autoridade, somado à taxa: golpe de coleta e golpe de ataque.
@export var hunger_cost_gather_strike: float = 0.3
@export var hunger_cost_attack: float = 0.4
## Com a saciedade nesta fração do máximo (ou menos) a HUD avisa de fome, antes de o dano começar
## (premissa: 25%).
@export_range(0.01, 1.0) var hunger_warning_ratio: float = 0.25
## Recarga, em segundos, depois de comer (GDD 5.2, premissa).
@export var food_cooldown: float = 0.5
## Recarga, em segundos, da troca de equipamento pela tecla (GDD 5.2, premissa).
@export var equip_cooldown: float = 0.3
## Abaixo desta fração do máximo de stamina o jogador está ofegante (GDD 5.7).
@export_range(0.01, 1.0) var winded_ratio: float = 0.25
## Caixa de colisão do corpo do jogador, em pixels (largura, altura). O corpo a lê ao nascer.
## Só os pés colidem (GDD 4.2): 12x8, o `colisao_pes` do `jogador.json`; cabeça e tronco passam por
## cima de quem está atrás, pela ordem de profundidade.
@export var hitbox_size: Vector2 = Vector2(12.0, 8.0)
## Centro da caixa em relação à origem do corpo (os pés, onde a caixa fica apoiada): metade da altura, para cima.
@export var hitbox_offset: Vector2 = Vector2(0.0, -4.0)
## Vida abaixo da qual o dano que o jogador causa a si mesmo (Soco, GDD 5.9b) não passa: o Soco não mata.
@export_range(0.0, 100.0) var hand_damage_floor: float = 10.0
## Saciedade devolvida por 1 unidade, por id de item (decisão do dono, 08/11): só a baga e a carne crua são comida do
## jogador. Outro item (a samambaia é de dino) não é comida: recusa com "Isso não é comida". Valores [premissa].
## A saciedade sobe aos poucos (`hunger_recovery_per_second`), não de uma vez.
## Pontos de saciedade que sobem por segundo enquanto há "fome pendente" (comer de novo soma na fila, sem acelerar).
## [premissa] 4/s: a baga (+10) leva 2,5 s e a carne (+30), 7,5 s.
@export_range(0.5, 50.0) var hunger_recovery_per_second: float = 4.0
@export var hunger_restore: Dictionary[String, float] = {}


## Hora de avisar de fome? Vale também com a saciedade zerada.
func is_hungry(current: float, maximum: float) -> bool:
	return maximum > 0.0 and current <= maximum * hunger_warning_ratio


func hunger_restore_of(item_id: String) -> float:
	return maxf(hunger_restore.get(item_id, 0.0), 0.0)


## Os itens de desenvolvimento valem? Build de debug ou o argumento `--dev`. Puro, para testar sem depender do binário.
static func dev_items_allowed(debug_build: bool, args: PackedStringArray) -> bool:
	return debug_build or args.has("--dev")
