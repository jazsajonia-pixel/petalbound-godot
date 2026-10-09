extends Control

var count_label: Label
var message_label: Label
var hint_label: Label
var dash_button: Button
var pause_button: Button
var pause_overlay: ColorRect
var pause_panel: PanelContainer
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

func setup() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_register_pause_action()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	count_label = _label("MOONSEEDS  0 / 3", Vector2.ZERO, Vector2(300, 36), 22)
	message_label = _label("Find three moonseeds, then reach the shrine.", Vector2.ZERO, Vector2(560, 34), 15)
	hint_label = _label("Left stick to move   •   Space / Shift to dash", Vector2.ZERO, Vector2(580, 28), 13)
	dash_button = _make_button("DASH", Vector2.ZERO, Vector2(120, 78))
	pause_button = _make_button("PAUSE", Vector2.ZERO, Vector2(92, 56), "", 15)
	_make_pause_overlay()
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
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color("fff9e8"))
	label.add_theme_color_override("font_shadow_color", Color("34444b"))
	label.add_theme_constant_override("shadow_offset_x", 2)
	label.add_theme_constant_override("shadow_offset_y", 2)
	add_child(label)
	return label

func _make_button(text: String, pos: Vector2, size: Vector2, action: String = "dash", font_size: int = 18) -> Button:
	var button := Button.new()
	button.text = text
	button.position = pos
	button.size = size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", Color("fff9e8"))
	button.add_theme_color_override("font_hover_color", Color("ffffff"))
	button.add_theme_color_override("font_pressed_color", Color("ffffff"))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.23, 0.27, 0.34, 0.76)
	normal.border_color = Color(0.88, 0.94, 0.85, 0.78)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(16)
	button.add_theme_stylebox_override("normal", normal)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.32, 0.57, 0.51, 0.94)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover", normal)
	if action.is_empty():
		button.pressed.connect(toggle_pause)
	else:
		button.button_down.connect(func(): Input.action_press(action))
		button.button_up.connect(func(): Input.action_release(action))
	add_child(button)
	return button

func _make_pause_overlay() -> void:
	pause_overlay = ColorRect.new()
	pause_overlay.name = "PauseOverlay"
	pause_overlay.color = Color(0.08, 0.13, 0.17, 0.72)
	pause_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_overlay.visible = false
	pause_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(pause_overlay)

	pause_panel = PanelContainer.new()
	pause_panel.size = Vector2(360, 330)
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color("344f53")
	panel_style.border_color = Color("d8e7d8")
	panel_style.set_border_width_all(3)
	panel_style.set_corner_radius_all(18)
	pause_panel.add_theme_stylebox_override("panel", panel_style)
	pause_overlay.add_child(pause_panel)

	var margin := MarginContainer.new()
	for side in ["left", "top", "right", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 22)
	pause_panel.add_child(margin)

	var layout := VBoxContainer.new()
	layout.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_theme_constant_override("separation", 14)
	margin.add_child(layout)

	var title := Label.new()
	title.text = "PAUSED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color("fff5df"))
	layout.add_child(title)

	var resume := Button.new()
	resume.name = "ResumeButton"
	resume.text = "RESUME"
	resume.custom_minimum_size = Vector2(0, 54)
	resume.focus_mode = Control.FOCUS_NONE
	resume.add_theme_font_size_override("font_size", 18)
	resume.add_theme_color_override("font_color", Color("fff9e8"))
	var resume_style := StyleBoxFlat.new()
	resume_style.bg_color = Color("597b72")
	resume_style.border_color = Color("d8e7d8")
	resume_style.set_border_width_all(2)
	resume_style.set_corner_radius_all(12)
	resume.add_theme_stylebox_override("normal", resume_style)
	resume.add_theme_stylebox_override("hover", resume_style)
	var resume_pressed := resume_style.duplicate() as StyleBoxFlat
	resume_pressed.bg_color = Color("6d9586")
	resume.add_theme_stylebox_override("pressed", resume_pressed)
	resume.pressed.connect(func(): set_game_paused(false))
	layout.add_child(resume)

	deadzone_label = Label.new()
	deadzone_label.text = "DEAD ZONE  8%"
	deadzone_label.add_theme_font_size_override("font_size", 13)
	deadzone_label.add_theme_color_override("font_color", Color("e1e6d6"))
	layout.add_child(deadzone_label)
	deadzone_slider = _make_setting_slider(0.0, 0.30, joystick_deadzone, 0.01)
	deadzone_slider.value_changed.connect(_on_deadzone_changed)
	layout.add_child(deadzone_slider)

	sensitivity_label = Label.new()
	sensitivity_label.text = "SENSITIVITY  1.00×"
	sensitivity_label.add_theme_font_size_override("font_size", 13)
	sensitivity_label.add_theme_color_override("font_color", Color("e1e6d6"))
	layout.add_child(sensitivity_label)
	sensitivity_slider = _make_setting_slider(0.60, 1.60, joystick_sensitivity, 0.05)
	sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
	layout.add_child(sensitivity_slider)

	var hint := Label.new()
	hint.text = "Changes apply immediately • Esc / P to resume"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color("e1e6d6"))
	layout.add_child(hint)

func _make_setting_slider(minimum: float, maximum: float, initial: float, step: float) -> HSlider:
	var slider := HSlider.new()
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = step
	slider.value = initial
	slider.custom_minimum_size = Vector2(0, 26)
	slider.focus_mode = Control.FOCUS_NONE
	return slider

func _layout_controls() -> void:
	if not is_instance_valid(count_label) or not is_instance_valid(dash_button) or not is_instance_valid(pause_button):
		return
	safe_rect = _get_safe_rect()
	count_label.position = safe_rect.position + Vector2(14, 10)
	message_label.position = safe_rect.position + Vector2(14, 48)
	hint_label.position = safe_rect.position + Vector2(14, 80)
	pause_button.position = Vector2(safe_rect.end.x - pause_button.size.x - 22, safe_rect.position.y + 14)
	dash_button.position = Vector2(safe_rect.end.x - dash_button.size.x - 22, safe_rect.end.y - dash_button.size.y - 22)
	if is_instance_valid(pause_panel):
		pause_panel.position = safe_rect.position + safe_rect.size * 0.5 - pause_panel.size * 0.5
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
	if right - left < 240.0 or bottom - top < 180.0:
		return Rect2(Vector2(24, 24), Vector2(maxf(1.0, viewport_size.x - 48), maxf(1.0, viewport_size.y - 48)))
	return Rect2(Vector2(left, top), Vector2(right - left, bottom - top))

func _input(event: InputEvent) -> void:
	if get_tree().paused:
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

func set_seed_count(amount: int) -> void:
	if is_instance_valid(count_label):
		count_label.text = "MOONSEEDS  %d / 3" % amount

func show_message(text: String) -> void:
	if is_instance_valid(message_label):
		message_label.text = text
		message_timer = 4.0
		message_label.add_theme_color_override("font_color", Color("fff6c5"))

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("pause"):
		toggle_pause()
	if not get_tree().paused and message_timer > 0.0:
		message_timer -= delta
		if message_timer <= 0.0 and is_instance_valid(message_label):
			message_label.text = "Explore the meadow. Gather three moonseeds."
			message_label.add_theme_color_override("font_color", Color("fff9e8"))

func toggle_pause() -> void:
	set_game_paused(not get_tree().paused)

func set_game_paused(paused: bool) -> void:
	if not is_instance_valid(pause_overlay):
		return
	if paused:
		_end_joystick()
		Input.action_release("dash")
	pause_overlay.visible = paused
	get_tree().paused = paused

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
