extends CharacterBody2D

signal hit_taken

enum Facing { DOWN, LEFT, RIGHT, UP, DOWN_LEFT, DOWN_RIGHT, UP_LEFT, UP_RIGHT }

const WALK_SPEED := 170.0
const DASH_SPEED := 560.0
const DASH_DURATION := 0.16
const DASH_COOLDOWN := 0.55
const MAX_HEALTH_BASE := 5
const CLOAK_SPEED_MULTIPLIER := 1.08
const WEAPON_NAMES := ["THORNBLADE", "BLOOMSTAFF"]

var facing := Vector2.RIGHT
var facing_direction := Facing.RIGHT
var dash_direction := Vector2.RIGHT
var dash_left := 0.0
var cooldown_left := 0.0
var anim_time := 0.0
var trail_points: Array[Vector2] = []
var health := MAX_HEALTH_BASE
var max_health := MAX_HEALTH_BASE
var invulnerable_left := 0.0
var attack_left := 0.0
var attack_cooldown := 0.0
var attack_combo := -1
var combo_timer := 0.0
var weapon_index := 0
var mothlight_cooldown := 0.0
var guard_cooldown := 0.0
var guard_time_left := 0.0
var guard_active := false
var moontea_charges := 3
var petalcoins := 0
var charm_equipped := false
var cloak_equipped := true

func _ready() -> void:
	_register_inputs()
	var shape_node := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(18, 16)
	shape_node.shape = shape
	add_child(shape_node)
	z_index = 2

func _register_inputs() -> void:
	_add_keys("move_up", [KEY_W, KEY_UP])
	_add_keys("move_down", [KEY_S, KEY_DOWN])
	_add_keys("move_left", [KEY_A, KEY_LEFT])
	_add_keys("move_right", [KEY_D, KEY_RIGHT])
	_add_keys("dash", [KEY_SPACE, KEY_SHIFT])
	_add_keys("attack", [KEY_J, KEY_K, KEY_ENTER])
	_add_keys("skill", [KEY_F])
	_add_keys("guard", [KEY_G])
	_add_keys("heal", [KEY_R])
	_add_keys("switch_weapon", [KEY_Q])
	_add_keys("inventory", [KEY_I])
	_add_keys("interact", [KEY_E])
	_add_keys("pause", [KEY_ESCAPE, KEY_P])

func _add_keys(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		if not InputMap.action_has_event(action, event):
			InputMap.action_add_event(action, event)

func _physics_process(delta: float) -> void:
	anim_time += delta
	cooldown_left = maxf(0.0, cooldown_left - delta)
	dash_left = maxf(0.0, dash_left - delta)
	invulnerable_left = maxf(0.0, invulnerable_left - delta)
	attack_left = maxf(0.0, attack_left - delta)
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	combo_timer = maxf(0.0, combo_timer - delta)
	if combo_timer <= 0.0:
		attack_combo = -1
	mothlight_cooldown = maxf(0.0, mothlight_cooldown - delta)
	guard_cooldown = maxf(0.0, guard_cooldown - delta)
	guard_time_left = maxf(0.0, guard_time_left - delta)
	if guard_time_left <= 0.0:
		guard_active = false
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if direction.length() > 0.1:
		facing = direction.normalized()
		if absf(direction.x) > absf(direction.y) * 2.0:
			facing_direction = Facing.RIGHT if direction.x > 0.0 else Facing.LEFT
		elif absf(direction.y) > absf(direction.x) * 2.0:
			facing_direction = Facing.DOWN if direction.y > 0.0 else Facing.UP
		elif direction.y > 0.0:
			facing_direction = Facing.DOWN_RIGHT if direction.x > 0.0 else Facing.DOWN_LEFT
		else:
			facing_direction = Facing.UP_RIGHT if direction.x > 0.0 else Facing.UP_LEFT
	if Input.is_action_just_pressed("dash") and dash_left <= 0.0 and cooldown_left <= 0.0:
		dash_direction = facing if direction.length() < 0.1 else direction.normalized()
		dash_left = DASH_DURATION
		cooldown_left = DASH_COOLDOWN
		trail_points.clear()
	if dash_left > 0.0:
		velocity = dash_direction * DASH_SPEED
		if Engine.get_physics_frames() % 2 == 0:
			trail_points.append(-dash_direction * 12.0)
			if trail_points.size() > 5:
				trail_points.pop_front()
	else:
		velocity = direction * get_move_speed()
	move_and_slide()
	queue_redraw()

func try_attack() -> bool:
	if attack_cooldown > 0.0 or dash_left > 0.0:
		return false
	if combo_timer <= 0.0:
		attack_combo = -1
	attack_combo = (attack_combo + 1) % 3
	combo_timer = 0.92
	var finisher := weapon_index == 0 and attack_combo == 2
	attack_left = 0.40 if finisher else (0.28 if weapon_index == 0 else 0.38)
	attack_cooldown = 0.48 if finisher else (0.34 if weapon_index == 0 else 0.62)
	return true

func cycle_weapon() -> void:
	weapon_index = (weapon_index + 1) % WEAPON_NAMES.size()
	attack_combo = -1
	combo_timer = 0.0

func get_weapon_name() -> String:
	return WEAPON_NAMES[weapon_index]

func get_move_speed() -> float:
	return WALK_SPEED * CLOAK_SPEED_MULTIPLIER if cloak_equipped else WALK_SPEED

func activate_mothlight() -> bool:
	if mothlight_cooldown > 0.0:
		return false
	mothlight_cooldown = 4.5
	return true

func activate_petalguard() -> bool:
	if guard_cooldown > 0.0 or guard_active:
		return false
	guard_cooldown = 8.0
	guard_time_left = 5.0
	guard_active = true
	return true

func drink_moontea() -> bool:
	if moontea_charges <= 0 or health >= max_health:
		return false
	moontea_charges -= 1
	health = mini(max_health, health + 1)
	return true

func take_damage() -> bool:
	if guard_active:
		guard_active = false
		guard_time_left = 0.0
		invulnerable_left = 0.35
		return false
	if invulnerable_left > 0.0 or dash_left > 0.0:
		return false
	health = maxi(0, health - 1)
	invulnerable_left = 0.95
	hit_taken.emit()
	return true

func equip_moonheart_charm() -> bool:
	if charm_equipped:
		return false
	charm_equipped = true
	max_health = MAX_HEALTH_BASE + 1
	health = mini(max_health, health + 1)
	return true

func add_petalcoins(amount: int) -> void:
	petalcoins += maxi(0, amount)

func get_status() -> Dictionary:
	return {
		"health": health,
		"max_health": max_health,
		"moontea": moontea_charges,
		"petalcoins": petalcoins,
		"weapon": get_weapon_name(),
		"mothlight_cooldown": mothlight_cooldown,
		"guard_cooldown": guard_cooldown,
		"guard_active": guard_active,
		"charm_equipped": charm_equipped,
		"cloak_equipped": cloak_equipped
	}

func _draw() -> void:
	var walking := velocity.length() > 8.0 and dash_left <= 0.0
	var bob := sin(anim_time * 9.0) * 1.4 if walking else sin(anim_time * 3.5) * 0.8
	var step := sin(anim_time * 12.0) * 1.8 if walking else 0.0
	for i in range(trail_points.size()):
		var alpha := float(i + 1) / float(trail_points.size() + 1) * 0.25
		var point: Vector2 = trail_points[i]
		draw_rect(Rect2(point + Vector2(-7, -3), Vector2(14, 9)), Color(0.91, 0.98, 0.90, alpha))
	if dash_left > 0.0:
		var dash_color := Color(0.92, 1.0, 0.89, 0.75)
		for streak in range(3):
			var offset := -dash_direction * float(18 + streak * 8)
			draw_line(offset + Vector2(-5, 0), offset + Vector2(5, 0), dash_color, 2.0, true)
	draw_circle(Vector2(0, 10), 10.0, Color(0.24, 0.43, 0.38, 0.24))
	match facing_direction:
		Facing.UP:
			_draw_back(bob, step)
		Facing.LEFT, Facing.RIGHT:
			_draw_side(bob, step)
		Facing.UP_LEFT, Facing.UP_RIGHT:
			_draw_back(bob, step, -1.0 if facing_direction == Facing.UP_LEFT else 1.0)
		Facing.DOWN_LEFT, Facing.DOWN_RIGHT:
			_draw_front(bob, step, -1.0 if facing_direction == Facing.DOWN_LEFT else 1.0)
		_:
			_draw_front(bob, step)
	if attack_left > 0.0:
		_draw_attack_effect()
	if guard_active:
		var pulse := 0.78 + sin(anim_time * 9.0) * 0.12
		draw_arc(Vector2(0, -7), 24.0, 0.0, TAU, 32, Color(0.93, 0.77, 1.0, pulse), 3.0, true)
		draw_circle(Vector2(0, -20), 3.0, Color(1.0, 0.91, 0.99, pulse))
	if invulnerable_left > 0.0:
		var flash_alpha := 0.55 + sin(anim_time * 32.0) * 0.20
		draw_arc(Vector2(0, -7), 20.0, 0.0, TAU, 28, Color(1.0, 0.83, 0.78, flash_alpha), 2.0, true)

func _draw_attack_effect() -> void:
	var aim := facing.normalized()
	var center := Vector2(0, -8) + aim * 14.0
	var start_angle := aim.angle() - 0.82
	var end_angle := aim.angle() + 0.82
	var finisher := weapon_index == 0 and attack_combo == 2
	var tint := Color("ffc99c") if finisher else (Color("f6eaa6") if weapon_index == 0 else Color("9de6de"))
	var attack_phase := clampf(attack_left / 0.40, 0.0, 1.0)
	var radius := 25.0 + (1.0 - attack_phase) * 10.0 + (9.0 if finisher else 0.0)
	draw_arc(center, radius, start_angle, end_angle, 20, Color(tint.r, tint.g, tint.b, 0.9), 4.5 if finisher else 3.0, true)
	var tip := center + aim * radius
	draw_circle(tip, 3.5, Color(1.0, 0.95, 0.75, 0.88))
	if weapon_index == 1:
		draw_circle(center + aim * 12.0, 7.0, Color(0.60, 0.92, 0.83, 0.58))

func _is_blinking() -> bool:
	var blink_phase := fposmod(anim_time, 4.3)
	return blink_phase < 0.11

func _draw_front(bob: float, step: float, look_bias: float = 0.0) -> void:
	var ear_flick := sin(anim_time * 2.5) * 0.8 if velocity.length() <= 8.0 else -minf(2.0, dash_left * 8.0)
	_draw_feet(step)
	draw_rect(Rect2(Vector2(-9, -3 + bob), Vector2(18, 13)), Color("514467"))
	draw_rect(Rect2(Vector2(-7, -5 + bob), Vector2(14, 11)), Color("68547c"))
	draw_rect(Rect2(Vector2(-7, -12 + bob), Vector2(14, 12)), Color("f2f0df"))
	draw_rect(Rect2(Vector2(-7, -19 + bob + ear_flick), Vector2(4, 9)), Color("f2f0df"))
	draw_rect(Rect2(Vector2(3, -19 + bob - ear_flick), Vector2(4, 9)), Color("f2f0df"))
	draw_rect(Rect2(Vector2(-6, -17 + bob + ear_flick), Vector2(2, 5)), Color("e58f9e"))
	draw_rect(Rect2(Vector2(4, -17 + bob - ear_flick), Vector2(2, 5)), Color("e58f9e"))
	if _is_blinking():
		draw_rect(Rect2(Vector2(-5 + look_bias * 1.5, -9 + bob), Vector2(3, 1)), Color("382e42"))
		draw_rect(Rect2(Vector2(2 + look_bias * 1.5, -9 + bob), Vector2(3, 1)), Color("382e42"))
	else:
		draw_rect(Rect2(Vector2(-4 + look_bias * 1.5, -10 + bob), Vector2(2, 2)), Color("382e42"))
		draw_rect(Rect2(Vector2(3 + look_bias * 1.5, -10 + bob), Vector2(2, 2)), Color("382e42"))

func _draw_back(bob: float, step: float, look_bias: float = 0.0) -> void:
	var ear_flick := sin(anim_time * 2.5) * 0.8 if velocity.length() <= 8.0 else -minf(2.0, dash_left * 8.0)
	_draw_feet(step)
	draw_rect(Rect2(Vector2(-9, -3 + bob), Vector2(18, 13)), Color("514467"))
	draw_rect(Rect2(Vector2(-7, -5 + bob), Vector2(14, 11)), Color("68547c"))
	var satchel_x := 4.0 if look_bias >= 0.0 else -8.0
	draw_rect(Rect2(Vector2(satchel_x, -1 + bob), Vector2(4, 6)), Color("b78978"))
	draw_rect(Rect2(Vector2(-7, -12 + bob), Vector2(14, 12)), Color("e7e5d7"))
	draw_rect(Rect2(Vector2(-7, -19 + bob + ear_flick), Vector2(4, 9)), Color("e7e5d7"))
	draw_rect(Rect2(Vector2(3, -19 + bob - ear_flick), Vector2(4, 9)), Color("e7e5d7"))
	draw_rect(Rect2(Vector2(-6, -17 + bob + ear_flick), Vector2(2, 5)), Color("d98798"))
	draw_rect(Rect2(Vector2(4, -17 + bob - ear_flick), Vector2(2, 5)), Color("d98798"))
	draw_rect(Rect2(Vector2(-2, -6 + bob), Vector2(4, 2)), Color("d6d4c8"))

func _draw_side(bob: float, step: float) -> void:
	var look_sign := -1.0 if facing_direction == Facing.LEFT else 1.0
	var ear_flick := sin(anim_time * 2.5) * 0.8 if velocity.length() <= 8.0 else -minf(2.0, dash_left * 8.0)
	draw_rect(Rect2(Vector2(-5, 5 + step), Vector2(6, 4)), Color("493d61"))
	draw_rect(Rect2(Vector2(1, 5 - step), Vector2(6, 4)), Color("493d61"))
	draw_rect(Rect2(Vector2(-7, -3 + bob), Vector2(15, 13)), Color("514467"))
	draw_rect(Rect2(Vector2(-5, -5 + bob), Vector2(12, 11)), Color("68547c"))
	var head_x := look_sign * 1.0
	draw_rect(Rect2(Vector2(head_x - 6, -12 + bob), Vector2(12, 12)), Color("f2f0df"))
	var ear_y := -19.0 + bob + ear_flick
	var rear_ear_x := head_x - look_sign * 4.0
	var front_ear_x := head_x + look_sign * 1.0
	draw_rect(Rect2(Vector2(rear_ear_x, ear_y), Vector2(3.0, 9.0)), Color("f2f0df"))
	draw_rect(Rect2(Vector2(front_ear_x, ear_y - ear_flick), Vector2(3.0, 9.0)), Color("f2f0df"))
	draw_rect(Rect2(Vector2(rear_ear_x + 1.0, ear_y + 2.0), Vector2(1.0, 5.0)), Color("e58f9e"))
	draw_rect(Rect2(Vector2(front_ear_x + 1.0, ear_y + 2.0 - ear_flick), Vector2(1.0, 5.0)), Color("e58f9e"))
	var eye_y := -9.0 + bob
	if _is_blinking():
		draw_rect(Rect2(Vector2(head_x + look_sign * 3.0, eye_y), Vector2(3, 1)), Color("382e42"))
	else:
		draw_rect(Rect2(Vector2(head_x + look_sign * 3.0, eye_y), Vector2(2, 2)), Color("382e42"))
	draw_rect(Rect2(Vector2(head_x + look_sign * 5.0, -6 + bob), Vector2(2, 2)), Color("e58f9e"))

func _draw_feet(step: float) -> void:
	draw_rect(Rect2(Vector2(-8, 4 + step), Vector2(6, 5)), Color("493d61"))
	draw_rect(Rect2(Vector2(2, 4 - step), Vector2(6, 5)), Color("493d61"))
