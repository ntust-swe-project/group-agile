# Story 003 (production/epics/orbit-shift/story-003-tasks-and-priorities.md):
# which task a free colonist takes. Pure logic, no scene, no file I/O.
extends GdUnitTestSuite

# Line graph a - b - c - dorm, d off b, e off d; "island" has no connection.
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
		{"id": "island", "name": "Island", "color": "#ffffff", "pos": [0, 0]},
	],
	"connections": [["a", "b"], ["b", "c"], ["c", "dorm"], ["b", "d"], ["d", "e"]],
}

const BREACH_FIRST: Array[StringName] = [CrisisKind.BREACH, CrisisKind.MALFUNCTION]
const MALFUNCTION_FIRST: Array[StringName] = [CrisisKind.MALFUNCTION, CrisisKind.BREACH]


func _map() -> StationMap:
	var map := StationMap.new()
	map.setup(DATA)
	return map


func _pick(tasks: Array, order: Array[StringName], from: StringName = &"a") -> WorkTask:
	return TaskPicker.pick(tasks, order, from, _map())


func test_pick_with_no_tasks_returns_null() -> void:
	# Arrange / Act / Assert
	assert_object(_pick([], BREACH_FIRST)).is_null()


func test_pick_higher_priority_kind_wins_over_a_closer_task() -> void:
	# Arrange: the malfunction is next door, the breach is 3 hops away
	var near := WorkTask.new(1, CrisisKind.MALFUNCTION, &"b")
	var far := WorkTask.new(2, CrisisKind.BREACH, &"dorm")
	# Act / Assert
	assert_object(_pick([near, far], BREACH_FIRST)).is_same(far)
	assert_object(_pick([near, far], MALFUNCTION_FIRST)).is_same(near)


func test_pick_same_priority_takes_the_nearest_room() -> void:
	# Arrange: from a, c is 2 hops, d is 2 hops, b is 1 hop
	var c := WorkTask.new(1, CrisisKind.BREACH, &"c")
	var b := WorkTask.new(2, CrisisKind.BREACH, &"b")
	var e := WorkTask.new(3, CrisisKind.BREACH, &"e")
	# Act / Assert
	assert_object(_pick([c, e, b], BREACH_FIRST)).is_same(b)
	assert_object(_pick([c, e], BREACH_FIRST, &"e")).is_same(e)


func test_pick_task_in_own_room_counts_as_nearest() -> void:
	# Arrange
	var here := WorkTask.new(5, CrisisKind.BREACH, &"a")
	var next_door := WorkTask.new(1, CrisisKind.BREACH, &"b")
	# Act / Assert
	assert_object(_pick([next_door, here], BREACH_FIRST)).is_same(here)


func test_pick_same_priority_and_distance_takes_the_smaller_id_in_any_list_order() -> void:
	# Arrange: c and d are both 2 hops from a
	var c := WorkTask.new(7, CrisisKind.BREACH, &"c")
	var d := WorkTask.new(3, CrisisKind.BREACH, &"d")
	# Act / Assert
	assert_object(_pick([c, d], BREACH_FIRST)).is_same(d)
	assert_object(_pick([d, c], BREACH_FIRST)).is_same(d)


func test_pick_skips_claimed_tasks() -> void:
	# Arrange: the best task is already held
	var held := WorkTask.new(1, CrisisKind.BREACH, &"b")
	held.claimed_by = 0
	var free := WorkTask.new(2, CrisisKind.MALFUNCTION, &"e")
	# Act / Assert
	assert_object(_pick([held, free], BREACH_FIRST)).is_same(free)
	assert_object(_pick([held], BREACH_FIRST)).is_null()


func test_pick_kind_missing_from_priority_order_ranks_last() -> void:
	# Arrange
	var listed := WorkTask.new(2, CrisisKind.MALFUNCTION, &"e")
	var unlisted := WorkTask.new(1, CrisisKind.BREACH, &"b")
	var only_malfunction: Array[StringName] = [CrisisKind.MALFUNCTION]
	# Act / Assert
	assert_object(_pick([unlisted, listed], only_malfunction)).is_same(listed)


func test_pick_skips_task_in_unreachable_room() -> void:
	# Arrange
	var cut_off := WorkTask.new(1, CrisisKind.BREACH, &"island")
	var reachable := WorkTask.new(2, CrisisKind.MALFUNCTION, &"b")
	# Act / Assert
	assert_object(_pick([cut_off, reachable], BREACH_FIRST)).is_same(reachable)
	assert_object(_pick([cut_off], BREACH_FIRST)).is_null()
