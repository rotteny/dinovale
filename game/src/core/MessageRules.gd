# SPDX-License-Identifier: MIT
class_name MessageRules
extends Resource
## Tempos e limites do log de mensagens da HUD (dados em `res://data/ui/message_rules.tres`).

## Linhas recentes que aparecem no canto da tela.
@export_range(1, 12) var visible_lines: int = 6
## Segundos que a linha fica inteira antes de começar a sumir.
@export_range(1.0, 60.0) var hold_seconds: float = 6.0
## Segundos que o desvanecer leva.
@export_range(0.1, 10.0) var fade_seconds: float = 2.0
## Linhas guardadas no histórico completo.
@export_range(10, 1000) var history_max: int = 200
