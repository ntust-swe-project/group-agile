# Story 004 (production/epics/orbit-shift/story-004-escalating-crises.md).
# CrisisDirector is driven only by Events signals and explicit tick(delta):
# no wall clock, explicit seed, a fake StationIntegrity that records damage.
extends GdUnitTestSuite

const DIRECTOR_SCRIPT := preload("res://src/core/crisis_director.gd")
const SEED := 4242
const DAY_LENGTH := 60.0
const BREACH_RATE := 2.0
const MALFUNCTION_RATE := 0.5
const MIN_DELAY := 4.0
const LATE_DAY := 20
const EPSILON := 0.0001
const MISSING_CURVE_PATH := "res://tests/fixtures/crisis/does_not_exist.tres"

var _started: Array = []
var _resolved: Array = []


func before_test() -> void:
	_started = []
	_resolved = []
	Events.crisis_started.connect(_record_started)
	Events.crisis_resolved.connect(_record_resolved)


func after_test() -> void:
	if Events.crisis_started.is_connected(_record_started):
		Events.crisis_started.disconnect(_record_started)
	if Events.crisis_resolved.is_connected(_record_resolved):
		Events.crisis_resolved.disconnect(_record_resolved)


func _record_started(crisis_id: int, kind: StringName, room_id: StringName) -> void:
	_started.append([crisis_id, kind, room_id])


func _record_resolved(crisis_id: int) -> void:
	_resolved.append(crisis_id)


# --- fixtures ---

# Day 1 has exactly one crisis; by the late day the cap of 6 is reached.
func _curve(breach_weight: float = 1.0, malfunction_weight: float = 1.0) -> CrisisCurve:
	var curve := CrisisCurve.new()
	curve.base_crises = 1.0
	curve.growth_per_day = 0.5
	curve.min_crises_per_day = 1
	curve.max_crises_per_day = 6
	curve.breach_weight = breach_weight
	curve.malfunction_weight = malfunction_weight
	curve.breach_damage_per_second = BREACH_RATE
	curve.malfunction_damage_per_second = MALFUNCTION_RATE
	curve.min_start_delay_seconds = MIN_DELAY
	curve.latest_start_day_fraction = 0.75
	return curve


func _breach_only_curve() -> CrisisCurve:
	return _curve(1.0, 0.0)


func _malfunction_only_curve() -> CrisisCurve:
	return _curve(0.0, 1.0)


func _rooms() -> Array[StringName]:
	return [&"dorm", &"bridge", &"engine", &"lab"]


func _make_script(source: String) -> GDScript:
	var script := GDScript.new()
	script.source_code = source
	script.reload()
	return script


# A stand-in for StationIntegrity that records every apply_damage call.
func _fake_integrity() -> Node:
	var fake: Node = auto_free(Node.new())
	fake.set_script(_make_script(
		"extends Node\nvar calls: Array = []\nfunc apply_damage(amount: float) -> void:\n\tcalls.append(amount)\n"
	))
	return fake


# Like _fake_integrity, but every call ends the game, as StationIntegrity does
# when it reaches 0 (story 001: DayCycle emits game_ended synchronously).
func _fake_integrity_that_ends_the_game() -> Node:
	var fake: Node = auto_free(Node.new())
	fake.set_script(_make_script(
		"extends Node\nvar calls: Array = []\nfunc apply_damage(amount: float) -> void:\n\tcalls.append(amount)\n\tEvents.game_ended.emit(false, &\"integrity\")\n"
	))
	return fake


func _fake_day_cycle(day_length: float) -> Node:
	var fake: Node = auto_free(Node.new())
	fake.set_script(_make_script("extends Node\nvar day_length: float = %f\n" % day_length))
	return fake


func _director(curve: CrisisCurve, integrity: Node = null) -> Node:
	var director: Node = auto_free(DIRECTOR_SCRIPT.new())
	director.auto_tick = false
	director.run_seed = SEED
	director.day_length = DAY_LENGTH
	director.setup(curve, _rooms())
	director.station_integrity = integrity
	add_child(director)
	return director


func _scheduled(day: int, curve: CrisisCurve) -> Array[Crisis]:
	return CrisisScheduler.schedule(day, SEED, _rooms(), curve, DAY_LENGTH)


func _total(fake: Node) -> float:
	var total := 0.0
	for amount: float in fake.calls:
		total += amount
	return total


# Starts day 1 and ticks to the moment its only crisis fires. Returns that crisis.
func _start_day_one_and_fire(director: Node, curve: CrisisCurve) -> Crisis:
	var crisis := _scheduled(1, curve)[0]
	Events.day_started.emit(1)
	director.tick(crisis.start_seconds)
	return crisis


# --- AC: two kinds, each in a room; signals carry the right arguments ---

func test_crisis_started_is_emitted_with_id_kind_and_room_of_the_scheduled_crisis() -> void:
	# Arrange
	var curve := _curve()
	var director := _director(curve)
	var expected := _scheduled(1, curve)[0]
	Events.day_started.emit(1)
	# Act
	director.tick(expected.start_seconds)
	# Assert
	assert_array(_started).is_equal([[expected.id, expected.kind, expected.room_id]])
	assert_bool(director.active_crises.has(expected.id)).is_true()


func test_breach_crisis_is_emitted_as_breach_in_a_known_room() -> void:
	# Arrange
	var director := _director(_breach_only_curve())
	# Act
	_start_day_one_and_fire(director, _breach_only_curve())
	# Assert
	assert_str(_started[0][1]).is_equal(CrisisKind.BREACH)
	assert_bool(_rooms().has(_started[0][2])).is_true()


func test_malfunction_crisis_is_emitted_as_malfunction_in_a_known_room() -> void:
	# Arrange
	var director := _director(_malfunction_only_curve())
	# Act
	_start_day_one_and_fire(director, _malfunction_only_curve())
	# Assert
	assert_str(_started[0][1]).is_equal(CrisisKind.MALFUNCTION)
	assert_bool(_rooms().has(_started[0][2])).is_true()


func test_both_kinds_are_emitted_over_a_run() -> void:
	# Arrange
	var director := _director(_curve())
	# Act — a day per tick of DAY_LENGTH, resolving nothing
	for day in range(1, 31):
		Events.day_started.emit(day)
		director.tick(DAY_LENGTH)
	# Assert
	var kinds := {}
	for row: Array in _started:
		kinds[row[1]] = true
	assert_bool(kinds.has(CrisisKind.BREACH)).is_true()
	assert_bool(kinds.has(CrisisKind.MALFUNCTION)).is_true()


# --- AC: damage every second until the task completes ---

func test_breach_damages_station_every_second_at_the_curve_rate() -> void:
	# Arrange
	var integrity := _fake_integrity()
	var curve := _breach_only_curve()
	var director := _director(curve, integrity)
	_start_day_one_and_fire(director, curve)
	# Act
	director.tick(1.0)
	director.tick(1.0)
	director.tick(1.0)
	# Assert
	assert_float(_total(integrity)).is_equal_approx(3.0 * BREACH_RATE, EPSILON)


func test_damage_goes_through_apply_damage_in_per_tick_amounts() -> void:
	# Arrange
	var integrity := _fake_integrity()
	var curve := _breach_only_curve()
	var director := _director(curve, integrity)
	_start_day_one_and_fire(director, curve)
	# Act
	director.tick(0.5)
	# Assert
	assert_int(integrity.calls.size()).is_equal(1)
	assert_float(integrity.calls[0]).is_equal_approx(0.5 * BREACH_RATE, EPSILON)


func test_damage_is_frame_rate_independent() -> void:
	# Arrange — two directors with the same seed see the same day_started
	var curve := _breach_only_curve()
	var coarse_integrity := _fake_integrity()
	var coarse := _director(curve, coarse_integrity)
	var fine_integrity := _fake_integrity()
	var fine := _director(curve, fine_integrity)
	var crisis := _scheduled(1, curve)[0]
	Events.day_started.emit(1)
	coarse.tick(crisis.start_seconds)
	fine.tick(crisis.start_seconds)
	# Act — the same 2 seconds, in one step and in twenty
	coarse.tick(2.0)
	for step in 20:
		fine.tick(0.1)
	# Assert
	assert_float(_total(coarse_integrity)).is_equal_approx(2.0 * BREACH_RATE, EPSILON)
	assert_float(_total(fine_integrity)).is_equal_approx(_total(coarse_integrity), EPSILON)


func test_crisis_that_fires_mid_tick_is_only_charged_for_the_time_after_it_fired() -> void:
	# Arrange
	var integrity := _fake_integrity()
	var curve := _breach_only_curve()
	var director := _director(curve, integrity)
	var crisis := _scheduled(1, curve)[0]
	Events.day_started.emit(1)
	# Act — one big tick that ends 1.5 s after the crisis fired
	director.tick(crisis.start_seconds + 1.5)
	# Assert
	assert_float(_total(integrity)).is_equal_approx(1.5 * BREACH_RATE, EPSILON)


func test_malfunction_damages_at_its_own_smaller_data_driven_rate() -> void:
	# Arrange
	var integrity := _fake_integrity()
	var curve := _malfunction_only_curve()
	var director := _director(curve, integrity)
	_start_day_one_and_fire(director, curve)
	# Act
	director.tick(2.0)
	# Assert
	assert_float(_total(integrity)).is_equal_approx(2.0 * MALFUNCTION_RATE, EPSILON)
	assert_float(MALFUNCTION_RATE).is_less(BREACH_RATE)


func test_changing_the_curve_rate_changes_the_damage() -> void:
	# Arrange
	var integrity := _fake_integrity()
	var curve := _malfunction_only_curve()
	curve.malfunction_damage_per_second = 4.0
	var director := _director(curve, integrity)
	_start_day_one_and_fire(director, curve)
	# Act
	director.tick(1.0)
	# Assert
	assert_float(_total(integrity)).is_equal_approx(4.0, EPSILON)


# --- AC: task_completed resolves ---

func test_task_completed_for_the_crisis_stops_damage_and_emits_resolved() -> void:
	# Arrange
	var integrity := _fake_integrity()
	var curve := _breach_only_curve()
	var director := _director(curve, integrity)
	var crisis := _start_day_one_and_fire(director, curve)
	director.tick(1.0)
	var damage_before := _total(integrity)
	# Act
	Events.task_completed.emit(1, crisis.id)
	director.tick(5.0)
	# Assert
	assert_array(_resolved).is_equal([crisis.id])
	assert_bool(director.active_crises.has(crisis.id)).is_false()
	assert_float(_total(integrity)).is_equal(damage_before)


func test_task_completed_for_another_crisis_id_is_ignored() -> void:
	# Arrange
	var integrity := _fake_integrity()
	var curve := _breach_only_curve()
	var director := _director(curve, integrity)
	var crisis := _start_day_one_and_fire(director, curve)
	# Act
	Events.task_completed.emit(1, crisis.id + 999)
	director.tick(1.0)
	# Assert
	assert_array(_resolved).is_empty()
	assert_bool(director.active_crises.has(crisis.id)).is_true()
	assert_float(_total(integrity)).is_equal_approx(BREACH_RATE, EPSILON)


func test_task_completed_before_the_crisis_fired_does_not_cancel_it() -> void:
	# Arrange
	var curve := _breach_only_curve()
	var director := _director(curve)
	var crisis := _scheduled(1, curve)[0]
	Events.day_started.emit(1)
	# Act
	Events.task_completed.emit(1, crisis.id)
	director.tick(crisis.start_seconds)
	# Assert
	assert_array(_resolved).is_empty()
	assert_array(_started).is_equal([[crisis.id, crisis.kind, crisis.room_id]])


func test_completing_the_same_crisis_twice_resolves_it_once() -> void:
	# Arrange
	var curve := _breach_only_curve()
	var director := _director(curve)
	var crisis := _start_day_one_and_fire(director, curve)
	# Act
	Events.task_completed.emit(1, crisis.id)
	Events.task_completed.emit(2, crisis.id)
	# Assert
	assert_array(_resolved).is_equal([crisis.id])


# --- ordering rule: nothing at day_started ---

func test_day_started_alone_fires_and_damages_nothing() -> void:
	# Arrange
	var integrity := _fake_integrity()
	var director := _director(_curve(), integrity)
	# Act — emit and let the same frame pass without any time
	Events.day_started.emit(1)
	director.tick(0.0)
	# Assert
	assert_array(_started).is_empty()
	assert_array(integrity.calls).is_empty()
	assert_bool(director.active_crises.is_empty()).is_true()


func test_nothing_fires_before_the_minimum_start_delay() -> void:
	# Arrange — a collapsed window puts every crisis exactly at the delay
	var curve := _curve()
	curve.latest_start_day_fraction = 0.0
	var integrity := _fake_integrity()
	var director := _director(curve, integrity)
	Events.day_started.emit(LATE_DAY)
	# Act
	director.tick(MIN_DELAY - 0.01)
	var started_before_delay := _started.size()
	director.tick(0.01)
	# Assert
	assert_int(started_before_delay).is_equal(0)
	assert_array(integrity.calls).is_empty()
	assert_int(_started.size()).is_equal(_scheduled(LATE_DAY, curve).size())


# --- AC: escalation and daily minimum, reproducibility ---

func test_late_day_fires_more_crises_than_day_one() -> void:
	# Arrange
	var curve := _curve()
	var director := _director(curve)
	Events.day_started.emit(1)
	director.tick(DAY_LENGTH)
	var day_one_count := _started.size()
	_started.clear()
	# Act
	Events.day_started.emit(LATE_DAY)
	director.tick(DAY_LENGTH)
	# Assert
	assert_int(day_one_count).is_equal(1)
	assert_int(_started.size()).is_equal(curve.crises_for_day(LATE_DAY))
	assert_int(_started.size()).is_greater(day_one_count)


func test_every_day_fires_at_least_one_crisis() -> void:
	# Arrange
	var curve := _curve()
	curve.growth_per_day = 0.0
	curve.base_crises = 0.0
	var director := _director(curve)
	for day in range(1, 31):
		_started.clear()
		# Act
		Events.day_started.emit(day)
		director.tick(DAY_LENGTH)
		# Assert
		assert_int(_started.size()).is_greater_equal(1)


func test_fired_crises_match_the_scheduler_for_the_same_seed() -> void:
	# Arrange
	var curve := _curve()
	var director := _director(curve)
	var expected := []
	for crisis in _scheduled(LATE_DAY, curve):
		expected.append([crisis.id, crisis.kind, crisis.room_id])
	# Act
	Events.day_started.emit(LATE_DAY)
	director.tick(DAY_LENGTH)
	# Assert
	assert_array(_started).is_equal(expected)


func test_explicit_seed_of_zero_is_kept() -> void:
	# Arrange
	var director: Node = auto_free(DIRECTOR_SCRIPT.new())
	director.auto_tick = false
	director.run_seed = 0
	director.setup(_curve(), _rooms())
	# Act
	add_child(director)
	# Assert
	assert_int(director.run_seed).is_equal(0)


func test_same_day_started_twice_schedules_the_day_once() -> void:
	# Arrange
	var curve := _curve()
	var director := _director(curve)
	# Act
	Events.day_started.emit(LATE_DAY)
	Events.day_started.emit(LATE_DAY)
	director.tick(DAY_LENGTH)
	# Assert
	assert_int(_started.size()).is_equal(curve.crises_for_day(LATE_DAY))


# --- persistence across days, game end ---

func test_unresolved_crisis_keeps_damaging_after_the_next_day_starts() -> void:
	# Arrange
	var integrity := _fake_integrity()
	var curve := _breach_only_curve()
	var director := _director(curve, integrity)
	var crisis := _start_day_one_and_fire(director, curve)
	director.tick(1.0)
	# Act — day 2 starts; before day 2's first crisis can fire (min delay), time passes
	Events.day_started.emit(2)
	var damage_before := _total(integrity)
	director.tick(MIN_DELAY - 0.01)
	# Assert
	assert_bool(director.active_crises.has(crisis.id)).is_true()
	assert_float(_total(integrity) - damage_before).is_equal_approx((MIN_DELAY - 0.01) * BREACH_RATE, EPSILON)


func test_crisis_of_an_earlier_day_can_still_be_resolved_on_a_later_day() -> void:
	# Arrange
	var curve := _breach_only_curve()
	var director := _director(curve)
	var crisis := _start_day_one_and_fire(director, curve)
	Events.day_started.emit(2)
	# Act
	Events.task_completed.emit(1, crisis.id)
	# Assert
	assert_array(_resolved).is_equal([crisis.id])


func test_game_ended_before_any_crisis_prevents_every_crisis() -> void:
	# Arrange
	var integrity := _fake_integrity()
	var director := _director(_curve(), integrity)
	Events.day_started.emit(LATE_DAY)
	# Act
	Events.game_ended.emit(false, &"integrity_zero")
	director.tick(DAY_LENGTH)
	Events.day_started.emit(LATE_DAY + 1)
	director.tick(DAY_LENGTH)
	# Assert
	assert_array(_started).is_empty()
	assert_array(integrity.calls).is_empty()


func test_game_ended_stops_damage_of_an_active_crisis() -> void:
	# Arrange
	var integrity := _fake_integrity()
	var curve := _breach_only_curve()
	var director := _director(curve, integrity)
	_start_day_one_and_fire(director, curve)
	director.tick(1.0)
	var damage_before := _total(integrity)
	# Act
	Events.game_ended.emit(true, &"survived")
	director.tick(10.0)
	# Assert
	assert_float(_total(integrity)).is_equal(damage_before)


func test_game_ended_ignores_later_task_completed() -> void:
	# Arrange
	var curve := _breach_only_curve()
	var director := _director(curve)
	var crisis := _start_day_one_and_fire(director, curve)
	# Act
	Events.game_ended.emit(false, &"integrity_zero")
	Events.task_completed.emit(1, crisis.id)
	# Assert
	assert_array(_resolved).is_empty()


# --- integration seams ---

func test_two_active_crises_damage_together_and_resolve_independently() -> void:
	# Arrange — day 3 has two breaches; tick until both have fired
	var curve := _breach_only_curve()
	var crises := _scheduled(3, curve)
	assert_int(crises.size()).is_equal(2)
	var integrity := _fake_integrity()
	var director := _director(curve, integrity)
	Events.day_started.emit(3)
	director.tick(crises[1].start_seconds)
	# Act — one second with both, resolve the first, one second with one
	var before_both := _total(integrity)
	director.tick(1.0)
	var with_both := _total(integrity) - before_both
	Events.task_completed.emit(0, crises[0].id)
	var before_one := _total(integrity)
	director.tick(1.0)
	var with_one := _total(integrity) - before_one
	# Assert
	assert_float(with_both).is_equal_approx(2.0 * BREACH_RATE, EPSILON)
	assert_float(with_one).is_equal_approx(BREACH_RATE, EPSILON)
	assert_array(_resolved).is_equal([crises[0].id])
	assert_bool(director.active_crises.has(crises[1].id)).is_true()


func test_game_ended_during_damage_stops_the_remaining_crises_in_the_same_tick() -> void:
	# Arrange — day 3 has two breaches; the first apply_damage ends the game
	var curve := _breach_only_curve()
	var crises := _scheduled(3, curve)
	assert_int(crises.size()).is_equal(2)
	var integrity := _fake_integrity_that_ends_the_game()
	var director := _director(curve, integrity)
	Events.day_started.emit(3)
	# Act — one tick in which both crises fire and are billed
	director.tick(crises[1].start_seconds + 1.0)
	# Assert — the second crisis is not billed after the loss
	assert_int(integrity.calls.size()).is_equal(1)


func test_missing_curve_file_reports_an_error_instead_of_running_silently() -> void:
	# Arrange
	var director: Node = auto_free(DIRECTOR_SCRIPT.new())
	director.auto_tick = false
	director.run_seed = SEED
	director.curve_path = MISSING_CURVE_PATH
	# Act / Assert
	await assert_error(func() -> void: add_child(director)) \
		.is_push_error("CrisisDirector: cannot load crisis curve from %s; no crises will be scheduled" % MISSING_CURVE_PATH)


func test_day_length_is_read_from_an_injected_day_cycle_when_it_has_one() -> void:
	# Arrange — a 10 s day: every crisis must fall inside 0.75 * 10 s
	var curve := _curve()
	var director := _director(curve)
	director.day_cycle = _fake_day_cycle(10.0)
	# Act
	Events.day_started.emit(LATE_DAY)
	director.tick(8.0)
	# Assert
	assert_int(_started.size()).is_equal(curve.crises_for_day(LATE_DAY))


func test_day_cycle_without_a_day_length_property_keeps_the_default() -> void:
	# Arrange
	var curve := _curve()
	var director := _director(curve)
	director.day_cycle = auto_free(Node.new())
	# Act
	Events.day_started.emit(LATE_DAY)
	director.tick(DAY_LENGTH)
	# Assert
	assert_float(director.day_length).is_equal(DAY_LENGTH)
	assert_int(_started.size()).is_equal(curve.crises_for_day(LATE_DAY))


func test_integrity_node_without_apply_damage_is_tolerated() -> void:
	# Arrange — as on this branch, before story 001 gives the node a script
	var curve := _breach_only_curve()
	var director := _director(curve, auto_free(Node.new()))
	_start_day_one_and_fire(director, curve)
	# Act
	director.tick(1.0)
	# Assert — still fired and still tracked, no crash
	assert_int(director.active_crises.size()).is_equal(1)


func test_missing_integrity_reference_is_tolerated() -> void:
	# Arrange
	var curve := _breach_only_curve()
	var director := _director(curve, null)
	_start_day_one_and_fire(director, curve)
	# Act
	director.tick(1.0)
	# Assert
	assert_int(director.active_crises.size()).is_equal(1)


func test_director_adds_a_non_blocking_marker_overlay_that_reads_it() -> void:
	# Arrange / Act
	var director := _director(_curve())
	var overlay: Control = null
	for child in director.get_children():
		if child is Control:
			overlay = child
	# Assert
	assert_object(overlay).is_not_null()
	assert_int(overlay.mouse_filter).is_equal(Control.MOUSE_FILTER_IGNORE)
	assert_object(overlay.director).is_same(director)


func test_shipped_curve_and_station_data_run_a_day_end_to_end() -> void:
	# Arrange — no setup(): _ready loads the shipped curve and station.json
	var director: Node = auto_free(DIRECTOR_SCRIPT.new())
	director.auto_tick = false
	director.run_seed = SEED
	add_child(director)
	var map := StationMap.new()
	map.setup(StationMap.load_data())
	# Act
	Events.day_started.emit(1)
	director.tick(DAY_LENGTH)
	# Assert
	assert_int(_started.size()).is_greater_equal(1)
	assert_bool(map.has_room(_started[0][2])).is_true()
