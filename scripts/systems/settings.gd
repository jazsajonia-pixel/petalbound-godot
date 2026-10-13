extends RefCounted
## Player preferences persisted in user://petalbound_settings.cfg (separate from
## the journey save so preferences survive New Journey and save erasure).
## Every key here is wired to a working option; see apply().

const PATH := "user://petalbound_settings.cfg"
static var path_override := ""

const DEFAULTS := {
	"joystick_mode": "floating",   # "floating" (centres on first touch) | "fixed"
	"joystick_deadzone": 0.08,
	"joystick_sensitivity": 1.0,
	"hud_scale": 1.0,              # whole right cluster + joystick
	"button_size": 1.0,            # touch button radius multiplier
	"hud_opacity": 0.9,
	"music_volume": 0.7,
	"sfx_volume": 0.85,
	"screen_shake": 1.0,
	"fx_intensity": 1.0,
	"damage_numbers": true,
	"auto_target": true,
	"aim_assist": true,
	"attack_indicator": 0.8,       # opacity of the always-on basic attack area
	"quality_high": true,
	"touch_controls": "auto",      # "auto" | "on" | "off"
	"layout": {},                  # control id -> [dx, dy] offset from default
}


static func path() -> String:
	return path_override if path_override != "" else PATH


static func load_all() -> Dictionary:
	var out := DEFAULTS.duplicate(true)
	var cf := ConfigFile.new()
	if cf.load(path()) != OK:
		return out
	for k in DEFAULTS:
		if cf.has_section_key("settings", k):
			var v = cf.get_value("settings", k)
			if typeof(v) == typeof(DEFAULTS[k]) or (typeof(DEFAULTS[k]) == TYPE_FLOAT and typeof(v) == TYPE_INT):
				out[k] = v
	out["joystick_deadzone"] = clampf(float(out["joystick_deadzone"]), 0.0, 0.35)
	out["joystick_sensitivity"] = clampf(float(out["joystick_sensitivity"]), 0.6, 1.8)
	out["hud_scale"] = clampf(float(out["hud_scale"]), 0.75, 1.3)
	out["button_size"] = clampf(float(out["button_size"]), 0.8, 1.35)
	out["hud_opacity"] = clampf(float(out["hud_opacity"]), 0.3, 1.0)
	if not out["joystick_mode"] in ["floating", "fixed"]:
		out["joystick_mode"] = "floating"
	if not out["touch_controls"] in ["auto", "on", "off"]:
		out["touch_controls"] = "auto"
	return out


static func save_all(s: Dictionary) -> bool:
	var cf := ConfigFile.new()
	for k in DEFAULTS:
		cf.set_value("settings", k, s.get(k, DEFAULTS[k]))
	return cf.save(path()) == OK


static func erase() -> void:
	if FileAccess.file_exists(path()):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path()))
