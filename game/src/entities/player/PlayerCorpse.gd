# SPDX-License-Identifier: MIT
class_name PlayerCorpse
extends Node2D
## Corpo do jogador morto (M1, etapa 6): fica no lugar da morte com TODOS os itens que ele levava (grade, equipado e
## atalhos) até `due_at` (instante do relógio do mundo, ADR-006: só corre com o mundo rodando, decisão D4). Entidade de
## mundo com id da autoridade; recuperar é `WorldAuthority.request_recover_corpse`. Lógica pura: o desenho é do `CorpseView`.

## Esvaziou (tudo foi recuperado): o campo o remove.
signal depleted(corpse: PlayerCorpse)
signal changed

const INTERACT_RADIUS := 10.0
const PROMPT := "recuperar itens"

## `player_id` do dono: só ele recupera (gancho do co-op).
var owner_player_id: String = ""
## Instante (relógio do mundo) em que o corpo some com o que sobrou.
var due_at: float = 0.0
## O que o corpo guarda: entradas de `InventoryComponent` (`{id, count}` de pilha ou `{id, iid, durab...}` de individual).
var entries: Array[Dictionary] = []
## Onde estavam os atalhos do dono ao morrer: `{slot, id, iid}` (`iid` vazio = tipo empilhável). Só a apresentação do
## "devolver ao atalho" lê isto; não guarda item nenhum.
var hotbar_slots: Array[Dictionary] = []
var interactable: InteractableArea = null


func _init() -> void:
	interactable = InteractableArea.new()
	interactable.entity = self
	interactable.prompt = PROMPT
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = INTERACT_RADIUS
	shape.shape = circle
	interactable.add_child(shape)
	add_child(interactable)


## Quantas unidades de item o corpo ainda guarda (pilha pela contagem; individual vale 1).
func item_count() -> int:
	var total := 0
	for entry in entries:
		total += _units(entry)
	return total


## Quantas unidades de `item_id` o corpo guarda.
func count(item_id: String) -> int:
	var total := 0
	for entry in entries:
		if entry.get("id") == item_id:
			total += _units(entry)
	return total


func is_empty() -> bool:
	return entries.is_empty()


## Passa ao inventário `to` o que couber, na ordem em que as entradas estão; o resto fica no corpo. Devolve quantas
## unidades passaram. Esvaziou: avisa o campo.
func recover_into(to: InventoryComponent) -> int:
	var moved := 0
	var kept: Array[Dictionary] = []
	for entry in entries:
		var units := _units(entry)
		var left := to.add_entry(entry)
		moved += units - left
		if left > 0:
			var rest := entry.duplicate(true)
			if not rest.has("iid"):
				rest["count"] = left
			kept.append(rest)
	entries = kept
	if moved > 0:
		changed.emit()
	if entries.is_empty():
		depleted.emit(self)
	return moved


## Por que nada do corpo coube em `bag`: "weight_limit" se o Peso barra algum item (o Peso vem primeiro), senão "inventory_full".
func refusal_for(bag: InventoryComponent) -> String:
	for entry in entries:
		if bag.refusal_for(str(entry.get("id", ""))) == "weight_limit":
			return "weight_limit"
	return "inventory_full"


## Devolve à barra `hotbar` os atalhos que apontavam para itens que já voltaram ao inventário `bag`. Só ocupa vaga vazia
## e não repete o item; o que ainda não voltou fica para a próxima recuperação.
func restore_hotbar(hotbar: HotbarComponent, bag: InventoryComponent) -> void:
	var pending: Array[Dictionary] = []
	for saved in hotbar_slots:
		var slot := int(saved.get("slot", -1))
		var item_id := str(saved.get("id", ""))
		var iid := str(saved.get("iid", ""))
		var back := (not bag.find_iid(iid).is_empty()) if iid != "" else bag.count(item_id) > 0
		if not back:
			pending.append(saved)
			continue
		if hotbar.entry_at(slot).is_empty():
			if iid != "":
				hotbar.assign_iid(slot, iid, item_id)
			else:
				hotbar.assign(slot, item_id)
	hotbar_slots = pending


static func _units(entry: Dictionary) -> int:
	return 1 if entry.has("iid") else maxi(SafeRead.integer(entry.get("count"), 0, 0, InventoryComponent.MAX_STACK), 0)
