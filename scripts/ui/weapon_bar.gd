extends RefCounted
## HUD weapon bar: a vertical column of up to five weapon slots on the right,
## inboard of the attack/art/potion cluster (layout ids "wslot0".."wslot4" in
## combat_controls.DEFAULTS, movable in the HUD editor). Tap a slot to switch;
## the held weapon is framed in gold with a pointer. Replaces the old
## "Q SWAP" chip / quick-swap button. Also drives the attack button's charge ring.

const DB := preload("res://scripts/data/db.gd")
const AnimLib := preload("res://scripts/core/anim_lib.gd")
const Build := preload("res://scripts/combat/build.gd")

const SLOTS := 5
const SLOT_RADIUS := 11.0


static func build(hud: Control) -> Array:
	var out: Array = []
	for i in range(SLOTS):
		var b = hud._touch("", "items/weapons/katana.png", SLOT_RADIUS, Color(0.8, 0.8, 0.9))
		b.id = "wslot%d" % i
		b.wslot = i
		b.icon = null
		b.name = "WeaponSlot%d" % i
		out.append(b)
	return out


static func update(hud: Control) -> void:
	var p: Node = hud.game.player
	var held: String = p.get_weapon_id()
	for b in hud.weapon_slots:
		var i: int = b.wslot
		var id: String = p.weapon_bar[i] if i < p.weapon_bar.size() else ""
		if b.weapon_id != id:
			b.weapon_id = id
			b.icon = AnimLib.tex(DB.ITEMS[id]["icon"]) if id != "" else null
			var rar := String(DB.ITEMS.get(id, {}).get("rarity", "common"))
			b.frame_color = DB.RARITY_COLORS.get(rar, Color(0.85, 0.85, 0.85))
			b.mythic = rar == "mythical"
			b.queue_redraw()
		b.active = id != "" and id == held
		b.dimmed = id != "" and not Build.can_equip(p, id)
	# charge ring on the attack button
	var ab = hud.attack_button
	var c = p.charge
	ab.charge = c.progress() if c.charging else -1.0
	ab.charge_full = c.is_full()
	ab.charge_cancel = c.off_button and c.charging


static func tap(hud: Control, b) -> void:
	var p: Node = hud.game.player
	if b.wslot >= p.weapon_bar.size():
		hud.show_message("Empty weapon slot: open BAG, pick a weapon and tap ADD TO BAR.", 2.0)
		return
	p.select_bar_slot(b.wslot)
