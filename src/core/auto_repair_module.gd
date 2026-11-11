## One auto-repair module installed in one room (story 005, MVP 5).
##
## Pure logic. The module counts down every malfunction it is told to watch;
## when a countdown reaches zero [method tick] reports that crisis as repaired.
## Whoever else finishes the crisis first calls [method forget], so a repair is
## never reported twice. Breaches are never given to a module.
class_name AutoRepairModule
extends RefCounted

## Room this module is installed in.
var room_id: StringName
## Seconds from the start of a malfunction until the module repairs it.
var repair_seconds: float

# Crisis id -> seconds left.
var _remaining: Dictionary = {}


## Creates a module for [param p_room_id] with a repair delay of [param p_repair_seconds].
func _init(p_room_id: StringName, p_repair_seconds: float) -> void:
	room_id = p_room_id
	repair_seconds = p_repair_seconds


## Starts repairing [param crisis_id]. Ignored when it is already watched.
func watch(crisis_id: int) -> void:
	if not _remaining.has(crisis_id):
		_remaining[crisis_id] = repair_seconds


## Stops repairing [param crisis_id] (someone else finished it). No-op if unknown.
func forget(crisis_id: int) -> void:
	_remaining.erase(crisis_id)


## True while [param crisis_id] is being repaired by this module.
func is_watching(crisis_id: int) -> bool:
	return _remaining.has(crisis_id)


## Advances all countdowns by [param delta] seconds and returns the crisis ids
## that are repaired now. Those ids are no longer watched.
func tick(delta: float) -> Array[int]:
	var done: Array[int] = []
	for crisis_id: int in _remaining.keys():
		_remaining[crisis_id] -= delta
		if _remaining[crisis_id] <= 0.0:
			done.append(crisis_id)
	for crisis_id in done:
		_remaining.erase(crisis_id)
	return done
