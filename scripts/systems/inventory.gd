extends RefCounted
## The bag: stackable items (materials, consumables, quest items) as
## id -> count on player.bag. Gear stays unique in player.inventory /
## player.weapons_owned. All mutations go through here so capacity and stack
## limits are enforced in one place.

const DBRef := preload("res://scripts/data/db.gd")


static func is_stackable(id: String) -> bool:
	return String(DBRef.ITEMS.get(id, {}).get("type", "")) in DBRef.STACKABLE


static func count(p: Node, id: String) -> int:
	return int(p.bag.get(id, 0))


static func stacks_used(p: Node) -> int:
	var n := 0
	for k in p.bag.keys():
		if int(p.bag[k]) > 0:
			n += 1
	return n


## How many of `id` would fit right now.
static func room_for(p: Node, id: String) -> int:
	if not is_stackable(id):
		return 0
	var have := count(p, id)
	if have > 0:
		return DBRef.STACK_MAX - have
	return DBRef.STACK_MAX if stacks_used(p) < DBRef.BAG_SLOTS else 0


static func can_add(p: Node, id: String, qty: int) -> bool:
	return qty > 0 and room_for(p, id) >= qty


## Adds up to `qty`; returns how many were actually added (0 = bag full).
static func add(p: Node, id: String, qty: int) -> int:
	if qty <= 0 or not DBRef.ITEMS.has(id):
		return 0
	var n := mini(qty, room_for(p, id))
	if n <= 0:
		return 0
	p.bag[id] = count(p, id) + n
	p.inventory_changed.emit()
	return n


## Removes exactly `qty` or nothing.
static func remove(p: Node, id: String, qty: int) -> bool:
	if qty <= 0 or count(p, id) < qty:
		return false
	var left := count(p, id) - qty
	if left <= 0:
		p.bag.erase(id)
	else:
		p.bag[id] = left
	p.inventory_changed.emit()
	return true


static func has_all(p: Node, needs: Dictionary) -> bool:
	for k in needs.keys():
		if count(p, String(k)) < int(needs[k]):
			return false
	return true


## Removes every listed item atomically (checks first).
static func remove_all(p: Node, needs: Dictionary) -> bool:
	if not has_all(p, needs):
		return false
	for k in needs.keys():
		remove(p, String(k), int(needs[k]))
	return true


static func missing_text(p: Node, needs: Dictionary) -> String:
	var parts: Array = []
	for k in needs.keys():
		var have := count(p, String(k))
		if have < int(needs[k]):
			parts.append("%d more %s" % [int(needs[k]) - have, DBRef.ITEMS[k]["name"]])
	return ", ".join(parts)


static func needs_text(needs: Dictionary) -> String:
	var parts: Array = []
	for k in needs.keys():
		parts.append("%d %s" % [int(needs[k]), DBRef.ITEMS[k]["name"]])
	return ", ".join(parts)


## Sorted bag listing for UI: [[id, count], ...] by type then rarity then name.
static func listing(p: Node) -> Array:
	var out: Array = []
	for k in p.bag.keys():
		if int(p.bag[k]) > 0 and DBRef.ITEMS.has(k):
			out.append([String(k), int(p.bag[k])])
	out.sort_custom(func(a, b) -> bool:
		var ia: Dictionary = DBRef.ITEMS[a[0]]
		var ib: Dictionary = DBRef.ITEMS[b[0]]
		if ia["type"] != ib["type"]:
			return String(ia["type"]) < String(ib["type"])
		var ra := DBRef.RARITIES.find(String(ia.get("rarity", "common")))
		var rb := DBRef.RARITIES.find(String(ib.get("rarity", "common")))
		if ra != rb:
			return ra > rb
		return String(ia["name"]) < String(ib["name"]))
	return out
