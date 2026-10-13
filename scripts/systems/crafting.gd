extends RefCounted
## Crafting rules. A recipe is validated (unlock, station, ingredients, fee,
## room for the result) before anything is consumed; ingredients and coins are
## then removed exactly once and the result granted. Failure changes nothing.

const Eco := preload("res://scripts/data/economy.gd")
const DBRef := preload("res://scripts/data/db.gd")
const Inv := preload("res://scripts/systems/inventory.gd")


static func recipe(id: String) -> Dictionary:
	for r in Eco.RECIPES:
		if r["id"] == id:
			return r
	return {}


static func unlock_reason(game: Node, r: Dictionary) -> String:
	var u: Dictionary = r.get("unlock", {})
	var p: Node = game.player
	if u.has("level") and p.level < int(u["level"]):
		return "Reach level %d." % int(u["level"])
	if u.has("flag") and not game.flags.get(String(u["flag"]), false):
		return "Clear a rift dungeon first." if u["flag"] == "rift_cleared" else "Locked."
	if u.has("recipe") and not game.flags.get("learned_" + String(u["recipe"]), false):
		return "Learn the recipe scroll (trade at Bramble's forge)."
	if u.has("boss") and not game.defeated_bosses.has(String(u["boss"])):
		return "Defeat the Quiet Warden."
	if r.has("requires_owned") and not p.owns(String(r["requires_owned"])):
		return "Needs a %s to temper." % DBRef.ITEMS[r["requires_owned"]]["name"]
	return ""


## "" if craftable now, else the reason shown in the UI.
static func block_reason(game: Node, r: Dictionary, at_forge: bool) -> String:
	if r.is_empty():
		return "Unknown recipe."
	var why := unlock_reason(game, r)
	if why != "":
		return why
	var p: Node = game.player
	var id: String = r["id"]
	if not Inv.is_stackable(id) and p.owns(id):
		return "Already crafted."
	if String(r.get("station", "field")) == "forge" and not at_forge:
		return "Craft this at Bramble's forge in Hearthgrove."
	if not Inv.has_all(p, r["needs"]):
		return "Need " + Inv.missing_text(p, r["needs"]) + "."
	if p.petalcoins < int(r.get("coins", 0)):
		return "Need %d petalcoins." % int(r.get("coins", 0))
	if Inv.is_stackable(id) and not Inv.can_add(p, id, int(r.get("qty", 1))):
		return "Your bag is full."
	return ""


static func craft(game: Node, id: String, at_forge: bool) -> Dictionary:
	var r := recipe(id)
	var why := block_reason(game, r, at_forge)
	if why != "":
		return {"ok": false, "reason": why}
	var p: Node = game.player
	if not Inv.remove_all(p, r["needs"]):
		return {"ok": false, "reason": "Missing ingredients."}
	p.petalcoins -= int(r.get("coins", 0))
	var ok: bool = p.give_item(id, int(r.get("qty", 1)))
	if not ok:
		# cannot happen after validation, but never eat ingredients on failure
		for k in r["needs"].keys():
			Inv.add(p, String(k), int(r["needs"][k]))
		p.petalcoins += int(r.get("coins", 0))
		return {"ok": false, "reason": "Could not add the item."}
	game.stats["crafted"] = int(game.stats.get("crafted", 0)) + 1
	return {"ok": true, "reason": ""}
