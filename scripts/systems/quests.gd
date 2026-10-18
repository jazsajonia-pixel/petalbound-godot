extends RefCounted
const DBQ := preload("res://scripts/data/db.gd")
## Journeys: a light quest system. Quests activate when you talk to their giver,
## track objectives through gameplay hooks, and pay out when you talk again.

const STATE_AVAILABLE := 0
const STATE_ACTIVE := 1
const STATE_DONE := 2
const STATE_CLAIMED := 3

## Objective "type" is one of:
##   kills (any), kill_kind (target = species prefix), kill_unarmed, elite,
##   moonpetals, talk (target npc), boss, rift_boss, waystone (target id),
##   flag (target key), collect (target item id, or any material), loot (gear
##   pickup), buy (any or target id), craft (any or target id), equip_weapon,
##   cast (petal arts), region (any region outside Hearthgrove), explore
##   (target interior id or "rift").
## "requires" = quest id that must be claimed first (chains). Unknown types are
## simply never progressed, so bad data cannot crash the game.
const QUESTS := [
	# ---- first steps (teach punching, loot, shopping, weapons, arts, exploring)
	{"id": "q_first_fists", "giver": "alder", "name": "First Fists", "desc": "No blade yet? Paws work. Defeat 3 creatures bare-pawed.",
		"type": "kill_unarmed", "goal": 3, "reward": {"coins": 20, "xp": 15}},
	{"id": "q_spoils", "giver": "alder", "requires": "q_first_fists", "name": "Pocket the Spoils", "desc": "Creatures drop materials. Pick up 3 of any kind.",
		"type": "collect", "goal": 3, "reward": {"coins": 20, "xp": 15}},
	{"id": "q_market", "giver": "pip", "requires": "q_spoils", "name": "Market Day", "desc": "Buy anything from Pip's Provisions (a Thornblade is 30 coins).",
		"type": "buy", "goal": 1, "reward": {"coins": 10, "xp": 10}},
	{"id": "q_arm", "giver": "pip", "requires": "q_market", "name": "Arm Yourself", "desc": "Open your satchel and equip a real weapon.",
		"type": "equip_weapon", "goal": 1, "reward": {"coins": 15, "xp": 15, "item": "herb", "qty": 2}},
	{"id": "q_arts", "giver": "alder", "requires": "q_arm", "name": "Petal Arts", "desc": "Use your class arts 5 times (the four big buttons).",
		"type": "cast", "goal": 5, "reward": {"coins": 20, "xp": 25}},
	{"id": "q_over_hill", "giver": "tallow", "requires": "q_arts", "name": "Over the Hill", "desc": "Walk beyond Hearthgrove into any wild region.",
		"type": "region", "goal": 1, "reward": {"coins": 25, "xp": 25}},
	# ---- the valley
	{"id": "q_thorns", "giver": "alder", "name": "A Thicker Thicket", "desc": "Thin the blight: defeat 8 creatures, any eight.",
		"type": "kills", "goal": 8, "reward": {"coins": 40, "xp": 30}},
	{"id": "q_moongarden", "giver": "mira", "name": "Mira's Night Garden", "desc": "Gather 3 moonpetals under the night sky.",
		"type": "moonpetals", "goal": 3, "reward": {"coins": 30, "xp": 25, "item": "moontea"}},
	{"id": "q_slimes", "giver": "mira", "requires": "q_moongarden", "name": "Lamp Gel", "desc": "Bring back 5 Slime Gel for the garden lamps.",
		"type": "collect", "target": "slime_gel", "goal": 5, "reward": {"coins": 35, "xp": 25}},
	{"id": "q_locket", "giver": "kit", "name": "The Silver Locket", "desc": "Ask Hana by Lake Lumen about a silver locket.",
		"type": "talk", "target": "hana", "goal": 1, "reward": {"coins": 25, "xp": 20}},
	{"id": "q_watch", "giver": "kaede", "name": "Eyes on the Valley", "desc": "Best any one guardian boss and report back.",
		"type": "boss", "goal": 1, "reward": {"coins": 60, "xp": 40}},
	{"id": "q_snakes", "giver": "kaede", "name": "Dune Patrol", "desc": "Defeat 6 snakes in the Sunscar Dunes.",
		"type": "kill_kind", "target": "snake", "goal": 6, "reward": {"coins": 45, "xp": 35}},
	{"id": "q_elite", "giver": "kaede", "requires": "q_watch", "name": "Gilded Prey", "desc": "Hunt down an elite creature (gold outline).",
		"type": "elite", "goal": 1, "reward": {"coins": 70, "xp": 50}},
	{"id": "q_forge", "giver": "bramble", "name": "Forge Debut", "desc": "Craft anything at Bramble's Forge or in the field.",
		"type": "craft", "goal": 1, "reward": {"coins": 25, "xp": 20, "item": "ore", "qty": 3}},
	{"id": "q_starfall_sight", "giver": "lumen", "name": "Starfall Sight", "desc": "Rest at the Starfall Waystone and see what the stars show you.",
		"type": "waystone", "target": "starfall", "goal": 1, "reward": {"coins": 50, "xp": 30}},
	{"id": "q_rift", "giver": "lumen", "name": "Mend a Rift", "desc": "Rifts tear open at random (watch your map). Defeat a Rift Warden.",
		"type": "rift_boss", "goal": 1, "reward": {"coins": 90, "xp": 70}},
	# ---- Emberleaf Vale (Rowan at Cinderbrook Camp)
	{"id": "q_ember_patrol", "giver": "rowan", "name": "Ember Patrol", "desc": "Defeat 5 Ember Spiders around Cinderbrook Camp.",
		"type": "kill_kind", "target": "spiderred", "goal": 5, "reward": {"coins": 60, "xp": 45}},
	{"id": "q_ember_cores", "giver": "rowan", "name": "Banked Embers", "desc": "Bring 3 Ember Cores (glowing ore rocks, Cinder Wisps).",
		"type": "collect", "target": "ember_core", "goal": 3, "reward": {"coins": 70, "xp": 50, "item": "ore", "qty": 3}},
	{"id": "q_emberbark", "giver": "rowan", "requires": "q_ember_patrol", "name": "Fell the Emberbark", "desc": "Defeat the Emberbark in its hollow north of camp.",
		"type": "flag", "target": "emberbark_felled", "goal": 1, "reward": {"coins": 120, "xp": 90, "item": "moon_shard", "qty": 1}},
	# ---- Saltbloom Shoals (Old Marlo in Brinewick)
	{"id": "q_salt_lines", "giver": "marlo", "name": "Cut Lines", "desc": "Defeat 5 Coral Crawlers on the Saltbloom beaches.",
		"type": "kill_kind", "target": "mollusc", "goal": 5, "reward": {"coins": 80, "xp": 60}},
	{"id": "q_salt_pearls", "giver": "marlo", "name": "Pearls for the Nets", "desc": "Bring 3 Brine Pearls (Saltbloom's coast creatures carry them).",
		"type": "collect", "target": "brine_pearl", "goal": 3, "reward": {"coins": 90, "xp": 60, "item": "moontea_vial", "qty": 2}},
	{"id": "q_brinehorn", "giver": "marlo", "requires": "q_salt_lines", "name": "Still the Brinehorn", "desc": "Defeat the Brinehorn on the reef south of Brinewick.",
		"type": "flag", "target": "brinehorn_felled", "goal": 1, "reward": {"coins": 150, "xp": 120, "item": "moon_shard", "qty": 2}},
	{"id": "q_crypt", "giver": "sora", "name": "The Hollow Crypt", "desc": "Something stirs under the graveyard in the marsh. Clear the Hollow Crypt.",
		"type": "flag", "target": "crypt_cleared", "goal": 1, "reward": {"coins": 80, "xp": 60, "item": "heart_piece"}},
]


static func is_unlocked(quests: Dictionary, q: Dictionary) -> bool:
	var req := String(q.get("requires", ""))
	return req == "" or int(entry(quests, req)["s"]) == STATE_CLAIMED


## Marker above an NPC: "!" new journey, "?" ready to claim, "..." in progress.
static func marker_for(quests: Dictionary, npc_id: String) -> String:
	var best := ""
	for q in QUESTS:
		if q["giver"] != npc_id:
			continue
		var s := int(entry(quests, q["id"])["s"])
		if s == STATE_DONE:
			return "?"
		if s == STATE_AVAILABLE and is_unlocked(quests, q):
			best = "!"
		elif s == STATE_ACTIVE and best == "":
			best = "..."
	return best


## Does a progress event match this quest's objective?
static func matches(q: Dictionary, type: String, key: String) -> bool:
	if q["type"] != type:
		return false
	if not q.has("target"):
		if type == "collect":
			return key != "" and String(DBQ.ITEMS.get(key, {}).get("type", "")) == "material"
		return true
	var t := String(q["target"])
	if type == "kill_kind":
		return key.begins_with(t)
	return t == key


static func def_of(id: String) -> Dictionary:
	for q in QUESTS:
		if q["id"] == id:
			return q
	return {}


static func quests_by_giver(giver: String) -> Array:
	var out: Array = []
	for q in QUESTS:
		if q["giver"] == giver:
			out.append(q)
	return out


static func entry(quests: Dictionary, id: String) -> Dictionary:
	if not quests.has(id):
		quests[id] = {"s": STATE_AVAILABLE, "n": 0}
	return quests[id]


static func tracker_text(quests: Dictionary) -> String:
	for q in QUESTS:
		var e: Dictionary = entry(quests, q["id"])
		if e["s"] == STATE_ACTIVE:
			return "%s  %d/%d" % [q["name"], e["n"], q["goal"]]
		if e["s"] == STATE_DONE:
			return "%s: report to %s" % [q["name"], String(q["giver"]).capitalize()]
	return ""


static func mark_done(quests: Dictionary, id: String) -> bool:
	var e: Dictionary = entry(quests, id)
	if e["s"] == STATE_ACTIVE and e["n"] >= int(def_of(id)["goal"]):
		e["s"] = STATE_DONE
		return true
	return false
