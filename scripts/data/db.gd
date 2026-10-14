extends RefCounted
## Static game data: items, equipment, weapons, enemies, bosses and NPC dialogue.

const NA := "res://assets/packs/ninja_adventure/"
const AW := "res://assets/art/weapons/"
const GENERATED_EQUIPMENT := "res://assets/generated/petalbound/equipment/"

const WEAPONS := ["thornblade", "bloomstaff", "gale_bow", "ironroot_hammer"]
const GENERATED_WEAPONS := {
	"thornblade": "katana", "thornblade_ii": "katana", "duskfan": "twin_katanas",
	"moonwell_blade": "katana", "petalbreaker": "katana", "twin_moon_katanas": "twin_katanas",
	"bloomstaff": "staff", "moonglass_staff": "staff", "oakwood_staff": "staff", "cloudstride_staff": "staff",
	"bramble_spear": "spear", "ironroot_hammer": "hammer", "gale_bow": "bow", "cinder_axe": "axe",
	"thornlash_whip": "whip", "ironbloom_gauntlet": "gauntlet", "starweave_gloves": "gauntlet",
}

const ITEMS := {
	"thornblade": {"rarity": "common", "name": "Thornblade", "type": "weapon", "icon": NA + "items/weapons/katana.png", "hand": NA + "items/weapons/katana_hand.png",
		"desc": "A quick rose-steel katana. Three-cut combo; the third cut staggers.", "damage": 2},
	"thornblade_ii": {"rarity": "uncommon", "name": "Thornblade · Tempered", "type": "weapon", "icon": NA + "items/weapons/katana.png", "hand": NA + "items/weapons/katana_hand.png",
		"desc": "Tier II: ore-tempered steel deals +2 damage.", "damage": 4, "tier": 2},
	"bloomstaff": {"rarity": "common", "name": "Bloomstaff", "type": "weapon", "icon": NA + "items/weapons/magicwand.png", "hand": NA + "items/weapons/magicwand_hand.png",
		"desc": "Fires seeking moonlight bolts that light up the dark.", "damage": 3},
	"gale_bow": {"rarity": "uncommon", "name": "Gale Bow", "type": "weapon", "icon": NA + "items/weapons/bow.png", "hand": NA + "items/weapons/bow.png",
		"desc": "Long-range arrows. Hold attack to charge a piercing gale shot.", "damage": 3},
	"duskfan": {"rarity": "uncommon", "name": "Duskfan", "type": "weapon", "icon": NA + "items/weapons/katana.png", "hand": NA + "items/weapons/katana_hand.png",
		"desc": "A nightsteel fan-blade. Swift cuts; the finisher bites deeper.", "damage": 3},
	"ironroot_hammer": {"rarity": "rare", "name": "Ironroot Hammer", "type": "weapon", "icon": NA + "items/weapons/hammer.png", "hand": NA + "items/weapons/hammer_hand.png",
		"desc": "Slow, crushing swings that send a shockwave through the ground.", "damage": 5},
	"plum_cloak": {"look": ["9a6ac0", "6a4590", "2a1838"], "rarity": "common", "name": "Plum Wayfarer Cloak", "type": "cloak", "icon": "res://assets/packs/rpg_inventory_icons/selected/plum_cloak.png",
		"desc": "Mallow's travelling cloak. +8% move speed.", "speed": 0.08},
	"emberleaf_mantle": {"look": ["ffad66", "d0602e", "5a2210"], "rarity": "uncommon", "name": "Emberleaf Mantle", "type": "cloak",
		"icon": "res://assets/packs/rpg_inventory_icons/selected/plum_cloak.png", "tint": "ffb27a",
		"desc": "Stitched from Emberleaf Vale's fallen leaves. +5% move speed and +1 defense.", "speed": 0.05, "defense": 1},
	"moonheart_charm": {"rarity": "uncommon", "name": "Moonheart Charm", "type": "charm", "icon": NA + "ui/skill/amulet.png",
		"desc": "A warm charm from Lake Lumen's island. +1 heart.", "hearts": 1},
	"briar_mail": {"look": ["c9a07a", "8a5a3c", "523221"], "rarity": "common", "name": "Briar Mail", "type": "armor", "icon": NA + "ui/skill/armor.png",
		"desc": "Woven thornwood armour. +1 heart and less knockback.", "hearts": 1, "poise": 0.5},
	"briar_mail_ii": {"look": ["d8b48a", "9a6a44", "5a3826"], "rarity": "uncommon", "name": "Briar Mail · Reinforced", "type": "armor", "icon": NA + "ui/skill/armor.png",
		"desc": "Tier II: reinforced plates grant +2 defense and +1 heart.", "defense": 2, "hearts": 1, "tier": 2},
	"zephyr_boots": {"look": ["b8d8ff", "5a7fb8", "33466e"], "rarity": "rare", "name": "Zephyr Boots", "type": "boots", "icon": NA + "ui/skill/boot.png",
		"desc": "+12% speed and much faster stamina recovery.", "speed": 0.12, "stamina_regen": 0.6},
	"ember_ring": {"rarity": "uncommon", "name": "Ember Ring", "type": "ring", "icon": NA + "ui/skill/ring.png",
		"desc": "Staff bolts and arrows deal +1 damage.", "ranged_bonus": 1},
	"moonveil_ring": {"rarity": "rare", "name": "Moonveil Ring", "type": "ring", "icon": NA + "ui/skill/ring.png",
		"desc": "Woven from crypt-moonlight. +6% critical chance.", "crit": 0.06},
	"sunplate": {"look": ["ffe69a", "d8a640", "8a6020"], "rarity": "rare", "name": "Sunplate Vest", "type": "armor", "icon": NA + "ui/skill/armor.png",
		"desc": "Radiant plate from the Watch forge. +2 defense.", "defense": 2},
	"starlocket": {"rarity": "rare", "name": "Star Locket", "type": "charm", "icon": NA + "ui/skill/amulet.png",
		"desc": "Hums with starlight. +1 heart and +10 focus.", "hearts": 1, "focus": 10},
	# ---- combat overhaul gear. "classes": any-of line requirement ([] = every wanderer);
	# "requires_all": true means every listed line must be bound (hybrid gear).
	"nightfang": {"rarity": "rare", "name": "Nightfang Knives", "dual": true, "type": "weapon", "classes": ["nightbloom"], "icon": NA + "items/weapons/sai.png", "hand": NA + "items/weapons/sai_hand.png",
		"desc": "Twin nightsteel sai. Lightning-quick two-cut combos with a high critical rate.", "damage": 2},
	"moonglass_staff": {"rarity": "rare", "name": "Moonglass Staff", "type": "weapon", "classes": ["lumimancer"], "icon": NA + "items/weapons/magicwand.png", "hand": NA + "items/weapons/magicwand_hand.png", "tint": "a8d8ff",
		"desc": "A prism-staff whose bolts cycle fire, frost and storm.", "damage": 3},
	"grave_scythe": {"rarity": "rare", "name": "Grave Scythe", "type": "weapon", "classes": ["gravetender"], "icon": NA + "items/weapons/axe.png", "hand": NA + "items/weapons/axe_hand.png", "tint": "b8ffd0",
		"desc": "A wide, reaping sweep that curses what it touches.", "damage": 3},
	"mossleaf_cap": {"look": ["b8e08a", "6aa04a", "3a6430"], "rarity": "common", "name": "Mossleaf Cap", "type": "head", "icon": NA + "ui/skill/helmet.png", "tint": "b8f0a0",
		"desc": "A soft cap of woven moss. +4 focus.", "focus": 4},
	"rootgrip_gloves": {"look": ["d0a878", "8a6440", "523a24"], "rarity": "common", "name": "Rootgrip Gloves", "type": "arms", "icon": NA + "ui/skill/punch.png", "tint": "d8c09a",
		"desc": "Bark-palmed gloves. +6% attack speed.", "atk_speed": 0.06},
	"trail_leggings": {"look": ["c8b48c", "8a7454", "544630"], "rarity": "common", "name": "Trail Leggings", "type": "legs", "icon": NA + "ui/skill/boot.png", "tint": "c0d0a0",
		"desc": "Well-worn travelling leggings. +4% speed, faster stamina.", "speed": 0.04, "stamina_regen": 0.2},
	"ember_heart": {"rarity": "rare", "name": "Ember Heart", "type": "relic", "icon": NA + "items/gemred.png",
		"desc": "A coal that never cools. Relic: Kindle.", "relic": "kindle"},
	"oakguard_helm": {"look": ["d8c49a", "9a8458", "5a4a30"], "rarity": "rare", "name": "Oakguard Helm", "type": "head", "classes": ["warden"], "icon": NA + "ui/skill/helmet.png", "tint": "a8c4ff",
		"desc": "Warden's heartwood helm. +1 defense, +1 heart.", "defense": 1, "hearts": 1},
	"ironknuckle_wraps": {"look": ["e0e4ec", "9aa2b4", "5a6274"], "rarity": "rare", "name": "Ironknuckle Wraps", "type": "arms", "classes": ["pugilist"], "icon": NA + "ui/skill/punch.png", "tint": "ffc9a0",
		"desc": "Iron-studded wraps. +1 attack, +5% attack speed.", "atk": 1, "atk_speed": 0.05},
	"duskweave_hood": {"look": ["8a7ab8", "4e3f7a", "2a2048"], "rarity": "uncommon", "name": "Duskweave Hood", "type": "head", "classes": ["nightbloom"], "icon": NA + "ui/skill/helmet.png", "tint": "c0a8ff",
		"desc": "A hood that drinks the light. +5% crit, +3% speed.", "crit": 0.05, "speed": 0.03},
	"shadow_wraps": {"look": ["a890e0", "5a4890", "30245a"], "rarity": "rare", "name": "Shadow Wraps", "type": "arms", "classes": ["nightbloom"], "icon": NA + "ui/skill/punch.png", "tint": "a890e0",
		"desc": "Silent arm-wraps. +10% attack speed, +3% crit.", "atk_speed": 0.10, "crit": 0.03},
	"gloam_lantern": {"rarity": "epic", "name": "Gloam Lantern", "type": "relic", "classes": ["nightbloom"], "icon": NA + "items/gempurple.png",
		"desc": "A lantern lit with darkness. Relic: Nightveil.", "relic": "nightveil"},
	"starweave_circlet": {"look": ["eef6ff", "a8c8f0", "5a78a8"], "rarity": "uncommon", "name": "Starweave Circlet", "type": "head", "classes": ["lumimancer"], "icon": NA + "ui/skill/helmet.png", "tint": "bfe0ff",
		"desc": "A circlet strung with starlight. +8 focus, +8% elemental damage.", "focus": 8, "elem": 0.08},
	"frostlace_robe": {"look": ["e0f4ff", "98c8e8", "4a7898"], "rarity": "rare", "name": "Frostlace Robe", "type": "armor", "classes": ["lumimancer"], "icon": NA + "ui/skill/armor.png", "tint": "c8ecff",
		"desc": "A cold, light robe. +1 defense, +6 focus, arts cool 8% faster.", "defense": 1, "focus": 6, "cdr": 0.08},
	"stormseed": {"rarity": "epic", "name": "Stormseed", "type": "relic", "classes": ["lumimancer"], "icon": NA + "items/gemyellow.png",
		"desc": "A seed full of thunder. Relic: Overcharge.", "relic": "overcharge"},
	"bonewrap_gloves": {"look": ["eef8ee", "b8ccb8", "6a806a"], "rarity": "uncommon", "name": "Bonewrap Gloves", "type": "arms", "classes": ["gravetender"], "icon": NA + "ui/skill/punch.png", "tint": "d8ffe0",
		"desc": "Gloves stitched with knucklebones. +5% lifesteal, +1 attack.", "lifesteal": 0.05, "atk": 1},
	"cryptwarden_greaves": {"look": ["a0e0b8", "4a8a6a", "28503c"], "rarity": "rare", "name": "Cryptwarden Greaves", "type": "legs", "classes": ["gravetender"], "icon": NA + "ui/skill/boot.png", "tint": "a0e0b8",
		"desc": "Grave-iron greaves. +1 heart, +1 defense.", "hearts": 1, "defense": 1},
	"soul_lantern": {"rarity": "epic", "name": "Soul Lantern", "type": "relic", "classes": ["gravetender"], "icon": NA + "items/gemgreen.png",
		"desc": "Houses a hungry little soul. Relic: Soul Feast.", "relic": "soulfeast"},
	"galestride_leggings": {"look": ["c8f8e0", "70c8a0", "3a7a5a"], "rarity": "uncommon", "name": "Galestride Leggings", "type": "legs", "classes": ["windrunner"], "icon": NA + "ui/skill/boot.png", "tint": "b0f0d0",
		"desc": "Feather-light leggings. +6% speed, ranged hits +1.", "speed": 0.06, "ranged_bonus": 1},
	"bloomthread_shawl": {"look": ["ffc4e0", "e07fb0", "6a2a4c"], "rarity": "rare", "name": "Bloomthread Shawl", "type": "cloak", "classes": ["petalweaver"], "icon": "res://assets/packs/rpg_inventory_icons/selected/plum_cloak.png", "tint": "ffd0e8",
		"desc": "Woven from living petals. Healing +25%, +6 focus.", "heal_power": 0.25, "focus": 6},
	"twilight_mantle": {"look": ["7ab894", "3f6e5c", "15302a"], "rarity": "epic", "name": "Twilight Reaper Mantle", "type": "cloak", "classes": ["nightbloom", "gravetender"], "requires_all": true, "icon": "res://assets/packs/rpg_inventory_icons/selected/plum_cloak.png", "tint": "9ad0b0",
		"desc": "Hybrid: Nightbloom + Gravetender. +5% crit, +6% lifesteal, +4% speed.", "crit": 0.05, "lifesteal": 0.06, "speed": 0.04},
	"spellblade_sash": {"rarity": "epic", "name": "Spellblade Sash", "type": "ring", "classes": ["nightbloom", "lumimancer"], "requires_all": true, "icon": NA + "ui/skill/ring.png", "tint": "c8b8ff",
		"desc": "Hybrid: Nightbloom + Lumimancer. +10% elemental damage, +4% crit.", "elem": 0.10, "crit": 0.04},
	# ---- bare hands: always owned, never sold, no sprite in hand
	"fists": {"rarity": "common", "name": "Bare Paws", "type": "weapon", "unarmed": true, "wclass": "Fists", "icon": NA + "ui/skill/punch.png",
		"desc": "Mallow's own paws. A quick jab-jab-hook combo with short reach. Any weapon hits harder.", "damage": 1, "value": 0},
	# ---- more weapon categories
	"bramble_spear": {"rarity": "uncommon", "name": "Bramble Spear", "type": "weapon", "wclass": "Spear", "icon": NA + "items/weapons/lance.png", "hand": NA + "items/weapons/lance_hand.png", "tint": "e8d8b0",
		"desc": "A long thorn-tipped spear. Narrow thrusts that reach far; the finisher pierces a line.", "damage": 2, "value": 40},
	"cinder_axe": {"rarity": "uncommon", "name": "Cinder Axe", "type": "weapon", "wclass": "Axe", "icon": NA + "items/weapons/axe.png", "hand": NA + "items/weapons/axe_hand.png", "tint": "ffc8a0",
		"desc": "A heavy axe with an ember in the haft. Two chopping blows; the second sets foes burning.", "damage": 3, "value": 55},
	"petalbreaker": {"rarity": "epic", "name": "Petalbreaker", "type": "weapon", "wclass": "Greatsword", "classes": ["warden", "pugilist"], "icon": NA + "items/weapons/bigsword.png", "hand": NA + "items/weapons/bigsword_hand.png", "tint": "ffe0f0",
		"desc": "A greatsword for Wardens and Pugilists. Slow, wide cleaves; the finisher exposes foes (+20% damage taken).", "damage": 4, "value": 160},
	"moonwell_blade": {"rarity": "legendary", "name": "Moonwell Blade", "type": "weapon", "wclass": "Sword", "icon": NA + "items/weapons/katana.png", "hand": NA + "items/weapons/katana_hand.png", "tint": "d8e8ff",
		"desc": "Forged from a guardian's moonlight. Three-cut combo; every third cut releases a moon wave.", "damage": 4, "value": 260},
	# ---- arsenal pass: signature weapons with hold-to-charge effects (art: assets/art/weapons, original)
	"oakwood_staff": {"rarity": "common", "name": "Oakwood Staff", "type": "weapon", "wclass": "Staff", "icon": AW + "oakwood_staff.png", "hand": AW + "oakwood_staff_hand.png",
		"desc": "A plain quarterstaff. Wide sweeping strikes with good reach. No hold effect.", "damage": 2, "value": 30},
	"cloudstride_staff": {"rarity": "mythical", "name": "Cloudstride Staff", "type": "weapon", "wclass": "Staff", "icon": AW + "cloudstride_staff.png", "hand": AW + "cloudstride_staff_hand.png",
		"desc": "A lacquered staff that remembers every step. Fast extending strikes. HOLD: blink ahead and leave a fighting afterimage behind.", "damage": 4, "value": 420},
	"twin_moon_katanas": {"rarity": "epic", "name": "Twin Moon Katanas", "type": "weapon", "wclass": "Katana", "dual": true, "icon": NA + "items/weapons/katana.png", "hand": NA + "items/weapons/katana_hand.png", "tint": "d6d0ff",
		"desc": "Paired moonsteel blades. Four-cut cross-slash combo. HOLD: Moonrend Dash cuts through everything in a line.", "damage": 3, "value": 220},
	"ironbloom_gauntlet": {"rarity": "rare", "name": "Ironbloom Gauntlet", "type": "weapon", "wclass": "Gauntlet", "icon": AW + "ironbloom_gauntlet.png", "hand": AW + "ironbloom_gauntlet_hand.png",
		"desc": "A petal-etched iron fist. Slow, heavy punches. HOLD: Energy Burst blasts foes back and knocks them down.", "damage": 4, "value": 140},
	"thornlash_whip": {"rarity": "rare", "name": "Thornlash Whip", "type": "weapon", "wclass": "Whip", "icon": AW + "thornlash_whip.png", "hand": AW + "thornlash_whip_hand.png",
		"desc": "A living briar whip. Spins all around you; the thorned tip (outer ring) hits 50% harder. HOLD: Wide Lash, one bigger, stronger spin.", "damage": 2, "value": 150},
	"starweave_gloves": {"rarity": "epic", "name": "Starweave Gloves", "type": "weapon", "wclass": "Gloves", "icon": AW + "starweave_gloves.png", "hand": AW + "starweave_gloves_hand.png",
		"desc": "Gloves woven with starlight. Long-range star orbs (no homing). HOLD: Overcharge, a bigger and stronger orb.", "damage": 3, "value": 210},
	"direwolf_claws": {"rarity": "epic", "name": "Direwolf Claws", "type": "weapon", "wclass": "Claws", "dual": true, "icon": AW + "direwolf_claws.png", "hand": AW + "direwolf_claws_hand.png",
		"desc": "Paired wolf-fang claws. Quick swipes; heals you for 7% of damage dealt. HOLD: Feral Barrage, a long-reaching claw flurry (lifesteal applies).", "damage": 2, "value": 200},
	# ---- legendary armour (crafted / rift rewards)
	"starfall_crown": {"rarity": "legendary", "name": "Starfall Crown", "type": "head", "look": ["fff2b8", "e8c060", "9a7430"], "icon": NA + "ui/skill/helmet.png", "tint": "ffe8a0",
		"desc": "A crown of fallen stars. +1 heart, +6% crit, +6 focus.", "hearts": 1, "crit": 0.06, "focus": 6, "value": 240},
	"moonwell_aegis": {"rarity": "legendary", "name": "Moonwell Aegis", "type": "armor", "look": ["eef4ff", "a8b8e8", "5a6898"], "icon": NA + "ui/skill/armor.png", "tint": "d8e4ff",
		"desc": "Silver plate that hums with the Moonwell. +2 defense, +1 heart.", "defense": 2, "hearts": 1, "value": 260},
	"rift_treads": {"rarity": "epic", "name": "Riftwalker Treads", "type": "boots", "look": ["e0c8ff", "9a70d8", "4a3088"], "icon": NA + "ui/skill/boot.png", "tint": "d0b8ff",
		"desc": "Boots that remember the rifts. +8% speed, +1 defense.", "speed": 0.08, "defense": 1, "value": 150},
	"hidebound_vest": {"rarity": "uncommon", "name": "Hidebound Vest", "type": "armor", "look": ["d8b890", "9a7a50", "5a4428"], "icon": NA + "ui/skill/armor.png", "tint": "e0c8a0",
		"desc": "Stitched from beast hide. +1 defense, +4% lifesteal.", "defense": 1, "lifesteal": 0.04, "value": 60},
	"slimeglass_boots": {"rarity": "common", "name": "Slimeglass Boots", "type": "boots", "look": ["b8f0d8", "60c0a0", "2e7a64"], "icon": NA + "ui/skill/boot.png", "tint": "b0f0d8",
		"desc": "Bouncy boots set with dried gel. +4% speed.", "speed": 0.04, "value": 25},
	"gale_band": {"rarity": "rare", "name": "Gale Band", "type": "relic", "icon": NA + "ui/skill/amulet.png", "tint": "c8f8ff", "relic": "swiftwind",
		"desc": "Any class. Active: Swiftwind (+35% attack speed and +15% speed for 6s).", "value": 120},
	"barkskin_charm": {"rarity": "uncommon", "name": "Barkskin Charm", "type": "relic", "icon": NA + "items/gemgreen.png", "tint": "b8e090", "relic": "barkskin",
		"desc": "Any class. Active: Barkskin (+2 defense and regenerate a quarter-heart per second for 5s).", "value": 90},
	"moonpetal_ring": {"rarity": "rare", "name": "Moonpetal Ring", "type": "ring", "classes": ["petalweaver"], "icon": "res://assets/generated/petalbound/icons/moonpetal_ring.png", "tint": "e8c9ff",
		"desc": "A ring woven from the hollow's night-blooming petals. +10% healing and +4 focus.", "heal_power": 0.10, "focus": 4, "value": 110},
	"hollowglow_charm": {"rarity": "uncommon", "name": "Hollowglow Charm", "type": "charm", "icon": "res://assets/generated/petalbound/icons/hollowglow_charm.png", "tint": "d7efad",
		"desc": "A lantern-seed that never goes dark. +1 defense and +4 focus.", "defense": 1, "focus": 4, "value": 75},
	"starweft_boots": {"rarity": "rare", "name": "Starweft Boots", "type": "boots", "classes": ["windrunner"], "icon": "res://assets/generated/petalbound/icons/starweft_boots.png", "tint": "c7e8ff",
		"desc": "Light as a falling petal. +6% move speed and +0.2 stamina recovery.", "speed": 0.06, "stamina_regen": 0.2, "value": 105},
	"moonfall_circlet": {"rarity": "epic", "name": "Moonfall Circlet", "type": "head", "classes": ["lumimancer"], "icon": "res://assets/generated/petalbound/icons/moonfall_circlet.png", "tint": "fff0ae",
		"desc": "A circlet tempered beneath the basin's falling stars. +6 focus and +6% cooldown reduction.", "focus": 6, "cdr": 0.06, "value": 165},
	# ---- materials (stack in the bag, sell, exchange, craft)
	"wood": {"rarity": "common", "name": "Oak Branch", "type": "material", "icon": NA + "items/branch.png", "value": 2, "desc": "Sturdy branches from Hollowroot trees."},
	"ore": {"rarity": "common", "name": "Iron Ore", "type": "material", "icon": NA + "items/rock.png", "value": 3, "desc": "Rough ore knocked from boulders."},
	"herb": {"rarity": "common", "name": "Dew Herb", "type": "material", "icon": NA + "items/tealeaf.png", "value": 2, "desc": "A fragrant herb for brewing Moontea."},
	"slime_gel": {"rarity": "common", "name": "Slime Gel", "type": "material", "icon": NA + "items/honey.png", "tint": "a8f0c8", "value": 2, "desc": "Wobbly gel left by slimes."},
	"bat_wing": {"rarity": "common", "name": "Gloam Wing", "type": "material", "icon": NA + "items/feather.png", "tint": "a8a0e0", "value": 3, "desc": "A papery wing from flyers."},
	"beast_hide": {"rarity": "common", "name": "Beast Hide", "type": "material", "icon": NA + "items/meat.png", "tint": "d8b890", "value": 4, "desc": "Tough hide from lizards, moles and vipers."},
	"venom_sac": {"rarity": "uncommon", "name": "Venom Sac", "type": "material", "icon": NA + "items/gemgreen.png", "tint": "c0f080", "value": 6, "desc": "A sac of briar venom. Handle gently."},
	"bone_shard": {"rarity": "uncommon", "name": "Bone Shard", "type": "material", "icon": NA + "items/nut.png", "tint": "f0f0e0", "value": 6, "desc": "A splinter of old bone from the restless dead."},
	"ember_core": {"rarity": "uncommon", "name": "Ember Core", "type": "material", "icon": NA + "items/gemred.png", "value": 8, "desc": "A warm core from fire creatures."},
	"spirit_dust": {"rarity": "rare", "name": "Spirit Dust", "type": "material", "icon": NA + "items/gempurple.png", "tint": "d8c8ff", "value": 12, "desc": "Glittering dust from spirits and watchers."},
	"moon_shard": {"rarity": "epic", "name": "Moon Shard", "type": "material", "icon": NA + "items/seedlargewhite.png", "tint": "d8e8ff", "value": 40, "desc": "A rare sliver of moonlight. Found in rifts and on elites."},
	# ---- consumables & quest items
	"moontea_vial": {"rarity": "common", "name": "Moontea Vial", "type": "consumable", "icon": NA + "items/lifepot.png", "value": 12,
		"desc": "Used by the potion button when the flask is empty. Restores two hearts."},
	"rift_key": {"rarity": "rare", "name": "Rift Key", "type": "consumable", "icon": NA + "items/goldkey.png", "value": 30,
		"desc": "Lets you enter a rift that would otherwise need a higher level."},
	"alder_letter": {"rarity": "common", "name": "Elder's Letter", "type": "quest", "icon": NA + "items/book.png", "value": 0,
		"desc": "A sealed letter from Elder Alder for Bramble the smith."},
	"moontea": {"name": "Moontea Flask", "type": "flask_up", "icon": NA + "items/lifepot.png",
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

## Paper-doll order. "armor" is the chest slot and "boots" the feet slot (save-compatible keys).
const EQUIP_SLOTS := ["head", "armor", "arms", "legs", "boots", "cloak", "charm", "ring", "relic"]
const SLOT_NAMES := {"head": "Head", "armor": "Chest", "arms": "Arms", "legs": "Legs", "boots": "Feet",
	"cloak": "Cloak", "charm": "Charm", "ring": "Ring", "relic": "Relic", "weapon": "Weapon"}
const RARITIES := ["common", "uncommon", "rare", "epic", "legendary", "mythical"]
const RARITY_NAMES := {"common": "Common", "uncommon": "Uncommon", "rare": "Rare", "epic": "Epic", "legendary": "Legendary", "mythical": "Mythical"}
## Stackable item types live in the bag (id -> count) instead of the gear list.
const STACKABLE := ["material", "consumable", "quest"]
const STACK_MAX := 99
const BAG_SLOTS := 24
const RARITY_COLORS := {"common": Color(0.85, 0.85, 0.85), "uncommon": Color(0.55, 0.95, 0.55),
	"rare": Color(0.5, 0.75, 1.0), "epic": Color(0.85, 0.6, 1.0), "legendary": Color(1.0, 0.75, 0.35),
	"mythical": Color(1.0, 0.45, 0.42)}

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
	# Emberleaf Vale side guardian: the Briarback's sheet, scorched orange. Not a Moonseed keeper.
	"emberbark": {"hp": 210, "frame": 62, "anims": {"idle": 6, "walk": 12, "attack": 5, "charge": 3, "hit": 4}, "music": "boss", "radius": 22.0,
		"sheet": "giantbamboo", "side": true,
		# palette swap: the Briarback's limes and mosses become ember oranges and bark
		"swap": {"adbc3a": "ffb347", "74a334": "e8742c", "56864c": "a8442a", "5f7160": "7a4e3e"}},
}

const OUTFITS := {
	# NinjaGreen source palette -> Petalbound rose-wanderer palette
	"default": [["a8a129", "f08aa8"], ["56864c", "7a4f95"], ["345a52", "4a2d63"], ["d14b34", "ffd27a"]],
	"briar_mail": [["a8a129", "f08aa8"], ["56864c", "8a5a3c"], ["345a52", "523221"], ["d14b34", "9ee07a"]],
	"zephyr_boots": [["a8a129", "f6a6c1"], ["56864c", "5a7fb8"], ["345a52", "33466e"], ["d14b34", "ffd27a"]],
}

const REGION_MUSIC := ["meadow", "forest", "desert", "snow", "forest", "meadow", "snow", "forest", "village"]

static func dialogue(id: String, seeds: int, flags: Dictionary) -> Array:
	match id:
		"alder":
			if seeds == 0:
				return ["Mallow! The Moonwell has gone dim, and the colour is draining from every petal.",
					"Four guardians took the Moonseeds when the blight spread: the Briarback in Hollowroot Grove, the Glasswater Toad in the marsh, the Ember Cyclops in the Sunscar Dunes and the Quiet Warden of Moonstone Ruins.",
					"Bring the seeds back to the Moonwell, north of here. Waystones will remember you if you fall. Go gently.",
					"And if you can thin the blight on your way — eight creatures, any eight — the village will pay you back for it."]
			elif seeds < 4:
				return ["%d of 4 Moonseeds... I can already see colour returning to the lanterns." % seeds, "Rest at a waystone if the road gets rough."]
			return ["All four seeds! Carry them to the Moonwell in the north. The whole valley is holding its breath."]
		"mira":
			if not flags.get("mira_tea", false):
				return ["Oh, you're heading out? Take this, freshly brewed.", "@moontea", "Moontea restores two hearts. Any waystone will refill your flask, too.",
				"The moonpetals only open at night now. If you gather three for me, I'll pay you well — Rosa is inside the cottage if you want to warm your hands."]
			return ["The garden misses the moonlight. Petals don't open the same way in the blight.", "Hollowroot spores are thick this season. Watch for the sproutlings; they charge when they see you."]
		"pip":
			return ["Welcome to Pip's Provisions! Best prices this side of the Moonwell.", "@shop"]
		"nomad":
			return ["The dunes take more than they give, traveller. But I trade fair.", "@shop"]
		"tallow":
			return ["The roads branch from Hearthgrove like roots: north to Hollowroot, east to the marsh and the dunes, north-east to the Moonstone Ruins.",
				"Hold SHIFT or push the stick all the way to sprint, and jump low hedges with C. Hold attack and steer: your swings follow your stick.",
				"Open your map with M. Skulls mark the guardians you haven't faced."]
		"sora":
			if seeds >= 4:
				return ["The seeds hum in your satchel. Kneel at the Moonwell and return them."]
			return ["The Moonwell sleeps. Only four Moonseeds can wake it.", "Until then, the ruins grow colder every night.",
				"The graves in the marsh predate the blight. If you clear what sleeps beneath them, the Moonwell will owe you more than words."]
		"rosa":
			return ["Mira's out with the garden. Sit by the kettle, it's warm.", "The old graveyard in the marsh hums at night. I don't listen. You shouldn't either."]
		"jun":
			return ["Sis says the graveyard marsh hums at night. I'm not allowed past the reeds.", "If you go down there... bring a lantern. And snacks. Mostly snacks."]
		"fen":
			return ["Alder keeps the village; I keep its memory. Sit a while.", "Every door in Hearthgrove opens to you now. Ours did not always, you know."]
		"kit":
			return ["Did you know you can cut bushes? Sometimes there are coins inside!", "Mum says not to go past the torii gate at night...",
				"If you're going to the lake... Hana found something silver in the reeds. I think it's Mum's locket. Could you ask her?"]
		"bramble":
			return ["Bramble's Forge! Bring me monster parts and ore and I'll shape them into something worth swinging.",
				"I'll also buy spare materials, and trade rare parts for recipe scrolls.", "@forge"]
		"kaede":
			return ["The Watch keeps the valley armed. Blade, plate, wand — I sell them all.",
				"Best any one guardian and report back to me. The Watch pays bounties, even to wanderers.", "@shop"]
		"hana":
			return ["Lake Lumen is the prettiest place in the world when the moon is on it.", "Well. It used to be.",
				"This? It caught in the reeds... you take it back to Kit's family. It's theirs, not mine."]
		"lumen":
			if seeds >= 4:
				return ["The stars told me you would come. The Moonwell's light runs down beneath the water now.",
					"A stair of light unfolds under the Moonwell for those who saved it. Old guardian echoes wait down there — every fourth wave.",
					"Starfall petals drift from the sky here. Gather the moonpetals at night; they brew beautifully."]
			return ["Welcome to Starfall Rise, wanderer. The petals here fall from the sky, not the trees.",
				"The Mirror Basin shows the stars even at noon. Mind the wisps after dark.",
				"Sit with the eye statue a while. It has seen more roads than any of us.",
				"The Ember Road runs east through a gap in the white grove, down into Emberleaf Vale."]
		"rowan":
			if flags.get("emberbark_felled", false):
				return ["The hollow's quiet at last. The leaves still burn orange, but now it's only autumn.",
					"If you're after ember cores, crack the glowing ore rocks with your weapon."]
			return ["Cinderbrook Camp, wanderer. We hunt the vale and keep the waystone lit.",
				"Ember spiders have been crawling right up to the stalls. Thin them out and I'll make it worth your while.",
				"North of camp, the Emberbark sleeps in its hollow. Watch the ground: when it glows red, step out of it."]
	return ["..."]


## Resolve generated artwork for supported equipment while preserving legacy art elsewhere.
static func icon_path(id: String) -> String:
	var item: Dictionary = ITEMS.get(id, {})
	if item.is_empty():
		return NA + "ui/skill/scroll.png"
	if GENERATED_WEAPONS.has(id):
		return GENERATED_EQUIPMENT + "weapons/" + String(GENERATED_WEAPONS[id]) + ".png"
	var item_type := String(item.get("type", ""))
	if item_type in EQUIP_SLOTS:
		return GENERATED_EQUIPMENT + "gear/" + item_type + ".png"
	return String(item.get("icon", NA + "ui/skill/scroll.png"))


## Resolve a small player-held weapon texture, or the original texture when unmapped.
static func hand_path(id: String) -> String:
	if GENERATED_WEAPONS.has(id):
		return GENERATED_EQUIPMENT + "weapon_hands/" + String(GENERATED_WEAPONS[id]) + ".png"
	return String(ITEMS.get(id, {}).get("hand", ""))
