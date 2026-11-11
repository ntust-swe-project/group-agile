## Loads and validates the run settings from `assets/data/game_config.json`.
##
## Validation happens here, at the load boundary, so the systems that consume
## the values can trust them.
## [codeblock]
## var settings := GameConfig.load_settings()
## if not settings.is_empty():
##     print(settings["total_days"])  # int
## [/codeblock]
class_name GameConfig
extends RefCounted

## Where the settings file lives.
const DEFAULT_PATH := "res://assets/data/game_config.json"

## Every key must be present, numeric and greater than 0.
const REQUIRED_KEYS: Array[String] = ["day_length_seconds", "total_days", "integrity_max"]


## Returns an empty string when [param data] is valid settings, otherwise a
## message saying what is wrong. Pure: no file access, no logging.
static func validate(data: Variant) -> String:
	if not data is Dictionary:
		return "config must be a JSON object"
	for key in REQUIRED_KEYS:
		if not data.has(key):
			return "missing key '%s'" % key
		var value: Variant = data[key]
		if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
			return "'%s' must be a number" % key
		if value <= 0:
			return "'%s' must be greater than 0" % key
	if float(int(data["total_days"])) != float(data["total_days"]):
		return "'total_days' must be a whole number"
	return ""


## Reads [param path] and returns {day_length_seconds: float, total_days: int,
## integrity_max: float}. Pushes an error and returns an empty dictionary when
## the file is missing, is not JSON, or fails [method validate].
static func load_settings(path: String = DEFAULT_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("GameConfig: file not found: %s" % path)
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var error := validate(data)
	if error != "":
		push_error("GameConfig: %s: %s" % [path, error])
		return {}
	return {
		"day_length_seconds": float(data["day_length_seconds"]),
		"total_days": int(data["total_days"]),
		"integrity_max": float(data["integrity_max"]),
	}
