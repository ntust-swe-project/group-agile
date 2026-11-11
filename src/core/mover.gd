## The single component that moves a colonist between rooms (story 002).
##
## Moving costs a fixed number of seconds per hop and follows the room graph.
## Replace this class to switch to corridor walking; [Colonist] only uses
## [method start_move], [method step], [method is_moving] and [member room_id].
class_name Mover
extends RefCounted

## Seconds one hop between adjacent rooms takes.
var move_seconds: float
## Room the colonist is in; during a hop, the room it left.
var room_id: StringName

var _map: StationMap
var _target: StringName = &""
var _next: StringName = &""
var _elapsed: float = 0.0


## Starts idle in [param start_room] of [param map]; every hop takes
## [param p_move_seconds] seconds.
func _init(map: StationMap, start_room: StringName, p_move_seconds: float) -> void:
	_map = map
	room_id = start_room
	move_seconds = p_move_seconds


## Heads for [param target] along the room graph. A move already in progress
## finishes its current hop first, then re-routes.
func start_move(target: StringName) -> void:
	_target = target
	if not is_moving():
		_begin_hop()


## Advances the move by [param delta] seconds. Returns the seconds left over
## after arriving (0.0 while still moving), so the caller can use them.
func step(delta: float) -> float:
	var left := delta
	while is_moving():
		var needed := move_seconds - _elapsed
		if left < needed:
			_elapsed += left
			return 0.0
		left -= needed
		room_id = _next
		_begin_hop()
	return left


## True while between rooms; a moving colonist cannot work.
func is_moving() -> bool:
	return _next != &""


## Room the current hop enters, or an empty name when not moving.
func next_room() -> StringName:
	return _next


## Progress of the current hop, 0.0 to 1.0.
func hop_progress() -> float:
	if not is_moving() or move_seconds <= 0.0:
		return 0.0
	return _elapsed / move_seconds


func _begin_hop() -> void:
	_elapsed = 0.0
	if room_id == _target:
		_next = &""
		return
	var path := _map.find_path(room_id, _target)
	if path.is_empty():
		push_error("Mover: no route from %s to %s" % [room_id, _target])
		_next = &""
		return
	_next = path[0]
