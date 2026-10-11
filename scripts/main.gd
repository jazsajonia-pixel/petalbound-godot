extends Node2D

const PLAYER_SCRIPT = preload("res://scripts/player.gd")
const HUD_SCRIPT = preload("res://scripts/hud.gd")
const ENEMY_SCRIPT = preload("res://scripts/enemy.gd")
const WORLD_SIZE := Vector2(1800, 1100)
const RUINS := [Vector2(420, 300), Vector2(760, 190), Vector2(1120, 465), Vector2(1450, 275), Vector2(560, 790), Vector2(1000, 900), Vector2(1450, 820)]
const PATH_POINTS := [Vector2(130, 150), Vector2(310, 430), Vector2(630, 500), Vector2(880, 635), Vector2(1190, 570), Vector2(1470, 640), Vector2(1660, 545)]
const SEEDS := [Vector2(345, 520), Vector2(900, 635), Vector2(1315, 610)]
const SHRINE := Vector2(1660, 545)
const CABIN := Vector2(255, 245)
const CACHE := Vector2(635, 395)
const POND_CENTER := Vector2(965, 318)
const GROUND_TEXTURE = preload("res://assets/packs/mini_meadow/sheets/ground.png")
const PALETTE_SHADER = preload("res://assets/shaders/meadow_palette.gdshader")
const VIGNETTE_SHADER = preload("res://assets/shaders/meadow_vignette.gdshader")
const PROP_FLOWER_PINK = preload("res://assets/packs/mini_meadow/tiles/flower_pink.png")
const PROP_FLOWER_WHITE = preload("res://assets/packs/mini_meadow/tiles/flower_white.png")
const PROP_BUSH = preload("res://assets/packs/mini_meadow/tiles/bush.png")
const PROP_ROCK = preload("res://assets/packs/mini_meadow/tiles/rock.png")
const PROP_PEBBLES = preload("res://assets/packs/mini_meadow/tiles/pebbles.png")
const PROP_MUSHROOM = preload("res://assets/packs/mini_meadow/tiles/mushroom_red.png")
const PROP_LOG = preload("res://assets/packs/mini_meadow/tiles/log.png")
const PROP_STUMP = preload("res://assets/packs/mini_meadow/tiles/stump.png")

var player: CharacterBody2D
var hud: Control
var ground_layer: TileMapLayer
var seed_taken: Array[bool] = [false, false, false]
var seed_count := 0
var elapsed := 0.0
var petals: Array[Dictionary] = []
var effect_bursts: Array[Dictionary] = []
var enemies: Array[Node2D] = []
var water_cells: Array[Vector2i] = []
var water_frame := 0
var water_timer := 0.0
var won := false
var game_started := false
var cache_opened := false
var rng := RandomNumberGenerator.new()
var light_texture: GradientTexture2D

func _ready() -> void:
	_rng_setup()
	_make_ground()
	_make_props()
	_make_petals()
	_make_structures_and_collisions()
	_make_world_bounds()
	_make_player()
	_make_camera()
	_make_enemies()
	_make_world_lighting()
	_make_hud()
	queue_redraw()

func _rng_setup() -> void:
	rng.seed = 40821

func _make_ground() -> void:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(16, 16)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = GROUND_TEXTURE
	atlas.texture_region_size = Vector2i(16, 16)
	for x in range(9):
		atlas.create_tile(Vector2i(x, 0))
	tile_set.add_source(atlas, 0)
	ground_layer = TileMapLayer.new()
	ground_layer.name = "CC0MeadowGround"
	ground_layer.tile_set = tile_set
	ground_layer.z_index = -20
	var palette := ShaderMaterial.new()
	palette.shader = PALETTE_SHADER
	palette.set_shader_parameter("meadow_tint", 0.68)
	palette.set_shader_parameter("water_tint", 0.42)
	ground_layer.material = palette
	add_child(ground_layer)
	for y in range(int(WORLD_SIZE.y / 16.0) + 1):
		for x in range(int(WORLD_SIZE.x / 16.0) + 1):
			var grass_cell := Vector2i(1 if rng.randf() < 0.22 else 0, 0)
			ground_layer.set_cell(Vector2i(x, y), 0, grass_cell)
	_paint_paths()
	_paint_stone_courts()
	_paint_pond()

func _paint_paths() -> void:
	for segment in range(PATH_POINTS.size() - 1):
		var start: Vector2 = PATH_POINTS[segment]
		var finish: Vector2 = PATH_POINTS[segment + 1]
		var delta := finish - start
		var steps := maxi(1, ceili(delta.length() / 8.0))
		var across := Vector2(-delta.normalized().y, delta.normalized().x)
		for step in range(steps + 1):
			var point := start.lerp(finish, float(step) / float(steps))
			var center := Vector2i(roundi(point.x / 16.0), roundi(point.y / 16.0))
			for lane in range(-1, 2):
				var side := Vector2i(roundi(across.x * lane), roundi(across.y * lane))
				ground_layer.set_cell(center + side, 0, Vector2i(2, 0))

func _paint_stone_courts() -> void:
	for point in RUINS:
		var center := Vector2i(roundi(point.x / 16.0), roundi(point.y / 16.0))
		for y in range(-3, 4):
			for x in range(-3, 4):
				if absf(float(x)) + absf(float(y)) < 6.0:
					ground_layer.set_cell(center + Vector2i(x, y), 0, Vector2i(4, 0))
	var cabin_center := Vector2i(roundi(CABIN.x / 16.0), roundi((CABIN.y + 35.0) / 16.0))
	for y in range(-2, 3):
		for x in range(-4, 5):
			ground_layer.set_cell(cabin_center + Vector2i(x, y), 0, Vector2i(4, 0))

func _paint_pond() -> void:
	var center := Vector2i(roundi(POND_CENTER.x / 16.0), roundi(POND_CENTER.y / 16.0))
	for y in range(-5, 6):
		for x in range(-7, 8):
			var measure := pow(float(x) / 7.0, 2.0) + pow(float(y) / 5.0, 2.0)
			if measure <= 1.0:
				var cell := center + Vector2i(x, y)
				if measure > 0.67:
					ground_layer.set_cell(cell, 0, Vector2i(3, 0))
				else:
					water_cells.append(cell)
					ground_layer.set_cell(cell, 0, Vector2i(5, 0))

func _make_props() -> void:
	var fixed_props: Array[Dictionary] = [
		{"texture": PROP_LOG, "position": Vector2(400, 460), "scale": 2.0},
		{"texture": PROP_STUMP, "position": Vector2(490, 590), "scale": 2.0, "solid": true},
		{"texture": PROP_ROCK, "position": Vector2(780, 490), "scale": 2.0, "solid": true},
		{"texture": PROP_MUSHROOM, "position": Vector2(1030, 385), "scale": 2.0},
		{"texture": PROP_ROCK, "position": Vector2(1000, 386), "scale": 1.7},
		{"texture": PROP_LOG, "position": Vector2(1230, 455), "scale": 2.0},
		{"texture": PROP_STUMP, "position": Vector2(1390, 710), "scale": 2.0, "solid": true},
		{"texture": PROP_ROCK, "position": Vector2(335, 760), "scale": 2.1, "solid": true},
		{"texture": PROP_MUSHROOM, "position": Vector2(1520, 390), "scale": 2.0}
	]
	for prop in fixed_props:
		_add_prop(prop["texture"], prop["position"], float(prop.get("scale", 1.0)), bool(prop.get("solid", false)))
	var flower_textures := [PROP_FLOWER_PINK, PROP_FLOWER_WHITE]
	for i in range(105):
		var point := Vector2(rng.randf_range(54.0, WORLD_SIZE.x - 54.0), rng.randf_range(54.0, WORLD_SIZE.y - 54.0))
		if _is_busy_location(point, 56.0):
			continue
		_add_prop(flower_textures[rng.randi_range(0, flower_textures.size() - 1)], point, 1.55)
	for i in range(25):
		var point := Vector2(rng.randf_range(85.0, WORLD_SIZE.x - 85.0), rng.randf_range(85.0, WORLD_SIZE.y - 85.0))
		if _is_busy_location(point, 100.0):
			continue
		_add_prop(PROP_BUSH, point, 2.2, true)
		if i % 3 == 0:
			_add_prop(PROP_PEBBLES, point + Vector2(24, 13), 1.6)

func _is_busy_location(point: Vector2, clearance: float) -> bool:
	if point.distance_to(Vector2(130, 150)) < 88.0 or point.distance_to(CABIN) < 100.0 or point.distance_to(CACHE) < 78.0 or point.distance_to(POND_CENTER) < 140.0 or point.distance_to(SHRINE) < 110.0:
		return true
	for ruin in RUINS:
		if point.distance_to(ruin) < clearance:
			return true
	for seed in SEEDS:
		if point.distance_to(seed) < 52.0:
			return true
	for i in range(PATH_POINTS.size() - 1):
		if _distance_to_segment(point, PATH_POINTS[i], PATH_POINTS[i + 1]) < clearance * 0.55:
			return true
	return false

func _distance_to_segment(point: Vector2, start: Vector2, finish: Vector2) -> float:
	var segment := finish - start
	var t := clampf((point - start).dot(segment) / maxf(1.0, segment.length_squared()), 0.0, 1.0)
	return point.distance_to(start + segment * t)

func _add_prop(texture: Texture2D, point: Vector2, scale_factor: float, solid: bool = false) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = texture
	sprite.position = point
	sprite.scale = Vector2.ONE * scale_factor
	sprite.z_index = 1
	add_child(sprite)
	if solid:
		_add_solid("FoliageBlocker", point + Vector2(0, 5), Vector2(20.0 * scale_factor, 11.0 * scale_factor))

func _make_structures_and_collisions() -> void:
	_add_solid("Cabin", CABIN + Vector2(0, 4), Vector2(104, 66))
	_add_solid("OldBridgeFooting", Vector2(860, 720), Vector2(112, 20))
	_add_solid("PondBank", POND_CENTER, Vector2(150, 92))
	for point in RUINS:
		_add_solid("MossyRuin", point + Vector2(0, 12), Vector2(56, 44))

func _make_world_bounds() -> void:
	var wall_thickness := 36.0
	var horizontal_span := WORLD_SIZE.x + wall_thickness * 2.0
	var vertical_span := WORLD_SIZE.y + wall_thickness * 2.0
	_add_solid("WorldBoundLeft", Vector2(0, WORLD_SIZE.y * 0.5), Vector2(wall_thickness, vertical_span))
	_add_solid("WorldBoundRight", Vector2(WORLD_SIZE.x, WORLD_SIZE.y * 0.5), Vector2(wall_thickness, vertical_span))
	_add_solid("WorldBoundTop", Vector2(WORLD_SIZE.x * 0.5, 0), Vector2(horizontal_span, wall_thickness))
	_add_solid("WorldBoundBottom", Vector2(WORLD_SIZE.x * 0.5, WORLD_SIZE.y), Vector2(horizontal_span, wall_thickness))

func _add_solid(body_name: String, position: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.name = body_name
	body.position = position
	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	shape_node.shape = shape
	body.add_child(shape_node)
	add_child(body)

func _make_petals() -> void:
	for i in range(44):
		petals.append({"pos": Vector2(rng.randf_range(0, WORLD_SIZE.x), rng.randf_range(0, WORLD_SIZE.y)), "speed": rng.randf_range(14.0, 38.0), "drift": rng.randf_range(-16.0, 16.0), "size": rng.randi_range(3, 5), "phase": rng.randf_range(0.0, TAU)})

func _make_player() -> void:
	player = CharacterBody2D.new()
	player.name = "Mallow"
	player.set_script(PLAYER_SCRIPT)
	player.position = Vector2(130, 150)
	add_child(player)

func _make_camera() -> void:
	var camera := Camera2D.new()
	camera.zoom = Vector2(1.08, 1.08)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 4.0
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(WORLD_SIZE.x)
	camera.limit_bottom = int(WORLD_SIZE.y)
	player.add_child(camera)
	camera.make_current()

func _make_enemies() -> void:
	for enemy in enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	enemies.clear()
	_add_enemy("thornling", Vector2(530, 390))
	_add_enemy("thornling", Vector2(690, 595))
	_add_enemy("puffcap", Vector2(1060, 520))
	_add_enemy("thornling", Vector2(1240, 735))
	_add_enemy("puffcap", Vector2(1450, 450))
	_add_enemy("thornling", Vector2(1510, 710))

func _add_enemy(species: String, point: Vector2) -> void:
	var enemy := Node2D.new()
	enemy.name = "Thornling" if species == "thornling" else "Puffcap"
	enemy.set_script(ENEMY_SCRIPT)
	enemy.position = point
	enemy.call("configure", species)
	add_child(enemy)
	enemies.append(enemy)

func _make_world_lighting() -> void:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, 1.0])
	gradient.colors = PackedColorArray([Color(1.0, 0.85, 0.53, 0.75), Color(0.86, 0.97, 0.78, 0.0)])
	light_texture = GradientTexture2D.new()
	light_texture.width = 128
	light_texture.height = 128
	light_texture.fill = GradientTexture2D.FILL_RADIAL
	light_texture.fill_from = Vector2(0.5, 0.5)
	light_texture.fill_to = Vector2(0.5, 0.05)
	light_texture.gradient = gradient
	_add_light(SHRINE, 0.9, 2.9, Color("ffe9a8"))
	_add_light(CABIN + Vector2(0, 38), 0.42, 1.5, Color("ffd8a0"))
	for seed in SEEDS:
		_add_light(seed, 0.45, 1.1, Color("efffae"))
	var atmosphere_layer := CanvasLayer.new()
	atmosphere_layer.layer = 3
	add_child(atmosphere_layer)
	var vignette := ColorRect.new()
	vignette.name = "MeadowVignette"
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var material := ShaderMaterial.new()
	material.shader = VIGNETTE_SHADER
	vignette.material = material
	atmosphere_layer.add_child(vignette)

func _add_light(point: Vector2, energy: float, scale_factor: float, tint: Color) -> void:
	var light := PointLight2D.new()
	light.position = point
	light.texture = light_texture
	light.color = tint
	light.energy = energy
	light.texture_scale = scale_factor
	light.shadow_enabled = false
	add_child(light)

func _make_hud() -> void:
	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 5
	add_child(hud_layer)
	hud = Control.new()
	hud.set_script(HUD_SCRIPT)
	hud_layer.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.call("setup")
	hud.start_requested.connect(_on_start_requested)
	hud.retry_requested.connect(_on_retry_requested)
	get_viewport().size_changed.connect(_on_viewport_resized)
	hud.call("show_title_menu")

func _on_start_requested() -> void:
	game_started = true
	hud.call("hide_title_menu")
	hud.call("show_message", "Find Moontea in the field kit. Clear a path to the shrine!")

func _on_retry_requested() -> void:
	_reset_journey()
	game_started = true
	hud.call("hide_title_menu")
	hud.call("show_message", "The meadow welcomes you back. Try another path.")

func _reset_journey() -> void:
	seed_taken = [false, false, false]
	seed_count = 0
	cache_opened = false
	won = false
	player.position = Vector2(130, 150)
	player.velocity = Vector2.ZERO
	player.weapon_index = 0
	player.attack_combo = -1
	player.combo_timer = 0.0
	player.attack_left = 0.0
	player.attack_cooldown = 0.0
	player.dash_left = 0.0
	player.cooldown_left = 0.0
	player.invulnerable_left = 0.0
	player.mothlight_cooldown = 0.0
	player.guard_cooldown = 0.0
	player.guard_time_left = 0.0
	player.guard_active = false
	player.moontea_charges = 3
	player.petalcoins = 0
	player.charm_equipped = false
	player.cloak_equipped = true
	player.max_health = player.MAX_HEALTH_BASE
	player.health = player.max_health
	_make_enemies()

func _process(delta: float) -> void:
	if not game_started:
		return
	elapsed += delta
	water_timer += delta
	if water_timer >= 0.22:
		water_timer = 0.0
		water_frame = (water_frame + 1) % 4
		for cell in water_cells:
			ground_layer.set_cell(cell, 0, Vector2i(5 + water_frame, 0))
	_update_petals(delta)
	_update_effects(delta)
	_update_enemies(delta)
	_handle_player_actions()
	_handle_collectibles()
	_check_player_state()
	if is_instance_valid(hud):
		hud.call("set_seed_count", seed_count, SEEDS.size())
		hud.call("set_status", player.call("get_status"))
	queue_redraw()

func _update_petals(delta: float) -> void:
	for i in range(petals.size()):
		var petal: Dictionary = petals[i]
		var point: Vector2 = petal["pos"]
		point.y += float(petal["speed"]) * delta
		point.x += (float(petal["drift"]) + sin(elapsed * 1.2 + float(petal["phase"])) * 10.0) * delta
		if point.y > WORLD_SIZE.y + 10.0:
			point.y = -8.0
			point.x = rng.randf_range(0, WORLD_SIZE.x)
		petal["pos"] = point
		petals[i] = petal

func _update_effects(delta: float) -> void:
	for i in range(effect_bursts.size() - 1, -1, -1):
		var effect: Dictionary = effect_bursts[i]
		effect["time"] = float(effect["time"]) - delta
		if float(effect["time"]) <= 0.0:
			effect_bursts.remove_at(i)
		else:
			effect_bursts[i] = effect

func _update_enemies(delta: float) -> void:
	for i in range(enemies.size() - 1, -1, -1):
		var enemy := enemies[i]
		if not is_instance_valid(enemy):
			enemies.remove_at(i)
			continue
		var attacked: bool = enemy.call("tick", delta, player.global_position)
		if attacked:
			var old_health: int = player.health
			var blocked: bool = player.guard_active
			player.call("take_damage")
			if old_health > player.health:
				hud.call("show_message", "Thornling hit! Find a clear opening and dash away.")
			elif blocked:
				hud.call("show_message", "Petalguard caught the strike!")

func _handle_player_actions() -> void:
	if Input.is_action_just_pressed("attack"):
		_try_player_attack()
	if Input.is_action_just_pressed("skill"):
		_cast_mothlight()
	if Input.is_action_just_pressed("guard"):
		if player.call("activate_petalguard"):
			hud.call("show_message", "Petalguard is ready to soften one hit.")
	if Input.is_action_just_pressed("heal"):
		if player.call("drink_moontea"):
			hud.call("show_message", "A sip of Moontea restores one heart.")
	if Input.is_action_just_pressed("switch_weapon"):
		player.call("cycle_weapon")
		var weapon_name: String = player.call("get_weapon_name")
		hud.call("show_message", "Equipped %s." % weapon_name.capitalize())
	if Input.is_action_just_pressed("interact"):
		_open_cache()
	if player.global_position.distance_to(CACHE) < 68.0 and not cache_opened:
		hud.call("set_interact_visible", true, "OPEN CACHE")
	else:
		hud.call("set_interact_visible", false)

func _open_cache() -> bool:
	if cache_opened or player.global_position.distance_to(CACHE) >= 60.0:
		return false
	if not player.call("equip_moonheart_charm"):
		return false
	cache_opened = true
	hud.call("show_message", "Moonheart Charm equipped: +1 maximum heart.")
	return true

func _try_player_attack() -> void:
	if not player.call("try_attack"):
		return
	var staff: bool = player.weapon_index == 1
	var finisher: bool = not staff and player.attack_combo == 2
	var max_range := 255.0 if staff else (92.0 if finisher else 76.0)
	var min_dot := 0.18 if staff else -0.1
	var target: Node2D
	var nearest := max_range
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var offset: Vector2 = enemy.global_position - player.global_position
		var distance := offset.length()
		if distance <= 0.1 or distance > max_range:
			continue
		if player.facing.dot(offset.normalized()) < min_dot:
			continue
		if distance < nearest:
			nearest = distance
			target = enemy
	if target != null:
		var amount := 2 if finisher else 1
		_damage_enemy(target, amount)
		if staff:
			effect_bursts.append({"from": player.global_position + Vector2(0, -10), "to": target.global_position, "time": 0.20, "duration": 0.20, "kind": "bolt"})
		else:
			effect_bursts.append({"from": target.global_position, "to": target.global_position, "time": 0.24, "duration": 0.24, "kind": "slash"})

func _cast_mothlight() -> void:
	if not player.call("activate_mothlight"):
		return
	var target: Node2D
	var nearest := 370.0
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		var distance: float = player.global_position.distance_to(enemy.global_position)
		if distance < nearest:
			nearest = distance
			target = enemy
	if target == null:
		hud.call("show_message", "Mothlight is ready; move closer to a thornling.")
		return
	effect_bursts.append({"from": player.global_position + Vector2(0, -12), "to": target.global_position, "time": 0.45, "duration": 0.45, "kind": "mothlight"})
	_damage_enemy(target, 2)
	hud.call("show_message", "Mothlight finds its mark.")

func _damage_enemy(enemy: Node2D, amount: int) -> void:
	if enemy.call("take_damage", amount):
		var dead_position := enemy.global_position
		enemies.erase(enemy)
		enemy.queue_free()
		player.call("add_petalcoins", 3)
		_spawn_burst(dead_position, 8)
		hud.call("show_message", "A tangle dissolves.  +3 Petalcoins")

func _spawn_burst(point: Vector2, count: int) -> void:
	for i in range(count):
		var angle := TAU * float(i) / float(count) + rng.randf_range(-0.12, 0.12)
		var velocity := Vector2.from_angle(angle) * rng.randf_range(28.0, 82.0)
		effect_bursts.append({"from": point, "to": point + velocity, "time": 0.42, "duration": 0.42, "kind": "petal"})

func _handle_collectibles() -> void:
	for i in range(SEEDS.size()):
		if not seed_taken[i] and player.global_position.distance_to(SEEDS[i]) < 28.0:
			seed_taken[i] = true
			seed_count += 1
			hud.call("show_message", "Moonseed gathered.  %d / %d" % [seed_count, SEEDS.size()])
			_spawn_burst(SEEDS[i], 6)
	if seed_count == SEEDS.size() and not won and player.global_position.distance_to(SHRINE) < 52.0:
		won = true
		hud.call("show_victory", "Three Moonseeds wake the old shrine. The path can bloom again.")

func _check_player_state() -> void:
	if player.health <= 0 and not won:
		game_started = false
		hud.call("show_game_over", "The thornlings overwhelm you. Keep the charm close and save Moontea for a quiet moment.")

func _draw() -> void:
	_draw_hut()
	_draw_bench_and_lanterns()
	_draw_ruins()
	_draw_cache()
	_draw_shrine()
	for i in range(SEEDS.size()):
		if not seed_taken[i]:
			_draw_seed(SEEDS[i], elapsed + float(i))
	for petal in petals:
		var point: Vector2 = petal["pos"]
		var size := int(petal["size"])
		var sway := sin(elapsed * 1.8 + float(petal["phase"])) * 1.5
		draw_rect(Rect2(point.x + sway, point.y, size, size * 2), Color("ed9dac"))
		draw_rect(Rect2(point.x + size + sway, point.y + 1, size, size), Color("f5c0c4"))
	_draw_effects()

func _draw_hut() -> void:
	var base := CABIN
	draw_rect(Rect2(base + Vector2(-52, -28), Vector2(104, 76)), Color(0.19, 0.32, 0.30, 0.28))
	draw_rect(Rect2(base + Vector2(-48, -46), Vector2(96, 70)), Color("dbcfae"))
	draw_rect(Rect2(base + Vector2(-54, -51), Vector2(108, 30)), Color("69516c"))
	draw_colored_polygon(PackedVector2Array([base + Vector2(-62, -48), base + Vector2(0, -88), base + Vector2(62, -48)]), Color("6c536e"))
	draw_line(base + Vector2(-48, -49), base + Vector2(0, -83), Color("c18a9a"), 4.0, true)
	draw_line(base + Vector2(0, -83), base + Vector2(48, -49), Color("c18a9a"), 4.0, true)
	draw_rect(Rect2(base + Vector2(-34, -28), Vector2(18, 19)), Color("91c6bb"))
	draw_rect(Rect2(base + Vector2(17, -28), Vector2(18, 19)), Color("91c6bb"))
	draw_rect(Rect2(base + Vector2(-8, -19), Vector2(18, 43)), Color("574561"))
	draw_circle(base + Vector2(5, 1), 2.2, Color("f3d597"))
	draw_rect(Rect2(base + Vector2(-22, 31), Vector2(44, 7)), Color("b89d7e"))
	draw_rect(Rect2(base + Vector2(-16, 39), Vector2(32, 6)), Color("8b7b67"))
	draw_rect(Rect2(base + Vector2(-5, -75), Vector2(10, 7)), Color("edd49a"))

func _draw_bench_and_lanterns() -> void:
	var bench := Vector2(330, 290)
	draw_rect(Rect2(bench + Vector2(-28, -9), Vector2(56, 12)), Color("8b695f"))
	draw_rect(Rect2(bench + Vector2(-23, -16), Vector2(46, 8)), Color("c39979"))
	draw_rect(Rect2(bench + Vector2(-20, 2), Vector2(5, 16)), Color("634d56"))
	draw_rect(Rect2(bench + Vector2(15, 2), Vector2(5, 16)), Color("634d56"))
	for point in [Vector2(200, 325), Vector2(390, 330), Vector2(1570, 590), Vector2(1710, 595)]:
		draw_rect(Rect2(point + Vector2(-3, -20), Vector2(6, 34)), Color("594a5e"))
		draw_rect(Rect2(point + Vector2(-9, -31), Vector2(18, 16)), Color("6d586f"))
		draw_circle(point + Vector2(0, -24), 5.0, Color("ffe5a1", 0.92))
		draw_line(point + Vector2(-12, 14), point + Vector2(12, 14), Color("6f6d60"), 4.0, true)

func _draw_ruins() -> void:
	for point in RUINS:
		var r := Rect2(point - Vector2(30, 20), Vector2(60, 58))
		draw_rect(Rect2(r.position + Vector2(5, 7), r.size), Color(0.25, 0.46, 0.43, 0.35))
		draw_rect(r, Color("e8eadb"))
		draw_rect(Rect2(r.position + Vector2(7, 6), Vector2(46, 9)), Color("f6f3df"))
		draw_rect(Rect2(r.position + Vector2(8, 21), Vector2(44, 7)), Color("c6d5c4"))
		draw_rect(Rect2(r.position + Vector2(7, 41), Vector2(47, 9)), Color("d1ddcf"))
		draw_rect(Rect2(r.position + Vector2(18, 6), Vector2(4, 44)), Color("a6c5b0"))
		for vine in range(4):
			var vx := r.position.x + 11 + vine * 12
			draw_rect(Rect2(vx, r.position.y - 3 + (vine % 2) * 10, 4, 18), Color("39a99b"))
			draw_rect(Rect2(vx - 3, r.position.y + 14 + (vine % 2) * 6, 4, 16), Color("4fbea4"))
		for i in range(4):
			var rock: Vector2 = point + Vector2(-58 + i * 36, 47 + (i % 2) * 9)
			draw_rect(Rect2(rock, Vector2(15, 9)), Color("758f88"))
			draw_rect(Rect2(rock + Vector2(3, -3), Vector2(9, 4)), Color("9bb0a2"))

func _draw_cache() -> void:
	var glow := 0.12 + (sin(elapsed * 2.0) + 1.0) * 0.06
	draw_circle(CACHE + Vector2(0, 5), 24.0, Color(0.96, 0.86, 0.55, glow))
	draw_rect(Rect2(CACHE + Vector2(-17, -5), Vector2(34, 25)), Color("805f67"))
	draw_rect(Rect2(CACHE + Vector2(-19, -14), Vector2(38, 12)), Color("c29473"))
	draw_rect(Rect2(CACHE + Vector2(-3, -13), Vector2(6, 24)), Color("f0d596"))
	if cache_opened:
		draw_rect(Rect2(CACHE + Vector2(-2, -17), Vector2(4, 5)), Color("fff5c2"))

func _draw_seed(point: Vector2, phase: float) -> void:
	var bob := sin(phase * 2.2) * 3.0
	var shimmer := 0.20 + (sin(phase * 3.0) + 1.0) * 0.08
	draw_circle(point + Vector2(0, 4), 15, Color(0.76, 1.0, 0.82, shimmer))
	draw_rect(Rect2(point.x - 5, point.y - 9 + bob, 10, 14), Color("f9e99a"))
	draw_rect(Rect2(point.x - 2, point.y - 13 + bob, 5, 5), Color("fff6c5"))
	draw_rect(Rect2(point.x + 5, point.y - 4 + bob, 4, 6), Color("d2d68d"))
	draw_line(point + Vector2(-11, bob), point + Vector2(11, bob), Color(1, 1, 0.8, 0.55), 1.0, true)

func _draw_shrine() -> void:
	var glow := 0.18 + (sin(elapsed * 2.0) + 1.0) * 0.08
	draw_circle(SHRINE, 55, Color(0.95, 0.98, 0.78, glow))
	draw_circle(SHRINE, 34, Color(0.86, 1.0, 0.87, glow * 0.65))
	draw_rect(Rect2(SHRINE + Vector2(-30, 4), Vector2(10, 42)), Color("d7e6d4"))
	draw_rect(Rect2(SHRINE + Vector2(20, 4), Vector2(10, 42)), Color("d7e6d4"))
	draw_rect(Rect2(SHRINE + Vector2(-30, -5), Vector2(60, 11)), Color("f3f1db"))
	draw_rect(Rect2(SHRINE + Vector2(-19, -18), Vector2(38, 13)), Color("c9ded0"))
	draw_rect(Rect2(SHRINE + Vector2(-7, 20), Vector2(14, 25)), Color("8ed1b5"))
	for petal in range(4):
		var angle := elapsed * 0.35 + TAU * float(petal) / 4.0
		var orbit := Vector2.from_angle(angle) * 29.0
		draw_circle(SHRINE + orbit, 3.0, Color("f1b1c1", 0.82))

func _draw_effects() -> void:
	for effect in effect_bursts:
		var from: Vector2 = effect["from"]
		var to: Vector2 = effect["to"]
		var time_left := float(effect["time"])
		var duration := maxf(0.01, float(effect["duration"]))
		var age := 1.0 - time_left / duration
		var kind: String = effect["kind"]
		if kind == "slash":
			draw_arc(to, 25.0 + age * 8.0, -2.5, -0.4, 20, Color(1.0, 0.85, 0.62, time_left / duration), 4.0, true)
		elif kind == "bolt" or kind == "mothlight":
			var point := from.lerp(to, age)
			var tint := Color("a6f1dc") if kind == "bolt" else Color("fff1ae")
			draw_line(from, point, Color(tint.r, tint.g, tint.b, 0.85), 3.0, true)
			draw_circle(point, 7.0 if kind == "mothlight" else 5.0, Color(tint.r, tint.g, tint.b, 0.92))
			draw_circle(point, 13.0, Color(tint.r, tint.g, tint.b, 0.28))
		elif kind == "petal":
			var point := from.lerp(to, age)
			draw_rect(Rect2(point, Vector2(4, 7)), Color(0.95, 0.58, 0.68, time_left / duration))

func _on_viewport_resized() -> void:
	if is_instance_valid(hud):
		hud.call("set_anchors_and_offsets_preset", Control.PRESET_FULL_RECT)
