extends CharacterBody2D
## Villagers and animals. Villagers wander near home, turn toward Mallow, and can be talked to.

const AnimLib := preload("res://scripts/core/anim_lib.gd")

var game: Node
var npc_id := ""
var display_name := ""
var sprite_name := "villager"
var is_animal := false
var is_shop := false
var wander_radius := 0.0
var home := Vector2.ZERO
var target := Vector2.ZERO
var wait_t := 0.0
var dir_name := "down"
var sprite: AnimatedSprite2D
var prompt: Sprite2D
var talking := false


func setup(p_game: Node, d: Dictionary, animal := false) -> void:
	game = p_game
	is_animal = animal
	sprite_name = d.get("sprite", "villager")
	npc_id = d.get("id", sprite_name)
	display_name = d.get("name", sprite_name.capitalize())
	is_shop = d.get("shop", false)
	wander_radius = float(d.get("wander", 40 if animal else 0))
	home = Vector2(d["x"], d["y"])
	global_position = home
	target = home
	wait_t = randf_range(0.5, 2.5)


func _ready() -> void:
	collision_layer = 8
	collision_mask = 1 | 4 | 8
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 5.0
	cs.shape = shape
	cs.position = Vector2(0, -3)
	add_child(cs)
	var shadow := Sprite2D.new()
	shadow.texture = preload("res://scripts/actors/player.gd")._shadow_texture()
	shadow.modulate = Color(0.05, 0.06, 0.12, 0.33)
	shadow.scale = Vector2(0.45, 0.36)
	add_child(shadow)
	sprite = AnimatedSprite2D.new()
	var f := SpriteFrames.new()
	f.remove_animation("default")
	if is_animal:
		AnimLib.add_strip(f, "idle", AnimLib.tex("animals/%s.png" % sprite_name), 16, 3.0, true)
		sprite.offset = Vector2(0, -7)
	else:
		var base := "npcs/%s/" % sprite_name
		AnimLib.add_directional(f, "walk", AnimLib.tex(base + "walk.png"), Vector2i(16, 16), 7.0, true)
		AnimLib.add_directional(f, "idle", AnimLib.tex(base + "idle.png"), Vector2i(16, 16), 2.0, true)
		sprite.offset = Vector2(0, -7)
	sprite.sprite_frames = f
	add_child(sprite)
	sprite.play("idle" if is_animal else "idle_down")
	if not is_animal:
		prompt = Sprite2D.new()
		prompt.texture = AnimLib.tex("ui/emote/emote%d.png" % (9 if is_shop else 20))
		prompt.position = Vector2(0, -24)
		prompt.visible = false
		add_child(prompt)


func _physics_process(delta: float) -> void:
	if game == null:
		return
	var p: Node2D = game.player
	var dist := global_position.distance_to(p.global_position)
	if prompt:
		prompt.visible = dist < 28.0 and not talking
		prompt.position.y = -24.0 + sin(Time.get_ticks_msec() / 220.0) * 1.5
	var desired := Vector2.ZERO
	if talking or (not is_animal and dist < 36.0):
		dir_name = AnimLib.dir_name(p.global_position - global_position)
	elif wander_radius > 0.0:
		wait_t -= delta
		if wait_t <= 0.0:
			target = home + Vector2(randf_range(-wander_radius, wander_radius), randf_range(-wander_radius, wander_radius) * 0.6)
			wait_t = randf_range(2.5, 5.5)
		var d := target - global_position
		if d.length() > 3.0:
			desired = d.normalized() * (20.0 if is_animal else 26.0)
			dir_name = AnimLib.dir_name(d)
	velocity = desired
	move_and_slide()
	if is_animal:
		if absf(velocity.x) > 1.0:
			sprite.flip_h = velocity.x > 0.0
		return
	var anim := ("walk_" if velocity.length() > 2.0 else "idle_") + dir_name
	if sprite.animation != anim:
		sprite.play(anim)
