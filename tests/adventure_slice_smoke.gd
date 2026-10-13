extends SceneTree
## End-to-end smoke test of the open-world loop: world build, movement kit, combat,
## loot, chests and gear, NPC dialogue, bosses and Moonseeds, the Moonwell ending,
## death/respawn at a waystone, and save/load.

const Save := preload("res://scripts/systems/save.gd")

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


func isolate() -> void:
	# park every creature far away so movement checks are deterministic
	for e in game.enemies:
		e.set_physics_process(false)
	game._activation_t = 999.0


func _run_test() -> void:
	Save.path_override = "user://petalbound_test_save.json"
	Save.erase()
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	check(not game.game_started and game.hud.title_overlay.visible, "Title screen should be shown on boot.")
	check(not game.hud.continue_button.visible, "Continue should be hidden without a save.")
	game.hud.title_button.pressed.emit()
	game.hud.call("confirm_character")
	await process_frame
	await physics_frame
	player = game.player
	# new journeys start bare-pawed; this slice exercises the classic loadout
	check(player.is_unarmed() and player.weapons_owned == ["fists"], "A new journey should start unarmed (fists only).")
	player.give_item("thornblade")
	player.give_item("bloomstaff")
	player._set_weapon_index(player.weapons_owned.find("thornblade"))
	check(game.game_started and not game.hud.title_overlay.visible, "New Journey should start the game.")

	# ---- world
	check(game.world.prop_count > 1500, "World should place over 1500 props (got %d)." % game.world.prop_count)
	check(game.enemies.size() > 60, "World should spawn dozens of monsters.")
	var seed_keepers: Array = game.bosses.filter(func(b): return not game.is_side_boss(b))
	check(seed_keepers.size() == 4, "Four Moonseed guardians expected (got %d)." % seed_keepers.size())
	check(game.bosses.size() == 5, "Four guardians plus the Emberbark expected.")
	check(game.npcs.size() >= 8, "Hearthgrove and the roads should have villagers.")
	check(game.waystones.size() == 8, "Eight waystones expected (including Moonpetal, Starfall and Cinderbrook).")
	var lumen_found := false
	for n in game.npcs:
		if n.npc_id == "lumen":
			lumen_found = true
	check(lumen_found, "Lumen the Stargazer should live in Starfall Rise.")
	var biomes := {}
	for p in [Vector2(1248, 1888), Vector2(640, 640), Vector2(3424, 1850), Vector2(3100, 700), Vector2(2700, 2300), Vector2(4600, 1460)]:
		biomes[game.world.biome_at(p)] = true
	check(biomes.size() >= 4, "Expected several distinct biomes across the map.")
	check(game.world.is_water(Vector2(1888, 1536)) or game.world.is_water(Vector2(1860, 1560)), "Lake Lumen should be water.")
	check(game.world.biome_at(Vector2(4600, 1460)) == 6, "Starfall Rise should be the seventh biome.")
	check(game.world.region_name(Vector2(4600, 1460)) == "Starfall Rise", "The eastern rise should be named Starfall Rise.")
	check(game.world.biome_at(Vector2(320 * 16, 88 * 16)) == 7, "Moonpetal Hollow should be the eighth biome.")
	check(game.world.region_name(Vector2(320 * 16, 88 * 16)) == "Moonpetal Hollow", "The far eastern grove should have a distinct region name.")
	check(game.world.is_water(Vector2(276 * 16 + 8, 58 * 16 + 8)), "Mirror Basin should be water.")

	# ---- movement kit
	isolate()
	var open_spot := Vector2(1500, 1400)
	game.world.solids.collision_layer = 0
	game.world.low_solids.collision_layer = 0
	player.global_position = open_spot
	release_all()
	await frames(2)
	Input.action_press("move_right")
	await frames(30)
	var walk_dist: float = player.global_position.x - open_spot.x
	release_all()
	await frames(20)
	player.global_position = open_spot
	player.stamina = 100.0
	Input.action_press("move_right")
	Input.action_press("sprint")
	await frames(30)
	var sprint_dist: float = player.global_position.x - open_spot.x
	release_all()
	check(walk_dist > 20.0, "Walking should move Mallow (moved %.1f)." % walk_dist)
	check(sprint_dist > walk_dist * 1.25, "Sprinting should be faster than walking (%.1f vs %.1f)." % [sprint_dist, walk_dist])
	check(player.stamina < 100.0, "Sprinting should spend stamina.")
	await frames(30)
	player.stamina = 100.0
	check(player.start_roll(Vector2.LEFT), "Roll should start.")
	check(player.invulnerable_left > 0.0, "Roll should grant invulnerability frames.")
	var hp_before: int = player.health
	player.take_damage(4, player.global_position + Vector2(10, 0))
	check(player.health == hp_before, "Damage during a roll should be ignored.")
	await frames(30)
	check(player.state == player.State.MOVE, "Roll should end back in the move state.")
	player.stamina = 100.0
	check(player.start_jump(), "Jump should start.")
	check(player.airborne and (player.collision_mask & 4) == 0, "Jumping should hop over low props (mask cleared).")
	await frames(40)
	check(not player.airborne and (player.collision_mask & 4) != 0, "Jump should land and restore low-prop collision.")
	player.global_position = Vector2(1888, 1600)
	for y in range(1500, 1700, 8):
		if game.world.is_water(Vector2(1888, y)):
			player.global_position = Vector2(1888, y)
			break
	await frames(3)
	check(player.swimming, "Mallow should swim in deep water.")
	player.global_position = open_spot
	await frames(3)
	check(not player.swimming, "Mallow should stop swimming on land.")
	game.world.solids.collision_layer = 1
	game.world.low_solids.collision_layer = 4

	# ---- combat & loot
	player.invulnerable_left = 0.0
	player.health = player.max_health
	var e: Node = game.enemies[0]
	e.global_position = player.global_position + Vector2(14, 0)
	e.set_physics_process(false)
	player.facing = Vector2.RIGHT
	player.dir_name = "right"
	var coins_before: int = player.petalcoins
	var swings := 0
	while e.alive and swings < 12:
		player.state = player.State.MOVE
		player.attack_cooldown = 0.0
		player.combo_timer = 0.5
		player.try_attack()
		swings += 1
		await frames(4)
	check(not e.alive, "Thornblade combo should defeat a field monster.")
	check(game.pickups.size() > 0, "Defeated monsters should drop Petalcoins.")
	for pk in game.pickups:
		pk["node"].global_position = player.global_position
		pk["t"] = 1.0
	await frames(4)
	check(player.petalcoins > coins_before, "Walking over coins should collect them.")
	player.cycle_weapon()
	check(player.get_weapon_name() == "BLOOMSTAFF", "Weapon swap should select the Bloomstaff.")
	var shots_before: int = game.projectiles.get_child_count()
	player.attack_cooldown = 0.0
	player.state = player.State.MOVE
	player.try_attack()
	check(game.projectiles.get_child_count() > shots_before, "Bloomstaff should fire a bolt.")
	player.cycle_weapon()
	check(player.activate_mothlight(), "Mothlight should cast.")
	check(not player.activate_mothlight(), "Mothlight should respect its cooldown.")
	check(player.activate_petalguard(), "Petalguard should activate.")
	player.invulnerable_left = 0.0
	hp_before = player.health
	player.take_damage(2)
	check(player.health == hp_before and not player.guard_active, "Petalguard should absorb one hit.")
	await frames(30)
	player.invulnerable_left = 0.0
	player.take_damage(4)
	check(player.health == hp_before - 4, "Damage should remove a full heart.")
	var tea_before: int = player.moontea_charges
	check(player.drink_moontea() and player.moontea_charges == tea_before - 1, "Moontea should heal and use a charge.")

	# ---- chest & gear
	var charm_chest: Dictionary = {}
	for c in game.chests:
		if c["item"] == "moonheart_charm":
			charm_chest = c
	var max_before: int = player.max_health
	player.global_position = charm_chest["pos"] + Vector2(0, 14)
	await frames(2)
	game._update_interactables()
	check(game._interact_target.get("type", "") == "chest", "Standing by a chest should offer OPEN.")
	game._interact()
	check(charm_chest["open"], "Interacting should open the chest.")
	check(player.charm_equipped and player.max_health == max_before + 4, "Moonheart Charm should auto-equip and add a heart.")
	await frames(110)
	player.give_item("briar_mail")
	check(player.equipped.get("armor", "") == "briar_mail", "Briar Mail should equip into the armor slot.")
	player.give_item("gale_bow")
	check(player.weapons_owned.has("gale_bow"), "Gale Bow should join the weapon wheel.")

	# ---- dialogue
	var alder: Node = game.npcs[0]
	player.global_position = alder.global_position + Vector2(0, 16)
	await frames(2)
	game._update_interactables()
	game._interact()
	check(game.hud.dialogue_open, "Talking to Elder Alder should open dialogue.")
	for i in range(8):
		game.hud.advance_dialogue()
		game.hud.advance_dialogue()
	check(not game.hud.dialogue_open, "Dialogue should close after the last line.")

	# ---- bosses, seeds, ending
	var boss: Node = game.bosses[0]
	player.global_position = boss.home + Vector2(0, 80)
	player.invulnerable_left = 99.0
	await frames(4)
	check(boss.awake and game.active_boss == boss, "Approaching a guardian should wake it.")
	check(game.hud.boss_panel.visible, "Boss bar should be visible during a guardian fight.")
	boss.hurt(boss.max_hp / 2 + 1, player.global_position, 0.0)
	check(boss.enraged, "Guardian should enrage below half health.")
	boss.hurt(boss.max_hp, player.global_position, 0.0)
	check(boss.defeated and game.active_boss == null, "Guardian should be defeated.")
	await frames(2)
	var seed_found := false
	for pk in game.pickups:
		if pk["kind"] == "moonseed":
			seed_found = true
			pk["node"].global_position = player.global_position
			pk["t"] = 1.0
	check(seed_found, "Guardian should drop a Moonseed.")
	await frames(3)
	check(game.moonseeds.size() == 1, "Collecting the Moonseed should count it (got %d)." % game.moonseeds.size())
	await frames(120)
	game.moonseeds = ["briarback", "toad", "cyclops", "warden"]
	player.global_position = game.moonwell.global_position + Vector2(0, 24)
	await frames(2)
	game._update_interactables()
	check(game._interact_target.get("type", "") == "moonwell", "Moonwell should be interactable.")
	game._interact()
	check(game.victory, "Returning four Moonseeds should restore the Moonwell.")
	await create_timer(3.5).timeout
	check(game.hud.end_overlay.visible, "Victory screen should appear.")
	check(game.environment.blight < 0.05, "The blight should lift after the ending.")
	game.hud.end_button.pressed.emit()
	await frames(2)

	# ---- save / load
	var coins_saved: int = player.petalcoins
	check(game.save_game() and Save.exists(), "Saving should write the save file.")
	player.petalcoins = 0
	game._reset_state()
	check(game.load_game(), "Loading should read the save file.")
	check(player.petalcoins == coins_saved and game.victory and charm_chest["open"], "Loaded state should match the saved journey.")

	# ---- death & respawn
	game.victory = false
	player.invulnerable_left = 0.0
	player.guard_active = false
	player.take_damage(999)
	check(player.state == player.State.DEAD and game.game_over, "Lethal damage should down Mallow.")
	await create_timer(1.5).timeout
	check(game.hud.end_overlay.visible, "Game-over screen should appear.")
	game.hud.end_button.pressed.emit()
	await frames(2)
	var ws: Dictionary = game._waystone(game.last_waystone)
	check(player.state == player.State.MOVE and player.health == player.max_health, "Rising again should fully revive Mallow.")
	check(player.global_position.distance_to(ws["pos"]) < 40.0, "Mallow should respawn at the last waystone.")

	Save.erase()
	if failures.size() > 0:
		push_error("%d adventure checks failed." % failures.size())
		quit(1)
		return
	print("Open-world adventure smoke test passed: world, movement kit, combat, loot, gear, dialogue, guardians, Moonwell ending, save/load and respawn all work.")
	game.get("audio").call("stop_all")
	game.queue_free()
	await process_frame
	quit(0)
