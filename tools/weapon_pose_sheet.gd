extends SceneTree
## Renders Mallow holding every weapon in all four facings, at rest and mid-swing,
## into one contact sheet (user://shots/weapon_poses.png). Visual QA aid, not a test.
## xvfb-run godot --path . --rendering-driver opengl3 -s tools/weapon_pose_sheet.gd

const Settings := preload("res://scripts/systems/settings.gd")
const Save := preload("res://scripts/systems/save.gd")
const DB := preload("res://scripts/data/db.gd")

const CELL := 72
const DIRS := {"down": Vector2.DOWN, "left": Vector2.LEFT, "right": Vector2.RIGHT, "up": Vector2.UP}

var game: Node
var player: Node


func _initialize() -> void:
	Settings.path_override = "user://petalbound_pose_settings.cfg"
	Settings.erase()
	Save.path_override = "user://petalbound_pose_save.json"
	Save.erase()
	call_deferred("_run")


func _grab(scale: float) -> Image:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var p: Vector2 = player.get_global_transform_with_canvas().origin * scale + Vector2(0, -8 * scale)
	var half := CELL / 2 * int(scale)
	var crop := img.get_region(Rect2i(int(p.x) - half, int(p.y) - half, half * 2, half * 2))
	crop.resize(CELL * 2, CELL * 2, Image.INTERPOLATE_NEAREST)
	return crop


func _run() -> void:
	root.size = Vector2i(1280, 720)
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.hud.title_button.pressed.emit()
	await create_timer(0.2).timeout
	game.hud.call("confirm_character")
	for i in range(10):
		await process_frame
	player = game.player
	game.hud.visible = false
	var only := OS.get_environment("POSE_WEAPONS")
	var ids: Array = []
	for id in DB.ITEMS:
		var it: Dictionary = DB.ITEMS[id]
		if it.get("type", "") == "weapon" and not it.get("unarmed", false) and DB.hand_path(id) != "":
			if only.is_empty() or (only.split(",") as Array).has(id):
				ids.append(id)
	var scale := float(root.get_texture().get_image().get_width()) / root.get_visible_rect().size.x
	var cols := 8  # 4 rest + 4 swing
	var sheet := Image.create(cols * CELL * 2 + 180, ids.size() * CELL * 2, false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.12, 0.12, 0.15))
	for row in range(ids.size()):
		var id: String = ids[row]
		player.give_item(id)
		player._set_weapon_index(player.weapons_owned.find(id))
		var col := 0
		for swing in [false, true]:
			for d in DIRS:
				player._set_facing(DIRS[d])
				player.velocity = Vector2.ZERO
				player.refresh_held_weapon()
				await create_timer(0.05).timeout
				if swing:
					player.attack_combo = 0
					player._swing_weapon(0.8, false)
					await create_timer(0.4).timeout
				var c: Image = await _grab(scale)
				sheet.blit_rect(c, Rect2i(0, 0, CELL * 2, CELL * 2), Vector2i(col * CELL * 2, row * CELL * 2))
				col += 1
				if swing:
					await create_timer(0.5).timeout
		print("pose ", row, " ", id)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots"))
	sheet.save_png("user://shots/weapon_poses.png")
	var f := FileAccess.open("user://shots/weapon_poses.txt", FileAccess.WRITE)
	f.store_string("\n".join(ids))
	print("sheet ", ProjectSettings.globalize_path("user://shots/weapon_poses.png"))
	quit(0)
