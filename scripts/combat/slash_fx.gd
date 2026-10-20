class_name PetalboundSlashFX
extends Node2D
## Lightweight, texture-free pixel-combat accents. One short-lived node per attack.

var direction: Vector2 = Vector2.RIGHT
var tint: Color = Color(0.95, 0.85, 1.0)
var style: String = "slash"
var effect_scale: float = 1.0
var age: float = 0.0

const LIFE := 0.22

static func spawn(parent: Node, world_pos: Vector2, dir: Vector2, color: Color, effect_style: String = "slash", scale_value: float = 1.0) -> void:
	if parent == null or not is_instance_valid(parent):
		return
	var fx := PetalboundSlashFX.new()
	fx.direction = dir.normalized() if dir.length() > 0.01 else Vector2.RIGHT
	fx.tint = color
	fx.style = effect_style
	fx.effect_scale = clampf(scale_value, 0.5, 1.8)
	parent.add_child(fx)
	fx.global_position = world_pos


func _ready() -> void:
	z_index = 8
	top_level = true


func _process(delta: float) -> void:
	age += delta
	if age >= LIFE:
		queue_free()
		return
	queue_redraw()


func _draw() -> void:
	var progress := clampf(age / LIFE, 0.0, 1.0)
	var fade := 1.0 - progress
	var d := direction
	var n := d.orthogonal()
	var reach := 22.0 * effect_scale * (0.72 + progress * 0.28)
	var bright := Color(1.0, 0.98, 0.9, fade)
	var core := Color(tint.r, tint.g, tint.b, tint.a * fade)
	var shadow := Color(tint.r * 0.35, tint.g * 0.35, tint.b * 0.45, 0.65 * fade)

	match style:
		"cross":
			for offset in [-0.22, 0.22]:
				var axis := d.rotated(offset)
				draw_line(-axis * reach * 0.45 + n * 2.0, axis * reach + n * 2.0, shadow, 4.0 * effect_scale)
				draw_line(-axis * reach * 0.35 + n * 2.0, axis * reach, core, 2.0 * effect_scale)
				draw_line(-axis * reach * 0.25, axis * reach * 0.78, bright, 1.0)
		"claw":
			for i in range(3):
				var axis := d.rotated((float(i) - 1.0) * 0.24)
				var start := axis * (5.0 + float(i % 2) * 2.0)
				var finish := axis * reach + n * (float(i) - 1.0) * 4.0
				draw_line(start, finish, shadow, 3.2 * effect_scale)
				draw_line(start, finish, core, 1.6 * effect_scale)
				draw_line(start + n, finish - axis * 4.0 + n, bright, 0.8)
		"tornado":
			var sweep := TAU * progress
			draw_arc(Vector2.ZERO, reach * 0.78, -0.9 + sweep, 1.5 + sweep, 22, shadow, 5.0 * effect_scale)
			draw_arc(Vector2.ZERO, reach * 0.78, -0.9 + sweep, 1.5 + sweep, 22, core, 2.0 * effect_scale)
			draw_arc(Vector2.ZERO, reach * 0.48, 1.6 - sweep, 3.7 - sweep, 18, bright, 1.0)
			for i in range(4):
				var angle := sweep + float(i) * TAU / 4.0
				var ray := Vector2.from_angle(angle)
				draw_line(ray * reach * 0.55, ray * reach, core, 1.3)
		"dash":
			var tail := -d * reach * (0.7 + progress * 0.3)
			draw_line(tail + n * 4.0, d * reach * 0.35 + n * 1.0, shadow, 4.0 * effect_scale)
			draw_line(tail, d * reach * 0.42, core, 2.2 * effect_scale)
			draw_line(tail + n * 2.0, d * reach * 0.2, bright, 1.0)
			draw_line(-d * reach * 0.25 - n * 5.0, d * reach * 0.45 - n * 5.0, core, 1.0)
		_:
			var angle := d.angle()
			draw_arc(Vector2.ZERO, reach * 0.72, angle - 0.9, angle + 0.85, 18, shadow, 4.0 * effect_scale)
			draw_arc(Vector2.ZERO, reach * 0.72, angle - 0.9, angle + 0.85, 18, core, 2.0 * effect_scale)
			draw_arc(Vector2.ZERO, reach * 0.72, angle - 0.65, angle + 0.45, 14, bright, 1.0)
			for i in range(3):
				var ray := d.rotated((float(i) - 1.0) * 0.55)
				var from := ray * reach * (0.55 + float(i % 2) * 0.1)
				draw_line(from, from + ray * (4.0 * (1.0 - progress)), bright, 1.0)
