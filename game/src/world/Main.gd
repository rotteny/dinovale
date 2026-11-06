# SPDX-License-Identifier: MIT
class_name Main
extends Node2D
## Cena principal: liga o mundo à UI. Quando o jogador interage com uma criatura,
## abre o inventário compartilhado; enquanto a tela está aberta o jogador não anda.
## Também liga o save: "Continuar" (pedido em `GameSession`) restaura o último jogo; o `SaveScheduler`
## salva no intervalo, na morte do jogador e na de um dino domado; a pausa tem Salvar; voltar ao menu e
## fechar a janela salvam direto. O jogo nunca pergunta antes de salvar.

@export var player: Player
@export var screen: InventoryScreen
@export var dino: Dino
## Pausa (Esc quando nenhuma tela está aberta). Opcional: um servidor ou teste pode não ter UI.
@export var pause: PauseMenu
## Cena da apresentação, para "Voltar ao menu"; vazio = a pausa só tem Continuar.
@export_file("*.tscn") var menu_scene: String = ""
## HUD, só para os avisos do save (opcional).
@export var hud: PlayerHud
## Mundo do save: pasta `<raiz>/<world_id>/` (ver `GameSession.save_root`).
@export var world_id: String = GameSession.DEFAULT_WORLD
## Nível fixo da criatura da cena (sem biomas nem sorteio por enquanto).
@export var dino_level: int = 20

## O jogo carregado é de um jogador que morreu sem escolher onde renascer (GDD 12.4). A tela de morte
## (SOB-01, próxima etapa) lê isto; até lá o jogador volta vivo no lugar (ver `WorldSnapshot`).
var pending_death_choice: bool = false
var save_manager: SaveManager
var scheduler: SaveScheduler

var _quit_failed_once: bool = false
var _last_failure_notice: String = ""
## O Continuar falhou: esta partida não existe de verdade (a cena volta ao título) e não grava nada.
var _load_failed: bool = false


func _ready() -> void:
	dino.level = dino_level
	get_tree().auto_accept_quit = false  # o fechar da janela passa pelo save (_notification)
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
	save_manager = SaveManager.new(GameSession.save_root, world_id)
	scheduler = SaveScheduler.new()
	scheduler.player = player
	scheduler.dino = dino
	scheduler.manager = save_manager
	scheduler.saved.connect(_on_saved)
	add_child(scheduler)
	player.health.died.connect(func() -> void: scheduler.request(SaveManager.Reason.PLAYER_DEATH))
	dino.health.died.connect(_on_dino_died)
	if pause != null:
		pause.set_menu_available(menu_scene != "")
		pause.set_save_available(true)
		pause.save_requested.connect(_on_save_requested)
		pause.menu_requested.connect(_on_menu_requested)
	if GameSession.take_continue():
		_continue_saved_game()


## Gravar agora (Salvar da pausa; a Cama usa `SaveManager.Reason.BED`). Falhou: o motivo fica em
## `scheduler.last_message` e o save anterior continua.
func save_game(reason: SaveManager.Reason = SaveManager.Reason.MANUAL) -> bool:
	return scheduler.save_now(reason)


func _continue_saved_game() -> void:
	var outcome := save_manager.load_first(func(data: Dictionary) -> bool: return WorldSnapshot.restore(data, player, dino))
	if outcome.status == SaveManager.Status.OK:
		pending_death_choice = WorldSnapshot.was_dead_pending_choice(outcome.data)
		_notify(outcome.message)
		return
	# Continuar que falha não abre jogo novo nem grava nada: volta ao título com o motivo, e o arquivo
	# que o jogo recusou fica exatamente como estava.
	_load_failed = true
	scheduler.frozen = true
	GameSession.notice = outcome.message if outcome.message != "" else "Nenhum jogo salvo."
	if menu_scene != "":
		get_tree().change_scene_to_file.call_deferred(menu_scene)


func _notify(text: String, seconds: float = PlayerHud.NOTICE_SECONDS) -> void:
	if hud != null and text != "":
		hud.show_notice(text, seconds)


## Só domado: um selvagem que morre não é salvo. A criatura já saiu do mundo (`queue_free` do próprio
## dino roda antes, pela ordem das conexões), então o save a deixa de fora e ela não volta ao carregar.
func _on_dino_died() -> void:
	if dino.state_machine.is_tamed:
		scheduler.request(SaveManager.Reason.TAMED_DINO_DEATH)


## Falha de escrita avisa na HUD e o jogo segue; sucesso é silencioso (a pausa mostra o dela).
func _on_saved(reason: SaveManager.Reason, ok: bool, message: String) -> void:
	if not ok:
		if message != _last_failure_notice:  # só na primeira falha da sequência, ou se a mensagem mudar
			_last_failure_notice = message
			_notify(message, 6.0)
		return
	_last_failure_notice = ""
	_quit_failed_once = false
	if hud != null and reason != SaveManager.Reason.EXIT_MENU and reason != SaveManager.Reason.QUIT:
		hud.show_saving()


func _on_save_requested() -> void:
	save_game()
	if pause != null:
		pause.show_status(scheduler.last_message)


## Voltar ao menu salva e volta direto. Se a escrita falhar, a partida não fecha: o aviso aparece
## na pausa e o save anterior continua.
func _on_menu_requested() -> void:
	if not _load_failed and not save_game(SaveManager.Reason.EXIT_MENU):
		pause.show_status(scheduler.last_message)
		return
	get_tree().paused = false
	get_tree().change_scene_to_file(menu_scene)


## Fechar a janela salva antes de sair. Se a escrita falhar, a janela fica aberta com o aviso na HUD;
## um segundo pedido de fechar sai mesmo assim (decisão explícita do jogador).
func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_CLOSE_REQUEST or save_manager == null:
		return
	if _load_failed or save_game(SaveManager.Reason.QUIT) or _quit_failed_once:
		get_tree().quit()
	else:
		_quit_failed_once = true
		_notify(scheduler.last_message + " Feche de novo para sair mesmo assim.", 8.0)


func _exit_tree() -> void:
	get_tree().auto_accept_quit = true


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
