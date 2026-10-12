extends Node
## The Blighted Depths: a post-victory wave arena beneath the Moonwell.
## Every fourth wave summons a guardian echo; waves pay coins and hearts at milestones.

const BossScript := preload("res://scripts/actors/boss.gd")
const EnemyScript := preload("res://scripts/actors/enemy.gd")
const DB := preload("res://scripts/data/db.gd")

const GUARDIAN_KINDS := ["giantbamboo", "giantfrog", "demoncyclop", "giantspirit"]
const GUARDIAN_TITLES := ["THE BRIARBACK ECHO", "THE GLASSWATER ECHO", "THE EMBER ECHO", "THE QUIET ECHO"]

var game: Node
var active := false
var wave := 0
var _targets: Array = []
var _between_t := 0.0
var _boss: Node = null


func descend() -> void:
	if active:
		return
	active = true
	wave = 0
	_targets.clear()
	_between_t = 0.0
	_boss = null
	game.hud.show_message("A stair of light unfolds beneath the Moonwell...", 3.0)
	game.audio.play_music("boss", 0.8)
	game.audio.play("levelup1", 0.0, -1.0)
	_next_wave()


func ascend(silent := false) -> void:
	if not active:
		return
	active = false
	for t in _targets:
		if is_instance_valid(t):
			t.queue_free()
	_targets.clear()
	if is_instance_valid(_boss):
		_boss.queue_free()
	_boss = null
	game.active_boss = null
	game.hud.hide_boss()
	if not silent:
		game.hud.show_message("You climb the stair of light back to the valley.", 3.0)
		game.current_region = ""
		game._update_region(true)


func targets() -> Array:
	return _targets


func _next_wave() -> void:
	wave += 1
	_between_t = 0.0
	game.hud.show_region("THE BLIGHTED DEPTHS", "depth %d" % wave)
	if wave % 4 == 0:
		_summon_guardian()
		return
	var count := 3 + mini(wave * 2, 14)
	var center: Vector2 = game.moonwell.global_position
	var kinds: Array = DB.ENEMIES.keys()
	kinds.shuffle()
	for i in range(count):
		var kind: String = kinds[i % kinds.size()]
		var e := EnemyScript.new()
		var ang := TAU * i / float(count) + randf() * 0.5
		e.setup(game, kind, center + Vector2.from_angle(ang) * randf_range(56.0, 110.0))
		game.entities.add_child(e)
		e.set_meta("depths", true)
		_targets.append(e)
	game.audio.play("alert2", 0.0, -2.0)
	game.fx.shake(3.0, 0.3)


func _summon_guardian() -> void:
	var kind: String = GUARDIAN_KINDS[(wave / 4 - 1) % GUARDIAN_KINDS.size()]
	var b := BossScript.new()
	b.setup(game, "echo_%d" % wave, kind, game.moonwell.global_position + Vector2(0, -12))
	b.title = GUARDIAN_TITLES[GUARDIAN_KINDS.find(kind)]
	b.max_hp = int(float(int(b.cfg["hp"])) * (1.0 + 0.15 * wave))
	b.hp = b.max_hp
	game.entities.add_child(b)
	b.awake = true
	_boss = b
	_targets.append(b)
	game.on_boss_awake(b)


func _process(delta: float) -> void:
	if not active:
		return
	for i in range(_targets.size() - 1, -1, -1):
		var t: Node = _targets[i]
		if not is_instance_valid(t) or not t.get("alive", false) or t.get("defeated", false):
			_targets.remove_at(i)
	if _targets.is_empty():
		_between_t += delta
		if _between_t >= 2.4:
			_between_t = 0.0
			game.on_depths_wave_cleared(wave)
			_next_wave()
	else:
		_between_t = 0.0
