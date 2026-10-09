extends CharacterBody2D

const WALK_SPEED := 170.0
const DASH_SPEED := 560.0
const DASH_DURATION := 0.16
const DASH_COOLDOWN := 0.55
var facing := Vector2.RIGHT
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
	var bob := sin(anim_time * 9.0) * 1.4 if velocity.length() > 8.0 else sin(anim_time * 3.5) * 1.0
	for i in range(trail_points.size()):
		var alpha := float(i + 1) / float(trail_points.size() + 1) * 0.25
		var t: Vector2 = trail_points[i]
		draw_rect(Rect2(t + Vector2(-7, -3), Vector2(14, 9)), Color(0.91, 0.98, 0.90, alpha))
	# Dark plum cloak and tiny boots.
	draw_rect(Rect2(Vector2(-8, 4 + bob), Vector2(6, 5)), Color("493d61"))
	draw_rect(Rect2(Vector2(3, 4 + bob), Vector2(6, 5)), Color("493d61"))
	draw_rect(Rect2(Vector2(-9, -3 + bob), Vector2(18, 13)), Color("514467"))
	draw_rect(Rect2(Vector2(-7, -5 + bob), Vector2(14, 11)), Color("68547c"))
	# White round traveler with long ears.
	draw_rect(Rect2(Vector2(-7, -12 + bob), Vector2(14, 12)), Color("f2f0df"))
	draw_rect(Rect2(Vector2(-7, -17 + bob), Vector2(4, 7)), Color("f2f0df"))
	draw_rect(Rect2(Vector2(3, -17 + bob), Vector2(4, 7)), Color("f2f0df"))
	draw_rect(Rect2(Vector2(-5, -15 + bob), Vector2(2, 4)), Color("e58f9e"))
	draw_rect(Rect2(Vector2(4, -15 + bob), Vector2(2, 4)), Color("e58f9e"))
	var eye_offset := Vector2(0, 0)
	if absf(facing.x) > absf(facing.y):
		eye_offset.x = signf(facing.x) * 2.0
	else:
		eye_offset.y = signf(facing.y) * 1.0
	draw_rect(Rect2(Vector2(-3, -10 + bob) + eye_offset, Vector2(2, 2)), Color("382e42"))
	draw_rect(Rect2(Vector2(3, -10 + bob) + eye_offset, Vector2(2, 2)), Color("382e42"))
