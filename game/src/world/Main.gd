class_name Main
extends Node2D
## Cena principal: liga o mundo à UI. Quando o jogador interage com uma criatura,
## abre o inventário compartilhado; enquanto a tela está aberta o jogador não anda.

@export var player: Player
@export var screen: InventoryScreen


func _ready() -> void:
	screen.player_inventory = player.inventory
	screen.opened.connect(func() -> void: player.input_locked = true)
	screen.closed.connect(func() -> void: player.input_locked = false)
	player.interacted.connect(_on_player_interacted)


func _on_player_interacted(target: InteractableArea) -> void:
	var dino := target.entity as Dino
	if dino != null:
		screen.open_with(player.inventory, dino.inventory, target, "Criatura")
