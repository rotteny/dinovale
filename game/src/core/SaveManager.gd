# SPDX-License-Identifier: MIT
class_name SaveManager
extends RefCounted
## Arquivo de save de um mundo (ADR-002, SAV-01): `<raiz>/<mundo>/world.json` em JSON, com envelope
## `{format_version, game_version, saved_at, world, players, entities}`. Só lê e grava o envelope;
## quem sabe montar e aplicar o conteúdo é `WorldSnapshot`.
##
## Escrita: grava `world.json.tmp`, relê e valida; só então o save válido atual vira `.bak` (o `.bak`
## antigo sai) e o `.tmp` vira `world.json`. Não depende de rename sobrescrever destino. Falhou em
## qualquer passo: o save anterior continua onde estava. Um `.tmp` que sobrar é ignorado.
## Leitura: o save principal; danificado, a cópia `.bak`. Versão do formato maior que a do jogo é
## recusa explícita (não cai no `.bak`: seria voltar progresso sem aviso). Arquivo danificado nunca
## é apagado: ao gravar por cima, vai para `world.json.rejected` (e `.rejected.N`). Nada aborta lendo arquivo ruim.
## Dado de save é não confiável: só JSON, com limite de tamanho antes do parse.

enum Status {
	OK,
	## Nenhum arquivo de save.
	NONE,
	## O formato é de uma versão mais nova do jogo: recusado sem tocar no arquivo.
	FUTURE_VERSION,
	## Existe arquivo, mas nenhum utilizável.
	CORRUPT,
}

## Por que o jogo salvou (gatilhos decididos pelo dono). Quem escolhe quando é o `SaveScheduler`; aqui
## fica só o vocabulário. Menor valor = mais prioritário quando gatilhos seguidos viram um save só.
enum Reason {
	## Botão Salvar da pausa.
	MANUAL,
	## Deitar na cama (a Cama não existe ainda: só o ponto de entrada).
	BED,
	PLAYER_DEATH,
	## O jogador escolheu onde renascer (a morte pendente deixa de existir no save).
	RESPAWN,
	## Morreu um dino domado.
	TAMED_DINO_DEATH,
	EXIT_MENU,
	QUIT,
	AUTOSAVE,
}

enum Rotation { NOTHING, TO_BACKUP, TO_REJECTED, FAILED }

## Arquivo maior que isto é lixo: recusado antes de ler (premissa do ADR-002).
const MAX_FILE_BYTES := 64 * 1024 * 1024
const MAX_PLAYERS := 64
const MAX_ENTITIES := 100000
const MAX_WORLD_ID_LENGTH := 64
const FILE_NAME := "world.json"
const BACKUP_SUFFIX := ".bak"
const TEMP_SUFFIX := ".tmp"
const REJECTED_SUFFIX := ".rejected"
const MAX_REJECTED := 99

## Limite de tamanho; os testes baixam para provar a recusa sem criar arquivos enormes.
var max_bytes: int = MAX_FILE_BYTES
## Motivo da última gravação que falhou ("" se a última deu certo).
var last_error: String = ""

var _dir: String


## Resultado de uma leitura: o envelope migrado e validado (`data`) quando `status` é OK.
class Outcome extends RefCounted:
	var status: SaveManager.Status = SaveManager.Status.NONE
	var data: Dictionary = {}
	## Veio da cópia `.bak` porque o principal não serviu.
	var from_backup: bool = false
	## Texto para o jogador ("" quando não há nada a dizer).
	var message: String = ""


func _init(root: String = GameSession.DEFAULT_SAVE_ROOT, world_id: String = GameSession.DEFAULT_WORLD) -> void:
	_dir = root.path_join(world_id if is_valid_world_id(world_id) else GameSession.DEFAULT_WORLD)


## Id de mundo vira nome de pasta: só letras minúsculas, dígitos, `_` e `-`.
static func is_valid_world_id(world_id: String) -> bool:
	if world_id.is_empty() or world_id.length() > MAX_WORLD_ID_LENGTH:
		return false
	for i in world_id.length():
		var c := world_id.unicode_at(i)
		var ok := (c >= 97 and c <= 122) or (c >= 48 and c <= 57) or c == 95 or c == 45
		if not ok:
			return false
	return true


func main_path() -> String:
	return _dir.path_join(FILE_NAME)


func backup_path() -> String:
	return main_path() + BACKUP_SUFFIX


func temp_path() -> String:
	return main_path() + TEMP_SUFFIX


## Monta o envelope da versão atual. `saved_at` e `game_version` são informativos (nada os lê).
static func make_envelope(world: Dictionary, players: Array, entities: Array, game_version: String,
		saved_at: String) -> Dictionary:
	return {
		"format_version": SaveMigrations.CURRENT_VERSION,
		"game_version": game_version,
		"saved_at": saved_at,
		"world": world,
		"players": players,
		"entities": entities,
	}


## Confere a forma do envelope já na versão atual. Devolve "" se válido, senão o motivo.
static func validate_envelope(data: Dictionary) -> String:
	if SafeRead.integer(data.get("format_version"), 0, 1, SaveMigrations.CURRENT_VERSION) != SaveMigrations.CURRENT_VERSION:
		return "format_version inválido"
	if typeof(data.get("world")) != TYPE_DICTIONARY:
		return "world ausente"
	for key in ["players", "entities"]:
		var list: Variant = data.get(key)
		if typeof(list) != TYPE_ARRAY:
			return "%s ausente" % key
		if (list as Array).size() > (MAX_PLAYERS if key == "players" else MAX_ENTITIES):
			return "%s demais" % key
		for entry: Variant in list:
			if typeof(entry) != TYPE_DICTIONARY or typeof((entry as Dictionary).get("state")) != TYPE_DICTIONARY:
				return "item de %s malformado" % key
	for entry: Dictionary in data["entities"]:
		if typeof(entry.get("type")) != TYPE_STRING or SafeRead.integer(entry.get("id"), -1, 0, 1 << 52) < 0:
			return "entidade sem type ou id"
	for entry: Dictionary in data["players"]:
		if typeof(entry.get("player_id")) != TYPE_STRING:
			return "jogador sem player_id"
	return ""


## Lê um arquivo de save qualquer (também a fixture `res://`). Nunca aborta: tudo que dá errado vira
## `CORRUPT` ou `FUTURE_VERSION`, com o motivo em `message`. Ausente é `NONE`.
func read_file(path: String) -> Outcome:
	var outcome := Outcome.new()
	if not FileAccess.file_exists(path):
		return outcome
	outcome.status = Status.CORRUPT
	var raw := _parse_file(path, outcome)
	if outcome.message != "":
		return outcome
	var version := SafeRead.integer(raw.get("format_version"), 0, 1, 1 << 30)
	if version == 0:
		outcome.message = "versão do formato ausente ou inválida"
		return outcome
	if version > SaveMigrations.CURRENT_VERSION:
		outcome.status = Status.FUTURE_VERSION
		outcome.message = "Este save é de uma versão mais nova do jogo (formato %d, este jogo conhece até %d). Nada foi alterado." \
				% [version, SaveMigrations.CURRENT_VERSION]
		return outcome
	var migrated := SaveMigrations.migrate(raw)
	var problem := "migração impossível" if migrated.is_empty() else validate_envelope(migrated)
	if problem != "":
		outcome.message = problem
		return outcome
	outcome.status = Status.OK
	outcome.data = migrated
	return outcome


## Abre, confere o tamanho e parseia. Falhou: devolve {} e põe o motivo em `outcome.message`.
func _parse_file(path: String, outcome: Outcome) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		outcome.message = "não foi possível abrir o arquivo"
		return {}
	var length := file.get_length()
	if length > max_bytes:
		outcome.message = "arquivo grande demais"
		return {}
	var bytes := file.get_buffer(length)
	file.close()
	if bytes.has(0):  # JSON de verdade nunca tem NUL; evita o parser de UTF-8 reclamar de lixo binário
		outcome.message = "o conteúdo não é um save legível"
		return {}
	var parser := JSON.new()
	if parser.parse(bytes.get_string_from_utf8()) != OK or typeof(parser.data) != TYPE_DICTIONARY:
		outcome.message = "o conteúdo não é um save legível"
	elif not SaveMigrations.is_shallow(parser.data):
		outcome.message = "estrutura aninhada demais"
	else:
		return parser.data
	return {}


## Carrega o primeiro save que serve: o principal, depois a cópia `.bak`. `accept(data) -> bool` é
## quem aplica o envelope (e recusa devolvendo false sem ter mudado nada); recusado, tenta o próximo.
## Versão futura para na hora. Sem arquivo algum: `NONE`; com arquivos e nenhum serviu: `CORRUPT`,
## e os arquivos ficam como estão.
func load_first(accept: Callable) -> Outcome:
	var reasons: Array[String] = []
	var main := read_file(main_path())
	match main.status:
		Status.OK:
			if accept.call(main.data):
				return main
			reasons.append("o jogo recusou o arquivo principal")
		Status.FUTURE_VERSION:
			return main
		Status.CORRUPT:
			reasons.append("arquivo principal: " + main.message)
	var backup := read_file(backup_path())
	match backup.status:
		Status.OK:
			if accept.call(backup.data):
				backup.from_backup = true
				backup.message = "O save principal estava danificado ou ausente: carregada a cópia anterior." \
						if main.status != Status.OK else "O jogo recusou o save principal: carregada a cópia anterior."
				return backup
			reasons.append("o jogo recusou a cópia anterior")
		Status.FUTURE_VERSION:
			return backup
		Status.CORRUPT:
			reasons.append("cópia anterior: " + backup.message)
	var failure := Outcome.new()
	if main.status == Status.NONE and backup.status == Status.NONE:
		return failure
	failure.status = Status.CORRUPT
	failure.message = "Nenhum save utilizável (%s). Os arquivos foram mantidos." % "; ".join(reasons)
	return failure


## Resposta rápida para o menu: há save que dá para continuar? Não aplica nada.
func probe() -> Outcome:
	return load_first(func(_data: Dictionary) -> bool: return true)


## Algum arquivo de save (principal ou cópia) existe?
func has_files() -> bool:
	return FileAccess.file_exists(main_path()) or FileAccess.file_exists(backup_path())


## Grava o envelope de forma atômica. Devolve false (com `last_error`) sem tocar no save anterior
## quando algo falha antes da troca final; se a troca final falha, o anterior é recolocado.
func write(envelope: Dictionary) -> bool:
	last_error = ""
	var text := JSON.stringify(envelope, "\t")
	var problem := validate_envelope(envelope)
	if problem == "" and text.to_utf8_buffer().size() > max_bytes:
		problem = "o save passaria do limite de tamanho"
	if problem == "":
		problem = _stage(text)
	if problem != "":
		return _fail(problem)
	var temp := temp_path()
	var rotated := _rotate_current()
	if rotated == Rotation.FAILED:
		_remove(temp)
		return false
	if DirAccess.rename_absolute(temp, main_path()) != OK:
		if rotated == Rotation.TO_BACKUP:
			DirAccess.rename_absolute(backup_path(), main_path())  # recoloca o save anterior
		_remove(temp)
		return _fail("não foi possível concluir a gravação")
	return true


## Cria a pasta e deixa o conteúdo no `.tmp`, já relido e validado. Devolve "" ou o motivo da falha.
func _stage(text: String) -> String:
	var made := DirAccess.make_dir_recursive_absolute(_dir)
	if made != OK and made != ERR_ALREADY_EXISTS:
		return "não foi possível criar a pasta do save"
	var temp := temp_path()
	var reason := ""
	if not _write_text(temp, text):
		reason = "não foi possível gravar o arquivo temporário"
	elif read_file(temp).status != Status.OK:
		reason = "o arquivo temporário não passou na releitura"
	if reason != "":
		_remove(temp)
	return reason


## Tira o principal do caminho antes da troca final. Só save VÁLIDO entra no rodízio (principal -> `.bak`);
## o `.bak` velho só é apagado se for válido. Versão futura ou arquivo danificado, no principal ou no
## `.bak`, vai para um nome preservado (`.rejected`, `.rejected.1`, ...), sem sobrescrever outro
## preservado e fora do rodízio: nunca é apagado. Falha: `last_error` explica e nada fica pela metade.
func _rotate_current() -> Rotation:
	var main := main_path()
	var backup := backup_path()
	var current := read_file(main)
	if current.status == Status.NONE:
		return Rotation.NOTHING
	if current.status != Status.OK:
		return Rotation.TO_REJECTED if _preserve(main) else Rotation.FAILED
	if FileAccess.file_exists(backup):
		var kept_ok := read_file(backup).status == Status.OK
		if (kept_ok and not _remove(backup)) or (not kept_ok and not _preserve(backup)):
			_fail("não foi possível trocar a cópia anterior")
			return Rotation.FAILED
	if DirAccess.rename_absolute(main, backup) != OK:
		_fail("não foi possível guardar a cópia anterior")
		return Rotation.FAILED
	return Rotation.TO_BACKUP


## Move o arquivo para um nome preservado livre.
func _preserve(path: String) -> bool:
	var rejected := _free_rejected_path()
	if rejected == "" or DirAccess.rename_absolute(path, rejected) != OK:
		_fail("não foi possível preservar o arquivo que o jogo não leu")
		return false
	return true


func _fail(reason: String) -> bool:
	last_error = reason
	return false


func _write_text(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return false
	var stored := file.store_string(text)
	file.flush()
	var ok := stored and file.get_error() == OK
	file.close()
	return ok


func _remove(path: String) -> bool:
	return not FileAccess.file_exists(path) or DirAccess.remove_absolute(path) == OK


func _free_rejected_path() -> String:
	var base := main_path() + REJECTED_SUFFIX
	if not FileAccess.file_exists(base):
		return base
	for i in range(1, MAX_REJECTED + 1):
		var candidate := "%s.%d" % [base, i]
		if not FileAccess.file_exists(candidate):
			return candidate
	return ""
