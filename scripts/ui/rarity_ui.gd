extends RefCounted
## One consistent rarity treatment for every item surface (satchel, shop,
## crafting, loot feed, reward banner): frame border + background tint,
## a gentle pulse for Epic and a pulse + sparkle for Legendary, and coloured
## names. Rarity also matters in play: higher tiers carry more bonuses or a
## unique effect, sell for more and need rarer materials to craft.

const DB := preload("res://scripts/data/db.gd")
const AnimLib := preload("res://scripts/core/anim_lib.gd")

const STYLE := {
	"common": {"border": Color("9a93a6"), "bg": Color(0.13, 0.11, 0.17), "width": 1, "glow": 0.0},
	"uncommon": {"border": Color("86dd8f"), "bg": Color(0.10, 0.17, 0.13), "width": 1, "glow": 0.0},
	"rare": {"border": Color("72b6ff"), "bg": Color(0.09, 0.13, 0.22), "width": 1, "glow": 0.0},
	"epic": {"border": Color("cc93ff"), "bg": Color(0.16, 0.09, 0.24), "width": 2, "glow": 0.5},
	"legendary": {"border": Color("ffcc5c"), "bg": Color(0.22, 0.15, 0.06), "width": 2, "glow": 1.0},
	# Mythical: crimson-gold frame, colour cycling border, orbiting sparks (never a random drop)
	"mythical": {"border": Color("ff7066"), "bg": Color(0.24, 0.07, 0.10), "width": 2, "glow": 1.4},
}


static func rarity_of(id: String) -> String:
	var r := String(DB.ITEMS.get(id, {}).get("rarity", "common"))
	return r if STYLE.has(r) else "common"


static func color(id: String) -> Color:
	return STYLE[rarity_of(id)]["border"]


static func name_of(id: String) -> String:
	return String(DB.RARITY_NAMES.get(rarity_of(id), "Common"))


static func category_of(id: String) -> String:
	var it: Dictionary = DB.ITEMS.get(id, {})
	var t := String(it.get("type", ""))
	if t == "weapon":
		return String(it.get("wclass", "Weapon"))
	if DB.SLOT_NAMES.has(t):
		return String(DB.SLOT_NAMES[t])
	return {"material": "Material", "consumable": "Consumable", "quest": "Quest item", "tool": "Tool", "upgrade": "Upgrade",
		"flask_up": "Flask upgrade", "key": "Key item"}.get(t, t.capitalize())


static func box(id: String, selected := false, dim := false) -> StyleBoxFlat:
	var st: Dictionary = STYLE[rarity_of(id)]
	var s := StyleBoxFlat.new()
	s.bg_color = st["bg"]
	s.border_color = st["border"] if not dim else Color(0.9, 0.45, 0.45)
	s.set_border_width_all(int(st["width"]) + (1 if selected else 0))
	s.set_corner_radius_all(3)
	s.content_margin_left = 2
	s.content_margin_right = 2
	s.content_margin_top = 2
	s.content_margin_bottom = 2
	return s


## A framed item icon. `count` > 1 shows a stack number.
static func icon(id: String, size: float, parent: Control, selected := false, dim := false, count := 0) -> Control:
	var it: Dictionary = DB.ITEMS.get(id, {})
	var f := RarityFrame.new()
	f.rarity = rarity_of(id)
	f.custom_minimum_size = Vector2(size, size)
	f.add_theme_stylebox_override("panel", box(id, selected, dim))
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t := TextureRect.new()
	t.texture = AnimLib.tex(String(it.get("icon", "ui/skill/scroll.png")))
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if it.has("tint"):
		t.modulate = Color(String(it["tint"]))
	if dim:
		t.modulate = t.modulate * Color(0.8, 0.65, 0.7)
	f.add_child(t)
	if count > 1:
		var l := Label.new()
		l.text = str(count)
		l.add_theme_font_size_override("font_size", 7)
		l.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.08))
		l.add_theme_constant_override("outline_size", 3)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		f.add_child(l)
	if parent != null:
		parent.add_child(f)
	return f


## Pulsing border for Epic/Legendary frames; Legendary also twinkles.
class RarityFrame extends PanelContainer:
	var rarity := "common"
	var _t := 0.0

	func _ready() -> void:
		set_process(rarity in ["epic", "legendary", "mythical"])

	func _process(delta: float) -> void:
		_t += delta
		var sb := get_theme_stylebox("panel") as StyleBoxFlat
		if sb:
			var base: Color = STYLE[rarity]["border"]
			sb.border_color = base.lerp(Color.WHITE, 0.25 + 0.25 * sin(_t * 3.0))
			if rarity == "mythical":
				sb.border_color = Color("ff6a5c").lerp(Color("ffd24a"), 0.5 + 0.5 * sin(_t * 2.4))
		if rarity == "legendary" or rarity == "mythical":
			queue_redraw()

	func _draw() -> void:
		if rarity == "mythical":
			# two sparks orbiting the frame edge + a corner flare
			var sz := size
			var per := 2.0 * (sz.x + sz.y)
			for i in range(2):
				var d := fmod(_t * 28.0 + per * 0.5 * i, per)
				var q := Vector2(d, 1) if d < sz.x else (Vector2(sz.x - 1, d - sz.x) if d < sz.x + sz.y else (Vector2(sz.x - (d - sz.x - sz.y), sz.y - 1) if d < 2.0 * sz.x + sz.y else Vector2(1, sz.y - (d - 2.0 * sz.x - sz.y))))
				draw_circle(q, 1.4, Color(1, 0.92, 0.6, 0.95))
				draw_circle(q, 2.6, Color(1, 0.5, 0.4, 0.35))
			return
		if rarity != "legendary":
			return
		var s := size
		for i in range(2):
			var ph := fmod(_t * 0.6 + i * 0.5, 1.0)
			var p := Vector2(s.x * ph, s.y * (0.15 + 0.7 * fmod(ph * 1.7 + i * 0.3, 1.0)))
			var a := sin(ph * PI)
			draw_line(p - Vector2(1.5, 0), p + Vector2(1.5, 0), Color(1, 0.95, 0.7, a), 1.0)
			draw_line(p - Vector2(0, 1.5), p + Vector2(0, 1.5), Color(1, 0.95, 0.7, a), 1.0)
