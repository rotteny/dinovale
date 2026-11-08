# SPDX-License-Identifier: MIT
class_name AreaAttackTests
extends TestSuite
## Dano em área (`documentacao/design/corte-v02/bandos-e-dano-em-area.md`, seção 4): uma frase testável por grupo.
## O Triceratops ainda não existe em `data/`; o atacante é um Grande de teste montado aqui.

const TILE := 16.0
const DAMAGE := 20.0
const TORPOR := 10.0
const OWNER := "local"
const PRIMARY_AT := Vector2(400.0, 0.0)


func run() -> void:
	_test_curve_data()
	_test_primary_full_and_secondaries_capped()
	_test_fraction_by_distance()
	_test_radius_and_min_fraction()
	_test_max_extra_targets()
	_test_never_hits_owner_allies_or_tamed()
	_test_wild_attacker_never_hits_wild()
	_test_wild_candidates_do_not_take_extra_slots()
	_test_others_tamed_switch()
	_test_area_uses_global_position()
	_test_skips_taming_and_unconscious()
	_test_torpor_uses_same_fraction()
	_test_events_like_direct_hit()
	_test_eligibility_and_taming_kind()


# ----------------------------------------------------------------------------- montagem

func _area(min_fraction: float = 0.05) -> AreaAttackRules:
	var area := AreaAttackRules.new()
	area.min_fraction = min_fraction
	return area


func _stats(size: Enums.DinoSize, area: AreaAttackRules) -> DinoBaseStats:
	var stats := DinoBaseStats.new()
	stats.id = "grande_de_teste"
	stats.size = size
	stats.attacker_kind = TamingRules.ATTACKER_HERBIVORE
	stats.area_attack = area
	return stats


func _dino(position: Vector2, stats: DinoBaseStats = null) -> Dino:
	var dino: Dino = DinoScene.instantiate()
	if stats != null:
		dino.stats = stats
	_root.add_child(dino)
	_track.call(dino)
	dino.set_physics_process(false)
	dino.position = position
	return dino


func _sleeping(dino: Dino) -> Dino:
	dino.torpor.add_torpor(dino.torpor.max_torpor)
	return dino


func _tamed(dino: Dino, owner: String) -> Dino:
	_sleeping(dino)
	dino.state_machine.mark_tamed()
	dino.owner_player_id = owner
	return dino


## Arena: atacante Grande domado do jogador "local" em (0,0) e `others` registrados depois do jogador. O alvo principal
## costuma ser o primeiro de `others`.
func _arena(attacker: Dino, others: Array) -> Dictionary:
	var player := _player_at(Vector2(-900.0, 0.0))
	player.player_id = OWNER
	var authority := TestWorld.arm(player, [attacker] + others, _track)
	return {"authority": authority, "player": player, "attacker_id": authority.id_of(attacker)}


func _player_at(position: Vector2) -> Player:
	var player: Player = PlayerScene.instantiate()
	_root.add_child(player)
	_track.call(player)
	player.set_physics_process(false)
	player.position = position
	return player


func _big_tamed(area: AreaAttackRules = null) -> Dino:
	return _tamed(_dino(Vector2.ZERO, _stats(Enums.DinoSize.LARGE, area if area != null else _area())), OWNER)


func _wild_at(tiles_from_main: float, angle: float = 0.0) -> Dino:
	return _dino(PRIMARY_AT + Vector2.from_angle(angle) * tiles_from_main * TILE)


func _hit(arena: Dictionary, main: Node, damage: float = DAMAGE, torpor: float = TORPOR) -> Dictionary:
	var authority: WorldAuthority = arena["authority"]
	return authority.resolve_area_attack(arena["attacker_id"], authority.id_of(main), damage, torpor)


func _lost(dino: Dino) -> float:
	return dino.health.max_health - dino.health.current_health


# ----------------------------------------------------------------------------- testes

func _test_curve_data() -> void:
	var area := _area()
	_check(is_equal_approx(area.fraction(0.0), 0.6) and is_equal_approx(area.fraction(1.0), 0.6), "área: até 1 tile vale 0,6")
	_check(is_equal_approx(area.fraction(2.0), 0.3) and is_equal_approx(area.fraction(2.5), 0.15),
			"área: de 1 a 3 tiles cai em linha reta (2 -> 0,3; 2,5 -> 0,15)")
	_check(area.fraction(3.0) == 0.0 and area.fraction(5.0) == 0.0, "área: 3 tiles ou mais não acerta")
	var previous := 1.0
	var monotonic := true
	for step in 61:
		var value := area.fraction(float(step) * 0.05)
		monotonic = monotonic and value <= previous
		previous = value
	_check(monotonic, "área: a fração nunca cresce com a distância")


func _test_primary_full_and_secondaries_capped() -> void:
	var main := _wild_at(0.0)
	var near := _wild_at(1.0, 1.0)
	var mid := _wild_at(2.0, 2.0)
	var arena := _arena(_big_tamed(), [main, near, mid])
	var hits := _hit(arena, main)
	_check(is_equal_approx(_lost(main), DAMAGE) and is_equal_approx(main.torpor.current_torpor, TORPOR),
			"área 1: o principal leva 100% do dano e do torpor")
	_check(hits.size() == 3 and hits.values().max() == 1.0, "área 1: devolve os três atingidos")
	_check(_lost(near) <= DAMAGE * 0.6 + 0.001 and _lost(mid) <= DAMAGE * 0.6 + 0.001, "área 1: nenhum secundário sofre mais de 60%")


func _test_fraction_by_distance() -> void:
	var main := _wild_at(0.0)
	var b := _wild_at(1.0, 2.0)
	var c := _wild_at(2.0, 3.5)
	var d := _wild_at(2.5, 5.0)
	var arena := _arena(_big_tamed(), [main, b, c, d])
	_hit(arena, main)
	_check(is_equal_approx(_lost(b), 12.0), "área 2: a 1 tile leva 0,6 do dano")
	_check(is_equal_approx(_lost(c), 6.0) and is_equal_approx(_lost(d), 3.0), "área 2: 2 tiles leva 0,3 e 2,5 tiles leva 0,15")
	_check(_lost(b) >= _lost(c) and _lost(c) >= _lost(d), "área 2: distância maior nunca causa mais dano")


func _test_radius_and_min_fraction() -> void:
	var main := _wild_at(0.0)
	var edge := _wild_at(3.0, 1.0)
	var far := _wild_at(6.0, 2.0)
	var faint := _wild_at(2.5, 3.0)
	var arena := _arena(_big_tamed(_area(0.2)), [main, edge, far, faint])
	var hits := _hit(arena, main)
	_check(_lost(edge) == 0.0 and _lost(far) == 0.0 and not hits.has(arena["authority"].id_of(edge)),
			"área 3: a 3 tiles ou mais não é acertado")
	_check(_lost(faint) == 0.0, "área 3: fração abaixo do mínimo (0,15 < 0,2) não acerta")


func _test_max_extra_targets() -> void:
	var main := _wild_at(0.0)
	# distâncias em px do principal: 4, 6, 12, 12 (empate com o anterior, id maior), 32, 34
	var offsets: Array[Vector2] = [
		Vector2(4.0, 0.0), Vector2(0.0, 6.0), Vector2(12.0, 0.0),
		Vector2(-12.0, 0.0), Vector2(0.0, 32.0), Vector2(0.0, -34.0)]
	var extras: Array = []
	for offset in offsets:
		extras.append(_dino(PRIMARY_AT + offset))
	var arena := _arena(_big_tamed(), [main] + extras)
	var hits := _hit(arena, main)
	var authority: WorldAuthority = arena["authority"]
	_check(hits.size() == 4, "área 4: principal + no máximo 3 extras (havia 6 candidatos)")
	_check(hits.has(authority.id_of(extras[0])) and hits.has(authority.id_of(extras[1])) and hits.has(authority.id_of(extras[2])),
			"área 4: valem os 3 mais próximos do principal")
	_check(not hits.has(authority.id_of(extras[3])) and _lost(extras[3]) == 0.0, "área 4: no empate de distância vale o id menor")
	_check(_lost(extras[4]) == 0.0 and _lost(extras[5]) == 0.0, "área 4: os mais longe ficam de fora")


func _test_never_hits_owner_allies_or_tamed() -> void:
	var main := _wild_at(0.0)
	var mine := _tamed(_dino(PRIMARY_AT + Vector2(8.0, 0.0)), OWNER)
	var foreign := _tamed(_dino(PRIMARY_AT + Vector2(0.0, 8.0)), "outro")
	var arena := _arena(_big_tamed(), [main, mine, foreign])
	var owner_body: Player = arena["player"]
	owner_body.position = PRIMARY_AT + Vector2(0.0, -8.0)
	var ally := _player_at(PRIMARY_AT + Vector2(-8.0, 0.0))
	ally.player_id = "aliado"
	var enemy := _player_at(PRIMARY_AT + Vector2(-12.0, 0.0))
	enemy.player_id = "inimigo"
	var authority: WorldAuthority = arena["authority"]
	authority.register(ally)
	authority.register(enemy)
	authority.ally_check = func(owner_id: String, other_id: String) -> bool: return owner_id == OWNER and other_id == "aliado"
	_hit(arena, main)
	_check(owner_body.health.current_health == owner_body.health.max_health, "área 5: o dono nunca é acertado")
	_check(ally.health.current_health == ally.health.max_health, "área 5: aliado do dono nunca é acertado")
	_check(_lost(mine) == 0.0 and _lost(foreign) == 0.0, "área 5: domado (do atacante ou de outro) nunca é acertado")
	_check(enemy.health.current_health < enemy.health.max_health, "área 5: jogador hostil perto do alvo é acertado")
	# o atacante não se acerta, nem o dono como principal
	var self_hit := authority.resolve_area_attack(arena["attacker_id"], arena["attacker_id"], DAMAGE, TORPOR)
	var owner_hit := authority.resolve_area_attack(arena["attacker_id"], authority.id_of(owner_body), DAMAGE, TORPOR)
	_check(self_hit.is_empty() and owner_hit.is_empty() and owner_body.health.current_health == owner_body.health.max_health,
			"área 5: nem a si, nem ao dono como alvo principal")


func _test_wild_attacker_never_hits_wild() -> void:
	var attacker := _dino(Vector2.ZERO, _stats(Enums.DinoSize.LARGE, _area()))
	var main := _wild_at(0.0)
	var neighbour := _wild_at(1.0)
	var arena := _arena(attacker, [main, neighbour])
	var victim := _player_at(PRIMARY_AT + Vector2(10.0, 0.0))
	victim.player_id = "vitima"
	arena["authority"].register(victim)
	_check(_hit(arena, main).is_empty() and _lost(main) == 0.0, "área 6: selvagem não acerta selvagem nem como alvo principal")
	var hits := _hit(arena, victim)
	_check(hits.size() == 1 and victim.health.current_health < victim.health.max_health and _lost(neighbour) == 0.0 and _lost(main) == 0.0,
			"área 6: selvagem acerta o jogador e continua poupando os selvagens ao redor")


## A guarda "selvagem não acerta selvagem" é do PRÓPRIO candidato: selvagem que só falharia no `_area_hit` ainda
## ocuparia uma das vagas de extras e pouparia o jogador logo atrás.
func _test_wild_candidates_do_not_take_extra_slots() -> void:
	var attacker := _dino(Vector2.ZERO, _stats(Enums.DinoSize.LARGE, _area()))
	var victim := _player_at(PRIMARY_AT)
	victim.player_id = "vitima"
	var crowd: Array = []
	for offset in [Vector2(2.0, 0.0), Vector2(0.0, 3.0), Vector2(-4.0, 0.0)]:
		crowd.append(_dino(PRIMARY_AT + offset))
	var behind := _player_at(PRIMARY_AT + Vector2(0.0, 20.0))
	behind.player_id = "atras"
	var arena := _arena(attacker, crowd)
	arena["authority"].register(victim)
	arena["authority"].register(behind)
	var hits := _hit(arena, victim)
	_check(hits.has(arena["authority"].id_of(behind)) and behind.health.current_health < behind.health.max_health,
			"área 6b: selvagens não gastam vaga de extra; o jogador mais longe é acertado")


## PvP (`WorldAuthority.pvp_enabled`, chave de servidor `pvp`): desligado, o domado de OUTRO fica fora da área; ligado,
## entra; o do mesmo dono, nunca.
func _test_others_tamed_switch() -> void:
	var main := _wild_at(0.0)
	var mine := _tamed(_dino(PRIMARY_AT + Vector2(8.0, 0.0)), OWNER)
	var foreign := _tamed(_dino(PRIMARY_AT + Vector2(0.0, 8.0)), "outro")
	var arena := _arena(_big_tamed(), [main, mine, foreign])
	var authority: WorldAuthority = arena["authority"]
	_check(not authority.pvp_enabled, "área 7: padrão sem PvP")
	_hit(arena, main)
	_check(_lost(foreign) == 0.0 and _lost(mine) == 0.0, "área 7: sem PvP, domado de terceiros fora da área")
	authority.pvp_enabled = true
	_hit(arena, main)
	_check(_lost(foreign) > 0.0 and _lost(mine) == 0.0, "área 7: com PvP, só o domado de outro é acertado")


## O alcance da área mede em `global_position` (nó dentro de pai deslocado ainda conta pela posição real).
func _test_area_uses_global_position() -> void:
	var main := _wild_at(0.0)
	var shifted := _dino(Vector2.ZERO)
	var holder := Node2D.new()
	holder.position = PRIMARY_AT + Vector2(6.0, 0.0)
	_root.add_child(holder)
	_track.call(holder)
	shifted.reparent(holder, false)
	var arena := _arena(_big_tamed(), [main, shifted])
	var hits := _hit(arena, main)
	_check(hits.has(arena["authority"].id_of(shifted)), "área 8: a distância usa a posição global")


func _test_skips_taming_and_unconscious() -> void:
	var main := _wild_at(0.0)
	var taming := _sleeping(_wild_at(1.0, 1.0))
	var efficiency := taming.taming.efficiency
	var dead_player := _player_at(PRIMARY_AT + Vector2(6.0, 0.0))
	dead_player.player_id = "caido"
	dead_player.health.take_damage(dead_player.health.max_health)
	var arena := _arena(_big_tamed(), [main, taming])
	arena["authority"].register(dead_player)
	var hits := _hit(arena, main)
	_check(taming.taming.is_active() and _lost(taming) == 0.0 and taming.taming.efficiency == efficiency
			and taming.torpor.current_torpor == taming.torpor.max_torpor,
			"área 7: quem está sendo domado não é acertado (vida e Eficiência intactas)")
	_check(hits.size() == 1, "área 8: inconsciente ou morto que não é o principal não leva a área")
	var direct := _hit(arena, taming)
	_check(direct.has(arena["authority"].id_of(taming)) and _lost(taming) == DAMAGE and taming.taming.efficiency < efficiency,
			"área 7/8: como alvo principal, o dormindo leva o golpe cheio e perde Eficiência")


func _test_torpor_uses_same_fraction() -> void:
	var main := _wild_at(0.0)
	var mid := _wild_at(2.0, 1.0)
	var arena := _arena(_big_tamed(), [main, mid])
	_hit(arena, main, DAMAGE, 40.0)
	_check(is_equal_approx(mid.torpor.current_torpor, 12.0) and is_equal_approx(_lost(mid), 6.0),
			"área 9: torpor e vida do secundário usam a mesma fração (0,3)")


func _test_events_like_direct_hit() -> void:
	var main := _wild_at(0.0)
	var doomed := _wild_at(1.0, 1.0)
	var dozer := _wild_at(1.0, 3.0)
	var arena := _arena(_big_tamed(), [main, doomed, dozer])
	var events := {"died": 0, "knocked": 0}
	doomed.health.died.connect(func() -> void: events["died"] += 1)
	dozer.torpor.knocked_out.connect(func() -> void: events["knocked"] += 1)
	_hit(arena, main, 1000.0, 1000.0)
	_check(doomed.health.is_dead() and events["died"] == 1, "área 10: secundário que morre emite `died`")
	_check(dozer.health.is_dead() or events["knocked"] == 1, "área 10: secundário que desmaia emite `knocked_out`")
	var main2 := _wild_at(0.0)
	var sleepy := _wild_at(1.0, 1.0)
	var arena2 := _arena(_big_tamed(), [main2, sleepy])
	var knocked := [0]
	sleepy.torpor.knocked_out.connect(func() -> void: knocked[0] += 1)
	_hit(arena2, main2, 5.0, sleepy.torpor.max_torpor / 0.6 + 1.0)
	_check(knocked[0] == 1 and not sleepy.health.is_dead(), "área 10: só o desmaio, sem morte, emite `knocked_out`")


func _test_eligibility_and_taming_kind() -> void:
	var medium := _tamed(_dino(Vector2.ZERO, _stats(Enums.DinoSize.MEDIUM, _area())), OWNER)
	var plain := _tamed(_dino(Vector2.ZERO, _stats(Enums.DinoSize.LARGE, null)), OWNER)
	var main := _wild_at(0.0)
	var near := _wild_at(1.0)
	var arena := _arena(medium, [main, near, plain])
	_check(_hit(arena, main).is_empty() and _lost(main) == 0.0, "elegibilidade: porte que não é Grande não tem área, mesmo com o dado")
	var authority: WorldAuthority = arena["authority"]
	var plain_hits := authority.resolve_area_attack(authority.id_of(plain), authority.id_of(main), DAMAGE, TORPOR)
	_check(plain_hits.is_empty(), "elegibilidade: Grande sem `area_attack` não tem área")
	var victim := _wild_at(0.0)
	_check(victim.receive_hit(1.0, 0.0, TamingRules.ATTACKER_HERBIVORE) and not victim.receive_hit(1.0, 0.0, "alienigena"),
			"doma: `herbivore` é tipo conhecido (dado em taming_rules.tres); tipo desconhecido segue recusado")
