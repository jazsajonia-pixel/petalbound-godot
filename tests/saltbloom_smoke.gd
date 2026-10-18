extends SceneTree
## Headless test for Saltbloom Shoals, the coast region east of Emberleaf Vale.
## Exercises real game code: world growth and biome, the gap in the vale's east
## grove wall, reachability of Brinewick / the reef / chests / Marlo on foot, the
## lagoon islet (reachable only by swimming), the new coast monsters and their
## loot, the Brinehorn side guardian (rewards once, no Moonseed), Marlo's quests,
## the Tidecaller Trident, the Saltkoi fish, region music and save/load.

const Save := preload("res://scripts/systems/save.gd")
const Settings := preload("res://scripts/systems/settings.gd")
const DB := preload("res://scripts/data/db.gd")
const CD := preload("res://scripts/data/combat_data.gd")
const Eco := preload("res://scripts/data/economy.gd")
const Inv := preload("res://scripts/systems/inventory.gd")
const QuestSys := preload("res://scripts/systems/quests.gd")
const World := preload("res://scripts/world/world.gd")

var game: Node
var player: CharacterBody2D
var failures: PackedStringArray = []
var passes := 0


func _initialize() -> void:
	Settings.path_override = "user://petalbound_salt_settings.cfg"
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


func _tile(tx: float, ty: float) -> Vector2:
	return Vector2(tx * 16.0, ty * 16.0)


func _run_test() -> void:
	Save.path_override = "user://petalbound_salt_test_save.json"
	Save.erase()
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(game)
	await process_frame
	await physics_frame
	game.hud.title_button.pressed.emit()
	await process_frame
	game.hud.confirm_character()
	await process_frame
	await physics_frame
	player = game.player
	for e in game.enemies:
		e.set_physics_process(false)

	_test_layout()
	_test_reachable()
	_test_data()
	await _test_brinehorn()
	await _test_save()

	Save.erase()
	Settings.erase()
	if failures.size() > 0:
		push_error("%d Saltbloom checks failed (%d passed)." % [failures.size(), passes])
		quit(1)
		return
	print("Saltbloom smoke test passed (%d checks): coast region size and biome, Tide Road gate, Brinewick/reef/chests/Marlo reachable, swim-only islet, coast monsters and pearls, Brinehorn side guardian, Marlo's quests, Tidecaller Trident, Saltkoi, music and save/load all work." % passes)
	game.get("audio").call("stop_all")
	game.free()
	quit(0)


func _test_layout() -> void:
	var w: Node = game.world
	check(w.tiles.x == 456, "Saltbloom should grow the world to 456 tiles (got %d)." % w.tiles.x)
	check(w.biome_at(_tile(412, 120)) == World.SALT, "The coast interior should be biome 9 (got %d)." % w.biome_at(_tile(412, 120)))
	check(w.biome_at(_tile(370, 110)) == World.EMBER, "Emberleaf Vale should be untouched.")
	check((w.data["biome_names"] as Array).size() == 10 and w.data["biome_names"][World.SALT] == "Saltbloom Shoals", "Biome 9 should be named Saltbloom Shoals.")
	check(w.region_name(_tile(420, 100)) == "Brinewick", "The plaza should be Brinewick (got %s)." % w.region_name(_tile(420, 100)))
	check(w.region_name(_tile(439, 66)) == "Saltbloom Lagoon", "The lagoon should be named (got %s)." % w.region_name(_tile(439, 66)))
	check(w.region_name(_tile(435, 140)) == "Brinehorn Reef", "The reef should be named (got %s)." % w.region_name(_tile(435, 140)))
	check(w.region_name(_tile(410, 150)) == "Saltbloom Shoals", "Open coast should report the region name (got %s)." % w.region_name(_tile(410, 150)))
	# open sea along the east edge, a real lagoon, and dry ground on the islet
	check(w.is_water(_tile(454, 40)) and w.is_water(_tile(454, 140)), "The east edge should be open sea.")
	check(w.is_water(_tile(439, 66)), "Saltbloom Lagoon should be water.")
	check(not w.is_water(_tile(439, 74)), "The lagoon islet should be dry land.")
	check(w.field_at(_tile(402, 100)).r > 0.25 and w.field_at(_tile(420, 100)).r > 0.25, "The Tide Road should be stamped through the gate to Brinewick.")
	# the vale's east grove wall has a gap for the road
	var gap_blocked := 0
	for ty in range(World.SALT_GATE_ROWS[0] + 1, World.SALT_GATE_ROWS[1]):
		if w.is_solid(_tile(397.5, ty + 0.5)) or w.is_solid(_tile(395.5, ty + 0.5)):
			gap_blocked += 1
	check(gap_blocked == 0, "The Tide Road gate in the vale's east wall should be open (%d blocked rows)." % gap_blocked)
	var salt_props := 0
	var salt_kinds: Dictionary = {}
	for pr in w.data["props"]:
		if float(pr["x"]) >= 400 * 16.0:
			salt_props += 1
			salt_kinds[pr["k"]] = true
	check(salt_props > 120 and salt_props < 1800, "The coast should be furnished but not packed (%d props)." % salt_props)
	for k in ["boat", "fishnet", "palm", "hut_straw", "boulder_teal"]:
		check(salt_kinds.has(k), "The coast should use the %s prop." % k)
	check(w.prop_defs.has("boat") and w.prop_defs.has("fishnet_full") and w.prop_defs.has("sail"), "New harbour props should be registered.")


func _walkable(p: Vector2) -> bool:
	var w: Node = game.world
	if p.x < 8 or p.y < 8 or p.x > w.world_size.x - 8 or p.y > w.world_size.y - 8:
		return false
	for o in [Vector2.ZERO, Vector2(4, 0), Vector2(-4, 0), Vector2(0, 4), Vector2(0, -4)]:
		if w.is_water(p + o) or w.is_solid(p + o):
			return false
	return true


## 8px flood fill over dry walkable ground from the start; swim_ok also lets
## the fill cross water (Mallow can swim).
func _flood(swim_ok: bool) -> Dictionary:
	var w: Node = game.world
	var step := 8.0
	var gw := int(w.world_size.x / step)
	var gh := int(w.world_size.y / step)
	var seen := PackedByteArray()
	seen.resize(gw * gh)
	var start: Vector2 = game.player.global_position
	var queue: Array = [Vector2i(int(start.x / step), int(start.y / step))]
	seen[queue[0].y * gw + queue[0].x] = 1
	var head := 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if n.x < 0 or n.y < 0 or n.x >= gw or n.y >= gh or seen[n.y * gw + n.x] != 0:
				continue
			var p := (Vector2(n) + Vector2(0.5, 0.5)) * step
			var ok: bool = _walkable(p) or (swim_ok and w.is_water(p) and not w.is_solid(p) and p.x < w.world_size.x - 8)
			if not ok:
				seen[n.y * gw + n.x] = 2
				continue
			seen[n.y * gw + n.x] = 1
			queue.append(n)
	return {"seen": seen, "gw": gw, "gh": gh, "step": step}


func _reached(f: Dictionary, p: Vector2) -> bool:
	var step: float = f["step"]
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var cx := int(p.x / step) + dx
			var cy := int(p.y / step) + dy
			if cx >= 0 and cy >= 0 and cx < f["gw"] and cy < f["gh"] and f["seen"][cy * f["gw"] + cx] == 1:
				return true
	return false


func _test_reachable() -> void:
	var w: Node = game.world
	var dry := _flood(false)
	var targets := {"Brinewick plaza": _tile(420, 101), "Brinehorn Reef": _tile(435, 136), "lagoon shore": _tile(427, 86)}
	for c in w.data["chests"]:
		if String(c["id"]).begins_with("c_salt") and c["id"] != "c_salt_trident":
			targets[String(c["id"])] = Vector2(c["x"], c["y"]) + Vector2(0, 10)
	for s in w.data["shrines"]:
		if s["id"] == "brinewick":
			targets["waystone"] = Vector2(s["x"], s["y"])
	for n in w.data["npcs"]:
		if n["id"] == "marlo":
			targets["Marlo"] = Vector2(n["x"], n["y"])
	for name in targets:
		check(_reached(dry, targets[name]), "%s should be reachable on foot from the start (%s)." % [name, str(targets[name])])
	check(targets.size() >= 7, "All coast landmarks, chests, the waystone and Marlo should be tested (%d)." % targets.size())
	var islet := _tile(439, 74) + Vector2(0, 10)
	check(not _reached(dry, islet), "The trident islet should not be reachable without swimming.")
	check(_reached(_flood(true), islet), "The trident islet should be reachable by swimming across the lagoon.")


func _test_data() -> void:
	var w: Node = game.world
	var kinds: Dictionary = {}
	for e in w.data["enemies"]:
		if float(e["x"]) >= 400 * 16.0:
			kinds[e["s"]] = int(kinds.get(e["s"], 0)) + 1
			check(not w.is_water(Vector2(e["x"], e["y"])) and not w.is_solid(Vector2(e["x"], e["y"])), "%s at %s should stand on open ground." % [e["s"], str(Vector2(e["x"], e["y"]) / 16.0)])
	for k in ["axolotblue", "mollusc", "kappagreen", "octopus"]:
		check(kinds.get(k, 0) >= 3, "Saltbloom should have at least three %s (got %d)." % [k, kinds.get(k, 0)])
		check(DB.ENEMIES.has(k) and ResourceLoader.exists(DB.NA + "monsters/%s.png" % k), "%s should have stats and a sprite sheet." % k)
		check(Eco.LOOT_GROUP.get(k, "") == "tide", "%s should drop the tide loot group." % k)
	var live := 0
	for e in game.enemies:
		if e.global_position.x >= 400 * 16.0:
			live += 1
	check(live >= 15, "Coast enemies should spawn in the live game (%d)." % live)
	# items, weapon, fish, music
	check(DB.ITEMS.has("brine_pearl") and DB.ITEMS["brine_pearl"]["type"] == "material", "Brine Pearl should be a material.")
	check(DB.WEAPON_VARIANTS.has("tidecaller_trident") and CD.WEAPONS.has("tidecaller_trident"), "The Tidecaller Trident should be a sourced weapon with a combat profile.")
	check(ResourceLoader.exists(DB.icon_path("tidecaller_trident")) and ResourceLoader.exists(DB.hand_path("tidecaller_trident")), "The trident's icon and held art should load.")
	player.give_item("tidecaller_trident")
	check(player.equip_weapon("tidecaller_trident"), "The trident should equip.")
	check(player.weapon_sprite.texture != null and player.weapon_sprite.texture.resource_path == DB.hand_path("tidecaller_trident"), "The trident should render in Mallow's paw.")
	check(DB.FISH.has("saltkoi") and int(DB.FISH["saltkoi"]["biome"]) == World.SALT, "Saltkoi should be fished on the coast.")
	check(DB.REGION_MUSIC.size() == 10 and DB.REGION_MUSIC[World.SALT] == "coast", "The coast should have its own music.")
	check(ResourceLoader.exists("res://assets/packs/ninja_adventure/audio/music/coast.ogg"), "The coast track should be imported.")
	var trident_chest := false
	for c in w.data["chests"]:
		if c["id"] == "c_salt_trident":
			trident_chest = c["item"] == "tidecaller_trident" and c.get("big", false)
	check(trident_chest, "The lagoon islet should hold the trident in a big chest.")
	check(game.npcs.any(func(n): return n.npc_id == "marlo"), "Old Marlo should be in Brinewick.")
	check(DB.dialogue("marlo", 0, {}).size() >= 3 and DB.dialogue("marlo", 0, {"brinehorn_felled": true}).size() >= 1, "Marlo should have dialogue before and after the Brinehorn.")


func _find_boss(id: String) -> Node:
	for b in game.bosses:
		if b.boss_id == id:
			return b
	return null


func _test_brinehorn() -> void:
	var b: Node = _find_boss("brinehorn")
	check(b != null, "The Brinehorn should be placed on the reef.")
	if b == null:
		return
	check(game.is_side_boss(b), "The Brinehorn should be a side guardian.")
	check(b.title == "THE BRINEHORN", "The Brinehorn should have its own title (got %s)." % b.title)
	check(b.sprite.sprite_frames.has_animation("attack") and b.sprite.sprite_frames.get_frame_count("idle") == 4, "The squid's frames should be cut from its sheets.")
	check(game.quest_text().find("Brinehorn") == -1, "The Moonseed objective should not list the Brinehorn.")
	game._quest_on_talk("marlo")
	var lines: Dictionary = QuestSys.entry(game.quests, "q_salt_lines")
	check(lines["s"] == QuestSys.STATE_ACTIVE, "Talking to Marlo should start Cut Lines.")
	for i in range(5):
		game._quest_progress("kill_kind", "mollusc")
	check(lines["s"] == QuestSys.STATE_DONE, "Five Coral Crawlers should finish Cut Lines.")
	var seeds: int = game.moonseeds.size()
	var coins: int = player.petalcoins
	var shards := Inv.count(player, "moon_shard")
	b.awake = true
	b.hp = 1
	b.hurt(5, player.global_position, 0.0)
	await frames(2)
	check(b.defeated and game.flags.get("brinehorn_felled", false), "The Brinehorn should fall and be recorded.")
	check(game.moonseeds.size() == seeds, "The Brinehorn must not grant a Moonseed.")
	check(player.petalcoins > coins and Inv.count(player, "moon_shard") == shards + 2, "The Brinehorn should pay coins and two Moon Shards.")
	var after: int = player.petalcoins
	game._side_boss_reward(b)
	check(player.petalcoins == after, "The side reward must only pay once.")
	game._quest_on_talk("marlo")
	var fell: Dictionary = QuestSys.entry(game.quests, "q_brinehorn")
	check(fell["s"] == QuestSys.STATE_DONE, "Still the Brinehorn should count a kill made before it unlocked (state %s)." % str(fell["s"]))
	game._quest_on_talk("marlo")
	check(fell["s"] == QuestSys.STATE_CLAIMED, "Turning in Still the Brinehorn should work.")
	# pearls quest
	var pearls: Dictionary = QuestSys.entry(game.quests, "q_salt_pearls")
	if pearls["s"] == QuestSys.STATE_AVAILABLE:
		game._quest_on_talk("marlo")
	Inv.add(player, "brine_pearl", 3)
	game._quest_progress("collect", "brine_pearl", 3)
	game._quest_on_talk("marlo")
	check(pearls["s"] == QuestSys.STATE_CLAIMED or pearls["s"] == QuestSys.STATE_DONE, "Pearls for the Nets should complete with three pearls (state %s)." % str(pearls["s"]))


func _test_save() -> void:
	game.save_game()
	var d: Dictionary = Save.read()
	check(d.get("flags", {}).get("brinehorn_felled", false), "The Brinehorn's defeat should be saved.")
	check(d.get("bosses", []).has("brinehorn"), "Defeated bosses should include the Brinehorn.")
