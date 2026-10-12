extends Node
## Fishing minigame: cast into water, wait for a bite, then hook it inside the window.

const AnimLib := preload("res://scripts/core/anim_lib.gd")
const DB := preload("res://scripts/data/db.gd")

const BITE_MIN := 0.9
const BITE_MAX := 2.4
const HOOK_WINDOW := 0.65

var game: Node
var active := false
var _state := "wait"
var _t := 0.0
var _bite_at := 1.5
var _pos := Vector2.ZERO
var _cast_from := Vector2.ZERO
var _ripple_t := 0.0
var _bobber: Sprite2D = null


func start(p_game: Node, pos: Vector2) -> bool:
	var p = p_game.player
	if active or p.swimming or p.state != p.State.MOVE or p.health <= 0:
		return false
	if not p_game.world.is_water(pos):
		return false
	game = p_game
	active = true
	_state = "wait"
	_t = 0.0
	_ripple_t = 0.0
	_bite_at = randf_range(BITE_MIN, BITE_MAX)
	_pos = pos
	_cast_from = p.global_position
	p.fishing = true
	p.velocity = Vector2.ZERO
	p.sprite.play("idle_" + p.dir_name)
	_bobber = Sprite2D.new()
	_bobber.texture = AnimLib.tex("items/goldcoin.png")
	_bobber.scale = Vector2(0.55, 0.55)
	_bobber.z_index = -3
	_bobber.position = pos + Vector2(0, -2)
	game.fx.add_child(_bobber)
	game.fx.spawn("ripple", pos, 0.0, 1.2)
	game.hud.show_message("You cast the line... watch the water.", 2.5)
	return true


func cancel(message := "") -> void:
	_end(false, message)


func _process(delta: float) -> void:
	if not active or game == null or game.player == null:
		return
	var p: Node = game.player
	_t += delta
	if p.state != p.State.MOVE or p.swimming or p.health <= 0 or p.global_position.distance_to(_cast_from) > 14.0:
		_end(false, "You reel the line back in.")
		return
	match _state:
		"wait":
			_ripple_t -= delta
			if _ripple_t <= 0.0:
				_ripple_t = 0.85
				game.fx.spawn("ripple", _pos, 0.0, 0.9, Color(1, 1, 1, 0.7))
			if _bobber:
				_bobber.position.y = _pos.y - 2.0 + sin(_t * 3.0) * 1.0
			if _t >= _bite_at:
				_state = "bite"
				_t = 0.0
				game.audio.play("alert2", 0.0, -2.0, _pos)
				game.fx.number(_pos + Vector2(0, -14), "!", Color("ffe9a8"), true)
				game.fx.burst("spark", _pos + Vector2(0, -3), 8, 70.0, Color(0.85, 0.95, 1.0), -40.0)
				game.hud.show_message("! ! !  A bite!  ATTACK to hook it!", 1.2)
		"bite":
			if _bobber:
				_bobber.position = _pos + Vector2(randf_range(-1.5, 1.5), -2.0 + randf_range(-2.0, 0.0))
			if Input.is_action_just_pressed("attack") or Input.is_action_just_pressed("interact"):
				_hook()
			elif _t > HOOK_WINDOW:
				_end(false, "It got away...")


func _hook() -> void:
	_end(true)


func _end(caught: bool, message := "") -> void:
	if not active:
		return
	active = false
	if is_instance_valid(_bobber):
		_bobber.queue_free()
	_bobber = null
	var p: Node = game.player
	p.fishing = false
	if not caught:
		if message != "":
			game.hud.show_message(message, 2.0)
		game.audio.play("water1", 0.1, -8.0, _pos)
		return
	var def := _pick_species()
	var tint := Color(String(def["tint"]))
	game.fx.spawn("slash_circular", _pos, 0.0, 0.8, tint, null, true)
	game.fx.burst("spark", _pos + Vector2(0, -6), 12, 100.0, tint, -60.0)
	game.fx.spawn("ripple", _pos, 0.0, 1.4)
	game.audio.play("success1", 0.05, -3.0, _pos)
	game.on_fish_caught(String(def["id"]), int(def["coins"]))


func _pick_species() -> Dictionary:
	var night: bool = game.environment.is_night()
	var ids: Array = []
	var weights: Array = []
	for id in DB.FISH:
		var def: Dictionary = DB.FISH[id]
		if bool(def["night"]) and not night:
			continue
		var biome := int(def["biome"])
		if biome >= 0 and biome != int(game.current_biome):
			continue
		ids.append(id)
		weights.append(float(def["weight"]))
	if ids.is_empty():
		return DB.FISH["dewfin"]
	var total := 0.0
	for w in weights:
		total += w
	var roll := randf() * total
	for i in range(ids.size()):
		roll -= float(weights[i])
		if roll <= 0.0:
			return DB.FISH[ids[i]]
	return DB.FISH[ids[0]]
