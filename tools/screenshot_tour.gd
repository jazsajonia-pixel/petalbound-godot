extends SceneTree
## Renders screenshots of the overhauled combat HUD, aiming, menus and the HUD
## editor to user://shots/ (needs a display, e.g. xvfb-run; not a pass/fail test).

const Settings := preload("res://scripts/systems/settings.gd")
const Save := preload("res://scripts/systems/save.gd")
const StatusFx := preload("res://scripts/combat/status.gd")

var game: Node
var player: Node


func _initialize() -> void:
	Settings.path_override = "user://petalbound_shot_settings.cfg"
	Settings.erase()
	Save.path_override = "user://petalbound_shot_save.json"
	Save.erase()
	call_deferred("_run")


func shot(name: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://shots"))
	img.save_png("user://shots/%s.png" % name)
	print("shot ", ProjectSettings.globalize_path("user://shots/%s.png" % name))


func _run() -> void:
	root.size = Vector2i(1280, 720)
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	game.hud.settings["touch_controls"] = "on"
	game.hud.apply_settings()
	game.hud.title_button.pressed.emit()
	for i in range(10):
		await process_frame
	player = game.player
	game.hud._layout_controls()
	player.add_xp(3000)
	player.skill_points = 30
	player.bind_class("nightbloom")
	player.spend_node("nightbloom", "nightveil")
	player.spend_node("nightbloom", "quiet_step")
	player.bind_class("gravetender")
	player.give_item("ember_heart")
	if player.equipped.get("relic", "") != "ember_heart":
		player.equip("ember_heart")
	player.set_skill_slot(2, "toxic_veil")
	# a couple of foes near Mallow
	var EnemyScript := preload("res://scripts/actors/enemy.gd")
	var foes: Array = []
	for off in [Vector2(30, 6), Vector2(70, -30), Vector2(-50, 40)]:
		var e := EnemyScript.new()
		e.setup(game, "mushroom", player.global_position + off)
		game.entities.add_child(e)
		game.enemies.append(e)
		e.max_hp = 60
		e.hp = 60
		e.set_physics_process(false)
		foes.append(e)
	StatusFx.apply(game, foes[0], "poison", 2)
	StatusFx.apply(game, foes[0], "curse", 1)
	player._update_target()
	await create_timer(0.4).timeout
	await shot("01_hud_idle")
	player.skill_cd["shadowstep"] = 4.0
	player.skill_cd["fan_knives"] = 1.5
	player.dodge_cd = 0.3
	player.activate_relic()
	player.try_attack()
	await create_timer(0.05).timeout
	await shot("02_combat")
	# aim preview for a point art (toxic veil, slot 2)
	var ctl: Node = game.hud.controls
	var b: Control = ctl.skill_buttons[2]
	var e1 := InputEventScreenTouch.new()
	e1.index = 3
	e1.position = b.center()
	e1.pressed = true
	game.hud._input(e1)
	var d := InputEventScreenDrag.new()
	d.index = 3
	d.position = b.center() + Vector2(-45, -20)
	game.hud._input(d)
	await shot("03_aim_point")
	var e2 := InputEventScreenTouch.new()
	e2.index = 3
	e2.position = d.position
	e2.pressed = false
	game.hud._input(e2)
	player.skill_cd["fan_knives"] = 0.0
	var b1: Control = ctl.skill_buttons[1]
	e1.position = b1.center()
	e1.index = 4
	game.hud._input(e1)
	d.index = 4
	d.position = b1.center() + Vector2(-50, -10)
	game.hud._input(d)
	await shot("04_aim_direction")
	e2.index = 4
	game.hud._input(e2)
	# weapons: staff line + hammer circle
	player.give_item("bloomstaff")
	player.equip_weapon("bloomstaff")
	await create_timer(0.1).timeout
	await shot("05_staff_indicator")
	player.equip_weapon("grave_scythe")
	await shot("06_scythe_indicator")
	# menus
	game.hud.toggle_arts()
	await shot("07_arts_loadout")
	game.hud.toggle_arts()
	game.hud.toggle_inventory()
	game.hud.satchel_selected = "twilight_mantle"
	player.give_item("twilight_mantle")
	game.hud._refresh_inventory()
	await shot("08_satchel")
	game.hud.satchel_selected = "frostlace_robe"
	player.give_item("frostlace_robe")
	game.hud._refresh_inventory()
	await shot("09_satchel_locked")
	game.hud.toggle_inventory()
	game.hud.set_game_paused(true)
	await shot("10_settings")
	game.hud.set_game_paused(false)
	game.hud.controls.start_edit()
	await shot("11_hud_editor")
	game.hud.controls.end_edit()
	# small phone aspect
	root.size = Vector2i(960, 432)
	await create_timer(0.2).timeout
	game.hud._layout_controls()
	await shot("12_wide_phone")
	game.hud.settings["hud_scale"] = 1.3
	game.hud.settings["button_size"] = 1.35
	game.hud._layout_controls()
	await shot("13_max_scale")
	Settings.erase()
	Save.erase()
	game.get("audio").call("stop_all")
	game.free()
	quit(0)
