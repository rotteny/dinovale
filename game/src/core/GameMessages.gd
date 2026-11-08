# SPDX-License-Identifier: MIT
class_name GameMessages
extends RefCounted
## Texto pt-BR das mensagens do sistema, num lugar só. A autoridade emite eventos com CÓDIGO estável e
## parâmetros (`WorldAuthority.game_event`); a UI traduz o código aqui. Código novo pede texto novo: o teste
## percorre `EVENTS` e `REASONS` e falha se faltar um.

enum Kind { INFO, SUCCESS, WARNING, DANGER }

## Eventos de jogo: código -> {kind, text}. `{nome}` é trocado pelo parâmetro de mesmo nome.
const EVENTS: Dictionary = {
	"taming_meal": {"kind": Kind.INFO, "text": "{species} comeu {item} ({done}/{total})."},
	"taming_lost": {"kind": Kind.WARNING, "text": "{species} acordou: a doma foi perdida."},
	"wrong_food": {"kind": Kind.WARNING, "text": "{species} não come {item} — precisa de {ideal}."},
	"weapon_broke": {"kind": Kind.DANGER, "text": "{item} quebrou."},
	"tame_done": {"kind": Kind.SUCCESS, "text": "{species} foi domado!"},
	"dino_killed": {"kind": Kind.INFO, "text": "{species} morreu."},
	"item_collected": {"kind": Kind.SUCCESS, "text": "+{amount} {item}"},
	"resource_dropped": {"kind": Kind.INFO, "text": "{item} x{amount} caiu no chão."},
	"hands_hurt": {"kind": Kind.WARNING, "text": "-{amount} de vida (sem ferramenta)."},
	"inventory_full": {"kind": Kind.WARNING, "text": "Inventário cheio."},
	"player_downed": {"kind": Kind.DANGER, "text": "Você caiu."},
	"tamed_stuck": {"kind": Kind.WARNING, "text": "{species} ficou preso."},
	"order_given": {"kind": Kind.INFO, "text": "{species}: {order}."},
	"action_refused": {"kind": Kind.WARNING, "text": "{reason}"},
}

## Motivos de recusa (o `reason` de `action_refused`). Cobre todo `Enums.ActionResult` negado e os motivos de regra.
const REASONS: Dictionary = {
	"unknown_actor": "Você não está no mundo.",
	"actor_dead": "Você está caído.",
	"unknown_target": "Não há nada aí.",
	"invalid_target": "Isso não serve de alvo.",
	"invalid_argument": "Pedido inválido.",
	"out_of_range": "Fora de alcance.",
	"behind": "O alvo está atrás de você.",
	"cooldown": "Em recarga.",
	"gather_interval": "Espere um pouco para coletar de novo.",
	"wrong_state": "Agora não dá.",
	"not_owner": "Esse dino não é seu.",
	"refused": "Não deu.",
	"inventory_full": "Inventário cheio.",
	"weight_limit": "Peso no limite.",
	"needs_tool": "Precisa de {tool}.",
	"depleted": "Já foi colhido.",
	"no_space": "Sem espaço no destino.",
	"wrong_slot": "Isso não vai nessa vaga.",
	"already_ordered": "Já está assim.",
	"not_hungry": "Você não está com fome.",
	"nothing_to_use": "Nada para usar aí.",
	"not_food": "Isso não é comida.",
}

## Motivo padrão de cada resultado negado da autoridade.
const RESULT_REASONS: Dictionary = {
	Enums.ActionResult.UNKNOWN_ACTOR: "unknown_actor",
	Enums.ActionResult.ACTOR_DEAD: "actor_dead",
	Enums.ActionResult.UNKNOWN_TARGET: "unknown_target",
	Enums.ActionResult.INVALID_TARGET: "invalid_target",
	Enums.ActionResult.INVALID_ARGUMENT: "invalid_argument",
	Enums.ActionResult.OUT_OF_RANGE: "out_of_range",
	Enums.ActionResult.COOLDOWN: "cooldown",
	Enums.ActionResult.WRONG_STATE: "wrong_state",
	Enums.ActionResult.NOT_OWNER: "not_owner",
	Enums.ActionResult.REFUSED: "refused",
}


static func reason_for(result: Enums.ActionResult) -> String:
	return str(RESULT_REASONS.get(result, "refused"))


## Texto do motivo com os parâmetros (`tool`...). Motivo desconhecido cai em "Não deu.".
static func reason_text(reason: String, params: Dictionary = {}) -> String:
	return _fill(str(REASONS.get(reason, REASONS["refused"])), params)


## Texto de um evento. `action_refused` usa `params.reason`. Código desconhecido devolve "".
static func text_of(code: String, params: Dictionary = {}) -> String:
	if not EVENTS.has(code):
		return ""
	if code == "action_refused":
		return reason_text(str(params.get("reason", "refused")), params)
	return _fill(str(EVENTS[code]["text"]), params)


static func kind_of(code: String) -> Kind:
	return EVENTS[code]["kind"] as Kind if EVENTS.has(code) else Kind.INFO


static func _fill(template: String, params: Dictionary) -> String:
	var text := template
	for key: Variant in params:
		text = text.replace("{%s}" % str(key), str(params[key]))
	return text
