# SPDX-License-Identifier: MIT
class_name ResourceNodeComponent
extends Node
## Estado de um nó de recurso (MUN-02): cheio ou esgotado, e QUANDO volta (`due_at`, instante do relógio do mundo,
## ADR-006: nunca um contador que desconta `delta`). Lógica pura,
## sem desenho nem física. `harvest()` é a única porta de saída do recurso; quem pede a coleta
## (o jogador, via `Player.request_gather`) valida alcance e espaço antes.

## Mudou entre cheio e esgotado (a apresentação e a dica reagem).
signal changed

## Um golpe acertou o nó (a apresentação treme, solta lascas e troca o estágio de dano): vida que sobrou e vida máxima.
## `by_hand`: o golpe foi de mão (sem a ferramenta do nó), para o som.
signal damaged(health: float, health_max: float, by_hand: bool)

## O último golpe derrubou o nó (a apresentação o faz cair antes de sumir). Sai antes de `changed`.
signal felled

## A mão bateu no nó e não tirou nada (rocha sem ferramenta): só o som e o tremor.
signal rebuffed

## Intervalo entre as tentativas de voltar quando o lugar está ocupado.
const RETRY_SECONDS := 0.5

@export var def: ResourceNodeDef

var depleted: bool = false
## Instante (relógio do mundo) em que o nó esgotado volta; decidido na colheita, com `respawn_total()` de então.
var due_at: float = 0.0
## Leitor do relógio do mundo, `() -> float` (injetado pelo campo; `WorldAuthority.clock.now`). Sem ele, o tempo é 0.
var clock: Callable = Callable()
## Tempo de volta próprio deste nó (a pedra avulsa do núcleo volta mais cedo). 0 = o do tipo.
var respawn_override: float = 0.0
## Regras do servidor (ADR-004): multiplica o que a colheita entrega e acelera a volta do nó (2 = volta em metade do
## tempo). 1,0 é a identidade. O mundo define ao criar o nó; nunca muda na sessão.
var yield_multiplier: float = 1.0
var respawn_rate: float = 1.0
## O que sobrou no nó numa colheita parcial (item -> unidades): o inventário não coube tudo e "o que sobra
## fica no arbusto" (mapa-ilha.md 8). Vazio = nó inteiro. Nó parcial segue disponível e vai ao save.
var leftover: Dictionary = {}
## O lugar está livre para o nó voltar? (sem regra, sempre). Ocupado: o nó fica esgotado, esperando, e tenta de
## novo a cada `RETRY_SECONDS`; esperar não conta como perdido e o nó segue no save como esgotado.
var can_return: Callable = Callable()

## Vida já perdida em golpes (nó de vários golpes). Volta a zero sozinho, `def.hit_reset_seconds` depois do último
## golpe: a vida volta ao máximo.
var damage_taken: float = 0.0
var _damage_expire_at: float = 0.0
## Próxima tentativa de voltar com o lugar ocupado (instante do relógio; não vai ao save).
var _retry_at: float = 0.0


## O relógio do mundo agora.
func now() -> float:
	return float(clock.call()) if clock.is_valid() else 0.0


## Quem acorda o nó é o `ResourceField` (só os esgotados, só quando o prazo vence): esgotado que chegou a `due_at`
## volta cheio, se o lugar estiver livre. Só compara instantes: não há `_physics_process` aqui.
func tick() -> void:
	if not depleted or def == null:
		return
	var current := now()
	if current < due_at or current < _retry_at:
		return
	_retry_at = current + RETRY_SECONDS
	if can_return.is_valid() and not bool(can_return.call()):
		return  # lugar ocupado: espera e tenta de novo
	depleted = false
	due_at = 0.0
	changed.emit()


## Quando vale olhar este nó de novo (o prazo, ou a próxima tentativa se o lugar estava ocupado).
func next_check_at() -> float:
	return maxf(due_at, _retry_at)


## Esgotado, com o prazo de volta já vencido, esperando o lugar ficar livre?
func is_waiting() -> bool:
	return depleted and now() >= due_at


## Segundos até um nó esgotado voltar: o do próprio nó ou, sem ele, o do tipo.
func respawn_total() -> float:
	var base := respawn_override if respawn_override > 0.0 else (def.respawn_seconds if def != null else 0.0)
	return base / maxf(respawn_rate, 0.001)


## Dano acumulado agora (já descontado o prazo sem golpes).
func current_damage() -> float:
	if damage_taken > 0.0 and now() >= _damage_expire_at:
		damage_taken = 0.0
	return damage_taken


func has_damage() -> bool:
	return current_damage() > 0.0


func _max_health() -> float:
	return def.health_max if def != null else 0.0


## Vida que o nó tem agora.
func current_health() -> float:
	return maxf(_max_health() - current_damage(), 0.0)


## Fração de vida (1 = inteiro, 0 = caiu). Nó de um toque é sempre 1.
func health_fraction() -> float:
	var maximum := _max_health()
	return current_health() / maximum if maximum > 0.0 else 1.0


## Estágio visual de dano: 0 = inteiro, 1 e 2 conforme `def.damage_stage_thresholds` (fração de vida <= limite).
func damage_stage() -> int:
	if def == null:
		return 0
	var fraction := health_fraction()
	var stage := 0
	for limit: float in def.damage_stage_thresholds:
		if fraction <= limit:
			stage += 1
	return stage


## Um golpe `amount` aceito (> 0) tira vida (nunca abaixo de zero) e devolve a que sobrou.
func register_damage(amount: float, by_hand: bool = false) -> float:
	var maximum := _max_health()
	damage_taken = minf(current_damage() + maxf(amount, 0.0), maximum)
	_damage_expire_at = now() + (def.hit_reset_seconds if def != null else 0.0)
	damaged.emit(current_health(), maximum, by_hand)
	return current_health()


## A mão bateu sem efeito (a apresentação reage).
func rebuff() -> void:
	rebuffed.emit()


func is_available() -> bool:
	return def != null and not depleted


func is_partial() -> bool:
	return not leftover.is_empty()


## O que a próxima colheita entrega: o que sobrou, ou tudo se o nó está inteiro.
func pending_yields() -> Dictionary:
	if def == null or depleted:
		return {}
	return leftover.duplicate() if is_partial() else full_yields()


## A colheita inteira deste nó (item -> unidades), já com o multiplicador do servidor: `maxi(1, roundi(x mult))`.
func full_yields() -> Dictionary:
	var scaled: Dictionary = {}
	if def == null:
		return scaled
	var base := def.total_yields()
	for item_id: String in base:
		scaled[item_id] = maxi(1, roundi(float(base[item_id]) * yield_multiplier))
	return scaled


## Colheita parcial: o que não coube continua no nó, que não esgota nem começa a contar tempo.
func leave(remaining: Dictionary) -> void:
	if not is_available():
		return
	leftover = remaining.duplicate()


## Colhe o nó: devolve as unidades entregues (0 se já estava esgotado) e começa o tempo de volta.
func harvest() -> int:
	if not is_available():
		return 0
	if def.is_struck():
		felled.emit()
	depleted = true
	damage_taken = 0.0
	leftover = {}
	due_at = now() + respawn_total()
	_retry_at = 0.0
	changed.emit()
	return int(full_yields().get(def.item_id, def.yield_amount))


func to_dict() -> Dictionary:
	var data := {"def": def.id if def != null else "", "depleted": depleted, "due_at": due_at}
	if is_partial():
		data["leftover"] = leftover.duplicate()
	if has_damage():
		data["health"] = current_health()
		data["health_left_seconds"] = _damage_expire_at - now()  # relativo: o relógio do mundo é restaurado à parte
	return data


## Restaura sem entregar nada. Dado de outro tipo de nó (o mundo mudou) é ignorado: o nó fica como está.
func from_dict(data: Dictionary) -> void:
	if def == null or SafeRead.text(data.get("def"), "") != def.id:
		return
	depleted = SafeRead.flag(data.get("depleted"), false)
	var current := now()
	# Prazo absoluto: no máximo a duração cheia à frente do relógio já reposto (ADR-006); vencido volta no 1º tick.
	due_at = SafeRead.number(data.get("due_at"), current, 0.0, current + respawn_total()) if depleted else 0.0
	_retry_at = 0.0
	leftover = _read_leftover(data.get("leftover")) if not depleted else {}
	damage_taken = 0.0
	if not depleted and def.is_struck() and data.has("health"):
		# Save antigo (contava golpes) não tem "health": a vida fica cheia. Dado de fora fica entre 0 e o máximo.
		var saved_health := SafeRead.number(data.get("health"), def.health_max, 0.0, def.health_max)
		damage_taken = clampf(def.health_max - saved_health, 0.0, def.health_max)
		_damage_expire_at = current + SafeRead.number(data.get("health_left_seconds"), 0.0, 0.0, def.hit_reset_seconds)
	changed.emit()


## Só itens que a colheita do tipo entrega e no máximo a quantidade dela (dado de fora não é confiável).
func _read_leftover(raw: Variant) -> Dictionary:
	var kept: Dictionary = {}
	var all := full_yields()
	var source := SafeRead.dict(raw)
	for item_id: Variant in source:
		var key := str(item_id)
		if all.has(key):
			var amount := clampi(SafeRead.integer(source[item_id], 0, 0, 1 << 20), 0, all[key])
			if amount > 0:
				kept[key] = amount
	return kept
