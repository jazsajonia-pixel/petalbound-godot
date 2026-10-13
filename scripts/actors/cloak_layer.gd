extends Node2D
## Pixel cape drawn on Mallow when a cloak is equipped. The Ninja Adventure hero
## sheet has no cape frames, so the cape is drawn procedurally at the sheet's
## 1:1 pixel scale: behind the body when facing down/left/right (only the edges
## and hem peek out) and over the back when facing up. Colours come from the
## cloak item's "look" triple (main, shade, outline), falling back to its tint.

const DEFAULT_LOOK := ["9a6ac0", "6a4590", "2a1838"]

var item_id := ""
var dir := "down"
var moving := false
var step := 0
var main_col := Color("9a6ac0")
var shade_col := Color("6a4590")
var line_col := Color("2a1838")


## Wear (or remove, with "") a cloak item. Returns true if a cape is now shown.
func set_item(id: String, items: Dictionary) -> bool:
	item_id = id
	var it: Dictionary = items.get(id, {})
	if id == "" or it.is_empty() or String(it.get("type", "")) != "cloak":
		item_id = ""
		visible = false
		return false
	var look: Array = it.get("look", [])
	if look.size() < 3:
		var base := Color(String(it.get("tint", DEFAULT_LOOK[0])))
		look = [base.to_html(false), base.darkened(0.3).to_html(false), base.darkened(0.75).to_html(false)]
	main_col = Color(String(look[0]))
	shade_col = Color(String(look[1]))
	line_col = Color(String(look[2]))
	visible = true
	queue_redraw()
	return true


func is_worn() -> bool:
	return item_id != ""


func set_pose(p_dir: String, p_moving: bool, p_step: int) -> void:
	if p_dir == dir and p_moving == moving and p_step == step:
		return
	dir = p_dir
	moving = p_moving
	step = p_step
	queue_redraw()


## True when the cape should render in front of the body (Mallow faces away).
func in_front() -> bool:
	return dir == "up"


func _px(x: int, y: int, w: int, h: int, c: Color) -> void:
	draw_rect(Rect2(x, y, w, h), c, true)


func _draw() -> void:
	if item_id == "":
		return
	var sway := 1 if moving and step % 2 == 1 else 0
	match dir:
		"up":
			# full cape over the back, shoulders tucked under the hood
			_px(-5, -8, 10, 7, line_col)
			_px(-6, -3, 12, 3, line_col)
			_px(-4, -8, 8, 6, main_col)
			_px(-5, -3, 10, 2, main_col)
			_px(-2, -6, 1, 4, shade_col)
			_px(1, -6, 1, 4, shade_col)
			_px(-5, -2, 10, 1, shade_col)
			if sway == 1:
				_px(-6, -1, 3, 1, line_col)
				_px(3, -1, 3, 1, line_col)
		"left", "right":
			# trailing cape behind the body, flaring towards the back
			var s := 1 if dir == "left" else -1
			var pts := PackedVector2Array([
				Vector2(0 * s, -8), Vector2(4 * s, -8), Vector2((8 + sway) * s, -1), Vector2(0 * s, -1)])
			for o in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
				draw_colored_polygon(_shift(pts, o), line_col)
			draw_colored_polygon(pts, main_col)
			draw_line(Vector2(3 * s, -7), Vector2((6 + sway) * s, -2), shade_col, 1.0)
		_:
			# facing down: the cape hangs behind, edges and hem visible
			_px(-8, -7, 16, 7, line_col)
			_px(-7, -7, 14, 6, shade_col)
			_px(-7, -2, 14, 1, main_col)
			if sway == 1:
				_px(-7, 0, 14, 1, line_col)


func _shift(pts: PackedVector2Array, o: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p + o)
	return out
