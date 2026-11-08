# SPDX-License-Identifier: MIT
class_name ActionHints
extends RefCounted
## Dicas de contexto curtas para o jogador (texto pt-BR num lugar só): o gesto certo para colher um nó de recurso e o
## que falta quando algo bloqueia. Lógica pura; a HUD só mostra (cinza quando `blocked`).


## `{text, blocked}` da dica de um nó que se colhe por golpes. Só a ação: nada de contagem de golpes (a vida do nó
## aparece no desenho, não em número). `damage` é o dano por golpe do que está em mãos contra o nó; `waiting` é o
## intervalo entre coletas, que pinta a dica de cinza.
static func for_resource(def: ResourceNodeDef, damage: float, waiting: bool = false) -> Dictionary:
	if damage <= 0.0:
		var tool_name := def.tool_name if def.tool_name != "" else "ferramenta"
		return {"text": "Precisa de %s (à mão só machuca, nada cai)" % tool_name, "blocked": true}
	return {"text": "[clique] Golpear %s" % def.display_name.to_lower(), "blocked": waiting}
