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
	await create_timer(0.3).timeout
	await shot("00_title")
	game.hud.title_button.pressed.emit()
	await create_timer(0.3).timeout
	await shot("00b_character_creation")
	game.hud.create_state["look"] = preload("res://scripts/actors/hero_look.gd").PRESETS[2]
	preload("res://scripts/ui/char_create.gd").render(game.hud)
	await create_timer(0.2).timeout
	await shot("00c_character_preset")
	game.hud.call("confirm_character")
	for i in range(10):
		await process_frame
	player = game.player
	game.hud._layout_controls()
	await create_timer(0.6).timeout
	await shot("00d_unarmed_village")
	await _expansion_shots()
	await _gaps_shots()
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


func _expansion_shots() -> void:
	var hud: Control = game.hud
	# quest markers over villagers
	var alder: Node = null
	for n in game.npcs:
		if n.npc_id == "alder":
			alder = n
	if alder:
		player.global_position = alder.global_position + Vector2(-40, 20)
		for r in range(1, 12):
			var q: Vector2 = alder.global_position + Vector2(-16.0 * r, 24.0)
			if game.rifts.is_open_ground(q):
				player.global_position = q
				break
		game.camera.global_position = player.global_position
		game.camera.reset_smoothing()
		await create_timer(0.8).timeout
		await shot("14_quest_marker")
	# held weapons and armour visuals
	player.give_item("thornblade")
	player.equip_weapon("thornblade")
	for id in ["briar_mail", "mossleaf_cap"]:
		player.give_item(id)
		if not player.equipped.values().has(id):
			player.equip(id)
	await create_timer(0.3).timeout
	await shot("15_armed_armoured")
	player.bind_class("nightbloom")
	player.give_item("nightfang")
	player.equip_weapon("nightfang")
	await create_timer(0.3).timeout
	await shot("16_dual_knives")
	# loot feed + rarity banner
	for id in ["slime_gel", "ore", "moon_shard"]:
		preload("res://scripts/systems/inventory.gd").add(player, id, 3)
		hud.show_loot(id, 3)
	hud.show_item_get("moonwell_blade")
	await create_timer(0.4).timeout
	await shot("17_loot_feed")
	# shop screens
	player.petalcoins = 120
	game.shop_id = "pip"
	hud.open_trade("pip", "buy")
	await shot("18_shop_buy")
	hud.open_trade("pip", "sell")
	await shot("19_shop_sell")
	game.shop_id = "bramble"
	hud.open_trade("bramble", "craft")
	await shot("20_forge_craft")
	hud.open_trade("bramble", "trade")
	await shot("21_forge_trade")
	hud.close_trade()
	hud.toggle_inventory()
	hud.set_meta("satchel_filter", "bag")
	hud._refresh_inventory()
	await shot("22_satchel_materials")
	hud.set_meta("satchel_filter", "all")
	hud.toggle_inventory()
	hud.toggle_journeys()
	await shot("23_journeys")
	hud.toggle_journeys()
	# interior
	var h: Dictionary = game._house("house_alder")
	player.global_position = h["door"] + Vector2(0, 10)
	game.enter_interior("house_alder")
	await create_timer(0.8).timeout
	await shot("24_interior_hall")
	game.enter_interior("alder_study")
	await create_timer(0.8).timeout
	await shot("25_interior_study")
	game.leave_interior()
	game.leave_interior()
	await create_timer(0.6).timeout
	# rift
	var R: Node = game.rifts
	R.build_spawn_points()
	var hg: Array = game.world.data["landmarks"]["hearthgrove"]
	player.global_position = Vector2(hg[0], hg[1])
	R.try_spawn()
	player.global_position = R.entrance["point"] + Vector2(-30, 10)
	game.camera.global_position = player.global_position
	game.camera.reset_smoothing()
	await create_timer(0.6).timeout
	await shot("26_rift_entrance")
	hud.toggle_map()
	await create_timer(0.2).timeout
	await shot("27_map_rift")
	hud.toggle_map()
	player.level = 20
	player.global_position = R.entrance["point"]
	R.enter()
	await create_timer(1.2).timeout
	await shot("28_rift_chamber")
	R.leave(false)
	await create_timer(0.5).timeout
	player.unequip_weapon()
	player.unequip("armor")


func _goto(p: Vector2, wait := 0.6) -> void:
	player.global_position = p
	game.camera.global_position = p
	game.camera.reset_smoothing()
	await create_timer(wait).timeout


## Emberleaf Vale, Emberbark telegraphs, the cloak layer and textured rifts.
func _gaps_shots() -> void:
	var hud: Control = game.hud
	player.invulnerable_left = 999.0
	for e in game.enemies:
		e.set_physics_process(false)
	await _goto(Vector2(299.5, 96.4) * 16.0, 1.0)
	await shot("40_ember_gate")
	await _goto(Vector2(320.0, 100.5) * 16.0, 1.0)
	await shot("41_cinderbrook")
	await _goto(Vector2(334.0, 132.0) * 16.0, 0.8)
	await shot("42_ember_grove")
	# the cloak from each side (player close-ups are cropped from these)
	if not player.equipped.values().has("plum_cloak"):
		player.equip("plum_cloak")
	player.invulnerable_left = 0.0
	await _goto(Vector2(321.0, 104.0) * 16.0, 0.4)
	for d in [["up", Vector2.UP], ["left", Vector2.LEFT], ["down", Vector2.DOWN]]:
		player._set_facing(d[1])
		await create_timer(0.25).timeout
		await shot("43_cloak_%s" % d[0])
	player.invulnerable_left = 999.0
	# Emberbark telegraphs
	var b: Node = null
	for x in game.bosses:
		if x.boss_id == "emberbark":
			b = x
	if b != null:
		await _goto(b.global_position + Vector2(0, 80), 1.6)
		b.awake = true
		for atk in ["charge", "spread", "ring"]:
			b.set_physics_process(true)
			b.pattern_i = (b.attack_pattern() as Array).find(atk)
			b.state = "idle"
			b._next_attack()
			b.set_physics_process(false)
			b._physics_process(0.016)
			await create_timer(0.12 if atk == "spread" else 0.3).timeout
			await shot("44_boss_%s" % atk)
			for t in game.fx.get_children():
				if t.get("shape") != null:
					t.queue_free()
		b.enraged = true
		b.pattern_i = (b.attack_pattern() as Array).find("quake")
		b.state = "idle"
		b._next_attack()
		b._physics_process(0.016)
		await create_timer(0.55).timeout
		await shot("44_boss_quake")
		b.state = "idle"
		b.awake = false
		b.enraged = false
		game.active_boss = null
		hud.boss_panel.visible = false
	hud.toggle_map()
	await create_timer(0.2).timeout
	await shot("45_map_ember")
	hud.toggle_map()
	# textured rift chambers
	var R: Node = game.rifts
	R._close_entrance()
	R._since = 0.0
	var hg: Array = game.world.data["landmarks"]["hearthgrove"]
	player.global_position = Vector2(hg[0], hg[1])
	if R.try_spawn():
		player.global_position = R.entrance["point"]
		R.enter()
		await create_timer(1.0).timeout
		for t in R.targets():
			if is_instance_valid(t):
				t.set_physics_process(false)
		await shot("46_rift_tiles_a")
		player.global_position = R.room_center(1) + Vector2(-60, 20)
		await create_timer(0.8).timeout
		await shot("46_rift_tiles_b")
		R.leave(false)
		await create_timer(0.5).timeout
	player.invulnerable_left = 0.0
