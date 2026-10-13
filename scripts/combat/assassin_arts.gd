extends RefCounted
## Nightbloom mobility arts: Petal Rush (chain dash) and Vine Hook (grapple).
## Both reuse the player's dash (roll state + _charge dict, see player._state_roll),
## which slides along walls, stops at walls/water and never ends inside obstacles.

const Build := preload("res://scripts/combat/build.gd")
const ClassBook := preload("res://scripts/data/classdb.gd")


# ------------------------------------------------------------------ Petal Rush
## True while a hit has opened the free recast window.
static func rush_recast(p: Node, id: String) -> bool:
	return not p._rush.is_empty() and String(p._rush.get("id", "")) == id and float(p._rush.get("window", 0.0)) > 0.0


static func rush_cast(p: Node, id: String, def: Dictionary, aim: Vector2, dmg: int, info: Dictionary) -> void:
	var dir: Vector2 = aim.normalized() if aim.length() > 0.1 else p.facing
	if p._rush.is_empty():
		p._rush = {"id": id, "count": 0, "cap": int(def.get("chain", 6)) + Build.skill_level(p, id) - 1}
	p._rush["count"] = int(p._rush["count"]) + 1
	p._rush["window"] = 0.0
	p._rush["dashing"] = true
	p._rush["hit"] = false
	p.skill_cd[id] = 0.0  # the real cooldown starts when the chain ends
	var spd := float(def.get("speed", 360.0))
	var inf := info.duplicate()
	p._charge = {"dmg": dmg, "info": inf, "hit": {}, "radius": p.skill_radius(id), "force": 60.0, "no_stun": true, "dry": true,
		"on_hit": func(_t: Node) -> void:
			if not p._rush.is_empty():
				p._rush["hit"] = true}
	p.state = p.State.MOVE
	p._start_dash(dir, p.skill_range(id) / spd, spd)
	p.invulnerable_left = maxf(p.invulnerable_left, 0.12)
	if p.game:
		p.game.fx.spawn("slash", p.global_position + Vector2(0, -6) + dir * 12.0, dir.angle(), 0.9, Color(String(def.get("tint", "f0b8ff"))), null, true)
		p.game.audio.play("slash5", 0.1, -4.0)


static func rush_tick(p: Node, delta: float) -> void:
	if p._rush.is_empty():
		return
	if bool(p._rush.get("dashing", false)):
		if p.state != p.State.ROLL:
			_rush_dash_end(p)
		return
	p._rush["window"] = float(p._rush["window"]) - delta
	if float(p._rush["window"]) <= 0.0 or p.state == p.State.DEAD:
		rush_end(p)


static func _rush_dash_end(p: Node) -> void:
	p._rush["dashing"] = false
	if bool(p._rush.get("hit", false)) and int(p._rush["count"]) < int(p._rush["cap"]):
		p._rush["window"] = float(ClassBook.skill_of(String(p._rush["id"])).get("window", 0.75))
		if p.game:
			p.game.fx.spawn("sparkle", p.global_position + Vector2(0, -26), 0.0, 0.7, Color(1.0, 0.8, 1.0), null, true)
	else:
		rush_end(p)


static func rush_end(p: Node) -> void:
	if p._rush.is_empty():
		return
	var id := String(p._rush["id"])
	p.last_rush = {"count": int(p._rush["count"])}
	p._rush = {}
	p.skill_cd[id] = float(Build.skill_stat(p, id, "cd", 1.0)) * p.skill_cd_scale()


## Chained dashes left in the current chain (0 when no recast is open).
static func rush_left(p: Node, id: String) -> int:
	if not rush_recast(p, id):
		return 0
	return int(p._rush["cap"]) - int(p._rush["count"])


# ------------------------------------------------------------------ Vine Hook
## What a hook fired along `dir` would catch: {"kind": enemy|wall|miss, "point", "target"}.
static func hook_probe(p: Node, dir: Vector2, rng: float) -> Dictionary:
	var origin: Vector2 = p.global_position + Vector2(0, -4)
	var end := origin + dir * rng
	var wall_s := rng + 1.0
	var wall_pt := end
	var space: PhysicsDirectSpaceState2D = p.get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(origin, end, 1)
	q.exclude = [p.get_rid()]
	q.collide_with_bodies = true
	var hit := space.intersect_ray(q)
	if not hit.is_empty():
		var col = hit.get("collider")
		if col == null or (col.get("hp") == null and not col.has_method("take_damage")):
			wall_pt = hit["position"]
			wall_s = origin.distance_to(wall_pt)
	var best: Node2D = null
	var best_s := wall_s
	for t in p.game.hittable_targets(origin, rng + 24.0):
		var pt: Vector2 = t.global_position + Vector2(0, -5)
		var extra := 0.0
		if t.get("cfg") != null and (t.cfg as Dictionary).has("radius"):
			extra = float(t.cfg["radius"])
			pt = t.global_position + Vector2(0, -10)
		var s := (pt - origin).dot(dir)
		if s < 0.0 or s - extra > rng:
			continue
		var perp := absf((pt - origin).cross(dir))
		if perp > 10.0 + extra:
			continue
		var along := maxf(0.0, s - extra)
		if along < best_s:
			best_s = along
			best = t
	if best != null:
		return {"kind": "enemy", "point": origin + dir * best_s, "target": best, "dist": best_s}
	if wall_s <= rng:
		return {"kind": "wall", "point": wall_pt, "dist": wall_s}
	return {"kind": "miss", "point": end, "dist": rng}


static func hook_cast(p: Node, id: String, def: Dictionary, aim: Vector2, dmg: int, info: Dictionary) -> void:
	var dir: Vector2 = aim.normalized() if aim.length() > 0.1 else p.facing
	var rng: float = p.skill_range(id)
	var pr := hook_probe(p, dir, rng)
	var tint := Color(String(def.get("tint", "9cf08a")))
	var vine := VineLine.new()
	vine.tint = tint
	vine.p = p
	vine.tip = pr["point"]
	vine.miss = String(pr["kind"]) == "miss"
	p.game.add_child(vine)
	p.last_hook = {"id": id, "kind": String(pr["kind"]), "point": pr["point"], "tornado": false}
	if String(pr["kind"]) == "miss":
		p.game.audio.play("cancel", 0.0, -8.0)
		return
	p.game.audio.play("launch", 0.08, -4.0)
	var stop := 11.0 if String(pr["kind"]) == "enemy" else 9.0
	var dest: Vector2 = (pr["point"] as Vector2) - dir * stop + Vector2(0, 4)
	var travel: float = p.global_position.distance_to(dest)
	if travel < 4.0:
		# already there: strike/tornado immediately
		if String(pr["kind"]) == "enemy":
			tornado(p, dmg, def, info)
		return
	var spd := float(def.get("speed", 400.0))
	var inf := info.duplicate()
	p._charge = {"dmg": dmg, "info": inf, "hit": {}, "radius": 14.0, "force": 50.0, "no_stun": true, "dry": true, "dest": dest,
		"on_hit": func(_t: Node) -> void:
			if not bool(p.last_hook.get("tornado", false)):
				tornado(p, dmg, def, info),
		"on_end": func() -> void:
			# hooked a foe but the dash stopped just short: still strike on arrival
			if String(p.last_hook.get("kind", "")) == "enemy" and not bool(p.last_hook.get("tornado", false)) and p.game:
				var t: Node = pr.get("target")
				if is_instance_valid(t) and t.global_position.distance_to(p.global_position) < 30.0:
					tornado(p, dmg, def, info)}
	p.state = p.State.MOVE
	p._start_dash(dir, travel / spd + 0.05, spd)
	p.invulnerable_left = maxf(p.invulnerable_left, 0.1)


## Spinning slash around Mallow: every foe in the radius is hit once.
static func tornado(p: Node, dmg: int, def: Dictionary, info: Dictionary) -> void:
	p.last_hook["tornado"] = true
	var r: float = p.skill_radius(String(p.last_hook.get("id", "vine_hook")))
	var c: Vector2 = p.global_position + Vector2(0, -4)
	var n := 0
	for t in p.game.hittable_targets(c, r):
		if not p.game.line_clear(c, t.global_position + Vector2(0, -5)):
			continue
		var inf := info.duplicate()
		inf["force"] = 90.0
		p.deal(t, dmg + 1, inf)
		n += 1
	p.last_hook["tornado_hits"] = n
	p.game.fx.spawn("slash_circular", c, 0.0, 1.5, Color(String(def.get("tint", "9cf08a"))), null, true)
	p.game.fx.spawn("slash_circular", c, PI, 1.1, Color(1, 1, 1, 0.7), null, true)
	p.game.audio.play("slash3", 0.05, -2.0)
	p.game.hitstop(0.05)


## Thorned vine from Mallow's paw to the hook point; shoots out, then retracts.
class VineLine extends Node2D:
	var p: Node = null
	var tip := Vector2.ZERO
	var tint := Color(0.6, 0.94, 0.54)
	var miss := false
	var t := 0.0
	const OUT := 0.08
	const LIFE := 0.32

	func _ready() -> void:
		z_index = 5
		top_level = true

	func _process(delta: float) -> void:
		t += delta
		if t > LIFE or p == null or not is_instance_valid(p):
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var a: Vector2 = p.global_position + Vector2(0, -8)
		var k := clampf(t / OUT, 0.0, 1.0)
		if t > LIFE * 0.6:
			k = clampf(1.0 - (t - LIFE * 0.6) / (LIFE * 0.4), 0.0, 1.0)
		var e := a.lerp(tip, k)
		draw_line(a, e, Color(0.18, 0.36, 0.16), 2.4)
		draw_line(a, e, tint, 1.2)
		var n := int(a.distance_to(e) / 7.0)
		var d := (e - a).normalized()
		for i in range(1, n + 1):
			var q := a + d * 7.0 * float(i)
			draw_line(q, q + d.orthogonal() * (2.0 if i % 2 == 0 else -2.0), Color(0.85, 1.0, 0.7), 1.0)
		draw_circle(e, 2.5, Color(1.0, 0.95, 0.7) if not miss else Color(1.0, 0.5, 0.5))
