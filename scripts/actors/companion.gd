extends Node2D
## Moth companion: a little light that follows Mallow, glows at night and drifts
## toward the nearest unopened chest when Mallow stands still for a moment.

const AnimLib := preload("res://scripts/core/anim_lib.gd")
const WorldScript := preload("res://scripts/world/world.gd")

var game: Node
var sprite: AnimatedSprite2D
var light: PointLight2D
var _idle_t := 0.0


func setup(p_game: Node) -> void:
	game = p_game


func _ready() -> void:
	z_index = 3
	sprite = AnimatedSprite2D.new()
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	AnimLib.add_directional(frames, "move", AnimLib.tex("monsters/butterfly.png"), Vector2i(16, 16), 10.0, true)
	sprite.sprite_frames = frames
	sprite.offset = Vector2(0, -7)
	sprite.modulate = Color(1.0, 0.93, 0.78)
	add_child(sprite)
	light = PointLight2D.new()
	light.texture = WorldScript.light_texture()
	light.color = Color(1.0, 0.9, 0.65)
	light.texture_scale = 1.1
	light.position = Vector2(0, -7)
	add_child(light)
	sprite.play("move_down")


func _process(delta: float) -> void:
	if game == null or game.player == null:
		return
	visible = game.game_started and not game.game_over
	var p: Node2D = game.player
	var target := p.global_position + Vector2(16, -24) + Vector2(sin(Time.get_ticks_msec() / 480.0) * 6.0, cos(Time.get_ticks_msec() / 380.0) * 4.0)
	if p.velocity.length() < 5.0:
		_idle_t += delta
	else:
		_idle_t = 0.0
	if _idle_t > 2.2:
		var best := target
		var bd := 480.0
		for c in game.chests:
			if c["open"]:
				continue
			var d: float = (c["pos"] as Vector2).distance_to(p.global_position)
			if d < bd:
				bd = d
				best = (c["pos"] as Vector2) + Vector2(0, -12)
		target = best
	global_position = global_position.lerp(target, clampf(delta * 3.5, 0.0, 1.0))
	var anim := "move_" + AnimLib.dir_name(global_position - p.global_position)
	if sprite.animation != anim:
		sprite.play(anim)
	light.energy = 0.4 * game.environment.darkness
