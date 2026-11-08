# SPDX-License-Identifier: MIT
class_name ActionHints
extends RefCounted
## Dicas de contexto curtas para o jogador (texto pt-BR num lugar só): o gesto certo para colher um nó de recurso e o
## que falta quando algo bloqueia. Lógica pura; a HUD só mostra (cinza quando `blocked`).


## `{text, blocked}` da dica de um nó que se colhe por golpes. `hits` são os golpes que o nó já levou.
static func for_resource(def: ResourceNodeDef, tool_in_hand: bool, hits: int) -> Dictionary:
	var name := def.display_name.to_lower()
	if def.tool_required and not tool_in_hand:
		var tool_name := def.tool_name if def.tool_name != "" else "ferramenta"
		return {"text": "Precisa de %s (à mão só machuca, nada cai)" % tool_name, "blocked": true}
	var needed := def.hits_needed(tool_in_hand)
	if needed <= 1:
		return {"text": "E para %s" % def.prompt, "blocked": false}
	var progress := " %d/%d" % [hits, needed] if hits > 0 else ""
	if tool_in_hand:
		return {"text": "[clique] Golpear %s (%s: %d golpes)%s" % [name, def.tool_name, needed, progress], "blocked": false}
	return {"text": "[clique] Golpear %s (à mão: %d golpes, dói)%s" % [name, needed, progress], "blocked": false}
