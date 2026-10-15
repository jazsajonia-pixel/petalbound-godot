extends SceneTree
## Headless test for the combat, classes & UI overhaul. Exercises real game
## code paths (no mocks): data validation for every class/skill/item combo,
## auto-targeting and retargeting, the always-on attack indicator, weapon hit
## shapes and passives, the four art slots with tap and aimed casting, unlocks
## and upgrades, hybrid class gear, every equipment slot and stat recalculation,
## dodge, the Moontea flask, elemental statuses and resistances, the relic
## active, the mobile HUD (aim / cancel / empty slot), fixed and floating
## joysticks, the HUD editor and settings persistence, and save/load.

const Save := preload("res://scripts/systems/save.gd")
const Settings := preload("res://scripts/systems/settings.gd")
const ClassBook := preload("res://scripts/data/classdb.gd")
const DB := preload("res://scripts/data/db.gd")
const CD := preload("res://scripts/data/combat_data.gd")
const Build := preload("res://scripts/combat/build.gd")
const StatusFx := preload("res://scripts/combat/status.gd")
const EnemyScript := preload("res://scripts/actors/enemy.gd")

var game: Node
var player: CharacterBody2D
var failures: PackedStringArray = []
var passes := 0
var spawned: Array = []
var arena := Vector2.ZERO


func _initialize() -> void:
	Settings.path_override = "user://petalbound_test_settings.cfg"
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


func seconds(t: float) -> void:
	await create_timer(t).timeout


func release_all() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down", "sprint", "jump", "attack", "interact", "relic"]:
		Input.action_release(a)


## A frozen-in-place test dummy with plenty of health.
func dummy(offset: Vector2, hp := 200, species := "mushroom") -> Node:
	var e := Dummy.new()
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
	player.state = player.State.MOVE
	player.attack_cooldown = 0.0
	player._lock_t = 0.0
	player.roll_t = 0.0
	player.invulnerable_left = 0.0
	player.focus = player.focus_max
	player.buffs.clear()
	for k in player.skill_cd.keys():
		player.skill_cd[k] = 0.0
	player._set_facing(Vector2.RIGHT)


func _run_test() -> void:
	Save.path_override = "user://petalbound_overhaul_test_save.json"
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
	# move every world enemy far away from the test arena: freeze them
	for e in game.enemies:
		e.set_physics_process(false)
		e.global_position += Vector2(4000, 4000)
	arena = player.global_position

	_test_data()
	await _test_targeting_and_indicator()
	await _test_basic_attacks()
	await _test_slots_unlocks_upgrades()
	await _test_casting()
	await _test_hybrid_and_equipment()
	await _test_weapons()
	await _test_dodge_and_flask()
	await _test_status_effects()
	await _test_relic()
	await _test_hud_controls()
	await _test_settings_and_editor()
	await _test_every_art()
	await _test_more_weapons_and_relics()
	await _test_save_load()
	await _test_legacy_save()

	Save.erase()
	Settings.erase()
	if failures.size() > 0:
		push_error("%d overhaul checks failed (%d passed)." % [failures.size(), passes])
		quit(1)
		return
	print("Combat overhaul smoke test passed (%d checks): data combos, auto-targeting, attack indicator, weapon shapes and passives, four art slots, tap and aimed casting, unlocks and upgrades, hybrid gear, nine equipment slots, stat recalculation, dodge, flask, elemental statuses, relic, mobile HUD aim/cancel, fixed and floating joysticks, HUD editor, settings and save/load all work." % passes)
	game.get("audio").call("stop_all")
	game.free()
	quit(0)


# ---------------------------------------------------------------- data
func _test_data() -> void:
	var skills_ok := true
	for cid in ClassBook.CLASSES:
		var c: Dictionary = ClassBook.CLASSES[cid]
		if (c["skills"] as Array).size() < 3:
			skills_ok = false
			failures.append("%s should have at least three arts." % cid)
		for sid in c["skills"]:
			var d: Dictionary = ClassBook.skill_of(sid)
			if d.is_empty() or d["class"] != cid or not ResourceLoader.exists(d["icon"]):
				skills_ok = false
				failures.append("Art %s of %s is invalid." % [sid, cid])
			if not String(d.get("aim", "")) in ["tap", "direction", "point"]:
				skills_ok = false
				failures.append("Art %s has no valid aim type." % sid)
			if String(d.get("aim", "tap")) != "tap" and float(d.get("range", 0.0)) <= 0.0:
				skills_ok = false
				failures.append("Aimable art %s needs a range." % sid)
		for need in c.get("rewards", {}):
			for gid in c["rewards"][need]:
				if not DB.ITEMS.has(gid):
					skills_ok = false
					failures.append("Reward %s of %s missing." % [gid, cid])
	check(skills_ok, "Every class should define three valid arts and real rewards.")
	var items_ok := true
	for id in DB.ITEMS:
		var it: Dictionary = DB.ITEMS[id]
		if not ResourceLoader.exists(DB.icon_path(id)):
			items_ok = false
			failures.append("Item %s icon missing." % id)
		for c in it.get("classes", []):
			if not ClassBook.CLASSES.has(c):
				items_ok = false
				failures.append("Item %s requires unknown line %s." % [id, c])
		if it["type"] == "weapon" and not CD.WEAPONS.has(id):
			items_ok = false
			failures.append("Weapon %s has no attack pattern." % id)
		if it.has("relic") and not CD.RELICS.has(String(it["relic"])):
			items_ok = false
			failures.append("Relic %s maps to an unknown buff." % id)
		if it["type"] in DB.EQUIP_SLOTS and not it.has("rarity"):
			items_ok = false
			failures.append("Gear %s has no rarity." % id)
	check(items_ok, "Every item should have an icon, valid class requirements, patterns and rarity.")
	var slots_present: Dictionary = {}
	for id in DB.ITEMS:
		slots_present[DB.ITEMS[id]["type"]] = true
	for slot in ["head", "armor", "arms", "legs", "boots", "relic"]:
		check(slots_present.has(slot), "Some item should fill the %s slot." % slot)
	# every single and dual line combination: eligible arts, loadouts and gear rules
	var combos: Array = []
	for a in ClassBook.CLASSES:
		combos.append([a])
		for b in ClassBook.CLASSES:
			if a != b:
				combos.append([a, b])
	var fake := FakeBuild.new()
	var combos_ok := true
	for combo in combos:
		fake.classes = combo.duplicate()
		fake.class_nodes = {}
		for c in combo:
			fake.class_nodes[c] = {}
			for nid in ClassBook.class_of(c)["tree"]:
				fake.class_nodes[c][nid] = true
		var elig: Array = Build.eligible_skills(fake)
		for sid in elig:
			var cl: String = ClassBook.skill_of(sid)["class"]
			if cl != "" and not combo.has(cl):
				combos_ok = false
		var bar := Build.sanitize_loadout(fake, elig + ["bogus", elig[0]])
		if bar.size() != 4:
			combos_ok = false
		var seen := {}
		for sid in bar:
			if sid != "" and seen.has(sid):
				combos_ok = false
			seen[sid] = true
		fake.inventory = DB.ITEMS.keys()
		fake.weapons_owned = []
		for id in DB.ITEMS:
			if DB.ITEMS[id]["type"] == "weapon":
				fake.weapons_owned.append(id)
		for id in DB.ITEMS:
			var it: Dictionary = DB.ITEMS[id]
			if not (it["type"] == "weapon" or it["type"] in DB.EQUIP_SLOTS):
				continue
			var req: Array = it.get("classes", [])
			var expect := req.is_empty()
			if not req.is_empty():
				if bool(it.get("requires_all", false)):
					expect = true
					for r in req:
						if not combo.has(r):
							expect = false
				else:
					for r in req:
						if combo.has(r):
							expect = true
			if Build.can_equip(fake, id) != expect:
				combos_ok = false
				failures.append("Gear rule mismatch for %s with %s." % [id, str(combo)])
			if not expect and Build.item_reason(fake, id) == "":
				combos_ok = false
		var st := Build.compute_stats(fake)
		for k in st:
			if is_nan(float(st[k])) or is_inf(float(st[k])):
				combos_ok = false
	check(combos_ok, "All %d line combinations should give valid arts, loadouts and gear rules." % combos.size())


## Enemy that never moves or attacks (statuses still tick on their own node).
class Dummy:
	extends "res://scripts/actors/enemy.gd"

	func _physics_process(_delta: float) -> void:
		pass


class FakeBuild:
	extends RefCounted
	var classes: Array = []
	var class_nodes: Dictionary = {}
	var skill_levels: Dictionary = {}
	var skill_points := 0
	var level := 10
	var inventory: Array = []
	var weapons_owned: Array = []
	var equipped: Dictionary = {}

	func get_weapon_id() -> String:
		return "thornblade"


# ---------------------------------------------------------------- targeting
func _test_targeting_and_indicator() -> void:
	reset_player()
	await frames(2)
	check(player.range_hint.visible, "The attack area indicator should be visible while idle with no enemy near.")
	Input.action_press("move_right")
	await frames(4)
	check(player.range_hint.visible, "The attack area indicator should stay visible while moving.")
	Input.action_release("move_right")
	reset_player()
	var far := dummy(Vector2(55, 0))
	var near := dummy(Vector2(26, 0))
	player._update_target()
	check(player.current_target == near, "Auto-target should pick the closest valid enemy.")
	near.hp = 1
	player.deal(near, 5, {"can_crit": false})
	check(not near.alive, "The near dummy should die from a lethal hit.")
	player._update_target()
	check(player.current_target == far, "Auto-target should retarget when the target dies.")
	var near2 := dummy(Vector2(20, 6))
	check(player.lock_target_at(far.global_position), "Tapping an enemy should lock it as a manual target.")
	player._update_target()
	check(player.current_target == far, "A manual lock should override the closer enemy.")
	player.lock_target_at(far.global_position)
	player._update_target()
	check(player.manual_target == null and player.current_target == near2, "Tapping the locked enemy again should clear the lock.")
	game.hud.settings["auto_target"] = false
	game.hud.apply_settings()
	player._update_target()
	check(player.current_target == null, "Turning auto-target off should clear the automatic target.")
	game.hud.settings["auto_target"] = true
	game.hud.apply_settings()
	clear_dummies()
	await frames(1)


# ---------------------------------------------------------------- basic attacks
func _test_basic_attacks() -> void:
	reset_player()
	player._set_weapon_index(player.weapons_owned.find("thornblade"))
	var w: Dictionary = player.weapon_def()
	check(player.range_hint.shape == "arc" and is_equal_approx(player.range_hint.reach, float(w["reach"])), "Indicator should show the Thornblade arc at its real reach.")
	var inside := dummy(Vector2(float(w["reach"]) - 4.0, 4.0))
	var outside := dummy(Vector2(0, -float(w["reach"]) - 40.0))
	var behind := dummy(Vector2(-22, 4))
	var hits := {"n": 0}
	var counter := func(t: Node, _a: int, _c: bool, _e: String) -> void:
		if t == inside:
			hits["n"] += 1
	player.damage_dealt.connect(counter)
	var hp_in: int = inside.hp
	var hp_out: int = outside.hp
	var hp_behind: int = behind.hp
	player.manual_target = inside
	player.current_target = inside
	check(player.try_attack(), "A basic attack should start.")
	check(inside.hp < hp_in, "A target inside the arc should take damage.")
	check(outside.hp == hp_out, "A target outside the reach should not be hit.")
	check(behind.hp == hp_behind, "A target behind Mallow (outside the arc) should not be hit.")
	check(hits["n"] == 1, "One swing should deal exactly one damage event per target (got %d)." % hits["n"])
	player.damage_dealt.disconnect(counter)
	check(not player.try_attack(), "Attack timing: a second swing during the cooldown should be refused.")
	await seconds(0.6)
	player.state = player.State.MOVE
	clear_dummies()
	await frames(1)


# ---------------------------------------------------------------- slots, unlocks, upgrades
func _test_slots_unlocks_upgrades() -> void:
	reset_player()
	player.add_xp(3000)
	check(player.level >= 5, "XP should raise the level to the combine gate.")
	player.skill_points = 30
	check(player.bind_class("nightbloom"), "Bind Nightbloom (assassin) as primary.")
	check(player.skill_bar.size() == 4, "There should always be exactly four art slots.")
	check(player.skill_bar.has("shadowstep") and player.skill_bar.has("fan_knives"), "Nightbloom arts should be slotted on bind (%s)." % str(player.skill_bar))
	check(not player.skill_bar.has("toxic_veil"), "The third art should start locked.")
	check(not player.set_skill_slot(0, "toxic_veil"), "Slotting a locked art should be refused.")
	check(Build.skill_lock_reason(player, "toxic_veil").contains("rank 3"), "Locked arts should explain their rank requirement.")
	check(player.weapons_owned.has("nightfang"), "Binding Nightbloom should grant its signature daggers.")
	player.spend_node("nightbloom", "nightveil")
	check(player.class_rank("nightbloom") == 2 and player.inventory.has("duskweave_hood"), "Rank 2 should grant the Duskweave Hood.")
	player.spend_node("nightbloom", "quiet_step")
	check(player.class_rank("nightbloom") == 3, "Two tree nodes should reach rank 3.")
	check(Build.is_skill_unlocked(player, "toxic_veil"), "Rank 3 should unlock Toxic Veil.")
	check(player.set_skill_slot(2, "toxic_veil"), "An unlocked third art should be slottable.")
	var where: int = player.skill_bar.find("shadowstep")
	check(player.set_skill_slot(3, "shadowstep") and player.skill_bar.count("shadowstep") == 1 and player.skill_bar[3] == "shadowstep", "Re-slotting an art should swap rather than duplicate.")
	check(where >= 0, "Shadowstep should have been in the bar.")
	# upgrades
	var d0: int = Build.skill_stat(player, "fan_knives", "dmg", 0)
	var cd0: float = Build.skill_stat(player, "fan_knives", "cd", 0.0)
	var pts: int = player.skill_points
	check(player.upgrade_skill("fan_knives"), "Upgrading Fan of Knives to level 2 at rank 3 should work.")
	check(player.skill_points == pts - 1, "Level 2 upgrade should cost one point.")
	check(Build.skill_stat(player, "fan_knives", "dmg", 0) > d0 and Build.skill_stat(player, "fan_knives", "cd", 0.0) < cd0, "Upgrades should raise damage and shorten the cooldown.")
	check(player.upgrade_skill("fan_knives"), "Level 3 needs rank 3: should work.")
	check(not player.upgrade_skill("fan_knives"), "Mastered arts cannot be upgraded further.")
	check(Build.upgrade_reason(player, "frost_lance") != "", "Arts of unbound lines cannot be upgraded.")
	player.skill_points = 0
	check(not player.upgrade_skill("shadowstep"), "Upgrades should be refused without points.")
	player.skill_points = 30


# ---------------------------------------------------------------- casting
func _test_casting() -> void:
	reset_player()
	var foe := dummy(Vector2(70, 0))
	player.current_target = foe
	# tap art: Shadowstep is 'direction' aim, Fan of Knives direction, Toxic Veil point
	player.set_skill_slot(0, "fan_knives")
	var focus0: float = player.focus
	var hp0: int = foe.hp
	check(player.cast_slot(0, Vector2(70, -4)), "An aimed art should cast with an explicit aim vector.")
	check(player.focus < focus0, "Casting should spend focus.")
	check(float(player.skill_cd["fan_knives"]) > 0.0, "Casting should start the cooldown.")
	check(not player.cast_slot(0), "An art on cooldown should be refused.")
	await seconds(0.7)
	check(foe.hp < hp0, "Fan of Knives projectiles should hit the aimed enemy.")
	check(StatusFx.of(foe) != null and StatusFx.of(foe).has_effect("poison"), "Fan of Knives should poison its target.")
	# point aim: toxic veil at the foe
	reset_player()
	player.set_skill_slot(1, "toxic_veil")
	var hp1: int = foe.hp
	check(player.cast_skill("toxic_veil", foe.global_position - player.global_position), "Toxic Veil should cast at a ground point.")
	await seconds(1.2)
	check(foe.hp < hp1, "A ground zone should damage enemies inside it over time.")
	# insufficient focus
	reset_player()
	player.focus = 0.0
	check(not player.cast_skill("shadowstep"), "Casting without enough focus should be refused.")
	check(player.cast_block_reason("shadowstep") == "focus", "The block reason should report missing focus.")
	reset_player()
	# tap art with auto aim
	var pos0: Vector2 = player.global_position
	check(player.cast_skill("shadowstep"), "A quick-cast aimable art should auto-aim.")
	check(player.global_position.distance_to(pos0) > 20.0, "Shadowstep should blink Mallow forward.")
	check(player.buffs.has("shadow"), "Shadowstep should grant the guaranteed-crit buff.")
	player.current_target = foe
	var crit := {"c": false}
	var cb := func(_t: Node, _a: int, c: bool, _e: String) -> void: crit["c"] = c
	player.damage_dealt.connect(cb)
	player.deal(foe, 2, {"source": "basic"})
	player.damage_dealt.disconnect(cb)
	check(crit["c"] and not player.buffs.has("shadow"), "The shadow buff should force one critical and then be consumed.")
	# wanderer tap art
	reset_player()
	player.set_skill_slot(3, "mothlight")
	var hp2: int = foe.hp
	foe.global_position = player.global_position + Vector2(30, 0)
	check(player.cast_slot(3), "Mothlight (tap) should cast immediately.")
	check(foe.hp < hp2, "Mothlight should damage nearby enemies.")
	clear_dummies()
	await seconds(0.4)


# ---------------------------------------------------------------- hybrid gear & equipment
func _test_hybrid_and_equipment() -> void:
	reset_player()
	player.give_item("twilight_mantle")
	check(player.inventory.has("twilight_mantle"), "The hybrid mantle should be in the satchel.")
	check(not player.equip("twilight_mantle"), "Hybrid gear should be refused with only Nightbloom bound.")
	check(player.last_equip_error.contains("Gravetender"), "The refusal should name the missing line (%s)." % player.last_equip_error)
	check(player.bind_class("gravetender"), "Combine Gravetender as the secondary line.")
	check(player.classes == ["nightbloom", "gravetender"], "Nightbloom should stay primary.")
	check(player.weapons_owned.has("grave_scythe"), "Gravetender should grant its scythe.")
	check(Build.eligible_skills(player).has("grave_bolt") and Build.eligible_skills(player).has("fan_knives"), "Arts from both lines should be eligible.")
	check(player.set_skill_slot(0, "grave_bolt") and player.set_skill_slot(1, "fan_knives"), "The loadout should mix arts from both lines.")
	check(player.equip("twilight_mantle"), "Assassin + Necromancer should unlock the hybrid mantle.")
	player.give_item("frostlace_robe")
	check(not player.equip("frostlace_robe") and player.last_equip_error.contains("Lumimancer"), "Mage gear should be refused for Assassin + Necromancer.")
	# all nine slots with universal gear, stats recomputed exactly once
	for id in player.equipped.keys().duplicate():
		player.unequip(id)
	player.recalc_stats()
	var base: Dictionary = player.stats.duplicate()
	var base_hp: int = player.max_health
	var gear := {"head": "mossleaf_cap", "armor": "briar_mail", "arms": "rootgrip_gloves", "legs": "trail_leggings",
		"boots": "zephyr_boots", "cloak": "plum_cloak", "charm": "moonheart_charm", "ring": "moonveil_ring", "relic": "ember_heart"}
	for slot in gear:
		player.give_item(gear[slot])
		if player.equipped.get(slot, "") != gear[slot]:
			player.equip(gear[slot])
	var all_ok := true
	for slot in gear:
		if player.equipped.get(slot, "") != gear[slot]:
			all_ok = false
			failures.append("Slot %s did not equip %s." % [slot, gear[slot]])
	check(all_ok, "Every equipment slot (head, chest, arms, legs, feet, cloak, charm, ring, relic) should equip.")
	var expect_crit := float(base["crit"]) + 0.06
	check(is_equal_approx(player.stat("crit"), expect_crit), "Crit should include the ring exactly once (%.3f vs %.3f)." % [player.stat("crit"), expect_crit])
	check(player.max_health == base_hp + 8, "Hearts from chest and charm should add exactly 2 hearts.")
	for i in range(5):
		player.recalc_stats()
	check(is_equal_approx(player.stat("crit"), expect_crit) and player.max_health == base_hp + 8, "Recalculating repeatedly must not stack bonuses.")
	player.equip("moonveil_ring")  # toggle off
	check(is_equal_approx(player.stat("crit"), float(base["crit"])), "Unequipping should remove the bonus exactly.")
	player.equip("moonveil_ring")
	var cmp: Array = Build.compare_lines(player, "ember_ring")
	check(cmp.size() >= 2, "Comparing a ring with the worn ring should list stat differences.")
	# releasing a line returns its gear to the satchel instead of deleting it
	player._set_weapon_index(player.weapons_owned.find("grave_scythe"))
	player.equip("twilight_mantle")
	check(player.equipped.get("cloak", "") == "twilight_mantle", "Mantle should be worn before the release.")
	var nodes_before: int = (player.class_nodes["nightbloom"] as Dictionary).size()
	check(player.release_class("gravetender"), "Releasing the secondary line should work.")
	check(not player.equipped.has("cloak") and player.inventory.has("twilight_mantle"), "Invalid gear should return to the satchel, not vanish.")
	check(player.get_weapon_id() != "grave_scythe" and player.weapons_owned.has("grave_scythe"), "An invalid held weapon should be swapped, but kept.")
	check(not player.skill_bar.has("grave_bolt"), "Arts of the released line should leave the loadout.")
	check((player.class_nodes["nightbloom"] as Dictionary).size() == nodes_before, "Releasing must not touch other line progress.")
	check(player.bind_class("gravetender") and player.class_rank("gravetender") >= 1, "Rebinding should restore the line.")
	var w_before: int = player.weapons_owned.size()
	player.release_class("gravetender")
	player.bind_class("gravetender")
	check(player.weapons_owned.size() == w_before, "Rebinding must not hand out signature gear twice.")


# ---------------------------------------------------------------- weapons
func _test_weapons() -> void:
	reset_player()
	# daggers: Flurry builds a small, capped crit bonus on one target
	player._set_weapon_index(player.weapons_owned.find("nightfang"))
	check(player.range_hint.reach == float(CD.WEAPONS["nightfang"]["reach"]), "Indicator should update to the dagger reach.")
	var foe := dummy(Vector2(18, 4))
	player.current_target = foe
	check(is_zero_approx(player._weapon_crit_bonus(foe, "basic")), "Flurry should start with no bonus.")
	for i in range(5):
		player._weapon_on_hit(foe, "basic", {})
	check(player._flurry_stacks == 3 and is_equal_approx(player._weapon_crit_bonus(foe, "basic"), 0.12), "Flurry should cap at 3 stacks (+12%% crit), got %d." % player._flurry_stacks)
	var other := dummy(Vector2(18, -20))
	check(is_zero_approx(player._weapon_crit_bonus(other, "basic")), "Flurry must not carry over to a different foe.")
	player._weapon_on_hit(other, "basic", {})
	check(player._flurry_stacks == 1, "Hitting a new foe should restart Flurry.")
	player._flurry_t = 0.01
	await frames(3)
	check(player._flurry_stacks == 0, "Flurry should fade after its window.")
	await seconds(0.25)
	reset_player()
	# scythe: wide sweep curses; curse raises damage taken
	player._set_weapon_index(player.weapons_owned.find("grave_scythe"))
	check(player.range_hint.half_angle > 1.5, "The scythe indicator should be a wide sweep.")
	var side := dummy(Vector2(10, 22))
	player.current_target = foe
	player._set_facing(Vector2.RIGHT)
	player._attack_melee(player.weapon_def())
	check(StatusFx.of(foe) != null and StatusFx.of(foe).has_effect("curse"), "Scythe Reap should curse what it hits.")
	check(StatusFx.of(side) != null and StatusFx.of(side).has_effect("curse"), "The wide sweep should also reach a foe off to the side.")
	await seconds(0.6)
	# changing weapon mid-attack
	reset_player()
	player._set_weapon_index(player.weapons_owned.find("thornblade"))
	player.current_target = foe
	player.try_attack()
	check(player.state == player.State.ATTACK, "Mallow should be mid-attack.")
	player.cycle_weapon()
	check(player.attack_combo == -1 and player.range_hint.reach == float(player.weapon_def()["reach"]), "Swapping weapons mid-combat should reset the combo and refresh the indicator.")
	await seconds(0.5)
	# staves: projectiles; Moonglass prism cycles elements
	player.give_item("moonglass_staff")
	check(not player.equip_weapon("moonglass_staff"), "Mage staff should be refused without the Lumimancer line.")
	player.give_item("bloomstaff")
	reset_player()
	player._set_weapon_index(player.weapons_owned.find("bloomstaff"))
	check(player.range_hint.shape == "line", "Staff indicator should be a projectile line.")
	var hp0: int = foe.hp
	var lane := Vector2.RIGHT
	for dv in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
		var clear := true
		for k in range(1, 11):
			if game.world.is_solid(player.global_position + Vector2(0, -3) + dv * 6.0 * k):
				clear = false
		if clear:
			lane = dv
			break
	foe.global_position = player.global_position + lane * 55.0
	player._set_facing(lane)
	player.manual_target = foe
	var ok_atk: bool = player.try_attack()
	check(ok_atk, "The staff should fire.")
	await seconds(0.6)
	check(foe.hp < hp0, "Staff bolts should travel and hit the (manually locked) target.")
	player.manual_target = null
	# hammer: circle slam chills (Quake)
	if not player.weapons_owned.has("ironroot_hammer"):
		player.give_item("ironroot_hammer")
	reset_player()
	player._set_weapon_index(player.weapons_owned.find("ironroot_hammer"))
	check(player.range_hint.shape == "circle", "Hammer indicator should be an impact circle.")
	foe.global_position = player.global_position + Vector2(20, 2)
	StatusFx.of(foe).clear_all()
	player.current_target = foe
	player.try_attack()
	await seconds(0.45)
	check(StatusFx.of(foe).has_effect("chill") or StatusFx.of(foe).has_effect("freeze"), "Hammer Quake should chill what it hits.")
	player._set_weapon_index(player.weapons_owned.find("thornblade"))
	clear_dummies()
	await seconds(0.3)


# ---------------------------------------------------------------- dodge & flask
func _test_dodge_and_flask() -> void:
	reset_player()
	player.stamina = 100.0
	player.dodge_cd = 0.0
	check(player.start_roll(Vector2.UP), "Dodge should start in the chosen direction.")
	check(player.roll_dir.y < -0.9, "Dodge should follow the movement direction.")
	check(player.invulnerable_left > 0.0, "Dodge should grant a brief invulnerability window.")
	var h: int = player.health
	player.take_damage(4, player.global_position + Vector2(10, 0))
	check(player.health == h, "Hits during the dodge should be ignored.")
	await seconds(0.4)
	player.state = player.State.MOVE
	player.dodge_cd = 0.3
	check(not player.start_roll(Vector2.LEFT), "Dodge should respect its cooldown.")
	player.dodge_cd = 0.0
	player.stamina = 5.0
	check(not player.start_roll(Vector2.LEFT), "Dodge should need stamina.")
	player.stamina = 100.0
	# flask
	reset_player()
	player.health = player.max_health
	player.moontea_charges = 2
	check(not player.drink_moontea(), "The flask should refuse at full health.")
	player.health = player.max_health - 2
	check(player.drink_moontea() and player.health == player.max_health, "The flask should never heal beyond maximum.")
	check(player.moontea_charges == 1, "Drinking should spend one charge.")
	player.health = 4
	check(not player.drink_moontea(), "The flask should respect its short cooldown.")
	player.flask_cd = 0.0
	check(player.drink_moontea() and player.moontea_charges == 0, "The last charge should be drinkable.")
	player.flask_cd = 0.0
	player.health = 4
	check(not player.drink_moontea(), "An empty flask should refuse.")
	player.moontea_charges = 3
	player.health = player.max_health


# ---------------------------------------------------------------- statuses
func _test_status_effects() -> void:
	reset_player()
	var foe := dummy(Vector2(40, 0))
	var hp0: int = foe.hp
	StatusFx.apply(game, foe, "burn", 1)
	await seconds(1.4)
	check(foe.hp < hp0, "Burn should deal damage over time.")
	for i in range(9):
		StatusFx.apply(game, foe, "poison", 1)
	check(StatusFx.of(foe).stacks("poison") == int(CD.STATUS["poison"]["max_stacks"]), "Poison stacks should cap at their maximum.")
	StatusFx.of(foe).clear_all()
	StatusFx.apply(game, foe, "chill", 1)
	check(StatusFx.of(foe).speed_mult() < 1.0, "Chill should slow.")
	StatusFx.apply(game, foe, "chill", 2)
	check(StatusFx.of(foe).has_effect("freeze") and StatusFx.of(foe).speed_mult() == 0.0, "Three chills should freeze.")
	await seconds(float(CD.STATUS["freeze"]["duration"]) + 0.2)
	check(not StatusFx.apply(game, foe, "freeze", 1), "Freeze immunity should follow a freeze.")
	# curse / expose vulnerability
	StatusFx.of(foe).clear_all()
	var a: int = game.damage_target(foe, 8, foe.global_position, 0.0)
	StatusFx.apply(game, foe, "curse", 1)
	var b: int = game.damage_target(foe, 8, foe.global_position, 0.0)
	check(b == 10 and a == 8, "Curse should raise damage taken by 25%% (got %d -> %d)." % [a, b])
	StatusFx.apply(game, foe, "expose", 1)
	check(game.damage_target(foe, 8, foe.global_position, 0.0) == 10, "Curse and expose should not stack (larger wins).")
	# resistances
	var fire_foe := dummy(Vector2(60, 20), 50, "flam")
	check(not StatusFx.apply(game, fire_foe, "burn", 1), "Flame foes should be immune to burn.")
	var bosses: Array = game.bosses if game.get("bosses") != null else []
	if bosses.size() > 0:
		var boss: Node = bosses[0]
		boss.awake = true
		check(not StatusFx.apply(game, boss, "freeze", 1), "Bosses should be immune to freeze.")
		StatusFx.apply(game, boss, "burn", 1)
		check(float(StatusFx.of(boss).effects["burn"]["t"]) <= float(CD.STATUS["burn"]["duration"]) * 0.5 + 0.01, "Bosses should take half status duration.")
		StatusFx.of(boss).clear_all()
		boss.awake = false
	# dead targets drop statuses and are never targeted
	foe.hp = 1
	StatusFx.apply(game, foe, "poison", 3)
	game.damage_target(foe, 5, foe.global_position, 0.0)
	await frames(2)
	check(not foe.alive and StatusFx.of(foe).effects.is_empty(), "A dead enemy should lose its statuses.")
	check(player.deal(foe, 5) == 0, "Dealing damage to a dead target should do nothing.")
	clear_dummies()
	await frames(2)


# ---------------------------------------------------------------- relic
func _test_relic() -> void:
	reset_player()
	if player.equipped.get("relic", "") != "ember_heart":
		player.give_item("ember_heart")
		player.equip("ember_heart")
	check(player.relic_id() == "kindle", "The Ember Heart relic should grant Kindle.")
	var bar_before: Array = player.skill_bar.duplicate()
	check(player.activate_relic(), "The relic active should trigger.")
	check(player.skill_bar == bar_before, "The relic must not use an art slot.")
	check(player.buffs.has("relic_kindle") and player.relic_cd > 0.0, "Kindle should be active with a cooldown.")
	check(not player.activate_relic(), "The relic should respect its cooldown.")
	if not player.weapons_owned.has("thornblade"):
		player.give_item("thornblade")
	player._set_weapon_index(player.weapons_owned.find("thornblade"))
	var foe := dummy(Vector2(22, 4))
	player.current_target = foe
	player.try_attack()
	check(StatusFx.of(foe) != null and StatusFx.of(foe).has_effect("burn"), "Kindle should make basic attacks burn.")
	player.relic_cd = 0.0
	player.buffs.clear()
	clear_dummies()
	await seconds(0.5)


# ---------------------------------------------------------------- HUD
func _test_hud_controls() -> void:
	var hud: Control = game.hud
	hud.show_touch = true
	hud.settings["touch_controls"] = "on"
	hud._layout_controls()
	reset_player()
	await process_frame
	await process_frame
	var ctl: Node = hud.controls
	check(ctl.skill_buttons.size() == 4, "The HUD should have four art buttons.")
	check(ctl.relic_button.visible, "The relic button should show with a relic equipped.")
	check(hud.touch_root.visible, "Touch controls should be visible in play.")
	# no overlaps inside the default layout
	var overlap := false
	for x in hud.touch_buttons:
		for y in hud.touch_buttons:
			if x != y and x.visible and y.visible and x.center().distance_to(y.center()) < x.radius + y.radius:
				overlap = true
				failures.append("%s overlaps %s" % [x.id, y.id])
		if not hud.safe_rect.grow(1.0).encloses(Rect2(x.position, x.size)):
			overlap = true
			failures.append("%s leaves the safe area" % x.id)
	check(not overlap, "Default touch controls should neither overlap nor leave the screen.")
	# aimed art via touch: press, drag, release -> cast toward the drag
	var foe := dummy(Vector2(0, -60))
	player.set_skill_slot(0, "fan_knives")
	player.skill_cd["fan_knives"] = 0.0
	player.focus = player.focus_max
	await process_frame
	var b0: Control = ctl.skill_buttons[0]
	var c0: Vector2 = b0.center()
	_touch(hud, 7, c0, true)
	check(ctl.aim_index == 7, "Pressing an aimable art should begin aiming.")
	_drag(hud, 7, c0 + Vector2(0, -50))
	check(player.aim_indicator.visible and player.aim_indicator.mode == "direction", "Dragging should show the direction indicator.")
	check(is_equal_approx(player.aim_indicator.range_px, player.skill_range("fan_knives")), "The indicator should use the art's real range.")
	check(player.aim_indicator.aim.y < -0.5, "The indicator should follow the drag direction.")
	_touch(hud, 7, c0 + Vector2(0, -50), false)
	check(float(player.skill_cd.get("fan_knives", 0.0)) > 0.0 and not player.aim_indicator.visible, "Releasing should cast the art and hide the indicator.")
	check(player.facing.y < -0.5, "The cast should face the aimed direction.")
	# cancel: drag out, then back onto the button
	reset_player()
	player.set_skill_slot(1, "toxic_veil")
	player.skill_cd["toxic_veil"] = 0.0
	await process_frame
	var b1: Control = ctl.skill_buttons[1]
	var c1: Vector2 = b1.center()
	_touch(hud, 8, c1, true)
	_drag(hud, 8, c1 + Vector2(-40, -30))
	check(player.aim_indicator.mode == "point" and player.aim_indicator.radius > 0.0, "Point arts should show a ground circle.")
	_drag(hud, 8, c1 + Vector2(2, 1))
	check(player.aim_indicator.cancelling, "Sliding back onto the button should mark the cast as cancelled.")
	_touch(hud, 8, c1, false)
	check(float(player.skill_cd.get("toxic_veil", 0.0)) == 0.0, "A cancelled aim must not cast.")
	# tap art via touch
	player.set_skill_slot(2, "mothlight")
	player.skill_cd["mothlight"] = 0.0
	await process_frame
	var b2: Control = ctl.skill_buttons[2]
	_touch(hud, 9, b2.center(), true)
	check(float(player.skill_cd.get("mothlight", 0.0)) > 0.0, "Tap arts should cast immediately on press.")
	_touch(hud, 9, b2.center(), false)
	# the separate dodge control was removed (and not recreated under another name)
	reset_player()
	check(not ("dash_button" in hud) and not InputMap.has_action("dash") and not InputMap.has_action("dodge"), "There should be no dodge/dash control.")
	player.health = 4
	player.flask_cd = 0.0
	player.moontea_charges = 2
	_touch(hud, 11, hud.heal_button.center(), true)
	await process_frame
	await physics_frame
	_touch(hud, 11, hud.heal_button.center(), false)
	check(player.moontea_charges == 1 and player.health > 4, "The flask button should drink Moontea.")
	await process_frame
	ctl.update_buttons()
	check(hud.heal_button.label == "1", "The flask button should show the remaining charges.")
	# empty slot opens the loadout
	reset_player()
	player.skill_bar[3] = ""
	await process_frame
	_touch(hud, 12, ctl.skill_buttons[3].center(), true)
	_touch(hud, 12, ctl.skill_buttons[3].center(), false)
	await process_frame
	check(hud.arts_overlay.visible and hud.loadout_slot == 3, "Tapping an empty art slot should open the loadout on that slot.")
	var assign: Button = null
	for n in hud.arts_list.find_children("*", "Button", true, false):
		if (n as Button).text == "SLOT 4" and not (n as Button).disabled:
			assign = n
			break
	check(assign != null, "The loadout should offer arts for the selected slot.")
	if assign:
		assign.pressed.emit()
		check(player.skill_bar[3] != "", "Choosing an art should fill the slot.")
	hud.toggle_arts()
	await process_frame
	# satchel compare panel
	hud.toggle_inventory()
	hud.satchel_selected = "frostlace_robe"
	hud._refresh_inventory()
	var txt := ""
	for l in hud.inventory_detail.find_children("*", "Label", true, false):
		txt += (l as Label).text + "\n"
	check(txt.contains("Cannot equip") and txt.contains("Lumimancer"), "The satchel should explain why gear is unavailable.")
	check(hud.inventory_detail.get_index() < hud.inventory_doll.get_index(), "The selected-item details and actions should appear before the equipment doll in the inspection pane.")
	check(hud.inventory_detail.find_child("EquipButton", true, false) != null, "The selected-item equip action should be present directly in the item detail pane.")
	hud.toggle_inventory()
	clear_dummies()
	await frames(2)


func _touch(hud: Control, index: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	hud._input(e)


func _drag(hud: Control, index: int, pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = pos
	hud._input(e)


# ---------------------------------------------------------------- settings & editor
func _test_settings_and_editor() -> void:
	var hud: Control = game.hud
	# fixed joystick
	hud.settings["joystick_mode"] = "fixed"
	hud._layout_controls()
	var home: Vector2 = hud.joystick_home
	_touch(hud, 20, home + Vector2(hud.joystick_radius * 3.5, -10), true)
	check(hud.joystick_touch_index == -1, "Fixed joystick should ignore touches far from its base.")
	_touch(hud, 20, home + Vector2(10, 0), false)
	_touch(hud, 21, home + Vector2(12, 0), true)
	check(hud.joystick_touch_index == 21 and hud.joystick_center == home, "Fixed joystick should stay at its home position.")
	_drag(hud, 21, home + Vector2(hud.joystick_radius * 3.0, 0))
	check(hud.joystick_center == home and hud.joystick_vector.x > 0.9, "Dragging a fixed joystick should not relocate it.")
	_touch(hud, 21, home, false)
	# floating joystick
	hud.settings["joystick_mode"] = "floating"
	var start: Vector2 = hud.safe_rect.position + Vector2(hud.safe_rect.size.x * 0.25, hud.safe_rect.size.y * 0.5)
	_touch(hud, 22, start, true)
	check(hud.joystick_center == start, "Floating joystick should centre on the first touch.")
	_touch(hud, 22, start, false)
	# HUD editor: dragging moves controls but never fires actions
	hud.controls.start_edit()
	check(hud.controls.edit_active and paused, "The HUD editor should open and pause combat.")
	var ab: Control = hud.attack_button
	var c0: Vector2 = ab.center()
	_touch(hud, 30, c0, true)
	check(not Input.is_action_pressed("attack"), "Pressing a control in the editor must not attack.")
	var target := c0
	for cand in [Vector2(-200, -40), Vector2(-220, -120), Vector2(-160, -200), Vector2(-260, -60)]:
		var pt: Vector2 = hud.controls.clamp_center(c0 + cand, ab.radius)
		if not hud.controls.overlaps_any(ab, pt):
			target = pt
			break
	check(target != c0, "The editor test needs a free spot.")
	_drag(hud, 30, target)
	_touch(hud, 30, target, false)
	check(ab.center().distance_to(target) < 2.0, "The editor should move the dragged control.")
	check(hud.settings["layout"].has("attack"), "The new position should be stored.")
	# overlap refusal
	var db: Control = hud.heal_button
	var d0: Vector2 = db.center()
	_touch(hud, 31, d0, true)
	_drag(hud, 31, ab.center() + Vector2(3, 0))
	_touch(hud, 31, ab.center() + Vector2(3, 0), false)
	check(db.center().distance_to(d0) < 1.0, "Dropping a control on top of another should be refused.")
	# off-screen clamp
	_touch(hud, 32, ab.center(), true)
	_drag(hud, 32, Vector2(99999, 99999))
	_touch(hud, 32, Vector2(99999, 99999), false)
	check(hud.safe_rect.grow(1.0).encloses(Rect2(ab.position, ab.size)), "Controls must not leave the screen.")
	# scale
	var r0: float = ab.radius
	hud.settings["button_size"] = 1.3
	hud._layout_controls()
	check(ab.radius > r0 * 1.2, "Button size should scale touch buttons.")
	hud.controls.reset_layout()
	check(hud.settings["layout"].is_empty() and is_equal_approx(hud.settings["button_size"], 1.0), "Reset should restore the default layout.")
	hud.controls.end_edit()
	check(not hud.controls.edit_active and not paused, "Closing the editor should resume play.")
	# settings persistence + application
	hud.settings["damage_numbers"] = false
	hud.settings["screen_shake"] = 0.0
	hud.settings["joystick_mode"] = "fixed"
	hud.settings["hud_opacity"] = 0.55
	hud.settings["layout"] = {"jump": [-10.0, -4.0]}
	hud.apply_settings()
	hud.save_settings()
	check(not game.fx.numbers_enabled and game.fx.shake_scale == 0.0, "Damage-number and screen-shake settings should apply.")
	var loaded := Settings.load_all()
	check(loaded["joystick_mode"] == "fixed" and not loaded["damage_numbers"] and is_equal_approx(loaded["hud_opacity"], 0.55), "Settings should persist to disk.")
	check((loaded["layout"] as Dictionary).has("jump"), "Custom layouts should persist.")
	hud.settings = Settings.DEFAULTS.duplicate(true)
	hud.settings["touch_controls"] = "on"
	hud.apply_settings()
	hud._layout_controls()


# ---------------------------------------------------------------- save / load
func _test_save_load() -> void:
	reset_player()
	var bar: Array = player.skill_bar.duplicate()
	var lv := Build.skill_level(player, "fan_knives")
	var eq: Dictionary = player.equipped.duplicate()
	check(game.save_game(), "Saving should work.")
	player.skill_levels.clear()
	player.skill_bar.assign(["", "", "", ""])
	player.equipped.clear()
	check(game.load_game(), "Loading should work.")
	check(Build.skill_level(player, "fan_knives") == lv, "Art levels should persist.")
	check(player.skill_bar == bar, "The four-slot loadout should persist (%s vs %s)." % [str(player.skill_bar), str(bar)])
	check(player.equipped == eq, "Equipment should persist.")
	check(player.rewards_claimed.has("nightfang"), "Claimed rank rewards should persist.")


# ---------------------------------------------------------------- every art in every line
func _test_every_art() -> void:
	var saved_classes: Array = player.classes.duplicate()
	for c in saved_classes:
		player.release_class(c)
	player.skill_points = 200
	player.health = 4
	for cid in ClassBook.CLASSES:
		player.bind_class(cid)
		for nid in ClassBook.class_of(cid)["tree"]:
			player.spend_node(cid, nid)
		for sid in ClassBook.class_of(cid)["skills"]:
			reset_player()
			player.health = 4
			var def: Dictionary = ClassBook.skill_of(sid)
			var foe := dummy(Vector2(28, 0), 400)
			player.manual_target = foe
			player.current_target = foe
			var hp0: int = foe.hp
			var h0: int = player.health
			var aim: Vector2 = foe.global_position - player.global_position
			var ok: bool = player.cast_skill(sid, aim if String(def.get("aim", "tap")) != "tap" else Vector2.INF)
			check(ok, "%s (%s) should cast once unlocked (%s)." % [def["name"], cid, player.cast_block_reason(sid)])
			var wait := 0.9
			if def["exec"] == "summon":
				wait = 2.0
			elif def["exec"] in ["heal_zone", "cloud", "rain"]:
				wait = 1.4
			await seconds(wait)
			if def.has("dmg"):
				check(foe.hp < hp0, "%s should damage an enemy in range (hp %d -> %d)." % [def["name"], hp0, foe.hp])
			if def.has("heal"):
				check(player.health > h0, "%s should heal Mallow." % def["name"])
			if def["exec"] == "buff":
				check(player.buffs.has(String(def["buff"])), "%s should apply its buff." % def["name"])
			player.state = player.State.MOVE
			player.roll_t = 0.0
			player._dash_speed = 0.0
			clear_dummies()
			await frames(2)
		player.release_class(cid)
	player.health = player.max_health
	for c in saved_classes:
		player.bind_class(c)
	player.skill_points = 30


func _test_more_weapons_and_relics() -> void:
	# bow: charged shot pierces; prism staff cycles elements (needs Lumimancer)
	reset_player()
	var c0: Array = player.classes.duplicate()
	player.release_class(c0[1])
	player.bind_class("lumimancer")
	check(player.equip_weapon("moonglass_staff"), "Lumimancer should be able to wield the Moonglass Staff.")
	var foe := dummy(Vector2(40, 0), 400)
	player.manual_target = foe
	var elems: Array = []
	var cb := func(_t: Node, _a: int, _c: bool, e: String) -> void:
		if e != "":
			elems.append(e)
	player.damage_dealt.connect(cb)
	for i in range(3):
		reset_player()
		player.manual_target = foe
		player.try_attack()
		await seconds(0.55)
	player.damage_dealt.disconnect(cb)
	check(elems.has("fire") and elems.has("ice") and elems.has("lightning"), "Prism bolts should cycle fire, frost and storm (%s)." % str(elems))
	if not player.weapons_owned.has("gale_bow"):
		player.give_item("gale_bow")
	reset_player()
	player.equip_weapon("gale_bow")
	player.manual_target = foe
	var hp0: int = foe.hp
	player.try_attack()
	check(player.bow_charge >= 0.0, "The bow should start charging on press.")
	player.bow_charge = 0.7
	player._release_bow()
	await seconds(0.5)
	check(foe.hp < hp0, "A released bow shot should hit.")
	# other relics
	for rel in [["stormseed", "relic_overcharge"], ["soul_lantern", "relic_soulfeast"], ["gloam_lantern", "relic_nightveil"]]:
		player.give_item(rel[0])
	reset_player()
	player.relic_cd = 0.0
	check(player.equip("stormseed") and player.relic_id() == "overcharge", "Stormseed should equip for a Lumimancer.")
	player.activate_relic()
	check(player.buffs.has("relic_overcharge"), "Overcharge should activate.")
	var other := dummy(Vector2(46, 18), 400)
	var hp_o: int = other.hp
	player._overcharge_cd = 0.0
	player.deal(foe, 2, {"source": "basic"})
	check(other.hp < hp_o, "Overcharge should arc lightning to a nearby foe.")
	player.buffs.clear()
	player.relic_cd = 0.0
	check(not player.equip("soul_lantern") and player.last_equip_error.contains("Gravetender"), "Soul Lantern should need the Gravetender line.")
	player.release_class("lumimancer")
	player.bind_class(c0[1])
	check(player.relic_id() != "overcharge", "Releasing Lumimancer should unequip its relic.")
	player.equip_weapon("thornblade")
	clear_dummies()
	await frames(2)


func _test_legacy_save() -> void:
	# a save written before the overhaul: two-art bar, no art levels or rewards
	check(game.save_game(), "Saving for the legacy check should work.")
	var f := FileAccess.open(Save.path(), FileAccess.READ)
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	f.close()
	var pd: Dictionary = data["player"] if data.has("player") else data
	pd.erase("skill_levels")
	pd.erase("rewards")
	pd["bar"] = ["bulwark", "sunder"]
	pd["classes"] = ["warden"]
	pd["nodes"] = {"warden": {"oakheart": true}}
	var w := FileAccess.open(Save.path(), FileAccess.WRITE)
	w.store_string(JSON.stringify(data))
	w.close()
	check(game.load_game(), "A pre-overhaul save should load.")
	check(player.skill_bar.size() == 4 and player.skill_bar[0] == "bulwark", "Old loadouts should be kept and padded to four slots (%s)." % str(player.skill_bar))
	check(player.rewards_claimed.has("oakguard_helm") and player.inventory.has("oakguard_helm"), "Old saves should receive rank rewards they already earned.")
	check(Build.invalid_equipped(player).is_empty(), "Loading should never leave invalid gear equipped.")
