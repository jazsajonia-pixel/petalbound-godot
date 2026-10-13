extends RefCounted
## Data for the RPG loop: loot tables, crafting recipes, NPC shops and
## exchanges. Pure data - rules live in scripts/systems/{loot,crafting,trade}.gd.

# ------------------------------------------------------------------ loot
## Species -> loot group.
const LOOT_GROUP := {
	"slime": "slime", "slime2": "slime", "slime3": "slime",
	"mushroom": "beast", "mushroom2": "beast", "bamboo": "beast", "lizard": "beast", "mole": "beast",
	"snake2": "venom", "spiderred": "venom",
	"bluebat": "flyer", "butterfly": "flyer", "owl": "flyer",
	"skull": "undead",
	"spirit": "spirit", "eye": "spirit",
	"flam": "fire", "spirit2": "fire", "cyclope": "fire",
}
## Each entry: [item id, chance 0..1, min qty, max qty]. Rolled independently.
## Coins come from DB.ENEMIES[species].coins (dropped as physical coins).
const LOOT := {
	"slime": [["slime_gel", 0.55, 1, 2], ["herb", 0.10, 1, 1], ["moontea_vial", 0.03, 1, 1]],
	"beast": [["beast_hide", 0.45, 1, 1], ["wood", 0.18, 1, 2], ["herb", 0.08, 1, 1]],
	"venom": [["venom_sac", 0.35, 1, 1], ["beast_hide", 0.25, 1, 1]],
	"flyer": [["bat_wing", 0.50, 1, 2]],
	"undead": [["bone_shard", 0.50, 1, 2], ["spirit_dust", 0.05, 1, 1]],
	"spirit": [["spirit_dust", 0.20, 1, 1], ["bone_shard", 0.12, 1, 1]],
	"fire": [["ember_core", 0.35, 1, 1], ["ore", 0.10, 1, 1]],
}
## Extra rolls for elites (always at least one uncommon-or-better material).
const ELITE_BONUS := [["moon_shard", 0.15, 1, 1], ["spirit_dust", 0.35, 1, 2]]
const ELITE_GUARANTEE := ["venom_sac", "bone_shard", "ember_core"]
## Field equipment drops: small chance per kill, rarity-weighted pool, with pity.
const GEAR_CHANCE := 0.02
const GEAR_CHANCE_ELITE := 0.30
const GEAR_PITY := 40           # kills without a gear drop -> next kill guarantees one
const GEAR_RARITY_WEIGHTS := {"common": 60, "uncommon": 30, "rare": 9, "epic": 1}
## Items that can drop in the field (no legendaries, no hybrid/signature gear).
const GEAR_POOL := ["slimeglass_boots", "mossleaf_cap", "rootgrip_gloves", "trail_leggings", "hidebound_vest",
	"thornblade", "bloomstaff", "bramble_spear", "cinder_axe", "ember_ring", "moonheart_charm", "barkskin_charm", "gale_band"]

# ------------------------------------------------------------------ crafting
## needs: material -> qty. coins: optional fee. unlock: {"level": n} / {"flag": id} /
## {"quest": id}. station: "field" (anywhere, U) or "forge" (Bramble's forge only).
const RECIPES := [
	{"id": "thornblade_ii", "needs": {"wood": 3, "ore": 3}, "coins": 0, "station": "field", "unlock": {}, "requires_owned": "thornblade"},
	{"id": "briar_mail_ii", "needs": {"ore": 3, "herb": 2}, "coins": 0, "station": "field", "unlock": {}, "requires_owned": "briar_mail"},
	{"id": "moontea_vial", "needs": {"herb": 2, "slime_gel": 1}, "coins": 0, "station": "field", "unlock": {}, "qty": 1},
	{"id": "bramble_spear", "needs": {"wood": 4, "ore": 2}, "coins": 10, "station": "forge", "unlock": {}},
	{"id": "slimeglass_boots", "needs": {"slime_gel": 4, "beast_hide": 1}, "coins": 5, "station": "forge", "unlock": {}},
	{"id": "hidebound_vest", "needs": {"beast_hide": 4, "venom_sac": 1}, "coins": 20, "station": "forge", "unlock": {"level": 3}},
	{"id": "cinder_axe", "needs": {"ore": 4, "ember_core": 2, "wood": 2}, "coins": 30, "station": "forge", "unlock": {"level": 5}},
	{"id": "rift_treads", "needs": {"bat_wing": 4, "spirit_dust": 2, "beast_hide": 2}, "coins": 60, "station": "forge", "unlock": {"flag": "rift_cleared"}},
	{"id": "petalbreaker", "needs": {"ore": 6, "bone_shard": 4, "spirit_dust": 2}, "coins": 90, "station": "forge", "unlock": {"level": 8}},
	{"id": "starfall_crown", "needs": {"moon_shard": 3, "spirit_dust": 4, "ember_core": 2}, "coins": 150, "station": "forge", "unlock": {"recipe": "recipe_crown"}},
	{"id": "moonwell_aegis", "needs": {"moon_shard": 3, "ore": 8, "bone_shard": 4}, "coins": 160, "station": "forge", "unlock": {"recipe": "recipe_aegis"}},
	{"id": "direwolf_claws", "needs": {"beast_hide": 5, "bone_shard": 3, "venom_sac": 2}, "coins": 70, "station": "forge", "unlock": {"level": 5}},
	{"id": "twin_moon_katanas", "needs": {"ore": 5, "ember_core": 3, "moon_shard": 1}, "coins": 120, "station": "forge", "unlock": {"boss": "emberbark"}},
	{"id": "cloudstride_staff", "needs": {"moon_shard": 4, "spirit_dust": 4, "wood": 6}, "coins": 250, "station": "forge", "unlock": {"recipe": "recipe_cloudstride"}},
	{"id": "moonwell_blade", "needs": {"moon_shard": 4, "ore": 6, "spirit_dust": 3}, "coins": 180, "station": "forge", "unlock": {"boss": "warden"}},
]

# ------------------------------------------------------------------ shops
## stock: price, limit (-1 = unlimited, n = per save), unlock like recipes.
## sell: which item types the merchant buys (at SELL_RATE of value).
const SELL_RATE := 0.5
const SHOPS := {
	"pip": {"name": "Pip's Provisions", "service": "Weapons, gear & supplies", "sell": ["material", "gear"],
		"stock": [
			{"id": "thornblade", "price": 30, "limit": 1},
			{"id": "bloomstaff", "price": 35, "limit": 1},
			{"id": "oakwood_staff", "price": 30, "limit": 1},
			{"id": "moontea_vial", "price": 14, "limit": -1},
			{"id": "fishing_rod", "price": 60, "limit": 1},
			{"id": "mossleaf_cap", "price": 45, "limit": 1},
			{"id": "rootgrip_gloves", "price": 50, "limit": 1},
			{"id": "trail_leggings", "price": 45, "limit": 1},
			{"id": "briar_mail", "price": 55, "limit": 1, "unlock": {"level": 2}},
			{"id": "gale_bow", "price": 90, "limit": 1, "unlock": {"level": 4}},
			{"id": "heart_piece", "price": 150, "limit": 1},
		],
		"exchanges": [
			{"give": {"slime_gel": 5}, "get": "moontea_vial", "qty": 1},
			{"give": {"bat_wing": 3, "beast_hide": 3}, "get": "coins", "qty": 40},
		]},
	"bramble": {"name": "Bramble's Forge", "service": "Crafting & monster-part trades", "sell": ["material"], "forge": true,
		"stock": [
			{"id": "ironroot_hammer", "price": 160, "limit": 1, "unlock": {"level": 4}},
			{"id": "barkskin_charm", "price": 95, "limit": 1, "unlock": {"level": 3}},
			{"id": "ironbloom_gauntlet", "price": 140, "limit": 1, "unlock": {"level": 3}},
		],
		"exchanges": [
			{"give": {"bone_shard": 6, "spirit_dust": 2}, "get": "recipe_crown", "qty": 1, "unlock": {"flag": "rift_cleared"}},
			{"give": {"ember_core": 5, "bone_shard": 5}, "get": "recipe_aegis", "qty": 1, "unlock": {"level": 6}},
			{"give": {"venom_sac": 3}, "get": "coins", "qty": 30},
			{"give": {"moon_shard": 1}, "get": "rift_key", "qty": 1},
			{"give": {"moon_shard": 2, "ember_core": 4}, "get": "recipe_cloudstride", "qty": 1, "unlock": {"flag": "emberbark_felled"}},
		]},
	"nomad": {"name": "Dune Nomad", "service": "Rare goods", "sell": ["material", "gear"],
		"stock": [
			{"id": "moontea_vial", "price": 16, "limit": -1},
			{"id": "starlocket", "price": 300, "limit": 1},
			{"id": "heart_piece", "price": 220, "limit": 1},
			{"id": "gale_band", "price": 260, "limit": 1},
			{"id": "starweave_gloves", "price": 280, "limit": 1},
			{"id": "twilight_mantle", "price": 380, "limit": 1},
			{"id": "spellblade_sash", "price": 380, "limit": 1},
		],
		"exchanges": [{"give": {"ember_core": 4}, "get": "coins", "qty": 45}]},
	"kaede": {"name": "Kaede's Armoury", "service": "Class weapons & armour", "sell": ["gear"],
		"stock": [
			{"id": "moontea_vial", "price": 15, "limit": -1},
			{"id": "duskfan", "price": 220, "limit": 1},
			{"id": "thornlash_whip", "price": 190, "limit": 1},
			{"id": "sunplate", "price": 260, "limit": 1},
			{"id": "heart_piece", "price": 200, "limit": 1},
			{"id": "ember_heart", "price": 280, "limit": 1},
			{"id": "shadow_wraps", "price": 240, "limit": 1},
			{"id": "frostlace_robe", "price": 240, "limit": 1},
			{"id": "cryptwarden_greaves", "price": 240, "limit": 1},
		],
		"exchanges": []},
}
## Recipe scrolls (granted by exchanges; unlock legendary recipes).
const RECIPE_SCROLLS := {
	"recipe_crown": {"name": "Recipe: Starfall Crown", "recipe": "starfall_crown"},
	"recipe_aegis": {"name": "Recipe: Moonwell Aegis", "recipe": "moonwell_aegis"},
	"recipe_cloudstride": {"name": "Recipe: Cloudstride Staff", "recipe": "cloudstride_staff"},
}
