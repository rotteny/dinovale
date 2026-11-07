# SPDX-License-Identifier: MIT
class_name ResourceNodeComponent
extends Node
## Estado de um nó de recurso (MUN-02): cheio ou esgotado, e quanto falta para voltar. Lógica pura,
## sem desenho nem física. `harvest()` é a única porta de saída do recurso; quem pede a coleta
## (o jogador, via `Player.request_gather`) valida alcance e espaço antes.

## Mudou entre cheio e esgotado (a apresentação e a dica reagem).
signal changed

## Intervalo entre as tentativas de voltar quando o lugar está ocupado.
const RETRY_SECONDS := 0.5

@export var def: ResourceNodeDef

var depleted: bool = false
var respawn_left: float = 0.0
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

var _retry_left: float = 0.0


func _ready() -> void:
	set_physics_process(depleted)  # só o esgotado conta tempo: com centenas de nós cheios, nenhum custo por quadro


func _physics_process(delta: float) -> void:
	tick(delta)


## Faz o tempo de volta correr. Esgotado que chega a zero volta cheio.
func tick(delta: float) -> void:
	if not depleted or def == null:
		return
	if respawn_left > 0.0:
		respawn_left -= delta
		if respawn_left > 0.0:
			return
		respawn_left = 0.0
	_retry_left -= delta
	if _retry_left > 0.0:
		return
	_retry_left = RETRY_SECONDS
	if can_return.is_valid() and not bool(can_return.call()):
		return  # lugar ocupado: espera e tenta de novo
	depleted = false
	set_physics_process(false)
	changed.emit()


## Esgotado, com o tempo de volta já cumprido, esperando o lugar ficar livre?
func is_waiting() -> bool:
	return depleted and respawn_left <= 0.0


## Segundos até um nó esgotado voltar: o do próprio nó ou, sem ele, o do tipo.
func respawn_total() -> float:
	var base := respawn_override if respawn_override > 0.0 else (def.respawn_seconds if def != null else 0.0)
	return base / maxf(respawn_rate, 0.001)


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
	depleted = true
	leftover = {}
	respawn_left = respawn_total()
	_retry_left = 0.0
	set_physics_process(true)
	changed.emit()
	return int(full_yields().get(def.item_id, def.yield_amount))


func to_dict() -> Dictionary:
	var data := {"def": def.id if def != null else "", "depleted": depleted, "respawn_left": respawn_left}
	if is_partial():
		data["leftover"] = leftover.duplicate()
	return data


## Restaura sem entregar nada. Dado de outro tipo de nó (o mundo mudou) é ignorado: o nó fica como está.
func from_dict(data: Dictionary) -> void:
	if def == null or SafeRead.text(data.get("def"), "") != def.id:
		return
	depleted = SafeRead.flag(data.get("depleted"), false)
	respawn_left = SafeRead.number(data.get("respawn_left"), 0.0, 0.0, respawn_total()) if depleted else 0.0
	leftover = _read_leftover(data.get("leftover")) if not depleted else {}
	set_physics_process(depleted)
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
