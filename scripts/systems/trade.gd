extends RefCounted
## NPC shop rules: buying (coins, stock limits, unlocks, class requirements,
## bag room), selling (merchant buys only listed types, never equipped gear or
## quest items) and material exchanges. Every action validates first and only
## then moves coins/items, so a failed transaction changes nothing.

const Eco := preload("res://scripts/data/economy.gd")
const DBRef := preload("res://scripts/data/db.gd")
const Inv := preload("res://scripts/systems/inventory.gd")
const Build := preload("res://scripts/combat/build.gd")
const Craft := preload("res://scripts/systems/crafting.gd")


static func shop(id: String) -> Dictionary:
	return Eco.SHOPS.get(id, {})


static func bought(game: Node, shop_id: String, item_id: String) -> int:
	return int(game.flags.get("bought_%s_%s" % [shop_id, item_id], 0))


static func value_of(id: String) -> int:
	var it: Dictionary = DBRef.ITEMS.get(id, {})
	if it.has("value"):
		return int(it["value"])
	return {"common": 20, "uncommon": 45, "rare": 90, "epic": 160, "legendary": 260}.get(String(it.get("rarity", "common")), 20)


static func sell_price(id: String) -> int:
	return maxi(1, int(round(value_of(id) * Eco.SELL_RATE)))


static func stock_left(game: Node, shop_id: String, entry: Dictionary) -> int:
	var lim := int(entry.get("limit", -1))
	if lim < 0:
		return -1
	return maxi(0, lim - bought(game, shop_id, String(entry["id"])))


static func buy_reason(game: Node, shop_id: String, entry: Dictionary) -> String:
	var p: Node = game.player
	var id: String = entry["id"]
	if not DBRef.ITEMS.has(id):
		return "Unavailable."
	var why := Craft.unlock_reason(game, {"unlock": entry.get("unlock", {})})
	if why != "":
		return why
	if stock_left(game, shop_id, entry) == 0:
		return "Sold out."
	if not Inv.is_stackable(id) and p.owns(id):
		return "Already owned."
	if not Build.item_classes(id).is_empty() and Build.item_reason(p, id) != "":
		return Build.item_reason(p, id)
	if Inv.is_stackable(id) and not Inv.can_add(p, id, 1):
		return "Your bag is full."
	if p.petalcoins < int(entry["price"]):
		return "Need %d more petalcoins." % (int(entry["price"]) - p.petalcoins)
	return ""


static func buy(game: Node, shop_id: String, entry: Dictionary) -> Dictionary:
	var why := buy_reason(game, shop_id, entry)
	if why != "":
		return {"ok": false, "reason": why}
	var p: Node = game.player
	var price := int(entry["price"])
	if not p.give_item(String(entry["id"])):
		return {"ok": false, "reason": "Could not take the item."}
	p.petalcoins -= price
	p.stats_changed.emit()
	var key := "bought_%s_%s" % [shop_id, String(entry["id"])]
	game.flags[key] = int(game.flags.get(key, 0)) + 1
	game.stats["purchases"] = int(game.stats.get("purchases", 0)) + 1
	return {"ok": true, "reason": ""}


## Items the player could sell here: [[id, count, price, reason], ...]
static func sellables(game: Node, shop_id: String) -> Array:
	var s := shop(shop_id)
	var types: Array = s.get("sell", [])
	var p: Node = game.player
	var out: Array = []
	if "material" in types:
		for e in Inv.listing(p):
			var t := String(DBRef.ITEMS[e[0]]["type"])
			if t == "material" or t == "consumable":
				out.append([e[0], e[1], sell_price(e[0]), ""])
	if "gear" in types:
		for id in p.inventory + p.real_weapons():
			var t2 := String(DBRef.ITEMS[id].get("type", ""))
			if t2 in ["tool", "key", "upgrade"]:
				continue
			out.append([id, 1, sell_price(id), sell_reason(game, shop_id, id)])
	return out


static func sell_reason(game: Node, shop_id: String, id: String) -> String:
	var p: Node = game.player
	var it: Dictionary = DBRef.ITEMS.get(id, {})
	if it.is_empty() or id == "fists":
		return "Can't sell that."
	var types: Array = shop(shop_id).get("sell", [])
	if String(it.get("type", "")) == "quest":
		return "Quest items can't be sold."
	if Inv.is_stackable(id):
		if not ("material" in types):
			return "This merchant doesn't buy materials."
		return "" if Inv.count(p, id) > 0 else "None left."
	if not ("gear" in types):
		return "This merchant doesn't buy gear."
	if p.equipped.values().has(id) or p.get_weapon_id() == id:
		return "Unequip it first."
	if not p.owns(id):
		return "Not owned."
	return ""


static func sell(game: Node, shop_id: String, id: String) -> Dictionary:
	var why := sell_reason(game, shop_id, id)
	if why != "":
		return {"ok": false, "reason": why}
	var p: Node = game.player
	if Inv.is_stackable(id):
		if not Inv.remove(p, id, 1):
			return {"ok": false, "reason": "None left."}
	elif p.weapons_owned.has(id):
		p.weapons_owned.erase(id)
		p.weapon_index = clampi(p.weapon_index, 0, p.weapons_owned.size() - 1)
		p.ensure_fists()
		p.refresh_held_weapon()
		p.inventory_changed.emit()
	else:
		p.inventory.erase(id)
		p.inventory_changed.emit()
	p.add_petalcoins(sell_price(id))
	return {"ok": true, "reason": ""}


static func exchange_reason(game: Node, ex: Dictionary) -> String:
	var p: Node = game.player
	var why := Craft.unlock_reason(game, {"unlock": ex.get("unlock", {})})
	if why != "":
		return why
	var get_id: String = ex["get"]
	if Eco.RECIPE_SCROLLS.has(get_id) and game.flags.get("learned_" + get_id, false):
		return "Already learned."
	if not Inv.has_all(p, ex["give"]):
		return "Need " + Inv.missing_text(p, ex["give"]) + "."
	if DBRef.ITEMS.has(get_id) and Inv.is_stackable(get_id) and not Inv.can_add(p, get_id, int(ex.get("qty", 1))):
		return "Your bag is full."
	return ""


static func exchange(game: Node, ex: Dictionary) -> Dictionary:
	var why := exchange_reason(game, ex)
	if why != "":
		return {"ok": false, "reason": why}
	var p: Node = game.player
	if not Inv.remove_all(p, ex["give"]):
		return {"ok": false, "reason": "Missing items."}
	var get_id: String = ex["get"]
	if get_id == "coins":
		p.add_petalcoins(int(ex.get("qty", 1)))
	elif Eco.RECIPE_SCROLLS.has(get_id):
		game.flags["learned_" + get_id] = true
	else:
		p.give_item(get_id, int(ex.get("qty", 1)))
	return {"ok": true, "reason": ""}


static func exchange_label(ex: Dictionary) -> String:
	var get_id: String = ex["get"]
	var got := ""
	if get_id == "coins":
		got = "%d petalcoins" % int(ex.get("qty", 1))
	elif Eco.RECIPE_SCROLLS.has(get_id):
		got = String(Eco.RECIPE_SCROLLS[get_id]["name"])
	else:
		got = "%d %s" % [int(ex.get("qty", 1)), DBRef.ITEMS[get_id]["name"]]
	return "%s  ->  %s" % [Inv.needs_text(ex["give"]), got]
