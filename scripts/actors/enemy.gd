extends CharacterBody2D
## Field monster with five behaviours (hopper, chaser, flyer, caster, charger), readable
## wind-up tells, knockback, hit flash and a dissolve death that drops loot.

const AnimLib := preload("res://scripts/core/anim_lib.gd")
const DB := preload("res://scripts/data/db.gd")
const SPRITE_SHADER := preload("res://assets/shaders/sprite_fx.gdshader")

var game: Node
var species := "slime"
var cfg: Dictionary = {}
var hp := 4
var max_hp := 4
var home := Vector2.ZERO
var ai := "chaser"
var state := "idle"
var state_t := 0.0
var dir_name := "down"
var sprite: AnimatedSprite2D
var shadow: Sprite2D
var mat: ShaderMaterial
var knock := Vector2.ZERO
var alive := true
var aggro := false
var attack_cooldown := 0.0
var wander_target := Vector2.ZERO
var charge_dir := Vector2.ZERO
var fly_phase := 0.0
var hop_h := 0.0
var respawn_at := -1.0
var hp_bar_t := 0.0

var health: int:
	get:
		return hp
	set(value):
		hp = value


func setup(p_game: Node, p_species: String, pos: Vector2) -> void:
	game = p_game
	species = p_species
	cfg = DB.ENEMIES.get(species, DB.ENEMIES["slime"])
	ai = cfg["ai"]
	max_hp = int(cfg["hp"])
	hp = max_hp
	home = pos
	global_position = pos
	fly_phase = randf() * TAU
	state_t = randf_range(0.2, 1.4)


func _ready() -> void:
	collision_layer = 16
	collision_mask = 0 if ai == "flyer" else 1 | 4
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 5.0
	cs.shape = shape
	cs.position = Vector2(0, -3)
	add_child(cs)
	shadow = Sprite2D.new()
	shadow.texture = preload("res://scripts/actors/player.gd")._shadow_texture()
	shadow.modulate = Color(0.05, 0.06, 0.12, 0.35)
	shadow.scale = Vector2(0.45, 0.36)
	add_child(shadow)
	sprite = AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	AnimLib.add_directional(frames, "move", AnimLib.tex("monsters/%s.png" % species), Vector2i(16, 16), float(cfg.get("fps", 8.0)), true)
	sprite.sprite_frames = frames
	sprite.offset = Vector2(0, -7)
	mat = ShaderMaterial.new()
	mat.shader = SPRITE_SHADER
	mat.set_shader_parameter("noise_tex", load("res://assets/data/noise.png"))
	sprite.material = mat
	add_child(sprite)
	sprite.play("move_down")
	if ai == "flyer":
		sprite.position.y = -9.0


func _physics_process(delta: float) -> void:
	if not alive or game == null:
		return
	state_t -= delta
	attack_cooldown = maxf(0.0, attack_cooldown - delta)
	hp_bar_t = maxf(0.0, hp_bar_t - delta)
	var player: Node2D = game.player
	var to_player: Vector2 = player.global_position - global_position
	var dist := to_player.length()
	var player_ok: bool = game.player_targetable()
	if player_ok and dist < float(cfg["sight"]):
		if not aggro:
			aggro = true
			if state in ["idle", "wander"]:
				_emote()
	elif aggro and (dist > float(cfg["sight"]) * 2.0 or not player_ok or global_position.distance_to(home) > 300.0):
		aggro = false
		state = "wander"
	var desired := Vector2.ZERO
	var speed: float = cfg["speed"]
	match state:
		"stagger":
			if state_t <= 0.0:
				state = "chase" if aggro else "wander"
		"windup":
			_tell(delta)
			if state_t <= 0.0:
				_release_attack(to_player)
		"lunge":
			desired = charge_dir * speed * (5.0 if ai == "charger" else 3.6)
			if state_t <= 0.0:
				state = "recover"
				state_t = 0.55 if ai == "charger" else 0.35
		"recover":
			if state_t <= 0.0:
				state = "chase" if aggro else "wander"
		_:
			if aggro:
				desired = _chase(to_player, dist, speed, delta)
			else:
				desired = _wander(speed)
	if ai == "flyer":
		fly_phase += delta * 3.0
		sprite.position.y = -9.0 + sin(fly_phase * 1.3) * 2.5
	elif ai == "hopper":
		sprite.position.y = -hop_h
	velocity = velocity.move_toward(desired, 600.0 * delta) + knock
	knock = knock.move_toward(Vector2.ZERO, 900.0 * delta)
	move_and_slide()
	if ai == "flyer":
		global_position = global_position.clamp(Vector2(24, 24), game.world.world_size - Vector2(24, 24))
	if ai == "charger" and state == "lunge" and get_slide_collision_count() > 0:
		state = "stagger"
		state_t = 0.8
		game.fx.spawn("thunder", global_position + Vector2(0, -16), 0.0, 0.6)
		game.fx.shake(1.5, 0.1)
	if velocity.length() > 4.0:
		dir_name = AnimLib.dir_name(velocity)
	var anim := "move_" + dir_name
	if sprite.animation != anim:
		sprite.play(anim)
	sprite.speed_scale = 0.4 if velocity.length() < 4.0 and ai != "flyer" else 1.0
	# contact damage
	if player_ok and dist < 11.0 and state != "stagger" and attack_cooldown <= 0.0:
		if player.take_damage(int(cfg["dmg"]), global_position):
			attack_cooldown = 0.8
			game.on_player_hit()


func _wander(speed: float) -> Vector2:
	if state != "wander" and state != "idle":
		state = "idle"
	if state_t <= 0.0:
		if state == "idle":
			state = "wander"
			wander_target = home + Vector2(randf_range(-56, 56), randf_range(-40, 40))
			state_t = randf_range(1.2, 2.6)
		else:
			state = "idle"
			state_t = randf_range(0.8, 2.2)
	if state == "wander":
		var d := wander_target - global_position
		if d.length() > 4.0:
			if ai == "hopper":
				return _hop(d.normalized(), speed * 0.8)
			return d.normalized() * speed * 0.45
	hop_h = maxf(0.0, hop_h - 0.6)
	return Vector2.ZERO


func _chase(to_player: Vector2, dist: float, speed: float, _delta: float) -> Vector2:
	var dir := to_player / maxf(dist, 0.001)
	match ai:
		"hopper":
			return _hop(dir, speed * 1.6)
		"chaser":
			if dist < 30.0 and attack_cooldown <= 0.0:
				_start_windup(0.38, dir)
				return Vector2.ZERO
			return dir * speed
		"flyer":
			var side := Vector2(-dir.y, dir.x) * sin(fly_phase) * 0.8
			if dist < 46.0 and attack_cooldown <= 0.0:
				_start_windup(0.32, dir)
				return Vector2.ZERO
			return (dir + side).normalized() * speed
		"caster":
			if attack_cooldown <= 0.0 and dist < 165.0:
				_start_windup(0.55, dir)
				return Vector2.ZERO
			if dist < 70.0:
				return -dir * speed
			if dist > 120.0:
				return dir * speed
			return Vector2(-dir.y, dir.x) * speed * 0.6 * signf(sin(fly_phase + float(get_instance_id() % 7)))
		"charger":
			if attack_cooldown <= 0.0 and dist < 120.0:
				_start_windup(0.6, dir)
				return Vector2.ZERO
			return dir * speed * 0.7
	return dir * speed


func _hop(dir: Vector2, speed: float) -> Vector2:
	# hop cycle: crouch, leap, land
	var cycle := fmod(Time.get_ticks_msec() / 1000.0 + float(get_instance_id() % 97) * 0.13, 1.0)
	if cycle < 0.45:
		hop_h = sin(cycle / 0.45 * PI) * 6.0
		return dir * speed * 1.6
	hop_h = 0.0
	return Vector2.ZERO


func _start_windup(t: float, dir: Vector2) -> void:
	state = "windup"
	state_t = t
	charge_dir = dir
	if ai == "charger" or ai == "chaser":
		game.fx.ring(global_position + dir * 22.0, 12.0, t, Color(1.0, 0.45, 0.3, 0.55))


func _tell(_delta: float) -> void:
	var k := sin(state_t * 40.0) * 0.5 + 0.5
	mat.set_shader_parameter("tint_color", Color(1.0, 0.55, 0.35) if ai != "caster" else Color(0.7, 0.85, 1.0))
	mat.set_shader_parameter("tint_amount", 0.35 + k * 0.35)
	sprite.position.x = sin(state_t * 70.0) * 0.8


func _release_attack(to_player: Vector2) -> void:
	mat.set_shader_parameter("tint_amount", 0.0)
	sprite.position.x = 0.0
	attack_cooldown = 1.6 if ai != "caster" else 2.4
	if ai == "caster":
		var dir := to_player.normalized()
		var shot: String = cfg.get("shot", "energy_ball")
		game.spawn_projectile({"kind": shot, "pos": global_position + Vector2(0, -8), "dir": dir, "speed": 120.0, "damage": int(cfg["dmg"]), "team": "enemy", "life": 2.2})
		game.audio.play("fireball" if shot == "fireball" else "magic1", 0.1, -8.0, global_position)
		state = "recover"
		state_t = 0.4
	else:
		charge_dir = to_player.normalized() if ai != "charger" else charge_dir
		state = "lunge"
		state_t = 0.45 if ai == "charger" else 0.2
		game.audio.play("slash5" if ai == "charger" else "voice3", 0.15, -12.0, global_position)


func _emote() -> void:
	if game:
		game.emote(self, 17)


func hurt(amount: int, from: Vector2, force: float) -> bool:
	if not alive:
		return false
	hp -= amount
	hp_bar_t = 2.5
	aggro = true
	var away := (global_position - from)
	if away.length() < 0.1:
		away = Vector2.RIGHT.rotated(randf() * TAU)
	knock = away.normalized() * force
	mat.set_shader_parameter("tint_amount", 0.0)
	mat.set_shader_parameter("flash", 1.0)
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("flash", v), 1.0, 0.0, 0.18)
	game.fx.number(global_position + Vector2(0, -6), str(amount), Color("ffe08a") if amount < 4 else Color("ff9a6b"), amount >= 4)
	game.fx.spawn("cut", global_position + Vector2(0, -7), randf() * TAU, 0.55, Color(1, 1, 1, 0.9), null, true)
	game.audio.play("hit1" if amount < 4 else "hit5", 0.12, -4.0, global_position)
	if hp <= 0:
		die()
	elif state != "lunge":
		state = "stagger"
		state_t = 0.22
	return true


func die() -> void:
	alive = false
	hp = 0
	collision_layer = 0
	collision_mask = 0
	velocity = Vector2.ZERO
	game.on_enemy_killed(self)
	game.fx.spawn("smoke", global_position + Vector2(0, -6), 0.0, 0.8, Color(0.95, 0.9, 1.0))
	game.fx.burst("spark", global_position + Vector2(0, -6), 8, 70.0, Color(1, 0.9, 0.8), 40.0, 0.5)
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("dissolve", v), 0.0, 1.0, 0.4)
	tw.tween_callback(func() -> void: visible = false)


func respawn() -> void:
	alive = true
	visible = true
	hp = max_hp
	aggro = false
	state = "idle"
	global_position = home
	collision_layer = 16
	collision_mask = 0 if ai == "flyer" else 1 | 4
	mat.set_shader_parameter("dissolve", 0.0)
	mat.set_shader_parameter("flash", 0.0)
	modulate = Color(1, 1, 1, 0)
	create_tween().tween_property(self, "modulate:a", 1.0, 0.6)
