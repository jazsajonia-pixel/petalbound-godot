extends Node2D
## One-shot animated effects, particle bursts, floating numbers and ground telegraphs.

const AnimLib := preload("res://scripts/core/anim_lib.gd")
const FX := "res://assets/packs/ninja_adventure/fx/"

const DEFS := {
	"slash": ["slash_curved.png", 32, 20.0],
	"slash_double": ["slash_double.png", 32, 20.0],
	"slash_circular": ["slash_circular.png", 32, 18.0],
	"cut": ["cut_x.png", 32, 18.0],
	"claw": ["claw.png", 32, 18.0],
	"explosion": ["explosion.png", 40, 18.0],
	"smoke": ["smoke.png", 32, 16.0],
	"magic_circle": ["magic_circle.png", 32, 12.0],
	"spark_circle": ["spark_circle.png", 32, 14.0],
	"spirit": ["spirit_blue.png", 32, 12.0],
	"aura": ["aura.png", 25, 12.0],
	"spark": ["magic_spark.png", 30, 20.0],
	"ice": ["ice.png", 32, 18.0],
	"thunder": ["thunder.png", 20, 16.0],
	"shield": ["shield.png", 24, 14.0],
	"ripple": ["res://assets/packs/ninja_adventure/tilesets/water_ripples.png", 16, 8.0],
}

const PARTICLES := {
	"leaf": ["p_leaf.png", 6], "leaf_pink": ["p_leaf_pink.png", 6], "grass": ["p_grass.png", 6],
	"spark": ["p_spark.png", 7], "snow": ["p_snow.png", 7], "rock": ["p_rock.png", 5], "wood": ["p_wood.png", 6],
	"fire": ["p_fire.png", 12],
}

var font: Font
var _materials: Dictionary = {}
## Player settings (applied by Settings): particle density, screen shake, damage numbers.
var intensity := 1.0
var shake_scale := 1.0
var numbers_enabled := true
signal shake_requested(strength: float, duration: float)


func _ready() -> void:
	z_index = 6
	font = preload("res://scripts/ui/fonts.gd").title()


func spawn(name: String, pos: Vector2, rot := 0.0, scl := 1.0, tint := Color.WHITE, parent: Node = null, additive := false) -> AnimatedSprite2D:
	if not DEFS.has(name):
		return null
	var d: Array = DEFS[name]
	var s := AnimatedSprite2D.new()
	var path: String = d[0] if String(d[0]).begins_with("res://") else FX + d[0]
	s.sprite_frames = AnimLib.strip_frames(path, d[1], d[2], false)
	s.position = pos
	s.rotation = rot
	s.scale = Vector2(scl, scl)
	s.modulate = tint
	if additive:
		s.modulate.a *= 0.75
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		s.material = m
	(parent if parent != null else self).add_child(s)
	s.play("play")
	s.animation_finished.connect(s.queue_free)
	return s


func burst(kind: String, pos: Vector2, amount := 8, speed := 60.0, tint := Color.WHITE, gravity := 140.0, lifetime := 0.7) -> void:
	if not PARTICLES.has(kind):
		return
	var def: Array = PARTICLES[kind]
	amount = maxi(1, int(round(float(amount) * intensity)))
	var p := CPUParticles2D.new()
	p.texture = AnimLib.tex(FX + def[0])
	p.material = _particle_material(def[1])
	p.position = pos
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = amount
	p.lifetime = lifetime
	p.direction = Vector2.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector2(0, gravity)
	p.damping_min = 20.0
	p.damping_max = 60.0
	p.angular_velocity_min = -200.0
	p.angular_velocity_max = 200.0
	p.anim_offset_max = 1.0
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.1
	p.color = tint
	var fade := Gradient.new()
	fade.set_color(0, Color(1, 1, 1, 1))
	fade.set_color(1, Color(1, 1, 1, 0))
	fade.add_point(0.7, Color(1, 1, 1, 0.9))
	p.color_ramp = fade
	add_child(p)
	p.emitting = true
	get_tree().create_timer(lifetime + 0.3, false).timeout.connect(p.queue_free)


func _particle_material(frames: int) -> CanvasItemMaterial:
	if _materials.has(frames):
		return _materials[frames]
	var m := CanvasItemMaterial.new()
	m.particles_animation = true
	m.particles_anim_h_frames = frames
	m.particles_anim_v_frames = 1
	m.particles_anim_loop = false
	_materials[frames] = m
	return m


func number(pos: Vector2, text: String, color := Color("fff3c4"), big := false) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", 16 if big else 8)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color("1b1726"))
	l.add_theme_constant_override("outline_size", 3)
	l.position = pos + Vector2(-4 + randf_range(-4, 4), -30 if big else -26)
	l.z_index = 20
	add_child(l)
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y - 16.0, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.35).set_delay(0.45)
	tw.chain().tween_callback(l.queue_free)


func dust(pos: Vector2, scl := 0.45) -> void:
	var s := spawn("smoke", pos + Vector2(0, -3), 0.0, scl, Color(1, 0.97, 0.9, 0.75))
	if s:
		s.z_index = -1


func ring(pos: Vector2, radius: float, duration: float, color: Color, filled := true) -> Node2D:
	var r := Telegraph.new()
	r.radius = radius
	r.duration = duration
	r.color = color
	r.filled = filled
	r.position = pos
	r.z_index = -4
	add_child(r)
	return r


func shake(strength: float, duration := 0.18) -> void:
	if shake_scale <= 0.01:
		return
	shake_requested.emit(strength * shake_scale, duration)


## Combat damage number. Honors the damage-number setting; crits are larger and
## gold, elemental hits take their element colour, DoT ticks are small.
func damage_number(pos: Vector2, amount: int, color: Color, crit := false, small := false) -> void:
	if not numbers_enabled:
		return
	var text := str(amount) + ("!" if crit else "")
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", 16 if crit else (8 if not small else 8))
	l.add_theme_color_override("font_color", Color("ffd24a") if crit else color)
	l.add_theme_color_override("font_outline_color", Color("1b1726"))
	l.add_theme_constant_override("outline_size", 3)
	l.position = pos + Vector2(-4 + randf_range(-5, 5), -30 if crit else -24)
	l.z_index = 20
	if small:
		l.modulate.a = 0.85
	add_child(l)
	var tw := l.create_tween()
	tw.set_parallel(true)
	var rise := 22.0 if crit else 16.0
	tw.tween_property(l, "position:y", l.position.y - rise, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if crit:
		l.scale = Vector2(1.6, 1.6)
		l.pivot_offset = Vector2(8, 8)
		tw.tween_property(l, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.3).set_delay(0.35)
	tw.chain().tween_callback(l.queue_free)


## Small additive impact flash for crits and elemental hits.
func spark_hit(pos: Vector2, color: Color) -> void:
	if intensity < 0.35:
		return
	spawn("spark", pos, randf() * TAU, 0.55, color, null, true)


## A short-lived jagged lightning arc between two points (chain lightning, shock).
func bolt(from: Vector2, to: Vector2, color := Color(1.0, 0.95, 0.5)) -> void:
	var line := Line2D.new()
	line.width = 1.6
	line.default_color = color
	line.z_index = 15
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	line.material = m
	var segs := 6
	for i in range(segs + 1):
		var k := float(i) / float(segs)
		var pt := from.lerp(to, k)
		if i > 0 and i < segs:
			pt += (to - from).orthogonal().normalized() * randf_range(-5.0, 5.0)
		line.add_point(pt)
	add_child(line)
	var tw := line.create_tween()
	tw.tween_property(line, "modulate:a", 0.0, 0.22)
	tw.tween_callback(line.queue_free)


class Telegraph:
	extends Node2D
	var radius := 24.0
	var duration := 0.8
	var color := Color(1, 0.3, 0.3, 0.5)
	var filled := true
	var t := 0.0

	func _process(delta: float) -> void:
		t += delta
		if t >= duration:
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var k := clampf(t / duration, 0.0, 1.0)
		var pulse := 0.6 + sin(t * 18.0) * 0.2
		var c := Color(color.r, color.g, color.b, color.a * pulse)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.62))
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 40, c, 1.5)
		if filled:
			draw_circle(Vector2.ZERO, radius * k, Color(c.r, c.g, c.b, c.a * 0.45))


static var _glow_tex: Texture2D

## Soft round glow used behind rare loot and rarity frames.
static func glow_texture() -> Texture2D:
	if _glow_tex == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 32
		t.height = 32
		_glow_tex = t
	return _glow_tex
