extends RefCounted
## Build screens drawn into existing HUD overlays:
##  - Petal Arts (K): four-slot loadout + art list with upgrade, then the class
##    lines with rank, attributes, unlock path, bind / release / make primary.
##  - Satchel (I/B): paper-doll slots, item grid with rarity and class checks,
##    detail + comparison panel, equip / unequip.

const ClassBook := preload("res://scripts/data/classdb.gd")
const DB := preload("res://scripts/data/db.gd")
const CD := preload("res://scripts/data/combat_data.gd")
const RUI := preload("res://scripts/ui/rarity_ui.gd")
const Inv := preload("res://scripts/systems/inventory.gd")
const Build := preload("res://scripts/combat/build.gd")
const AnimLib := preload("res://scripts/core/anim_lib.gd")

const C_BAD := Color(1.0, 0.5, 0.5)
const C_GOOD := Color(0.6, 1.0, 0.65)


static func _spacer(parent: Control) -> void:
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(sp)


static func _wrap(hud: Control, text: String, color: Color, parent: Control, width := 300.0) -> Label:
	var l: Label = hud._label(text, 8, color, parent)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(width, 0)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


static func _icon_button(hud: Control, tex_path: String, parent: Control, cb: Callable, sz := 24.0) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(sz, sz)
	if tex_path != "":
		b.icon = AnimLib.tex(tex_path)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


# ------------------------------------------------------------------ petal arts
static func refresh_arts(hud: Control) -> void:
	var list: VBoxContainer = hud.arts_list
	var classes: VBoxContainer = hud.class_list
	for c in list.get_children():
		c.queue_free()
	for c in classes.get_children():
		c.queue_free()
	var p: Node = hud.game.player
	hud.arts_head_label.text = "FIELD GUIDE  ·  LV %d  ·  %d ART POINTS" % [p.level, p.skill_points]
	var refresh := func() -> void: refresh_arts(hud)
	# ---- skills and loadout: this page never contains class trees
	hud._label("YOUR FOUR ACTIVE ARTS", 10, hud.C_GOLD, list)
	hud._label("Choose an empty slot, then assign an unlocked art below. Tap an occupied slot to select it.", 8, hud.C_DIM, list)
	var slots: HBoxContainer = hud._hbox(list, 4)
	for i in range(4):
		var sid: String = p.skill_bar[i] if i < p.skill_bar.size() else ""
		var def: Dictionary = ClassBook.skill_of(sid)
		var box := PanelContainer.new()
		var sel: bool = hud.loadout_slot == i
		box.add_theme_stylebox_override("panel", hud._box(Color(0.30, 0.18, 0.32, 0.95) if sel else Color(0.12, 0.09, 0.17, 0.9), hud.C_GOLD if sel else Color(0.5, 0.42, 0.58), 1, 3))
		slots.add_child(box)
		var row: HBoxContainer = hud._hbox(box, 3)
		var b := _icon_button(hud, def.get("icon", ""), row, func() -> void:
			hud.loadout_slot = i
			refresh.call(), 22.0)
		b.name = "LoadoutSlot%d" % i
		var col: VBoxContainer = hud._vbox(row, 0)
		hud._label("SLOT %d" % (i + 1), 8, hud.C_DIM, col)
		var nm: Label = hud._label(String(def.get("name", "— empty —")), 8, hud.C_TEXT, col)
		nm.custom_minimum_size = Vector2(68, 0)
	var rid: String = p.relic_id()
	var relic_line := "Relic slot: %s" % ("none — equip a relic in the satchel" if rid == "" else "%s — %s" % [CD.RELICS[rid]["name"], CD.RELICS[rid]["desc"]])
	_wrap(hud, relic_line + "  ·  Relics use their own button / V key.", hud.C_DIM, list, 500)
	hud._label("AVAILABLE ARTS  ·  grey entries explain their unlock requirement", 9, hud.C_GOLD, list)
	for sid in Build.listed_skills(p):
		_art_row(hud, p, sid, list, refresh)
	hud._label("Controls: keys 1–4 cast · K opens this guide.", 8, hud.C_DIM, list)
	# ---- classes: dedicated table so binding/rank/trees are not mixed with arts
	hud._label("CLASS LINES  ·  bind a primary line; at level %d you may add one secondary." % ClassBook.COMBINE_LEVEL, 10, hud.C_GOLD, classes)
	hud._label("Primary attributes are full strength; secondary attributes are half strength. You can change your mind without losing progress.", 8, hud.C_DIM, classes)
	for cid in ClassBook.CLASSES:
		_line_panel(hud, p, cid, classes, refresh)


static func _art_row(hud: Control, p: Node, sid: String, list: Control, refresh: Callable) -> void:
	var def: Dictionary = ClassBook.skill_of(sid)
	var lock: String = Build.skill_lock_reason(p, sid)
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", hud._box(Color(0.10, 0.08, 0.15, 0.85), Color(0.35, 0.3, 0.42), 1, 2))
	list.add_child(box)
	var row: HBoxContainer = hud._hbox(box, 5)
	var ic: TextureRect = hud._icon(def["icon"], Vector2(16, 16), row)
	if lock != "":
		ic.modulate = Color(0.5, 0.5, 0.55)
	var col: VBoxContainer = hud._vbox(row, 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var lv: int = Build.skill_level(p, sid)
	var cls: String = def.get("class", "")
	var head := "%s  Lv %d/%d   %s · %s" % [def["name"], lv, ClassBook.SKILL_MAX_LEVEL,
		Build.class_display(cls) if cls != "" else "Wanderer", ClassBook.aim_label(String(def.get("aim", "tap")))]
	hud._label(head, 8, Color(String(def.get("tint", "ffffff"))) if lock == "" else hud.C_DIM, col)
	var facts := PackedStringArray()
	if def.has("dmg"):
		facts.append("%d dmg" % int(Build.skill_stat(p, sid, "dmg", 0)))
	var el := String(def.get("element", ""))
	if el != "":
		facts.append(CD.ELEMENT_NAMES[el])
	facts.append("%d focus" % int(def.get("cost", 0)))
	facts.append("%.1fs cd" % (float(Build.skill_stat(p, sid, "cd", 0.0)) * p.skill_cd_scale()))
	if def.has("range"):
		facts.append("range %d" % int(p.skill_range(sid)))
	_wrap(hud, def["desc"] + "  [" + " · ".join(facts) + "]", hud.C_TEXT if lock == "" else hud.C_DIM, col, 280)
	if lock != "":
		hud._label("LOCKED: " + lock, 8, C_BAD, col)
	var btns: VBoxContainer = hud._vbox(row, 2)
	var in_slot: int = p.skill_bar.find(sid)
	var slot_b: Button = hud._button("IN SLOT %d" % (in_slot + 1) if in_slot >= 0 else "SLOT %d" % (hud.loadout_slot + 1), btns, func() -> void:
		if p.set_skill_slot(hud.loadout_slot, sid):
			hud.game.audio.play("menu5", 0.02, -4.0)
		refresh.call())
	slot_b.disabled = lock != "" or in_slot == hud.loadout_slot
	var why: String = Build.upgrade_reason(p, sid)
	var up_text := "MASTERED" if lv >= ClassBook.SKILL_MAX_LEVEL else "UPGRADE %dpt" % Build.upgrade_cost(p, sid)
	var up: Button = hud._button(up_text, btns, func() -> void:
		if p.upgrade_skill(sid):
			hud.show_message("%s upgraded to level %d: more damage, faster cooldown." % [def["name"], Build.skill_level(p, sid)], 2.5)
		refresh.call())
	up.disabled = why != ""
	up.tooltip_text = why
	if why != "" and lock == "" and lv < ClassBook.SKILL_MAX_LEVEL:
		hud._label("Next level: " + why, 8, hud.C_DIM, col)
	elif why == "":
		hud._label("Next level: +%d dmg, -10%% cooldown." % int(def.get("dmg_step", 1)) if int(def.get("dmg_step", 1)) > 0 else "Next level: -10% cooldown, stronger effect.", 8, C_GOOD, col)


static func _line_panel(hud: Control, p: Node, cid: String, list: Control, refresh: Callable) -> void:
	var def: Dictionary = ClassBook.CLASSES[cid]
	var bound: bool = p.classes.has(cid)
	var primary: bool = bound and p.classes[0] == cid
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", hud._box(Color(0.16, 0.12, 0.22, 0.9) if bound else Color(0.09, 0.07, 0.13, 0.75), def["color"] if bound else hud.C_BORDER, 1, 3))
	list.add_child(box)
	var col: VBoxContainer = hud._vbox(box, 1)
	var row: HBoxContainer = hud._hbox(col, 6)
	var icon: TextureRect = hud._icon(def["icon"], Vector2(14, 14), row)
	icon.modulate = def["color"]
	var name_col: VBoxContainer = hud._vbox(row, 0)
	var rank_txt := ""
	if bound:
		rank_txt = "  ·  %s  RANK %d/%d" % ["PRIMARY" if primary else "SECONDARY", Build.rank(p, cid), ClassBook.MAX_RANK]
	elif not (p.class_nodes.get(cid, {}) as Dictionary).is_empty():
		rank_txt = "  ·  released (progress kept, rank %d)" % (1 + (p.class_nodes[cid] as Dictionary).size())
	hud._label("%s — %s (%s)%s" % [def["name"], def["title"], def["role"], rank_txt], 9, def["color"] if bound else hud.C_TEXT, name_col)
	hud._label(def["desc"], 8, hud.C_DIM, name_col)
	_spacer(row)
	var bcol: VBoxContainer = hud._vbox(row, 2)
	if bound:
		if not primary:
			hud._button("MAKE PRIMARY", bcol, func() -> void:
				p.swap_lines()
				refresh.call())
		hud._button("RELEASE", bcol, func() -> void:
			p.release_class(cid)
			refresh.call())
	else:
		var why: String = Build.bind_reason(p, cid)
		var b: Button = hud._button("BIND" if why == "" else ("LV %d" % ClassBook.COMBINE_LEVEL if p.classes.size() == 1 else "FULL"), bcol, func() -> void:
			if p.bind_class(cid):
				refresh.call())
		b.disabled = why != ""
		b.tooltip_text = why
	# attributes at the current (or first) rank
	var r: int = maxi(1, Build.rank(p, cid))
	var scale := 1.0 if primary or not bound else ClassBook.SECONDARY_ATTR_SCALE
	var attrs := PackedStringArray()
	for k in def.get("attrs", {}):
		var arr: Array = def["attrs"][k]
		var v := float(arr[clampi(r - 1, 0, arr.size() - 1)]) * scale
		if k in Build.INT_STATS:
			v = floorf(v)
		if v != 0.0:
			attrs.append(CD.format_stat(k, v))
	hud._label("Line attributes: " + (", ".join(attrs) if attrs.size() > 0 else "grow with rank"), 8, hud.C_TEXT, col)
	hud._label("Signature arts (%d) are listed on the SKILLS + LOADOUT tab." % def["skills"].size(), 8, hud.C_DIM, col)
	var gear := PackedStringArray()
	var rw: Dictionary = def.get("rewards", {})
	for need in rw:
		for gid in rw[need]:
			gear.append("%s%s (rank %d)" % ["+ " if p.rewards_claimed.has(gid) else "· ", DB.ITEMS[gid]["name"], int(need)])
	if gear.size() > 0:
		_wrap(hud, "Signature gear: " + ", ".join(gear), hud.C_DIM, col, 420)
	if not bound:
		return
	for nid in def["tree"]:
		var node: Dictionary = def["tree"][nid]
		var nrow: HBoxContainer = hud._hbox(col, 4)
		var owned: bool = (p.class_nodes.get(cid, {}) as Dictionary).has(nid)
		var needs_met := true
		for need in node.get("needs", []):
			if not (p.class_nodes.get(cid, {}) as Dictionary).has(need):
				needs_met = false
		var l: Label = hud._label(("+ " if owned else "· ") + node["name"], 8, def["color"] if owned else hud.C_TEXT, nrow)
		l.custom_minimum_size = Vector2(96, 10)
		var need_txt := ""
		if not owned and not needs_met:
			var nn := PackedStringArray()
			for need in node.get("needs", []):
				nn.append(String(def["tree"][need]["name"]))
			need_txt = "  (needs " + ", ".join(nn) + ")"
		var d: Label = hud._label(node["desc"] + need_txt + ("  -> rank up" if not owned else ""), 8, hud.C_DIM if owned or needs_met else Color(0.55, 0.5, 0.6), nrow)
		d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if owned:
			hud._label("LEARNED", 8, hud.C_GOLD, nrow)
		else:
			var bb: Button = hud._button("+ POINT", nrow, func() -> void:
				if p.spend_node(cid, nid):
					refresh.call())
			bb.disabled = not needs_met or p.skill_points < 1


# ------------------------------------------------------------------ satchel
const WEAPON_FAMILIES := [
	["swords", "Swords"], ["daggers", "Daggers"], ["staves", "Staves"], ["bows", "Bows"],
	["axes", "Axes"], ["hammers", "Hammers"], ["spears", "Spears"], ["other_weapons", "Other weapons"],
]
const SORT_OPTIONS := [["rarity", "Rarity ↓"], ["name", "Name A–Z"], ["category", "Category"], ["value", "Value ↓"]]


static func _filter_of(id: String) -> String:
	var item: Dictionary = DB.ITEMS.get(id, {})
	var t := String(item.get("type", ""))
	if t == "weapon":
		var wclass := String(item.get("wclass", "")).to_lower()
		var item_id := id.to_lower()
		if wclass in ["sword", "sabre", "rapier", "greatsword", "falchion", "katana", "blade"] or item_id.contains("blade") or item_id.contains("sword") or item_id.contains("katana"):
			return "swords"
		if wclass in ["dagger", "daggers", "knives", "twinblade"] or item.get("dual", false):
			return "daggers"
		if wclass in ["staff", "staves"]:
			return "staves"
		if wclass == "bow":
			return "bows"
		if wclass == "axe":
			return "axes"
		if wclass in ["hammer", "maul"]:
			return "hammers"
		if wclass in ["spear", "lance"]:
			return "spears"
		return "other_weapons"
	if t in ["head", "armor", "arms", "legs", "boots", "cloak"]:
		return "armor"
	if t in ["charm", "ring", "relic"]:
		return "accessories"
	if t == "material":
		return "materials"
	if t in ["consumable", "flask_up", "tool"]:
		return "consumables"
	return "other"


static func _matches_filter(id: String, filter_id: String) -> bool:
	if filter_id in ["", "all"]:
		return true
	if filter_id in ["weapons", "weapon"]:
		return String(DB.ITEMS.get(id, {}).get("type", "")) == "weapon"
	if filter_id == "acc":
		return _filter_of(id) == "accessories"
	if filter_id == "bag":
		return _filter_of(id) in ["materials", "consumables", "other"]
	return _filter_of(id) == filter_id


static func _category_label(filter_id: String) -> String:
	var labels := {"all": "All items", "weapons": "Weapons", "armor": "Armor", "accessories": "Accessories",
		"materials": "Materials", "consumables": "Consumables", "other": "Other"}
	for family in WEAPON_FAMILIES:
		labels[String(family[0])] = String(family[1])
	return String(labels.get(filter_id, "Other"))


static func _sort_rarity(id: String) -> int:
	return DB.RARITIES.find(RUI.rarity_of(id))


static func _name_less(a: String, b: String) -> bool:
	return String(DB.ITEMS[a].get("name", a)).to_lower() < String(DB.ITEMS[b].get("name", b)).to_lower()


static func _sort_inventory(ids: Array, sort_id: String) -> void:
	match sort_id:
		"name":
			ids.sort_custom(func(a, b) -> bool: return _name_less(String(a), String(b)))
		"category":
			ids.sort_custom(func(a, b) -> bool:
				var ca := _category_label(_filter_of(String(a)))
				var cb := _category_label(_filter_of(String(b)))
				if ca != cb:
					return ca < cb
				var ra := _sort_rarity(String(a))
				var rb := _sort_rarity(String(b))
				return _name_less(String(a), String(b)) if ra == rb else ra > rb)
		"value":
			ids.sort_custom(func(a, b) -> bool:
				var va := int(DB.ITEMS[String(a)].get("value", 0))
				var vb := int(DB.ITEMS[String(b)].get("value", 0))
				return _name_less(String(a), String(b)) if va == vb else va > vb)
		_:
			ids.sort_custom(func(a, b) -> bool:
				var ra := _sort_rarity(String(a))
				var rb := _sort_rarity(String(b))
				return _name_less(String(a), String(b)) if ra == rb else ra > rb)


static func _filter_bar(hud: Control, grid: GridContainer, ids: Array) -> void:
	var parent: Control = grid.get_parent()
	var bar: HBoxContainer = parent.get_node_or_null("SatchelFilters")
	if bar == null:
		bar = HBoxContainer.new()
		bar.name = "SatchelFilters"
		bar.add_theme_constant_override("separation", 2)
		parent.add_child(bar)
		parent.move_child(bar, 0)
	var category: OptionButton = bar.get_node_or_null("SatchelCategory") as OptionButton
	if category == null:
		category = OptionButton.new()
		category.name = "SatchelCategory"
		category.custom_minimum_size = Vector2(112, 16)
		category.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		category.tooltip_text = "Show all items or narrow the satchel by equipment family and item type."
		category.add_theme_font_size_override("font_size", 7)
		bar.add_child(category)
		category.item_selected.connect(func(index: int) -> void:
			hud.set_meta("satchel_filter", String(category.get_item_metadata(index)))
			refresh_inventory(hud))
	var counts: Dictionary = {}
	var has_weapons := false
	for id in ids:
		var group := _filter_of(String(id))
		counts[group] = int(counts.get(group, 0)) + 1
		if String(DB.ITEMS[String(id)].get("type", "")) == "weapon":
			has_weapons = true
	category.clear()
	var options: Array = [["all", "All items", ids.size()]]
	if has_weapons:
		var weapon_count := 0
		for id in ids:
			if String(DB.ITEMS[String(id)].get("type", "")) == "weapon":
				weapon_count += 1
		options.append(["weapons", "Weapons", weapon_count])
		for family in WEAPON_FAMILIES:
			var family_id := String(family[0])
			if int(counts.get(family_id, 0)) > 0:
				options.append([family_id, String(family[1]), int(counts[family_id])])
	for group in [["armor", "Armor"], ["accessories", "Accessories"], ["materials", "Materials"], ["consumables", "Consumables"], ["other", "Other"]]:
		if int(counts.get(group[0], 0)) > 0:
			options.append([String(group[0]), String(group[1]), int(counts[group[0]])])
	var cur := String(hud.get_meta("satchel_filter", "all"))
	var selected_index := 0
	for option in options:
		var idx := category.item_count
		category.add_item("%s (%d)" % [String(option[1]), int(option[2])])
		category.set_item_metadata(idx, String(option[0]))
		if String(option[0]) == cur:
			selected_index = idx
	category.select(selected_index)
	hud.set_meta("satchel_filter", String(category.get_item_metadata(selected_index)))
	var sorter: OptionButton = bar.get_node_or_null("SatchelSort") as OptionButton
	if sorter == null:
		sorter = OptionButton.new()
		sorter.name = "SatchelSort"
		sorter.custom_minimum_size = Vector2(88, 16)
		sorter.tooltip_text = "Sort the current satchel view."
		sorter.add_theme_font_size_override("font_size", 7)
		for choice in SORT_OPTIONS:
			var idx := sorter.item_count
			sorter.add_item(String(choice[1]))
			sorter.set_item_metadata(idx, String(choice[0]))
		bar.add_child(sorter)
		sorter.item_selected.connect(func(index: int) -> void:
			hud.set_meta("satchel_sort", String(sorter.get_item_metadata(index)))
			refresh_inventory(hud))
	var selected_sort := String(hud.get_meta("satchel_sort", "rarity"))
	for i in range(sorter.item_count):
		if String(sorter.get_item_metadata(i)) == selected_sort:
			sorter.select(i)
			break


static func refresh_inventory(hud: Control) -> void:
	var grid: GridContainer = hud.inventory_grid
	for c in grid.get_children():
		grid.remove_child(c)
		c.queue_free()
	var p: Node = hud.game.player
	var ids: Array = []
	var counts := {}
	for w in p.weapons_owned:
		if not DB.ITEMS.get(w, {}).get("unarmed", false) and not ids.has(w):
			ids.append(w)
	for i in p.inventory:
		if DB.ITEMS.has(i) and not ids.has(i):
			ids.append(i)
	for id in p.bag.keys():
		if int(p.bag[id]) > 0 and DB.ITEMS.has(id):
			if not ids.has(id):
				ids.append(String(id))
			counts[String(id)] = int(p.bag[id])
	_filter_bar(hud, grid, ids)
	var cur := String(hud.get_meta("satchel_filter", "all"))
	var shown: Array = []
	for id in ids:
		if _matches_filter(String(id), cur):
			shown.append(String(id))
	_sort_inventory(shown, String(hud.get_meta("satchel_sort", "rarity")))
	if hud.satchel_selected == "" or not shown.has(hud.satchel_selected):
		hud.satchel_selected = "" if shown.is_empty() else (p.get_weapon_id() if shown.has(p.get_weapon_id()) else shown[0])
	for id in shown:
		var item: Dictionary = DB.ITEMS[id]
		var b := Button.new()
		b.name = "SatchelItem_" + id
		b.tooltip_text = "%s · %s · %s" % [String(item.get("name", id)), RUI.name_of(id), RUI.category_of(id)]
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(26, 26)
		b.flat = true
		var equipped: bool = (item["type"] == "weapon" and p.get_weapon_id() == id) or p.equipped.values().has(id)
		var usable: bool = not item["type"] in ["weapon"] + DB.EQUIP_SLOTS or Build.can_equip(p, id)
		var fr: Control = RUI.icon(id, 26.0, b, hud.satchel_selected == id, not usable, int(counts.get(id, 0)))
		fr.set_anchors_preset(Control.PRESET_FULL_RECT)
		if hud.satchel_selected == id:
			var sb: StyleBoxFlat = RUI.box(id, true)
			sb.border_color = hud.C_GOLD
			fr.add_theme_stylebox_override("panel", sb)
		if equipped:
			var tag: Label = hud._label("E", 7, hud.C_GOLD, fr)
			tag.add_theme_color_override("font_outline_color", Color(0.05, 0.03, 0.08))
			tag.add_theme_constant_override("outline_size", 3)
			tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.pressed.connect(func() -> void:
			hud.satchel_selected = id
			refresh_inventory(hud))
		grid.add_child(b)
	if shown.is_empty():
		hud._label("No items in this category.", 8, hud.C_DIM, grid)
	var used: int = Inv.stacks_used(p)
	var cap_l: Label = grid.get_parent().get_node_or_null("BagCap")
	if cap_l == null:
		cap_l = hud._label("", 7, hud.C_DIM, grid.get_parent())
		cap_l.name = "BagCap"
		grid.get_parent().move_child(cap_l, 2)
	cap_l.text = "Showing %d/%d items · %d/%d stacks%s" % [shown.size(), ids.size(), used, DB.BAG_SLOTS, " · bag full" if used >= DB.BAG_SLOTS else ""]
	cap_l.tooltip_text = "Category-filtered inventory count and stack capacity."
	cap_l.add_theme_color_override("font_color", C_BAD if used >= DB.BAG_SLOTS else hud.C_DIM)
	_detail(hud, p, hud.satchel_selected)
	_doll(hud, p)


static func _detail(hud: Control, p: Node, id: String) -> void:
	var box: VBoxContainer = hud.inventory_detail
	var details_scroll := box.get_parent().get_parent() as ScrollContainer
	if details_scroll != null:
		details_scroll.scroll_vertical = 0
	for c in box.get_children():
		c.queue_free()
	if id == "" or not DB.ITEMS.has(id):
		return
	var item: Dictionary = DB.ITEMS[id]
	var t: String = item["type"]
	var head: HBoxContainer = hud._hbox(box, 5)
	RUI.icon(id, 22.0, head)
	var hc: VBoxContainer = hud._vbox(head, 0)
	hud._label(String(item["name"]), 10, RUI.color(id), hc)
	hud._label("%s · %s%s" % [RUI.category_of(id), RUI.name_of(id), ("" if Build.item_classes(id).is_empty() else " · " + Build.requirement_text(id))], 8, hud.C_DIM, hc)
	if Inv.is_stackable(id):
		hud._label("x%d in bag" % Inv.count(p, id), 8, hud.C_DIM, box)
	if t == "weapon":
		var w: Dictionary = CD.weapon(id)
		var shape := {"arc": "arc %d" % int(w["reach"]), "circle": "slam r%d" % int(w["reach"]), "line": "range %d" % int(w["reach"]),
			"ring": "360° r%d, tip +%d%%" % [int(w["reach"]), int(round((float(w.get("sweet_mult", 1.5)) - 1.0) * 100.0))]}
		hud._label("Attack: %s · %.2fs · %s" % [String(w["pattern"]).capitalize(), float(w["cooldown"]), shape[String(w["shape"])]], 8, hud.C_TEXT, box)
		var hd: Dictionary = w.get("hold", {})
		if not hd.is_empty():
			var hold_names := {"afterimage": "Afterimage (blink + fighting clone)", "moonrend": "Moonrend Dash", "burst": "Energy Burst (knockback + knockdown)",
				"wide_lash": "Wide Lash (one bigger, stronger spin)", "overcharge": "Overcharge (bigger, stronger orb)", "barrage": "Feral Barrage"}
			_wrap(hud, "Hold · %s · %.1fs charge, %.1fs cooldown. Aim with the move stick." % [hold_names.get(String(hd["kind"]), String(hd["kind"])), float(hd.get("time", 0.7)), float(hd.get("cd", 1.0))], Color(0.75, 0.88, 1.0), box, 200)
		else:
			hud._label("No hold effect (holding repeats attacks).", 8, hud.C_DIM, box)
		var ps: Dictionary = CD.PASSIVES.get(String(w.get("passive", "")), {})
		if not ps.is_empty():
			_wrap(hud, "Passive · %s: %s" % [ps["name"], ps["desc"]], Color(1.0, 0.86, 0.55), box, 200)
	if item.has("relic"):
		var rl: Dictionary = CD.RELICS[String(item["relic"])]
		_wrap(hud, "Relic active · %s (%ds cd): %s" % [rl["name"], int(rl["cd"]), rl["desc"]], Color(1.0, 0.86, 0.55), box, 200)
	if t == "weapon" or t in DB.EQUIP_SLOTS:
		for ln in Build.compare_lines(p, id):
			var dv := float(ln["delta"])
			hud._label(String(ln["text"]), 8, C_GOOD if dv > 0.0 else (C_BAD if dv < 0.0 else hud.C_TEXT), box)
		var why: String = Build.item_reason(p, id)
		var worn: bool = (t == "weapon" and p.get_weapon_id() == id) or p.equipped.get(t, "") == id
		if why != "":
			_wrap(hud, "Cannot equip: " + why, C_BAD, box, 200)
		var row: HBoxContainer = hud._hbox(box, 4)
		if worn and t != "weapon":
			hud._button("UNEQUIP", row, func() -> void:
				p.unequip(t)
				hud.game.audio.play("menu5", 0.02, -4.0)
				refresh_inventory(hud))
		elif worn and t == "weapon" and not p.is_unarmed():
			var ub: Button = hud._button("UNEQUIP", row, func() -> void:
				p.unequip_weapon()
				hud.game.audio.play("menu5", 0.02, -4.0)
				refresh_inventory(hud))
			ub.name = "UnequipWeapon"
			hud._label("HELD", 8, hud.C_GOLD, row)
		elif not worn:
			var eb: Button = hud._button("EQUIP", row, func() -> void:
				if p.equip(id):
					hud.game.audio.play("menu5", 0.02, -4.0)
				else:
					hud.show_message(p.last_equip_error, 2.0)
				refresh_inventory(hud))
			eb.name = "EquipButton"
			eb.disabled = why != ""
		else:
			hud._label("HELD", 8, hud.C_GOLD, row)
		if t == "weapon":
			var brow: HBoxContainer = hud._hbox(box, 4)
			if p.weapon_bar.has(id):
				var rb: Button = hud._button("REMOVE FROM BAR", brow, func() -> void:
					p.bar_remove(id)
					hud.game.audio.play("menu5", 0.02, -4.0)
					refresh_inventory(hud))
				rb.name = "BarRemove"
			else:
				var ab: Button = hud._button("ADD TO BAR", brow, func() -> void:
					if p.bar_add(id):
						hud.game.audio.play("menu5", 0.02, -4.0)
					else:
						hud.show_message(p.last_equip_error, 2.0)
					refresh_inventory(hud))
				ab.name = "BarAdd"
				hud._label("BAR %d/%d" % [p.weapon_bar.size(), p.bar_max()], 8, hud.C_DIM if p.weapon_bar.size() < p.bar_max() else hud.C_GOLD, brow)
	# Longer flavor copy is deliberately last. The selected item's attack,
	# passive, comparison, and equip controls stay together at the top of the
	# inspection pane rather than being displaced below prose.
	_wrap(hud, String(item["desc"]), Color(0.76, 0.73, 0.8), box, 200)


static func _row_button(hud: Control, text: String, parent: Control, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_font_size_override("font_size", 8)
	b.clip_text = true
	b.custom_minimum_size = Vector2(0, 14)
	for st in ["normal", "hover", "pressed"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.16, 0.11, 0.22, 0.9) if st == "normal" else Color(0.32, 0.2, 0.36, 0.95)
		sb.border_color = Color(0.5, 0.4, 0.58)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(2)
		sb.content_margin_left = 4
		sb.content_margin_right = 4
		sb.content_margin_top = 1
		sb.content_margin_bottom = 1
		b.add_theme_stylebox_override(st, sb)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


static func _doll(hud: Control, p: Node) -> void:
	var box: VBoxContainer = hud.inventory_doll
	for c in box.get_children():
		c.queue_free()
	var cls := PackedStringArray()
	for cid in p.classes:
		cls.append(Build.class_display(cid))
	hud._label("MALLOW  ·  " + (" + ".join(cls) if cls.size() > 0 else "no line (K)"), 8, hud.C_GOLD, box)
	var wb: Button = _row_button(hud, "Weapon: " + String(DB.ITEMS[p.get_weapon_id()]["name"]), box, func() -> void:
		hud.satchel_selected = p.get_weapon_id()
		refresh_inventory(hud))
	wb.alignment = HORIZONTAL_ALIGNMENT_LEFT
	for slot in DB.EQUIP_SLOTS:
		var eq: String = p.equipped.get(slot, "")
		var b: Button = _row_button(hud, "%s: %s" % [DB.SLOT_NAMES[slot], DB.ITEMS[eq]["name"] if eq != "" else "-"], box, func() -> void:
			if eq != "":
				hud.satchel_selected = eq
				refresh_inventory(hud))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if eq != "":
			b.add_theme_color_override("font_color", DB.RARITY_COLORS.get(DB.ITEMS[eq].get("rarity", "common"), Color.WHITE))
	var lines := PackedStringArray()
	lines.append("Hearts %d/%d · Def %d · Focus %d" % [ceili(p.health / 4.0), p.max_health / 4, p.defense_total(), int(p.focus_max)])
	lines.append("Atk +%d · Crit %d%% · Spd %d%%" % [p.attack_bonus(), roundi(p.crit_chance() * 100.0), roundi(p.get_move_speed() / p.WALK_SPEED * 100.0)])
	lines.append("Atk speed +%d%% · CDR %d%%" % [roundi((p.attack_speed_mult() - 1.0) * 100.0), roundi((1.0 - p.skill_cd_scale()) * 100.0)])
	lines.append("Elem +%d%% · Lifesteal %d%% · Heal +%d%%" % [roundi((p.elem_mult() - 1.0) * 100.0), roundi(p.lifesteal() * 100.0), roundi((p.heal_mult() - 1.0) * 100.0)])
	lines.append("Lv %d · Coins %d · Moontea %d/%d" % [p.level, p.petalcoins, p.moontea_charges, p.moontea_max])
	hud._label("\n".join(lines), 8, hud.C_TEXT, box)
