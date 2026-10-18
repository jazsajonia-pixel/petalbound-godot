extends SceneTree
## Headless test for the arsenal pass: weapon bar (max 5, tap to switch,
## lockout, save/load + migration, HUD layout), the hold-to-charge framework
## (tap vs hold, no hold-repeat on signature weapons, charge indicator, stick
## aim without target lock, cancel rules, slowed movement), every new weapon
## (Oakwood/Cloudstride staffs, Twin Moon Katanas, Ironbloom Gauntlet,
## Thornlash Whip, Starweave Gloves, Direwolf Claws), the Mythical tier, and
## the Nightbloom arts Petal Rush and Vine Hook. Real game code, no mocks.

const Save := preload("res://scripts/systems/save.gd")
const Settings := preload("res://scripts/systems/settings.gd")
const DB := preload("res://scripts/data/db.gd")
const CD := preload("res://scripts/data/combat_data.gd")
const Eco := preload("res://scripts/data/economy.gd")
const Build := preload("res://scripts/combat/build.gd")
const ClassBook := preload("res://scripts/data/classdb.gd")
const StatusFx := preload("res://scripts/combat/status.gd")
const RUI := preload("res://scripts/ui/rarity_ui.gd")
const UIScreens := preload("res://scripts/ui/build_screens.gd")

const NEW_WEAPONS := ["oakwood_staff", "cloudstride_staff", "twin_moon_katanas", "ironbloom_gauntlet", "thornlash_whip", "starweave_gloves", "direwolf_claws"]

var game: Node
var player: CharacterBody2D
var failures: PackedStringArray = []
var passes := 0
var spawned: Array = []
var walls: Array = []
var arena := Vector2.ZERO


func _initialize() -> void:
	Settings.path_override = "user://petalbound_arsenal_settings.cfg"
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


func dummy(offset: Vector2, hp := 400) -> Node:
	var e := Dummy.new()
	e.setup(game, "mushroom", arena + offset)
	game.entities.add_child(e)
	game.enemies.append(e)
	e.max_hp = hp
	e.hp = hp
	e.respawn_at = -1.0
	e.set_physics_process(false)
	spawned.append(e)
	return e


func wall(offset: Vector2, size: Vector2) -> StaticBody2D:
	var b := StaticBody2D.new()
	b.collision_layer = 1
	b.collision_mask = 0
	var cs := CollisionShape2D.new()
	var r := RectangleShape2D.new()
	r.size = size
	cs.shape = r
	b.add_child(cs)
	game.add_child(b)
	b.global_position = arena + offset
	walls.append(b)
	return b


func clear_all() -> void:
	for e in spawned:
		if is_instance_valid(e):
			game.enemies.erase(e)
			e.queue_free()
	spawned.clear()
	for w in walls:
		if is_instance_valid(w):
			w.queue_free()
	walls.clear()
	if player.clone_ref != null and is_instance_valid(player.clone_ref):
		player.clone_ref.queue_free()
	player.clone_ref = null
	player.current_target = null
	player.manual_target = null


func reset_player() -> void:
	release_all()
	player.charge.cancel()
	player.charge.special_cd = 0.0
	player.global_position = arena
	player.velocity = Vector2.ZERO
	player.knockback = Vector2.ZERO
	player.state = player.State.MOVE
	player.attack_cooldown = 0.0
	player._attack_buffer = 0.0
	player._lock_t = 0.0
	player.roll_t = 0.0
	player._dash_speed = 0.0
	player._charge = {}
	player._rush = {}
	player._switch_lock = 0.0
	player.invulnerable_left = 0.0
	player.input_enabled = true
	player.focus = player.focus_max
	player.buffs.clear()
	for k in player.skill_cd.keys():
		player.skill_cd[k] = 0.0
	player._set_facing(Vector2.RIGHT)


func hold(id: String) -> void:
	player._set_weapon_index(player.weapons_owned.find(id))
	reset_player()


## Press attack, keep it held `t` seconds.
func press_for(t: float) -> void:
	Input.action_press("attack")
	await frames(1)
	await seconds(t)


func let_go() -> void:
	Input.action_release("attack")
	await frames(2)


func spot_ok(c: Vector2) -> bool:
	for i in range(8):
		var d := Vector2.from_angle(float(i) * PI / 4.0)
		if not game.line_clear(c + Vector2(0, -4), c + Vector2(0, -4) + d * 150.0):
			return false
		for k in range(0, 9):
			var q := c + d * 18.0 * float(k)
			if game.world.is_water(q) or game.world.is_solid(q) or game.world.is_solid(q + Vector2(0, -6)):
				return false
	return true


func find_arena() -> Vector2:
	var base: Vector2 = player.global_position
	for r in range(0, 2000, 40):
		for a in range(16):
			var c := base + Vector2.from_angle(float(a) * TAU / 16.0) * float(r)
			if spot_ok(c):
				return c
	return base


func _run_test() -> void:
	Save.path_override = "user://petalbound_arsenal_test_save.json"
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
	for e in game.enemies:
		e.set_physics_process(false)
		e.global_position += Vector2(5000, 5000)
	for n in game.get_tree().get_nodes_in_group("npcs"):
		n.global_position += Vector2(5000, 5000)
	await frames(2)
	arena = find_arena()
	player.global_position = arena
	await frames(2)

	_test_data()
	await _test_weapon_bar()
	await _test_hud_bar()
	await _test_tap_vs_hold()
	await _test_katanas()
	await _test_staffs()
	await _test_gauntlet()
	await _test_whip()
	await _test_gloves()
	await _test_claws()
	await _test_petal_rush()
	await _test_vine_hook()
	await _test_save_and_migration()
	_test_itch_equipment_art()
	await _test_satchel_categories_and_sort()

	Save.erase()
	Settings.erase()
	if failures.size() > 0:
		push_error("%d arsenal checks failed (%d passed)." % [failures.size(), passes])
		quit(1)
		return
	print("Arsenal smoke test passed (%d checks): weapon bar (5 max, tap switch, lockout, layout, save/migration), tap vs hold, charge indicator, stick aim without lock, cancel rules, Cloudstride blink + clone, Oakwood no-hold, Moonrend Dash, Energy Burst, whip sweet spot + Wide Lash, Overcharge orb, wolf lifesteal cap + Feral Barrage, Mythical tier, Petal Rush chains and Vine Hook all work." % passes)
	game.get("audio").call("stop_all")
	game.free()
	quit(0)


class Dummy:
	extends "res://scripts/actors/enemy.gd"

	func _physics_process(_delta: float) -> void:
		pass


# ---------------------------------------------------------------- data
func _test_data() -> void:
	var stocked := {}
	for sid in Eco.SHOPS:
		for e in Eco.SHOPS[sid].get("stock", []):
			stocked[String(e.get("id", ""))] = true
	for r in Eco.RECIPES:
		stocked[String(r["id"])] = true
	for id in NEW_WEAPONS:
		var it: Dictionary = DB.ITEMS.get(id, {})
		check(not it.is_empty() and it["type"] == "weapon", "%s should be a weapon item." % id)
		check(ResourceLoader.exists(DB.icon_path(id)) and ResourceLoader.exists(DB.hand_path(id)), "%s should have an icon and a held sprite." % id)
		check(CD.WEAPONS.has(id), "%s should have combat data." % id)
		check(stocked.has(id), "%s should be obtainable (shop or recipe)." % id)
	check(not CD.weapon("oakwood_staff").has("hold"), "The common Oakwood Staff must have no hold effect.")
	var kinds := {}
	for id in NEW_WEAPONS:
		var h: Dictionary = CD.weapon(id).get("hold", {})
		if not h.is_empty():
			kinds[String(h["kind"])] = true
			check(float(h.get("time", 0.0)) > CD.BALANCE["charge_tap"] and float(h.get("cd", 0.0)) > 0.0, "%s hold needs a charge time and cooldown." % id)
	check(kinds.size() == 6, "Six distinct hold effects should exist (%s)." % str(kinds.keys()))
	check(String(DB.ITEMS["cloudstride_staff"]["rarity"]) == "mythical" and DB.RARITIES.has("mythical"), "Cloudstride Staff should be Mythical.")
	check(RUI.STYLE.has("mythical") if "STYLE" in RUI else true, "Mythical should have its own frame style.")
	check(not Eco.GEAR_RARITY_WEIGHTS.has("mythical") and not Eco.GEAR_POOL.has("cloudstride_staff"), "Mythical gear must never be a random drop.")
	for sid in Eco.SHOPS:
		for e in Eco.SHOPS[sid].get("stock", []):
			check(String(e.get("id", "")) != "cloudstride_staff", "The mythical staff must not be sold in shops.")
	for nid in ["petal_rush", "vine_hook"]:
		var d: Dictionary = ClassBook.skill_of(nid)
		check(not d.is_empty() and d["class"] == "nightbloom" and ClassBook.class_of("nightbloom")["skills"].has(nid), "%s should be a Nightbloom art." % nid)
	check(float(ClassBook.skill_of("vine_hook")["cd"]) <= 2.0 and int(ClassBook.skill_of("vine_hook")["cost"]) > 0, "Vine Hook should have a very short cooldown and a Focus cost.")


func _test_itch_equipment_art() -> void:
	var seen_names: Dictionary = {}
	var seen_weapon_icons: Dictionary = {}
	for id in DB.WEAPON_VARIANTS:
		var item: Dictionary = DB.ITEMS.get(id, {})
		check(not item.is_empty() and item.get("type", "") == "weapon", "%s should be a registered weapon variant." % id)
		check(not seen_names.has(item.get("name", "")), "%s should have a distinct display name." % id)
		seen_names[item.get("name", "")] = true
		check(String(item.get("rarity", "")) in DB.RARITIES and int(item.get("damage", 0)) > 0, "%s should have a rarity and damage value." % id)
		var icon := DB.icon_path(id)
		check(CD.WEAPONS.has(id) and not seen_weapon_icons.has(icon), "%s should have a unique icon and combat profile." % id)
		seen_weapon_icons[icon] = true
		check(icon.begins_with(DB.ITCH_RUNTIME + "weapons/") and ResourceLoader.exists(icon) and ResourceLoader.exists(DB.hand_path(id)), "%s sourced icon and held art should load." % id)
		if item.has("classes"):
			# class-locked weapons (the Gravetender's scythe) use sourced art but are
			# granted by their class, not field loot, and need that class to equip
			continue
		check(Eco.GEAR_POOL.has(id), "%s should be obtainable through the existing field equipment loot." % id)
		if not player.weapons_owned.has(id):
			player.give_item(id)
		check(player.equip_weapon(id), "%s should equip through the live weapon system." % id)
		check(player.get_weapon_id() == id and player.weapon_sprite.texture != null and player.weapon_sprite.texture.resource_path == DB.hand_path(id), "%s should render in Mallow's hand when equipped." % id)
		var bonuses := Build.item_stats(id)
		for stat_key in bonuses:
			check(player.stat(stat_key) >= float(bonuses[stat_key]), "%s should apply its active-weapon %s bonus." % [id, stat_key])
	var seen_gear_icons: Dictionary = {}
	for id in DB.GEAR_VARIANTS:
		var item: Dictionary = DB.ITEMS.get(id, {})
		check(not item.is_empty() and String(item.get("type", "")) in DB.EQUIP_SLOTS, "%s should be a registered gear variant." % id)
		check(not seen_names.has(item.get("name", "")), "%s should have a distinct display name." % id)
		seen_names[item.get("name", "")] = true
		check(String(item.get("rarity", "")) in DB.RARITIES and (not Build.item_stats(id).is_empty() or item.has("relic")), "%s should have a rarity and meaningful equipment effect." % id)
		var icon := DB.icon_path(id)
		check(not seen_gear_icons.has(icon) and ResourceLoader.exists(icon), "%s should resolve to a distinct sourced gear icon." % id)
		seen_gear_icons[icon] = true
		check(Eco.GEAR_POOL.has(id), "%s should be obtainable through the existing field equipment loot." % id)
		var slot := String(item["type"])
		if not player.inventory.has(id):
			player.give_item(id)
		if player.equipped.get(slot, "") != id:
			check(player.equip(id), "%s should equip through the live gear system." % id)
		check(player.equipped.get(slot, "") == id, "%s should occupy the %s slot." % [id, slot])
		if item.has("look"):
			check(String(player.visible_gear.get(slot, "")) == id, "%s should apply its unique palette to the live player." % id)
	for id in DB.GEAR_ART.keys():
		check(ResourceLoader.exists(DB.icon_path(id)), "%s should resolve to its sourced gear icon." % id)
	for id in ["slime_gel", "venom_sac", "ember_core", "spirit_dust", "moon_shard", "moontea_vial", "moontea"]:
		check(ResourceLoader.exists(DB.icon_path(id)), "%s should resolve to a sourced material/consumable icon." % id)
	for id in DB.ITEMS.keys():
		var item: Dictionary = DB.ITEMS[id]
		if String(item.get("type", "")) in DB.EQUIP_SLOTS:
			check(ResourceLoader.exists(DB.icon_path(id)), "%s equipment should resolve to an inventory icon." % id)
		if String(item.get("type", "")) == "weapon" and item.has("hand"):
			check(ResourceLoader.exists(DB.icon_path(id)) and ResourceLoader.exists(DB.hand_path(id)), "%s weapon icon and held art should load." % id)
	for id in ClassBook.SKILLS.keys():
		check(ResourceLoader.exists(String(ClassBook.SKILLS[id].get("icon", ""))), "%s skill icon should load." % id)
	for id in ["mossleaf_cap", "briar_mail", "rootgrip_gloves", "trail_leggings", "slimeglass_boots"]:
		var slot := String(DB.ITEMS[id]["type"])
		if not player.inventory.has(id):
			player.give_item(id)
		if player.equipped.get(slot, "") != id:
			check(player.equip(id), "%s should equip through the live gear system." % id)
		check(player.equipped.get(slot, "") == id, "%s should occupy the %s slot." % [id, slot])
		check(String(player.visible_gear.get(slot, "")) == id, "%s should apply its palette layer to the live player." % id)


func _satchel_icon_ids() -> Array:
	var ids: Array = []
	for child in game.hud.inventory_grid.get_children():
		if child.name.begins_with("SatchelItem_"):
			ids.append(String(child.name).trim_prefix("SatchelItem_"))
	return ids


func _option_index(option: OptionButton, key: String) -> int:
	for i in range(option.item_count):
		if String(option.get_item_metadata(i)) == key:
			return i
	return -1


func _test_satchel_categories_and_sort() -> void:
	var hud: Control = game.hud
	hud.set_meta("satchel_filter", "all")
	hud.set_meta("satchel_sort", "rarity")
	hud.satchel_selected = "moonshard_rapier"
	hud.toggle_inventory()
	await process_frame
	await process_frame
	var category := hud.inventory_panel.find_child("SatchelCategory", true, false) as OptionButton
	var sorter := hud.inventory_panel.find_child("SatchelSort", true, false) as OptionButton
	check(category != null and sorter != null, "The satchel should expose category and sort selectors.")
	if category == null or sorter == null:
		hud.toggle_inventory()
		return
	var swords_idx := _option_index(category, "swords")
	var weapons_idx := _option_index(category, "weapons")
	var accessories_idx := _option_index(category, "accessories")
	check(swords_idx >= 0 and weapons_idx >= 0 and accessories_idx >= 0, "Dynamic filters should include owned swords, weapons and accessories.")
	if swords_idx >= 0:
		category.select(swords_idx)
		category.item_selected.emit(swords_idx)
		await process_frame
		await process_frame
		var sword_ids := _satchel_icon_ids()
		check(sword_ids.size() >= 5, "The Swords category should surface the new named sword variants.")
		var swords_only := true
		var rarity_ordered := true
		var previous_rank := 999
		for id in sword_ids:
			if UIScreens._filter_of(String(id)) != "swords":
				swords_only = false
			var rank: int = DB.RARITIES.find(RUI.rarity_of(String(id)))
			if rank > previous_rank:
				rarity_ordered = false
			previous_rank = rank
		check(swords_only, "The Swords category should contain only sword-family weapons.")
		check(rarity_ordered, "Default rarity sorting should place higher rarities first.")
		var name_idx := _option_index(sorter, "name")
		check(name_idx >= 0, "The sort selector should offer A–Z name sorting.")
		if name_idx >= 0:
			sorter.select(name_idx)
			sorter.item_selected.emit(name_idx)
			await process_frame
			await process_frame
			var named_ids := _satchel_icon_ids()
			var names_ordered := true
			var prior_name := ""
			for id in named_ids:
				var current_name := String(DB.ITEMS[String(id)]["name"]).to_lower()
				if prior_name != "" and current_name < prior_name:
					names_ordered = false
				prior_name = current_name
			check(names_ordered, "Name sorting should be alphabetical within the selected category.")
		var value_idx := _option_index(sorter, "value")
		if value_idx >= 0:
			sorter.select(value_idx)
			sorter.item_selected.emit(value_idx)
			await process_frame
			await process_frame
			var value_ids := _satchel_icon_ids()
			var values_ordered := true
			var prior_value := 2147483647
			for id in value_ids:
				var current_value := int(DB.ITEMS[String(id)].get("value", 0))
				if current_value > prior_value:
					values_ordered = false
				prior_value = current_value
			check(values_ordered, "Value sorting should list higher-value equipment first.")
	if accessories_idx >= 0:
		category.select(accessories_idx)
		category.item_selected.emit(accessories_idx)
		await process_frame
		await process_frame
		var accessory_only := true
		for id in _satchel_icon_ids():
			if not String(DB.ITEMS[String(id)].get("type", "")) in ["charm", "ring", "relic"]:
				accessory_only = false
		check(accessory_only, "The Accessories category should contain only charms, rings and relics.")
	var count_label := hud.inventory_panel.find_child("BagCap", true, false) as Label
	check(count_label != null and count_label.text.begins_with("Showing "), "The satchel should show live visible-item and stack counts.")
	hud.toggle_inventory()


# ---------------------------------------------------------------- bar
func _test_weapon_bar() -> void:
	check(player.weapon_bar.is_empty() and player.is_unarmed(), "A new journey starts with an empty weapon bar.")
	for id in ["thornblade", "oakwood_staff", "twin_moon_katanas", "ironbloom_gauntlet", "thornlash_whip", "starweave_gloves"]:
		player.give_item(id)
	check(player.weapon_bar.size() == 5 and not player.weapon_bar.has("starweave_gloves"), "The bar should cap at five weapons (%s)." % str(player.weapon_bar))
	check(player.weapons_owned.has("starweave_gloves"), "A sixth weapon is still owned, just not in the bar.")
	check(not player.weapon_bar.has("fists"), "Bare paws never take a bar slot.")
	check(not player.bar_add("starweave_gloves") and player.last_equip_error.begins_with("Weapon bar full (5/5)"), "Adding to a full bar should fail with 'Weapon bar full (5/5)'.")
	check(player.bar_remove("thornblade") and player.weapon_bar.size() == 4 and player.weapons_owned.has("thornblade"), "Removing from the bar keeps the weapon owned.")
	check(player.bar_add("starweave_gloves") and player.weapon_bar.size() == 5, "A freed slot can take another weapon.")
	reset_player()
	check(player.select_bar_slot(0) and player.get_weapon_id() == player.weapon_bar[0], "Tapping slot 1 should equip that weapon.")
	check(not player.select_bar_slot(1) and player.get_weapon_id() == player.weapon_bar[0], "A second switch inside the 0.3s lockout should be refused.")
	await seconds(0.4)
	check(player.select_bar_slot(1) and player.get_weapon_id() == player.weapon_bar[1], "After the lockout, switching works again.")
	var held: String = player.get_weapon_id()
	player.bar_remove(held)
	check(player.is_unarmed(), "Removing the held weapon from the bar returns to bare paws.")
	player.bar_add(held)
	check(not player.select_bar_slot(7), "An out-of-range slot does nothing.")
	# Q / Tab cycles bar slots only
	player._switch_lock = 0.0
	player.select_bar_slot(0)
	player.cycle_weapon()
	check(player.get_weapon_id() == player.weapon_bar[1], "Next-weapon (Q/Tab) should step through the bar.")
	# equipping from the satchel with a full bar replaces the held weapon's slot
	player.give_item("direwolf_claws")
	var slot: int = player.weapon_bar.find(player.get_weapon_id())
	check(player.equip_weapon("direwolf_claws") and player.weapon_bar[slot] == "direwolf_claws" and player.weapon_bar.size() == 5, "Equipping a 6th weapon swaps it into the held weapon's slot.")
	player.unequip_weapon()
	player.give_item("cloudstride_staff")
	check(not player.equip_weapon("cloudstride_staff") and player.last_equip_error.begins_with("Weapon bar full"), "Bare-handed with a full bar, equipping explains the bar is full.")
	# arrange a known bar for the rest of the test
	player.weapon_bar.assign(["twin_moon_katanas", "cloudstride_staff", "thornlash_whip", "starweave_gloves", "direwolf_claws"])


func _test_hud_bar() -> void:
	var hud: Control = game.hud
	await process_frame
	await process_frame
	check(not ("weapon_button" in hud) and not hud.has_node("WeaponBox"), "The quick-swap button and 'Q SWAP' chip are removed.")
	check(hud.weapon_slots.size() == 5, "The HUD shows five weapon-bar slots.")
	var xs := {}
	var prev_y := INF
	var column_ok := true
	for b in hud.weapon_slots:
		xs[int(round(b.center().x))] = true
		if b.center().y >= prev_y:
			column_ok = false
		prev_y = b.center().y
	check(xs.size() == 1 and column_ok, "The slots form one straight vertical column.")
	var ab: Control = hud.attack_button
	check(hud.weapon_slots[0].center().x < ab.center().x - ab.radius and hud.weapon_slots[0].center().x > hud.safe_rect.get_center().x, "The bar sits on the right, inboard of the attack button.")
	var overlap := false
	for s in hud.weapon_slots:
		for o in hud.touch_buttons:
			if o == s or not o.visible or o.wslot >= 0:
				continue
			if s.center().distance_to(o.center()) < s.radius + o.radius:
				overlap = true
		if not hud.safe_rect.grow(1.0).has_point(s.center()):
			overlap = true
	check(not overlap, "Weapon slots must not overlap any other control or leave the safe area.")
	player._set_weapon_index(player.weapons_owned.find("twin_moon_katanas"))
	await process_frame
	await process_frame
	var held_slot: Control = null
	for b in hud.weapon_slots:
		if b.active:
			held_slot = b
	check(held_slot != null and held_slot.weapon_id == player.get_weapon_id(), "The held weapon's slot is highlighted.")
	check(hud.weapon_slots[1].mythic, "A mythical weapon slot uses the animated Mythical frame.")
	# tap a slot through the real touch path
	await seconds(0.4)
	player._switch_lock = 0.0
	hud.show_touch = true
	await process_frame
	await process_frame
	await process_frame
	var ev := InputEventScreenTouch.new()
	ev.index = 4
	ev.position = hud.weapon_slots[2].center()
	ev.pressed = true
	hud._input(ev)
	ev = ev.duplicate()
	ev.pressed = false
	hud._input(ev)
	check(player.get_weapon_id() == "thornlash_whip", "Tapping a slot on screen switches weapons.")
	# HUD editor: moving a slot persists, reset restores the default
	var def_c: Vector2 = hud.controls.default_center("wslot0")
	var lay: Dictionary = hud.settings.get("layout", {})
	lay["wslot0"] = [ -20.0, -10.0]
	hud.settings["layout"] = lay
	hud.controls.apply_layout()
	var moved: bool = hud.weapon_slots[0].center().distance_to(def_c) > 5.0
	hud.settings["layout"] = {}
	hud.controls.apply_layout()
	check(moved and hud.weapon_slots[0].center().distance_to(hud.controls.clamp_center(def_c, hud.weapon_slots[0].radius)) < 3.0, "The bar is movable in the layout and resets to its default.")


# ---------------------------------------------------------------- framework
func _test_tap_vs_hold() -> void:
	# common weapon: holding repeats attacks
	player.give_item("thornblade")
	player.bar_remove("direwolf_claws")
	player.bar_add("thornblade")
	hold("thornblade")
	var d := dummy(Vector2(18, 0))
	var hp0: int = d.hp
	await press_for(0.9)
	await let_go()
	var hits_common: int = hp0 - d.hp
	check(hits_common >= int(DB.ITEMS["thornblade"]["damage"]) * 2, "Holding a basic weapon keeps auto-repeating (damage %d)." % hits_common)
	check(not player.charge.charging, "Basic weapons never charge.")
	clear_all()
	# signature weapon: one attack on press, then charging, no repeats
	hold("twin_moon_katanas")
	d = dummy(Vector2(18, 0))
	hp0 = d.hp
	await press_for(0.12)
	var after_tap: int = hp0 - d.hp
	check(after_tap > 0, "Pressing attack on a signature weapon still swings at once (tap-spam works).")
	await seconds(0.3)
	check(player.charge.charging, "Holding past the tap threshold starts charging.")
	await process_frame
	check(game.hud.attack_button.charge >= 0.0, "The attack button shows the charge ring while charging.")
	var view: Node2D = player.get_node("ChargeView")
	check(view != null and view.ctl == player.charge, "The charge arc/preview is drawn above Mallow.")
	var hp_mid: int = d.hp
	await seconds(0.3)
	check(d.hp == hp_mid, "Charging does not auto-repeat swings.")
	check(player.charge.is_full(), "The charge fills to FULL.")
	await process_frame
	check(game.hud.attack_button.charge_full, "The attack button marks FULL.")
	await let_go()
	check(player.charge.last_release == "special", "Releasing at full fires the special.")
	await seconds(0.45)
	await process_frame
	check(game.hud.attack_button.charge < 0.0, "The charge ring hides after release.")
	clear_all()
	# early release = nothing extra
	hold("twin_moon_katanas")
	var x0: float = player.global_position.x
	await press_for(0.35)
	await let_go()
	check(player.charge.last_release == "early" and absf(player.global_position.x - x0) < 20.0, "Releasing before full does no special.")
	# slowed movement while charging
	hold("twin_moon_katanas")
	Input.action_press("move_down")
	await seconds(0.3)
	var walk: float = player.velocity.length()
	Input.action_press("attack")
	await seconds(0.45)
	var slow: float = player.velocity.length()
	check(player.charge.charging and slow < walk * 0.75 and slow > 1.0, "Mallow moves slower while charging (%.0f vs %.0f)." % [slow, walk])
	# cancel: drag off the button, then release
	player.charge.off_button = true
	await seconds(0.3)
	var before_cancel: Vector2 = player.global_position
	Input.action_release("move_down")
	await let_go()
	check(player.charge.last_release == "cancel" and player.state != player.State.ROLL, "Releasing after dragging off the button cancels.")
	# cancel through the real touch path: press the attack button, drag off, drag back
	var hud: Control = game.hud
	hud.show_touch = true
	await process_frame
	await process_frame
	hold("twin_moon_katanas")
	var ab: Control = hud.attack_button
	var t := InputEventScreenTouch.new()
	t.index = 6
	t.position = ab.center()
	t.pressed = true
	hud._input(t)
	await seconds(0.45)
	var dr := InputEventScreenDrag.new()
	dr.index = 6
	dr.position = ab.center() + Vector2(-ab.radius - 40.0, -30.0)
	hud._input(dr)
	var armed: bool = player.charge.off_button
	await process_frame
	await process_frame
	var red: bool = ab.charge_cancel
	dr = dr.duplicate()
	dr.position = ab.center() + Vector2(2, 2)
	hud._input(dr)
	var rearmed: bool = not player.charge.off_button
	dr = dr.duplicate()
	dr.position = ab.center() + Vector2(-ab.radius - 40.0, -30.0)
	hud._input(dr)
	t = t.duplicate()
	t.pressed = false
	t.position = dr.position
	hud._input(t)
	await frames(2)
	check(armed and red and rearmed and player.charge.last_release == "cancel", "Dragging off the attack button arms a cancel (red ring), sliding back re-arms, releasing outside cancels.")
	# cancel: switching weapon
	hold("twin_moon_katanas")
	await press_for(0.4)
	player._switch_lock = 0.0
	player.select_bar_slot(player.weapon_bar.find("thornlash_whip"))
	check(not player.charge.active(), "Switching weapons cancels the charge.")
	await let_go()
	# cancel: menus / transitions (input disabled)
	hold("twin_moon_katanas")
	await press_for(0.4)
	player.charge.last_release = ""
	game.hud.toggle_inventory()
	await seconds(0.4)
	game.hud.toggle_inventory()
	await frames(3)
	check(not player.charge.active() and player.charge.last_release == "cancel", "Opening a menu (or teleporting, which disables input) cancels the charge (%s)." % player.charge.last_release)
	await let_go()
	# cancel: hurt / knocked back
	hold("twin_moon_katanas")
	await press_for(0.4)
	player.state = player.State.HURT
	player._lock_t = 0.2
	await frames(2)
	check(not player.charge.active(), "Getting hit (stun/knockback) cancels the charge.")
	await let_go()
	await seconds(0.3)
	reset_player()


func _test_katanas() -> void:
	hold("twin_moon_katanas")
	check(player.off_weapon_sprite != null and player.off_weapon_sprite.visible, "Twin Moon Katanas show a blade in each paw.")
	# aim with the stick, not the locked target
	var side := dummy(Vector2(40, 0))
	player.manual_target = side
	player.current_target = side
	var a := dummy(Vector2(0, -40))
	var b := dummy(Vector2(0, -75))
	var ha: int = a.hp
	var hb: int = b.hp
	var hs: int = side.hp
	Input.action_press("move_up")
	await press_for(0.85)
	await let_go()
	Input.action_release("move_up")
	await seconds(0.5)
	check(player.global_position.y < arena.y - 50.0 and absf(player.global_position.x - arena.x) < 14.0, "Moonrend Dash goes where the stick aims (moved to %s)." % str(player.global_position - arena))
	var dmg: int = int(round(float(int(DB.ITEMS["twin_moon_katanas"]["damage"]) + player.attack_bonus()) * 2.5))
	var max_once := int(ceil(float(dmg) * float(CD.BALANCE["crit_mult"]))) + 2
	check(ha - a.hp >= dmg and ha - a.hp <= max_once and hb - b.hp >= dmg and hb - b.hp <= max_once, "Every foe on the dash path is hit exactly once (%d, %d of %d)." % [ha - a.hp, hb - b.hp, dmg])
	check(hs - side.hp <= int(DB.ITEMS["twin_moon_katanas"]["damage"]) * 4, "The locked target off to the side is not where the dash went.")
	clear_all()
	# stops at walls
	hold("twin_moon_katanas")
	var w := wall(Vector2(52, 0), Vector2(10, 60))
	await frames(3)
	await press_for(0.85)
	await let_go()
	await seconds(0.5)
	check(player.global_position.x < w.global_position.x - 5.0 and player.global_position.x > arena.x + 20.0, "Moonrend Dash stops at the wall (x %.0f, wall %.0f)." % [player.global_position.x - arena.x, w.global_position.x - arena.x])
	clear_all()
	await frames(2)


func _test_staffs() -> void:
	# Oakwood Staff: no hold effect -> holding repeats
	player.give_item("oakwood_staff")
	player.weapon_bar.assign(["twin_moon_katanas", "cloudstride_staff", "thornlash_whip", "starweave_gloves", "oakwood_staff"])
	hold("oakwood_staff")
	player.charge.last_release = ""
	var d := dummy(Vector2(22, 0))
	var hp0: int = d.hp
	await press_for(0.8)
	await let_go()
	check(not player.charge.charging and player.charge.last_release != "special" and hp0 - d.hp >= 2 * int(DB.ITEMS["oakwood_staff"]["damage"]), "The common Oakwood Staff has no hold effect and repeats attacks.")
	clear_all()
	# Cloudstride: blink + clone at the old position
	hold("cloudstride_staff")
	player.charge.last_release = ""
	var foe := dummy(Vector2(-18, 0))
	var hf: int = foe.hp
	await press_for(0.95)
	Input.action_press("move_right")
	await frames(2)
	await let_go()
	Input.action_release("move_right")
	await frames(2)
	check(player.charge.last_release == "special", "Cloudstride releases its Afterimage at full charge.")
	check(player.global_position.x > arena.x + 50.0, "Mallow blinks a short distance in the aim direction (%.0f)." % (player.global_position.x - arena.x))
	var c: Node = player.clone_ref
	check(c != null and is_instance_valid(c) and c.global_position.distance_to(arena) < 14.0, "A clone stays at the starting position.")
	await seconds(1.2)
	check(foe.hp < hf and c.hits > 0, "The clone attacks nearby foes.")
	# one clone at a time
	player.charge.special_cd = 0.0
	player.state = player.State.MOVE
	await press_for(0.95)
	await let_go()
	await frames(3)
	var n := 0
	for ch in game.entities.get_children():
		if ch.name.begins_with("Afterimage") and not ch.is_queued_for_deletion():
			n += 1
	check(n == 1, "Only one clone exists at a time (%d)." % n)
	player.clone_ref.life = 0.05
	await seconds(0.2)
	check(player.clone_ref == null, "The clone expires.")
	clear_all()
	# blink never passes through a wall
	hold("cloudstride_staff")
	var w := wall(Vector2(40, 0), Vector2(8, 80))
	await frames(3)
	await press_for(0.95)
	await let_go()
	await frames(3)
	check(player.global_position.x < w.global_position.x and game.line_clear(arena + Vector2(0, -4), player.global_position + Vector2(0, -4)), "The blink stops short of walls (x %.0f)." % (player.global_position.x - arena.x))
	clear_all()
	await frames(2)


func _test_gauntlet() -> void:
	player.weapon_bar.assign(["twin_moon_katanas", "cloudstride_staff", "thornlash_whip", "starweave_gloves", "ironbloom_gauntlet"])
	hold("ironbloom_gauntlet")
	var d := dummy(Vector2(26, 0))
	var far := dummy(Vector2(110, 0))
	var hp0: int = d.hp
	var hfar: int = far.hp
	await press_for(0.9)
	await let_go()
	await frames(2)
	check(player.last_burst.get("hits", 0) >= 1 and d.hp < hp0, "Energy Burst damages foes in its short area.")
	check(far.hp == hfar, "Energy Burst has a short range.")
	var st = StatusFx.of(d)
	check((st != null and st.has_effect("stun")) or d.get("knockback") != null and (d.knockback as Vector2).length() > 0.0, "Energy Burst knocks foes back and down.")
	clear_all()
	await seconds(0.3)


func _test_whip() -> void:
	hold("thornlash_whip")
	check(player.range_hint.shape == "ring" and player.range_hint.sweet > 0.5, "The whip shows a 360° ring with a sweet-spot band.")
	var inner := dummy(Vector2(-16, 0))     # behind Mallow: 360°
	var tip := dummy(Vector2(0, 42))        # in the outer tip band
	var out := dummy(Vector2(70, 0))
	var hi: int = inner.hp
	var ht: int = tip.hp
	var ho: int = out.hp
	player.try_attack()
	await frames(2)
	check(inner.hp < hi and tip.hp < ht and out.hp == ho, "The whip hits all around at mid distance, not beyond.")
	check(int(player.last_whip.get("sweet", 0)) == 1 and int(player.last_whip.get("hits", 0)) == 2, "Only the foe at the tip counts as a sweet-spot hit.")
	var base: int = int(DB.ITEMS["thornlash_whip"]["damage"]) + player.attack_bonus()
	check(ht - tip.hp >= int(round(float(base) * 1.5)), "Sweet-spot hits deal extra damage (%d vs base %d)." % [ht - tip.hp, base])
	await seconds(0.6)
	reset_player()
	# Wide Lash: bigger + stronger once, then back to normal
	await press_for(0.8)
	await let_go()
	check(bool(player.last_whip.get("big", false)) and float(player.last_whip["reach"]) > float(CD.weapon("thornlash_whip")["reach"]) * 1.3, "Wide Lash spins bigger after a full charge.")
	await seconds(0.7)
	reset_player()
	player.try_attack()
	await frames(2)
	check(not bool(player.last_whip.get("big", true)) and absf(float(player.last_whip["reach"]) - float(CD.weapon("thornlash_whip")["reach"])) < 0.5, "The next swing is back to normal size.")
	clear_all()
	await seconds(0.5)


func _test_gloves() -> void:
	hold("starweave_gloves")
	var n0: int = game.projectiles.get_child_count()
	player.try_attack()
	await frames(1)
	check(game.projectiles.get_child_count() > n0, "Starweave Gloves fire a long-range orb.")
	var pr: Node = game.projectiles.get_child(game.projectiles.get_child_count() - 1)
	check(float(pr.homing) == 0.0 and float(pr.life) * float(pr.speed) >= 180.0, "The basic orb is long range and does not home.")
	var r_small: float = pr.radius
	await seconds(0.5)
	reset_player()
	# Overcharge aims with the stick (up), never at the locked target (right)
	var t := dummy(Vector2(60, 0))
	player.manual_target = t
	player.current_target = t
	Input.action_press("move_up")
	await press_for(0.85)
	await let_go()
	Input.action_release("move_up")
	await frames(1)
	var big: Node = game.projectiles.get_child(game.projectiles.get_child_count() - 1)
	check(float(big.radius) > r_small and big.sprite.scale.x > 1.5, "Overcharge fires a bigger orb.")
	check((big.dir as Vector2).y < -0.9, "The charged orb flies where the stick aims, not at the locked target.")
	clear_all()
	await seconds(0.5)


func _test_claws() -> void:
	player.weapon_bar.assign(["twin_moon_katanas", "cloudstride_staff", "thornlash_whip", "starweave_gloves", "direwolf_claws"])
	hold("direwolf_claws")
	check(player.lifesteal() >= 0.07 - 0.001, "Direwolf Claws grant lifesteal.")
	player.health = 2
	var d := dummy(Vector2(16, 0), 2000)
	await press_for(1.8)
	await let_go()
	# tapping repeatedly for a few seconds
	for i in range(30):
		player.attack_cooldown = 0.0
		player.state = player.State.MOVE
		player.try_attack()
		await frames(3)
	check(player.health > 2, "Lifesteal heals Mallow while clawing (%d HP)." % player.health)
	# cap: heavy damage in one second heals at most 3
	player.health = 1
	player._ls_window = 1.0
	player._ls_sec = 0.0
	for i in range(8):
		player.deal(d, 40, {"source": "basic", "can_crit": false})
	check(player.health - 1 <= int(CD.BALANCE["lifesteal_per_sec"]), "Lifesteal is capped per second (+%d)." % (player.health - 1))
	clear_all()
	await seconds(0.4)
	# Feral Barrage: longer reach than the basic swipe, lifesteal applies
	reset_player()
	var far := dummy(Vector2(36, 0))
	var hf: int = far.hp
	player.try_attack()
	await frames(2)
	check(far.hp == hf, "A basic claw swipe cannot reach 36px.")
	await seconds(0.4)
	reset_player()
	player.health = 2
	player._ls_sec = 0.0
	await press_for(0.8)
	await let_go()
	await seconds(0.6)
	check(player.barrage_hits >= 3 and far.hp < hf, "Feral Barrage releases a claw flurry with extra reach (%d hits)." % player.barrage_hits)
	check(player.health > 2, "Lifesteal works on the barrage.")
	clear_all()
	await seconds(0.3)


# ---------------------------------------------------------------- arts
func _nightbloom() -> void:
	player.skill_points = 200
	player.level = 20
	player.bind_class("nightbloom")
	for nid in ClassBook.class_of("nightbloom")["tree"]:
		player.spend_node("nightbloom", nid)


func _test_petal_rush() -> void:
	_nightbloom()
	player._set_weapon_index(player.weapons_owned.find("fists"))
	reset_player()
	check(player.cast_block_reason("petal_rush") == "", "Petal Rush should be castable once unlocked (%s)." % player.cast_block_reason("petal_rush"))
	var a := dummy(Vector2(40, 0))
	var f0: float = player.focus
	check(player.cast_skill("petal_rush", Vector2.RIGHT * 60.0), "Petal Rush casts.")
	await seconds(0.35)
	check(a.hp < a.max_hp, "The dash damages the foe it passes.")
	check(not player._rush.is_empty() and float(player._rush["window"]) > 0.0 and float(player.skill_cd.get("petal_rush", 0.0)) <= 0.0, "A hit opens a free recast window; no cooldown yet.")
	var f1: float = player.focus
	check(f1 < f0, "The first dash costs Focus.")
	# chain back through the foe
	player.state = player.State.MOVE
	player._lock_t = 0.0
	check(player.cast_skill("petal_rush", Vector2.LEFT * 60.0), "The chain recast works.")
	check(absf(player.focus - f1) < 0.01, "Chained dashes are free.")
	await seconds(0.35)
	check(int(player._rush.get("count", 0)) == 2 and float(player._rush.get("window", 0.0)) > 0.0, "Hitting again keeps the chain going.")
	# a miss ends the chain and starts the cooldown
	player.state = player.State.MOVE
	player._lock_t = 0.0
	player.cast_skill("petal_rush", Vector2.UP * 60.0)
	await seconds(0.35)
	check(player._rush.is_empty() and float(player.skill_cd.get("petal_rush", 0.0)) > 0.0 and int(player.last_rush.get("count", 0)) == 3, "A dash that misses ends the chain and starts the cooldown.")
	# the cap
	clear_all()
	reset_player()
	var b := dummy(Vector2(40, 0))
	player.cast_skill("petal_rush", Vector2.RIGHT * 60.0)
	await seconds(0.05)
	player._rush["count"] = int(player._rush["cap"]) - 1
	await seconds(0.35)
	player.state = player.State.MOVE
	player._lock_t = 0.0
	player.cast_skill("petal_rush", Vector2.LEFT * 60.0)
	await seconds(0.35)
	check(player._rush.is_empty() and float(player.skill_cd.get("petal_rush", 0.0)) > 0.0, "The chain stops at its cap even when it hits (%s)." % str(player.last_rush))
	# window expires
	clear_all()
	reset_player()
	var c := dummy(Vector2(40, 0))
	player.cast_skill("petal_rush", Vector2.RIGHT * 60.0)
	await seconds(0.35 + 0.9)
	check(player._rush.is_empty() and float(player.skill_cd.get("petal_rush", 0.0)) > 0.0, "If the window runs out, the chain ends and the cooldown starts.")
	clear_all()
	await frames(2)


func _test_vine_hook() -> void:
	reset_player()
	var d := dummy(Vector2(95, 0))
	var near := dummy(Vector2(100, 10))
	var hd: int = d.hp
	var hn: int = near.hp
	var f0: float = player.focus
	check(player.cast_skill("vine_hook", Vector2.RIGHT * 100.0), "Vine Hook casts.")
	check(String(player.last_hook["kind"]) == "enemy", "The hook catches the foe in line.")
	check(player.focus < f0, "Vine Hook costs Focus.")
	var cd: float = float(player.skill_cd.get("vine_hook", 0.0))
	check(cd > 0.0 and cd <= 2.0, "Vine Hook has a very short cooldown (%.2fs)." % cd)
	await seconds(0.45)
	check(player.global_position.x > arena.x + 70.0, "Mallow zips to the hooked foe (%.0f)." % (player.global_position.x - arena.x))
	check(bool(player.last_hook.get("tornado", false)) and d.hp < hd and near.hp < hn, "Reaching the foe triggers Tornado Slash on everything nearby.")
	clear_all()
	# obstacle: zip to it, stop in front, no clipping
	reset_player()
	var w := wall(Vector2(90, 0), Vector2(10, 60))
	await frames(3)
	player.cast_skill("vine_hook", Vector2.RIGHT * 100.0)
	check(String(player.last_hook["kind"]) == "wall", "The hook catches an obstacle.")
	await seconds(0.45)
	check(player.global_position.x > arena.x + 55.0 and player.global_position.x < w.global_position.x - 5.0, "Mallow zips to the obstacle and stops in front of it (%.0f)." % (player.global_position.x - arena.x))
	check(not bool(player.last_hook.get("tornado", false)), "No Tornado Slash without hitting a foe.")
	clear_all()
	# passing through a foe on the way to a wall triggers the tornado
	reset_player()
	var mid := dummy(Vector2(40, 13))
	var w2 := wall(Vector2(100, 0), Vector2(10, 60))
	await frames(3)
	var hm: int = mid.hp
	player.cast_skill("vine_hook", Vector2.RIGHT * 110.0)
	await seconds(0.45)
	check(String(player.last_hook["kind"]) == "wall" and bool(player.last_hook.get("tornado", false)) and mid.hp < hm, "Hitting a foe during the hook dash unleashes Tornado Slash.")
	clear_all()
	# miss: nothing in range -> no movement
	reset_player()
	player.cast_skill("vine_hook", Vector2.UP * 100.0)
	await seconds(0.3)
	check(String(player.last_hook["kind"]) == "miss" and player.global_position.distance_to(arena) < 6.0, "A miss retracts the vine without moving Mallow.")
	clear_all()
	await frames(2)


# ---------------------------------------------------------------- save
func _test_save_and_migration() -> void:
	reset_player()
	player.weapon_bar.assign(["direwolf_claws", "cloudstride_staff", "thornlash_whip"])
	player._set_weapon_index(player.weapons_owned.find("thornlash_whip"))
	check(game.save_game(), "Saving with a weapon bar works.")
	player.weapon_bar.clear()
	player._set_weapon_index(0)
	check(game.load_game(), "Loading works.")
	check(player.weapon_bar == ["direwolf_claws", "cloudstride_staff", "thornlash_whip"] and player.get_weapon_id() == "thornlash_whip", "The bar and held weapon persist (%s / %s)." % [str(player.weapon_bar), player.get_weapon_id()])
	# a save from before the weapon bar existed
	var f := FileAccess.open(Save.path(), FileAccess.READ)
	var data: Dictionary = JSON.parse_string(f.get_as_text())
	f.close()
	var pd: Dictionary = data["player"] if data.has("player") else data
	pd.erase("weapon_bar")
	var w := FileAccess.open(Save.path(), FileAccess.WRITE)
	w.store_string(JSON.stringify(data))
	w.close()
	var owned_before: int = player.weapons_owned.size()
	check(game.load_game(), "A pre-bar save loads.")
	check(player.weapons_owned.size() == owned_before, "Migration never loses owned weapons.")
	check(player.weapon_bar.size() == 5 and player.weapon_bar.has("thornlash_whip") and player.get_weapon_id() == "thornlash_whip", "Old saves get a full bar that keeps the held weapon (%s)." % str(player.weapon_bar))
	check(player.weapon_bar.has("cloudstride_staff"), "Migration fills the bar best-rarity first.")
