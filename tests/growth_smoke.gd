extends SceneTree
## Headless smoke test for the Petal Arts update: attack target-snapping and
## softer knockback, XP levels, class binding/combining/trees, arts casting,
## journeys (quests), Kaede's shop, enterable houses, the Hollow Crypt, the
## arts/journeys overlays and skill bar, plus save/load round-trip.

const Save := preload("res://scripts/systems/save.gd")

var game: Node
var player: CharacterBody2D
var failures: PackedStringArray = []


func _initialize() -> void:
	call_deferred("_run_test")


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)
		push_error(msg)


func frames(n: int) -> void:
	for i in range(n):
		await physics_frame


func release_all() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down", "sprint", "dash", "jump", "attack", "interact"]:
		Input.action_release(a)


## Stand at a door until the ENTER prompt wins over any NPC standing nearby.
func door_prompt(h: Dictionary) -> bool:
	for off in [Vector2(0, 0), Vector2(0, 10), Vector2(0, -10), Vector2(8, 0), Vector2(-8, 0)]:
		player.global_position = h["door"] + off
		player.velocity = Vector2.ZERO
		player.state = player.State.MOVE
		await frames(2)
		game._update_interactables()
		if game._interact_target.get("type", "") == "door":
			return true
	return false


func _run_test() -> void:
	Save.path_override = "user://petalbound_growth_test_save.json"
	Save.erase()
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	game.hud.title_button.pressed.emit()
	await process_frame
	await physics_frame
	player = game.player
	release_all()
	check(game.game_started, "New Journey should start the game.")

	# ---- combat: target snap + range hint + softer knockback
	var foe: Node = null
	for e in game.enemies:
		if e.alive:
			foe = e
			break
	check(foe != null, "An enemy should be available for the combat checks.")
	if foe != null:
		foe.set_physics_process(false)
		player.global_position = foe.global_position + Vector2(-28.0, -4.0)
		player.velocity = Vector2.ZERO
		player.state = player.State.MOVE
		player._set_facing(Vector2.DOWN)
		await frames(2)
		check(player.range_hint.visible, "The basic-attack range hint should show with an enemy in reach.")
		player._attack_blade()
		check(player.facing.x > 0.9, "Basic attack should snap toward the closest enemy (facing %s)." % player.facing)
		check(foe.knock.length() <= 120.0, "Blade knockback should be soft (got %.0f)." % foe.knock.length())
		await frames(4)
		player.state = player.State.MOVE

	# ---- XP, levels and the Petal Arts
	var level0: int = player.level
	player.add_xp(2000)
	check(player.level > level0 and player.level >= 5, "XP should raise the level past the combine gate (got %d)." % player.level)
	check(player.skill_points >= 10, "Levels should grant art points (got %d)." % player.skill_points)
	check(player.bind_class("warden"), "Binding the Warden line should work.")
	check(player.classes.has("warden") and player.skill_bar.size() == 2, "Warden arts should fill the skill bar.")
	check(player.bind_class("nightbloom"), "Combining a second line at level %d should work." % player.level)
	check(player.classes.size() == 2 and player.skill_bar.size() == 4, "Two lines should fill all four art slots.")
	check(not player.bind_class("lumimancer"), "A third line should be refused.")
	check(player.spend_node("warden", "oakheart"), "Spending a point on Oakheart should work.")
	check(player.spend_node("warden", "ironbark"), "Ironbark should unlock after Oakheart.")
	check(not player.spend_node("warden", "not_a_node"), "Unknown nodes should be refused.")
	check(player.spend_node("nightbloom", "nightveil"), "Nightveil should unlock the Nightbloom branch.")
	check(player.spend_node("nightbloom", "deep_cut"), "Deep Cut should be purchasable.")
	check(player.attack_bonus() >= 2, "Tree nodes and the dual-line synergy should add attack damage (got %d)." % player.attack_bonus())
	var focus0: float = player.focus
	player.state = player.State.MOVE
	player.cast_slot(0)
	check(player.focus < focus0, "Casting an art should spend focus (%.0f -> %.0f)." % [focus0, player.focus])
	check(float(player.skill_cd.get("bulwark", 0.0)) > 0.0, "Casting should start the art cooldown.")
	var focus1: float = player.focus
	player.cast_slot(1)
	check(player.focus < focus1, "The second art should also spend focus.")

	# ---- journeys (quests)
	game._quest_on_talk("alder")
	check(int(game.quests["q_thorns"]["s"]) == 1, "Talking to Alder should begin A Thicker Thicket.")
	for i in range(8):
		game._quest_progress("kills")
	check(int(game.quests["q_thorns"]["s"]) == 2, "Eight kills should finish the quest (state %d)." % int(game.quests["q_thorns"]["s"]))
	var coins0: int = player.petalcoins
	game._quest_on_talk("alder")
	check(int(game.quests["q_thorns"]["s"]) == 3, "Talking again should claim the reward.")
	check(player.petalcoins > coins0, "Claiming should pay Petalcoins.")
	game._quest_on_talk("kit")
	game._quest_on_talk("hana")
	check(int(game.quests["q_locket"]["s"]) == 2, "Kit's quest should complete after talking to Hana.")

	# ---- Kaede's shop
	game.shop_id = "kaede"
	var stock: Array = game._shop_stock()
	var dusk: Dictionary = {}
	for entry in stock:
		if entry["id"] == "duskfan":
			dusk = entry
	check(not dusk.is_empty(), "Kaede should stock the Duskfan.")
	player.petalcoins += 300
	if not dusk.is_empty():
		game.buy_item(dusk)
		check(player.weapons_owned.has("duskfan"), "Buying the Duskfan should add it to the armoury.")

	# ---- gathering, refining and gear tiers
	game.gather_material("wood", 3)
	game.gather_material("ore", 6)
	game.gather_material("herb", 2)
	check(game.craft_next_upgrade(), "Three wood and ore should craft the Tier II Thornblade.")
	check(player.weapons_owned.has("thornblade_ii"), "The crafted weapon tier should be added to the armoury.")
	check(game.materials["wood"] == 0 and game.materials["ore"] == 3, "Crafting should consume the recipe materials.")
	check(game.craft_next_upgrade(), "Remaining ore and herbs should craft reinforced Tier II Briar Mail.")
	check(player.inventory.has("briar_mail_ii"), "The crafted armor tier should enter the satchel.")

	# ---- enterable houses
	var mira: Dictionary = game._house("house_mira")
	check(await door_prompt(mira), "A house door should offer ENTER.")
	game._interact()
	check(game.current_interior.get("id", "") == "house_mira", "Mallow should step inside Mira's Cottage.")
	check(player.global_position.distance_to(mira["center"]) < 120.0, "The interior should hold Mallow (dist %.0f)." % player.global_position.distance_to(mira["center"]))
	await frames(4)
	game._update_interactables()
	check(game._interact_target.get("type", "") == "door", "The inside doormat should offer LEAVE.")
	game._interact()
	check(game.current_interior.is_empty(), "Mallow should be back outside.")
	check(player.global_position.distance_to(mira["door"]) < 40.0, "Leaving should return Mallow to the door.")

	# ---- the Hollow Crypt
	var crypt: Dictionary = game._house("crypt")
	check(await door_prompt(crypt), "The crypt door should offer ENTER.")
	game._interact()
	check(game.current_interior.get("id", "") == "crypt", "Mallow should enter the Hollow Crypt.")
	check(game.crypt_enemies.size() == 6, "The crypt should hold six enemies (got %d)." % game.crypt_enemies.size())
	check(is_instance_valid(game.crypt_boss), "The Hollow Revenant should be waiting.")
	await frames(6)
	var seeds0: int = game.moonseeds.size()
	var bosses0: int = game.defeated_bosses.size()
	game.crypt_boss.awake = true
	game.crypt_boss._defeat()
	check(bool(game.flags.get("crypt_cleared", false)), "The crypt should be flagged cleared.")
	check(player.inventory.has("moonveil_ring"), "The Revenant should drop the Moonveil Ring.")
	check(game.moonseeds.size() == seeds0 and game.defeated_bosses.size() == bosses0, "Dungeon bosses should not drop Moonseeds.")
	await frames(4)
	player.global_position = (crypt["_in_door"] as Vector2) + Vector2(0, -6.0)
	player.velocity = Vector2.ZERO
	await frames(2)
	game._update_interactables()
	check(game._interact_target.get("type", "") == "door", "The way out should open after the fight.")
	game._interact()
	check(game.current_interior.is_empty(), "Mallow should leave the crypt.")
	check(game.crypt_enemies.is_empty() and game.crypt_boss == null, "Leaving should clear the crypt.")

	# ---- arts overlay, journeys overlay, skill bar
	game.hud.toggle_arts()
	check(game.hud.arts_overlay.visible and paused, "The arts overlay should open and pause.")
	game.hud.toggle_arts()
	game.hud.toggle_journeys()
	check(game.hud.journeys_overlay.visible and paused, "The journeys overlay should open and pause.")
	game.hud.toggle_journeys()
	check(not paused, "Closing overlays should unpause.")
	game.hud._refresh_skill_bar()
	check(game.hud.skill_slots.size() == 4, "The skill bar should have four slots.")
	var slot_visible: int = 0
	for s in game.hud.skill_slots:
		if s["panel"].visible:
			slot_visible += 1
	check(slot_visible == 4, "All four bound arts should show on the skill bar (got %d)." % slot_visible)

	# ---- save / load round-trip of the growth state
	check(game.save_game() and Save.exists(), "Saving should write the save file.")
	player.classes.clear()
	player.class_nodes.clear()
	game.quests.clear()
	check(game.load_game(), "Loading should read the save file.")
	check(player.classes.has("warden") and player.classes.has("nightbloom"), "Bound lines should persist.")
	check((player.class_nodes.get("warden", {}) as Dictionary).has("oakheart"), "Tree nodes should persist.")
	check(int(game.quests["q_thorns"]["s"]) == 3, "Quest states should persist.")

	Save.erase()
	if failures.size() > 0:
		push_error("%d growth checks failed." % failures.size())
		quit(1)
		return
	print("Petal Arts growth smoke test passed: target snap, soft knockback, levels, classes and trees, arts, journeys, shop, gathering/crafting tiers, houses and the Hollow Crypt, overlays and skill bar, save/load all work.")
	game.get("audio").call("stop_all")
	game.free()
	quit(0)
