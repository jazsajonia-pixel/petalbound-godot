extends Node2D
## Cloudstride Staff afterimage: a translucent copy of Mallow left where the
## blink started. It stays put, strikes the nearest foe in reach with a weaker
## staff hit, and fades after `clone_time`. One at a time (player.clone_ref).
## It never picks up loot, opens doors, talks, or enters rifts; it is removed on
## expiry, Mallow's death, or when Mallow leaves the area (room change/teleport).

var p: Node = null
var life := 4.5
var dmg := 1
var rate := 0.55
var reach := 36.0
var hits := 0
var _cool := 0.25
var _t := 0.0
var body: Sprite2D
var staff: Sprite2D


func setup(player: Node, hold: Dictionary, damage: int) -> void:
	p = player
	dmg = damage
	life = float(hold.get("clone_time", 4.5))
	rate = float(hold.get("clone_rate", 0.55))
	reach = float(hold.get("clone_reach", 36.0))
	z_index = 0
	y_sort_enabled = false
	var spr: AnimatedSprite2D = p.sprite
	body = Sprite2D.new()
	body.texture = spr.sprite_frames.get_frame_texture(spr.animation, spr.frame)
	body.flip_h = spr.flip_h
	body.position = spr.offset + spr.position
	body.modulate = Color(1.0, 0.86, 0.55, 0.62)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	body.material = m
	add_child(body)
	var held = p.get("weapon_sprite")
	if held is Sprite2D and (held as Sprite2D).texture != null and (held as Sprite2D).visible:
		staff = Sprite2D.new()
		staff.centered = (held as Sprite2D).centered
		staff.offset = (held as Sprite2D).offset
		staff.texture = (held as Sprite2D).texture
		staff.position = (held as Sprite2D).position
		staff.rotation = (held as Sprite2D).rotation
		staff.flip_h = (held as Sprite2D).flip_h
		staff.modulate = Color(1.0, 0.9, 0.6, 0.7)
		add_child(staff)
	name = "Afterimage"


func _process(delta: float) -> void:
	if p == null or not is_instance_valid(p):
		queue_free()
		return
	_t += delta
	life -= delta
	_cool -= delta
	if life <= 0.0 or p.state == p.State.DEAD or p.global_position.distance_to(global_position) > 260.0:
		_vanish()
		return
	body.position.y = (p.sprite.offset + p.sprite.position).y + sin(_t * 4.0) * 0.6
	var a := 0.62 if life > 0.6 else 0.62 * life / 0.6
	body.modulate.a = a
	if staff:
		staff.modulate.a = a
	if _cool <= 0.0:
		_strike()


func _strike() -> void:
	var g = p.game
	if g == null:
		return
	var origin := global_position + Vector2(0, -4)
	var best: Node2D = null
	var bd := reach + 1.0
	for t in g.hittable_targets(origin, reach):
		var d: float = (t.global_position + Vector2(0, -5)).distance_to(origin)
		if d < bd and g.line_clear(origin, t.global_position + Vector2(0, -5)):
			bd = d
			best = t
	if best == null:
		_cool = 0.15
		return
	_cool = rate
	var dir := ((best.global_position + Vector2(0, -5)) - origin).normalized()
	body.flip_h = dir.x < 0.0
	p.deal(best, dmg, {"element": "", "source": "clone", "force": 50.0, "no_proc": true, "from": origin})
	hits += 1
	g.fx.spawn("slash", origin + dir * 14.0, dir.angle(), 0.8, Color(1.0, 0.85, 0.5), null, true)
	g.audio.play("slash", 0.15, -9.0, global_position)
	var tw := create_tween()
	tw.tween_property(body, "scale", Vector2(1.12, 0.92), 0.06)
	tw.tween_property(body, "scale", Vector2.ONE, 0.1)


func _vanish() -> void:
	if p and is_instance_valid(p) and p.game:
		p.game.fx.spawn("smoke", global_position + Vector2(0, -6), 0.0, 0.7, Color(1.0, 0.9, 0.7, 0.6))
	if p and is_instance_valid(p) and p.get("clone_ref") == self:
		p.clone_ref = null
	queue_free()
