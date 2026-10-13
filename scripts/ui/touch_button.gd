extends Control
## Round on-screen button. Draws icon, pressed state, a radial cooldown sweep
## with seconds left, a charge/label badge, "not enough focus" and "locked"
## states, a ready flash when a cooldown completes, and an edit-mode outline.

var id := ""               # layout id (stable, used for saved positions)
var action := ""           # InputMap action pressed while held ("" = custom)
var slot := -1             # art slot 0-3, or -1
var aim_mode := "tap"      # "tap" | "direction" | "point" for art buttons
var icon: Texture2D:
	set(v):
		if v != icon:
			icon = v
			queue_redraw()
var base_radius := 16.0
var radius := 16.0
var tint := Color.WHITE
var opacity := 0.9:
	set(v):
		if absf(v - opacity) > 0.001:
			opacity = v
			queue_redraw()
var pressed_now := false:
	set(v):
		pressed_now = v
		queue_redraw()
var cooldown := 0.0:
	set(v):
		if absf(v - cooldown) > 0.01:
			queue_redraw()
		if cooldown > 0.0 and v <= 0.0:
			_flash = 1.0
		cooldown = v
var cd_text := "":
	set(v):
		if v != cd_text:
			cd_text = v
			queue_redraw()
var label := "":
	set(v):
		if v != label:
			label = v
			queue_redraw()
var dimmed := false:       # e.g. not enough focus / stamina
	set(v):
		if v != dimmed:
			dimmed = v
			queue_redraw()
var empty := false:        # empty art slot: draws a "+"
	set(v):
		if v != empty:
			empty = v
			queue_redraw()
var editing := false:
	set(v):
		if v != editing:
			editing = v
			queue_redraw()
var edit_invalid := false:
	set(v):
		if v != edit_invalid:
			edit_invalid = v
			queue_redraw()
var _flash := 0.0


func set_radius(r: float) -> void:
	var c := position + Vector2(radius, radius)
	radius = r
	size = Vector2(r * 2.0, r * 2.0)
	center_at(c)


func center() -> Vector2:
	return position + Vector2(radius, radius)


func center_at(p: Vector2) -> void:
	position = p - Vector2(radius, radius)


func hit(p: Vector2) -> bool:
	# a little generous so thumbs do not miss; never larger than +6px
	return p.distance_to(center()) <= radius + minf(6.0, radius * 0.25)


func _process(delta: float) -> void:
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 3.0)
		queue_redraw()


func _draw() -> void:
	var c := Vector2(radius, radius)
	var a := opacity
	draw_circle(c, radius + 1.5, Color(0.06, 0.04, 0.1, 0.35 * a))
	var bg := Color(0.18, 0.12, 0.24, 0.62 * a) if not pressed_now else Color(tint.r * 0.6, tint.g * 0.4, tint.b * 0.6, 0.9 * a)
	draw_circle(c, radius, bg)
	var ring := Color(tint.r, tint.g, tint.b, 0.85 * a)
	if dimmed:
		ring = Color(0.45, 0.5, 0.9, 0.7 * a)
	draw_arc(c, radius, 0.0, TAU, 36, ring, 1.5 if not pressed_now else 2.5)
	if empty:
		var w := radius * 0.4
		draw_line(c - Vector2(w, 0), c + Vector2(w, 0), Color(1, 1, 1, 0.5 * a), 1.5)
		draw_line(c - Vector2(0, w), c + Vector2(0, w), Color(1, 1, 1, 0.5 * a), 1.5)
	elif icon:
		var s := minf(radius * 1.15, 24.0)
		var sz := icon.get_size()
		var k := s / maxf(sz.x, sz.y)
		var ia := 0.95 if cooldown <= 0.0 and not dimmed else 0.45
		draw_texture_rect(icon, Rect2(c - sz * k / 2.0, sz * k), false, Color(1, 1, 1, ia * maxf(a, 0.6)))
	if cooldown > 0.0:
		# darkened remaining sector (thick arc = filled sector, no triangulation)
		var a0 := -PI / 2.0
		var a1 := a0 + TAU * clampf(cooldown, 0.0, 1.0)
		var rr := (radius - 1.0) * 0.5
		draw_arc(c, rr, a0, a1, 24, Color(0.03, 0.02, 0.06, 0.55 * a), rr * 2.0)
	var f := get_theme_default_font()
	if cd_text != "" and f:
		draw_string_outline(f, c + Vector2(-radius, 4), cd_text, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, 8, 3, Color(0.05, 0.03, 0.08, a))
		draw_string(f, c + Vector2(-radius, 4), cd_text, HORIZONTAL_ALIGNMENT_CENTER, radius * 2.0, 8, Color(1, 0.95, 0.85, a))
	if label != "" and f:
		# badge (charges, slot number)
		var bp := c + Vector2(radius * 0.62, radius * 0.62)
		draw_circle(bp, 6.0, Color(0.1, 0.07, 0.14, 0.92 * a))
		draw_arc(bp, 6.0, 0.0, TAU, 16, ring, 1.0)
		draw_string(f, bp + Vector2(-6, 3), label, HORIZONTAL_ALIGNMENT_CENTER, 12, 8, Color(1, 0.95, 0.85, a))
	if _flash > 0.0:
		draw_arc(c, radius + 2.0 + (1.0 - _flash) * 5.0, 0.0, TAU, 32, Color(1, 1, 1, _flash * 0.8), 2.0)
	if editing:
		var ec := Color(1.0, 0.35, 0.35, 0.95) if edit_invalid else Color(1.0, 0.85, 0.4, 0.95)
		draw_arc(c, radius + 3.0, 0.0, TAU, 32, ec, 1.0)
