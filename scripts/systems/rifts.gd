extends Node
## Rare rift dungeons. A rift entrance tears open now and then at a validated
## overworld spot (never in water, walls, villages, houses, boss arenas or
## unreachable pockets), stays for a while, shows on the map, and leads to a
## separate three-chamber dungeon in the rift pocket far outside the world:
##   1. wave chamber  2. elite + cache chamber  3. Rift Warden (boss)
## Chambers are hand-made templates combined at random. Gates open when a
## chamber is cleared. A retreat portal is always at the start; the exit portal
## and reward cache appear when the warden falls. Each rift has a uid and its
## reward can be claimed once (saved immediately), so reloads and repeat boss
## kills never duplicate it. Dying or leaving keeps all normal progress.

const EnemyScript := preload("res://scripts/actors/enemy.gd")
const BossScript := preload("res://scripts/actors/boss.gd")
const DB := preload("res://scripts/data/db.gd")
const Loot := preload("res://scripts/systems/loot.gd")
const Inv := preload("res://scripts/systems/inventory.gd")
const Trade := preload("res://scripts/systems/trade.gd")
const AnimLib := preload("res://scripts/core/anim_lib.gd")
const FxScript := preload("res://scripts/core/fx.gd")

# ---- spawn configuration
const CHECK_INTERVAL := 30.0     # seconds of overworld play between spawn rolls
const SPAWN_CHANCE := 0.30       # chance per roll once MIN_INTERVAL has passed
const MIN_INTERVAL := 150.0      # never sooner than this after the last rift
const MAX_INTERVAL := 480.0      # always one by this time (discoverable in normal play)
const LIFETIME := 360.0          # an unvisited rift closes after this long
const MAX_ACTIVE := 1            # simultaneous entrances
const MIN_PLAYER_DIST := 260.0   # never opens right next to Mallow
const GRID_STEP := 10            # candidate grid, in tiles
const CLEARANCE := 22.0          # open ground needed around an entrance
const KEEP_OUT := 140.0          # distance from doors, waystones, NPCs, chests
const VILLAGE_KEEP_OUT := 260.0
const BOSS_KEEP_OUT := 220.0

# ---- dungeon configuration
const POCKET := Vector2(7000, 2400)
const ROOM := Vector2(240, 160)
const ROOM_GAP := 300.0
const TIERS := [
	{"name": "Shallow Rift", "min_level": 2, "kinds": ["slime", "slime2", "mushroom", "bluebat"], "elite": "mushroom2", "boss": "giantbamboo", "boss_hp": 0.55, "coins": 60},
	{"name": "Deep Rift", "min_level": 5, "kinds": ["snake2", "spiderred", "skull", "lizard"], "elite": "skull", "boss": "giantfrog", "boss_hp": 0.7, "coins": 100},
	{"name": "Starved Rift", "min_level": 8, "kinds": ["flam", "spirit2", "eye", "spirit"], "elite": "cyclope", "boss": "demoncyclop", "boss_hp": 0.85, "coins": 150},
]
## Pillar layouts per chamber (rects relative to the room centre). Each keeps a
## clear lane through the middle row so the gate is always reachable.
const LAYOUTS := [
	[],
	[Rect2(-70, -50, 16, 16), Rect2(54, -50, 16, 16), Rect2(-70, 34, 16, 16), Rect2(54, 34, 16, 16)],
	[Rect2(-20, -62, 40, 14), Rect2(-20, 48, 40, 14)],
	[Rect2(-90, -20, 14, 14), Rect2(76, -20, 14, 14), Rect2(-8, -64, 16, 12)],
]

## Rift look: Ninja Adventure (CC0) tiles, recoloured violet. Regions are in px.
const NA := "res://assets/packs/ninja_adventure/tilesets/"
const TILE_FLOOR := ["floor", Rect2(192, 240, 16, 16)]
const TILE_FLOOR_ALT := ["floor", Rect2(208, 240, 16, 16)]
const TILE_WALL := ["house", Rect2(112, 336, 16, 32)]
const TILE_BLOCK := ["house", Rect2(112, 336, 16, 16)]
const PROP_PILLAR := ["house", Rect2(0, 310, 16, 42)]
const PROP_CRYSTAL := ["nature", Rect2(32, 224, 16, 16)]
const PROP_GEM := ["nature", Rect2(32, 240, 16, 16)]
const PROP_STATUE := ["house", Rect2(49, 306, 30, 30)]
const FLOOR_BITS := [["floor_detail", Rect2(208, 0, 16, 16)], ["floor_detail", Rect2(224, 0, 16, 16)],
	["floor_detail", Rect2(0, 16, 16, 16)], ["floor_detail", Rect2(112, 0, 16, 16)], ["floor_detail", Rect2(64, 0, 16, 16)]]
const TINT_FLOOR := Color(0.62, 0.52, 0.86)
const TINT_WALL := Color(0.70, 0.60, 0.95)
const TINT_BLOCK := Color(0.82, 0.70, 1.0)
static var _tile_cache: Dictionary = {}

var game: Node
var valid_points: Array = []
var entrance: Dictionary = {}     # point, uid, left, tier, node
var claimed: Array = []
var active := false               # Mallow is inside a rift
var cleared := false
var room := 0
var _uid := 0
var _since := 0.0
var _check_t := 0.0
var _targets: Array = []
var _boss: Node = null
var _nodes: Array = []
var _gates: Array = []
var _return_pos := Vector2.ZERO
var _layouts: Array = []
var _run_tier := 0
var _run_uid := 0
var _cache_pos := Vector2.INF
var _exit_pos := Vector2.INF
var _spawned_rooms := {}
var _between_t := 0.0
var _wave := 0


func reset() -> void:
	if active:
		_teardown()
	active = false
	_close_entrance()
	claimed.clear()
	_uid = 0
	_since = 0.0
	_check_t = 0.0


# ------------------------------------------------------------------ spawn points
## Candidate grid filtered by every placement rule. Called once after the
## world is built (and lazily by tests).
func build_spawn_points() -> Array:
	valid_points.clear()
	var w: Node = game.world
	var reach := _reachable_grid()
	var tiles: Vector2i = w.tiles
	for ty in range(4, tiles.y - 4, GRID_STEP):
		for tx in range(4, tiles.x - 4, GRID_STEP):
			var p := Vector2(tx * 16 + 8, ty * 16 + 8)
			if is_valid_point(p, reach):
				valid_points.append(p)
	return valid_points


## Open, dry ground with clearance, reachable from the start (if a grid is given).
func is_open_ground(p: Vector2, reach: PackedByteArray = PackedByteArray()) -> bool:
	var w: Node = game.world
	if p.x < 32.0 or p.y < 32.0 or p.x > w.world_size.x - 32.0 or p.y > w.world_size.y - 32.0:
		return false
	for i in range(9):
		var q := p if i == 0 else p + Vector2.RIGHT.rotated(i * TAU / 8.0) * CLEARANCE
		if w.is_water(q) or w.is_solid(q):
			return false
	if not reach.is_empty():
		var idx: int = int(p.y / 16.0) * int(w.tiles.x) + int(p.x / 16.0)
		if idx < 0 or idx >= reach.size() or reach[idx] == 0:
			return false
	return true


func is_valid_point(p: Vector2, reach: PackedByteArray = PackedByteArray()) -> bool:
	var w: Node = game.world
	if not is_open_ground(p, reach):
		return false
	var lm: Array = w.data["landmarks"]["hearthgrove"]
	if p.distance_to(Vector2(lm[0], lm[1])) < VILLAGE_KEEP_OUT:
		return false
	for h in game.HOUSES:
		if not h.has("parent") and p.distance_to(h["door"]) < KEEP_OUT:
			return false
	for b in game.bosses:
		if p.distance_to(b.home) < BOSS_KEEP_OUT:
			return false
	for ws in game.waystones:
		if p.distance_to(ws["pos"]) < KEEP_OUT * 0.6:
			return false
	for n in game.npcs:
		if p.distance_to(n.global_position) < KEEP_OUT * 0.6:
			return false
	if p.distance_to(game.moonwell.global_position) < BOSS_KEEP_OUT:
		return false
	return true


## Flood fill from the start over walkable tiles: entrances must be reachable.
func _reachable_grid() -> PackedByteArray:
	var w: Node = game.world
	var tiles: Vector2i = w.tiles
	var out := PackedByteArray()
	out.resize(tiles.x * tiles.y)
	var start := Vector2i(int(w.data["start"][0] / 16.0), int(w.data["start"][1] / 16.0))
	var queue: Array[Vector2i] = [start]
	out[start.y * tiles.x + start.x] = 1
	var head := 0
	while head < queue.size():
		var c: Vector2i = queue[head]
		head += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = c + d
			if n.x < 0 or n.y < 0 or n.x >= tiles.x or n.y >= tiles.y:
				continue
			var idx := n.y * tiles.x + n.x
			if out[idx] == 1:
				continue
			var wp := Vector2(n.x * 16 + 8, n.y * 16 + 8)
			if w.solid_grid[idx] == 1 or w.is_water(wp):
				continue
			out[idx] = 1
			queue.append(n)
	return out


func tier_at(p: Vector2) -> int:
	var lm: Array = game.world.data["landmarks"]["hearthgrove"]
	var d := p.distance_to(Vector2(lm[0], lm[1]))
	return 0 if d < 1000.0 else (1 if d < 2000.0 else 2)


# ------------------------------------------------------------------ overworld tick
func _process(delta: float) -> void:
	if game == null or not game.game_started or game.game_over:
		return
	if active:
		_tick_dungeon(delta)
		return
	if game.is_inside() or game.depths.active:
		return
	if not entrance.is_empty():
		entrance["left"] = float(entrance["left"]) - delta
		if float(entrance["left"]) <= 0.0:
			game.hud.show_message("The rift has sealed itself.", 2.5)
			_close_entrance()
		return
	_since += delta
	_check_t += delta
	if _check_t < CHECK_INTERVAL:
		return
	_check_t = 0.0
	if _since >= MAX_INTERVAL or (_since >= MIN_INTERVAL and randf() < SPAWN_CHANCE):
		try_spawn()


## Opens a rift at a random valid point away from Mallow. Returns success.
func try_spawn(force_point := Vector2.INF) -> bool:
	if not entrance.is_empty() or active:
		return false
	if valid_points.is_empty():
		build_spawn_points()
	var p := force_point
	if p == Vector2.INF:
		var pool: Array = []
		for q in valid_points:
			if q.distance_to(game.player.global_position) >= MIN_PLAYER_DIST:
				pool.append(q)
		if pool.is_empty():
			return false
		p = pool[randi() % pool.size()]
	elif not is_valid_point(p):
		return false
	_uid += 1
	_since = 0.0
	entrance = {"point": p, "uid": _uid, "left": LIFETIME, "tier": tier_at(p)}
	_make_entrance_node()
	var t: Dictionary = TIERS[entrance["tier"]]
	game.hud.show_message("A %s has torn open in %s! (Lv %d+, marked on your map)" % [t["name"], game.world.region_name(p), int(t["min_level"])], 4.0)
	game.audio.play("secret2", 0.0, -2.0)
	return true


func _make_entrance_node() -> void:
	var n := RiftPortal.new()
	n.color = Color(0.75, 0.45, 1.0)
	n.global_position = entrance["point"]
	game.entities.add_child(n)
	entrance["node"] = n


func _close_entrance() -> void:
	if entrance.has("node") and is_instance_valid(entrance["node"]):
		entrance["node"].queue_free()
	entrance = {}


func entry_reason() -> String:
	if entrance.is_empty():
		return "No rift is open."
	var t: Dictionary = TIERS[entrance["tier"]]
	if game.player.level < int(t["min_level"]) and game.player.bag.get("rift_key", 0) <= 0:
		return "This rift needs level %d (or a Rift Key)." % int(t["min_level"])
	return ""


# ------------------------------------------------------------------ interaction
func interactable(pp: Vector2) -> Dictionary:
	if active:
		if pp.distance_to(_retreat_pos()) < 22.0:
			return {"type": "rift", "action": "retreat", "label": "RETREAT", "dist": pp.distance_to(_retreat_pos())}
		if _exit_pos != Vector2.INF and pp.distance_to(_exit_pos) < 22.0:
			return {"type": "rift", "action": "exit", "label": "LEAVE", "dist": pp.distance_to(_exit_pos)}
		if _cache_pos != Vector2.INF and pp.distance_to(_cache_pos) < 20.0 and not claimed.has(_run_uid):
			return {"type": "rift", "action": "cache", "label": "OPEN", "dist": pp.distance_to(_cache_pos)}
		return {}
	if not entrance.is_empty() and not game.is_inside():
		var d: float = pp.distance_to(entrance["point"])
		if d < 24.0:
			var t: Dictionary = TIERS[entrance["tier"]]
			return {"type": "rift", "action": "enter", "label": "RIFT Lv%d" % int(t["min_level"]), "dist": d}
	return {}


func interact(action: String) -> bool:
	match action:
		"enter":
			return enter()
		"retreat", "exit":
			return leave(action == "exit")
		"cache":
			return claim_cache()
	return false


# ------------------------------------------------------------------ dungeon
func enter() -> bool:
	var why := entry_reason()
	if why != "":
		game.hud.show_message(why, 2.5)
		game.audio.play("cancel", 0.0, -4.0)
		return false
	var t: Dictionary = TIERS[entrance["tier"]]
	if game.player.level < int(t["min_level"]):
		Inv.remove(game.player, "rift_key", 1)
		game.hud.show_message("The Rift Key dissolves and the rift lets you through.", 2.5)
	active = true
	cleared = false
	room = 0
	_wave = 0
	_run_tier = int(entrance["tier"])
	_run_uid = int(entrance["uid"])
	_return_pos = (entrance["point"] as Vector2) + Vector2(0, 22)
	_cache_pos = Vector2.INF
	_exit_pos = Vector2.INF
	_spawned_rooms.clear()
	_layouts = [LAYOUTS[randi() % LAYOUTS.size()], LAYOUTS[randi() % LAYOUTS.size()], LAYOUTS[0]]
	_build_dungeon()
	game._door_transition(room_center(0) + Vector2(-ROOM.x / 2.0 + 24.0, 0))
	_set_camera()
	game.hud.show_region(String(t["name"]).to_upper(), "chamber 1 of 3")
	game.audio.play_music("boss", 0.8)
	game._quest_progress("explore", "rift")
	return true


func room_center(i: int) -> Vector2:
	return POCKET + Vector2(i * ROOM_GAP, 0)


func _retreat_pos() -> Vector2:
	return room_center(0) + Vector2(-ROOM.x / 2.0 + 10.0, 0)


func _set_camera() -> void:
	var cam: Camera2D = game.camera
	var c := room_center(clampi(room, 0, 2))
	var view: Vector2 = game.get_viewport().get_visible_rect().size / cam.zoom / 2.0
	var half := Vector2(maxf(ROOM.x / 2.0 + 20.0, view.x), maxf(ROOM.y / 2.0 + 20.0, view.y))
	cam.limit_left = int(room_center(0).x - half.x)
	cam.limit_right = int(room_center(2).x + half.x)
	cam.limit_top = int(c.y - half.y)
	cam.limit_bottom = int(c.y + half.y)
	game.world.visible = false


func _build_dungeon() -> void:
	var root := Node2D.new()
	root.name = "RiftDungeon"
	game.add_child(root)
	_nodes.append(root)
	var span := Rect2(room_center(0) - ROOM / 2.0 - Vector2(300, 220), Vector2(ROOM_GAP * 2 + ROOM.x + 600, ROOM.y + 440))
	game._flat_sprite(root, Color(0.03, 0.02, 0.06), span, -10)
	var body := StaticBody2D.new()
	body.collision_layer = 1
	root.add_child(body)
	_gates.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = _run_uid * 7919 + 13
	for i in range(3):
		var c := room_center(i)
		tiled(root, TILE_FLOOR, Rect2(c - ROOM / 2.0, ROOM), -9, TINT_FLOOR)
		# a few worn flagstones and floor clutter for texture
		for k in range(5):
			var fp := c + Vector2(rng.randi_range(-6, 5) * 16.0, rng.randi_range(-4, 3) * 16.0)
			tiled(root, TILE_FLOOR_ALT, Rect2(fp, Vector2(16, 16)), -9, TINT_FLOOR.darkened(0.08))
		for k in range(7):
			var bit: Array = FLOOR_BITS[rng.randi() % FLOOR_BITS.size()]
			var bp := c + Vector2(rng.randf_range(-ROOM.x * 0.42, ROOM.x * 0.42), rng.randf_range(-ROOM.y * 0.4, ROOM.y * 0.4))
			decal(root, bit, bp, -8, Color(0.8, 0.7, 1.0, 0.75))
		# purple rune ring on the floor
		var ring := RiftPortal.new()
		ring.floor_only = true
		ring.color = Color(0.55, 0.35, 0.85, 0.35)
		ring.position = c
		ring.z_index = -8
		root.add_child(ring)
		var t := 12.0
		var walls := [Rect2(c.x - ROOM.x / 2.0, c.y - ROOM.y / 2.0 - t, ROOM.x, t), Rect2(c.x - ROOM.x / 2.0, c.y + ROOM.y / 2.0, ROOM.x, t)]
		# west wall (door gap except on the first chamber), east wall (gate gap except last)
		var gap := 28.0
		if i == 0:
			walls.append(Rect2(c.x - ROOM.x / 2.0 - t, c.y - ROOM.y / 2.0, t, ROOM.y))
		else:
			walls.append(Rect2(c.x - ROOM.x / 2.0 - t, c.y - ROOM.y / 2.0, t, ROOM.y / 2.0 - gap / 2.0))
			walls.append(Rect2(c.x - ROOM.x / 2.0 - t, c.y + gap / 2.0, t, ROOM.y / 2.0 - gap / 2.0))
		if i == 2:
			walls.append(Rect2(c.x + ROOM.x / 2.0, c.y - ROOM.y / 2.0, t, ROOM.y))
		else:
			walls.append(Rect2(c.x + ROOM.x / 2.0, c.y - ROOM.y / 2.0, t, ROOM.y / 2.0 - gap / 2.0))
			walls.append(Rect2(c.x + ROOM.x / 2.0, c.y + gap / 2.0, t, ROOM.y / 2.0 - gap / 2.0))
			# corridor to the next chamber
			var cx := c.x + ROOM.x / 2.0 + t
			var clen := ROOM_GAP - ROOM.x - 2.0 * t
			tiled(root, TILE_FLOOR, Rect2(cx, c.y - gap / 2.0, clen, gap), -9, TINT_FLOOR.darkened(0.15))
			walls.append(Rect2(cx, c.y - gap / 2.0 - t, clen, t))
			walls.append(Rect2(cx, c.y + gap / 2.0, clen, t))
			_gates.append(_make_gate(root, Rect2(c.x + ROOM.x / 2.0, c.y - gap / 2.0, t, gap)))
		for wr in walls:
			var w: Rect2 = wr
			# the north face rises above its collision so walls read as walls
			var vis := Rect2(w.position - Vector2(0, 14), w.size + Vector2(0, 14)) if w.size.x > w.size.y else w
			tiled(root, TILE_WALL, vis, -7, TINT_WALL)
			game._flat_sprite(root, Color(0.05, 0.03, 0.09, 0.55), Rect2(vis.position.x, vis.end.y - 2, vis.size.x, 2), -7)
			_add_rect(body, w)
		for pr in _layouts[i]:
			var r: Rect2 = pr
			r.position += c
			tiled(root, TILE_BLOCK, r, -6, TINT_BLOCK)
			_add_rect(body, r)
		# carved pillars on the north wall, crystals glowing in the corners
		for sx in [-1.0, 1.0]:
			decal(root, PROP_PILLAR, Vector2(c.x + sx * (ROOM.x / 2.0 - 14.0), c.y - ROOM.y / 2.0 + 2.0), -5, TINT_WALL, true)
			decal(root, PROP_CRYSTAL, Vector2(c.x + sx * (ROOM.x / 2.0 - 12.0), c.y + ROOM.y / 2.0 - 8.0), -5, Color(1, 1, 1), true)
		if i == 1:
			decal(root, PROP_STATUE, Vector2(c.x, c.y - ROOM.y / 2.0 + 4.0), -5, TINT_WALL, true)
		if i == 2:
			decal(root, PROP_GEM, Vector2(c.x - 24, c.y - ROOM.y / 2.0 + 10.0), -5, Color(1, 1, 1), true)
			decal(root, PROP_GEM, Vector2(c.x + 24, c.y - ROOM.y / 2.0 + 10.0), -5, Color(1, 1, 1), true)
		var glow := PointLight2D.new()
		glow.texture = FxScript.glow_texture()
		glow.texture_scale = 7.0
		glow.energy = 0.35
		glow.color = Color(0.75, 0.55, 1.0)
		glow.position = c
		root.add_child(glow)
	# retreat portal at the start
	var back := RiftPortal.new()
	back.color = Color(0.6, 0.85, 1.0)
	back.position = _retreat_pos()
	back.scale = Vector2(0.7, 0.7)
	root.add_child(back)
	var light := PointLight2D.new()
	light.texture = FxScript.glow_texture()
	light.texture_scale = 14.0
	light.energy = 0.55
	light.color = Color(0.75, 0.6, 1.0)
	light.position = room_center(1)
	root.add_child(light)


## A single tile cut out of a sheet, cached, so it can repeat across a rect.
static func tile_texture(spec: Array) -> Texture2D:
	var key := "%s:%s" % [spec[0], str(spec[1])]
	if _tile_cache.has(key):
		return _tile_cache[key]
	var src: Texture2D = load(NA + String(spec[0]) + ".png")
	var out: Texture2D = null
	if src != null:
		var img := src.get_image()
		if img != null and not img.is_empty():
			if img.is_compressed():
				img.decompress()
			var r: Rect2 = spec[1]
			out = ImageTexture.create_from_image(img.get_region(Rect2i(r)))
	_tile_cache[key] = out
	return out


## Repeat one tile over rect (rift floors, walls and blocks).
func tiled(parent: Node, spec: Array, rect: Rect2, z: int, tint: Color) -> Sprite2D:
	var tex := tile_texture(spec)
	if tex == null:
		game._flat_sprite(parent, tint.darkened(0.7), rect, z)
		return null
	var s := Sprite2D.new()
	s.texture = tex
	s.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.centered = false
	s.region_enabled = true
	s.region_rect = Rect2(Vector2.ZERO, rect.size)
	s.position = rect.position
	s.modulate = tint
	s.z_index = z
	s.set_meta("rift_tile", String(spec[0]))
	parent.add_child(s)
	return s


## One prop or floor decal from a sheet; bottom-anchored props when grounded.
func decal(parent: Node, spec: Array, pos: Vector2, z: int, tint: Color, grounded := false) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(NA + String(spec[0]) + ".png")
	s.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	s.region_enabled = true
	var r: Rect2 = spec[1]
	s.region_rect = r
	s.centered = true
	if grounded:
		s.offset = Vector2(0, -r.size.y / 2.0)
	s.position = pos.round()
	s.modulate = tint
	s.z_index = z
	s.set_meta("rift_tile", String(spec[0]))
	parent.add_child(s)
	return s


func _add_rect(body: StaticBody2D, r: Rect2) -> void:
	var cs := CollisionShape2D.new()
	var rs := RectangleShape2D.new()
	rs.size = r.size
	cs.shape = rs
	cs.position = r.get_center()
	body.add_child(cs)


func _make_gate(root: Node, r: Rect2) -> StaticBody2D:
	var g := StaticBody2D.new()
	g.collision_layer = 1
	root.add_child(g)
	_add_rect(g, r)
	var s := ColorRect.new()
	s.color = Color(0.85, 0.5, 1.0, 0.85)
	s.position = r.position
	s.size = r.size
	s.name = "Glow"
	g.add_child(s)
	return g


func _open_gate(i: int) -> void:
	if i < 0 or i >= _gates.size() or not is_instance_valid(_gates[i]):
		return
	var g: StaticBody2D = _gates[i]
	for c in g.get_children():
		if c is CollisionShape2D:
			c.set_deferred("disabled", true)
	var tw := g.create_tween()
	tw.tween_property(g.get_node("Glow"), "modulate:a", 0.0, 0.6)
	game.audio.play("secret2", 0.0, -4.0)
	game.hud.show_message("A rift gate opens to the east.", 2.0)


func targets() -> Array:
	return _targets


func _spawn_enemy(kind: String, pos: Vector2, elite := false) -> Node:
	var e := EnemyScript.new()
	e.setup(game, kind, pos)
	game.entities.add_child(e)
	e.set_meta("rift", true)
	if elite:
		make_elite(e)
	_targets.append(e)
	return e


## Elites: more health and damage, a gold outline, triple coins and bonus loot.
static func make_elite(e: Node) -> void:
	e.elite = true
	e.max_hp = int(e.max_hp * 3)
	e.hp = e.max_hp
	e.kb_resist = minf(0.85, e.kb_resist + 0.4)
	e.scale = Vector2(1.3, 1.3)
	if e.get("mat") != null and e.mat is ShaderMaterial:
		e.mat.set_shader_parameter("outline", 0.9)
		e.mat.set_shader_parameter("outline_color", Color(1.0, 0.82, 0.35))


func _populate(i: int) -> void:
	if _spawned_rooms.has(i):
		return
	_spawned_rooms[i] = true
	var t: Dictionary = TIERS[_run_tier]
	var c := room_center(i)
	match i:
		0:
			_wave = 1
			_spawn_wave(c, 4)
		1:
			_spawn_enemy(String(t["elite"]), c + Vector2(30, 0), true)
			for k in range(2):
				_spawn_enemy(String(t["kinds"][randi() % t["kinds"].size()]), c + Vector2(50, -40 + k * 80))
		2:
			var b := BossScript.new()
			b.setup(game, "rift_%d" % _run_uid, String(t["boss"]), c + Vector2(40, 0))
			b.title = "RIFT WARDEN"
			b.max_hp = int(float(int(b.cfg["hp"])) * float(t["boss_hp"]))
			b.hp = b.max_hp
			game.entities.add_child(b)
			b.awake = true
			_boss = b
			_targets.append(b)
			game.on_boss_awake(b)
	game.hud.show_region(String(t["name"]).to_upper(), "chamber %d of 3" % (i + 1))


func _spawn_wave(c: Vector2, count: int) -> void:
	var t: Dictionary = TIERS[_run_tier]
	for k in range(count):
		var ang := TAU * k / float(count) + randf() * 0.4
		_spawn_enemy(String(t["kinds"][randi() % t["kinds"].size()]), c + Vector2(30, 0) + Vector2.from_angle(ang) * randf_range(30.0, 60.0))
	game.audio.play("alert2", 0.0, -3.0)


func _alive(t: Node) -> bool:
	var a = t.get("alive")
	var d = t.get("defeated")
	return (a == null or bool(a)) and not (d != null and bool(d))


func _tick_dungeon(delta: float) -> void:
	var pp: Vector2 = game.player.global_position
	# entering the next chamber spawns it and moves the camera band
	for i in range(3):
		var c := room_center(i)
		if absf(pp.x - c.x) < ROOM.x / 2.0 - 8.0 and absf(pp.y - c.y) < ROOM.y / 2.0:
			if room != i:
				room = i
				_set_camera()
			_populate(i)
	for k in range(_targets.size() - 1, -1, -1):
		var t: Node = _targets[k]
		if not is_instance_valid(t) or not _alive(t):
			_targets.remove_at(k)
	if not _targets.is_empty():
		_between_t = 0.0
		return
	if not _spawned_rooms.has(room):
		return
	_between_t += delta
	if _between_t < 1.2:
		return
	_between_t = 0.0
	if room == 0 and _wave == 1:
		_wave = 2
		_spawn_wave(room_center(0), 5)
		game.hud.show_message("Another wave pours out of the rift!", 1.8)
		return
	if room < 2 and _gates.size() > room and is_instance_valid(_gates[room]) and not _gates[room].has_meta("open"):
		_gates[room].set_meta("open", true)
		_open_gate(room)
		if room == 1:
			_cache_pos = room_center(1) + Vector2(70, -50)
			_spawn_cache_node(_cache_pos, false)


func _spawn_cache_node(pos: Vector2, big: bool) -> void:
	var s := Sprite2D.new()
	s.texture = AnimLib.tex("items/bigtreasurechest.png" if big else "items/littletreasurechest.png")
	s.offset = Vector2(0, -6)
	s.position = pos
	s.modulate = Color(1.0, 0.9, 1.0)
	game.entities.add_child(s)
	_nodes.append(s)


func on_boss_defeated(b: Node) -> void:
	cleared = true
	game.flags["rift_cleared"] = true
	game._quest_progress("rift_boss")
	game.audio.play("success3", 0.0, -1.0)
	game.hitstop(0.25)
	for i in range(6):
		game.spawn_coin(b.global_position + Vector2(randf_range(-20, 20), randf_range(-10, 10)), 3 + _run_tier)
	_cache_pos = room_center(2) + Vector2(0, -30)
	_exit_pos = room_center(2) + Vector2(70, 0)
	_spawn_cache_node(_cache_pos, true)
	var ex := RiftPortal.new()
	ex.color = Color(0.6, 0.85, 1.0)
	ex.position = _exit_pos
	game.add_child(ex)
	_nodes.append(ex)
	game.hud.show_message("The Rift Warden falls! Open the cache, then step through the portal.", 3.5)
	game.get_tree().create_timer(2.0, true, false, true).timeout.connect(func() -> void:
		if is_instance_valid(b):
			b.queue_free())
	game.save_game()


## Reward cache: only the boss cache pays the main reward; claimed once per uid.
func claim_cache() -> bool:
	if _cache_pos == Vector2.INF:
		return false
	var p: Node = game.player
	if not cleared:
		# mid-dungeon cache (after the elite): small purse, can't be farmed
		var key := "rift_%d_small" % _run_uid
		if game.flags.get(key, false):
			return false
		game.flags[key] = true
		game.gather_material("spirit_dust", 1)
		p.add_petalcoins(20 + _run_tier * 10)
		_cache_pos = Vector2.INF
		game.audio.play("success1", 0.0, -3.0)
		return true
	if claimed.has(_run_uid):
		return false
	claimed.append(_run_uid)
	var t: Dictionary = TIERS[_run_tier]
	p.add_petalcoins(int(t["coins"]))
	game.gather_material("moon_shard", 1 + (1 if _run_tier >= 1 else 0))
	game.gather_material("spirit_dust", 2)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var gear := Loot.pick_gear(func(id: String) -> bool: return p.owns(id), rng, true)
	if _run_tier >= 1 and not p.owns("rift_treads") and rng.randf() < 0.5:
		gear = "rift_treads"
	if gear != "":
		if p.owns(gear):
			p.add_petalcoins(Trade.sell_price(gear))
		else:
			p.give_item(gear)
			game.hud.show_item_get(gear)
	_cache_pos = Vector2.INF
	game.audio.play("secret2", 0.0, -2.0)
	game.save_game()
	return true


func leave(completed: bool) -> bool:
	if not active:
		return false
	if completed and not cleared:
		# the exit portal only exists once the warden falls; retreat is always open
		game.hud.show_message("The Rift Warden still holds this rift. Defeat it, or retreat through the portal at the start.", 2.5)
		return false
	_teardown()
	active = false
	if completed or cleared:
		_close_entrance()  # a cleared rift collapses behind you
	game._door_transition(_return_pos)
	game._restore_world_camera()
	var bi: int = game.world.biome_at(game.player.global_position)
	game.audio.play_music(DB.REGION_MUSIC[bi] if bi >= 0 and bi < DB.REGION_MUSIC.size() else "meadow", 1.0)
	game.current_region = ""
	game._update_region(true)
	game.save_game()
	return true


## Called when Mallow falls inside: tidy up; the entrance stays if unexpired.
func on_player_died() -> void:
	if not active:
		return
	_teardown()
	active = false
	game._restore_world_camera()


func _teardown() -> void:
	for t in _targets:
		if is_instance_valid(t):
			t.queue_free()
	_targets.clear()
	if is_instance_valid(_boss):
		_boss.queue_free()
		if game.active_boss == _boss:
			game.active_boss = null
			game.hud.hide_boss()
	_boss = null
	for n in _nodes:
		if is_instance_valid(n):
			n.queue_free()
	_nodes.clear()
	_gates.clear()
	_cache_pos = Vector2.INF
	_exit_pos = Vector2.INF


func in_pocket(pos: Vector2) -> bool:
	return pos.x > POCKET.x - 400.0 and pos.y > POCKET.y - 400.0 and pos.y < POCKET.y + 400.0


# ------------------------------------------------------------------ save
func save_data() -> Dictionary:
	var d := {"uid": _uid, "since": _since, "claimed": claimed.duplicate()}
	if not entrance.is_empty():
		d["entrance"] = {"x": entrance["point"].x, "y": entrance["point"].y, "uid": entrance["uid"], "left": entrance["left"], "tier": entrance["tier"]}
	if active:
		d["return"] = [_return_pos.x, _return_pos.y]
	return d


func load_data(d: Dictionary) -> void:
	if active:
		_teardown()
		active = false
	_close_entrance()
	_uid = int(d.get("uid", 0))
	_since = float(d.get("since", 0.0))
	claimed.clear()
	for u in d.get("claimed", []):
		claimed.append(int(u))
	var e: Dictionary = d.get("entrance", {})
	if not e.is_empty() and not claimed.has(int(e.get("uid", -1))):
		entrance = {"point": Vector2(float(e["x"]), float(e["y"])), "uid": int(e["uid"]), "left": float(e.get("left", LIFETIME)), "tier": clampi(int(e.get("tier", 0)), 0, TIERS.size() - 1)}
		_make_entrance_node()
	# saved inside a rift: the run restarts from the entrance (no duplicate rewards)
	if d.has("return") and in_pocket(game.player.global_position):
		var r: Array = d["return"]
		game.player.global_position = Vector2(float(r[0]), float(r[1]))


# ------------------------------------------------------------------ portal visual
class RiftPortal extends Node2D:
	var color := Color(0.75, 0.45, 1.0)
	var floor_only := false
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		if floor_only:
			draw_arc(Vector2.ZERO, 34.0, 0.0, TAU, 40, color, 1.0)
			draw_arc(Vector2.ZERO, 26.0, _t * 0.4, _t * 0.4 + TAU * 0.8, 32, color, 1.0)
			return
		var pulse := 0.5 + 0.5 * sin(_t * 3.0)
		draw_circle(Vector2(0, -8), 11.0, Color(0.05, 0.02, 0.1, 0.9))
		for i in range(3):
			var r := 13.0 - i * 3.5
			var a := _t * (1.5 + i * 0.7) * (1.0 if i % 2 == 0 else -1.0)
			draw_arc(Vector2(0, -8), r, a, a + TAU * 0.7, 24, Color(color.r, color.g, color.b, 0.55 + 0.35 * pulse), 1.5)
		draw_arc(Vector2(0, 0), 14.0, 0.0, TAU, 24, Color(color.r, color.g, color.b, 0.25), 1.0)
