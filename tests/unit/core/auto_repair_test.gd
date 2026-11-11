# Story 005 (production/epics/orbit-shift/story-005-automation.md).
# BuildPoints, AutoRepairModule and the AutoRepair node, driven only by Events
# signals and explicit tick(delta). Config and room graph are injected: no file I/O.
extends GdUnitTestSuite

const AUTO_REPAIR_SCRIPT := preload("res://src/core/auto_repair.gd")
const COST := 2
const REPAIR_SECONDS := 10.0
const POINTS_PER_DAY := 1
const CRISIS_ID := 7
const OTHER_CRISIS_ID := 8
const COLONIST_TASK_ID := 3

var _completed: Array = []


func before_test() -> void:
	_completed = []
	Events.task_completed.connect(_record_completed)


func after_test() -> void:
	if Events.task_completed.is_connected(_record_completed):
		Events.task_completed.disconnect(_record_completed)


func _record_completed(task_id: int, crisis_id: int) -> void:
	_completed.append([task_id, crisis_id])


# --- fixtures ---

func _config() -> Dictionary:
	return {"points_per_day": POINTS_PER_DAY, "module_cost": COST, "repair_seconds": REPAIR_SECONDS}


func _map() -> StationMap:
	var map := StationMap.new()
	map.setup({
		"dorm_id": "dorm",
		"rooms": [
			{"id": "dorm", "name": "Dorm", "color": "#9a9a9a", "pos": [100, 100]},
			{"id": "lab", "name": "Lab", "color": "#9a9a9a", "pos": [400, 100]},
		],
		"connections": [["dorm", "lab"]],
	})
	return map


func _node() -> Node:
	var node: Node = auto_free(AUTO_REPAIR_SCRIPT.new())
	node.auto_tick = false
	node.setup(_config(), _map())
	add_child(node)
	return node


# Gives the node [param days] days of points through the real signal.
func _earn_days(days: int) -> void:
	for day in range(1, days + 1):
		Events.day_ended.emit(day)


# A node with a module in the lab.
func _node_with_lab_module() -> Node:
	var node := _node()
	_earn_days(COST)
	node.build(&"lab")
	return node


# --- BuildPoints ---

func test_build_points_add_increases_balance() -> void:
	var points := BuildPoints.new()

	points.add(3)

	assert_int(points.points).is_equal(3)


func test_build_points_spend_without_enough_returns_false_and_keeps_balance() -> void:
	var points := BuildPoints.new()
	points.add(1)

	var spent := points.spend(2)

	assert_bool(spent).is_false()
	assert_int(points.points).is_equal(1)


func test_build_points_spend_with_enough_deducts_cost() -> void:
	var points := BuildPoints.new()
	points.add(5)

	var spent := points.spend(2)

	assert_bool(spent).is_true()
	assert_int(points.points).is_equal(3)


# --- AutoRepairModule ---

func test_module_reports_crisis_only_after_repair_seconds() -> void:
	var module := AutoRepairModule.new(&"lab", 5.0)
	module.watch(CRISIS_ID)

	var early := module.tick(4.9)
	var due := module.tick(0.2)

	assert_array(early).is_empty()
	assert_array(due).contains_exactly([CRISIS_ID])
	assert_bool(module.is_watching(CRISIS_ID)).is_false()


func test_module_forget_prevents_repair() -> void:
	var module := AutoRepairModule.new(&"lab", 5.0)
	module.watch(CRISIS_ID)

	module.forget(CRISIS_ID)

	assert_array(module.tick(10.0)).is_empty()


func test_module_counts_each_crisis_from_its_own_start() -> void:
	var module := AutoRepairModule.new(&"lab", 5.0)
	module.watch(CRISIS_ID)
	module.tick(3.0)
	module.watch(OTHER_CRISIS_ID)

	var first := module.tick(2.0)
	var second := module.tick(3.0)

	assert_array(first).contains_exactly([CRISIS_ID])
	assert_array(second).contains_exactly([OTHER_CRISIS_ID])


# --- AutoRepair: build points ---

func test_day_ended_adds_points_per_day() -> void:
	var node := _node()

	Events.day_ended.emit(1)
	Events.day_ended.emit(2)

	assert_int(node.build_points.points).is_equal(2 * POINTS_PER_DAY)


func test_build_with_insufficient_points_fails_and_keeps_points() -> void:
	var node := _node()
	_earn_days(COST - 1)

	var built: bool = node.build(&"lab")

	assert_bool(built).is_false()
	assert_bool(node.modules.has(&"lab")).is_false()
	assert_int(node.build_points.points).is_equal(COST - 1)


func test_build_with_enough_points_creates_module_and_spends_cost() -> void:
	var node := _node()
	_earn_days(COST + 1)

	var built: bool = node.build(&"lab")

	assert_bool(built).is_true()
	assert_bool(node.modules.has(&"lab")).is_true()
	assert_int(node.build_points.points).is_equal(1)


func test_second_module_in_same_room_is_refused_without_spending() -> void:
	var node := _node()
	_earn_days(COST * 2)
	node.build(&"lab")

	var built_again: bool = node.build(&"lab")

	assert_bool(built_again).is_false()
	assert_int(node.build_points.points).is_equal(COST)


func test_build_in_another_room_is_allowed() -> void:
	var node := _node()
	_earn_days(COST * 2)
	node.build(&"lab")

	var built: bool = node.build(&"dorm")

	assert_bool(built).is_true()
	assert_int(node.modules.size()).is_equal(2)


func test_build_in_unknown_room_is_refused() -> void:
	var node := _node()
	_earn_days(COST)

	var built: bool = node.build(&"nowhere")

	assert_bool(built).is_false()
	assert_int(node.build_points.points).is_equal(COST)


# --- AutoRepair: repairs ---

func test_module_completes_malfunction_after_repair_seconds_with_right_ids() -> void:
	var node := _node_with_lab_module()
	Events.crisis_started.emit(CRISIS_ID, CrisisKind.MALFUNCTION, &"lab")

	node.tick(REPAIR_SECONDS - 0.1)
	var before_delay := _completed.size()
	node.tick(0.2)

	assert_int(before_delay).is_equal(0)
	assert_array(_completed).contains_exactly([[AUTO_REPAIR_SCRIPT.MODULE_TASK_ID, CRISIS_ID]])


func test_module_completes_each_malfunction_only_once() -> void:
	var node := _node_with_lab_module()
	Events.crisis_started.emit(CRISIS_ID, CrisisKind.MALFUNCTION, &"lab")

	node.tick(REPAIR_SECONDS + 0.1)
	node.tick(REPAIR_SECONDS)

	assert_int(_completed.size()).is_equal(1)


func test_colonist_finishing_first_prevents_double_completion() -> void:
	var node := _node_with_lab_module()
	Events.crisis_started.emit(CRISIS_ID, CrisisKind.MALFUNCTION, &"lab")
	node.tick(REPAIR_SECONDS / 2.0)

	Events.task_completed.emit(COLONIST_TASK_ID, CRISIS_ID)
	node.tick(REPAIR_SECONDS)

	assert_array(_completed).contains_exactly([[COLONIST_TASK_ID, CRISIS_ID]])


func test_colonist_finishing_one_crisis_does_not_cancel_another() -> void:
	var node := _node_with_lab_module()
	Events.crisis_started.emit(CRISIS_ID, CrisisKind.MALFUNCTION, &"lab")
	Events.crisis_started.emit(OTHER_CRISIS_ID, CrisisKind.MALFUNCTION, &"lab")

	Events.task_completed.emit(COLONIST_TASK_ID, CRISIS_ID)
	node.tick(REPAIR_SECONDS + 0.1)

	assert_array(_completed).contains_exactly([
		[COLONIST_TASK_ID, CRISIS_ID],
		[AUTO_REPAIR_SCRIPT.MODULE_TASK_ID, OTHER_CRISIS_ID],
	])


func test_breach_in_module_room_is_ignored() -> void:
	var node := _node_with_lab_module()
	Events.crisis_started.emit(CRISIS_ID, CrisisKind.BREACH, &"lab")

	node.tick(REPAIR_SECONDS * 10.0)

	assert_array(_completed).is_empty()


func test_malfunction_in_room_without_module_is_ignored() -> void:
	var node := _node_with_lab_module()
	Events.crisis_started.emit(CRISIS_ID, CrisisKind.MALFUNCTION, &"dorm")

	node.tick(REPAIR_SECONDS * 10.0)

	assert_array(_completed).is_empty()


func test_nothing_happens_after_game_ended() -> void:
	var node := _node_with_lab_module()
	Events.crisis_started.emit(CRISIS_ID, CrisisKind.MALFUNCTION, &"lab")

	Events.game_ended.emit(false, &"test")
	node.tick(REPAIR_SECONDS * 2.0)
	Events.day_ended.emit(99)

	assert_array(_completed).is_empty()
	assert_int(node.build_points.points).is_equal(0)


# --- config validation ---

func test_validate_accepts_a_complete_config() -> void:
	assert_str(AUTO_REPAIR_SCRIPT.validate(_config())).is_empty()


func test_validate_rejects_missing_key() -> void:
	var config := _config()
	config.erase("repair_seconds")

	assert_str(AUTO_REPAIR_SCRIPT.validate(config)).contains("repair_seconds")


func test_validate_rejects_non_positive_value() -> void:
	var config := _config()
	config["module_cost"] = 0

	assert_str(AUTO_REPAIR_SCRIPT.validate(config)).contains("module_cost")
