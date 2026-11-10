# gdlint: ignore=max-public-methods
# SPDX-License-Identifier: MIT
class_name InventoryComponent
extends Node
## Inventário em slots (PRO-15, GDD 5.9). Dois formatos de slot:
##   pilha       `{id, count, expira_em}`: empilhável; `expira_em` 0 = não vence;
##   individual  `{id, iid, durab, durab_max}`: arma, ferramenta, armadura; não empilha,
##               conta como 1 e é identificada pelo `iid` (estável ao mover).
## Slot vazio é `{}`.
##
## Cinto (CRI-42): com `belt_size` > 0, as últimas posições de `_slots` são o cinto, FORA da grade: só recebem item
## individual marcado `belt` (ferramenta e arma). A posição é unificada (grade de 0 a `grid_size()-1`, cinto depois): o
## save, o corpo e as telas usam o mesmo índice. Sem cinto (Baú, criatura) o item de cinto vai à grade como qualquer outro.
##
## Invariantes: item nunca some nem duplica. `add` devolve quanto NÃO coube; `remove`
## devolve quanto foi retirado; `transfer` só move o que o destino comporta e leva o item
## inteiro (o individual mantém `iid` e durabilidade). Ids desconhecidos são rejeitados.
## Juntar pilhas com validades diferentes fica com a mais antiga (a regra de 2 min é do PRO-17).

## Emitido uma vez por operação que alterou o conteúdo (também em `from_dict`,
## para a UI redesenhar; não é um evento de jogo).
signal changed

const MAX_CAPACITY := 64
const MAX_BELT := 8
const MAX_STACK := 9999
## Versão do formato dos itens no save. 1 = `{id, count}`; 2 = o formato acima.
const FORMAT_VERSION := 2
const MAX_IID_LENGTH := 32
const MAX_EXPIRY := 1.0e12
## Teto de posições aceito num save: 4x a capacidade máxima. Acima disso é dado hostil e a carga
## é recusada. O custo de cada posição também é limitado (ver `_sanitize`).
const MAX_SAVED_SLOTS := MAX_CAPACITY * 4
## Teto de unidades que UMA carga com excedente (`from_dict_spilling`) expande: nada se corta até aqui; acima disso é dado hostil.
const MAX_SPILL_LOAD_UNITS := 100000
## Espaço de Peso "infinito" (inventário sem limite).
const NO_WEIGHT_LIMIT := 1 << 30

## Quantidade de slots da grade. Reduzir nunca descarta itens: só corta slots vazios do fim da grade.
@export_range(1, 64) var capacity: int = 8:
	set(value):
		capacity = _fit_grid(clampi(value, 1, MAX_CAPACITY))
## Posições do cinto (fora da grade). 0 = sem cinto. Reduzir também só corta posições vazias do fim.
@export_range(0, 8) var belt_size: int = 0:
	set(value):
		belt_size = _fit_belt(clampi(value, 0, MAX_BELT))
## Teto de pilha deste inventário (vale o menor entre este e o do item).
@export_range(1, 9999) var max_stack: int = 99:
	set(value):
		max_stack = clampi(value, 1, MAX_STACK)
## Prefixo dos `iid` criados aqui ("p" jogador, "d" criatura): evita colisão ao transferir.
## Com a autoridade (NET-01) o `iid` passa a ser alocado por ela.
@export var iid_prefix: String = "i"
## Se aceita item individual (equipamento). A criatura não: o item não volta a ser achado
## e some da barra do jogador; então `add`, `add_entry`, `transfer*` e a carga o recusam.
@export var accepts_individual: bool = true
## Peso máximo carregado, em kg (GDD 5.1, PRO-09). 0 = sem limite (o alforje do dino). Passou disso, `room_for`, `add`,
## `add_entry` e as transferências não aceitam mais nada: recusa por Peso, sem sobrar efeito colateral. Carregar um save
## acima do limite é aceito (restaurar não recusa); só impede de pegar mais.
@export_range(0.0, 10000.0) var weight_limit: float = 0.0
## Vagas de equipamento do mesmo dono: o que está vestido ou empunhado pesa (não ocupa slot, mas conta no Peso).
var worn: EquipmentComponent = null


var _slots: Array[Dictionary] = []
## Quantas posições de `_slots` são a grade; o resto é o cinto.
var _grid: int = 0
var _next_iid: int = 1


func _init() -> void:
	_fit_grid(capacity)
	_fit_belt(belt_size)


## Total de posições (grade mais cinto).
func slot_count() -> int:
	return _slots.size()


## Posições da grade (o limite de variedade).
func grid_size() -> int:
	return _grid


## Posições ocupadas da grade (o cinto não conta).
func grid_used() -> int:
	var used := 0
	for i in _grid:
		if not _slots[i].is_empty():
			used += 1
	return used


## Quantas pilhas teriam de sair da grade para ela caber em `size` posições (0 = cabe; só se compacta, nada se perde).
func piles_over(size: int) -> int:
	return maxi(grid_used() - size, 0)


## Muda a grade para `size` posições (a bolsa do jogador, CRI-42 parte 2). Crescer sempre vale. Encolher COMPACTA: as pilhas
## das posições que vão sumir passam para posições livres do começo da grade, e só então o fim é cortado. Se há mais pilhas
## do que posições, recusa e NADA muda: devolve quantas pilhas faltam esvaziar (0 = mudou). O cinto não é tocado.
func resize_grid(size: int) -> int:
	size = clampi(size, 1, MAX_CAPACITY)
	var over := piles_over(size)
	if over > 0:
		return over
	for i in range(_grid - 1, size - 1, -1):
		if _slots[i].is_empty():
			continue
		for j in size:
			if _slots[j].is_empty():
				_slots[j] = _slots[i]
				_slots[i] = {}
				break
	var before := _grid
	capacity = size
	if _grid != before:
		changed.emit()
	return 0


## A posição `index` é do cinto.
func is_belt_index(index: int) -> bool:
	return index >= _grid and index < _slots.size()


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


## Quantidade total do tipo (cada individual conta 1).
func count(item_id: String) -> int:
	var total := 0
	for slot in _slots:
		if slot.get("id", "") == item_id:
			total += _amount(slot)
	return total


## Cópia do item individual com este `iid`, ou `{}`.
func find_iid(iid: String) -> Dictionary:
	var index := _index_of_iid(iid)
	return _slots[index].duplicate() if index >= 0 else {}


func has_iid(iid: String) -> bool:
	return _index_of_iid(iid) >= 0


func stack_limit(item_id: String) -> int:
	return mini(max_stack, Items.max_stack(item_id))


## Peso carregado agora, em gramas inteiras: a grade mais o que está nas vagas de equipamento.
func carried_grams() -> int:
	var total := worn.weight_grams() if worn != null else 0
	for slot in _slots:
		if not slot.is_empty():
			total += Items.weight_grams(str(slot["id"])) * _amount(slot)
	return total


## Peso carregado agora, em kg (para a tela).
func carried_weight() -> float:
	return float(carried_grams()) / 1000.0


## Espaço de Peso que sobra, em gramas (nunca negativo). Sem limite, `NO_WEIGHT_LIMIT`.
func weight_room_grams() -> int:
	if weight_limit <= 0.0:
		return NO_WEIGHT_LIMIT
	return maxi(roundi(weight_limit * 1000.0) - carried_grams(), 0)


## Quantas unidades de `item_id` o Peso ainda deixa entrar (sem limite, `NO_WEIGHT_LIMIT`).
func weight_units_for(item_id: String) -> int:
	var unit := Items.weight_grams(item_id)
	if weight_limit <= 0.0 or unit <= 0:
		return NO_WEIGHT_LIMIT
	return weight_room_grams() / unit


## Por que `item_id` não entra agora: "weight_limit" (o Peso manda e vale mesmo se os slots também estiverem cheios),
## "belt_full" (ferramenta ou arma sem posição no cinto, mesmo com a grade livre), "inventory_full" (sem slot) ou "" (cabe).
func refusal_for(item_id: String) -> String:
	if weight_units_for(item_id) < 1:
		return "weight_limit"
	if room_for(item_id) >= 1:
		return ""
	return "belt_full" if _slots.size() > _grid and Items.belt_of(item_id) else "inventory_full"


## Quanto ainda cabe deste item: o menor entre o espaço dos slots e o do Peso.
func room_for(item_id: String) -> int:
	return mini(_slot_room_for(item_id), weight_units_for(item_id))


func _slot_room_for(item_id: String) -> int:
	var limit := stack_limit(item_id)
	if limit <= 0 or (Items.is_individual(item_id) and not accepts_individual):
		return 0
	var room := 0
	var region := _region_of(item_id)
	for i in range(region.x, region.y):
		var slot := _slots[i]
		if slot.is_empty():
			room += limit
		elif slot["id"] == item_id and not slot.has("iid"):
			room += maxi(limit - int(slot["count"]), 0)
	return room


## Adiciona e devolve quanto NÃO coube (0 = tudo guardado). Individuais nascem novos
## (durabilidade cheia, `iid` novo); pilhas nascem sem validade.
func add(item_id: String, amount: int) -> int:
	if amount <= 0 or stack_limit(item_id) <= 0 or (Items.is_individual(item_id) and not accepts_individual):
		return maxi(amount, 0)
	var allowed := mini(amount, weight_units_for(item_id))  # o Peso corta o que passa do limite
	var left := allowed
	if Items.is_individual(item_id):
		while left > 0 and _put(_new_individual(item_id)):
			left -= 1
	else:
		left = allowed - _put_stack(item_id, allowed, 0.0)
	if left != allowed:
		changed.emit()
	return left + (amount - allowed)


## Guarda um item já existente (vindo de outro inventário), preservando `iid`, durabilidade
## e validade; devolve quanto NÃO coube (0 = tudo; o individual é 0 ou 1). Colisão de `iid`
## com um item daqui gera um novo. Entrada inválida (id desconhecido, contagem 0, individual
## sem `iid`) é recusada inteira. `changed` sai se ao menos parte foi guardada. `check_weight` falso é só para mover item
## entre a grade e as vagas do MESMO dono (equipar, tirar, trocar), que não muda o Peso total.
func add_entry(entry: Dictionary, check_weight: bool = true) -> int:
	var claimed := 1 if entry.has("iid") else maxi(SafeRead.integer(entry.get("count"), 0, 0, MAX_STACK), 0)
	var item_id := SafeRead.text(entry.get("id"), "")
	if claimed <= 0 or not Items.has(item_id) or Items.is_individual(item_id) != entry.has("iid"):
		return claimed
	var allowed := mini(claimed, weight_units_for(item_id)) if check_weight else claimed
	var left := claimed
	if allowed <= 0:
		return claimed
	if entry.has("iid"):
		left = 0 if _put_entry(_clean_individual(item_id, entry)) else 1
	else:
		left = claimed - _put_stack(item_id, allowed, SafeRead.number(entry.get("expira_em"), 0.0, 0.0, MAX_EXPIRY))
	if left != claimed:
		changed.emit()
	return left


## Retira até `amount` unidades da pilha do slot `index` (largar no chão) e devolve quantas saíram. Individual não sai por aqui.
func take_from_slot(index: int, amount: int) -> int:
	var slot := get_slot(index)
	if slot.is_empty() or slot.has("iid") or amount <= 0:
		return 0
	return int(_take_from(index, amount)["count"])


## Posição do item individual com este `iid` na grade, ou -1.
func index_of_iid(iid: String) -> int:
	return _index_of_iid(iid)


## Guarda um individual no slot `index` se ele estiver vago (a troca de equipamento devolve o antigo ao lugar do novo);
## senão no primeiro livre. Devolve se coube.
func put_individual_at(index: int, entry: Dictionary) -> bool:
	var item_id := SafeRead.text(entry.get("id"), "")
	var region := _region_of(item_id)
	if index >= region.x and index < region.y and _slots[index].is_empty() and accepts_individual \
			and Items.is_individual(item_id) and entry.has("iid"):
		var clean := _clean_individual(item_id, entry)
		if not clean.is_empty():
			_slots[index] = clean
			changed.emit()
			return true
	return add_entry(entry, false) == 0


## Retira até `amount` (do fim para o começo) e devolve quanto saiu de fato.
func remove(item_id: String, amount: int) -> int:
	var total := 0
	for entry in _take(item_id, amount):
		total += _amount(entry)
	return total


## Retira o item individual com este `iid` e o devolve (`{}` se não existe).
func remove_iid(iid: String) -> Dictionary:
	var index := _index_of_iid(iid)
	if index < 0:
		return {}
	var entry := _slots[index]
	_slots[index] = {}
	changed.emit()
	return entry


## Move até `amount` para `destination`, só o que couber. Devolve quanto moveu.
## A conta é feita antes de mexer: nada é retirado sem ter onde ficar.
func transfer(destination: InventoryComponent, item_id: String, amount: int) -> int:
	if destination == null or destination == self or amount <= 0:
		return 0
	var moving := mini(mini(amount, count(item_id)), destination.room_for(item_id))
	if moving <= 0:
		return 0
	var moved := 0
	for entry in _take(item_id, moving):
		if destination._put_entry(entry):
			moved += _amount(entry)
		else:
			_put_entry(entry)  # não deveria ocorrer (room_for conferiu): devolve à origem
	if moved > 0:
		destination.changed.emit()
	return moved


## Move o conteúdo do slot `index` (o que couber no destino). Tira DESTE slot, não de
## outro da mesma pilha. Individual: 1 ou nada (o destino pode recusar equipamento).
## `amount` limita a pilha (-1 = todas; individual é sempre 1). Devolve quanto moveu; nada sai sem ter onde ficar.
func transfer_slot(index: int, destination: InventoryComponent, amount: int = -1) -> int:
	var slot := get_slot(index)
	if slot.is_empty() or destination == null or destination == self:
		return 0
	var wanted := 1 if slot.has("iid") else int(slot["count"])
	if amount >= 0 and not slot.has("iid"):
		wanted = mini(wanted, amount)
	var moving := mini(wanted, destination.room_for(slot["id"]))
	if moving <= 0:
		return 0
	var entry := _take_from(index, moving)
	var left := destination.add_entry(entry)
	if left > 0:  # não deveria ocorrer (room_for conferiu): devolve à origem
		entry["count"] = left
		add_entry(entry)
	return moving - left


func to_dict() -> Dictionary:
	var slots: Array = []
	for slot in _slots:
		slots.append(slot.duplicate())
	return {"version": FORMAT_VERSION, "next_iid": _next_iid, "slots": slots}


## Restaura sem disparar evento de jogo. Save e RPC são dados não confiáveis: ids
## desconhecidos e contagens inválidas são descartados. A capacidade vem da cena, não do save.
##
## CONTRATO DO RETORNO (para o SAV-01): `true` = o save foi aplicado por inteiro; `false` =
## RECUSADO e NADA mudou (nem `next_iid`). Quem chama deve tratar `false` como save inválido ou
## incompatível e não seguir com uma carga parcial do resto (por isso `Player` e `Dino` validam
## o inventário antes de tocar em qualquer outro campo: `can_load`). Recusa quando: a versão é
## inválida ou maior que a conhecida; `slots` não é Array (um `{}` não apaga o inventário) ou
## passa de `MAX_SAVED_SLOTS`; ou algum item válido REALMENTE não cabe. Item na posição além
## da capacidade é compactado em slot livre; só se não houver slot livre a carga é recusada
## (nada some calado). Pilha acima do teto é dividida, não cortada.
## Sem versão ou versão 1 (`{id, count}`): equipamento vira N individuais com durabilidade
## cheia se faltar; pilha entra sem validade; `iid` ausente ou repetido é gerado.
func from_dict(data: Dictionary) -> bool:
	return _load(data, false, [])


## Carga de MIGRAÇÃO (save de um inventário maior que o atual): o que não cabe não recusa a carga; vai para `spill`, como
## entradas prontas (`{id, count, expira_em}` ou o individual inteiro), e quem chama decide o destino (o chão, aos pés).
## Nada some: o que entra aqui mais o que sai em `spill` é exatamente o que o save tinha. O resto do contrato é o do
## `from_dict` (`false` = recusado, nada mudou, `spill` intocado).
func from_dict_spilling(data: Dictionary, spill: Array[Dictionary]) -> bool:
	return _load(data, true, spill)


func _load(data: Dictionary, may_spill: bool, spill: Array[Dictionary]) -> bool:
	var saved: Variant = data.get("slots")
	if SafeRead.format_version(data, FORMAT_VERSION) == 0 or typeof(saved) != TYPE_ARRAY or (saved as Array).size() > MAX_SAVED_SLOTS:
		return false
	var old_slots := _slots.duplicate(true)
	var old_next := _next_iid
	for i in _slots.size():
		_slots[i] = {}
	_next_iid = SafeRead.integer(data.get("next_iid"), 1, 1, MAX_STACK * 1000)
	var overflow: Array[Dictionary] = []
	var fits := true
	for i in (saved as Array).size():
		var entries := _sanitize(saved[i], may_spill)
		if entries.is_empty():
			continue
		var region := _region_of(str(entries[0]["id"]))  # a posição do save só vale na região do item (cinto x grade)
		var direct: bool = i >= region.x and i < region.y and _slots[i].is_empty() \
				and (accepts_individual or not entries[0].has("iid"))
		if direct:
			_slots[i] = entries.pop_front()
		overflow.append_array(entries)
	var spilled: Array[Dictionary] = []
	for entry in overflow:
		var rest := _put_entry_partial(entry)
		if rest.is_empty():
			continue
		if may_spill:
			spilled.append(rest)
		else:
			fits = false
	if not fits:
		_slots.assign(old_slots)
		_next_iid = old_next
		return false
	spill.append_array(spilled)
	changed.emit()
	return true


## Cópia vazia com a mesma configuração (capacidade, teto, prefixo, regra de equipamento):
## serve para validar um save SEM tocar neste inventário. Quem chama libera (`free`).
func preview() -> InventoryComponent:
	var copy := InventoryComponent.new()
	copy.capacity = _grid
	copy.belt_size = _slots.size() - _grid
	copy.max_stack = max_stack
	copy.iid_prefix = iid_prefix
	copy.accepts_individual = accepts_individual
	return copy


## Diz se `from_dict(data)` seria aplicado, sem mudar nada (primeira fase da carga em duas fases).
func can_load(data: Dictionary) -> bool:
	var scratch := preview()
	var ok := scratch.from_dict(data)
	scratch.free()
	return ok


## Uma entrada do save vira 0, 1 ou várias entradas válidas (save antigo com equipamento
## em pilha vira N individuais).
## Com `may_spill` (migração) NADA é cortado por falta de lugar: o que não cabe vai ao excedente, então a entrada se expande por
## inteiro (até `MAX_SPILL_LOAD_UNITS`, contra dado hostil). Sem ele, o que passa de slots + 1 nunca caberia (a carga é recusada),
## então não se faz trabalho inútil.
func _sanitize(entry: Variant, may_spill: bool = false) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not entry is Dictionary:
		return result
	var item_id := SafeRead.text(entry.get("id"), "")
	if not Items.has(item_id):
		return result
	if Items.is_individual(item_id):
		var wanted := 1
		if not entry.has("iid") and entry.has("count"):
			# Sem excedente, mais que os slots mais um nunca cabe: o excedente só faria trabalho inútil (a carga é recusada).
			wanted = SafeRead.integer(entry.get("count"), 0, 0, MAX_STACK)
			wanted = mini(wanted, MAX_SPILL_LOAD_UNITS if may_spill else _slots.size() + 1)
		for n in wanted:
			result.append(_clean_individual(item_id, entry))
		return result
	var amount := SafeRead.number(entry.get("count"), 0.0, 0.0, float(MAX_STACK))
	var expiry := SafeRead.number(entry.get("expira_em"), 0.0, 0.0, MAX_EXPIRY)
	var limit := stack_limit(item_id)
	# Custo limitado: acima de (slots + 1) pilhas cheias nunca cabe, então não se divide além disso.
	var left := mini(int(amount), MAX_SPILL_LOAD_UNITS if may_spill else limit * (_slots.size() + 1))
	while left > 0 and limit > 0:
		var part := mini(left, limit)
		result.append({"id": item_id, "count": part, "expira_em": expiry})
		left -= part
	return result


## Entrada individual saneada (id conhecido e individual; `iid` e durabilidade com padrão seguro,
## `iid` repetido ou inválido ganha um novo da cópia), ou `{}` se não for um individual válido.
## Usada pelas vagas de equipamento para ler o save sem duplicar a regra.
func clean_individual_entry(entry: Dictionary) -> Dictionary:
	var item_id := SafeRead.text(entry.get("id"), "")
	if not Items.is_individual(item_id):
		return {}
	return _clean_individual(item_id, entry)


## Individual saneado: `iid` texto curto e único (senão novo); durabilidade com padrão seguro
## (máximo do item e cheia, se faltar).
func _clean_individual(item_id: String, entry: Dictionary) -> Dictionary:
	var iid := SafeRead.text(entry.get("iid"), "")
	if iid == "" or iid.length() > MAX_IID_LENGTH or has_iid(iid):
		iid = issue_iid()
	var limit := Items.durability_max(item_id)
	var durab_max := SafeRead.integer(entry.get("durab_max"), limit, 1, 1000000)
	var durab := SafeRead.integer(entry.get("durab"), durab_max, 0, durab_max)
	return {"id": item_id, "iid": iid, "durab": durab, "durab_max": durab_max}


## Emite um `iid` novo, que não existe na grade (a vaga de equipamento usa ao restaurar).
func issue_iid() -> String:
	var iid := "%s%d" % [iid_prefix, _next_iid]
	while has_iid(iid):
		_next_iid += 1
		iid = "%s%d" % [iid_prefix, _next_iid]
	_next_iid += 1
	return iid


func _new_individual(item_id: String) -> Dictionary:
	var limit := Items.durability_max(item_id)
	return {"id": item_id, "iid": issue_iid(), "durab": limit, "durab_max": limit}


func _amount(slot: Dictionary) -> int:
	return 1 if slot.has("iid") else int(slot.get("count", 0))


func _index_of_iid(iid: String) -> int:
	if iid == "":
		return -1
	for i in _slots.size():
		if _slots[i].get("iid", "") == iid:
			return i
	return -1


## Coloca uma entrada pronta. Pilha junta nas existentes (validade: a mais antiga); individual
## vai a um slot vazio (iid novo se colidir). Retorna true se coube inteira.
func _put_entry(entry: Dictionary) -> bool:
	if entry.has("iid"):
		if not accepts_individual:
			return false
		var placed := entry.duplicate()
		if has_iid(placed["iid"]):
			placed["iid"] = issue_iid()
		return _put(placed)
	var wanted := int(entry["count"])
	return _put_stack(entry["id"], wanted, float(entry.get("expira_em", 0.0))) == wanted


## Guarda o que couber da entrada e devolve o que sobrou (`{}` = coube tudo): a pilha pode caber em parte.
func _put_entry_partial(entry: Dictionary) -> Dictionary:
	if entry.has("iid"):
		return {} if _put_entry(entry) else entry
	var wanted := int(entry["count"])
	var placed := _put_stack(str(entry["id"]), wanted, float(entry.get("expira_em", 0.0)))
	if placed >= wanted:
		return {}
	var rest := entry.duplicate()
	rest["count"] = wanted - placed
	return rest


func _put(entry: Dictionary) -> bool:
	var region := _region_of(str(entry["id"]))
	for i in range(region.x, region.y):
		if _slots[i].is_empty():
			_slots[i] = entry
			return true
	return false


## Guarda `amount` da pilha e devolve quanto coube.
func _put_stack(item_id: String, amount: int, expiry: float) -> int:
	var limit := stack_limit(item_id)
	var left := amount
	var region := _region_of(item_id)
	for i in range(region.x, region.y):
		var slot := _slots[i]
		if left > 0 and not slot.is_empty() and slot["id"] == item_id and not slot.has("iid"):
			var moved := mini(left, limit - int(slot["count"]))
			if moved > 0:
				slot["count"] = int(slot["count"]) + moved
				slot["expira_em"] = _older(float(slot.get("expira_em", 0.0)), expiry)
				left -= moved
	for i in range(region.x, region.y):
		if left > 0 and _slots[i].is_empty():
			var moved := mini(left, limit)
			_slots[i] = {"id": item_id, "count": moved, "expira_em": expiry}
			left -= moved
	return amount - left


## Entre duas validades, a mais antiga; 0 (sem validade) cede à que vence.
func _older(first: float, second: float) -> float:
	if first <= 0.0:
		return second
	if second <= 0.0:
		return first
	return minf(first, second)


## Retira até `amount` (do fim para o começo) e devolve as entradas retiradas
## (pilhas parciais ou individuais inteiros). Emite `changed` se algo saiu.
func _take(item_id: String, amount: int) -> Array[Dictionary]:
	var taken: Array[Dictionary] = []
	var left := amount
	for i in range(_slots.size() - 1, -1, -1):
		var slot := _slots[i]
		if left <= 0 or slot.is_empty() or slot["id"] != item_id:
			continue
		if slot.has("iid"):
			taken.append(slot)
			_slots[i] = {}
			left -= 1
		else:
			var part := mini(left, int(slot["count"]))
			taken.append({"id": item_id, "count": part, "expira_em": float(slot.get("expira_em", 0.0))})
			slot["count"] = int(slot["count"]) - part
			left -= part
			if slot["count"] <= 0:
				_slots[i] = {}
	if left != amount:
		changed.emit()
	return taken


## Retira até `amount` do slot `index` e devolve a entrada retirada (individual inteiro ou pilha parcial).
func _take_from(index: int, amount: int) -> Dictionary:
	var slot := _slots[index]
	var entry: Dictionary
	if slot.has("iid"):
		entry = slot
		_slots[index] = {}
	else:
		var part := mini(amount, int(slot["count"]))
		entry = {"id": slot["id"], "count": part, "expira_em": float(slot.get("expira_em", 0.0))}
		slot["count"] = int(slot["count"]) - part
		if slot["count"] <= 0:
			_slots[index] = {}
	changed.emit()
	return entry


## Posições onde o item pode ficar: o cinto (se há cinto e o item é de cinto) ou a grade. `x` inclusive, `y` exclusivo.
func _region_of(item_id: String) -> Vector2i:
	if _slots.size() > _grid and Items.belt_of(item_id):
		return Vector2i(_grid, _slots.size())
	return Vector2i(0, _grid)


## Ajusta a grade ao pedido sem perder itens (só corta posições vazias do fim da grade); devolve o tamanho real.
## (Não escreve em `capacity`: quem chama do setter é que atribui, sem recursão.)
func _fit_grid(wanted: int) -> int:
	while _grid < wanted:
		_slots.insert(_grid, {})
		_grid += 1
	while _grid > wanted and _slots[_grid - 1].is_empty():
		_slots.remove_at(_grid - 1)
		_grid -= 1
	return _grid


## O mesmo para o cinto (as posições depois da grade); devolve o tamanho real.
func _fit_belt(wanted: int) -> int:
	var belt := _slots.size() - _grid
	while belt < wanted:
		_slots.append({})
		belt += 1
	while belt > wanted and _slots[_slots.size() - 1].is_empty():
		_slots.pop_back()
		belt -= 1
	return belt
