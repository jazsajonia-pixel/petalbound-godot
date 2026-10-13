extends Node2D
## A timed ground zone that calls `on_tick(zone)` every `period` seconds for
## `duration` seconds, drawn as a soft ring so its real radius is readable.
## Used by Toxic Veil (poison cloud), Bloom Ward (heal zone) and Ember Rain.

var radius := 30.0
var duration := 3.0
var period := 0.5
var color := Color(0.6, 1.0, 0.5)
var on_tick: Callable
var _t := 0.0
var _tick := 0.0


func setup(p_radius: float, p_duration: float, p_period: float, p_color: Color, p_on_tick: Callable) -> void:
	radius = p_radius
	duration = p_duration
	period = p_period
	color = p_color
	on_tick = p_on_tick
	_tick = 0.0
	z_index = -4


func _physics_process(delta: float) -> void:
	_t += delta
	_tick -= delta
	if _tick <= 0.0:
		_tick = period
		if on_tick.is_valid():
			on_tick.call(self)
	if _t >= duration:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var k := clampf(_t / duration, 0.0, 1.0)
	var fade := 1.0 - maxf(0.0, (k - 0.8) / 0.2)
	draw_circle(Vector2.ZERO, radius, Color(color, 0.16 * fade))
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 36, Color(color, 0.7 * fade), 1.3)
	# remaining-time sweep so players can read when the zone ends
	draw_arc(Vector2.ZERO, radius - 3.0, -PI / 2.0, -PI / 2.0 + TAU * (1.0 - k), 30, Color(color, 0.45 * fade), 1.0)
