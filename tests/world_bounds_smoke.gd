extends SceneTree
## The open world is fenced on all four sides: Mallow can walk (or swim) to the edge but never leave it.

func _initialize() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	preload("res://scripts/systems/save.gd").path_override = "user://petalbound_test_save.json"
	var game: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	(game.hud.title_button as Button).pressed.emit()
	await process_frame
	await physics_frame
	var player: CharacterBody2D = game.player
	var world_size: Vector2 = game.world.world_size
	# clear props and creatures so only the world fence can stop the walk
	game.world.solids.collision_layer = 0
	game.world.low_solids.collision_layer = 0
	for e in game.enemies:
		e.set_physics_process(false)
		e.collision_layer = 0
	for n in game.npcs:
		n.collision_layer = 0
	var scenarios: Array[Dictionary] = [
		{"action": "move_left", "start": Vector2(70, 1400), "axis": "x", "dir": -1},
		{"action": "move_right", "start": Vector2(world_size.x - 70, 1400), "axis": "x", "dir": 1},
		{"action": "move_up", "start": Vector2(2000, 70), "axis": "y", "dir": -1},
		{"action": "move_down", "start": Vector2(1200, world_size.y - 60), "axis": "y", "dir": 1},
	]
	for sc in scenarios:
		for a in ["move_left", "move_right", "move_up", "move_down"]:
			Input.action_release(a)
		player.global_position = sc["start"]
		player.velocity = Vector2.ZERO
		await physics_frame
		Input.action_press(sc["action"])
		for i in range(110):
			await physics_frame
			game._activation_t = 1.0
		Input.action_release(sc["action"])
		await physics_frame
		var c: float = player.global_position.x if sc["axis"] == "x" else player.global_position.y
		var size_axis: float = world_size.x if sc["axis"] == "x" else world_size.y
		var inside := c > 0.0 and c < size_axis
		var reached := c < 30.0 if sc["dir"] < 0 else c > size_axis - 30.0
		if not inside or not reached:
			push_error("%s: coordinate %s (inside=%s reached=%s)" % [sc["action"], c, inside, reached])
			quit(1)
			return
	print("World-bounds smoke test passed: Mallow reached and was stopped at all four edges of the open world.")
	game.get("audio").call("stop_all")
	game.queue_free()
	await process_frame
	quit(0)
