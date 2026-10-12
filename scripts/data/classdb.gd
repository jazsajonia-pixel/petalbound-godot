extends RefCounted
## Petal Arts: seven class lines inspired by Albion Online's weapon lines.
## Bind a primary line, combine with one secondary line at level 5+, and grow
## each line through a small destiny-style tree bought with level points.

const NA := "res://assets/packs/ninja_adventure/"

## Active arts. "exec" maps to an archetype implemented in player.cast_skill().
const SKILLS := {
	"bulwark": {"name": "Bulwark", "icon": NA + "ui/skill/guard.png", "cost": 16, "cd": 14.0,
		"desc": "Root your feet: +2 defense for 6s and a heartbeat of invulnerability.",
		"exec": "buff", "buff": "bulwark", "time": 6.0, "invuln": 0.8, "fx": "aura", "tint": "9fc4ff"},
	"sunder": {"name": "Sunder", "icon": NA + "items/weapons/katana.png", "cost": 12, "cd": 6.0,
		"desc": "A heavy overhead cut that cracks armour.",
		"exec": "strike", "dmg": 4, "knock": 130.0, "radius": 26.0, "fx": "slash_double", "tint": "ffd9f2"},
	"hundred_fists": {"name": "Hundred Fists", "icon": NA + "ui/skill/punch.png", "cost": 18, "cd": 8.0,
		"desc": "Three lightning jabs in one breath.",
		"exec": "flurry", "dmg": 2, "hits": 3, "tint": "ffd2a8"},
	"haymaker": {"name": "Haymaker", "icon": NA + "items/weapons/hammer.png", "cost": 16, "cd": 10.0,
		"desc": "A wide, staggering swing with everything behind it.",
		"exec": "strike", "dmg": 5, "knock": 160.0, "radius": 28.0, "fx": "explosion", "tint": "ffc9a8"},
	"shadowstep": {"name": "Shadowstep", "icon": NA + "ui/skill/boot.png", "cost": 14, "cd": 9.0,
		"desc": "Blink through shadow; your next strike within 2.5s is a guaranteed critical.",
		"exec": "blink", "dist": 88.0, "buff": "shadow", "time": 2.5, "tint": "c9b8ff"},
	"fan_knives": {"name": "Fan of Knives", "icon": NA + "items/weapons/katana.png", "cost": 16, "cd": 7.0,
		"desc": "Three whistling knives in a spreading fan.",
		"exec": "volley", "dmg": 2, "count": 3, "spread": 0.30, "speed": 240.0, "kind": "arrow", "homing": 0.0, "tint": "e8d2ff"},
	"frost_lance": {"name": "Frost Lance", "icon": NA + "items/weapons/magicwand.png", "cost": 12, "cd": 5.0,
		"desc": "A piercing shard of moonfrost.",
		"exec": "pierce", "dmg": 3, "kind": "ice_spike", "speed": 300.0, "tint": "bfe8ff"},
	"starfall": {"name": "Starfall", "icon": NA + "items/weapons/magicwand.png", "cost": 22, "cd": 9.0,
		"desc": "Call a star down onto the ground ahead.",
		"exec": "burst_point", "dmg": 4, "radius": 30.0, "delay": 0.25, "dist": 64.0, "tint": "ffe9a8"},
	"grave_bolt": {"name": "Grave Bolt", "icon": NA + "items/weapons/lance.png", "cost": 14, "cd": 6.0,
		"desc": "A bolt of grave-light that pierces everything in its path.",
		"exec": "pierce", "dmg": 3, "kind": "fireball", "speed": 210.0, "tint": "b8ffd8"},
	"soul_harvest": {"name": "Soul Harvest", "icon": NA + "items/weapons/lance.png", "cost": 20, "cd": 12.0,
		"desc": "Reap nearby life and drink it back: heals 2 per enemy struck.",
		"exec": "vamp", "dmg": 2, "radius": 46.0, "heal": 2, "knock": 60.0, "tint": "c8ffbf"},
	"gale_volley": {"name": "Gale Volley", "icon": NA + "items/weapons/bow.png", "cost": 14, "cd": 6.0,
		"desc": "Three seeking arrows, loosed a heartbeat apart.",
		"exec": "volley", "dmg": 2, "count": 3, "spread": 0.12, "speed": 320.0, "kind": "arrow", "homing": 2.0, "tint": "bfe8d8"},
	"hunt_mark": {"name": "Hunter's Mark", "icon": NA + "ui/skill/arrow.png", "cost": 12, "cd": 14.0,
		"desc": "Read the wind: +30% critical chance for 8s.",
		"exec": "buff", "buff": "marked", "time": 8.0, "crit": 0.30, "fx": "spark_circle", "tint": "ffe2a8"},
	"mend": {"name": "Petal Mend", "icon": NA + "ui/skill/amulet.png", "cost": 22, "cd": 9.0,
		"desc": "Close your wounds with a fall of soft petals: restore two hearts.",
		"exec": "heal", "heal": 8.0, "tint": "9cf5a5"},
	"sanctuary": {"name": "Sanctuary", "icon": NA + "ui/skill/amulet.png", "cost": 20, "cd": 14.0,
		"desc": "A ring of light repels everything near you and shields you for a moment.",
		"exec": "aoe", "dmg": 2, "radius": 48.0, "knock": 150.0, "invuln": 0.8, "tint": "fff0c8"},
}

## The seven class lines. "tree" nodes cost one point; "needs" lists prerequisites.
const CLASSES := {
	"warden": {
		"name": "Warden", "title": "wall of the grove", "icon": NA + "ui/skill/armor.png", "color": Color(0.62, 0.77, 1.0),
		"desc": "Steadfast sword-line. Heavy cuts and an unbreakable guard.",
		"skills": ["bulwark", "sunder"],
		"tree": {
			"oakheart": {"name": "Oakheart", "desc": "+1 heart.", "effect": {"hearts": 1}},
			"ironbark": {"name": "Ironbark", "desc": "+1 defense.", "needs": ["oakheart"], "effect": {"defense": 1}},
			"sunder_edge": {"name": "Sunder Edge", "desc": "+1 attack damage.", "needs": ["oakheart"], "effect": {"atk": 1}},
			"bulwark_master": {"name": "Bulwark Master", "desc": "+2 focus and arts cool 10% faster.", "needs": ["ironbark"], "effect": {"focus": 2, "cd": 0.10}},
		},
	},
	"pugilist": {
		"name": "Pugilist", "title": "the hundred hands", "icon": NA + "ui/skill/punch.png", "color": Color(1.0, 0.80, 0.55),
		"desc": "Bare-knuckle fighter line. Flurries and crushing blows.",
		"skills": ["hundred_fists", "haymaker"],
		"tree": {
			"knuckle_oil": {"name": "Knuckle Oil", "desc": "+1 attack damage.", "effect": {"atk": 1}},
			"roll_with_it": {"name": "Roll With It", "desc": "+5% move speed.", "needs": ["knuckle_oil"], "effect": {"speed": 0.05}},
			"wind_up": {"name": "Wind Up", "desc": "+5% critical chance.", "needs": ["knuckle_oil"], "effect": {"crit": 0.05}},
			"iron_jaw": {"name": "Iron Jaw", "desc": "+1 heart, +1 defense.", "needs": ["roll_with_it"], "effect": {"hearts": 1, "defense": 1}},
		},
	},
	"nightbloom": {
		"name": "Nightbloom", "title": "petal in the dark", "icon": NA + "items/weapons/katana.png", "color": Color(0.78, 0.62, 1.0),
		"desc": "Assassin line. Blinks, knives and guaranteed crits.",
		"skills": ["shadowstep", "fan_knives"],
		"tree": {
			"nightveil": {"name": "Nightveil", "desc": "+5% critical chance.", "effect": {"crit": 0.05}},
			"quiet_step": {"name": "Quiet Step", "desc": "+6% move speed.", "needs": ["nightveil"], "effect": {"speed": 0.06}},
			"deep_cut": {"name": "Deep Cut", "desc": "+1 attack damage.", "needs": ["nightveil"], "effect": {"atk": 1}},
			"veilwalker": {"name": "Veilwalker", "desc": "+6 focus, Shadowstep blinks farther.", "needs": ["quiet_step"], "effect": {"focus": 6}},
		},
	},
	"lumimancer": {
		"name": "Lumimancer", "title": "keeper of moonlight", "icon": NA + "items/weapons/magicwand.png", "color": Color(0.65, 0.85, 1.0),
		"desc": "Mage line. Frost lances and falling stars.",
		"skills": ["frost_lance", "starfall"],
		"tree": {
			"moonglass": {"name": "Moonglass", "desc": "+8 focus.", "effect": {"focus": 8}},
			"cold_read": {"name": "Cold Read", "desc": "+5% critical chance.", "needs": ["moonglass"], "effect": {"crit": 0.05}},
			"star_charts": {"name": "Star Charts", "desc": "+1 attack damage.", "needs": ["moonglass"], "effect": {"atk": 1}},
			"wellspring": {"name": "Wellspring", "desc": "+2 focus and arts cool 10% faster.", "needs": ["star_charts"], "effect": {"focus": 2, "cd": 0.10}},
		},
	},
	"gravetender": {
		"name": "Gravetender", "title": "friend of the quiet", "icon": NA + "items/weapons/lance.png", "color": Color(0.72, 1.0, 0.78),
		"desc": "Necromancer line. Grave bolts and stolen life.",
		"skills": ["grave_bolt", "soul_harvest"],
		"tree": {
			"bone_charm": {"name": "Bone Charm", "desc": "+1 heart.", "effect": {"hearts": 1}},
			"long_reach": {"name": "Long Reach", "desc": "+1 attack damage.", "needs": ["bone_charm"], "effect": {"atk": 1}},
			"grave_dirt": {"name": "Grave Dirt", "desc": "+1 defense.", "needs": ["bone_charm"], "effect": {"defense": 1}},
			"second_breath": {"name": "Second Breath", "desc": "+6 focus, Soul Harvest heals +1.", "needs": ["grave_dirt"], "effect": {"focus": 6}},
		},
	},
	"windrunner": {
		"name": "Windrunner", "title": "voice on the wind", "icon": NA + "items/weapons/bow.png", "color": Color(0.62, 0.95, 0.78),
		"desc": "Ranger line. Seeking volleys and perfect marks.",
		"skills": ["gale_volley", "hunt_mark"],
		"tree": {
			"swift_quiver": {"name": "Swift Quiver", "desc": "+6% move speed.", "effect": {"speed": 0.06}},
			"hawk_eye": {"name": "Hawk Eye", "desc": "+5% critical chance.", "needs": ["swift_quiver"], "effect": {"crit": 0.05}},
			"strong_arms": {"name": "Strong Arms", "desc": "+1 attack damage.", "needs": ["swift_quiver"], "effect": {"atk": 1}},
			"tailwind": {"name": "Tailwind", "desc": "+2 focus and arts cool 10% faster.", "needs": ["hawk_eye"], "effect": {"focus": 2, "cd": 0.10}},
		},
	},
	"petalweaver": {
		"name": "Petalweaver", "title": "mender of petals", "icon": NA + "ui/skill/amulet.png", "color": Color(1.0, 0.78, 0.88),
		"desc": "Cleric line. Healing petals and rings of sanctuary.",
		"skills": ["mend", "sanctuary"],
		"tree": {
			"soft_hands": {"name": "Soft Hands", "desc": "+1 heart.", "effect": {"hearts": 1}},
			"patient_loom": {"name": "Patient Loom", "desc": "+8 focus.", "needs": ["soft_hands"], "effect": {"focus": 8}},
			"thorn_litany": {"name": "Thorn Litany", "desc": "+1 attack damage.", "needs": ["soft_hands"], "effect": {"atk": 1}},
			"deep_roots": {"name": "Deep Roots", "desc": "+1 heart, +1 defense.", "needs": ["patient_loom"], "effect": {"hearts": 1, "defense": 1}},
		},
	},
}

const MAX_CLASSES := 2
const COMBINE_LEVEL := 5
const LEVEL_CAP := 20


static func skill_of(id: String) -> Dictionary:
	return SKILLS.get(id, {})


static func class_of(id: String) -> Dictionary:
	return CLASSES.get(id, {})


static func xp_needed(level: int) -> int:
	return 24 + level * 16
