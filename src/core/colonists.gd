## The `Colonists` node of Main (story 002): owns the colonists and ticks them.
##
## Emits [signal Events.colonists_collapsed] once when all colonists are
## collapsed at the same time. Tracks whether the dorm has an unresolved crisis
## from [signal Events.crisis_started] / [signal Events.crisis_resolved].
## Tests set [member auto_tick] to false and call [method tick] themselves.
extends Node

## Colonists, in data-file order.
var colonists: Array[Colonist] = []
## When true the node ticks itself in _process.
var auto_tick: bool = true

var _map: StationMap
var _dorm_crisis_ids := {}
var _collapse_emitted: bool = false
var _ended: bool = false


## Builds the map and colonists from [param data] (station data file shape).
## Called by _ready with the data file unless a test already called it.
func setup(data: Dictionary) -> void:
	_map = StationMap.new()
	_map.setup(data)
	for colonist_name: String in data["colonists"]:
		var mover := Mover.new(_map, StringName(data["start_room"]), data["move_seconds"])
		colonists.append(Colonist.new(colonist_name, mover, _map.dorm_id, data))


func _ready() -> void:
	if _map == null:
		setup(StationMap.load_data())
	Events.crisis_started.connect(_on_crisis_started)
	Events.crisis_resolved.connect(_on_crisis_resolved)
	Events.game_ended.connect(_on_game_ended)
	set_process(auto_tick)


func _process(delta: float) -> void:
	tick(delta)


## Orders colonist [param index] to work in [param room_id] (TaskBoard calls this).
## Bad input is reported with push_error and ignored.
func command_go_to(index: int, room_id: StringName) -> void:
	if index < 0 or index >= colonists.size():
		push_error("command_go_to: no colonist at index %d" % index)
		return
	if not _map.has_room(room_id):
		push_error("command_go_to: unknown room %s" % room_id)
		return
	colonists[index].assign_work(room_id)


## True while the dorm has at least one unresolved crisis.
func dorm_has_unresolved_crisis() -> bool:
	return not _dorm_crisis_ids.is_empty()


## Advances every colonist by [param delta] seconds.
func tick(delta: float) -> void:
	if _ended:
		return
	var dorm_crisis := dorm_has_unresolved_crisis()
	# An empty roster is not "everyone collapsed"; without this guard it would
	# emit colonists_collapsed on the first tick and end the game.
	var all_collapsed := not colonists.is_empty()
	for colonist in colonists:
		colonist.tick(delta, dorm_crisis)
		all_collapsed = all_collapsed and colonist.is_collapsed()
	if all_collapsed and not _collapse_emitted:
		_collapse_emitted = true
		Events.colonists_collapsed.emit()
	elif not all_collapsed:
		_collapse_emitted = false


func _on_crisis_started(crisis_id: int, _kind: StringName, room_id: StringName) -> void:
	if room_id == _map.dorm_id:
		_dorm_crisis_ids[crisis_id] = true


func _on_crisis_resolved(crisis_id: int) -> void:
	_dorm_crisis_ids.erase(crisis_id)


func _on_game_ended(_won: bool, _reason: StringName) -> void:
	_ended = true
