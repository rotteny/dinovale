# SPDX-License-Identifier: MIT
class_name SaveRules
extends Resource
## Números do salvamento, só dados (AGENTS.md: nada de balanceamento no código). Valores em
## `res://data/balance/save_rules.tres`. Quem usa: `SaveScheduler`.

## Intervalo do salvamento automático, em segundos de jogo (pausado não conta). Decisão do dono: 5 min.
@export_range(5.0, 3600.0) var autosave_interval_seconds: float = 300.0
## Rajada (GDD 12.1): gatilhos de morte a menos disto do último save viram UM save, feito quando o
## prazo acaba, com o estado daquela hora (nunca descartado). Cama, voltar ao menu e sair
## ignoram o prazo.
@export_range(0.0, 60.0) var min_seconds_between_saves: float = 10.0
## Escrita que falhou tenta de novo depois disto, sem esperar o intervalo do autosave.
@export_range(1.0, 300.0) var retry_seconds_after_failure: float = 10.0
