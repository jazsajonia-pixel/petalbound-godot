extends RefCounted
## Static game data: items, equipment, weapons, enemies, bosses and NPC dialogue.

const NA := "res://assets/packs/ninja_adventure/"

const WEAPONS := ["thornblade", "bloomstaff", "gale_bow", "ironroot_hammer"]

const ITEMS := {
	"thornblade": {"name": "Thornblade", "type": "weapon", "icon": NA + "items/weapons/katana.png", "hand": NA + "items/weapons/katana_hand.png",
		"desc": "A quick rose-steel katana. Three-cut combo; the third cut staggers.", "damage": 2},
	"bloomstaff": {"name": "Bloomstaff", "type": "weapon", "icon": NA + "items/weapons/magicwand.png", "hand": NA + "items/weapons/magicwand_hand.png",
		"desc": "Fires seeking moonlight bolts that light up the dark.", "damage": 3},
	"gale_bow": {"name": "Gale Bow", "type": "weapon", "icon": NA + "items/weapons/bow.png", "hand": NA + "items/weapons/bow.png",
		"desc": "Long-range arrows. Hold attack to charge a piercing gale shot.", "damage": 3},
	"ironroot_hammer": {"name": "Ironroot Hammer", "type": "weapon", "icon": NA + "items/weapons/hammer.png", "hand": NA + "items/weapons/hammer_hand.png",
		"desc": "Slow, crushing swings that send a shockwave through the ground.", "damage": 5},
	"plum_cloak": {"name": "Plum Wayfarer Cloak", "type": "cloak", "icon": "res://assets/packs/rpg_inventory_icons/selected/plum_cloak.png",
		"desc": "Mallow's travelling cloak. +8% move speed.", "speed": 0.08},
	"moonheart_charm": {"name": "Moonheart Charm", "type": "charm", "icon": NA + "ui/skill/amulet.png",
		"desc": "A warm charm from Lake Lumen's island. +1 heart.", "hearts": 1},
	"briar_mail": {"name": "Briar Mail", "type": "armor", "icon": NA + "ui/skill/armor.png",
		"desc": "Woven thornwood armour. +1 heart and less knockback.", "hearts": 1, "poise": 0.5},
	"zephyr_boots": {"name": "Zephyr Boots", "type": "boots", "icon": NA + "ui/skill/boot.png",
		"desc": "+12% speed and much faster stamina recovery.", "speed": 0.12, "stamina_regen": 0.6},
	"ember_ring": {"name": "Ember Ring", "type": "ring", "icon": NA + "ui/skill/ring.png",
		"desc": "Staff bolts and arrows deal +1 damage.", "ranged_bonus": 1},
	"moontea": {"name": "Moontea", "type": "consumable", "icon": NA + "items/lifepot.png",
		"desc": "Restores two hearts. Waystones refill your flask."},
	"heart_piece": {"name": "Heart Bloom", "type": "upgrade", "icon": NA + "items/heart.png",
		"desc": "A heart-shaped bloom. Permanently +1 heart."},
	"moonseed": {"name": "Moonseed", "type": "key", "icon": NA + "items/seedlarge.png",
		"desc": "A seed of the Moonwell's light. Return four to the Moonwell."},
	"coins_25": {"name": "25 Petalcoins", "type": "coins", "icon": NA + "items/goldcoin.png", "amount": 25, "desc": "A pouch of Petalcoins."},
	"coins_50": {"name": "50 Petalcoins", "type": "coins", "icon": NA + "items/moneybag.png", "amount": 50, "desc": "A heavy pouch of Petalcoins."},
	"fishing_rod": {"name": "Willow Fishing Rod", "type": "tool", "icon": NA + "items/weapons/lance.png",
		"desc": "A light willow rod. Face any water and press E to cast. Fish bite fast!"},
}

const EQUIP_SLOTS := ["cloak", "armor", "charm", "boots", "ring"]

# behaviours: hopper, chaser, flyer, caster, charger
const ENEMIES := {
	"slime": {"name": "Dew Slime", "hp": 4, "speed": 30.0, "ai": "hopper", "dmg": 2, "sight": 110.0, "coins": 2, "fps": 6.0},
	"slime2": {"name": "Moss Slime", "hp": 6, "speed": 34.0, "ai": "hopper", "dmg": 2, "sight": 120.0, "coins": 3, "fps": 6.0},
	"slime3": {"name": "Frost Slime", "hp": 8, "speed": 36.0, "ai": "hopper", "dmg": 3, "sight": 120.0, "coins": 3, "fps": 6.0},
	"mushroom": {"name": "Capling", "hp": 6, "speed": 38.0, "ai": "chaser", "dmg": 2, "sight": 120.0, "coins": 2, "fps": 8.0},
	"mushroom2": {"name": "Frost Capling", "hp": 8, "speed": 40.0, "ai": "chaser", "dmg": 3, "sight": 130.0, "coins": 3, "fps": 8.0},
	"butterfly": {"name": "Gale Moth", "hp": 3, "speed": 44.0, "ai": "flyer", "dmg": 1, "sight": 130.0, "coins": 1, "fps": 10.0},
	"bamboo": {"name": "Sproutling", "hp": 7, "speed": 36.0, "ai": "charger", "dmg": 2, "sight": 120.0, "coins": 3, "fps": 8.0},
	"owl": {"name": "Hollow Owl", "hp": 6, "speed": 48.0, "ai": "flyer", "dmg": 2, "sight": 150.0, "coins": 3, "fps": 8.0},
	"spiderred": {"name": "Ember Spider", "hp": 7, "speed": 44.0, "ai": "charger", "dmg": 3, "sight": 130.0, "coins": 3, "fps": 10.0},
	"snake2": {"name": "Briar Viper", "hp": 8, "speed": 40.0, "ai": "chaser", "dmg": 3, "sight": 120.0, "coins": 3, "fps": 8.0},
	"lizard": {"name": "Reed Lizard", "hp": 8, "speed": 46.0, "ai": "chaser", "dmg": 3, "sight": 130.0, "coins": 3, "fps": 10.0},
	"eye": {"name": "Watcher", "hp": 7, "speed": 24.0, "ai": "caster", "dmg": 3, "sight": 170.0, "coins": 4, "fps": 6.0, "shot": "energy_ball"},
	"mole": {"name": "Dune Mole", "hp": 9, "speed": 36.0, "ai": "chaser", "dmg": 3, "sight": 110.0, "coins": 4, "fps": 8.0},
	"skull": {"name": "Rattle Skull", "hp": 10, "speed": 40.0, "ai": "chaser", "dmg": 4, "sight": 130.0, "coins": 4, "fps": 8.0},
	"cyclope": {"name": "Sand Cyclops", "hp": 12, "speed": 30.0, "ai": "caster", "dmg": 4, "sight": 170.0, "coins": 5, "fps": 6.0, "shot": "fireball"},
	"flam": {"name": "Cinder Wisp", "hp": 7, "speed": 42.0, "ai": "flyer", "dmg": 3, "sight": 150.0, "coins": 4, "fps": 10.0},
	"spirit": {"name": "Pale Spirit", "hp": 9, "speed": 34.0, "ai": "caster", "dmg": 3, "sight": 170.0, "coins": 4, "fps": 8.0, "shot": "ice_spike"},
	"spirit2": {"name": "Ember Spirit", "hp": 9, "speed": 38.0, "ai": "flyer", "dmg": 3, "sight": 160.0, "coins": 4, "fps": 8.0},
	"bluebat": {"name": "Gloam Bat", "hp": 5, "speed": 56.0, "ai": "flyer", "dmg": 2, "sight": 160.0, "coins": 3, "fps": 12.0},
}

const FISH := {
	"dewfin": {"name": "Dewfin", "coins": 6, "weight": 50, "night": false, "biome": -1, "tint": "9adcf0"},
	"redbreast": {"name": "Redbreast", "coins": 12, "weight": 28, "night": false, "biome": -1, "tint": "f0956b"},
	"moonkoi": {"name": "Moonkoi", "coins": 25, "weight": 14, "night": true, "biome": -1, "tint": "cfc4ff"},
	"starfin": {"name": "Starfin", "coins": 40, "weight": 8, "night": false, "biome": 6, "tint": "ffe9a8"},
}

const BOSSES := {
	"giantbamboo": {"hp": 140, "frame": 62, "anims": {"idle": 6, "walk": 12, "attack": 5, "charge": 3, "hit": 4}, "music": "boss", "radius": 22.0},
	"giantfrog": {"hp": 150, "frame": 40, "anims": {"idle": 5, "jump": 6, "charge": 7, "attack": 3, "hit": 3}, "music": "boss", "radius": 16.0},
	"demoncyclop": {"hp": 170, "frame": 50, "anims": {"idle": 5, "walk": 6, "hit": 3}, "music": "boss", "radius": 18.0},
	"giantspirit": {"hp": 180, "frame": 50, "anims": {"idle": 5, "hit": 3}, "music": "boss", "radius": 18.0},
}

const OUTFITS := {
	# NinjaGreen source palette -> Petalbound rose-wanderer palette
	"default": [["a8a129", "f08aa8"], ["56864c", "7a4f95"], ["345a52", "4a2d63"], ["d14b34", "ffd27a"]],
	"briar_mail": [["a8a129", "f08aa8"], ["56864c", "8a5a3c"], ["345a52", "523221"], ["d14b34", "9ee07a"]],
	"zephyr_boots": [["a8a129", "f6a6c1"], ["56864c", "5a7fb8"], ["345a52", "33466e"], ["d14b34", "ffd27a"]],
}

const REGION_MUSIC := ["meadow", "forest", "desert", "snow", "forest", "meadow", "snow"]

static func dialogue(id: String, seeds: int, flags: Dictionary) -> Array:
	match id:
		"alder":
			if seeds == 0:
				return ["Mallow! The Moonwell has gone dim, and the colour is draining from every petal.",
					"Four guardians took the Moonseeds when the blight spread: the Briarback in Hollowroot Grove, the Glasswater Toad in the marsh, the Ember Cyclops in the Sunscar Dunes and the Quiet Warden of Moonstone Ruins.",
					"Bring the seeds back to the Moonwell, north of here. Waystones will remember you if you fall. Go gently."]
			elif seeds < 4:
				return ["%d of 4 Moonseeds... I can already see colour returning to the lanterns." % seeds, "Rest at a waystone if the road gets rough."]
			return ["All four seeds! Carry them to the Moonwell in the north. The whole valley is holding its breath."]
		"mira":
			if not flags.get("mira_tea", false):
				return ["Oh, you're heading out? Take this, freshly brewed.", "@moontea", "Moontea restores two hearts. Any waystone will refill your flask, too."]
			return ["The garden misses the moonlight. Petals don't open the same way in the blight.", "Hollowroot spores are thick this season. Watch for the sproutlings; they charge when they see you."]
		"pip":
			return ["Welcome to Pip's Provisions! Best prices this side of the Moonwell.", "@shop"]
		"nomad":
			return ["The dunes take more than they give, traveller. But I trade fair.", "@shop"]
		"tallow":
			return ["The roads branch from Hearthgrove like roots: north to Hollowroot, east to the marsh and the dunes, north-east to the Moonstone Ruins.",
				"Hold SHIFT or push the stick all the way to sprint. Roll through attacks with SPACE, and jump low hedges with C.",
				"Open your map with M. Skulls mark the guardians you haven't faced."]
		"sora":
			if seeds >= 4:
				return ["The seeds hum in your satchel. Kneel at the Moonwell and return them."]
			return ["The Moonwell sleeps. Only four Moonseeds can wake it.", "Until then, the ruins grow colder every night."]
		"kit":
			return ["Did you know you can cut bushes? Sometimes there are coins inside!", "Mum says not to go past the torii gate at night..."]
		"bramble":
			return ["I saw a chest on the little island in Lake Lumen. You'd have to swim for it!"]
		"kaede":
			return ["I keep watch on the east road. The marsh toad has been bellowing every night.", "Its leaps leave a shadow on the ground. Move when you see it grow."]
		"hana":
			return ["Lake Lumen is the prettiest place in the world when the moon is on it.", "Well. It used to be."]
		"lumen":
			if seeds >= 4:
				return ["The stars told me you would come. The Moonwell's light runs down beneath the water now.",
					"A stair of light unfolds under the Moonwell for those who saved it. Old guardian echoes wait down there — every fourth wave.",
					"Starfall petals drift from the sky here. Gather the moonpetals at night; they brew beautifully."]
			return ["Welcome to Starfall Rise, wanderer. The petals here fall from the sky, not the trees.",
				"The Mirror Basin shows the stars even at noon. Mind the wisps after dark.",
				"Sit with the eye statue a while. It has seen more roads than any of us."]
	return ["..."]

