extends SceneTree

const Save := preload("res://scripts/systems/save.gd")
const DB := preload("res://scripts/data/db.gd")
const ClassBook := preload("res://scripts/data/classdb.gd")
const Build := preload("res://scripts/combat/build.gd")

var game: Node
var failures := 0

func _initialize() -> void:
	Save.path_override = ""
	call_deferred("_run_test")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _run_test() -> void:
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	check(game.hud.test_profile_button != null, "Title should expose the Test Profile button.")
	check(not game.game_started, "The game should open at the title before selecting Test Profile.")
	game.begin_test_profile()
	await process_frame
	var p: Node = game.player
	check(game.game_started, "Selecting Test Profile should start the game.")
	check(p.level == ClassBook.LEVEL_CAP, "Test Profile should start at the level cap.")
	check(p.classes.size() == ClassBook.CLASSES.size(), "Every class line should be bound.")
	check(p.weapons_owned.size() == DB.ITEMS.values().filter(func(it): return it.get("type", "") == "weapon").size(), "Every weapon should be owned.")
	check(p.weapon_bar.size() <= p.bar_max(), "The weapon HUD bar should remain within its normal limit.")
	for id in DB.ITEMS:
		var item: Dictionary = DB.ITEMS[id]
		var owned: bool = p.weapons_owned.has(String(id)) or p.inventory.has(String(id)) or int(p.bag.get(String(id), 0)) > 0
		check(owned, "Test Profile should grant %s (%s)." % [String(id), String(item.get("type", "unknown"))])
	for sid in ClassBook.SKILLS:
		check(Build.is_skill_unlocked(p, String(sid)), "Test Profile should unlock skill %s." % String(sid))
		check(int(p.skill_levels.get(String(sid), 0)) == ClassBook.SKILL_MAX_LEVEL, "Test Profile should max skill %s." % String(sid))
	check(p.health == p.max_health and p.focus == p.focus_max, "Test Profile should start fully healed with full focus.")
	check(Save.path() == "user://petalbound_test_profile.json" and Save.exists(), "Test Profile should save to its own save slot.")
	if failures == 0:
		print("Test Profile smoke test passed: isolated save, max level, all items/weapons/gear/skills, fully ranked class lines and full vitals.")
	Save.erase()
	Save.path_override = ""
	game.free()
	quit(1 if failures > 0 else 0)
