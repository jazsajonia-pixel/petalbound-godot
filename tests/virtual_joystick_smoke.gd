extends SceneTree

func _initialize() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	preload("res://scripts/systems/save.gd").path_override = "user://petalbound_test_save.json"
	var packed_scene := load("res://scenes/main.tscn") as PackedScene
	var game := packed_scene.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	var menu_hud := game.get("hud") as Control
	var start_button := menu_hud.get("title_button") as Button if menu_hud != null else null
	if start_button == null:
		push_error("Could not find the start button in the title menu.")
		quit(1)
		return
	start_button.pressed.emit()
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
	var deadzone_slider := hud.get("deadzone_slider") as HSlider
	var sensitivity_slider := hud.get("sensitivity_slider") as HSlider
	var joystick_settings_work := deadzone_slider != null and sensitivity_slider != null
	if joystick_settings_work:
		hud.joystick_touch_index = 5
		hud.call("_update_joystick", hud.joystick_center + Vector2(hud.joystick_radius * 0.05, 0.0))
		var deadzone_blocks_drift: bool = hud.joystick_vector == Vector2.ZERO
		deadzone_slider.value = 0.2
		hud.call("_update_joystick", hud.joystick_center + Vector2(hud.joystick_radius * 0.6, 0.0))
		var baseline_strength: float = hud.joystick_vector.x
		sensitivity_slider.value = 1.5
		var sensitivity_strength: float = hud.joystick_vector.x
		joystick_settings_work = deadzone_blocks_drift and is_equal_approx(hud.joystick_deadzone, 0.2) and is_equal_approx(hud.joystick_sensitivity, 1.5) and sensitivity_strength > baseline_strength
		hud.call("_end_joystick")
	var pause_overlay := hud.get("pause_overlay") as Control
	var pause_button := hud.get("pause_button") as Button
	var resume_button: Button
	if pause_overlay != null:
		resume_button = pause_overlay.find_child("ResumeButton", true, false) as Button
	var pause_works := false
	var resume_works := false
	if pause_overlay != null and pause_button != null and resume_button != null:
		pause_button.pressed.emit()
		pause_works = paused and pause_overlay.visible
		resume_button.pressed.emit()
		resume_works = not paused and not pause_overlay.visible
	hud.joystick_touch_index = 9
	hud.joystick_vector = Vector2.RIGHT
	hud.call("_apply_joystick_actions")
	Input.action_press("dash")
	hud.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	var focus_loss_clears_inputs: bool = hud.joystick_touch_index == -1 and hud.joystick_vector == Vector2.ZERO and not Input.is_action_pressed("move_left") and not Input.is_action_pressed("move_right") and not Input.is_action_pressed("move_up") and not Input.is_action_pressed("move_down") and not Input.is_action_pressed("dash")
	if not moved_right:
		push_error("Virtual joystick drag did not move the player right.")
	if not joystick_released:
		push_error("Virtual joystick did not release movement input cleanly.")
	if not joystick_settings_work:
		push_error("Joystick dead-zone or sensitivity settings did not change input response.")
	if not pause_works or not resume_works:
		push_error("Pause/resume did not show the overlay and restore the tree state.")
	if not focus_loss_clears_inputs:
		push_error("Application focus loss did not clear held touch controls.")
		if not moved_right or not joystick_released or not joystick_settings_work or not pause_works or not resume_works or not focus_loss_clears_inputs:
			quit(1)
			return
	print("Mobile-controls smoke test passed: joystick drag/release, tuning, pause/resume, and focus-loss input cleanup work.")
	game.get("audio").call("stop_all")
	game.queue_free()
	await process_frame
	quit(0)
