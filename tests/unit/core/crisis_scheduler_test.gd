# Story 004 (production/epics/orbit-shift/story-004-escalating-crises.md).
# CrisisScheduler and CrisisCurve are pure logic: explicit seeds, no wall clock,
# no file I/O (except the one smoke test that loads the shipped data).
extends GdUnitTestSuite

const SEED_A := 12345
const SEED_B := 987654
const DAY_LENGTH := 60.0
const LAST_DAY := 30
const CURVE_PATH := "res://assets/data/crisis_curve.tres"


func _curve() -> CrisisCurve:
	var curve := CrisisCurve.new()
	curve.base_crises = 1.0
	curve.growth_per_day = 0.5
	curve.min_crises_per_day = 1
	curve.max_crises_per_day = 6
	curve.breach_weight = 1.0
	curve.malfunction_weight = 1.0
	curve.breach_damage_per_second = 2.0
	curve.malfunction_damage_per_second = 0.5
	curve.min_start_delay_seconds = 4.0
	curve.latest_start_day_fraction = 0.75
	return curve


func _rooms() -> Array[StringName]:
	return [&"dorm", &"bridge", &"engine", &"lab"]


func _schedule(day: int, run_seed: int = SEED_A, curve: CrisisCurve = null) -> Array[Crisis]:
	if curve == null:
		curve = _curve()
	return CrisisScheduler.schedule(day, run_seed, _rooms(), curve, DAY_LENGTH)


# Compact comparable form of a day: [id, kind, room, start] per crisis.
func _signature(crises: Array[Crisis]) -> Array:
	var rows := []
	for crisis in crises:
		rows.append([crisis.id, crisis.kind, crisis.room_id, crisis.start_seconds])
	return rows


# --- curve: count per day ---

func test_curve_crises_for_day_grows_with_the_day() -> void:
	# Arrange
	var curve := _curve()
	# Act
	var early := curve.crises_for_day(1)
	var late := curve.crises_for_day(LAST_DAY)
	# Assert
	assert_int(late).is_greater(early)
	assert_int(curve.crises_for_day(5)).is_greater_equal(curve.crises_for_day(3))


func test_curve_crises_for_day_never_drops_below_minimum_on_any_day() -> void:
	# Arrange — a curve that would round down to zero crises
	var curve := _curve()
	curve.base_crises = 0.0
	curve.growth_per_day = 0.0
	curve.min_crises_per_day = 1
	# Act / Assert
	for day in range(1, LAST_DAY + 1):
		assert_int(curve.crises_for_day(day)).is_equal(1)


func test_curve_crises_for_day_is_capped_at_maximum() -> void:
	# Arrange
	var curve := _curve()
	# Act
	var count := curve.crises_for_day(1000)
	# Assert
	assert_int(count).is_equal(curve.max_crises_per_day)


func test_curve_damage_per_second_differs_per_kind_and_is_data_driven() -> void:
	# Arrange
	var curve := _curve()
	curve.breach_damage_per_second = 3.0
	curve.malfunction_damage_per_second = 0.125
	# Act / Assert
	assert_float(curve.damage_per_second(CrisisKind.BREACH)).is_equal(3.0)
	assert_float(curve.damage_per_second(CrisisKind.MALFUNCTION)).is_equal(0.125)
	assert_float(curve.damage_per_second(&"unknown")).is_equal(0.0)


# --- scheduler: counts ---

func test_schedule_count_follows_the_curve_for_every_day() -> void:
	# Arrange
	var curve := _curve()
	for day in range(1, LAST_DAY + 1):
		# Act
		var crises := _schedule(day, SEED_A, curve)
		# Assert
		assert_int(crises.size()).is_equal(curve.crises_for_day(day))


func test_schedule_late_day_has_more_crises_than_day_one() -> void:
	# Arrange / Act
	var first := _schedule(1)
	var last := _schedule(LAST_DAY)
	# Assert
	assert_int(last.size()).is_greater(first.size())


func test_schedule_every_day_including_day_one_has_at_least_one_crisis() -> void:
	# Arrange — worst case curve: growth and base both zero
	var curve := _curve()
	curve.base_crises = 0.0
	curve.growth_per_day = 0.0
	for day in range(1, LAST_DAY + 1):
		# Act
		var crises := _schedule(day, SEED_A, curve)
		# Assert
		assert_int(crises.size()).is_greater_equal(1)


func test_schedule_day_below_one_or_no_rooms_gives_nothing() -> void:
	# Arrange
	var no_rooms: Array[StringName] = []
	# Act / Assert
	assert_array(_schedule(0)).is_empty()
	assert_array(CrisisScheduler.schedule(1, SEED_A, no_rooms, _curve(), DAY_LENGTH)).is_empty()


# --- scheduler: reproducibility ---

func test_schedule_same_seed_and_day_gives_identical_rooms_kinds_and_times() -> void:
	# Arrange / Act
	var first := _signature(_schedule(7, SEED_A))
	var second := _signature(_schedule(7, SEED_A))
	# Assert
	assert_array(first).is_equal(second)


func test_schedule_different_seed_gives_different_result() -> void:
	# Arrange / Act
	var from_a := _signature(_schedule(LAST_DAY, SEED_A))
	var from_b := _signature(_schedule(LAST_DAY, SEED_B))
	# Assert
	assert_array(from_a).is_not_equal(from_b)


func test_schedule_result_does_not_depend_on_which_days_were_scheduled_before() -> void:
	# Arrange
	var direct := _signature(_schedule(9, SEED_A))
	# Act — schedule other days first, in a different order, then day 9
	_schedule(20, SEED_A)
	_schedule(3, SEED_A)
	var after_others := _signature(_schedule(9, SEED_A))
	# Assert
	assert_array(after_others).is_equal(direct)


func test_schedule_different_days_with_same_seed_differ() -> void:
	# Arrange / Act
	var day_a := _signature(_schedule(10, SEED_A))
	var day_b := _signature(_schedule(11, SEED_A))
	# Assert
	assert_array(day_a).is_not_equal(day_b)


# --- scheduler: validity ---

func test_schedule_rooms_always_come_from_the_given_room_ids() -> void:
	# Arrange
	var rooms := _rooms()
	for day in range(1, LAST_DAY + 1):
		# Act
		for crisis in _schedule(day):
			# Assert
			assert_bool(rooms.has(crisis.room_id)).is_true()


func test_schedule_kinds_are_only_the_two_crisis_kinds() -> void:
	# Arrange
	var seen := {}
	# Act
	for day in range(1, LAST_DAY + 1):
		for crisis in _schedule(day):
			seen[crisis.kind] = true
	# Assert — both kinds occur across a whole run, nothing else does
	assert_bool(seen.has(CrisisKind.BREACH)).is_true()
	assert_bool(seen.has(CrisisKind.MALFUNCTION)).is_true()
	assert_int(seen.size()).is_equal(2)


func test_schedule_zero_weight_kind_never_appears() -> void:
	# Arrange
	var curve := _curve()
	curve.malfunction_weight = 0.0
	# Act / Assert
	for day in range(1, LAST_DAY + 1):
		for crisis in _schedule(day, SEED_A, curve):
			assert_str(crisis.kind).is_equal(CrisisKind.BREACH)


func test_schedule_times_stay_inside_the_allowed_window_and_are_sorted() -> void:
	# Arrange
	var curve := _curve()
	var earliest := curve.min_start_delay_seconds
	var latest := DAY_LENGTH * curve.latest_start_day_fraction
	for day in range(1, LAST_DAY + 1):
		var previous := 0.0
		# Act
		for crisis in _schedule(day, SEED_A, curve):
			# Assert
			assert_float(crisis.start_seconds).is_between(earliest, latest)
			assert_float(crisis.start_seconds).is_greater_equal(previous)
			previous = crisis.start_seconds


func test_schedule_never_fires_at_time_zero_even_when_data_says_zero_delay() -> void:
	# Arrange
	var curve := _curve()
	curve.min_start_delay_seconds = 0.0
	# Act / Assert
	for day in range(1, LAST_DAY + 1):
		for crisis in _schedule(day, SEED_A, curve):
			assert_float(crisis.start_seconds).is_greater(0.0)


func test_schedule_short_day_still_respects_the_minimum_delay() -> void:
	# Arrange — window collapses: latest < earliest
	var curve := _curve()
	# Act
	var crises := CrisisScheduler.schedule(1, SEED_A, _rooms(), curve, 1.0)
	# Assert
	for crisis in crises:
		assert_float(crisis.start_seconds).is_equal(curve.min_start_delay_seconds)


func test_schedule_ids_are_unique_across_the_whole_run_and_nonzero() -> void:
	# Arrange
	var ids := {}
	var total := 0
	# Act
	for day in range(1, LAST_DAY + 1):
		total += _curve().crises_for_day(day)
		for crisis in _schedule(day):
			ids[crisis.id] = true
			assert_int(crisis.id).is_not_equal(0)
			assert_int(crisis.day).is_equal(day)
	# Assert
	assert_int(ids.size()).is_equal(total)


# --- shipped data ---

func test_shipped_curve_and_station_rooms_schedule_a_crisis_every_day() -> void:
	# Arrange
	var curve := load(CURVE_PATH) as CrisisCurve
	var map := StationMap.new()
	map.setup(StationMap.load_data())
	assert_object(curve).is_not_null()
	# Assert — shipped data respects the story's contracts
	assert_float(curve.min_start_delay_seconds).is_greater(0.0)
	assert_float(curve.breach_damage_per_second).is_greater(curve.malfunction_damage_per_second)
	assert_int(curve.crises_for_day(LAST_DAY)).is_greater(curve.crises_for_day(1))
	for day in range(1, LAST_DAY + 1):
		# Act
		var crises := CrisisScheduler.schedule(day, SEED_A, map.room_ids, curve, DAY_LENGTH)
		# Assert
		assert_int(crises.size()).is_greater_equal(1)
		for crisis in crises:
			assert_bool(map.has_room(crisis.room_id)).is_true()
