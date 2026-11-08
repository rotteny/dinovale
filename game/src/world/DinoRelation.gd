# SPDX-License-Identifier: MIT
class_name DinoRelation
extends RefCounted
## Quem pode ferir quem entre dinos (M1 etapa 5b, `m1-ameaca-e-corpo.md` seção 10.4). Regra pura, sem estado: a autoridade
## a consulta antes de aplicar qualquer dano de dino em dino. Nunca cita espécie por id: o tipo de atacante e o perfil de
## predação decidem.


static func is_carnivore(stats: DinoBaseStats) -> bool:
	return stats.attacker_kind == TamingRules.ATTACKER_CARNIVORE


static func is_herbivore(stats: DinoBaseStats) -> bool:
	return stats.attacker_kind == TamingRules.ATTACKER_HERBIVORE


## A parte da relação que vale para QUALQUER atacante de criatura (selvagem ou domado): nunca em si mesmo, nunca no
## mesmo bando. `may_strike` e o golpe do domado (`WorldAuthority._area_hit`) passam por aqui. A espécie fica só no
## `may_strike` (domado de dono diferente da mesma espécie se acerta com pvp ligado).
static func may_hit_creature(attacker: Dino, target: Dino) -> bool:
	if attacker == null or target == null or attacker == target:
		return false
	return attacker.herd_id == "" or attacker.herd_id != target.herd_id


## Só carnívoro contra herbívoro, nos dois sentidos. Nunca no mesmo bando, nunca da mesma espécie, nunca carnívoro contra
## carnívoro nem herbívoro contra herbívoro. Domado nunca ataca no M1 (a ordem de atacar é do M3).
static func may_strike(attacker: Dino, target: Dino) -> bool:
	if attacker == null or target == null or attacker == target:
		return false
	if attacker.owner_player_id != "" or attacker.state_machine.is_tamed:
		return false
	if attacker.stats.id == target.stats.id or not may_hit_creature(attacker, target):
		return false
	var a := attacker.stats
	var b := target.stats
	return (is_carnivore(a) and is_herbivore(b)) or (is_herbivore(a) and is_carnivore(b))


## A espécie `prey` é presa do perfil do caçador `hunter`? `pack_bonus` sobe um porte (bando acordado junto).
static func is_prey_species(hunter: DinoBaseStats, prey: DinoBaseStats, pack_bonus: bool = false) -> bool:
	var profile := hunter.predation
	if profile == null or prey.id == hunter.id or prey.id in profile.prey_exclude_ids:
		return false
	if is_carnivore(prey) or not (prey.attacker_kind in profile.prey_kinds):
		return false
	var allowed := int(hunter.size) + profile.max_prey_size_delta + (1 if pack_bonus else 0)
	return int(prey.size) <= allowed
