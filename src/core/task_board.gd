## The `TaskBoard` node of Main (story 003, design/game-brief.md MVP 3).
##
## Holds the task list and hands tasks to colonists. The player never picks a
## colonist for a job: they only reorder [member priority_order], and free
## colonists choose for themselves with [TaskPicker] (indirect control).
##
## Each [method tick]:
## 1. a colonist who went to rest (fatigue) drops its task back to the list,
##    progress reset to zero, and forgets its work room so it is idle after rest;
## 2. a colonist standing in its task room, working and not moving, adds [param delta]
##    work seconds (starting the tick after it was first seen there); at
##    [member task_work_seconds] the task is removed and
##    [signal Events.task_completed] is emitted;
## 3. every idle colonist below max fatigue without a task claims one.
##
## When a crisis is resolved by someone else (story 005 AutoRepair emits
## [signal Events.task_completed] itself), [signal Events.crisis_resolved]
## removes the task for that crisis and frees its colonist.
##
## Changing [member priority_order] applies from the next pick. A task already
## claimed is never taken away from its colonist. Tests set [member auto_tick]
## to false and call [method tick] themselves. [member colonists] is injected by
## Main (main.gd INJECTIONS), so it is not usable inside [method Node._ready].
extends Node

const PRIORITY_PANEL := preload("res://src/ui/priority_panel.tscn")

## The Colonists node; set by Main before the first frame.
var colonists: Node
## When true the node ticks itself in _process.
var auto_tick: bool = true
## Open tasks, claimed or not.
var tasks: Array[WorkTask] = []
## Task kinds, highest priority first.
var priority_order: Array[StringName] = []
## Work seconds a colonist needs in the room to finish a task.
var task_work_seconds: float
## Room graph, used for distances and room names.
var map: StationMap

var _next_id: int = 1
var _ended: bool = false


## Reads the map, work time and default priority from [param data] (station
## data file shape). Called by _ready with the data file unless a test already called it.
func setup(data: Dictionary) -> void:
	map = StationMap.new()
	map.setup(data)
	task_work_seconds = data["task_work_seconds"]
	assert(task_work_seconds > 0.0, "task_work_seconds must be greater than 0")
	for kind: String in data["default_priority"]:
		priority_order.append(StringName(kind))
	assert(priority_order.size() == CrisisKind.ALL.size(), "default_priority must list every crisis kind once")
	for kind: StringName in CrisisKind.ALL:
		assert(priority_order.has(kind), "default_priority is missing " + kind)


func _ready() -> void:
	if map == null:
		setup(StationMap.load_data())
	Events.crisis_started.connect(_on_crisis_started)
	Events.crisis_resolved.connect(_on_crisis_resolved)
	Events.game_ended.connect(_on_game_ended)
	set_process(auto_tick)
	var panel := PRIORITY_PANEL.instantiate()
	panel.board = self
	add_child(panel)


func _process(delta: float) -> void:
	tick(delta)


## Adds an unclaimed task and returns its id. [param crisis_id] is the crisis it
## answers, or -1 for a hand-made task. Returns -1 and reports with push_error
## when [param kind] or [param room_id] is unknown.
func add_task(kind: StringName, room_id: StringName, crisis_id: int = -1) -> int:
	if not CrisisKind.ALL.has(kind):
		push_error("add_task: unknown kind %s" % kind)
		return -1
	if not map.has_room(room_id):
		push_error("add_task: unknown room %s" % room_id)
		return -1
	var task := WorkTask.new(_next_id, kind, room_id, crisis_id)
	_next_id += 1
	tasks.append(task)
	return task.id


## The task colonist [param colonist_index] holds, or null.
func task_of(colonist_index: int) -> WorkTask:
	for task: WorkTask in tasks:
		if task.claimed_by == colonist_index:
			return task
	return null


## Raises [param kind] one place in [member priority_order]; no-op at the top.
func move_kind_up(kind: StringName) -> void:
	var index := priority_order.find(kind)
	if index > 0:
		_swap_priority(index, index - 1)


## Lowers [param kind] one place in [member priority_order]; no-op at the bottom.
func move_kind_down(kind: StringName) -> void:
	var index := priority_order.find(kind)
	if index >= 0 and index < priority_order.size() - 1:
		_swap_priority(index, index + 1)


## Advances task work and assignment by [param delta] seconds.
func tick(delta: float) -> void:
	if _ended:
		return
	_release_resting()
	_do_work(delta)
	_assign_idle()


func _swap_priority(a: int, b: int) -> void:
	var kind := priority_order[a]
	priority_order[a] = priority_order[b]
	priority_order[b] = kind


func _colonist(index: int) -> Colonist:
	return colonists.colonists[index]


func _release_resting() -> void:
	for task: WorkTask in tasks:
		if not task.is_claimed():
			continue
		var colonist := _colonist(task.claimed_by)
		if colonist.state == Colonist.State.RESTING:
			task.claimed_by = -1
			task.progress = 0.0
			task.in_place = false
			colonist.clear_work()


func _do_work(delta: float) -> void:
	for task: WorkTask in tasks.duplicate():
		if not task.is_claimed():
			continue
		var colonist := _colonist(task.claimed_by)
		var in_place: bool = colonist.state == Colonist.State.WORKING \
				and not colonist.mover.is_moving() \
				and colonist.mover.room_id == task.room_id
		if not in_place:
			task.in_place = false
			continue
		if task.in_place:
			task.progress += delta
		task.in_place = true
		if task.progress >= task_work_seconds:
			tasks.erase(task)
			colonist.clear_work()
			Events.task_completed.emit(task.id, task.crisis_id)


func _assign_idle() -> void:
	for index in colonists.colonists.size():
		var colonist := _colonist(index)
		if colonist.state != Colonist.State.IDLE or colonist.fatigue >= colonist.fatigue_max:
			continue
		if task_of(index) != null:
			continue
		var task := TaskPicker.pick(tasks, priority_order, colonist.mover.room_id, map)
		if task == null:
			continue
		task.claimed_by = index
		colonists.command_go_to(index, task.room_id)


func _on_crisis_started(crisis_id: int, kind: StringName, room_id: StringName) -> void:
	if _ended:
		return
	add_task(kind, room_id, crisis_id)


# A crisis can end without this board finishing its task (AutoRepair, story 005).
# Drop the matching task and send its colonist back to idle. Hand-made tasks
# (crisis_id -1) are never matched; a task this board already completed is gone.
func _on_crisis_resolved(crisis_id: int) -> void:
	if crisis_id < 0:
		return
	for task: WorkTask in tasks.duplicate():
		if task.crisis_id != crisis_id:
			continue
		if task.is_claimed():
			_colonist(task.claimed_by).clear_work()
		tasks.erase(task)


func _on_game_ended(_won: bool, _reason: StringName) -> void:
	_ended = true
