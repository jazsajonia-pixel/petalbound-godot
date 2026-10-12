extends RefCounted
## Journeys: a light quest system. Quests activate when you talk to their giver,
## track objectives through gameplay hooks, and pay out when you talk again.

const STATE_AVAILABLE := 0
const STATE_ACTIVE := 1
const STATE_DONE := 2
const STATE_CLAIMED := 3

## Objective "type" is one of: kills, moonpetals, talk (target npc id),
## boss, waystone (target shrine id), flag (target flag key).
const QUESTS := [
	{"id": "q_thorns", "giver": "alder", "name": "A Thicker Thicket", "desc": "Thin the blight: defeat 8 creatures, any eight.",
		"type": "kills", "goal": 8, "reward": {"coins": 40, "xp": 30}},
	{"id": "q_moongarden", "giver": "mira", "name": "Mira's Night Garden", "desc": "Gather 3 moonpetals under the night sky.",
		"type": "moonpetals", "goal": 3, "reward": {"coins": 30, "xp": 25, "item": "moontea"}},
	{"id": "q_locket", "giver": "kit", "name": "The Silver Locket", "desc": "Ask Hana by Lake Lumen about a silver locket.",
		"type": "talk", "target": "hana", "goal": 1, "reward": {"coins": 25, "xp": 20}},
	{"id": "q_watch", "giver": "kaede", "name": "Eyes on the Valley", "desc": "Best any one guardian boss and report back.",
		"type": "boss", "goal": 1, "reward": {"coins": 60, "xp": 40}},
	{"id": "q_starfall_sight", "giver": "lumen", "name": "Starfall Sight", "desc": "Rest at the Starfall Waystone and see what the stars show you.",
		"type": "waystone", "target": "starfall", "goal": 1, "reward": {"coins": 50, "xp": 30}},
	{"id": "q_crypt", "giver": "sora", "name": "The Hollow Crypt", "desc": "Something stirs under the graveyard in the marsh. Clear the Hollow Crypt.",
		"type": "flag", "target": "crypt_cleared", "goal": 1, "reward": {"coins": 80, "xp": 60, "item": "heart_piece"}},
]


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
	return ""


static func mark_done(quests: Dictionary, id: String) -> bool:
	var e: Dictionary = entry(quests, id)
	if e["s"] == STATE_ACTIVE and e["n"] >= int(def_of(id)["goal"]):
		e["s"] = STATE_DONE
		return true
	return false
