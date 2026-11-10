# SPDX-License-Identifier: MIT
class_name PieceDef
extends Resource
## Peça de construção (E8a, CON-02): dado puro, em `res://data/build/`. Diz como a peça se comporta na grade (bloqueia o
## corpo, precisa de apoio, dá apoio, abre e fecha) e de onde sai o custo: das entradas de uma receita
## (`recipe_id`, que também exige a receita aprendida) ou de 1 item pronto (`item_id`, caso da Bancada). Os números de
## custo ficam na receita; aqui só a forma. Ids são strings estáveis (o save os leva).

@export var id: String = ""
@export var display_name: String = ""
## Receita que paga a peça (material = entradas dela) e que o jogador precisa conhecer. Vazio: custo por `item_id`.
@export var recipe_id: String = ""
## Item pronto gasto (1) para construir; devolvido (1) ao remover. Vazio: o custo vem de `recipe_id`.
@export var item_id: String = ""
## Corpo sólido: bloqueia jogador, dinos e a navegação (a porta aberta deixa de bloquear).
@export var blocks_body: bool = false
## Só se constrói com uma peça de apoio (fundação) por perto (`BuildRules.support_radius`).
@export var needs_support: bool = false
## Serve de apoio para as peças que precisam dele.
@export var gives_support: bool = false
## Abre e fecha (porta).
@export var toggleable: bool = false
## Quantas posições de inventário a peça guarda (Baú). 0 = não guarda nada. O conteúdo vive na `BuildGrid` e vai ao save com a peça.
@export_range(0, 64) var container_slots: int = 0
## Quantas dessas peças o mundo comporta. 0 = só vale o teto geral de peças.
@export_range(0, 100000) var max_count: int = 0
## Quantas dessas peças UM jogador pode ter postas (a Cama: 3; o Saco de dormir: 1). 0 = sem limite por dono.
@export_range(0, 1000) var max_per_owner: int = 0


## Coerente? (id, nome e exatamente uma fonte de custo; porta sem corpo não faz sentido.)
func is_valid() -> bool:
	if id == "" or display_name == "" or (recipe_id == "") == (item_id == ""):
		return false
	return not (toggleable and not blocks_body)
