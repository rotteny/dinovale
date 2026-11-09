# SPDX-License-Identifier: MIT
class_name CraftSystem
extends RefCounted
## Fabricações em andamento (E7a): no máximo uma por jogador. Só o relógio das tarefas: validar o pedido, consumir
## material e entregar o item é da `WorldAuthority`. Não vai ao save (o material só sai no fim: ver `finish_craft`).

## actor_id -> {"recipe": String, "left": float, "total": float, "bench": int}
var _jobs: Dictionary[int, Dictionary] = {}


func is_crafting(actor_id: int) -> bool:
	return _jobs.has(actor_id)


## Começa a tarefa. `bench_id` 0 = à mão. Devolve false se o jogador já fabrica algo.
func begin(actor_id: int, recipe_id: String, seconds: float, bench_id: int = 0) -> bool:
	if _jobs.has(actor_id):
		return false
	_jobs[actor_id] = {"recipe": recipe_id, "left": seconds, "total": seconds, "bench": bench_id}
	return true


## Cancela e devolve a tarefa que havia ({} se nenhuma).
func cancel(actor_id: int) -> Dictionary:
	var job: Dictionary = _jobs.get(actor_id, {})
	_jobs.erase(actor_id)
	return job


## A tarefa de `actor_id` ({} se nenhuma).
func job_of(actor_id: int) -> Dictionary:
	return _jobs.get(actor_id, {}).duplicate()


## Fração pronta (0 a 1) da tarefa; 0 sem tarefa.
func progress(actor_id: int) -> float:
	var job: Dictionary = _jobs.get(actor_id, {})
	if job.is_empty():
		return 0.0
	return clampf(1.0 - float(job["left"]) / maxf(float(job["total"]), 0.001), 0.0, 1.0)


## Passa o tempo. Devolve os jogadores cuja tarefa acabou (a autoridade a retira com `cancel`).
func tick(delta: float) -> Array[int]:
	var finished: Array[int] = []
	for actor_id in _jobs.keys():
		var job: Dictionary = _jobs[actor_id]
		job["left"] = float(job["left"]) - delta
		if float(job["left"]) <= 0.0:
			finished.append(actor_id)
	return finished


## Todos os jogadores com tarefa.
func actors() -> Array[int]:
	var list: Array[int] = []
	list.assign(_jobs.keys())
	return list
