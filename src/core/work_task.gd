## One entry of the task list (story 003). Plain data owned by [TaskBoard].
class_name WorkTask
extends RefCounted

## Unique id, assigned by the board.
var id: int
## A [CrisisKind] constant.
var kind: StringName
## Room the work happens in.
var room_id: StringName
## Crisis this task answers, or -1 for a task made by hand (debug button, tests).
var crisis_id: int
## Index of the colonist that claimed the task, or -1 while unclaimed.
var claimed_by: int = -1
## Seconds of work done so far.
var progress: float = 0.0
## True once the claiming colonist has been seen standing in [member room_id].
## Work seconds only count from the board tick after that.
var in_place: bool = false


## Creates a task; see the member descriptions.
func _init(p_id: int, p_kind: StringName, p_room_id: StringName, p_crisis_id: int = -1) -> void:
	id = p_id
	kind = p_kind
	room_id = p_room_id
	crisis_id = p_crisis_id


## True while a colonist holds the task.
func is_claimed() -> bool:
	return claimed_by >= 0
