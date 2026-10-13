extends Node2D
## Elemental status effects living on one enemy or boss (child named "Status").
## Rules (see combat_data.STATUS):
##  - reapplying refreshes duration and adds stacks up to max_stacks;
##  - DoT (burn, poison) ticks deal dmg_per_stack * stacks, capped by tick_cap,
##    and are routed through game.damage_target with source "dot" (no procs);
##  - chill slows 15% per stack; reaching 3 chills converts into a freeze
##    followed by freeze immunity; stun likewise grants brief immunity;
##  - curse / expose raise damage taken (the larger one applies, no stacking);
##  - species resistances scale duration and DoT (0 = immune); bosses take half
##    duration, ignore freeze/stun and are slowed at most 15%.

const CD := preload("res://scripts/data/combat_data.gd")

var game: Node
var host: Node2D
var is_boss := false
var resist: Dictionary = {}
var effects: Dictionary = {}   # id -> {"t": float, "stacks": int, "tick": float}
var immune_t: Dictionary = {}  # id -> seconds of immunity left
var _pip_t := 0.0
var _fx_t := 0.0


static func of(target: Node) -> Node:
	if target == null or not is_instance_valid(target):
		return null
	return target.get_node_or_null("Status")


static func ensure(p_game: Node, target: Node2D) -> Node:
	var s := of(target)
	if s != null:
		return s
	s = load("res://scripts/combat/status.gd").new()
	s.name = "Status"
	s.game = p_game
	s.host = target
	s.is_boss = target.get("title") != null
	s.z_index = 6
	var species = target.get("species")
	if species != null:
		s.resist = CD.RESIST.get(String(species), {})
	target.add_child(s)
	return s


## Apply `stacks` of a status. Returns true if it took hold.
static func apply(p_game: Node, target: Node2D, id: String, stacks := 1) -> bool:
	if not CD.STATUS.has(id) or target == null or not is_instance_valid(target):
		return false
	var s := ensure(p_game, target)
	return s.add(id, stacks)


func add(id: String, stacks: int) -> bool:
	var def: Dictionary = CD.STATUS[id]
	if not _host_alive():
		return false
	var mult := resist_mult(String(def.get("element", "")))
	if mult <= 0.0:
		if game:
			game.fx.number(host.global_position + Vector2(0, -14), "IMMUNE", Color(0.8, 0.8, 0.85))
		return false
	if is_boss and id in CD.BOSS_RESIST["immune"]:
		return false
	if float(immune_t.get(id, 0.0)) > 0.0:
		return false
	var dur := float(def["duration"]) * mult * (float(CD.BOSS_RESIST["duration"]) if is_boss else 1.0)
	var cur: Dictionary = effects.get(id, {"t": 0.0, "stacks": 0, "tick": float(def.get("tick", 0.0))})
	cur["stacks"] = mini(int(def.get("max_stacks", 1)), int(cur["stacks"]) + stacks)
	cur["t"] = maxf(float(cur["t"]), dur)
	effects[id] = cur
	if id == "chill" and not is_boss and int(cur["stacks"]) >= int(def.get("freeze_at", 99)):
		effects.erase("chill")
		add("freeze", 1)
	if id == "freeze" or id == "stun":
		if host.get("state") != null and host.has_method("die"):
			host.set("state", "stagger")
			host.set("state_t", dur)
		if game:
			game.fx.spawn("ice" if id == "freeze" else "thunder", host.global_position + Vector2(0, -8), 0.0, 0.8,
				CD.element_color(String(def["element"])), null, true)
	queue_redraw()
	return true


func resist_mult(element: String) -> float:
	if element == "":
		return 1.0
	return float(resist.get(element, 1.0))


func has_effect(id: String) -> bool:
	return effects.has(id)


func any_active() -> bool:
	return not effects.is_empty()


func stacks(id: String) -> int:
	return int(effects.get(id, {}).get("stacks", 0))


## Movement multiplier for the host's AI (1.0 = normal, 0.0 = frozen/stunned).
func speed_mult() -> float:
	if effects.has("freeze") or effects.has("stun"):
		return 0.0
	var slow := 0.0
	if effects.has("chill"):
		slow = float(CD.STATUS["chill"]["slow_per_stack"]) * float(stacks("chill"))
		if is_boss:
			slow = minf(slow, float(CD.BOSS_RESIST["slow_cap"]))
	return clampf(1.0 - slow, 0.2, 1.0)


func is_disabled() -> bool:
	return effects.has("freeze") or effects.has("stun")


## Extra damage taken (curse / expose do not stack with each other).
func vulnerability() -> float:
	var v := 0.0
	for id in ["curse", "expose"]:
		if effects.has(id):
			v = maxf(v, float(CD.STATUS[id]["vuln"]))
	return v


func _host_alive() -> bool:
	if host == null or not is_instance_valid(host):
		return false
	var a = host.get("alive")
	if a != null and not bool(a):
		return false
	var d = host.get("defeated")
	return d == null or not bool(d)


func clear_all() -> void:
	effects.clear()
	immune_t.clear()
	queue_redraw()


func _physics_process(delta: float) -> void:
	for k in immune_t.keys():
		immune_t[k] = float(immune_t[k]) - delta
		if float(immune_t[k]) <= 0.0:
			immune_t.erase(k)
	if effects.is_empty():
		return
	if not _host_alive():
		clear_all()
		return
	for id in effects.keys():
		var e: Dictionary = effects[id]
		var def: Dictionary = CD.STATUS[id]
		e["t"] = float(e["t"]) - delta
		if def.has("tick"):
			e["tick"] = float(e["tick"]) - delta
			if float(e["tick"]) <= 0.0:
				e["tick"] = float(def["tick"])
				var dmg := mini(int(def["tick_cap"]), int(def["dmg_per_stack"]) * int(e["stacks"]))
				dmg = maxi(1, int(round(float(dmg) * resist_mult(String(def["element"])))))
				if game and game.has_method("damage_target"):
					game.damage_target(host, dmg, host.global_position, 0.0,
						{"element": String(def["element"]), "source": "dot", "no_proc": true})
				if not _host_alive():
					clear_all()
					return
		if float(e["t"]) <= 0.0:
			effects.erase(id)
			if def.has("immunity"):
				immune_t[id] = float(def["immunity"])
	# periodic, intensity-scaled ambient particles so status is readable
	_fx_t -= delta
	if _fx_t <= 0.0 and game:
		_fx_t = 0.45
		var p := host.global_position + Vector2(randf_range(-4, 4), -8)
		if effects.has("burn"):
			game.fx.burst("fire", p, 2, 18.0, CD.element_color("fire"), -40.0, 0.4)
		if effects.has("poison"):
			game.fx.burst("spark", p, 2, 14.0, CD.element_color("poison"), -30.0, 0.5)
		if effects.has("curse"):
			game.fx.burst("spark", p, 1, 10.0, CD.element_color("necrotic"), -20.0, 0.6)
	_pip_t += delta
	if _pip_t > 0.1:
		_pip_t = 0.0
		queue_redraw()


## Small coloured pips above the host: one per active status, stack count as width.
func _draw() -> void:
	if effects.is_empty():
		return
	var y := -26.0 if is_boss else -19.0
	if is_boss:
		y = -46.0
	var n := effects.size()
	var x := -float(n) * 3.5
	for id in effects:
		var c := Color(String(CD.STATUS[id]["color"]))
		var st := int(effects[id]["stacks"])
		var w := 4.0 + 1.5 * float(st - 1)
		draw_rect(Rect2(Vector2(x, y), Vector2(w, 3)), Color(0.08, 0.06, 0.12, 0.85))
		draw_rect(Rect2(Vector2(x + 0.5, y + 0.5), Vector2(w - 1.0, 2)), c)
		x += w + 2.0
	if effects.has("freeze"):
		draw_rect(Rect2(Vector2(-7, -16), Vector2(14, 16)), Color(0.75, 0.92, 1.0, 0.28))
