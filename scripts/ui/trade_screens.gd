extends RefCounted
## Shop / sell / exchange / crafting screen. One overlay, four tabs; the left
## list shows framed items with price or state, the right panel shows the
## selected item's category, rarity, stats, class requirement, comparison and
## the action with the exact reason it is unavailable. All rules live in
## scripts/systems/trade.gd and crafting.gd - this file only draws.

const DB := preload("res://scripts/data/db.gd")
const Eco := preload("res://scripts/data/economy.gd")
const Trade := preload("res://scripts/systems/trade.gd")
const Craft := preload("res://scripts/systems/crafting.gd")
const Inv := preload("res://scripts/systems/inventory.gd")
const Build := preload("res://scripts/combat/build.gd")
const CD := preload("res://scripts/data/combat_data.gd")
const RUI := preload("res://scripts/ui/rarity_ui.gd")

const C_BAD := Color(1.0, 0.55, 0.55)
const C_GOOD := Color(0.62, 1.0, 0.68)
const TABS := [["buy", "BUY"], ["sell", "SELL"], ["trade", "TRADE"], ["craft", "CRAFT"]]


static func make(hud: Control) -> void:
	var o: ColorRect = hud._overlay()
	o.name = "TradeOverlay"
	hud.trade_overlay = o
	var p: PanelContainer = hud._centered_panel(o, Vector2(580, 0))
	var v: VBoxContainer = hud._vbox(p, 4)
	var head: HBoxContainer = hud._hbox(v, 6)
	hud.trade_title = hud._label("SHOP", 14, hud.C_GOLD, head)
	hud.trade_service = hud._label("", 8, hud.C_DIM, head)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	hud._icon("items/goldcoin.png", Vector2(9, 9), head)
	hud.trade_coins = hud._label("0", 10, hud.C_GOLD, head)
	hud.trade_bag = hud._label("", 8, hud.C_DIM, head)
	hud._button("LEAVE", head, hud.close_trade)
	hud.trade_tabs = hud._hbox(v, 4)
	var body: HBoxContainer = hud._hbox(v, 8)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(320, 214)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(sc)
	hud.trade_list = hud._vbox(sc, 3)
	hud.trade_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var dsc := ScrollContainer.new()
	dsc.custom_minimum_size = Vector2(236, 214)
	dsc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(dsc)
	hud.trade_detail = hud._vbox(dsc, 3)
	hud.trade_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	o.visible = false


static func _clear(c: Control) -> void:
	for ch in c.get_children():
		ch.queue_free()


static func _wrap(hud: Control, text: String, color: Color, parent: Control, size := 8) -> Label:
	var l: Label = hud._label(text, size, color, parent)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(220, 0)
	return l


static func tabs_for(shop_id: String) -> Array:
	if shop_id == "":
		return ["craft"]
	var out := ["buy"]
	var s: Dictionary = Eco.SHOPS.get(shop_id, {})
	if not s.get("sell", []).is_empty():
		out.append("sell")
	if not s.get("exchanges", []).is_empty():
		out.append("trade")
	if s.get("forge", false):
		out.append("craft")
	return out


static func render(hud: Control) -> void:
	var g: Node = hud.game
	var st: Dictionary = hud.trade_state
	var shop_id: String = st.get("shop", "")
	var tab: String = st.get("tab", "buy")
	var avail := tabs_for(shop_id)
	if not avail.has(tab):
		tab = avail[0]
		st["tab"] = tab
	var s: Dictionary = Eco.SHOPS.get(shop_id, {})
	hud.trade_title.text = String(s.get("name", "FIELDCRAFT")).to_upper()
	hud.trade_service.text = String(s.get("service", "Craft anywhere · forge recipes need Bramble"))
	hud.trade_coins.text = str(g.player.petalcoins)
	hud.trade_bag.text = "Bag %d/%d" % [Inv.stacks_used(g.player), DB.BAG_SLOTS]
	_clear(hud.trade_tabs)
	for t in TABS:
		if not avail.has(t[0]):
			continue
		var tid: String = t[0]
		var b: Button = hud._button(t[1], hud.trade_tabs, func() -> void:
			hud.trade_state["tab"] = tid
			hud.trade_state["sel"] = -1
			render(hud))
		b.custom_minimum_size = Vector2(60, 18)
		if tid == tab:
			b.add_theme_stylebox_override("normal", hud._box(Color(0.42, 0.24, 0.40), hud.C_GOLD, 1, 3))
	_clear(hud.trade_list)
	_clear(hud.trade_detail)
	match tab:
		"buy":
			_render_buy(hud, shop_id)
		"sell":
			_render_sell(hud, shop_id)
		"trade":
			_render_trade(hud, shop_id)
		"craft":
			_render_craft(hud)


static func _row(hud: Control, id: String, title: String, sub: String, right: String, right_color: Color, selected: bool, cb: Callable, count := 0) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(310, 26)
	b.add_theme_stylebox_override("normal", hud._box(Color(0.30, 0.18, 0.34, 0.95) if selected else Color(0.15, 0.11, 0.21, 0.9), hud.C_GOLD if selected else Color(0.35, 0.28, 0.42), 1, 3))
	b.add_theme_stylebox_override("hover", hud._box(Color(0.24, 0.16, 0.30, 0.95), Color(0.6, 0.5, 0.7), 1, 3))
	b.add_theme_stylebox_override("pressed", hud._box(Color(0.30, 0.18, 0.34, 0.95), hud.C_GOLD, 1, 3))
	b.pressed.connect(cb)
	hud.trade_list.add_child(b)
	var h: HBoxContainer = hud._hbox(b, 6)
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 3
	h.offset_right = -6
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if id != "":
		RUI.icon(id, 22.0, h, false, false, count)
	var col: VBoxContainer = hud._vbox(h, 0)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	var t: Label = hud._label(title, 8, RUI.color(id) if id != "" else hud.C_TEXT, col)
	t.clip_text = true
	t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var sl: Label = hud._label(sub, 7, hud.C_DIM, col)
	sl.clip_text = true
	sl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var r: Label = hud._label(right, 8, right_color, h)
	r.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	return b


## Item facts shared by every tab.
static func _item_detail(hud: Control, id: String) -> void:
	var g: Node = hud.game
	var p: Node = g.player
	var it: Dictionary = DB.ITEMS[id]
	var top: HBoxContainer = hud._hbox(hud.trade_detail, 6)
	RUI.icon(id, 30.0, top)
	var c: VBoxContainer = hud._vbox(top, 0)
	var nl: Label = hud._label(String(it["name"]), 10, RUI.color(id), c)
	nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nl.custom_minimum_size = Vector2(190, 0)
	hud._label("%s · %s" % [RUI.category_of(id), RUI.name_of(id)], 8, hud.C_DIM, c)
	var req := Build.requirement_text(id)
	if not Build.item_classes(id).is_empty():
		var why := Build.item_reason(p, id)
		_wrap(hud, req + ("" if why == "" else "  (" + why + ")"), C_BAD if why != "" else C_GOOD, hud.trade_detail)
	_wrap(hud, String(it.get("desc", "")), hud.C_TEXT, hud.trade_detail)
	var t := String(it.get("type", ""))
	if t == "weapon":
		var w: Dictionary = CD.weapon(id)
		hud._label("Damage %d · %s · %.2fs" % [int(it.get("damage", 1)), String(w["pattern"]).capitalize(), float(w["cooldown"])], 8, hud.C_TEXT, hud.trade_detail)
		var ps: Dictionary = CD.PASSIVES.get(String(w.get("passive", "")), {})
		if not ps.is_empty():
			_wrap(hud, "Passive · %s: %s" % [ps["name"], ps["desc"]], hud.C_GOLD, hud.trade_detail)
	if it.has("relic"):
		var rl: Dictionary = CD.RELICS[String(it["relic"])]
		_wrap(hud, "Gear active · %s (%ds cooldown, %ds): %s" % [rl["name"], int(rl["cd"]), int(rl["time"]), rl["desc"]], hud.C_GOLD, hud.trade_detail)
	if t == "weapon" or t in DB.EQUIP_SLOTS:
		for ln in Build.compare_lines(p, id):
			var dv := float(ln["delta"])
			hud._label(String(ln["text"]), 8, C_GOOD if dv > 0.0 else (C_BAD if dv < 0.0 else hud.C_DIM), hud.trade_detail)
	if Inv.is_stackable(id):
		hud._label("In bag: %d" % Inv.count(p, id), 8, hud.C_DIM, hud.trade_detail)
	elif p.owns(id):
		hud._label("Owned", 8, hud.C_DIM, hud.trade_detail)


static func _action(hud: Control, text: String, why: String, cb: Callable) -> void:
	if why != "":
		_wrap(hud, why, C_BAD, hud.trade_detail)
	var b: Button = hud._button(text, hud.trade_detail, cb)
	b.name = "TradeAction"
	b.custom_minimum_size = Vector2(120, 22)
	b.disabled = why != ""


static func _render_buy(hud: Control, shop_id: String) -> void:
	var g: Node = hud.game
	var stock: Array = g._shop_stock()
	var sel := int(hud.trade_state.get("sel", -1))
	if sel < 0 or sel >= stock.size():
		sel = 0
	for i in range(stock.size()):
		var e: Dictionary = stock[i]
		var id: String = e["id"]
		var why := Trade.buy_reason(g, shop_id, e)
		var left := Trade.stock_left(g, shop_id, e)
		var sub := "%s · %s%s" % [RUI.category_of(id), RUI.name_of(id), ("" if left < 0 else " · %d left" % left)]
		var idx := i
		_row(hud, id, String(DB.ITEMS[id]["name"]), sub, "%d c" % int(e["price"]), hud.C_GOLD if why == "" else C_BAD, idx == sel, func() -> void:
			hud.trade_state["sel"] = idx
			render(hud))
	if stock.is_empty():
		hud._label("Sold out. Check back after your next level.", 8, hud.C_DIM, hud.trade_list)
		return
	hud.trade_state["sel"] = sel
	var entry: Dictionary = stock[sel]
	_item_detail(hud, entry["id"])
	hud._label("Price: %d petalcoins" % int(entry["price"]), 8, hud.C_GOLD, hud.trade_detail)
	_action(hud, "BUY", Trade.buy_reason(g, shop_id, entry), func() -> void: g.buy_item(entry))


static func _render_sell(hud: Control, shop_id: String) -> void:
	var g: Node = hud.game
	var items: Array = Trade.sellables(g, shop_id)
	var sel := int(hud.trade_state.get("sel", -1))
	if sel < 0 or sel >= items.size():
		sel = 0
	for i in range(items.size()):
		var e: Array = items[i]
		var idx := i
		_row(hud, e[0], String(DB.ITEMS[e[0]]["name"]), "%s · %s" % [RUI.category_of(e[0]), RUI.name_of(e[0])],
			"+%d c" % int(e[2]), hud.C_GOLD if e[3] == "" else C_BAD, idx == sel, func() -> void:
				hud.trade_state["sel"] = idx
				render(hud), int(e[1]))
	if items.is_empty():
		hud._label("Nothing this merchant wants to buy.", 8, hud.C_DIM, hud.trade_list)
		return
	hud.trade_state["sel"] = sel
	var id: String = items[sel][0]
	_item_detail(hud, id)
	hud._label("Sells for %d petalcoins each" % Trade.sell_price(id), 8, hud.C_GOLD, hud.trade_detail)
	_action(hud, "SELL 1", Trade.sell_reason(g, shop_id, id), func() -> void: g.sell_item(id))


static func _render_trade(hud: Control, shop_id: String) -> void:
	var g: Node = hud.game
	var exs: Array = Eco.SHOPS.get(shop_id, {}).get("exchanges", [])
	var sel := int(hud.trade_state.get("sel", -1))
	if sel < 0 or sel >= exs.size():
		sel = 0
	for i in range(exs.size()):
		var ex: Dictionary = exs[i]
		var get_id: String = ex["get"]
		var icon_id: String = get_id if DB.ITEMS.has(get_id) else ("moon_shard" if Eco.RECIPE_SCROLLS.has(get_id) else "")
		var why := Trade.exchange_reason(g, ex)
		var idx := i
		var title := Trade.exchange_label(ex).split("  ->  ")[1]
		_row(hud, icon_id, title, "for " + Inv.needs_text(ex["give"]), "ready" if why == "" else "-", C_GOOD if why == "" else hud.C_DIM, idx == sel, func() -> void:
			hud.trade_state["sel"] = idx
			render(hud))
	if exs.is_empty():
		return
	hud.trade_state["sel"] = sel
	var ex2: Dictionary = exs[sel]
	_wrap(hud, Trade.exchange_label(ex2), hud.C_TEXT, hud.trade_detail, 9)
	var gid: String = ex2["get"]
	if DB.ITEMS.has(gid):
		_item_detail(hud, gid)
	elif Eco.RECIPE_SCROLLS.has(gid):
		_wrap(hud, "Teaches Bramble's forge the %s recipe." % DB.ITEMS[Eco.RECIPE_SCROLLS[gid]["recipe"]]["name"], hud.C_GOLD, hud.trade_detail)
	_action(hud, "TRADE", Trade.exchange_reason(g, ex2), func() -> void: g.do_exchange(ex2))


static func _render_craft(hud: Control) -> void:
	var g: Node = hud.game
	var forge: bool = g.at_forge()
	var list: Array = []
	for r in Eco.RECIPES:
		if String(r.get("station", "field")) == "forge" or forge or Craft.unlock_reason(g, r) == "":
			list.append(r)
	var sel := int(hud.trade_state.get("sel", -1))
	if sel < 0 or sel >= list.size():
		sel = 0
	for i in range(list.size()):
		var r: Dictionary = list[i]
		var why := Craft.block_reason(g, r, forge)
		var idx := i
		var station := "forge" if String(r.get("station", "field")) == "forge" else "field"
		var right := "ready" if why == "" else ("done" if why == "Already crafted." else "-")
		_row(hud, r["id"], String(DB.ITEMS[r["id"]]["name"]), "%s · %s" % [station, Inv.needs_text(r["needs"])], right,
			C_GOOD if why == "" else hud.C_DIM, idx == sel, func() -> void:
				hud.trade_state["sel"] = idx
				render(hud))
	if list.is_empty():
		return
	hud.trade_state["sel"] = sel
	var rr: Dictionary = list[sel]
	_item_detail(hud, rr["id"])
	var needs := PackedStringArray()
	for k in rr["needs"].keys():
		needs.append("%s %d/%d" % [DB.ITEMS[k]["name"], Inv.count(g.player, String(k)), int(rr["needs"][k])])
	_wrap(hud, "Needs: " + ", ".join(needs) + ("" if int(rr.get("coins", 0)) == 0 else " + %d coins" % int(rr["coins"])), hud.C_TEXT, hud.trade_detail)
	var rid: String = rr["id"]
	_action(hud, "CRAFT", Craft.block_reason(g, rr, forge), func() -> void:
		g.craft_recipe(rid)
		render(hud))
