extends CharacterBody2D
## Mallow, the rose-hooded wanderer. Walk, sprint, dodge-roll, jump hedges, swim,
## four weapons with distinct attacks, two skills, outfits that recolour the sprite.
## Petal Arts update: class lines with skill trees, focus, XP levels, target-snapping
## melee with a range hint, softer knockback, and an equipment-driven defense stat.

const AnimLib := preload("res://scripts/core/anim_lib.gd")
const DB := preload("res://scripts/data/db.gd")
const ClassDB := preload("res://scripts/data/classdb.gd")
const SPRITE_SHADER := preload("res://assets/shaders/sprite_fx.gdshader")
const HERO := "res://assets/packs/ninja_adventure/hero/"

signal hit_taken(amount: int)
signal died
signal health_changed

enum Facing { DOWN, LEFT, RIGHT, UP, DOWN_LEFT, DOWN_RIGHT, UP_LEFT, UP_RIGHT }
enum State { MOVE, ROLL, JUMP, ATTACK, HURT, DEAD, POSE }

const WALK_SPEED := 84.0
const SPRINT_SPEED := 132.0
const SWIM_SPEED := 54.0
const ROLL_SPEED := 215.0
const ROLL_TIME := 0.34
const JUMP_TIME := 0.48
const JUMP_HEIGHT := 14.0
const ACCEL := 1300.0
const STAMINA_MAX := 100.0
const HEART := 4
const MASK_GROUND := 1 | 4 | 8
const MASK_AIR := 1 | 8

var game: Node
var state := State.MOVE
var facing := Vector2.DOWN
var facing_direction := Facing.DOWN
var dir_name := "down"
var sprite: AnimatedSprite2D
var shadow: Sprite2D
var weapon_sprite: Sprite2D
var held_item: Sprite2D
var fx_material: ShaderMaterial
var lantern: PointLight2D
var guard_fx: AnimatedSprite2D

var base_hearts := 5
var heart_pieces := 0
var max_health := 20
var health := 20
var stamina := STAMINA_MAX
var stamina_delay := 0.0
var invulnerable_left := 0.0
var weapon_index := 0
var weapons_owned: Array[String] = ["thornblade", "bloomstaff"]
var equipped: Dictionary = {"cloak": "plum_cloak"}
var inventory: Array[String] = ["plum_cloak"]
var moontea_charges := 3
var moontea_max := 3
var petalcoins := 0
var attack_combo := -1
var combo_timer := 0.0
var attack_cooldown := 0.0
var attack_left := 0.0
var mothlight_cooldown := 0.0
var guard_cooldown := 0.0
var guard_time_left := 0.0
var guard_active := false
var swimming := false
var airborne := false
var jump_t := 0.0
var plunge := false
var roll_t := 0.0
var roll_dir := Vector2.DOWN
var knockback := Vector2.ZERO
var bow_charge := -1.0
var sprinting := false
var input_enabled := true
var pushing := false
var _lock_t := 0.0
var _step_t := 0.0
var _ghost_t := 0.0
var _ripple_t := 0.0
var _hammer_pending := -1.0
var _was_swimming := false
var fishing := false
var parry_cooldown := 0.0
## Petal Arts: bound class lines, trees, the skill bar, focus and levels.
var classes: Array[String] = []
var class_nodes: Dictionary = {}
var skill_bar: Array[String] = []
var skill_cd: Dictionary = {}
var buffs: Dictionary = {}
var xp := 0
var level := 1
var skill_points := 0
const FOCUS_BASE := 40
var focus := 40.0
var focus_max := 40.0
var range_hint: Node2D

var cloak_equipped: bool:
	get:
		return equipped.get("cloak", "") == "plum_cloak"
var charm_equipped: bool:
	get:
		return equipped.get("charm", "") == "moonheart_charm"
	set(value):
		if value:
			equipped["charm"] = "moonheart_charm"
		else:
			equipped.erase("charm")
		recalc_stats()
var dash_left: float:
	get:
		return roll_t
	set(value):
		roll_t = value


func _ready() -> void:
	_register_inputs()
	collision_layer = 2
	collision_mask = MASK_GROUND
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var cs := CollisionShape2D.new()
	var shape := CapsuleShape2D.new()
	shape.radius = 4.5
	shape.height = 11.0
	cs.shape = shape
	cs.rotation = PI / 2.0
	cs.position = Vector2(0, -2)
	add_child(cs)
	shadow = Sprite2D.new()
	shadow.texture = _shadow_texture()
	shadow.modulate = Color(0.05, 0.06, 0.12, 0.38)
	shadow.scale = Vector2(0.5, 0.42)
	shadow.z_index = -1
	add_child(shadow)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = _build_frames()
	sprite.offset = Vector2(0, -8)
	fx_material = ShaderMaterial.new()
	fx_material.shader = SPRITE_SHADER
	fx_material.set_shader_parameter("noise_tex", load("res://assets/data/noise.png"))
	sprite.material = fx_material
	add_child(sprite)
	weapon_sprite = Sprite2D.new()
	weapon_sprite.centered = false
	weapon_sprite.visible = false
	add_child(weapon_sprite)
	held_item = Sprite2D.new()
	held_item.visible = false
	held_item.position = Vector2(0, -30)
	add_child(held_item)
	lantern = PointLight2D.new()
	lantern.texture = preload("res://scripts/world/world.gd").light_texture()
	lantern.texture_scale = 2.4
	lantern.color = Color(1.0, 0.86, 0.66)
	lantern.energy = 0.0
	lantern.position = Vector2(0, -8)
	add_child(lantern)
	guard_fx = AnimatedSprite2D.new()
	guard_fx.sprite_frames = AnimLib.strip_frames("res://assets/packs/ninja_adventure/fx/shield.png", 24, 12.0, true)
	guard_fx.position = Vector2(0, -9)
	guard_fx.scale = Vector2(1.25, 1.25)
	guard_fx.visible = false
	guard_fx.modulate = Color(1.0, 0.8, 0.95, 0.9)
	add_child(guard_fx)
	range_hint = RangeHint.new()
	range_hint.radius = 26.0
	range_hint.visible = false
	add_child(range_hint)
	apply_outfit()
	recalc_stats()
	health = max_health
	sprite.play("idle_down")


func _register_inputs() -> void:
	_add_keys("move_up", [KEY_W, KEY_UP])
	_add_keys("move_down", [KEY_S, KEY_DOWN])
	_add_keys("move_left", [KEY_A, KEY_LEFT])
	_add_keys("move_right", [KEY_D, KEY_RIGHT])
	_add_keys("dash", [KEY_SPACE])
	_add_keys("sprint", [KEY_SHIFT])
	_add_keys("jump", [KEY_C, KEY_L])
	_add_keys("attack", [KEY_J, KEY_ENTER])
	_add_keys("skill", [KEY_F])
	_add_keys("guard", [KEY_G])
	_add_keys("heal", [KEY_R])
	_add_keys("switch_weapon", [KEY_Q, KEY_TAB])
	_add_keys("inventory", [KEY_I, KEY_B])
	_add_keys("interact", [KEY_E])
	_add_keys("map", [KEY_M])
	_add_keys("pause", [KEY_ESCAPE, KEY_P])
	_add_keys("photo", [KEY_F9])
	_add_keys("arts", [KEY_K])
	_add_keys("journeys", [KEY_H])
	_add_keys("art1", [KEY_1])
	_add_keys("art2", [KEY_2])
	_add_keys("art3", [KEY_3])
	_add_keys("art4", [KEY_4])
	_add_joy("attack", JOY_BUTTON_X)
	_add_joy("dash", JOY_BUTTON_B)
	_add_joy("jump", JOY_BUTTON_A)
	_add_joy("interact", JOY_BUTTON_Y)
	_add_joy("skill", JOY_BUTTON_LEFT_SHOULDER)
	_add_joy("guard", JOY_BUTTON_RIGHT_SHOULDER)
	_add_joy("heal", JOY_BUTTON_DPAD_DOWN)
	_add_joy("switch_weapon", JOY_BUTTON_DPAD_RIGHT)
	_add_joy("inventory", JOY_BUTTON_BACK)
	_add_joy("map", JOY_BUTTON_DPAD_UP)
	_add_joy("pause", JOY_BUTTON_START)
	_add_joy("sprint", JOY_BUTTON_LEFT_STICK)
	_add_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_add_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_add_axis("move_up", JOY_AXIS_LEFT_Y, -1.0)
	_add_axis("move_down", JOY_AXIS_LEFT_Y, 1.0)
	if not InputMap.has_action("attack_mouse"):
		InputMap.add_action("attack_mouse")


func _add_keys(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		if not InputMap.action_has_event(action, event):
			InputMap.action_add_event(action, event)


func _add_joy(action: String, button: JoyButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var e := InputEventJoypadButton.new()
	e.button_index = button
	if not InputMap.action_has_event(action, e):
		InputMap.action_add_event(action, e)


func _add_axis(action: String, axis: JoyAxis, value: float) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var e := InputEventJoypadMotion.new()
	e.axis = axis
	e.axis_value = value
	if not InputMap.action_has_event(action, e):
		InputMap.action_add_event(action, e)


func _build_frames() -> SpriteFrames:
	var f := SpriteFrames.new()
	f.remove_animation("default")
	var cell := Vector2i(32, 32)
	AnimLib.add_directional(f, "idle", AnimLib.tex(HERO + "idle.png"), cell, 5.0, true)
	AnimLib.add_directional(f, "walk", AnimLib.tex(HERO + "walk.png"), cell, 9.0, true)
	AnimLib.add_directional(f, "attack", AnimLib.tex(HERO + "attack.png"), cell, 16.0, false)
	AnimLib.add_directional(f, "roll", AnimLib.tex(HERO + "roll.png"), cell, 11.0, false)
	AnimLib.add_directional(f, "jump", AnimLib.tex(HERO + "jump.png"), cell, 9.0, false, ["down", "up", "left"])
	AnimLib.add_directional(f, "swim", AnimLib.tex(HERO + "swim.png"), cell, 6.0, true)
	AnimLib.add_directional(f, "hit", AnimLib.tex(HERO + "hit.png"), cell, 10.0, false)
	AnimLib.add_directional(f, "push", AnimLib.tex(HERO + "push.png"), cell, 6.0, true)
	AnimLib.add_directional(f, "dead", AnimLib.tex(HERO + "dead.png"), cell, 4.0, false, ["down"])
	AnimLib.add_directional(f, "item", AnimLib.tex(HERO + "item.png"), cell, 4.0, false, ["down"])
	return f


static var _shadow_tex: Texture2D


static func _shadow_texture() -> Texture2D:
	if _shadow_tex:
		return _shadow_tex
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.6, Color(1, 1, 1, 0.85))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 32
	t.height = 32
	_shadow_tex = t
	return t


# ------------------------------------------------------------------ stats & gear
func recalc_stats() -> void:
	var hearts := base_hearts + heart_pieces
	for slot in equipped:
		var item: Dictionary = DB.ITEMS.get(equipped[slot], {})
		hearts += int(item.get("hearts", 0))
	hearts += int(_tree_sum("hearts"))
	var old_max := max_health
	max_health = hearts * HEART
	if max_health > old_max:
		health = mini(max_health, health + (max_health - old_max))
	health = mini(health, max_health)
	var old_focus := focus_max
	focus_max = float(FOCUS_BASE + 2 * (level - 1) + int(_tree_sum("focus")))
	for slot in equipped:
		focus_max += float(DB.ITEMS.get(equipped[slot], {}).get("focus", 0.0))
	focus = clampf(focus, 0.0, focus_max)
	if focus_max > old_focus and old_focus > 0.0:
		focus += focus_max - old_focus
		focus = clampf(focus, 0.0, focus_max)
	health_changed.emit()


## Sum of one stat ("hearts", "focus", "atk", "defense", "crit", "speed", "cd")
## across every owned tree node of every bound class.
func _tree_sum(stat: String) -> float:
	var total := 0.0
	for cid in classes:
		var nodes: Dictionary = class_nodes.get(cid, {})
		for nid in nodes:
			var node: Dictionary = ClassDB.class_of(cid).get("tree", {}).get(nid, {})
			total += float(node.get("effect", {}).get(stat, 0.0))
	return total


func attack_bonus() -> int:
	var bonus := int(_tree_sum("atk"))
	if classes.size() >= 2:
		bonus += 1  # dual-line synergy
	return bonus


func defense_total() -> int:
	var d := int(_tree_sum("defense"))
	for slot in equipped:
		d += int(DB.ITEMS.get(equipped[slot], {}).get("defense", 0))
	if buffs.has("bulwark"):
		d += 2
	return d


func crit_chance() -> float:
	var c := 0.03 + _tree_sum("crit")
	for slot in equipped:
		c += float(DB.ITEMS.get(equipped[slot], {}).get("crit", 0.0))
	if buffs.has("marked"):
		c += 0.30
	if buffs.has("shadow"):
		c = 1.0
	return clampf(c, 0.0, 1.0)


func skill_cd_scale() -> float:
	return clampf(1.0 - _tree_sum("cd"), 0.5, 1.0)


## Roll a critical on a damage number; celebrate when it lands.
func _roll_crit(dmg: int) -> int:
	if randf() < crit_chance():
		if game:
			game.fx.number(global_position + Vector2(0, -22), "CRIT!", Color("ffd27a"), true)
			game.audio.play("secret2", 0.06, -6.0)
		return dmg * 2
	return dmg


func get_move_speed() -> float:
	var mult := 1.0 + _tree_sum("speed")
	for slot in equipped:
		mult += float(DB.ITEMS.get(equipped[slot], {}).get("speed", 0.0))
	return WALK_SPEED * mult


func stamina_regen_mult() -> float:
	var m := 1.0
	for slot in equipped:
		m += float(DB.ITEMS.get(equipped[slot], {}).get("stamina_regen", 0.0))
	return m


func ranged_bonus() -> int:
	var b := 0
	for slot in equipped:
		b += int(DB.ITEMS.get(equipped[slot], {}).get("ranged_bonus", 0))
	return b


func apply_outfit() -> void:
	var key := "default"
	if equipped.get("armor", "") == "briar_mail":
		key = "briar_mail"
	elif equipped.get("boots", "") == "zephyr_boots":
		key = "zephyr_boots"
	var pal: Array = DB.OUTFITS[key]
	var src := PackedColorArray()
	var dst := PackedColorArray()
	for pair in pal:
		src.append(Color(pair[0]))
		dst.append(Color(pair[1]))
	while src.size() < 8:
		src.append(Color(0, 0, 0, 0))
		dst.append(Color(0, 0, 0, 0))
	fx_material.set_shader_parameter("src_colors", src)
	fx_material.set_shader_parameter("dst_colors", dst)
	fx_material.set_shader_parameter("swap_count", pal.size())


func give_item(id: String) -> void:
	var item: Dictionary = DB.ITEMS.get(id, {})
	match item.get("type", ""):
		"weapon":
			if not weapons_owned.has(id):
				weapons_owned.append(id)
		"coins":
			add_petalcoins(int(item.get("amount", 0)))
		"consumable":
			moontea_max = mini(6, moontea_max + (1 if moontea_charges >= moontea_max else 0))
			moontea_charges = mini(moontea_max, moontea_charges + 1)
		"upgrade":
			heart_pieces += 1
			recalc_stats()
			health = max_health
		"key":
			pass
		_:
			if not inventory.has(id):
				inventory.append(id)
			var slot: String = item.get("type", "")
			if slot in DB.EQUIP_SLOTS and not equipped.has(slot):
				equip(id)
	health_changed.emit()


func equip(id: String) -> bool:
	var item: Dictionary = DB.ITEMS.get(id, {})
	var slot: String = item.get("type", "")
	if not slot in DB.EQUIP_SLOTS or not inventory.has(id):
		return false
	if equipped.get(slot, "") == id:
		equipped.erase(slot)
	else:
		equipped[slot] = id
	recalc_stats()
	apply_outfit()
	return true


func equip_moonheart_charm() -> bool:
	if charm_equipped:
		return false
	if not inventory.has("moonheart_charm"):
		inventory.append("moonheart_charm")
	equipped["charm"] = "moonheart_charm"
	recalc_stats()
	return true


# ------------------------------------------------------------------ petal arts
func xp_needed() -> int:
	return ClassDB.xp_needed(level)


func add_xp(amount: int) -> void:
	if amount <= 0:
		return
	xp += amount
	var leveled := false
	while level < ClassDB.LEVEL_CAP and xp >= xp_needed():
		xp -= xp_needed()
		level += 1
		skill_points += 1
		leveled = true
	recalc_stats()
	if leveled and game:
		game.fx.spawn("spark_circle", global_position + Vector2(0, -10), 0.0, 1.6, Color(1.0, 0.85, 0.6), null, true)
		game.fx.number(global_position + Vector2(0, -26), "LEVEL %d" % level, Color("ffd27a"), true)
		game.audio.play("levelup1", 0.02, -2.0)
		game.hud.show_message("Level %d! A Petal Art point to spend — press K." % level, 3.5)


func bind_class(id: String) -> bool:
	if not ClassDB.CLASSES.has(id) or classes.has(id):
		return false
	if classes.is_empty():
		classes.append(id)
	elif classes.size() == 1 and level >= ClassDB.COMBINE_LEVEL:
		classes.append(id)
	else:
		return false
	if not class_nodes.has(id):
		class_nodes[id] = {}
	_refresh_skill_bar()
	if game:
		var def: Dictionary = ClassDB.CLASSES[id]
		game.audio.play("secret2", 0.0, -3.0)
		game.fx.spawn("aura", global_position + Vector2(0, -8), 0.0, 1.4, def["color"], null, true)
		game.hud.show_message("%s line bound%s. Arts 1-4 on the keys." % [def["name"], " (combined)" if classes.size() == 2 else ""], 3.5)
	return true


func spend_node(class_id: String, node_id: String) -> bool:
	if not classes.has(class_id):
		return false
	var node: Dictionary = ClassDB.class_of(class_id).get("tree", {}).get(node_id, {})
	if node.is_empty() or skill_points < 1:
		return false
	var owned: Dictionary = class_nodes.get(class_id, {})
	if owned.has(node_id):
		return false
	for need in node.get("needs", []):
		if not owned.has(need):
			return false
	owned[node_id] = true
	class_nodes[class_id] = owned
	skill_points -= 1
	recalc_stats()
	if game:
		game.audio.play("levelup1", 0.03, -4.0)
		game.fx.burst("spark", global_position + Vector2(0, -12), 8, 60.0, Color(1, 0.9, 0.7), -40.0)
	return true


## Keep the four art slots filled with bound-class skills, primary line first.
func _refresh_skill_bar() -> void:
	skill_bar.clear()
	var seen: Dictionary = {}
	var add := func(ids: Array) -> void:
		for sid in ids:
			if skill_bar.size() >= 4 or seen.has(sid):
				continue
			seen[sid] = true
			skill_bar.append(sid)
	for cid in classes:
		add.call(ClassDB.class_of(cid).get("skills", []))


func cast_slot(index: int) -> void:
	if index < 0 or index >= skill_bar.size():
		return
	cast_skill(skill_bar[index])


func cast_skill(id: String) -> bool:
	var def: Dictionary = ClassDB.skill_of(id)
	if def.is_empty() or not game:
		return false
	if state != State.MOVE and state != State.ATTACK:
		return false
	if fishing or swimming or game.game_over:
		return false
	if float(skill_cd.get(id, 0.0)) > 0.0:
		game.audio.play("cancel", 0.0, -8.0)
		return false
	var cost := int(def["cost"])
	if focus < cost:
		game.hud.show_message("Not enough focus for %s." % def["name"], 1.5)
		game.audio.play("cancel", 0.0, -8.0)
		return false
	focus -= cost
	skill_cd[id] = float(def["cd"]) * skill_cd_scale()
	_begin_attack(0.24, 0.30)
	var atk := attack_bonus()
	var tint := Color(String(def.get("tint", "ffd9f2")))
	match String(def["exec"]):
		"strike":
			_swing_weapon(0.22, true)
			var center := global_position + Vector2(0, -6) + facing * 15.0
			game.fx.spawn(String(def.get("fx", "slash_double")), center, facing.angle(), 1.1, tint, null, true)
			game.audio.play("slash3", 0.08, -2.0)
			var hits: int = game.melee_hit(center, float(def["radius"]), _roll_crit(int(def["dmg"]) + atk), float(def["knock"]), facing, "art")
			if hits > 0:
				game.hitstop(0.07)
		"flurry":
			_swing_weapon(0.2, false)
			for i in range(int(def.get("hits", 3))):
				_fist_after(0.12 * float(i), int(def["dmg"]) + atk, tint)
		"volley":
			_swing_weapon(0.18, false, true)
			for i in range(int(def["count"])):
				_shoot_after(0.09 * float(i) - (0.09 if i == 0 else 0.0), def, atk)
			game.audio.play("slash5", 0.08, -4.0)
		"pierce":
			_swing_weapon(0.18, false, true)
			var dir: Vector2 = game.auto_aim(global_position, facing, 200.0)
			game.spawn_projectile({"kind": String(def["kind"]), "pos": global_position + Vector2(0, -9) + dir * 8.0,
				"dir": dir, "speed": float(def["speed"]), "damage": _roll_crit(int(def["dmg"]) + atk),
				"team": "player", "pierce": true, "life": 1.4})
			game.fx.spawn("spark", global_position + Vector2(0, -9) + dir * 10.0, 0.0, 0.6, tint, null, true)
			game.audio.play("magic1", 0.08, -4.0)
		"burst_point":
			var point := global_position + facing * float(def.get("dist", 64.0))
			game.fx.ring(point, float(def["radius"]), float(def["delay"]), tint)
			game.audio.play("magic3", 0.05, -6.0)
			get_tree().create_timer(float(def["delay"])).timeout.connect(func() -> void:
				if game == null:
					return
				game.fx.spawn("explosion", point, 0.0, 0.9, Color(1.0, 0.92, 0.6, 0.9), null, true)
				game.fx.shake(3.0, 0.2)
				game.audio.play("impact", 0.06, -2.0)
				game.melee_hit(point, float(def["radius"]), _roll_crit(int(def["dmg"]) + atk), 110.0, facing, "art"))
		"blink":
			var step_dir := facing
			var dist := float(def["dist"])
			if class_nodes.get("nightbloom", {}).has("veilwalker"):
				dist += 24.0
			for i in range(10, 0, -1):
				var probe := global_position + step_dir * dist * float(i) / 10.0
				if not game.world.is_solid(probe + Vector2(0, -4.0)) and not game.world.is_solid(probe + Vector2(0, 2.0)) and not game.world.is_water(probe):
					global_position = probe
					break
			buffs[String(def["buff"])] = float(def["time"])
			invulnerable_left = maxf(invulnerable_left, 0.35)
			for i in range(4):
				_afterimage()
			game.fx.spawn("ripple", global_position + Vector2(0, -4), 0.0, 1.2, tint)
			game.audio.play("spirit", 0.05, -4.0)
		"buff":
			buffs[String(def["buff"])] = float(def["time"])
			if def.has("invuln"):
				invulnerable_left = maxf(invulnerable_left, float(def["invuln"]))
				guard_fx.visible = true
				guard_fx.play("play")
			if def.has("fx"):
				game.fx.spawn(String(def["fx"]), global_position + Vector2(0, -8), 0.0, 1.5, tint, null, true)
			game.audio.play("magic1", 0.05, -3.0)
		"heal":
			health = mini(max_health, health + int(def["heal"]))
			health_changed.emit()
			game.fx.spawn("aura", global_position + Vector2(0, -8), 0.0, 1.3, tint, null, true)
			game.fx.burst("spark", global_position + Vector2(0, -10), 10, 50.0, Color(0.8, 1.0, 0.85), -40.0)
			game.fx.number(global_position + Vector2(0, -18), "+2", Color("9cf5a5"))
			game.audio.play("heal", 0.03, -3.0)
		"aoe":
			var hits2: int = game.melee_hit(global_position + Vector2(0, -6), float(def["radius"]), _roll_crit(int(def["dmg"]) + atk), float(def["knock"]), Vector2.ZERO, "art")
			if def.has("invuln"):
				invulnerable_left = maxf(invulnerable_left, float(def["invuln"]))
			game.fx.ring(global_position + Vector2(0, -6), float(def["radius"]), 0.4, tint)
			game.fx.burst("spark", global_position + Vector2(0, -10), 14, 90.0, tint, -30.0)
			game.audio.play("magic3", 0.05, -2.0)
			if hits2 > 0:
				game.hitstop(0.05)
		"vamp":
			var hits3: int = game.melee_hit(global_position + Vector2(0, -6), float(def["radius"]), _roll_crit(int(def["dmg"]) + atk), float(def.get("knock", 60.0)), Vector2.ZERO, "art")
			if hits3 > 0:
				var per := int(def.get("heal", 2))
				if class_nodes.get("gravetender", {}).has("second_breath"):
					per += 1
				health = mini(max_health, health + per * hits3)
				health_changed.emit()
				game.fx.burst("spark", global_position + Vector2(0, -12), 6 * hits3, 60.0, tint, -60.0)
				game.fx.number(global_position + Vector2(0, -18), "+%d" % (per * hits3), Color("9cf5a5"))
			game.fx.ring(global_position + Vector2(0, -6), float(def["radius"]), 0.35, tint)
			game.audio.play("spirit" if hits3 > 0 else "magic1", 0.05, -3.0)
	return true


func _fist_after(delay: float, dmg: int, tint: Color) -> void:
	get_tree().create_timer(delay).timeout.connect(func() -> void:
		if game == null or state == State.DEAD:
			return
		var center := global_position + Vector2(0, -6) + facing * 14.0
		game.fx.spawn("slash", center, facing.angle(), 0.7, tint, null, true)
		game.audio.play("slash" if int(delay * 20.0) % 2 == 0 else "slash2", 0.08, -5.0)
		game.melee_hit(center, 18.0, _roll_crit(dmg), 50.0, facing, "art"))


func _shoot_after(delay: float, def: Dictionary, atk: int) -> void:
	get_tree().create_timer(maxf(delay, 0.01)).timeout.connect(func() -> void:
		if game == null or state == State.DEAD:
			return
		var dir: Vector2 = game.auto_aim(global_position, facing, 220.0)
		var spread := float(def.get("spread", 0.0))
		var n := int(def.get("count", 3))
		var idx := int(round(delay / 0.09)) if n > 1 else 0
		var angle_off := 0.0
		if spread > 0.0 and n > 1:
			angle_off = (-1.0 + 2.0 * float(idx) / float(n - 1)) * spread
		dir = dir.rotated(angle_off)
		game.spawn_projectile({"kind": String(def["kind"]), "pos": global_position + Vector2(0, -9) + dir * 8.0,
			"dir": dir, "speed": float(def["speed"]), "damage": _roll_crit(int(def["dmg"]) + atk),
			"team": "player", "homing": float(def.get("homing", 0.0)), "life": 1.0})
		game.audio.play("launch", 0.08, -8.0))


func add_petalcoins(amount: int) -> void:
	petalcoins += maxi(0, amount)
	health_changed.emit()


func cycle_weapon() -> void:
	weapon_index = (weapon_index + 1) % weapons_owned.size()
	attack_combo = -1
	combo_timer = 0.0
	bow_charge = -1.0
	if game:
		game.audio.play("menu5", 0.02, -6.0)


func get_weapon_id() -> String:
	return weapons_owned[clampi(weapon_index, 0, weapons_owned.size() - 1)]


func get_weapon_name() -> String:
	return String(DB.ITEMS[get_weapon_id()]["name"]).to_upper()


func get_status() -> Dictionary:
	return {"health": health, "max_health": max_health, "moontea": moontea_charges, "petalcoins": petalcoins, "weapon": get_weapon_name(),
		"mothlight_cooldown": mothlight_cooldown, "guard_cooldown": guard_cooldown, "guard_active": guard_active,
		"charm_equipped": charm_equipped, "cloak_equipped": cloak_equipped, "stamina": stamina}


# ------------------------------------------------------------------ loop
func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	var input := Vector2.ZERO
	if input_enabled and state != State.DEAD and state != State.POSE:
		input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input.length() > 0.1 and (state == State.MOVE or state == State.JUMP):
		_set_facing(input)
	if game and not airborne:
		swimming = game.world.is_water(global_position)
	if swimming != _was_swimming:
		_was_swimming = swimming
		if game:
			game.audio.play("water5" if swimming else "water1", 0.1, -4.0, global_position)
			game.fx.spawn("ripple", global_position + Vector2(0, -2), 0.0, 1.3)
	match state:
		State.MOVE:
			_state_move(delta, input)
		State.ROLL:
			_state_roll(delta)
		State.JUMP:
			_state_jump(delta, input)
		State.ATTACK:
			_state_attack(delta, input)
		State.HURT:
			velocity = velocity.move_toward(Vector2.ZERO, 600.0 * delta)
			if _lock_t <= 0.0:
				state = State.MOVE
		State.DEAD, State.POSE:
			velocity = velocity.move_toward(Vector2.ZERO, 900.0 * delta)
	velocity += knockback
	knockback = knockback.move_toward(Vector2.ZERO, 900.0 * delta)
	var before := global_position
	move_and_slide()
	pushing = state == State.MOVE and input.length() > 0.5 and global_position.distance_to(before) < 0.25 and get_slide_collision_count() > 0
	_update_anim(input)
	_update_visuals(delta)


func _tick_timers(delta: float) -> void:
	_lock_t = maxf(0.0, _lock_t - delta)
	invulnerable_left = maxf(0.0, invulnerable_left - delta)
	parry_cooldown = maxf(0.0, parry_cooldown - delta)
	for b in buffs.keys():
		buffs[b] = float(buffs[b]) - delta
		if float(buffs[b]) <= 0.0:
			buffs.erase(b)
	for k in skill_cd.keys():
		skill_cd[k] = maxf(0.0, float(skill_cd[k]) - delta)
	focus = minf(focus_max, focus + 6.0 * delta)
	attack_left = maxf(0.0, attack_left - delta)
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	combo_timer = maxf(0.0, combo_timer - delta)
	if combo_timer <= 0.0 and state != State.ATTACK:
		attack_combo = -1
	mothlight_cooldown = maxf(0.0, mothlight_cooldown - delta)
	guard_cooldown = maxf(0.0, guard_cooldown - delta)
	guard_time_left = maxf(0.0, guard_time_left - delta)
	if guard_time_left <= 0.0:
		guard_active = false
	stamina_delay = maxf(0.0, stamina_delay - delta)
	if stamina_delay <= 0.0 and not sprinting:
		stamina = minf(STAMINA_MAX, stamina + 38.0 * stamina_regen_mult() * delta)
	if _hammer_pending > 0.0:
		_hammer_pending -= delta
		if _hammer_pending <= 0.0:
			_hammer_impact()


func _set_facing(direction: Vector2) -> void:
	facing = direction.normalized()
	if absf(direction.x) > absf(direction.y) * 2.0:
		facing_direction = Facing.RIGHT if direction.x > 0.0 else Facing.LEFT
	elif absf(direction.y) > absf(direction.x) * 2.0:
		facing_direction = Facing.DOWN if direction.y > 0.0 else Facing.UP
	elif direction.y > 0.0:
		facing_direction = Facing.DOWN_RIGHT if direction.x > 0.0 else Facing.DOWN_LEFT
	else:
		facing_direction = Facing.UP_RIGHT if direction.x > 0.0 else Facing.UP_LEFT
	dir_name = AnimLib.dir_name(direction)


func _state_move(delta: float, input: Vector2) -> void:
	var want_sprint := Input.is_action_pressed("sprint") and input.length() > 0.2 and not swimming
	sprinting = want_sprint and stamina > 1.0
	if sprinting:
		stamina = maxf(0.0, stamina - 24.0 * delta)
		stamina_delay = 0.55
	var speed := get_move_speed()
	if swimming:
		speed = SWIM_SPEED
	elif sprinting:
		speed = SPRINT_SPEED * (get_move_speed() / WALK_SPEED)
	if bow_charge >= 0.0:
		speed *= 0.45
	velocity = velocity.move_toward(input * speed, ACCEL * delta)
	if not input_enabled:
		return
	if Input.is_action_just_pressed("dash"):
		start_roll(input)
	elif Input.is_action_just_pressed("jump"):
		start_jump()
	if bow_charge >= 0.0:
		bow_charge += delta
		if not Input.is_action_pressed("attack"):
			_release_bow()
	elif Input.is_action_just_pressed("attack"):
		try_attack()


func start_roll(input := Vector2.ZERO) -> bool:
	if state != State.MOVE or swimming or fishing or stamina < 18.0:
		return false
	stamina -= 22.0
	stamina_delay = 0.6
	roll_dir = input.normalized() if input.length() > 0.1 else facing
	_set_facing(roll_dir)
	state = State.ROLL
	roll_t = ROLL_TIME
	invulnerable_left = maxf(invulnerable_left, ROLL_TIME * 0.85)
	bow_charge = -1.0
	if game:
		game.audio.play("jump2", 0.1, -6.0)
		game.fx.dust(global_position)
	return true


func _state_roll(delta: float) -> void:
	roll_t -= delta
	var k := clampf(roll_t / ROLL_TIME, 0.0, 1.0)
	velocity = roll_dir * ROLL_SPEED * (0.35 + 0.65 * k)
	_ghost_t -= delta
	if _ghost_t <= 0.0:
		_ghost_t = 0.045
		_afterimage()
	if roll_t <= 0.0:
		state = State.MOVE
		velocity *= 0.5


func start_jump() -> bool:
	if state != State.MOVE or airborne or stamina < 8.0:
		return false
	stamina -= 10.0
	stamina_delay = 0.5
	state = State.JUMP
	airborne = true
	plunge = false
	jump_t = 0.0
	collision_mask = MASK_AIR
	bow_charge = -1.0
	if swimming:
		velocity *= 0.6
	if game:
		game.audio.play("jump", 0.1, -5.0)
		if swimming:
			game.fx.spawn("ripple", global_position, 0.0, 1.4)
		else:
			game.fx.dust(global_position, 0.35)
	return true


func _state_jump(delta: float, input: Vector2) -> void:
	jump_t += delta
	var target := input * (SPRINT_SPEED if sprinting else get_move_speed()) * 1.05
	velocity = velocity.move_toward(target, ACCEL * 0.45 * delta)
	if input_enabled and Input.is_action_just_pressed("attack") and not plunge:
		plunge = true
		jump_t = maxf(jump_t, JUMP_TIME * 0.55)
	var k := clampf(jump_t / JUMP_TIME, 0.0, 1.0)
	sprite.position.y = -4.0 * JUMP_HEIGHT * k * (1.0 - k)
	if k >= 1.0:
		if _overlapping_low():
			jump_t = JUMP_TIME * 0.98
			velocity = velocity.normalized() * maxf(velocity.length(), 60.0) if velocity.length() > 1.0 else facing * 60.0
			return
		_land()


func _overlapping_low() -> bool:
	var space := get_world_2d().direct_space_state
	var q := PhysicsShapeQueryParameters2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 4.5
	q.shape = shape
	q.transform = Transform2D(0.0, global_position + Vector2(0, -2))
	q.collision_mask = 4
	return space.intersect_shape(q, 1).size() > 0


func _land() -> void:
	airborne = false
	sprite.position.y = 0.0
	collision_mask = MASK_GROUND
	state = State.MOVE
	if game:
		swimming = game.world.is_water(global_position)
		if swimming:
			game.audio.play("water5", 0.1, -3.0)
			game.fx.spawn("ripple", global_position, 0.0, 1.6)
		else:
			game.audio.play("bounce", 0.1, -10.0)
			game.fx.dust(global_position + Vector2(-5, 0), 0.32)
			game.fx.dust(global_position + Vector2(5, 0), 0.32)
		if plunge:
			plunge = false
			game.fx.spawn("explosion", global_position + Vector2(0, -6), 0.0, 0.7, Color(1, 0.9, 1.0, 0.85))
			game.fx.shake(2.5, 0.16)
			game.melee_hit(global_position, 24.0, _roll_crit(3 + attack_bonus()), 140.0, Vector2.ZERO, "plunge")
			game.audio.play("impact", 0.1, -2.0)


func try_attack() -> bool:
	if fishing or attack_cooldown > 0.0 or roll_t > 0.0 or swimming or state == State.ROLL:
		return false
	if state != State.MOVE and state != State.ATTACK:
		return false
	var wid := get_weapon_id()
	match wid:
		"thornblade", "duskfan":
			_attack_blade()
		"bloomstaff":
			_attack_staff()
		"gale_bow":
			bow_charge = 0.0
			sprite.play("attack_" + dir_name)
			sprite.pause()
			return true
		"ironroot_hammer":
			_attack_hammer()
	return true


func _begin_attack(lock: float, cooldown: float) -> void:
	state = State.ATTACK
	_lock_t = lock
	attack_left = lock
	attack_cooldown = cooldown
	sprite.play("attack_" + dir_name)
	sprite.frame = 0


func _attack_blade() -> void:
	_snap_to_target(40.0)
	if combo_timer <= 0.0:
		attack_combo = -1
	attack_combo = (attack_combo + 1) % 3
	var finisher := attack_combo == 2
	combo_timer = 0.62
	_begin_attack(0.30 if finisher else 0.22, 0.34 if finisher else 0.24)
	velocity = facing * (150.0 if finisher else 95.0)
	_swing_weapon(0.2, finisher)
	var center := global_position + Vector2(0, -6) + facing * 13.0
	if game:
		game.fx.spawn("slash_double" if finisher else "slash", center, facing.angle() + (0.0 if attack_combo != 1 else PI), 1.15 if finisher else 0.9, Color(1, 0.86, 0.95) if not finisher else Color(1, 0.95, 0.75), null, true)
		game.audio.play("slash" if attack_combo == 0 else ("slash2" if attack_combo == 1 else "slash3"), 0.08, -3.0)
		var base := int(DB.ITEMS[get_weapon_id()].get("damage", 2))
		var dmg := _roll_crit(base + attack_bonus() if not finisher else base * 2 + attack_bonus())
		var hits: int = game.melee_hit(center, 21.0 if finisher else 17.0, dmg, 110.0 if finisher else 55.0, facing, "blade")
		if hits > 0:
			game.hitstop(0.06 if finisher else 0.035)


func _attack_staff() -> void:
	_begin_attack(0.26, 0.42)
	_swing_weapon(0.18, false, true)
	if game:
		var dir: Vector2 = game.auto_aim(global_position, facing, 150.0)
		game.spawn_projectile({"kind": "bolt", "pos": global_position + Vector2(0, -9) + dir * 8.0, "dir": dir, "speed": 215.0,
			"damage": 3 + ranged_bonus(), "team": "player", "homing": 4.0, "life": 1.2})
		game.fx.spawn("spark", global_position + Vector2(0, -9) + dir * 10.0, 0.0, 0.5, Color(0.8, 0.95, 1.0), null, true)
		game.audio.play("magic1", 0.08, -5.0)


func _release_bow() -> void:
	var charged := bow_charge >= 0.55
	bow_charge = -1.0
	_begin_attack(0.2, 0.3)
	_swing_weapon(0.15, false, true)
	if game:
		var dir: Vector2 = game.auto_aim(global_position, facing, 190.0)
		game.spawn_projectile({"kind": "arrow", "pos": global_position + Vector2(0, -8) + dir * 8.0, "dir": dir,
			"speed": 360.0 if charged else 280.0, "damage": (6 if charged else 3) + ranged_bonus(), "team": "player", "pierce": charged, "life": 1.0, "glow": charged})
		game.audio.play("launch" if charged else "slash5", 0.08, -4.0)
		if charged:
			game.fx.spawn("spark", global_position + Vector2(0, -8) + dir * 12.0, 0.0, 0.6, Color(0.8, 1.0, 0.9), null, true)


func _attack_hammer() -> void:
	_begin_attack(0.5, 0.62)
	velocity = facing * 40.0
	_swing_weapon(0.32, true)
	_hammer_pending = 0.24


func _hammer_impact() -> void:
	if game == null:
		return
	_snap_to_target(44.0)
	var center := global_position + Vector2(0, -3) + facing * 16.0
	game.fx.spawn("explosion", center, 0.0, 0.8, Color(1, 0.95, 0.85, 0.9))
	game.fx.burst("rock", center, 10, 90.0, Color(1, 1, 1), 220.0)
	game.fx.ring(center, 30.0, 0.25, Color(1.0, 0.9, 0.7, 0.8), false)
	game.fx.shake(4.0, 0.22)
	game.audio.play("impact3", 0.06, -1.0)
	var base := int(DB.ITEMS[get_weapon_id()].get("damage", 5))
	var hits: int = game.melee_hit(center, 28.0, _roll_crit(base + attack_bonus()), 160.0, facing, "hammer")
	if hits > 0:
		game.hitstop(0.08)


## Target-snapping melee: if the closest enemy is within reach and not behind
## Mallow, turn the swing toward it so basic attacks follow the fight.
func _snap_to_target(reach: float) -> void:
	if game == null:
		return
	var t: Node2D = game.nearest_enemy(global_position, reach * 1.6)
	if t == null:
		return
	var to: Vector2 = (t.global_position + Vector2(0, -5)) - global_position
	if to.length() > reach * 1.6:
		return
	if facing.dot(to.normalized()) < -0.2:
		return
	_set_facing(to)


func _swing_weapon(duration: float, heavy: bool, point := false) -> void:
	var item: Dictionary = DB.ITEMS[get_weapon_id()]
	var t: Texture2D = AnimLib.tex(item["hand"])
	weapon_sprite.texture = t
	weapon_sprite.offset = Vector2(-t.get_width() / 2.0, -t.get_height())
	var hand := {"down": Vector2(3, -6), "up": Vector2(-3, -10), "left": Vector2(-4, -7), "right": Vector2(4, -7)}
	weapon_sprite.position = hand[dir_name]
	weapon_sprite.z_index = -1 if dir_name == "up" else 1
	weapon_sprite.visible = true
	var base := facing.angle() + PI / 2.0
	var tw := create_tween()
	if point:
		weapon_sprite.rotation = base - 0.4
		tw.tween_property(weapon_sprite, "rotation", base, duration * 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_interval(duration * 0.6)
	else:
		var arc := 1.9 if heavy else 1.5
		var sgn := -1.0 if attack_combo == 1 else 1.0
		weapon_sprite.rotation = base - arc * sgn
		tw.tween_property(weapon_sprite, "rotation", base + arc * sgn, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: weapon_sprite.visible = false)


func _state_attack(delta: float, _input: Vector2) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, 700.0 * delta)
	if _lock_t <= 0.0:
		state = State.MOVE
	elif input_enabled and Input.is_action_just_pressed("attack") and get_weapon_id() == "thornblade" and _lock_t < 0.12:
		state = State.MOVE
		attack_cooldown = 0.0
		try_attack()
	elif input_enabled and Input.is_action_just_pressed("dash"):
		state = State.MOVE
		start_roll(Input.get_vector("move_left", "move_right", "move_up", "move_down"))


func activate_mothlight() -> bool:
	if mothlight_cooldown > 0.0 or state == State.DEAD:
		return false
	mothlight_cooldown = 6.0
	if game:
		game.fx.spawn("spark_circle", global_position + Vector2(0, -8), 0.0, 2.4, Color(1.0, 0.72, 0.85, 0.55), null, true)
		game.fx.spawn("magic_circle", global_position + Vector2(0, -2), 0.0, 2.2, Color(0.8, 0.6, 1.0, 0.5), null, true)
		game.fx.burst("spark", global_position + Vector2(0, -8), 18, 120.0, Color(1, 0.85, 0.75), 0.0, 0.8)
		game.audio.play("magic3", 0.05, -2.0)
		game.flash_light(global_position, Color(1.0, 0.75, 0.85), 0.55, 0.5)
		game.melee_hit(global_position + Vector2(0, -6), 72.0, _roll_crit(3 + attack_bonus()), 130.0, Vector2.ZERO, "mothlight")
	return true


func activate_petalguard() -> bool:
	if guard_cooldown > 0.0 or guard_active or state == State.DEAD:
		return false
	guard_cooldown = 10.0
	guard_time_left = 5.0
	guard_active = true
	guard_fx.visible = true
	guard_fx.play("play")
	if game:
		game.audio.play("spirit", 0.05, -4.0)
		game.fx.spawn("aura", global_position + Vector2(0, -8), 0.0, 1.4, Color(1, 0.8, 0.95), null, true)
	return true


func drink_moontea() -> bool:
	if moontea_charges <= 0 or health >= max_health or state == State.DEAD:
		return false
	moontea_charges -= 1
	health = mini(max_health, health + HEART * 2)
	health_changed.emit()
	if game:
		game.audio.play("heal", 0.03, -3.0)
		game.fx.spawn("aura", global_position + Vector2(0, -8), 0.0, 1.3, Color(0.75, 1.0, 0.8), null, true)
		game.fx.burst("spark", global_position + Vector2(0, -10), 10, 50.0, Color(0.8, 1.0, 0.85), -40.0)
		game.fx.number(global_position, "+2", Color("9cf5a5"))
	return true


func take_damage(amount: int = 2, from := Vector2.INF) -> bool:
	if state == State.DEAD:
		return false
	if guard_active:
		guard_active = false
		guard_time_left = 0.0
		invulnerable_left = 0.45
		if game:
			game.audio.play("bubble", 0.05, -2.0)
			game.fx.spawn("shield", global_position + Vector2(0, -9), 0.0, 1.6, Color(1, 0.85, 1.0), null, true)
		return false
	if roll_t > 0.0:
		# perfect parry: if the hit lands in the first half of the roll
		if parry_cooldown <= 0.0 and roll_t >= ROLL_TIME * 0.55:
			parry_cooldown = 2.0
			if game:
				game.on_perfect_parry(self)
		return false
	if invulnerable_left > 0.0:
		return false
	if amount > 1 and defense_total() > 0:
		amount = maxi(1, amount - defense_total())
	health = maxi(0, health - amount)
	invulnerable_left = 1.0
	bow_charge = -1.0
	var poise := 1.0
	for slot in equipped:
		poise -= float(DB.ITEMS.get(equipped[slot], {}).get("poise", 0.0))
	if from != Vector2.INF:
		var away := (global_position - from).normalized()
		knockback = away * 140.0 * poise
	_flash(Color(1, 0.35, 0.4))
	hit_taken.emit(amount)
	health_changed.emit()
	if health <= 0:
		_die()
	elif state != State.JUMP:
		state = State.HURT
		_lock_t = 0.22
		sprite.play("hit_" + dir_name)
	return true


func heal_full() -> void:
	health = max_health
	moontea_charges = moontea_max
	health_changed.emit()


func _die() -> void:
	state = State.DEAD
	airborne = false
	sprite.position.y = 0.0
	collision_mask = MASK_GROUND
	sprite.play("dead_down")
	died.emit()


func revive(at: Vector2) -> void:
	global_position = at
	state = State.MOVE
	velocity = Vector2.ZERO
	knockback = Vector2.ZERO
	roll_t = 0.0
	airborne = false
	sprite.position.y = 0.0
	collision_mask = MASK_GROUND
	invulnerable_left = 1.5
	heal_full()
	fx_material.set_shader_parameter("dissolve", 0.0)


func pose_item(texture: Texture2D, duration := 1.4) -> void:
	state = State.POSE
	sprite.play("item_down")
	held_item.texture = texture
	held_item.visible = true
	held_item.scale = Vector2(0.2, 0.2)
	var tw := create_tween()
	tw.tween_property(held_item, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(duration)
	tw.tween_callback(_end_pose)


func _end_pose() -> void:
	held_item.visible = false
	if state == State.POSE:
		state = State.MOVE


func _flash(c: Color) -> void:
	fx_material.set_shader_parameter("flash_color", c)
	fx_material.set_shader_parameter("flash", 0.85)
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: fx_material.set_shader_parameter("flash", v), 0.85, 0.0, 0.25)


func _afterimage() -> void:
	if game == null:
		return
	var g := Sprite2D.new()
	g.texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	g.flip_h = sprite.flip_h
	g.global_position = global_position + sprite.offset + sprite.position
	g.modulate = Color(0.95, 0.6, 0.85, 0.5)
	g.z_index = -1
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	g.material = m
	game.fx.add_child(g)
	var tw := g.create_tween()
	tw.tween_property(g, "modulate:a", 0.0, 0.22)
	tw.tween_callback(g.queue_free)


# ------------------------------------------------------------------ animation
func _update_anim(input: Vector2) -> void:
	var anim := ""
	match state:
		State.MOVE:
			if bow_charge >= 0.0:
				return
			if swimming:
				anim = "swim"
			elif pushing:
				anim = "push"
			elif velocity.length() > 10.0:
				anim = "walk"
			else:
				anim = "idle"
			sprite.speed_scale = 1.55 if sprinting else 1.0
		State.ROLL:
			anim = "roll"
			sprite.speed_scale = 1.0
		State.JUMP:
			var dn := dir_name
			sprite.flip_h = dn == "right"
			var j := "jump_" + ("left" if dn == "right" else dn)
			if sprite.animation != j:
				sprite.play(j)
			return
		_:
			return
	sprite.flip_h = false
	var full := "%s_%s" % [anim, dir_name]
	if sprite.animation != full:
		sprite.play(full)
	elif not sprite.is_playing():
		sprite.play(full)


func _update_visuals(delta: float) -> void:
	var h := -sprite.position.y
	var s := 1.0 - clampf(h / 30.0, 0.0, 0.45)
	shadow.scale = Vector2(0.5, 0.42) * s
	shadow.visible = not swimming or airborne
	# basic-attack range hint: shows whenever a target hovers near melee reach
	if range_hint != null:
		var wid := get_weapon_id()
		var melee: bool = wid == "thornblade" or wid == "duskfan" or wid == "ironroot_hammer"
		var near := game != null and game.nearest_enemy(global_position, 40.0) != null
		range_hint.visible = melee and near and state == State.MOVE and not swimming and not airborne and game.game_started
		range_hint.pulse(delta)
	if invulnerable_left > 0.0 and state != State.ROLL and state != State.DEAD:
		sprite.modulate.a = 0.45 if int(invulnerable_left * 20.0) % 2 == 0 else 1.0
	else:
		sprite.modulate.a = 1.0
	guard_fx.visible = guard_active
	fx_material.set_shader_parameter("outline", 0.0 if bow_charge < 0.55 else 0.9)
	if game == null:
		return
	if state == State.MOVE and velocity.length() > 20.0:
		_step_t -= delta * (1.6 if sprinting else 1.0)
		if _step_t <= 0.0:
			_step_t = 0.26
			if swimming:
				game.fx.spawn("ripple", global_position + Vector2(0, -1), 0.0, 1.0, Color(1, 1, 1, 0.8))
			elif sprinting:
				game.fx.dust(global_position, 0.3)
			var b: int = game.world.biome_at(global_position)
			if not swimming and (b == 2 or b == 5 or b == 3):
				game.fx.burst("snow" if b == 3 else "rock", global_position, 2, 18.0, Color(1, 0.95, 0.85, 0.7) if b != 3 else Color(1, 1, 1, 0.8), 60.0, 0.35)
	elif swimming and state == State.MOVE:
		_ripple_t -= delta
		if _ripple_t <= 0.0:
			_ripple_t = 0.9
			game.fx.spawn("ripple", global_position, 0.0, 1.1, Color(1, 1, 1, 0.6))



# ------------------------------------------------------------------ inner widgets
class RangeHint:
	extends Node2D
	## A faint pulsing ring that shows basic-attack reach when enemies are near.
	var radius := 26.0
	var _t := 0.0

	func pulse(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var a := 0.22 + 0.14 * (0.5 + 0.5 * sin(_t * 5.0))
		draw_arc(Vector2(0, -4), radius, 0.0, TAU, 48, Color(1.0, 0.55, 0.75, a), 1.5)
		draw_arc(Vector2(0, -4), radius - 2.5, 0.0, TAU, 48, Color(1.0, 0.75, 0.85, a * 0.5), 1.0)
