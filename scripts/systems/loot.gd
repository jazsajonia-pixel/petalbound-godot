extends RefCounted
## Enemy loot: configurable tables per species group (scripts/data/economy.gd),
## elite bonuses and a pity counter for equipment. roll() is pure (takes an
## RNG) so tests can check distributions; drop() spawns ground pickups once
## per death (enemy.loot_dropped guards repeats).

const Eco := preload("res://scripts/data/economy.gd")
const DBRef := preload("res://scripts/data/db.gd")


## Returns {"items": [[id, qty], ...], "gear": id or ""}.
static func roll(species: String, elite: bool, pity: int, owned: Callable, rng: RandomNumberGenerator) -> Dictionary:
	var out := {"items": [], "gear": ""}
	var group: String = Eco.LOOT_GROUP.get(species, "beast")
	for e in Eco.LOOT.get(group, []):
		if rng.randf() < float(e[1]):
			out["items"].append([String(e[0]), rng.randi_range(int(e[2]), int(e[3]))])
	if elite:
		for e in Eco.ELITE_BONUS:
			if rng.randf() < float(e[1]):
				out["items"].append([String(e[0]), rng.randi_range(int(e[2]), int(e[3]))])
		out["items"].append([Eco.ELITE_GUARANTEE[rng.randi() % Eco.ELITE_GUARANTEE.size()], 1])
	var chance := Eco.GEAR_CHANCE_ELITE if elite else Eco.GEAR_CHANCE
	if pity >= Eco.GEAR_PITY or rng.randf() < chance:
		out["gear"] = pick_gear(owned, rng, pity >= Eco.GEAR_PITY)
	return out


## Rarity-weighted pick from the field pool, preferring gear not yet owned.
static func pick_gear(owned: Callable, rng: RandomNumberGenerator, pity := false) -> String:
	var weights := Eco.GEAR_RARITY_WEIGHTS.duplicate()
	if pity:
		weights["common"] = 0  # pity drops are at least uncommon
	var total := 0
	for r in weights.keys():
		total += int(weights[r])
	var pick := rng.randi_range(1, maxi(1, total))
	var rarity := "common"
	for r in DBRef.RARITIES:
		if not weights.has(r):
			continue
		pick -= int(weights[r])
		if pick <= 0:
			rarity = r
			break
	var pool: Array = []
	var fallback: Array = []
	for id in Eco.GEAR_POOL:
		if String(DBRef.ITEMS[id].get("rarity", "common")) != rarity and not (pity and rarity == "epic"):
			continue
		fallback.append(id)
		if not owned.call(id):
			pool.append(id)
	if pool.is_empty():
		pool = fallback
	if pool.is_empty():
		for id in Eco.GEAR_POOL:
			if not owned.call(id):
				pool.append(id)
	if pool.is_empty():
		return ""
	return pool[rng.randi() % pool.size()]
