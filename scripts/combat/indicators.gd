extends RefCounted
## Ground indicators drawn in world space (children of the player or FX layer).
##  - AttackIndicator: the held weapon's real basic-attack shape, always visible.
##  - AimIndicator: arrow / ground circle preview while an aimable art is held.
##  - TargetMarker: bracket under the current auto/manual target.


class AttackIndicator:
	extends Node2D
	## shape "arc": sector from origin with radius `reach` and half-width `half_angle`;
	## "circle": impact circle of radius `reach` centred `offset` px ahead;
	## "line": projectile lane of length `reach`.
	var shape := "arc"
	var reach := 30.0
	var half_angle := 0.95
	var offset := 0.0
	var dir := Vector2.DOWN
	var color := Color(1.0, 0.6, 0.8)
	var opacity := 1.0
	var engaged := false  # a valid target is inside reach: brighten slightly
	var sweet := 0.0      # "ring": inner edge of the sweet-spot band (fraction of reach)
	var _t := 0.0

	func setup_from(def: Dictionary) -> void:
		shape = String(def.get("shape", "arc"))
		reach = float(def.get("reach", 30.0))
		half_angle = float(def.get("half_angle", 0.95))
		offset = float(def.get("offset", 0.0))
		sweet = float(def.get("sweet", 0.0))
		color = Color(String(def.get("color", "ffb8d8")))
		queue_redraw()

	func tick(delta: float, p_dir: Vector2, p_engaged: bool) -> void:
		_t += delta
		if p_dir.length() > 0.01:
			dir = p_dir.normalized()
		engaged = p_engaged
		queue_redraw()

	func _draw() -> void:
		var o := Vector2(0, -4)
		var base_a := (0.62 if engaged else 0.40) * opacity
		var pulse := 0.06 * sin(_t * 4.0) * opacity
		var fill := Color(color.r, color.g, color.b, (0.14 if engaged else 0.08) * opacity)
		var edge := Color(color.r, color.g, color.b, base_a + pulse)
		var shade := Color(0.12, 0.05, 0.16, 0.30 * opacity)
		match shape:
			"arc":
				var a0 := dir.angle() - half_angle
				var a1 := dir.angle() + half_angle
				var pts := PackedVector2Array([o])
				var segs := 18
				for i in range(segs + 1):
					pts.append(o + Vector2.RIGHT.rotated(lerpf(a0, a1, float(i) / segs)) * reach)
				draw_colored_polygon(pts, fill)
				draw_arc(o, reach + 0.8, a0, a1, segs, shade, 1.6)
				draw_arc(o, reach, a0, a1, segs, edge, 1.2)
				draw_line(o, o + Vector2.RIGHT.rotated(a0) * reach, Color(edge, edge.a * 0.5), 1.0)
				draw_line(o, o + Vector2.RIGHT.rotated(a1) * reach, Color(edge, edge.a * 0.5), 1.0)
			"ring":
				# 360° whip: full circle; the outer tip band (sweet spot) is brighter
				# and its inner edge dashed, so players can see where hits land harder
				draw_circle(o, reach, fill)
				var inner := reach * sweet
				var band := Color(1.0, 0.92, 0.5, (0.20 if engaged else 0.13) * opacity + pulse * 0.5)
				draw_arc(o, (reach + inner) * 0.5, 0.0, TAU, 40, band, reach - inner)
				draw_arc(o, reach + 0.8, 0.0, TAU, 40, shade, 1.6)
				draw_arc(o, reach, 0.0, TAU, 40, Color(1.0, 0.95, 0.6, edge.a), 1.2)
				var segs := 24
				for i in range(segs):
					if i % 2 == 0:
						draw_arc(o, inner, TAU * i / segs, TAU * (i + 1) / segs, 3, Color(1.0, 0.9, 0.5, edge.a * 0.8), 1.0)
			"circle":
				var c := o + dir * offset
				draw_circle(c, reach, fill)
				draw_arc(c, reach + 0.8, 0.0, TAU, 32, shade, 1.6)
				draw_arc(c, reach, 0.0, TAU, 32, edge, 1.2)
			"line":
				var end := o + dir * reach
				var side := dir.orthogonal() * 3.0
				# dashed lane with an end tick: shows real projectile range
				var n := 10
				for i in range(n):
					if i % 2 == 0:
						var k0 := float(i) / n
						var k1 := float(i + 1) / n
						draw_line(o + dir * reach * k0, o + dir * reach * k1, edge, 1.2)
				draw_line(end - side, end + side, edge, 1.4)
				draw_arc(o, 10.0, dir.angle() - 0.5, dir.angle() + 0.5, 8, Color(edge, edge.a * 0.8), 1.0)


class AimIndicator:
	extends Node2D
	## mode "direction": arrow of length `range` and width `width`;
	## "point": dotted range circle around Mallow and the impact circle at `point`.
	var mode := "direction"
	var range_px := 120.0
	var radius := 24.0
	var width := 8.0
	var aim := Vector2.RIGHT   # world-space offset from Mallow
	var color := Color(0.8, 0.9, 1.0)
	var cancelling := false

	func show_aim(p_mode: String, p_range: float, p_radius: float, p_aim: Vector2, p_color: Color, p_cancel: bool) -> void:
		mode = p_mode
		range_px = p_range
		radius = p_radius
		aim = p_aim
		color = p_color
		cancelling = p_cancel
		visible = true
		queue_redraw()

	func _draw() -> void:
		var o := Vector2(0, -4)
		var c := Color(1.0, 0.4, 0.4) if cancelling else color
		var edge := Color(c, 0.85)
		var fill := Color(c, 0.18)
		if mode == "direction":
			var d := aim.normalized() if aim.length() > 0.01 else Vector2.RIGHT
			var end := o + d * range_px
			var side := d.orthogonal() * width * 0.5
			var pts := PackedVector2Array([o + side, end + side - d * 6.0, end + side * 2.0 - d * 6.0, end, end - side * 2.0 - d * 6.0, end - side - d * 6.0, o - side])
			draw_colored_polygon(pts, fill)
			draw_polyline(pts + PackedVector2Array([pts[0]]), edge, 1.2)
		else:
			# reachable area
			var segs := 48
			for i in range(segs):
				if i % 2 == 0:
					draw_arc(o, range_px, TAU * i / segs, TAU * (i + 1) / segs, 3, Color(c, 0.45), 1.0)
			var pt := o + aim.limit_length(range_px)
			draw_circle(pt, radius, fill)
			draw_arc(pt, radius, 0.0, TAU, 32, edge, 1.4)
			draw_line(o, pt, Color(c, 0.35), 1.0)


class TargetMarker:
	extends Node2D
	## Four corner brackets around the target's feet; gold when manually locked.
	var target: Node2D
	var locked := false
	var _t := 0.0

	func _process(delta: float) -> void:
		if target == null or not is_instance_valid(target) or not target.is_inside_tree():
			visible = false
			return
		visible = true
		_t += delta
		global_position = target.global_position
		queue_redraw()

	func _draw() -> void:
		var big: bool = target != null and is_instance_valid(target) and target.get("title") != null
		var r := 18.0 if big else 9.0
		var y := -2.0
		var c := Color(1.0, 0.85, 0.35, 0.9) if locked else Color(1.0, 0.55, 0.7, 0.75)
		var s := 1.0 + 0.08 * sin(_t * 6.0)
		var w := r * s
		var h := r * 0.55 * s
		var l := 4.0
		for sx in [-1.0, 1.0]:
			for sy in [-1.0, 1.0]:
				var corner := Vector2(sx * w, y + sy * h)
				draw_line(corner, corner + Vector2(-sx * l, 0), c, 1.2)
				draw_line(corner, corner + Vector2(0, -sy * l * 0.7), c, 1.2)
