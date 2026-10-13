extends SceneTree
## Headless smoke test for the Starfall content update: the seventh biome, fishing,
## moonpetals and night wisps, perfect parry, the Blighted Depths, the moth companion,
## the feats overlay and photo mode, plus save/load round-trip of the new state.

const Save := preload("res://scripts/systems/save.gd")
const DB := preload("res://scripts/data/db.gd")
const ClassBook := preload("res://scripts/data/classdb.gd")

var game: Node
var player: CharacterBody2D
var failures: PackedStringArray = []


func _initialize() -> void:
	preload("res://scripts/systems/settings.gd").path_override = "user://petalbound_test_settings.cfg"
	preload("res://scripts/systems/settings.gd").erase()
	call_deferred("_run_test")


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)
		push_error(msg)


func frames(n: int) -> void:
	for i in range(n):
		await physics_frame


func release_all() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down", "sprint", "jump", "attack", "interact"]:
		Input.action_release(a)


func _run_test() -> void:
	Save.path_override = "user://petalbound_content_test_save.json"
	Save.erase()
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	game.hud.title_button.pressed.emit()
	game.hud.call("confirm_character")
	await process_frame
	await physics_frame
	player = game.player
	release_all()
	check(game.game_started, "New Journey should start the game.")

	# ---- Starfall Rise
	check(game.world.tiles == Vector2i(400, 176), "The world should expand to 400 x 176 tiles (Starfall + Moonpetal + Emberleaf) (got %s)." % game.world.tiles)
	check(game.world.world_size.x > 6300.0, "The world width should grow past 5900px.")
	check(game.world.biome_at(Vector2(4600, 1460)) == 6, "Starfall Rise should be biome 6 at the Watch.")
	check(game.world.region_name(Vector2(4600, 1460)) == "Starfall Rise", "The eastern rise should be named Starfall Rise.")
	check(game.world.biome_at(Vector2(320 * 16, 88 * 16)) == 7, "Moonpetal Hollow should use its own eighth biome index.")
	check(game.world.region_name(Vector2(320 * 16, 88 * 16)) == "Moonpetal Hollow", "The eastern grove should retain its region name.")
	check(game.world.is_water(Vector2(328 * 16 + 8, 61 * 16 + 8)), "Moonpetal's upper pool should be water outside its central islet.")
	check(game.world.biome_at(Vector2(350 * 16, 88 * 16)) == 8, "Emberleaf Vale should use a distinct ninth biome index.")
	check(game.world.region_name(Vector2(362 * 16, 98 * 16)) == "Cinderbrook Camp", "Cinderbrook should be named around its waystone.")
	check(game.hud.arts_tabs.get_tab_title(0) == "CLASS LINES" and game.hud.arts_tabs.get_tab_title(1) == "SKILLS + LOADOUT", "Classes and skills should be shown on separate, clearly named tabs.")
	check(game.hud.class_list != null and game.hud.arts_list != null, "The class and skill tables should both be available.")
	for sid in ["moonstep", "seedling", "thorn_snare"]:
		var sd: Dictionary = ClassBook.skill_of(sid)
		check(not sd.is_empty() and FileAccess.file_exists(sd["icon"]), "New art %s should have a definition and unique icon." % sid)
	for gid in ["hollowglow_charm", "starweft_boots", "moonpetal_ring", "moonfall_circlet"]:
		check(DB.ITEMS.has(gid) and FileAccess.file_exists(DB.ITEMS[gid]["icon"]), "New Moonpetal gear %s should have a definition and icon." % gid)
	var hollow_chests := 0
	for chest in game.chests:
		if String(chest["id"]).begins_with("c_hollow_"):
			hollow_chests += 1
	check(hollow_chests == 4, "The new grove should contain four discoverable equipment chests.")
	var lumen_found := false
	for n in game.npcs:
		if n.npc_id == "lumen":
			lumen_found = true
	check(lumen_found, "Lumen the Stargazer should live in Starfall Rise.")
	check(game.world.is_water(Vector2(276 * 16 + 8, 58 * 16 + 8)), "Mirror Basin should be water.")
	check(DB.dialogue("lumen", 0, {}).size() >= 3, "Lumen should have dialogue.")

	# ---- fishing
	var shore := Vector2.ZERO
	var cast_pos := Vector2.ZERO
	for y in range(1500, 1650, 2):
		for x in range(1890, 1690, -2):
			var dry: Vector2 = Vector2(x, y)
			var water: Vector2 = dry + Vector2(20, 0)
			if not game.world.is_water(dry) and game.world.is_water(water):
				shore = dry
				cast_pos = water
				break
		if cast_pos != Vector2.ZERO:
			break
	check(cast_pos != Vector2.ZERO, "A dry shoreline next to water should be available.")
	player.global_position = shore
	player.state = player.State.MOVE
	player._set_facing(Vector2.RIGHT)
	await frames(2)
	game._update_interactables()
	check(game._interact_target.get("label", "") == "FISH", "The FISH prompt should appear from dry ground beside water.")
	check(game.world.is_water(cast_pos), "A fishing spot should be found at Lake Lumen.")
	var coins_before: int = player.petalcoins
	check(game.fishing.start(game, cast_pos), "Casting should start fishing.")
	check(player.fishing, "Fishing should hold Mallow in place.")
	game.fishing._state = "bite"
	game.fishing._t = 0.0
	game.fishing._hook()
	await frames(2)
	check(not game.fishing.active and not player.fishing, "Hooking a bite should land the fish.")
	check(not (game.stats["fish"] as Dictionary).is_empty(), "A caught fish should be logged in the stats.")
	check(player.petalcoins > coins_before, "Fish should pay Petalcoins.")
	check(game.achievements.has("first_cast"), "First Cast should unlock.")

	# ---- night: moonpetals and wisps
	game.environment.time_of_day = 0.95
	await frames(4)
	check(game.night_wisps.size() >= 4, "Night wisps should rise after dark (got %d)." % game.night_wisps.size())
	for e in game.night_wisps:
		e.set_physics_process(false)
	player.moontea_charges = 0
	var gathered := 0
	for mp in game.moonpetals:
		if gathered >= 5:
			break
		player.global_position = (mp["pos"] as Vector2) + Vector2(0, 8)
		await frames(2)
		game._update_interactables()
		if game._interact_target.get("type", "") == "moonpetal":
			game._interact()
			gathered += 1
	check(gathered >= 5, "Five moonpetals should be gatherable at night (got %d)." % gathered)
	check(player.moontea_charges > 0, "Moonpetals should refill Moontea.")
	check(game.achievements.has("night_gardener"), "Night Gardener should unlock at five petals.")
	game.environment.time_of_day = 0.4
	await frames(4)
	check(game.night_wisps.is_empty(), "Night wisps should fade at dawn.")

	# ---- perfect parry
	player.stamina = 100.0
	player.state = player.State.MOVE
	check(player.start_roll(Vector2.RIGHT), "Roll should start for the parry test.")
	var hp_par: int = player.health
	player.take_damage(3, player.global_position + Vector2(10, 0))
	check(player.health == hp_par, "A perfect parry should take no damage.")
	check(int(game.stats["parries"]) >= 1, "The parry should be counted.")
	check(game.achievements.has("petal_step"), "Petal Step should unlock.")
	await frames(30)

	# ---- Blighted Depths
	game.victory = true
	game.depths.descend()
	check(game.depths.active and game.depths.wave == 1, "Descend should start wave 1.")
	check(game.depths._targets.size() == 5, "Wave 1 should summon five monsters (got %d)." % game.depths._targets.size())
	var coins_wave: int = player.petalcoins
	game.on_depths_wave_cleared(1)
	check(player.petalcoins > coins_wave, "Cleared waves should pay Petalcoins.")
	game.depths.wave = 3
	game.depths._next_wave()
	check(game.depths.wave == 4 and game.depths._boss != null, "Wave 4 should summon a guardian echo.")
	check(String(game.depths._boss.boss_id).begins_with("echo_"), "The guardian echo should carry the echo id.")
	var seeds_before: int = game.moonseeds.size()
	var bosses_before: int = game.defeated_bosses.size()
	game.depths._boss._defeat()
	check(game.moonseeds.size() == seeds_before and game.defeated_bosses.size() == bosses_before, "Echoes should not drop Moonseeds.")
	game.depths.ascend(true)
	check(not game.depths.active, "Ascending should end the Depths.")

	# ---- moth companion
	if is_instance_valid(game.companion):
		game.companion.queue_free()
		game.companion = null
	game.moth_active = false
	game._spawn_companion()
	check(game.moth_active and is_instance_valid(game.companion), "The moth should join Mallow.")
	check(bool(game.flags.get("moth", false)), "The moth should be flagged in the save.")
	check(game.achievements.has("tiny_guide"), "Tiny Guide should unlock.")

	# ---- feats overlay & photo mode
	game.hud.toggle_inventory()
	check(game.hud.inventory_overlay.visible and paused, "Satchel should open and pause.")
	game.hud.toggle_inventory()
	game.hud.toggle_feats()
	check(game.hud.feats_overlay.visible and paused, "Feats overlay should open and pause.")
	game.hud.toggle_feats()
	check(not paused, "Closing overlays should unpause.")
	game.hud.toggle_photo_mode()
	check(game.hud.photo_active and paused, "Photo mode should pause the world.")
	game.hud._photo_zoom(1.2)
	check(absf(game.camera.zoom.x - 1.8) < 0.01, "Photo zoom should adjust the camera (got %.2f)." % game.camera.zoom.x)
	game.hud.toggle_photo_mode()
	check(not game.hud.photo_active and not paused, "Exiting photo mode should restore play.")
	check(absf(game.camera.zoom.x - game.CAMERA_ZOOM) < 0.001, "Camera zoom should be restored after photo mode.")

	# ---- save / load round-trip
	check(game.save_game() and Save.exists(), "Saving should write the save file.")
	game.achievements.clear()
	if is_instance_valid(game.companion):
		game.companion.queue_free()
		game.companion = null
	game.moth_active = false
	check(game.load_game(), "Loading should read the save file.")
	check(game.achievements.has("first_cast"), "Feats should persist through save/load.")
	check(game.moth_active and is_instance_valid(game.companion), "The moth should persist through save/load.")

	Save.erase()
	if failures.size() > 0:
		push_error("%d content checks failed." % failures.size())
		quit(1)
		return
	print("Starfall content smoke test passed: seventh biome, fishing, moonpetals and wisps, perfect parry, Blighted Depths, moth companion, feats and photo mode, save/load all work.")
	game.get("audio").call("stop_all")
	game.queue_free()
	await process_frame
	quit(0)
