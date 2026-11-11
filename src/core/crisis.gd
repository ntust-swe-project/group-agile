## One scheduled crisis (story 004, design/game-brief.md MVP 4).
##
## Plain value object produced by [CrisisScheduler] and tracked by the
## CrisisDirector node. It holds no behaviour.
class_name Crisis
extends RefCounted

## Unique per run and deterministic: see [method CrisisScheduler.make_id].
var id: int
## [constant CrisisKind.BREACH] or [constant CrisisKind.MALFUNCTION].
var kind: StringName
## Room the crisis hits; always an id from the station data file.
var room_id: StringName
## The day (1-based) this crisis was scheduled for.
var day: int
## Seconds after the start of [member day] at which the crisis fires.
var start_seconds: float


func _init(
	p_id: int = 0,
	p_kind: StringName = &"",
	p_room_id: StringName = &"",
	p_day: int = 0,
	p_start_seconds: float = 0.0,
) -> void:
	id = p_id
	kind = p_kind
	room_id = p_room_id
	day = p_day
	start_seconds = p_start_seconds
