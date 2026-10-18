extends CharacterBody2D
## Region guardian. Cycles through telegraphed attack patterns, enrages at half health
## and drops a Moonseed when defeated. Every attack shows a ground warning that
## matches its real hit area, plus a "!" over the boss while it winds up. Once
## enraged (half health) the pattern gains a close-range quake.

const AnimLib := preload("res://scripts/core/anim_lib.gd")
const DB := preload("res://scripts/data/db.gd")
const SPRITE_SHADER := preload("res://assets/shaders/sprite_fx.gdshader")

const PATTERNS := {
	"giantbamboo": ["charge", "spikes", "spread", "charge", "spikes"],
	"giantfrog": ["leap", "spread", "leap", "ring"],
	"demoncyclop": ["spread", "charge", "ring", "spikes"],
	"giantspirit": ["ring", "teleport", "spikes", "spread", "teleport"],
	"emberbark": ["spikes", "charge", "spread", "spikes", "ring"],
	"squidred": ["ring", "spread", "spikes", "ring", "charge"],
}
## Attack added to every pattern once the boss is enraged (phase two).
const ENRAGED_EXTRA := "quake"
const QUAKE_RADIUS := 64.0
const QUAKE_WIND := 1.0
const QUAKE_DAMAGE := 4
const CHARGE_SPEED := 230.0
const CHARGE_TIME := 0.75
const SPREAD_STEP := 0.28
const RING_REACH := 110.0
const SHOTS := {"giantbamboo": "rock_ball", "giantfrog": "energy_ball", "demoncyclop": "fireball", "giantspirit": "ice_spike", "emberbark": "fireball", "squidred": "energy_ball"}
const TITLES := {
	"giantbamboo": "THE BRIARBACK", "giantfrog": "THE GLASSWATER TOAD", "demoncyclop": "THE EMBER CYCLOPS", "giantspirit": "THE QUIET WARDEN",
	"emberbark": "THE EMBERBARK", "squidred": "THE BRINEHORN",
}

var game: Node
var boss_id := "briarback"
var species := "giantbamboo"
var cfg: Dictionary
var hp := 100
var max_hp := 100
var home := Vector2.ZERO
var awake := false
var defeated := false
var state := "idle"
var state_t := 1.2
var pattern_i := 0
var sprite: AnimatedSprite2D
var shadow: Sprite2D
var mat: ShaderMaterial
var charge_dir := Vector2.ZERO
var leap_from := Vector2.ZERO
var leap_to := Vector2.ZERO
var contact_cd := 0.0
var enraged := false
var title := ""
var _shots_left := 0
var _shot_t := 0.0
var _spike_points: Array = []
var _ring_off := 0.0
var _volley_dir := Vector2.DOWN
var warn: Label


func setup(p_game: Node, id: String, p_species: String, pos: Vector2) -> void:
	game = p_game
	boss_id = id
	species = p_species
	cfg = DB.BOSSES[species]
	max_hp = int(cfg["hp"])
	hp = max_hp
	home = pos
	global_position = pos
	title = TITLES.get(species, id.to_upper())


func _ready() -> void:
	collision_layer = 16
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = float(cfg["radius"]) * 0.6
	cs.shape = shape
	cs.position = Vector2(0, -4)
	add_child(cs)
	shadow = Sprite2D.new()
	shadow.texture = preload("res://scripts/actors/player.gd")._shadow_texture()
	shadow.modulate = Color(0.05, 0.06, 0.12, 0.4)
	shadow.scale = Vector2(float(cfg["radius"]) / 14.0, float(cfg["radius"]) / 20.0)
	add_child(shadow)
	sprite = AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	var fw: int = cfg["frame"]
	# variants (the Emberbark) reuse another guardian's sheet with their own tint
	var sheet: String = String(cfg.get("sheet", species))
	for a in cfg["anims"]:
		AnimLib.add_strip(frames, a, AnimLib.tex("bosses/%s/%s.png" % [sheet, a]), fw, 9.0, a in ["idle", "walk", "charge"])
	sprite.sprite_frames = frames
	var h: int = AnimLib.tex("bosses/%s/idle.png" % sheet).get_height()
	sprite.offset = Vector2(0, -h / 2.0 + 3.0)
	mat = ShaderMaterial.new()
	mat.shader = SPRITE_SHADER
	mat.set_shader_parameter("noise_tex", load("res://assets/data/noise.png"))
	sprite.material = mat
	if cfg.has("swap"):
		apply_palette(cfg["swap"])
	add_child(sprite)
	sprite.play("idle")
	sprite.animation_finished.connect(_on_anim_done)
	# wind-up warning mark above the head
	warn = Label.new()
	warn.name = "Warn"
	warn.text = "!"
	warn.add_theme_font_override("font", preload("res://scripts/ui/fonts.gd").title())
	warn.add_theme_font_size_override("font_size", 20)
	warn.add_theme_color_override("font_color", Color(1.0, 0.32, 0.25))
	warn.add_theme_color_override("font_outline_color", Color(0.12, 0.04, 0.06))
	warn.add_theme_constant_override("outline_size", 6)
	warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warn.size = Vector2(24, 26)
	warn.position = Vector2(-12, -h - 20.0)
	warn.z_index = 30
	warn.visible = false
	add_child(warn)


## Recolour a reused sheet through sprite_fx's palette swap (up to 8 colours).
func apply_palette(swap: Dictionary) -> void:
	var src: Array = []
	var dst: Array = []
	for k in swap:
		if src.size() >= 8:
			break
		src.append(Color(String(k)))
		dst.append(Color(String(swap[k])))
	while src.size() < 8:
		src.append(Color(0, 0, 0, 0))
		dst.append(Color(0, 0, 0, 0))
	mat.set_shader_parameter("swap_count", mini(swap.size(), 8))
	mat.set_shader_parameter("src_colors", PackedColorArray(src))
	mat.set_shader_parameter("dst_colors", PackedColorArray(dst))


## True while the boss is winding up an attack (the "!" mark is shown).
func is_winding() -> bool:
	return state.ends_with("_wind")


func _anim(a: String) -> void:
	if not sprite.sprite_frames.has_animation(a):
		a = "walk" if sprite.sprite_frames.has_animation("walk") and a in ["charge", "jump"] else "idle"
	if sprite.animation != a or not sprite.is_playing():
		sprite.play(a)


func _on_anim_done() -> void:
	if sprite.animation in ["hit", "attack"]:
		_anim("idle")


func _physics_process(delta: float) -> void:
	if defeated or game == null:
		return
	var p: Node2D = game.player
	var dist := global_position.distance_to(p.global_position)
	if not awake:
		if dist < 150.0 and game.player_targetable():
			awake = true
			game.on_boss_awake(self)
		return
	if not game.player_targetable() or dist > 420.0:
		if dist > 420.0:
			awake = false
			hp = max_hp
			global_position = home
			game.on_boss_sleep(self)
		return
	state_t -= delta
	contact_cd = maxf(0.0, contact_cd - delta)
	var speed := 42.0 * (1.3 if enraged else 1.0)
	var st := get_node_or_null("Status")
	if st != null:
		speed *= st.speed_mult()
	var to_p := p.global_position - global_position
	var desired := Vector2.ZERO
	match state:
		"idle":
			desired = to_p.normalized() * speed if dist > 50.0 else Vector2.ZERO
			_anim("walk" if desired != Vector2.ZERO else "idle")
			if state_t <= 0.0:
				_next_attack()
		"charge_wind":
			_tint(Color(1, 0.5, 0.3), 0.3 + sin(state_t * 30.0) * 0.2)
			if state_t <= 0.0:
				_tint(Color.WHITE, 0.0)
				state = "charging"
				state_t = CHARGE_TIME
				game.audio.play("slash5", 0.05, -2.0)
		"charging":
			desired = charge_dir * CHARGE_SPEED
			_anim("charge")
			if get_slide_collision_count() > 0 or state_t <= 0.0:
				if get_slide_collision_count() > 0:
					game.fx.shake(4.0, 0.25)
					game.fx.spawn("explosion", global_position + charge_dir * 12.0, 0.0, 1.0)
					game.audio.play("impact3", 0.05, 0.0)
				_rest(1.1)
		"leap_wind":
			_anim("charge")
			if state_t <= 0.0:
				state = "leaping"
				state_t = 0.7
				leap_from = global_position
				collision_mask = 0
				_anim("jump")
				game.audio.play("jump", 0.05, -2.0)
		"leaping":
			var k := 1.0 - clampf(state_t / 0.7, 0.0, 1.0)
			global_position = leap_from.lerp(leap_to, k)
			sprite.position.y = -sin(k * PI) * 46.0
			shadow.scale = Vector2(float(cfg["radius"]) / 14.0, float(cfg["radius"]) / 20.0) * (1.0 - sin(k * PI) * 0.4)
			if state_t <= 0.0:
				sprite.position.y = 0.0
				collision_mask = 1
				game.fx.spawn("explosion", global_position, 0.0, 1.5, Color(0.85, 0.95, 1.0))
				game.fx.burst("rock", global_position, 14, 120.0)
				game.fx.shake(6.0, 0.3)
				game.audio.play("impact3", 0.05, 0.0)
				game.area_damage_player(global_position, 40.0, 4)
				_rest(0.9)
		"volley_wind":
			_anim("idle")
			_tint(Color(1, 0.75, 0.35), 0.3 + sin(state_t * 30.0) * 0.2)
			if state_t <= 0.0:
				_tint(Color.WHITE, 0.0)
				state = "volley"
				_shot_t = 0.0
		"quake_wind":
			_anim("charge")
			_tint(Color(1, 0.3, 0.2), 0.35 + sin(state_t * 34.0) * 0.25)
			if state_t <= 0.0:
				_tint(Color.WHITE, 0.0)
				game.fx.spawn("explosion", global_position, 0.0, 2.0, Color(1.0, 0.8, 0.6))
				game.fx.burst("rock", global_position, 18, 150.0)
				game.fx.shake(6.0, 0.35)
				game.audio.play("impact3", 0.05, 0.0)
				game.area_damage_player(global_position, QUAKE_RADIUS, QUAKE_DAMAGE)
				_rest(1.0)
		"volley":
			_anim("attack" if sprite.sprite_frames.has_animation("attack") else "idle")
			_shot_t -= delta
			if _shot_t <= 0.0 and _shots_left > 0:
				_shots_left -= 1
				_shot_t = 0.32 if not enraged else 0.22
				var spread := 5 if enraged else 3
				# the first burst follows the telegraphed cone; later ones track again
				var base := _volley_dir.angle() if _shots_left == (3 if enraged else 2) else to_p.angle()
				for i in range(spread):
					var a := base + (i - (spread - 1) / 2.0) * SPREAD_STEP
					_fire(Vector2.from_angle(a), 130.0)
			if _shots_left <= 0:
				_rest(0.9)
		"ring_wind":
			_tint(Color(0.7, 0.85, 1.0), 0.3 + sin(state_t * 30.0) * 0.2)
			if state_t <= 0.0:
				_tint(Color.WHITE, 0.0)
				var n := ring_count()
				for i in range(n):
					_fire(Vector2.from_angle(_ring_off + TAU * i / n), 100.0)
				game.fx.spawn("spark_circle", global_position + Vector2(0, -16), 0.0, 2.0, Color(1, 1, 1), null, true)
				_rest(1.0)
		"spikes_wind":
			if state_t <= 0.0:
				for pt in _spike_points:
					game.fx.spawn("ice" if species == "giantspirit" else ("explosion" if species == "demoncyclop" else "spark_circle"), pt + Vector2(0, -10), 0.0, 1.0, Color.WHITE, null, species != "giantbamboo")
					game.fx.burst("rock" if species != "giantspirit" else "snow", pt, 6, 80.0)
					game.area_damage_player(pt, 22.0, 3)
				game.fx.shake(3.0, 0.2)
				game.audio.play("explosion", 0.1, -6.0)
				_rest(0.9)
		"teleport":
			if state_t <= 0.0:
				var a := randf() * TAU
				global_position = p.global_position + Vector2.from_angle(a) * 90.0
				global_position = global_position.clamp(home - Vector2(140, 110), home + Vector2(140, 110))
				game.fx.spawn("spirit", global_position + Vector2(0, -14), 0.0, 1.6, Color(0.8, 0.9, 1.0), null, true)
				modulate.a = 1.0
				_rest(0.4)
		"rest":
			_anim("idle")
			if state_t <= 0.0:
				state = "idle"
				state_t = 0.9 if not enraged else 0.5
	if warn != null:
		warn.visible = is_winding()
		if warn.visible:
			warn.scale = Vector2.ONE * (1.0 + sin(Time.get_ticks_msec() * 0.02) * 0.12)
	velocity = desired
	if state != "leaping":
		move_and_slide()
	if absf(velocity.x) > 2.0:
		sprite.flip_h = velocity.x > 0.0 if species == "giantfrog" else velocity.x < 0.0
	if contact_cd <= 0.0 and dist < float(cfg["radius"]) + 4.0 and state != "leaping":
		if p.take_damage(3, global_position):
			contact_cd = 1.0
			game.on_player_hit()


func _next_attack() -> void:
	var pat: Array = attack_pattern()
	var a: String = pat[pattern_i % pat.size()]
	pattern_i += 1
	var p: Node2D = game.player
	match a:
		"charge":
			state = "charge_wind"
			state_t = 0.75 if not enraged else 0.5
			charge_dir = (p.global_position - global_position).normalized()
			if charge_dir == Vector2.ZERO:
				charge_dir = Vector2.DOWN
			_telegraph_line()
		"leap":
			state = "leap_wind"
			state_t = 0.55
			leap_to = p.global_position
			game.fx.ring(leap_to, 40.0, 0.55 + 0.7, Color(1, 0.35, 0.3, 0.6))
		"spread":
			state = "volley_wind"
			state_t = 0.55 if not enraged else 0.4
			_shots_left = 4 if enraged else 3
			_volley_dir = (p.global_position - global_position).normalized()
			if _volley_dir == Vector2.ZERO:
				_volley_dir = Vector2.DOWN
			var spread := 5 if enraged else 3
			game.fx.cone(global_position + Vector2(0, -6), _volley_dir, SPREAD_STEP * (spread - 1) / 2.0 + 0.12, 150.0, state_t, Color(1, 0.6, 0.3, 0.6))
		"ring":
			state = "ring_wind"
			state_t = 0.7
			_ring_off = randf() * TAU
			game.fx.spokes(global_position + Vector2(0, -6), ring_count(), _ring_off, RING_REACH, state_t, Color(0.6, 0.8, 1.0, 0.7))
		"quake":
			state = "quake_wind"
			state_t = QUAKE_WIND
			game.fx.ring(global_position, QUAKE_RADIUS, QUAKE_WIND, Color(1, 0.3, 0.2, 0.7))
			game.audio.play("alert2", 0.05, -6.0)
		"spikes":
			state = "spikes_wind"
			state_t = 0.9 if not enraged else 0.7
			_spike_points.clear()
			_spike_points.append(p.global_position)
			for i in range(4 if enraged else 3):
				_spike_points.append(p.global_position + Vector2.from_angle(randf() * TAU) * randf_range(26, 60))
			for pt in _spike_points:
				game.fx.ring(pt, 22.0, state_t, Color(1, 0.4, 0.3, 0.65))
		"teleport":
			state = "teleport"
			state_t = 0.5
			game.fx.spawn("smoke", global_position + Vector2(0, -14), 0.0, 1.4)
			modulate.a = 0.25


## The current attack cycle; phase two adds the quake.
func attack_pattern() -> Array:
	var pat: Array = (PATTERNS.get(species, PATTERNS["giantbamboo"]) as Array).duplicate()
	if enraged:
		pat.append(ENRAGED_EXTRA)
	return pat


func ring_count() -> int:
	return 16 if enraged else 12


## Charge lane: as long as the dash travels and as wide as its contact reach.
func charge_lane_length() -> float:
	return CHARGE_SPEED * CHARGE_TIME + float(cfg["radius"])


func charge_lane_width() -> float:
	return (float(cfg["radius"]) + 4.0) * 2.0


func _telegraph_line() -> void:
	game.fx.lane(global_position, charge_dir, charge_lane_length(), charge_lane_width(), state_t, Color(1, 0.4, 0.3, 0.6))


func _fire(dir: Vector2, speed: float) -> void:
	game.spawn_projectile({"kind": SHOTS.get(species, "rock_ball"), "pos": global_position + Vector2(0, -14), "dir": dir, "speed": speed, "damage": 3, "team": "enemy", "life": 3.0, "radius": 7.0})


func _rest(t: float) -> void:
	state = "rest"
	state_t = t


func _tint(c: Color, amount: float) -> void:
	mat.set_shader_parameter("tint_color", c)
	mat.set_shader_parameter("tint_amount", amount)


func hurt(amount: int, _from: Vector2, _force: float, info: Dictionary = {}) -> bool:
	if defeated or not awake:
		return false
	hp = maxi(0, hp - amount)
	mat.set_shader_parameter("flash", 1.0)
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("flash", v), 1.0, 0.0, 0.16)
	game.fx.damage_number(global_position + Vector2(0, -24), amount, info.get("color", Color("ffd27a")), bool(info.get("crit", false)), String(info.get("source", "")) == "dot")
	game.fx.spawn("cut", global_position + Vector2(randf_range(-8, 8), -14), randf() * TAU, 0.8, Color.WHITE, null, true)
	game.audio.play("hit2", 0.1, -3.0)
	if sprite.sprite_frames.has_animation("hit") and state in ["idle", "rest"]:
		sprite.play("hit")
	if not enraged and hp <= max_hp / 2:
		enraged = true
		game.fx.spawn("aura", global_position + Vector2(0, -14), 0.0, 2.6, Color(1, 0.4, 0.4), null, true)
		game.audio.play("alert2", 0.0, -2.0)
		game.fx.shake(3.0, 0.3)
		if game.get("hud") != null and game.hud.has_method("show_message"):
			game.hud.show_message("%s is enraged! Watch for the quake." % title.capitalize(), 2.6)
	if hp <= 0:
		_defeat()
	return true


func _boom() -> void:
	game.fx.spawn("explosion", global_position + Vector2(randf_range(-18, 18), randf_range(-26, 0)), 0.0, 1.0)
	game.audio.play("explosion", 0.15, -6.0)


func _defeat() -> void:
	defeated = true
	if warn != null:
		warn.visible = false
	collision_layer = 0
	collision_mask = 0
	_anim("hit")
	game.fx.shake(8.0, 0.6)
	for i in range(5):
		get_tree().create_timer(i * 0.18, false).timeout.connect(_boom)
	var tw := create_tween()
	tw.tween_interval(0.5)
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter("dissolve", v), 0.0, 1.0, 0.9)
	tw.tween_callback(func() -> void: visible = false)
	game.on_boss_defeated(self)
