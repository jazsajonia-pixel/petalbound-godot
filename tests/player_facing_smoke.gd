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
	if player == null:
		push_error("Could not find the player in the main scene.")
		quit(1)
		return

	var cases: Array[Dictionary] = [
		{"actions": ["move_down"], "expected": 0},
		{"actions": ["move_left"], "expected": 1},
		{"actions": ["move_right"], "expected": 2},
		{"actions": ["move_up"], "expected": 3},
		{"actions": ["move_down", "move_left"], "expected": 4},
		{"actions": ["move_down", "move_right"], "expected": 5},
		{"actions": ["move_up", "move_left"], "expected": 6},
		{"actions": ["move_up", "move_right"], "expected": 7}
	]
	for test_case in cases:
		for action in ["move_left", "move_right", "move_up", "move_down"]:
			Input.action_release(action)
		var pressed_actions: Array = test_case["actions"]
		for action_name in pressed_actions:
			Input.action_press(action_name)
		await physics_frame
		for action_name in pressed_actions:
			Input.action_release(action_name)
		var actual_facing: int = player.get("facing_direction")
		if actual_facing != int(test_case["expected"]):
			push_error("Input %s selected facing %d, expected %d." % [pressed_actions, actual_facing, test_case["expected"]])
			quit(1)
			return

	print("Character-facing smoke test passed: all four cardinal and four diagonal inputs select matching pose states.")
	quit(0)
