extends Node
## Day/night cycle, regional colour grading, weather particles, fog/light rays and post-processing.

const POST_SHADER := preload("res://assets/shaders/post_process.gdshader")
const ATMO_SHADER := preload("res://assets/shaders/atmosphere.gdshader")
const FX := "res://assets/packs/ninja_adventure/fx/"
const DAY_LENGTH := 480.0

# biome -> [tint, fog, rays, weather]
const REGION := [
	[Color(1.0, 0.99, 0.97), 0.04, 0.32, "petals"],
	[Color(0.88, 0.97, 0.90), 0.22, 0.9, "leaves"],
	[Color(1.0, 0.95, 0.85), 0.0, 0.25, "sand"],
	[Color(0.90, 0.90, 1.02), 0.30, 0.3, "snow"],
	[Color(0.92, 0.98, 0.94), 0.38, 0.2, "rain"],
	[Color(1.0, 1.0, 0.98), 0.0, 0.45, ""],
	[Color(0.90, 0.88, 1.05), 0.16, 0.38, "petals"],
]
const SKY := [
	[0.00, Color(0.30, 0.34, 0.60)],
	[0.20, Color(0.34, 0.37, 0.64)],
	[0.27, Color(0.92, 0.74, 0.76)],
	[0.36, Color(1.00, 1.00, 1.00)],
	[0.68, Color(1.00, 1.00, 1.00)],
	[0.77, Color(0.96, 0.76, 0.72)],
	[0.84, Color(0.54, 0.46, 0.72)],
	[0.92, Color(0.32, 0.35, 0.62)],
	[1.00, Color(0.30, 0.34, 0.60)],
]

var game: Node
var time_of_day := 0.34
var time_scale := 1.0
var canvas_mod: CanvasModulate
var post_rect: ColorRect
var post_mat: ShaderMaterial
var atmo_rect: ColorRect
var atmo_mat: ShaderMaterial
var weather: Dictionary = {}
var current_weather := ""
var region_tint := Color.WHITE
var fog := 0.0
var rays := 0.0
var blight := 0.6
var damage_flash := 0.0
var fade := 0.0
var quality_high := true
var darkness := 0.0
var _gust_t := 0.0
var gust := 0.0


func setup(p_game: Node, world_root: Node2D) -> void:
	game = p_game
	canvas_mod = CanvasModulate.new()
	world_root.add_child(canvas_mod)
	var atmo_layer := CanvasLayer.new()
	atmo_layer.layer = 2
	add_child(atmo_layer)
	atmo_rect = ColorRect.new()
	atmo_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	atmo_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	atmo_mat = ShaderMaterial.new()
	atmo_mat.shader = ATMO_SHADER
	atmo_mat.set_shader_parameter("fog_tex", load(FX + "fog.png"))
	atmo_rect.material = atmo_mat
	atmo_layer.add_child(atmo_rect)
	var post_layer := CanvasLayer.new()
	post_layer.layer = 3
	add_child(post_layer)
	post_rect = ColorRect.new()
	post_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	post_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post_mat = ShaderMaterial.new()
	post_mat.shader = POST_SHADER
	post_rect.material = post_mat
	post_layer.add_child(post_rect)
	for kind in ["petals", "leaves", "sand", "snow", "rain"]:
		var p := _make_weather(kind)
		world_root.add_child(p)
		weather[kind] = p


func _make_weather(kind: String) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.z_index = 8
	p.emitting = false
	p.local_coords = false
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(260, 160)
	p.lifetime = 6.0
	p.preprocess = 4.0
	var m := CanvasItemMaterial.new()
	m.particles_animation = true
	m.particles_anim_loop = true
	p.material = m
	var fade_g := Gradient.new()
	fade_g.set_color(0, Color(1, 1, 1, 0))
	fade_g.set_color(1, Color(1, 1, 1, 0))
	fade_g.add_point(0.15, Color(1, 1, 1, 1))
	fade_g.add_point(0.85, Color(1, 1, 1, 1))
	p.color_ramp = fade_g
	match kind:
		"petals":
			p.texture = load(FX + "p_leaf_pink.png")
			m.particles_anim_h_frames = 6
			p.amount = 34
			p.direction = Vector2(1, 0.4)
			p.spread = 25.0
			p.gravity = Vector2(10, 12)
			p.initial_velocity_min = 14.0
			p.initial_velocity_max = 30.0
			p.anim_speed_min = 0.6
			p.anim_speed_max = 1.2
		"leaves":
			p.texture = load(FX + "p_leaf.png")
			m.particles_anim_h_frames = 6
			p.amount = 30
			p.direction = Vector2(0.6, 1)
			p.spread = 30.0
			p.gravity = Vector2(6, 14)
			p.initial_velocity_min = 8.0
			p.initial_velocity_max = 22.0
			p.anim_speed_min = 0.5
			p.anim_speed_max = 1.0
		"sand":
			p.texture = load(FX + "p_rock.png")
			m.particles_anim_h_frames = 5
			p.amount = 46
			p.direction = Vector2(1, 0.1)
			p.spread = 8.0
			p.gravity = Vector2(30, 0)
			p.initial_velocity_min = 60.0
			p.initial_velocity_max = 110.0
			p.lifetime = 3.0
			p.scale_amount_min = 0.3
			p.scale_amount_max = 0.6
			p.color = Color(1.0, 0.86, 0.62, 0.55)
		"snow":
			p.texture = load(FX + "p_snow.png")
			m.particles_anim_h_frames = 7
			p.amount = 60
			p.direction = Vector2(0.2, 1)
			p.spread = 20.0
			p.gravity = Vector2(4, 10)
			p.initial_velocity_min = 10.0
			p.initial_velocity_max = 26.0
			p.color = Color(1, 1, 1, 0.85)
		"rain":
			p.texture = load(FX + "p_rain.png")
			m.particles_anim_h_frames = 3
			p.amount = 110
			p.direction = Vector2(-0.25, 1)
			p.spread = 2.0
			p.gravity = Vector2(0, 240)
			p.initial_velocity_min = 180.0
			p.initial_velocity_max = 230.0
			p.lifetime = 1.2
			p.preprocess = 1.2
			p.color = Color(0.82, 0.9, 1.0, 0.6)
	return p


func _process(delta: float) -> void:
	if game == null:
		return
	if game.game_started and not get_tree().paused:
		time_of_day = fposmod(time_of_day + delta / DAY_LENGTH * time_scale, 1.0)
	var biome: int = game.current_biome
	var reg: Array = REGION[clampi(biome, 0, REGION.size() - 1)]
	var k := clampf(delta * 1.2, 0.0, 1.0)
	region_tint = region_tint.lerp(reg[0], k)
	fog = lerpf(fog, float(reg[1]) * (1.4 if is_night() else 1.0), k)
	var sky := _sky()
	rays = lerpf(rays, float(reg[2]) * (1.0 - darkness), k)
	canvas_mod.color = sky * region_tint
	darkness = clampf((1.0 - sky.g) / 0.6, 0.0, 1.0)
	var want: String = reg[3] if quality_high else ""
	if want != current_weather:
		for kname in weather:
			weather[kname].emitting = kname == want
		current_weather = want
	var cam: Camera2D = game.camera
	if cam:
		var c := cam.get_screen_center_position()
		for kname in weather:
			var w: CPUParticles2D = weather[kname]
			w.global_position = c - Vector2(80, 60) if kname in ["petals", "sand"] else c + Vector2(0, -40)
		atmo_mat.set_shader_parameter("camera_px", c)
		atmo_mat.set_shader_parameter("zoom", cam.zoom.x)
	atmo_mat.set_shader_parameter("fog", fog)
	atmo_mat.set_shader_parameter("rays", rays if quality_high else 0.0)
	damage_flash = maxf(0.0, damage_flash - delta * 2.4)
	var restored: float = clampf(1.0 - blight, 0.0, 1.0)
	post_mat.set_shader_parameter("saturation", 0.88 + restored * 0.26)
	post_mat.set_shader_parameter("bloom", (0.16 + darkness * 0.22) if quality_high else 0.0)
	post_mat.set_shader_parameter("damage", damage_flash)
	post_mat.set_shader_parameter("fade", fade)
	post_mat.set_shader_parameter("quality", 1.0 if quality_high else 0.0)
	post_mat.set_shader_parameter("vignette", 0.30 + darkness * 0.18)
	_gust_t -= delta
	if _gust_t <= 0.0:
		_gust_t = randf_range(5.0, 11.0)
		create_tween().tween_property(self, "gust", 1.0, 1.2).set_trans(Tween.TRANS_SINE)
		get_tree().create_timer(2.0, false).timeout.connect(func() -> void: create_tween().tween_property(self, "gust", 0.0, 2.0))
	game.world.set_night(darkness)
	game.player.lantern.energy = pow(darkness, 1.5) * 0.55


func _sky() -> Color:
	for i in range(SKY.size() - 1):
		var a: Array = SKY[i]
		var b: Array = SKY[i + 1]
		if time_of_day >= a[0] and time_of_day <= b[0]:
			var t := (time_of_day - float(a[0])) / maxf(0.0001, float(b[0]) - float(a[0]))
			return (a[1] as Color).lerp(b[1], smoothstep(0.0, 1.0, t))
	return Color.WHITE


func is_night() -> bool:
	return time_of_day < 0.24 or time_of_day > 0.86


func clock_text() -> String:
	var minutes := int(time_of_day * 24.0 * 60.0)
	return "%02d:%02d" % [minutes / 60, minutes % 60]


func set_quality(high: bool) -> void:
	quality_high = high
	current_weather = "__"

