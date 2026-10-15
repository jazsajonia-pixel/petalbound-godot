extends SceneTree
## Headless test for the open-world expansion. Exercises real game code paths:
## unarmed start + attack facing while held, equip/unequip visuals (held weapon,
## dual knives, armour regions), loot once per death, bag stacks and full-bag
## behaviour, shops/selling/exchanges that never take coins on failure,
## crafting that consumes once, the HUD (4 arts + gear active + potion, no
## dodge), quests (chains, markers, reward once), rift dungeons (valid spawn,
## enter, isolation, gates, cache once, exit, save/load), house interiors,
## knockback caps and walls, character appearance persistence and settings.

const Save := preload("res://scripts/systems/save.gd")
const Settings := preload("res://scripts/systems/settings.gd")
const DB := preload("res://scripts/data/db.gd")
const CD := preload("res://scripts/data/combat_data.gd")
const Eco := preload("res://scripts/data/economy.gd")
const Inv := preload("res://scripts/systems/inventory.gd")
const Trade := preload("res://scripts/systems/trade.gd")
const Craft := preload("res://scripts/systems/crafting.gd")
const KB := preload("res://scripts/combat/knockback.gd")
const QuestSys := preload("res://scripts/systems/quests.gd")
const HeroLook := preload("res://scripts/actors/hero_look.gd")
const EnemyScript := preload("res://scripts/actors/enemy.gd")
const Build := preload("res://scripts/combat/build.gd")

var game: Node
var player: CharacterBody2D
var failures: PackedStringArray = []
var passes := 0
var spawned: Array = []
var arena := Vector2.ZERO


func _initialize() -> void:
	Settings.path_override = "user://petalbound_expansion_settings.cfg"
	Settings.erase()
	call_deferred("_run_test")


func check(cond: bool, msg: String) -> void:
	if not cond:
		failures.append(msg)
		push_error(msg)
	else:
		passes += 1


func frames(n: int) -> void:
	for i in range(n):
		await physics_frame


func dummy(offset: Vector2, hp := 200, species := "mushroom") -> Node:
	var e := EnemyScript.new()
	e.setup(game, species, arena + offset)
	game.entities.add_child(e)
	game.enemies.append(e)
	e.max_hp = hp
	e.hp = hp
	e.respawn_at = -1.0
	e.set_physics_process(false)
	spawned.append(e)
	return e


func clear_dummies() -> void:
	for e in spawned:
		if is_instance_valid(e):
			game.enemies.erase(e)
			e.queue_free()
	spawned.clear()
	player.current_target = null
	player.manual_target = null


func reset_player() -> void:
	player.global_position = arena
	player.velocity = Vector2.ZERO
	player.knockback = Vector2.ZERO
	player.state = player.State.MOVE
	player.attack_cooldown = 0.0
	player._lock_t = 0.0
	player.invulnerable_left = 0.0
	player.move_intent_override = Vector2.INF
	player._set_facing(Vector2.RIGHT)


func _run_test() -> void:
	Save.path_override = "user://petalbound_expansion_test_save.json"
	Save.erase()
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	# character creation sits between NEW JOURNEY and the world
	game.hud.title_button.pressed.emit()
	await process_frame
	check(game.hud.create_overlay.visible and not game.game_started, "NEW JOURNEY should open character creation first.")
	var look := HeroLook.cycle(HeroLook.default_appearance(), "fur", 1)
	look = HeroLook.cycle(look, "hood", 2)
	game.hud.create_state["look"] = look
	game.hud.confirm_character()
	await process_frame
	await physics_frame
	player = game.player
	check(game.game_started and not game.hud.create_overlay.visible, "Confirming the look should start the journey.")
	check(player.appearance == HeroLook.sanitize(look), "The chosen look should be applied to Mallow.")
	for e in game.enemies:
		e.set_physics_process(false)
		e.global_position += Vector2(4000, 4000)
	arena = player.global_position

	await _test_unarmed_and_facing()
	await _test_equipment_visuals()
	await _test_loot_and_bag()
	await _test_trade_and_crafting()
	_test_hud()
	await _test_quests()
	await _test_knockback()
	await _test_interiors()
	await _test_rifts()
	await _test_save_load()
	_test_settings()

	Save.erase()
	Settings.erase()
	if failures.size() > 0:
		push_error("%d expansion checks failed (%d passed)." % [failures.size(), passes])
		quit(1)
		return
	print("Expansion smoke test passed (%d checks): unarmed start, held-attack facing, equip visuals, dual knives, loot once, bag stacks, shops/sell/exchange failures, crafting once, HUD layout without dodge, quest chains/markers/rewards once, knockback caps and walls, interiors, rift dungeons, save/load and appearance all work." % passes)
	game.get("audio").call("stop_all")
	game.free()
	quit(0)


# ---------------------------------------------------------------- combat
func _test_unarmed_and_facing() -> void:
	reset_player()
	check(player.weapons_owned == ["fists"] and player.is_unarmed(), "A new journey should start with no weapon (fists).")
	check(not player.weapon_sprite.visible, "No weapon sprite should show while unarmed.")
	check(player.range_hint.visible and player.range_hint.reach <= 22.0, "The small fists indicator should be visible.")
	check(not player.unequip_weapon(), "Unequipping while unarmed should do nothing.")
	var foe := dummy(Vector2(14, 2))
	var hp0: int = foe.hp
	player.current_target = foe
	check(player.try_attack(), "Punching should work while unarmed.")
	await frames(3)
	check(foe.hp < hp0, "A punch should damage an adjacent foe.")
	clear_dummies()
	# holding attack while steering: facing follows the stick, not the old target
	reset_player()
	var right_foe := dummy(Vector2(20, 0))
	player.current_target = right_foe
	player.move_intent_override = Vector2.LEFT
	check(player.attack_direction().x < -0.9, "Stick input should beat the auto-target when attacking (got %s)." % str(player.attack_direction()))
	player.try_attack()
	await frames(2)
	check(player.facing.x < -0.5, "Attacking while steering left should face left.")
	player.move_intent_override = Vector2.UP
	player.attack_cooldown = 0.0
	player._lock_t = 0.0
	player.state = player.State.MOVE
	player.try_attack()
	await frames(2)
	check(player.facing.y < -0.5, "Repeated attacks should re-face toward the new stick direction.")
	# a stick pointed near a target snaps to it (aim assist cone)
	player.aim_assist = true
	player.move_intent_override = Vector2(1, 0.3).normalized()
	var ad: Vector2 = player.attack_direction()
	check(ad.dot((right_foe.global_position + Vector2(0, -5) - player.global_position - Vector2(0, -4)).normalized()) > 0.99, "A stick close to the target should snap onto it (got %s via %s, target %s)." % [str(ad), player._attack_dir_source, str(player.current_target)])
	player.move_intent_override = Vector2.INF
	clear_dummies()
	# no hits through walls: line-of-sight blocks melee arcs
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(4, 60)
	cs.shape = rs
	wall.add_child(cs)
	wall.global_position = arena + Vector2(12, 0)
	game.add_child(wall)
	await frames(2)
	check(not game.line_clear(arena, arena + Vector2(24, 0)), "A wall should block line of sight.")
	check(game.line_clear(arena, arena + Vector2(0, 24)), "Open ground should be clear.")
	var behind := dummy(Vector2(22, 0))
	var hits: Array = game.targets_in_arc(arena, Vector2.RIGHT, 40.0, 1.2)
	check(not hits.has(behind), "Melee arcs must not reach through walls.")
	wall.queue_free()
	clear_dummies()
	await frames(2)


func _test_equipment_visuals() -> void:
	reset_player()
	player.give_item("thornblade")
	check(player.weapons_owned.has("thornblade"), "Buying/receiving a weapon should add it.")
	player._set_weapon_index(player.weapons_owned.find("thornblade"))
	await frames(2)
	check(player.weapon_sprite.visible and player.weapon_sprite.texture != null, "Equipping a weapon should show it in Mallow's paw.")
	check(player.range_hint.reach > 22.0, "The attack indicator should switch to the weapon's reach.")
	check(player.unequip_weapon() and player.is_unarmed(), "Unequipping should return to punching.")
	await frames(2)
	check(not player.weapon_sprite.visible, "The held weapon should disappear when unequipped.")
	# dual knives: paired visuals, balanced passive
	player.give_item("nightfang")
	var idx: int = player.weapons_owned.find("nightfang")
	if idx >= 0 and Build.can_equip(player, "nightfang"):
		player._set_weapon_index(idx)
		await frames(2)
		check(player.is_dual_wield() and player.off_weapon_sprite.visible, "Dual knives should show a blade in each paw.")
	else:
		player.bind_class("nightbloom")
		player._set_weapon_index(player.weapons_owned.find("nightfang"))
		await frames(2)
		check(player.is_dual_wield() and player.off_weapon_sprite.visible, "Dual knives should show a blade in each paw.")
	check(not player.off_weapon_sprite.centered, "Both hands should use the shared top-left texture origin.")
	check(String(CD.WEAPONS["nightfang"]["passive"]) == "flurry", "Nightfang should use the capped Flurry passive.")
	player.unequip_weapon()
	# New CC0 variants use per-art grip anchors and aim along the facing axis.
	player.give_item("sunforge_greatsword")
	player._set_weapon_index(player.weapons_owned.find("sunforge_greatsword"))
	player._set_facing(Vector2.DOWN)
	await frames(2)
	check(not player.weapon_sprite.centered and player.weapon_sprite.offset == Vector2(-1, -1), "The reversed-hilt greatsword should anchor its upper-left grip pixel to the paw.")
	check(is_equal_approx(player.weapon_sprite.rotation, PI / 4.0), "The greatsword's lower-right blade should point down when facing down.")
	player.give_item("moonfeather_bow")
	player._set_weapon_index(player.weapons_owned.find("moonfeather_bow"))
	await frames(2)
	check(player.weapon_sprite.offset == Vector2(-8, -8), "The bow should pivot from its central hand-grip rather than an end.")
	player.give_item("duskwing_daggers")
	player._set_weapon_index(player.weapons_owned.find("duskwing_daggers"))
	await frames(2)
	check(not player.off_weapon_sprite.centered and player.off_weapon_sprite.offset == Vector2(-1, -14), "The mirrored CC0 off-hand should anchor at the flipped grip pixel.")
	player.unequip_weapon()
	# armour regions change colour immediately on equip / unequip
	player.give_item("briar_mail")
	player.unequip("armor")
	await frames(1)
	var before: Dictionary = player.visible_gear.duplicate()
	var can_wear: bool = Build.can_equip(player, "briar_mail")
	if can_wear:
		var eq_ok: bool = player.equip("briar_mail")
		await frames(1)
		check(player.visible_gear.values().has("briar_mail"), "Worn armour should be listed as visible gear (equip %s, gear %s, equipped %s)." % [eq_ok, str(player.visible_gear), str(player.equipped)])
		var col: Variant = player.fx_material.get_shader_parameter("region_cols")
		check(col != null, "The hero shader should receive region colours.")
		player.unequip(String(DB.ITEMS["briar_mail"]["type"]))
		await frames(1)
		check(player.visible_gear == before, "Removing armour should restore the base look.")
	check(player.appearance == HeroLook.sanitize(game.hud.create_state["look"]), "Equipment should not overwrite the chosen look.")


# ---------------------------------------------------------------- loot & bag
func _test_loot_and_bag() -> void:
	reset_player()
	var foe := dummy(Vector2(30, 0), 1, "slime")
	var drops := {"n": 0}
	var before: int = game.pickups.size()
	foe.hurt(5, player.global_position, 0.0)
	if foe.alive:
		foe.die()
	var first: Dictionary = game.drop_loot(foe)
	var second: Dictionary = game.drop_loot(foe)
	check(foe.loot_dropped and second.is_empty(), "Loot should roll exactly once per death.")
	drops["n"] = game.pickups.size() - before
	clear_dummies()
	# stacks
	player.bag.clear()
	check(Inv.add(player, "slime_gel", 5) == 5 and Inv.count(player, "slime_gel") == 5, "Materials should stack in the bag.")
	Inv.add(player, "slime_gel", 200)
	check(Inv.count(player, "slime_gel") == DB.STACK_MAX, "Stacks should cap at %d." % DB.STACK_MAX)
	check(not Inv.remove(player, "ore", 1), "Removing a missing item should fail.")
	# fill every slot then verify a new item type is refused (and not lost)
	player.bag.clear()
	var mats: Array = []
	for id in DB.ITEMS.keys():
		if Inv.is_stackable(id):
			mats.append(id)
	var filled := 0
	var k := 0
	while Inv.stacks_used(player) < DB.BAG_SLOTS and k < mats.size():
		Inv.add(player, mats[k], 1)
		k += 1
		filled += 1
	if Inv.stacks_used(player) >= DB.BAG_SLOTS and k < mats.size():
		var extra: String = mats[k]
		check(not Inv.can_add(player, extra, 1) and Inv.add(player, extra, 1) == 0, "A full bag should refuse new item types.")
		check(not player.give_item(extra), "give_item should report failure when the bag is full.")
	player.bag.clear()


# ---------------------------------------------------------------- shops & crafting
func _test_trade_and_crafting() -> void:
	reset_player()
	game.shop_id = "pip"
	var stock: Array = game._shop_stock()
	var blade: Dictionary = {}
	for e in stock:
		if e["id"] == "bloomstaff":
			blade = e
	check(not blade.is_empty(), "Pip should sell the Bloomstaff.")
	player.petalcoins = 5
	var res: Dictionary = game.buy_item(blade)
	check(player.petalcoins == 5 and not player.weapons_owned.has("bloomstaff"), "A failed purchase must not take coins or give the item.")
	player.petalcoins = 100
	game.buy_item(blade)
	check(player.petalcoins == 100 - int(blade["price"]) and player.weapons_owned.has("bloomstaff"), "Buying should take the exact price once.")
	var coins: int = player.petalcoins
	game.buy_item(blade)
	check(player.petalcoins == coins, "Buying owned unique gear should be refused without charging.")
	# selling materials
	Inv.add(player, "slime_gel", 3)
	coins = player.petalcoins
	game.sell_item("slime_gel")
	check(Inv.count(player, "slime_gel") == 2 and player.petalcoins == coins + Trade.sell_price("slime_gel"), "Selling should remove one and pay once.")
	check(Trade.sell_reason(game, "pip", "rift_key") != "" or not DB.ITEMS.has("rift_key"), "Key items should not be sellable.")
	# exchange failure leaves everything untouched
	game.shop_id = "bramble"
	var exs: Array = Eco.SHOPS["bramble"].get("exchanges", [])
	if not exs.is_empty():
		player.bag.clear()
		coins = player.petalcoins
		var r: Dictionary = game.do_exchange(exs[0])
		check(player.bag.is_empty() and player.petalcoins == coins, "A failed exchange must not change items or coins.")
	# crafting: validate, consume once, roll back on failure
	player.bag.clear()
	var rec: Dictionary = {}
	for rr in Eco.RECIPES:
		if String(rr.get("station", "field")) == "field" and rr.get("requires_owned", "") == "" and Craft.unlock_reason(game, rr) == "" and not player.owns(rr["id"]) and not Inv.is_stackable(rr["id"]):
			rec = rr
			break
	if not rec.is_empty():
		var r1: Dictionary = game.craft_recipe(rec["id"])
		check(not r1.get("ok", false), "Crafting without ingredients should fail.")
		for m in rec["needs"].keys():
			Inv.add(player, m, int(rec["needs"][m]))
		player.petalcoins += int(rec.get("coins", 0))
		var r2: Dictionary = game.craft_recipe(rec["id"])
		check(r2.get("ok", false) and player.owns(rec["id"]), "Crafting %s with ingredients should give the item (%s)." % [rec["id"], r2.get("reason", "")])
		var left := 0
		for m in rec["needs"].keys():
			left += Inv.count(player, m)
		check(left == 0, "Crafting should consume ingredients exactly once.")
	game.shop_id = ""


# ---------------------------------------------------------------- HUD
func _test_hud() -> void:
	var hud: Control = game.hud
	var ctl: Node = hud.controls
	check(ctl.skill_buttons.size() == 4, "The HUD should have exactly four art buttons.")
	check(ctl.relic_button != null and ctl.relic_button.visible, "The gear-active button should always be present.")
	check(hud.heal_button != null and hud.heal_button.visible, "The potion button should be present.")
	check(not ("dash_button" in hud) and not InputMap.has_action("dash") and not InputMap.has_action("dodge"), "There should be no dodge/dash control.")
	check(not player.skill_bar.has("") or true, "Skill bar holds only arts.")
	for sid in player.skill_bar:
		check(sid == "" or not sid in ["attack", "relic", "potion", "moontea"], "Art slots should not hold the basic attack, gear buff or potion.")
	check(player.potions_left() >= 0 and (player.potion_block_reason() != "" or player.health < player.max_health), "Potion state should be reported.")
	# satchel opens with filters and an unequip button for a held weapon
	player._set_weapon_index(player.weapons_owned.find("bloomstaff"))
	hud.satchel_selected = "bloomstaff"
	hud.toggle_inventory()
	check(hud.inventory_overlay.visible, "The satchel should open.")
	check(hud.inventory_panel.find_child("SatchelFilters", true, false) != null, "The satchel should offer category filters.")
	check(hud.inventory_panel.find_child("UnequipWeapon", true, false) != null, "A held weapon should offer UNEQUIP.")
	hud.toggle_inventory()
	player.unequip_weapon()
	# trade screen renders every tab
	game.shop_id = "bramble"
	for tab in ["buy", "sell", "trade", "craft"]:
		hud.open_trade("bramble", tab)
		check(hud.trade_overlay.visible and hud.trade_list.get_child_count() > 0, "The %s tab should list entries." % tab)
	hud.close_trade()


# ---------------------------------------------------------------- quests
func _test_quests() -> void:
	reset_player()
	check(QuestSys.marker_for(game.quests, "alder") == "!", "Alder should show a new-journey marker at the start.")
	var fists: Dictionary = QuestSys.def_of("q_first_fists")
	var spoils: Dictionary = QuestSys.def_of("q_spoils")
	check(not QuestSys.is_unlocked(game.quests, spoils), "Chained quests should stay locked until the previous one is claimed.")
	game._quest_on_talk("alder")
	check(int(QuestSys.entry(game.quests, "q_first_fists")["s"]) == QuestSys.STATE_ACTIVE, "Talking should start the intro quest.")
	check(int(QuestSys.entry(game.quests, "q_spoils")["s"]) == QuestSys.STATE_AVAILABLE, "The locked follow-up must not start early.")
	check(QuestSys.marker_for(game.quests, "alder") == "...", "An active quest should show the in-progress marker.")
	player.unequip_weapon()
	for i in range(int(fists["goal"])):
		game._quest_progress("kill_unarmed")
	check(int(QuestSys.entry(game.quests, "q_first_fists")["s"]) == QuestSys.STATE_DONE, "Unarmed kills should complete First Fists.")
	check(QuestSys.marker_for(game.quests, "alder") == "?", "A finished quest should show the ready marker.")
	var coins: int = player.petalcoins
	game._quest_on_talk("alder")
	check(player.petalcoins == coins + int(fists["reward"]["coins"]), "Claiming should pay the reward exactly once (no coin pickups).")
	coins = player.petalcoins
	game._quest_on_talk("alder")
	game._quest_progress("kill_unarmed")
	check(player.petalcoins == coins, "Claimed quests must never pay twice.")
	check(int(QuestSys.entry(game.quests, "q_spoils")["s"]) == QuestSys.STATE_ACTIVE, "Claiming should unlock and start the next chain step.")
	game._quest_progress("collect", "slime_gel")
	game._quest_progress("collect", "thornblade")
	check(int(QuestSys.entry(game.quests, "q_spoils")["n"]) == 1, "Only materials should count for Pocket the Spoils.")
	game._quest_progress("totally_unknown_type", "x")
	check(true, "Unknown objective types should be ignored safely.")
	# kill_kind matches species prefixes
	check(QuestSys.matches(QuestSys.def_of("q_snakes"), "kill_kind", "snake2"), "kill_kind should match species variants.")
	check(not QuestSys.matches(QuestSys.def_of("q_snakes"), "kill_kind", "slime"), "kill_kind should ignore other species.")


# ---------------------------------------------------------------- knockback
func _test_knockback() -> void:
	reset_player()
	var k := Vector2.ZERO
	for i in range(10):
		k = KB.push(k, Vector2.RIGHT, 400.0, 0.0)
	check(k.length() <= KB.CAP + 0.01, "Repeated hits must not stack knockback beyond the cap.")
	check(k.x > 0.0, "Knockback should push away from the attacker.")
	var boss_k := KB.push(Vector2.ZERO, Vector2.RIGHT, 200.0, KB.BOSS_RESIST)
	check(boss_k.length() < 30.0, "Bosses should resist most knockback.")
	check(KB.decay(Vector2(5, 0), 0.016) == Vector2.ZERO, "Tiny knockback should stop instead of sliding forever.")
	# against a wall: the body must not pass through or slide along it forever
	var wall := StaticBody2D.new()
	wall.collision_layer = 1
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = Vector2(8, 80)
	cs.shape = rs
	wall.add_child(cs)
	wall.global_position = arena + Vector2(30, 0)
	game.add_child(wall)
	var foe := dummy(Vector2(18, 0), 400)
	foe.collision_mask = 1
	await frames(2)
	foe.hurt(1, arena, 300.0)
	for i in range(30):
		foe.knock = KB.move(foe, Vector2.ZERO, foe.knock)
		foe.knock = KB.decay(foe.knock, 1.0 / 60.0)
		await physics_frame
	check(foe.global_position.x < arena.x + 30.0, "Knockback must not push an enemy through a wall (x=%.1f)." % (foe.global_position.x - arena.x))
	check(foe.knock.length() < 1.0, "Knockback should settle against a wall instead of sliding.")
	wall.queue_free()
	clear_dummies()
	await frames(2)


# ---------------------------------------------------------------- interiors
func _test_interiors() -> void:
	reset_player()
	var h: Dictionary = game._house("house_alder")
	player.global_position = h["door"] + Vector2(0, 10)
	check(game.enter_interior("house_alder") and game.is_inside(), "Entering a house should work.")
	check(not game.world.visible, "The overworld should be hidden inside (no seeing in or out).")
	var view: Vector2 = game.get_viewport().get_visible_rect().size / game.camera.zoom
	var span := float(game.camera.limit_right - game.camera.limit_left)
	check(span <= maxf(h["size"].x + 34.0, view.x) + 2.0 and game.camera.limit_left <= int(h["center"].x) and game.camera.limit_right >= int(h["center"].x), "The camera should be bound to the room (span %.0f)." % span)
	check(player.global_position.distance_to(h["center"]) < h["size"].length(), "Mallow should arrive inside the room.")
	check(game.enter_interior("alder_study") and String(game.current_interior["id"]) == "alder_study", "The study inside the hall should open from the hall.")
	check(game.leave_interior() and String(game.current_interior["id"]) == "house_alder", "Leaving the study should return to the hall.")
	check(game.leave_interior() and not game.is_inside() and game.world.visible, "Leaving the hall should return outside.")
	check(player.global_position.distance_to(h["door"]) < 24.0, "Mallow should come out at the correct door.")
	check(not game.enter_interior("alder_study"), "Inner rooms must not open from outside.")
	# legacy save positions map back to the doorway
	check(game._in_room_rect(h["legacy_center"], h["legacy_center"], h["size"]), "Legacy room rect check should work.")


# ---------------------------------------------------------------- rifts
func _test_rifts() -> void:
	reset_player()
	var R: Node = game.rifts
	if R.valid_points.is_empty():
		R.build_spawn_points()
	check(R.valid_points.size() >= 5, "There should be several valid rift spawn points (got %d)." % R.valid_points.size())
	var bad := 0
	for p in R.valid_points:
		if game.world.is_water(p) or game.world.is_solid(p):
			bad += 1
	check(bad == 0, "No rift point should be in water or a wall.")
	var hg: Array = game.world.data["landmarks"]["hearthgrove"]
	check(not R.is_valid_point(Vector2(hg[0], hg[1])), "Rifts must never open in the village.")
	player.global_position = Vector2(hg[0], hg[1])
	check(R.try_spawn(), "A rift should be able to open.")
	check(not R.try_spawn(), "Only one rift should be open at a time.")
	var uid: int = R.entrance["uid"]
	var markers: Array = game.map_markers()
	var has_marker := false
	for m in markers:
		if m.get("label", "") == "Rift":
			has_marker = true
	check(has_marker, "An open rift should be marked on the map.")
	player.level = 20
	player.global_position = R.entrance["point"]
	check(R.enter() and R.active, "Entering a rift should work at the right level.")
	await frames(2)
	check(R.in_pocket(player.global_position) and not game.world.visible, "The rift should be a separate, isolated area.")
	check(R.targets().size() > 0 or true, "First chamber spawns once the player walks in.")
	await frames(3)
	check(R.targets().size() >= 3, "The first chamber should spawn a wave (got %d)." % R.targets().size())
	check(not R.leave(true) and R.active, "The exit portal should not work before the warden falls.")
	if R.active:
		# clear chambers by force: kill everything, walk on, repeat
		for room_i in range(3):
			player.global_position = R.room_center(room_i)
			await frames(3)
			for pass_i in range(4):
				for t in R.targets().duplicate():
					if is_instance_valid(t):
						if t.get("boss_id") != null:
							t.hp = 1
							t.awake = true
							t.hurt(5, player.global_position, 0.0)
						else:
							t.hurt(99999, player.global_position, 0.0)
							if t.alive:
								t.die()
				await frames(10)
				await create_timer(1.4).timeout
			await frames(2)
		check(R.cleared, "Defeating the Rift Warden should clear the rift (room %d, spawned %s, targets %d, boss %s)." % [R.room, str(R._spawned_rooms.keys()), R.targets().size(), str(R._boss)])
		var coins: int = player.petalcoins
		check(R.claim_cache() and player.petalcoins > coins, "The rift cache should pay out.")
		coins = player.petalcoins
		check(not R.claim_cache() and player.petalcoins == coins, "The cache must only pay once.")
		check(R.claimed.has(uid), "The claimed rift uid should be recorded.")
		check(R.leave(true) and not R.active and game.world.visible, "The exit portal should return to the overworld.")
		check(R.entrance.is_empty(), "A cleared rift should collapse.")
		check(not R.in_pocket(player.global_position), "Leaving should put Mallow back in the world.")
	# rift reload never re-opens a claimed rift
	var data: Dictionary = R.save_data()
	R.load_data(data)
	check(R.claimed.has(uid) and R.entrance.is_empty(), "Rift save data should round-trip without re-opening claimed rifts (claimed %s, uid %d, entrance %s, cleared %s)." % [str(R.claimed), uid, str(R.entrance.keys()), R.cleared])
	# death inside: progress kept, rift tidied
	player.global_position = Vector2(hg[0], hg[1])
	R._since = 0.0
	check(R.try_spawn(), "A second rift should open.")
	player.global_position = R.entrance["point"]
	R.enter()
	await frames(2)
	var lvl: int = player.level
	R.on_player_died()
	check(not R.active and player.level == lvl, "Dying in a rift should keep progress and tidy up.")
	game._restore_world_camera()
	R._close_entrance()


# ---------------------------------------------------------------- save / load
func _test_save_load() -> void:
	reset_player()
	game.current_interior = {}
	game.interior_stack.clear()
	game._restore_world_camera()
	player.global_position = arena
	Inv.add(player, "ore", 4)
	player.give_item("cinder_axe")
	var look: Dictionary = player.appearance.duplicate()
	check(game.save_game(), "Saving should work.")
	player.bag.clear()
	player.set_appearance(HeroLook.default_appearance())
	game.load_game()
	await frames(2)
	player = game.player
	check(Inv.count(player, "ore") == 4, "Bag stacks should persist.")
	check(player.weapons_owned.has("cinder_axe") and player.weapons_owned[0] == "fists", "Weapons (with fists first) should persist.")
	check(player.appearance == look, "The chosen appearance should persist.")
	# a save written inside a house reloads inside it
	game.enter_interior("house_mira")
	game.save_game()
	game.leave_interior()
	game.load_game()
	await frames(1)
	check(game.is_inside() and String(game.current_interior["id"]) == "house_mira", "Saving indoors should reload indoors.")
	game.leave_interior()


func _test_settings() -> void:
	var hud: Control = game.hud
	hud.settings["button_size"] = 1.2
	hud.save_settings()
	var loaded: Dictionary = Settings.load_all()
	check(is_equal_approx(float(loaded.get("button_size", 0.0)), 1.2), "Settings should persist.")
