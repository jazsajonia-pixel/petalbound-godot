extends Node2D

var species := "thornling"
var health := 3
var max_health := 3
var attack_cooldown := 0.0
var hit_flash := 0.0
var anim_time := 0.0
var move_speed := 34.0

func configure(enemy_species: String) -> void:
	species = enemy_species
	if species == "puffcap":
		health = 2
		max_health = 2
		move_speed = 18.0
	else:
		health = 3
		max_health = 3
		move_speed = 38.0

func tick(delta: float, target_position: Vector2) -> bool:
	anim_time += delta
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	hit_flash = maxf(0.0, hit_flash - delta)
	var offset := target_position - global_position
	var distance := offset.length()
	if distance < 250.0 and distance > 34.0:
		var speed_scale := 0.45 if species == "puffcap" else 1.0
		global_position += offset.normalized() * move_speed * speed_scale * delta
	var attacked := distance < 34.0 and attack_cooldown <= 0.0
	if attacked:
		attack_cooldown = 1.25 if species == "thornling" else 1.65
	queue_redraw()
	return attacked

func take_damage(amount: int) -> bool:
	health = maxi(0, health - amount)
	hit_flash = 0.16
	queue_redraw()
	return health <= 0

func _draw() -> void:
	var bob := sin(anim_time * 5.0) * 1.4
	var body := Color("fff0d5") if hit_flash > 0.0 else Color("6b8761")
	draw_ellipse_shadow()
	if species == "puffcap":
		_draw_puffcap(body, bob)
	else:
		_draw_thornling(body, bob)
	if health < max_health:
		draw_rect(Rect2(Vector2(-15, -31), Vector2(30, 4)), Color("3c394c"))
		draw_rect(Rect2(Vector2(-14, -30), Vector2(28.0 * float(health) / float(max_health), 2)), Color("e98591"))

func draw_ellipse_shadow() -> void:
	draw_circle(Vector2(0, 6), 13.0, Color(0.15, 0.22, 0.19, 0.27))

func _draw_thornling(body: Color, bob: float) -> void:
	var points := PackedVector2Array([
		Vector2(-13, 1 + bob), Vector2(-15, -8 + bob), Vector2(-7, -6 + bob),
		Vector2(-3, -16 + bob), Vector2(2, -8 + bob), Vector2(11, -12 + bob),
		Vector2(9, -4 + bob), Vector2(14, 1 + bob), Vector2(8, 10 + bob),
		Vector2(-8, 10 + bob)
	])
	draw_colored_polygon(points, Color("b57975") if hit_flash > 0.0 else Color("496e56"))
	draw_rect(Rect2(Vector2(-7, -6 + bob), Vector2(14, 13)), body)
	draw_rect(Rect2(Vector2(-5, -2 + bob), Vector2(3, 3)), Color("493b4d"))
	draw_rect(Rect2(Vector2(3, -2 + bob), Vector2(3, 3)), Color("493b4d"))
	draw_rect(Rect2(Vector2(-3, 5 + bob), Vector2(6, 2)), Color("d9a87c"))
	draw_colored_polygon(PackedVector2Array([Vector2(-11, -5 + bob), Vector2(-18, -11 + bob), Vector2(-8, -9 + bob)]), Color("90b782"))
	draw_colored_polygon(PackedVector2Array([Vector2(10, -5 + bob), Vector2(18, -10 + bob), Vector2(8, -9 + bob)]), Color("90b782"))

func _draw_puffcap(body: Color, bob: float) -> void:
	draw_rect(Rect2(Vector2(-4, -7 + bob), Vector2(8, 16)), Color("d9c49a"))
	draw_circle(Vector2(0, -9 + bob), 13, Color("8e687f") if hit_flash <= 0.0 else Color("fff0d5"))
	draw_rect(Rect2(Vector2(-12, -10 + bob), Vector2(24, 5)), Color("bb8391") if hit_flash <= 0.0 else Color("fff0d5"))
	draw_circle(Vector2(-4, -10 + bob), 2.0, Color("f2d69a"))
	draw_circle(Vector2(5, -6 + bob), 1.5, Color("f2d69a"))
	draw_rect(Rect2(Vector2(-5, 1 + bob), Vector2(3, 2)), Color("493b4d"))
	draw_rect(Rect2(Vector2(2, 1 + bob), Vector2(3, 2)), Color("493b4d"))
