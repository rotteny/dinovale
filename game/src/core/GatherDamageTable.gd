# SPDX-License-Identifier: MIT
class_name GatherDamageTable
extends Resource
## Tabela do dano de coleta (decisão do dono, 08/11): quanto cada FERRAMENTA tira da vida de um nó, por MATERIAL.
## Dado puro em `res://data/balance/gather_damage.tres`. `""` é a mão. Ferramenta fora da linha do material cai no
## dano da mão (Lança na rocha: 0 como a mão). Regra do dono: ferramenta sempre dá MAIS que a mão onde a mão causa
## dano; a certa para o material (Machado na madeira, Picareta na pedra e no minério) é a que dá mais.

## material -> {id da ferramenta (ou "" = mão) -> dano por golpe aceito}. [premissa]
@export var by_material: Dictionary = {}


## Dano por golpe de `tool_id` num nó de `material`. Material desconhecido: 0 (nada o quebra).
func damage(material: String, tool_id: String) -> float:
	var row := by_material.get(material, {}) as Dictionary
	if row.has(tool_id):
		return maxf(float(row[tool_id]), 0.0)
	return maxf(float(row.get("", 0.0)), 0.0)


## Golpes (arredondados para cima) até derrubar um nó de `health_max` com `tool_id`; 0 se a ferramenta não causa dano.
func hits_to_break(material: String, health_max: float, tool_id: String) -> int:
	var each := damage(material, tool_id)
	return ceili(health_max / each) if each > 0.0 else 0


## Materiais e ferramentas que a tabela conhece (para teste e balanceamento).
func materials() -> Array:
	return by_material.keys()
