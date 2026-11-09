# SPDX-License-Identifier: MIT
class_name PredationSystem
extends Node
## Cérebro da caça (M1 etapa 5b, `m1-ameaca-e-corpo.md` seção 10). Lê só os dinos ATIVOS (a até `active_radius_tiles` de um
## foco, em modo ativo na `DinoZone`), nunca os 360 do mundo, e decide o alvo de cada carnívoro (espécie com `PredationProfile`):
## o mais próximo entre o jogador e as presas elegíveis, só dentro do alcance de agressividade da espécie. O dano e a morte
## continuam da autoridade (`WorldAuthority.may_strike`): aqui só se escolhe o alvo (`Dino.hunt_target`), se avisa a presa
## (alarme e fuga), se come (a carcaça de caça nunca fica no mundo) e se descansa (saciedade).
##
## E3 (`corte-v02/e3-toca-e-vigilia.md`): a âncora da toca (`DinoHome`) e o núcleo seguro único (`SafeCore`) limitam quem é
## alvo e onde o caçador anda; o selvagem dormindo em doma, ao alcance do ronco, é um tipo de presa DESTE sistema (fase de
## farejada, sem sistema paralelo).
##
## Estado de caça e de refeição não vai para o save; só `Dino.sated_until` vai. Sem varredura de 360 dinos por caçador:
## a lista ativa é refeita a cada `ZoneRules.reevaluate_seconds`. `tick(delta)` é público (testável sem quadros).

## Caçada de um carnívoro (um registro por caçador ativo).
class Hunt extends RefCounted:
	var hunter: Dino
	var target: Node2D = null  # alvo travado: jogador ou presa
	var prey: Dino = null  # o alvo, se for criatura
	var lock_age := 0.0
	var age := 0.0
	var unseen := 0.0
	var eval_left := 0.0
	var bite_mark := 0  # `Dino.bite_count` da presa na última conferência: mudou = mordida de criatura (dano do jogador não conta)
	var bitten := false
	var damage_mark := 0
	var released_for_player := false  # já largou a presa e reiniciou o episódio por causa do jogador (uma vez só)
	var player_fixed := false  # o jogador bateu nele (ou foi mordido por ele) neste episódio: não troca para presa
	var alert_left := 0.0  # farejada ("!") antes de perseguir o dormindo; o caçador fica parado (`holding`)
	var sniffing := false
	var eating := false
	var carcass: ResourceNode = null
	var meat0 := 0
	var eat_total := 0.0
	var eat_elapsed := 0.0


## O caçador farejou o dormindo em doma (a apresentação mostra o "!" laranja e toca o som). Uma vez por trava.
signal sleeper_alerted(hunter: Dino, prey: Dino)

@export var rules: PredationRules = preload("res://data/balance/predation_rules.tres"):
	set(value):
		rules = value
		_core = null
@export var respawn_rules: RespawnRules = preload("res://data/balance/respawn_rules.tres"):
	set(value):
		respawn_rules = value
		_core = null
var zone: DinoZone = null
var carcasses: CarcassField = null
var ground: GroundItemField = null
## Autoridade: o sistema escuta as mortes por golpe de criatura e se oferece como filtro de mordida (piso do bando).
var authority: WorldAuthority = null:
	set(value):
		authority = value
		if value != null:
			value.predator_kill.connect(_on_kill)
			value.bite_filter = allows_bite
## Testes de distância feitos desde a criação (A30: uma reavaliação custa no máximo P x A + P).
var distance_tests := 0
## Quantas vezes o bônus de bando foi calculado (uma por caçador em cada avaliação, não uma por presa).
var pack_evaluations := 0

var _core: SafeCore = null
var _hunts: Dictionary = {}  # Dino -> Hunt
var _active: Array[Dino] = []
var _active_set: Dictionary = {}  # Dino -> true
var _hunters: Array[Dino] = []
var _herds: Dictionary = {}  # herd_id -> {count, sum}
var _refresh_left := 0.0
var _fail_until: Dictionary = {}  # chave da presa -> instante
var _attack_logged: Dictionary = {}  # id de combate da presa -> instante de rearme (INF = caçada em curso)


func _physics_process(delta: float) -> void:
	tick(delta)


## Passo de tempo: refaz a lista ativa quando vence e avança cada caçador ativo.
func tick(delta: float) -> void:
	if zone == null or authority == null:
		return
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		refresh_active()
	var now := _now()
	for hunter in _hunters:
		if is_instance_valid(hunter) and not hunter.is_queued_for_deletion():
			_step(_hunt_of(hunter), delta, now)


## Refaz a lista de dinos ativos (a até o raio ativo de um foco), os caçadores e a contagem dos bandos selvagens.
func refresh_active() -> void:
	_refresh_left = zone.rules.reevaluate_seconds
	_active.clear()
	_active_set.clear()
	_hunters.clear()
	_herds.clear()
	var radius := zone.rules.active_radius_tiles * _tile()
	for dino in zone.dinos():
		if dino.health.is_dead() or dino.is_queued_for_deletion():
			continue
		if _is_wild(dino) and dino.herd_id != "":
			var herd: Dictionary = _herds.get(dino.herd_id, {"count": 0, "sum": Vector2.ZERO})
			herd["count"] = int(herd["count"]) + 1
			herd["sum"] = (herd["sum"] as Vector2) + dino.global_position
			_herds[dino.herd_id] = herd
		if zone.mode_of(dino) != ActivityZone.Mode.ACTIVE or _focus_distance(dino.global_position) > radius:
			continue
		_active.append(dino)
		_active_set[dino] = true
		if _is_hunter(dino):
			_hunters.append(dino)
			dino.state_machine.safe_core = safe_core()
	for hunter: Variant in _hunts.keys():
		if not is_instance_valid(hunter) or (hunter as Dino).is_queued_for_deletion():
			var gone := _hunts[hunter] as Hunt
			_hunts.erase(hunter)
			_end_prey_log(gone, _now())  # caçador morto: o episódio do domado acaba (o aviso rearma depois)
		elif not _active_set.has(hunter) and not (_hunts[hunter] as Hunt).eating:
			_release(_hunts[hunter] as Hunt, _now(), false)
			_hunts.erase(hunter)


## Alvo de caça do carnívoro agora (null = nenhum ou o jogador): para teste e diagnóstico.
func target_of(hunter: Dino) -> Node2D:
	var hunt := _hunts.get(hunter) as Hunt
	return hunt.target if hunt != null else null


func is_eating(hunter: Dino) -> bool:
	var hunt := _hunts.get(hunter) as Hunt
	return hunt != null and hunt.eating


## Segundos de saciedade que restam ao carnívoro.
func sated_left(hunter: Dino) -> float:
	return maxf(hunter.sated_until - _now(), 0.0)


## Filtro de mordida da autoridade: a mordida de caçador em presa selvagem só vale com o bando acima do piso (vivos AGORA),
## senão duas mordidas no mesmo quadro passariam pelo piso. Domado e mordida de presa em caçador não passam por aqui.
func allows_bite(attacker: Dino, target: Dino) -> bool:
	if attacker.stats.predation == null or target.state_machine.is_tamed or target.owner_player_id != "":
		return true
	if _is_sleeper(target):
		var hunt := _hunts.get(attacker) as Hunt
		if hunt != null and attacker.stats.predation.switch_to_player_on_damage \
				and attacker.player_damage_count != hunt.damage_mark:
			return false  # o jogador bateu no caçador neste quadro: a mordida no dormindo não sai
		return rules.sleeper_ignores_herd_floor or _live_herd_count(target) > rules.herd_floor_alive
	return _live_herd_count(target) > rules.herd_floor_alive


# ----------------------------------------------------------------------------- elegibilidade

func _is_wild(dino: Dino) -> bool:
	return not dino.state_machine.is_tamed and dino.owner_player_id == ""


## O núcleo seguro único (um dado: região de nascimento + `spawn_safe_margin_tiles`).
func safe_core() -> SafeCore:
	if _core == null:
		_core = SafeCore.new(respawn_rules, rules.spawn_safe_margin_tiles, _tile())
	return _core


## Selvagem dormindo (em doma): a vigília com ameaça (E3b). Domado nunca é "dormindo" aqui.
func _is_sleeper(prey: Dino) -> bool:
	return prey.state_machine.current_id == Enums.DinoStateId.UNCONSCIOUS and _is_wild(prey)


## Alcance do ronco do dormindo para este caçador, em pixels: o ronco (com o bônus da comida de doma) até o teto da espécie.
func _snore_px(hunter: Dino, prey: Dino) -> float:
	var tiles := prey.taming.rules.snore_range(prey.taming.ideal_food)
	var cap := hunter.stats.predation.sleeper_range_cap_tiles
	return (minf(tiles, cap) if cap > 0.0 else tiles) * _tile()


## O ponto está vedado ao caçador: dentro do núcleo seguro ou fora da âncora da toca dele.
func _barred(hunter: Dino, point: Vector2) -> bool:
	if safe_core().contains(point):
		return true
	var home := hunter.state_machine.home
	return home != null and not home.in_anchor(point)


## A presa está ao alcance de percepção do caçador? Elipse para o resto, círculo do ronco para o dormindo.
func _in_view(hunter: Dino, prey: Dino) -> bool:
	if _is_sleeper(prey):
		return hunter.global_position.distance_to(prey.global_position) <= _snore_px(hunter, prey)
	return _effective(hunter, prey.global_position) <= hunter.stats.perception_tiles * _tile()


func _is_hunter(dino: Dino) -> bool:
	return dino.stats.predation != null and dino.stats.threat_profile != null and _is_wild(dino)


## A criatura `prey` é presa de `hunter` agora? `fresh` confere também o que só vale ao escolher (recuo, piso do bando).
func _prey_ok(hunter: Dino, prey: Dino, now: float, fresh: bool, pack: bool) -> bool:
	if prey == hunter or not is_instance_valid(prey) or prey.is_queued_for_deletion() or prey.health.is_dead():
		return false
	if not _active_set.has(prey) or _barred(hunter, prey.global_position) \
			or not DinoRelation.is_prey_species(hunter.stats, prey.stats, pack):
		return false
	if prey.state_machine.is_tamed:
		return prey.owner_player_id != ""  # domado do jogador: acordado ou dormindo, sem piso de bando
	var cooling := fresh and (_fail_until.get(_fail_key(prey), 0.0) as float) > now
	if prey.owner_player_id != "" or cooling:
		return false
	if _is_sleeper(prey):  # E3b (reverte o D15): em doma é presa de quem escuta o ronco; o alcance é do `_collect_prey`
		return _sleeper_prey_ok(hunter, prey)
	return int(_herds.get(prey.herd_id, {}).get("count", 1)) > rules.herd_floor_alive


func _sleeper_prey_ok(hunter: Dino, prey: Dino) -> bool:
	return rules.sleeper_is_prey and hunter.stats.predation.hears_sleepers \
			and (rules.sleeper_ignores_herd_floor or int(_herds.get(prey.herd_id, {}).get("count", 1)) > rules.herd_floor_alive)


func _pack_bonus(hunter: Dino) -> bool:
	pack_evaluations += 1
	var needed := hunter.stats.predation.pack_size_bonus_min_members
	if needed <= 0:
		return false
	var count := 0
	var radius := rules.pack_radius_tiles * _tile()
	for other in _hunters:
		if is_instance_valid(other) and other.herd_id == hunter.herd_id and other.herd_id != "" \
				and other.state_machine.current_id != Enums.DinoStateId.UNCONSCIOUS \
				and other.global_position.distance_to(hunter.global_position) <= radius:
			count += 1
	return count >= needed


func _fail_key(prey: Dino) -> String:
	if prey.state_machine.is_tamed or _is_sleeper(prey):  # o fracasso com um dormindo não imuniza o bando todo
		return prey.combat_id if prey.combat_id != "" else String(prey.name)
	return prey.herd_id if prey.herd_id != "" else String(prey.name)


func _live_herd_count(target: Dino) -> int:
	if target.herd_id == "" or zone == null:
		return 1
	var count := 0
	for dino in zone.dinos():
		if dino.herd_id == target.herd_id and _is_wild(dino) and not dino.health.is_dead():
			count += 1
	return count


# ----------------------------------------------------------------------------- passo de um caçador

func _hunt_of(hunter: Dino) -> Hunt:
	var hunt := _hunts.get(hunter) as Hunt
	if hunt == null:
		hunt = Hunt.new()
		hunt.hunter = hunter
		hunt.damage_mark = hunter.player_damage_count
		hunt.eval_left = float(hunter.combat_id.hash() % 997) / 997.0 * hunter.stats.predation.reevaluate_s  # fase por id
		_hunts[hunter] = hunt
	return hunt


func _step(hunt: Hunt, delta: float, now: float) -> void:
	var hunter := hunt.hunter
	if hunter.health.is_dead() or hunter.state_machine.current_id == Enums.DinoStateId.UNCONSCIOUS:
		_release(hunt, now, false)
		return
	if hunt.eating:
		_step_eat(hunt, delta, now)
		return
	if safe_core().contains(hunter.global_position) \
			or (hunter.state_machine.home != null and not hunter.state_machine.home.in_anchor(hunter.global_position)):
		if hunt.target != null:  # dentro do núcleo seguro ou fora da âncora: larga e volta (H3, H4)
			_release(hunt, now, false)
		return
	if not hunter.state_machine.is_aggressive:
		hunt.player_fixed = false
		hunt.released_for_player = false
	hunt.lock_age += delta
	hunt.eval_left -= delta
	if hunt.sniffing:
		hunt.alert_left -= delta
		if hunt.alert_left <= 0.0:
			_end_sniff(hunt)
	if hunt.prey != null and _is_sleeper(hunt.prey) and _provoked(hunt):  # a pancada vale já, não só a cada 0,5 s
		_switch_to_player(hunt, now)
		return
	if hunt.prey != null:
		_step_prey(hunt, delta, now)
	if hunt.eval_left <= 0.0:
		hunt.eval_left = hunter.stats.predation.reevaluate_s
		_reevaluate(hunt, now)


## Confere a presa travada a cada quadro: morreu, mudou de estado, sumiu, cansou ou o caçador recuou. Em alarme, ela foge.
func _step_prey(hunt: Hunt, delta: float, now: float) -> void:
	var hunter := hunt.hunter
	var prey := hunt.prey
	var profile := hunter.stats.predation
	var home := hunter.state_machine.home
	if home != null and not home.in_anchor(prey.global_position):  # a presa fugiu da âncora: a caçada falha (H3)
		_release(hunt, now, true)
		return
	if not _prey_ok(hunter, prey, now, false, _pack_bonus(hunter)):
		_release(hunt, now, false)
		return
	hunt.age += delta
	if prey.bite_count != hunt.bite_mark:
		hunt.bitten = true
		if _is_sleeper(prey):
			_warn_feeder(prey, hunter, now)
	hunt.bite_mark = prey.bite_count
	var tile := _tile()
	if _in_view(hunter, prey):
		hunt.unseen = 0.0
	else:
		hunt.unseen += delta
	var retreat := hunter.health.current_health < hunter.health.max_health * profile.retreat_health_ratio
	if retreat or hunt.age >= profile.hunt_max_seconds or hunt.unseen >= profile.no_sight_seconds \
			or hunter.global_position.distance_to(prey.global_position) > hunter.stats.chase_give_up_tiles * tile:
		_release(hunt, now, true)
		return
	if hunter.global_position.distance_to(prey.global_position) < rules.prey_alarm_tiles * tile:
		_alarm(hunt, now)


## A presa travada com o carnívoro perto: o domado avisa o dono (um aviso por episódio) e todos fogem se acordados.
func _alarm(hunt: Hunt, now: float) -> void:
	var prey := hunt.prey
	var machine := prey.state_machine
	if machine.current_id == Enums.DinoStateId.UNCONSCIOUS and not machine.is_tamed:
		return  # o dormindo não foge nem chama o bando (D-E8)
	if machine.is_tamed:
		_warn_owner(prey, hunt.hunter, now)
	var herd: Dictionary = _herds.get(prey.herd_id, {})
	var known := not machine.is_tamed and int(herd.get("count", 0)) > 0
	var center: Vector2 = (herd["sum"] as Vector2) / float(herd["count"]) if known else Vector2.ZERO
	machine.begin_flee(hunt.hunter.global_position, rules.flee_hold_seconds, center, known)


func _warn_owner(prey: Dino, hunter: Dino, now: float) -> void:
	var key := _log_key(prey)
	if _attack_logged.has(key) and float(_attack_logged[key]) > now:
		return
	_attack_logged[key] = INF  # caçada em curso: rearma só depois de acabar
	authority.owner_event.emit(prey.owner_player_id, "tamed_attacked",
			{"prey": prey.stats.display_name, "species": hunter.stats.display_name})


## Primeira mordida do episódio no dormindo em doma: avisa só quem o alimenta (`feeder_player_id`).
func _warn_feeder(prey: Dino, hunter: Dino, now: float) -> void:
	var key := _log_key(prey)
	if _attack_logged.has(key) and float(_attack_logged[key]) > now:
		return
	_attack_logged[key] = INF
	if prey.feeder_player_id != "":
		authority.owner_event.emit(prey.feeder_player_id, "taming_attacked",
				{"name": prey.stats.display_name, "species": hunter.stats.display_name})


func _log_key(prey: Dino) -> String:
	return prey.combat_id if prey.combat_id != "" else String(prey.name)


## Reavalia o alvo (10.2): em combate mantém; senão o mais próximo do alcance, com histerese, travado e escudo do dono.
func _reevaluate(hunt: Hunt, now: float) -> void:
	var hunter := hunt.hunter
	var profile := hunter.stats.predation
	if _provoked(hunt):
		hunt.damage_mark = hunter.player_damage_count
		hunt.player_fixed = true  # o jogador bateu: larga a presa e segue o ciclo normal contra ele
	if hunter.bit_player_episode == hunter.state_machine.episode_id and hunter.state_machine.is_aggressive:
		hunt.player_fixed = true  # quem já mordeu o jogador neste episódio não troca para presa
	if hunt.player_fixed and hunter.state_machine.is_aggressive:
		if not hunt.released_for_player:  # uma vez só: reiniciar a cada reavaliação impediria o raptor de acalmar
			hunt.released_for_player = true
			_release(hunt, now, false)  # volta ao natural: o `Dino` persegue o jogador que bateu
			hunter.state_machine.restart_episode()
		return
	var tile := _tile()
	var perception := hunter.stats.perception_tiles * tile
	if hunt.prey != null and (_effective(hunter, hunt.prey.global_position) <= profile.engage_tiles * tile or hunt.bitten):
		return  # em combate: o jogador não é candidato e a presa não troca
	var current := hunt.target
	if current != null and (not is_instance_valid(current) or _is_dead(current)):
		current = null
	elif current is Player and (_effective(hunter, current.global_position) > perception or _barred(hunter, current.global_position)):
		current = null  # o jogador saiu do alcance (ou do que o caçador pode perseguir): alvo perdido não espera nada
	var candidates: Array[Dictionary] = []
	for player in _players(hunter):
		distance_tests += 1
		var distance := _effective(hunter, player.global_position)
		if distance <= perception and not _barred(hunter, player.global_position):
			candidates.append({"node": player, "prey": null, "distance": distance})
	var sated := hunter.sated_until > now
	if not sated and not hunt.player_fixed:
		_collect_prey(hunt, candidates, current, now)
	var choice := _pick(candidates)
	if current != null and not choice.is_empty() and choice["node"] != current:
		var held := _effective(hunter, current.global_position)
		if not (float(choice["distance"]) < profile.switch_ratio * held and hunt.lock_age > profile.lock_min_seconds):
			choice = {"node": current, "prey": hunt.prey, "distance": held}
	if choice.is_empty() and hunt.prey != null and current == hunt.prey and not _outside(hunt, current):
		choice = {"node": current, "prey": hunt.prey, "distance": 0.0}  # presa fora do alcance mas ainda dentro dos 5 s de vista
	_set_target(hunt, choice["node"] if not choice.is_empty() else null, now)


## O jogador causou dano ao caçador desde a última conferência (e a espécie troca de alvo por isso)?
func _provoked(hunt: Hunt) -> bool:
	return hunt.hunter.stats.predation.switch_to_player_on_damage and hunt.hunter.player_damage_count != hunt.damage_mark


## O jogador bateu no caçador enquanto ele farejava ou perseguia o dormindo: larga o dormindo no MESMO quadro e vira o jogador.
func _switch_to_player(hunt: Hunt, now: float) -> void:
	var hunter := hunt.hunter
	hunt.damage_mark = hunter.player_damage_count
	hunt.player_fixed = true
	if hunter.state_machine.is_aggressive and not hunt.released_for_player:
		hunt.released_for_player = true
		_release(hunt, now, false)
		hunter.state_machine.restart_episode()
	else:
		_release(hunt, now, false)


func _outside(hunt: Hunt, node: Node2D) -> bool:
	return hunt.unseen >= hunt.hunter.stats.predation.no_sight_seconds or not is_instance_valid(node)


func _collect_prey(hunt: Hunt, candidates: Array[Dictionary], current: Node2D, now: float) -> void:
	var hunter := hunt.hunter
	var tile := _tile()
	var perception := hunter.stats.perception_tiles * tile
	var hears := hunter.stats.predation.hears_sleepers and rules.sleeper_is_prey
	var plain_limit := perception * perception
	var shield := rules.owner_shield_tiles * tile
	var guarded := current as Player
	var pack := _pack_bonus(hunter)  # uma vez por caçador, não por presa
	for prey in _active:
		distance_tests += 1
		if prey == hunter:
			continue
		var sleeper := hears and _is_sleeper(prey)
		if not sleeper and hunter.global_position.distance_squared_to(prey.global_position) > plain_limit:
			continue  # o ronco do dormindo é círculo e pode passar da percepção: só ele escapa do filtro grosso
		var distance := hunter.global_position.distance_to(prey.global_position) if sleeper \
				else _effective(hunter, prey.global_position)
		if distance > (_snore_px(hunter, prey) if sleeper else perception) or not _prey_ok(hunter, prey, now, true, pack):
			continue
		if guarded != null and guarded.global_position.distance_to(prey.global_position) <= shield:
			continue  # escudo do dono: quem já persegue o jogador não o larga por quem está colado nele
		candidates.append({"node": prey, "prey": prey, "distance": distance})


## O mais próximo; empate dentro de `tie_ratio`: o jogador.
func _pick(candidates: Array[Dictionary]) -> Dictionary:
	var best: Dictionary = {}
	for entry in candidates:
		if best.is_empty() or float(entry["distance"]) < float(best["distance"]):
			best = entry
	if not best.is_empty() and best["prey"] != null:
		for entry in candidates:
			if entry["prey"] == null and float(entry["distance"]) <= float(best["distance"]) * (1.0 + rules.tie_ratio):
				return entry
	return best


## Trava `node` (null = natural). Trocar de presa recomeça o relógio da caçada; manter o mesmo alvo não faz nada.
func _set_target(hunt: Hunt, node: Node2D, now: float) -> void:
	if node == hunt.target:
		return
	_end_prey_log(hunt, now)
	hunt.target = node
	hunt.prey = node as Dino
	hunt.lock_age = 0.0
	hunt.age = 0.0
	hunt.unseen = 0.0
	hunt.bitten = false
	hunt.damage_mark = hunt.hunter.player_damage_count
	_end_sniff(hunt)
	if hunt.prey != null:
		hunt.bite_mark = hunt.prey.bite_count
	hunt.hunter.hunt_target = hunt.prey
	hunt.hunter.observe_targets()  # o alvo vale já neste quadro
	if hunt.prey != null and _is_sleeper(hunt.prey):
		_begin_sniff(hunt)


## Toda trava de dormindo começa com a farejada: o caçador pára `sleeper_alert_s` e só então persegue (D-E6, sem memória).
func _begin_sniff(hunt: Hunt) -> void:
	hunt.alert_left = rules.sleeper_alert_s
	hunt.sniffing = hunt.alert_left > 0.0
	hunt.hunter.state_machine.holding = hunt.sniffing
	sleeper_alerted.emit(hunt.hunter, hunt.prey)


func _end_sniff(hunt: Hunt) -> void:
	if not hunt.sniffing:
		return
	hunt.sniffing = false
	hunt.alert_left = 0.0
	hunt.hunter.state_machine.holding = false


## Solta a presa (e só ela): `failed` põe o bando dela em `fail_cooldown_s`.
func _release(hunt: Hunt, now: float, failed: bool) -> void:
	if hunt.prey != null and failed and is_instance_valid(hunt.prey):
		_fail_until[_fail_key(hunt.prey)] = now + hunt.hunter.stats.predation.fail_cooldown_s
	_end_prey_log(hunt, now)
	if hunt.eating:
		_finish_eat(hunt, now, true)
	_end_sniff(hunt)
	hunt.target = null
	hunt.prey = null
	hunt.eval_left = 0.0
	hunt.hunter.hunt_target = null
	hunt.hunter.state_machine.hunt_engaged = false


func _end_prey_log(hunt: Hunt, now: float) -> void:
	var prey := hunt.prey
	if prey == null or not is_instance_valid(prey) or not (prey.state_machine.is_tamed or _is_sleeper(prey)):
		return
	for other: Variant in _hunts.values():
		if other != hunt and (other as Hunt).prey == prey:
			return  # outro caçador segue nele: o episódio continua
	var key := _log_key(prey)
	if _attack_logged.has(key):
		_attack_logged[key] = now + rules.tamed_attacked_rearm_s


# ----------------------------------------------------------------------------- abate e refeição

func _on_kill(attacker: Dino, victim: Dino) -> void:
	var now := _now()
	if victim.state_machine.is_tamed and victim.owner_player_id != "":
		_tamed_killed(attacker, victim)
	elif _is_sleeper(victim):
		_sleeper_killed(attacker, victim)
	var hunt := _hunts.get(attacker) as Hunt
	if hunt == null:
		return
	if hunt.prey == victim:
		_release(hunt, now, false)
	if attacker.sated_until > now or carcasses == null or attacker.stats.predation == null:
		return  # golpe final de saciado: a carcaça fica inteira, como sempre
	var carcass := carcasses.carcass_of(victim)
	if carcass == null:
		return
	hunt.eating = true
	hunt.carcass = carcass
	hunt.meat0 = carcasses.meat_of(carcass)
	hunt.eat_total = attacker.stats.predation.eat_seconds(float(hunt.meat0))
	hunt.eat_elapsed = 0.0
	attacker.hunt_target = null
	attacker.state_machine.transition_to(Enums.DinoStateId.IDLE)
	attacker.state_machine.holding = true  # para ao lado da carcaça até acabar ou o jogador chegar


func _tamed_killed(attacker: Dino, victim: Dino) -> void:
	var key := _log_key(victim)
	_attack_logged.erase(key)
	authority.owner_event.emit(victim.owner_player_id, "tamed_killed",
			{"prey": victim.stats.display_name, "species": attacker.stats.display_name})
	_drop_inventory(victim)


## A doma falhou na mordida (E3b): avisa quem alimentava e a comida que estava no inventário cai no chão.
## (A falha em si, `taming_failed`, é do `TamingComponent`, que escuta a morte.)
func _sleeper_killed(attacker: Dino, victim: Dino) -> void:
	_attack_logged.erase(_log_key(victim))
	if victim.feeder_player_id != "":
		authority.owner_event.emit(victim.feeder_player_id, "taming_killed",
				{"name": victim.stats.display_name, "species": attacker.stats.display_name})
	_drop_inventory(victim)


## O inventário da vítima cai no chão, sem perder nada pelo teto por área.
func _drop_inventory(victim: Dino) -> void:
	if ground == null:
		return
	for index in victim.inventory.slot_count():  # o alforje cai no chão, sem perder nada pelo teto por área
		var slot := victim.inventory.get_slot(index)
		if slot.is_empty():
			continue
		if slot.has("iid"):  # ferramenta ou arma: cai com a durabilidade que tinha
			ground.spawn_entry(slot, victim.global_position, true)
			continue
		var amount := victim.inventory.take_from_slot(index, int(slot.get("count", 0)))
		if amount > 0:
			ground.spawn_scatter(str(slot["id"]), amount, victim.global_position, "", true)


## Come: a carne encolhe em linha reta e a carcaça some no fim. O jogador dentro do alcance interrompe a refeição.
func _step_eat(hunt: Hunt, delta: float, now: float) -> void:
	var hunter := hunt.hunter
	var perception := hunter.stats.perception_tiles * _tile()
	for player in _players(hunter):
		distance_tests += 1
		if _effective(hunter, player.global_position) <= perception:
			_finish_eat(hunt, now, true)
			return
	if not is_instance_valid(hunt.carcass) or hunt.carcass.component.depleted:
		_finish_eat(hunt, now, true)
		return
	hunt.eat_elapsed += delta
	var fraction := 1.0 if hunt.eat_total <= 0.0 else clampf(hunt.eat_elapsed / hunt.eat_total, 0.0, 1.0)
	carcasses.set_meat(hunt.carcass, ceili(float(hunt.meat0) * (1.0 - fraction) - 0.0001))
	if fraction >= 1.0:
		_finish_eat(hunt, now, false)


## Fim da refeição. Interrompida, a carne que sobrou fica e a saciedade é proporcional ao que comeu.
func _finish_eat(hunt: Hunt, now: float, interrupted: bool) -> void:
	var hunter := hunt.hunter
	var fraction := 1.0
	if interrupted:
		fraction = 1.0 if hunt.eat_total <= 0.0 else clampf(hunt.eat_elapsed / hunt.eat_total, 0.0, 1.0)
	hunt.eating = false
	hunter.state_machine.holding = false
	if fraction > 0.0:
		hunter.sated_until = now + hunter.stats.predation.sated_seconds(float(hunt.meat0) * fraction)
	hunt.carcass = null


# ----------------------------------------------------------------------------- apoio

func _now() -> float:
	return authority.clock.now() if authority != null else 0.0


func _tile() -> float:
	return float(zone.rules.tile_size) if zone != null else 16.0


func _effective(hunter: Dino, point: Vector2) -> float:
	var offset := point - hunter.global_position
	return Vector2(offset.x, offset.y * hunter.stats.perception_vertical_weight).length()


func _focus_distance(point: Vector2) -> float:
	var best := INF
	for focus in zone.foci:
		if is_instance_valid(focus):
			best = minf(best, point.distance_to(focus.global_position))
	return best


## Jogadores que o caçador `hunter` enxerga como alvo: vivos, e caídos só para quem ataca caído (`attacks_downed`).
func _players(hunter: Dino) -> Array[Player]:
	var list: Array[Player] = []
	for focus in zone.foci:
		var player := focus as Player if is_instance_valid(focus) else null
		if player != null and not player.health.is_dead() and (not player.downed.is_downed or hunter.attacks_downed()):
			list.append(player)
	return list


func _is_dead(node: Node2D) -> bool:
	var health := node.get("health") as HealthComponent
	return health != null and health.is_dead()
