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
	"player_woke": {"kind": Kind.WARNING, "text": "Você acordou. Corra!"},
	"player_died": {"kind": Kind.DANGER, "text": "Você morreu. Seus itens ficaram no corpo."},
	"player_level_up": {"kind": Kind.SUCCESS, "text": "Nível {level}: +{saber} Saber"},
	"recipe_learned": {"kind": Kind.SUCCESS, "text": "Aprendeu: {item}"},
	"player_respawned": {"kind": Kind.INFO, "text": "Você renasceu."},
	"corpse_recovered": {"kind": Kind.SUCCESS, "text": "Você recuperou {amount} itens do seu corpo."},
	"corpse_expired": {"kind": Kind.DANGER, "text": "Seu corpo sumiu: {amount} itens se perderam."},
	"tamed_stuck": {"kind": Kind.WARNING, "text": "{species} ficou preso."},
	"dino_hit_player": {"kind": Kind.WARNING, "text": "{species} te acertou: -{amount} de vida."},
	"tamed_attacked": {"kind": Kind.WARNING, "text": "{prey} está sendo atacado por {species}."},
	"tamed_killed": {"kind": Kind.DANGER, "text": "{prey} foi morto por {species}."},
	"taming_attacked": {"kind": Kind.WARNING, "text": "{name} está sendo atacado enquanto dorme."},
	"taming_killed": {"kind": Kind.DANGER, "text": "A doma de {name} falhou: {species} o matou."},
	"order_given": {"kind": Kind.INFO, "text": "{species}: {order}."},
	"craft_started": {"kind": Kind.INFO, "text": "Fabricando {item}..."},
	"craft_done": {"kind": Kind.SUCCESS, "text": "{item} pronto."},
	"craft_cancelled": {"kind": Kind.WARNING, "text": "Fabricação de {item} cancelada."},
	"item_placed": {"kind": Kind.INFO, "text": "{item} colocada."},
	"piece_built": {"kind": Kind.INFO, "text": "{piece} construída."},
	"piece_removed": {"kind": Kind.INFO, "text": "{piece} removida."},
	"door_toggled": {"kind": Kind.INFO, "text": "{piece}: {state}."},
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
	"unknown_recipe": "Receita desconhecida.",
	"recipe_locked": "Você ainda não aprendeu essa receita (tecla P).",
	"recipe_not_learnable": "Essa receita você já conhece de início.",
	"recipe_already_learned": "Você já aprendeu essa receita.",
	"no_saber": "Saber insuficiente.",
	"already_crafting": "Você já está fabricando algo.",
	"no_workbench": "Chegue perto de uma Bancada.",
	"missing_materials": "Faltam materiais.",
	"no_item": "Você não tem esse item.",
	"cannot_place": "Não dá para colocar isso aqui.",
	"bad_terrain": "O terreno não serve.",
	"occupied": "Já tem algo nesse lugar.",
	"safe_core": "Não dá para colocar no refúgio.",
	"place_limit": "Peças demais no mundo.",
	"unknown_piece": "Peça desconhecida.",
	"no_support": "Precisa de uma fundação ao lado.",
	"body_in_way": "Tem alguém no lugar.",
	"no_piece": "Não há peça aí.",
	"no_door": "Isso não é uma porta.",
	"not_yours": "Essa peça é de outro jogador.",
	"has_dependents": "Tire antes as peças apoiadas nela.",
	"chest_not_empty": "Esvazie o baú antes de tirá-lo.",
	"build_in_world": "Isso se constrói no mundo (tecla B).",
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
