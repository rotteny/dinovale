# SPDX-License-Identifier: MIT
class_name Main
extends Node2D
## Cena principal: liga o mundo à UI. Quando o jogador interage com uma criatura,
## abre o inventário compartilhado; enquanto a tela está aberta o jogador não anda.

@export var player: Player
@export var screen: InventoryScreen
@export var dino: Dino
## Pausa (Esc quando nenhuma tela está aberta). Opcional: um servidor ou teste pode não ter UI.
@export var pause: PauseMenu
## Cena da apresentação, para "Voltar ao menu"; vazio = a pausa só tem Continuar.
@export_file("*.tscn") var menu_scene: String = ""
## Nível fixo da criatura da cena (sem biomas nem sorteio por enquanto).
@export var dino_level: int = 20


func _ready() -> void:
	dino.level = dino_level
	screen.player_inventory = player.inventory
	screen.hotbar = player.hotbar
	screen.equipment = player.equipment
	screen.equip_requested.connect(func(iid: String) -> void: player.request_equip(iid))
	screen.unequip_requested.connect(func(slot_id: String) -> void: player.request_unequip(slot_id))
	player.equip_refused.connect(screen.show_refusal)
	screen.hotbar_assign_requested.connect(_on_hotbar_assign_requested)
	screen.opened.connect(func() -> void: player.input_locked = true)
	screen.closed.connect(func() -> void: player.input_locked = false)
	player.interacted.connect(_on_player_interacted)
	if pause != null:
		pause.set_menu_available(menu_scene != "")
		pause.menu_requested.connect(_on_menu_requested)


func _on_menu_requested() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(menu_scene)


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
