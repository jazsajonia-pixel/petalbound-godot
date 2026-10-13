extends RefCounted
## Combat overhaul data: weapon attack patterns and passives, elemental status
## effects with resistances, relic buffs, and tunable balance constants.
## Everything here is plain data so it can be tuned without touching logic.

## Tunables (one place for balance passes).
const BALANCE := {
	"dodge_cooldown": 0.55,       # seconds from roll start until the next dodge
	"dodge_iframe_fraction": 0.85, # share of the roll that is invulnerable
	"flask_cooldown": 1.0,         # seconds between Moontea sips
	"flask_heal": 8,               # quarter-hearts (two hearts) before heal_power
	"defense_cap": 4,
	"crit_cap": 0.60,
	"crit_mult": 2.0,
	"atk_speed_cap": 0.35,
	"cdr_cap": 0.40,
	"elem_cap": 0.50,
	"lifesteal_cap": 0.30,
	"lifesteal_per_sec": 3.0,  # most HP lifesteal can heal in any one second
	"charge_tap": 0.2,         # hold longer than this (s) to start charging
	"charge_move": 0.6,        # move-speed multiplier while charging
	"weapon_bar_max": 5,
	"weapon_switch_lock": 0.3,
	"target_retarget_hysteresis": 0.8, # a new target must score 20% better to steal focus
}

## shape: "arc" (sector from Mallow), "circle" (impact circle ahead), "line" (projectile path).
## reach is in world pixels and is exactly what the ground indicator draws and the hit test uses.
## half_angle (radians) is the sector half-width. lock/cooldown are seconds before attack speed.
const WEAPONS := {
	"thornblade": {"pattern": "combo", "shape": "arc", "reach": 30.0, "finisher_reach": 34.0, "half_angle": 0.95,
		"lock": 0.22, "cooldown": 0.24, "combo": 3, "element": "", "passive": "briar_venom", "color": "ffb8d8"},
	"thornblade_ii": {"pattern": "combo", "shape": "arc", "reach": 30.0, "finisher_reach": 34.0, "half_angle": 0.95,
		"lock": 0.22, "cooldown": 0.24, "combo": 3, "element": "", "passive": "briar_venom", "color": "ffc8e0"},
	"duskfan": {"pattern": "combo", "shape": "arc", "reach": 30.0, "finisher_reach": 34.0, "half_angle": 1.05,
		"lock": 0.2, "cooldown": 0.22, "combo": 3, "element": "", "passive": "biting_dusk", "color": "d8c0ff"},
	"nightfang": {"pattern": "daggers", "shape": "arc", "reach": 24.0, "finisher_reach": 24.0, "half_angle": 0.75,
		"lock": 0.13, "cooldown": 0.15, "combo": 2, "element": "", "passive": "flurry", "color": "c8b0ff"},
	# Unarmed: short, quick jabs. Weak on purpose - the first quests point to a real weapon.
	"fists": {"pattern": "combo", "shape": "arc", "reach": 18.0, "finisher_reach": 20.0, "half_angle": 0.7,
		"lock": 0.18, "cooldown": 0.22, "combo": 3, "element": "", "passive": "", "color": "ffe8d0"},
	"bramble_spear": {"pattern": "combo", "shape": "arc", "reach": 40.0, "finisher_reach": 46.0, "half_angle": 0.35,
		"lock": 0.24, "cooldown": 0.28, "combo": 2, "element": "", "passive": "", "color": "e8d8b0"},
	"cinder_axe": {"pattern": "combo", "shape": "arc", "reach": 28.0, "finisher_reach": 32.0, "half_angle": 1.1,
		"lock": 0.28, "cooldown": 0.32, "combo": 2, "element": "", "passive": "ember_edge", "color": "ffb080"},
	"petalbreaker": {"pattern": "combo", "shape": "arc", "reach": 36.0, "finisher_reach": 40.0, "half_angle": 1.35,
		"lock": 0.36, "cooldown": 0.48, "combo": 2, "element": "", "passive": "sunder", "color": "ffd0e8"},
	"moonwell_blade": {"pattern": "combo", "shape": "arc", "reach": 32.0, "finisher_reach": 36.0, "half_angle": 1.0,
		"lock": 0.22, "cooldown": 0.24, "combo": 3, "element": "arcane", "passive": "moon_wave", "color": "c8dcff"},
	"grave_scythe": {"pattern": "sweep", "shape": "arc", "reach": 36.0, "finisher_reach": 36.0, "half_angle": 1.9,
		"lock": 0.32, "cooldown": 0.46, "combo": 1, "element": "necrotic", "passive": "reap", "color": "a8ffcf"},
	"ironroot_hammer": {"pattern": "slam", "shape": "circle", "reach": 24.0, "offset": 18.0,
		"lock": 0.5, "cooldown": 0.62, "combo": 1, "element": "", "passive": "quake", "color": "e0c8a0"},
	"bloomstaff": {"pattern": "bolt", "shape": "line", "reach": 150.0, "lock": 0.26, "cooldown": 0.42, "combo": 1,
		"speed": 215.0, "homing": 4.0, "element": "arcane", "passive": "moon_resonance", "color": "e0b8ff"},
	"moonglass_staff": {"pattern": "prism", "shape": "line", "reach": 170.0, "lock": 0.28, "cooldown": 0.48, "combo": 1,
		"speed": 230.0, "homing": 3.0, "element": "fire", "passive": "prism", "color": "a8d8ff"},
	# ---- arsenal pass. "hold": hold-to-charge special (scripts/combat/charge_attack.gd +
	# weapon_specials.gd). time = seconds to full charge, cd = special cooldown.
	"oakwood_staff": {"pattern": "combo", "shape": "arc", "reach": 34.0, "finisher_reach": 38.0, "half_angle": 1.15,
		"lock": 0.26, "cooldown": 0.30, "combo": 3, "element": "", "passive": "", "color": "e8c890"},
	"cloudstride_staff": {"pattern": "combo", "shape": "arc", "reach": 38.0, "finisher_reach": 46.0, "half_angle": 0.85,
		"lock": 0.22, "cooldown": 0.25, "combo": 3, "element": "", "passive": "", "color": "ffd27a",
		"hold": {"kind": "afterimage", "time": 0.8, "cd": 3.0, "dist": 72.0, "clone_time": 4.5, "clone_dmg": 0.6, "clone_rate": 0.55, "clone_reach": 36.0}},
	"twin_moon_katanas": {"pattern": "katana", "shape": "arc", "reach": 28.0, "finisher_reach": 32.0, "half_angle": 1.0,
		"lock": 0.15, "cooldown": 0.17, "combo": 4, "element": "", "passive": "", "color": "cfc8ff",
		"hold": {"kind": "moonrend", "time": 0.7, "cd": 1.6, "dist": 104.0, "speed": 380.0, "dmg_mult": 2.5, "width": 14.0}},
	"ironbloom_gauntlet": {"pattern": "combo", "shape": "arc", "reach": 21.0, "finisher_reach": 24.0, "half_angle": 0.8,
		"lock": 0.30, "cooldown": 0.42, "combo": 2, "element": "", "passive": "", "color": "f2b0c8",
		"hold": {"kind": "burst", "time": 0.75, "cd": 2.0, "radius": 30.0, "ahead": 16.0, "dmg_mult": 2.0, "force": 320.0}},
	"thornlash_whip": {"pattern": "whip", "shape": "ring", "reach": 46.0, "sweet": 0.72, "half_angle": PI,
		"lock": 0.32, "cooldown": 0.46, "combo": 1, "element": "", "passive": "", "color": "a8e890", "sweet_mult": 1.5,
		"hold": {"kind": "wide_lash", "time": 0.6, "cd": 0.9, "size_mult": 1.45, "dmg_mult": 1.8}},
	"starweave_gloves": {"pattern": "bolt", "kind": "energy_ball", "shape": "line", "reach": 200.0, "lock": 0.24, "cooldown": 0.40, "combo": 1,
		"speed": 250.0, "homing": 0.0, "element": "arcane", "passive": "", "color": "b8c4ff",
		"hold": {"kind": "overcharge", "time": 0.7, "cd": 1.0, "dmg_mult": 2.4, "scale": 1.8, "radius": 13.0}},
	"direwolf_claws": {"pattern": "daggers", "shape": "arc", "reach": 24.0, "finisher_reach": 24.0, "half_angle": 0.8,
		"lock": 0.13, "cooldown": 0.16, "combo": 2, "element": "", "passive": "wolf_hunger", "color": "e0d8f0",
		"hold": {"kind": "barrage", "time": 0.6, "cd": 2.4, "reach": 44.0, "half_angle": 0.6, "hits": 5, "gap": 0.08}},
	"gale_bow": {"pattern": "bow", "shape": "line", "reach": 190.0, "lock": 0.18, "cooldown": 0.34, "combo": 1,
		"speed": 330.0, "homing": 1.0, "element": "", "passive": "steady_aim", "color": "c0f0d8"},
}

## Weapon passives: description is shown in the satchel; logic lives in player.gd
## (_weapon_on_hit / _weapon_crit_bonus). Passives belong to the held weapon only,
## so they never stack with each other; buffs from relics stack additively.
const PASSIVES := {
	"wolf_hunger": {"name": "Wolf Hunger", "desc": "Heal 7% of the damage you deal (max 3 HP per second, all lifesteal)."},
	"briar_venom": {"name": "Briar Venom", "desc": "The third cut of the combo poisons (1 stack)."},
	"biting_dusk": {"name": "Biting Dusk", "desc": "Combo finishers gain +25% critical chance."},
	"flurry": {"name": "Flurry", "desc": "Each consecutive hit on the same foe gives +4% crit (max 3 stacks, fades after 2s or on a new target)."},
	"ember_edge": {"name": "Ember Edge", "desc": "The second chop of the combo sets foes burning (1 stack)."},
	"sunder": {"name": "Sunder", "desc": "Finishers leave foes Exposed (+20% damage taken, 4s). Slow and heavy."},
	"moon_wave": {"name": "Moon Wave", "desc": "Finishers release a ripple that strikes one more nearby foe."},
	"reap": {"name": "Reap", "desc": "Sweeps curse foes (+25% damage taken, 4s). Slaying a cursed foe heals a quarter-heart."},
	"quake": {"name": "Quake", "desc": "The shockwave chills everything it hits (slow; three chills freeze)."},
	"moon_resonance": {"name": "Moon Resonance", "desc": "Arcane bolts deal +1 damage to foes already suffering a status effect."},
	"prism": {"name": "Prism", "desc": "Bolts cycle Fire (burn) -> Frost (chill) -> Storm (chains to 1 foe)."},
	"steady_aim": {"name": "Steady Aim", "desc": "Fully charged gale shots pierce and gain +25% critical chance."},
}

const ELEMENT_COLORS := {
	"": Color(1.0, 0.95, 0.9),
	"fire": Color(1.0, 0.55, 0.25),
	"ice": Color(0.6, 0.88, 1.0),
	"lightning": Color(1.0, 0.95, 0.45),
	"arcane": Color(0.88, 0.65, 1.0),
	"poison": Color(0.55, 1.0, 0.45),
	"necrotic": Color(0.55, 1.0, 0.75),
}

const ELEMENT_NAMES := {"": "Physical", "fire": "Fire", "ice": "Frost", "lightning": "Storm",
	"arcane": "Arcane", "poison": "Poison", "necrotic": "Necrotic"}

## Status effects.
## max_stacks: cap. duration: seconds, refreshed on reapply. tick: DoT interval.
## dmg_per_stack: DoT damage per tick per stack (total per tick capped by tick_cap).
const STATUS := {
	"burn": {"name": "Burn", "element": "fire", "max_stacks": 3, "duration": 3.0, "tick": 0.6, "dmg_per_stack": 1, "tick_cap": 3, "color": "ff8040"},
	"poison": {"name": "Poison", "element": "poison", "max_stacks": 5, "duration": 4.0, "tick": 1.0, "dmg_per_stack": 1, "tick_cap": 4, "color": "80ff60"},
	"chill": {"name": "Chill", "element": "ice", "max_stacks": 3, "duration": 2.5, "slow_per_stack": 0.15, "freeze_at": 3, "color": "a0e0ff"},
	"freeze": {"name": "Frozen", "element": "ice", "max_stacks": 1, "duration": 1.2, "immunity": 3.0, "color": "e0f8ff"},
	"stun": {"name": "Stunned", "element": "lightning", "max_stacks": 1, "duration": 0.3, "immunity": 1.0, "color": "fff080"},
	"curse": {"name": "Curse", "element": "necrotic", "max_stacks": 1, "duration": 4.0, "vuln": 0.25, "color": "80ffb0"},
	"expose": {"name": "Exposed", "element": "", "max_stacks": 1, "duration": 4.0, "vuln": 0.20, "color": "ffe0a0"},
}

## Per-species resistances: element -> multiplier (0 = immune, 0.5 = half duration/damage).
const RESIST := {
	"flam": {"fire": 0.0}, "spirit2": {"fire": 0.0}, "spiderred": {"fire": 0.5},
	"slime3": {"ice": 0.0}, "mushroom2": {"ice": 0.5}, "spirit": {"ice": 0.5, "necrotic": 0.5},
	"skull": {"poison": 0.0, "necrotic": 0.5}, "snake2": {"poison": 0.5},
}
## Bosses: half duration on everything, immune to freeze and stun, slow capped.
const BOSS_RESIST := {"duration": 0.5, "slow_cap": 0.15, "immune": ["freeze", "stun"]}

## Relic actives (accessory slot). Granted by the equipped relic; never uses a skill slot.
const RELICS := {
	"kindle": {"name": "Kindle", "time": 8.0, "cd": 28.0, "color": "ff9050",
		"desc": "For 8s, every basic attack burns (1 stack)."},
	"nightveil": {"name": "Nightveil", "time": 6.0, "cd": 30.0, "color": "c0a8ff",
		"desc": "For 6s, +35% critical chance and +10% move speed."},
	"overcharge": {"name": "Overcharge", "time": 8.0, "cd": 30.0, "color": "fff080",
		"desc": "For 8s, your hits arc lightning to one nearby foe."},
	"soulfeast": {"name": "Soul Feast", "time": 8.0, "cd": 32.0, "color": "90ffc0",
		"desc": "For 8s, +25% lifesteal and every hit curses."},
	"swiftwind": {"name": "Swiftwind", "time": 6.0, "cd": 26.0, "color": "c8f8ff",
		"desc": "For 6s, +35% attack speed and +15% move speed."},
	"barkskin": {"name": "Barkskin", "time": 5.0, "cd": 30.0, "color": "b8e090",
		"desc": "For 5s, +2 defense and regenerate a quarter-heart per second."},
}

## Human-readable stat names for gear/compare panels.
const STAT_NAMES := {
	"atk": "Attack", "atk_speed": "Attack speed", "crit": "Critical", "hearts": "Hearts", "defense": "Defense",
	"speed": "Move speed", "cdr": "Cooldown reduction", "elem": "Elemental dmg", "focus": "Focus", "lifesteal": "Lifesteal",
	"ranged_bonus": "Ranged dmg", "poise": "Poise", "stamina_regen": "Stamina regen", "heal_power": "Healing",
}
const PERCENT_STATS := ["atk_speed", "crit", "speed", "cdr", "elem", "lifesteal", "poise", "stamina_regen", "heal_power"]


static func weapon(id: String) -> Dictionary:
	return WEAPONS.get(id, WEAPONS["fists"])


static func element_color(element: String) -> Color:
	return ELEMENT_COLORS.get(element, ELEMENT_COLORS[""])


static func format_stat(key: String, value: float) -> String:
	var sign := "+" if value >= 0.0 else ""
	if key in PERCENT_STATS:
		return "%s%d%% %s" % [sign, int(round(value * 100.0)), STAT_NAMES.get(key, key)]
	return "%s%d %s" % [sign, int(round(value)), STAT_NAMES.get(key, key)]
