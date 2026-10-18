extends SceneTree
## Screenshots of Saltbloom Shoals for visual QA (user://shots/salt_*.png).
## xvfb-run godot --path . --rendering-driver opengl3 -s tools/saltbloom_shots.gd

const Settings := preload("res://scripts/systems/settings.gd")
const Save := preload("res://scripts/systems/save.gd")

const SPOTS := {"gate": [399.0, 100.5], "brinewick": [420.0, 102.0], "lagoon": [430.0, 82.0], "reef": [435.0, 129.0], "coast": [446.0, 120.0], "beach_south": [412.0, 150.0]}


func _initialize() -> void:
	Settings.path_override = "user://petalbound_shot_settings.cfg"
	Settings.erase()
	Save.path_override = "user://petalbound_shot_save.json"
	Save.erase()
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var game: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.hud.title_button.pressed.emit()
	await create_timer(0.2).timeout
	game.hud.call("confirm_character")
	await create_timer(0.3).timeout
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots"))
	for name in SPOTS:
		game.player.global_position = Vector2(SPOTS[name][0], SPOTS[name][1]) * 16.0
		game.player.invulnerable_left = 99.0
		for e in game.enemies:
			e.set_physics_process(false)
		await create_timer(1.6).timeout
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("user://shots/salt_%s.png" % name)
		print("shot ", name, " region=", game.world.region_name(game.player.global_position))
	quit(0)
