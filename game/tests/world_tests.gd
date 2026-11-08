# SPDX-License-Identifier: MIT
class_name WorldTests
extends SaveTests
## Etapa B do mundo: ilha Lunata (mapa estático, terreno, nós, Soco, zona ativa e save v4).
## Reaproveita `_main` e a raiz de saves de `SaveTests`.

const FIXTURE_V3 := "res://tests/fixtures/saves/v3.json"
const FIXTURE_V4 := "res://tests/fixtures/saves/v4.json"
const FIXTURE_V5 := "res://tests/fixtures/saves/v5.json"
const RESULT := Enums.ActionResult
const WORLD_RULES: WorldRules = preload("res://data/world/world_rules.tres")
const RESPAWN_RULES: RespawnRules = preload("res://data/balance/respawn_rules.tres")
const PUNCH_ONLY := "A conta do Soco: 1 de dano por colheita, em dado"


func run() -> void:
	_test_island_map_data()
	_test_island_map_rejects_bad_data()
	_test_map_spawns_and_reserve()
	_test_map_shape_and_reach()
	_test_sea_margin_keeps_camera_free()
	_test_biome_borders_are_irregular()
	_test_portal_is_natural_cluster()
	_test_exporter_is_deterministic()
	_test_terrain_tiles()
	_test_world_rules()
	_test_zone_classify()
	await _test_main_terrain_and_nodes()
	_release_worlds()
	await _test_punch_rules()
	_release_worlds()
	await _test_punch_denials()
	_release_worlds()
	await _test_loose_stones()
	_release_worlds()
	await _test_zone_in_main()
	_release_worlds()
	await _test_zone_load_360()
	_release_worlds()
	await _test_save_v5()
	await _test_migration_v4_to_v5()
	_release_worlds()
	await _test_continue_from_v3()
	_release_worlds()


# ----------------------------------------------------------------------------- mapa

func _test_island_map_data() -> void:
	var map := IslandMap.from_file(IslandMap.DEFAULT_PATH)
	_check(map.is_valid() and map.size == 256 and map.map_id == "lunata" and map.revision >= 1, "a Lunata carrega: 256x256, id e revisão")
	var counts := map.count_by_terrain()
	var total := 0
	for count in counts:
		total += count
	_check(total == 256 * 256, "todo tile tem terreno (%d)" % total)
	for terrain in IslandMap.TERRAIN_COUNT:
		_check(counts[terrain] > 0, "o terreno %d aparece no mapa" % terrain)
	_check(map.is_land(map.start_cell) and map.is_walkable(map.start_cell) and map.terrain_at(map.start_cell) == IslandMap.GRASSLAND,
			"o início é terra firme na Campina")
	_check(map.safe_point() == map.start_point() and map.start_point() == map.center_of(map.start_cell), "ponto seguro = início")
	for key in ["arco_da_enseada", "pedra_do_aviso", "portal_de_pedra", "cabo_salgado", "paquicefalo_tutorial"]:
		_check(map.landmarks.has(key), "marco %s existe" % key)
	_check(map.landmarks["portal_de_pedra"] != map.landmarks["arco_da_enseada"], "marcos em lugares diferentes")
	# Regras de andar: raso anda sem lentidão, praia e terra andam, água funda e o anel não.
	var by_terrain := {}
	for y in map.size:
		for x in map.size:
			by_terrain[map.terrain_at(Vector2i(x, y))] = Vector2i(x, y)
	_check(map.is_walkable(by_terrain[IslandMap.SHALLOW]) and not map.is_land(by_terrain[IslandMap.SHALLOW]),
			"o raso anda, mas não é terra firme")
	_check(map.is_walkable(by_terrain[IslandMap.BEACH]) and map.is_land(by_terrain[IslandMap.BEACH]), "a praia anda e é terra")
	_check(not map.is_walkable(by_terrain[IslandMap.DEEP]) and not map.is_walkable(by_terrain[IslandMap.DEEP_RING]),
			"a água funda e o anel bloqueiam")
	_check(map.has_ring_collision(by_terrain[IslandMap.DEEP_RING]) and not map.has_ring_collision(by_terrain[IslandMap.DEEP]),
			"só o anel tem colisão; o resto do mar não")
	_check(map.terrain_at(Vector2i(-1, 5)) == IslandMap.DEEP and map.terrain_at(Vector2i(5, 999)) == IslandMap.DEEP, "fora do mapa é mar")
	_check(map.world_rect() == Rect2(0, 0, 4096, 4096), "o mapa mede 4096x4096 px")
	var shared := IslandMap.default_map()
	_check(shared.is_valid() and is_same(shared, IslandMap.default_map()), "o mapa padrão é lido uma vez")
	var bounds: MapBounds = load("res://data/world/map_bounds.tres")
	_check(bounds.rect == map.world_rect(), "o limite da câmera é o mapa inteiro, definido só no dado")
	_check(map.nearest_walkable_point(Vector2(5, 5), 3, Vector2(7, 7)) == Vector2(7, 7), "sem terra por perto devolve o ponto reserva")
	_check(map.nearest_walkable_point(map.start_point(), 3, Vector2.ZERO) == map.start_point(), "em chão caminhável fica onde está")


## Dados do mapa que o jogo usa: 36 vagas de bando (ids únicos, região conhecida) e a reserva do respawn livre e em terra.
func _test_map_spawns_and_reserve() -> void:
	var map := IslandMap.default_map()
	var by_species := {}
	var ids := {}
	for slot in map.spawn_slots:
		by_species[slot["species"]] = int(by_species.get(slot["species"], 0)) + 1
		ids[slot["id"]] = true
	_check(map.spawn_slots.size() == 36 and ids.size() == 36 and by_species == {"dodo": 8, "paquicefalo": 20, "utahraptor": 4,
			"triceratops": 4},
			"o mapa traz 36 vagas de bando, de id único (%s)" % str(by_species))
	_check(map.spawn_regions.size() == 4 and not map.region_cells("r_campina_mata").is_empty(), "as quatro regiões de nascimento carregaram")
	var reserve := map.cell_of(RESPAWN_RULES.default_fallback_point)
	_check(map.terrain_at(reserve) == IslandMap.GRASSLAND and map.cell_of(RESPAWN_RULES.regions[0].fallback_point) == reserve,
			"o ponto reserva do respawn é a Campina do mapa-ilha.md (%s)" % str(reserve))


func _test_island_map_rejects_bad_data() -> void:
	var good: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(IslandMap.DEFAULT_PATH))
	var map := IslandMap.new()
	_check(not map.is_valid() and not map.load_dict({}), "mapa vazio é recusado")
	var short: Dictionary = good.duplicate(true)
	(short["rows"] as Array).remove_at(0)
	_check(not map.load_dict(short) and not map.is_valid(), "linhas a menos: recusa")
	var bad_char: Dictionary = good.duplicate(true)
	(bad_char["rows"] as Array)[3] = "9".repeat(256)
	_check(not map.load_dict(bad_char), "terreno desconhecido: recusa (nunca carga parcial)")
	var narrow: Dictionary = good.duplicate(true)
	(narrow["rows"] as Array)[5] = "0".repeat(255)
	_check(not map.load_dict(narrow), "linha mais curta: recusa")
	var wrong_format: Dictionary = good.duplicate(true)
	wrong_format["format"] = 99
	_check(not map.load_dict(wrong_format), "formato desconhecido: recusa")
	var old_format: Dictionary = good.duplicate(true)
	old_format["format"] = 1
	_check(not map.load_dict(old_format) and not map.is_valid() and map.load_error.contains("formato 1")
			and map.load_error.contains("mapa_export.py"), "formato 1: recusa com erro claro (%s)" % map.load_error)
	_check(map.load_dict(good) and map.load_error == "", "formato atual: carrega e limpa o erro")
	var junk: Dictionary = good.duplicate(true)
	junk["nodes"] = {"tree": [[1, 2], "x", [999999, 4], [3], null], "rock": 7}
	junk["start"] = "no meio"
	_check(map.load_dict(junk) and map.nodes["tree"].size() == 1 and map.nodes.get("rock", []).is_empty()
			and map.start_cell == Vector2i(128, 128), "lista de nós com lixo: aproveita o que serve; início inválido vai ao centro")
	_check(not IslandMap.from_file("res://data/world/nao_existe.json").is_valid(), "arquivo ausente vira mapa inválido, sem aborto")
	_check(not IslandMap.from_file("res://project.godot").is_valid(), "arquivo que não é JSON vira mapa inválido")


func _test_map_shape_and_reach() -> void:
	var map := IslandMap.default_map()
	# Anel: toda água funda com colisão fica a até 2 tiles do raso, e o raso nunca encosta na funda sem anel.
	var ring_ok := true
	var shallow_ok := true
	for y in range(2, map.size - 2):
		for x in range(2, map.size - 2):
			var cell := Vector2i(x, y)
			var terrain := map.terrain_at(cell)
			if terrain == IslandMap.DEEP_RING:
				var near := false
				for dy in range(-2, 3):
					for dx in range(-2, 3):
						near = near or map.terrain_at(cell + Vector2i(dx, dy)) == IslandMap.SHALLOW
				ring_ok = ring_ok and near
			elif terrain == IslandMap.SHALLOW:
				for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					shallow_ok = shallow_ok and map.terrain_at(cell + d) != IslandMap.DEEP
	_check(ring_ok, "todo tile do anel está a até 2 tiles do raso")
	_check(shallow_ok, "o raso nunca encosta na água funda sem o anel no meio")
	# Alcance a pé a partir do início (inundação 4-vizinhos sobre o que anda).
	var seen := PackedByteArray()
	seen.resize(map.size * map.size)
	var stack: Array[Vector2i] = [map.start_cell]
	seen[map.start_cell.y * map.size + map.start_cell.x] = 1
	var reached_land := 0
	while not stack.is_empty():
		var cell: Vector2i = stack.pop_back()
		if map.is_land(cell):
			reached_land += 1
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next := cell + d
			if map.in_bounds(next) and map.is_walkable(next) and seen[next.y * map.size + next.x] == 0:
				seen[next.y * map.size + next.x] = 1
				stack.append(next)
	var land := 0
	for terrain in [IslandMap.BEACH, IslandMap.GRASSLAND, IslandMap.WOODLAND, IslandMap.QUARRY]:
		land += map.count_by_terrain()[terrain]
	# O resto é ilhota do mar raso (marcos fora do alcance a pé, como no desenho).
	_check(float(reached_land) / float(land) > 0.9,
			"a ilha principal é contínua: %.1f%% da terra alcança-se a pé do início" % (100.0 * reached_land / land))
	for key in ["pedra_do_aviso", "portal_de_pedra", "cabo_salgado", "paquicefalo_tutorial"]:
		var cell: Vector2i = map.landmarks[key]
		_check(seen[cell.y * map.size + cell.x] == 1, "o marco %s se alcança a pé do início" % key)
	# Pedreira ao norte do início (a caminhada do critério: do início até a Pedreira).
	var quarry := Vector2i(-1, -1)
	for y in map.size:
		for x in map.size:
			if quarry.x < 0 and map.terrain_at(Vector2i(x, y)) == IslandMap.QUARRY and seen[y * map.size + x] == 1:
				quarry = Vector2i(x, y)
	_check(quarry.x >= 0 and quarry.y < map.start_cell.y, "a Pedreira existe, é alcançável e fica ao norte do início")


## O mar em volta é largo: tudo que se anda fica a mais de meia tela da borda do mapa, então a câmera nunca
## encosta no limite e não "para" com o jogador olhando o mar (meia tela = 10 x 5,6 tiles; sobra de margem).
func _test_sea_margin_keeps_camera_free() -> void:
	var map := IslandMap.default_map()
	var margin := map.size
	for y in map.size:
		for x in map.size:
			if map.is_walkable(Vector2i(x, y)):
				margin = mini(margin, mini(mini(x, map.size - 1 - x), mini(y, map.size - 1 - y)))
	_check(margin >= 12, "o chão caminhável fica a %d tiles da borda do mapa (a câmera precisa de 10)" % margin)


## Divisas de bioma recortadas (formação natural, não corte reto) e a regra de transição do `terreno.png`:
## Mata-baixa nunca encosta na praia, sempre há Campina entre as duas.
func _test_biome_borders_are_irregular() -> void:
	var map := IslandMap.default_map()
	var quarry_edge: Array[int] = []
	for x in range(60, 115):
		var low := -1
		for y in map.size:
			if map.terrain_at(Vector2i(x, y)) == IslandMap.QUARRY:
				low = y
		if low >= 0:
			quarry_edge.append(low)
	var woodland_edge: Array[int] = []
	for x in range(30, 110):
		var low := -1
		for y in range(100, map.size):
			if map.terrain_at(Vector2i(x, y)) == IslandMap.WOODLAND:
				low = y
		if low >= 0:
			woodland_edge.append(low)
	_check(quarry_edge.size() > 40 and woodland_edge.size() > 60, "as duas divisas existem nas colunas medidas")
	_check(_amplitude(quarry_edge) >= 12 and _mean_step(quarry_edge) >= 0.5,
			"divisa Pedreira/Mata recortada (amplitude %d, passo médio %.2f)" % [_amplitude(quarry_edge), _mean_step(quarry_edge)])
	_check(_amplitude(woodland_edge) >= 20 and _mean_step(woodland_edge) >= 1.0,
			"divisa Mata/Campina recortada (amplitude %d, passo médio %.2f)" % [_amplitude(woodland_edge), _mean_step(woodland_edge)])
	var touching := 0
	for y in range(1, map.size - 1):
		for x in range(1, map.size - 1):
			if map.terrain_at(Vector2i(x, y)) != IslandMap.WOODLAND:
				continue
			for dy in range(-1, 2):
				for dx in range(-1, 2):
					touching += 1 if map.terrain_at(Vector2i(x + dx, y + dy)) == IslandMap.BEACH else 0
	_check(touching == 0, "Mata-baixa não encosta na praia (%d contatos)" % touching)


func _amplitude(values: Array[int]) -> int:
	return values.max() - values.min() if not values.is_empty() else 0


func _mean_step(values: Array[int]) -> float:
	var total := 0
	for i in range(1, values.size()):
		total += absi(values[i] - values[i - 1])
	return float(total) / maxf(values.size() - 1.0, 1.0)


## Portal-de-Pedra: formações naturais em aglomerado irregular, nunca uma linha ou muro, só no pescoço sul.
func _test_portal_is_natural_cluster() -> void:
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(IslandMap.DEFAULT_PATH))
	var map := IslandMap.default_map()
	var portal: Vector2i = map.landmarks["portal_de_pedra"]
	var pieces: Array = raw.get("portal_pieces", [])
	_check(pieces.size() >= 5, "o portal tem várias peças (%d)" % pieces.size())
	var kinds := {}
	var by_column := {}
	var by_row := {}
	var far := 0
	var ys: Array[int] = []
	for piece: Array in pieces:
		var px := int(piece[1])
		var py := int(piece[2])
		kinds[piece[0]] = true
		by_column[px] = (by_column.get(px, []) as Array) + [py]
		by_row[py] = (by_row.get(py, []) as Array) + [px]
		ys.append(py)
		far += 1 if Vector2(px - portal.x, py - portal.y).length() > 14.0 or py < 160 else 0
	_check(kinds.size() >= 2, "o portal mistura tamanhos de formação (%d tipos)" % kinds.size())
	_check(far == 0, "nenhuma peça do portal fora do raio do pescoço sul (%d fora)" % far)
	_check(_longest_run(by_column) < 4 and _longest_run(by_row) < 4,
			"nenhuma sequência de 4 ou mais formações alinhadas na mesma coluna ou linha do portal")
	ys.sort()
	var widest := 0
	for i in range(1, ys.size()):
		widest = maxi(widest, ys[i] - ys[i - 1] - 1)
	_check(widest >= 4, "o portal deixa uma passagem de ao menos 4 tiles (%d)" % widest)
	var leak := 0
	for kind: String in ["formation_a", "formation_b", "formation_c"]:
		for cell: Vector2i in map.scenery[kind]:
			leak += 1 if cell.x == portal.x and cell.y < 160 else 0
	_check(leak == 0, "nada em x=%d no chifre norte" % portal.x)


## Maior sequência de peças na mesma linha ou coluna, com no máximo 3 tiles entre uma e a próxima.
func _longest_run(groups: Dictionary) -> int:
	var best := 0
	for key: Variant in groups:
		var positions: Array = groups[key]
		positions.sort()
		var run := 1
		for i in range(1, positions.size()):
			run = run + 1 if positions[i] - positions[i - 1] <= 3 else 1
			best = maxi(best, run)
		best = maxi(best, run)
	return best


func _test_exporter_is_deterministic() -> void:
	var script := ProjectSettings.globalize_path("res://").path_join("../docs/design/mapa_export.py").simplify_path()
	if OS.get_environment("SKIP_EXPORTER_CHECK") == "1":
		printerr("AVISO: SKIP_EXPORTER_CHECK=1, o lunata.json NAO foi comparado com o exportador.")
		return
	var probe: Array = []
	# Sem python3 (ou sem o script) o teste FALHA: pular calado deixaria o JSON sair do script sem ninguém ver.
	var tool_ok := FileAccess.file_exists(script) and OS.execute("python3", ["--version"], probe) == 0
	_check(tool_ok, "o exportador do mapa roda aqui (python3 e docs/design/mapa_export.py); para pular de propósito: SKIP_EXPORTER_CHECK=1")
	if not tool_ok:
		return
	var output: Array = []
	var code := OS.execute("python3", ["-I", script, "--check"], output, true)
	_check(code == 0, "o exportador reproduz o lunata.json gravado, byte a byte (%s)" % str(output).left(120))


# ----------------------------------------------------------------------------- terreno

func _test_terrain_tiles() -> void:
	var map := IslandMap.default_map()
	var layers := TerrainTiles.ground_layers(map)
	_check(layers.size() == 6 and layers[0].size() > 0, "seis camadas de chão (funda a pedreira)")
	_check(TerrainTiles.ground_layers(map) == layers, "as camadas são as mesmas na segunda chamada (cache por revisão)")
	# Máscara: N=1 NE=2 L=4 SE=8 S=16 SO=32 O=64 NO=128; diagonal só conta com as duas arestas vizinhas.
	var ranks := PackedByteArray([0, 0, 0, 0, 1, 0, 0, 0, 0])
	_check(TerrainTiles.mask_of(ranks, 4, 3, 1) == 0, "sozinho: nenhum vizinho")
	var full := PackedByteArray([1, 1, 1, 1, 1, 1, 1, 1, 1])
	_check(TerrainTiles.mask_of(full, 4, 3, 1) == 255, "cercado: máscara cheia (miolo)")
	var row := PackedByteArray([1, 1, 1, 0, 0, 0, 0, 0, 0])
	var edge := TerrainTiles.mask_of(row, 4, 3, 1)
	_check(edge == 1, "o vizinho ao norte conta; as diagonais sem as duas arestas não (%d)" % edge)
	var cross := PackedByteArray([0, 1, 0, 1, 1, 1, 0, 1, 0])
	_check(TerrainTiles.mask_of(cross, 4, 3, 1) == (1 | 4 | 16 | 64), "só as quatro arestas, sem diagonais")
	_check(TerrainTiles.tile_for(2, 255) != Vector2i(-1, -1) and TerrainTiles.tile_for(2, 255) != TerrainTiles.tile_for(2, 1)
			and TerrainTiles.tile_for(0, 255) == Vector2i(-1, -1), "a máscara escolhe o tile; o posto 0 (água funda) não tem borda")
	var ground := TerrainTiles.ground_tile_set()
	_check(ground.get_physics_layers_count() == 1 and ground.get_source_count() == 1, "TileSet do chão: uma fonte, uma camada de física")
	var rules: WorldRules = WORLD_RULES
	var scenery := TerrainTiles.scenery_tile_set(rules)
	_check(scenery.get_source_count() == rules.scenery.size(), "uma fonte de cenário por definição (%d)" % scenery.get_source_count())
	var def_ids := {}
	for def in rules.scenery:
		_check(not def_ids.has(def.id) and def.texture != null and def.foot_size.x > 0.0 and def.foot_size.y > 0.0,
				"cenário %s: textura e pés definidos" % def.id)
		def_ids[def.id] = true


func _test_world_rules() -> void:
	var rules: WorldRules = WORLD_RULES
	_check(rules.node_def_of("tree") != null and rules.node_def_of("bush_baga") != null and rules.node_def_of("bush_sono") != null
			and rules.node_def_of("rock") != null and rules.node_def_of("loose_stone") != null, "as defs de nó do mapa existem")
	_check(rules.node_def_of("fiber_plant") == null and rules.node_def_of("berry_bush") == null,
			"a planta de fibra e o arbusto antigo saíram")
	_check(rules.disabled_node_kinds.has("iron_seam") and rules.node_defs.has("iron_seam") and rules.node_def_of("iron_seam") == null,
			"minério existe em dado, desligado na v0.2 (sem coleta)")
	_check(rules.loose_core_respawn_seconds == 300.0 and rules.core_radius_tiles == 16.0,
			"pedra avulsa do núcleo volta em 300 s, raio de 16 tiles")
	_check(rules.level_band_of(IslandMap.QUARRY) == Vector2i(15, 35),
			"população e faixa de nível vêm do dado")
	_check(rules.scenery_by_id("formation_a") != null and rules.scenery_by_id("nada") == null, "cenário por id")


# ----------------------------------------------------------------------------- mundo montado

func _test_main_terrain_and_nodes() -> void:
	var tree := _root.get_tree()
	var main := _main("world_nodes", 20, true)
	await tree.physics_frame
	var map := main.map
	var field := main.resources
	var expected := 0
	for kind: String in map.nodes:
		if not main.world_rules.disabled_node_kinds.has(kind):
			expected += (map.nodes[kind] as Array).size()
	_check(field.node_count() == expected and expected > 500, "um nó por posição do mapa, sem minério (%d)" % field.node_count())
	_check(field.node_by_id("n132") == null, "minério não é instanciado na v0.2")
	_check(field.node_by_id("n316") != null and field.node_by_id("fiber_plant_1") == null, "ids <tipo>_<n>; sem planta de fibra")
	_check(not map.scenery.has("tree_decor"), "toda árvore do mapa é coletável: não há árvore de cenário")
	var node_sum := 0
	for node in field.nodes():
		node_sum += 1
		if node_sum % 40 == 0:
			_check(map.is_land(map.cell_of(node.position)), "o nó %s está em terra firme" % node.node_id)
	# Colisão só nos pés.
	var rock := field.node_by_id("n174")
	var rock_body: StaticBody2D = null
	for child in rock.get_children():
		rock_body = child if child is StaticBody2D else rock_body
	var shape := rock_body.get_child(0) as CollisionShape2D
	var foot := rock.def.foot_size
	_check(rock.blocks_movement() and (shape.shape as RectangleShape2D).size == foot and is_equal_approx(shape.position.y, -foot.y / 2.0),
			"a rocha bloqueia só nos pés (caixa %s apoiada na origem)" % str(foot))
	var bush := field.node_by_id("n1")
	bush.component.harvest()
	await tree.physics_frame
	await tree.physics_frame
	_check(bush.def.blocks_when_full and not bush.blocks_movement(), "o arbusto desfolhado não bloqueia o passo")
	var view_sprite := _first_sprite(rock)
	_check(view_sprite != null and is_equal_approx(view_sprite.offset.y, -view_sprite.texture.get_height()),
			"o sprite sobe da origem: os pés ficam na origem (ordem por Y)")
	var wood := field.node_by_id("n316")
	wood.component.harvest()
	await tree.physics_frame
	await tree.physics_frame
	_check(wood.def.blocks_when_full and not wood.blocks_movement(),
			"o toco da árvore colhida não bloqueia")
	# O mapa estático não está na cena como tiles de nó: o terreno vem do dado.
	var terrain: Node = main.get_node("Terrain")
	var ground0: TileMapLayer = terrain.get_node("Ground0")
	var ring := Vector2i(-1, -1)
	var shallow := Vector2i(-1, -1)
	for y in map.size:
		for x in map.size:
			if ring.x < 0 and map.has_ring_collision(Vector2i(x, y)):
				ring = Vector2i(x, y)
			if shallow.x < 0 and map.terrain_at(Vector2i(x, y)) == IslandMap.SHALLOW:
				shallow = Vector2i(x, y)
	var ring_data := ground0.get_cell_tile_data(ring)
	var shallow_data := ground0.get_cell_tile_data(shallow)
	_check(ring_data != null and ring_data.get_collision_polygons_count(0) == 1, "o anel de água funda tem colisão")
	_check(shallow_data == null or shallow_data.get_collision_polygons_count(0) == 0, "o raso não tem colisão")
	# Quadrantes de render e física são grandes (o motor só processa o que cabe na tela).
	_check(ground0.physics_quadrant_size == 16 and ground0.rendering_quadrant_size >= 16, "quadrantes de física e render definidos")
	# Câmera: limite do mapa inteiro, sem a Main repetir (só o dado).
	var camera := main.get_node("PlayerCamera") as PlayerCamera
	_check(camera.limit_right == 4096 and camera.limit_bottom == 4096 and main.get_node_or_null("Bounds") == null,
			"o limite vem do dado, não da Main")


func _first_sprite(node: ResourceNode) -> Sprite2D:
	for view in node.get_children():
		if view is ResourceNodeView:
			for child in view.get_children():
				if child is Sprite2D:
					return child
	return null


# ----------------------------------------------------------------------------- Soco

func _near(main: Main, node: ResourceNode) -> void:
	main.player.position = node.position + Vector2(0, 10)
	main.player.tick(60.0)  # a recarga da colheita anterior


func _test_punch_rules() -> void:
	var tree := _root.get_tree()
	var main := _main("punch", 20, true)
	await tree.physics_frame
	var player := main.player
	var authority := main.authority
	var floor_hp := player.rules.hand_damage_floor
	_check(floor_hp == 10.0 and player.current_weapon().self_damage == 1.0 and player.current_weapon().damage > 0.0, PUNCH_ONLY)
	# Árvore à mão: coleta e custa 1 de vida por colheita.
	var wood := main.resources.node_by_id("n316")
	_near(main, wood)
	var hp := player.health.current_health
	var logs := player.inventory.count(Items.WOOD)
	_check(authority.request_gather(1, authority.id_of(wood)) == RESULT.OK
		and player.inventory.count(Items.WOOD) == logs + wood.def.yield_amount
			and not wood.is_available()
			and is_equal_approx(player.health.current_health, hp - 1.0), "árvore no Soco: coleta e custa 1 de vida")
	var second := main.resources.node_by_id("n317")
	_near(main, second)
	hp = player.health.current_health
	_check(authority.request_gather(1, authority.id_of(second)) == RESULT.OK and is_equal_approx(player.health.current_health, hp - 1.0),
			"a segunda colheita custa mais 1 (por colheita, não por golpe)")
	# Pedra à mão: um toque, 1 de dano, sem coleta; o nó fica cheio.
	var rock := main.resources.node_by_id("n174")
	_near(main, rock)
	hp = player.health.current_health
	var stones := player.inventory.count(Items.STONE)
	var refused: Array[String] = []
	player.gather_refused.connect(func(reason: String) -> void: refused.append(reason))
	_check(authority.request_gather(1, authority.id_of(rock)) == RESULT.OK and player.inventory.count(Items.STONE) == stones
			and rock.is_available() and is_equal_approx(player.health.current_health, hp - 1.0) and refused == [Player.GATHER_NEEDS_TOOL],
			"rocha no Soco: 1 de dano, nada coletado, o nó segue cheio, a recusa fala por quê")
	# Dino vivo: o golpe custa 1 ao jogador e machuca o dino.
	var creature := main.dino
	player.tick(60.0)
	hp = player.health.current_health
	var creature_hp := creature.health.current_health
	var torpor := creature.torpor.current_torpor
	_check(player.strike(creature) and is_equal_approx(player.health.current_health, hp - 1.0)
			and (creature.health.current_health < creature_hp
			or creature.torpor.current_torpor > torpor), "dino vivo: o golpe machuca o dino e custa 1 ao jogador")
	# Carcaça à mão: 1 de dano por item. A def é dado; o nó nasce de uma morte (SOB-06), aqui montado à mão.
	var def: ResourceNodeDef = load("res://data/resources/carcass_meat.tres")
	var carcass: ResourceNode = preload("res://src/entities/resource/ResourceNode.tscn").instantiate()
	carcass.node_id = "carcass_test"
	carcass.def = def
	carcass.position = player.position + Vector2(0, 8)
	main.resources.add_node(carcass)
	authority.register(carcass)
	player.tick(60.0)
	hp = player.health.current_health
	var meat := player.inventory.count(Items.MEAT)
	_check(def.hand_can_gather() and authority.request_gather(1, authority.id_of(carcass)) == RESULT.OK
			and player.inventory.count(Items.MEAT) == meat + def.yield_amount
			and is_equal_approx(player.health.current_health, hp - def.hand_self_damage * def.yield_amount),
			"carcaça à mão: 1 de dano por item entregue")
	# Piso: com 10 de vida, nenhum Soco (golpe, toque, colheita) baixa a vida, e o jogo segue.
	player.health.current_health = floor_hp + 0.5
	player.tick(60.0)
	_check(player.strike(creature) and player.health.current_health == floor_hp, "o Soco para em 10 de vida (tirou só o que cabia)")
	player.tick(60.0)
	_check(player.strike(creature) and player.health.current_health == floor_hp and not player.health.is_dead(),
			"no piso: nada mais é tirado")
	var third := main.resources.node_by_id("n318")
	_near(main, third)
	_check(authority.request_gather(1, authority.id_of(third)) == RESULT.OK and player.health.current_health == floor_hp
			and not third.is_available(), "no piso a árvore ainda é colhida, sem custo, sem morrer")
	# A conta do piso é do componente de vida: tira o que cabe acima do piso e nunca mata.
	player.health.current_health = 50.0
	_check(player.health.take_damage_down_to(3.0, floor_hp) == 3.0 and player.health.current_health == 47.0,
			"acima do piso tira o valor inteiro")
	_check(player.health.take_damage_down_to(100.0, floor_hp) == 37.0 and player.health.current_health == floor_hp,
			"o excedente nunca passa do piso")
	_check(player.health.take_damage_down_to(-5.0, floor_hp) == 0.0 and player.health.current_health == floor_hp,
			"valor negativo não cura nem fere")


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
	# Recarga.
	var hp := player.health.current_health
	_check(authority.request_gather(1, authority.id_of(wood)) == RESULT.OK, "preparo: colheu a árvore")
	var other := main.resources.node_by_id("n317")
	other.position = player.position + Vector2(0, 6)
	hp = player.health.current_health
	_check(authority.request_gather(1, authority.id_of(other)) == RESULT.COOLDOWN and other.is_available()
		and player.health.current_health == hp,
			"em recarga: negado, sem custo, o nó não gasta")
	# Esgotado.
	player.tick(60.0)
	hp = player.health.current_health
	_check(authority.request_gather(1, authority.id_of(wood)) == RESULT.WRONG_STATE and player.health.current_health == hp,
			"esgotado: negado, sem custo")
	# Sem espaço: nada é colhido nem cobrado.
	var bush := main.resources.node_by_id("n319")
	_near(main, bush)
	while player.inventory.room_for(Items.WOOD) > 0:
		var filler := Items.STONE if player.inventory.room_for(Items.STONE) > 0 else Items.WOOD
		player.inventory.add(filler, 1)
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


# ----------------------------------------------------------------------------- zona ativa

func _test_zone_classify() -> void:
	var rules: ZoneRules = load("res://data/world/zone_rules.tres")
	_check(rules.active_radius_tiles == 16.0 and rules.far_radius_tiles == 40.0 and rules.max_active == 32
		and rules.far_step_seconds == 2.0,
			"a zona vem do dado: raio ativo 16, distante 40, teto 32, passeio de 2 s")
	var px := rules.tile_size
	var distances := PackedFloat32Array([0.0, 16.0 * px, 16.0 * px + 1.0, 40.0 * px, 40.0 * px + 1.0, 1000.0 * px])
	var pinned := PackedByteArray([0, 0, 0, 0, 0, 0])
	var modes := ActivityZone.classify(distances, pinned, rules)
	_check(modes == [ActivityZone.Mode.ACTIVE, ActivityZone.Mode.ACTIVE, ActivityZone.Mode.FAR, ActivityZone.Mode.FAR,
			ActivityZone.Mode.DORMANT, ActivityZone.Mode.DORMANT], "bordas dos raios: 16 ainda ativo, 40 ainda distante, depois dorme")
	_check(ActivityZone.classify(PackedFloat32Array(), PackedByteArray(), rules).is_empty(), "sem dinos, sem modos")
	# Teto: 50 dinos dentro do raio, só os 32 mais perto ficam ativos; os outros viram distantes.
	var many := PackedFloat32Array()
	var none := PackedByteArray()
	many.resize(50)
	none.resize(50)
	for i in 50:
		many[i] = float(50 - i) * 4.0  # o último é o mais perto
	var capped := ActivityZone.classify(many, none, rules)
	var active := 0
	for mode in capped:
		active += 1 if mode == ActivityZone.Mode.ACTIVE else 0
	_check(active == 32 and capped[49] == ActivityZone.Mode.ACTIVE and capped[0] == ActivityZone.Mode.FAR,
			"teto de 32 ativos: ficam os mais perto")
	# Fixados pelo estado: ativos mesmo longe, e ocupam vaga (os outros disputam o resto).
	var far_pinned := PackedByteArray()
	far_pinned.resize(50)
	far_pinned[0] = 1
	far_pinned[1] = 1
	many[0] = 500.0 * px
	var with_pins := ActivityZone.classify(many, far_pinned, rules)
	active = 0
	for mode in with_pins:
		active += 1 if mode == ActivityZone.Mode.ACTIVE else 0
	_check(with_pins[0] == ActivityZone.Mode.ACTIVE and with_pins[1] == ActivityZone.Mode.ACTIVE and active == 32,
			"fixado fica ativo longe do jogador e conta nas 32 vagas")
	# Mais de 32 fixados: todos ficam (não se desliga domado), os outros não ganham vaga.
	var all_pinned := PackedByteArray()
	all_pinned.resize(50)
	all_pinned.fill(1)
	var every := ActivityZone.classify(many, all_pinned, rules)
	_check(every.count(ActivityZone.Mode.ACTIVE) == 50, "fixados passam do teto: nunca se desliga quem precisa do relógio")
	# Determinismo.
	var again := ActivityZone.classify(many, none, rules)
	_check(ActivityZone.classify(many, none, rules) == again, "a classificação é determinística")


func _test_zone_in_main() -> void:
	var tree := _root.get_tree()
	var main := _main("zone", 20, true)
	await tree.physics_frame
	var zone := main.zone
	# Reproduzível: o mesmo mapa dá os mesmos selvagens, nos mesmos lugares e níveis.
	var again := _main("zone_again", 20, true)
	var same := again.wild.get_child_count() == main.wild.get_child_count()
	for i in again.wild.get_child_count():
		var left := main.wild.get_child(i) as Dino
		var right := again.wild.get_child(i) as Dino
		same = same and left.position == right.position and left.level == right.level
	_check(same, "o mesmo mapa dá os mesmos selvagens, nos mesmos lugares e níveis")
	var raptors := 0
	for creature in main.wild.get_children():
		raptors += 1 if (creature as Dino).stats.spawn_key == "utahraptor" else 0
	_check(raptors == 10 and zone.dino_count() == main.wild.get_child_count() + 1 and main.wild.get_child_count() == 80,
			"a ilha nasce com 24 bandos conhecidos (70 paquicéfalos e 10 utahraptores) mais o do tutorial (%d)" % zone.dino_count())
	_check(zone.active_count + zone.far_count + zone.dormant_count == zone.dino_count() and zone.active_count <= 32,
			"todo dino tem modo e o teto vale")
	_check(zone.far_count > 0 and zone.dormant_count > 0, "do início há dino distante e dormindo")
	var map := main.map
	var levels_ok := true
	for creature in main.wild.get_children():
		var band := main.world_rules.level_band_of(map.terrain_at(map.cell_of(creature.position)))
		levels_ok = levels_ok and (creature as Dino).level >= band.x and (creature as Dino).level <= band.y \
				and map.is_land(map.cell_of(creature.position))
	_check(levels_ok, "todo selvagem nasce em terra e com nível da faixa do bioma")
	# Dormente: sem processamento e sem desenho. Ativo: processa.
	var dormant: Dino = null
	for creature in zone.dinos():
		if creature == main.dino:
			continue  # o do tutorial a `_main` deixa ligado de propósito
		match zone.mode_of(creature):
			ActivityZone.Mode.DORMANT:
				dormant = creature if dormant == null else dormant
	_check(dormant != null and dormant.process_mode == Node.PROCESS_MODE_DISABLED and not dormant.visible,
			"dormente: sem processamento e sem desenho")
	# Distante: só dado. Passeia no tempo do dado e só por terra.
	var distant: Dino = null
	for creature in zone.dinos():
		var tiles := creature.position.distance_to(main.player.position) / 16.0
		if creature != main.dino and zone.mode_of(creature) == ActivityZone.Mode.FAR and tiles > 30.0:
			distant = creature
			break
	_check(distant != null, "preparo: há um distante no meio da faixa de 16 a 40 tiles")
	var start := distant.position
	var moved := 0
	for i in 6:  # poucos passos: o distante não chega perto o bastante para virar ativo
		zone.tick(main.zone.rules.far_step_seconds)
		if distant.position != start:
			moved += 1
		_check(map.is_land(map.cell_of(distant.position)) or zone.mode_of(distant) != ActivityZone.Mode.FAR,
				"o passeio do distante fica em terra")
	_check(moved > 0 and distant.process_mode == Node.PROCESS_MODE_DISABLED, "o distante anda em dado (sem processamento próprio)")
	# O jogador anda: a zona reclassifica. Longe de todos, todos dormem; perto de um dormente, ele acorda.
	var target := dormant.position
	main.player.position = target
	zone.tick(zone.rules.reevaluate_seconds)
	_check(zone.mode_of(dormant) == ActivityZone.Mode.ACTIVE and dormant.process_mode == Node.PROCESS_MODE_INHERIT and dormant.visible,
			"o jogador chega perto: o dormente acorda, e ativo pensa e desenha")
	main.player.position = Vector2(8, 8)  # no mar, longe de tudo
	zone.tick(zone.rules.reevaluate_seconds)
	_check(zone.active_count == 0 and zone.far_count == 0 and zone.dormant_count == zone.dino_count(), "longe de todos, todos dormem")
	# Fixado pelo estado: domado fica ativo mesmo longe.
	main.dino.torpor.add_torpor(main.dino.torpor.max_torpor)
	_check(main.dino.state_machine.mark_tamed(), "preparo: o dino do tutorial foi domado")
	main.dino.owner_player_id = main.player.player_id
	zone.tick(zone.rules.reevaluate_seconds)
	_check(zone.mode_of(main.dino) == ActivityZone.Mode.ACTIVE and main.dino.process_mode == Node.PROCESS_MODE_INHERIT,
			"o domado fica ativo longe do dono (o relógio dele corre)")
	_check(zone.active_count == 1, "só o domado ficou ativo")
	# Quem sai do mundo sai da zona.
	var before := zone.dino_count()
	var gone: Dino = main.wild.get_child(0)
	gone.free()
	zone.reclassify()
	_check(zone.dino_count() == before - 1, "dino removido sai da zona")


func _test_zone_load_360() -> void:
	var tree := _root.get_tree()
	for child in _root.get_children():  # os mundos dos testes anteriores pesariam na medida
		if child is Main:
			child.free()
	var main := _main("load360", 20, true)
	main.wild.process_mode = Node.PROCESS_MODE_INHERIT
	main.zone.set_physics_process(true)  # a carga roda a zona de verdade, a cada quadro
	var map := main.map
	var rng := SeededRng.new()
	rng.seed_from(["carga"])
	var spawns: Array = []
	for creature in main.wild.get_children():
		spawns.append(map.cell_of((creature as Dino).position))
	var guard := 0
	while main.zone.dino_count() < 360 and guard < 5000:
		guard += 1
		var cell: Vector2i = (spawns[rng.next_below(spawns.size())] as Vector2i) + Vector2i(rng.next_below(9) - 4, rng.next_below(9) - 4)
		if not map.is_land(cell):
			continue
		var creature: Dino = WildPopulation.DINO_SCENE.instantiate()
		creature.position = map.center_of(cell)
		main.wild.add_child(creature)
		main.zone.register(creature, false)
	main.zone.reclassify()
	_check(main.zone.dino_count() == 360, "carga: 360 dinos na ilha")
	_check(main.zone.active_count <= 32 and main.zone.active_count + main.zone.far_count + main.zone.dormant_count == 360,
			"carga: no máximo 32 ativos (%d ativos, %d distantes, %d dormem)"
			% [main.zone.active_count, main.zone.far_count, main.zone.dormant_count])
	for i in 5:
		await tree.physics_frame
	var samples: Array[float] = []
	for i in 60:
		await tree.physics_frame
		samples.append(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0)
	samples.sort()
	var millis := samples[samples.size() >> 1]  # a mediana: o primeiro quadro paga a montagem dos quadrantes de física
	print("   carga com 360 dinos: física %.2f ms por quadro (mediana; pior %.0f ms no 1o quadro; headless)" % [millis, samples.back()])
	if millis >= 8.0:  # aviso, não falha: o tempo depende da máquina e da carga (já deu falso vermelho)
		print("   AVISO: física com 360 dinos passou de metade do orçamento de 16 ms (%.2f ms)" % millis)
	_check(main.zone.active_count <= 32, "carga: o teto de 32 ativos se mantém depois de 60 quadros")


# ----------------------------------------------------------------------------- save v5

func _test_save_v5() -> void:
	var tree := _root.get_tree()
	var manager := SaveManager.new(root_dir)
	var outcome := manager.read_file(FIXTURE_V5)
	_check(outcome.status == SaveManager.Status.OK and outcome.data.get("format_version") == 5 and SaveMigrations.CURRENT_VERSION == 5,
			"fixture v5 carrega sem migrar")
	var world: Dictionary = outcome.data.get("world", {})
	_check(world.get("map_id") == "lunata" and world.get("map_revision") == SaveMigrations.FIRST_ID_MAP_HASH
			and not world.has("rows") and not world.has("nodes"),
			"o save leva o id e o hash do mapa (o da exportação em que a fixture foi gravada), nunca o mapa")
	_check(FileAccess.get_file_as_string(FIXTURE_V5).length() < 8000, "o save é pequeno: o mapa estático fica fora dele")
	var main := _main("fixture_v5", 20, true)
	await tree.physics_frame
	var pair := [main.player, main.dino]
	_check(WorldSnapshot.restore(outcome.data, pair[0], pair[1], main.resources, main.wild, main.carcasses, main.authority),
			"fixture v5 é aplicada ao mundo")
	_check(main.player.player_id == world["local_player_id"] and main.authority.clock.now() == 1000.0,
			"o jogador local vem de world.local_player_id e o relógio do mundo é reposto")
	_check(main.wild.creature_at(_wid(main, 3)) != null and not main.wild.is_dead(_wid(main, 3))
			and main.wild.creature_at(_wid(main, 4)) != null
			and main.wild.world_seed == IslandMap.default_map().seed_value,
			"save anterior à emenda: o id w3 do delta é ignorado (ninguém some) e, sem world.seed, vale a semente do mapa")
	var stone := main.resources.node_by_id("n160")
	var wood := main.resources.node_by_id("n318")
	_check(not stone.is_available() and stone.component.due_at == 1500.0 and not wood.is_available()
		and wood.component.due_at == 1230.0,
			"só os nós esgotados voltam esgotados, com o instante em que voltam")
	_check(main.carcasses.count() == 1, "a carcaça do save volta (nasceu em 850, o relógio está em 1000)")
	_check(main.resources.node_by_id("n316").is_available() and main.resources.node_by_id("n174").is_available(),
			"o resto do mapa segue cheio")
	_check(main.resources.to_list().size() == 2, "to_list leva só os 2 esgotados")
	# O relógio decide: em 1230 a árvore volta, a pedra ainda não; em 1450 a carcaça (600 s) já passou.
	TestWorld.pass_time(main, 230.0)
	_check(wood.is_available() and not stone.is_available(), "aos 1230 s a árvore volta e a pedra segue esgotada")
	TestWorld.pass_time(main, 220.0)
	_check(main.carcasses.count() == 0, "aos 1450 s a carcaça de 850 some (600 s)")
	# Roundtrip: salvar o que a Main tem e carregar gera o mesmo estado dos nós, e o arquivo não cresce com o mapa.
	_check(main.save_game(SaveManager.Reason.BED), "salva o mundo restaurado")
	var raw := FileAccess.get_file_as_string(main.save_manager.main_path())
	_check(raw.length() < 8000 and raw.contains('"map_id"') and raw.contains("n160") and raw.contains('"time"'),
			"o arquivo salvo é pequeno e leva só o estado dos nós e o relógio")
	GameSession.continue_requested = true
	var again := _main("fixture_v5", 20, true)
	await tree.physics_frame
	_check(not again.resources.node_by_id("n160").is_available() and again.resources.node_by_id("n160").component.due_at == 1500.0
			and absf(again.authority.clock.now() - 1450.0) < 1.0, "Continuar mantém os nós esgotados, os instantes e o relógio")
	_check(again.player.position == Vector2(2296, 3160), "Continuar mantém a posição do jogador dentro da ilha")
	_check(again.player.player_id == main.player.player_id, "Continuar mantém o player_id")
	# Hostil: lista de nós com lixo, posição fora da ilha e mapa de outra revisão.
	var hostile := outcome.data.duplicate(true)
	hostile["world"]["resource_nodes"] = [5, "x", {"id": "n316", "def": "tree", "depleted": true, "due_at": 1.0e30},
			{"id": "nao_existe"}]
	hostile["players"][0]["state"]["position"] = {"x": -5000.0, "y": 1.0e9}
	var other := _main("hostile_v5", 20, true)
	await tree.physics_frame
	_check(WorldSnapshot.restore(hostile, other.player, other.dino, other.resources, null, null, other.authority),
			"save hostil é aceito sem abortar")
	other._keep_on_island(false)
	_check(other.player.position == other.map.safe_point()
			and other.resources.node_by_id("n316").component.due_at <= other.authority.clock.now() + 480.0,
			"posição fora da ilha vai ao ponto seguro; instante absurdo é limitado")
	# `next_entity_id` é obrigatório no v5.
	var without := outcome.data.duplicate(true)
	without["world"].erase("next_entity_id")
	var third := _main("no_next_id", 20, true)
	await tree.physics_frame
	_check(not WorldSnapshot.restore(without, third.player, third.dino, third.resources, third.wild, third.carcasses, third.authority),
			"v5 sem world.next_entity_id é recusado")
	# Migração v3 para v4 pura e repetível (o salto continua na tabela).
	var v3: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE_V3))
	var migrated := SaveMigrations.v3_to_v4(v3)
	_check(migrated["world"]["map_id"] == "lunata" and migrated["world"]["map_revision"] == 0
			and WorldSnapshot.has_legacy_coordinates(migrated), "v3 para v4: id do mapa, revisão 0 e marca de coordenadas antigas")
	_check(v3["format_version"] == 3 and v3["world"]["map_id"] == "main", "a migração não altera o dado de entrada")
	_check(not WorldSnapshot.has_legacy_coordinates(outcome.data), "o save novo não é marcado como antigo")


func _test_migration_v4_to_v5() -> void:
	var tree := _root.get_tree()
	var fixed_id := "3f9c1a7be2d84f60a15c9e7d0b4a2c68"
	var v4: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE_V4))
	var before := v4.duplicate(true)
	var v5 := SaveMigrations.v4_to_v5(v4, fixed_id)
	_check(v4 == before, "a migração v4 para v5 não altera o dado de entrada")
	_check(v5 == SaveMigrations.v4_to_v5(v4, fixed_id), "a migração é pura: o mesmo v4 e o mesmo id dão o mesmo v5")
	var world: Dictionary = v5["world"]
	_check(world["map_revision"] == SaveMigrations.FIRST_ID_MAP_HASH and world["time"] == 0.0
			and world["local_player_id"] == fixed_id and v5["players"][0]["player_id"] == fixed_id,
			"v5: revisão em texto (hash), world.time 0 e o jogador 'local' vira o id novo")
	_check(world["wild"] == [{"dead": true, "id": "w3"}], "o delta do selvagem passa de índice 3 para o id w3")
	var due := {}
	for node: Dictionary in world["resource_nodes"]:
		due[node["id"]] = node["due_at"]
		_check(not node.has("respawn_left"), "o nó migrado não guarda mais o que faltava")
	_check(due == {"n160": 500.0, "n318": 230.0}, "loose_stone_11 vira n160 e tree_3 vira n318, com due_at = o que faltava")
	var sex: String = v5["entities"][0]["state"]["sex"]
	_check(sex == SaveMigrations.v4_sex(2) and (sex == "f" or sex == "m") and SaveMigrations.v4_sex(2) == sex,
			"o dino ganha sexo por [sex, v4, id da entidade], igual em toda chamada")
	_check(SaveMigrations.v4_sex(5) == SaveMigrations.v4_sex(int(5.0)), "o id entra como inteiro (o JSON devolve 5.0)")
	_check(int(world["next_entity_id"]) >= 581, "next_entity_id nunca fica abaixo do que já existe")
	# Outra revisão (ou mapa antigo): o delta cai, domados ficam, a revisão vira texto.
	var other_rev := v4.duplicate(true)
	other_rev["world"]["map_revision"] = 99
	var dropped := SaveMigrations.v4_to_v5(other_rev, fixed_id)
	_check(dropped["world"]["wild"] == [] and dropped["world"]["resource_nodes"] == [] and dropped["world"]["map_revision"] == "99"
			and dropped["entities"].size() == 1, "outra revisão: delta de selvagem e de nó descartados, entidades ficam")
	var legacy := v4.duplicate(true)
	legacy["world"]["legacy_coordinates"] = true
	_check(SaveMigrations.v4_to_v5(legacy, fixed_id)["world"]["resource_nodes"] == [], "coordenadas legadas: o delta cai")
	# Id de jogador que não é "local" fica como está.
	var named := v4.duplicate(true)
	named["players"][0]["player_id"] = "outro"
	_check(SaveMigrations.v4_to_v5(named, fixed_id)["world"]["local_player_id"] == "outro", "player_id que não é 'local' não é trocado")
	# Entradas malformadas seguem como vieram: a carga as recusa, a migração não as conserta.
	var junk := v4.duplicate(true)
	junk["world"]["wild"] = [{"index": -3, "dead": true}, {"index": "x", "dead": true}, 5]
	var junk_out: Array = SaveMigrations.v4_to_v5(junk, fixed_id)["world"]["wild"]
	_check(junk_out == [{"index": -3, "dead": true}, {"index": "x", "dead": true}, 5], "índice inválido não vira id")
	# A numeração congelada é a da primeira exportação com ids, e a migração não lê o arquivo de hoje (o hash dele muda a cada
	# exportação): confere a tabela contra si mesma e com os nós do mapa só quando ele ainda tem aquele bloco.
	var map := IslandMap.default_map()
	var next_free := 0
	for kind: String in SaveMigrations.V4_NODE_BLOCKS:  # as chaves já estão em ordem alfabética: os blocos são contíguos
		var block: Array = SaveMigrations.V4_NODE_BLOCKS[kind]
		_check(int(block[0]) == next_free, "a tabela congelada de %s começa onde a anterior terminou" % kind)
		next_free += int(block[1])
		var ids: Array = map.node_ids.get(kind, [])
		if ids.size() == int(block[1]):
			_check(ids[0] == "n%d" % (int(block[0]) + 1) and ids[-1] == "n%d" % (int(block[0]) + int(block[1])),
					"os ids de nó de %s no mapa seguem a tabela congelada" % kind)
	_check(next_free == 1344 and SaveMigrations.V4_SPAWN_COUNT == 117, "a tabela congelada: 1344 nós e 117 selvagens")
	var edge_wild: Array = SaveMigrations.v4_to_v5({"world": {"map_id": "lunata", "map_revision": 2, "wild": [
			{"index": 0, "dead": true}, {"index": 116, "dead": true}, {"index": 117, "dead": true}]}}, fixed_id)["world"]["wild"]
	_check(edge_wild[0]["id"] == "w0" and edge_wild[1]["id"] == "w116" and edge_wild[2].has("index"),
			"índice 0 a 116 do v4 vira w0 a w116; o 117 (fora da lista de então) não vira id")
	# Mesmo segundo de jogo antes e depois: o nó (230 s) e a carcaça (idade 100 de 600) vencem como venceriam no v4.
	var aged := v4.duplicate(true)
	aged["world"]["carcasses"] = [{"id": 570, "species": "placeholder_dino", "level": 12, "x": 2000.0, "y": 3000.0, "age": 100.0}]
	var mig := SaveMigrations.v4_to_v5(aged, fixed_id)
	_check(mig["world"]["carcasses"][0]["born_at"] == -100.0 and not mig["world"]["carcasses"][0].has("age"),
			"carcaça: age 100 vira born_at -100")
	var main := _main("mig_same_second", 20, true)
	await tree.physics_frame
	mig["format_version"] = 5
	_check(WorldSnapshot.restore(mig, main.player, main.dino, main.resources, main.wild, main.carcasses, main.authority),
			"o v5 migrado é aplicado")
	TestWorld.pass_time(main, 229.0)
	_check(not main.resources.node_by_id("n318").is_available() and main.carcasses.count() == 1, "aos 229 s a árvore ainda não voltou")
	TestWorld.pass_time(main, 1.0)
	_check(main.resources.node_by_id("n318").is_available(), "aos 230 s a árvore volta (como no v4)")
	TestWorld.pass_time(main, 269.0)
	_check(main.carcasses.count() == 1, "aos 499 s a carcaça (idade 100) ainda está")
	TestWorld.pass_time(main, 1.0)
	_check(main.carcasses.count() == 0, "aos 500 s a carcaça (idade 100 + 500 = 600) some (como no v4)")
	# Pelo caminho do arquivo: o `SaveManager` migra com id aleatório e o Continuar o aplica.
	var manager := SaveManager.new(root_dir, "from_v4")
	DirAccess.make_dir_recursive_absolute(manager.main_path().get_base_dir())
	var written := FileAccess.open(manager.main_path(), FileAccess.WRITE)
	written.store_string(FileAccess.get_file_as_string(FIXTURE_V4))
	written.close()
	GameSession.continue_requested = true
	var loaded := _main("from_v4", 20, true)
	await tree.physics_frame
	_check(loaded.player.player_id.length() == 32 and loaded.player.player_id != "local"
			and loaded.player.player_id.is_valid_hex_number(false),
			"Continuar de um v4: o jogador ganha um id aleatório de 32 hex")
	_check(not loaded.wild.is_dead(_wid(loaded, 3)) and not loaded.resources.node_by_id("n318").is_available(),
			"Continuar de um v4: o delta de nó vale por id; o de selvagem w<n> é de outro modelo e é ignorado")


func _test_continue_from_v3() -> void:
	var tree := _root.get_tree()
	var main := _main("from_v3", 20, true)
	await tree.physics_frame
	var manager := SaveManager.new(root_dir, "from_v3")
	DirAccess.make_dir_recursive_absolute(manager.main_path().get_base_dir())
	var written := FileAccess.open(manager.main_path(), FileAccess.WRITE)
	written.store_string(FileAccess.get_file_as_string(FIXTURE_V3))
	written.close()
	GameSession.continue_requested = true
	var loaded := _main("from_v3", 20, true)
	await tree.physics_frame
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE_V3))
	_check(loaded.dino.level == 28 and loaded.dino.state_machine.is_tamed and loaded.dino.owner_player_id == loaded.player.player_id,
			"Continuar de um save v3: o dino domado e o nível voltam (sem perder o bicho)")
	var saved_hunger: float = raw["players"][0]["state"]["hunger"]["current"]
	_check(is_equal_approx(loaded.player.hunger.current_hunger, saved_hunger), "Continuar de um save v3: o estado do jogador volta")
	_check(loaded.map.is_walkable_at(loaded.player.position) and loaded.player.position == loaded.map.safe_point(),
			"a posição do mapa antigo vai ao ponto seguro da ilha")
	_check(loaded.map.is_walkable_at(loaded.dino.position) and loaded.dino.position.distance_to(loaded.player.position) < 64.0,
			"o dino que ficou fora vem para perto do jogador")
	_check(loaded.zone.mode_of(loaded.dino) == ActivityZone.Mode.ACTIVE, "o domado carregado fica ativo na zona")
	_check(loaded.save_game(SaveManager.Reason.BED), "depois de carregar o v3, salvar grava no formato novo")
	var after: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(loaded.save_manager.main_path()))
	_check(after["format_version"] == 5 and not WorldSnapshot.has_legacy_coordinates(after),
			"o arquivo regravado é v5 e sem a marca de mapa antigo")
	main.free()
