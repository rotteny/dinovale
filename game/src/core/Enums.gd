# SPDX-License-Identifier: MIT
class_name Enums
extends RefCounted
## Enums compartilhados. Em saves, grave o NOME do valor, não o número:
## assim reordenar um enum não corrompe mundos antigos.

enum DinoStateId { IDLE, WANDER, UNCONSCIOUS, TAMED, AGGRESSIVE, STUCK }

## Fases do ciclo de ameaça do bravo (`ThreatCycle`). Nunca vai para o save (bravo não persiste).
enum ThreatPhase { NONE, THREAT, APPROACH, CIRCLE, WINDUP, LUNGE, RECOVER }

## Porte da espécie. Em dado, o NOME (`DinoBaseStats.size`); só Grande pode ter dano em área.
enum DinoSize { SMALL, MEDIUM, LARGE }

## Ordem de movimento do dino domado (GDD 6.11). STAY é o padrão de quem acabou de ser domado.
enum DinoOrder { STAY, FOLLOW }

## Resultado de um `WorldAuthority.request_*` (ADR-001). Só diferente de OK quando nada mudou.
## O retorno serve a teste e log; a UI nunca atualiza estado por ele.
enum ActionResult {
	OK,
	UNKNOWN_ACTOR,
	ACTOR_DEAD,
	UNKNOWN_TARGET,
	INVALID_TARGET,
	INVALID_ARGUMENT,
	OUT_OF_RANGE,
	COOLDOWN,
	WRONG_STATE,
	NOT_OWNER,
	REFUSED,
}
