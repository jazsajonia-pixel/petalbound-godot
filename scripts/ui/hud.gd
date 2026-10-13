extends Control
## Petalbound HUD: hearts/stamina/coins, region banners, boss bar, minimap, quest tracker,
## multi-touch joystick + action buttons, dialogue, shop, inventory, world map, title/pause/settings.

const AnimLib := preload("res://scripts/core/anim_lib.gd")
const DB := preload("res://scripts/data/db.gd")
const Ach := preload("res://scripts/systems/achievements.gd")
const ClassBook := preload("res://scripts/data/classdb.gd")
const QuestSys := preload("res://scripts/systems/quests.gd")
const NA := "res://assets/packs/ninja_adventure/"
const TouchButton := preload("res://scripts/ui/touch_button.gd")
const ControlsScript := preload("res://scripts/ui/combat_controls.gd")
const Screens := preload("res://scripts/ui/build_screens.gd")
const Settings := preload("res://scripts/systems/settings.gd")
const Build := preload("res://scripts/combat/build.gd")
const CD := preload("res://scripts/data/combat_data.gd")

signal start_requested(new_game: bool)
signal retry_requested

const C_PANEL := Color(0.13, 0.10, 0.19, 0.86)
const C_PANEL_LIGHT := Color(0.22, 0.17, 0.30, 0.92)
const C_BORDER := Color(0.96, 0.72, 0.84, 0.95)
const C_TEXT := Color(1.0, 0.96, 0.90)
const C_DIM := Color(0.80, 0.74, 0.86)
const C_GOLD := Color(1.0, 0.84, 0.48)
const C_ROSE := Color(0.96, 0.55, 0.72)

var game: Node
var font: FontFile
var ui_theme: Theme
var heart_tex: Texture2D
var hearts_box: HBoxContainer
var stamina_bar: Control
var coin_label: Label
var tea_label: Label
var seed_icons: Array[TextureRect] = []
var clock_label: Label
var quest_label: Label
var message_label: Label
var message_timer := 0.0
var region_label: Label
var region_sub: Label
var region_t := 0.0
var boss_panel: Control
var boss_name: Label
var boss_bar: ProgressBar
var minimap: Control
var minimap_tex: ImageTexture
var weapon_icon: TextureRect
var weapon_label: Label
var skill_bars: Dictionary = {}
var hint_label: Label

var touch_root: Control
var touch_buttons: Array = []
var touch_held: Dictionary = {}
var attack_button: TouchButton
var dash_button: TouchButton
var jump_button: TouchButton
var mothlight_button: TouchButton
var guard_button: TouchButton
var heal_button: TouchButton
var weapon_button: TouchButton
var interact_button: TouchButton
var sprint_button: TouchButton
var pause_button: Button
var bag_button: Button
var map_button: Button
var show_touch := true
## Persisted preferences (scripts/systems/settings.gd) and the combat controls.
var settings: Dictionary = {}
var controls: Node
var settings_panel: Control
var loadout_slot := 0
var satchel_selected := ""

var pause_overlay: ColorRect
var pause_panel: PanelContainer
var inventory_overlay: ColorRect
var inventory_panel: PanelContainer
var inventory_grid: GridContainer
var inventory_desc: Label
var inventory_stats: Label
var inventory_text: Label
var inventory_detail: VBoxContainer
var inventory_doll: VBoxContainer
var map_overlay: ColorRect
var map_view: Control
var title_overlay: ColorRect
var title_panel: Control
var title_heading: Label
var title_subheading: Label
var title_button: Button
var continue_button: Button
var end_overlay: ColorRect
var end_heading: Label
var end_body: Label
var end_button: Button
var dialogue_panel: PanelContainer
var dialogue_face: TextureRect
var dialogue_name: Label
var dialogue_text: Label
var dialogue_lines: Array = []
var dialogue_index := 0
var dialogue_open := false
var dialogue_chars := 0.0
var shop_overlay: ColorRect
var shop_list: VBoxContainer
var shop_coins: Label
var item_banner: PanelContainer
var item_banner_icon: TextureRect
var item_banner_title: Label
var item_banner_desc: Label
var feat_banner: PanelContainer
var feat_banner_title: Label
var feat_banner_desc: Label
var feats_overlay: ColorRect
var feats_panel: PanelContainer
var feats_list: VBoxContainer
var feats_head_label: Label
var photo_overlay: ColorRect
var photo_row: HBoxContainer
var photo_status: Label
var photo_active := false
var photo_status_t := 0.0
var photo_dragging := false
var photo_saved_visible := {}
## Petal Arts (K), Journeys (H) and the 1-4 skill bar.
var arts_overlay: ColorRect
var arts_panel: PanelContainer
var arts_list: VBoxContainer
var arts_head_label: Label
var journeys_overlay: ColorRect
var journeys_panel: PanelContainer
var journeys_list: VBoxContainer
var journey_label: Label
var arts_button: Button
var skill_row: HBoxContainer
var skill_slots: Array = []
var xp_bar: Control
var focus_bar: Control
var deadzone_slider: HSlider
var sensitivity_slider: HSlider
var music_slider: HSlider
var sfx_slider: HSlider
var deadzone_label: Label
var sensitivity_label: Label
var quality_button: Button
var touch_toggle: Button

var joystick_deadzone := 0.08
var joystick_sensitivity := 1.0
var safe_rect := Rect2(Vector2(12, 12), Vector2(616, 336))
var joystick_home := Vector2(70, 290)
var joystick_center := Vector2(70, 290)
var joystick_vector := Vector2.ZERO
var joystick_raw_direction := Vector2.ZERO
var joystick_raw_strength := 0.0
var joystick_touch_index := -1
var joystick_radius := 38.0
var joystick_knob_radius := 15.0
var _sprint_from_stick := false


func setup(p_game: Node) -> void:
	game = p_game
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = load("res://assets/packs/kenney_fonts/kenney_mini.ttf")
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font.hinting = TextServer.HINTING_NONE
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	heart_tex = AnimLib.tex("ui/heart.png")
	_make_theme()
	show_touch = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
	settings = Settings.load_all()
	match String(settings["touch_controls"]):
		"on":
			show_touch = true
		"off":
			show_touch = false
	_make_status()
	_make_minimap()
	_make_banners()
	_make_touch_controls()
	controls = ControlsScript.new()
	controls.name = "CombatControls"
	add_child(controls)
	controls.setup(self)
	_make_top_buttons()
	_make_dialogue()
	_make_item_banner()
	_make_feat_banner()
	_make_shop()
	_make_inventory_overlay()
	_make_feats_overlay()
	_make_arts_overlay()
	_make_journeys_overlay()
	_make_skill_bar()
	_make_map_overlay()
	_make_pause_overlay()
	_make_photo_overlay()
	_make_end_overlay()
	_make_title_overlay()
	apply_settings()
	_layout_controls()
	resized.connect(_layout_controls)
	get_viewport().size_changed.connect(_layout_controls)


# ------------------------------------------------------------------ styling helpers
func _make_theme() -> void:
	ui_theme = Theme.new()
	ui_theme.default_font = font
	ui_theme.default_font_size = 8
	var btn := _box(C_PANEL_LIGHT, C_BORDER, 1, 3)
	btn.content_margin_left = 8
	btn.content_margin_right = 8
	btn.content_margin_top = 4
	btn.content_margin_bottom = 4
	var hover := btn.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.36, 0.24, 0.42, 0.96)
	var pressed := btn.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.62, 0.32, 0.50, 0.98)
	var disabled := btn.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.16, 0.14, 0.2, 0.7)
	disabled.border_color = Color(0.5, 0.45, 0.55, 0.6)
	ui_theme.set_stylebox("normal", "Button", btn)
	ui_theme.set_stylebox("hover", "Button", hover)
	ui_theme.set_stylebox("pressed", "Button", pressed)
	ui_theme.set_stylebox("disabled", "Button", disabled)
	ui_theme.set_stylebox("focus", "Button", _box(Color(0, 0, 0, 0), C_GOLD, 1, 3))
	ui_theme.set_color("font_color", "Button", C_TEXT)
	ui_theme.set_color("font_hover_color", "Button", Color.WHITE)
	ui_theme.set_color("font_pressed_color", "Button", Color.WHITE)
	ui_theme.set_color("font_disabled_color", "Button", Color(0.6, 0.55, 0.62))
	ui_theme.set_color("font_color", "Label", C_TEXT)
	ui_theme.set_color("font_shadow_color", "Label", Color(0.08, 0.05, 0.12, 0.9))
	ui_theme.set_constant("shadow_offset_x", "Label", 1)
	ui_theme.set_constant("shadow_offset_y", "Label", 1)
	ui_theme.set_constant("line_spacing", "Label", 1)
	ui_theme.set_stylebox("panel", "PanelContainer", _box(C_PANEL, C_BORDER, 1, 4))
	var slider_bg := _box(Color(0.1, 0.08, 0.14, 0.9), Color(0.6, 0.5, 0.65), 1, 2)
	slider_bg.content_margin_top = 2
	slider_bg.content_margin_bottom = 2
	ui_theme.set_stylebox("slider", "HSlider", slider_bg)
	ui_theme.set_stylebox("grabber_area", "HSlider", _box(C_ROSE, C_ROSE, 0, 2))
	ui_theme.set_stylebox("grabber_area_highlight", "HSlider", _box(C_ROSE, C_ROSE, 0, 2))
	ui_theme.set_stylebox("background", "ProgressBar", _box(Color(0.1, 0.06, 0.1, 0.9), Color(0.9, 0.7, 0.8), 1, 2))
	ui_theme.set_stylebox("fill", "ProgressBar", _box(Color(0.9, 0.3, 0.42), Color(0.9, 0.3, 0.42), 0, 2))
	theme = ui_theme


func _box(bg: Color, border: Color, width: int, radius: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.anti_aliasing = false
	s.content_margin_left = 6
	s.content_margin_right = 6
	s.content_margin_top = 4
	s.content_margin_bottom = 4
	return s


func _label(text: String, size := 8, color := C_TEXT, parent: Control = null) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	(parent if parent != null else self).add_child(l)
	return l


func _icon(path: String, size: Vector2, parent: Control) -> TextureRect:
	var t := TextureRect.new()
	t.texture = AnimLib.tex(path)
	t.custom_minimum_size = size
	t.size = size
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(t)
	return t


func _button(text: String, parent: Control, cb: Callable, size := 8) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", size)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _overlay(color := Color(0.05, 0.03, 0.09, 0.6)) -> ColorRect:
	var o := ColorRect.new()
	o.color = color
	o.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.mouse_filter = Control.MOUSE_FILTER_STOP
	o.visible = false
	add_child(o)
	return o


func _centered_panel(parent: Control, min_size: Vector2) -> PanelContainer:
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(cc)
	var p := PanelContainer.new()
	p.custom_minimum_size = min_size
	cc.add_child(p)
	return p


func _vbox(parent: Control, sep := 4) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	parent.add_child(v)
	return v


func _hbox(parent: Control, sep := 4) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	parent.add_child(h)
	return h


# ------------------------------------------------------------------ status
func _make_status() -> void:
	hearts_box = HBoxContainer.new()
	hearts_box.add_theme_constant_override("separation", 0)
	hearts_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hearts_box)
	stamina_bar = StaminaBar.new()
	stamina_bar.hud = self
	stamina_bar.size = Vector2(70, 5)
	add_child(stamina_bar)
	focus_bar = MiniBar.new()
	focus_bar.hud = self
	focus_bar.mode = "focus"
	focus_bar.size = Vector2(70, 4)
	add_child(focus_bar)
	xp_bar = MiniBar.new()
	xp_bar.hud = self
	xp_bar.mode = "xp"
	xp_bar.size = Vector2(70, 4)
	add_child(xp_bar)
	journey_label = _label("", 8, Color(0.82, 0.72, 1.0))
	journey_label.size = Vector2(240, 12)
	var row := _hbox(self, 3)
	row.name = "CounterRow"
	_icon("items/goldcoin.png", Vector2(8, 8), row)
	coin_label = _label("0", 8, C_GOLD, row)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(6, 1)
	row.add_child(sp)
	_icon("items/lifepot.png", Vector2(9, 9), row)
	tea_label = _label("3/3", 8, Color(0.75, 1.0, 0.82), row)
	quest_label = _label("", 8, C_DIM)
	quest_label.size = Vector2(240, 30)
	quest_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var wbox := PanelContainer.new()
	wbox.name = "WeaponBox"
	wbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(wbox)
	var wrow := _hbox(wbox, 4)
	weapon_icon = _icon("items/weapons/katana.png", Vector2(14, 14), wrow)
	var wcol := _vbox(wrow, 0)
	weapon_label = _label("THORNBLADE", 8, C_TEXT, wcol)
	hint_label = _label("Q  SWAP", 8, C_DIM, wcol)
	hint_label.add_theme_font_size_override("font_size", 8)
	message_label = _label("", 8, C_TEXT)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.size = Vector2(400, 12)


func _make_minimap() -> void:
	minimap = Minimap.new()
	minimap.hud = self
	minimap.size = Vector2(92, 64)
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(minimap)
	var seeds_row := _hbox(self, 1)
	seeds_row.name = "SeedRow"
	for i in range(4):
		var t := _icon("items/seedlarge.png", Vector2(10, 10), seeds_row)
		t.modulate = Color(0.25, 0.22, 0.3, 0.8)
		seed_icons.append(t)
	clock_label = _label("08:00", 8, C_DIM, seeds_row)


func build_minimap_texture(biome: Image, field: Image) -> void:
	var w := biome.get_width()
	var h := biome.get_height()
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var cols := [Color("7fc46e"), Color("3f8a5a"), Color("e3c27d"), Color("b9b2d6"), Color("6f9a6a"), Color("f0dfa4"), Color("cbb8f0")]
	var fw := field.get_width() / w
	for y in range(h):
		for x in range(w):
			var b := int(round(biome.get_pixel(x, y).r * 255.0))
			var f := field.get_pixel(x * fw, y * fw)
			var c: Color = cols[clampi(b, 0, 6)]
			if f.g > 0.5:
				c = Color("4fb6d8").lerp(Color("2b6aa8"), f.b)
			elif f.r > 0.5:
				c = c.lerp(Color("c99d66"), 0.55)
			img.set_pixel(x, y, c)
	minimap_tex = ImageTexture.create_from_image(img)


func _make_banners() -> void:
	region_label = _label("", 16, Color(1, 0.95, 0.88))
	region_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	region_label.size = Vector2(400, 20)
	region_label.modulate.a = 0.0
	region_sub = _label("", 8, C_ROSE)
	region_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	region_sub.size = Vector2(400, 12)
	region_sub.modulate.a = 0.0
	boss_panel = VBoxContainer.new()
	boss_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_panel.visible = false
	add_child(boss_panel)
	boss_name = _label("", 8, Color(1, 0.86, 0.8), boss_panel)
	boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_bar = ProgressBar.new()
	boss_bar.custom_minimum_size = Vector2(220, 7)
	boss_bar.show_percentage = false
	boss_panel.add_child(boss_bar)


# ------------------------------------------------------------------ touch controls
func _make_touch_controls() -> void:
	touch_root = Control.new()
	touch_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	touch_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(touch_root)
	attack_button = _touch("attack", "items/weapons/katana.png", 27.0, Color(0.95, 0.45, 0.6))
	dash_button = _touch("dash", "ui/skill/boot.png", 16.0, Color(0.55, 0.75, 0.95))
	jump_button = _touch("jump", "ui/skill/arrow.png", 13.0, Color(0.6, 0.9, 0.75))
	heal_button = _touch("heal", "items/lifepot.png", 13.0, Color(0.6, 1.0, 0.7))
	weapon_button = _touch("switch_weapon", "items/weapons/magicwand.png", 12.0, Color(0.8, 0.8, 0.9))
	interact_button = _touch("interact", "ui/skill/talk.png", 15.0, Color(1.0, 0.9, 0.6))
	sprint_button = _touch("sprint", "ui/skill/punch.png", 12.0, Color(0.95, 0.75, 0.55))
	interact_button.visible = false


func _touch(action: String, icon: String, radius: float, color: Color) -> TouchButton:
	var b := TouchButton.new()
	b.action = action
	b.id = action
	b.icon = AnimLib.tex(icon)
	b.radius = radius
	b.base_radius = radius
	b.tint = color
	b.size = Vector2(radius * 2.0, radius * 2.0)
	b.theme = ui_theme
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	touch_root.add_child(b)
	touch_buttons.append(b)
	return b


func _make_top_buttons() -> void:
	pause_button = _button("II", self, toggle_pause)
	pause_button.custom_minimum_size = Vector2(22, 18)
	bag_button = _button("BAG", self, toggle_inventory)
	bag_button.custom_minimum_size = Vector2(32, 18)
	map_button = _button("MAP", self, toggle_map)
	map_button.custom_minimum_size = Vector2(32, 18)
	arts_button = _button("ARTS", self, toggle_arts)
	arts_button.custom_minimum_size = Vector2(32, 18)


# ------------------------------------------------------------------ dialogue, item get, shop
func _make_dialogue() -> void:
	dialogue_panel = PanelContainer.new()
	dialogue_panel.visible = false
	dialogue_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	dialogue_panel.gui_input.connect(_on_dialogue_gui)
	add_child(dialogue_panel)
	var row := _hbox(dialogue_panel, 8)
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", _box(Color(0.32, 0.22, 0.38), C_GOLD, 1, 3))
	row.add_child(frame)
	dialogue_face = TextureRect.new()
	dialogue_face.custom_minimum_size = Vector2(38, 38)
	dialogue_face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	dialogue_face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	dialogue_face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	frame.add_child(dialogue_face)
	var col := _vbox(row, 3)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dialogue_name = _label("", 8, C_GOLD, col)
	dialogue_text = _label("", 8, C_TEXT, col)
	dialogue_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_text.custom_minimum_size = Vector2(300, 30)
	dialogue_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var more := _label("E / TAP", 8, C_DIM, col)
	more.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


func _make_item_banner() -> void:
	item_banner = PanelContainer.new()
	item_banner.visible = false
	item_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	item_banner.add_theme_stylebox_override("panel", _box(Color(0.18, 0.12, 0.24, 0.94), C_GOLD, 1, 4))
	add_child(item_banner)
	var row := _hbox(item_banner, 8)
	item_banner_icon = _icon("items/heart.png", Vector2(24, 24), row)
	var col := _vbox(row, 2)
	item_banner_title = _label("", 8, C_GOLD, col)
	item_banner_desc = _label("", 8, C_TEXT, col)
	item_banner_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	item_banner_desc.custom_minimum_size = Vector2(210, 10)


func _make_feat_banner() -> void:
	feat_banner = PanelContainer.new()
	feat_banner.visible = false
	feat_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	feat_banner.add_theme_stylebox_override("panel", _box(Color(0.20, 0.12, 0.22, 0.94), C_ROSE, 1, 4))
	add_child(feat_banner)
	var row := _hbox(feat_banner, 8)
	_icon("ui/skill/scroll.png", Vector2(20, 20), row)
	var col := _vbox(row, 2)
	feat_banner_title = _label("", 8, C_ROSE, col)
	feat_banner_desc = _label("", 8, C_TEXT, col)
	feat_banner_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	feat_banner_desc.custom_minimum_size = Vector2(210, 10)


func show_achievement(id: String) -> void:
	var def := Ach.def_of(id)
	if def.is_empty():
		return
	feat_banner_title.text = "FEAT UNLOCKED!"
	feat_banner_desc.text = "%s — %s" % [def["name"], def["desc"]]
	feat_banner.visible = true
	feat_banner.modulate = Color(1, 1, 1, 0)
	feat_banner.scale = Vector2(0.85, 0.85)
	var tw := create_tween().set_parallel()
	tw.tween_property(feat_banner, "modulate:a", 1.0, 0.25)
	tw.tween_property(feat_banner, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(3.0)
	tw.chain().tween_property(feat_banner, "modulate:a", 0.0, 0.4)
	tw.chain().tween_callback(func() -> void: feat_banner.visible = false)


func _make_shop() -> void:
	shop_overlay = _overlay()
	var p := _centered_panel(shop_overlay, Vector2(300, 0))
	var v := _vbox(p, 5)
	var head := _hbox(v, 6)
	_label("PROVISIONS", 16, C_GOLD, head)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	_icon("items/goldcoin.png", Vector2(8, 8), head)
	shop_coins = _label("0", 8, C_GOLD, head)
	shop_list = _vbox(v, 3)
	_button("LEAVE", v, close_shop)


func open_shop(stock: Array) -> void:
	for c in shop_list.get_children():
		c.queue_free()
	for entry in stock:
		var id: String = entry["id"]
		var item: Dictionary = DB.ITEMS[id]
		var row := _hbox(shop_list, 6)
		_icon(item["icon"], Vector2(14, 14), row)
		var nm: String = item["name"]
		if not Build.item_classes(id).is_empty():
			nm += "  (" + Build.requirement_text(id) + ")"
		var l := _label(nm, 8, DB.RARITY_COLORS.get(item.get("rarity", "common"), C_TEXT), row)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.custom_minimum_size = Vector2(150, 0)
		var b := _button("%d" % entry["price"], row, func() -> void: game.buy_item(entry))
		b.icon = AnimLib.tex("items/goldcoin.png")
		b.custom_minimum_size = Vector2(54, 16)
		b.disabled = not game.can_buy(entry)
	shop_coins.text = str(game.player.petalcoins)
	shop_overlay.visible = true
	_clear_touch_inputs()


func close_shop() -> void:
	shop_overlay.visible = false


func refresh_shop(stock: Array) -> void:
	if shop_overlay.visible:
		open_shop(stock)


# ------------------------------------------------------------------ inventory
func _make_inventory_overlay() -> void:
	inventory_overlay = _overlay()
	inventory_panel = _centered_panel(inventory_overlay, Vector2(470, 0))
	var v := _vbox(inventory_panel, 5)
	var head := _hbox(v, 6)
	_label("SATCHEL", 16, C_GOLD, head)
	_label("tap an item to inspect and compare", 8, C_DIM, head)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	_button("FEATS", head, toggle_feats)
	_button("CLOSE", head, toggle_inventory)
	var body := _hbox(v, 8)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(212, 262)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var left := _vbox(scroll, 4)
	inventory_grid = GridContainer.new()
	inventory_grid.columns = 7
	inventory_grid.add_theme_constant_override("h_separation", 3)
	inventory_grid.add_theme_constant_override("v_separation", 3)
	left.add_child(inventory_grid)
	inventory_detail = _vbox(left, 2)
	inventory_desc = _label("", 8, C_TEXT, left)
	var rscroll := ScrollContainer.new()
	rscroll.custom_minimum_size = Vector2(230, 262)
	rscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(rscroll)
	inventory_doll = _vbox(rscroll, 2)
	inventory_stats = _label("", 8, C_TEXT, left)
	inventory_stats.visible = false
	inventory_text = inventory_stats


func _refresh_inventory() -> void:
	Screens.refresh_inventory(self)


func _on_inventory_item(id: String) -> void:
	satchel_selected = id
	_refresh_inventory()


func toggle_inventory() -> void:
	if title_overlay.visible or end_overlay.visible or pause_overlay.visible:
		return
	if feats_overlay.visible:
		toggle_feats()
	if arts_overlay.visible:
		toggle_arts()
	if journeys_overlay.visible:
		toggle_journeys()
	inventory_overlay.visible = not inventory_overlay.visible
	if inventory_overlay.visible:
		_clear_touch_inputs()
		_refresh_inventory()
	game.set_menu_pause(menus_pausing())


# ------------------------------------------------------------------ feats
func _make_feats_overlay() -> void:
	feats_overlay = _overlay()
	feats_panel = _centered_panel(feats_overlay, Vector2(430, 0))
	var v := _vbox(feats_panel, 5)
	var head := _hbox(v, 6)
	feats_head_label = _label("FEATS", 16, C_GOLD, head)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	_button("CLOSE", head, toggle_feats)
	feats_list = _vbox(v, 2)


func toggle_feats() -> void:
	if title_overlay.visible or end_overlay.visible or pause_overlay.visible:
		return
	feats_overlay.visible = not feats_overlay.visible
	if feats_overlay.visible:
		_clear_touch_inputs()
		_refresh_feats()
	game.set_menu_pause(menus_pausing())


func _refresh_feats() -> void:
	for c in feats_list.get_children():
		c.queue_free()
	feats_head_label.text = "FEATS  %d / %d" % [game.achievements.size(), Ach.DEFS.size()]
	for id in Ach.DEFS:
		var def: Dictionary = Ach.DEFS[id]
		if game.achievements.has(id):
			_label("✿  %s — %s" % [def["name"], def["desc"]], 8, C_GOLD, feats_list)
		else:
			var l := _label("·  %s — %s" % [def["name"], def["desc"]], 8, C_DIM, feats_list)
			l.modulate.a = 0.55


# ------------------------------------------------------------------ petal arts (K)
func _make_arts_overlay() -> void:
	arts_overlay = _overlay()
	arts_panel = _centered_panel(arts_overlay, Vector2(490, 0))
	var v := _vbox(arts_panel, 5)
	var head := _hbox(v, 6)
	arts_head_label = _label("PETAL ARTS", 16, C_GOLD, head)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	_button("CLOSE", head, toggle_arts)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(470, 270)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	arts_list = _vbox(scroll, 3)
	arts_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func toggle_arts() -> void:
	if title_overlay.visible or end_overlay.visible or pause_overlay.visible:
		return
	if inventory_overlay.visible:
		toggle_inventory()
	if map_overlay.visible:
		toggle_map()
	if feats_overlay.visible:
		toggle_feats()
	if journeys_overlay.visible:
		toggle_journeys()
	arts_overlay.visible = not arts_overlay.visible
	if arts_overlay.visible:
		_clear_touch_inputs()
		_refresh_arts()
	game.set_menu_pause(menus_pausing())


func _refresh_arts() -> void:
	Screens.refresh_arts(self)


## Open the arts page with a slot preselected (tapping an empty art button).
func open_loadout(slot: int) -> void:
	_clear_touch_inputs()
	loadout_slot = clampi(slot, 0, 3)
	if not arts_overlay.visible:
		toggle_arts()
	else:
		_refresh_arts()


# ------------------------------------------------------------------ journeys (H)
func _make_journeys_overlay() -> void:
	journeys_overlay = _overlay()
	journeys_panel = _centered_panel(journeys_overlay, Vector2(400, 0))
	var v := _vbox(journeys_panel, 5)
	var head := _hbox(v, 6)
	_label("JOURNEYS", 16, C_GOLD, head)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	_button("CLOSE", head, toggle_journeys)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(370, 220)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	journeys_list = _vbox(scroll, 4)


func toggle_journeys() -> void:
	if title_overlay.visible or end_overlay.visible or pause_overlay.visible:
		return
	if inventory_overlay.visible:
		toggle_inventory()
	if map_overlay.visible:
		toggle_map()
	if feats_overlay.visible:
		toggle_feats()
	if arts_overlay.visible:
		toggle_arts()
	journeys_overlay.visible = not journeys_overlay.visible
	if journeys_overlay.visible:
		_clear_touch_inputs()
		_refresh_journeys()
	game.set_menu_pause(menus_pausing())


func _refresh_journeys() -> void:
	for c in journeys_list.get_children():
		c.queue_free()
	var done := 0
	for q in QuestSys.QUESTS:
		var e: Dictionary = QuestSys.entry(game.quests, q["id"])
		var line := ""
		var col := C_DIM
		match int(e["s"]):
			QuestSys.STATE_AVAILABLE:
				line = "·  %s — %s" % [q["name"], q["desc"]]
				col = Color(0.62, 0.60, 0.68)
			QuestSys.STATE_ACTIVE:
				line = "▶  %s — %s (%d/%d)" % [q["name"], q["desc"], e["n"], q["goal"]]
				col = C_GOLD
			QuestSys.STATE_DONE:
				line = "✿  %s — done! Report back to %s." % [q["name"], q["giver"].capitalize()]
				col = Color(0.78, 1.0, 0.85)
			_:
				line = "✓  %s — %s" % [q["name"], q["desc"]]
				col = Color(0.58, 0.78, 0.62)
				done += 1
		var l := _label(line, 8, col, journeys_list)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(340, 10)
	_label("Journeys %d / %d claimed. Givers: Alder, Mira, Kit, Kaede, Lumen, Sora." % [done, QuestSys.QUESTS.size()], 8, C_DIM, journeys_list)


# ------------------------------------------------------------------ skill bar (1-4)
func _make_skill_bar() -> void:
	skill_row = _hbox(self, 3)
	skill_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in range(4):
		var panel := PanelContainer.new()
		panel.custom_minimum_size = Vector2(26, 30)
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_theme_stylebox_override("panel", _box(Color(0.10, 0.07, 0.15, 0.85), Color(0.55, 0.46, 0.62), 1, 3))
		var v := _vbox(panel, 0)
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(16, 16)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		v.add_child(icon)
		var cd := _label(str(i + 1), 7, C_GOLD, v)
		cd.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		skill_row.add_child(panel)
		skill_slots.append({"panel": panel, "icon": icon, "cd": cd, "key": str(i + 1)})


func _refresh_skill_bar() -> void:
	var p: Node = game.player
	for i in range(4):
		var s: Dictionary = skill_slots[i]
		if i < p.skill_bar.size():
			var sid: String = p.skill_bar[i]
			var def: Dictionary = ClassBook.skill_of(sid)
			s["panel"].visible = true
			if def.is_empty():
				s["icon"].texture = null
				s["cd"].text = s["key"]
				s["panel"].modulate = Color(0.55, 0.55, 0.6, 0.55)
				continue
			s["icon"].texture = AnimLib.tex(def["icon"])
			var cdv := float(p.skill_cd.get(sid, 0.0))
			if cdv > 0.05:
				s["cd"].text = "%.0f" % ceilf(cdv)
				s["panel"].modulate = Color(0.6, 0.6, 0.66, 1.0)
			elif p.focus < int(def["cost"]):
				s["cd"].text = s["key"]
				s["panel"].modulate = Color(0.55, 0.55, 0.6, 0.55)
			else:
				s["cd"].text = s["key"]
				s["panel"].modulate = Color(1, 1, 1, 1)
		else:
			s["panel"].visible = false


# ------------------------------------------------------------------ map
func _make_map_overlay() -> void:
	map_overlay = _overlay(Color(0.04, 0.03, 0.08, 0.82))
	map_view = WorldMapView.new()
	map_view.hud = self
	map_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	map_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_overlay.add_child(map_view)
	var close := _button("CLOSE", map_overlay, toggle_map)
	close.name = "MapClose"


func toggle_map() -> void:
	if title_overlay.visible or end_overlay.visible or pause_overlay.visible:
		return
	if feats_overlay.visible:
		toggle_feats()
	if arts_overlay.visible:
		toggle_arts()
	if journeys_overlay.visible:
		toggle_journeys()
	map_overlay.visible = not map_overlay.visible
	if map_overlay.visible:
		_clear_touch_inputs()
		map_view.queue_redraw()
	game.set_menu_pause(menus_pausing())


# ------------------------------------------------------------------ pause / settings
func _make_pause_overlay() -> void:
	pause_overlay = _overlay()
	pause_panel = _centered_panel(pause_overlay, Vector2(330, 0))
	var v := _vbox(pause_panel, 4)
	var head := _hbox(v, 6)
	var t := _label("PAUSED", 16, C_GOLD, head)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	var resume := _button("RESUME", head, func() -> void: set_game_paused(false))
	resume.name = "ResumeButton"
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(310, 220)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var body := _vbox(scroll, 3)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# --- controls
	_label("CONTROLS", 8, C_GOLD, body)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 3)
	body.add_child(grid)
	_label("JOYSTICK", 8, C_TEXT, grid)
	_choice(grid, "joystick_mode", ["floating", "fixed"], ["FLOATING", "FIXED"])
	deadzone_label = _label("DEAD ZONE  %d%%" % roundi(float(settings["joystick_deadzone"]) * 100.0), 8, C_TEXT, grid)
	deadzone_slider = _slider(0.0, 0.35, float(settings["joystick_deadzone"]), 0.01, grid)
	deadzone_slider.value_changed.connect(_on_deadzone_changed)
	sensitivity_label = _label("SENSITIVITY  %.2fx" % float(settings["joystick_sensitivity"]), 8, C_TEXT, grid)
	sensitivity_slider = _slider(0.6, 1.8, float(settings["joystick_sensitivity"]), 0.05, grid)
	sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
	_label("TOUCH CONTROLS", 8, C_TEXT, grid)
	touch_toggle = _choice(grid, "touch_controls", ["auto", "on", "off"], ["AUTO", "ON", "OFF"])
	_setting_slider(grid, "HUD SCALE", "hud_scale", 0.75, 1.3, 0.05, true)
	_setting_slider(grid, "BUTTON SIZE", "button_size", 0.8, 1.35, 0.05, true)
	_setting_slider(grid, "HUD OPACITY", "hud_opacity", 0.3, 1.0, 0.05, true)
	var erow := _hbox(body, 4)
	_button("EDIT HUD LAYOUT", erow, func() -> void: controls.start_edit())
	_button("RESET LAYOUT", erow, func() -> void:
		controls.reset_layout()
		_sync_settings_widgets())
	# --- combat
	_label("COMBAT", 8, C_GOLD, body)
	var g2 := GridContainer.new()
	g2.columns = 2
	g2.add_theme_constant_override("h_separation", 8)
	g2.add_theme_constant_override("v_separation", 3)
	body.add_child(g2)
	_label("AUTO-TARGET", 8, C_TEXT, g2)
	_toggle(g2, "auto_target")
	_label("AIM ASSIST", 8, C_TEXT, g2)
	_toggle(g2, "aim_assist")
	_setting_slider(g2, "ATTACK AREA", "attack_indicator", 0.0, 1.0, 0.05, false)
	_label("DAMAGE NUMBERS", 8, C_TEXT, g2)
	_toggle(g2, "damage_numbers")
	# --- audio & video
	_label("AUDIO & VIDEO", 8, C_GOLD, body)
	var g3 := GridContainer.new()
	g3.columns = 2
	g3.add_theme_constant_override("h_separation", 8)
	g3.add_theme_constant_override("v_separation", 3)
	body.add_child(g3)
	_label("MUSIC", 8, C_TEXT, g3)
	music_slider = _slider(0.0, 1.0, float(settings["music_volume"]), 0.05, g3)
	music_slider.value_changed.connect(func(x: float) -> void:
		settings["music_volume"] = x
		apply_settings()
		save_settings())
	_label("EFFECTS", 8, C_TEXT, g3)
	sfx_slider = _slider(0.0, 1.0, float(settings["sfx_volume"]), 0.05, g3)
	sfx_slider.value_changed.connect(func(x: float) -> void:
		settings["sfx_volume"] = x
		apply_settings()
		save_settings())
	_setting_slider(g3, "SCREEN SHAKE", "screen_shake", 0.0, 1.0, 0.1, false)
	_setting_slider(g3, "FX INTENSITY", "fx_intensity", 0.25, 1.0, 0.05, false)
	_label("LIGHTING", 8, C_TEXT, g3)
	quality_button = _choice(g3, "quality_high", [true, false], ["HIGH", "LOW (FAST)"])
	_label("Settings save automatically.", 8, C_DIM, body)
	var row2 := _hbox(v, 4)
	_button("PHOTO MODE", row2, func() -> void:
		set_game_paused(false)
		toggle_photo_mode())
	_button("SAVE", row2, func() -> void:
		game.save_game()
		show_message("Journey saved."))
	_button("SAVE & TITLE", row2, func() -> void:
		game.save_game()
		set_game_paused(false)
		game.return_to_title())


var _setting_widgets: Array = []


## Cycling choice button bound to a settings key.
func _choice(parent: Control, key: String, values: Array, labels: Array) -> Button:
	var b := _button("", parent, func() -> void: pass)
	var refresh := func() -> void:
		var i := values.find(settings[key])
		b.text = labels[maxi(0, i)]
	b.pressed.connect(func() -> void:
		var i := values.find(settings[key])
		settings[key] = values[(i + 1) % values.size()]
		refresh.call()
		apply_settings()
		_layout_controls()
		save_settings())
	refresh.call()
	_setting_widgets.append(refresh)
	return b


func _toggle(parent: Control, key: String) -> Button:
	return _choice(parent, key, [true, false], ["ON", "OFF"])


func _setting_slider(parent: Control, title: String, key: String, mn: float, mx: float, step: float, relayout: bool) -> HSlider:
	var l := _label("%s  %d%%" % [title, roundi(float(settings[key]) * 100.0)], 8, C_TEXT, parent)
	var sl := _slider(mn, mx, float(settings[key]), step, parent)
	sl.value_changed.connect(func(x: float) -> void:
		settings[key] = x
		l.text = "%s  %d%%" % [title, roundi(x * 100.0)]
		apply_settings()
		if relayout:
			_layout_controls()
		save_settings())
	_setting_widgets.append(func() -> void:
		sl.set_value_no_signal(float(settings[key]))
		l.text = "%s  %d%%" % [title, roundi(float(settings[key]) * 100.0)])
	return sl


func _sync_settings_widgets() -> void:
	for f in _setting_widgets:
		f.call()


## Push settings into the systems that use them.
func apply_settings() -> void:
	joystick_deadzone = float(settings["joystick_deadzone"])
	joystick_sensitivity = float(settings["joystick_sensitivity"])
	match String(settings["touch_controls"]):
		"on":
			show_touch = true
		"off":
			show_touch = false
		_:
			show_touch = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
	if game == null:
		return
	if game.get("fx") != null:
		game.fx.intensity = float(settings["fx_intensity"])
		game.fx.shake_scale = float(settings["screen_shake"])
		game.fx.numbers_enabled = bool(settings["damage_numbers"])
	if game.get("audio") != null:
		game.audio.music_volume = float(settings["music_volume"])
		game.audio.sfx_volume = float(settings["sfx_volume"])
		game.audio.apply_volumes()
	if game.get("environment") != null and game.environment.quality_high != bool(settings["quality_high"]):
		game.environment.set_quality(bool(settings["quality_high"]))
	if game.get("player") != null:
		game.player.auto_target_enabled = bool(settings["auto_target"])
		game.player.aim_assist = bool(settings["aim_assist"])
		game.player.attack_indicator_opacity = float(settings["attack_indicator"])
		if not game.player.auto_target_enabled:
			game.player.current_target = null
	for b in touch_buttons:
		b.opacity = float(settings["hud_opacity"])


func save_settings() -> void:
	Settings.save_all(settings)


func _slider(minimum: float, maximum: float, initial: float, step: float, parent: Control) -> HSlider:
	var s := HSlider.new()
	s.min_value = minimum
	s.max_value = maximum
	s.step = step
	s.value = initial
	s.focus_mode = Control.FOCUS_NONE
	s.custom_minimum_size = Vector2(120, 12)
	parent.add_child(s)
	return s


func toggle_pause() -> void:
	if title_overlay.visible or end_overlay.visible:
		return
	if photo_active:
		_exit_photo_mode()
		return
	if inventory_overlay.visible:
		toggle_inventory()
		return
	if map_overlay.visible:
		toggle_map()
		return
	if feats_overlay.visible:
		toggle_feats()
		return
	if arts_overlay.visible:
		toggle_arts()
		return
	if journeys_overlay.visible:
		toggle_journeys()
		return
	if shop_overlay.visible:
		close_shop()
		return
	set_game_paused(not get_tree().paused)


func set_game_paused(paused: bool) -> void:
	if paused:
		_clear_touch_inputs()
	pause_overlay.visible = paused
	if paused:
		_sync_settings_widgets()
	get_tree().paused = paused


# ------------------------------------------------------------------ photo mode
func _make_photo_overlay() -> void:
	photo_overlay = _overlay(Color(0, 0, 0, 0))
	photo_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	photo_row = _hbox(photo_overlay, 4)
	photo_row.set_anchors_preset(Control.PRESET_CENTER_TOP)
	photo_row.mouse_filter = Control.MOUSE_FILTER_STOP
	photo_row.visible = false
	_button("ZOOM −", photo_row, func() -> void: _photo_zoom(0.82))
	_button("ZOOM +", photo_row, func() -> void: _photo_zoom(1.22))
	_button("CAPTURE", photo_row, _capture_photo)
	_button("EXIT", photo_row, func() -> void: toggle_photo_mode())
	photo_status = _label("drag to pan", 8, C_TEXT, photo_overlay)


func toggle_photo_mode() -> void:
	if photo_active:
		_exit_photo_mode()
		return
	if title_overlay.visible or end_overlay.visible or not game.game_started:
		return
	_enter_photo_mode()


func _enter_photo_mode() -> void:
	if photo_active or not game.game_started:
		return
	photo_active = true
	photo_dragging = false
	photo_saved_visible.clear()
	for n in get_children():
		if not n is CanvasItem:
			continue
		photo_saved_visible[n] = n.visible
		if n != photo_overlay:
			n.visible = false
	photo_overlay.visible = true
	photo_row.visible = true
	photo_status.text = "drag to pan"
	_clear_touch_inputs()
	game.set_menu_pause(true)


func _exit_photo_mode() -> void:
	if not photo_active:
		return
	photo_active = false
	photo_dragging = false
	for n in photo_saved_visible.keys():
		if is_instance_valid(n):
			n.visible = photo_saved_visible[n]
	photo_saved_visible.clear()
	photo_row.visible = false
	photo_overlay.visible = false
	game.camera.zoom = Vector2(game.CAMERA_ZOOM, game.CAMERA_ZOOM)
	game.camera.reset_smoothing()
	game.set_menu_pause(false)


func _photo_zoom(k: float) -> void:
	if not photo_active:
		return
	var z := clampf(game.camera.zoom.x * k, 0.55, 4.0)
	game.camera.zoom = Vector2(z, z)


func _capture_photo() -> void:
	if not photo_active:
		return
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("user://photos")
	var fname := "petalbound_%d.png" % Time.get_unix_time_from_system()
	img.save_png("user://photos/" + fname)
	photo_status.text = "saved: " + fname
	photo_status_t = 2.5
	game.audio.play("menu5", 0.02, -6.0)


# ------------------------------------------------------------------ title / end
func _make_title_overlay() -> void:
	title_overlay = _overlay(Color(0.06, 0.04, 0.10, 0.25))
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_overlay.add_child(cc)
	title_panel = VBoxContainer.new()
	title_panel.add_theme_constant_override("separation", 6)
	cc.add_child(title_panel)
	title_heading = _label("PETALBOUND", 32, Color(1.0, 0.86, 0.92), title_panel)
	title_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_heading.add_theme_color_override("font_shadow_color", Color(0.45, 0.16, 0.36))
	title_heading.add_theme_constant_override("shadow_offset_x", 2)
	title_heading.add_theme_constant_override("shadow_offset_y", 2)
	title_subheading = _label("Return the four Moonseeds. Wake the Moonwell.", 8, C_TEXT, title_panel)
	title_subheading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(1, 8)
	title_panel.add_child(spacer)
	continue_button = _button("CONTINUE JOURNEY", title_panel, func() -> void: start_requested.emit(false))
	title_button = _button("NEW JOURNEY", title_panel, func() -> void: start_requested.emit(true))
	for b in [continue_button, title_button]:
		b.custom_minimum_size = Vector2(150, 20)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var keys := _label("WASD move  SHIFT sprint  SPACE roll  C jump  J attack\nF mothlight  G guard  R moontea  Q swap  E talk  I bag  M map\nK petal arts  1-4 arts  H journeys  F9 photo", 8, C_DIM, title_panel)
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func show_title_menu(has_save: bool) -> void:
	title_overlay.visible = true
	continue_button.visible = has_save
	_clear_touch_inputs()


func hide_title_menu() -> void:
	title_overlay.visible = false


func _make_end_overlay() -> void:
	end_overlay = _overlay(Color(0.05, 0.03, 0.09, 0.55))
	var p := _centered_panel(end_overlay, Vector2(300, 120))
	var v := _vbox(p, 6)
	end_heading = _label("", 16, C_GOLD, v)
	end_heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_body = _label("", 8, C_TEXT, v)
	end_body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	end_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	end_button = _button("RISE AGAIN", v, func() -> void:
		end_overlay.visible = false
		retry_requested.emit())


func show_game_over(message := "The petals fall... but the waystone remembers you.") -> void:
	end_heading.text = "MALLOW FALLS"
	end_body.text = message
	end_button.text = "RISE AT WAYSTONE"
	end_overlay.visible = true
	_clear_touch_inputs()


func show_victory(message := "The Moonwell blooms again. Colour returns to every petal in the valley.") -> void:
	end_heading.text = "THE MOONWELL WAKES"
	end_body.text = message
	end_button.text = "KEEP EXPLORING"
	end_overlay.visible = true
	_clear_touch_inputs()


# ------------------------------------------------------------------ public api
func show_message(text: String, duration := 3.0) -> void:
	message_label.text = text
	message_timer = duration
	message_label.modulate.a = 1.0


func show_region(name: String, sub := "") -> void:
	region_label.text = name.to_upper()
	region_sub.text = sub
	region_t = 3.2


func show_item_get(id: String) -> void:
	var item: Dictionary = DB.ITEMS[id]
	item_banner_icon.texture = AnimLib.tex(item["icon"])
	item_banner_title.text = String(item["name"]).to_upper()
	item_banner_desc.text = item["desc"]
	item_banner.visible = true
	item_banner.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(item_banner, "modulate:a", 1.0, 0.2)
	tw.tween_interval(2.6)
	tw.tween_property(item_banner, "modulate:a", 0.0, 0.4)
	tw.tween_callback(func() -> void: item_banner.visible = false)


func show_boss(boss: Node) -> void:
	boss_panel.visible = true
	boss_name.text = boss.title
	boss_bar.max_value = boss.max_hp
	boss_bar.value = boss.hp


func hide_boss() -> void:
	boss_panel.visible = false


func set_interact_visible(visible_now: bool, label := "") -> void:
	interact_button.visible = visible_now
	interact_button.label = label


func set_seed_count(amount: int, total := 4) -> void:
	for i in range(seed_icons.size()):
		seed_icons[i].modulate = Color(1, 1, 1, 1) if i < amount else Color(0.25, 0.22, 0.3, 0.8)
		seed_icons[i].visible = i < total


func start_dialogue(speaker: String, face: Texture2D, lines: Array) -> void:
	dialogue_lines = lines.duplicate()
	dialogue_index = 0
	dialogue_name.text = speaker
	dialogue_face.texture = face
	dialogue_panel.visible = true
	dialogue_open = true
	_clear_touch_inputs()
	_show_line()


func _show_line() -> void:
	while dialogue_index < dialogue_lines.size() and String(dialogue_lines[dialogue_index]).begins_with("@"):
		var cmd := String(dialogue_lines[dialogue_index]).substr(1)
		dialogue_index += 1
		game.on_dialogue_command(cmd)
		if cmd == "shop":
			end_dialogue()
			return
	if dialogue_index >= dialogue_lines.size():
		end_dialogue()
		return
	dialogue_text.text = dialogue_lines[dialogue_index]
	dialogue_text.visible_characters = 0
	dialogue_chars = 0.0
	game.audio.play("voice1", 0.12, -12.0)


func advance_dialogue() -> void:
	if not dialogue_open:
		return
	if dialogue_text.visible_characters >= 0 and dialogue_text.visible_characters < dialogue_text.text.length():
		dialogue_text.visible_characters = -1
		return
	dialogue_index += 1
	_show_line()


func end_dialogue() -> void:
	dialogue_open = false
	dialogue_panel.visible = false
	game.on_dialogue_closed()


func _on_dialogue_gui(event: InputEvent) -> void:
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventScreenTouch and event.pressed):
		advance_dialogue()
		accept_event()


## True while any overlay that pauses the world is open.
func menus_pausing() -> bool:
	return inventory_overlay.visible or map_overlay.visible or feats_overlay.visible or arts_overlay.visible or journeys_overlay.visible or (controls != null and controls.edit_active)


func any_menu_open() -> bool:
	return (controls != null and controls.edit_active) or title_overlay.visible or pause_overlay.visible or inventory_overlay.visible or map_overlay.visible or end_overlay.visible or shop_overlay.visible or dialogue_open or feats_overlay.visible or arts_overlay.visible or journeys_overlay.visible or photo_active


# ------------------------------------------------------------------ layout
func _layout_controls() -> void:
	if not is_instance_valid(hearts_box):
		return
	var vs := get_viewport_rect().size
	if size != vs:
		position = Vector2.ZERO
		size = vs
	safe_rect = _get_safe_rect()
	(map_overlay.get_node("MapClose") as Control).position = Vector2(safe_rect.end.x - 50, safe_rect.position.y + 4)
	var tl := safe_rect.position
	var tr := Vector2(safe_rect.end.x, safe_rect.position.y)
	hearts_box.position = tl
	stamina_bar.position = tl + Vector2(1, 17)
	focus_bar.position = tl + Vector2(1, 24)
	xp_bar.position = tl + Vector2(1, 30)
	var counters := get_node("CounterRow") as Control
	counters.position = tl + Vector2(0, 37)
	quest_label.position = tl + Vector2(0, 51)
	journey_label.position = tl + Vector2(0, 85)
	skill_row.position = Vector2(safe_rect.position.x + 4, safe_rect.end.y - 36)
	minimap.position = tr + Vector2(-minimap.size.x, 0)
	var seed_row := get_node("SeedRow") as Control
	seed_row.position = minimap.position + Vector2(0, minimap.size.y + 3)
	pause_button.position = minimap.position + Vector2(-26, 0)
	map_button.position = minimap.position + Vector2(-36, 21)
	bag_button.position = minimap.position + Vector2(-36, 42)
	arts_button.position = minimap.position + Vector2(-36, 63)
	var wbox := get_node("WeaponBox") as Control
	wbox.position = Vector2(safe_rect.end.x - 92, safe_rect.position.y + 84)
	message_label.position = Vector2(safe_rect.get_center().x - 200, safe_rect.end.y - 62)
	region_label.position = Vector2(safe_rect.get_center().x - 200, safe_rect.position.y + 50)
	region_sub.position = region_label.position + Vector2(0, 20)
	boss_panel.position = Vector2(safe_rect.get_center().x - 110, safe_rect.end.y - 26)
	dialogue_panel.position = Vector2(safe_rect.get_center().x - 190, safe_rect.end.y - 70)
	dialogue_panel.size = Vector2(380, 64)
	item_banner.position = Vector2(safe_rect.get_center().x - 130, safe_rect.position.y + 74)
	feat_banner.position = Vector2(safe_rect.get_center().x - 130, safe_rect.position.y + 104)
	photo_row.position = Vector2(safe_rect.get_center().x - 110, safe_rect.position.y + 6)
	photo_status.position = Vector2(safe_rect.get_center().x - 60, safe_rect.position.y + 30)
	# touch cluster (bottom right) + joystick (bottom left); scaled, saved offsets
	joystick_radius = clampf(minf(safe_rect.size.x * 0.07, safe_rect.size.y * 0.12), 26.0, 42.0) * float(settings.get("hud_scale", 1.0))
	joystick_knob_radius = maxf(10.0, joystick_radius * 0.4)
	if controls != null:
		controls.apply_layout()
		if controls.edit_active:
			controls._place_edit_panel()
	if settings_panel != null:
		settings_panel.position = Vector2(safe_rect.get_center().x - settings_panel.size.x / 2.0, safe_rect.position.y + 4)
	queue_redraw()


func _get_safe_rect() -> Rect2:
	var viewport_size := get_viewport_rect().size
	var window_size := DisplayServer.window_get_size()
	var margin := 8.0
	var fallback := Rect2(Vector2(margin, margin), Vector2(maxf(1.0, viewport_size.x - margin * 2.0), maxf(1.0, viewport_size.y - margin * 2.0)))
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0 or window_size.x <= 0 or window_size.y <= 0:
		return fallback
	var display_safe := DisplayServer.get_display_safe_area()
	var window_pos := DisplayServer.window_get_position()
	var left := maxf(margin, clampf(float(display_safe.position.x - window_pos.x) / float(window_size.x), 0.0, 1.0) * viewport_size.x)
	var top := maxf(margin, clampf(float(display_safe.position.y - window_pos.y) / float(window_size.y), 0.0, 1.0) * viewport_size.y)
	var right := minf(viewport_size.x - margin, clampf(float(display_safe.end.x - window_pos.x) / float(window_size.x), 0.0, 1.0) * viewport_size.x)
	var bottom := minf(viewport_size.y - margin, clampf(float(display_safe.end.y - window_pos.y) / float(window_size.y), 0.0, 1.0) * viewport_size.y)
	if right - left < 300.0 or bottom - top < 200.0:
		return fallback
	return Rect2(Vector2(left, top), Vector2(right - left, bottom - top))


# ------------------------------------------------------------------ per-frame
func _process(delta: float) -> void:
	if game == null or game.player == null:
		return
	if photo_active and photo_status_t > 0.0:
		photo_status_t -= delta
		if photo_status_t <= 0.0:
			photo_status.text = "drag to pan"
	var p: Node = game.player
	_update_hearts(p.health, p.max_health)
	coin_label.text = str(p.petalcoins)
	tea_label.text = "%d/%d" % [p.moontea_charges, p.moontea_max]
	clock_label.text = game.environment.clock_text()
	var wid: String = p.get_weapon_id()
	weapon_icon.texture = AnimLib.tex(DB.ITEMS[wid]["icon"])
	weapon_label.text = p.get_weapon_name()
	attack_button.icon = weapon_icon.texture
	var next_w: String = p.get_weapon_id()
	for step in range(1, p.weapons_owned.size() + 1):
		var cand: String = p.weapons_owned[(p.weapon_index + step) % p.weapons_owned.size()]
		if Build.can_equip(p, cand):
			next_w = cand
			break
	weapon_button.icon = AnimLib.tex(DB.ITEMS[next_w]["icon"])
	controls.update_buttons()
	quest_label.text = game.quest_text()
	journey_label.text = game.journey_text()
	_refresh_skill_bar()
	if message_timer > 0.0:
		message_timer -= delta
		if message_timer < 0.5:
			message_label.modulate.a = maxf(0.0, message_timer / 0.5)
	if region_t > 0.0:
		region_t -= delta
		var a := clampf(minf(3.2 - region_t, region_t) / 0.6, 0.0, 1.0)
		region_label.modulate.a = a
		region_sub.modulate.a = a
	if boss_panel.visible and game.active_boss:
		boss_bar.value = lerpf(boss_bar.value, game.active_boss.hp, clampf(delta * 8.0, 0.0, 1.0))
	if dialogue_open and dialogue_text.visible_characters >= 0:
		dialogue_chars += delta * 55.0
		dialogue_text.visible_characters = int(dialogue_chars)
		if dialogue_text.visible_characters >= dialogue_text.text.length():
			dialogue_text.visible_characters = -1
	var playing: bool = game.game_started and not any_menu_open()
	touch_root.visible = show_touch and (playing or controls.edit_active)
	for n in [hearts_box, stamina_bar, quest_label, journey_label, xp_bar, focus_bar, skill_row, minimap, get_node("CounterRow"), get_node("SeedRow"), get_node("WeaponBox"), pause_button, bag_button, map_button, arts_button]:
		if photo_active:
			n.visible = false
		else:
			n.visible = game.game_started and not title_overlay.visible
	# keyboard skill bar only without touch controls (touch has its own art buttons)
	skill_row.visible = skill_row.visible and not show_touch
	minimap.queue_redraw()
	queue_redraw()
	if dialogue_open and (Input.is_action_just_pressed("interact") or Input.is_action_just_pressed("attack")):
		advance_dialogue()


func _update_hearts(health: int, max_health: int) -> void:
	var count := ceili(max_health / 4.0)
	while hearts_box.get_child_count() < count:
		var t := TextureRect.new()
		var a := AtlasTexture.new()
		a.atlas = heart_tex
		a.region = Rect2(64, 0, 16, 16)
		t.texture = a
		t.custom_minimum_size = Vector2(13, 13)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		hearts_box.add_child(t)
	while hearts_box.get_child_count() > count:
		var c := hearts_box.get_child(hearts_box.get_child_count() - 1)
		hearts_box.remove_child(c)
		c.queue_free()
	for i in range(count):
		var quarters := clampi(health - i * 4, 0, 4)
		var tr := hearts_box.get_child(i) as TextureRect
		(tr.texture as AtlasTexture).region = Rect2(quarters * 16, 0, 16, 16)


# ------------------------------------------------------------------ input
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle_pause()
		get_viewport().set_input_as_handled()
		return
	if game == null or not game.game_started:
		return
	if photo_active:
		if event.is_action_pressed("photo") or event.is_action_pressed("pause"):
			_exit_photo_mode()
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed and not photo_row.get_global_rect().has_point(event.position):
				photo_dragging = true
			elif not event.pressed:
				photo_dragging = false
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseMotion and photo_dragging:
			game.camera.global_position -= event.relative / game.camera.zoom.x
			get_viewport().set_input_as_handled()
		return
	if controls != null and controls.edit_active:
		controls.edit_input(event)
		return
	if not get_tree().paused and event.is_action_pressed("photo") and not any_menu_open():
		toggle_photo_mode()
		get_viewport().set_input_as_handled()
		return
	if title_overlay.visible or end_overlay.visible or get_tree().paused and not inventory_overlay.visible and not map_overlay.visible and not arts_overlay.visible and not journeys_overlay.visible:
		return
	if event.is_action_pressed("inventory"):
		toggle_inventory()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("map"):
		toggle_map()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("arts"):
		toggle_arts()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("journeys"):
		toggle_journeys()
		get_viewport().set_input_as_handled()
		return
	if controls != null and controls.edit_active:
		controls.edit_input(event)
		return
	if any_menu_open():
		return
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed:
			var b := _button_at(touch.position)
			if b != null:
				_press_touch(b, touch.index, touch.position)
				get_viewport().set_input_as_handled()
			elif joystick_touch_index == -1 and _can_start_joystick(touch.position):
				joystick_touch_index = touch.index
				if String(settings.get("joystick_mode", "floating")) == "fixed":
					joystick_center = joystick_home
				else:
					joystick_center = touch.position
				_update_joystick(touch.position)
				get_viewport().set_input_as_handled()
			elif _try_lock_target(touch.position):
				get_viewport().set_input_as_handled()
		else:
			if touch.index == joystick_touch_index:
				_end_joystick()
				get_viewport().set_input_as_handled()
			elif touch_held.has(touch.index):
				_release_touch(touch.index)
				get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == joystick_touch_index:
			_update_joystick(drag.position)
			get_viewport().set_input_as_handled()
		elif controls.drag(drag.index, drag.position):
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				var b2 := _button_at(mb.position) if show_touch else null
				if b2 != null:
					_press_touch(b2, 100, mb.position)
					get_viewport().set_input_as_handled()
				elif _try_lock_target(mb.position):
					get_viewport().set_input_as_handled()
			elif touch_held.has(100):
				_release_touch(100)
	elif event is InputEventMouseMotion and touch_held.has(100) and event.device != InputEvent.DEVICE_ID_EMULATION:
		controls.drag(100, (event as InputEventMouseMotion).position)


func _button_at(point: Vector2) -> TouchButton:
	if not touch_root.visible:
		return null
	for b in touch_buttons:
		if b.visible and b.hit(point):
			return b
	return null


## Tap on an enemy (outside controls) to lock it as the target; tap again to clear.
func _try_lock_target(screen_pos: Vector2) -> bool:
	if game == null or not game.game_started or game.player == null:
		return false
	var world_pos: Vector2 = game.get_viewport().get_canvas_transform().affine_inverse() * screen_pos
	var had: bool = game.player.manual_target != null
	var locked: bool = game.player.lock_target_at(world_pos + Vector2(0, 4))
	return locked or had


func _press_touch(b: TouchButton, index: int, pos := Vector2.INF) -> void:
	if b.slot >= 0:
		controls.press_skill(b, index, b.center() if pos == Vector2.INF else pos)
		queue_redraw()
		return
	touch_held[index] = b
	b.pressed_now = true
	Input.action_press(b.action)
	if b.action == "switch_weapon":
		game.player.cycle_weapon()
		Input.action_release(b.action)
	queue_redraw()


func _release_touch(index: int) -> void:
	var b: TouchButton = touch_held[index]
	touch_held.erase(index)
	b.pressed_now = false
	if controls.release(index):
		return
	if b.action != "":
		Input.action_release(b.action)


func _can_start_joystick(point: Vector2) -> bool:
	if String(settings.get("joystick_mode", "floating")) == "fixed":
		return point.distance_to(joystick_home) <= joystick_radius * 2.2
	return point.x <= safe_rect.position.x + safe_rect.size.x * 0.48 and point.y >= safe_rect.position.y + safe_rect.size.y * 0.30


func _update_joystick(point: Vector2) -> void:
	var offset := point - joystick_center
	if String(settings.get("joystick_mode", "floating")) == "fixed":
		joystick_center = joystick_home
		offset = point - joystick_center
	elif offset.length() > joystick_radius * 1.4:
		joystick_center = point - offset.normalized() * joystick_radius * 1.4
		offset = point - joystick_center
	var raw_strength := minf(offset.length() / maxf(1.0, joystick_radius), 1.0)
	joystick_raw_strength = raw_strength
	joystick_raw_direction = offset.normalized() if raw_strength > 0.0 else Vector2.ZERO
	if raw_strength <= joystick_deadzone:
		joystick_vector = Vector2.ZERO
	else:
		var adjusted := (raw_strength - joystick_deadzone) / maxf(0.001, 1.0 - joystick_deadzone)
		joystick_vector = joystick_raw_direction * minf(1.0, adjusted * joystick_sensitivity)
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
	var full := joystick_vector.length() > 0.97
	if full and not _sprint_from_stick:
		_sprint_from_stick = true
		Input.action_press("sprint")
	elif not full and _sprint_from_stick:
		_sprint_from_stick = false
		if not touch_held.values().has(sprint_button):
			Input.action_release("sprint")


func _set_axis_action(action: String, strength: float) -> void:
	if strength > 0.08:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)


func _clear_touch_inputs() -> void:
	if controls != null:
		controls.cancel_aim()
	_end_joystick()
	for idx in touch_held.keys():
		_release_touch(idx)
	for action in ["dash", "attack", "skill", "guard", "heal", "interact", "jump", "sprint", "switch_weapon", "relic"]:
		if InputMap.has_action(action):
			Input.action_release(action)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_clear_touch_inputs()


func _on_deadzone_changed(value: float) -> void:
	joystick_deadzone = value
	settings["joystick_deadzone"] = value
	save_settings()
	deadzone_label.text = "DEAD ZONE  %d%%" % roundi(value * 100.0)
	if joystick_touch_index != -1:
		_update_joystick(joystick_center + joystick_raw_direction * joystick_raw_strength * joystick_radius)


func _on_sensitivity_changed(value: float) -> void:
	joystick_sensitivity = value
	settings["joystick_sensitivity"] = value
	save_settings()
	sensitivity_label.text = "SENSITIVITY  %.2fx" % value
	if joystick_touch_index != -1:
		_update_joystick(joystick_center + joystick_raw_direction * joystick_raw_strength * joystick_radius)


func _draw() -> void:
	if not touch_root.visible:
		return
	var center := joystick_center if joystick_touch_index != -1 else joystick_home
	var op := float(settings.get("hud_opacity", 0.9))
	draw_circle(center, joystick_radius + 3.0, Color(0.08, 0.05, 0.12, 0.25 * op))
	draw_circle(center, joystick_radius, Color(0.2, 0.14, 0.26, 0.42 * op))
	draw_arc(center, joystick_radius, 0.0, TAU, 40, Color(0.98, 0.78, 0.88, 0.6 * op), 1.5)
	if String(settings.get("joystick_mode", "floating")) == "fixed":
		draw_arc(center, joystick_radius * 0.55, 0.0, TAU, 24, Color(0.98, 0.78, 0.88, 0.25 * op), 1.0)
	var knob := center + joystick_vector * joystick_radius
	draw_circle(knob, joystick_knob_radius, Color(0.86, 0.48, 0.66, 0.8 * op))
	draw_arc(knob, joystick_knob_radius, 0.0, TAU, 28, Color(1.0, 0.94, 0.86, 0.9 * op), 1.5)
	if controls != null and controls.edit_active:
		draw_arc(center, joystick_radius + 4.0, 0.0, TAU, 40, Color(1.0, 0.85, 0.4, 0.95), 1.0)


# ------------------------------------------------------------------ inner widgets
class StaminaBar:
	extends Control
	var hud: Control

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if hud == null or hud.game == null or hud.game.player == null:
			return
		var p: Node = hud.game.player
		var k: float = p.stamina / p.STAMINA_MAX
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.05, 0.1, 0.75))
		var col := Color(0.62, 0.92, 0.7) if k > 0.25 else Color(1.0, 0.55, 0.45)
		draw_rect(Rect2(Vector2(1, 1), Vector2((size.x - 2) * k, size.y - 2)), col)
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 0.9, 0.95, 0.5), false, 1.0)


## Tiny XP / Focus gauge for the Petal Arts system.
class MiniBar:
	extends Control
	var hud: Control
	var mode := "xp"

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if hud == null or hud.game == null or hud.game.player == null:
			return
		var p: Node = hud.game.player
		var k := 0.0
		var col := Color.WHITE
		if mode == "xp":
			k = clampf(float(p.xp) / float(maxi(1, p.xp_needed())), 0.0, 1.0)
			col = Color(1.0, 0.83, 0.45)
		else:
			k = clampf(float(p.focus) / maxf(1.0, float(p.focus_max)), 0.0, 1.0)
			col = Color(0.66, 0.85, 1.0) if float(p.focus) >= 12.0 else Color(0.45, 0.5, 1.0)
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.08, 0.05, 0.1, 0.75))
		draw_rect(Rect2(Vector2(1, 1), Vector2((size.x - 2) * k, size.y - 2)), col)
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 0.9, 0.95, 0.4), false, 1.0)


class Minimap:
	extends Control
	var hud: Control

	func _draw() -> void:
		if hud == null or hud.minimap_tex == null or hud.game == null:
			return
		var g: Node = hud.game
		var ws: Vector2 = g.world.world_size
		var ppos: Vector2 = g.player.global_position
		var view := Vector2(72, 50)
		var tex_size: Vector2 = hud.minimap_tex.get_size()
		var tiles: Vector2 = ppos / 16.0
		var src := Rect2(tiles - view / 2.0, view)
		src.position = src.position.clamp(Vector2.ZERO, tex_size - view)
		draw_rect(Rect2(Vector2(-2, -2), size + Vector2(4, 4)), Color(0.08, 0.05, 0.12, 0.85))
		draw_texture_rect_region(hud.minimap_tex, Rect2(Vector2.ZERO, size), src, Color(1, 1, 1, 0.92))
		var scale_v := size / view
		for m in g.map_markers():
			var mp: Vector2 = (m["pos"] / 16.0 - src.position) * scale_v
			if Rect2(Vector2.ZERO, size).has_point(mp):
				draw_rect(Rect2(mp - Vector2(1.5, 1.5), Vector2(3, 3)), m["color"])
		var pp: Vector2 = (tiles - src.position) * scale_v
		draw_circle(pp, 2.5, Color(1, 1, 1))
		draw_circle(pp, 1.6, Color(0.95, 0.4, 0.62))
		draw_rect(Rect2(Vector2(-2, -2), size + Vector2(4, 4)), Color(0.96, 0.72, 0.84, 0.9), false, 1.0)
		var _u := ws


class WorldMapView:
	extends Control
	var hud: Control

	func _draw() -> void:
		if hud == null or hud.minimap_tex == null:
			return
		var g: Node = hud.game
		var tex_size: Vector2 = hud.minimap_tex.get_size()
		var avail := size - Vector2(40, 60)
		var k := minf(avail.x / tex_size.x, avail.y / tex_size.y)
		var dsize := tex_size * k
		var origin := (size - dsize) / 2.0 + Vector2(0, 10)
		draw_rect(Rect2(origin - Vector2(3, 3), dsize + Vector2(6, 6)), Color(0.96, 0.72, 0.84, 0.9), false, 1.0)
		draw_texture_rect(hud.minimap_tex, Rect2(origin, dsize), false)
		var f := get_theme_default_font()
		draw_string(f, Vector2(origin.x, origin.y - 10), "VALLEY OF PETALS", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 0.86, 0.6))
		for m in g.map_markers():
			var mp: Vector2 = origin + m["pos"] / 16.0 * k
			draw_rect(Rect2(mp - Vector2(2, 2), Vector2(4, 4)), m["color"])
			if m.has("label"):
				draw_string(f, mp + Vector2(5, 3), m["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1, 0.96, 0.9))
		var pp: Vector2 = origin + g.player.global_position / 16.0 * k
		draw_circle(pp, 3.5, Color.WHITE)
		draw_circle(pp, 2.4, Color(0.95, 0.4, 0.62))
