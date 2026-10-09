extends Control

var count_label: Label
var message_label: Label
var hint_label: Label
var message_timer := 0.0

func setup() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	count_label = _label("MOONSEEDS  0 / 3", Vector2(22, 16), Vector2(300, 36), 22)
	message_label = _label("Find three moonseeds, then reach the shrine.", Vector2(22, 52), Vector2(560, 34), 15)
	hint_label = _label("WASD / arrows to move   •   Space / Shift to dash", Vector2(22, 86), Vector2(580, 28), 13)
	_make_button("▲", "move_up", Vector2(98, 340), Vector2(76, 66))
	_make_button("◀", "move_left", Vector2(18, 410), Vector2(76, 66))
	_make_button("▼", "move_down", Vector2(98, 410), Vector2(76, 66))
	_make_button("▶", "move_right", Vector2(178, 410), Vector2(76, 66))
	_make_button("DASH", "dash", Vector2(818, 397), Vector2(120, 78))

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

func _make_button(text: String, action: String, pos: Vector2, size: Vector2) -> void:
	var button := Button.new()
	button.text = text
	button.position = pos
	button.size = size
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 22 if text != "DASH" else 18)
	button.add_theme_color_override("font_color", Color("fff9e8"))
	button.add_theme_color_override("font_hover_color", Color("ffffff"))
	button.add_theme_color_override("font_pressed_color", Color("ffffff"))
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.23, 0.27, 0.34, 0.76)
	normal.border_color = Color(0.88, 0.94, 0.85, 0.78)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(12)
	button.add_theme_stylebox_override("normal", normal)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.32, 0.57, 0.51, 0.94)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("hover", normal)
	button.button_down.connect(func(): Input.action_press(action))
	button.button_up.connect(func(): Input.action_release(action))
	add_child(button)

func set_seed_count(amount: int) -> void:
	if is_instance_valid(count_label):
		count_label.text = "MOONSEEDS  %d / 3" % amount

func show_message(text: String) -> void:
	if is_instance_valid(message_label):
		message_label.text = text
		message_timer = 4.0
		message_label.add_theme_color_override("font_color", Color("fff6c5"))

func _process(delta: float) -> void:
	if message_timer > 0.0:
		message_timer -= delta
		if message_timer <= 0.0 and is_instance_valid(message_label):
			message_label.text = "Explore the meadow. Gather three moonseeds."
			message_label.add_theme_color_override("font_color", Color("fff9e8"))
