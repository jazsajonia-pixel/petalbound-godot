extends RefCounted
## Signature weapon behaviour: the whip spin basic attack and every hold-to-charge
## special (see CD.WEAPONS[...]["hold"]). Static helpers that act on the player.

const DB := preload("res://scripts/data/db.gd")
const CD := preload("res://scripts/data/combat_data.gd")
const CloneScript := preload("res://scripts/combat/clone.gd")
const SlashFX := preload("res://scripts/combat/slash_fx.gd")


static func release(p: Node, hold: Dictionary, dir: Vector2) -> void:
	if p.game == null:
		return
	match String(hold.get("kind", "")):
		"afterimage":
			afterimage(p, hold, dir)
		"moonrend":
			moonrend(p, hold, dir)
		"burst":
			burst(p, hold, dir)
		"wide_lash":
			whip_attack(p, p.weapon_def(), float(hold.get("size_mult", 1.45)), float(hold.get("dmg_mult", 1.8)), true)
		"overcharge":
			overcharge(p, hold, dir)
		"barrage":
			barrage(p, hold, dir)


static func base_damage(p: Node) -> int:
	return int(DB.ITEMS.get(p.get_weapon_id(), {}).get("damage", 2)) + p.attack_bonus()


# ------------------------------------------------------------------ ground checks
## True when Mallow could stand at `pos` (no wall, prop, water or void).
static func ground_ok(p: Node, pos: Vector2) -> bool:
	var w = p.game.world
	var inside: bool = pos.x >= 0.0 and pos.y >= 0.0 and pos.x < w.world_size.x and pos.y < w.world_size.y
	if inside and (w.is_solid(pos + Vector2(0, -4)) or w.is_solid(pos + Vector2(0, 2)) or w.is_water(pos)):
		return false
	var space: PhysicsDirectSpaceState2D = p.get_world_2d().direct_space_state
	var q := PhysicsPointQueryParameters2D.new()
	q.collision_mask = 1
	q.collide_with_bodies = true
	q.exclude = [p.get_rid()]
	for off in [Vector2(0, -3), Vector2(-4, 0), Vector2(4, 0)]:
		q.position = pos + off
		for hit in space.intersect_point(q, 4):
			var col = hit.get("collider")
			if col != null and col.get("hp") == null and not col.has_method("take_damage"):
				return false
	return true


## Farthest valid landing point up to `dist` along `dir` (never through walls).
static func blink_point(p: Node, dir: Vector2, dist: float) -> Vector2:
	var from: Vector2 = p.global_position
	if p.game == null:
		return from
	for i in range(10, 0, -1):
		var probe := from + dir * dist * float(i) / 10.0
		if ground_ok(p, probe) and p.game.line_clear(from + Vector2(0, -4), probe + Vector2(0, -4)):
			return probe
	return from


## How far a dash along `dir` can travel before a wall or water (preview only;
## the real dash uses move_and_slide and stops on water/walls by itself).
static func dash_length(p: Node, dir: Vector2, dist: float) -> float:
	if p.game == null:
		return dist
	var from: Vector2 = p.global_position
	var step := 6.0
	var d := step
	while d <= dist:
		var probe := from + dir * d
		if not p.game.line_clear(from + Vector2(0, -4), probe + Vector2(0, -4)):
			return maxf(0.0, d - step)
		var w = p.game.world
		if probe.x >= 0.0 and probe.y >= 0.0 and probe.x < w.world_size.x and probe.y < w.world_size.y and w.is_water(probe):
			return maxf(0.0, d - step)
		d += step
	return dist


# ------------------------------------------------------------------ whip
## 360° spin; foes in the outer tip band (sweet spot) take sweet_mult damage.
static func whip_attack(p: Node, w: Dictionary, size_mult := 1.0, dmg_mult := 1.0, big := false) -> int:
	var spd: float = p.attack_speed_mult()
	p._begin_attack(float(w["lock"]) * (1.25 if big else 1.0) / spd, float(w["cooldown"]) / spd)
	p._swing_weapon(0.26 / spd, true)
	if p.game == null:
		return 0
	var reach := float(w.get("reach", 46.0)) * size_mult
	var inner := reach * float(w.get("sweet", 0.72))
	var origin: Vector2 = p.global_position + Vector2(0, -4)
	var base := base_damage(p)
	var tint := Color(String(w.get("color", "a8e890")))
	var fx := WhipSwing.new()
	fx.reach = reach
	fx.inner = inner
	fx.tint = tint
	fx.big = big
	fx.start = p.facing.angle()
	p.game.add_child(fx)
	fx.global_position = origin
	p.game.audio.play("slash3" if big else "slash5", 0.08, -3.0)
	var hits := 0
	var sweet_hits := 0
	for t in p.game.targets_in_arc(origin, p.facing, reach, PI):
		var pt: Vector2 = t.global_position + Vector2(0, -5)
		var extra := 0.0
		if t.get("cfg") != null and (t.cfg as Dictionary).has("radius"):
			extra = float(t.cfg["radius"])
			pt = t.global_position + Vector2(0, -10)
		var dist: float = maxf(0.0, pt.distance_to(origin) - extra)
		var dmg := float(base) * dmg_mult
		var sweet := dist >= inner - 2.0
		if sweet:
			dmg *= float(w.get("sweet_mult", 1.5))
			sweet_hits += 1
			p.game.fx.spawn("spark", t.global_position + Vector2(0, -8), 0.0, 0.8, Color(1, 0.95, 0.5), null, true)
		p.deal(t, maxi(1, int(round(dmg))), {"element": String(w.get("element", "")), "source": "basic", "force": 90.0 if big else 60.0, "sweet": sweet})
		hits += 1
	p.game.break_props(origin, reach * 0.7)
	p.last_whip = {"hits": hits, "sweet": sweet_hits, "reach": reach, "big": big}
	if hits > 0:
		p.game.hitstop(0.05 if big else 0.03)
	return hits


# ------------------------------------------------------------------ staff
static func afterimage(p: Node, hold: Dictionary, dir: Vector2) -> void:
	var from: Vector2 = p.global_position
	var to := blink_point(p, dir, float(hold.get("dist", 72.0)))
	if p.clone_ref != null and is_instance_valid(p.clone_ref):
		p.clone_ref.queue_free()
	var c := CloneScript.new()
	p.game.entities.add_child(c)  # y-sorted with Mallow and the foes
	c.global_position = from
	c.setup(p, hold, maxi(1, int(round(float(base_damage(p)) * float(hold.get("clone_dmg", 0.6))))))
	p.clone_ref = c
	for i in range(3):
		p._afterimage()
	p.global_position = to
	p.velocity = Vector2.ZERO
	p.game.fx.spawn("spark_circle", to + Vector2(0, -6), 0.0, 0.9, Color(1.0, 0.85, 0.5), null, true)
	p.game.fx.spawn("smoke", from + Vector2(0, -6), 0.0, 0.8, Color(1.0, 0.9, 0.7, 0.7))
	p.game.audio.play("spirit", 0.05, -4.0, to)


# ------------------------------------------------------------------ katanas
static func moonrend(p: Node, hold: Dictionary, dir: Vector2) -> void:
	var speed := float(hold.get("speed", 380.0))
	var dmg := maxi(1, int(round(float(base_damage(p)) * float(hold.get("dmg_mult", 2.5)))))
	p._charge = {"dmg": dmg, "info": {"element": "", "source": "special"}, "hit": {}, "radius": float(hold.get("width", 14.0)),
		"force": 70.0, "no_stun": true, "dry": true, "trail": Color(0.8, 0.78, 1.0)}
	p.state = p.State.MOVE
	p._start_dash(dir, float(hold.get("dist", 104.0)) / speed, speed)
	p.game.fx.spawn("slash_double", p.global_position + Vector2(0, -6) + dir * 14.0, dir.angle(), 1.2, Color(0.85, 0.82, 1.0), null, true)
	SlashFX.spawn(p.game, p.global_position + Vector2(0, -6) + dir * 14.0, dir, Color(0.85, 0.82, 1.0), "cross", 1.25)
	p.game.audio.play("slash3", 0.04, -2.0)


# ------------------------------------------------------------------ gauntlet
static func burst(p: Node, hold: Dictionary, dir: Vector2) -> void:
	p._begin_attack(0.3, 0.35)
	p._swing_weapon(0.2, true)
	var origin: Vector2 = p.global_position + Vector2(0, -4)
	var center := origin + dir * float(hold.get("ahead", 16.0))
	var r := float(hold.get("radius", 30.0))
	var dmg := maxi(1, int(round(float(base_damage(p)) * float(hold.get("dmg_mult", 2.0)))))
	var n := 0
	for t in p.game.hittable_targets(center, r):
		if not p.game.line_clear(origin, t.global_position + Vector2(0, -5)):
			continue
		p.deal(t, dmg, {"element": "", "source": "special", "force": float(hold.get("force", 320.0)), "from": origin, "status": {"stun": 1}})
		n += 1
	p.game.fx.spawn("explosion", center, 0.0, 1.1, Color(1.0, 0.75, 0.85), null, true)
	p.game.fx.spawn("spark_circle", center, 0.0, 1.5, Color(1.0, 0.8, 0.9), null, true)
	p.game.break_props(center, r * 0.8)
	p.game.audio.play("explosion", 0.05, -4.0, center)
	if n > 0:
		p.game.hitstop(0.07)
	p.last_burst = {"hits": n, "center": center}


# ------------------------------------------------------------------ gloves
static func overcharge(p: Node, hold: Dictionary, dir: Vector2) -> void:
	var w: Dictionary = p.weapon_def()
	p._begin_attack(float(w["lock"]), float(w["cooldown"]))
	p._swing_weapon(0.18, false, true)
	var dmg := maxi(1, int(round(float(int(DB.ITEMS[p.get_weapon_id()].get("damage", 3)) + p.ranged_bonus()) * float(hold.get("dmg_mult", 2.4)))))
	var speed := float(w.get("speed", 250.0)) * 0.9
	p._spawn_player_projectile({"kind": "energy_ball", "pos": p.global_position + Vector2(0, -9) + dir * 8.0, "dir": dir, "speed": speed,
		"homing": 0.0, "life": float(w["reach"]) * 1.1 / speed, "element": "arcane", "scale": float(hold.get("scale", 1.8)),
		"radius": float(hold.get("radius", 13.0)), "pierce": true, "tint": Color(1.0, 0.95, 0.7)},
		dmg, {"element": "arcane", "source": "special", "force": 180.0})
	p.game.fx.spawn("magic_circle", p.global_position + Vector2(0, -6), 0.0, 0.7, Color(0.8, 0.85, 1.0), null, true)
	p.game.audio.play("magic3", 0.05, -3.0)


# ------------------------------------------------------------------ claws
static func barrage(p: Node, hold: Dictionary, dir: Vector2) -> void:
	var hits := int(hold.get("hits", 5))
	var gap := float(hold.get("gap", 0.08))
	p._begin_attack(gap * float(hits) + 0.1, gap * float(hits) + 0.2)
	p.velocity = Vector2.ZERO
	p.barrage_hits = 0
	for i in range(hits):
		if i == 0:
			_claw_strike(p, hold, dir, i)
		else:
			p.get_tree().create_timer(gap * float(i), false).timeout.connect(func() -> void:
				if is_instance_valid(p) and p.state != p.State.DEAD and p.game:
					_claw_strike(p, hold, dir, i))


static func _claw_strike(p: Node, hold: Dictionary, dir: Vector2, i: int) -> void:
	var origin: Vector2 = p.global_position + Vector2(0, -4)
	var reach := float(hold.get("reach", 44.0))
	var dmg := base_damage(p)
	for t in p.game.targets_in_arc(origin, dir, reach, float(hold.get("half_angle", 0.6))):
		p.deal(t, dmg, {"element": "", "source": "special", "force": 30.0})
		p.barrage_hits += 1
	var side := -1.0 if i % 2 == 0 else 1.0
	var at := origin + dir * (reach * 0.55) + dir.orthogonal() * side * 6.0
	p.game.fx.spawn("claw", at, dir.angle() + side * 0.3, 0.85, Color(0.95, 0.85, 1.0), null, true)
	SlashFX.spawn(p.game, at, dir.rotated(side * 0.12), Color(0.95, 0.85, 1.0), "claw", 0.9)
	p.game.audio.play("slash" if i % 2 == 0 else "slash2", 0.12, -6.0)
	p._swing_weapon(0.07, false)


## Procedural whip ring: a thorned vine sweeping a full circle, the sweet band glowing.
class WhipSwing extends Node2D:
	var reach := 46.0
	var inner := 33.0
	var tint := Color(0.66, 0.9, 0.56)
	var big := false
	var start := 0.0
	var t := 0.0
	const DUR := 0.26

	func _ready() -> void:
		z_index = 4

	func _process(delta: float) -> void:
		t += delta
		if t > DUR + 0.18:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var k := clampf(t / DUR, 0.0, 1.0)
		var fade := 1.0 - clampf((t - DUR) / 0.18, 0.0, 1.0)
		var a1 := start + TAU * k
		var a0 := maxf(start, a1 - 2.6)
		var c := Color(tint.r, tint.g, tint.b, 0.85 * fade)
		# vine body from the paw out to the tip, sweeping
		var tip := Vector2.from_angle(a1) * reach
		var mid := Vector2.from_angle(a1 - 0.35) * reach * 0.55
		draw_polyline(PackedVector2Array([Vector2.ZERO, mid, tip]), Color(0.25, 0.45, 0.2, fade), 2.5 if big else 2.0)
		draw_polyline(PackedVector2Array([Vector2.ZERO, mid, tip]), c, 1.2)
		# sweep trail at the tip band (the sweet spot)
		draw_arc(Vector2.ZERO, (reach + inner) * 0.5, a0, a1, 24, Color(1.0, 0.95, 0.55, 0.45 * fade), reach - inner)
		draw_arc(Vector2.ZERO, reach, a0, a1, 24, Color(1, 1, 0.8, 0.8 * fade), 1.0)
		draw_circle(tip, 2.5 if big else 2.0, Color(1, 0.95, 0.6, fade))
