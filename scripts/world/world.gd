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

## Starfall Rise: a scripted seventh biome appended east of the dunes at runtime.
const STARFALL := 6
const EXPAND_EAST := 48
const STARFALL_SEED := 20261012
const STARFALL_ROAD := [[228.0, 122.0], [244.0, 116.0], [258.0, 106.0], [272.0, 100.0], [283.0, 94.0], [287.0, 92.0]]
const STARFALL_LAKE := [276.0, 58.0]
const STARFALL_POND := [294.0, 138.0]

## Emberleaf Vale: an autumn valley appended east of Starfall Rise. Reached by
## the Ember Road through a gap in Starfall's white grove wall.
const EMBER := 7
const EXPAND_EAST2 := 40
const EMBER_SEED := 20261013
const EMBER_ROAD := [[287.0, 92.0], [294.0, 94.0], [300.0, 96.0], [306.0, 97.0], [314.0, 98.0], [322.0, 98.0]]
const EMBER_PLAZA := [322.0, 98.0]
const EMBER_ARENA := [331.0, 62.0]
const EMBER_POND := [313.0, 124.0]
const EMBER_GROVE := [335.0, 138.0]
## Rows of Starfall's east wall left open for the Ember Road.
const EMBER_GATE_ROWS := [93, 101]

const DECOR_CELLS := {
	"fd_leaves": Vector2i(0, 0), "fd_pebbles": Vector2i(4, 0), "fd_sticks": Vector2i(5, 0), "fd_sand_rock": Vector2i(9, 0),
	"fd_bone": Vector2i(14, 0), "fd_shell": Vector2i(15, 0), "fd_pebbles_gray": Vector2i(0, 1), "fd_flower_yellow": Vector2i(2, 0),
	"fd_tuft": Vector2i(0, 2), "fd_sprout": Vector2i(1, 2), "fd_tuft2": Vector2i(2, 2), "fd_grass": Vector2i(3, 2),
	"fd_flower_red": Vector2i(5, 2), "fd_clover": Vector2i(6, 2), "fd_leafy": Vector2i(7, 2), "fd_flower_white": Vector2i(2, 0),
	"fd_white_tuft": Vector2i(0, 3), "fd_white_tuft2": Vector2i(2, 3), "fd_white_flower": Vector2i(5, 3),
}
const FOLIAGE_PREFIX := ["tree_", "big_", "grove_", "palm", "bamboo", "small_tree", "thin"]
const BREAKABLE := ["bush_round", "bush_round2", "pot", "pot_red", "crate", "pot_desert", "barrel", "ember_ore"]
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
var interior_footprints: Array = []
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
	_expand_starfall()
	_expand_ember()
	_clear_interiors()
	biome_tex = ImageTexture.create_from_image(biome_image)
	field_tex = ImageTexture.create_from_image(field_image)
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
		Vector4(0, 12, 1, 4), Vector4(11, 12, 12, 4), Vector4(0, 5, 1, 4), Vector4(0, 19, 1, 4), Vector4(11, 19, 12, 4), Vector4(1, 1, 0, 0), Vector4(0, 12, 1, 4), Vector4(0, 12, 1, 4)]))
	ground_material.set_shader_parameter("path_tiles", PackedVector4Array([
		Vector4(1, 8, 0, 0), Vector4(12, 8, 11, 0), Vector4(1, 1, 0, 0), Vector4(1, 22, 0, 0), Vector4(12, 15, 11, 0), Vector4(0, 5, 1, 2), Vector4(1, 22, 0, 0), Vector4(1, 8, 0, 0)]))
	ground_material.set_shader_parameter("water_shallow", PackedColorArray([
		Color("63d3e4"), Color("57c9c4"), Color("5cdbe0"), Color("7fa8ea"), Color("6cc7b0"), Color("62cbe6"), Color("8f86e8"), Color("7cc6d8")]))
	ground_material.set_shader_parameter("water_deep", PackedColorArray([
		Color("3a95c8"), Color("2f8a97"), Color("2fa6c2"), Color("4a5cb8"), Color("3b8a7c"), Color("2c7cc0"), Color("4f46a0"), Color("3a7f9a")]))
	ground_material.set_shader_parameter("biome_grade", PackedColorArray([
		Color(0.78, 0.98, 0.86, 0.42), Color(0.80, 0.98, 0.90, 0.25), Color(1.0, 0.93, 0.86, 0.10), Color(0.80, 0.80, 0.95, 0.45), Color(0.96, 0.98, 0.90, 0.15), Color(1, 1, 1, 0.0), Color(0.84, 0.80, 1.02, 0.42), Color(1.06, 0.80, 0.56, 0.46)]))
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


# ------------------------------------------------------------------ Starfall Rise
func _expand_starfall() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = STARFALL_SEED
	# grow the biome map east: beach rows stay beach, everything else becomes starfall
	var old_w := biome_image.get_width()
	var new_w := old_w + EXPAND_EAST
	var h := biome_image.get_height()
	var grow := Image.create(new_w, h, false, biome_image.get_format())
	grow.blit_rect(biome_image, Rect2i(0, 0, old_w, h), Vector2i.ZERO)
	for y in range(h):
		var edge := biome_image.get_pixel(old_w - 1, y)
		var b := int(round(edge.r * 255.0))
		if b != BEACH:
			b = STARFALL
		for x in range(old_w, new_w):
			grow.set_pixel(x, y, Color(b / 255.0, b / 255.0, b / 255.0))
	biome_image = grow
	# grow the field map east, continuing the southern sea
	var fw_old := field_image.get_width()
	var fh := field_image.get_height()
	var fw_new := new_w * field_res
	var fgrow := Image.create(fw_new, fh, false, field_image.get_format())
	fgrow.blit_rect(field_image, Rect2i(0, 0, fw_old, fh), Vector2i.ZERO)
	for fy in range(fh):
		var fedge := field_image.get_pixel(fw_old - 1, fy)
		if fedge.g > 0.5:
			for fx in range(fw_old, fw_new):
				fgrow.set_pixel(fx, fy, Color(0.0, fedge.g, fedge.b))
	field_image = fgrow
	# the pilgrim road: dunes to the Starfall Watch plaza, then a branch north to Mirror Basin
	for i in range(STARFALL_ROAD.size() - 1):
		_star_stamp_road(STARFALL_ROAD[i], STARFALL_ROAD[i + 1])
	_star_stamp_road_plaza(287.0, 92.0, 3.5)
	var branch := [[287.0, 92.0], [283.0, 80.0], [278.0, 70.0], [276.0, 64.0]]
	for i in range(branch.size() - 1):
		_star_stamp_road(branch[i], branch[i + 1])
	# Mirror Basin with a small island, and the southern pond
	_star_stamp_water(STARFALL_LAKE[0], STARFALL_LAKE[1], 8.0, 5.0, rng)
	_star_clear_water(277.0, 56.0, 1.9, 1.3)
	_star_stamp_water(STARFALL_POND[0], STARFALL_POND[1], 4.0, 3.0, rng)
	# the first stretch of the Ember Road (the rest is stamped once the vale exists)
	for i in range(EMBER_ROAD.size() - 1):
		_star_stamp_road(EMBER_ROAD[i], EMBER_ROAD[i + 1])
	# widen the world bookkeeping
	tiles = Vector2i(new_w, tiles.y)
	world_size = Vector2(tiles) * 16.0
	data["tiles"] = [new_w, tiles.y]
	if not (data["biome_names"] as Array).has("Starfall Rise"):
		(data["biome_names"] as Array).append("Starfall Rise")
	data["landmarks"]["starfall_shrine"] = [287 * 16, 91 * 16]
	data["landmarks"]["mirror_lake"] = [int(STARFALL_LAKE[0]) * 16, int(STARFALL_LAKE[1]) * 16]
	_star_place_actors(rng)


func _star_field(tx: float, ty: float) -> Color:
	var fx := clampi(int(tx * field_res), 0, field_image.get_width() - 1)
	var fy := clampi(int(ty * field_res), 0, field_image.get_height() - 1)
	return field_image.get_pixel(fx, fy)


func _star_stamp_road(a: Array, b: Array) -> void:
	var pa := Vector2(a[0], a[1])
	var pb := Vector2(b[0], b[1])
	var steps := int(pa.distance_to(pb) * 2.0) + 1
	for i in range(steps + 1):
		_star_stamp_road_disc(pa.lerp(pb, float(i) / float(steps)), 1.1)


func _star_stamp_road_plaza(cx: float, cy: float, r: float) -> void:
	_star_stamp_road_disc(Vector2(cx, cy), r)


func _star_stamp_road_disc(center: Vector2, radius: float) -> void:
	var max_tx := field_image.get_width() / field_res - 1
	var max_ty := field_image.get_height() / field_res - 1
	var x0 := maxi(0, int(floor(center.x - radius)))
	var x1 := mini(max_tx, int(ceil(center.x + radius)))
	var y0 := maxi(0, int(floor(center.y - radius)))
	var y1 := mini(max_ty, int(ceil(center.y + radius)))
	for ty in range(y0, y1 + 1):
		for tx in range(x0, x1 + 1):
			if Vector2(float(tx) + 0.5, float(ty) + 0.5).distance_to(center) > radius + 0.35:
				continue
			for fy in range(field_res):
				for fx in range(field_res):
					var px := tx * field_res + fx
					var py := ty * field_res + fy
					var c := field_image.get_pixel(px, py)
					if c.g <= 0.5:
						field_image.set_pixel(px, py, Color(1.0, 0.0, 0.0))


func _star_stamp_water(cx: float, cy: float, rx: float, ry: float, rng: RandomNumberGenerator) -> void:
	for ty in range(int(cy - ry - 1.0), int(cy + ry + 2.0)):
		for tx in range(int(cx - rx - 1.0), int(cx + rx + 2.0)):
			var nx := (float(tx) + 0.5 - cx) / rx
			var ny := (float(ty) + 0.5 - cy) / ry
			var e := nx * nx + ny * ny
			if e > 1.0 + rng.randf_range(-0.07, 0.09):
				continue
			var deep := 0.0 if e < 0.55 else 0.65
			for fy in range(field_res):
				for fx in range(field_res):
					var px := tx * field_res + fx
					var py := ty * field_res + fy
					if px < 0 or py < 0 or px >= field_image.get_width() or py >= field_image.get_height():
						continue
					field_image.set_pixel(px, py, Color(0.0, 1.0, deep))


func _star_clear_water(cx: float, cy: float, rx: float, ry: float) -> void:
	for ty in range(int(cy - ry - 1.0), int(cy + ry + 2.0)):
		for tx in range(int(cx - rx - 1.0), int(cx + rx + 2.0)):
			var nx := (float(tx) + 0.5 - cx) / rx
			var ny := (float(ty) + 0.5 - cy) / ry
			if nx * nx + ny * ny > 1.0:
				continue
			for fy in range(field_res):
				for fx in range(field_res):
					var px := tx * field_res + fx
					var py := ty * field_res + fy
					if px < 0 or py < 0 or px >= field_image.get_width() or py >= field_image.get_height():
						continue
					field_image.set_pixel(px, py, Color(0.0, 0.0, 0.0))


## Punch quiet land into the far-south sea for every enterable interior, so
## the ground shader, minimap and is_water() treat the rooms as solid ground.
func _clear_interiors() -> void:
	for f in interior_footprints:
		var cx := float(f[0])
		var cy := float(f[1])
		var w := float(f[2])
		var h := float(f[3])
		var x0 := int((cx - w * 0.5 - 12.0) / 16.0 * field_res)
		var x1 := int((cx + w * 0.5 + 12.0) / 16.0 * field_res)
		var y0 := int((cy - h * 0.5 - 12.0) / 16.0 * field_res)
		var y1 := int((cy + h * 0.5 + 12.0) / 16.0 * field_res)
		for py in range(y0, y1):
			for px in range(x0, x1):
				if px < 0 or py < 0 or px >= field_image.get_width() or py >= field_image.get_height():
					continue
				field_image.set_pixel(px, py, Color(0.0, 0.0, 0.0))


func _star_free(tx: float, ty: float, occupied: Dictionary, rad: float) -> bool:
	var f := _star_field(tx, ty)
	if f.g > 0.35 or f.r > 0.25:
		return false
	var cx := int(tx * 2.0)
	var cy := int(ty * 2.0)
	var r := int(ceil(rad * 2.0))
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if occupied.has(Vector2i(cx + dx, cy + dy)):
				return false
	return true


func _star_collision(kind: String) -> Dictionary:
	if kind in ["pillar", "statue_eye", "statue_monk", "stone_lantern", "sign", "grave", "cross", "bench"]:
		return {"w": 10.0, "h": 7.0, "oy": -4.0}
	if kind in ["tree_white", "big_white", "grove_white", "cliff_rock_gray"]:
		return {"w": 13.0, "h": 9.0, "oy": -5.0}
	if kind in ["boulder_gray", "tall_rock_gray", "rocks_gray"]:
		return {"w": 11.0, "h": 8.0, "oy": -4.0}
	if kind in ["pebble_gray", "bush_round2"]:
		return {"w": 9.0, "h": 6.0, "oy": -3.0, "low": true}
	return {}


func _star_add_prop(kind: String, tx: float, ty: float, occupied: Dictionary, force := false, rad := 0.8) -> bool:
	if not force and not _star_free(tx, ty, occupied, rad):
		return false
	var cx := int(tx * 2.0)
	var cy := int(ty * 2.0)
	var r := int(ceil(rad * 2.0))
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			occupied[Vector2i(cx + dx, cy + dy)] = true
	var entry := {"k": kind, "x": round(tx * 16.0), "y": round(ty * 16.0)}
	var col := _star_collision(kind)
	if not col.is_empty():
		entry["c"] = col
	data["props"].append(entry)
	return true


func _star_place_actors(rng: RandomNumberGenerator) -> void:
	var new_w := biome_image.get_width()
	var old_w := new_w - EXPAND_EAST
	var h := tiles.y
	var occupied: Dictionary = {}
	# white grove walls along the new east edge
	for ty in range(4, h - 4):
		if ty >= EMBER_GATE_ROWS[0] and ty <= EMBER_GATE_ROWS[1]:
			continue
		if ty % 2 == 0:
			_star_add_prop("tree_white", float(new_w) - 2.5, float(ty) + 0.5, occupied, true, 0.9)
		elif ty % 4 == 1:
			_star_add_prop("tree_white", float(new_w) - 4.5, float(ty) + 0.5, occupied, true, 0.9)
	# Starfall Watch: a ring of pillars and the eye statue above the plaza
	for i in range(6):
		var ang := TAU * i / 6.0 + PI / 6.0
		_star_add_prop("pillar", 287.0 + cos(ang) * 5.0, 91.0 + sin(ang) * 3.6, occupied, true, 0.8)
	_star_add_prop("statue_eye", 287.0, 86.5, occupied, true, 0.8)
	for l in [[250.0, 113.0], [266.0, 101.0], [280.0, 95.0]]:
		_star_add_prop("stone_lantern", l[0], l[1], occupied, true, 0.8)
	# scatter props and ground decor across the new tiles
	var scatter := [
		["tree_white", 0.030, 0.9], ["big_white", 0.004, 1.1], ["boulder_gray", 0.007, 0.9],
		["tall_rock_gray", 0.004, 0.8], ["pebble_gray", 0.020, 0.4], ["bush_round2", 0.012, 0.5],
		["rocks_gray", 0.002, 1.2], ["grave", 0.0015, 0.4], ["cliff_rock_gray", 0.002, 1.3]]
	var decor_kinds := ["fd_white_flower", "fd_white_tuft", "fd_white_tuft2", "fd_pebbles_gray", "fd_clover"]
	for ty in range(h):
		for tx in range(old_w, new_w):
			for s in scatter:
				if rng.randf() < float(s[1]):
					_star_add_prop(s[0], float(tx) + 0.5, float(ty) + 0.5, occupied, false, float(s[2]))
			if rng.randf() < 0.26:
				var f := _star_field(float(tx) + 0.5, float(ty) + 0.5)
				if f.g <= 0.4 and f.r <= 0.3:
					data["decor"].append([decor_kinds[rng.randi() % decor_kinds.size()], round((float(tx) + 0.5) * 16.0), round((float(ty) + 0.5) * 16.0)])
	# fixed monster camps along the road and around the basin
	for s in [["spirit", 270.0, 100.0], ["bluebat", 275.0, 105.0], ["eye", 282.0, 88.0], ["skull", 290.0, 97.0],
			["slime3", 295.0, 120.0], ["slime3", 278.0, 132.0], ["spirit2", 268.0, 120.0], ["lizard", 260.0, 112.0],
			["lizard", 250.0, 110.0], ["mole", 288.0, 108.0], ["spirit", 293.0, 80.0], ["bluebat", 283.0, 74.0],
			["spirit", 265.0, 95.0], ["bluebat", 272.0, 88.0], ["spirit", 296.0, 128.0], ["eye", 258.0, 96.0]]:
		data["enemies"].append({"s": s[0], "x": round(s[1] * 16.0), "y": round(s[2] * 16.0)})
	# treasure
	data["chests"].append({"id": "c_star_heart", "x": 289 * 16, "y": 86 * 16, "item": "heart_piece"})
	data["chests"].append({"id": "c_star_coins", "x": 277 * 16, "y": 56 * 16, "item": "coins_50", "big": true})
	data["chests"].append({"id": "c_star_tea", "x": 296 * 16, "y": 131 * 16, "item": "moontea"})
	# the sixth waystone and its keeper
	data["shrines"].append({"id": "starfall", "name": "Starfall Waystone", "x": 287 * 16, "y": 91 * 16})
	data["npcs"].append({"id": "lumen", "sprite": "monk", "name": "Lumen the Stargazer", "x": 284 * 16, "y": 95 * 16, "wander": 18})
	data["animals"].append({"sprite": "frog", "x": 280 * 16, "y": 64 * 16, "wander": 30})
	# villagers drift to their night anchors after dark
	var night_off := {"alder": [40, 24], "mira": [64, -16], "kit": [-48, 64], "bramble": [48, -48], "tallow": [96, 32], "hana": [48, 48]}
	for d in data["npcs"]:
		if night_off.has(d["id"]):
			d["night"] = [d["x"] + night_off[d["id"]][0], d["y"] + night_off[d["id"]][1]]


# ------------------------------------------------------------------ Emberleaf Vale
func _expand_ember() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = EMBER_SEED
	var old_w := biome_image.get_width()
	var new_w := old_w + EXPAND_EAST2
	var h := biome_image.get_height()
	var grow := Image.create(new_w, h, false, biome_image.get_format())
	grow.blit_rect(biome_image, Rect2i(0, 0, old_w, h), Vector2i.ZERO)
	for y in range(h):
		var b := int(round(biome_image.get_pixel(old_w - 1, y).r * 255.0))
		if b != BEACH:
			b = EMBER
		for x in range(old_w, new_w):
			grow.set_pixel(x, y, Color(b / 255.0, b / 255.0, b / 255.0))
	biome_image = grow
	var fw_old := field_image.get_width()
	var fh := field_image.get_height()
	var fw_new := new_w * field_res
	var fgrow := Image.create(fw_new, fh, false, field_image.get_format())
	fgrow.blit_rect(field_image, Rect2i(0, 0, fw_old, fh), Vector2i.ZERO)
	for fy in range(fh):
		var fedge := field_image.get_pixel(fw_old - 1, fy)
		if fedge.g > 0.5:
			for fx in range(fw_old, fw_new):
				fgrow.set_pixel(fx, fy, Color(0.0, fedge.g, fedge.b))
	field_image = fgrow
	# the Ember Road to Cinderbrook Camp, north to the Emberbark's hollow, south to Amber Pond
	for i in range(EMBER_ROAD.size() - 1):
		_star_stamp_road(EMBER_ROAD[i], EMBER_ROAD[i + 1])
	_star_stamp_road_plaza(EMBER_PLAZA[0], EMBER_PLAZA[1], 4.0)
	var north := [[322.0, 98.0], [325.0, 86.0], [329.0, 74.0], [331.0, 67.0]]
	for i in range(north.size() - 1):
		_star_stamp_road(north[i], north[i + 1])
	_star_stamp_road_plaza(EMBER_ARENA[0], EMBER_ARENA[1] + 1.0, 2.2)
	var south := [[322.0, 98.0], [319.0, 108.0], [316.0, 117.0]]
	for i in range(south.size() - 1):
		_star_stamp_road(south[i], south[i + 1])
	_star_stamp_water(EMBER_POND[0], EMBER_POND[1], 4.5, 3.0, rng)
	# Starfall props that ended up on the now-complete road near the gate
	var keep: Array = []
	for pr in data["props"]:
		var ptx := float(pr["x"]) / 16.0
		var pty := float(pr["y"]) / 16.0
		if ptx > 290.0 and ptx < float(old_w) and pty > 88.0 and pty < 104.0:
			var on_road := false
			for o in [Vector2(0, 0), Vector2(0, -0.8), Vector2(0, -1.6), Vector2(0.6, -0.5), Vector2(-0.6, -0.5), Vector2(0, 0.6)]:
				if _star_field(ptx + o.x, pty + o.y).r > 0.25:
					on_road = true
			if on_road:
				continue
		keep.append(pr)
	data["props"] = keep
	tiles = Vector2i(new_w, tiles.y)
	world_size = Vector2(tiles) * 16.0
	data["tiles"] = [new_w, tiles.y]
	if not (data["biome_names"] as Array).has("Emberleaf Vale"):
		(data["biome_names"] as Array).append("Emberleaf Vale")
	data["landmarks"]["cinderbrook"] = [int(EMBER_PLAZA[0]) * 16, int(EMBER_PLAZA[1]) * 16]
	data["landmarks"]["emberbark_hollow"] = [int(EMBER_ARENA[0]) * 16, int(EMBER_ARENA[1]) * 16]
	data["landmarks"]["amber_pond"] = [int(EMBER_POND[0]) * 16, int(EMBER_POND[1]) * 16]
	_ember_place_actors(rng, old_w)


func _ember_collision(kind: String) -> Dictionary:
	if kind in ["big_orange"]:
		return {"w": 14.0, "h": 9.0, "oy": -5.0}
	if kind in ["tree_dead", "grove_dead"]:
		return {"w": 12.0, "h": 8.0, "oy": -4.0}
	if kind in ["stump", "boulder_brown", "oven", "stall_red", "rocks_brown"]:
		return {"w": 14.0 if kind == "rocks_brown" else 11.0, "h": 8.0, "oy": -4.0}
	if kind in ["stone_lantern", "sign", "haystack", "barrel", "rock_orange"]:
		return {"w": 10.0, "h": 7.0, "oy": -4.0}
	if kind in ["log", "ember_ore", "bush_round"]:
		return {"w": 10.0, "h": 6.0, "oy": -3.0, "low": kind == "log"}
	return {}


func _ember_add_prop(kind: String, tx: float, ty: float, occupied: Dictionary, force := false, rad := 0.8) -> bool:
	if not _star_add_prop(kind, tx, ty, occupied, force, rad):
		return false
	var col := _ember_collision(kind)
	if not col.is_empty():
		(data["props"] as Array)[-1]["c"] = col
	return true


## Mark a disc as taken so scatter keeps camps, arenas and chests clear.
func _ember_reserve(occupied: Dictionary, tx: float, ty: float, rad: float) -> void:
	var r := int(ceil(rad * 2.0))
	var cx := int(tx * 2.0)
	var cy := int(ty * 2.0)
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx * dx + dy * dy <= r * r:
				occupied[Vector2i(cx + dx, cy + dy)] = true


func _ember_place_actors(rng: RandomNumberGenerator, old_w: int) -> void:
	var new_w := biome_image.get_width()
	var h := tiles.y
	var occupied: Dictionary = {}
	# autumn grove wall along the new east edge
	for ty in range(4, h - 4):
		if ty % 2 == 0:
			_ember_add_prop("big_orange" if ty % 6 != 0 else "tree_dead", float(new_w) - 2.5, float(ty) + 0.5, occupied, true, 0.9)
		elif ty % 4 == 1:
			_ember_add_prop("tree_dead", float(new_w) - 4.5, float(ty) + 0.5, occupied, true, 0.9)
	# Cinderbrook Camp: a hunters' market around the plaza
	var px: float = EMBER_PLAZA[0]
	var py: float = EMBER_PLAZA[1]
	_ember_reserve(occupied, px, py, 6.5)
	for it in [["stall_red", px - 4.5, py - 3.5], ["oven", px + 4.5, py - 3.5], ["haystack", px + 6.0, py - 1.5],
			["haystack", px + 6.5, py + 0.5], ["barrel", px - 6.0, py - 2.0], ["barrel", px - 6.2, py - 0.6],
			["log", px - 3.0, py + 4.5], ["log", px + 3.0, py + 4.5], ["sign", 309.0, 95.6],
			["stone_lantern", 304.0, 95.0], ["stone_lantern", 314.0, 96.0], ["stone_lantern", px - 2.5, py - 4.5],
			["stone_lantern", px + 2.5, py - 4.5]]:
		_ember_add_prop(it[0], it[1], it[2], occupied, true, 0.6)
	# the Emberbark's hollow: a ring of stumps and boulders, open to the south road
	var ax: float = EMBER_ARENA[0]
	var ay: float = EMBER_ARENA[1]
	_ember_reserve(occupied, ax, ay, 9.5)
	for i in range(18):
		var ang := TAU * i / 18.0
		if absf(wrapf(ang - PI / 2.0, -PI, PI)) < 0.5:
			continue
		_ember_add_prop("boulder_brown" if i % 3 == 0 else ("stump" if i % 3 == 1 else "big_orange"),
				ax + cos(ang) * 9.0, ay + sin(ang) * 7.0, occupied, true, 0.8)
	# keep chest spots and the grove clear
	for c in [[EMBER_GROVE[0], EMBER_GROVE[1]], [px + 1.5, py - 5.5], [EMBER_POND[0] + 6.0, EMBER_POND[1] - 1.0]]:
		_ember_reserve(occupied, c[0], c[1], 1.5)
	for i in range(8):
		var ang := TAU * i / 8.0
		_ember_add_prop("big_orange" if i % 2 == 0 else "tree_dead", EMBER_GROVE[0] + cos(ang) * 4.0, EMBER_GROVE[1] + sin(ang) * 3.0, occupied, i != 2, 0.9)
	# scatter: dense autumn canopy with clearings, ore and herb nodes to gather
	var scatter := [
		["big_orange", 0.024, 1.1], ["tree_dead", 0.006, 0.9], ["grove_dead", 0.0012, 1.7], ["stump", 0.004, 0.8],
		["log", 0.003, 0.6], ["boulder_brown", 0.004, 0.9], ["rocks_brown", 0.0012, 1.5], ["shrub_dry", 0.010, 0.4],
		["rock_orange", 0.004, 0.5], ["leaf_orange", 0.012, 0.4], ["ember_ore", 0.004, 0.6], ["bush_round", 0.006, 0.5]]
	var decor_kinds := ["fd_leaves", "fd_leaves", "fd_sticks", "fd_flower_red", "fd_tuft", "fd_pebbles"]
	for ty in range(h):
		for tx in range(old_w, new_w):
			for sc in scatter:
				if rng.randf() < float(sc[1]):
					_ember_add_prop(sc[0], float(tx) + 0.5, float(ty) + 0.5, occupied, false, float(sc[2]))
			if rng.randf() < 0.24:
				var f := _star_field(float(tx) + 0.5, float(ty) + 0.5)
				if f.g <= 0.4 and f.r <= 0.3:
					data["decor"].append([decor_kinds[rng.randi() % decor_kinds.size()], round((float(tx) + 0.5) * 16.0), round((float(ty) + 0.5) * 16.0)])
	# monster camps: tougher than Starfall, plus one elite on the hollow road
	for e in [["spiderred", 308.0, 104.0], ["spiderred", 311.0, 88.0], ["flam", 316.0, 84.0], ["flam", 333.0, 92.0],
			["snake2", 327.0, 108.0], ["snake2", 330.0, 116.0], ["owl", 318.0, 70.0], ["owl", 336.0, 78.0],
			["mushroom", 309.0, 118.0], ["mushroom", 320.0, 130.0], ["spirit2", 326.0, 140.0], ["cyclope", 333.0, 124.0],
			["skull", 312.0, 140.0], ["flam", 338.0, 104.0], ["spiderred", 306.0, 76.0], ["snake2", 324.0, 150.0]]:
		data["enemies"].append({"s": e[0], "x": round(e[1] * 16.0), "y": round(e[2] * 16.0)})
	data["enemies"].append({"s": "cyclope", "x": 327 * 16, "y": 80 * 16, "elite": true})
	# treasure: the mantle sits in the hidden grove, ore and coins elsewhere
	data["chests"].append({"id": "c_ember_mantle", "x": int(EMBER_GROVE[0] * 16.0), "y": int(EMBER_GROVE[1] * 16.0), "item": "emberleaf_mantle", "big": true})
	data["chests"].append({"id": "c_ember_heart", "x": int((px + 1.5) * 16.0), "y": int((py - 5.5) * 16.0), "item": "heart_piece"})
	data["chests"].append({"id": "c_ember_coins", "x": int((EMBER_POND[0] + 6.0) * 16.0), "y": int((EMBER_POND[1] - 1.0) * 16.0), "item": "coins_50"})
	# waystone, the camp's hunter, and the Emberbark
	data["shrines"].append({"id": "cinderbrook", "name": "Cinderbrook Waystone", "x": int(px * 16.0), "y": int((py - 1.0) * 16.0)})
	data["npcs"].append({"id": "rowan", "sprite": "hunter", "name": "Rowan the Hunter", "x": int((px - 2.0) * 16.0), "y": int((py + 2.0) * 16.0), "wander": 14})
	data["bosses"].append({"id": "emberbark", "kind": "emberbark", "name": "The Emberbark", "x": int(ax * 16.0), "y": int(ay * 16.0), "region": EMBER})
	data["animals"].append({"sprite": "frog", "x": int(EMBER_POND[0] * 16.0) - 80, "y": int(EMBER_POND[1] * 16.0) - 40, "wander": 24})


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
	if lm.has("cinderbrook") and pos.distance_to(Vector2(lm["cinderbrook"][0], lm["cinderbrook"][1])) < 9.0 * 16.0:
		return "Cinderbrook Camp"
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
