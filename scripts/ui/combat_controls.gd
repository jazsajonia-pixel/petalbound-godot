extends Node
## Mobile combat controls layered on the HUD:
##  - the right-hand cluster layout (attack, four art slots, potion, gear active,
##    jump, swap, interact) scaled by HUD scale / button size, with saved per-
##    control offsets from the HUD editor;
##  - drag-to-aim for aimable arts (release to cast, slide back onto the button,
##    or off the screen edge to cancel; a touch that never
##    moves past the dead-zone is a tap = smart cast at the current target);
##  - the HUD layout editor (drag controls, scale/size/opacity, reset);
##  - per-frame button state (cooldowns, focus, charges) and a compact target
##    frame + active-buff readout.

const ClassBook := preload("res://scripts/data/classdb.gd")
const CD := preload("res://scripts/data/combat_data.gd")
const AssassinArts := preload("res://scripts/combat/assassin_arts.gd")
const Build := preload("res://scripts/combat/build.gd")
const DB := preload("res://scripts/data/db.gd")
const AnimLib := preload("res://scripts/core/anim_lib.gd")
const AIM_DEADZONE := 10.0
const AIM_DRAG_FULL := 56.0
const AIM_EDGE := 3.0  # px from the screen edge where a release cancels

var hud: Control
var skill_buttons: Array = []
var relic_button: Control
## Default layout: id -> [offset from safe-rect bottom-right, radius]. Joystick
## ("stick") is relative to bottom-left. Values are before HUD scale.
const DEFAULTS := {
	"attack": [Vector2(-42, -42), 27.0],
	"skill0": [Vector2(-106, -30), 17.0],
	"skill1": [Vector2(-96, -80), 17.0],
	"skill2": [Vector2(-58, -110), 17.0],
	"skill3": [Vector2(-18, -114), 15.0],
	"heal": [Vector2(-152, -24), 15.0],
	"relic": [Vector2(-146, -68), 14.0],
	"jump": [Vector2(-20, -160), 13.0],
	# weapon bar: vertical column inboard (left) of the action cluster
	"wslot0": [Vector2(-188, -26), 11.0],
	"wslot1": [Vector2(-188, -52), 11.0],
	"wslot2": [Vector2(-188, -78), 11.0],
	"wslot3": [Vector2(-188, -104), 11.0],
	"wslot4": [Vector2(-188, -130), 11.0],
	"interact": [Vector2(-150, -110), 15.0],
	"sprint": [Vector2(0, 0), 12.0],
}

# aim state
var aim_index := -1
var aim_button: Control
var aim_slot := -1
var aim_offset := Vector2.ZERO
var aim_started := false
var aim_cancelling := false

# editor state
var edit_active := false
var edit_panel: PanelContainer
var edit_drag_id := ""
var edit_drag_index := -99
var edit_last_valid := Vector2.ZERO
var info: Control


func setup(p_hud: Control) -> void:
	hud = p_hud
	for i in range(4):
		var b: Control = hud._touch("", "ui/skill/scroll.png", 17.0, Color(0.85, 0.75, 1.0))
		b.id = "skill%d" % i
		b.slot = i
		skill_buttons.append(b)
	relic_button = hud._touch("relic", "items/gemred.png", 13.0, Color(1.0, 0.7, 0.45))
	relic_button.id = "relic"
	info = CombatInfo.new()
	info.controls = self
	info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.add_child(info)
	_make_edit_panel()


# ------------------------------------------------------------------ layout
func _scale() -> float:
	return float(hud.settings.get("hud_scale", 1.0))


func _bsize() -> float:
	return float(hud.settings.get("button_size", 1.0))


func default_center(id: String) -> Vector2:
	var sr: Rect2 = hud.safe_rect
	var k := _scale()
	if id == "stick":
		var r: float = hud.joystick_radius
		return Vector2(sr.position.x + r + 16.0 * k, sr.end.y - r - 14.0 * k)
	if id == "sprint":
		return default_center("stick") + Vector2(0, -hud.joystick_radius - 26.0 * k)
	var d: Array = DEFAULTS.get(id, [Vector2(-40, -40), 16.0])
	return sr.end + (d[0] as Vector2) * k


func default_radius(id: String) -> float:
	var d: Array = DEFAULTS.get(id, [Vector2.ZERO, 16.0])
	return float(d[1]) * _scale() * _bsize()


func _offset(id: String) -> Vector2:
	var lay: Dictionary = hud.settings.get("layout", {})
	if lay.has(id):
		var v = lay[id]
		if v is Array and v.size() == 2:
			return Vector2(float(v[0]), float(v[1]))
	return Vector2.ZERO


## Clamp a control so it stays fully inside the safe area.
func clamp_center(p: Vector2, r: float) -> Vector2:
	var sr: Rect2 = hud.safe_rect
	return Vector2(clampf(p.x, sr.position.x + r, sr.end.x - r), clampf(p.y, sr.position.y + r + 20.0, sr.end.y - r))


func apply_layout() -> void:
	var op := float(hud.settings.get("hud_opacity", 0.9))
	for b in hud.touch_buttons:
		if b.id == "":
			continue
		b.set_radius(default_radius(b.id))
		b.center_at(clamp_center(default_center(b.id) + _offset(b.id), b.radius))
		b.opacity = op
	var stick := clamp_center(default_center("stick") + _offset("stick"), hud.joystick_radius)
	hud.joystick_home = stick
	if hud.joystick_touch_index == -1:
		hud.joystick_center = stick
	# sprint follows the joystick unless it has its own saved offset
	var sb: Control = hud.sprint_button
	sb.center_at(clamp_center(stick + Vector2(0, -hud.joystick_radius - 26.0 * _scale()) + _offset("sprint"), sb.radius))
	_resolve_overlaps()


## Nudge apart any defaults that collide (e.g. tiny screens or big buttons).
func _resolve_overlaps() -> void:
	for pass_i in range(4):
		var moved := false
		for a in hud.touch_buttons:
			if not a.visible and a != hud.interact_button:
				continue
			for b in hud.touch_buttons:
				if a == b:
					continue
				var d: Vector2 = b.center() - a.center()
				var need: float = a.radius + b.radius + 2.0
				if d.length() < need and d.length() > 0.01:
					var push: Vector2 = d.normalized() * (need - d.length()) * 0.5
					a.center_at(clamp_center(a.center() - push, a.radius))
					b.center_at(clamp_center(b.center() + push, b.radius))
					moved = true
		if not moved:
			break


func overlaps_any(b: Control, at: Vector2) -> bool:
	for o in hud.touch_buttons:
		if o == b or o.id == "":
			continue
		if at.distance_to(o.center()) < b.radius + o.radius + 2.0:
			return true
	if b.id != "stick" and at.distance_to(hud.joystick_home) < b.radius + hud.joystick_radius + 2.0:
		return true
	return false


# ------------------------------------------------------------------ per-frame state
func update_buttons() -> void:
	var p: Node = hud.game.player
	for i in range(4):
		var b: Control = skill_buttons[i]
		var sid: String = p.skill_bar[i] if i < p.skill_bar.size() else ""
		if sid == "":
			b.empty = true
			b.icon = null
			b.cooldown = 0.0
			b.cd_text = ""
			b.label = str(i + 1)
			b.aim_mode = "tap"
			b.dimmed = false
			continue
		var def: Dictionary = ClassBook.skill_of(sid)
		b.empty = false
		b.icon = AnimLib.tex(def["icon"])
		b.tint = Color(String(def.get("tint", "ffd9f2")))
		b.aim_mode = String(def.get("aim", "tap"))
		var cdv := float(p.skill_cd.get(sid, 0.0))
		var full := maxf(0.1, float(Build.skill_stat(p, sid, "cd", 1.0)) * p.skill_cd_scale())
		b.cooldown = clampf(cdv / full, 0.0, 1.0) if cdv > 0.0 else 0.0
		b.cd_text = ("%.1f" % cdv if cdv < 1.0 else "%d" % ceili(cdv)) if cdv > 0.05 else ""
		b.dimmed = p.focus < float(def.get("cost", 0))
		var lv := Build.skill_level(p, sid)
		b.label = "" if lv <= 1 else str(lv)
		# Petal Rush recast window: show the free dashes left, never dim for Focus
		var chain_left: int = AssassinArts.rush_left(p, sid)
		if chain_left > 0:
			b.dimmed = false
			b.cd_text = "x%d" % chain_left
	# flask
	var hb: Control = hud.heal_button
	var left: int = p.potions_left()
	hb.label = str(left)
	hb.cooldown = 1.0 if left <= 0 else clampf(p.flask_cd / float(CD.BALANCE["flask_cooldown"]), 0.0, 1.0)
	hb.cd_text = "EMPTY" if left <= 0 else ""
	hb.dimmed = p.potion_block_reason() != ""
	# gear active (relic slot): always shown; empty socket when no relic is worn
	var rid: String = p.relic_id()
	relic_button.visible = true
	if rid == "":
		relic_button.icon = AnimLib.tex("ui/skill/amulet.png")
		relic_button.tint = Color(0.55, 0.5, 0.62)
		relic_button.cooldown = 0.0
		relic_button.cd_text = ""
		relic_button.label = ""
		relic_button.dimmed = true
	else:
		relic_button.dimmed = false
		var item_id: String = p.equipped.get("relic", "")
		relic_button.icon = AnimLib.tex(DB.ITEMS[item_id]["icon"])
		relic_button.tint = Color(String(CD.RELICS[rid]["color"]))
		var full_r := float(CD.RELICS[rid]["cd"])
		relic_button.cooldown = clampf(p.relic_cd / full_r, 0.0, 1.0)
		relic_button.cd_text = "%d" % ceili(p.relic_cd) if p.relic_cd > 0.05 else ""
		var bt := float(p.buffs.get("relic_" + rid, 0.0))
		relic_button.label = "" if bt <= 0.0 else "%ds" % ceili(bt)
	info.queue_redraw()


# ------------------------------------------------------------------ art buttons & aiming
## Called by the HUD when a touch lands on an art button. Returns true if handled.
func press_skill(b: Control, index: int, pos: Vector2) -> bool:
	var p: Node = hud.game.player
	var sid: String = p.skill_bar[b.slot] if b.slot < p.skill_bar.size() else ""
	b.pressed_now = true
	hud.touch_held[index] = b
	if sid == "":
		# empty slot: open the loadout so it can be filled
		hud.call_deferred("open_loadout", b.slot)
		return true
	if b.aim_mode == "tap":
		p.cast_slot(b.slot)
		return true
	aim_index = index
	aim_button = b
	aim_slot = b.slot
	aim_offset = Vector2.ZERO
	aim_started = false
	aim_cancelling = false
	_show_aim(pos)
	return true


func drag(index: int, pos: Vector2) -> bool:
	if index != aim_index or aim_button == null:
		return false
	_show_aim(pos)
	return true


## Where an aim touch would be cancelled instead of cast.
func aim_cancel_reason(pos: Vector2) -> String:
	if aim_button == null:
		return ""
	var r: Rect2 = hud.get_viewport().get_visible_rect().grow(-AIM_EDGE)
	if not r.has_point(pos):
		return "edge"
	if aim_started and pos.distance_to(aim_button.center()) <= aim_button.radius:
		return "button"
	return ""


func _show_aim(pos: Vector2) -> void:
	var p: Node = hud.game.player
	var sid: String = p.skill_bar[aim_slot]
	var def: Dictionary = ClassBook.skill_of(sid)
	var off: Vector2 = pos - aim_button.center()
	if off.length() > AIM_DEADZONE * _scale():
		aim_started = true
	aim_cancelling = aim_started and aim_cancel_reason(pos) != ""
	var rng: float = p.skill_range(sid)
	var world_aim: Vector2
	if not aim_started:
		world_aim = p.auto_aim_offset(sid)
	elif b_mode() == "point":
		var k := clampf((off.length() - AIM_DEADZONE) / AIM_DRAG_FULL, 0.0, 1.0)
		world_aim = off.normalized() * rng * k
	else:
		world_aim = off.normalized() * rng
	aim_offset = world_aim
	var col := Color(String(def.get("tint", "ffffff")))
	var rad: float = p.skill_radius(sid) if b_mode() == "point" else 0.0
	var width := 10.0 if String(def.get("exec", "")) == "charge" else 7.0
	p.aim_indicator.width = width
	p.aim_indicator.show_aim(b_mode(), rng, rad, world_aim, col, aim_cancelling)


func b_mode() -> String:
	return aim_button.aim_mode if aim_button else "tap"


## Release: cast with the aimed vector, or cancel if the finger slid back onto
## the button after aiming. Returns true if this touch was an aim touch.
func release(index: int) -> bool:
	if index != aim_index:
		return false
	var p: Node = hud.game.player
	p.aim_indicator.visible = false
	if aim_button:
		aim_button.pressed_now = false
	if not aim_cancelling:
		p.cast_slot(aim_slot, aim_offset if aim_started else Vector2.INF)
	elif hud.game:
		hud.game.audio.play("cancel", 0.0, -10.0)
	aim_index = -1
	aim_button = null
	aim_slot = -1
	aim_started = false
	aim_cancelling = false
	return true


func cancel_aim() -> void:
	if aim_index == -1:
		return
	hud.game.player.aim_indicator.visible = false
	if aim_button:
		aim_button.pressed_now = false
	aim_index = -1
	aim_button = null


# ------------------------------------------------------------------ HUD editor
func _make_edit_panel() -> void:
	edit_panel = PanelContainer.new()
	edit_panel.add_theme_stylebox_override("panel", hud._box(Color(0.10, 0.07, 0.15, 0.94), hud.C_BORDER, 1, 4))
	edit_panel.visible = false
	edit_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	hud.add_child(edit_panel)
	var v: VBoxContainer = hud._vbox(edit_panel, 3)
	var head: HBoxContainer = hud._hbox(v, 6)
	hud._label("EDIT HUD", 10, hud.C_GOLD, head)
	hud._label("drag controls · red = overlapping", 8, hud.C_DIM, head)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 6)
	v.add_child(grid)
	_edit_slider(grid, "SCALE", "hud_scale", 0.75, 1.3, 0.05)
	_edit_slider(grid, "BUTTONS", "button_size", 0.8, 1.35, 0.05)
	_edit_slider(grid, "OPACITY", "hud_opacity", 0.3, 1.0, 0.05)
	var row: HBoxContainer = hud._hbox(v, 4)
	hud._button("RESET LAYOUT", row, reset_layout)
	var done: Button = hud._button("DONE", row, end_edit)
	done.name = "EditDone"


func _edit_slider(grid: GridContainer, title: String, key: String, mn: float, mx: float, step: float) -> void:
	var l: Label = hud._label("%s %d%%" % [title, roundi(float(hud.settings[key]) * 100.0)], 8, hud.C_TEXT, grid)
	var s: HSlider = hud._slider(mn, mx, float(hud.settings[key]), step, grid)
	s.custom_minimum_size = Vector2(70, 12)
	s.name = "Edit_" + key
	s.value_changed.connect(func(x: float) -> void:
		hud.settings[key] = x
		l.text = "%s %d%%" % [title, roundi(x * 100.0)]
		hud._layout_controls()
		hud.save_settings())


func start_edit() -> void:
	edit_active = true
	hud.set_game_paused(false)
	hud._clear_touch_inputs()
	hud.game.set_menu_pause(true)
	edit_panel.visible = true
	for b in hud.touch_buttons:
		b.editing = true
	_place_edit_panel()


func _place_edit_panel() -> void:
	var sr: Rect2 = hud.safe_rect
	edit_panel.position = Vector2(sr.get_center().x - 150, sr.position.y + 4)
	edit_panel.size = Vector2(300, 0)


func end_edit() -> void:
	edit_active = false
	edit_panel.visible = false
	edit_drag_id = ""
	for b in hud.touch_buttons:
		b.editing = false
		b.edit_invalid = false
	hud.save_settings()
	hud.game.set_menu_pause(hud.menus_pausing())


func reset_layout() -> void:
	hud.settings["layout"] = {}
	hud.settings["hud_scale"] = 1.0
	hud.settings["button_size"] = 1.0
	hud.settings["hud_opacity"] = 0.9
	for k in ["hud_scale", "button_size", "hud_opacity"]:
		var s := edit_panel.find_child("Edit_" + k, true, false) as HSlider
		if s:
			s.set_value_no_signal(float(hud.settings[k]))
	hud._layout_controls()
	hud.save_settings()


## Editor input (touch or mouse). Never triggers combat actions.
func edit_input(event: InputEvent) -> void:
	var pos := Vector2.ZERO
	var idx := -99
	var pressed := false
	var released := false
	var moved := false
	if event is InputEventScreenTouch:
		pos = event.position
		idx = event.index
		pressed = event.pressed
		released = not event.pressed
	elif event is InputEventScreenDrag:
		pos = event.position
		idx = event.index
		moved = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.device != InputEvent.DEVICE_ID_EMULATION:
		pos = event.position
		idx = -1
		pressed = event.pressed
		released = not event.pressed
	elif event is InputEventMouseMotion and event.device != InputEvent.DEVICE_ID_EMULATION:
		pos = event.position
		idx = -1
		moved = true
	else:
		return
	if edit_panel.get_global_rect().has_point(pos) and edit_drag_id == "":
		return  # let the panel's own controls work
	if pressed and edit_drag_id == "":
		for b in hud.touch_buttons:
			if b.visible and b.hit(pos):
				edit_drag_id = b.id
				edit_drag_index = idx
				edit_last_valid = b.center()
				break
		if edit_drag_id == "" and pos.distance_to(hud.joystick_home) <= hud.joystick_radius:
			edit_drag_id = "stick"
			edit_drag_index = idx
			edit_last_valid = hud.joystick_home
		hud.get_viewport().set_input_as_handled()
	elif moved and edit_drag_id != "" and idx == edit_drag_index:
		_edit_move(pos)
		hud.get_viewport().set_input_as_handled()
	elif released and edit_drag_id != "" and idx == edit_drag_index:
		_edit_drop()
		hud.get_viewport().set_input_as_handled()


func _edit_target(id: String) -> Control:
	for b in hud.touch_buttons:
		if b.id == id:
			return b
	return null


func _edit_move(pos: Vector2) -> void:
	if edit_drag_id == "stick":
		var c := clamp_center(pos, hud.joystick_radius)
		hud.joystick_home = c
		hud.joystick_center = c
		hud.queue_redraw()
		return
	var b := _edit_target(edit_drag_id)
	if b == null:
		return
	var c2 := clamp_center(pos, b.radius)
	b.center_at(c2)
	b.edit_invalid = overlaps_any(b, c2)


func _edit_drop() -> void:
	var lay: Dictionary = hud.settings.get("layout", {})
	if edit_drag_id == "stick":
		var base := default_center("stick")
		lay["stick"] = [hud.joystick_home.x - base.x, hud.joystick_home.y - base.y]
	else:
		var b := _edit_target(edit_drag_id)
		if b != null:
			if overlaps_any(b, b.center()):
				b.center_at(edit_last_valid)  # refuse unusable overlaps
				b.edit_invalid = false
			var base2 := default_center(edit_drag_id)
			if edit_drag_id == "sprint":
				base2 = hud.joystick_home + Vector2(0, -hud.joystick_radius - 26.0 * _scale())
			lay[edit_drag_id] = [b.center().x - base2.x, b.center().y - base2.y]
	hud.settings["layout"] = lay
	edit_drag_id = ""
	hud.save_settings()


# ------------------------------------------------------------------ target frame / buffs
class CombatInfo:
	extends Control
	var controls: Node

	func _draw() -> void:
		if controls == null or controls.hud == null or controls.hud.game == null:
			return
		var hud: Control = controls.hud
		var g: Node = hud.game
		if not g.game_started or hud.any_menu_open() or hud.photo_active:
			return
		var p: Node = g.player
		var f := get_theme_default_font()
		if f == null:
			return
		var sr: Rect2 = hud.safe_rect
		# target frame (top centre)
		var t = p.current_target
		if p.is_valid_target(t) and t.get("title") == null:
			var w := 110.0
			var pos := Vector2(sr.get_center().x - w / 2.0, sr.position.y + 2)
			var nm := String(t.cfg.get("name", "Foe")) if t.get("cfg") != null else "Foe"
			if p.manual_target == t:
				nm += "  [LOCKED]"
			draw_rect(Rect2(pos, Vector2(w, 16)), Color(0.08, 0.05, 0.12, 0.75))
			draw_string(f, pos + Vector2(3, 7), nm, HORIZONTAL_ALIGNMENT_LEFT, w - 6, 8, Color(1, 0.92, 0.85))
			var hp := float(t.get("hp"))
			var mx := maxf(1.0, float(t.get("max_hp")))
			draw_rect(Rect2(pos + Vector2(3, 10), Vector2(w - 6, 3)), Color(0.25, 0.1, 0.15))
			draw_rect(Rect2(pos + Vector2(3, 10), Vector2((w - 6) * clampf(hp / mx, 0.0, 1.0), 3)), Color(1.0, 0.45, 0.55))
			var st: Node = t.get_node_or_null("Status")
			if st != null:
				var x := pos.x + w + 3
				for sid in st.effects:
					var c := Color(String(CD.STATUS[sid]["color"]))
					var txt := "%s%s" % [String(CD.STATUS[sid]["name"]).to_upper(), " x%d" % st.stacks(sid) if st.stacks(sid) > 1 else ""]
					draw_string(f, Vector2(x, pos.y + 9), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, c)
					x += f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 8).x + 4
		# active buffs on Mallow (under the stat bars)
		var bx := sr.position.x
		var by := sr.position.y + 100
		var names := {"bulwark": "BULWARK", "shadow": "SHADOW", "marked": "MARKED", "relic_kindle": "KINDLE",
			"relic_nightveil": "NIGHTVEIL", "relic_overcharge": "OVERCHARGE", "relic_soulfeast": "SOUL FEAST"}
		var parts := PackedStringArray()
		for b in p.buffs:
			if names.has(b):
				parts.append("%s %ds" % [names[b], ceili(float(p.buffs[b]))])
		if p.guard_active:
			parts.append("PETALGUARD")
		if parts.size() > 0:
			var s := "  ".join(parts)
			draw_string_outline(f, Vector2(bx, by), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, 3, Color(0.05, 0.03, 0.08))
			draw_string(f, Vector2(bx, by), s, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1.0, 0.86, 0.55))
