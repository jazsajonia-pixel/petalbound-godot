extends Control

signal start_requested
signal retry_requested

var count_label: Label
var message_label: Label
var hint_label: Label
var status_label: Label
var dash_button: Button
var attack_button: Button
var mothlight_button: Button
var guard_button: Button
var heal_button: Button
var weapon_button: Button
var bag_button: Button
var interact_button: Button
var pause_button: Button
var pause_overlay: ColorRect
var pause_panel: PanelContainer
var inventory_overlay: ColorRect
var inventory_panel: PanelContainer
var inventory_text: Label
var title_overlay: ColorRect
var title_panel: PanelContainer
var title_heading: Label
var title_subheading: Label
var title_button: Button
var deadzone_slider: HSlider
var sensitivity_slider: HSlider
var deadzone_label: Label
var sensitivity_label: Label
var message_timer := 0.0
var joystick_deadzone := 0.08
var joystick_sensitivity := 1.0
var safe_rect := Rect2(Vector2(24, 24), Vector2(912, 492))
var joystick_home := Vector2(112, 425)
var joystick_center := Vector2(112, 425)
var joystick_vector := Vector2.ZERO
var joystick_raw_direction := Vector2.ZERO
var joystick_raw_strength := 0.0
var joystick_touch_index := -1
var joystick_radius := 76.0
var joystick_knob_radius := 29.0
const FIELD_KIT_ICONS := [
	{"name": "Blade", "path": "res://assets/packs/rpg_inventory_icons/selected/thornblade.png"},
	{"name": "Staff", "path": "res://assets/packs/rpg_inventory_icons/selected/bloomstaff.png"},
	{"name": "Cloak", "path": "res://assets/packs/rpg_inventory_icons/selected/plum_cloak.png"},
	{"name": "Charm", "path": "res://assets/packs/rpg_inventory_icons/selected/moonheart_charm.png"},
	{"name": "Tea", "path": "res://assets/packs/rpg_inventory_icons/selected/moontea.png"}
]

func setup() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_pause_action()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	count_label = _label("MOONSEEDS  0 / 3", Vector2.ZERO, Vector2(320, 36), 20)
	message_label = _label("Restore the shrine by gathering moonseeds.", Vector2.ZERO, Vector2(630, 32), 15)
	hint_label = _label("STICK / WASD MOVE  ·  J ATTACK  ·  SPACE DASH  ·  F MOTHLIGHT  ·  G GUARD  ·  R TEA", Vector2.ZERO, Vector2(760, 26), 12)
	status_label = _label("HP  ♥♥♥♥♥    TEA 3    PETALS 0", Vector2.ZERO, Vector2(340, 30), 16)
	dash_button = _make_button("DASH", Vector2.ZERO, Vector2(108, 64), "dash", 16)
	attack_button = _make_button("ATTACK", Vector2.ZERO, Vector2(108, 64), "attack", 15)
	mothlight_button = _make_button("MOTHLIGHT", Vector2.ZERO, Vector2(108, 64), "skill", 13)
	guard_button = _make_button("PETALGUARD", Vector2.ZERO, Vector2(108, 64), "guard", 12)
	heal_button = _make_button("MOONTEA", Vector2.ZERO, Vector2(108, 64), "heal", 13)
	weapon_button = _make_button("THORNBLADE  Q", Vector2.ZERO, Vector2(138, 48), "switch_weapon", 12)
	bag_button = _make_button("BAG  I", Vector2.ZERO, Vector2(84, 48), "", 13)
	bag_button.pressed.connect(toggle_inventory)
	interact_button = _make_button("INTERACT", Vector2.ZERO, Vector2(108, 58), "interact", 13)
	interact_button.visible = false
	pause_button = _make_button("PAUSE", Vector2.ZERO, Vector2(92, 50), "", 14)
	pause_button.pressed.connect(toggle_pause)
	_make_pause_overlay()
	_make_inventory_overlay()
	_make_title_overlay()
	_layout_controls()
	resized.connect(_layout_controls)
	get_viewport().size_changed.connect(_on_viewport_resized)

func _register_pause_action() -> void:
	if InputMap.has_action("pause"):
		return
	InputMap.add_action("pause")
	for key in [KEY_ESCAPE, KEY_P]:
		var key_event := InputEventKey.new()
		key_event.physical_keycode = key
		InputMap.action_add_event("pause", key_event)

func _label(text: String, pos: Vector2, size: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.size = size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("fff9e8"))
	label.add_theme_color_override("font_shadow_color", Color("34444b"))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(label)
	return label

func _style_button(button: Button, font_size: int) -> void:
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", Color("fff9e8"))
	button.add_theme_color_override("font_hover_color", Color("ffffff"))
	button.add_theme_color_override("font_pressed_color", Color("ffffff"))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.23, 0.27, 0.34, 0.88)
	normal.border_color = Color(0.88, 0.94, 0.85, 0.88)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(13)
	button.add_theme_stylebox_override("normal", normal)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.32, 0.57, 0.51, 0.96)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover", normal)

func _make_button(text: String, pos: Vector2, size: Vector2, action: String = "", font_size: int = 18) -> Button:
	var button := Button.new()
	button.text = text
	button.position = pos
	button.size = size
	_style_button(button, font_size)
	if not action.is_empty():
		button.button_down.connect(func(): Input.action_press(action))
		button.button_up.connect(func(): Input.action_release(action))
	add_child(button)
	return button

func _style_panel(panel: PanelContainer, color: Color = Color("344f53")) -> void:
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = color
	panel_style.border_color = Color("d8e7d8")
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(18)
	panel.add_theme_stylebox_override("panel", panel_style)

func _make_pause_overlay() -> void:
	pause_overlay = ColorRect.new()
	pause_overlay.name = "PauseOverlay"
	pause_overlay.color = Color(0.08, 0.13, 0.17, 0.78)
	pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_overlay.visible = false
	pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(pause_overlay)
	pause_panel = PanelContainer.new()
	pause_panel.size = Vector2(370, 360)
	_style_panel(pause_panel)
	pause_overlay.add_child(pause_panel)
	var margin := _add_margin(pause_panel, 22)
	var layout := _add_vbox(margin, 12)
	layout.add_child(_panel_label("PAUSED", 26, Color("fff5df")))
	var resume := Button.new()
	resume.name = "ResumeButton"
	resume.text = "RESUME"
	resume.custom_minimum_size = Vector2(0, 52)
	_style_button(resume, 17)
	resume.pressed.connect(func(): set_game_paused(false))
	layout.add_child(resume)
	deadzone_label = _panel_label("DEAD ZONE  8%", 13, Color("e1e6d6"))
	layout.add_child(deadzone_label)
	deadzone_slider = _make_setting_slider(0.0, 0.30, joystick_deadzone, 0.01)
	deadzone_slider.value_changed.connect(_on_deadzone_changed)
	layout.add_child(deadzone_slider)
	sensitivity_label = _panel_label("SENSITIVITY  1.00×", 13, Color("e1e6d6"))
	layout.add_child(sensitivity_label)
	sensitivity_slider = _make_setting_slider(0.60, 1.60, joystick_sensitivity, 0.05)
	sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
	layout.add_child(sensitivity_slider)
	layout.add_child(_panel_label("WASD / arrows also move  ·  Q changes weapon", 11, Color("e1e6d6")))

func _make_inventory_overlay() -> void:
	inventory_overlay = ColorRect.new()
	inventory_overlay.name = "InventoryOverlay"
	inventory_overlay.color = Color(0.07, 0.12, 0.15, 0.80)
	inventory_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	inventory_overlay.visible = false
	inventory_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(inventory_overlay)
	inventory_panel = PanelContainer.new()
	inventory_panel.size = Vector2(520, 420)
	_style_panel(inventory_panel, Color("3c4d55"))
	inventory_overlay.add_child(inventory_panel)
	var margin := _add_margin(inventory_panel, 24)
	var layout := _add_vbox(margin, 13)
	layout.add_child(_panel_label("MALLOW'S FIELD KIT", 24, Color("fff5df")))
	var item_row := HBoxContainer.new()
	item_row.alignment = BoxContainer.ALIGNMENT_CENTER
	item_row.add_theme_constant_override("separation", 8)
	for item in FIELD_KIT_ICONS:
		var slot := VBoxContainer.new()
		slot.alignment = BoxContainer.ALIGNMENT_CENTER
		slot.add_theme_constant_override("separation", 2)
		slot.custom_minimum_size = Vector2(72, 78)
		var icon := TextureRect.new()
		icon.texture = load(str(item["path"])) as Texture2D
		icon.custom_minimum_size = Vector2(38, 38)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		slot.add_child(icon)
		var icon_label := _panel_label(str(item["name"]), 10, Color("e1e6d6"))
		slot.add_child(icon_label)
		item_row.add_child(slot)
	layout.add_child(item_row)
	inventory_text = _panel_label("THORNBLADE  ·  MOONTEA 3  ·  No charm equipped", 15, Color("e1e6d6"))
	inventory_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inventory_text.custom_minimum_size = Vector2(0, 106)
	layout.add_child(inventory_text)
	var close := Button.new()
	close.text = "CLOSE BAG"
	close.custom_minimum_size = Vector2(0, 48)
	_style_button(close, 16)
	close.pressed.connect(toggle_inventory)
	layout.add_child(close)

func _make_title_overlay() -> void:
	title_overlay = ColorRect.new()
	title_overlay.name = "TitleMenu"
	title_overlay.color = Color(0.07, 0.12, 0.15, 0.88)
	title_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	title_overlay.visible = false
	title_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(title_overlay)
	title_panel = PanelContainer.new()
	title_panel.size = Vector2(560, 420)
	_style_panel(title_panel, Color("344f53"))
	title_overlay.add_child(title_panel)
	var margin := _add_margin(title_panel, 28)
	var layout := _add_vbox(margin, 14)
	title_heading = _panel_label("PETALBOUND", 38, Color("fff5df"))
	title_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(title_heading)
	title_subheading = _panel_label("A little light can wake a sleeping meadow.", 16, Color("e7e9d5"))
	title_subheading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layout.add_child(title_subheading)
	title_button = Button.new()
	title_button.text = "BEGIN JOURNEY"
	title_button.custom_minimum_size = Vector2(0, 58)
	_style_button(title_button, 20)
	title_button.pressed.connect(_start_from_menu)
	layout.add_child(title_button)
	var controls := _panel_label("EXPLORE  WASD / left stick\nTHORNBLADE  J / ATTACK\nDASH  SPACE  ·  MOTHLIGHT  F\nPETALGUARD  G  ·  MOONTEA  R\nWEAPON  Q  ·  FIELD KIT  I  ·  PAUSE  Esc", 14, Color("e1e6d6"))
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	layout.add_child(controls)

func _panel_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func _add_margin(parent: Control, padding: int) -> MarginContainer:
	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, padding)
	parent.add_child(margin)
	return margin

func _add_vbox(parent: Control, separation: int) -> VBoxContainer:
	var layout := VBoxContainer.new()
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", separation)
	parent.add_child(layout)
	return layout

func _make_setting_slider(minimum: float, maximum: float, initial: float, step: float) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = initial
	slider.custom_minimum_size = Vector2(0, 24)
	slider.focus_mode = Control.FOCUS_NONE
	return slider

func _layout_controls() -> void:
	if not is_instance_valid(count_label) or not is_instance_valid(dash_button) or not is_instance_valid(pause_button):
		return
	safe_rect = _get_safe_rect()
	count_label.position = safe_rect.position + Vector2(14, 10)
	message_label.position = safe_rect.position + Vector2(14, 42)
	hint_label.position = safe_rect.position + Vector2(14, 74)
	status_label.position = safe_rect.position + Vector2(14, 104)
	var right := safe_rect.end.x - 14.0
	pause_button.position = Vector2(right - pause_button.size.x, safe_rect.position.y + 12)
	bag_button.position = Vector2(right - bag_button.size.x, safe_rect.position.y + 70)
	weapon_button.position = Vector2(right - weapon_button.size.x - bag_button.size.x - 8, safe_rect.position.y + 70)
	dash_button.position = Vector2(right - dash_button.size.x, safe_rect.end.y - dash_button.size.y - 12)
	attack_button.position = Vector2(right - attack_button.size.x, dash_button.position.y - attack_button.size.y - 8)
	mothlight_button.position = Vector2(right - mothlight_button.size.x - 8 - dash_button.size.x, dash_button.position.y)
	guard_button.position = Vector2(mothlight_button.position.x, attack_button.position.y)
	heal_button.position = Vector2(mothlight_button.position.x, guard_button.position.y - heal_button.size.y - 8)
	interact_button.position = Vector2(right - interact_button.size.x, heal_button.position.y)
	if is_instance_valid(pause_panel):
		pause_panel.position = safe_rect.position + safe_rect.size * 0.5 - pause_panel.size * 0.5
	if is_instance_valid(inventory_panel):
		inventory_panel.position = safe_rect.position + safe_rect.size * 0.5 - inventory_panel.size * 0.5
	if is_instance_valid(title_panel):
		title_panel.position = safe_rect.position + safe_rect.size * 0.5 - title_panel.size * 0.5
	joystick_radius = minf(76.0, minf(safe_rect.size.x * 0.12, safe_rect.size.y * 0.18))
	joystick_knob_radius = maxf(18.0, joystick_radius * 0.38)
	joystick_home = Vector2(safe_rect.position.x + joystick_radius + 24, safe_rect.end.y - joystick_radius - 24)
	if joystick_touch_index == -1:
		joystick_center = joystick_home
	queue_redraw()

func _get_safe_rect() -> Rect2:
	var viewport_size := get_viewport_rect().size
	var window_size := DisplayServer.window_get_size()
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0 or window_size.x <= 0 or window_size.y <= 0:
		return Rect2(Vector2(24, 24), Vector2(maxf(1.0, viewport_size.x - 48), maxf(1.0, viewport_size.y - 48)))
	var display_safe := DisplayServer.get_display_safe_area()
	var window_pos := DisplayServer.window_get_position()
	var left_ratio := clampf(float(display_safe.position.x - window_pos.x) / float(window_size.x), 0.0, 1.0)
	var top_ratio := clampf(float(display_safe.position.y - window_pos.y) / float(window_size.y), 0.0, 1.0)
	var right_ratio := clampf(float(display_safe.end.x - window_pos.x) / float(window_size.x), 0.0, 1.0)
	var bottom_ratio := clampf(float(display_safe.end.y - window_pos.y) / float(window_size.y), 0.0, 1.0)
	var left := maxf(24.0, left_ratio * viewport_size.x)
	var top := maxf(24.0, top_ratio * viewport_size.y)
	var right := minf(viewport_size.x - 24.0, right_ratio * viewport_size.x)
	var bottom := minf(viewport_size.y - 24.0, bottom_ratio * viewport_size.y)
	if right - left < 280.0 or bottom - top < 210.0:
		return Rect2(Vector2(24, 24), Vector2(maxf(1.0, viewport_size.x - 48), maxf(1.0, viewport_size.y - 48)))
	return Rect2(Vector2(left, top), Vector2(right - left, bottom - top))

func _input(event: InputEvent) -> void:
	if get_tree().paused or title_overlay.visible or inventory_overlay.visible:
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and joystick_touch_index == -1 and _can_start_joystick(touch.position):
			joystick_touch_index = touch.index
			joystick_center = touch.position
			_update_joystick(touch.position)
			get_viewport().set_input_as_handled()
		elif not touch.pressed and touch.index == joystick_touch_index:
			_end_joystick()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == joystick_touch_index:
			_update_joystick(drag.position)
			get_viewport().set_input_as_handled()

func _can_start_joystick(point: Vector2) -> bool:
	return point.x <= safe_rect.position.x + safe_rect.size.x * 0.48 and point.y >= safe_rect.position.y + safe_rect.size.y * 0.30

func _update_joystick(point: Vector2) -> void:
	var offset := point - joystick_center
	var raw_strength := minf(offset.length() / maxf(1.0, joystick_radius), 1.0)
	joystick_raw_strength = raw_strength
	joystick_raw_direction = offset.normalized() if raw_strength > 0.0 else Vector2.ZERO
	if raw_strength <= joystick_deadzone:
		joystick_vector = Vector2.ZERO
	else:
		var adjusted_strength := (raw_strength - joystick_deadzone) / maxf(0.001, 1.0 - joystick_deadzone)
		joystick_vector = joystick_raw_direction * minf(1.0, adjusted_strength * joystick_sensitivity)
	_apply_joystick_actions()
	queue_redraw()

func _end_joystick() -> void:
	joystick_touch_index = -1
	joystick_center = joystick_home
	joystick_vector = Vector2.ZERO
	joystick_raw_direction = Vector2.ZERO
	joystick_raw_strength = 0.0
	_apply_joystick_actions()
	queue_redraw()

func _apply_joystick_actions() -> void:
	_set_axis_action("move_left", maxf(-joystick_vector.x, 0.0))
	_set_axis_action("move_right", maxf(joystick_vector.x, 0.0))
	_set_axis_action("move_up", maxf(-joystick_vector.y, 0.0))
	_set_axis_action("move_down", maxf(joystick_vector.y, 0.0))

func _set_axis_action(action: String, strength: float) -> void:
	if strength > 0.08:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)

func _draw() -> void:
	var center := joystick_center if joystick_touch_index != -1 else joystick_home
	draw_circle(center, joystick_radius + 4.0, Color(0.18, 0.23, 0.29, 0.28))
	draw_circle(center, joystick_radius, Color(0.25, 0.31, 0.36, 0.54))
	draw_arc(center, joystick_radius, 0.0, TAU, 48, Color(0.91, 0.95, 0.87, 0.68), 3.0, true)
	var knob_center := center + joystick_vector * joystick_radius
	draw_circle(knob_center, joystick_knob_radius, Color(0.49, 0.39, 0.57, 0.87))
	draw_arc(knob_center, joystick_knob_radius, 0.0, TAU, 32, Color(0.96, 0.91, 0.82, 0.9), 3.0, true)

func set_seed_count(amount: int, total: int = 3) -> void:
	if is_instance_valid(count_label):
		count_label.text = "MOONSEEDS  %d / %d" % [amount, total]

func set_status(status: Dictionary) -> void:
	if not is_instance_valid(status_label):
		return
	var hearts := ""
	for i in range(int(status.get("max_health", 5))):
		hearts += "♥" if i < int(status.get("health", 0)) else "·"
	status_label.text = "HP  %s    TEA %d    PETALS %d" % [hearts, int(status.get("moontea", 0)), int(status.get("petalcoins", 0))]
	if is_instance_valid(weapon_button):
		weapon_button.text = "%s\nQ" % str(status.get("weapon", "THORNBLADE"))
	if is_instance_valid(mothlight_button):
		var cd := float(status.get("mothlight_cooldown", 0.0))
		mothlight_button.text = "MOTHLIGHT" if cd <= 0.0 else "MOTE %.1f" % cd
	if is_instance_valid(guard_button):
		var guard_cd := float(status.get("guard_cooldown", 0.0))
		guard_button.text = "GUARD UP" if bool(status.get("guard_active", false)) else ("PETALGUARD" if guard_cd <= 0.0 else "GUARD %.1f" % guard_cd)
	if is_instance_valid(heal_button):
		heal_button.text = "MOONTEA\n%d" % int(status.get("moontea", 0))
	if is_instance_valid(inventory_text):
		var charm_text := "Moonheart Charm equipped (+1 heart)" if bool(status.get("charm_equipped", false)) else "No charm equipped — seek the old chest."
		var cloak_text := "Plum Wayfarer equipped (+8% movement)" if bool(status.get("cloak_equipped", false)) else "No cloak equipped."
		inventory_text.text = "WEAPON  %s\nCLOAK  %s\nCHARM  %s\nMOONTEA  %d   ·   PETALCOINS  %d\n\nMOTHLIGHT  homing mote, 4.5s rest\nPETALGUARD  blocks one hit, 8s rest" % [str(status.get("weapon", "THORNBLADE")), cloak_text, charm_text, int(status.get("moontea", 0)), int(status.get("petalcoins", 0))]

func set_interact_visible(visible: bool, label: String = "INTERACT") -> void:
	interact_button.visible = visible
	interact_button.text = label

func show_message(text: String) -> void:
	if is_instance_valid(message_label):
		message_label.text = text
		message_timer = 4.5
		message_label.add_theme_color_override("font_color", Color("fff6c5"))

func show_title_menu() -> void:
	title_overlay.visible = true
	inventory_overlay.visible = false
	pause_overlay.visible = false
	get_tree().paused = true

func hide_title_menu() -> void:
	title_overlay.visible = false
	get_tree().paused = false

func _start_from_menu() -> void:
	start_requested.emit()

func show_game_over(message: String = "The meadow still needs you.") -> void:
	title_heading.text = "REST, LITTLE TRAVELER"
	title_subheading.text = message
	title_button.text = "TRY AGAIN"
	if title_button.pressed.is_connected(_start_from_menu):
		title_button.pressed.disconnect(_start_from_menu)
	if not title_button.pressed.is_connected(_retry_from_menu):
		title_button.pressed.connect(_retry_from_menu)
	show_title_menu()

func show_victory(message: String = "Moonlight returns to the meadow.") -> void:
	title_heading.text = "THE SHRINE BLOOMS"
	title_subheading.text = message
	title_button.text = "WANDER AGAIN"
	if title_button.pressed.is_connected(_start_from_menu):
		title_button.pressed.disconnect(_start_from_menu)
	if not title_button.pressed.is_connected(_retry_from_menu):
		title_button.pressed.connect(_retry_from_menu)
	show_title_menu()

func _retry_from_menu() -> void:
	title_button.pressed.disconnect(_retry_from_menu)
	title_button.pressed.connect(_start_from_menu)
	title_heading.text = "PETALBOUND"
	title_subheading.text = "A little light can wake a sleeping meadow."
	title_button.text = "BEGIN JOURNEY"
	retry_requested.emit()

func toggle_inventory() -> void:
	if get_tree().paused or title_overlay.visible:
		return
	inventory_overlay.visible = not inventory_overlay.visible
	if inventory_overlay.visible:
		_clear_touch_inputs()

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("pause") and not title_overlay.visible:
		toggle_pause()
	if not get_tree().paused and message_timer > 0.0:
		message_timer -= delta
		if message_timer <= 0.0 and is_instance_valid(message_label):
			message_label.text = "Explore. Find the cache, then gather moonseeds."
			message_label.add_theme_color_override("font_color", Color("fff9e8"))
	if Input.is_action_just_pressed("inventory"):
		toggle_inventory()

func toggle_pause() -> void:
	if title_overlay.visible or inventory_overlay.visible:
		return
	set_game_paused(not get_tree().paused)

func set_game_paused(paused: bool) -> void:
	if not is_instance_valid(pause_overlay):
		return
	if paused:
		_clear_touch_inputs()
	pause_overlay.visible = paused
	get_tree().paused = paused

func _clear_touch_inputs() -> void:
	_end_joystick()
	for action in ["dash", "attack", "skill", "guard", "heal", "interact"]:
		if InputMap.has_action(action):
			Input.action_release(action)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_clear_touch_inputs()

func _on_viewport_resized() -> void:
	_layout_controls()

func _on_deadzone_changed(value: float) -> void:
	joystick_deadzone = value
	deadzone_label.text = "DEAD ZONE  %d%%" % roundi(value * 100.0)
	if joystick_touch_index != -1:
		_update_joystick(joystick_center + joystick_raw_direction * joystick_raw_strength * joystick_radius)

func _on_sensitivity_changed(value: float) -> void:
	joystick_sensitivity = value
	sensitivity_label.text = "SENSITIVITY  %.2f×" % value
	if joystick_touch_index != -1:
		_update_joystick(joystick_center + joystick_raw_direction * joystick_raw_strength * joystick_radius)
