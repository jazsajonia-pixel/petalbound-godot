extends RefCounted
## Helpers that turn Ninja Adventure sprite sheets into SpriteFrames at runtime.

const DIRS := ["down", "up", "left", "right"]
const NA := "res://assets/packs/ninja_adventure/"

static var _cache: Dictionary = {}


static func tex(path: String) -> Texture2D:
	if not path.begins_with("res://"):
		path = NA + path
	if _cache.has(path):
		return _cache[path]
	var t: Texture2D = load(path)
	_cache[path] = t
	return t


static func atlas(texture: Texture2D, region: Rect2) -> AtlasTexture:
	var a := AtlasTexture.new()
	a.atlas = texture
	a.region = region
	return a


## Sheet where every column is a facing (down, up, left, right) and rows are frames.
static func add_directional(frames: SpriteFrames, base: String, texture: Texture2D, cell: Vector2i, fps: float, loop: bool, dirs: Array = DIRS) -> void:
	var cols := texture.get_width() / cell.x
	var rows := texture.get_height() / cell.y
	for c in range(mini(cols, dirs.size())):
		var anim := "%s_%s" % [base, dirs[c]]
		if frames.has_animation(anim):
			frames.remove_animation(anim)
		frames.add_animation(anim)
		frames.set_animation_speed(anim, fps)
		frames.set_animation_loop(anim, loop)
		for r in range(rows):
			frames.add_frame(anim, atlas(texture, Rect2(c * cell.x, r * cell.y, cell.x, cell.y)))


## Horizontal strip of equally sized frames.
static func add_strip(frames: SpriteFrames, anim: String, texture: Texture2D, frame_w: int, fps: float, loop: bool, frame_h: int = -1) -> void:
	if frames.has_animation(anim):
		frames.remove_animation(anim)
	frames.add_animation(anim)
	frames.set_animation_speed(anim, fps)
	frames.set_animation_loop(anim, loop)
	var h := texture.get_height() if frame_h <= 0 else frame_h
	var count := texture.get_width() / frame_w
	for i in range(count):
		frames.add_frame(anim, atlas(texture, Rect2(i * frame_w, 0, frame_w, h)))


static func strip_frames(path: String, frame_w: int, fps: float = 14.0, loop: bool = false) -> SpriteFrames:
	var key := "strip:%s:%d:%s:%s" % [path, frame_w, fps, loop]
	if _cache.has(key):
		return _cache[key]
	var f := SpriteFrames.new()
	f.remove_animation("default")
	add_strip(f, "play", tex(path), frame_w, fps, loop)
	_cache[key] = f
	return f


static func dir_name(v: Vector2) -> String:
	if absf(v.x) > absf(v.y):
		return "right" if v.x > 0.0 else "left"
	return "down" if v.y >= 0.0 else "up"


static func dir_vector(name: String) -> Vector2:
	match name:
		"up":
			return Vector2.UP
		"left":
			return Vector2.LEFT
		"right":
			return Vector2.RIGHT
	return Vector2.DOWN
