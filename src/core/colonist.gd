## One colonist: fatigue, work assignment and forced rest (story 002).
##
## Pure logic. Drive it with [method tick]. Movement is delegated to [Mover].
## Working = standing in the assigned work room, not moving, not resting.
## At max fatigue the colonist drops work and walks to the dorm; resting starts
## on arrival unless the dorm has an unresolved crisis. Resting ends when
## fatigue falls below the threshold, then the colonist returns to work.
## "Collapsed" = at max fatigue, in the dorm, unable to start resting because
## of a dorm crisis for more than the collapse seconds (counted from arrival).
class_name Colonist
extends RefCounted

enum State { IDLE, WORKING, RESTING }

## Name shown to the player.
var display_name: String
## Current fatigue, 0 to [member fatigue_max].
var fatigue: float = 0.0
## Current state.
var state: State = State.IDLE
## Room the colonist should work in; empty when none.
var work_room: StringName = &""
## The movement component.
var mover: Mover

## Fatigue at which the colonist drops work and goes to rest.
var fatigue_max: float
## Fatigue gained per second of work.
var rise_per_sec: float
## Fatigue lost per second of rest in the dorm.
var fall_per_sec: float
## Rest ends once fatigue falls below this value.
var rest_threshold: float
## Seconds a blocked, exhausted colonist waits in the dorm before collapsing.
var collapse_seconds: float

var _dorm_id: StringName
var _rest_started: bool = false
var _blocked_seconds: float = 0.0


## Creates a colonist named [param p_name] that moves with [param p_mover]
## and rests in [param dorm_id]. [param settings] keys: fatigue_max, fatigue_rise_per_sec, fatigue_fall_per_sec,
## rest_threshold, collapse_seconds (the station data file).
func _init(p_name: String, p_mover: Mover, dorm_id: StringName, settings: Dictionary) -> void:
	display_name = p_name
	mover = p_mover
	_dorm_id = dorm_id
	fatigue_max = settings["fatigue_max"]
	rise_per_sec = settings["fatigue_rise_per_sec"]
	fall_per_sec = settings["fatigue_fall_per_sec"]
	rest_threshold = settings["rest_threshold"]
	collapse_seconds = settings["collapse_seconds"]


## Orders the colonist to work in [param room_id]. While exhausted or resting
## the room is only remembered; work resumes after rest.
func assign_work(room_id: StringName) -> void:
	work_room = room_id
	if state == State.RESTING:
		return
	if fatigue >= fatigue_max:
		_begin_rest()
		return
	state = State.WORKING
	mover.start_move(room_id)


## Forgets the work room (story 003: the task is done or was released). A
## working colonist becomes idle where it stands; a resting one keeps resting
## and ends idle instead of returning to the old room.
func clear_work() -> void:
	work_room = &""
	if state == State.WORKING:
		state = State.IDLE


## True when collapsed (see class description).
func is_collapsed() -> bool:
	return state == State.RESTING and not mover.is_moving() and not _rest_started \
			and fatigue >= fatigue_max and _blocked_seconds > collapse_seconds


## Advances the colonist by [param delta] seconds. [param dorm_has_crisis] is
## whether the dorm has an unresolved crisis right now.
func tick(delta: float, dorm_has_crisis: bool) -> void:
	var left := mover.step(delta)
	if mover.is_moving():
		return
	if state == State.WORKING:
		fatigue = minf(fatigue_max, fatigue + rise_per_sec * left)
		if fatigue >= fatigue_max:
			_begin_rest()
	elif state == State.RESTING:
		if not _rest_started:
			if dorm_has_crisis:
				_blocked_seconds += left
				return
			_blocked_seconds = 0.0
			_rest_started = true
		fatigue = maxf(0.0, fatigue - fall_per_sec * left)
		if fatigue < rest_threshold:
			_end_rest()


func _begin_rest() -> void:
	state = State.RESTING
	_rest_started = false
	_blocked_seconds = 0.0
	mover.start_move(_dorm_id)


func _end_rest() -> void:
	_rest_started = false
	if work_room == &"":
		state = State.IDLE
		return
	state = State.WORKING
	mover.start_move(work_room)
