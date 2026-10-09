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
		{"action": "move_down", "expected": 0},
		{"action": "move_left", "expected": 1},
		{"action": "move_right", "expected": 2},
		{"action": "move_up", "expected": 3}
	]
	for test_case in cases:
		for action in ["move_left", "move_right", "move_up", "move_down"]:
			Input.action_release(action)
		var action_name: String = test_case["action"]
		Input.action_press(action_name)
		await physics_frame
		Input.action_release(action_name)
		var actual_facing: int = player.get("facing_direction")
		if actual_facing != int(test_case["expected"]):
			push_error("%s input selected facing %d, expected %d." % [action_name, actual_facing, test_case["expected"]])
			quit(1)
			return

	print("Character-facing smoke test passed: down, left, right, and up input select the matching pose.")
	quit(0)
