extends RefCounted
## Petal Arts: seven class lines inspired by Albion Online's weapon lines.
## Bind a primary line, combine with one secondary line at level 5+, and grow
## each line through a small destiny-style tree bought with level points.
##
## Combat overhaul: every line now carries three arts (the third unlocks at line
## rank 3), arts have an element, an activation type ("tap", "direction" or
## "point"), a real range used by the aim indicator, and three upgrade levels.
## Lines grant rank-scaled attributes (primary at full strength, secondary at
## half) and hand out their signature gear as the line ranks up.

const NA := "res://assets/packs/ninja_adventure/"

## Innate arts every wanderer may slot, whatever their lines.
const WANDERER_SKILLS := ["mothlight", "petalguard", "moonstep", "seedling", "thorn_snare"]

## Active arts. "exec" maps to an archetype implemented in player.cast_skill().
## aim: "tap" (instant, auto-targets), "direction" (arrow), "point" (ground circle).
## unlock: line rank needed (rank = 1 + tree nodes learned in that line).
## dmg_step: extra damage per upgrade level; cd and cost scale in Build.skill_stat().
const SKILLS := {
	"mothlight": {"name": "Mothlight", "icon": NA + "ui/skill/scroll.png", "cost": 0, "cd": 6.0, "class": "",
		"desc": "A burst of moth-glow that scorches everything around you.",
		"exec": "mothlight", "aim": "tap", "dmg": 3, "radius": 72.0, "element": "arcane", "tint": "ffb8d8", "unlock": 1},
		"petalguard": {"name": "Petalguard", "icon": NA + "ui/skill/guard.png", "cost": 0, "cd": 10.0, "class": "",
			"desc": "A petal shield that swallows the next hit within 5s.",
			"exec": "petalguard", "aim": "tap", "tint": "ffd0f0", "unlock": 1, "dmg_step": 0},
		"moonstep": {"name": "Moonstep", "icon": "res://assets/generated/petalbound/icons/moonstep.png", "cost": 8, "cd": 8.0, "class": "",
			"desc": "Slip a short distance through moonlight and gain a brief window of safety.",
			"exec": "blink", "aim": "direction", "range": 64.0, "dist": 64.0, "buff": "moonstep", "time": 1.2, "tint": "d9c5ff", "unlock": 1, "dmg_step": 0},
		"seedling": {"name": "Seedling Ward", "icon": "res://assets/generated/petalbound/icons/seedling.png", "cost": 12, "cd": 14.0, "class": "",
			"desc": "Plant a soft-glowing seed at your feet; the little ward restores health while you stand nearby.",
			"exec": "heal_zone", "aim": "tap", "radius": 30.0, "time": 4.2, "heal": 1, "tint": "b7f1af", "zone_style": "seed", "unlock": 1, "dmg_step": 0},
		"thorn_snare": {"name": "Thorn Snare", "icon": "res://assets/generated/petalbound/icons/thorn_snare.png", "cost": 15, "cd": 12.0, "class": "",
			"desc": "Mark a patch of ground; thorny roots lash foes caught inside.",
			"exec": "cloud", "aim": "point", "range": 105.0, "radius": 28.0, "time": 3.0, "dmg": 2, "tint": "c7e587", "zone_style": "roots", "element": "poison", "status": {"poison": 1}, "unlock": 1},
		"bulwark": {"name": "Bulwark", "icon": NA + "ui/skill/armor.png", "cost": 16, "cd": 14.0, "class": "warden",
		"desc": "Root your feet: +2 defense for 6s and a heartbeat of invulnerability.",
		"exec": "buff", "aim": "tap", "buff": "bulwark", "time": 6.0, "invuln": 0.8, "fx": "aura", "tint": "9fc4ff", "unlock": 1, "dmg_step": 0},
	"sunder": {"name": "Sunder", "icon": NA + "items/weapons/bigsword.png", "cost": 12, "cd": 6.0, "class": "warden",
		"desc": "A heavy overhead cut that cracks armour: struck foes take +20% damage for 4s.",
		"exec": "strike", "aim": "tap", "dmg": 4, "knock": 130.0, "radius": 26.0, "fx": "slash_double", "tint": "ffd9f2",
		"status": {"expose": 1}, "unlock": 1},
	"iron_charge": {"name": "Iron Charge", "icon": NA + "ui/skill/armor.png", "cost": 18, "cd": 9.0, "class": "warden",
		"desc": "Shoulder-charge along a line, battering and staggering everything in the way.",
		"exec": "charge", "aim": "direction", "range": 80.0, "dmg": 4, "radius": 16.0, "knock": 150.0, "tint": "b8d4ff", "unlock": 3},
	"hundred_fists": {"name": "Hundred Fists", "icon": NA + "ui/skill/punch.png", "cost": 18, "cd": 8.0, "class": "pugilist",
		"desc": "Three lightning jabs in one breath.",
		"exec": "flurry", "aim": "tap", "dmg": 2, "hits": 3, "tint": "ffd2a8", "unlock": 1},
	"haymaker": {"name": "Haymaker", "icon": NA + "items/weapons/hammer.png", "cost": 16, "cd": 10.0, "class": "pugilist",
		"desc": "A wide, staggering swing with everything behind it.",
		"exec": "strike", "aim": "tap", "dmg": 5, "knock": 160.0, "radius": 28.0, "fx": "explosion", "tint": "ffc9a8", "unlock": 1},
		"thunder_palm": {"name": "Thunder Palm", "icon": "res://assets/generated/petalbound/icons/thunder_palm.png", "cost": 16, "cd": 7.0, "class": "pugilist",
		"desc": "A crackling palm strike; lightning arcs to two more foes and stuns briefly.",
		"exec": "strike", "aim": "tap", "dmg": 3, "knock": 90.0, "radius": 22.0, "fx": "thunder", "tint": "fff2a0",
		"element": "lightning", "chain": 2, "unlock": 3},
	"shadowstep": {"name": "Shadowstep", "icon": NA + "ui/skill/boot.png", "cost": 14, "cd": 9.0, "class": "nightbloom",
		"desc": "Blink through shadow; your next strike within 2.5s is a guaranteed critical.",
		"exec": "blink", "aim": "direction", "range": 88.0, "dist": 88.0, "buff": "shadow", "time": 2.5, "tint": "c9b8ff", "unlock": 1, "dmg_step": 0},
	"fan_knives": {"name": "Fan of Knives", "icon": NA + "items/weapons/sai.png", "cost": 16, "cd": 7.0, "class": "nightbloom",
		"desc": "Three whistling knives in a spreading fan. Each one poisons.",
		"exec": "volley", "aim": "direction", "range": 160.0, "dmg": 2, "count": 3, "spread": 0.30, "speed": 240.0, "kind": "arrow", "homing": 0.0,
		"tint": "e8d2ff", "element": "poison", "status": {"poison": 1}, "unlock": 1},
	"toxic_veil": {"name": "Toxic Veil", "icon": NA + "items/gemgreen.png", "cost": 18, "cd": 11.0, "class": "nightbloom",
		"desc": "Throw a cloud of night-venom: foes inside gain poison every half second for 3s.",
		"exec": "cloud", "aim": "point", "range": 110.0, "radius": 30.0, "time": 3.0, "dmg": 1, "tint": "9cf08a",
		"element": "poison", "status": {"poison": 1}, "unlock": 3},
	"frost_lance": {"name": "Frost Lance", "icon": NA + "items/weapons/magicwand.png", "cost": 12, "cd": 5.0, "class": "lumimancer",
		"desc": "A piercing shard of moonfrost. Chills; three chills freeze.",
		"exec": "pierce", "aim": "direction", "range": 200.0, "dmg": 3, "kind": "ice_spike", "speed": 300.0, "tint": "bfe8ff",
		"element": "ice", "status": {"chill": 1}, "unlock": 1},
	"starfall": {"name": "Starfall", "icon": NA + "items/gemyellow.png", "cost": 22, "cd": 9.0, "class": "lumimancer",
		"desc": "Call an arcane star down onto the ground you choose.",
		"exec": "burst_point", "aim": "point", "range": 120.0, "dmg": 4, "radius": 30.0, "delay": 0.35, "dist": 64.0, "tint": "ffe9a8",
		"element": "arcane", "unlock": 1},
		"chain_lightning": {"name": "Chain Lightning", "icon": "res://assets/generated/petalbound/icons/chain_lightning.png", "cost": 20, "cd": 8.0, "class": "lumimancer",
		"desc": "Lightning leaps to your target and on to three more, stunning each.",
		"exec": "chain", "aim": "tap", "range": 130.0, "dmg": 4, "chain": 3, "tint": "fff6a8", "element": "lightning", "unlock": 3},
	"grave_bolt": {"name": "Grave Bolt", "icon": NA + "items/weapons/lance.png", "cost": 14, "cd": 6.0, "class": "gravetender",
		"desc": "A bolt of grave-light that pierces everything in its path and curses it.",
		"exec": "pierce", "aim": "direction", "range": 180.0, "dmg": 3, "kind": "fireball", "speed": 210.0, "tint": "b8ffd8",
		"element": "necrotic", "status": {"curse": 1}, "unlock": 1},
	"soul_harvest": {"name": "Soul Harvest", "icon": NA + "items/gempurple.png", "cost": 20, "cd": 12.0, "class": "gravetender",
		"desc": "Reap nearby life and drink it back: heals 2 per enemy struck.",
		"exec": "vamp", "aim": "tap", "dmg": 2, "radius": 46.0, "heal": 2, "knock": 60.0, "tint": "c8ffbf", "element": "necrotic", "unlock": 1},
	"bone_thrall": {"name": "Bone Thrall", "icon": NA + "monsters/skull_face.png", "cost": 22, "cd": 16.0, "class": "gravetender",
		"desc": "Raise a grave-wisp for 10s that hunts your foes with necrotic bites.",
		"exec": "summon", "aim": "tap", "dmg": 2, "time": 10.0, "tint": "a8ffcf", "element": "necrotic", "unlock": 3},
	"gale_volley": {"name": "Gale Volley", "icon": NA + "items/weapons/bow.png", "cost": 14, "cd": 6.0, "class": "windrunner",
		"desc": "Three seeking arrows, loosed a heartbeat apart.",
		"exec": "volley", "aim": "direction", "range": 220.0, "dmg": 2, "count": 3, "spread": 0.12, "speed": 320.0, "kind": "arrow", "homing": 2.0, "tint": "bfe8d8", "unlock": 1},
	"hunt_mark": {"name": "Hunter's Mark", "icon": NA + "ui/skill/arrow.png", "cost": 12, "cd": 14.0, "class": "windrunner",
		"desc": "Read the wind: +30% critical chance for 8s.",
		"exec": "buff", "aim": "tap", "buff": "marked", "time": 8.0, "crit": 0.30, "fx": "spark_circle", "tint": "ffe2a8", "unlock": 1, "dmg_step": 0},
	"ember_rain": {"name": "Ember Rain", "icon": NA + "items/weapons/bow_arrow.png", "cost": 20, "cd": 10.0, "class": "windrunner",
		"desc": "Three volleys of burning arrows fall on the ground you mark. Burns.",
		"exec": "rain", "aim": "point", "range": 140.0, "radius": 32.0, "dmg": 2, "waves": 3, "tint": "ffb070",
		"element": "fire", "status": {"burn": 1}, "unlock": 3},
	"mend": {"name": "Petal Mend", "icon": NA + "ui/skill/amulet.png", "cost": 22, "cd": 9.0, "class": "petalweaver",
		"desc": "Close your wounds with a fall of soft petals: restore two hearts.",
		"exec": "heal", "aim": "tap", "heal": 8.0, "tint": "9cf5a5", "unlock": 1, "dmg_step": 0},
	"sanctuary": {"name": "Sanctuary", "icon": NA + "items/gemred.png", "cost": 20, "cd": 14.0, "class": "petalweaver",
		"desc": "A ring of light repels everything near you and shields you for a moment.",
		"exec": "aoe", "aim": "tap", "dmg": 2, "radius": 48.0, "knock": 150.0, "invuln": 0.8, "tint": "fff0c8", "element": "arcane", "unlock": 1},
	"bloom_ward": {"name": "Bloom Ward", "icon": NA + "items/seedbig1.png", "cost": 20, "cd": 15.0, "class": "petalweaver",
		"desc": "Plant a ring of blossoms: standing inside heals a quarter-heart every 0.6s for 4.8s.",
		"exec": "heal_zone", "aim": "point", "range": 80.0, "radius": 30.0, "time": 4.8, "heal": 1, "tint": "a8ffc0", "unlock": 3, "dmg_step": 0},
}

## The seven class lines. "tree" nodes cost one point; "needs" lists prerequisites.
## "attrs": stat -> value at line rank 1..5 (primary full, secondary half).
## "rewards": line rank -> gear granted once when that rank is reached.
const CLASSES := {
	"warden": {
		"name": "Warden", "title": "wall of the grove", "role": "warrior", "icon": NA + "ui/skill/armor.png", "color": Color(0.62, 0.77, 1.0),
		"desc": "Steadfast sword-line. Heavy cuts and an unbreakable guard.",
		"skills": ["bulwark", "sunder", "iron_charge"],
		"attrs": {"defense": [1, 1, 1, 2, 2], "hearts": [0, 0, 1, 1, 1]},
		"rewards": {2: ["oakguard_helm"]},
		"tree": {
			"oakheart": {"name": "Oakheart", "desc": "+1 heart.", "effect": {"hearts": 1}},
			"ironbark": {"name": "Ironbark", "desc": "+1 defense.", "needs": ["oakheart"], "effect": {"defense": 1}},
			"sunder_edge": {"name": "Sunder Edge", "desc": "+1 attack damage.", "needs": ["oakheart"], "effect": {"atk": 1}},
			"bulwark_master": {"name": "Bulwark Master", "desc": "+2 focus and arts cool 10% faster.", "needs": ["ironbark"], "effect": {"focus": 2, "cd": 0.10}},
		},
	},
	"pugilist": {
		"name": "Pugilist", "title": "the hundred hands", "role": "fighter", "icon": NA + "ui/skill/punch.png", "color": Color(1.0, 0.80, 0.55),
		"desc": "Bare-knuckle fighter line. Flurries, crushing blows and thunder.",
		"skills": ["hundred_fists", "haymaker", "thunder_palm"],
		"attrs": {"atk": [1, 1, 1, 2, 2], "atk_speed": [0.04, 0.05, 0.06, 0.08, 0.10]},
		"rewards": {2: ["ironknuckle_wraps"]},
		"tree": {
			"knuckle_oil": {"name": "Knuckle Oil", "desc": "+1 attack damage.", "effect": {"atk": 1}},
			"roll_with_it": {"name": "Roll With It", "desc": "+5% move speed.", "needs": ["knuckle_oil"], "effect": {"speed": 0.05}},
			"wind_up": {"name": "Wind Up", "desc": "+5% critical chance.", "needs": ["knuckle_oil"], "effect": {"crit": 0.05}},
			"iron_jaw": {"name": "Iron Jaw", "desc": "+1 heart, +1 defense.", "needs": ["roll_with_it"], "effect": {"hearts": 1, "defense": 1}},
		},
	},
	"nightbloom": {
		"name": "Nightbloom", "title": "petal in the dark", "role": "assassin", "icon": NA + "items/weapons/sai.png", "color": Color(0.78, 0.62, 1.0),
		"desc": "Assassin line. Blinks, poisoned knives and guaranteed crits.",
		"skills": ["shadowstep", "fan_knives", "toxic_veil"],
		"attrs": {"crit": [0.04, 0.05, 0.06, 0.07, 0.08], "speed": [0.03, 0.03, 0.04, 0.05, 0.06]},
		"rewards": {1: ["nightfang"], 2: ["duskweave_hood"], 4: ["gloam_lantern"]},
		"tree": {
			"nightveil": {"name": "Nightveil", "desc": "+5% critical chance.", "effect": {"crit": 0.05}},
			"quiet_step": {"name": "Quiet Step", "desc": "+6% move speed.", "needs": ["nightveil"], "effect": {"speed": 0.06}},
			"deep_cut": {"name": "Deep Cut", "desc": "+1 attack damage.", "needs": ["nightveil"], "effect": {"atk": 1}},
			"veilwalker": {"name": "Veilwalker", "desc": "+6 focus, Shadowstep blinks farther.", "needs": ["quiet_step"], "effect": {"focus": 6}},
		},
	},
	"lumimancer": {
		"name": "Lumimancer", "title": "keeper of moonlight", "role": "mage", "icon": NA + "items/weapons/magicwand.png", "color": Color(0.65, 0.85, 1.0),
		"desc": "Mage line. Frost, falling stars and chain lightning.",
		"skills": ["frost_lance", "starfall", "chain_lightning"],
		"attrs": {"focus": [6, 8, 10, 12, 15], "elem": [0.08, 0.10, 0.12, 0.15, 0.18]},
		"rewards": {1: ["moonglass_staff"], 2: ["starweave_circlet"], 4: ["stormseed"]},
		"tree": {
			"moonglass": {"name": "Moonglass", "desc": "+8 focus.", "effect": {"focus": 8}},
			"cold_read": {"name": "Cold Read", "desc": "+5% critical chance.", "needs": ["moonglass"], "effect": {"crit": 0.05}},
			"star_charts": {"name": "Star Charts", "desc": "+1 attack damage.", "needs": ["moonglass"], "effect": {"atk": 1}},
			"wellspring": {"name": "Wellspring", "desc": "+2 focus and arts cool 10% faster.", "needs": ["star_charts"], "effect": {"focus": 2, "cd": 0.10}},
		},
	},
	"gravetender": {
		"name": "Gravetender", "title": "friend of the quiet", "role": "necromancer", "icon": NA + "items/weapons/lance.png", "color": Color(0.72, 1.0, 0.78),
		"desc": "Necromancer line. Curses, stolen life and a grave-wisp thrall.",
		"skills": ["grave_bolt", "soul_harvest", "bone_thrall"],
		"attrs": {"lifesteal": [0.06, 0.07, 0.08, 0.10, 0.12], "hearts": [0, 1, 1, 1, 1]},
		"rewards": {1: ["grave_scythe"], 2: ["bonewrap_gloves"], 4: ["soul_lantern"]},
		"tree": {
			"bone_charm": {"name": "Bone Charm", "desc": "+1 heart.", "effect": {"hearts": 1}},
			"long_reach": {"name": "Long Reach", "desc": "+1 attack damage.", "needs": ["bone_charm"], "effect": {"atk": 1}},
			"grave_dirt": {"name": "Grave Dirt", "desc": "+1 defense.", "needs": ["bone_charm"], "effect": {"defense": 1}},
			"second_breath": {"name": "Second Breath", "desc": "+6 focus, Soul Harvest heals +1.", "needs": ["grave_dirt"], "effect": {"focus": 6}},
		},
	},
	"windrunner": {
		"name": "Windrunner", "title": "voice on the wind", "role": "ranger", "icon": NA + "items/weapons/bow.png", "color": Color(0.62, 0.95, 0.78),
		"desc": "Ranger line. Seeking volleys, perfect marks and ember rain.",
		"skills": ["gale_volley", "hunt_mark", "ember_rain"],
		"attrs": {"ranged_bonus": [0, 1, 1, 1, 2], "speed": [0.03, 0.04, 0.04, 0.05, 0.06]},
		"rewards": {2: ["galestride_leggings"]},
		"tree": {
			"swift_quiver": {"name": "Swift Quiver", "desc": "+6% move speed.", "effect": {"speed": 0.06}},
			"hawk_eye": {"name": "Hawk Eye", "desc": "+5% critical chance.", "needs": ["swift_quiver"], "effect": {"crit": 0.05}},
			"strong_arms": {"name": "Strong Arms", "desc": "+1 attack damage.", "needs": ["swift_quiver"], "effect": {"atk": 1}},
			"tailwind": {"name": "Tailwind", "desc": "+2 focus and arts cool 10% faster.", "needs": ["hawk_eye"], "effect": {"focus": 2, "cd": 0.10}},
		},
	},
	"petalweaver": {
		"name": "Petalweaver", "title": "mender of petals", "role": "cleric", "icon": NA + "ui/skill/amulet.png", "color": Color(1.0, 0.78, 0.88),
		"desc": "Cleric line. Healing petals, sanctuary rings and blooming wards.",
		"skills": ["mend", "sanctuary", "bloom_ward"],
		"attrs": {"heal_power": [0.10, 0.15, 0.20, 0.25, 0.30], "focus": [4, 6, 8, 10, 12]},
		"rewards": {2: ["bloomthread_shawl"]},
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
const MAX_RANK := 5
const SKILL_MAX_LEVEL := 3
## Secondary lines grant this share of their rank attributes.
const SECONDARY_ATTR_SCALE := 0.5


static func skill_of(id: String) -> Dictionary:
	return SKILLS.get(id, {})


static func class_of(id: String) -> Dictionary:
	return CLASSES.get(id, {})


static func xp_needed(level: int) -> int:
	return 24 + level * 16


static func aim_label(aim: String) -> String:
	match aim:
		"direction":
			return "AIM: LINE"
		"point":
			return "AIM: AREA"
	return "TAP"
