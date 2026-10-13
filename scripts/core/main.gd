extends Node2D
## Petalbound: open-world orchestration. Builds the world, actors and UI; owns combat
## resolution, loot, interactions, regions, bosses, save/load and the Moonwell ending.

const AnimLib := preload("res://scripts/core/anim_lib.gd")
const DB := preload("res://scripts/data/db.gd")
const Save := preload("res://scripts/systems/save.gd")
const WorldScript := preload("res://scripts/world/world.gd")
const PlayerScript := preload("res://scripts/actors/player.gd")
const EnemyScript := preload("res://scripts/actors/enemy.gd")
const BossScript := preload("res://scripts/actors/boss.gd")
const NpcScript := preload("res://scripts/actors/npc.gd")
const ProjectileScript := preload("res://scripts/combat/projectile.gd")
const FxScript := preload("res://scripts/core/fx.gd")
const AudioScript := preload("res://scripts/core/audio.gd")
const EnvScript := preload("res://scripts/systems/environment.gd")
const HudScript := preload("res://scripts/ui/hud.gd")
const FishingScript := preload("res://scripts/systems/fishing.gd")
const DepthsScript := preload("res://scripts/systems/depths.gd")
const CompanionScript := preload("res://scripts/actors/companion.gd")
const Ach := preload("res://scripts/systems/achievements.gd")
const ClassBook := preload("res://scripts/data/classdb.gd")
const QuestSys := preload("res://scripts/systems/quests.gd")
const StatusFx := preload("res://scripts/combat/status.gd")

const CAMERA_ZOOM := 1.5
const CRAFT_RECIPES := [
	{"id": "thornblade_ii", "needs": {"wood": 3, "ore": 3}},
	{"id": "briar_mail_ii", "needs": {"ore": 3, "herb": 2}},
]
const SHOPS := {
	"pip": [{"id": "moontea", "price": 20}, {"id": "heart_piece", "price": 150, "once": "pip_heart"}, {"id": "fishing_rod", "price": 60, "once": "pip_rod"},
		{"id": "mossleaf_cap", "price": 60, "once": "pip_cap"}, {"id": "rootgrip_gloves", "price": 70, "once": "pip_gloves"}, {"id": "trail_leggings", "price": 60, "once": "pip_legs"}],
	"nomad": [{"id": "moontea", "price": 24}, {"id": "starlocket", "price": 300, "once": "nomad_locket"}, {"id": "heart_piece", "price": 220, "once": "nomad_heart"},
		{"id": "twilight_mantle", "price": 380, "once": "nomad_mantle"}, {"id": "spellblade_sash", "price": 380, "once": "nomad_sash"}],
	"kaede": [{"id": "moontea", "price": 22}, {"id": "duskfan", "price": 220, "once": "kaede_fan"}, {"id": "sunplate", "price": 260, "once": "kaede_plate"}, {"id": "heart_piece", "price": 200, "once": "kaede_heart"},
		{"id": "ember_heart", "price": 280, "once": "kaede_ember"}, {"id": "shadow_wraps", "price": 240, "once": "kaede_wraps"},
		{"id": "frostlace_robe", "price": 240, "once": "kaede_robe"}, {"id": "cryptwarden_greaves", "price": 240, "once": "kaede_greaves"}],
}

## Enterable buildings: doors stand just south of the village house props; the
## rooms themselves are built on quiet water in the far south of the map.
const HOUSES := [
	{"id": "house_mira", "name": "Mira's Cottage", "door": Vector2(1072, 1818), "center": Vector2(320, 2704), "size": Vector2(176, 128)},
	{"id": "house_tallow", "name": "Tallow's Home", "door": Vector2(1408, 1802), "center": Vector2(560, 2704), "size": Vector2(176, 128)},
	{"id": "house_kit", "name": "Kit's House", "door": Vector2(1040, 2026), "center": Vector2(800, 2704), "size": Vector2(176, 128)},
	{"id": "house_alder", "name": "Elder's Hall", "door": Vector2(1200, 1738), "center": Vector2(1040, 2704), "size": Vector2(200, 136)},
	{"id": "crypt", "name": "Hollow Crypt", "door": Vector2(2848, 2528), "center": Vector2(1280, 2704), "size": Vector2(256, 176), "dungeon": true},
]
const CRYPT_KINDS := ["skull", "skull", "spirit", "spirit", "eye", "slime3"]

const MOONPETAL_SPOTS := [[122, 97], [125, 33], [82, 114], [199, 51], [217, 115], [279, 64], [287, 80]]
const NIGHT_WISP_SPOTS := [["spirit", 70, 110], ["bluebat", 120, 40], ["spirit", 130, 100], ["bluebat", 192, 52], ["spirit", 212, 116], ["spirit2", 284, 92]]

var world: Node2D
var entities: Node2D
var fx: Node2D
var projectiles: Node2D
var audio: Node
var environment: Node
var hud: Control
var hud_layer: CanvasLayer
var camera: Camera2D
var player: CharacterBody2D
var enemies: Array = []
var bosses: Array = []
var npcs: Array = []
var chests: Array = []
var waystones: Array = []
var pickups: Array = []
var moonwell: Node2D
var moonwell_light: PointLight2D
var game_started := false
var game_over := false
var victory := false
var moonseeds: Array = []
var defeated_bosses: Array = []
var opened_chests: Array = []
var flags: Dictionary = {}
var discovered_waystones: Array = ["hearthgrove"]
var last_waystone := "hearthgrove"
var current_biome := 0
var current_region := ""
var active_boss: Node = null
var shop_id := ""
var talking_npc: Node = null
var shake_strength := 0.0
var shake_time := 0.0
var _look := Vector2.ZERO
var _interact_target: Dictionary = {}
var _hitstop_active := false
var _activation_t := 0.0
var _title_t := 0.0
var _save_t := 0.0
var kills := 0
var fishing: Node
var depths: Node
var companion: Node2D
var moth_active := false
var achievements := {}
var stats := {"fish": {}, "moonpetals": 0, "parries": 0, "depths_best": 0}
var moonpetals: Array = []
var night_wisps: Array = []
var _night_was := false
var _descend_prompted := false
var _ach_t := 0.0
## Journeys (quests), houses and the Hollow Crypt.
var quests: Dictionary = {}
var current_interior: Dictionary = {}
var crypt_enemies: Array = []
var crypt_boss: Node = null
var crypt_cleared_once := false
var materials: Dictionary = {"wood": 0, "ore": 0, "herb": 0}


func _ready() -> void:
	randomize()
	audio = AudioScript.new()
	audio.name = "Audio"
	add_child(audio)
	world = WorldScript.new()
	world.name = "World"
	add_child(world)
	for h in HOUSES:
		world.interior_footprints.append([h["center"].x, h["center"].y, h["size"].x, h["size"].y])
	entities = Node2D.new()
	entities.name = "Entities"
	entities.y_sort_enabled = true
	add_child(entities)
	world.build(entities)
	projectiles = Node2D.new()
	projectiles.name = "Projectiles"
	projectiles.z_index = 5
	add_child(projectiles)
	fx = FxScript.new()
	fx.name = "FX"
	add_child(fx)
	fx.shake_requested.connect(_on_shake)
	player = PlayerScript.new()
	player.name = "Mallow"
	player.game = self
	entities.add_child(player)
	player.global_position = Vector2(world.data["start"][0], world.data["start"][1])
	player.died.connect(_on_player_died)
	camera = Camera2D.new()
	camera.zoom = Vector2(CAMERA_ZOOM, CAMERA_ZOOM)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(world.world_size.x)
	camera.limit_bottom = int(world.world_size.y)
	add_child(camera)
	camera.make_current()
	_inject_runtime_content()
	_spawn_npcs()
	_spawn_enemies()
	_spawn_bosses()
	_spawn_chests()
	_spawn_waystones()
	_spawn_moonwell()
	_build_all_interiors()
	environment = EnvScript.new()
	environment.name = "Environment"
	add_child(environment)
	environment.setup(self, self)
	fishing = FishingScript.new()
	fishing.name = "Fishing"
	add_child(fishing)
	depths = DepthsScript.new()
	depths.game = self
	depths.name = "Depths"
	add_child(depths)
	_spawn_moonpetals()
	hud_layer = CanvasLayer.new()
	hud_layer.layer = 10
	add_child(hud_layer)
	hud = HudScript.new()
	hud.name = "HUD"
	hud_layer.add_child(hud)
	hud.setup(self)
	hud.build_minimap_texture(world.biome_image, world.field_image)
	hud.start_requested.connect(_on_start_requested)
	hud.retry_requested.connect(_on_retry_requested)
	_enter_title()


# ------------------------------------------------------------------ spawning
func _spawn_npcs() -> void:
	for d in world.data["npcs"]:
		var n := NpcScript.new()
		n.setup(self, d)
		entities.add_child(n)
		npcs.append(n)
	for d in world.data["animals"]:
		var a := NpcScript.new()
		a.setup(self, d, true)
		entities.add_child(a)


func _spawn_enemies() -> void:
	for d in world.data["enemies"]:
		if not DB.ENEMIES.has(d["s"]):
			continue
		var e := EnemyScript.new()
		e.setup(self, d["s"], Vector2(d["x"], d["y"]))
		entities.add_child(e)
		enemies.append(e)


func _spawn_bosses() -> void:
	for d in world.data["bosses"]:
		var b := BossScript.new()
		b.setup(self, d["id"], d["kind"], Vector2(d["x"], d["y"]))
		entities.add_child(b)
		bosses.append(b)


func _spawn_chests() -> void:
	for d in world.data["chests"]:
		var big: bool = d.get("big", false)
		var tex: Texture2D = AnimLib.tex("items/bigtreasurechest.png" if big else "items/littletreasurechest.png")
		var s := Sprite2D.new()
		s.texture = tex
		s.hframes = 2
		s.centered = false
		s.offset = Vector2(-8, -tex.get_height())
		s.position = Vector2(d["x"], d["y"])
		entities.add_child(s)
		var body := StaticBody2D.new()
		body.collision_layer = 1
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(14, 7)
		cs.shape = rect
		cs.position = Vector2(0, -4)
		body.add_child(cs)
		s.add_child(body)
		var glow := PointLight2D.new()
		glow.texture = WorldScript.light_texture()
		glow.texture_scale = 0.45
		glow.color = Color(1.0, 0.85, 0.5)
		glow.energy = 0.3 if big else 0.15
		glow.position = Vector2(0, -8)
		s.add_child(glow)
		chests.append({"id": d["id"], "item": d["item"], "sprite": s, "pos": Vector2(d["x"], d["y"]), "open": false, "glow": glow, "big": big})


func _spawn_waystones() -> void:
	var defs: Dictionary = world.prop_defs
	for d in world.data["shrines"]:
		var pos := Vector2(d["x"], d["y"])
		var s := Sprite2D.new()
		var r: Array = defs["statue_monk"]["rect"]
		s.texture = world.sheet(defs["statue_monk"]["sheet"])
		s.region_enabled = true
		s.region_rect = Rect2(r[0], r[1], r[2], r[3])
		s.centered = false
		s.offset = Vector2(-floorf(r[2] / 2.0), -r[3])
		s.position = pos
		entities.add_child(s)
		var circle := AnimatedSprite2D.new()
		circle.sprite_frames = AnimLib.strip_frames("res://assets/packs/ninja_adventure/fx/magic_circle.png", 32, 8.0, true)
		circle.position = pos + Vector2(0, 6)
		circle.scale = Vector2(1.1, 0.7)
		circle.z_index = -7
		circle.modulate = Color(0.85, 0.75, 1.0, 0.0)
		var m := CanvasItemMaterial.new()
		m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
		circle.material = m
		add_child(circle)
		circle.play("play")
		var light := PointLight2D.new()
		light.texture = WorldScript.light_texture()
		light.color = Color(0.8, 0.7, 1.0)
		light.energy = 0.0
		light.texture_scale = 1.0
		light.position = pos + Vector2(0, -14)
		add_child(light)
		var body := StaticBody2D.new()
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(16, 8)
		cs.shape = rect
		cs.position = Vector2(0, -4)
		body.add_child(cs)
		s.add_child(body)
		waystones.append({"id": d["id"], "name": d["name"], "pos": pos, "circle": circle, "light": light})


func _spawn_moonwell() -> void:
	var lm: Array = world.data["landmarks"]["moonwell"]
	moonwell = Node2D.new()
	moonwell.position = Vector2(lm[0], lm[1])
	add_child(moonwell)
	var circle := AnimatedSprite2D.new()
	circle.sprite_frames = AnimLib.strip_frames("res://assets/packs/ninja_adventure/fx/magic_circle.png", 32, 6.0, true)
	circle.scale = Vector2(2.6, 1.7)
	circle.z_index = -7
	circle.modulate = Color(0.75, 0.8, 1.0, 0.35)
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	circle.material = m
	circle.name = "Circle"
	moonwell.add_child(circle)
	circle.play("play")
	var spirit := AnimatedSprite2D.new()
	spirit.sprite_frames = AnimLib.strip_frames("res://assets/packs/ninja_adventure/fx/spirit_blue.png", 32, 8.0, true)
	spirit.position = Vector2(0, -14)
	spirit.modulate = Color(0.8, 0.85, 1.0, 0.5)
	spirit.material = m
	spirit.name = "Spirit"
	moonwell.add_child(spirit)
	spirit.play("play")
	moonwell_light = PointLight2D.new()
	moonwell_light.texture = WorldScript.light_texture()
	moonwell_light.color = Color(0.7, 0.8, 1.0)
	moonwell_light.energy = 0.3
	moonwell_light.texture_scale = 2.4
	moonwell.add_child(moonwell_light)


# ------------------------------------------------------------------ houses & the Hollow Crypt
func _inject_runtime_content() -> void:
	# interior villagers and the crypt chest ride the normal spawn pipelines
	var npcs: Array = world.data["npcs"]
	npcs.append({"id": "rosa", "sprite": "woman", "name": "Rosa", "x": 292.0, "y": 2692.0, "wander": 10})
	npcs.append({"id": "jun", "sprite": "villager3", "name": "Jun", "x": 772.0, "y": 2696.0, "wander": 14})
	npcs.append({"id": "fen", "sprite": "oldman", "name": "Old Fen", "x": 1016.0, "y": 2690.0, "wander": 8})
	world.data["chests"].append({"id": "c_hall_tea", "x": 1064.0, "y": 2696.0, "item": "moontea"})
	world.data["chests"].append({"id": "c_crypt", "x": 1352.0, "y": 2656.0, "item": "sunplate", "big": true})


func _build_all_interiors() -> void:
	for h in HOUSES:
		_build_interior(h)
		# a warm doorway light outside every entrance
		var l := PointLight2D.new()
		l.texture = WorldScript.light_texture()
		l.color = Color(0.75, 0.78, 1.0) if h.get("dungeon", false) else Color(1.0, 0.82, 0.55)
		l.energy = 0.35
		l.texture_scale = 0.7
		l.position = h["door"] + Vector2(0, -8)
		add_child(l)


func _flat_sprite(parent: Node, color: Color, rect: Rect2, z: int) -> void:
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	var s := Sprite2D.new()
	s.texture = ImageTexture.create_from_image(img)
	s.centered = false
	s.modulate = color
	s.position = rect.position
	s.scale = rect.size / 2.0
	s.z_index = z
	parent.add_child(s)


func _interior_prop(kind: String, x: float, y: float, collide := true) -> void:
	var def: Dictionary = world.prop_defs.get(kind, {})
	if def.is_empty():
		return
	var r: Array = def["rect"]
	var s := Sprite2D.new()
	s.texture = world.sheet(def["sheet"])
	s.region_enabled = true
	s.region_rect = Rect2(r[0], r[1], r[2], r[3])
	s.centered = false
	s.offset = Vector2(-floorf(r[2] / 2.0), -r[3])
	s.position = Vector2(x, y)
	entities.add_child(s)
	if collide:
		var body := StaticBody2D.new()
		body.collision_layer = 1
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(minf(r[2], 14.0), 6.0)
		cs.shape = rect
		cs.position = Vector2(0, -3)
		body.add_child(cs)
		s.add_child(body)


func _build_interior(h: Dictionary) -> void:
	var size: Vector2 = h["size"]
	var c: Vector2 = h["center"]
	var dungeon: bool = h.get("dungeon", false)
	var room := Node2D.new()
	room.name = "Interior_" + h["id"]
	add_child(room)
	var floor_c := Color(0.10, 0.08, 0.13) if dungeon else Color(0.30, 0.19, 0.13)
	var wall_c := Color(0.16, 0.12, 0.16) if dungeon else Color(0.19, 0.12, 0.11)
	_flat_sprite(room, floor_c, Rect2(c - size / 2.0, size), -9)
	var t := 12.0
	_flat_sprite(room, wall_c, Rect2(c.x - size.x / 2.0, c.y - size.y / 2.0 - t, size.x, t), -7)
	_flat_sprite(room, wall_c, Rect2(c.x - size.x / 2.0, c.y + size.y / 2.0, size.x, t), -7)
	_flat_sprite(room, wall_c, Rect2(c.x - size.x / 2.0 - t, c.y - size.y / 2.0, t, size.y), -7)
	_flat_sprite(room, wall_c, Rect2(c.x + size.x / 2.0, c.y - size.y / 2.0, t, size.y), -7)
	var body := StaticBody2D.new()
	body.collision_layer = 1
	room.add_child(body)
	for wall in [Rect2(c.x - size.x / 2.0, c.y - size.y / 2.0 - t, size.x, t), Rect2(c.x - size.x / 2.0, c.y + size.y / 2.0, size.x, t),
			Rect2(c.x - size.x / 2.0 - t, c.y - size.y / 2.0, t, size.y), Rect2(c.x + size.x / 2.0, c.y - size.y / 2.0, t, size.y)]:
		var cs := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = wall.size
		cs.shape = rect
		cs.position = wall.get_center()
		body.add_child(cs)
	# doormat inside the exit
	_flat_sprite(room, Color(0.45, 0.30, 0.22), Rect2(c.x - 10.0, c.y + size.y / 2.0 - 14.0, 20.0, 8.0), -8)
	# lighting
	for lx in [-0.28, 0.28]:
		var l := PointLight2D.new()
		l.texture = WorldScript.light_texture()
		l.color = Color(0.75, 0.85, 1.0) if dungeon else Color(1.0, 0.78, 0.5)
		l.energy = 0.55
		l.texture_scale = 1.1
		l.position = c + Vector2(size.x * lx, -14.0)
		room.add_child(l)
	if dungeon:
		for g in [[-70.0, -40.0], [56.0, -52.0], [-18.0, -64.0], [70.0, -18.0], [-84.0, 6.0], [24.0, -30.0]]:
			_interior_prop(["grave", "cross", "bones", "skull_bone", "grave", "bones"][int(absf(g[0] + 84.0) / 28.0) % 6], c.x + g[0], c.y + g[1])
		_interior_prop("pillar", c.x - 96.0, c.y - 48.0)
		_interior_prop("pillar", c.x + 96.0, c.y - 48.0)
		_interior_prop("stone_lantern", c.x - 20.0, c.y - 20.0)
		_interior_prop("stone_lantern", c.x + 20.0, c.y - 20.0)
		_interior_prop("arch", h["door"].x, h["door"].y, false)
		return
	match h["id"]:
		"house_mira":
			_interior_prop("oven", c.x - 44.0, c.y - 30.0)
			_interior_prop("bench", c.x + 24.0, c.y - 26.0)
			_interior_prop("pot_red", c.x + 52.0, c.y - 6.0)
			_interior_prop("plant_pot", c.x - 62.0, c.y - 8.0)
			_interior_prop("crate", c.x + 48.0, c.y - 46.0)
			_interior_prop("pot", c.x - 30.0, c.y - 50.0)
		"house_tallow":
			_interior_prop("crate", c.x - 48.0, c.y - 28.0)
			_interior_prop("crate", c.x - 34.0, c.y - 40.0)
			_interior_prop("barrel", c.x + 44.0, c.y - 30.0)
			_interior_prop("bench", c.x + 12.0, c.y - 24.0)
			_interior_prop("sign", c.x + 54.0, c.y - 8.0)
			_interior_prop("plant_pot", c.x - 58.0, c.y - 8.0)
		"house_kit":
			_interior_prop("bench", c.x - 34.0, c.y - 30.0)
			_interior_prop("plant_pot", c.x + 44.0, c.y - 28.0)
			_interior_prop("pot_red", c.x - 54.0, c.y - 10.0)
			_interior_prop("crate", c.x + 52.0, c.y - 10.0)
			_interior_prop("mailbox", c.x + 8.0, c.y - 44.0)
		"house_alder":
			_interior_prop("pillar", c.x - 60.0, c.y - 40.0)
			_interior_prop("pillar", c.x + 60.0, c.y - 40.0)
			_interior_prop("bench", c.x - 30.0, c.y - 22.0)
			_interior_prop("bench", c.x + 30.0, c.y - 22.0)
			_interior_prop("oven", c.x, c.y - 52.0)
			_interior_prop("statue_monk", c.x, c.y - 62.0, false)
			_interior_prop("pot", c.x - 74.0, c.y - 8.0)
			_interior_prop("pot", c.x + 74.0, c.y - 8.0)


func _spawn_crypt_contents() -> void:
	if not crypt_enemies.is_empty():
		return
	var h := _house("crypt")
	var c: Vector2 = h["center"]
	var i := 0
	for kind in CRYPT_KINDS:
		var e := EnemyScript.new()
		var ang := -PI / 2.0 + TAU * float(i) / float(CRYPT_KINDS.size()) * 0.6
		e.setup(self, kind, c + Vector2.from_angle(ang) * randf_range(40.0, 76.0) + Vector2(0, -20.0))
		entities.add_child(e)
		enemies.append(e)
		crypt_enemies.append(e)
		i += 1
	var b := BossScript.new()
	b.setup(self, "crypt_revenant", "giantspirit", c + Vector2(0, -52.0))
	b.title = "THE HOLLOW REVENANT"
	b.max_hp = 160
	b.hp = b.max_hp
	entities.add_child(b)
	b.set_meta("dungeon", true)
	crypt_boss = b


func _clear_crypt_contents() -> void:
	for e in crypt_enemies:
		if is_instance_valid(e):
			e.queue_free()
			enemies.erase(e)
	crypt_enemies.clear()
	if is_instance_valid(crypt_boss):
		if active_boss == crypt_boss:
			active_boss = null
			hud.hide_boss()
		crypt_boss.queue_free()
	crypt_boss = null


func _house(id: String) -> Dictionary:
	for h in HOUSES:
		if h["id"] == id:
			var found: Dictionary = h.duplicate()
			found["_in_door"] = _interior_door(found)
			return found
	return {}


func _interior_door(h: Dictionary) -> Vector2:
	return h["center"] + Vector2(0, h["size"].y / 2.0 - 10.0)


func _use_door(h: Dictionary) -> void:
	if current_interior.is_empty():
		if h.get("dungeon", false) and not flags.get("crypt_open", false) and not crypt_cleared_once:
			# the crypt opens with a rumble the first time
			flags["crypt_open"] = true
		if h.get("dungeon", false):
			_spawn_crypt_contents()
		current_interior = h.duplicate()
		current_interior["_in_door"] = _interior_door(h)
		player.velocity = Vector2.ZERO
		player.knockback = Vector2.ZERO
		environment.fade = 1.0
		var tw := create_tween()
		tw.tween_method(func(v: float) -> void: environment.fade = v, 1.0, 0.0, 0.5)
		player.global_position = _interior_door(h) + Vector2(0, -6.0)
		camera.global_position = player.global_position
		camera.reset_smoothing()
		audio.play("menu2", 0.03, -6.0)
		if h.get("dungeon", false):
			hud.show_message("The Hollow Crypt. The air remembers every name here.", 3.0)
			audio.play_music("night", 0.6)
		else:
			hud.show_message("%s" % h["name"], 2.0)
	else:
		if h.get("dungeon", false) and is_instance_valid(crypt_boss) and crypt_boss.awake and not crypt_boss.defeated:
			hud.show_message("The Revenant bars the door. Finish what you started.", 2.5)
			return
		var out: Dictionary = current_interior
		current_interior = {}
		if out.get("dungeon", false):
			_clear_crypt_contents()
		player.velocity = Vector2.ZERO
		player.knockback = Vector2.ZERO
		environment.fade = 1.0
		var tw := create_tween()
		tw.tween_method(func(v: float) -> void: environment.fade = v, 1.0, 0.0, 0.5)
		player.global_position = out["door"] + Vector2(0, 14.0)
		camera.global_position = player.global_position
		camera.reset_smoothing()
		audio.play("menu2", 0.03, -6.0)
		current_region = ""
		_update_region(true)


# ------------------------------------------------------------------ night & companion content
func _spawn_moonpetals() -> void:
	for spot in MOONPETAL_SPOTS:
		var pos := Vector2(float(spot[0]) * 16.0 + 8.0, float(spot[1]) * 16.0 + 8.0)
		var s := AnimatedSprite2D.new()
		s.sprite_frames = AnimLib.strip_frames("res://assets/packs/ninja_adventure/tilesets/flower_anim.png", 16, 6.0, true)
		s.offset = Vector2(-8, -14)
		s.position = pos
		s.visible = false
		s.z_index = 2
		entities.add_child(s)
		s.play("play")
		var l := PointLight2D.new()
		l.texture = WorldScript.light_texture()
		l.color = Color(0.75, 0.8, 1.0)
		l.energy = 0.0
		l.texture_scale = 0.6
		l.position = Vector2(0, -6)
		s.add_child(l)
		moonpetals.append({"node": s, "light": l, "pos": pos, "taken": false})


func _spawn_night_wisps() -> void:
	if not night_wisps.is_empty():
		return
	for spot in NIGHT_WISP_SPOTS:
		var pos := Vector2(float(spot[1]) * 16.0, float(spot[2]) * 16.0)
		var e := EnemyScript.new()
		e.setup(self, spot[0], pos)
		entities.add_child(e)
		e.set_meta("night_only", true)
		enemies.append(e)
		night_wisps.append(e)
		flash_light(pos, Color(0.7, 0.75, 1.0), 0.8, 0.8)


func _clear_night_wisps() -> void:
	for e in night_wisps:
		if is_instance_valid(e):
			e.queue_free()
			enemies.erase(e)
	night_wisps.clear()


func _spawn_companion() -> void:
	if moth_active and is_instance_valid(companion):
		return
	companion = CompanionScript.new()
	companion.setup(self)
	entities.add_child(companion)
	moth_active = true
	flags["moth"] = true
	unlock_achievement("tiny_guide")
	save_game()


# ------------------------------------------------------------------ title & start
func _enter_title() -> void:
	game_started = false
	player.input_enabled = false
	player.visible = false
	environment.time_of_day = 0.74
	var lake: Array = world.data["landmarks"]["lake_lumen"]
	camera.position_smoothing_enabled = false
	camera.global_position = Vector2(lake[0], lake[1]) + Vector2(-60, 40)
	_title_t = 0.0
	audio.play_music("title")
	hud.show_title_menu(Save.exists())
	hud.hide_boss()


func _on_start_requested(new_game: bool = true) -> void:
	if new_game:
		Save.erase()
		_reset_state()
	else:
		_reset_state()
		load_game()
	hud.hide_title_menu()
	game_started = true
	game_over = false
	player.visible = true
	player.input_enabled = true
	camera.position_smoothing_enabled = true
	camera.global_position = player.global_position
	camera.reset_smoothing()
	current_region = ""
	environment.fade = 1.0
	create_tween().tween_property(environment, "fade", 0.0, 0.8)
	_update_region(true)
	hud.set_seed_count(moonseeds.size())
	if new_game:
		hud.show_message("Elder Alder is waiting in Hearthgrove. Press E to talk.", 5.0)
	audio.play("accept", 0.0, -4.0)


func _reset_state() -> void:
	moonseeds.clear()
	defeated_bosses.clear()
	opened_chests.clear()
	flags.clear()
	materials = {"wood": 0, "ore": 0, "herb": 0}
	discovered_waystones = ["hearthgrove"]
	last_waystone = "hearthgrove"
	victory = false
	kills = 0
	environment.time_of_day = 0.34
	environment.blight = 0.6
	world.ground_material.set_shader_parameter("moonwell_power", 0.0)
	var p := player
	p.base_hearts = 5
	p.heart_pieces = 0
	p.weapons_owned.assign(["thornblade", "bloomstaff"])
	p.weapon_index = 0
	p.inventory.assign(["plum_cloak"])
	p.equipped = {"cloak": "plum_cloak"}
	p.moontea_charges = 3
	p.moontea_max = 3
	p.petalcoins = 0
	p.classes.clear()
	p.class_nodes.clear()
	p.skill_bar.clear()
	p.skill_cd.clear()
	p.buffs.clear()
	p.xp = 0
	p.level = 1
	p.skill_points = 0
	p.recalc_stats()
	p.focus = p.focus_max
	p.apply_outfit()
	p.revive(Vector2(world.data["start"][0], world.data["start"][1]))
	for c in chests:
		c["open"] = false
		(c["sprite"] as Sprite2D).frame = 0
		c["glow"].visible = true
	for b in bosses:
		b.defeated = false
		b.awake = false
		b.hp = b.max_hp
		b.visible = true
		b.global_position = b.home
		b.collision_layer = 16
		b.collision_mask = 1
		b.mat.set_shader_parameter("dissolve", 0.0)
	for e in enemies:
		e.respawn()
		e.modulate.a = 1.0
	for pk in pickups:
		if is_instance_valid(pk["node"]):
			pk["node"].queue_free()
	pickups.clear()
	achievements.clear()
	stats = {"fish": {}, "moonpetals": 0, "parries": 0, "depths_best": 0}
	moth_active = false
	flags.erase("moth")
	if is_instance_valid(companion):
		companion.queue_free()
		companion = null
	_clear_night_wisps()
	_night_was = false
	_descend_prompted = false
	for mp in moonpetals:
		mp["taken"] = false
		mp["node"].visible = false
	if depths.active:
		depths.ascend(true)
	fishing.cancel()
	_clear_crypt_contents()
	crypt_cleared_once = false
	current_interior = {}
	quests.clear()
	_refresh_waystones()
	active_boss = null


func return_to_title() -> void:
	hud.close_shop()
	if hud.dialogue_open:
		hud.end_dialogue()
	_enter_title()


func _on_retry_requested() -> void:
	if depths.active:
		depths.ascend(true)
	if victory:
		game_over = false
		player.input_enabled = true
		return
	game_over = false
	var ws := _waystone(last_waystone)
	player.revive(ws["pos"] + Vector2(0, 18))
	player.input_enabled = true
	camera.global_position = player.global_position
	camera.reset_smoothing()
	for e in enemies:
		if e.alive:
			e.global_position = e.home
			e.aggro = false
	for b in bosses:
		if not b.defeated:
			b.awake = false
			b.hp = b.max_hp
			b.global_position = b.home
	active_boss = null
	hud.hide_boss()
	current_region = ""
	_update_region(true)
	environment.fade = 1.0
	create_tween().tween_property(environment, "fade", 0.0, 0.8)


func _on_player_died() -> void:
	game_over = true
	player.input_enabled = false
	audio.play("gameover", 0.0, -2.0)
	fx.shake(5.0, 0.3)
	var tw := create_tween()
	tw.tween_interval(1.1)
	tw.tween_callback(func() -> void: hud.show_game_over())


# ------------------------------------------------------------------ main loop
func _process(delta: float) -> void:
	audio.listener_pos = camera.global_position
	if not game_started:
		_title_t += delta
		var lake: Array = world.data["landmarks"]["lake_lumen"]
		camera.global_position = Vector2(lake[0], lake[1]) + Vector2(-60 + sin(_title_t * 0.08) * 120.0, 30 + cos(_title_t * 0.06) * 40.0)
		world.update_foliage(Vector2(-9999, -9999), environment.gust)
		return
	player.input_enabled = not game_over and not hud.any_menu_open() and not get_tree().paused
	_update_camera(delta)
	world.update_foliage(player.global_position, environment.gust)
	_update_pickups(delta)
	_update_interactables()
	_content_tick(delta)
	_activation_t -= delta
	if _activation_t <= 0.0:
		_activation_t = 0.25
		_update_activation()
		_update_region(false)
	if not get_tree().paused and not game_over:
		if Input.is_action_just_pressed("craft"):
			craft_next_upgrade()
		if Input.is_action_just_pressed("interact"):
			_interact()
		if Input.is_action_just_pressed("switch_weapon") and not hud.touch_held.size():
			player.cycle_weapon()
		if Input.is_action_just_pressed("skill"):
			player.activate_mothlight()
		if Input.is_action_just_pressed("guard"):
			player.activate_petalguard()
		if Input.is_action_just_pressed("relic"):
			if not player.activate_relic() and player.relic_block_reason() != "cooldown":
				hud.show_message(player.relic_block_reason(), 1.5)
		if Input.is_action_just_pressed("target_next"):
			player.cycle_target()
		if Input.is_action_just_pressed("heal"):
			if not player.drink_moontea():
				if player.moontea_charges <= 0:
					hud.show_message("Your Moontea flask is empty. Rest at a waystone.", 2.0)
		for i in range(4):
			if Input.is_action_just_pressed("art%d" % (i + 1)):
				player.cast_slot(i)
	var mw_power: float = world.ground_material.get_shader_parameter("moonwell_power")
	moonwell_light.energy = (0.15 + mw_power * 0.7) * (0.4 + environment.darkness) + sin(Time.get_ticks_msec() / 600.0) * 0.08
	_save_t += delta
	if _save_t > 45.0 and not game_over and active_boss == null:
		_save_t = 0.0
		save_game()


func _update_camera(delta: float) -> void:
	var target := player.global_position + Vector2(0, -8)
	var look := player.velocity * 0.22
	if active_boss and is_instance_valid(active_boss):
		target = target.lerp(active_boss.global_position, 0.3)
		look *= 0.3
	_look = _look.lerp(look, clampf(delta * 3.0, 0.0, 1.0))
	camera.global_position = target + _look
	if shake_time > 0.0:
		shake_time -= delta
		camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake_strength * (shake_time / 0.3 + 0.3)
	else:
		camera.offset = camera.offset.lerp(Vector2.ZERO, clampf(delta * 12.0, 0.0, 1.0))


func _on_shake(strength: float, duration: float) -> void:
	shake_strength = maxf(shake_strength if shake_time > 0.0 else 0.0, strength)
	shake_time = maxf(shake_time, duration)


func _update_activation() -> void:
	var pp := player.global_position
	var now := Time.get_ticks_msec() / 1000.0
	for e in enemies:
		var near: bool = e.global_position.distance_to(pp) < 420.0
		e.set_physics_process(near and e.alive)
		if not e.alive and not e.has_meta("night_only") and e.respawn_at > 0.0 and now > e.respawn_at and e.home.distance_to(pp) > 320.0:
			e.respawn_at = -1.0
			e.respawn()


func _content_tick(delta: float) -> void:
	var night: bool = environment.is_night()
	for mp in moonpetals:
		var show: bool = night and not mp["taken"] and game_started
		mp["node"].visible = show
		mp["light"].energy = 0.5 if show else 0.0
	if night != _night_was:
		_night_was = night
		if night:
			for mp in moonpetals:
				mp["taken"] = false
			if game_started and not game_over:
				_spawn_night_wisps()
				hud.show_message("Night falls. Moonpetals open along the water...", 3.5)
		else:
			_clear_night_wisps()
	_ach_t += delta
	if _ach_t < 1.0:
		return
	_ach_t = 0.0
	if player.petalcoins >= 500:
		unlock_achievement("coin_hoard")
	if player.max_health >= 40:
		unlock_achievement("fullbloom")
	if not waystones.is_empty() and discovered_waystones.size() >= waystones.size():
		unlock_achievement("welltraveled")
	if not chests.is_empty() and opened_chests.size() >= chests.size():
		unlock_achievement("chestnut")
	if player.weapons_owned.size() >= 4:
		unlock_achievement("arsenal")


func _update_region(force: bool) -> void:
	if not current_interior.is_empty():
		# inside a house or the crypt: show the room name, leave the music alone
		current_biome = clampi(world.biome_at(player.global_position), 0, 6)
		if current_region != current_interior["name"] or force:
			current_region = current_interior["name"]
			hud.show_region(current_interior["name"], "inside")
			audio.play_ambient("")
		return
	current_biome = world.biome_at(player.global_position)
	var name: String = world.region_name(player.global_position)
	if name == current_region and not force:
		return
	current_region = name
	var sub := ""
	match name:
		"Hearthgrove":
			sub = "a village of lanterns and soft bread"
		"The Moonwell":
			sub = "heart of the valley"
		"Lake Lumen":
			sub = "where the moon used to bathe"
		_:
			sub = ["meadows of drifting petals", "the old grove remembers", "sun-scarred and silent", "frost on forgotten stone", "reeds and slow water", "salt wind and shells", "where petals fall from the stars"][clampi(current_biome, 0, 6)]
	hud.show_region(name, sub)
	if name == "Starfall Rise":
		unlock_achievement("star_walker")
	if active_boss == null:
		var track: String = DB.REGION_MUSIC[clampi(current_biome, 0, 6)]
		if name == "Hearthgrove":
			track = "village"
		elif name == "The Moonwell" or environment.is_night():
			track = "night" if not victory else "ending"
		audio.play_music(track)
	audio.play_ambient(["bird", "wind", "wind", "wind", "rain", "water1", "wind"][clampi(current_biome, 0, 6)] if environment.quality_high else "")


# ------------------------------------------------------------------ combat api
func player_targetable() -> bool:
	return game_started and not game_over and player.state != player.State.DEAD


## Depths foes are duck-typed Nodes (enemies or echo bosses); Node.get() takes
## one argument, so probe the members defensively instead of two-arg get().
func _depths_target_alive(t: Node) -> bool:
	var v = t.get("alive")
	if v == null:
		v = true
	return bool(v) and not bool(t.get("defeated"))


func hittable_targets(center: Vector2, radius: float) -> Array:
	var out: Array = []
	for e in enemies:
		if e.alive and (e.global_position + Vector2(0, -5)).distance_to(center) <= radius:
			out.append(e)
	for b in bosses:
		if b.awake and not b.defeated and (b.global_position + Vector2(0, -10)).distance_to(center) <= radius + float(b.cfg["radius"]):
			out.append(b)
	if is_instance_valid(crypt_boss) and crypt_boss.awake and not crypt_boss.defeated and (crypt_boss.global_position + Vector2(0, -10)).distance_to(center) <= radius + float(crypt_boss.cfg["radius"]):
		out.append(crypt_boss)
	for t in depths.targets():
		if is_instance_valid(t) and _depths_target_alive(t) and (t.global_position + Vector2(0, -5)).distance_to(center) <= radius:
			out.append(t)
	return out


## Every hit on an enemy/boss lands here. Curse/expose vulnerability is applied
## once; returns the damage actually dealt.
func damage_target(t: Node, amount: int, from: Vector2, force: float, info: Dictionary = {}) -> int:
	if t == null or not is_instance_valid(t):
		return 0
	var st := StatusFx.of(t)
	if st != null and st.vulnerability() > 0.0:
		amount = int(ceil(float(amount) * (1.0 + st.vulnerability())))
	if t.hurt(amount, from, force, info):
		return amount
	return 0


## Targets inside a sector (origin, facing, reach, half-angle). Bosses count
## their body radius. This is the exact shape the attack indicator draws.
func targets_in_arc(origin: Vector2, dir: Vector2, reach: float, half_angle: float) -> Array:
	var out: Array = []
	var d := dir.normalized() if dir.length() > 0.01 else Vector2.DOWN
	for t in hittable_targets(origin, reach + 40.0):
		var pt: Vector2 = t.global_position + Vector2(0, -5)
		var extra := 0.0
		if t.get("cfg") != null and (t.cfg as Dictionary).has("radius"):
			extra = float(t.cfg["radius"])
			pt = t.global_position + Vector2(0, -10)
		var to: Vector2 = pt - origin
		if to.length() > reach + extra:
			continue
		if to.length() > 6.0 + extra and absf(d.angle_to(to)) > half_angle:
			continue
		out.append(t)
	return out


func break_props(center: Vector2, radius: float) -> void:
	for b in world.break_at(center, radius + 4.0):
		_break_prop(b)


func melee_hit(center: Vector2, radius: float, damage: int, force: float, _dir: Vector2, _kind: String) -> int:
	var hits := 0
	for t in hittable_targets(center, radius):
		player.deal(t, damage, {"source": "art", "force": force, "can_crit": false})
		hits += 1
	for b in world.break_at(center, radius + 4.0):
		_break_prop(b)
		hits += 0
	return hits


func _break_prop(b: Dictionary) -> void:
	var pos: Vector2 = b["pos"]
	var kind: String = b["kind"]
	var material := ""
	if kind.begins_with("bush") or kind == "grass":
		material = "herb"
	elif kind in ["crate", "barrel", "stump", "log"]:
		material = "wood"
	elif kind in ["rock", "stone", "ore"]:
		material = "ore"
	if not material.is_empty():
		gather_material(material, 1 + (1 if randf() < 0.25 else 0))
	if kind.begins_with("bush"):
		fx.burst("leaf", pos, 10, 70.0, Color(1, 1, 1), 120.0)
		fx.burst("grass", pos, 6, 50.0, Color(1, 1, 1), 120.0)
		audio.play("grass", 0.12, -6.0, pos)
	else:
		fx.burst("wood" if kind in ["crate", "barrel"] else "rock", pos, 10, 80.0, Color(1, 1, 1), 200.0)
		audio.play("explosion" if kind in ["crate", "barrel"] else "hit1", 0.12, -8.0, pos)
	var roll := randf()
	if roll < 0.35:
		spawn_coin(pos, 1 + randi() % 2)
	elif roll < 0.45 and player.health < player.max_health:
		spawn_heart(pos)


func gather_material(id: String, amount := 1) -> void:
	if not materials.has(id) or amount <= 0:
		return
	materials[id] = int(materials[id]) + amount
	hud.show_message("Gathered %d %s · W %d / O %d / H %d. Press U to craft." % [amount, id, int(materials["wood"]), int(materials["ore"]), int(materials["herb"])], 2.5)


func craft_next_upgrade() -> bool:
	for recipe in CRAFT_RECIPES:
		if player.weapons_owned.has(recipe["id"]) or player.inventory.has(recipe["id"]):
			continue
		for material in recipe["needs"]:
			if int(materials.get(material, 0)) < int(recipe["needs"][material]):
				hud.show_message("Need %s to craft %s." % [str(recipe["needs"]), DB.ITEMS[recipe["id"]]["name"]], 2.5)
				return false
		for material in recipe["needs"]:
			materials[material] = int(materials[material]) - int(recipe["needs"][material])
		player.give_item(recipe["id"])
		hud.show_item_get(recipe["id"])
		hud.show_message("Crafted %s (Tier II)." % DB.ITEMS[recipe["id"]]["name"], 3.0)
		save_game()
		return true
	hud.show_message("All available fieldcraft upgrades are complete.", 2.5)
	return false


func auto_aim(origin: Vector2, facing: Vector2, reach: float) -> Vector2:
	var best: Node2D = null
	var best_score := -1.0
	for t in hittable_targets(origin, reach):
		var to: Vector2 = (t.global_position + Vector2(0, -5)) - origin
		var dot := facing.dot(to.normalized())
		if dot > 0.55:
			var score := dot - to.length() / reach * 0.4
			if score > best_score:
				best_score = score
				best = t
	if best:
		return ((best.global_position + Vector2(0, -5)) - (origin + Vector2(0, -8))).normalized()
	return facing


func nearest_enemy(pos: Vector2, reach: float) -> Node2D:
	var best: Node2D = null
	var bd := reach
	for t in hittable_targets(pos, reach):
		var d := pos.distance_to(t.global_position)
		if d < bd:
			bd = d
			best = t
	return best


func spawn_projectile(d: Dictionary) -> void:
	var p := ProjectileScript.new()
	projectiles.add_child(p)
	p.setup(self, d)


func area_damage_player(center: Vector2, radius: float, amount: int) -> void:
	if player_targetable() and player.global_position.distance_to(center) <= radius and not player.airborne:
		if player.take_damage(amount, center):
			on_player_hit()


func on_player_hit() -> void:
	fx.shake(3.0, 0.18)
	environment.damage_flash = 0.6
	audio.play("hit2", 0.08, -2.0)
	hitstop(0.05)


func hitstop(duration: float) -> void:
	if _hitstop_active:
		return
	_hitstop_active = true
	Engine.time_scale = 0.08
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
	_hitstop_active = false


func flash_light(pos: Vector2, color: Color, energy: float, duration: float) -> void:
	var l := PointLight2D.new()
	l.texture = WorldScript.light_texture()
	l.color = color
	l.energy = energy
	l.texture_scale = 2.4
	l.global_position = pos
	add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "energy", 0.0, duration)
	tw.tween_callback(l.queue_free)


func emote(node: Node2D, index: int) -> void:
	var s := Sprite2D.new()
	s.texture = AnimLib.tex("ui/emote/emote%d.png" % index)
	s.position = Vector2(0, -22)
	node.add_child(s)
	s.scale = Vector2(0.2, 0.2)
	var tw := s.create_tween()
	tw.tween_property(s, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.7)
	tw.tween_property(s, "modulate:a", 0.0, 0.25)
	tw.tween_callback(s.queue_free)


func on_enemy_killed(e: Node) -> void:
	kills += 1
	e.respawn_at = Time.get_ticks_msec() / 1000.0 + 90.0
	if e.has_meta("night_only"):
		e.respawn_at = -1.0
		night_wisps.erase(e)
	unlock_achievement("first_thorn")
	if kills >= 100:
		unlock_achievement("bane_of_blight")
	var coins: int = int(e.cfg.get("coins", 1))
	player.add_xp(3 + coins)
	_quest_progress("kills")
	spawn_coin(e.global_position, coins)
	if randf() < 0.18 and player.health < player.max_health:
		spawn_heart(e.global_position)
	hitstop(0.04)


func on_boss_awake(b: Node) -> void:
	active_boss = b
	hud.show_boss(b)
	hud.show_region(b.title, "guardian of the Moonseed")
	audio.play_music("boss", 0.8)
	audio.play("alert2", 0.0, -2.0)
	fx.shake(3.0, 0.4)
	emote(player, 21)


func on_boss_sleep(b: Node) -> void:
	if active_boss == b:
		active_boss = null
		hud.hide_boss()
		current_region = ""
		_update_region(true)


func on_boss_defeated(b: Node) -> void:
	active_boss = null
	hud.hide_boss()
	if b.has_meta("dungeon"):
		# Hollow Crypt guardian: loot and a flag, but no Moonseed or world-state change
		audio.play("success3", 0.0, -1.0)
		hitstop(0.25)
		player.add_petalcoins(80)
		for i in range(6):
			spawn_coin(b.global_position + Vector2(randf_range(-20, 20), randf_range(-10, 10)), 4)
		player.give_item("moonveil_ring")
		player.pose_item(AnimLib.tex(DB.ITEMS["moonveil_ring"]["icon"]), 1.6)
		hud.show_item_get("moonveil_ring")
		flags["crypt_cleared"] = true
		crypt_cleared_once = true
		_quest_progress("flag", "crypt_cleared")
		save_game()
		return
	if String(b.boss_id).begins_with("echo_"):
		# guardian echoes from the Depths: no Moonseed, no world-state change
		audio.play("success3", 0.0, -1.0)
		hitstop(0.25)
		get_tree().create_timer(2.0, true, false, true).timeout.connect(b.queue_free)
		return
	defeated_bosses.append(b.boss_id)
	_quest_progress("boss")
	audio.play("success3", 0.0, -1.0)
	hitstop(0.25)
	_spawn_moonseed(b.global_position + Vector2(0, -4), b.boss_id)
	for i in range(10):
		spawn_coin(b.global_position + Vector2(randf_range(-20, 20), randf_range(-10, 10)), 3)
	current_region = ""
	_update_region(true)


# ------------------------------------------------------------------ pickups
func spawn_coin(pos: Vector2, amount: int) -> void:
	for i in range(clampi(amount, 1, 6)):
		var s := AnimatedSprite2D.new()
		s.sprite_frames = AnimLib.strip_frames("res://assets/packs/ninja_adventure/items/coin2.png", 10, 10.0, true)
		s.play("play")
		s.offset = Vector2(0, -5)
		_add_pickup(s, pos, "coin", 1)


func spawn_heart(pos: Vector2) -> void:
	var s := Sprite2D.new()
	s.texture = AnimLib.tex("items/heart.png")
	s.offset = Vector2(0, -4)
	_add_pickup(s, pos, "heart", 4)


func _spawn_moonseed(pos: Vector2, id: String) -> void:
	var s := Sprite2D.new()
	s.texture = AnimLib.tex("items/seedlarge.png")
	s.offset = Vector2(0, -8)
	var l := PointLight2D.new()
	l.texture = WorldScript.light_texture()
	l.color = Color(0.8, 0.85, 1.0)
	l.energy = 1.2
	l.texture_scale = 1.4
	s.add_child(l)
	_add_pickup(s, pos, "moonseed", 1, id)


func _add_pickup(node: Node2D, pos: Vector2, kind: String, value: int, id := "") -> void:
	node.position = pos
	entities.add_child(node)
	var v := Vector2.from_angle(randf() * TAU) * randf_range(20.0, 55.0) if kind != "moonseed" else Vector2.ZERO
	pickups.append({"node": node, "kind": kind, "value": value, "vel": v, "h": 0.0, "vh": 90.0 if kind != "moonseed" else 0.0, "t": 0.0, "id": id})


func _update_pickups(delta: float) -> void:
	var pp := player.global_position
	for i in range(pickups.size() - 1, -1, -1):
		var pk: Dictionary = pickups[i]
		var n: Node2D = pk["node"]
		if not is_instance_valid(n):
			pickups.remove_at(i)
			continue
		pk["t"] += delta
		pk["vh"] -= 320.0 * delta
		pk["h"] = maxf(0.0, pk["h"] + pk["vh"] * delta)
		if pk["h"] <= 0.0 and pk["vh"] < 0.0:
			pk["vh"] = -pk["vh"] * 0.4 if absf(pk["vh"]) > 30.0 else 0.0
		pk["vel"] = (pk["vel"] as Vector2).move_toward(Vector2.ZERO, 80.0 * delta)
		n.position += pk["vel"] * delta
		var bob: float = sin(pk["t"] * 3.0) * 2.0 if pk["kind"] == "moonseed" else 0.0
		(n as Node2D).set("offset", Vector2(0, -5.0 - pk["h"] + bob) if pk["kind"] != "moonseed" else Vector2(0, -12.0 + bob))
		var d := n.global_position.distance_to(pp)
		if pk["t"] > 0.35 and d < 46.0 and pk["kind"] != "moonseed" and player_targetable():
			n.position = n.position.move_toward(pp, (160.0 + (46.0 - d) * 6.0) * delta)
		if pk["t"] > 0.3 and d < 9.0 and player_targetable():
			_collect(pk)
			n.queue_free()
			pickups.remove_at(i)
		elif pk["t"] > 40.0 and pk["kind"] != "moonseed":
			n.queue_free()
			pickups.remove_at(i)


func _collect(pk: Dictionary) -> void:
	match pk["kind"]:
		"coin":
			player.add_petalcoins(pk["value"])
			audio.play("coin", 0.1, -8.0)
		"heart":
			player.health = mini(player.max_health, player.health + int(pk["value"]))
			player.health_changed.emit()
			audio.play("heal", 0.1, -8.0)
		"moonseed":
			if not moonseeds.has(pk["id"]):
				moonseeds.append(pk["id"])
			hud.set_seed_count(moonseeds.size())
			player.pose_item(AnimLib.tex("items/seedlarge.png"), 1.6)
			hud.show_item_get("moonseed")
			audio.play("levelup1", 0.0, -1.0)
			fx.spawn("spark_circle", player.global_position + Vector2(0, -16), 0.0, 1.8, Color(0.85, 0.9, 1.0), null, true)
			environment.blight = 0.6 - moonseeds.size() * 0.12
			unlock_achievement("seedbearer")
			if not moth_active:
				_spawn_companion()
			save_game()


# ------------------------------------------------------------------ interaction
func _update_interactables() -> void:
	var pp := player.global_position
	var best: Dictionary = {}
	var bd := 26.0
	for n in npcs:
		var d: float = n.global_position.distance_to(pp)
		if d < bd:
			bd = d
			best = {"type": "npc", "node": n, "label": "TALK"}
	for c in chests:
		if c["open"]:
			continue
		var d2: float = (c["pos"] as Vector2).distance_to(pp)
		if d2 < bd:
			bd = d2
			best = {"type": "chest", "chest": c, "label": "OPEN"}
	for w in waystones:
		var d3: float = (w["pos"] as Vector2).distance_to(pp + Vector2(0, -6))
		if d3 < bd + 4.0:
			bd = d3
			best = {"type": "waystone", "ws": w, "label": "REST"}
	if not current_interior.is_empty():
		# the way out stands at the south wall of whatever room we are in
		var d4: float = _interior_door(current_interior).distance_to(pp)
		if d4 < 30.0:
			bd = d4
			best = {"type": "door", "house": current_interior, "label": "LEAVE"}
	else:
		for h in HOUSES:
			var d5: float = (h["door"] as Vector2).distance_to(pp)
			if d5 < 26.0 and d5 < bd:
				bd = d5
				best = {"type": "door", "house": h, "label": "ENTER"}
	if environment.is_night() and not game_over:
		for mp in moonpetals:
			if mp["taken"]:
				continue
			var dm: float = (mp["pos"] as Vector2).distance_to(pp)
			if dm < 24.0 and dm < bd:
				bd = dm
				best = {"type": "moonpetal", "mp": mp, "label": "GATHER"}
	if not fishing.active and not game_over and player.state == player.State.MOVE and not player.swimming and player.health > 0:
		var probe: Vector2 = pp + player.facing * 20.0
		if world.is_water(probe) and best.is_empty():
			best = {"type": "fishing", "pos": probe, "label": "FISH"}
	if moonwell.global_position.distance_to(pp) < 44.0:
		best = {"type": "moonwell", "label": "MOONWELL"}
	_interact_target = best
	hud.set_interact_visible(not best.is_empty(), best.get("label", ""))


func _interact() -> void:
	if _interact_target.is_empty() or hud.any_menu_open():
		return
	if fishing.active:
		return
	match _interact_target["type"]:
		"npc":
			_talk(_interact_target["node"])
		"chest":
			_open_chest(_interact_target["chest"])
		"waystone":
			_rest_at(_interact_target["ws"])
		"door":
			_use_door(_interact_target["house"])
		"moonwell":
			_use_moonwell()
		"moonpetal":
			_gather_moonpetal(_interact_target["mp"])
		"fishing":
			if not player.inventory.has("fishing_rod"):
				hud.show_message("You have no rod. Pip sells willow rods in Hearthgrove.", 2.5)
			else:
				fishing.start(self, _interact_target["pos"])


func _talk(n: Node) -> void:
	talking_npc = n
	n.talking = true
	var face: Texture2D = AnimLib.tex("npcs/%s/faceset.png" % n.sprite_name)
	var lines := DB.dialogue(n.npc_id, moonseeds.size(), flags)
	shop_id = n.npc_id if (n.is_shop or SHOPS.has(n.npc_id)) else ""
	_quest_on_talk(n.npc_id)
	hud.start_dialogue(n.display_name, face, lines)


## Journeys: talking to a giver starts their quests; talking again claims the
## finished ones. Talk-objective quests resolve when the target NPC is met.
func _quest_on_talk(npc_id: String) -> void:
	for q in QuestSys.QUESTS:
		if q["giver"] != npc_id:
			continue
		var e: Dictionary = QuestSys.entry(quests, q["id"])
		if e["s"] == QuestSys.STATE_AVAILABLE:
			e["s"] = QuestSys.STATE_ACTIVE
			hud.show_message("Journey begun: %s" % q["name"], 3.0)
			audio.play("menu2", 0.04, -6.0)
		elif e["s"] == QuestSys.STATE_DONE:
			e["s"] = QuestSys.STATE_CLAIMED
			_pay_quest_reward(q)
	for q in QuestSys.QUESTS:
		if q["type"] == "talk" and q["target"] == npc_id:
			_quest_progress("talk", npc_id)


func _quest_progress(type: String, key := "", amount := 1) -> void:
	for q in QuestSys.QUESTS:
		if q["type"] != type:
			continue
		if q.has("target") and q["target"] != key:
			continue
		var e: Dictionary = QuestSys.entry(quests, q["id"])
		if e["s"] != QuestSys.STATE_ACTIVE:
			continue
		e["n"] = mini(int(e["n"]) + amount, int(q["goal"]))
		if QuestSys.mark_done(quests, q["id"]):
			hud.show_message("Journey done: %s! Report back to %s." % [q["name"], q["giver"].capitalize()], 4.0)
			audio.play("success1", 0.02, -4.0)
			save_game()


func _pay_quest_reward(q: Dictionary) -> void:
	var r: Dictionary = q["reward"]
	var parts := PackedStringArray()
	if r.has("coins"):
		player.add_petalcoins(int(r["coins"]))
		spawn_coin(player.global_position + Vector2(0, -6), clampi(int(r["coins"]) / 4, 1, 6))
		parts.append("+%d Petalcoins" % int(r["coins"]))
	if r.has("xp"):
		player.add_xp(int(r["xp"]))
		parts.append("+%d XP" % int(r["xp"]))
	if r.has("item"):
		player.give_item(r["item"])
		hud.show_item_get(r["item"])
		parts.append(DB.ITEMS[r["item"]]["name"])
	audio.play("levelup1", 0.02, -3.0)
	fx.spawn("spark_circle", player.global_position + Vector2(0, -10), 0.0, 1.4, Color(1.0, 0.85, 0.6), null, true)
	hud.show_message("Journey rewarded: %s! %s" % [q["name"], ", ".join(parts)], 4.0)
	save_game()


func journey_text() -> String:
	return QuestSys.tracker_text(quests)


func on_dialogue_command(cmd: String) -> void:
	match cmd:
		"moontea":
			flags["mira_tea"] = true
			player.give_item("moontea")
			hud.show_item_get("moontea")
			audio.play("success1", 0.0, -4.0)
		"shop":
			if SHOPS.has(shop_id):
				hud.open_shop(_shop_stock())


func on_dialogue_closed() -> void:
	if talking_npc and is_instance_valid(talking_npc):
		talking_npc.talking = false
	talking_npc = null


func _shop_stock() -> Array:
	var out: Array = []
	for e in SHOPS.get(shop_id, []):
		if e.has("once") and flags.get(e["once"], false):
			continue
		out.append(e)
	return out


func can_buy(entry: Dictionary) -> bool:
	if player.petalcoins < int(entry["price"]):
		return false
	if entry["id"] == "fishing_rod" and player.inventory.has("fishing_rod"):
		return false
	if entry["id"] == "moontea" and player.moontea_charges >= player.moontea_max and player.moontea_max >= 6:
		return false
	return true


func buy_item(entry: Dictionary) -> void:
	if not can_buy(entry):
		audio.play("cancel", 0.0, -4.0)
		return
	player.petalcoins -= int(entry["price"])
	player.give_item(entry["id"])
	if entry.has("once"):
		flags[entry["once"]] = true
	audio.play("coin", 0.0, -4.0)
	hud.show_item_get(entry["id"])
	hud.refresh_shop(_shop_stock())


func _open_chest(c: Dictionary) -> void:
	c["open"] = true
	opened_chests.append(c["id"])
	var s: Sprite2D = c["sprite"]
	s.frame = 1
	c["glow"].visible = false
	var id: String = c["item"]
	audio.play("secret2" if c["big"] else "success1", 0.0, -3.0)
	fx.spawn("spark_circle", c["pos"] + Vector2(0, -10), 0.0, 1.2, Color(1, 0.92, 0.7), null, true)
	fx.burst("spark", c["pos"] + Vector2(0, -10), 10, 60.0, Color(1, 0.9, 0.6), -20.0)
	player.give_item(id)
	player.pose_item(AnimLib.tex(DB.ITEMS[id]["icon"]), 1.3)
	hud.show_item_get(id)
	save_game()


func _rest_at(w: Dictionary) -> void:
	var first: bool = not discovered_waystones.has(w["id"])
	if first:
		discovered_waystones.append(w["id"])
	last_waystone = w["id"]
	player.heal_full()
	_quest_progress("waystone", w["id"])
	_refresh_waystones()
	fx.spawn("aura", player.global_position + Vector2(0, -8), 0.0, 1.6, Color(0.85, 0.8, 1.0), null, true)
	fx.burst("spark", w["pos"] + Vector2(0, -14), 14, 50.0, Color(0.85, 0.8, 1.0), -30.0, 1.0)
	audio.play("magic1" if not first else "secret2", 0.0, -3.0)
	hud.show_message(("Waystone awakened: %s. " % w["name"] if first else "") + "Hearts and Moontea restored. Journey saved.", 3.0)
	save_game()


func _refresh_waystones() -> void:
	for w in waystones:
		var on: bool = discovered_waystones.has(w["id"])
		w["circle"].modulate.a = 0.7 if on else 0.0
		w["light"].energy = 0.45 if on else 0.0


func _use_moonwell() -> void:
	if victory:
		if depths.active:
			depths.ascend()
			return
		if not _descend_prompted:
			_descend_prompted = true
			hud.show_message("The Moonwell hums softly. A stair of light waits beneath it — press E again to descend into the Blighted Depths.", 4.5)
			return
		depths.descend()
		return
	if moonseeds.size() < 4:
		hud.show_message("The Moonwell is dim. Moonseeds returned: %d / 4." % moonseeds.size(), 3.0)
		audio.play("voice5", 0.0, -8.0)
		return
	victory = true
	unlock_achievement("waker_of_wells")
	player.input_enabled = false
	audio.play_music("ending", 2.0)
	audio.play("levelup1", 0.0, 0.0)
	fx.shake(4.0, 0.8)
	for i in range(4):
		fx.spawn("spark_circle", moonwell.global_position + Vector2.from_angle(TAU * i / 4.0) * 22.0, 0.0, 1.4, Color(0.85, 0.9, 1.0), null, true)
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: world.ground_material.set_shader_parameter("moonwell_power", v), 0.0, 1.0, 2.5)
	tw.parallel().tween_property(environment, "blight", 0.0, 3.0)
	tw.parallel().tween_property(moonwell.get_node("Circle"), "modulate:a", 1.0, 2.0)
	tw.tween_callback(func() -> void:
		flash_light(moonwell.global_position, Color(0.85, 0.9, 1.0), 3.0, 2.0)
		hud.show_victory()
		save_game())


func set_menu_pause(paused: bool) -> void:
	get_tree().paused = paused


# ------------------------------------------------------------------ feats & new content api
func unlock_achievement(id: String) -> void:
	if achievements.has(id) or not Ach.DEFS.has(id):
		return
	achievements[id] = true
	hud.show_achievement(id)
	audio.play("secret2", 0.0, -4.0)
	save_game()


func on_perfect_parry(p: Node2D) -> void:
	stats["parries"] = int(stats.get("parries", 0)) + 1
	unlock_achievement("petal_step")
	if int(stats["parries"]) >= 10:
		unlock_achievement("untouchable")
	var pos := p.global_position
	fx.ring(pos + Vector2(0, -8), 44.0, 0.5, Color(1.0, 0.85, 1.0, 0.8), false)
	fx.burst("spark", pos + Vector2(0, -10), 16, 120.0, Color(1.0, 0.85, 1.0), -80.0)
	fx.number(pos + Vector2(0, -20), "PARRY!", Color("ffd9f2"), true)
	flash_light(pos, Color(0.9, 0.8, 1.0), 1.2, 0.4)
	p.stamina = minf(p.STAMINA_MAX, p.stamina + 30.0)
	p.invulnerable_left = maxf(p.invulnerable_left, 0.5)
	melee_hit(pos, 64.0, 3, 130.0, Vector2.ZERO, "parry")
	audio.play("magic1", 0.05, -2.0)
	audio.play("impact", 0.05, -2.0)
	hitstop(0.12)
	fx.shake(4.0, 0.2)


func on_fish_caught(id: String, coins: int) -> void:
	var fish_log: Dictionary = stats.get("fish", {})
	fish_log[id] = int(fish_log.get(id, 0)) + 1
	stats["fish"] = fish_log
	player.add_petalcoins(coins)
	unlock_achievement("first_cast")
	if fish_log.size() >= DB.FISH.size():
		unlock_achievement("moonangler")
	hud.show_message("Caught a %s! (+%d Petalcoins)" % [DB.FISH[id]["name"], coins], 2.5)


func _gather_moonpetal(mp: Dictionary) -> void:
	mp["taken"] = true
	mp["node"].visible = false
	mp["light"].energy = 0.0
	stats["moonpetals"] = int(stats.get("moonpetals", 0)) + 1
	if int(stats["moonpetals"]) >= 5:
		unlock_achievement("night_gardener")
	player.moontea_charges = mini(player.moontea_max, player.moontea_charges + 1)
	player.health_changed.emit()
	player.add_petalcoins(8)
	_quest_progress("moonpetals")
	player.pose_item(AnimLib.tex(DB.ITEMS["moontea"]["icon"]), 1.3)
	hud.show_message("You gather a moonpetal. Moontea +1, Petalcoins +8.", 2.5)
	audio.play("heal", 0.05, -4.0)
	fx.burst("spark", (mp["pos"] as Vector2) + Vector2(0, -10), 10, 60.0, Color(0.8, 0.85, 1.0), -30.0)
	save_game()


func on_depths_wave_cleared(cleared_wave: int) -> void:
	if cleared_wave > int(stats.get("depths_best", 0)):
		stats["depths_best"] = cleared_wave
	if cleared_wave >= 5:
		unlock_achievement("depths_daring")
	if cleared_wave >= 10:
		unlock_achievement("depths_delver")
	var coins := 5 + cleared_wave * 3
	player.add_petalcoins(coins)
	if cleared_wave == 5 or cleared_wave == 10:
		player.heart_pieces += 1
		player.recalc_stats()
		player.health = player.max_health
		hud.show_message("Depth %d cleared! +%d Petalcoins, and a Heart Bloom opens inside you." % [cleared_wave, coins], 3.5)
	else:
		hud.show_message("Depth %d cleared! +%d Petalcoins." % [cleared_wave, coins], 2.5)
	audio.play("success1", 0.0, -3.0)
	fx.spawn("spark_circle", player.global_position + Vector2(0, -10), 0.0, 1.4, Color(0.85, 0.9, 1.0), null, true)
	save_game()


func quest_text() -> String:
	if victory:
		if int(stats.get("depths_best", 0)) == 0:
			return "The Moonwell blooms. A stair of light waits beneath it..."
		return "The Moonwell blooms. Explore freely."
	if not flags.get("met_alder", false) and moonseeds.is_empty():
		if talking_npc and talking_npc.npc_id == "alder":
			flags["met_alder"] = true
		return "Speak with Elder Alder in Hearthgrove."
	if moonseeds.size() >= 4:
		return "Return the Moonseeds to the Moonwell (north)."
	var remaining := PackedStringArray()
	for b in bosses:
		if not b.defeated:
			remaining.append(b.title.capitalize())
	return "Moonseeds %d/4. Guardians: %s" % [moonseeds.size(), ", ".join(remaining)]


func map_markers() -> Array:
	var out: Array = []
	for w in waystones:
		var wm := {"pos": w["pos"], "color": Color(0.8, 0.7, 1.0) if discovered_waystones.has(w["id"]) else Color(0.45, 0.4, 0.5)}
		if w["id"] != "hearthgrove":
			wm["label"] = w["name"].replace(" Waystone", "")
		out.append(wm)
	for b in bosses:
		if not b.defeated:
			out.append({"pos": b.home, "color": Color(1.0, 0.35, 0.35), "label": b.title.capitalize()})
	for c in chests:
		if not c["open"] and c["big"]:
			out.append({"pos": c["pos"], "color": Color(1.0, 0.85, 0.4)})
	if not flags.get("crypt_cleared", false):
		out.append({"pos": _house("crypt")["door"], "color": Color(0.9, 0.5, 1.0), "label": "Crypt"})
	out.append({"pos": moonwell.global_position, "color": Color(0.6, 0.85, 1.0), "label": "Moonwell"})
	out.append({"pos": Vector2(world.data["landmarks"]["hearthgrove"][0], world.data["landmarks"]["hearthgrove"][1]), "color": Color(1, 0.75, 0.5), "label": "Hearthgrove"})
	return out


func _waystone(id: String) -> Dictionary:
	for w in waystones:
		if w["id"] == id:
			return w
	return waystones[0]


# ------------------------------------------------------------------ save / load
func save_game() -> bool:
	if not game_started:
		return false
	var p := player
	return Save.write({
		"pos": [p.global_position.x, p.global_position.y],
		"heart_pieces": p.heart_pieces, "health": p.health,
		"weapons": p.weapons_owned, "weapon_index": p.weapon_index,
		"inventory": p.inventory, "equipped": p.equipped,
		"coins": p.petalcoins, "tea": p.moontea_charges, "tea_max": p.moontea_max,
		"seeds": moonseeds, "bosses": defeated_bosses, "chests": opened_chests, "flags": flags,
		"waystones": discovered_waystones, "last_waystone": last_waystone,
		"time": environment.time_of_day, "victory": victory,
		"achievements": achievements, "stats": stats, "moth": moth_active,
		"xp": p.xp, "level": p.level, "points": p.skill_points, "focus": p.focus,
		"classes": p.classes, "nodes": p.class_nodes, "bar": p.skill_bar,
		"skill_levels": p.skill_levels, "rewards": p.rewards_claimed,
		"quests": quests, "materials": materials,
	})


func load_game() -> bool:
	var d := Save.read()
	if d.is_empty():
		return false
	var p := player
	p.heart_pieces = int(d.get("heart_pieces", 0))
	p.weapons_owned.assign(d.get("weapons", ["thornblade", "bloomstaff"]))
	p.weapon_index = clampi(int(d.get("weapon_index", 0)), 0, p.weapons_owned.size() - 1)
	p.inventory.assign(d.get("inventory", ["plum_cloak"]))
	p.equipped = d.get("equipped", {"cloak": "plum_cloak"})
	p.petalcoins = int(d.get("coins", 0))
	p.moontea_max = int(d.get("tea_max", 3))
	p.xp = int(d.get("xp", 0))
	p.level = clampi(int(d.get("level", 1)), 1, ClassBook.LEVEL_CAP)
	p.skill_points = int(d.get("points", 0))
	p.classes.assign(d.get("classes", []))
	p.class_nodes = d.get("nodes", {})
	p.skill_bar.assign(d.get("bar", []))
	p.skill_levels = {}
	var lv: Dictionary = d.get("skill_levels", {})
	for k in lv:
		p.skill_levels[String(k)] = clampi(int(lv[k]), 1, ClassBook.SKILL_MAX_LEVEL)
	p.rewards_claimed = d.get("rewards", {})
	p._ensure_bar()
	# older saves: rank rewards for lines already bound
	for cid in p.classes:
		p._grant_rank_rewards(cid)
	quests = d.get("quests", {})
	materials = d.get("materials", {"wood": 0, "ore": 0, "herb": 0})
	for material in ["wood", "ore", "herb"]:
		materials[material] = maxi(0, int(materials.get(material, 0)))
	p.recalc_stats()
	p.apply_outfit()
	var pos: Array = d.get("pos", world.data["start"])
	p.revive(Vector2(pos[0], pos[1]))
	# if the save was written inside a room, put Mallow back in that room
	for h in HOUSES:
		var hc: Vector2 = h["center"]
		var hs: Vector2 = h["size"]
		if absf(p.global_position.x - hc.x) < hs.x / 2.0 + 8.0 and absf(p.global_position.y - hc.y) < hs.y / 2.0 + 8.0:
			current_interior = h.duplicate()
			current_interior["_in_door"] = _interior_door(h)
			if h.get("dungeon", false):
				_spawn_crypt_contents()
			break
	p.health = clampi(int(d.get("health", p.max_health)), 1, p.max_health)
	p.moontea_charges = int(d.get("tea", 3))
	p.focus = clampf(float(d.get("focus", float(p.focus_max))), 0.0, float(p.focus_max))
	p._validate_build()
	moonseeds = d.get("seeds", [])
	defeated_bosses = d.get("bosses", [])
	opened_chests = d.get("chests", [])
	flags = d.get("flags", {})
	discovered_waystones = d.get("waystones", ["hearthgrove"])
	last_waystone = d.get("last_waystone", "hearthgrove")
	environment.time_of_day = float(d.get("time", 0.34))
	victory = bool(d.get("victory", false))
	achievements = d.get("achievements", {})
	var loaded_stats: Dictionary = d.get("stats", {})
	if not loaded_stats.has("fish"):
		loaded_stats["fish"] = {}
	stats = loaded_stats
	moth_active = bool(d.get("moth", false))
	if moth_active:
		_spawn_companion()
	for c in chests:
		if opened_chests.has(c["id"]):
			c["open"] = true
			(c["sprite"] as Sprite2D).frame = 1
			c["glow"].visible = false
	for b in bosses:
		if defeated_bosses.has(b.boss_id):
			b.defeated = true
			b.visible = false
			b.collision_layer = 0
			if not moonseeds.has(b.boss_id):
				_spawn_moonseed(b.home, b.boss_id)
	environment.blight = 0.0 if victory else 0.6 - moonseeds.size() * 0.12
	world.ground_material.set_shader_parameter("moonwell_power", 1.0 if victory else 0.0)
	_refresh_waystones()
	hud.set_seed_count(moonseeds.size())
	return true
