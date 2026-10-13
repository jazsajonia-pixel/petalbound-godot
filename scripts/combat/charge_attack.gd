extends RefCounted
## Hold-to-charge basic attacks.
##
## Weapons with a "hold" dict in CD.WEAPONS charge while the attack input is held:
##  - the press itself still fires a normal basic attack (tap-spam keeps working),
##  - after CD.BALANCE.charge_tap seconds the charge starts (no hold-to-repeat),
##  - releasing at full charge fires the special (scripts/combat/weapon_specials.gd),
##  - releasing early does nothing extra (the press already attacked),
##  - releasing after dragging off the attack button cancels.
## Aim = movement stick direction, else the facing. Never the auto-target.
## Charge cancels on weapon switch, menus/teleports (input disabled), hurt/stun,
## roll/jump, swimming and death.

const CD := preload("res://scripts/data/combat_data.gd")
const Specials := preload("res://scripts/combat/weapon_specials.gd")

var p: Node = null
var held_t := -1.0          # seconds held; -1 = not tracking a press
var charging := false
var hold: Dictionary = {}
var weapon_id := ""
var off_button := false     # set by the HUD while the finger is outside the attack button
var special_cd := 0.0
var last_release := ""      # "special" | "early" | "cancel" (read by tests/HUD)
var _full_fx := false
var _last_tick_ms := 0
var view: Node2D = null


func setup(player: Node) -> void:
	p = player
	view = ChargeView.new()
	view.ctl = self
	view.z_index = 6
	view.name = "ChargeView"
	p.add_child(view)


func active() -> bool:
	return held_t >= 0.0


func tap_time() -> float:
	return float(CD.BALANCE.get("charge_tap", 0.2))


func full_time() -> float:
	return maxf(tap_time() + 0.05, float(hold.get("time", 0.7)))


func progress() -> float:
	if not charging:
		return 0.0
	return clampf((held_t - tap_time()) / maxf(0.01, full_time() - tap_time()), 0.0, 1.0)


func is_full() -> bool:
	return charging and held_t >= full_time()


func kind() -> String:
	return String(hold.get("kind", ""))


## Called on attack just-pressed while holding a hold-capable weapon.
func press(id: String, hold_def: Dictionary) -> void:
	weapon_id = id
	hold = hold_def
	held_t = 0.0
	charging = false
	off_button = false
	_full_fx = false
	_last_tick_ms = Time.get_ticks_msec()


func aim_dir() -> Vector2:
	var inp: Vector2 = p.move_intent()
	if inp.length() > p.INTENT_DEADZONE:
		return inp.normalized()
	return p.facing if p.facing.length() > 0.01 else Vector2.DOWN


func cancel_reason() -> String:
	if p.state == p.State.DEAD:
		return "dead"
	if not p.input_enabled or (p.game != null and p.game.hud != null and p.game.hud.any_menu_open()):
		return "input"
	if p.state in [p.State.HURT, p.State.ROLL, p.State.JUMP, p.State.POSE]:
		return "busy"
	if p.swimming:
		return "water"
	if p.get_weapon_id() != weapon_id:
		return "switch"
	return ""


## pressed = whether the attack input is still held this frame.
func tick(delta: float, pressed: bool) -> void:
	special_cd = maxf(0.0, special_cd - delta)
	var now := Time.get_ticks_msec()
	var gap := now - _last_tick_ms
	_last_tick_ms = now
	if held_t < 0.0:
		return
	# the game was paused (bag, map, pause menu) since the last tick: never fire late
	if gap > 250 and held_t > 0.0:
		cancel()
		return
	if cancel_reason() != "":
		cancel()
		return
	if not pressed:
		release()
		return
	held_t += delta
	if not charging and held_t >= tap_time() and special_cd <= 0.0:
		charging = true
	if is_full() and not _full_fx:
		_full_fx = true
		if p.game:
			p.game.audio.play("menu3", 0.02, -4.0, p.global_position)
			p.game.fx.spawn("sparkle", p.global_position + Vector2(0, -30), 0.0, 0.9)


func release() -> void:
	var full := is_full()
	var was := charging
	var off := off_button
	var dir := aim_dir()
	var h := hold
	_reset()
	if was and off:
		last_release = "cancel"
		return
	if full:
		last_release = "special"
		special_cd = float(h.get("cd", 1.0))
		p._set_facing(dir)
		Specials.release(p, h, dir)
	else:
		last_release = "early"


func cancel() -> void:
	if held_t >= 0.0:
		last_release = "cancel"
	_reset()


func _reset() -> void:
	held_t = -1.0
	charging = false
	off_button = false
	_full_fx = false


## Charge arc over Mallow's head + live ground preview in the aim direction.
class ChargeView extends Node2D:
	var ctl = null
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		if ctl == null or not ctl.charging:
			return
		var pr: float = ctl.progress()
		var full: bool = ctl.is_full()
		var cancel: bool = ctl.off_button
		var col := Color(1.0, 0.92, 0.6) if not full else Color(1, 1, 1)
		if cancel:
			col = Color(1.0, 0.35, 0.35)
		# --- arc over the head
		var c := Vector2(0, -31)
		draw_arc(c, 5.5, 0.0, TAU, 20, Color(0.1, 0.08, 0.14, 0.75), 3.0)
		draw_arc(c, 5.5, -PI / 2.0, -PI / 2.0 + TAU * pr, 20, col, 2.0)
		if full and not cancel:
			var pulse := 0.5 + 0.5 * sin(_t * 14.0)
			draw_arc(c, 7.5 + pulse, 0.0, TAU, 20, Color(1, 0.95, 0.7, 0.55 + 0.4 * pulse), 1.0)
			draw_circle(c, 1.6, Color(1, 1, 1))
		# --- ground preview (relative to Mallow's feet)
		var p: Node = ctl.p
		var dir: Vector2 = ctl.aim_dir()
		var a := 0.22 + 0.25 * pr
		var gc := Color(col.r, col.g, col.b, a)
		var line := Color(col.r, col.g, col.b, 0.55 + 0.35 * pr)
		var h: Dictionary = ctl.hold
		var o := Vector2(0, -4)
		match ctl.kind():
			"afterimage":
				var land: Vector2 = ctl.Specials.blink_point(p, dir, float(h.get("dist", 72.0))) - p.global_position
				_dashed(o, land + o, line)
				draw_arc(land, 6.0, 0.0, TAU, 16, line, 1.5)
				draw_circle(land, 4.0, gc)
				draw_arc(Vector2.ZERO, 7.0, 0.0, TAU, 16, Color(0.6, 0.85, 1.0, 0.5), 1.0)  # clone spot
			"moonrend":
				var ln: float = ctl.Specials.dash_length(p, dir, float(h.get("dist", 100.0)))
				_lane(o, dir, ln, float(h.get("width", 14.0)), gc, line)
			"burst":
				var cc: Vector2 = dir * float(h.get("ahead", 16.0)) + o
				var r := float(h.get("radius", 30.0))
				draw_circle(cc, r, gc)
				draw_arc(cc, r, 0.0, TAU, 28, line, 1.5)
			"wide_lash":
				var w: Dictionary = p.weapon_def()
				var r2: float = float(w.get("reach", 46.0)) * float(h.get("size_mult", 1.45))
				draw_arc(o, r2, 0.0, TAU, 40, line, 1.5)
				draw_arc(o, r2 * float(w.get("sweet", 0.72)), 0.0, TAU, 40, Color(line.r, line.g, line.b, 0.35), 1.0)
				draw_arc(o, r2 * (1.0 + float(w.get("sweet", 0.72))) * 0.5, 0.0, TAU, 40, gc, r2 * (1.0 - float(w.get("sweet", 0.72))))
			"overcharge":
				var reach: float = float(p.weapon_def().get("reach", 200.0))
				_lane(o, dir, reach, 6.0 + 10.0 * pr, Color(gc.r, gc.g, gc.b, a * 0.6), line)
				draw_circle(o + dir * 18.0, 3.0 + 5.0 * pr, Color(0.75, 0.8, 1.0, 0.8))
			"barrage":
				var rr := float(h.get("reach", 44.0))
				var ha := float(h.get("half_angle", 0.6))
				var pts := PackedVector2Array([o])
				for i in range(13):
					pts.append(o + dir.rotated(-ha + 2.0 * ha * float(i) / 12.0) * rr)
				draw_colored_polygon(pts, gc)
				pts.append(o)
				draw_polyline(pts, line, 1.2)

	func _lane(o: Vector2, dir: Vector2, length: float, width: float, fill: Color, edge: Color) -> void:
		var n := dir.orthogonal() * width * 0.5
		var e := o + dir * length
		draw_colored_polygon(PackedVector2Array([o + n, e + n, e - n, o - n]), fill)
		draw_polyline(PackedVector2Array([o + n, e + n, e - n, o - n, o + n]), edge, 1.2)

	func _dashed(a: Vector2, b: Vector2, col: Color) -> void:
		var l := a.distance_to(b)
		if l < 1.0:
			return
		var d := (b - a) / l
		var s := 0.0
		while s < l:
			draw_line(a + d * s, a + d * minf(l, s + 4.0), col, 1.5)
			s += 7.0
