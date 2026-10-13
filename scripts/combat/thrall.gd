extends Node2D
## Bone Thrall: a grave-wisp that orbits Mallow and darts at nearby foes,
## dealing necrotic damage through the player's damage pipeline (so curses,
## crits and lifesteal all apply the same way). One thrall at a time.

const AnimLib := preload("res://scripts/core/anim_lib.gd")

var player: Node2D
var damage := 2
var life := 10.0
var bite_cd := 0.0
var _phase := 0.0
var _target: Node2D
var _dart := 0.0
var sprite: AnimatedSprite2D


func setup(p_player: Node2D, p_damage: int, p_life: float) -> void:
	player = p_player
	damage = p_damage
	life = p_life
	global_position = player.global_position + Vector2(10, -14)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = AnimLib.strip_frames("res://assets/packs/ninja_adventure/fx/spirit_blue.png", 32, 12.0, true)
	sprite.modulate = Color(0.6, 1.0, 0.75, 0.9)
	sprite.scale = Vector2(0.55, 0.55)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	sprite.material = m
	add_child(sprite)
	sprite.play("play")
	z_index = 6


func _physics_process(delta: float) -> void:
	if player == null or not is_instance_valid(player) or player.game == null:
		queue_free()
		return
	life -= delta
	bite_cd = maxf(0.0, bite_cd - delta)
	_phase += delta * 3.0
	if life <= 0.0 or player.state == player.State.DEAD:
		player.game.fx.spawn("smoke", global_position, 0.0, 0.6, Color(0.7, 1.0, 0.8))
		queue_free()
		return
	if _target != null and (not is_instance_valid(_target) or not player.is_valid_target(_target)):
		_target = null
	if _target == null and bite_cd <= 0.0:
		_target = player.game.nearest_enemy(player.global_position, 96.0)
	var goal := player.global_position + Vector2(cos(_phase) * 14.0, -16.0 + sin(_phase * 1.3) * 4.0)
	if _target != null:
		goal = _target.global_position + Vector2(0, -8)
	global_position = global_position.move_toward(goal, (190.0 if _target else 120.0) * delta)
	if _target != null and global_position.distance_to(_target.global_position + Vector2(0, -8)) < 8.0 and bite_cd <= 0.0:
		bite_cd = 0.8
		player.deal(_target, damage, {"element": "necrotic", "source": "proc", "status": {"curse": 1} if randf() < 0.35 else {}, "force": 30.0})
		player.game.fx.spawn("claw", _target.global_position + Vector2(0, -8), randf() * TAU, 0.6, Color(0.6, 1.0, 0.75), null, true)
		_target = null
