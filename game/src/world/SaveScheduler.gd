# SPDX-License-Identifier: MIT
class_name SaveScheduler
extends Node
## Quando salvar. Recebe os gatilhos (`SaveManager.Reason`) e grava com o `SaveManager`:
## - `AUTOSAVE` a cada `SaveRules.autosave_interval_seconds` de jogo, contado por `tick(delta)`;
##   pausado não conta (o `_physics_process` não roda com a árvore pausada).
## - O relógio zera a cada save, de qualquer origem (GDD 12.1).
## - `request(reason)` agenda; vários pedidos antes do fim do quadro viram UM save só
##   (o de maior prioridade dá o motivo). Morte a menos de `min_seconds_between_saves` do último save
##   espera o prazo e vira um save só, com o estado de então: nunca é descartada. `save_now(reason)`
##   grava na hora, sem prazo e levando junto o que estiver agendado (menu, sair, Salvar, Cama).
## - Nunca grava dentro de outra gravação, e o estado é tirado de uma vez só, no fim do quadro:
##   morte e autosave no mesmo instante não gravam estado pela metade.
## - Falha de escrita não interrompe o jogo nem apaga o arquivo anterior: `saved(..., false, msg)`.
## - Nunca pergunta nada. `frozen` (o Continuar falhou e a cena está saindo) não grava nada, de nenhum
##   gatilho: o arquivo que o jogo recusou fica como está.
## - Escrita que falha NÃO perde o pedido: tenta de novo depois de `retry_seconds_after_failure`, sem
##   esperar o intervalo todo e sem martelar o disco.

## `reason` é o de maior prioridade entre os fundidos. `message` é para o jogador.
signal saved(reason: SaveManager.Reason, ok: bool, message: String)

@export var rules: SaveRules = preload("res://data/balance/save_rules.tres")

var player: Player
var dino: Dino
## Nós de recurso do mundo (opcional: sem eles o save leva uma lista vazia).
var field: ResourceField
## Contador de respawns do mundo, semente do sorteio de ponto (quem renasce atualiza).
var respawn_count: int = 0
var manager: SaveManager
var frozen: bool = false
## Texto do último save (sucesso ou falha).
var last_message: String = ""
## Duração do último save, em microssegundos (captura, escrita e releitura).
var last_duration_usec: int = 0
var saves_done: int = 0

var _elapsed: float = 0.0
var _saved_once: bool = false
var _pending: Array[SaveManager.Reason] = []
var _flush_queued: bool = false
var _saving: bool = false
var _retry_wait: float = 0.0


func _physics_process(delta: float) -> void:
	tick(delta)


## Passo do relógio do autosave.
func tick(delta: float) -> void:
	_elapsed += delta
	_retry_wait = maxf(_retry_wait - delta, 0.0)
	if _elapsed >= rules.autosave_interval_seconds:
		request(SaveManager.Reason.AUTOSAVE)
	if not _pending.is_empty() and not _flush_queued and not _in_cooldown() and _retry_wait <= 0.0:
		_flush()


## Segundos desde o último save (para teste e depuração).
func elapsed() -> float:
	return _elapsed


## Agenda um save para o fim do quadro. Pedidos seguidos viram um só.
func request(reason: SaveManager.Reason) -> void:
	if not _allowed(reason):
		return
	_queue(reason)
	if _retry_wait > 0.0 or (_in_cooldown() and reason != SaveManager.Reason.AUTOSAVE):
		return  # o `tick` grava quando o prazo acabar ou a espera da nova tentativa passar
	if not _flush_queued:
		_flush_queued = true
		_flush.call_deferred()


## Um motivo só entra uma vez na fila: durante uma falha longa ela não cresce.
func _queue(reason: SaveManager.Reason) -> void:
	if not _pending.has(reason):
		_pending.append(reason)


## Quantos motivos esperam (para teste).
func pending_count() -> int:
	return _pending.size()


## Dentro do prazo de rajada do último save?
func _in_cooldown() -> bool:
	return _saved_once and _elapsed < rules.min_seconds_between_saves


## Grava agora, junto com o que estiver agendado. Devolve se gravou.
func save_now(reason: SaveManager.Reason) -> bool:
	if not _allowed(reason):
		return false
	_queue(reason)
	return _flush()


func _allowed(_reason: SaveManager.Reason) -> bool:
	return not frozen


func _flush() -> bool:
	_flush_queued = false
	if _saving or _pending.is_empty():
		return false
	_saving = true
	var reason: SaveManager.Reason = _pending.min()
	var reasons := _pending.duplicate()
	_pending.clear()
	var started := Time.get_ticks_usec()
	var live_dino: Dino = dino if is_instance_valid(dino) else null
	var envelope := WorldSnapshot.capture(player, live_dino, _game_version(),
			Time.get_datetime_string_from_system(true), field, respawn_count)
	var ok := manager.write(envelope)
	last_duration_usec = Time.get_ticks_usec() - started
	_saving = false
	if ok:
		_elapsed = 0.0
		_saved_once = true
		_retry_wait = 0.0
		saves_done += 1
		last_message = "Jogo salvo."
	else:
		for kept: SaveManager.Reason in reasons:  # não se perde
			_queue(kept)
		_retry_wait = rules.retry_seconds_after_failure
		last_message = "Não foi possível salvar: %s. O jogo continua e o save anterior foi mantido." % manager.last_error
	saved.emit(reason, ok, last_message)
	return ok


func _game_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.1.0"))
