class_name InventoryComponent
extends Node
## Inventário em slots com pilhas (id do item + quantidade).
##
## Invariantes: item nunca some nem duplica. `add` devolve quanto NÃO coube;
## `remove` devolve quanto foi retirado; `transfer` só move o que o destino comporta.
## Ids desconhecidos (fora de `Items`) são rejeitados.

## Emitido uma vez por operação que alterou o conteúdo (também em `from_dict`,
## para a UI redesenhar; não é um evento de jogo).
signal changed

const MAX_CAPACITY := 64
const MAX_STACK := 9999

## Quantidade de slots. Reduzir nunca descarta itens: só corta slots vazios do fim.
@export_range(1, 64) var capacity: int = 8:
	set(value):
		capacity = _fit_slots(clampi(value, 1, MAX_CAPACITY))
## Teto de pilha deste inventário (vale o menor entre este e o do item).
@export_range(1, 9999) var max_stack: int = 99:
	set(value):
		max_stack = clampi(value, 1, MAX_STACK)

## Slot vazio é `{}`; ocupado é `{"id": String, "count": int}`.
var _slots: Array[Dictionary] = []


func _init() -> void:
	_fit_slots(capacity)


func slot_count() -> int:
	return _slots.size()


## Cópia do slot (a UI não pode alterar o estado por aqui). `{}` se vazio ou fora do intervalo.
func get_slot(index: int) -> Dictionary:
	if index < 0 or index >= _slots.size():
		return {}
	return _slots[index].duplicate()


func is_empty() -> bool:
	for slot in _slots:
		if not slot.is_empty():
			return false
	return true


func count(item_id: String) -> int:
	var total := 0
	for slot in _slots:
		if slot.get("id", "") == item_id:
			total += int(slot["count"])
	return total


func stack_limit(item_id: String) -> int:
	return mini(max_stack, Items.max_stack(item_id))


## Quanto ainda cabe deste item.
func room_for(item_id: String) -> int:
	var limit := stack_limit(item_id)
	if limit <= 0:
		return 0
	var room := 0
	for slot in _slots:
		if slot.is_empty():
			room += limit
		elif slot["id"] == item_id:
			room += maxi(limit - int(slot["count"]), 0)
	return room


## Adiciona e devolve quanto NÃO coube (0 = tudo guardado).
func add(item_id: String, amount: int) -> int:
	if amount <= 0:
		return 0
	var limit := stack_limit(item_id)
	if limit <= 0:
		return amount
	var left := amount
	for slot in _slots:
		if left > 0 and not slot.is_empty() and slot["id"] == item_id:
			var moved := mini(left, limit - int(slot["count"]))
			if moved > 0:
				slot["count"] = int(slot["count"]) + moved
				left -= moved
	for i in _slots.size():
		if left > 0 and _slots[i].is_empty():
			var moved := mini(left, limit)
			_slots[i] = {"id": item_id, "count": moved}
			left -= moved
	if left != amount:
		changed.emit()
	return left


## Retira até `amount` (do fim para o começo) e devolve quanto saiu de fato.
func remove(item_id: String, amount: int) -> int:
	if amount <= 0:
		return 0
	var left := amount
	for i in range(_slots.size() - 1, -1, -1):
		var slot := _slots[i]
		if left > 0 and not slot.is_empty() and slot["id"] == item_id:
			var taken := mini(left, int(slot["count"]))
			slot["count"] = int(slot["count"]) - taken
			left -= taken
			if slot["count"] <= 0:
				_slots[i] = {}
	if left != amount:
		changed.emit()
	return amount - left


## Move até `amount` para `destination`, só o que couber. Devolve quanto moveu.
## A conta é feita antes de mexer: nada é retirado sem ter onde ficar.
func transfer(destination: InventoryComponent, item_id: String, amount: int) -> int:
	if destination == null or destination == self or amount <= 0:
		return 0
	var moving := mini(mini(amount, count(item_id)), destination.room_for(item_id))
	if moving <= 0:
		return 0
	var taken := remove(item_id, moving)
	var left := destination.add(item_id, taken)
	assert(left == 0, "transfer: destino tinha espaço calculado")
	return taken - left


## Move o conteúdo inteiro do slot (o que couber). Devolve quanto moveu.
func transfer_slot(index: int, destination: InventoryComponent) -> int:
	var slot := get_slot(index)
	if slot.is_empty():
		return 0
	return transfer(destination, slot["id"], int(slot["count"]))


func to_dict() -> Dictionary:
	var slots: Array = []
	for slot in _slots:
		slots.append(slot.duplicate())
	return {"slots": slots}


## Restaura sem disparar evento de jogo. Save e RPC são dados não confiáveis:
## ids desconhecidos, contagens inválidas e slots além da capacidade são descartados,
## e a contagem é limitada à pilha. A capacidade vem da cena, não do save.
func from_dict(data: Dictionary) -> void:
	for i in _slots.size():
		_slots[i] = {}
	var saved: Variant = data.get("slots", [])
	if saved is Array:
		for i in mini(saved.size(), _slots.size()):
			_slots[i] = _sanitize(saved[i])
	changed.emit()


func _sanitize(entry: Variant) -> Dictionary:
	if not entry is Dictionary:
		return {}
	var item_id: Variant = entry.get("id")
	var raw: Variant = entry.get("count")
	if not item_id is String or not Items.has(item_id):
		return {}
	if not (raw is int or raw is float) or (raw is float and not is_finite(raw)):
		return {}
	var amount := clampi(int(clampf(float(raw), 0.0, float(MAX_STACK))), 0, stack_limit(item_id))
	if amount <= 0:
		return {}
	return {"id": item_id, "count": amount}


## Ajusta o número de slots ao pedido sem perder itens; devolve o tamanho real.
## (Não escreve em `capacity`: quem chama do setter é que atribui, sem recursão.)
func _fit_slots(wanted: int) -> int:
	while _slots.size() < wanted:
		_slots.append({})
	while _slots.size() > wanted and _slots[_slots.size() - 1].is_empty():
		_slots.pop_back()
	return _slots.size()
