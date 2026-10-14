extends Node2D
## Petalbound: open-world orchestration. Builds the world, actors and UI; owns combat
## resolution, loot, interactions, regions, bosses, save/load and the Moonwell ending.

const AnimLib := preload("res://scripts/core/anim_lib.gd")
const DB := preload("res://scripts/data/db.gd")
const Save := preload("res://scripts/systems/save.gd")
const WorldScript := preload("res://scripts/world/world.gd")
const PlayerScript := preload("res://scripts/actors/player.gd")
const EnemyScript := preload("res://scripts/actors/enemy.gd")
const BossScript := preload("res://scripts/actors/boss.gd")
const NpcScript := preload("res://scripts/actors/npc.gd")
const ProjectileScript := preload("res://scripts/combat/projectile.gd")
const FxScript := preload("res://scripts/core/fx.gd")
const AudioScript := preload("res://scripts/core/audio.gd")
const EnvScript := preload("res://scripts/systems/environment.gd")
const HudScript := preload("res://scripts/ui/hud.gd")

const CAMERA_ZOOM := 1.5
const SHOPS := {
	"pip": [{"id": "moontea", "price": 20}, {"id": "heart_piece", "price": 150, "once": "pip_heart"}],
	"nomad": [{"id": "moontea", "price": 24}, {"id": "heart_piece", "price": 220, "once": "nomad_heart"}],
}

var world: Node2D
var entities: Node2D
var fx: Node2D
var projectiles: Node2D
var audio: Node
var environment: Node
var hud: Control
var hud_layer: CanvasLayer
var camera: Camera2D
var player: CharacterBody2D
var enemies: Array = []
var bosses: Array = []
var npcs: Array = []
var chests: Array = []
var waystones: Array = []
var pickups: Array = []
var moonwell: Node2D
var moonwell_light: PointLight2D
var game_started := false
var game_over := false
var victory := false
var moonseeds: Array = []
var defeated_bosses: Array = []
var opened_chests: Array = []
var flags: Dictionary = {}
var discovered_waystones: Array = ["hearthgrove"]
var last_waystone := "hearthgrove"
var current_biome := 0
var current_region := ""
var active_boss: Node = null
var shop_id := ""
var talking_npc: Node = null
var shake_strength := 0.0
var shake_time := 0.0
var _look := Vector2.ZERO
var _interact_target: Dictionary = {}
var _hitstop_active := false
var _activation_t := 0.0
var _title_t := 0.0
var _save_t := 0.0
var kills := 0


func _ready() -> void:
	randomize()
	audio = AudioScript.new()
	audio.name = "Audio"
	add_child(audio)
	world = WorldScript.new()
	world.name = "World"
	add_child(world)
	entities = Node2D.new()
	entities.name = "Entities"
	entities.y_sort_enabled = true
	add_child(entities)
	world.build(entities)
	projectiles = Node2D.new()
	projectiles.name = "Projectiles"
	projectiles.z_index = 5
	add_child(projectiles)
	fx = FxScript.new()
	fx.name = "FX"
	add_child(fx)
	fx.shake_requested.connect(_on_shake)
	player = PlayerScript.new()
	player.name = "Mallow"
	player.game = self
	entities.add_child(player)
	player.global_position = Vector2(world.data["start"][0], world.data["start"][1])
	player.died.connect(_on_player_died)
	camera = Camera2D.new()
	camera.zoom = Vector2(CAMERA_ZOOM, CAMERA_ZOOM)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(world.world_size.x)
	camera.limit_bottom = int(world.world_size.y)
	add_child(camera)
	camera.make_current()
	_spawn_npcs()
	_spawn_enemies()
	_spawn_bosses()
	_spawn_chests()
	_spawn_waystones()
	_spawn_moonwell()
	environment = EnvScript.new()
	environment.name = "Environment"
	add_child(environment)
	environment.setup(self, self)
	hud_layer = CanvasLayer.new()
	hud_layer.layer = 10
	add_child(hud_layer)
	hud = HudScript.new()
	hud.name = "HUD"
	hud_layer.add_child(hud)
	hud.setup(self)
	hud.build_minimap_texture(world.biome_image, world.field_image)
	hud.start_requested.connect(_on_start_requested)
	hud.retry_requested.connect(_on_retry_requested)
	_enter_title()


# ------------------------------------------------------------------ spawning
func _spawn_npcs() -> void:
	for d in world.data["npcs"]:
		var n := NpcScript.new()
		n.setup(self, d)
		entities.add_child(n)
		npcs.append(n)
	for d in world.data["animals"]:
		var a := NpcScript.new()
		a.setup(self, d, true)
		entities.add_child(a)


func _spawn_enemies() -> void:
	for d in world.data["enemies"]:
		if not DB.ENEMIES.has(d["s"]):
			continue
		var e := EnemyScript.new()
		e.setup(self, d["s"], Vector2(d["x"], d["y"]))
		entities.add_child(e)
		enemies.append(e)


func _spawn_bosses() -> void:
	for d in world.data["bosses"]:
		var b := BossScript.new()
		b.setup(self, d["id"], d["kind"], Vector2(d["x"], d["y"]))
		entities.add_child(b)
		bosses.append(b)


func _spawn_chests() -> void:
	for d in world.data["chests"]:
		var big: bool = d.get("big", false)
		var tex: Texture2D = AnimLib.tex("items/bigtreasurechest.png" if big else "items/littletreasurechest.png")
		var s := Sprite2D.new()
		s.texture = tex
		s.hframes = 2
		s.centered = false
		s.offset = Vector2(-8, -tex.get_height())
		s.position = Vector2(d["x"], d["y"])
		entities.add_child(s)
		var body := StaticBody2D.new()
		body.collision_layer = 1
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(14, 7)
		cs.shape = rect
		cs.position = Vector2(0, -4)
		body.add_child(cs)
		s.add_child(body)
		var glow := PointLight2D.new()
		glow.texture = WorldScript.light_texture()
		glow.texture_scale = 0.45
		glow.color = Color(1.0, 0.85, 0.5)
		glow.energy = 0.3 if big else 0.15
		glow.position = Vector2(0, -8)
		s.add_child(glow)
		chests.append({"id": d["id"], "item": d["item"], "sprite": s, "pos": Vector2(d["x"], d["y"]), "open": false, "glow": glow, "big": big})


func _spawn_waystones() -> void:
	var defs: Dictionary = world.prop_defs
	for d in world.data["shrines"]:
		var pos := Vector2(d["x"], d["y"])
		var s := Sprite2D.new()
		var r: Array = defs["statue_monk"]["rect"]
		s.texture = world.sheet(defs["statue_monk"]["sheet"])
		s.region_enabled = true
		s.region_rect = Rect2(r[0], r[1], r[2], r[3])
		s.centered = false
		s.offset = Vector2(-floorf(r[2] / 2.0), -r[3])
		s.position = pos
		entities.add_child(s)
		var circle := AnimatedSprite2D.new()
		circle.sprite_frames = AnimLib.strip_frames("res://assets/packs/ninja_adventure/fx/magic_circle.png", 32, 8.0, true)
		circle.position = pos + Vector2(0, 6)
		circle.scale = Vector2(1.1, 0.7)
		circle.z_index = -7
		circle.modulate = Color(0.85, 0.75, 1.0, 0.0)
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		circle.material = m
		add_child(circle)
		circle.play("play")
		var light := PointLight2D.new()
		light.texture = WorldScript.light_texture()
		light.color = Color(0.8, 0.7, 1.0)
		light.energy = 0.0
		light.texture_scale = 1.0
		light.position = pos + Vector2(0, -14)
		add_child(light)
		var body := StaticBody2D.new()
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(16, 8)
		cs.shape = rect
		cs.position = Vector2(0, -4)
		body.add_child(cs)
		s.add_child(body)
		waystones.append({"id": d["id"], "name": d["name"], "pos": pos, "circle": circle, "light": light})


func _spawn_moonwell() -> void:
	var lm: Array = world.data["landmarks"]["moonwell"]
	moonwell = Node2D.new()
	moonwell.position = Vector2(lm[0], lm[1])
	add_child(moonwell)
	var circle := AnimatedSprite2D.new()
	circle.sprite_frames = AnimLib.strip_frames("res://assets/packs/ninja_adventure/fx/magic_circle.png", 32, 6.0, true)
	circle.scale = Vector2(2.6, 1.7)
	circle.z_index = -7
	circle.modulate = Color(0.75, 0.8, 1.0, 0.35)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	circle.material = m
	circle.name = "Circle"
	moonwell.add_child(circle)
	circle.play("play")
	var spirit := AnimatedSprite2D.new()
	spirit.sprite_frames = AnimLib.strip_frames("res://assets/packs/ninja_adventure/fx/spirit_blue.png", 32, 8.0, true)
	spirit.position = Vector2(0, -14)
	spirit.modulate = Color(0.8, 0.85, 1.0, 0.5)
	spirit.material = m
	spirit.name = "Spirit"
	moonwell.add_child(spirit)
	spirit.play("play")
	moonwell_light = PointLight2D.new()
	moonwell_light.texture = WorldScript.light_texture()
	moonwell_light.color = Color(0.7, 0.8, 1.0)
	moonwell_light.energy = 0.3
	moonwell_light.texture_scale = 2.4
	moonwell.add_child(moonwell_light)


# ------------------------------------------------------------------ title & start
func _enter_title() -> void:
	game_started = false
	player.input_enabled = false
	player.visible = false
	environment.time_of_day = 0.74
	var lake: Array = world.data["landmarks"]["lake_lumen"]
	camera.position_smoothing_enabled = false
	camera.global_position = Vector2(lake[0], lake[1]) + Vector2(-60, 40)
	_title_t = 0.0
	audio.play_music("title")
	hud.show_title_menu(Save.exists())
	hud.hide_boss()


func _on_start_requested(new_game: bool = true) -> void:
	if new_game:
		Save.erase()
		_reset_state()
	else:
		_reset_state()
		load_game()
	hud.hide_title_menu()
	game_started = true
	game_over = false
	player.visible = true
	player.input_enabled = true
	camera.position_smoothing_enabled = true
	camera.global_position = player.global_position
	camera.reset_smoothing()
	current_region = ""
	environment.fade = 1.0
	create_tween().tween_property(environment, "fade", 0.0, 0.8)
	_update_region(true)
	hud.set_seed_count(moonseeds.size())
	if new_game:
		hud.show_message("Elder Alder is waiting in Hearthgrove. Press E to talk.", 5.0)
	audio.play("accept", 0.0, -4.0)


func _reset_state() -> void:
	moonseeds.clear()
	defeated_bosses.clear()
	opened_chests.clear()
	flags.clear()
	discovered_waystones = ["hearthgrove"]
	last_waystone = "hearthgrove"
	victory = false
	kills = 0
	environment.time_of_day = 0.34
	environment.blight = 0.6
	world.ground_material.set_shader_parameter("moonwell_power", 0.0)
	var p := player
	p.base_hearts = 5
	p.heart_pieces = 0
	p.weapons_owned.assign(["thornblade", "bloomstaff"])
	p.weapon_index = 0
	p.inventory.assign(["plum_cloak"])
	p.equipped = {"cloak": "plum_cloak"}
	p.moontea_charges = 3
	p.moontea_max = 3
	p.petalcoins = 0
	p.recalc_stats()
	p.apply_outfit()
	p.revive(Vector2(world.data["start"][0], world.data["start"][1]))
	for c in chests:
		c["open"] = false
		(c["sprite"] as Sprite2D).frame = 0
		c["glow"].visible = true
	for b in bosses:
		b.defeated = false
		b.awake = false
		b.hp = b.max_hp
		b.visible = true
		b.global_position = b.home
		b.collision_layer = 16
		b.collision_mask = 1
		b.mat.set_shader_parameter("dissolve", 0.0)
	for e in enemies:
		e.respawn()
		e.modulate.a = 1.0
	for pk in pickups:
		if is_instance_valid(pk["node"]):
			pk["node"].queue_free()
	pickups.clear()
	_refresh_waystones()
	active_boss = null


func return_to_title() -> void:
	hud.close_shop()
	if hud.dialogue_open:
		hud.end_dialogue()
	_enter_title()


func _on_retry_requested() -> void:
	if victory:
		game_over = false
		player.input_enabled = true
		return
	game_over = false
	var ws := _waystone(last_waystone)
	player.revive(ws["pos"] + Vector2(0, 18))
	player.input_enabled = true
	camera.global_position = player.global_position
	camera.reset_smoothing()
	for e in enemies:
		if e.alive:
			e.global_position = e.home
			e.aggro = false
	for b in bosses:
		if not b.defeated:
			b.awake = false
			b.hp = b.max_hp
			b.global_position = b.home
	active_boss = null
	hud.hide_boss()
	current_region = ""
	_update_region(true)
	environment.fade = 1.0
	create_tween().tween_property(environment, "fade", 0.0, 0.8)


func _on_player_died() -> void:
	game_over = true
	player.input_enabled = false
	audio.play("gameover", 0.0, -2.0)
	fx.shake(5.0, 0.3)
	var tw := create_tween()
	tw.tween_interval(1.1)
	tw.tween_callback(func() -> void: hud.show_game_over())


# ------------------------------------------------------------------ main loop
func _process(delta: float) -> void:
	audio.listener_pos = camera.global_position
	if not game_started:
		_title_t += delta
		var lake: Array = world.data["landmarks"]["lake_lumen"]
		camera.global_position = Vector2(lake[0], lake[1]) + Vector2(-60 + sin(_title_t * 0.08) * 120.0, 30 + cos(_title_t * 0.06) * 40.0)
		world.update_foliage(Vector2(-9999, -9999), environment.gust)
		return
	player.input_enabled = not game_over and not hud.any_menu_open() and not get_tree().paused
	_update_camera(delta)
	world.update_foliage(player.global_position, environment.gust)
	_update_pickups(delta)
	_update_interactables()
	_activation_t -= delta
	if _activation_t <= 0.0:
		_activation_t = 0.25
		_update_activation()
		_update_region(false)
	if not get_tree().paused and not game_over:
		if Input.is_action_just_pressed("interact"):
			_interact()
		if Input.is_action_just_pressed("switch_weapon") and not hud.touch_held.size():
			player.cycle_weapon()
		if Input.is_action_just_pressed("skill"):
			player.activate_mothlight()
		if Input.is_action_just_pressed("guard"):
			player.activate_petalguard()
		if Input.is_action_just_pressed("heal"):
			if not player.drink_moontea():
				if player.moontea_charges <= 0:
					hud.show_message("Your Moontea flask is empty. Rest at a waystone.", 2.0)
	var mw_power: float = world.ground_material.get_shader_parameter("moonwell_power")
	moonwell_light.energy = (0.15 + mw_power * 0.7) * (0.4 + environment.darkness) + sin(Time.get_ticks_msec() / 600.0) * 0.08
	_save_t += delta
	if _save_t > 45.0 and not game_over and active_boss == null:
		_save_t = 0.0
		save_game()


func _update_camera(delta: float) -> void:
	var target := player.global_position + Vector2(0, -8)
	var look := player.velocity * 0.22
	if active_boss and is_instance_valid(active_boss):
		target = target.lerp(active_boss.global_position, 0.3)
		look *= 0.3
	_look = _look.lerp(look, clampf(delta * 3.0, 0.0, 1.0))
	camera.global_position = target + _look
	if shake_time > 0.0:
		shake_time -= delta
		camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_strength * (shake_time / 0.3 + 0.3)
	else:
		camera.offset = camera.offset.lerp(Vector2.ZERO, clampf(delta * 12.0, 0.0, 1.0))


func _on_shake(strength: float, duration: float) -> void:
	shake_strength = maxf(shake_strength if shake_time > 0.0 else 0.0, strength)
	shake_time = maxf(shake_time, duration)


func _update_activation() -> void:
	var pp := player.global_position
	var now := Time.get_ticks_msec() / 1000.0
	for e in enemies:
		var near: bool = e.global_position.distance_to(pp) < 420.0
		e.set_physics_process(near and e.alive)
		if not e.alive and e.respawn_at > 0.0 and now > e.respawn_at and e.home.distance_to(pp) > 320.0:
			e.respawn_at = -1.0
			e.respawn()


func _update_region(force: bool) -> void:
	current_biome = world.biome_at(player.global_position)
	var name: String = world.region_name(player.global_position)
	if name == current_region and not force:
		return
	current_region = name
	var sub := ""
	match name:
		"Hearthgrove":
			sub = "a village of lanterns and soft bread"
		"The Moonwell":
			sub = "heart of the valley"
		"Lake Lumen":
			sub = "where the moon used to bathe"
		_:
			sub = ["meadows of drifting petals", "the old grove remembers", "sun-scarred and silent", "frost on forgotten stone", "reeds and slow water", "salt wind and shells"][clampi(current_biome, 0, 5)]
	hud.show_region(name, sub)
	if active_boss == null:
		var track: String = DB.REGION_MUSIC[clampi(current_biome, 0, 5)]
		if name == "Hearthgrove":
			track = "village"
		elif name == "The Moonwell" or environment.is_night():
			track = "night" if not victory else "ending"
		audio.play_music(track)
	audio.play_ambient(["bird", "wind", "wind", "wind", "rain", "water1"][clampi(current_biome, 0, 5)] if environment.quality_high else "")


# ------------------------------------------------------------------ combat api
func player_targetable() -> bool:
	return game_started and not game_over and player.state != player.State.DEAD


func hittable_targets(center: Vector2, radius: float) -> Array:
	var out: Array = []
	for e in enemies:
		if e.alive and (e.global_position + Vector2(0, -5)).distance_to(center) <= radius:
			out.append(e)
	for b in bosses:
		if b.awake and not b.defeated and (b.global_position + Vector2(0, -10)).distance_to(center) <= radius + float(b.cfg["radius"]):
			out.append(b)
	return out


func damage_target(t: Node, amount: int, from: Vector2, force: float) -> void:
	t.hurt(amount, from, force)


func melee_hit(center: Vector2, radius: float, damage: int, force: float, _dir: Vector2, _kind: String) -> int:
	var hits := 0
	for t in hittable_targets(center, radius):
		damage_target(t, damage, player.global_position, force)
		hits += 1
	for b in world.break_at(center, radius + 4.0):
		_break_prop(b)
		hits += 0
	return hits


func _break_prop(b: Dictionary) -> void:
	var pos: Vector2 = b["pos"]
	var kind: String = b["kind"]
	if kind.begins_with("bush"):
		fx.burst("leaf", pos, 10, 70.0, Color(1, 1, 1), 120.0)
		fx.burst("grass", pos, 6, 50.0, Color(1, 1, 1), 120.0)
		audio.play("grass", 0.12, -6.0, pos)
	else:
		fx.burst("wood" if kind in ["crate", "barrel"] else "rock", pos, 10, 80.0, Color(1, 1, 1), 200.0)
		audio.play("explosion" if kind in ["crate", "barrel"] else "hit1", 0.12, -8.0, pos)
	var roll := randf()
	if roll < 0.35:
		spawn_coin(pos, 1 + randi() % 2)
	elif roll < 0.45 and player.health < player.max_health:
		spawn_heart(pos)


func auto_aim(origin: Vector2, facing: Vector2, reach: float) -> Vector2:
	var best: Node2D = null
	var best_score := -1.0
	for t in hittable_targets(origin, reach):
		var to: Vector2 = (t.global_position + Vector2(0, -5)) - origin
		var dot := facing.dot(to.normalized())
		if dot > 0.55:
			var score := dot - to.length() / reach * 0.4
			if score > best_score:
				best_score = score
				best = t
	if best:
		return ((best.global_position + Vector2(0, -5)) - (origin + Vector2(0, -8))).normalized()
	return facing


func nearest_enemy(pos: Vector2, reach: float) -> Node2D:
	var best: Node2D = null
	var bd := reach
	for t in hittable_targets(pos, reach):
		var d := pos.distance_to(t.global_position)
		if d < bd:
			bd = d
			best = t
	return best


func spawn_projectile(d: Dictionary) -> void:
	var p := ProjectileScript.new()
	projectiles.add_child(p)
	p.setup(self, d)


func area_damage_player(center: Vector2, radius: float, amount: int) -> void:
	if player_targetable() and player.global_position.distance_to(center) <= radius and not player.airborne:
		if player.take_damage(amount, center):
			on_player_hit()


func on_player_hit() -> void:
	fx.shake(3.0, 0.18)
	environment.damage_flash = 0.6
	audio.play("hit2", 0.08, -2.0)
	hitstop(0.05)


func hitstop(duration: float) -> void:
	if _hitstop_active:
		return
	_hitstop_active = true
	Engine.time_scale = 0.08
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
	_hitstop_active = false


func flash_light(pos: Vector2, color: Color, energy: float, duration: float) -> void:
	var l := PointLight2D.new()
	l.texture = WorldScript.light_texture()
	l.color = color
	l.energy = energy
	l.texture_scale = 2.4
	l.global_position = pos
	add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "energy", 0.0, duration)
	tw.tween_callback(l.queue_free)


func emote(node: Node2D, index: int) -> void:
	var s := Sprite2D.new()
	s.texture = AnimLib.tex("ui/emote/emote%d.png" % index)
	s.position = Vector2(0, -22)
	node.add_child(s)
	s.scale = Vector2(0.2, 0.2)
	var tw := s.create_tween()
	tw.tween_property(s, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.7)
	tw.tween_property(s, "modulate:a", 0.0, 0.25)
	tw.tween_callback(s.queue_free)


func on_enemy_killed(e: Node) -> void:
	kills += 1
	e.respawn_at = Time.get_ticks_msec() / 1000.0 + 90.0
	var coins: int = int(e.cfg.get("coins", 1))
	spawn_coin(e.global_position, coins)
	if randf() < 0.18 and player.health < player.max_health:
		spawn_heart(e.global_position)
	hitstop(0.04)


func on_boss_awake(b: Node) -> void:
	active_boss = b
	hud.show_boss(b)
	hud.show_region(b.title, "guardian of the Moonseed")
	audio.play_music("boss", 0.8)
	audio.play("alert2", 0.0, -2.0)
	fx.shake(3.0, 0.4)
	emote(player, 21)


func on_boss_sleep(b: Node) -> void:
	if active_boss == b:
		active_boss = null
		hud.hide_boss()
		current_region = ""
		_update_region(true)


func on_boss_defeated(b: Node) -> void:
	defeated_bosses.append(b.boss_id)
	active_boss = null
	hud.hide_boss()
	audio.play("success3", 0.0, -1.0)
	hitstop(0.25)
	_spawn_moonseed(b.global_position + Vector2(0, -4), b.boss_id)
	for i in range(10):
		spawn_coin(b.global_position + Vector2(randf_range(-20, 20), randf_range(-10, 10)), 3)
	current_region = ""
	_update_region(true)


# ------------------------------------------------------------------ pickups
func spawn_coin(pos: Vector2, amount: int) -> void:
	for i in range(clampi(amount, 1, 6)):
		var s := AnimatedSprite2D.new()
		s.sprite_frames = AnimLib.strip_frames("res://assets/packs/ninja_adventure/items/coin2.png", 10, 10.0, true)
		s.play("play")
		s.offset = Vector2(0, -5)
		_add_pickup(s, pos, "coin", 1)


func spawn_heart(pos: Vector2) -> void:
	var s := Sprite2D.new()
	s.texture = AnimLib.tex("items/heart.png")
	s.offset = Vector2(0, -4)
	_add_pickup(s, pos, "heart", 4)


func _spawn_moonseed(pos: Vector2, id: String) -> void:
	var s := Sprite2D.new()
	s.texture = AnimLib.tex("items/seedlarge.png")
	s.offset = Vector2(0, -8)
	var l := PointLight2D.new()
	l.texture = WorldScript.light_texture()
	l.color = Color(0.8, 0.85, 1.0)
	l.energy = 1.2
	l.texture_scale = 1.4
	s.add_child(l)
	_add_pickup(s, pos, "moonseed", 1, id)


func _add_pickup(node: Node2D, pos: Vector2, kind: String, value: int, id := "") -> void:
	node.position = pos
	entities.add_child(node)
	var v := Vector2.from_angle(randf() * TAU) * randf_range(20.0, 55.0) if kind != "moonseed" else Vector2.ZERO
	pickups.append({"node": node, "kind": kind, "value": value, "vel": v, "h": 0.0, "vh": 90.0 if kind != "moonseed" else 0.0, "t": 0.0, "id": id})


func _update_pickups(delta: float) -> void:
	var pp := player.global_position
	for i in range(pickups.size() - 1, -1, -1):
		var pk: Dictionary = pickups[i]
		var n: Node2D = pk["node"]
		if not is_instance_valid(n):
			pickups.remove_at(i)
			continue
		pk["t"] += delta
		pk["vh"] -= 320.0 * delta
		pk["h"] = maxf(0.0, pk["h"] + pk["vh"] * delta)
		if pk["h"] <= 0.0 and pk["vh"] < 0.0:
			pk["vh"] = -pk["vh"] * 0.4 if absf(pk["vh"]) > 30.0 else 0.0
		pk["vel"] = (pk["vel"] as Vector2).move_toward(Vector2.ZERO, 80.0 * delta)
		n.position += pk["vel"] * delta
		var bob: float = sin(pk["t"] * 3.0) * 2.0 if pk["kind"] == "moonseed" else 0.0
		(n as Node2D).set("offset", Vector2(0, -5.0 - pk["h"] + bob) if pk["kind"] != "moonseed" else Vector2(0, -12.0 + bob))
		var d := n.global_position.distance_to(pp)
		if pk["t"] > 0.35 and d < 46.0 and pk["kind"] != "moonseed" and player_targetable():
			n.position = n.position.move_toward(pp, (160.0 + (46.0 - d) * 6.0) * delta)
		if pk["t"] > 0.3 and d < 9.0 and player_targetable():
			_collect(pk)
			n.queue_free()
			pickups.remove_at(i)
		elif pk["t"] > 40.0 and pk["kind"] != "moonseed":
			n.queue_free()
			pickups.remove_at(i)


func _collect(pk: Dictionary) -> void:
	match pk["kind"]:
		"coin":
			player.add_petalcoins(pk["value"])
			audio.play("coin", 0.1, -8.0)
		"heart":
			player.health = mini(player.max_health, player.health + int(pk["value"]))
			player.health_changed.emit()
			audio.play("heal", 0.1, -8.0)
		"moonseed":
			if not moonseeds.has(pk["id"]):
				moonseeds.append(pk["id"])
			hud.set_seed_count(moonseeds.size())
			player.pose_item(AnimLib.tex("items/seedlarge.png"), 1.6)
			hud.show_item_get("moonseed")
			audio.play("levelup1", 0.0, -1.0)
			fx.spawn("spark_circle", player.global_position + Vector2(0, -16), 0.0, 1.8, Color(0.85, 0.9, 1.0), null, true)
			environment.blight = 0.6 - moonseeds.size() * 0.12
			save_game()


# ------------------------------------------------------------------ interaction
func _update_interactables() -> void:
	var pp := player.global_position
	var best: Dictionary = {}
	var bd := 26.0
	for n in npcs:
		var d: float = n.global_position.distance_to(pp)
		if d < bd:
			bd = d
			best = {"type": "npc", "node": n, "label": "TALK"}
	for c in chests:
		if c["open"]:
			continue
		var d2: float = (c["pos"] as Vector2).distance_to(pp)
		if d2 < bd:
			bd = d2
			best = {"type": "chest", "chest": c, "label": "OPEN"}
	for w in waystones:
		var d3: float = (w["pos"] as Vector2).distance_to(pp + Vector2(0, -6))
		if d3 < bd + 4.0:
			bd = d3
			best = {"type": "waystone", "ws": w, "label": "REST"}
	if moonwell.global_position.distance_to(pp) < 44.0:
		best = {"type": "moonwell", "label": "MOONWELL"}
	_interact_target = best
	hud.set_interact_visible(not best.is_empty(), best.get("label", ""))


func _interact() -> void:
	if _interact_target.is_empty() or hud.any_menu_open():
		return
	match _interact_target["type"]:
		"npc":
			_talk(_interact_target["node"])
		"chest":
			_open_chest(_interact_target["chest"])
		"waystone":
			_rest_at(_interact_target["ws"])
		"moonwell":
			_use_moonwell()


func _talk(n: Node) -> void:
	talking_npc = n
	n.talking = true
	var face: Texture2D = AnimLib.tex("npcs/%s/faceset.png" % n.sprite_name)
	var lines := DB.dialogue(n.npc_id, moonseeds.size(), flags)
	shop_id = n.npc_id if n.is_shop else ""
	hud.start_dialogue(n.display_name, face, lines)


func on_dialogue_command(cmd: String) -> void:
	match cmd:
		"moontea":
			flags["mira_tea"] = true
			player.give_item("moontea")
			hud.show_item_get("moontea")
			audio.play("success1", 0.0, -4.0)
		"shop":
			if SHOPS.has(shop_id):
				hud.open_shop(_shop_stock())


func on_dialogue_closed() -> void:
	if talking_npc and is_instance_valid(talking_npc):
		talking_npc.talking = false
	talking_npc = null


func _shop_stock() -> Array:
	var out: Array = []
	for e in SHOPS.get(shop_id, []):
		if e.has("once") and flags.get(e["once"], false):
			continue
		out.append(e)
	return out


func can_buy(entry: Dictionary) -> bool:
	if player.petalcoins < int(entry["price"]):
		return false
	if entry["id"] == "moontea" and player.moontea_charges >= player.moontea_max and player.moontea_max >= 6:
		return false
	return true


func buy_item(entry: Dictionary) -> void:
	if not can_buy(entry):
		audio.play("cancel", 0.0, -4.0)
		return
	player.petalcoins -= int(entry["price"])
	player.give_item(entry["id"])
	if entry.has("once"):
		flags[entry["once"]] = true
	audio.play("coin", 0.0, -4.0)
	hud.show_item_get(entry["id"])
	hud.refresh_shop(_shop_stock())


func _open_chest(c: Dictionary) -> void:
	c["open"] = true
	opened_chests.append(c["id"])
	var s: Sprite2D = c["sprite"]
	s.frame = 1
	c["glow"].visible = false
	var id: String = c["item"]
	audio.play("secret2" if c["big"] else "success1", 0.0, -3.0)
	fx.spawn("spark_circle", c["pos"] + Vector2(0, -10), 0.0, 1.2, Color(1, 0.92, 0.7), null, true)
	fx.burst("spark", c["pos"] + Vector2(0, -10), 10, 60.0, Color(1, 0.9, 0.6), -20.0)
	player.give_item(id)
	player.pose_item(AnimLib.tex(DB.icon_path(id)), 1.3)
	hud.show_item_get(id)
	save_game()


func _rest_at(w: Dictionary) -> void:
	var first: bool = not discovered_waystones.has(w["id"])
	if first:
		discovered_waystones.append(w["id"])
	last_waystone = w["id"]
	player.heal_full()
	_refresh_waystones()
	fx.spawn("aura", player.global_position + Vector2(0, -8), 0.0, 1.6, Color(0.85, 0.8, 1.0), null, true)
	fx.burst("spark", w["pos"] + Vector2(0, -14), 14, 50.0, Color(0.85, 0.8, 1.0), -30.0, 1.0)
	audio.play("magic1" if not first else "secret2", 0.0, -3.0)
	hud.show_message(("Waystone awakened: %s. " % w["name"] if first else "") + "Hearts and Moontea restored. Journey saved.", 3.0)
	save_game()


func _refresh_waystones() -> void:
	for w in waystones:
		var on: bool = discovered_waystones.has(w["id"])
		w["circle"].modulate.a = 0.7 if on else 0.0
		w["light"].energy = 0.45 if on else 0.0


func _use_moonwell() -> void:
	if victory:
		hud.show_message("The Moonwell hums softly. The valley is whole again.", 3.0)
		return
	if moonseeds.size() < 4:
		hud.show_message("The Moonwell is dim. Moonseeds returned: %d / 4." % moonseeds.size(), 3.0)
		audio.play("voice5", 0.0, -8.0)
		return
	victory = true
	player.input_enabled = false
	audio.play_music("ending", 2.0)
	audio.play("levelup1", 0.0, 0.0)
	fx.shake(4.0, 0.8)
	for i in range(4):
		fx.spawn("spark_circle", moonwell.global_position + Vector2.from_angle(TAU * i / 4.0) * 22.0, 0.0, 1.4, Color(0.85, 0.9, 1.0), null, true)
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: world.ground_material.set_shader_parameter("moonwell_power", v), 0.0, 1.0, 2.5)
	tw.parallel().tween_property(environment, "blight", 0.0, 3.0)
	tw.parallel().tween_property(moonwell.get_node("Circle"), "modulate:a", 1.0, 2.0)
	tw.tween_callback(func() -> void:
		flash_light(moonwell.global_position, Color(0.85, 0.9, 1.0), 3.0, 2.0)
		hud.show_victory()
		save_game())


func set_menu_pause(paused: bool) -> void:
	get_tree().paused = paused


func quest_text() -> String:
	if victory:
		return "The Moonwell blooms. Explore freely."
	if not flags.get("met_alder", false) and moonseeds.is_empty():
		if talking_npc and talking_npc.npc_id == "alder":
			flags["met_alder"] = true
		return "Speak with Elder Alder in Hearthgrove."
	if moonseeds.size() >= 4:
		return "Return the Moonseeds to the Moonwell (north)."
	var remaining := PackedStringArray()
	for b in bosses:
		if not b.defeated:
			remaining.append(b.title.capitalize())
	return "Moonseeds %d/4. Guardians: %s" % [moonseeds.size(), ", ".join(remaining)]


func map_markers() -> Array:
	var out: Array = []
	for w in waystones:
		var wm := {"pos": w["pos"], "color": Color(0.8, 0.7, 1.0) if discovered_waystones.has(w["id"]) else Color(0.45, 0.4, 0.5)}
		if w["id"] != "hearthgrove":
			wm["label"] = w["name"].replace(" Waystone", "")
		out.append(wm)
	for b in bosses:
		if not b.defeated:
			out.append({"pos": b.home, "color": Color(1.0, 0.35, 0.35), "label": b.title.capitalize()})
	for c in chests:
		if not c["open"] and c["big"]:
			out.append({"pos": c["pos"], "color": Color(1.0, 0.85, 0.4)})
	out.append({"pos": moonwell.global_position, "color": Color(0.6, 0.85, 1.0), "label": "Moonwell"})
	out.append({"pos": Vector2(world.data["landmarks"]["hearthgrove"][0], world.data["landmarks"]["hearthgrove"][1]), "color": Color(1, 0.75, 0.5), "label": "Hearthgrove"})
	return out


func _waystone(id: String) -> Dictionary:
	for w in waystones:
		if w["id"] == id:
			return w
	return waystones[0]


# ------------------------------------------------------------------ save / load
func save_game() -> bool:
	if not game_started:
		return false
	var p := player
	return Save.write({
		"pos": [p.global_position.x, p.global_position.y],
		"heart_pieces": p.heart_pieces, "health": p.health,
		"weapons": p.weapons_owned, "weapon_index": p.weapon_index,
		"inventory": p.inventory, "equipped": p.equipped,
		"coins": p.petalcoins, "tea": p.moontea_charges, "tea_max": p.moontea_max,
		"seeds": moonseeds, "bosses": defeated_bosses, "chests": opened_chests, "flags": flags,
		"waystones": discovered_waystones, "last_waystone": last_waystone,
		"time": environment.time_of_day, "victory": victory,
	})


func load_game() -> bool:
	var d := Save.read()
	if d.is_empty():
		return false
	var p := player
	p.heart_pieces = int(d.get("heart_pieces", 0))
	p.weapons_owned.assign(d.get("weapons", ["thornblade", "bloomstaff"]))
	p.weapon_index = clampi(int(d.get("weapon_index", 0)), 0, p.weapons_owned.size() - 1)
	p.inventory.assign(d.get("inventory", ["plum_cloak"]))
	p.equipped = d.get("equipped", {"cloak": "plum_cloak"})
	p.petalcoins = int(d.get("coins", 0))
	p.moontea_max = int(d.get("tea_max", 3))
	p.recalc_stats()
	p.apply_outfit()
	var pos: Array = d.get("pos", world.data["start"])
	p.revive(Vector2(pos[0], pos[1]))
	p.health = clampi(int(d.get("health", p.max_health)), 1, p.max_health)
	p.moontea_charges = int(d.get("tea", 3))
	moonseeds = d.get("seeds", [])
	defeated_bosses = d.get("bosses", [])
	opened_chests = d.get("chests", [])
	flags = d.get("flags", {})
	discovered_waystones = d.get("waystones", ["hearthgrove"])
	last_waystone = d.get("last_waystone", "hearthgrove")
	environment.time_of_day = float(d.get("time", 0.34))
	victory = bool(d.get("victory", false))
	for c in chests:
		if opened_chests.has(c["id"]):
			c["open"] = true
			(c["sprite"] as Sprite2D).frame = 1
			c["glow"].visible = false
	for b in bosses:
		if defeated_bosses.has(b.boss_id):
			b.defeated = true
			b.visible = false
			b.collision_layer = 0
			if not moonseeds.has(b.boss_id):
				_spawn_moonseed(b.home, b.boss_id)
	environment.blight = 0.0 if victory else 0.6 - moonseeds.size() * 0.12
	world.ground_material.set_shader_parameter("moonwell_power", 1.0 if victory else 0.0)
	_refresh_waystones()
	hud.set_seed_count(moonseeds.size())
	return true
