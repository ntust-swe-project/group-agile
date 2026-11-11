# Story 003 (production/epics/orbit-shift/story-003-tasks-and-priorities.md):
# task list, claiming, work, release and priorities. Driven with explicit
# deltas and injected data; no file I/O except the one data-integrity check.
extends GdUnitTestSuite

const COLONISTS_SCRIPT := preload("res://src/core/colonists.gd")
const BOARD_SCRIPT := preload("res://src/core/task_board.gd")

# Line graph a - b - c - dorm, d off b, e off d. Colonists start in a, a hop
# takes 2s, fatigue +10/s while working (max 100), -20/s while resting.
const DATA := {
	"dorm_id": "dorm",
	"start_room": "a",
	"rooms": [
		{"id": "a", "name": "A", "color": "#ffffff", "pos": [0, 0]},
		{"id": "b", "name": "B", "color": "#ffffff", "pos": [0, 0]},
		{"id": "c", "name": "C", "color": "#ffffff", "pos": [0, 0]},
		{"id": "d", "name": "D", "color": "#ffffff", "pos": [0, 0]},
		{"id": "e", "name": "E", "color": "#ffffff", "pos": [0, 0]},
		{"id": "dorm", "name": "Dorm", "color": "#ffffff", "pos": [0, 0]},
	],
	"connections": [["a", "b"], ["b", "c"], ["c", "dorm"], ["b", "d"], ["d", "e"]],
	"colonists": ["Ann", "Bob", "Cat"],
	"move_seconds": 2.0,
	"fatigue_max": 100.0,
	"fatigue_rise_per_sec": 10.0,
	"fatigue_fall_per_sec": 20.0,
	"rest_threshold": 40.0,
	"collapse_seconds": 5.0,
	"task_work_seconds": 4.0,
	"default_priority": ["breach", "malfunction"],
}

var _colonists: Node
var _board: Node
var _cleanups: Array[Callable] = []


func before_test() -> void:
	_colonists = auto_free(COLONISTS_SCRIPT.new())
	_colonists.auto_tick = false
	_colonists.setup(DATA)
	add_child(_colonists)
	_board = auto_free(BOARD_SCRIPT.new())
	_board.auto_tick = false
	_board.setup(DATA)
	_board.colonists = _colonists
	add_child(_board)


# One frame in the real order: colonists move first, then the board reacts.
func _step(delta: float) -> void:
	_colonists.tick(delta)
	_board.tick(delta)


# Idle but at max fatigue: takes no task. Leaves only the others free.
func _exhaust(index: int) -> void:
	_colonists.colonists[index].fatigue = 100.0


func _completions() -> Array:
	var seen := []
	var on_completed := func(task_id: int, crisis_id: int) -> void: seen.append([task_id, crisis_id])
	Events.task_completed.connect(on_completed)
	# The caller reads the array after stepping; disconnect when the test ends.
	var cleanup := func() -> void:
		if Events.task_completed.is_connected(on_completed):
			Events.task_completed.disconnect(on_completed)
	_cleanups.append(cleanup)
	return seen



func after_test() -> void:
	for cleanup in _cleanups:
		cleanup.call()
	_cleanups.clear()


# --- task list ---

func test_add_task_lists_unclaimed_tasks_with_kind_room_and_unique_ids() -> void:
	# Act
	var first: int = _board.add_task(CrisisKind.BREACH, &"b")
	var second: int = _board.add_task(CrisisKind.MALFUNCTION, &"c", 9)
	# Assert
	assert_int(_board.tasks.size()).is_equal(2)
	assert_int(first).is_not_equal(second)
	var task: WorkTask = _board.tasks[1]
	assert_str(task.kind).is_equal(CrisisKind.MALFUNCTION)
	assert_str(task.room_id).is_equal("c")
	assert_int(task.crisis_id).is_equal(9)
	assert_bool(task.is_claimed()).is_false()
	assert_int((_board.tasks[0] as WorkTask).crisis_id).is_equal(-1)


func test_add_task_with_unknown_kind_or_room_reports_error_and_adds_nothing() -> void:
	# Act / Assert
	await assert_error(func() -> void: _board.add_task(&"fire", &"b")) \
		.is_push_error("add_task: unknown kind fire")
	await assert_error(func() -> void: _board.add_task(CrisisKind.BREACH, &"nowhere")) \
		.is_push_error("add_task: unknown room nowhere")
	assert_array(_board.tasks).is_empty()


func test_crisis_started_creates_a_task_carrying_the_crisis_id() -> void:
	# Act
	Events.crisis_started.emit(7, CrisisKind.MALFUNCTION, &"d")
	# Assert
	assert_int(_board.tasks.size()).is_equal(1)
	var task: WorkTask = _board.tasks[0]
	assert_int(task.crisis_id).is_equal(7)
	assert_str(task.kind).is_equal(CrisisKind.MALFUNCTION)
	assert_str(task.room_id).is_equal("d")


# --- claiming ---

func test_free_colonists_claim_different_tasks() -> void:
	# Arrange: two tasks, three colonists
	_board.add_task(CrisisKind.BREACH, &"b")
	_board.add_task(CrisisKind.BREACH, &"c")
	# Act
	_step(0.5)
	# Assert: two colonists hold one task each, the third has none
	var holders := []
	for task: WorkTask in _board.tasks:
		holders.append(task.claimed_by)
	assert_array(holders).contains_exactly_in_any_order([0, 1])
	assert_object(_board.task_of(2)).is_null()
	assert_int(_colonists.colonists[2].state).is_equal(Colonist.State.IDLE)


func test_one_task_is_claimed_by_a_single_colonist() -> void:
	# Arrange
	_board.add_task(CrisisKind.BREACH, &"b")
	# Act: several frames, three free colonists
	_step(0.5)
	_step(0.5)
	# Assert
	assert_int((_board.tasks[0] as WorkTask).claimed_by).is_equal(0)
	assert_int(_colonists.colonists[0].state).is_equal(Colonist.State.WORKING)
	assert_int(_colonists.colonists[1].state).is_equal(Colonist.State.IDLE)
	assert_int(_colonists.colonists[2].state).is_equal(Colonist.State.IDLE)


func test_claiming_sends_the_colonist_to_the_task_room() -> void:
	# Arrange
	_board.add_task(CrisisKind.BREACH, &"c")
	# Act
	_step(0.5)
	# Assert
	var ann: Colonist = _colonists.colonists[0]
	assert_str(ann.work_room).is_equal("c")
	assert_bool(ann.mover.is_moving()).is_true()


func test_idle_colonist_at_max_fatigue_does_not_claim() -> void:
	# Arrange
	for index in 3:
		_exhaust(index)
	_board.add_task(CrisisKind.BREACH, &"b")
	# Act
	_step(0.5)
	# Assert
	assert_bool((_board.tasks[0] as WorkTask).is_claimed()).is_false()


func test_resting_colonist_does_not_claim() -> void:
	# Arrange: Ann is sent to rest, the others are exhausted
	var ann: Colonist = _colonists.colonists[0]
	ann.fatigue = 100.0
	ann.assign_work(&"a")
	_exhaust(1)
	_exhaust(2)
	_board.add_task(CrisisKind.BREACH, &"b")
	# Act
	_step(0.5)
	# Assert
	assert_int(ann.state).is_equal(Colonist.State.RESTING)
	assert_bool((_board.tasks[0] as WorkTask).is_claimed()).is_false()


# --- work and completion ---

func test_task_completes_after_work_seconds_in_the_room_and_emits_task_completed() -> void:
	# Arrange: crisis 7 at b; only Ann is free
	_exhaust(1)
	_exhaust(2)
	var seen := _completions()
	Events.crisis_started.emit(7, CrisisKind.BREACH, &"b")
	var task_id: int = (_board.tasks[0] as WorkTask).id
	# Act / Assert
	_step(0.5)  # claimed, walking
	_step(2.0)  # arrives in b
	_step(3.0)  # 3 of 4 work seconds
	assert_int(_board.tasks.size()).is_equal(1)
	assert_array(seen).is_empty()
	_step(1.0)  # 4 of 4
	assert_array(_board.tasks).is_empty()
	assert_array(seen).is_equal([[task_id, 7]])
	var ann: Colonist = _colonists.colonists[0]
	assert_int(ann.state).is_equal(Colonist.State.IDLE)
	assert_str(ann.work_room).is_empty()


func test_hand_made_task_completes_with_crisis_id_minus_one() -> void:
	# Arrange: Ann starts in a, the task is in a
	_exhaust(1)
	_exhaust(2)
	var seen := _completions()
	var task_id: int = _board.add_task(CrisisKind.MALFUNCTION, &"a")
	# Act
	_step(0.5)  # claimed, already in the room
	_step(0.5)  # first seen in place, not counted yet
	_step(4.0)
	# Assert
	assert_array(seen).is_equal([[task_id, -1]])


func test_no_work_is_counted_while_the_colonist_is_still_moving() -> void:
	# Arrange
	_exhaust(1)
	_exhaust(2)
	_board.add_task(CrisisKind.BREACH, &"c")
	# Act: 2 hops = 4s of walking, far more than task_work_seconds of frames
	_step(0.5)
	_step(1.5)
	_step(1.5)
	# Assert
	assert_float((_board.tasks[0] as WorkTask).progress).is_equal(0.0)


func test_finished_colonist_takes_the_next_task_in_the_same_frame() -> void:
	# Arrange: Ann works a task in a, a second one waits in b
	_exhaust(1)
	_exhaust(2)
	_board.add_task(CrisisKind.BREACH, &"a")
	_step(0.5)
	_step(0.5)
	_board.add_task(CrisisKind.BREACH, &"b")
	# Act
	_step(4.0)
	# Assert
	assert_int(_board.tasks.size()).is_equal(1)
	assert_int((_board.tasks[0] as WorkTask).claimed_by).is_equal(0)
	assert_str(_colonists.colonists[0].work_room).is_equal("b")


# --- fatigue release ---

func test_exhausted_colonist_releases_the_task_and_another_can_claim_it() -> void:
	# Arrange: Ann stands in b at fatigue 95 and works a task there; the others are exhausted
	var ann: Colonist = _colonists.colonists[0]
	ann.mover.room_id = &"b"
	ann.fatigue = 95.0
	_exhaust(1)
	_exhaust(2)
	_board.add_task(CrisisKind.BREACH, &"b")
	_step(0.5)
	assert_int((_board.tasks[0] as WorkTask).claimed_by).is_equal(0)
	# Act: 1s of work takes Ann to max fatigue, so she walks off to the dorm
	_step(1.0)
	# Assert: released, progress reset, nobody free to take it yet
	var task: WorkTask = _board.tasks[0]
	assert_int(ann.state).is_equal(Colonist.State.RESTING)
	assert_bool(task.is_claimed()).is_false()
	assert_float(task.progress).is_equal(0.0)
	assert_str(ann.work_room).is_empty()
	# Act: Bob has rested, the next frame he takes it
	_colonists.colonists[1].fatigue = 0.0
	_step(0.5)
	# Assert
	assert_int(task.claimed_by).is_equal(1)


func test_colonist_that_rested_returns_to_idle_not_to_the_released_task_room() -> void:
	# Arrange: as above, then let Ann walk to the dorm (2 hops) and rest 100 -> 30
	var ann: Colonist = _colonists.colonists[0]
	ann.mover.room_id = &"b"
	ann.fatigue = 95.0
	_exhaust(1)
	_exhaust(2)
	_board.add_task(CrisisKind.BREACH, &"b")
	_step(0.5)
	_step(1.0)
	# Act
	_step(2.0)
	_step(2.0)
	_step(3.5)
	# Assert: she is idle in the dorm, and takes the task again only via the board
	assert_str(ann.mover.room_id).is_equal("dorm")
	assert_int(ann.state).is_equal(Colonist.State.WORKING)
	assert_int((_board.tasks[0] as WorkTask).claimed_by).is_equal(0)


# --- priorities ---

func test_default_priority_comes_from_the_data() -> void:
	# Assert
	assert_array(_board.priority_order).is_equal([CrisisKind.BREACH, CrisisKind.MALFUNCTION])


func test_changing_priority_applies_to_the_next_pick() -> void:
	# Arrange: only Ann is free; the malfunction is nearer, the breach farther
	_exhaust(1)
	_exhaust(2)
	var malfunction: int = _board.add_task(CrisisKind.MALFUNCTION, &"b")
	_board.add_task(CrisisKind.BREACH, &"e")
	# Act
	_board.move_kind_up(CrisisKind.MALFUNCTION)
	_step(0.5)
	# Assert
	assert_array(_board.priority_order).is_equal([CrisisKind.MALFUNCTION, CrisisKind.BREACH])
	assert_int((_board.task_of(0) as WorkTask).id).is_equal(malfunction)


func test_move_kind_down_swaps_and_edges_do_nothing() -> void:
	# Act / Assert
	_board.move_kind_up(CrisisKind.BREACH)
	_board.move_kind_down(CrisisKind.MALFUNCTION)
	assert_array(_board.priority_order).is_equal([CrisisKind.BREACH, CrisisKind.MALFUNCTION])
	_board.move_kind_down(CrisisKind.BREACH)
	assert_array(_board.priority_order).is_equal([CrisisKind.MALFUNCTION, CrisisKind.BREACH])


func test_changing_priority_does_not_take_a_claimed_task_away() -> void:
	# Arrange: Ann holds the breach
	_exhaust(1)
	_exhaust(2)
	var breach: int = _board.add_task(CrisisKind.BREACH, &"e")
	_board.add_task(CrisisKind.MALFUNCTION, &"b")
	_step(0.5)
	# Act
	_board.move_kind_up(CrisisKind.MALFUNCTION)
	_step(0.5)
	# Assert
	assert_int((_board.task_of(0) as WorkTask).id).is_equal(breach)


# --- indirect control ---

func test_board_has_no_public_method_that_names_a_colonist() -> void:
	# Arrange / Act: every public method of the board and its panel
	var offenders := []
	for script: Script in [BOARD_SCRIPT, load("res://src/ui/priority_panel.gd")]:
		for method: Dictionary in script.get_script_method_list():
			if (method["name"] as String).begins_with("_"):
				continue
			for arg: Dictionary in method["args"]:
				if (arg["name"] as String).contains("colonist"):
					offenders.append(method["name"])
	# Assert: only the read-only lookup task_of(colonist_index) is allowed
	assert_array(offenders).is_equal(["task_of"])


# --- game end ---

func test_after_game_ended_the_board_stops_claiming_working_and_adding() -> void:
	# Arrange
	_board.add_task(CrisisKind.BREACH, &"a")
	Events.game_ended.emit(false, &"test")
	# Act
	Events.crisis_started.emit(1, CrisisKind.BREACH, &"b")
	_step(5.0)
	# Assert
	assert_int(_board.tasks.size()).is_equal(1)
	assert_bool((_board.tasks[0] as WorkTask).is_claimed()).is_false()


# Deliberate exception to the no-file-I/O rule: the real data file must carry
# the board's tunables (it is what the game reads).
func test_real_station_data_file_has_work_seconds_and_a_full_default_priority() -> void:
	# Arrange / Act
	var data := StationMap.load_data()
	# Assert
	assert_float(data["task_work_seconds"] as float).is_greater(0.0)
	var order: Array = data["default_priority"]
	assert_int(order.size()).is_equal(CrisisKind.ALL.size())
	for kind: StringName in CrisisKind.ALL:
		assert_bool(order.has(String(kind))).is_true()
