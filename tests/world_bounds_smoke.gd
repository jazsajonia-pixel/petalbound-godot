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

	var scenarios: Array[Dictionary] = [
		{"action": "move_left", "start": Vector2(220, 500), "axis": "x", "direction": "min", "limit": 36.0},
		{"action": "move_right", "start": Vector2(1580, 500), "axis": "x", "direction": "max", "limit": 1764.0},
		{"action": "move_up", "start": Vector2(900, 250), "axis": "y", "direction": "min", "limit": 36.0},
		{"action": "move_down", "start": Vector2(220, 830), "axis": "y", "direction": "max", "limit": 1064.0}
	]

	for scenario in scenarios:
		for action in ["move_left", "move_right", "move_up", "move_down"]:
			Input.action_release(action)
		player.global_position = scenario["start"]
		player.velocity = Vector2.ZERO
		await physics_frame
		Input.action_press(scenario["action"])
		for frame in range(90):
			await physics_frame
		Input.action_release(scenario["action"])
		await physics_frame

		var coordinate: float = player.global_position.x if scenario["axis"] == "x" else player.global_position.y
		var limit: float = scenario["limit"]
		var reached_bound: bool = coordinate <= limit if scenario["direction"] == "min" else coordinate >= limit
		if not reached_bound:
			push_error("Player did not reach the %s world bound; coordinate was %s." % [scenario["action"], coordinate])
			quit(1)
			return

	print("World-bounds smoke test passed: player was stopped at all four edges.")
	quit(0)
