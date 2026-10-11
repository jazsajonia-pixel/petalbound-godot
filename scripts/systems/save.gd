extends RefCounted
## JSON save slot in user://.

const PATH := "user://petalbound_save.json"
const VERSION := 2

static var path_override := ""


static func path() -> String:
	return path_override if path_override != "" else PATH


static func exists() -> bool:
	return FileAccess.file_exists(path())


static func write(data: Dictionary) -> bool:
	data["version"] = VERSION
	var f := FileAccess.open(path(), FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data))
	return true


static func read() -> Dictionary:
	if not exists():
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path()))
	if typeof(parsed) != TYPE_DICTIONARY or int(parsed.get("version", 0)) != VERSION:
		return {}
	return parsed


static func erase() -> void:
	if exists():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path()))
