extends Node2D

const PLAYER_SCRIPT = preload("res://scripts/player.gd")
const HUD_SCRIPT = preload("res://scripts/hud.gd")
const WORLD_SIZE := Vector2(1800, 1100)
const RUINS := [Vector2(420, 300), Vector2(760, 190), Vector2(1120, 465), Vector2(1450, 275), Vector2(560, 790), Vector2(1000, 900), Vector2(1450, 820)]
const SEEDS := [Vector2(345, 520), Vector2(900, 635), Vector2(1315, 610)]
const SHRINE := Vector2(1660, 545)

var player: CharacterBody2D
var hud: Control
var seed_taken: Array[bool] = [false, false, false]
var seed_count := 0
var elapsed := 0.0
var petals: Array[Dictionary] = []
var won := false
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng_setup()
	_make_petals()
	player = CharacterBody2D.new()
	player.name = "Traveler"
	player.set_script(PLAYER_SCRIPT)
	player.position = Vector2(130, 150)
	add_child(player)
	_make_ruin_collisions()
	_make_world_bounds()
	var camera := Camera2D.new()
	camera.zoom = Vector2(1.15, 1.15)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 5.0
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(WORLD_SIZE.x)
	camera.limit_bottom = int(WORLD_SIZE.y)
	player.add_child(camera)
	camera.make_current()
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	hud = Control.new()
	hud.set_script(HUD_SCRIPT)
	layer.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.call("setup")
	get_viewport().size_changed.connect(_on_viewport_resized)
	queue_redraw()

func _rng_setup() -> void:
	rng.seed = 40821

func _make_petals() -> void:
	for i in range(36):
		petals.append({"pos": Vector2(rng.randf_range(0, WORLD_SIZE.x), rng.randf_range(0, WORLD_SIZE.y)), "speed": rng.randf_range(18.0, 46.0), "drift": rng.randf_range(-12.0, 12.0), "size": rng.randi_range(3, 5), "phase": rng.randf_range(0.0, TAU)})

func _make_ruin_collisions() -> void:
	for point in RUINS:
		var body := StaticBody2D.new()
		body.position = point + Vector2(0, 12)
		var shape_node := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2(56, 44)
		shape_node.shape = shape
		body.add_child(shape_node)
		add_child(body)

func _make_world_bounds() -> void:
	var wall_thickness := 36.0
	var horizontal_span := WORLD_SIZE.x + wall_thickness * 2.0
	var vertical_span := WORLD_SIZE.y + wall_thickness * 2.0
	_add_world_bound("WorldBoundLeft", Vector2(0, WORLD_SIZE.y * 0.5), Vector2(wall_thickness, vertical_span))
	_add_world_bound("WorldBoundRight", Vector2(WORLD_SIZE.x, WORLD_SIZE.y * 0.5), Vector2(wall_thickness, vertical_span))
	_add_world_bound("WorldBoundTop", Vector2(WORLD_SIZE.x * 0.5, 0), Vector2(horizontal_span, wall_thickness))
	_add_world_bound("WorldBoundBottom", Vector2(WORLD_SIZE.x * 0.5, WORLD_SIZE.y), Vector2(horizontal_span, wall_thickness))

func _add_world_bound(bound_name: String, position: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.name = bound_name
	body.position = position
	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	shape_node.shape = shape
	body.add_child(shape_node)
	add_child(body)

func _process(delta: float) -> void:
	elapsed += delta
	for petal in petals:
		var p: Vector2 = petal["pos"]
		p.y += float(petal["speed"]) * delta
		p.x += (float(petal["drift"]) + sin(elapsed * 1.2 + float(petal["phase"])) * 10.0) * delta
		if p.y > WORLD_SIZE.y + 10:
			p.y = -8
			p.x = rng.randf_range(0, WORLD_SIZE.x)
		petal["pos"] = p
	if is_instance_valid(player):
		for i in range(SEEDS.size()):
			if not seed_taken[i] and player.global_position.distance_to(SEEDS[i]) < 28:
				seed_taken[i] = true
				seed_count += 1
				if seed_count == 3:
					hud.call("show_message", "The shrine is awake. Find the glowing arch!")
		if not won and seed_count == 3 and player.global_position.distance_to(SHRINE) < 48:
			won = true
			hud.call("show_message", "A gentle light welcomes you home.  •  You made it!")
	if is_instance_valid(hud):
		hud.call("set_seed_count", seed_count)
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color("83c8b1"))
	_draw_ground_details()
	_draw_paths()
	for point in RUINS:
		_draw_ruin(point)
	_draw_shrine()
	for i in range(SEEDS.size()):
		if not seed_taken[i]:
			_draw_seed(SEEDS[i], elapsed + float(i))
	for petal in petals:
		var p: Vector2 = petal["pos"]
		var size := int(petal["size"])
		draw_rect(Rect2(p.x, p.y, size, size * 2), Color("ed9dac"))
		draw_rect(Rect2(p.x + size, p.y + 1, size, size), Color("f5c0c4"))

func _draw_ground_details() -> void:
	var local_rng := RandomNumberGenerator.new()
	local_rng.seed = 22107
	for i in range(900):
		var x := local_rng.randi_range(8, int(WORLD_SIZE.x) - 8)
		var y := local_rng.randi_range(8, int(WORLD_SIZE.y) - 8)
		var tint := local_rng.randi_range(0, 3)
		var color := Color("a8d8bd") if tint < 2 else Color("70b69f")
		draw_rect(Rect2(x, y, local_rng.randi_range(2, 5), 2), color)
	for i in range(26):
		var x := local_rng.randi_range(24, int(WORLD_SIZE.x) - 24)
		var y := local_rng.randi_range(24, int(WORLD_SIZE.y) - 24)
		draw_circle(Vector2(x, y), local_rng.randi_range(11, 23), Color(0.86, 0.95, 0.85, 0.45))
	for i in range(80):
		var x := local_rng.randi_range(20, int(WORLD_SIZE.x) - 20)
		var y := local_rng.randi_range(30, int(WORLD_SIZE.y) - 20)
		draw_rect(Rect2(x, y, 3, 7), Color("4c967f"))
		draw_rect(Rect2(x - 3, y + 2, 3, 3), Color("5da48a"))
		draw_rect(Rect2(x + 3, y + 1, 3, 3), Color("5da48a"))

func _draw_paths() -> void:
	var path_points := [Vector2(130, 150), Vector2(310, 430), Vector2(630, 500), Vector2(880, 635), Vector2(1190, 570), Vector2(1470, 640), SHRINE]
	for i in range(path_points.size() - 1):
		var a: Vector2 = path_points[i]
		var b: Vector2 = path_points[i + 1]
		draw_line(a, b, Color("b9d8ae"), 46.0, true)
		draw_line(a, b, Color(0.75, 0.86, 0.68, 0.55), 30.0, true)

func _draw_ruin(point: Vector2) -> void:
	var r := Rect2(point - Vector2(30, 20), Vector2(60, 58))
	draw_rect(Rect2(r.position + Vector2(5, 7), r.size), Color(0.25, 0.46, 0.43, 0.35))
	draw_rect(r, Color("e8eadb"))
	draw_rect(Rect2(r.position + Vector2(7, 6), Vector2(46, 9)), Color("f6f3df"))
	draw_rect(Rect2(r.position + Vector2(8, 21), Vector2(44, 7)), Color("c6d5c4"))
	draw_rect(Rect2(r.position + Vector2(7, 41), Vector2(47, 9)), Color("d1ddcf"))
	draw_rect(Rect2(r.position + Vector2(18, 6), Vector2(4, 44)), Color("a6c5b0"))
	for v in range(4):
		var vx := r.position.x + 11 + v * 12
		draw_rect(Rect2(vx, r.position.y - 3 + (v % 2) * 10, 4, 18), Color("39a99b"))
		draw_rect(Rect2(vx - 3, r.position.y + 14 + (v % 2) * 6, 4, 16), Color("4fbea4"))
	for i in range(4):
		var rock := point + Vector2(-58 + i * 36, 47 + (i % 2) * 9)
		draw_rect(Rect2(rock, Vector2(15, 9)), Color("758f88"))
		draw_rect(Rect2(rock + Vector2(3, -3), Vector2(9, 4)), Color("9bb0a2"))

func _draw_seed(point: Vector2, phase: float) -> void:
	var bob := sin(phase * 2.2) * 3.0
	draw_circle(point + Vector2(0, 4), 13, Color(0.76, 1.0, 0.82, 0.20))
	draw_rect(Rect2(point.x - 5, point.y - 9 + bob, 10, 14), Color("f9e99a"))
	draw_rect(Rect2(point.x - 2, point.y - 13 + bob, 5, 5), Color("fff6c5"))
	draw_rect(Rect2(point.x + 5, point.y - 4 + bob, 4, 6), Color("d2d68d"))

func _draw_shrine() -> void:
	var glow := 0.18 + (sin(elapsed * 2.0) + 1.0) * 0.08
	draw_circle(SHRINE, 46, Color(0.95, 0.98, 0.78, glow))
	draw_rect(Rect2(SHRINE + Vector2(-30, 4), Vector2(10, 42)), Color("d7e6d4"))
	draw_rect(Rect2(SHRINE + Vector2(20, 4), Vector2(10, 42)), Color("d7e6d4"))
	draw_rect(Rect2(SHRINE + Vector2(-30, -5), Vector2(60, 11)), Color("f3f1db"))
	draw_rect(Rect2(SHRINE + Vector2(-19, -18), Vector2(38, 13)), Color("c9ded0"))
	draw_rect(Rect2(SHRINE + Vector2(-7, 20), Vector2(14, 25)), Color("8ed1b5"))

func _on_viewport_resized() -> void:
	if is_instance_valid(hud):
		hud.call("set_anchors_and_offsets_preset", Control.PRESET_FULL_RECT)
