# SPDX-License-Identifier: MIT
extends RefCounted
## Tabela de roundtrip por JSON (INF-03). Todo script com `to_dict` em `src/`
## precisa constar em SCRIPTS e ter um caso em `build`. O teste de arquitetura
## `tools/checks.d/10-arquitetura.sh` compara esta lista com o código: um saveable
## esquecido, ou uma entrada que já não existe, deixa o `tools/check.sh` vermelho.
##
## O caso devolve `[original, restaurado]`: o original com estado fora do padrão
## e o restaurado em estado padrão. O teste passa o `to_dict` do original por JSON
## e confere que o restaurado fica igual.

const DinoScene := preload("res://src/entities/dino/Dino.tscn")
const PlayerScene := preload("res://src/entities/player/Player.tscn")

# SAVEABLES-BEGIN
const SCRIPTS: Array[String] = [
	"res://src/components/EquipmentComponent.gd",
	"res://src/components/HealthComponent.gd",
	"res://src/components/HotbarComponent.gd",
	"res://src/components/HungerComponent.gd",
	"res://src/components/InventoryComponent.gd",
	"res://src/components/ResourceNodeComponent.gd",
	"res://src/components/StaminaComponent.gd",
	"res://src/components/TamingComponent.gd",
	"res://src/components/TorporComponent.gd",
	"res://src/entities/dino/Dino.gd",
	"res://src/entities/dino/DinoStateMachine.gd",
	"res://src/entities/player/Player.gd",
]
# SAVEABLES-END

var _host: Node
var _track: Callable


## `host` recebe as cenas; `track` registra todo nó criado para o teste liberar.
func _init(host: Node, track: Callable) -> void:
	_host = host
	_track = track


## Devolve `[original, restaurado]`, ou `[]` se o script não tem caso na tabela.
func build(script_path: String) -> Array:
	var cases := {
		"res://src/components/EquipmentComponent.gd": _equipment_case,
		"res://src/components/HealthComponent.gd": _health_case,
		"res://src/components/HotbarComponent.gd": _hotbar_case,
		"res://src/components/HungerComponent.gd": _hunger_case,
		"res://src/components/InventoryComponent.gd": _inventory_case,
		"res://src/components/ResourceNodeComponent.gd": _resource_node_case,
		"res://src/components/StaminaComponent.gd": _stamina_case,
		"res://src/components/TamingComponent.gd": _taming_case,
		"res://src/components/TorporComponent.gd": _torpor_case,
		"res://src/entities/dino/Dino.gd": _dino_case,
		"res://src/entities/dino/DinoStateMachine.gd": _state_machine_case,
		"res://src/entities/player/Player.gd": _player_case,
	}
	if not cases.has(script_path):
		return []
	return cases[script_path].call()


func _health_case() -> Array:
	var original: HealthComponent = _track.call(HealthComponent.new())
	original.take_damage(25.0)
	return [original, _track.call(HealthComponent.new())]


func _equipment_case() -> Array:
	var grid: InventoryComponent = _track.call(InventoryComponent.new())
	grid.add("sleep_staff", 1)
	var original: EquipmentComponent = _track.call(EquipmentComponent.new())
	original.inventory = grid
	original.equip(grid.get_slot(0)["iid"])
	var restored: EquipmentComponent = _track.call(EquipmentComponent.new())
	restored.inventory = grid
	return [original, restored]


func _hotbar_case() -> Array:
	var original: HotbarComponent = _track.call(HotbarComponent.new())
	original.assign(0, "berry")
	original.assign(4, "fern")
	return [original, _track.call(HotbarComponent.new())]


func _hunger_case() -> Array:
	var original: HungerComponent = _track.call(HungerComponent.new())
	original.tick(10.0)
	return [original, _track.call(HungerComponent.new())]


func _inventory_case() -> Array:
	var original: InventoryComponent = _track.call(InventoryComponent.new())
	original.add("berry", 3)
	original.add_entry({"id": "meat", "count": 2, "expira_em": 90.5})
	original.add("sleep_staff", 2)
	return [original, _track.call(InventoryComponent.new())]


func _stamina_case() -> Array:
	var original: StaminaComponent = _track.call(StaminaComponent.new())
	original.tick(1.0, true)
	return [original, _track.call(StaminaComponent.new())]


func _torpor_case() -> Array:
	var original: TorporComponent = _track.call(TorporComponent.new())
	original.add_torpor(40.0)
	return [original, _track.call(TorporComponent.new())]


## A domesticação depende de torpor, inventário e máquina: os dois dinos dormem.
func _taming_case() -> Array:
	var original := _sleeping_dino()
	original.inventory.add("berry", 5)
	original.taming.tick(7.0)
	return [original.taming, _sleeping_dino().taming]


## Domesticar acorda a criatura (torpor zerado), então o restaurado nasce acordado:
## o torpor é a fonte da verdade da consciência.
func _state_machine_case() -> Array:
	var original := _sleeping_dino()
	original.state_machine.mark_tamed()
	return [original.state_machine, (_spawn(DinoScene) as Dino).state_machine]


func _dino_case() -> Array:
	var original := _spawn(DinoScene) as Dino
	original.position = Vector2(48.0, 96.0)
	original.level = 15
	original.health.take_damage(25.0)
	original.torpor.add_torpor(100.0)
	return [original, _spawn(DinoScene)]


func _resource_node_case() -> Array:
	var def: ResourceNodeDef = load("res://data/resources/tree.tres")
	var original: ResourceNodeComponent = _track.call(ResourceNodeComponent.new())
	original.def = def
	original.harvest()
	original.tick(30.0)
	var restored: ResourceNodeComponent = _track.call(ResourceNodeComponent.new())
	restored.def = def
	return [original, restored]


func _player_case() -> Array:
	var original := _spawn(PlayerScene) as Player
	original.health.take_damage(10.0)
	original.health.grant_protection(2.5)
	original.inventory.remove("berry", 3)
	original.hotbar.assign(8, "meat")
	original.request_use_item(3)
	return [original, _spawn(PlayerScene)]


func _sleeping_dino() -> Dino:
	var dino := _spawn(DinoScene) as Dino
	dino.torpor.add_torpor(100.0)
	return dino


func _spawn(scene: PackedScene) -> Node:
	var node: Node = scene.instantiate()
	_host.add_child(node)
	return _track.call(node)
