# SPDX-License-Identifier: MIT
class_name Main
extends Node2D
## Cena principal: liga o mundo à UI. Quando o jogador interage com uma criatura,
## abre o inventário compartilhado; enquanto a tela está aberta o jogador não anda.

@export var player: Player
@export var screen: InventoryScreen
@export var dino: Dino
## Nível fixo da criatura da cena (sem biomas nem sorteio por enquanto).
@export var dino_level: int = 20


func _ready() -> void:
	dino.level = dino_level
	screen.player_inventory = player.inventory
	screen.hotbar = player.hotbar
	screen.hotbar_assign_requested.connect(_on_hotbar_assign_requested)
	screen.opened.connect(func() -> void: player.input_locked = true)
	screen.closed.connect(func() -> void: player.input_locked = false)
	player.interacted.connect(_on_player_interacted)


## A tela pede, o mundo muda a barra do jogador ("" limpa a posição).
func _on_hotbar_assign_requested(slot: int, item_id: String, iid: String) -> void:
	if item_id == "":
		player.hotbar.clear(slot)
	elif iid != "":
		player.hotbar.assign_iid(slot, iid, item_id)
	else:
		player.hotbar.assign(slot, item_id)


func _on_player_interacted(target: InteractableArea) -> void:
	var target_dino := target.entity as Dino
	if target_dino != null:
		screen.open_with(player.inventory, target_dino.inventory, target, "Criatura")
