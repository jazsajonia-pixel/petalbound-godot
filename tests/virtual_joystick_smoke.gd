extends SceneTree

func _initialize() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	var packed_scene := load("res://scenes/main.tscn") as PackedScene
	var game := packed_scene.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame

	var player := game.get("player") as CharacterBody2D
	var hud := game.get("hud") as Control
	if player == null or hud == null:
		push_error("Could not find the player or HUD in the main scene.")
		quit(1)
		return
	var start_position := player.global_position
	var safe_area: Rect2 = hud.get("safe_rect")
	var touch_radius: float = hud.get("joystick_radius")
	var touch_start: Vector2 = safe_area.position + Vector2(safe_area.size.x * 0.20, safe_area.size.y * 0.75)
	var touch_drag: Vector2 = touch_start + Vector2(touch_radius, 0.0)

	var press := InputEventScreenTouch.new()
	press.index = 4
	press.position = touch_start
	press.pressed = true
	hud.call("_input", press)

	var drag := InputEventScreenDrag.new()
	drag.index = 4
	drag.position = touch_drag
	drag.relative = touch_drag - touch_start
	hud.call("_input", drag)
	for i in range(8):
		await physics_frame

	var moved_right := player.global_position.x > start_position.x + 10.0
	var release := InputEventScreenTouch.new()
	release.index = 4
	release.position = touch_drag
	release.pressed = false
	hud.call("_input", release)
	await physics_frame

	var joystick_released: bool = hud.joystick_touch_index == -1 and not Input.is_action_pressed("move_right")
	if not moved_right:
		push_error("Virtual joystick drag did not move the player right.")
	if not joystick_released:
		push_error("Virtual joystick did not release movement input cleanly.")
	if not moved_right or not joystick_released:
		quit(1)
		return
	print("Virtual joystick smoke test passed: drag moved player; release cleared input.")
	quit(0)
