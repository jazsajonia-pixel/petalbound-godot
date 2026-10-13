extends Node2D
## Lightweight projectile: moves, optionally homes, hits the opposing team or stops on solid props.

const AnimLib := preload("res://scripts/core/anim_lib.gd")
const CD := preload("res://scripts/data/combat_data.gd")
const FX := "res://assets/packs/ninja_adventure/fx/"
const KINDS := {
	"bolt": ["energy_ball.png", 16, Color(1.0, 0.75, 0.95), true],
	"energy_ball": ["energy_ball.png", 16, Color(0.75, 0.85, 1.0), true],
	"big_energy_ball": ["big_energy_ball.png", 24, Color(1, 1, 1), true],
	"fireball": ["fireball.png", 16, Color(1, 1, 1), true],
	"ice_spike": ["ice_spike.png", 18, Color(1, 1, 1), false],
	"rock_ball": ["rock_ball.png", 16, Color(1, 1, 1), false],
	"arrow": ["arrow.png", 13, Color(1, 1, 1), false],
}

var game: Node
var kind := "bolt"
var dir := Vector2.RIGHT
var speed := 200.0
var damage := 2
var team := "player"
var homing := 0.0
var life := 1.5
var pierce := false
var radius := 7.0
var hit_ids: Dictionary = {}
## Player projectiles resolve hits through this (player.deal) when provided.
var on_hit: Callable
var element := ""
var sprite: AnimatedSprite2D
var glow: PointLight2D
var _trail_t := 0.0


func setup(p_game: Node, d: Dictionary) -> void:
	game = p_game
	kind = d.get("kind", "bolt")
	position = d["pos"]
	dir = (d.get("dir", Vector2.RIGHT) as Vector2).normalized()
	speed = d.get("speed", 200.0)
	damage = d.get("damage", 2)
	team = d.get("team", "player")
	homing = d.get("homing", 0.0)
	life = d.get("life", 1.5)
	pierce = d.get("pierce", false)
	radius = d.get("radius", 7.0 if team == "player" else 6.0)
	on_hit = d.get("on_hit", Callable())
	element = d.get("element", "")
	var def: Array = KINDS.get(kind, KINDS["bolt"])
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = AnimLib.strip_frames(FX + def[0], def[1], 12.0, true)
	sprite.modulate = def[2]
	if d.get("glow", false):
		sprite.modulate = Color(0.75, 1.0, 0.85)
	if def[3]:
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		sprite.material = m
	add_child(sprite)
	sprite.play("play")
	sprite.rotation = dir.angle()
	if element != "" and team == "player" and kind == "bolt":
		sprite.modulate = CD.element_color(element)
	if def[3] or d.get("glow", false):
		glow = PointLight2D.new()
		glow.texture = preload("res://scripts/world/world.gd").light_texture()
		glow.texture_scale = 0.6
		glow.color = def[2]
		glow.energy = 0.9
		add_child(glow)
	z_index = 5


func _physics_process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		_pop(false)
		return
	if homing > 0.0 and team == "player":
		var t: Node2D = null
		var pl = game.player
		if pl != null and pl.is_valid_target(pl.current_target) and pl.current_target.global_position.distance_to(global_position) < 140.0:
			t = pl.current_target
		else:
			t = game.nearest_enemy(global_position, 120.0)
		if t:
			var want := (t.global_position + Vector2(0, -6) - global_position).normalized()
			dir = dir.lerp(want, clampf(homing * delta, 0.0, 1.0)).normalized()
	position += dir * speed * delta
	_trail_t -= delta
	if _trail_t <= 0.0 and (kind == "bolt" or kind == "fireball" or kind == "ice_spike" or kind == "energy_ball" or pierce):
		_trail_t = 0.04
		game.fx.burst("spark" if kind != "fireball" else "fire", global_position, 1, 10.0, CD.element_color(element) if element != "" else sprite.modulate, 0.0, 0.3)
	if game.world.is_solid(global_position + Vector2(0, 6)):
		_pop(true)
		return
	if team == "player":
		for e in game.hittable_targets(global_position, radius + 8.0):
			var id: int = e.get_instance_id()
			if hit_ids.has(id):
				continue
			hit_ids[id] = true
			if on_hit.is_valid():
				on_hit.call(e, global_position - dir * 8.0)
			else:
				game.damage_target(e, damage, global_position - dir * 8.0, 140.0)
			if not pierce:
				_pop(true)
				return
	else:
		var p: Node2D = game.player
		if game.player_targetable() and p.global_position.distance_to(global_position + Vector2(0, 7)) < radius + 4.0:
			if p.take_damage(damage, global_position - dir * 6.0):
				game.on_player_hit()
			_pop(true)


func _pop(impact: bool) -> void:
	if impact:
		var c := sprite.modulate
		game.fx.spawn("spark" if kind != "fireball" else "explosion", global_position, 0.0, 0.45, c, null, true)
	queue_free()
