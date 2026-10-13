extends RefCounted
## Mallow's appearance: character-creation choices plus the colour layers worn
## gear paints onto the sprite. Purely cosmetic - no gameplay stats live here.
##
## The 16px Ninja Adventure rig has no modular meshes, so visible equipment is a
## per-region colour layer (head, chest, arms/hands, legs, feet) selected by a
## region mask that matches each sprite sheet, plus real weapon sprites held in
## the hands (see player.refresh_held_weapon). Cloaks, charms, rings and relics
## have no visible layer on this rig.

const HERO := "res://assets/packs/ninja_adventure/hero/"
const SHEETS := ["idle", "walk", "attack", "hit", "item", "jump", "pickup", "push", "roll", "swim", "dead"]
const REGIONS := ["head", "armor", "arms", "legs", "boots"]  # equipment slot per mask region 1..5

const OPTIONS := {
	"fur": {"label": "Fur", "values": [
		["cream", "Cream", "ffe7d6"], ["rose", "Rose", "f7c9c0"], ["honey", "Honey", "e9b98c"],
		["cocoa", "Cocoa", "b98463"], ["moon", "Moon", "dcd6f2"]]},
	"hood": {"label": "Hood", "values": [
		["petal", "Petal", "f08aa8"], ["lilac", "Lilac", "c39af0"], ["sky", "Sky", "8cc8f2"],
		["moss", "Moss", "9fd27a"], ["gold", "Gold", "f2cd6a"], ["snow", "Snow", "eef0f6"]]},
	"outfit": {"label": "Outfit", "values": [
		["plum", "Plum", "7a4f95"], ["forest", "Forest", "4f8a5a"], ["ocean", "Ocean", "4a6fae"],
		["ember", "Ember", "b0533f"], ["slate", "Slate", "5d6478"], ["sand", "Sand", "a8875a"]]},
	"accent": {"label": "Eyes & band", "values": [
		["gold", "Gold", "ffd27a"], ["mint", "Mint", "9ef0c4"], ["coral", "Coral", "ff9a8a"], ["ice", "Ice", "bfe6ff"]]},
}
const PRESETS := [
	{"name": "Rose wanderer", "fur": "cream", "hood": "petal", "outfit": "plum", "accent": "gold"},
	{"name": "Moss scout", "fur": "honey", "hood": "moss", "outfit": "forest", "accent": "mint"},
	{"name": "Tide runner", "fur": "moon", "hood": "sky", "outfit": "ocean", "accent": "ice"},
	{"name": "Ember kit", "fur": "cocoa", "hood": "gold", "outfit": "ember", "accent": "coral"},
]

static var _masks := {}


static func default_appearance() -> Dictionary:
	var p: Dictionary = PRESETS[0]
	return {"fur": p["fur"], "hood": p["hood"], "outfit": p["outfit"], "accent": p["accent"]}


static func sanitize(a) -> Dictionary:
	var out := default_appearance()
	if typeof(a) != TYPE_DICTIONARY:
		return out
	for k in OPTIONS.keys():
		var v := String(a.get(k, ""))
		for opt in OPTIONS[k]["values"]:
			if opt[0] == v:
				out[k] = v
	return out


static func color_of(category: String, value: String) -> Color:
	for opt in OPTIONS[category]["values"]:
		if opt[0] == value:
			return Color(String(opt[2]))
	return Color(String(OPTIONS[category]["values"][0][2]))


static func label_of(category: String, value: String) -> String:
	for opt in OPTIONS[category]["values"]:
		if opt[0] == value:
			return String(opt[1])
	return value


static func cycle(a: Dictionary, category: String, step: int) -> Dictionary:
	var vals: Array = OPTIONS[category]["values"]
	var i := 0
	for j in range(vals.size()):
		if vals[j][0] == a.get(category, ""):
			i = j
	var out := a.duplicate()
	out[category] = vals[(i + step + vals.size()) % vals.size()][0]
	return out


static func mask_for(sheet: String) -> Texture2D:
	if not _masks.has(sheet):
		var path := HERO + "masks/" + sheet + "_mask.png"
		_masks[sheet] = load(path) if ResourceLoader.exists(path) else null
	return _masks[sheet]


static func sheet_of(anim: String) -> String:
	var base := anim.split("_")[0]
	return base if base in SHEETS else "idle"


static func shades(c: Color) -> Array:
	return [c.lightened(0.18), c, c.darkened(0.38)]


## Colours for the five mask regions. Worn visible gear (item "look") replaces
## the appearance colours of its region; everything else shows the chosen look.
static func region_colors(appearance: Dictionary, equipped: Dictionary, items: Dictionary) -> Dictionary:
	var a := sanitize(appearance)
	var hood := color_of("hood", a["hood"])
	var outfit := color_of("outfit", a["outfit"])
	var skin := color_of("fur", a["fur"])
	var o := shades(outfit)
	var base := [hood, o[1], o[2]]
	var cols := PackedColorArray()
	var glow := PackedFloat32Array()
	var worn := {}
	for r in range(REGIONS.size()):
		var slot: String = REGIONS[r]
		var lc: Array = base.duplicate()
		var extra := skin
		if slot == "boots":
			extra = skin
		var g := 0.0
		var id: String = equipped.get(slot, "")
		if id != "" and items.has(id) and items[id].has("look"):
			var look: Array = items[id]["look"]
			lc = [Color(String(look[0])), Color(String(look[1])), Color(String(look[2]))]
			extra = lc[0] if slot == "arms" else lc[1]
			worn[slot] = id
			match String(items[id].get("rarity", "common")):
				"legendary":
					g = 1.0
				"epic":
					g = 0.55
		for c in lc:
			cols.append(c)
		cols.append(extra)
		glow.append(g)
	return {"cols": cols, "glow": glow, "skin": skin, "accent": color_of("accent", a["accent"]), "worn": worn}


static func apply(mat: ShaderMaterial, appearance: Dictionary, equipped: Dictionary, items: Dictionary) -> Dictionary:
	var rc := region_colors(appearance, equipped, items)
	mat.set_shader_parameter("use_mask", true)
	mat.set_shader_parameter("region_cols", rc["cols"])
	mat.set_shader_parameter("region_glow", rc["glow"])
	mat.set_shader_parameter("skin_color", rc["skin"])
	mat.set_shader_parameter("accent_color", rc["accent"])
	return rc
