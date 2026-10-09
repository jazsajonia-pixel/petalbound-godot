extends CharacterBody2D

enum Facing { DOWN, LEFT, RIGHT, UP, DOWN_LEFT, DOWN_RIGHT, UP_LEFT, UP_RIGHT }

const WALK_SPEED := 170.0
const DASH_SPEED := 560.0
const DASH_DURATION := 0.16
const DASH_COOLDOWN := 0.55
var facing := Vector2.RIGHT
var facing_direction := Facing.RIGHT
var dash_direction := Vector2.RIGHT
var dash_left := 0.0
var cooldown_left := 0.0
var anim_time := 0.0
var trail_points: Array[Vector2] = []

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

func _add_keys(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)

func _physics_process(delta: float) -> void:
	anim_time += delta
	cooldown_left = maxf(0.0, cooldown_left - delta)
	dash_left = maxf(0.0, dash_left - delta)
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
		velocity = direction * WALK_SPEED
	move_and_slide()
	queue_redraw()

func _draw() -> void:
	var walking := velocity.length() > 8.0 and dash_left <= 0.0
	var bob := sin(anim_time * 9.0) * 1.4 if walking else sin(anim_time * 3.5) * 0.8
	var step := sin(anim_time * 12.0) * 1.8 if walking else 0.0
	for i in range(trail_points.size()):
		var alpha := float(i + 1) / float(trail_points.size() + 1) * 0.25
		var point: Vector2 = trail_points[i]
		draw_rect(Rect2(point + Vector2(-7, -3), Vector2(14, 9)), Color(0.91, 0.98, 0.90, alpha))
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

func _draw_front(bob: float, step: float, look_bias: float = 0.0) -> void:
	var ear_flick := sin(anim_time * 2.5) * 0.8 if velocity.length() <= 8.0 else 0.0
	_draw_feet(step)
	draw_rect(Rect2(Vector2(-9, -3 + bob), Vector2(18, 13)), Color("514467"))
	draw_rect(Rect2(Vector2(-7, -5 + bob), Vector2(14, 11)), Color("68547c"))
	draw_rect(Rect2(Vector2(-7, -12 + bob), Vector2(14, 12)), Color("f2f0df"))
	draw_rect(Rect2(Vector2(-7, -19 + bob + ear_flick), Vector2(4, 9)), Color("f2f0df"))
	draw_rect(Rect2(Vector2(3, -19 + bob - ear_flick), Vector2(4, 9)), Color("f2f0df"))
	draw_rect(Rect2(Vector2(-6, -17 + bob + ear_flick), Vector2(2, 5)), Color("e58f9e"))
	draw_rect(Rect2(Vector2(4, -17 + bob - ear_flick), Vector2(2, 5)), Color("e58f9e"))
	draw_rect(Rect2(Vector2(-4 + look_bias * 1.5, -10 + bob), Vector2(2, 2)), Color("382e42"))
	draw_rect(Rect2(Vector2(3 + look_bias * 1.5, -10 + bob), Vector2(2, 2)), Color("382e42"))

func _draw_back(bob: float, step: float, look_bias: float = 0.0) -> void:
	var ear_flick := sin(anim_time * 2.5) * 0.8 if velocity.length() <= 8.0 else 0.0
	_draw_feet(step)
	draw_rect(Rect2(Vector2(-9, -3 + bob), Vector2(18, 13)), Color("514467"))
	draw_rect(Rect2(Vector2(-7, -5 + bob), Vector2(14, 11)), Color("68547c"))
	# A small satchel mark distinguishes the back-facing pose without adding fine detail.
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
	var ear_flick := sin(anim_time * 2.5) * 0.8 if velocity.length() <= 8.0 else 0.0
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
	draw_rect(Rect2(Vector2(head_x + look_sign * 3.0, -9 + bob), Vector2(2, 2)), Color("382e42"))
	draw_rect(Rect2(Vector2(head_x + look_sign * 5.0, -6 + bob), Vector2(2, 2)), Color("e58f9e"))

func _draw_feet(step: float) -> void:
	draw_rect(Rect2(Vector2(-8, 4 + step), Vector2(6, 5)), Color("493d61"))
	draw_rect(Rect2(Vector2(2, 4 - step), Vector2(6, 5)), Color("493d61"))
