extends RefCounted
## Knockback rules shared by Mallow, field monsters and bosses.
## - push is replaced, not added, so repeated hits can never stack past CAP
## - resistance scales the push (0 = full, 1 = immune)
## - decay is exponential and snaps to zero, so nothing slides forever
## - after a collision the into-wall part is removed, so actors stop at walls
##   instead of vibrating or being pushed through them

const CAP := 190.0
const DECAY := 11.0
const STOP := 6.0

## Per-species resistance (DB.ENEMIES may override with "kb_resist").
const RESIST := {
	"slime": 0.0, "slime2": 0.1, "slime3": 0.2, "bluebat": 0.0, "butterfly": 0.0, "mushroom": 0.1, "mushroom2": 0.15,
	"snake2": 0.1, "spiderred": 0.15, "lizard": 0.2, "mole": 0.3, "owl": 0.1, "eye": 0.2, "flam": 0.25, "skull": 0.3,
	"spirit": 0.1, "spirit2": 0.15, "bamboo": 0.45, "cyclope": 0.55,
}
const BOSS_RESIST := 0.9
const PLAYER_BASE := 140.0


static func resist_for(species: String, cfg: Dictionary) -> float:
	if cfg.has("kb_resist"):
		return clampf(float(cfg["kb_resist"]), 0.0, 1.0)
	return float(RESIST.get(species, 0.15))


## New knockback vector after a hit. `current` keeps a small share so a second
## hit in another direction blends instead of snapping, but the result is capped.
static func push(current: Vector2, away: Vector2, force: float, resist: float) -> Vector2:
	if force <= 0.0:
		return current
	var d := away.normalized() if away.length() > 0.01 else Vector2.RIGHT.rotated(randf() * TAU)
	var v := current * 0.25 + d * force * (1.0 - clampf(resist, 0.0, 1.0))
	return v.limit_length(CAP)


static func decay(kb: Vector2, delta: float) -> Vector2:
	kb *= exp(-DECAY * delta)
	return Vector2.ZERO if kb.length() < STOP else kb


## Move a CharacterBody2D with its own movement velocity plus knockback, then
## strip the into-wall component from both. Returns the remaining knockback.
static func move(body: CharacterBody2D, base: Vector2, kb: Vector2) -> Vector2:
	body.velocity = base + kb
	body.move_and_slide()
	var out_base := base
	for i in range(body.get_slide_collision_count()):
		var n := body.get_slide_collision(i).get_normal()
		if kb.dot(n) < 0.0:
			kb = kb.slide(n) * 0.5
		if out_base.dot(n) < 0.0:
			out_base = out_base.slide(n)
	body.velocity = out_base
	return kb
