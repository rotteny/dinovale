# SPDX-License-Identifier: MIT
class_name CombatService
extends Node
## Resolução de golpe de criatura (E7a, extraída da `WorldAuthority`, que segue como fachada pública): golpe em área, golpe de
## um alvo, quem pode ferir quem, o pedido de golpe do bravo, empurrão e chamada do bando. Filho da autoridade; o pedido do
## jogador (`request_attack`) continua nela, porque fecha a resposta com o motivo.

var authority: WorldAuthority = null

## Último episódio de agressão anunciado por criatura (`entity_id` -> episódio): `dino_hit_player` sai uma vez por episódio.
var _announced_episode: Dictionary = {}
## Último golpe aceito por criatura (`entity_id` -> `ThreatCycle.strike_count`): um golpe do ciclo vale um pedido só.
var _last_strike: Dictionary = {}


## A criatura saiu do mundo: esquece o que guardava dela.
func forget(entity_id: int) -> void:
	_announced_episode.erase(entity_id)
	_last_strike.erase(entity_id)


## Golpe em área de uma criatura (não é intenção de jogador: quem chama é o servidor, quando a IA ataca).
## `attacker_id` precisa ter `area_rules()` (porte Grande com dado). O alvo principal leva o golpe inteiro; os
## secundários, a fração de `AreaAttackRules.fraction` do dano e do torpor, até `max_extra_targets`, os mais
## próximos do principal (empate: id menor). Nunca acerta o dono, os aliados dele nem domados (os de terceiros só com
## `authority.pvp_enabled`, chave de servidor `pvp`, padrão falso); selvagem só acerta jogador; quem está
## sendo domado ou já caiu só leva se for o principal. Devolve `{entity_id: fração}` dos atingidos (vazio se o principal não foi acertado).
func resolve_area_attack(attacker_id: int, target_id: int, damage: float, torpor_amount: float) -> Dictionary:
	var attacker := authority.entity(attacker_id) as Dino
	var main_target := authority.entity(target_id) as Node2D
	var hits: Dictionary = {}
	if attacker == null or main_target == null or main_target == attacker or damage < 0.0 or torpor_amount < 0.0:
		return hits
	var area := attacker.stats.area_rules()
	if area == null or attacker.health.is_dead() or attacker.state_machine.current_id == Enums.DinoStateId.UNCONSCIOUS:
		return hits
	if not _area_hit(attacker, main_target, damage, torpor_amount, 1.0):
		return hits
	hits[target_id] = 1.0
	var tile := float(attacker.level_rules.tile_size)
	var extras: Array = []
	for candidate_id: int in authority.entity_ids():
		var node := authority.entity(candidate_id) as Node2D
		if node == null or node == attacker or node == main_target or not _area_candidate(attacker, node):
			continue
		var fraction := area.fraction(node.global_position.distance_to(main_target.global_position) / tile)
		if fraction > 0.0:
			extras.append({"id": candidate_id, "fraction": fraction, "distance": node.global_position.distance_to(main_target.global_position)})
	extras.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["distance"] < b["distance"] or (a["distance"] == b["distance"] and a["id"] < b["id"]))
	for extra: Dictionary in extras.slice(0, area.max_extra_targets):
		var node := authority.entity(extra["id"]) as Node2D
		if _area_hit(attacker, node, damage, torpor_amount, extra["fraction"]):
			hits[extra["id"]] = extra["fraction"]
	return hits


## Golpe de uma criatura selvagem ou domada no alvo `target_id`, de um só alvo. Porte Grande com `area_attack` vai pelo
## golpe em área (`resolve_area_attack`, sem torpor); os demais acertam só o principal, pelas MESMAS regras de quem pode
## ser acertado (dono e aliados nunca; dino domado de outro dono só com `authority.pvp_enabled`). Devolve `{entity_id: fração}`.
func resolve_dino_attack(attacker_id: int, target_id: int, damage: float) -> Dictionary:
	var attacker := authority.entity(attacker_id) as Dino
	var target := authority.entity(target_id) as Node2D
	if attacker == null or target == null or target == attacker or damage < 0.0:
		return {}
	var target_dino := target as Dino
	if target_dino != null and not attacker.state_machine.is_tamed and attacker.owner_player_id == "":
		return {target_id: 1.0} if _creature_bite(attacker, target_dino, damage) else {}  # selvagem em criatura: só `may_strike`
	if attacker.stats.area_rules() != null:
		return resolve_area_attack(attacker_id, target_id, damage, 0.0)
	if attacker.health.is_dead() or attacker.state_machine.current_id == Enums.DinoStateId.UNCONSCIOUS:
		return {}
	return {target_id: 1.0} if _area_hit(attacker, target, damage, 0.0, 1.0) else {}


## Quem pode ferir quem (a única porta do dano de selvagem em criatura): jogador contra jogador e domado são de outras
## regras; aqui, jogador vivo e hostil ao selvagem, ou criatura segundo `DinoRelation.may_strike` (carnívoro contra herbívoro,
## nunca no mesmo bando, nunca da mesma espécie) com os dois vivos e o atacante acordado.
func may_strike(attacker: Dino, target: Node2D) -> bool:
	if attacker == null or target == null or attacker.health.is_dead() \
			or attacker.state_machine.current_id == Enums.DinoStateId.UNCONSCIOUS:
		return false
	var player := target as Player
	if player != null:
		return _hostile_player(attacker, player)
	var dino := target as Dino
	return dino != null and not dino.health.is_dead() and DinoRelation.may_strike(attacker, dino)


## Mordida de selvagem em criatura: aplica o dano se `may_strike` deixa, atrasa a presa ferida e avisa a morte.
func _creature_bite(attacker: Dino, target: Dino, damage: float) -> bool:
	if not may_strike(attacker, target) or (authority.bite_filter.is_valid() and not authority.bite_filter.call(attacker, target)) \
			or not target.be_bitten(damage, attacker):
		return false
	var profile := attacker.stats.predation
	if profile != null and not target.health.is_dead():
		target.state_machine.apply_wound(profile.wound_slow_factor, profile.wound_slow_seconds)
	if target.health.is_dead():
		authority.predator_kill.emit(attacker, target)
	return true


## O corpo de um atacante pelo id de combate (`player_id` ou `dino:<id>`); null se saiu do mundo.
func attacker_body(attacker_id: String) -> Node2D:
	if attacker_id.begins_with("dino:"):
		return authority.entity(attacker_id.trim_prefix("dino:").to_int()) as Node2D
	return authority.player_body(attacker_id) as Node2D


## Um selvagem foi golpeado e está bravo: o bando dele é chamado contra o mesmo atacante (jogador ou criatura).
func on_dino_provoked(dino: Dino, attacker_id: String) -> void:
	var attacker := attacker_body(attacker_id)
	if attacker == null:
		return
	var others: Array[Dino] = []
	for id: int in authority.entity_ids():
		var other := authority.entity(id) as Dino  # `entity` pula nó liberado (o cast direto de um liberado é erro de script)
		if other != null:
			others.append(other)
	authority.herd.raise_call(dino, attacker_id, attacker.global_position, others, attacker)


## O bravo pediu um golpe (`Dino.attack_requested`): confere o alcance contra a posição REAL dos dois, aplica o dano e
## anuncia o primeiro golpe que acertou de cada episódio. Recusa: sem perfil na espécie, dano acima do da espécie
## (`base_damage`), dino que não está bravo, fora da fase de golpe, golpe do ciclo já atendido (a recarga) ou fora do alcance.
func on_dino_attack(dino: Dino, target: Node2D, damage: float, episode: int) -> void:
	var profile := dino.stats.threat_profile
	var attacker_id := authority.id_of(dino)
	var target_id := authority.id_of(target)
	if profile == null or attacker_id == 0 or target_id == 0 or damage > dino.stats.base_damage:
		return
	var cycle := dino.state_machine.threat_cycle
	if cycle == null or not dino.state_machine.is_aggressive or cycle.phase != Enums.ThreatPhase.LUNGE \
			or cycle.cooldown_left < profile.cooldown_s - 0.001 or _last_strike.get(attacker_id, -1) == cycle.strike_count:
		return
	if dino.global_position.distance_to(target.global_position) > profile.attack_reach_px + profile.reach_slack_px:
		return
	if authority.build.grid.segment_blocked(dino.global_position, target.global_position):
		return  # parede ou porta fechada entre os dois: a mordida não atravessa (a distância sozinha não basta)
	_last_strike[attacker_id] = cycle.strike_count
	var hits := resolve_dino_attack(attacker_id, target_id, damage)
	_knock_back(dino, target, profile, hits.has(target_id))
	if hits.has(target_id):
		dino.state_machine.confirm_hit()
	if hits.has(target_id) and target is Player:
		dino.bit_player_episode = episode
	if hits.has(target_id) and target is Player and _announced_episode.get(attacker_id, 0) != episode:
		_announced_episode[attacker_id] = episode
		authority.announce("dino_hit_player", {"species": dino.stats.display_name, "amount": snappedf(damage, 0.1)})


## Empurrão do golpe que acertou: só o jogador, só se ainda está de pé depois do dano, sempre para longe de quem bateu.
func _knock_back(dino: Dino, target: Node2D, profile: ThreatProfile, landed: bool) -> void:
	var player := target as Player
	if not landed or player == null or player.is_incapacitated() or profile.knockback_px <= 0.0:
		return
	var away := target.global_position - dino.global_position
	if away.length_squared() > 0.0001:
		player.knock_back(away.normalized() * profile.knockback_px, profile.knockback_seconds)


## O jogador pode ser acertado pela criatura? Vivo, e nem o dono dela nem aliado do dono. Caído: só por quem ataca o
## caído (`ThreatProfile.attacks_downed`; o Paquicéfalo não, o Utahraptor sim).
func _hostile_player(attacker: Dino, player: Player) -> bool:
	var owner_id := attacker.owner_player_id
	if player.health.is_dead():
		return false
	if player.downed.is_downed and not attacker.attacks_downed():
		return false
	if owner_id == "":
		return true
	return player.player_id != owner_id and not (authority.ally_check.is_valid() and authority.ally_check.call(owner_id, player.player_id))


## O nó pode ser SECUNDÁRIO do golpe em área de `attacker`? (O principal só passa pelo `_area_hit`.)
func _area_candidate(attacker: Dino, node: Node) -> bool:
	if node is Player:
		return _hostile_player(attacker, node as Player)
	var dino := node as Dino
	if dino == null or dino.health.is_dead():
		return false
	if not attacker.state_machine.is_tamed:
		return false  # selvagem não acerta selvagem
	if dino.state_machine.is_tamed:
		# Domado do mesmo dono nunca. Domado de OUTRO só com PvP ligado (`authority.pvp_enabled`).
		if not authority.pvp_enabled or dino.owner_player_id == attacker.owner_player_id:
			return false
	return not dino.taming.is_active() and dino.state_machine.current_id != Enums.DinoStateId.UNCONSCIOUS


## Aplica o golpe (já multiplicado por `fraction`) em `node`; false se ele não pode ser acertado.
func _area_hit(attacker: Dino, node: Node, damage: float, torpor_amount: float, fraction: float) -> bool:
	var player := node as Player
	if player != null:
		if not _hostile_player(attacker, player):
			return false
		player.health.take_damage(damage * fraction)
		return true
	var dino := node as Dino
	if dino == null or not attacker.state_machine.is_tamed or attacker == dino:
		return false  # selvagem não acerta selvagem (nem o principal)
	if not dino.state_machine.is_tamed and not DinoRelation.may_hit_creature(attacker, dino):
		return false  # em selvagem: bando nunca (regra única de relação)
	if dino.state_machine.is_tamed:  # só com a chave ligada, e só de outro dono: leva dano (sem torpor: já está domado)
		return authority.pvp_enabled and dino.owner_player_id != attacker.owner_player_id and not dino.health.is_dead() \
				and dino.take_damage(damage * fraction, attacker.stats.attacker_kind)
	return dino.receive_hit(damage * fraction, torpor_amount * fraction, attacker.stats.attacker_kind)
