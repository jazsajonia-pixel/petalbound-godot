extends Node2D
## Builds the open world from assets/data/*: shader ground, batched decor, y-sorted props,
## colliders, lights, breakables, and exposes terrain queries for gameplay.

const AnimLib := preload("res://scripts/core/anim_lib.gd")
const GROUND_SHADER := preload("res://assets/shaders/ground.gdshader")
const FOLIAGE_SHADER := preload("res://assets/shaders/foliage.gdshader")
const NA := "res://assets/packs/ninja_adventure/"
const CHUNK := 256.0

const MEADOW := 0
const FOREST := 1
const DESERT := 2
const RUINS := 3
const MARSH := 4
const BEACH := 5

const DECOR_CELLS := {
	"fd_leaves": Vector2i(0, 0), "fd_pebbles": Vector2i(4, 0), "fd_sticks": Vector2i(5, 0), "fd_sand_rock": Vector2i(9, 0),
	"fd_bone": Vector2i(14, 0), "fd_shell": Vector2i(15, 0), "fd_pebbles_gray": Vector2i(0, 1), "fd_flower_yellow": Vector2i(2, 0),
	"fd_tuft": Vector2i(0, 2), "fd_sprout": Vector2i(1, 2), "fd_tuft2": Vector2i(2, 2), "fd_grass": Vector2i(3, 2),
	"fd_flower_red": Vector2i(5, 2), "fd_clover": Vector2i(6, 2), "fd_leafy": Vector2i(7, 2), "fd_flower_white": Vector2i(2, 0),
	"fd_white_tuft": Vector2i(0, 3), "fd_white_tuft2": Vector2i(2, 3), "fd_white_flower": Vector2i(5, 3),
}
const FOLIAGE_PREFIX := ["tree_", "big_", "grove_", "palm", "bamboo", "small_tree", "thin"]
const BREAKABLE := ["bush_round", "bush_round2", "pot", "pot_red", "crate", "pot_desert", "barrel"]
const LIGHT_PROPS := {"stone_lantern": Color(1.0, 0.78, 0.45), "lion_fountain": Color(0.6, 0.85, 1.0), "statue_monk": Color(0.75, 0.9, 1.0), "torii": Color(1.0, 0.55, 0.45)}

var data: Dictionary = {}
var prop_defs: Dictionary = {}
var tiles := Vector2i(256, 176)
var world_size := Vector2(4096, 2816)
var field_res := 2
var biome_image: Image
var field_image: Image
var ground: ColorRect
var ground_material: ShaderMaterial
var foliage_material: ShaderMaterial
var bush_material: ShaderMaterial
var entities: Node2D
var solids: StaticBody2D
var low_solids: StaticBody2D
var bounds: StaticBody2D
var lights: Array[PointLight2D] = []
var breakables: Array[Dictionary] = []
var prop_count := 0
var solid_grid := PackedByteArray()
var _sheets: Dictionary = {}
var _shadow_tex: Texture2D


func build(entities_parent: Node2D) -> void:
	entities = entities_parent
	data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/world.json"))
	prop_defs = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/props.json"))
	tiles = Vector2i(int(data["tiles"][0]), int(data["tiles"][1]))
	world_size = Vector2(tiles) * 16.0
	field_res = int(data.get("field_res", 2))
	var biome_tex: Texture2D = load("res://assets/data/world_biome.png")
	var field_tex: Texture2D = load("res://assets/data/world_field.png")
	biome_image = biome_tex.get_image()
	field_image = field_tex.get_image()
	if biome_image.is_compressed():
		biome_image.decompress()
	if field_image.is_compressed():
		field_image.decompress()
	solid_grid.resize(tiles.x * tiles.y)
	_make_ground(biome_tex, field_tex)
	_make_materials()
	_shadow_tex = _make_shadow_texture()
	_make_bodies()
	_make_props_and_decor()
	_make_bounds()


func _make_ground(biome_tex: Texture2D, field_tex: Texture2D) -> void:
	ground = ColorRect.new()
	ground.name = "Ground"
	ground.size = world_size
	ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ground.z_index = -10
	ground_material = ShaderMaterial.new()
	ground_material.shader = GROUND_SHADER
	var atlas: Texture2D = load(NA + "tilesets/floor.png")
	ground_material.set_shader_parameter("floor_atlas", atlas)
	ground_material.set_shader_parameter("biome_map", biome_tex)
	ground_material.set_shader_parameter("field_map", field_tex)
	ground_material.set_shader_parameter("noise_tex", load("res://assets/data/noise.png"))
	ground_material.set_shader_parameter("world_px", world_size)
	ground_material.set_shader_parameter("map_tiles", Vector2(tiles))
	ground_material.set_shader_parameter("atlas_px", Vector2(atlas.get_width(), atlas.get_height()))
	# plain fill tile (xy), first decorated tile x (z), decorated count (w)
	ground_material.set_shader_parameter("ground_tiles", PackedVector4Array([
		Vector4(0, 12, 1, 4), Vector4(11, 12, 12, 4), Vector4(0, 5, 1, 4), Vector4(0, 19, 1, 4), Vector4(11, 19, 12, 4), Vector4(1, 1, 0, 0)]))
	ground_material.set_shader_parameter("path_tiles", PackedVector4Array([
		Vector4(1, 8, 0, 0), Vector4(12, 8, 11, 0), Vector4(1, 1, 0, 0), Vector4(1, 22, 0, 0), Vector4(12, 15, 11, 0), Vector4(0, 5, 1, 2)]))
	ground_material.set_shader_parameter("water_shallow", PackedColorArray([
		Color("63d3e4"), Color("57c9c4"), Color("5cdbe0"), Color("7fa8ea"), Color("6cc7b0"), Color("62cbe6")]))
	ground_material.set_shader_parameter("water_deep", PackedColorArray([
		Color("3a95c8"), Color("2f8a97"), Color("2fa6c2"), Color("4a5cb8"), Color("3b8a7c"), Color("2c7cc0")]))
	ground_material.set_shader_parameter("biome_grade", PackedColorArray([
		Color(0.78, 0.98, 0.86, 0.42), Color(0.80, 0.98, 0.90, 0.25), Color(1.0, 0.93, 0.86, 0.10), Color(0.80, 0.80, 0.95, 0.45), Color(0.96, 0.98, 0.90, 0.15), Color(1, 1, 1, 0.0)]))
	var mw: Array = data["landmarks"]["moonwell"]
	ground_material.set_shader_parameter("moonwell_px", Vector2(mw[0], mw[1]))
	ground.material = ground_material
	add_child(ground)


func _make_materials() -> void:
	foliage_material = ShaderMaterial.new()
	foliage_material.shader = FOLIAGE_SHADER
	foliage_material.set_shader_parameter("sway", 1.3)
	bush_material = ShaderMaterial.new()
	bush_material.shader = FOLIAGE_SHADER
	bush_material.set_shader_parameter("sway", 0.7)
	bush_material.set_shader_parameter("speed", 1.6)
	bush_material.set_shader_parameter("occlusion", 0.0)


func _make_shadow_texture() -> Texture2D:
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 1))
	g.set_color(1, Color(0, 0, 0, 0))
	g.add_point(0.55, Color(0, 0, 0, 0.8))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 32
	t.height = 16
	return t


func _make_bodies() -> void:
	solids = StaticBody2D.new()
	solids.name = "Solids"
	solids.collision_layer = 1
	solids.collision_mask = 0
	add_child(solids)
	low_solids = StaticBody2D.new()
	low_solids.name = "LowSolids"
	low_solids.collision_layer = 4
	low_solids.collision_mask = 0
	add_child(low_solids)


func sheet(name: String) -> Texture2D:
	if not _sheets.has(name):
		_sheets[name] = load(NA + "tilesets/%s.png" % name)
	return _sheets[name]


func _make_props_and_decor() -> void:
	var chunks: Dictionary = {}
	var decor_tex := sheet("floor_detail")
	for d in data["decor"]:
		var kind: String = d[0]
		if not DECOR_CELLS.has(kind):
			continue
		var pos := Vector2(d[1], d[2])
		var cell: Vector2i = DECOR_CELLS[kind]
		_chunk(chunks, pos).items.append([decor_tex, Rect2(cell.x * 16, cell.y * 16, 16, 16), pos - Vector2(8, 12)])
	for p in data["props"]:
		_add_prop(p, chunks)
	for c in chunks.values():
		add_child(c)


func _chunk(chunks: Dictionary, pos: Vector2) -> DecorChunk:
	var key := Vector2i(int(pos.x / CHUNK), int(pos.y / CHUNK))
	if not chunks.has(key):
		var c := DecorChunk.new()
		c.z_index = -8
		c.name = "Decor_%d_%d" % [key.x, key.y]
		chunks[key] = c
	return chunks[key]


func _is_foliage(kind: String) -> bool:
	for p in FOLIAGE_PREFIX:
		if kind.begins_with(p):
			return true
	return false


func _add_prop(p: Dictionary, chunks: Dictionary) -> void:
	var kind: String = p["k"]
	if not prop_defs.has(kind):
		return
	var def: Dictionary = prop_defs[kind]
	var r: Array = def["rect"]
	var rect := Rect2(r[0], r[1], r[2], r[3])
	var pos := Vector2(p["x"], p["y"])
	var s := Sprite2D.new()
	s.texture = sheet(def["sheet"])
	s.region_enabled = true
	s.region_rect = rect
	s.centered = false
	s.offset = Vector2(-floorf(rect.size.x / 2.0), -rect.size.y)
	s.position = pos
	s.name = "%s_%d" % [kind, prop_count]
	prop_count += 1
	var is_breakable := kind in BREAKABLE
	if kind.begins_with("bush"):
		s.material = bush_material
	elif _is_foliage(kind):
		s.material = foliage_material
	entities.add_child(s)
	# ground contact shadow
	var sw := rect.size.x * (0.86 if _is_foliage(kind) else 0.95)
	var sh := clampf(rect.size.y * 0.22, 5.0, 14.0)
	_chunk(chunks, pos).shadows.append(Rect2(pos.x - sw / 2.0, pos.y - sh * 0.62, sw, sh))
	var shape_nodes: Array = []
	if p.has("c"):
		var c: Dictionary = p["c"]
		var low: bool = c.get("low", false)
		var body := low_solids if low else solids
		var size := Vector2(c["w"], c["h"])
		if c.has("split"):
			for sx in [-1, 1]:
				shape_nodes.append(_add_rect(body, pos + Vector2(sx * float(c["split"]), float(c["oy"])), size))
		else:
			shape_nodes.append(_add_rect(body, pos + Vector2(0, float(c["oy"])), size))
		if not low:
			_mark_solid(Rect2(pos + Vector2(-size.x / 2.0, float(c["oy"]) - size.y / 2.0), size))
	if is_breakable:
		breakables.append({"sprite": s, "shapes": shape_nodes, "pos": pos + Vector2(0, -6), "kind": kind, "alive": true})
	if LIGHT_PROPS.has(kind):
		_add_light(pos + Vector2(0, -rect.size.y * 0.6), LIGHT_PROPS[kind], 0.55 if kind == "stone_lantern" else 0.4)


func _add_rect(body: StaticBody2D, center: Vector2, size: Vector2) -> CollisionShape2D:
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	cs.shape = shape
	cs.position = center
	body.add_child(cs)
	return cs


func _mark_solid(r: Rect2) -> void:
	var x0 := int(floor(r.position.x / 16.0))
	var y0 := int(floor(r.position.y / 16.0))
	var x1 := int(floor(r.end.x / 16.0))
	var y1 := int(floor(r.end.y / 16.0))
	for y in range(maxi(0, y0), mini(tiles.y, y1 + 1)):
		for x in range(maxi(0, x0), mini(tiles.x, x1 + 1)):
			solid_grid[y * tiles.x + x] = 1


func _add_light(pos: Vector2, color: Color, energy: float) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = light_texture()
	l.color = color
	l.energy = 0.0
	l.texture_scale = 1.3
	l.position = pos
	l.set_meta("base_energy", energy)
	add_child(l)
	lights.append(l)
	return l


static var _light_tex: Texture2D


static func light_texture() -> Texture2D:
	if _light_tex != null:
		return _light_tex
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	g.add_point(0.35, Color(1, 1, 1, 0.55))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 128
	t.height = 128
	_light_tex = t
	return t


func _make_bounds() -> void:
	bounds = StaticBody2D.new()
	bounds.name = "WorldBounds"
	bounds.collision_layer = 1
	add_child(bounds)
	var t := 64.0
	_add_rect(bounds, Vector2(world_size.x / 2.0, 8.0 - t / 2.0), Vector2(world_size.x + t * 2.0, t))
	_add_rect(bounds, Vector2(world_size.x / 2.0, world_size.y - 8.0 + t / 2.0), Vector2(world_size.x + t * 2.0, t))
	_add_rect(bounds, Vector2(8.0 - t / 2.0, world_size.y / 2.0), Vector2(t, world_size.y + t * 2.0))
	_add_rect(bounds, Vector2(world_size.x - 8.0 + t / 2.0, world_size.y / 2.0), Vector2(t, world_size.y + t * 2.0))


# ------------------------------------------------------------------ queries
func biome_at(pos: Vector2) -> int:
	var x := clampi(int(pos.x / 16.0), 0, tiles.x - 1)
	var y := clampi(int(pos.y / 16.0), 0, tiles.y - 1)
	return int(round(biome_image.get_pixel(x, y).r * 255.0))


func field_at(pos: Vector2) -> Color:
	var fx := clampi(int(pos.x / 16.0 * field_res), 0, tiles.x * field_res - 1)
	var fy := clampi(int(pos.y / 16.0 * field_res), 0, tiles.y * field_res - 1)
	return field_image.get_pixel(fx, fy)


func is_water(pos: Vector2) -> bool:
	return field_at(pos).g > 0.5


func is_road(pos: Vector2) -> bool:
	return field_at(pos).r > 0.5


func is_solid(pos: Vector2) -> bool:
	if pos.x < 0 or pos.y < 0 or pos.x >= world_size.x or pos.y >= world_size.y:
		return true
	return solid_grid[int(pos.y / 16.0) * tiles.x + int(pos.x / 16.0)] == 1


func region_name(pos: Vector2) -> String:
	var lm: Dictionary = data["landmarks"]
	var v := Vector2(lm["hearthgrove"][0], lm["hearthgrove"][1])
	if pos.distance_to(v) < 26.0 * 16.0:
		return "Hearthgrove"
	var mw := Vector2(lm["moonwell"][0], lm["moonwell"][1])
	if pos.distance_to(mw) < 13.0 * 16.0:
		return "The Moonwell"
	if pos.distance_to(Vector2(lm["lake_lumen"][0], lm["lake_lumen"][1])) < 15.0 * 16.0:
		return "Lake Lumen"
	var names: Array = data["biome_names"]
	return names[clampi(biome_at(pos), 0, names.size() - 1)]


func break_at(center: Vector2, radius: float) -> Array:
	var broken: Array = []
	for b in breakables:
		if b["alive"] and (b["pos"] as Vector2).distance_to(center) <= radius:
			b["alive"] = false
			(b["sprite"] as Sprite2D).visible = false
			for s in b["shapes"]:
				(s as CollisionShape2D).set_deferred("disabled", true)
			broken.append(b)
	return broken


func update_foliage(player_pos: Vector2, gust: float) -> void:
	foliage_material.set_shader_parameter("player_pos", player_pos)
	foliage_material.set_shader_parameter("gust", gust)
	bush_material.set_shader_parameter("gust", gust * 0.6)


func set_night(darkness: float) -> void:
	for l in lights:
		l.energy = float(l.get_meta("base_energy")) * pow(darkness, 1.6)
		l.visible = darkness > 0.02


class DecorChunk:
	extends Node2D
	var items: Array = []
	var shadows: Array = []
	static var shadow_tex: Texture2D

	func _ready() -> void:
		if shadow_tex == null:
			var g := Gradient.new()
			g.set_color(0, Color(0, 0, 0, 1))
			g.set_color(1, Color(0, 0, 0, 0))
			var t := GradientTexture2D.new()
			t.gradient = g
			t.fill = GradientTexture2D.FILL_RADIAL
			t.fill_from = Vector2(0.5, 0.5)
			t.fill_to = Vector2(1.0, 0.5)
			t.width = 32
			t.height = 16
			shadow_tex = t
		queue_redraw()

	func _draw() -> void:
		for r in shadows:
			draw_texture_rect(shadow_tex, r, false, Color(0.08, 0.1, 0.16, 0.30))
		for it in items:
			draw_texture_rect_region(it[0], Rect2(it[2], Vector2(16, 16)), it[1], Color(0.93, 0.93, 0.93))
