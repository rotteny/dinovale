# SPDX-License-Identifier: MIT
class_name DinoView
extends Node2D
## Apresentação do dino sobre a folha da espécie (`sprites/dinos/<espécie>.png`, quadros de 32x32, 11 a 18 colunas x
## 4 ou 8 linhas, descrita por `<espécie>.json`: a linha é a direção, as colunas são as animações `idle`, `walk`,
## `attack`, `sleep` e `dead`; os pés ficam em y=30 do quadro): quadro por direção, cambaleio (deslocamento de 1 a
## 2 px) e pausa pela faixa de torpor, bocejo, sono (quadro `sleep`, já deitado na arte, e o balão "zz"), flash
## branco e número flutuante ao levar dano. Só apresentação:
## lê sinais e valores do dino e mexe apenas no `dino.visual`; nenhuma regra mora aqui.
## Instancie FORA do `Dino.tscn`. Velocidade, pausas e cooldown por faixa são regra de
## simulação (`TorporComponent`), não desta classe.
##
## Som: este é o ponto de ligação, e nenhum áudio foi criado. Cada ocasião emite
## `sound_cue` e, se houver stream em `cue_streams`, toca no `AudioStreamPlayer2D`.
## Para ligar um som: coloque o arquivo em `res://assets/sounds/dino/`, registre-o em
## `assets/CREDITS.md` e arraste-o para `cue_streams` do nó `DinoView` na `Main.tscn`
## (chaves: `hit`, `yawn`, `tamed`). Os arquivos do pacote são baixos (pico em -10 dBFS):
## `volume_db` (+6 por padrão) compensa.

signal sound_cue(cue: StringName)

const ANIM_IDLE := "idle"
const ANIM_WALK := "walk"
const ANIM_SLEEP := "sleep"
## Tempo da animação de golpe durante o aviso: parado no primeiro quadro (cabeça recuada).
const WINDUP_HOLD := 0.0
const CUE_HIT := &"hit"
const CUE_YAWN := &"yawn"
const CUE_TAMED := &"tamed"

const FLASH_SECONDS := 0.1
const ORDER_COLOR := Color(0.75, 0.95, 0.6)
const FLASH_COLOR := Color(4.0, 4.0, 4.0)
const SLEEP_COLOR := Color(0.65, 0.65, 0.85)
const TEXT_SECONDS := 0.9
## Intervalo entre bocejos por faixa de torpor; 0 = não boceja.
const YAWN_INTERVAL_BY_BAND: Array[float] = [0.0, 8.0, 4.0, 2.5]
## Cambaleio por faixa: deslocamento lateral em pixels inteiros (pixel art não gira) e velocidade.
const SWAY_AMPLITUDE_BY_BAND: Array[float] = [0.0, 0.0, 1.0, 2.0]
const SWAY_SPEED_BY_BAND: Array[float] = [0.0, 0.0, 6.0, 3.5]
const SLEEP_ICON := preload("res://assets/third_party/ninja-adventure/ui/emote_sleep.png")
const SLEEP_ICON_POSITION := Vector2(10.0, -14.0)
## "!" de bravo: sobre a cabeça, abaixo da placa de nível.
const ALERT_MARK_POSITION := Vector2(-4.0, -28.0)
const POPUP_RISE := 14.0
const POPUP_SECONDS := 0.7

@export var dino: Dino
## Sons por ocasião (`hit`, `yawn`, `tamed`). Vazio até a escolha do pacote de som.
@export var cue_streams: Dictionary[StringName, AudioStream] = {}
@export var volume_db: float = 6.0
@export var aggression_rules: AggressionRules = preload("res://data/balance/aggression_rules.tres")
## O jogador local (para saber se o domado é dele); sem ele vale o id padrão do jogador de teste.
var viewer: Player = null

var _audio := AudioStreamPlayer2D.new()
var _sleep_icon := Sprite2D.new()
var _facing := SpriteFacing.DOWN
var _sheet := SpriteSheetDef.new()
var _popups := Node2D.new()
var _text := Label.new()
var _time := 0.0
var _flash_left := 0.0
var _text_left := 0.0
var _yawn_clock := 0.0
var _alert_mark := Label.new()
var _alert_fade := AggressionFade.new()
## Segundos desde a entrada na fase de ameaça atual e desde o início do golpe (investida, que segue na recuperação).
var _phase_clock := 0.0
var _strike_clock := 0.0


func _ready() -> void:
	z_index = 11
	_audio.volume_db = volume_db
	_audio.bus = GameSettings.BUS_SFX
	add_child(_audio)
	_sleep_icon.texture = SLEEP_ICON
	_sleep_icon.position = SLEEP_ICON_POSITION
	_sleep_icon.visible = false
	add_child(_sleep_icon)
	add_child(_popups)
	_text.add_theme_font_size_override("font_size", 8)
	_text.add_theme_color_override("font_outline_color", Color.BLACK)
	_text.add_theme_constant_override("outline_size", 3)
	_text.position = Vector2(14.0, -18.0)
	_text.visible = false
	add_child(_text)
	_alert_mark.text = aggression_rules.mark_text
	_alert_mark.add_theme_font_size_override("font_size", 10)
	_alert_mark.add_theme_color_override("font_color", aggression_rules.mark_color)
	_alert_mark.add_theme_color_override("font_outline_color", Color.BLACK)
	_alert_mark.add_theme_constant_override("outline_size", 3)
	_alert_mark.position = ALERT_MARK_POSITION
	_alert_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_alert_mark.visible = false
	add_child(_alert_mark)
	if dino == null:
		return
	_sheet = SpriteSheetDef.from_json_file(dino.stats.sheet_path)
	_use_species_texture()
	dino.health.damaged.connect(_on_damaged)
	dino.torpor.band_changed.connect(_on_band_changed)
	dino.taming.level_finalized.connect(_on_tamed)
	dino.state_machine.order_changed.connect(_on_order_changed)
	dino.state_machine.threat_phase_changed.connect(_on_threat_phase)
	dino.state_machine.struck.connect(_on_struck)
	follow()


## O sprite da cena nasce com a folha do Paquicéfalo: a espécie traz a dela em `sheet_texture`.
func _use_species_texture() -> void:
	if dino.stats.sheet_texture != null:
		dino.visual.texture = dino.stats.sheet_texture


func _process(delta: float) -> void:
	tick(delta)


## Passo de tempo da apresentação (separado do `_process` para testar sem frames).
func tick(delta: float) -> void:
	if not is_instance_valid(dino):
		queue_free()
		return
	follow()
	_time += delta
	_phase_clock += delta
	_strike_clock += delta
	_flash_left = maxf(_flash_left - delta, 0.0)
	_text_left = maxf(_text_left - delta, 0.0)
	var awake := not dino.torpor.is_unconscious
	var band := dino.torpor.band if awake else 0
	if not awake:
		_text_left = 0.0
	_apply_sway(band)
	_apply_pose(awake)
	_apply_yawn(band, delta)
	_apply_pause(awake and dino.torpor.is_paused())
	_apply_tint(awake)
	_text.visible = _text_left > 0.0
	_apply_alert_mark(awake, delta)


func follow() -> void:
	if is_instance_valid(dino):
		global_position = dino.global_position


## Quantos números de dano ainda estão na tela.
func popup_count() -> int:
	var count := 0
	for child in _popups.get_children():
		if not child.is_queued_for_deletion():
			count += 1
	return count


## O "!" vermelho está à mostra (mesmo em fade)?
func alert_mark_visible() -> bool:
	return _alert_mark.visible


func alert_mark_alpha() -> float:
	return _alert_mark.modulate.a if _alert_mark.visible else 0.0


func text_shown() -> String:
	return _text.text if _text.visible else ""


func audio_player() -> AudioStreamPlayer2D:
	return _audio


func is_flashing() -> bool:
	return _flash_left > 0.0


func is_sleep_icon_visible() -> bool:
	return _sleep_icon.visible


## Cambaleio: o sprite balança de lado, em pixels inteiros.
func _apply_sway(band: int) -> void:
	var amplitude := SWAY_AMPLITUDE_BY_BAND[band]
	dino.visual.position.x = roundf(sin(_time * SWAY_SPEED_BY_BAND[band]) * amplitude)


## Quadro do sprite, pela folha do JSON: dormindo, o quadro `sleep` na direção em que estava (a arte já vem deitada);
## acordado, `walk` se anda e `idle` se está parado. A linha é a direção (mesma ordem de `SpriteFacing`).
func _apply_pose(awake: bool) -> void:
	_sleep_icon.visible = not awake
	dino.visual.rotation = 0.0
	var moving := awake and dino.velocity.length_squared() > 1.0
	var phase := dino.state_machine.threat_phase if awake else Enums.ThreatPhase.NONE
	if moving:
		_facing = SpriteFacing.facing_for(dino.velocity, _facing, _sheet.rows)
	elif phase != Enums.ThreatPhase.NONE:
		_facing = SpriteFacing.facing_for(dino.state_machine.target_position - dino.global_position, _facing, _sheet.rows)
	var column := 0
	var threat_column := _threat_column(phase)
	if not awake:
		column = _sheet.column_at(ANIM_SLEEP, 0.0)
	elif threat_column >= 0:
		column = threat_column
	elif moving:
		column = _sheet.column_at(ANIM_WALK, _time)
	else:
		column = _sheet.column_at(ANIM_IDLE, _time)
	_show_frame(column)


## Quadro da fase de ameaça (-1 = nenhuma animação própria, segue o andar e o parado): ameaça parada = `threat`; aviso do
## golpe = primeiro quadro do golpe; investida e recuperação = a animação do golpe. A ameaça feita correndo anda.
func _threat_column(phase: Enums.ThreatPhase) -> int:
	var cycle := dino.state_machine.threat_cycle
	if cycle == null or phase == Enums.ThreatPhase.NONE:
		return -1
	var profile := cycle.profile
	match phase:
		Enums.ThreatPhase.THREAT:
			if not cycle.runs_threat and _sheet.has_animation(profile.threat_animation):
				return _sheet.column_at(profile.threat_animation, _phase_clock)
		Enums.ThreatPhase.WINDUP:
			if _sheet.has_animation(profile.strike_animation):
				return _sheet.column_at(profile.strike_animation, WINDUP_HOLD)
		Enums.ThreatPhase.LUNGE, Enums.ThreatPhase.RECOVER:
			if _sheet.has_animation(profile.strike_animation):
				return _sheet.column_at(profile.strike_animation, _strike_clock)
	return -1


## Folha do JSON de outro tamanho que o sprite da cena: fica no primeiro quadro da direção, nunca fora da folha.
func _show_frame(column: int) -> void:
	var sprite := dino.visual
	var usable := SpriteFacing.fit_sheet(sprite, _sheet)
	sprite.frame_coords = Vector2i(
			clampi(column if usable else 0, 0, sprite.hframes - 1), clampi(_facing, 0, sprite.vframes - 1))


## "!" vermelho enquanto a máquina diz que o dino está bravo; some com fade ao acalmar.
func _apply_alert_mark(awake: bool, delta: float) -> void:
	var alpha := _alert_fade.step(delta, awake and (dino.state_machine.is_aggressive or dino.is_sniffing()), aggression_rules)
	_alert_mark.visible = alpha > 0.0
	_alert_mark.modulate.a = alpha
	var color := aggression_rules.hunt_mark_color if dino.is_hunting_prey() else aggression_rules.mark_color
	_alert_mark.add_theme_color_override("font_color", color)  # laranja = caça outro dino; vermelho = bravo com você


func _apply_yawn(band: int, delta: float) -> void:
	var interval := YAWN_INTERVAL_BY_BAND[band]
	if interval <= 0.0:
		_yawn_clock = 0.0
		return
	_yawn_clock += delta
	if _yawn_clock >= interval:
		_yawn_clock = 0.0
		_show_text("Aaah...")
		_cue(CUE_YAWN)


func _apply_pause(paused: bool) -> void:
	dino.visual.scale = Vector2(1.0, 0.875) if paused else Vector2.ONE
	dino.visual.position.y = 1.0 if paused else 0.0
	if paused:
		_show_text("...")


func _apply_tint(awake: bool) -> void:
	if _flash_left > 0.0:
		dino.visual.modulate = FLASH_COLOR
	else:
		dino.visual.modulate = Color.WHITE if awake else SLEEP_COLOR


func _show_text(text: String) -> void:
	_text.text = text
	_text_left = TEXT_SECONDS


func _on_damaged(amount: float) -> void:
	SfxPlayer.play(self, SfxPlayer.DINO_HURT, global_position)
	_flash_left = FLASH_SECONDS
	_spawn_popup(FloatingText.damage_text(amount), Color(1.0, 0.45, 0.4))
	_cue(CUE_HIT)


## A ordem do domado mudou: o texto sobe da criatura (sem sprite novo; GDD 6.11).
func _on_order_changed(order: Enums.DinoOrder) -> void:
	_spawn_popup("Seguir" if order == Enums.DinoOrder.FOLLOW else "Ficar", ORDER_COLOR)


## Fase nova do ciclo de ameaça: zera o relógio da animação e, na ameaça, toca o som (bufada ou rosnado).
func _on_threat_phase(phase: Enums.ThreatPhase) -> void:
	_phase_clock = 0.0
	var cycle := dino.state_machine.threat_cycle
	if cycle == null:
		return
	if phase == Enums.ThreatPhase.THREAT:
		SfxPlayer.play(self, cycle.profile.threat_sound, global_position)
	elif phase == Enums.ThreatPhase.LUNGE:
		_strike_clock = 0.0


## O golpe saiu (acertando ou errando): o som de golpe da espécie.
func _on_struck(_in_reach: bool) -> void:
	var cycle := dino.state_machine.threat_cycle
	if cycle != null:
		SfxPlayer.play(self, cycle.profile.strike_sound, global_position)


func _on_band_changed(_band: int) -> void:
	_yawn_clock = 0.0


func _on_tamed(final_level: int) -> void:
	# O domado do jogador já mostra o nível na placa (DinoMarker); o número flutuante seria texto duplicado.
	if dino.owner_player_id != (viewer.player_id if viewer != null else Player.LOCAL_PLAYER_ID):
		_spawn_popup("Nv %d" % final_level, Color(1.0, 0.9, 0.4))
	_cue(CUE_TAMED)


func _spawn_popup(text: String, color: Color) -> void:
	FloatingText.spawn(_popups, text, color, Vector2(-6.0, -16.0), POPUP_RISE, POPUP_SECONDS)


## Ponto de ligação do som: sempre avisa; toca só se houver stream.
func _cue(cue: StringName) -> void:
	sound_cue.emit(cue)
	var stream: AudioStream = cue_streams.get(cue)
	if stream != null:
		_audio.stream = stream
		_audio.play()
