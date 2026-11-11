## Priority and task panel (story 003): reorder task kinds, see the task list
## and what every colonist is doing.
##
## The player can only change priorities (and, until story 004 produces real
## crises, add debug tasks). There is deliberately no control that sends a
## given colonist to a given task. Everything here reads [member board] each frame.
extends Control

## Most task lines shown before the rest are summed up.
const MAX_TASK_LINES := 7

## The TaskBoard to show; set by TaskBoard before this node enters the tree.
var board: Node

var _priority_labels: Array[Label] = []
var _debug_room_cursor: int = 0

@onready var _priority_rows: VBoxContainer = %PriorityRows
@onready var _debug_buttons: HBoxContainer = %DebugButtons
@onready var _task_title: Label = %TaskTitle
@onready var _task_list: Label = %TaskList
@onready var _colonist_list: Label = %ColonistList


func _ready() -> void:
	for rank in CrisisKind.ALL.size():
		var row := HBoxContainer.new()
		var label := Label.new()
		label.custom_minimum_size.x = 170
		row.add_child(label)
		var up := Button.new()
		up.text = "Up"
		up.pressed.connect(func() -> void: board.move_kind_up(board.priority_order[rank]))
		row.add_child(up)
		var down := Button.new()
		down.text = "Down"
		down.pressed.connect(func() -> void: board.move_kind_down(board.priority_order[rank]))
		row.add_child(down)
		_priority_rows.add_child(row)
		_priority_labels.append(label)
	for kind: StringName in CrisisKind.ALL:
		var button := Button.new()
		button.text = "+ " + _kind_name(kind)
		button.pressed.connect(_add_debug_task.bind(kind))
		_debug_buttons.add_child(button)


func _process(_delta: float) -> void:
	for rank in _priority_labels.size():
		_priority_labels[rank].text = "%d. %s" % [rank + 1, _kind_name(board.priority_order[rank])]
	_task_title.text = "Tasks (%d)" % board.tasks.size()
	_task_list.text = _task_lines()
	_colonist_list.text = _colonist_lines()


# Debug only: rooms are taken in data-file order, round robin, so the result is
# the same on every run.
func _add_debug_task(kind: StringName) -> void:
	var rooms: Array[StringName] = board.map.room_ids
	board.add_task(kind, rooms[_debug_room_cursor % rooms.size()])
	_debug_room_cursor += 1


func _task_lines() -> String:
	var lines: Array[String] = []
	for task: WorkTask in board.tasks:
		if lines.size() == MAX_TASK_LINES:
			lines.append("... +%d more" % (board.tasks.size() - MAX_TASK_LINES))
			break
		var who := "waiting"
		if task.is_claimed():
			who = board.colonists.colonists[task.claimed_by].display_name
		lines.append("%s @ %s: %s" % [_kind_name(task.kind), _room_name(task.room_id), who])
	return "\n".join(lines)


func _colonist_lines() -> String:
	var lines: Array[String] = []
	for index in board.colonists.colonists.size():
		var colonist: Colonist = board.colonists.colonists[index]
		lines.append("%s: %s" % [colonist.display_name, _activity(index, colonist)])
	return "\n".join(lines)


func _activity(index: int, colonist: Colonist) -> String:
	if colonist.state == Colonist.State.RESTING:
		return "Resting"
	var task: WorkTask = board.task_of(index)
	if task == null:
		return "Idle"
	if colonist.mover.is_moving() or colonist.mover.room_id != task.room_id:
		return "Going to %s (%s)" % [_room_name(task.room_id), _kind_name(task.kind)]
	return "Working in %s (%s) %d%%" % [
		_room_name(task.room_id), _kind_name(task.kind),
		100.0 * task.progress / board.task_work_seconds,
	]


func _kind_name(kind: StringName) -> String:
	return String(kind).capitalize()


func _room_name(room_id: StringName) -> String:
	return board.map.get_room(room_id)["name"]
