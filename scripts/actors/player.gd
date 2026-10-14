extends CharacterBody2D
## Mallow, the rose-hooded wanderer. Walk, sprint, dodge-roll, jump hedges, swim,
## four weapons with distinct attacks, two skills, outfits that recolour the sprite.
## Petal Arts update: class lines with skill trees, focus, XP levels, target-snapping
## melee with a range hint, softer knockback, and an equipment-driven defense stat.

const AnimLib := preload("res://scripts/core/anim_lib.gd")
const DB := preload("res://scripts/data/db.gd")
const ClassBook := preload("res://scripts/data/classdb.gd")
const CD := preload("res://scripts/data/combat_data.gd")
const Build := preload("res://scripts/combat/build.gd")
const StatusFx := preload("res://scripts/combat/status.gd")
const Ind := preload("res://scripts/combat/indicators.gd")
const ZoneScript := preload("res://scripts/combat/zone.gd")
const ThrallScript := preload("res://scripts/combat/thrall.gd")
const KB := preload("res://scripts/combat/knockback.gd")
const HeroLook := preload("res://scripts/actors/hero_look.gd")
const CloakLayer := preload("res://scripts/actors/cloak_layer.gd")
const ChargeCtl := preload("res://scripts/combat/charge_attack.gd")
const Specials := preload("res://scripts/combat/weapon_specials.gd")
const Assassin := preload("res://scripts/combat/assassin_arts.gd")
const HERO_SHADER := preload("res://assets/shaders/hero_layers.gdshader")
const SPRITE_SHADER := preload("res://assets/shaders/sprite_fx.gdshader")
const HERO := "res://assets/packs/ninja_adventure/hero/"

signal hit_taken(amount: int)
signal died
signal health_changed
## Build/loadout/cooldown-affecting changes (HUD refreshes on this).
signal stats_changed
signal inventory_changed
signal skill_cast(id: String)
signal damage_dealt(target: Node, amount: int, crit: bool, element: String)

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
var weapons_owned: Array[String] = ["fists"]
var equipped: Dictionary = {"cloak": "plum_cloak"}
var inventory: Array[String] = ["plum_cloak"]
var moontea_charges := 3
var moontea_max := 3
var petalcoins := 0
var attack_combo := -1
var combo_timer := 0.0
var attack_cooldown := 0.0
var attack_left := 0.0
var mothlight_cooldown: float:
	get:
		return float(skill_cd.get("mothlight", 0.0))
	set(value):
		skill_cd["mothlight"] = value
var guard_cooldown: float:
	get:
		return float(skill_cd.get("petalguard", 0.0))
	set(value):
		skill_cd["petalguard"] = value
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
## Always-visible basic-attack indicator (kept under its old name for callers).
var range_hint: Node2D
var aim_indicator: Node2D
var target_marker: Node2D

# combat overhaul state
var stats: Dictionary = {}
var skill_levels: Dictionary = {}
var rewards_claimed: Dictionary = {}
var last_equip_error := ""
var current_target: Node2D
var manual_target: Node2D
var auto_target_enabled := true
var aim_assist := true
var attack_indicator_opacity := 1.0
var dodge_cd := 0.0
var flask_cd := 0.0
var relic_cd := 0.0
var prism_index := 0
var _target_t := 0.0
var _attack_is_finisher := false
## Nightfang "Flurry": consecutive hits on one foe build a small, capped crit bonus.
const FLURRY_CRIT := 0.04
const FLURRY_MAX := 3
const FLURRY_TIME := 2.0
var _flurry_target := 0
var _flurry_stacks := 0
var _flurry_t := 0.0
var _attack_charged := false
var _last_crit := false
var _ls_acc := 0.0
var _overcharge_cd := 0.0
var _charge: Dictionary = {}
# ---- arsenal pass
## Weapons shown in the HUD weapon bar (max CD.BALANCE.weapon_bar_max, fists never listed).
var weapon_bar: Array[String] = []
var _switch_lock := 0.0
var charge := ChargeCtl.new()
var clone_ref: Node = null
var last_whip: Dictionary = {}
var last_burst: Dictionary = {}
var last_hook: Dictionary = {}
var last_rush: Dictionary = {}
var barrage_hits := 0
var _rush: Dictionary = {}
var _ls_sec := 0.0      # lifesteal HP healed in the current one-second window
var _ls_window := 0.0
var _dash_prev := Vector2.ZERO
var _dash_frames := 0
var _dash_speed := 0.0
var _dash_time := 0.0
var _thrall: Node2D
var _next_zone_style := "ring"
## Attack direction rule (see attack_direction): deliberate stick input wins,
## then a locked target, then the auto-target, then the current facing.
const ATTACK_BUFFER := 0.22
const INTENT_DEADZONE := 0.35
const ASSIST_CONE := 0.64   # cos(50 deg): stick within this cone of a target snaps to it
var _attack_buffer := 0.0
var _attack_dir_source := "facing"
var move_intent_override := Vector2.INF   # tests can inject stick input
var off_weapon_sprite: Sprite2D
## Procedural cape for the equipped cloak (see cloak_layer.gd).
var cloak_layer: Node2D
var appearance: Dictionary = {}
## Stackable bag (materials, consumables, quest items): id -> count.
var bag: Dictionary = {}
const Inv := preload("res://scripts/systems/inventory.gd")

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
	fx_material.shader = HERO_SHADER
	fx_material.set_shader_parameter("noise_tex", load("res://assets/data/noise.png"))
	sprite.material = fx_material
	sprite.animation_changed.connect(_on_sprite_anim_changed)
	add_child(sprite)
	cloak_layer = CloakLayer.new()
	cloak_layer.name = "Cloak"
	cloak_layer.visible = false
	add_child(cloak_layer)
	move_child(cloak_layer, sprite.get_index())
	charge.setup(self)
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
	range_hint = Ind.AttackIndicator.new()
	range_hint.z_index = -2
	range_hint.show_behind_parent = true
	add_child(range_hint)
	aim_indicator = Ind.AimIndicator.new()
	aim_indicator.visible = false
	aim_indicator.z_index = -1
	add_child(aim_indicator)
	target_marker = Ind.TargetMarker.new()
	target_marker.visible = false
	target_marker.top_level = true
	target_marker.z_index = -3
	add_child(target_marker)
	_ensure_bar()
	apply_outfit()
	recalc_stats()
	health = max_health
	sprite.play("idle_down")


func _register_inputs() -> void:
	_add_keys("move_up", [KEY_W, KEY_UP])
	_add_keys("move_down", [KEY_S, KEY_DOWN])
	_add_keys("move_left", [KEY_A, KEY_LEFT])
	_add_keys("move_right", [KEY_D, KEY_RIGHT])
	_add_keys("sprint", [KEY_SHIFT])
	_add_keys("jump", [KEY_C, KEY_L])
	_add_keys("attack", [KEY_J, KEY_ENTER])
	_add_keys("skill", [KEY_F])
	_add_keys("guard", [KEY_G])
	_add_keys("heal", [KEY_R])
	_add_keys("switch_weapon", [KEY_Q, KEY_TAB])
	# weapon bar slots 1-5 on 6,7,8,9,0 (1-5 are the arts and relic)
	var slot_keys := [KEY_6, KEY_7, KEY_8, KEY_9, KEY_0]
	for i in range(5):
		_add_keys("weapon_slot_%d" % (i + 1), [slot_keys[i]])
	_add_keys("inventory", [KEY_I, KEY_B])
	_add_keys("interact", [KEY_E])
	_add_keys("map", [KEY_M])
	_add_keys("pause", [KEY_ESCAPE, KEY_P])
	_add_keys("photo", [KEY_F9])
	_add_keys("arts", [KEY_K])
	_add_keys("journeys", [KEY_H])
	_add_keys("craft", [KEY_U])
	_add_keys("art1", [KEY_1])
	_add_keys("art2", [KEY_2])
	_add_keys("art3", [KEY_3])
	_add_keys("art4", [KEY_4])
	_add_keys("relic", [KEY_5, KEY_V])
	_add_keys("target_next", [KEY_T])
	_add_joy("attack", JOY_BUTTON_X)
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
## Recompute every passive stat from scratch (Build.compute_stats) so gear,
## tree nodes and line attributes are applied exactly once.
func recalc_stats() -> void:
	stats = Build.compute_stats(self)
	var hearts := base_hearts + heart_pieces + int(stats["hearts"])
	var old_max := max_health
	max_health = hearts * HEART
	if max_health > old_max:
		health = mini(max_health, health + (max_health - old_max))
	health = mini(health, max_health)
	var old_focus := focus_max
	focus_max = float(FOCUS_BASE + 2 * (level - 1) + int(stats["focus"]))
	focus = clampf(focus, 0.0, focus_max)
	if focus_max > old_focus and old_focus > 0.0:
		focus += focus_max - old_focus
		focus = clampf(focus, 0.0, focus_max)
	_refresh_attack_indicator()
	health_changed.emit()
	stats_changed.emit()


func stat(key: String) -> float:
	return float(stats.get(key, 0.0))


## Kept for compatibility with older callers: tree-only sum of one stat.
func _tree_sum(key: String) -> float:
	var total := 0.0
	for cid in classes:
		var nodes: Dictionary = class_nodes.get(cid, {})
		for nid in nodes:
			var node: Dictionary = ClassBook.class_of(cid).get("tree", {}).get(nid, {})
			total += float(node.get("effect", {}).get(key, 0.0))
	return total


func attack_bonus() -> int:
	return int(stat("atk"))


func defense_total() -> int:
	var d := int(stat("defense"))
	var bonus := 0
	if buffs.has("bulwark"):
		bonus += 2
	if buffs.has("relic_barkskin"):
		bonus += 2
	return mini(d, int(CD.BALANCE["defense_cap"])) + bonus


func crit_chance() -> float:
	var c := 0.03 + stat("crit")
	if buffs.has("marked"):
		c += 0.30
	if buffs.has("relic_nightveil"):
		c += 0.35
	c = minf(c, float(CD.BALANCE["crit_cap"]))
	if buffs.has("shadow"):
		c = 1.0
	return clampf(c, 0.0, 1.0)


func skill_cd_scale() -> float:
	return 1.0 - clampf(stat("cdr"), 0.0, float(CD.BALANCE["cdr_cap"]))


func attack_speed_mult() -> float:
	var a := clampf(stat("atk_speed"), 0.0, float(CD.BALANCE["atk_speed_cap"]))
	if buffs.has("relic_swiftwind"):
		a += 0.35
	return 1.0 + a


func elem_mult() -> float:
	return 1.0 + clampf(stat("elem"), 0.0, float(CD.BALANCE["elem_cap"]))


func lifesteal() -> float:
	var l := stat("lifesteal")
	if buffs.has("relic_soulfeast"):
		l += 0.25
	if String(weapon_def().get("passive", "")) == "wolf_hunger":
		l += 0.07
	return clampf(l, 0.0, float(CD.BALANCE["lifesteal_cap"]))


func heal_mult() -> float:
	return 1.0 + maxf(0.0, stat("heal_power"))


## Roll a critical on a damage number (legacy helper used by plunge attacks).
func _roll_crit(dmg: int) -> int:
	if randf() < crit_chance():
		_last_crit = true
		return int(round(float(dmg) * float(CD.BALANCE["crit_mult"])))
	_last_crit = false
	return dmg


func get_move_speed() -> float:
	var mult := 1.0 + stat("speed")
	if buffs.has("relic_nightveil"):
		mult += 0.10
	if buffs.has("relic_swiftwind"):
		mult += 0.15
	return WALK_SPEED * mult


func stamina_regen_mult() -> float:
	return 1.0 + stat("stamina_regen")


func ranged_bonus() -> int:
	return int(stat("ranged_bonus"))


## Repaint Mallow from the chosen appearance and the worn visible gear.
## Called on every equip/unequip, so changes show immediately.
var visible_gear: Dictionary = {}

func apply_outfit() -> void:
	if fx_material == null:
		return
	appearance = HeroLook.sanitize(appearance)
	var rc := HeroLook.apply(fx_material, appearance, equipped, DB.ITEMS)
	visible_gear = (rc["worn"] as Dictionary).duplicate()
	if cloak_layer != null and cloak_layer.set_item(String(equipped.get("cloak", "")), DB.ITEMS):
		visible_gear["cloak"] = String(equipped["cloak"])
	_on_sprite_anim_changed()
	refresh_held_weapon()


func set_appearance(a: Dictionary) -> void:
	appearance = HeroLook.sanitize(a)
	apply_outfit()


func _on_sprite_anim_changed() -> void:
	if sprite == null or fx_material == null:
		return
	fx_material.set_shader_parameter("mask_tex", HeroLook.mask_for(HeroLook.sheet_of(String(sprite.animation))))


# ------------------------------------------------------------------ held weapon visuals
const HAND_REST := {
	# main hand (right paw), off hand (left paw): position, rotation, behind body?
	"down": [Vector2(6, -3), 0.35, false, Vector2(-4, -3), -0.2, false],
	"up": [Vector2(-6, -4), -0.3, true, Vector2(6, -4), 0.3, true],
	"left": [Vector2(-3, -3), -0.55, false, Vector2(3, -4), -0.25, true],
	"right": [Vector2(3, -3), 0.55, false, Vector2(-3, -4), 0.25, true],
}
var _swinging := false


func is_dual_wield() -> bool:
	return bool(DB.ITEMS.get(get_weapon_id(), {}).get("dual", false))


## Show the held weapon in Mallow's paw(s); hidden when bare-handed.
func refresh_held_weapon() -> void:
	if weapon_sprite == null:
		return
	if off_weapon_sprite == null:
		off_weapon_sprite = Sprite2D.new()
		off_weapon_sprite.name = "OffHandWeapon"
		off_weapon_sprite.visible = false
		add_child(off_weapon_sprite)
	var item: Dictionary = DB.ITEMS.get(get_weapon_id(), {})
	if is_unarmed():
		weapon_sprite.visible = false
		off_weapon_sprite.visible = false
		return
	var held_path := DB.hand_path(get_weapon_id())
	if held_path == "":
		weapon_sprite.visible = false
		off_weapon_sprite.visible = false
		return
	var t: Texture2D = AnimLib.tex(held_path)
	for sp in [weapon_sprite, off_weapon_sprite]:
		sp.texture = t
		sp.offset = Vector2(-t.get_width() / 2.0, -t.get_height() + 2.0)
		sp.modulate = Color(String(item.get("tint", "ffffff")))
	off_weapon_sprite.flip_h = true
	_update_held_weapon()


func _update_cloak() -> void:
	if cloak_layer == null or not cloak_layer.is_worn():
		return
	var walking := String(sprite.animation).begins_with("walk")
	cloak_layer.set_pose(dir_name, walking, sprite.frame)
	cloak_layer.position = Vector2(0, sprite.position.y)
	cloak_layer.modulate = sprite.modulate
	cloak_layer.visible = sprite.visible and state != State.DEAD and not swimming
	_layer_behind_body(cloak_layer, not cloak_layer.in_front())


func _update_held_weapon() -> void:
	_update_cloak()
	if weapon_sprite == null or off_weapon_sprite == null:
		return
	var armed := not is_unarmed() and state != State.DEAD and not swimming and not fishing
	var dual := armed and is_dual_wield()
	if _swinging:
		off_weapon_sprite.visible = dual and off_weapon_sprite.visible
		return
	var rest: Array = HAND_REST.get(dir_name, HAND_REST["down"])
	var bob := sprite.position.y + (-1.0 if String(sprite.animation).begins_with("walk") and sprite.frame % 2 == 1 else 0.0)
	weapon_sprite.visible = armed
	weapon_sprite.position = rest[0] + Vector2(0, bob)
	weapon_sprite.rotation = rest[1]
	_layer_behind_body(weapon_sprite, rest[2])
	off_weapon_sprite.visible = dual
	off_weapon_sprite.position = rest[3] + Vector2(0, bob)
	off_weapon_sprite.rotation = rest[4]
	_layer_behind_body(off_weapon_sprite, rest[5])


## Held weapons sort with Mallow (z 0) so trees and buildings still cover
## them; only the child order decides whether a blade is behind the body.
func _layer_behind_body(n: Node2D, behind: bool) -> void:
	n.z_index = 0
	var si := sprite.get_index()
	var ni := n.get_index()
	if behind and ni > si:
		move_child(n, si)
	elif not behind and ni < si:
		move_child(n, si)


## Adds an item to the right store. Returns false if nothing was added
## (already owned unique gear, or the bag is full).
func give_item(id: String, qty := 1) -> bool:
	var item: Dictionary = DB.ITEMS.get(id, {})
	if item.is_empty():
		return false
	if Inv.is_stackable(id):
		var added := Inv.add(self, id, qty)
		health_changed.emit()
		return added > 0
	match item.get("type", ""):
		"weapon":
			if weapons_owned.has(id):
				return false
			weapons_owned.append(id)
			if weapon_bar.size() < bar_max():
				weapon_bar.append(id)
			inventory_changed.emit()
		"coins":
			add_petalcoins(int(item.get("amount", 0)))
		"flask_up":
			moontea_max = mini(6, moontea_max + (1 if moontea_charges >= moontea_max else 0))
			moontea_charges = mini(moontea_max, moontea_charges + 1)
		"upgrade":
			heart_pieces += 1
			recalc_stats()
			health = max_health
		"key":
			pass
		_:
			if inventory.has(id):
				return false
			inventory.append(id)
			var slot: String = item.get("type", "")
			if slot in DB.EQUIP_SLOTS and not equipped.has(slot) and Build.can_equip(self, id):
				equip(id)
			inventory_changed.emit()
	health_changed.emit()
	return true


## True if the player already holds this unique item (gear or weapon).
func owns(id: String) -> bool:
	return weapons_owned.has(id) or inventory.has(id)


## Equip (or, if already worn, unequip) an item. Refuses gear the current
## lines cannot use; the reason is kept in last_equip_error for the UI.
func equip(id: String) -> bool:
	var item: Dictionary = DB.ITEMS.get(id, {})
	var slot: String = item.get("type", "")
	last_equip_error = ""
	if slot == "weapon":
		return equip_weapon(id)
	if not slot in DB.EQUIP_SLOTS or not inventory.has(id):
		last_equip_error = "Not equipment." if inventory.has(id) else "Not owned."
		return false
	if equipped.get(slot, "") == id:
		equipped.erase(slot)
	else:
		var why := Build.item_reason(self, id)
		if why != "":
			last_equip_error = why
			return false
		equipped[slot] = id
	recalc_stats()
	apply_outfit()
	return true


func unequip(slot: String) -> bool:
	if not equipped.has(slot):
		return false
	equipped.erase(slot)
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


## Make a weapon the held weapon (must be owned and allowed by the lines).
func equip_weapon(id: String) -> bool:
	var why := Build.item_reason(self, id)
	if why != "":
		last_equip_error = why
		return false
	var idx := weapons_owned.find(id)
	if idx < 0:
		return false
	if not DB.ITEMS.get(id, {}).get("unarmed", false) and not weapon_bar.has(id):
		if weapon_bar.size() >= bar_max():
			# full bar: the new weapon takes the held weapon's slot
			var slot := weapon_bar.find(get_weapon_id())
			if slot < 0:
				last_equip_error = "Weapon bar full (%d/%d). Remove a weapon from the bar first." % [weapon_bar.size(), bar_max()]
				return false
			weapon_bar[slot] = id
		else:
			weapon_bar.append(id)
	_set_weapon_index(idx)
	return true


# ------------------------------------------------------------------ weapon bar
func bar_max() -> int:
	return int(CD.BALANCE.get("weapon_bar_max", 5))


## Add an owned weapon to the bar. Fails (with last_equip_error) when full.
func bar_add(id: String) -> bool:
	if not weapons_owned.has(id) or DB.ITEMS.get(id, {}).get("unarmed", false):
		return false
	if weapon_bar.has(id):
		return true
	if weapon_bar.size() >= bar_max():
		last_equip_error = "Weapon bar full (%d/%d)." % [weapon_bar.size(), bar_max()]
		return false
	weapon_bar.append(id)
	inventory_changed.emit()
	stats_changed.emit()
	return true


## Remove a weapon from the bar (it stays owned). Holding it -> bare paws.
func bar_remove(id: String) -> bool:
	if not weapon_bar.has(id):
		return false
	weapon_bar.erase(id)
	if get_weapon_id() == id:
		_set_weapon_index(maxi(0, weapons_owned.find("fists")))
	inventory_changed.emit()
	stats_changed.emit()
	return true


## Tap on a weapon bar slot. A short lockout stops switch-cancelling.
func select_bar_slot(i: int) -> bool:
	if i < 0 or i >= weapon_bar.size():
		return false
	var id := weapon_bar[i]
	if id == get_weapon_id():
		return true
	if _switch_lock > 0.0:
		return false
	if not Build.can_equip(self, id):
		last_equip_error = Build.item_reason(self, id)
		if game:
			game.hud.show_message(last_equip_error, 1.5)
		return false
	_set_weapon_index(weapons_owned.find(id))
	_switch_lock = float(CD.BALANCE.get("weapon_switch_lock", 0.3))
	if game:
		game.audio.play("menu5", 0.02, -6.0)
	return true


## Keep the bar valid: owned weapons only, no fists/duplicates, max size.
## Old saves (no bar) get up to five weapons, best rarity first, held one kept.
func sanitize_bar(migrate := false) -> void:
	var out: Array[String] = []
	for w in weapon_bar:
		if weapons_owned.has(w) and not out.has(w) and not DB.ITEMS.get(w, {}).get("unarmed", false) and out.size() < bar_max():
			out.append(w)
	if migrate:
		var rest := real_weapons()
		rest.sort_custom(func(a, b) -> bool:
			return DB.RARITIES.find(String(DB.ITEMS[a].get("rarity", "common"))) > DB.RARITIES.find(String(DB.ITEMS[b].get("rarity", "common"))))
		var held := get_weapon_id()
		if held != "fists" and not out.has(held):
			out.append(held)
		for w in rest:
			if out.size() >= bar_max():
				break
			if not out.has(w):
				out.append(w)
	weapon_bar = out


## After a line change: move now-invalid gear back to the satchel (never
## deleted), fix the held weapon, prune locked arts and refill empty slots.
func _validate_build() -> Array:
	var removed: Array = []
	for id in Build.invalid_equipped(self):
		var slot: String = DB.ITEMS[id]["type"]
		equipped.erase(slot)
		removed.append(id)
	if not Build.can_equip(self, get_weapon_id()):
		for i in range(weapons_owned.size()):
			if Build.can_equip(self, weapons_owned[i]):
				_set_weapon_index(i)
				break
	_refresh_skill_bar()
	recalc_stats()
	apply_outfit()
	return removed


# ------------------------------------------------------------------ petal arts
func xp_needed() -> int:
	return ClassBook.xp_needed(level)


func add_xp(amount: int) -> void:
	if amount <= 0:
		return
	xp += amount
	var leveled := false
	while level < ClassBook.LEVEL_CAP and xp >= xp_needed():
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


func class_rank(id: String) -> int:
	return Build.rank(self, id)


func bind_class(id: String) -> bool:
	if Build.bind_reason(self, id) != "":
		return false
	classes.append(id)
	if not class_nodes.has(id):
		class_nodes[id] = {}
	_grant_rank_rewards(id)
	_prefer_line_arts(id)
	_validate_build()
	if game:
		var def: Dictionary = ClassBook.CLASSES[id]
		game.audio.play("secret2", 0.0, -3.0)
		game.fx.spawn("aura", global_position + Vector2(0, -8), 0.0, 1.4, def["color"], null, true)
		game.hud.show_message("%s line bound%s. Arts 1-4 on the keys." % [def["name"], " (combined)" if classes.size() == 2 else ""], 3.5)
	return true


## Release a bound line. Tree progress, art levels and gear are kept; gear the
## remaining lines cannot use returns to the satchel. Releasing the primary
## promotes the secondary.
func release_class(id: String) -> bool:
	if not classes.has(id):
		return false
	classes.erase(id)
	var removed := _validate_build()
	if game:
		var msg := "%s line released. Its progress is kept for when you rebind it." % Build.class_display(id)
		if removed.size() > 0:
			var names := PackedStringArray()
			for r in removed:
				names.append(String(DB.ITEMS[r]["name"]))
			msg += " Returned to satchel: %s." % ", ".join(names)
		game.hud.show_message(msg, 4.0)
		game.audio.play("menu5", 0.02, -4.0)
	return true


## Swap primary and secondary (primary line gets full attribute strength).
func swap_lines() -> bool:
	if classes.size() < 2:
		return false
	var a: String = classes[0]
	classes[0] = classes[1]
	classes[1] = a
	recalc_stats()
	return true


func spend_node(class_id: String, node_id: String) -> bool:
	if not classes.has(class_id):
		return false
	var node: Dictionary = ClassBook.class_of(class_id).get("tree", {}).get(node_id, {})
	if node.is_empty() or skill_points < 1:
		return false
	var owned: Dictionary = class_nodes.get(class_id, {})
	if owned.has(node_id):
		return false
	for need in node.get("needs", []):
		if not owned.has(need):
			return false
	var rank_before := class_rank(class_id)
	owned[node_id] = true
	class_nodes[class_id] = owned
	skill_points -= 1
	_grant_rank_rewards(class_id)
	recalc_stats()
	var rank_now := class_rank(class_id)
	if game:
		game.audio.play("levelup1", 0.03, -4.0)
		game.fx.burst("spark", global_position + Vector2(0, -12), 8, 60.0, Color(1, 0.9, 0.7), -40.0)
		if rank_now > rank_before:
			var unlocked := PackedStringArray()
			for sid in ClassBook.class_of(class_id).get("skills", []):
				if int(ClassBook.skill_of(sid).get("unlock", 1)) == rank_now:
					unlocked.append(String(ClassBook.skill_of(sid)["name"]))
			var txt := "%s rank %d." % [Build.class_display(class_id), rank_now]
			if unlocked.size() > 0:
				txt += " New art: %s!" % ", ".join(unlocked)
				_refresh_skill_bar()
			game.hud.show_message(txt, 3.5)
	return true


## Hand out a line's signature gear once per rank milestone (tracked forever).
func _grant_rank_rewards(cls: String) -> void:
	var rewards: Dictionary = ClassBook.class_of(cls).get("rewards", {})
	var r := class_rank(cls)
	for need in rewards:
		if int(need) > r:
			continue
		for item_id in rewards[need]:
			if rewards_claimed.has(item_id):
				continue
			rewards_claimed[item_id] = true
			give_item(item_id)
			if game and game.hud.has_method("show_item_get"):
				game.hud.show_message("%s gear unlocked: %s." % [Build.class_display(cls), DB.ITEMS[item_id]["name"]], 3.0)


func upgrade_skill(id: String) -> bool:
	if Build.upgrade_reason(self, id) != "":
		return false
	skill_points -= Build.upgrade_cost(self, id)
	skill_levels[id] = Build.skill_level(self, id) + 1
	if game:
		game.audio.play("levelup1", 0.03, -3.0)
		game.fx.spawn("spark_circle", global_position + Vector2(0, -10), 0.0, 1.0, Color(String(ClassBook.skill_of(id).get("tint", "ffffff"))), null, true)
	stats_changed.emit()
	return true


## Put an art in a slot. Swaps if it already sits in another slot (no duplicates).
func set_skill_slot(index: int, id: String) -> bool:
	if index < 0 or index >= 4:
		return false
	_ensure_bar()
	if id != "" and not Build.is_skill_unlocked(self, id):
		return false
	var prev := skill_bar.find(id) if id != "" else -1
	if prev >= 0 and prev != index:
		skill_bar[prev] = skill_bar[index]
	skill_bar[index] = id
	stats_changed.emit()
	return true


func _ensure_bar() -> void:
	while skill_bar.size() < 4:
		skill_bar.append("")
	while skill_bar.size() > 4:
		skill_bar.pop_back()


## Validate the four art slots (drop locked/duplicate arts) and fill empty slots
## with eligible arts: primary line, secondary line, then wanderer arts.
func _refresh_skill_bar() -> void:
	var clean := Build.sanitize_loadout(self, skill_bar)
	skill_bar.clear()
	for sid in clean:
		skill_bar.append(String(sid))
	for sid in Build.eligible_skills(self):
		if skill_bar.has(sid):
			continue
		var empty := skill_bar.find("")
		if empty < 0:
			break
		skill_bar[empty] = sid
	stats_changed.emit()


## A newly bound line's unlocked arts replace wanderer arts in the bar.
func _prefer_line_arts(cls: String) -> void:
	_ensure_bar()
	for sid in ClassBook.class_of(cls).get("skills", []):
		if skill_bar.has(sid) or not Build.is_skill_unlocked(self, sid):
			continue
		var slot := skill_bar.find("")
		if slot < 0:
			for i in range(4):
				if skill_bar[i] in ClassBook.WANDERER_SKILLS:
					slot = i
					break
		if slot < 0:
			break
		skill_bar[slot] = sid


func cast_slot(index: int, aim := Vector2.INF) -> bool:
	if index < 0 or index >= skill_bar.size() or skill_bar[index] == "":
		return false
	return cast_skill(skill_bar[index], aim)


## Why an art cannot be cast right now ("" = ready).
func cast_block_reason(id: String) -> String:
	var def: Dictionary = ClassBook.skill_of(id)
	if def.is_empty() or not game:
		return "?"
	var lock := Build.skill_lock_reason(self, id)
	if lock != "":
		return lock
	if state != State.MOVE and state != State.ATTACK:
		return "busy"
	if fishing or swimming or game.game_over:
		return "busy"
	if float(skill_cd.get(id, 0.0)) > 0.0:
		return "cooldown"
	if id == "petalguard" and guard_active:
		return "active"
	if focus < float(def.get("cost", 0)) and not Assassin.rush_recast(self, id):
		return "focus"
	return ""


## Real range of an art for aim indicators and auto-aim.
func skill_range(id: String) -> float:
	var def: Dictionary = ClassBook.skill_of(id)
	var r := float(def.get("range", 0.0))
	if id == "shadowstep" and class_nodes.get("nightbloom", {}).has("veilwalker"):
		r += 24.0
	return r


func skill_radius(id: String) -> float:
	return float(Build.skill_stat(self, id, "radius", 0.0))


## Default aim (world offset) when an aimable art is tapped without dragging:
## the current target if it is in range, otherwise straight ahead.
func auto_aim_offset(id: String) -> Vector2:
	var def: Dictionary = ClassBook.skill_of(id)
	var r := skill_range(id)
	var t := current_target if is_valid_target(current_target) else null
	if t == null and game:
		t = game.nearest_enemy(global_position, maxf(r, 60.0))
	if String(def.get("aim", "tap")) == "point":
		if t != null and global_position.distance_to(t.global_position) <= r + 8.0:
			return (t.global_position - global_position).limit_length(r)
		return facing * r * 0.6
	if t != null and global_position.distance_to(t.global_position) <= r * 1.3:
		return (t.global_position + Vector2(0, -5)) - (global_position + Vector2(0, -6))
	return facing * r


func cast_skill(id: String, aim := Vector2.INF) -> bool:
	var def: Dictionary = ClassBook.skill_of(id)
	var why := cast_block_reason(id)
	if why != "":
		if game and why != "?":
			match why:
				"focus":
					game.hud.show_message("Not enough focus for %s." % def["name"], 1.5)
				"cooldown", "busy", "active":
					pass
				_:
					game.hud.show_message("%s: %s" % [def["name"], why], 2.0)
			game.audio.play("cancel", 0.0, -8.0)
		return false
	var aim_type := String(def.get("aim", "tap"))
	if aim == Vector2.INF:
		aim = auto_aim_offset(id) if aim_type != "tap" else Vector2.ZERO
	if aim_type == "direction" and aim.length() > 0.5:
		_set_facing(aim)
	elif aim_type == "point" and aim.length() > 2.0:
		_set_facing(aim)
	var cost := 0 if Assassin.rush_recast(self, id) else int(def.get("cost", 0))
	focus -= cost
	skill_cd[id] = float(Build.skill_stat(self, id, "cd", 1.0)) * skill_cd_scale()
	_begin_attack(0.24 / attack_speed_mult(), 0.30 / attack_speed_mult())
	var atk := attack_bonus()
	var dmg := int(Build.skill_stat(self, id, "dmg", 0)) + atk
	var tint := Color(String(def.get("tint", "ffd9f2")))
	var elem := String(def.get("element", ""))
	var status: Dictionary = def.get("status", {})
	var info := {"element": elem, "source": "art", "status": status}
	match String(def["exec"]):
		"mothlight":
			_cast_mothlight(dmg)
		"petalguard":
			guard_time_left = 5.0
			guard_active = true
			guard_fx.visible = true
			guard_fx.play("play")
			game.audio.play("spirit", 0.05, -4.0)
			game.fx.spawn("aura", global_position + Vector2(0, -8), 0.0, 1.4, Color(1, 0.8, 0.95), null, true)
		"strike":
			_swing_weapon(0.22, true)
			var center := global_position + Vector2(0, -6) + facing * 15.0
			game.fx.spawn(String(def.get("fx", "slash_double")), center, facing.angle(), 1.1, tint, null, true)
			game.audio.play("slash3", 0.08, -2.0)
			var first: Node2D = null
			var n := 0
			for t in game.hittable_targets(center, skill_radius(id)):
				if first == null:
					first = t
				var inf := info.duplicate()
				inf["force"] = float(def["knock"])
				if def.has("chain"):
					inf["status"] = {"stun": 1}
				deal(t, dmg, inf)
				n += 1
			game.break_props(center, skill_radius(id))
			if first != null and def.has("chain"):
				_chain_from(first, int(def["chain"]), maxi(1, dmg - 1), elem, 60.0, {first.get_instance_id(): true})
			if n > 0:
				game.hitstop(0.07)
		"flurry":
			_swing_weapon(0.2, false)
			for i in range(int(def.get("hits", 3))):
				_fist_after(0.12 * float(i), dmg, tint)
		"volley":
			_swing_weapon(0.18, false, true)
			var dir := aim.normalized() if aim.length() > 0.1 else facing
			var count := int(def["count"])
			for i in range(count):
				_shoot_after(0.09 * float(i), def, dmg, dir, i, count, info)
			game.audio.play("slash5", 0.08, -4.0)
		"pierce":
			_swing_weapon(0.18, false, true)
			var dir2 := aim.normalized() if aim.length() > 0.1 else facing
			var speed := float(def["speed"])
			_spawn_player_projectile({"kind": String(def["kind"]), "pos": global_position + Vector2(0, -9) + dir2 * 8.0,
				"dir": dir2, "speed": speed, "pierce": true, "life": skill_range(id) / speed, "element": elem}, dmg, info)
			game.fx.spawn("spark", global_position + Vector2(0, -9) + dir2 * 10.0, 0.0, 0.6, tint, null, true)
			game.audio.play("magic1", 0.08, -4.0)
		"burst_point":
			var point := global_position + aim.limit_length(skill_range(id))
			var rad := skill_radius(id)
			game.fx.ring(point, rad, float(def["delay"]), tint)
			game.audio.play("magic3", 0.05, -6.0)
			get_tree().create_timer(float(def["delay"])).timeout.connect(func() -> void:
				if game == null or state == State.DEAD:
					return
				game.fx.spawn("explosion", point, 0.0, 0.9, Color(1.0, 0.92, 0.6, 0.9), null, true)
				game.fx.shake(3.0, 0.2)
				game.audio.play("impact", 0.06, -2.0)
				var inf2 := info.duplicate()
				inf2["force"] = 110.0
				inf2["from"] = point
				for t in game.hittable_targets(point, rad):
					deal(t, dmg, inf2)
				game.break_props(point, rad))
		"blink":
			var step_dir := aim.normalized() if aim.length() > 0.1 else facing
			var dist := skill_range(id)
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
		"rush":
			Assassin.rush_cast(self, id, def, aim, dmg, info)
		"hook":
			Assassin.hook_cast(self, id, def, aim, dmg, info)
		"charge":
			_charge = {"dmg": dmg, "info": info, "hit": {}, "radius": skill_radius(id), "force": float(def.get("knock", 120.0))}
			state = State.MOVE
			_start_dash(aim.normalized() if aim.length() > 0.1 else facing, skill_range(id) / 300.0, 300.0)
			invulnerable_left = maxf(invulnerable_left, skill_range(id) / 300.0)
			game.audio.play("slash3", 0.06, -3.0)
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
			var amt := int(round(float(Build.skill_stat(self, id, "heal", 0.0)) * heal_mult()))
			heal(amt, Color("9cf5a5"))
		"aoe":
			var n2 := 0
			var inf3 := info.duplicate()
			inf3["force"] = float(def["knock"])
			for t in game.hittable_targets(global_position + Vector2(0, -6), skill_radius(id)):
				deal(t, dmg, inf3)
				n2 += 1
			if def.has("invuln"):
				invulnerable_left = maxf(invulnerable_left, float(def["invuln"]))
			game.fx.ring(global_position + Vector2(0, -6), skill_radius(id), 0.4, tint)
			game.fx.burst("spark", global_position + Vector2(0, -10), 14, 90.0, tint, -30.0)
			game.audio.play("magic3", 0.05, -2.0)
			if n2 > 0:
				game.hitstop(0.05)
		"vamp":
			var hits3 := 0
			var inf4 := info.duplicate()
			inf4["force"] = float(def.get("knock", 60.0))
			for t in game.hittable_targets(global_position + Vector2(0, -6), skill_radius(id)):
				deal(t, dmg, inf4)
				hits3 += 1
			if hits3 > 0:
				var per := int(round(float(Build.skill_stat(self, id, "heal", 2)) * heal_mult()))
				if class_nodes.get("gravetender", {}).has("second_breath"):
					per += 1
				heal(per * hits3, Color("9cf5a5"))
				game.fx.burst("spark", global_position + Vector2(0, -12), 6 * hits3, 60.0, tint, -60.0)
			game.fx.ring(global_position + Vector2(0, -6), skill_radius(id), 0.35, tint)
			game.audio.play("spirit" if hits3 > 0 else "magic1", 0.05, -3.0)
		"chain":
			var first2: Node2D = current_target if is_valid_target(current_target) and global_position.distance_to(current_target.global_position) <= skill_range(id) else game.nearest_enemy(global_position, skill_range(id))
			if first2 == null:
				game.fx.spawn("thunder", global_position + Vector2(0, -10) + facing * 20.0, 0.0, 0.8, tint, null, true)
			else:
				_set_facing(first2.global_position - global_position)
				game.fx.bolt(global_position + Vector2(0, -12), first2.global_position + Vector2(0, -6), CD.element_color("lightning"))
				var inf5 := info.duplicate()
				inf5["status"] = {"stun": 1}
				deal(first2, dmg, inf5)
				_chain_from(first2, int(def["chain"]), dmg, "lightning", 70.0, {first2.get_instance_id(): true})
			game.audio.play("magic3", 0.05, -3.0)
		"cloud":
			var cpt := global_position + aim.limit_length(skill_range(id))
			var crad := skill_radius(id)
			var cdmg := dmg
			_next_zone_style = String(def.get("zone_style", "ring"))
			_spawn_zone(cpt, crad, float(def["time"]), 0.5, tint, func(z: Node2D) -> void:
				if game == null:
					return
				for t in game.hittable_targets(z.global_position, crad):
					deal(t, maxi(1, cdmg / 3), {"element": "poison", "source": "proc", "status": status, "force": 0.0, "no_proc": true}))
			game.fx.burst("spark", cpt, 12, 50.0, tint, -20.0, 0.8)
			game.audio.play("magic1", 0.05, -4.0)
		"rain":
			var rpt := global_position + aim.limit_length(skill_range(id))
			var rrad := skill_radius(id)
			var waves := int(def.get("waves", 3))
			game.fx.ring(rpt, rrad, 0.3, tint)
			var rdmg := dmg
			_spawn_zone(rpt, rrad, 0.35 * float(waves) + 0.05, 0.35, tint, func(z: Node2D) -> void:
				if game == null:
					return
				game.fx.burst("fire", z.global_position, 6, 60.0, tint, 80.0, 0.4)
				game.audio.play("slash5", 0.1, -10.0)
				for t in game.hittable_targets(z.global_position, rrad):
					deal(t, rdmg, {"element": elem, "source": "art", "status": status, "force": 20.0}))
		"summon":
			if is_instance_valid(_thrall):
				_thrall.queue_free()
			_thrall = ThrallScript.new()
			game.fx.add_child(_thrall)
			_thrall.setup(self, dmg, float(def["time"]))
			game.fx.spawn("smoke", global_position + Vector2(10, -10), 0.0, 0.8, tint)
			game.audio.play("spirit", 0.05, -3.0)
		"heal_zone":
			var hpt := global_position + aim.limit_length(skill_range(id))
			var hrad := skill_radius(id)
			var per_tick := maxi(1, int(round(float(Build.skill_stat(self, id, "heal", 1.0)) * heal_mult())))
			_next_zone_style = String(def.get("zone_style", "ring"))
			_spawn_zone(hpt, hrad, float(def["time"]), 0.6, tint, func(z: Node2D) -> void:
				if game == null or state == State.DEAD:
					return
				if global_position.distance_to(z.global_position) <= hrad:
					heal(per_tick, Color("9cf5a5"), true))
			game.audio.play("heal", 0.05, -4.0)
	skill_cast.emit(id)
	return true


func _cast_mothlight(dmg: int) -> void:
	game.fx.spawn("spark_circle", global_position + Vector2(0, -8), 0.0, 2.4, Color(1.0, 0.72, 0.85, 0.55), null, true)
	game.fx.spawn("magic_circle", global_position + Vector2(0, -2), 0.0, 2.2, Color(0.8, 0.6, 1.0, 0.5), null, true)
	game.fx.burst("spark", global_position + Vector2(0, -8), 18, 120.0, Color(1, 0.85, 0.75), 0.0, 0.8)
	game.audio.play("magic3", 0.05, -2.0)
	game.flash_light(global_position, Color(1.0, 0.75, 0.85), 0.55, 0.5)
	var rad := skill_radius("mothlight")
	for t in game.hittable_targets(global_position + Vector2(0, -6), rad):
		deal(t, dmg, {"element": "arcane", "source": "art", "force": 130.0})
	game.break_props(global_position + Vector2(0, -6), rad)


func _spawn_zone(pos: Vector2, radius: float, duration: float, period: float, color: Color, cb: Callable) -> void:
	var z := ZoneScript.new()
	z.position = pos
	z.setup(radius, duration, period, color, cb, _next_zone_style)
	_next_zone_style = "ring"
	game.fx.add_child(z)


## Jump lightning (or any element) from `from` to up to `count` new foes.
func _chain_from(from: Node2D, count: int, dmg: int, element: String, hop: float, visited: Dictionary) -> void:
	var cur := from
	for i in range(count):
		if cur == null or not is_instance_valid(cur):
			return
		var best: Node2D = null
		var bd := hop
		for t in game.hittable_targets(cur.global_position, hop):
			if visited.has(t.get_instance_id()):
				continue
			var d: float = cur.global_position.distance_to(t.global_position)
			if d < bd:
				bd = d
				best = t
		if best == null:
			return
		visited[best.get_instance_id()] = true
		game.fx.bolt(cur.global_position + Vector2(0, -6), best.global_position + Vector2(0, -6), CD.element_color(element))
		deal(best, dmg, {"element": element, "source": "proc", "status": {"stun": 1} if element == "lightning" else {}, "force": 40.0, "no_proc": true})
		cur = best


func _fist_after(delay: float, dmg: int, tint: Color) -> void:
	get_tree().create_timer(maxf(delay, 0.001)).timeout.connect(func() -> void:
		if game == null or state == State.DEAD:
			return
		var center := global_position + Vector2(0, -6) + facing * 14.0
		game.fx.spawn("slash", center, facing.angle(), 0.7, tint, null, true)
		game.audio.play("slash" if int(delay * 20.0) % 2 == 0 else "slash2", 0.08, -5.0)
		for t in game.hittable_targets(center, 18.0):
			deal(t, dmg, {"source": "art", "force": 50.0}))


func _shoot_after(delay: float, def: Dictionary, dmg: int, dir: Vector2, idx: int, n: int, info: Dictionary) -> void:
	var fire := func() -> void:
		if game == null or state == State.DEAD:
			return
		var spread := float(def.get("spread", 0.0))
		var angle_off := 0.0
		if spread > 0.0 and n > 1:
			angle_off = (-1.0 + 2.0 * float(idx) / float(n - 1)) * spread
		var d := dir.rotated(angle_off)
		var speed := float(def["speed"])
		_spawn_player_projectile({"kind": String(def["kind"]), "pos": global_position + Vector2(0, -9) + d * 8.0,
			"dir": d, "speed": speed, "homing": float(def.get("homing", 0.0)), "life": float(def.get("range", 200.0)) / speed,
			"element": String(info.get("element", ""))}, dmg, info)
		game.audio.play("launch", 0.08, -8.0)
	if delay <= 0.0:
		fire.call()
	else:
		get_tree().create_timer(delay).timeout.connect(fire)


## Spawn a player projectile whose hits go through deal(), so crits, elements,
## statuses, lifesteal and passives all resolve in one place, once per target.
func _spawn_player_projectile(d: Dictionary, dmg: int, info: Dictionary) -> void:
	d["team"] = "player"
	d["damage"] = dmg
	var inf := info.duplicate()
	d["on_hit"] = func(t: Node2D, from: Vector2) -> void:
		var i2 := inf.duplicate()
		i2["from"] = from
		i2["ranged"] = true
		if not i2.has("force"):
			i2["force"] = 140.0
		deal(t, dmg, i2)
	game.spawn_projectile(d)


func add_petalcoins(amount: int) -> void:
	petalcoins += maxi(0, amount)
	health_changed.emit()


## Cycle to the next weapon the current lines allow. Safe mid-combat: resets
## combo and bow charge, cancels a pending hammer impact.
func cycle_weapon() -> void:
	# keyboard/gamepad "next weapon": the next weapon-bar slot (no quick-swap wheel)
	if weapon_bar.is_empty():
		return
	var cur := weapon_bar.find(get_weapon_id())
	for step in range(1, weapon_bar.size() + 1):
		var id := weapon_bar[(cur + step) % weapon_bar.size()]
		if Build.can_equip(self, id):
			_set_weapon_index(weapons_owned.find(id))
			break
	if game:
		game.audio.play("menu5", 0.02, -6.0)


func _set_weapon_index(idx: int) -> void:
	weapon_index = clampi(idx, 0, weapons_owned.size() - 1)
	var wid := get_weapon_id()
	if wid != "fists" and not weapon_bar.has(wid) and weapon_bar.size() < bar_max():
		weapon_bar.append(wid)
	charge.cancel()
	attack_combo = -1
	combo_timer = 0.0
	bow_charge = -1.0
	_hammer_pending = -1.0
	_attack_buffer = 0.0
	if state == State.ATTACK:
		state = State.MOVE
	recalc_stats()
	refresh_held_weapon()


func get_weapon_id() -> String:
	if weapons_owned.is_empty():
		return "fists"
	return weapons_owned[clampi(weapon_index, 0, weapons_owned.size() - 1)]


func is_unarmed() -> bool:
	return bool(DB.ITEMS.get(get_weapon_id(), {}).get("unarmed", false))


## Bare hands are always available at index 0 (never sold, never shown as loot).
func ensure_fists() -> void:
	var held := get_weapon_id()
	weapons_owned.erase("fists")
	weapons_owned.insert(0, "fists")
	weapon_index = maxi(0, weapons_owned.find(held))


## Real weapons owned (bare hands excluded).
func real_weapons() -> Array:
	var out: Array = []
	for w in weapons_owned:
		if w != "fists":
			out.append(w)
	return out


## Put the held weapon away: back to bare-handed punches.
func unequip_weapon() -> bool:
	if is_unarmed():
		return false
	_set_weapon_index(0)
	return true


func get_weapon_name() -> String:
	return String(DB.ITEMS[get_weapon_id()]["name"]).to_upper()


func weapon_def() -> Dictionary:
	return CD.weapon(get_weapon_id())


func get_status() -> Dictionary:
	return {"health": health, "max_health": max_health, "moontea": moontea_charges, "petalcoins": petalcoins, "weapon": get_weapon_name(),
		"mothlight_cooldown": mothlight_cooldown, "guard_cooldown": guard_cooldown, "guard_active": guard_active,
		"charm_equipped": charm_equipped, "cloak_equipped": cloak_equipped, "stamina": stamina}


# ------------------------------------------------------------------ targeting
func is_valid_target(t) -> bool:
	if t == null or not is_instance_valid(t) or not t.is_inside_tree():
		return false
	var a = t.get("alive")
	if a != null and not bool(a):
		return false
	var d = t.get("defeated")
	if d != null and bool(d):
		return false
	var aw = t.get("awake")
	if aw != null and t.get("title") != null and not bool(aw):
		return false
	return true


## How far the auto-target looks: a little past the weapon's real reach.
func acquire_range() -> float:
	var w := weapon_def()
	if String(w.get("shape", "arc")) == "line":
		return float(w["reach"])
	return maxf(70.0, float(w["reach"]) * 2.4)


## Pick the best target: closest by distance, facing bonus, bosses slightly
## preferred, sticky current target (hysteresis) and manual lock override.
func _update_target() -> void:
	if game == null:
		return
	var reach := acquire_range()
	if manual_target != null:
		if not is_valid_target(manual_target) or global_position.distance_to(manual_target.global_position) > reach * 1.6:
			manual_target = null
		else:
			current_target = manual_target
			return
	if not auto_target_enabled:
		current_target = null
		return
	var best: Node2D = null
	var best_score := INF
	for t in game.hittable_targets(global_position + Vector2(0, -4), reach):
		var to: Vector2 = t.global_position - global_position
		var score := to.length() / reach
		if to.length() > 1.0 and facing.dot(to.normalized()) < -0.3:
			score += 0.25
		if t.get("title") != null:
			score -= 0.15
		if t == current_target:
			score *= float(CD.BALANCE["target_retarget_hysteresis"])
		if score < best_score:
			best_score = score
			best = t
	current_target = best


## Manual override: lock the enemy nearest to a world point (tap/click on it).
## Tapping the locked enemy again, or empty ground, clears the lock.
func lock_target_at(world_pos: Vector2) -> bool:
	if game == null:
		return false
	var t: Node2D = game.nearest_enemy(world_pos, 22.0)
	if t == null or global_position.distance_to(t.global_position) > acquire_range() * 1.6:
		manual_target = null
		return false
	manual_target = null if t == manual_target else t
	_update_target()
	return manual_target != null


func cycle_target() -> void:
	if game == null:
		return
	var list: Array = game.hittable_targets(global_position, acquire_range() * 1.4)
	if list.is_empty():
		manual_target = null
		return
	list.sort_custom(func(a: Node2D, b: Node2D) -> bool: return global_position.distance_to(a.global_position) < global_position.distance_to(b.global_position))
	var i := list.find(current_target)
	manual_target = list[(i + 1) % list.size()]
	_update_target()


func _face_target() -> void:
	if is_valid_target(current_target):
		var to: Vector2 = (current_target.global_position + Vector2(0, -5)) - (global_position + Vector2(0, -4))
		if to.length() > 0.5 and to.length() <= acquire_range() * 1.2:
			_set_facing(to)


# ------------------------------------------------------------------ damage pipeline
## The one place player damage resolves. info keys:
##  element, status {id: stacks}, source ("basic"|"art"|"proc"|"dot"),
##  crit_bonus, can_crit, force, from, ranged, no_proc.
## Returns the damage dealt (0 if the target was invalid).
func deal(t: Node, base: int, info: Dictionary = {}) -> int:
	if game == null or not is_valid_target(t):
		return 0
	var element := String(info.get("element", ""))
	var source := String(info.get("source", "basic"))
	var dmg := float(maxi(1, base))
	if bool(info.get("staff_resonance", false)):
		var stx := StatusFx.of(t)
		if stx != null and stx.any_active():
			dmg += 1.0
	if element != "":
		dmg *= elem_mult()
	var crit := false
	if bool(info.get("can_crit", true)):
		var chance := crit_chance() + float(info.get("crit_bonus", 0.0)) + _weapon_crit_bonus(t, source)
		if buffs.has("shadow") and source != "dot":
			chance = 1.0
		if randf() < chance:
			crit = true
			dmg *= float(CD.BALANCE["crit_mult"])
	if crit and buffs.has("shadow") and source != "dot":
		buffs.erase("shadow")
	var amount := maxi(1, int(round(dmg)))
	var from: Vector2 = info.get("from", global_position)
	var color: Color = CD.element_color(element) if element != "" else Color("ffe08a")
	var was_cursed: bool = _has_status(t, "curse")
	var dealt: int = game.damage_target(t, amount, from, float(info.get("force", 60.0)),
		{"element": element, "crit": crit, "color": color, "source": source})
	if crit:
		game.audio.play("secret2", 0.06, -8.0)
		game.fx.spark_hit(t.global_position + Vector2(0, -8), Color("ffd24a"))
	elif element != "":
		game.fx.spark_hit(t.global_position + Vector2(0, -8), color)
	# statuses (skip on dead targets)
	var st: Dictionary = info.get("status", {})
	for sid in st:
		if is_valid_target(t):
			StatusFx.apply(game, t, String(sid), int(st[sid]))
	if source != "dot" and not bool(info.get("no_proc", false)):
		_weapon_on_hit(t, source, info)
		_relic_on_hit(t, source)
	# lifesteal, accumulated so small hits still add up
	var ls := lifesteal()
	if ls > 0.0 and source != "dot":
		_ls_acc += float(dealt) * ls
		if _ls_acc >= 1.0:
			var h := int(_ls_acc)
			_ls_acc -= float(h)
			# per-second cap so lifesteal never makes Mallow unkillable
			h = mini(h, int(float(CD.BALANCE.get("lifesteal_per_sec", 3.0)) - _ls_sec))
			if h > 0:
				_ls_sec += float(h)
				heal(h, Color("90ffc0"), true)
	if was_cursed and not is_valid_target(t) and String(weapon_def().get("passive", "")) == "reap":
		heal(1, Color("90ffc0"), true)
	damage_dealt.emit(t, dealt, crit, element)
	return dealt


func _has_status(t: Node, id: String) -> bool:
	var s := StatusFx.of(t)
	return s != null and s.has_effect(id)


## Weapon passives that change the crit roll.
func _weapon_crit_bonus(t: Node, source: String) -> float:
	if source != "basic":
		return 0.0
	match String(weapon_def().get("passive", "")):
		"flurry":
			return FLURRY_CRIT * _flurry_stacks if _flurry_target == t.get_instance_id() and _flurry_t > 0.0 else 0.0
		"biting_dusk":
			return 0.25 if _attack_is_finisher else 0.0
		"steady_aim":
			return 0.25 if _attack_charged else 0.0
	return 0.0


## Weapon passives that trigger on a basic-attack hit (once per target per swing).
func _weapon_on_hit(t: Node, source: String, info: Dictionary) -> void:
	if source != "basic" or not is_valid_target(t):
		return
	match String(weapon_def().get("passive", "")):
		"briar_venom":
			if _attack_is_finisher:
				StatusFx.apply(game, t, "poison", 1)
		"ember_edge":
			if _attack_is_finisher:
				StatusFx.apply(game, t, "burn", 1)
		"sunder":
			if _attack_is_finisher:
				StatusFx.apply(game, t, "expose", 1)
		"moon_wave":
			if _attack_is_finisher:
				_chain_from(t, 1, maxi(1, int(DB.ITEMS[get_weapon_id()].get("damage", 2)) / 2), "arcane", 56.0, {t.get_instance_id(): true})
		"flurry":
			var tid := t.get_instance_id()
			if tid != _flurry_target or _flurry_t <= 0.0:
				_flurry_target = tid
				_flurry_stacks = 0
			_flurry_stacks = mini(FLURRY_MAX, _flurry_stacks + 1)
			_flurry_t = FLURRY_TIME
		"reap":
			StatusFx.apply(game, t, "curse", 1)
		"quake":
			StatusFx.apply(game, t, "chill", 1)
		"prism":
			match String(info.get("element", "")):
				"fire":
					StatusFx.apply(game, t, "burn", 1)
				"ice":
					StatusFx.apply(game, t, "chill", 1)
				"lightning":
					_chain_from(t, 1, maxi(1, int(DB.ITEMS[get_weapon_id()].get("damage", 2)) - 1), "lightning", 60.0, {t.get_instance_id(): true})


func _relic_on_hit(t: Node, source: String) -> void:
	if not is_valid_target(t):
		return
	if buffs.has("relic_kindle") and source == "basic":
		StatusFx.apply(game, t, "burn", 1)
	if buffs.has("relic_soulfeast"):
		StatusFx.apply(game, t, "curse", 1)
	if buffs.has("relic_overcharge") and _overcharge_cd <= 0.0:
		_overcharge_cd = 0.25
		_chain_from(t, 1, 2, "lightning", 64.0, {t.get_instance_id(): true})


func heal(amount: int, color := Color("9cf5a5"), quiet := false) -> int:
	if amount <= 0 or state == State.DEAD:
		return 0
	var before := health
	health = mini(max_health, health + amount)
	var gained := health - before
	if gained > 0:
		health_changed.emit()
		if game:
			game.fx.number(global_position + Vector2(0, -18), "+%d" % gained, color)
			if not quiet:
				game.fx.spawn("aura", global_position + Vector2(0, -8), 0.0, 1.3, color, null, true)
				game.fx.burst("spark", global_position + Vector2(0, -10), 10, 50.0, Color(0.8, 1.0, 0.85), -40.0)
				game.audio.play("heal", 0.03, -3.0)
	return gained


# ------------------------------------------------------------------ loop
func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	charge.tick(delta, Input.is_action_pressed("attack"))
	Assassin.rush_tick(self, delta)
	if _flurry_t > 0.0:
		_flurry_t -= delta
		if _flurry_t <= 0.0:
			_flurry_stacks = 0
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
	var before := global_position
	knockback = KB.move(self, velocity, knockback)
	knockback = KB.decay(knockback, delta)
	pushing = state == State.MOVE and input.length() > 0.5 and global_position.distance_to(before) < 0.25 and get_slide_collision_count() > 0
	_update_anim(input)
	_update_visuals(delta)


func _tick_timers(delta: float) -> void:
	_lock_t = maxf(0.0, _lock_t - delta)
	_attack_buffer = maxf(0.0, _attack_buffer - delta)
	_switch_lock = maxf(0.0, _switch_lock - delta)
	_ls_window -= delta
	if _ls_window <= 0.0:
		_ls_window = 1.0
		_ls_sec = 0.0
	invulnerable_left = maxf(0.0, invulnerable_left - delta)
	parry_cooldown = maxf(0.0, parry_cooldown - delta)
	if buffs.has("relic_barkskin"):
		var before_t := float(buffs["relic_barkskin"])
		if floori(before_t) != floori(before_t - delta) and health < max_health and state != State.DEAD:
			health = mini(max_health, health + 1)
			health_changed.emit()
	for b in buffs.keys():
		buffs[b] = float(buffs[b]) - delta
		if float(buffs[b]) <= 0.0:
			buffs.erase(b)
	for k in skill_cd.keys():
		skill_cd[k] = maxf(0.0, float(skill_cd[k]) - delta)
	dodge_cd = maxf(0.0, dodge_cd - delta)
	flask_cd = maxf(0.0, flask_cd - delta)
	relic_cd = maxf(0.0, relic_cd - delta)
	_overcharge_cd = maxf(0.0, _overcharge_cd - delta)
	_target_t -= delta
	if _target_t <= 0.0:
		_target_t = 0.1
		_update_target()
	focus = minf(focus_max, focus + 6.0 * delta)
	attack_left = maxf(0.0, attack_left - delta)
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	combo_timer = maxf(0.0, combo_timer - delta)
	if combo_timer <= 0.0 and state != State.ATTACK:
		attack_combo = -1
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
	if charge.charging:
		speed *= float(CD.BALANCE.get("charge_move", 0.6))
	velocity = velocity.move_toward(input * speed, ACCEL * delta)
	if not input_enabled:
		return
	if Input.is_action_just_pressed("jump"):
		start_jump()
	if bow_charge >= 0.0:
		bow_charge += delta
		if not Input.is_action_pressed("attack"):
			_release_bow()
		return
	var hold_def: Dictionary = weapon_def().get("hold", {})
	if not hold_def.is_empty():
		# signature weapon: tap attacks, holding charges the special (no hold-repeat)
		if Input.is_action_just_pressed("attack"):
			try_attack()
			if not charge.active():
				charge.press(get_weapon_id(), hold_def)
		elif _attack_buffer > 0.0 and attack_cooldown <= 0.0 and not charge.charging:
			try_attack()
		return
	var held := Input.is_action_pressed("attack") and String(weapon_def()["pattern"]) != "bow"
	if Input.is_action_just_pressed("attack") or (_attack_buffer > 0.0 and attack_cooldown <= 0.0) or (held and attack_cooldown <= 0.0):
		try_attack()


## Dodge: directional (move input, else facing), stamina + short cooldown,
## invulnerable for BALANCE.dodge_iframe_fraction of the roll. Cancels attacks.
func start_roll(input := Vector2.ZERO) -> bool:
	var ready := not swimming and not fishing and stamina >= 18.0 and dodge_cd <= 0.0
	if ready and state == State.ATTACK:
		state = State.MOVE
		_hammer_pending = -1.0
	if state != State.MOVE or swimming or fishing or stamina < 18.0 or dodge_cd > 0.0:
		return false
	stamina -= 22.0
	stamina_delay = 0.6
	dodge_cd = float(CD.BALANCE["dodge_cooldown"])
	_charge = {}
	_dash_speed = 0.0
	roll_dir = input.normalized() if input.length() > 0.1 else facing
	_set_facing(roll_dir)
	state = State.ROLL
	roll_t = ROLL_TIME
	invulnerable_left = maxf(invulnerable_left, ROLL_TIME * float(CD.BALANCE["dodge_iframe_fraction"]))
	bow_charge = -1.0
	if game:
		game.audio.play("jump2", 0.1, -6.0)
		game.fx.dust(global_position)
		game.fx.burst("spark", global_position + Vector2(0, -6), 4, 30.0, Color(1, 0.8, 0.95, 0.8), 0.0, 0.3)
	return true


## Skill-driven dash (Iron Charge) reusing the roll state with a fixed speed.
func _start_dash(dir: Vector2, time: float, speed: float) -> void:
	_dash_frames = 0
	_dash_prev = global_position
	roll_dir = dir.normalized()
	_set_facing(roll_dir)
	state = State.ROLL
	roll_t = time
	_dash_time = time
	_dash_speed = speed
	bow_charge = -1.0


## Dashes stop at walls (no progress), before water ("dry") and at "dest".
func _dash_should_stop(delta: float) -> bool:
	if _dash_frames > 1 and global_position.distance_to(_dash_prev) < _dash_speed * delta * 0.25:
		return true
	_dash_frames += 1
	_dash_prev = global_position
	if _charge.is_empty() or game == null:
		return false
	if _charge.has("dest") and ((_charge["dest"] as Vector2) - global_position).dot(roll_dir) <= 2.0:
		return true
	if bool(_charge.get("dry", false)):
		var ahead := global_position + roll_dir * 7.0
		var ws: Vector2 = game.world.world_size
		if ahead.x >= 0.0 and ahead.y >= 0.0 and ahead.x < ws.x and ahead.y < ws.y and game.world.is_water(ahead):
			return true
	return false


func _end_dash() -> void:
	var cb = _charge.get("on_end")
	_dash_speed = 0.0
	_charge = {}
	state = State.MOVE
	velocity *= 0.3
	if cb is Callable and (cb as Callable).is_valid():
		(cb as Callable).call()


func _state_roll(delta: float) -> void:
	roll_t -= delta
	var k := clampf(roll_t / ROLL_TIME, 0.0, 1.0)
	if _dash_speed > 0.0:
		velocity = roll_dir * _dash_speed
		if not _charge.is_empty() and game:
			var hit: Dictionary = _charge["hit"]
			for t in game.hittable_targets(global_position + Vector2(0, -4), float(_charge["radius"])):
				if hit.has(t.get_instance_id()):
					continue
				hit[t.get_instance_id()] = true
				var inf: Dictionary = (_charge["info"] as Dictionary).duplicate()
				inf["force"] = float(_charge["force"])
				if not bool(_charge.get("no_stun", false)):
					inf["status"] = {"stun": 1}
				deal(t, int(_charge["dmg"]), inf)
				game.fx.spawn("cut", t.global_position + Vector2(0, -6), randf() * TAU, 0.7, Color(0.8, 0.9, 1.0), null, true)
				var cb = _charge.get("on_hit")
				if cb is Callable and (cb as Callable).is_valid():
					(cb as Callable).call(t)
				if _charge.is_empty():
					break
		if roll_t <= 0.0 or _dash_should_stop(delta):
			_end_dash()
			return
		_ghost_t -= delta
		if _ghost_t <= 0.0:
			_ghost_t = 0.04
			_afterimage()
		return
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


func move_intent() -> Vector2:
	if move_intent_override != Vector2.INF:
		return move_intent_override
	if not input_enabled:
		return Vector2.ZERO
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


## Direction of the next basic attack. Priority:
##  1. deliberate stick/keys (|input| > INTENT_DEADZONE) - a target inside a
##     50-degree cone of that input is snapped to (aim assist), otherwise the
##     input direction wins, so auto-targeting never overrides the player;
##  2. a manually locked target; 3. the auto-target in acquire range; 4. facing.
func attack_direction() -> Vector2:
	var tdir := Vector2.ZERO
	var t: Node2D = manual_target if is_valid_target(manual_target) else (current_target if is_valid_target(current_target) else null)
	if t != null:
		var to: Vector2 = (t.global_position + Vector2(0, -5)) - (global_position + Vector2(0, -4))
		if to.length() > 0.5 and to.length() <= acquire_range() * 1.2:
			tdir = to.normalized()
	var inp := move_intent()
	if inp.length() > INTENT_DEADZONE:
		var n := inp.normalized()
		if tdir != Vector2.ZERO and (aim_assist or t == manual_target) and n.dot(tdir) >= ASSIST_CONE:
			_attack_dir_source = "assist"
			return tdir
		_attack_dir_source = "input"
		return n
	if tdir != Vector2.ZERO and (auto_target_enabled or t == manual_target):
		_attack_dir_source = "target"
		return tdir
	_attack_dir_source = "facing"
	return facing


func try_attack() -> bool:
	if fishing or roll_t > 0.0 or swimming or state == State.ROLL:
		return false
	if attack_cooldown > 0.0 or (state != State.MOVE and state != State.ATTACK):
		# input buffer: a press slightly early queues the next swing instead of
		# being dropped (but never shortens the cooldown)
		if state == State.MOVE or state == State.ATTACK:
			_attack_buffer = ATTACK_BUFFER
		return false
	_attack_buffer = 0.0
	_update_target()
	_set_facing(attack_direction())
	var w := weapon_def()
	_attack_charged = false
	match String(w["pattern"]):
		"combo", "daggers", "sweep", "katana":
			_attack_melee(w)
		"whip":
			Specials.whip_attack(self, w)
		"bolt", "prism":
			_attack_staff()
		"bow":
			bow_charge = 0.0
			sprite.play("attack_" + dir_name)
			sprite.pause()
			return true
		"slam":
			_attack_hammer()
	return true


func _begin_attack(lock: float, cooldown: float) -> void:
	state = State.ATTACK
	_lock_t = lock
	attack_left = lock
	attack_cooldown = cooldown
	sprite.play("attack_" + dir_name)
	sprite.frame = 0


## Legacy entry (tests): one basic blade swing.
func _attack_blade() -> void:
	_update_target()
	_set_facing(attack_direction())
	_attack_melee(weapon_def())


## Arc-shaped melee: combo blades, twin daggers and the reaping scythe. The hit
## test is exactly the sector the ground indicator draws.
func _attack_melee(w: Dictionary) -> void:
	var combo_len := int(w.get("combo", 3))
	if combo_timer <= 0.0:
		attack_combo = -1
	attack_combo = (attack_combo + 1) % combo_len
	var finisher := combo_len > 1 and attack_combo == combo_len - 1
	_attack_is_finisher = finisher
	var pattern := String(w["pattern"])
	var spd := attack_speed_mult()
	combo_timer = 0.62 if not pattern in ["daggers", "katana"] else 0.48
	var lock := float(w["lock"]) * (1.35 if finisher and pattern == "combo" else 1.0) / spd
	var cd := float(w["cooldown"]) * (1.4 if finisher and pattern == "combo" else 1.0) / spd
	_begin_attack(lock, cd)
	var lunge := 95.0
	match pattern:
		"daggers", "katana":
			lunge = 75.0
		"sweep":
			lunge = 40.0
	if finisher:
		lunge = 150.0
	# step toward a target that is just beyond reach so swings connect
	if is_valid_target(current_target):
		var gap := global_position.distance_to(current_target.global_position) - float(w["reach"])
		if gap > 0.0 and gap < 24.0:
			lunge += gap * 5.0
	velocity = facing * lunge
	_swing_weapon(0.2 / spd, finisher or pattern == "sweep")
	if game == null:
		return
	var reach := float(w["finisher_reach"]) if finisher else float(w["reach"])
	var half := float(w["half_angle"])
	var origin := global_position + Vector2(0, -4)
	var tint := Color(String(w.get("color", "ffd9f2")))
	var center := origin + facing * reach * 0.5
	if is_unarmed():
		game.audio.play("hit1" if not finisher else "impact", 0.12, -6.0)
	else:
		_melee_fx(pattern, finisher, center, origin, tint)
	_melee_hits(w, pattern, finisher, reach, half, origin, center)


func _melee_fx(pattern: String, finisher: bool, center: Vector2, origin: Vector2, tint: Color) -> void:
	match pattern:
		"katana":
			# cross-slashes: two crossing cuts, the finisher a wide double cut
			var a := facing.angle()
			if finisher:
				game.fx.spawn("slash_double", center, a, 1.2, Color(0.9, 0.88, 1.0), null, true)
				game.fx.spawn("slash", center, a + PI, 1.0, tint, null, true)
			else:
				game.fx.spawn("slash", center, a + 0.55, 0.85, tint, null, true)
				game.fx.spawn("slash", center, a - 0.55 + PI, 0.85, Color(1, 1, 1, 0.85), null, true)
			game.audio.play("slash" if attack_combo % 2 == 0 else "slash2", 0.1, -4.0)
		"daggers":
			game.fx.spawn("slash", center, facing.angle() + (PI if attack_combo == 1 else 0.0), 0.75, tint, null, true)
			game.audio.play("slash" if attack_combo == 0 else "slash2", 0.1, -5.0)
		"sweep":
			game.fx.spawn("slash_circular", origin + facing * 6.0, facing.angle(), 1.25, tint, null, true)
			game.audio.play("slash3", 0.06, -3.0)
		_:
			game.fx.spawn("slash_double" if finisher else "slash", center, facing.angle() + (0.0 if attack_combo != 1 else PI), 1.15 if finisher else 0.9, Color(1, 0.95, 0.75) if finisher else tint, null, true)
			game.audio.play("slash" if attack_combo == 0 else ("slash2" if attack_combo == 1 else "slash3"), 0.08, -3.0)


func _melee_hits(w: Dictionary, pattern: String, finisher: bool, reach: float, half: float, origin: Vector2, center: Vector2) -> void:
	var base := int(DB.ITEMS[get_weapon_id()].get("damage", 2))
	var dmg := (base * 2 if finisher and pattern in ["combo", "katana"] else base) + attack_bonus()
	var force := 110.0 if finisher else 55.0
	if is_unarmed():
		force = 90.0 if finisher else 40.0
	if pattern == "sweep":
		force = 80.0
	var hits := 0
	for t in game.targets_in_arc(origin, facing, reach, half):
		deal(t, dmg, {"element": String(w.get("element", "")), "source": "basic", "force": force})
		hits += 1
	game.break_props(center, reach * 0.6)
	if hits > 0:
		game.hitstop(0.06 if finisher else 0.035)


func _attack_staff() -> void:
	var w := weapon_def()
	var spd := attack_speed_mult()
	_begin_attack(float(w["lock"]) / spd, float(w["cooldown"]) / spd)
	_swing_weapon(0.18 / spd, false, true)
	if game == null:
		return
	var dir: Vector2 = _aim_dir(float(w["reach"]))
	var elem := String(w.get("element", "arcane"))
	var kind := String(w.get("kind", "bolt"))
	if String(w["pattern"]) == "prism":
		elem = ["fire", "ice", "lightning"][prism_index % 3]
		kind = ["fireball", "ice_spike", "energy_ball"][prism_index % 3]
		prism_index += 1
	var dmg := int(DB.ITEMS[get_weapon_id()].get("damage", 3)) + ranged_bonus()
	var speed := float(w["speed"])
	var bonus_status := {}
	_spawn_player_projectile({"kind": kind, "pos": global_position + Vector2(0, -9) + dir * 8.0, "dir": dir, "speed": speed,
		"homing": float(w.get("homing", 0.0)), "life": float(w["reach"]) / speed, "element": elem},
		dmg, {"element": elem, "source": "basic", "status": bonus_status, "staff_resonance": String(w.get("passive", "")) == "moon_resonance"})
	game.fx.spawn("spark", global_position + Vector2(0, -9) + dir * 10.0, 0.0, 0.5, CD.element_color(elem), null, true)
	game.audio.play("magic1", 0.08, -5.0)


## Direction toward the current target if it lies within `reach`, else facing.
func _aim_dir(reach: float) -> Vector2:
	if _attack_dir_source == "input":
		return facing
	if is_valid_target(current_target) and global_position.distance_to(current_target.global_position) <= reach + 12.0:
		return ((current_target.global_position + Vector2(0, -5)) - (global_position + Vector2(0, -8))).normalized()
	if game and aim_assist:
		return game.auto_aim(global_position, facing, reach)
	return facing


func _release_bow() -> void:
	var w := weapon_def()
	var charged := bow_charge >= 0.55
	_attack_charged = charged
	bow_charge = -1.0
	var spd := attack_speed_mult()
	_begin_attack(float(w["lock"]) / spd, float(w["cooldown"]) / spd)
	_swing_weapon(0.15, false, true)
	if game:
		_update_target()
		_set_facing(attack_direction())
		var dir: Vector2 = _aim_dir(float(w["reach"]))
		var speed := 360.0 if charged else 280.0
		var dmg := (6 if charged else 3) + ranged_bonus()
		_spawn_player_projectile({"kind": "arrow", "pos": global_position + Vector2(0, -8) + dir * 8.0, "dir": dir,
			"speed": speed, "pierce": charged, "life": float(w["reach"]) / speed, "glow": charged}, dmg,
			{"source": "basic", "force": 140.0})
		game.audio.play("launch" if charged else "slash5", 0.08, -4.0)
		if charged:
			game.fx.spawn("spark", global_position + Vector2(0, -8) + dir * 12.0, 0.0, 0.6, Color(0.8, 1.0, 0.9), null, true)


func _attack_hammer() -> void:
	var w := weapon_def()
	var spd := attack_speed_mult()
	_begin_attack(float(w["lock"]) / spd, float(w["cooldown"]) / spd)
	velocity = facing * 40.0
	_swing_weapon(0.32 / spd, true)
	_hammer_pending = 0.24 / spd


func _hammer_impact() -> void:
	if game == null or String(weapon_def()["pattern"]) != "slam":
		return
	# the impact lands where the swing was aimed (no re-facing mid-swing)
	var w := weapon_def()
	var center := global_position + Vector2(0, -4) + facing * float(w.get("offset", 18.0))
	var rad := float(w["reach"])
	game.fx.spawn("explosion", center, 0.0, 0.8, Color(1, 0.95, 0.85, 0.9))
	game.fx.burst("rock", center, 10, 90.0, Color(1, 1, 1), 220.0)
	game.fx.ring(center, rad, 0.25, Color(1.0, 0.9, 0.7, 0.8), false)
	game.fx.shake(4.0, 0.22)
	game.audio.play("impact3", 0.06, -1.0)
	var base := int(DB.ITEMS[get_weapon_id()].get("damage", 5))
	var hits := 0
	for t in game.hittable_targets(center, rad):
		deal(t, base + attack_bonus(), {"source": "basic", "force": 160.0})
		hits += 1
	game.break_props(center, rad)
	if hits > 0:
		game.hitstop(0.08)


## Legacy helper kept for callers: face the nearest enemy in reach.
func _snap_to_target(reach: float) -> void:
	if game == null:
		return
	var t: Node2D = game.nearest_enemy(global_position, reach * 1.6)
	if t == null:
		return
	var to: Vector2 = (t.global_position + Vector2(0, -5)) - global_position
	if facing.dot(to.normalized()) < -0.2:
		return
	_set_facing(to)


func _swing_weapon(duration: float, heavy: bool, point := false) -> void:
	var item: Dictionary = DB.ITEMS[get_weapon_id()]
	var held_path := DB.hand_path(get_weapon_id())
	if is_unarmed() or held_path == "":
		_punch_fx(heavy)
		return
	var t: Texture2D = AnimLib.tex(held_path)
	weapon_sprite.texture = t
	weapon_sprite.offset = Vector2(-t.get_width() / 2.0, -t.get_height())
	weapon_sprite.modulate = Color(String(item.get("tint", "ffffff")))
	var hand := {"down": Vector2(3, -6), "up": Vector2(-3, -10), "left": Vector2(-4, -7), "right": Vector2(4, -7)}
	weapon_sprite.position = hand[dir_name]
	_layer_behind_body(weapon_sprite, dir_name == "up")
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
		if is_dual_wield() and off_weapon_sprite != null:
			# twin knives: the off-hand knife cuts back across on alternate strikes
			var hand2 := {"down": Vector2(-3, -6), "up": Vector2(3, -10), "left": Vector2(2, -7), "right": Vector2(-2, -7)}
			off_weapon_sprite.texture = t
			off_weapon_sprite.position = hand2[dir_name]
			_layer_behind_body(off_weapon_sprite, dir_name != "down")
			off_weapon_sprite.visible = true
			off_weapon_sprite.rotation = base + arc * sgn
			var tw2 := create_tween()
			tw2.tween_property(off_weapon_sprite, "rotation", base - arc * sgn, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_swinging = true
	tw.tween_callback(func() -> void:
		_swinging = false
		_update_held_weapon())


## Bare-handed strikes: a paw jab with a small impact puff in front of Mallow.
func _punch_fx(heavy: bool) -> void:
	if game == null:
		return
	var w := weapon_def()
	var p := global_position + Vector2(0, -5) + facing * float(w.get("reach", 18.0)) * 0.7
	game.fx.burst("spark", p, 8 if heavy else 5, 55.0 if heavy else 40.0, Color(1.0, 0.92, 0.8), -10.0)


func _state_attack(delta: float, _input: Vector2) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, 700.0 * delta)
	var pattern := String(weapon_def()["pattern"])
	if input_enabled and Input.is_action_just_pressed("attack") and pattern != "bow":
		_attack_buffer = ATTACK_BUFFER
		var hold_def: Dictionary = weapon_def().get("hold", {})
		if not hold_def.is_empty() and not charge.active():
			charge.press(get_weapon_id(), hold_def)
	if _lock_t <= 0.0:
		state = State.MOVE


func activate_mothlight() -> bool:
	return cast_skill("mothlight")


func activate_petalguard() -> bool:
	return cast_skill("petalguard")


## Potion uses left: flask charges plus Moontea Vials carried in the bag.
func potions_left() -> int:
	return moontea_charges + Inv.count(self, "moontea_vial")


## Why the potion button can't be used right now ("" = usable).
func potion_block_reason() -> String:
	if state == State.DEAD:
		return "busy"
	if potions_left() <= 0:
		return "empty"
	if flask_cd > 0.0:
		return "cooldown"
	if health >= max_health:
		return "full"
	return ""


## Moontea flask: limited charges, short cooldown, never heals past max.
func drink_moontea() -> bool:
	if state == State.DEAD or flask_cd > 0.0:
		return false
	var use_vial := moontea_charges <= 0 and Inv.count(self, "moontea_vial") > 0
	if moontea_charges <= 0 and not use_vial:
		if game:
			game.hud.show_message("Flask empty. Rest at a waystone or buy Moontea Vials.", 1.6)
		return false
	if health >= max_health:
		if game:
			game.hud.show_message("Already at full health.", 1.2)
		return false
	if use_vial:
		Inv.remove(self, "moontea_vial", 1)
	else:
		moontea_charges -= 1
	flask_cd = float(CD.BALANCE["flask_cooldown"])
	var amt := int(round(float(CD.BALANCE["flask_heal"]) * heal_mult()))
	health = mini(max_health, health + amt)
	health_changed.emit()
	if game:
		game.audio.play("heal", 0.03, -3.0)
		game.fx.spawn("aura", global_position + Vector2(0, -8), 0.0, 1.3, Color(0.75, 1.0, 0.8), null, true)
		game.fx.burst("spark", global_position + Vector2(0, -10), 10, 50.0, Color(0.8, 1.0, 0.85), -40.0)
		game.fx.number(global_position, "+%d" % amt, Color("9cf5a5"))
	return true


## Relic slot active buff. Separate from the four art slots.
func relic_id() -> String:
	var id := String(equipped.get("relic", ""))
	if id == "" or not Build.can_equip(self, id):
		return ""
	return String(DB.ITEMS[id].get("relic", ""))


func relic_block_reason() -> String:
	var r := relic_id()
	if r == "":
		return "No relic equipped."
	if relic_cd > 0.0:
		return "cooldown"
	if state == State.DEAD:
		return "busy"
	return ""


func activate_relic() -> bool:
	if relic_block_reason() != "":
		return false
	var r := relic_id()
	var def: Dictionary = CD.RELICS[r]
	relic_cd = float(def["cd"])
	buffs["relic_" + r] = float(def["time"])
	if game:
		var c := Color(String(def["color"]))
		game.fx.spawn("aura", global_position + Vector2(0, -8), 0.0, 1.6, c, null, true)
		game.fx.burst("spark", global_position + Vector2(0, -10), 14, 70.0, c, -30.0)
		game.audio.play("secret2", 0.03, -3.0)
		game.hud.show_message("%s: %s" % [def["name"], def["desc"]], 2.5)
	stats_changed.emit()
	return true


func take_damage(amount: int = 2, from := Vector2.INF) -> bool:
	if state == State.DEAD:
		return false
	if guard_active:
		# Petalguard opened in the last 0.6s: perfect parry (stun + riposte)
		var perfect := guard_time_left >= 4.4 and parry_cooldown <= 0.0
		guard_active = false
		guard_time_left = 0.0
		invulnerable_left = 0.45
		if perfect:
			parry_cooldown = 2.0
			if game:
				game.on_perfect_parry(self)
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
	var poise := 1.0 - clampf(stat("poise"), 0.0, 0.8)
	if from != Vector2.INF:
		var away := (global_position - from).normalized()
		knockback = KB.push(knockback, away, KB.PLAYER_BASE, 1.0 - poise)
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
	_update_held_weapon()
	var h := -sprite.position.y
	var s := 1.0 - clampf(h / 30.0, 0.0, 0.45)
	shadow.scale = Vector2(0.5, 0.42) * s
	shadow.visible = not swimming or airborne
	# basic-attack indicator: always on during play (idle and moving), shows the
	# held weapon's real shape and reach, brightens when a target is inside it.
	if range_hint != null:
		var playing: bool = game != null and game.game_started and state != State.DEAD and not swimming and not fishing and attack_indicator_opacity > 0.01
		range_hint.visible = playing
		if playing:
			var d := facing if state != State.MOVE else attack_direction()
			var engaged := false
			if is_valid_target(current_target):
				var to: Vector2 = current_target.global_position - global_position
				engaged = to.length() <= float(weapon_def()["reach"]) + 6.0
			range_hint.opacity = attack_indicator_opacity
			range_hint.tick(delta, d, engaged)
	if target_marker != null:
		target_marker.target = current_target if is_valid_target(current_target) and game != null and game.game_started else null
		target_marker.locked = manual_target != null and current_target == manual_target
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


func _refresh_attack_indicator() -> void:
	if range_hint != null and range_hint.has_method("setup_from"):
		range_hint.setup_from(weapon_def())
