extends RefCounted
## Build rules shared by the player, HUD, save system and tests.
## - Line ranks and the art (skill) unlock / upgrade rules.
## - Equipment and weapon class compatibility, with readable refusal reasons.
## - A pure stat aggregator: stats are always recomputed from scratch from the
##   current state, so gear/tree/class bonuses can never be applied twice.

const ClassBook := preload("res://scripts/data/classdb.gd")
const DB := preload("res://scripts/data/db.gd")
const CD := preload("res://scripts/data/combat_data.gd")

const STAT_KEYS := ["atk", "atk_speed", "crit", "hearts", "defense", "speed", "cdr", "elem", "focus",
	"lifesteal", "ranged_bonus", "poise", "stamina_regen", "heal_power"]
## Stats that are whole numbers (class attributes are floored for secondaries).
const INT_STATS := ["atk", "hearts", "defense", "focus", "ranged_bonus"]


# ------------------------------------------------------------------ lines
static func rank(p: Object, cls: String) -> int:
	if not p.classes.has(cls):
		return 0
	var nodes: Dictionary = p.class_nodes.get(cls, {})
	return clampi(1 + nodes.size(), 1, ClassBook.MAX_RANK)


static func class_display(cls: String) -> String:
	return String(ClassBook.class_of(cls).get("name", cls.capitalize()))


## Why a line cannot be bound right now ("" = it can).
static func bind_reason(p: Object, cls: String) -> String:
	if not ClassBook.CLASSES.has(cls):
		return "Unknown line."
	if p.classes.has(cls):
		return "Already bound."
	if p.classes.size() >= ClassBook.MAX_CLASSES:
		return "Two lines already bound. Release the secondary first."
	if p.classes.size() == 1 and p.level < ClassBook.COMBINE_LEVEL:
		return "Combine a second line at level %d." % ClassBook.COMBINE_LEVEL
	return ""


# ------------------------------------------------------------------ arts
static func skill_level(p: Object, id: String) -> int:
	return clampi(int(p.skill_levels.get(id, 1)), 1, ClassBook.SKILL_MAX_LEVEL)


## Why an art cannot be slotted ("" = unlocked).
static func skill_lock_reason(p: Object, id: String) -> String:
	var d: Dictionary = ClassBook.skill_of(id)
	if d.is_empty():
		return "Unknown art."
	var cls: String = d.get("class", "")
	if cls == "":
		return ""
	if not p.classes.has(cls):
		return "Bind the %s line." % class_display(cls)
	var need := int(d.get("unlock", 1))
	if rank(p, cls) < need:
		return "Needs %s rank %d (learn %d tree node%s)." % [class_display(cls), need, need - 1, "s" if need - 1 != 1 else ""]
	return ""


static func is_skill_unlocked(p: Object, id: String) -> bool:
	return skill_lock_reason(p, id) == ""


## Every art the player could put in a slot right now, wanderer arts last.
static func eligible_skills(p: Object) -> Array:
	var out: Array = []
	for cls in p.classes:
		for sid in ClassBook.class_of(cls).get("skills", []):
			if is_skill_unlocked(p, sid) and not out.has(sid):
				out.append(sid)
	for sid in ClassBook.WANDERER_SKILLS:
		if not out.has(sid):
			out.append(sid)
	return out


## Arts to list in the loadout screen: unlocked ones plus locked arts of bound lines.
static func listed_skills(p: Object) -> Array:
	var out: Array = []
	for cls in p.classes:
		for sid in ClassBook.class_of(cls).get("skills", []):
			if not out.has(sid):
				out.append(sid)
	for sid in ClassBook.WANDERER_SKILLS:
		if not out.has(sid):
			out.append(sid)
	return out


## An art stat after upgrades. Damage +dmg_step/level, cooldown -10%/level,
## heal +25%/level, radius +8%/level, cost unchanged.
static func skill_stat(p: Object, id: String, key: String, fallback: Variant = 0) -> Variant:
	var d: Dictionary = ClassBook.skill_of(id)
	if not d.has(key):
		return fallback
	var lv := skill_level(p, id) - 1
	var v = d[key]
	match key:
		"dmg":
			return int(v) + lv * int(d.get("dmg_step", 1))
		"cd":
			return float(v) * (1.0 - 0.10 * float(lv))
		"heal":
			return float(v) * (1.0 + 0.25 * float(lv))
		"radius":
			return float(v) * (1.0 + 0.08 * float(lv))
	return v


static func upgrade_cost(p: Object, id: String) -> int:
	return skill_level(p, id)


## Why an art cannot be upgraded ("" = it can).
static func upgrade_reason(p: Object, id: String) -> String:
	var lock := skill_lock_reason(p, id)
	if lock != "":
		return lock
	var lv := skill_level(p, id)
	if lv >= ClassBook.SKILL_MAX_LEVEL:
		return "Mastered."
	var d: Dictionary = ClassBook.skill_of(id)
	var cls: String = d.get("class", "")
	if cls != "" and rank(p, cls) < lv + 1:
		return "Level %d needs %s rank %d." % [lv + 1, class_display(cls), lv + 1]
	if cls == "" and p.level < 4 * lv:
		return "Level %d needs wanderer level %d." % [lv + 1, 4 * lv]
	var cost := upgrade_cost(p, id)
	if p.skill_points < cost:
		return "Needs %d art point%s." % [cost, "s" if cost != 1 else ""]
	return ""


## Validate a loadout: drop locked or duplicate arts, keep exactly four slots.
static func sanitize_loadout(p: Object, bar: Array) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	for i in range(4):
		var sid := String(bar[i]) if i < bar.size() else ""
		if sid != "" and (seen.has(sid) or not is_skill_unlocked(p, sid)):
			sid = ""
		if sid != "":
			seen[sid] = true
		out.append(sid)
	return out


# ------------------------------------------------------------------ equipment
static func item_classes(id: String) -> Array:
	return DB.ITEMS.get(id, {}).get("classes", [])


static func requirement_text(id: String) -> String:
	var cl: Array = item_classes(id)
	if cl.is_empty():
		return "Any line"
	var names := PackedStringArray()
	for c in cl:
		names.append(class_display(c))
	if bool(DB.ITEMS.get(id, {}).get("requires_all", false)):
		return " + ".join(names) + " (hybrid)"
	return " or ".join(names)


## Why an item or weapon cannot be equipped with the current lines ("" = it can).
static func item_reason(p: Object, id: String) -> String:
	var item: Dictionary = DB.ITEMS.get(id, {})
	if item.is_empty():
		return "Unknown item."
	var t: String = item.get("type", "")
	if t == "weapon":
		if not p.weapons_owned.has(id):
			return "Not owned."
	elif not t in DB.EQUIP_SLOTS:
		return "Not equipment."
	elif not p.inventory.has(id):
		return "Not owned."
	var cl: Array = item.get("classes", [])
	if cl.is_empty():
		return ""
	if bool(item.get("requires_all", false)):
		var missing := PackedStringArray()
		for c in cl:
			if not p.classes.has(c):
				missing.append(class_display(c))
		if missing.size() > 0:
			return "Hybrid gear: bind %s (missing %s)." % [requirement_text(id).replace(" (hybrid)", ""), ", ".join(missing)]
		return ""
	for c in cl:
		if p.classes.has(c):
			return ""
	return "Requires the %s line." % requirement_text(id)


static func can_equip(p: Object, id: String) -> bool:
	return item_reason(p, id) == ""


static func item_stats(id: String) -> Dictionary:
	var item: Dictionary = DB.ITEMS.get(id, {})
	var out: Dictionary = {}
	for k in STAT_KEYS:
		if item.has(k) and float(item[k]) != 0.0:
			out[k] = float(item[k])
	return out


## Stat delta lines for the compare panel: candidate vs what is in its slot now.
static func compare_lines(p: Object, id: String) -> Array:
	var item: Dictionary = DB.ITEMS.get(id, {})
	var slot: String = item.get("type", "")
	var cur_id: String = ""
	if slot == "weapon":
		cur_id = p.get_weapon_id()
	else:
		cur_id = String(p.equipped.get(slot, ""))
	var a := item_stats(id)
	var b := item_stats(cur_id) if cur_id != "" and cur_id != id else {}
	var lines: Array = []
	if slot == "weapon":
		var da := int(item.get("damage", 0))
		var db := int(DB.ITEMS.get(cur_id, {}).get("damage", 0))
		if cur_id != id:
			lines.append({"text": "%d damage (%s%d)" % [da, "+" if da - db >= 0 else "", da - db], "delta": da - db})
		else:
			lines.append({"text": "%d damage" % da, "delta": 0})
	var keys: Array = a.keys()
	for k in b.keys():
		if not keys.has(k):
			keys.append(k)
	for k in keys:
		var dv := float(a.get(k, 0.0)) - float(b.get(k, 0.0))
		if cur_id == id:
			dv = float(a.get(k, 0.0))
		if absf(dv) < 0.0001:
			continue
		lines.append({"text": CD.format_stat(k, dv), "delta": dv})
	return lines


# ------------------------------------------------------------------ stats
static func empty_stats() -> Dictionary:
	var s: Dictionary = {}
	for k in STAT_KEYS:
		s[k] = 0.0
	return s


## The single source of truth for passive stats. Order: tree nodes (bound lines
## only), line rank attributes (primary full, secondary half), dual-line synergy,
## then every equipped item that is still compatible. Buffs are applied live by
## the player on top of this snapshot.
static func compute_stats(p: Object) -> Dictionary:
	var s := empty_stats()
	for cls in p.classes:
		var tree: Dictionary = ClassBook.class_of(cls).get("tree", {})
		for nid in p.class_nodes.get(cls, {}):
			var eff: Dictionary = tree.get(nid, {}).get("effect", {})
			for k in eff:
				var key := "cdr" if k == "cd" else String(k)
				s[key] = float(s.get(key, 0.0)) + float(eff[k])
	for i in range(p.classes.size()):
		var cls: String = p.classes[i]
		var scale := 1.0 if i == 0 else ClassBook.SECONDARY_ATTR_SCALE
		var r := rank(p, cls)
		var attrs: Dictionary = ClassBook.class_of(cls).get("attrs", {})
		for k in attrs:
			var arr: Array = attrs[k]
			var v := float(arr[clampi(r - 1, 0, arr.size() - 1)]) * scale
			if k in INT_STATS:
				v = floorf(v)
			s[k] = float(s.get(k, 0.0)) + v
	if p.classes.size() >= 2:
		s["atk"] = float(s["atk"]) + 1.0  # dual-line synergy
	for slot in p.equipped:
		var id := String(p.equipped[slot])
		if not can_equip(p, id):
			continue
		var st := item_stats(id)
		for k in st:
			s[k] = float(s.get(k, 0.0)) + float(st[k])
	return s


## Items in `equipped` that the current lines no longer allow.
static func invalid_equipped(p: Object) -> Array:
	var out: Array = []
	for slot in p.equipped:
		if not can_equip(p, String(p.equipped[slot])):
			out.append(String(p.equipped[slot]))
	return out
