extends RefCounted
## Character creation, shown before a new journey. Only options the hero
## sprite + region masks really support: fur, hood, outfit and eye/band
## colours (no body shapes or hairstyles the 16px sheet can't draw).
## Cosmetic only. The live preview uses the same frames + layered shader
## as gameplay, so what you pick is exactly what walks into the world.

const HeroLook := preload("res://scripts/actors/hero_look.gd")
const HERO_SHADER := preload("res://assets/shaders/hero_layers.gdshader")
const DB := preload("res://scripts/data/db.gd")

const ORDER := ["fur", "hood", "outfit", "accent"]
const DIRS := ["down", "left", "up", "right"]


static func make(hud: Control) -> void:
	var o: ColorRect = hud._overlay(Color(0.06, 0.04, 0.10, 0.92))
	o.name = "CharCreate"
	hud.create_overlay = o
	o.visible = false


static func open(hud: Control) -> void:
	hud.create_state = {"look": HeroLook.default_appearance(), "dir": 0, "t": 0.0}
	render(hud)
	hud.create_overlay.visible = true
	hud.title_overlay.visible = false
	hud._clear_touch_inputs()


static func close(hud: Control) -> void:
	hud.create_overlay.visible = false


static func render(hud: Control) -> void:
	var o: ColorRect = hud.create_overlay
	for c in o.get_children():
		c.queue_free()
	var look: Dictionary = hud.create_state["look"]
	var p: PanelContainer = hud._centered_panel(o, Vector2(470, 0))
	var v: VBoxContainer = hud._vbox(p, 5)
	var head: HBoxContainer = hud._hbox(v, 6)
	hud._label("WHO IS MALLOW?", 14, hud.C_GOLD, head)
	hud._label("cosmetic only · gear still shows on top", 8, hud.C_DIM, head)
	var body: HBoxContainer = hud._hbox(v, 10)
	# ---- preview
	var pv: VBoxContainer = hud._vbox(body, 4)
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(120, 120)
	frame.add_theme_stylebox_override("panel", hud._box(Color(0.16, 0.24, 0.16), Color(0.45, 0.62, 0.42), 1, 4))
	pv.add_child(frame)
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(120, 120)
	frame.add_child(holder)
	var spr := AnimatedSprite2D.new()
	spr.name = "Preview"
	spr.sprite_frames = hud.game.player.sprite.sprite_frames
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.scale = Vector2(3, 3)
	spr.position = Vector2(60, 64)
	var mat := ShaderMaterial.new()
	mat.shader = HERO_SHADER
	mat.set_shader_parameter("noise_tex", load("res://assets/data/noise.png"))
	HeroLook.apply(mat, look, {}, DB.ITEMS)
	spr.material = mat
	var anim := "walk_%s" % DIRS[int(hud.create_state["dir"])]
	spr.animation = anim
	mat.set_shader_parameter("mask_tex", HeroLook.mask_for("walk"))
	spr.play()
	holder.add_child(spr)
	var turn: HBoxContainer = hud._hbox(pv, 4)
	turn.alignment = BoxContainer.ALIGNMENT_CENTER
	hud._button("<", turn, func() -> void:
		hud.create_state["dir"] = (int(hud.create_state["dir"]) + 3) % 4
		render(hud))
	hud._label("TURN", 8, hud.C_DIM, turn)
	hud._button(">", turn, func() -> void:
		hud.create_state["dir"] = (int(hud.create_state["dir"]) + 1) % 4
		render(hud))
	# ---- options
	var opts: VBoxContainer = hud._vbox(body, 4)
	hud._label("PRESETS", 8, hud.C_DIM, opts)
	var pr: HBoxContainer = hud._hbox(opts, 3)
	for i in range(HeroLook.PRESETS.size()):
		var preset: Dictionary = HeroLook.PRESETS[i]
		var b: Button = hud._button(String(preset["name"]).split(" ")[0].to_upper(), pr, func() -> void:
			hud.create_state["look"] = HeroLook.sanitize(preset)
			render(hud))
		b.custom_minimum_size = Vector2(58, 18)
		b.tooltip_text = preset["name"]
	for cat in ORDER:
		var row: HBoxContainer = hud._hbox(opts, 4)
		var lab: Label = hud._label(String(HeroLook.OPTIONS[cat]["label"]), 8, hud.C_TEXT, row)
		lab.custom_minimum_size = Vector2(70, 0)
		var c: String = cat
		hud._button("<", row, func() -> void:
			hud.create_state["look"] = HeroLook.cycle(hud.create_state["look"], c, -1)
			render(hud))
		var sw := ColorRect.new()
		sw.custom_minimum_size = Vector2(12, 12)
		sw.color = HeroLook.color_of(cat, String(look[cat]))
		row.add_child(sw)
		var vl: Label = hud._label(HeroLook.label_of(cat, String(look[cat])), 8, hud.C_GOLD, row)
		vl.custom_minimum_size = Vector2(56, 0)
		hud._button(">", row, func() -> void:
			hud.create_state["look"] = HeroLook.cycle(hud.create_state["look"], c, 1)
			render(hud))
	var foot: HBoxContainer = hud._hbox(v, 6)
	hud._button("BACK", foot, func() -> void:
		close(hud)
		hud.title_overlay.visible = true)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(sp)
	var go: Button = hud._button("BEGIN JOURNEY", foot, func() -> void:
		var chosen: Dictionary = HeroLook.sanitize(hud.create_state["look"])
		close(hud)
		hud.game.begin_new_game(chosen))
	go.name = "ConfirmLook"
	go.custom_minimum_size = Vector2(120, 20)
