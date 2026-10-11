extends SceneTree
## Multi-touch: the joystick and an action button can be held at the same time, and each
## touch releases only its own input.

func _initialize() -> void:
	call_deferred("_run_test")

func _touch(hud: Control, index: int, pos: Vector2, pressed: bool) -> void:
	var t := InputEventScreenTouch.new()
	t.index = index
	t.position = pos
	t.pressed = pressed
	hud.call("_input", t)

func _run_test() -> void:
	preload("res://scripts/systems/save.gd").path_override = "user://petalbound_test_save.json"
	var game: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	(game.hud.title_button as Button).pressed.emit()
	await process_frame
	await process_frame
	var hud: Control = game.hud
	hud.show_touch = true
	await process_frame
	var ok := true
	var stick_start: Vector2 = hud.joystick_home
	_touch(hud, 0, stick_start, true)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = stick_start + Vector2(hud.joystick_radius * 0.6, 0)
	hud.call("_input", drag)
	var attack_center: Vector2 = hud.attack_button.position + Vector2(hud.attack_button.radius, hud.attack_button.radius)
	_touch(hud, 1, attack_center, true)
	ok = ok and Input.is_action_pressed("attack") and Input.is_action_pressed("move_right")
	_touch(hud, 1, attack_center, false)
	ok = ok and not Input.is_action_pressed("attack") and Input.is_action_pressed("move_right")
	var dash_center: Vector2 = hud.dash_button.position + Vector2(hud.dash_button.radius, hud.dash_button.radius)
	_touch(hud, 2, dash_center, true)
	ok = ok and Input.is_action_pressed("dash")
	_touch(hud, 0, stick_start, false)
	ok = ok and not Input.is_action_pressed("move_right") and Input.is_action_pressed("dash")
	_touch(hud, 2, dash_center, false)
	ok = ok and not Input.is_action_pressed("dash")
	var w_before: int = game.player.weapon_index
	var swap_center: Vector2 = hud.weapon_button.position + Vector2(hud.weapon_button.radius, hud.weapon_button.radius)
	_touch(hud, 3, swap_center, true)
	_touch(hud, 3, swap_center, false)
	ok = ok and game.player.weapon_index != w_before
	if not ok:
		push_error("Multi-touch buttons did not press/release their own actions independently.")
		quit(1)
		return
	print("Touch-buttons smoke test passed: joystick + action buttons work together with independent releases.")
	quit(0)
