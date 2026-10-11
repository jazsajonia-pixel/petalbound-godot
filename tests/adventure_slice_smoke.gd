extends SceneTree

func _initialize() -> void:
	call_deferred("_run_test")

func _run_test() -> void:
	var packed_scene := load("res://scenes/main.tscn") as PackedScene
	if packed_scene == null:
		push_error("Could not load the main scene.")
		quit(1)
		return
	var game := packed_scene.instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame

	var player := game.get("player") as CharacterBody2D
	var hud := game.get("hud") as Control
	if player == null or hud == null:
		push_error("Could not find the player or HUD in the main scene.")
		quit(1)
		return

	var all_passed := true
	var start_button := hud.get("title_button") as Button
	var title_overlay := hud.get("title_overlay") as ColorRect
	var menu_ready: bool = start_button != null and title_overlay != null and title_overlay.visible and paused
	if not menu_ready:
		push_error("The new title menu did not open in a paused state.")
		all_passed = false
	if start_button != null:
		start_button.pressed.emit()
	await process_frame
	await physics_frame
	if paused or not bool(game.get("game_started")):
		push_error("The Begin Journey button did not start play and unpause the scene.")
		all_passed = false

	var ground := game.get("ground_layer") as TileMapLayer
	var terrain_ok := ground != null and ground.get_used_cells().size() > 6000
	var water: Array = game.get("water_cells")
	var enemies: Array = game.get("enemies")
	var world_ok := terrain_ok and water.size() > 30 and enemies.size() == 6
	if not world_ok:
		push_error("The tiled meadow, animated pond data, or six-enemy encounter did not initialize as expected.")
		all_passed = false
	var icon_paths := [
		"res://assets/packs/rpg_inventory_icons/selected/thornblade.png",
		"res://assets/packs/rpg_inventory_icons/selected/bloomstaff.png",
		"res://assets/packs/rpg_inventory_icons/selected/moonheart_charm.png",
		"res://assets/packs/rpg_inventory_icons/selected/moontea.png",
		"res://assets/packs/rpg_inventory_icons/selected/plum_cloak.png"
	]
	var icons_ok := true
	for icon_path in icon_paths:
		if not ResourceLoader.exists(icon_path):
			icons_ok = false
	if not icons_ok:
		push_error("One or more selected CC0 field-kit icons are missing from the project.")
		all_passed = false

	player.global_position = Vector2(130, 150)
	var cloak_speed: float = player.call("get_move_speed")
	if not bool(player.get("cloak_equipped")) or absf(cloak_speed - 183.6) > 0.02:
		push_error("The starting Plum Wayfarer cloak did not grant its 8% movement bonus.")
		all_passed = false
	player.facing = Vector2.RIGHT
	player.weapon_index = 0
	var enemy_before: Node2D = enemies[0]
	enemy_before.global_position = player.global_position + Vector2(48, 0)
	enemy_before.health = 1
	game.call("_try_player_attack")
	var after_attack: Array = game.get("enemies")
	var blade_ok := after_attack.size() == 5 and int(player.get("petalcoins")) >= 3
	if not blade_ok:
		push_error("Thornblade did not defeat a nearby target and award Petalcoins.")
		all_passed = false

	player.call("cycle_weapon")
	var staff_target: Node2D = after_attack[0]
	staff_target.global_position = player.global_position + Vector2(120, 0)
	staff_target.health = 2
	game.call("_cast_mothlight")
	var after_skill: Array = game.get("enemies")
	var staff_and_skill_ok: bool = str(player.call("get_weapon_name")) == "BLOOMSTAFF" and after_skill.size() == 4 and float(player.get("mothlight_cooldown")) > 0.0
	if not staff_and_skill_ok:
		push_error("Weapon cycling or Mothlight's ranged hit/cooldown did not work.")
		all_passed = false
	var combo_target: Node2D = after_skill[0]
	combo_target.global_position = player.global_position + Vector2(54, 0)
	combo_target.health = 4
	player.weapon_index = 0
	player.attack_combo = -1
	player.combo_timer = 0.0
	var combo_damage_ok := true
	for expected_health in [3, 2, 0]:
		player.attack_cooldown = 0.0
		game.call("_try_player_attack")
		if int(combo_target.get("health")) != expected_health:
			combo_damage_ok = false
	if not combo_damage_ok:
		push_error("The three-swing Thornblade chain did not end with its heavier finisher.")
		all_passed = false

	player.health = 3
	var tea_ok: bool = player.call("drink_moontea") and player.health == 4 and int(player.get("moontea_charges")) == 2
	if not tea_ok:
		push_error("Moontea did not consume a charge and restore one heart.")
		all_passed = false
	var charm_ok: bool = player.call("equip_moonheart_charm") and player.max_health == 6 and player.health == 5
	if not charm_ok:
		push_error("Moonheart Charm did not increase the maximum heart count.")
		all_passed = false
	var guard_started: bool = player.call("activate_petalguard")
	var health_before_guard: int = player.health
	var guard_hit_damage: bool = player.call("take_damage")
	var guard_ok: bool = guard_started and not guard_hit_damage and player.health == health_before_guard and not bool(player.get("guard_active"))
	if not guard_ok:
		push_error("Petalguard did not absorb one hit without heart loss.")
		all_passed = false

	player.charm_equipped = false
	player.max_health = 5
	player.health = 5
	player.global_position = Vector2(635, 395)
	var cache_opened_now: bool = game.call("_open_cache")
	var cache_ok := cache_opened_now and bool(game.get("cache_opened")) and bool(player.get("charm_equipped"))
	if not cache_ok:
		push_error("The nearby Moonheart cache did not respond to the contextual interact action.")
		all_passed = false

	var defeat_target: Node2D = game.get("enemies")[0]
	player.global_position = Vector2(130, 150)
	player.health = 1
	player.invulnerable_left = 0.0
	player.dash_left = 0.0
	player.guard_active = false
	defeat_target.global_position = player.global_position + Vector2(24, 0)
	defeat_target.attack_cooldown = 0.0
	game.call("_update_enemies", 0.02)
	game.call("_check_player_state")
	var defeat_menu: bool = player.health == 0 and not bool(game.get("game_started")) and title_overlay.visible and paused
	if not defeat_menu:
		push_error("Defeat did not show the retry menu and pause the game.")
		all_passed = false
	start_button.pressed.emit()
	await process_frame
	await physics_frame
	var retry_ok: bool = not paused and bool(game.get("game_started")) and player.health == 5 and game.get("enemies").size() == 6 and int(game.get("seed_count")) == 0 and str(player.call("get_weapon_name")) == "THORNBLADE" and not bool(player.get("charm_equipped")) and bool(player.get("cloak_equipped")) and int(player.get("moontea_charges")) == 3 and int(player.get("petalcoins")) == 0 and float(player.get("mothlight_cooldown")) == 0.0 and float(player.get("guard_cooldown")) == 0.0 and not bool(player.get("guard_active")) and int(player.get("attack_combo")) == -1 and float(player.get("combo_timer")) == 0.0
	if not retry_ok:
		push_error("Retry did not restore the full starting health, gear, resources, cooldowns, encounter, and menu state.")
		all_passed = false

	game.set("seed_taken", [true, true, true])
	game.set("seed_count", 3)
	player.global_position = Vector2(1660, 545)
	game.call("_handle_collectibles")
	var victory_ok: bool = bool(game.get("won")) and title_overlay.visible and paused
	if not victory_ok:
		push_error("Gathering all three Moonseeds and reaching the shrine did not produce the victory screen.")
		all_passed = false

	if not all_passed:
		quit(1)
		return
	print("Adventure-slice smoke test passed: menu/start, tiled world, assets, cloak bonus, combo finisher, Mothlight, weapons, Moontea, charm/guard, cache interaction, defeat/retry, and shrine victory.")
	quit(0)
