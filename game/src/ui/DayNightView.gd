# SPDX-License-Identifier: MIT
class_name DayNightView
extends Node
## Apresentação do dia e da noite (SOB-03, E9): tinta do mundo e luz de 5 tiles ao redor do jogador. Só lê o
## `DayCycle` da autoridade; nenhuma regra aqui (a percepção do Agressivo é da autoridade). Pode ser removida sem efeito
## no jogo (roda igual sem ela, inclusive headless).
##
## DECISÃO (E9): `CanvasModulate` + `PointLight2D`, e não shader de tela. Motivos: (1) o `CanvasModulate` só tinge o canvas
## em que está; o HUD vive no `CanvasLayer` `UI`, outro canvas, então a tinta NÃO o atinge por construção (nada de
## máscara nem de ordem de desenho); (2) shader de pós-processamento precisa ler a tela inteira e o HUD teria de ficar
## de fora por truque; (3) a luz do jogador sai de graça: a luz soma ao que a tinta multiplica. A conta: pixel final =
## cor x (tinta + luz). Com a luz de cor `1 - tinta` e energia 1, o centro dela devolve exatamente a cor original e a
## borda cai até a tinta, sem estourar o branco. A tinta nunca vai a preto (`DayCycleRules.min_tint_channel`), e a
## troca de faixa é suave (`blend_seconds`). A Fogueira (E12) reaproveita o mesmo desenho de luz: uma `PointLight2D` fixa no
## centro de cada Fogueira da grade (`DayCycleRules.campfire_light_radius_tiles`, 4 tiles), com a cor e a força da luz do jogador,
## então de dia ela some e à noite aparece. A vista ouve os sinais da grade: Fogueira posta ou removida liga e desliga a luz.
## Custo conhecido: o `Light2D` entra na iluminação 2D da engine; o que não deve ser iluminado usa um `CanvasLayer`.

const LIGHT_TEXTURE_SIZE := 128
## Sem noite (tinta quase branca) a luz some: não custa nada de dia.
const LIGHT_MIN_STRENGTH := 0.01

@export var authority: WorldAuthority
@export var player: Player
@export var tile_px: float = 16.0
## Ponto do corpo do jogador onde a luz fica: o meio do corpo, como a câmera (`PlayerCamera.BODY_CENTER`).
@export var light_offset: Vector2 = PlayerCamera.BODY_CENTER

var _modulate := CanvasModulate.new()
var _light := PointLight2D.new()
## Último valor escrito: só se escreve no nó quando muda (a tinta fica parada na maior parte do dia).
var _last_tint: Color = Color(-1.0, -1.0, -1.0)
var _last_radius_px: float = -1.0
var _last_fire_radius_px: float = -1.0
## A luz de cada Fogueira, pela célula dela.
var _fire_lights: Dictionary[Vector2i, PointLight2D] = {}


func _ready() -> void:
	_modulate.name = "DayTint"
	add_child(_modulate)
	_light.name = "PlayerLight"
	_light.texture = _radial_texture()
	_light.shadow_enabled = false
	add_child(_light)
	if authority != null:
		var grid := authority.build.grid
		grid.piece_added.connect(_on_piece_added)
		grid.piece_removed.connect(_on_piece_removed)
		for cell in grid.cells():
			_on_piece_added(cell)
	tick(0.0)


func _process(delta: float) -> void:
	tick(delta)


## Passo de apresentação (público para testar sem quadros): tinta do instante e luz no jogador.
func tick(_delta: float) -> void:
	if authority == null:
		return
	var tint := authority.day_cycle.tint_at(authority.clock.now())
	if tint != _last_tint:
		_last_tint = tint
		_modulate.color = tint
		var missing := Color(1.0 - tint.r, 1.0 - tint.g, 1.0 - tint.b, 1.0)
		_light.visible = maxf(missing.r, maxf(missing.g, missing.b)) > LIGHT_MIN_STRENGTH
		_light.color = missing
		_light.energy = 1.0
		for fire in _fire_lights.values():
			_style_fire_light(fire)
	var radius_px := authority.day_cycle.rules.light_radius_tiles * tile_px
	if radius_px != _last_radius_px:
		_last_radius_px = radius_px
		_light.texture_scale = radius_px * 2.0 / float(LIGHT_TEXTURE_SIZE)
	var fire_radius_px := authority.day_cycle.rules.campfire_light_radius_tiles * tile_px
	if fire_radius_px != _last_fire_radius_px:
		_last_fire_radius_px = fire_radius_px
		for fire in _fire_lights.values():
			_style_fire_light(fire)
	if player != null:
		var at := player.global_position + light_offset
		if at != _light.global_position:
			_light.global_position = at


## As luzes das Fogueiras (uma por Fogueira da grade), pela célula.
func fire_lights() -> Dictionary[Vector2i, PointLight2D]:
	return _fire_lights


func _on_piece_added(cell: Vector2i) -> void:
	var def := authority.build.grid.def_at(cell)
	if def == null or def.id != "campfire" or _fire_lights.has(cell):
		return
	var fire := PointLight2D.new()
	fire.name = "CampfireLight"
	fire.texture = _light.texture
	fire.shadow_enabled = false
	fire.position = (Vector2(cell) + Vector2(0.5, 0.5)) * tile_px  # o pai é um Node: a posição local é a do mundo
	add_child(fire)
	_fire_lights[cell] = fire
	_style_fire_light(fire)


func _on_piece_removed(cell: Vector2i, _piece: Dictionary) -> void:
	var fire: PointLight2D = _fire_lights.get(cell)
	if fire != null:
		_fire_lights.erase(cell)
		fire.queue_free()


## Cor, força e tamanho da luz da Fogueira: os mesmos da luz do jogador, no raio dela.
func _style_fire_light(fire: PointLight2D) -> void:
	fire.visible = _light.visible
	fire.color = _light.color
	fire.energy = _light.energy
	fire.texture_scale = authority.day_cycle.rules.campfire_light_radius_tiles * tile_px * 2.0 / float(LIGHT_TEXTURE_SIZE)


func tint_node() -> CanvasModulate:
	return _modulate


func light_node() -> PointLight2D:
	return _light


## Luz redonda: branco no centro e preto na borda (preto = sem luz).
func _radial_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color.WHITE, Color.BLACK])
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = LIGHT_TEXTURE_SIZE
	texture.height = LIGHT_TEXTURE_SIZE
	return texture
