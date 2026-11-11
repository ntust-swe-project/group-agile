## The `AutoRepair` node of Main (story 005, design/game-brief.md MVP 5).
##
## - [signal Events.day_ended] gives build points ([member points_per_day]).
## - [method build] spends [member module_cost] points on one
##   [AutoRepairModule] in a room; at most one per room.
## - [signal Events.crisis_started] with a malfunction in a room that has a
##   module: the module repairs it after [member repair_seconds] and this node
##   emits [signal Events.task_completed] (task id -1: no TaskBoard task is
##   involved; the crisis id is what CrisisDirector and TaskBoard match on).
## - Colonists may finish first: any [signal Events.task_completed] for a
##   watched crisis cancels the module's countdown, so nothing completes twice.
## - Breaches are ignored. After [signal Events.game_ended] nothing happens.
##
## Values come from [constant CONFIG_PATH]. Time only moves through [method tick];
## tests set [member auto_tick] to false.
extends Node

const CONFIG_PATH := "res://assets/data/auto_repair_config.json"
const MARKERS := preload("res://src/ui/auto_repair_markers.gd")
const PANEL := preload("res://src/ui/auto_repair_panel.gd")
## Keys that must be present in the config; numeric and greater than 0.
const REQUIRED_KEYS: Array[String] = ["points_per_day", "module_cost", "repair_seconds"]

## Task id used in [signal Events.task_completed] for a module repair.
const MODULE_TASK_ID := -1

## Set by Main (main.gd INJECTIONS): the CrisisDirector, read for crises that are
## already active when a module is built. Unusable inside _ready.
var crisis_director: Node
## When true the node ticks itself in _process.
var auto_tick: bool = true
## Build point balance.
var build_points: BuildPoints
## Installed modules, room id -> [AutoRepairModule].
var modules: Dictionary = {}
## Points earned per day.
var points_per_day: int
## Points one module costs.
var module_cost: int
## Seconds from the start of a malfunction to its automatic repair.
var repair_seconds: float
## Room graph, for room ids and marker positions.
var map: StationMap

var _ended: bool = false


## Returns an empty string when [param data] is a valid config, otherwise what
## is wrong. Pure: no file access.
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
	return ""


## Reads and validates [param path]. Pushes an error and returns an empty
## dictionary when the file is missing, not JSON, or invalid.
static func load_config(path: String = CONFIG_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("AutoRepair: file not found: %s" % path)
		return {}
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	var error := validate(data)
	if error != "":
		push_error("AutoRepair: %s: %s" % [path, error])
		return {}
	return data


## Applies a valid config dictionary (see [method validate]) and the room graph.
## Called by _ready with the shipped files unless a test already called it.
func setup(config: Dictionary, p_map: StationMap) -> void:
	points_per_day = int(config["points_per_day"])
	module_cost = int(config["module_cost"])
	repair_seconds = float(config["repair_seconds"])
	map = p_map
	build_points = BuildPoints.new()


func _ready() -> void:
	if build_points == null:
		var config := load_config()
		if config.is_empty():
			return
		var station_map := StationMap.new()
		station_map.setup(StationMap.load_data())
		setup(config, station_map)
	Events.day_ended.connect(_on_day_ended)
	Events.crisis_started.connect(_on_crisis_started)
	Events.task_completed.connect(_on_task_completed)
	Events.game_ended.connect(_on_game_ended)
	var markers := MARKERS.new()
	markers.auto_repair = self
	add_child(markers)
	var panel := PANEL.new()
	panel.auto_repair = self
	add_child(panel)
	set_process(auto_tick)


func _process(delta: float) -> void:
	tick(delta)


## True when a module can be built in [param room_id] now: the room exists, has
## no module, the run is on, and enough points are available.
func can_build(room_id: StringName) -> bool:
	return not _ended and map.has_room(room_id) and not modules.has(room_id) \
			and build_points.can_afford(module_cost)


## Builds a module in [param room_id], spending [member module_cost] points.
## Returns false and changes nothing when [method can_build] is false. A
## malfunction already active in the room is picked up by the new module.
func build(room_id: StringName) -> bool:
	if not can_build(room_id):
		return false
	build_points.spend(module_cost)
	var module := AutoRepairModule.new(room_id, repair_seconds)
	modules[room_id] = module
	if crisis_director != null:
		for crisis: Crisis in crisis_director.active_crises.values():
			if crisis.kind == CrisisKind.MALFUNCTION and crisis.room_id == room_id:
				module.watch(crisis.id)
	return true


## Advances every module by [param delta] seconds and emits
## [signal Events.task_completed] for each malfunction repaired.
func tick(delta: float) -> void:
	if _ended:
		return
	for module: AutoRepairModule in modules.values():
		for crisis_id in module.tick(delta):
			Events.task_completed.emit(MODULE_TASK_ID, crisis_id)


func _on_day_ended(_day: int) -> void:
	if not _ended:
		build_points.add(points_per_day)


func _on_crisis_started(crisis_id: int, kind: StringName, room_id: StringName) -> void:
	if _ended or kind != CrisisKind.MALFUNCTION or not modules.has(room_id):
		return
	modules[room_id].watch(crisis_id)


# Someone (a colonist, or this node a moment ago) finished the crisis: stop counting.
func _on_task_completed(_task_id: int, crisis_id: int) -> void:
	for module: AutoRepairModule in modules.values():
		module.forget(crisis_id)


func _on_game_ended(_won: bool, _reason: StringName) -> void:
	_ended = true
