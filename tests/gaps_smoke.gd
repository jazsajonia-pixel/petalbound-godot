extends SceneTree
## Headless test for the "close known gaps" pass. Exercises real game code:
## Emberleaf Vale (size, biome, reachability from the start, actors on valid
## ground, the Starfall gate), the Emberbark side guardian (no fifth Moonseed,
## reward once, quest), boss telegraphs (lane/cone/spokes match the real
## attack, "!" during wind-ups, phase-two quake hit area), the visible cloak
## layer (equip/unequip/colours/facing order) and the textured rift dungeon.

const Save := preload("res://scripts/systems/save.gd")
const Settings := preload("res://scripts/systems/settings.gd")
const DB := preload("res://scripts/data/db.gd")
const Inv := preload("res://scripts/systems/inventory.gd")
const QuestSys := preload("res://scripts/systems/quests.gd")
const BossScript := preload("res://scripts/actors/boss.gd")
const Rifts := preload("res://scripts/systems/rifts.gd")
const World := preload("res://scripts/world/world.gd")

var game: Node
var player: CharacterBody2D
var failures: PackedStringArray = []
var passes := 0


func _initialize() -> void:
	Settings.path_override = "user://petalbound_gaps_settings.cfg"
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


func _run_test() -> void:
	Save.path_override = "user://petalbound_gaps_test_save.json"
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

	_test_region_layout()
	_test_region_reachable()
	await _test_cloak()
	await _test_telegraphs()
	await _test_emberbark()
	await _test_rift_tiles()

	Save.erase()
	Settings.erase()
	if failures.size() > 0:
		push_error("%d gap checks failed (%d passed)." % [failures.size(), passes])
		quit(1)
		return
	print("Gaps smoke test passed (%d checks): Emberleaf Vale layout and reachability, Emberbark side guardian and quest, boss telegraph shapes and quake, visible cloak layer and textured rift dungeon all work." % passes)
	game.get("audio").call("stop_all")
	game.free()
	quit(0)


func _tile(tx: float, ty: float) -> Vector2:
	return Vector2(tx * 16.0, ty * 16.0)


# ---------------------------------------------------------------- region
func _test_region_layout() -> void:
	var w: Node = game.world
	check(w.tiles.x == 400, "The world should be 400 tiles wide with Moonpetal and Emberleaf Vale (got %d)." % w.tiles.x)
	check(w.world_size.x == 400 * 16.0, "world_size should follow the new width.")
	check(w.biome_image.get_width() == 400 and w.field_image.get_width() == 400 * w.field_res, "Biome and field maps should both grow.")
	check((w.data["biome_names"] as Array).size() >= 9 and String(w.data["biome_names"][World.EMBER]) == "Emberleaf Vale", "Biome 8 should be named Emberleaf Vale.")
	check(w.biome_at(_tile(390, 110)) == World.EMBER, "The vale interior should be biome 8 (got %d)." % w.biome_at(_tile(390, 110)))
	check(w.biome_at(_tile(280, 92)) == World.STARFALL, "Starfall Rise should be untouched.")
	check(w.region_name(_tile(362, 98)) == "Cinderbrook Camp", "The plaza should be named Cinderbrook Camp (got %s)." % w.region_name(_tile(362, 98)))
	check(w.region_name(_tile(390, 112)) == "Emberleaf Vale", "The vale should report its region name (got %s)." % w.region_name(_tile(390, 112)))
	check(DB.REGION_MUSIC.size() >= 9, "Every biome needs a music entry, including both new eastern biomes.")
	# the Starfall gate: no props on the Ember Road where the wall used to be
	var blocked := 0
	for x in range(296, 312):
		var y := 94.0 + (x - 294) * (2.0 / 6.0)
		if w.is_solid(_tile(x + 0.5, y + 0.3)):
			blocked += 1
	check(blocked == 0, "The Ember Road through Starfall's east wall should be clear (%d blocked samples)." % blocked)
	# Starfall's wall still exists north and south of the gate
	var wall_props := 0
	for pr in w.data["props"]:
		if String(pr["k"]) in ["big_orange", "tree_dead"] and absf(float(pr["x"]) - (400 - 2.5) * 16.0) < 4.0:
			wall_props += 1
	check(wall_props > 20, "Emberleaf's east boundary should remain walled (%d trees)." % wall_props)
	# content counts
	var npc_ok := false
	for n in w.data["npcs"]:
		if n["id"] == "rowan":
			npc_ok = true
	check(npc_ok, "Rowan should live in Cinderbrook Camp.")
	var ember_enemies := 0
	for e in w.data["enemies"]:
		if float(e["x"]) >= 336 * 16.0:
			ember_enemies += 1
			check(not w.is_water(Vector2(e["x"], e["y"])) and not w.is_solid(Vector2(e["x"], e["y"])), "Enemy %s at %s should be on open ground." % [e["s"], str(Vector2(e["x"], e["y"]))])
	check(ember_enemies >= 12, "The vale should have monster camps (got %d)." % ember_enemies)
	var props_in_vale := 0
	for pr in w.data["props"]:
		if float(pr["x"]) >= 336 * 16.0:
			props_in_vale += 1
	check(props_in_vale > 300 and props_in_vale < 2600, "The vale should be dressed but stay light for phones (%d props)." % props_in_vale)


## 8px flood fill over walkable ground (Mallow is ~10px wide, so each cell
## needs its centre and four 4px neighbours free).
func _walkable(p: Vector2) -> bool:
	var w: Node = game.world
	if p.x < 8 or p.y < 8 or p.x > w.world_size.x - 8 or p.y > w.world_size.y - 8:
		return false
	for o in [Vector2.ZERO, Vector2(4, 0), Vector2(-4, 0), Vector2(0, 4), Vector2(0, -4)]:
		if w.is_water(p + o) or w.is_solid(p + o):
			return false
	return true


func _test_region_reachable() -> void:
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
			if not _walkable((Vector2(n) + Vector2(0.5, 0.5)) * step):
				seen[n.y * gw + n.x] = 2
				continue
			seen[n.y * gw + n.x] = 1
			queue.append(n)
	var reach := func(p: Vector2) -> bool:
		# within 16px of a reached cell (actors stand next to, not inside, props)
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				var cx := int(p.x / step) + dx
				var cy := int(p.y / step) + dy
				if cx >= 0 and cy >= 0 and cx < gw and cy < gh and seen[cy * gw + cx] == 1:
					return true
		return false
	var targets := {"Cinderbrook plaza": _tile(362, 98), "Emberbark hollow": _tile(331, 62), "Amber Pond shore": _tile(316, 118)}
	for c in w.data["chests"]:
		if String(c["id"]).begins_with("c_ember"):
			targets[String(c["id"])] = Vector2(c["x"], c["y"]) + Vector2(0, 10)
	for s in w.data["shrines"]:
		if s["id"] == "cinderbrook":
			targets["waystone"] = Vector2(s["x"], s["y"])
	for n in w.data["npcs"]:
		if n["id"] == "rowan":
			targets["Rowan"] = Vector2(n["x"], n["y"])
	for name in targets:
		check(reach.call(targets[name]), "%s should be reachable on foot from the start (%s)." % [name, str(targets[name])])
	check(targets.size() >= 8, "All vale landmarks, chests, the waystone and Rowan should be tested (%d)." % targets.size())


# ---------------------------------------------------------------- cloak
func _test_cloak() -> void:
	var cl: Node2D = player.cloak_layer
	check(cl != null, "Mallow should have a cloak layer.")
	if cl == null:
		return
	check(player.equipped.get("cloak", "") == "plum_cloak", "A new journey starts in the Plum Wayfarer Cloak.")
	await frames(2)
	check(cl.visible and cl.is_worn(), "The starting cloak should be drawn on Mallow.")
	check(player.visible_gear.get("cloak", "") == "plum_cloak", "The cloak should be listed in visible gear.")
	check(cl.main_col.is_equal_approx(Color("9a6ac0")), "The plum cloak should use its own colours.")
	check(player.unequip("cloak"), "Unequipping the cloak should work.")
	await frames(2)
	check(not cl.visible and not player.visible_gear.has("cloak"), "Removing the cloak should hide the cape immediately.")
	Inv.add(player, "emberleaf_mantle", 1)
	if not player.inventory.has("emberleaf_mantle"):
		player.inventory.append("emberleaf_mantle")
	check(player.equip("emberleaf_mantle"), "The Emberleaf Mantle should be equippable.")
	await frames(2)
	check(cl.visible and cl.main_col.is_equal_approx(Color("ffad66")), "A different cloak should recolour the cape (got %s)." % cl.main_col.to_html(false))
	player._set_facing(Vector2.UP)
	await frames(3)
	check(cl.in_front() and cl.get_index() > player.sprite.get_index(), "Facing away, the cape should draw over Mallow's back.")
	player._set_facing(Vector2.DOWN)
	await frames(3)
	check(not cl.in_front() and cl.get_index() < player.sprite.get_index(), "Facing the camera, the cape should hang behind the body.")
	player._set_facing(Vector2.LEFT)
	await frames(3)
	check(cl.dir == "left" and cl.get_index() < player.sprite.get_index(), "Side views should trail the cape behind.")
	# back to the starting cloak for the rest of the run
	player.equip("plum_cloak")
	await frames(1)
	check(cl.visible and cl.item_id == "plum_cloak", "Re-equipping the plum cloak should show it again.")


# ---------------------------------------------------------------- telegraphs
func _find_boss(id: String) -> Node:
	for b in game.bosses:
		if b.boss_id == id:
			return b
	return null


func _telegraphs() -> Array:
	var out: Array = []
	for c in game.fx.get_children():
		if c.get("shape") != null and c.get("duration") != null and not c.is_queued_for_deletion():
			out.append(c)
	return out


func _clear_telegraphs() -> void:
	for t in _telegraphs():
		t.free()


func _start_attack(b: Node, attack: String) -> void:
	var pat: Array = b.attack_pattern()
	var idx := pat.find(attack)
	check(idx >= 0, "%s should be in %s's pattern %s." % [attack, b.species, str(pat)])
	b.pattern_i = max(idx, 0)
	b.state = "idle"
	_clear_telegraphs()
	b._next_attack()


func _test_telegraphs() -> void:
	var b: Node = _find_boss("emberbark")
	check(b != null, "The Emberbark should be spawned in its hollow.")
	if b == null:
		return
	var home: Vector2 = b.global_position
	player.global_position = home + Vector2(0, 70)
	player.invulnerable_left = 0.0
	b.awake = true
	b.set_physics_process(false)
	# charge: a lane as long as the dash and as wide as its contact reach
	_start_attack(b, "charge")
	var lanes := _telegraphs().filter(func(t): return t.shape == "lane")
	check(lanes.size() == 1, "A charge should show one lane warning (got %d)." % lanes.size())
	if lanes.size() == 1:
		var ln = lanes[0]
		check(is_equal_approx(ln.length, BossScript.CHARGE_SPEED * BossScript.CHARGE_TIME + 22.0), "The lane should cover the full charge distance.")
		check(is_equal_approx(ln.width, (22.0 + 4.0) * 2.0), "The lane width should match the contact hit area.")
		check(ln.dir.dot((player.global_position - home).normalized()) > 0.99, "The lane should point where the charge will go.")
	check(b.is_winding(), "The boss should be winding up during a charge telegraph.")
	b._physics_process(0.016)
	check(b.warn.visible, "A '!' should show above the boss during wind-ups.")
	# volley: a cone wind-up before the first shot, aimed where the shots go
	_start_attack(b, "spread")
	check(b.state == "volley_wind", "A volley should start with a wind-up (got %s)." % b.state)
	var cones := _telegraphs().filter(func(t): return t.shape == "cone")
	check(cones.size() == 1, "A volley should show a cone warning (got %d)." % cones.size())
	if cones.size() == 1:
		var spread := 3
		check(cones[0].half_angle >= BossScript.SPREAD_STEP * (spread - 1) / 2.0, "The cone should cover the whole spread.")
	# ring: one spoke per projectile, at the real angles
	_start_attack(b, "ring")
	var sp := _telegraphs().filter(func(t): return t.shape == "spokes")
	check(sp.size() == 1 and sp[0].spokes == b.ring_count() and is_equal_approx(sp[0].offset, b._ring_off), "The ring warning should match the real projectile count and angles.")
	# phase two: quake joins the pattern, warning circle == hit radius
	check(not b.attack_pattern().has("quake"), "The quake should be reserved for phase two.")
	b.enraged = true
	check(b.attack_pattern().has("quake"), "Enraged bosses should gain the quake.")
	_start_attack(b, "quake")
	var circles := _telegraphs().filter(func(t): return t.shape == "circle")
	check(circles.size() == 1 and is_equal_approx(circles[0].radius, BossScript.QUAKE_RADIUS), "The quake warning should be exactly the hit radius.")
	# outside the circle: no damage
	player.global_position = home + Vector2(0, BossScript.QUAKE_RADIUS + 14.0)
	player.invulnerable_left = 0.0
	var hp0: int = player.health
	b.state_t = 0.0
	b._physics_process(0.016)
	check(player.health == hp0, "Standing outside the quake circle should be safe.")
	# inside: damage lands
	_start_attack(b, "quake")
	player.global_position = home + Vector2(0, BossScript.QUAKE_RADIUS - 14.0)
	player.invulnerable_left = 0.0
	hp0 = player.health
	b.state_t = 0.0
	b._physics_process(0.016)
	check(player.health < hp0, "Standing inside the quake circle should hurt (hp %d -> %d)." % [hp0, player.health])
	# every circle telegraph is drawn as a true circle (matches distance checks)
	var src := FileAccess.get_file_as_string("res://scripts/core/fx.gd")
	check(src.find("Vector2(1.0, 0.62)") == -1, "Telegraph circles should no longer be squashed into ellipses.")
	b.enraged = false
	b.state = "idle"
	b.awake = false
	b.global_position = home
	_clear_telegraphs()
	player.health = player.max_health
	player.global_position = home + Vector2(0, 160)


# ---------------------------------------------------------------- emberbark
func _test_emberbark() -> void:
	var b: Node = _find_boss("emberbark")
	if b == null:
		return
	check(game.is_side_boss(b), "The Emberbark should be a side guardian.")
	check(b.title == "THE EMBERBARK", "The Emberbark should have its own title.")
	check(int(b.mat.get_shader_parameter("swap_count")) >= 3, "The Emberbark should be recoloured to stand apart from the Briarback.")
	check(game.quest_text().find("Emberbark") == -1, "The Moonseed objective should not list the Emberbark.")
	# Rowan's patrol first, so the Emberbark journey unlocks
	game._quest_on_talk("rowan")
	var patrol: Dictionary = QuestSys.entry(game.quests, "q_ember_patrol")
	check(patrol["s"] == QuestSys.STATE_ACTIVE, "Talking to Rowan should start Ember Patrol.")
	for i in range(5):
		game._quest_progress("kill_kind", "spiderred")
	check(patrol["s"] == QuestSys.STATE_DONE, "Five Ember Spiders should finish the patrol.")
	var seeds: int = game.moonseeds.size()
	var coins: int = player.petalcoins
	var shards := Inv.count(player, "moon_shard")
	b.awake = true
	b.hp = 1
	b.hurt(5, player.global_position, 0.0)
	await frames(2)
	check(b.defeated, "The Emberbark should fall.")
	check(game.defeated_bosses.has("emberbark") and game.flags.get("emberbark_felled", false), "Its defeat should be recorded.")
	check(game.moonseeds.size() == seeds, "The Emberbark must not grant a Moonseed.")
	var seed_pickups := 0
	for pk in game.pickups:
		if pk["kind"] == "moonseed" and pk["id"] == "emberbark":
			seed_pickups += 1
	check(seed_pickups == 0, "No fifth Moonseed should spawn.")
	check(player.petalcoins > coins, "The Emberbark should pay coins.")
	check(Inv.count(player, "moon_shard") == shards + 2, "The Emberbark should give two Moon Shards.")
	var after_coins: int = player.petalcoins
	game._side_boss_reward(b)
	check(player.petalcoins == after_coins and Inv.count(player, "moon_shard") == shards + 2, "The side reward must only pay once.")
	# claiming the patrol unlocks Fell the Emberbark, already earned
	game._quest_on_talk("rowan")
	var fell: Dictionary = QuestSys.entry(game.quests, "q_emberbark")
	check(patrol["s"] == QuestSys.STATE_CLAIMED, "The patrol should be claimed.")
	check(fell["s"] == QuestSys.STATE_DONE, "Fell the Emberbark should count a kill made before the journey began (state %s)." % str(fell["s"]))
	game._quest_on_talk("rowan")
	check(fell["s"] == QuestSys.STATE_CLAIMED and Inv.count(player, "moon_shard") == shards + 3, "Turning in should pay once.")
	game._quest_on_talk("rowan")
	check(Inv.count(player, "moon_shard") == shards + 3, "Repeat turn-ins should not pay again.")
	# reload: still down, still no Moonseed
	game.save_game()
	var d: Dictionary = Save.read()
	check((d.get("bosses", []) as Array).has("emberbark"), "The defeat should be saved.")


# ---------------------------------------------------------------- rift tiles
func _test_rift_tiles() -> void:
	check(Rifts.tile_texture(Rifts.TILE_FLOOR) != null, "The rift floor tile should load from the tileset.")
	var ft: Texture2D = Rifts.tile_texture(Rifts.TILE_FLOOR)
	if ft != null:
		check(ft.get_width() == 16 and ft.get_height() == 16, "Rift tiles should be single 16px tiles.")
	check(Rifts.tile_texture(Rifts.TILE_WALL) != null, "The rift wall tile should load.")
	var R: Node = game.rifts
	var hg: Array = game.world.data["landmarks"]["hearthgrove"]
	player.global_position = Vector2(hg[0], hg[1])
	R._since = 0.0
	R._close_entrance()
	check(R.try_spawn(), "A rift should open for the tile test.")
	player.level = 20
	player.global_position = R.entrance["point"]
	check(R.enter(), "Entering the rift should work.")
	await frames(2)
	var dungeon: Node = game.get_node_or_null("RiftDungeon")
	check(dungeon != null, "The rift dungeon should be built.")
	if dungeon != null:
		var tiles := 0
		var floors := 0
		var props := 0
		for c in dungeon.get_children():
			if c is Sprite2D and c.has_meta("rift_tile"):
				tiles += 1
				if c.texture_repeat == CanvasItem.TEXTURE_REPEAT_ENABLED:
					floors += 1
				else:
					props += 1
		check(floors >= 20, "Rift floors and walls should use repeating tiles (got %d)." % floors)
		check(props >= 10, "Rift rooms should have pillars, crystals and floor details (got %d)." % props)
	R.on_player_died()
	game._restore_world_camera()
	R._close_entrance()
	await frames(1)
	check(not R.active and game.world.visible, "Leaving the rift should restore the world.")
