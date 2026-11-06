# SPDX-License-Identifier: MIT
class_name ErrorCounter
extends Logger
## Erro de runtime em GDScript só aborta a função atual: sem isto, um teste
## quebrado no meio passaria como verde. O runner o instala com `OS.add_logger` e falha se `count` passar de zero.

var count := 0


func _log_error(_function: String, _file: String, _line: int, _code: String,
		_rationale: String, _editor_notify: bool, _error_type: int,
		_script_backtrace: Array[ScriptBacktrace]) -> void:
	count += 1
