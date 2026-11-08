# SPDX-License-Identifier: MIT
class_name WorldPunchTests
extends WorldTests
## Parte do mundo que saiu de `WorldTests` (limite de linhas do arquivo): recusas do golpe e pedras avulsas.


func run() -> void:
	await _test_punch_denials()
	_release_worlds()
	await _test_loose_stones()
	_release_worlds()


func _test_punch_denials() -> void:
	var tree := _root.get_tree()
	var main := _main("punch_denials", 20, true)
	await tree.physics_frame
	var player := main.player
	var authority := main.authority
	var wood := main.resources.node_by_id("n316")
	var rock := main.resources.node_by_id("n174")
	# Fora de alcance: negado, sem custo e sem gastar o nó.
	player.position = wood.position + Vector2(400, 0)
	var before := player.to_dict()
	_check(authority.request_gather(1, authority.id_of(wood)) == RESULT.OUT_OF_RANGE and wood.is_available() and player.to_dict() == before,
			"longe: negado, sem custo, o nó não gasta")
	player.position = rock.position + Vector2(400, 0)
	before = player.to_dict()
	_check(authority.request_gather(1, authority.id_of(rock)) == RESULT.OUT_OF_RANGE and player.to_dict() == before,
			"toque na rocha de longe: negado, sem custo")
	# Alvo que não existe ou não é nó.
	_check(authority.request_gather(1, 99999) == RESULT.UNKNOWN_TARGET
		and authority.request_gather(1, authority.id_of(main.dino)) == RESULT.UNKNOWN_TARGET,
			"alvo inexistente ou que não é nó: negado")
	# Ator desconhecido (outro jogador que não existe): negado, nada muda.
	_near(main, wood)
	_check(authority.request_gather(7, authority.id_of(wood)) == RESULT.UNKNOWN_ACTOR and wood.is_available(), "ator desconhecido: negado")
	# Recarga do golpe: dois golpes no mesmo instante, o segundo é negado sem custo e o nó segue como estava.
	var hp := player.health.current_health
	_near(main, wood)
	player.facing = Vector2.UP
	_check(authority.request_gather(1, authority.id_of(wood)) == RESULT.OK, "preparo: primeiro golpe na árvore")
	hp = player.health.current_health
	_check(authority.request_gather(1, authority.id_of(wood)) == RESULT.COOLDOWN and wood.is_available()
			and player.health.current_health == hp and wood.component.has_damage(),
			"em recarga: negado, sem custo, o golpe não conta")
	# Esgotado.
	_strikes(main, wood, _hand_hits(wood))
	player.tick(60.0)
	main.authority.clock.advance(2.0)  # intervalo entre coletas
	hp = player.health.current_health
	_check(authority.request_gather(1, authority.id_of(wood)) == RESULT.WRONG_STATE and player.health.current_health == hp,
			"esgotado: negado, sem custo")
	# Sem espaço: nada é colhido nem cobrado.
	var bush: ResourceNode = null
	for candidate in main.resources.nodes():
		if bush == null and candidate.def.id == "bush_baga":
			bush = candidate
	_near(main, bush)
	for filler in [Items.STONE, Items.WOOD, Items.MEAT, Items.FERN, Items.SLEEP_FRUIT, Items.FIBER, Items.BERRY]:
		while player.inventory.room_for(filler) > 0 and player.inventory.add(filler, 1) == 0:
			pass  # `add` devolve o que NÃO coube: 0 = entrou
	hp = player.health.current_health
	var result := authority.request_gather(1, authority.id_of(bush))
	_check(result != RESULT.OK and bush.is_available() and player.health.current_health == hp,
			"sem espaço: negado, o nó não gasta, sem custo")
	# Morto não colhe nem se machuca.
	player.health.take_damage(10000.0)
	_check(authority.request_gather(1, authority.id_of(rock)) == RESULT.ACTOR_DEAD, "morto: negado")
	# Quem não é o jogador não colhe pela intenção da mira: sem alvo a recusa é clara.
	player.target = null
	_check(player.request_gather() != "", "sem alvo: recusa")


func _test_loose_stones() -> void:
	var tree := _root.get_tree()
	var main := _main("loose", 20, true)
	await tree.physics_frame
	var player := main.player
	var authority := main.authority
	var core: ResourceNode = null
	var trail: ResourceNode = null
	var fast := 0
	var slow := 0
	for node in main.resources.nodes():
		if node.def.id != "loose_stone":
			continue
		if node.component.respawn_total() == 300.0:
			fast += 1
			core = node if core == null else core
		else:
			slow += 1
			trail = node if trail == null else trail
	_check(fast == main.map.loose_core_count and fast == 10 and slow == 14,
			"o exportador manda: 10 pedras voltam em 300 s e 14 em 600 s (%d e %d)" % [fast, slow])
	var on_beach := 0
	for cell: Vector2i in main.map.nodes.get("loose_stone", []):
		if main.map.terrain_at(cell) == IslandMap.BEACH:
			on_beach += 1
	_check(on_beach == 0, "nenhuma pedra avulsa na praia")
	_check(core != null and trail != null, "há pedra avulsa no núcleo e na trilha")
	_check(core.component.respawn_total() == 300.0 and trail.component.respawn_total() == 600.0,
			"pedra do núcleo volta em 300 s, a da trilha em 600 s")
	_near(main, core)
	var hp := player.health.current_health
	var stones := player.inventory.count(Items.STONE)
	_check(authority.request_gather(1, authority.id_of(core)) == RESULT.OK
		and player.inventory.count(Items.STONE) == stones + core.def.yield_amount
			and player.health.current_health == hp and not core.is_available(), "pedra avulsa: coleta à mão, sem custo")
	main.player.position = core.position + Vector2(200, 0)  # o corpo em cima do lugar segura o nó (caixa de colisão)
	TestWorld.pass_time(main, 299.0)
	_check(not core.is_available(), "antes dos 300 s segue esgotada")
	TestWorld.pass_time(main, 1.0)
	_check(core.is_available(), "aos 300 s a pedra do núcleo volta")
	_near(main, trail)
	authority.request_gather(1, authority.id_of(trail))
	main.player.position = trail.position + Vector2(200, 0)
	TestWorld.pass_time(main, 300.0)
	_check(not trail.is_available(), "a pedra da trilha segue esgotada aos 300 s")
	TestWorld.pass_time(main, 300.0)
	_check(trail.is_available(), "aos 600 s a pedra da trilha volta")
