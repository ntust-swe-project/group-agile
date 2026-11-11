# Logic tests for DayCycle, StationIntegrity and GameConfig (story 001).
# Time is stepped with advance(); no real time. File access is limited to the
# constant fixtures under tests/fixtures/game_config/ and one check of the
# shipped config file.
extends GdUnitTestSuite

const DAY_LENGTH := 10.0
const TOTAL_DAYS := 3
const INTEGRITY_MAX := 100.0
const FIXTURE_DIR := "res://tests/fixtures/game_config/"

var _cycle: DayCycle
# A listener that ends the run from inside day_ended; disconnected in after_test.
var _collapse_on_day_end: Callable
var _integrity: StationIntegrity
var _days_started: Array[int] = []
var _days_ended: Array[int] = []
var _integrity_values: Array[float] = []
var _endings: Array = []


func before_test() -> void:
	_days_started.clear()
	_days_ended.clear()
	_integrity_values.clear()
	_endings.clear()
	_collapse_on_day_end = func(_day: int) -> void: Events.colonists_collapsed.emit()
	Events.day_started.connect(_on_day_started)
	Events.day_ended.connect(_on_day_ended)
	Events.integrity_changed.connect(_on_integrity_changed)
	Events.game_ended.connect(_on_game_ended)
	_cycle = auto_free(DayCycle.new())
	_cycle.configure(DAY_LENGTH, TOTAL_DAYS)
	_integrity = auto_free(StationIntegrity.new())


func after_test() -> void:
	if Events.day_ended.is_connected(_collapse_on_day_end):
		Events.day_ended.disconnect(_collapse_on_day_end)
	Events.day_started.disconnect(_on_day_started)
	Events.day_ended.disconnect(_on_day_ended)
	Events.integrity_changed.disconnect(_on_integrity_changed)
	Events.game_ended.disconnect(_on_game_ended)


func _on_day_started(day: int) -> void:
	_days_started.append(day)


func _on_day_ended(day: int) -> void:
	_days_ended.append(day)


func _on_integrity_changed(current: float, _max_value: float) -> void:
	_integrity_values.append(current)


func _on_game_ended(won: bool, reason: StringName) -> void:
	_endings.append([won, reason])


# --- day cycle ---

func test_start_begins_at_day_one_and_emits_day_started() -> void:
	# Act
	_cycle.start()

	# Assert
	assert_int(_cycle.current_day).is_equal(1)
	assert_array(_days_started).is_equal([1])


func test_advance_below_day_length_does_not_change_day() -> void:
	# Arrange
	_cycle.start()

	# Act
	_cycle.advance(DAY_LENGTH - 0.1)

	# Assert
	assert_int(_cycle.current_day).is_equal(1)
	assert_array(_days_ended).is_empty()


func test_advance_past_day_length_ends_day_and_starts_next() -> void:
	# Arrange
	_cycle.start()

	# Act
	_cycle.advance(DAY_LENGTH)

	# Assert
	assert_int(_cycle.current_day).is_equal(2)
	assert_array(_days_ended).is_equal([1])
	assert_array(_days_started).is_equal([1, 2])


func test_advance_with_large_delta_runs_each_day_in_order() -> void:
	# Arrange
	_cycle.start()

	# Act — two full days in one step
	_cycle.advance(DAY_LENGTH * 2.0)

	# Assert
	assert_array(_days_ended).is_equal([1, 2])
	assert_array(_days_started).is_equal([1, 2, 3])


func test_leftover_time_carries_into_the_next_day() -> void:
	# Arrange
	_cycle.start()

	# Act — 14s ends day 1 with 4s left over; 6 more seconds finish day 2
	_cycle.advance(DAY_LENGTH + 4.0)
	_cycle.advance(6.0)

	# Assert
	assert_array(_days_ended).is_equal([1, 2])
	assert_int(_cycle.current_day).is_equal(3)


func test_day_length_comes_from_configure_not_a_fixed_value() -> void:
	# Arrange
	_cycle.configure(2.0, TOTAL_DAYS)
	_cycle.start()

	# Act
	_cycle.advance(2.0)

	# Assert
	assert_int(_cycle.current_day).is_equal(2)


# --- win ---

func test_ending_last_day_wins_and_stops_time() -> void:
	# Arrange
	_cycle.start()

	# Act
	_cycle.advance(DAY_LENGTH * TOTAL_DAYS)

	# Assert
	assert_array(_endings).is_equal([[true, DayCycle.REASON_SURVIVED]])
	assert_array(_days_ended).is_equal([1, 2, 3])
	assert_bool(_cycle.is_running()).is_false()


func test_advance_after_game_ended_does_nothing() -> void:
	# Arrange
	_cycle.start()
	_cycle.advance(DAY_LENGTH * TOTAL_DAYS)

	# Act
	_cycle.advance(DAY_LENGTH * 5.0)

	# Assert
	assert_array(_days_ended).is_equal([1, 2, 3])
	assert_int(_endings.size()).is_equal(1)


# --- loss ---

func test_colonists_collapsed_signal_loses_immediately_and_stops_time() -> void:
	# Arrange
	_cycle.start()

	# Act
	Events.colonists_collapsed.emit()
	_cycle.advance(DAY_LENGTH)

	# Assert
	assert_array(_endings).is_equal([[false, DayCycle.REASON_COLONISTS]])
	assert_bool(_cycle.is_running()).is_false()
	assert_array(_days_ended).is_empty()


func test_integrity_reaching_zero_loses_immediately() -> void:
	# Arrange
	_cycle.start()
	_integrity.configure(INTEGRITY_MAX)

	# Act
	_integrity.apply_damage(INTEGRITY_MAX)

	# Assert
	assert_array(_endings).is_equal([[false, DayCycle.REASON_INTEGRITY]])
	assert_bool(_cycle.is_running()).is_false()


func test_integrity_above_zero_does_not_lose() -> void:
	# Arrange
	_cycle.start()
	_integrity.configure(INTEGRITY_MAX)

	# Act
	_integrity.apply_damage(INTEGRITY_MAX - 1.0)

	# Assert
	assert_array(_endings).is_empty()
	assert_bool(_cycle.is_running()).is_true()


func test_loss_during_day_ended_does_not_start_next_day() -> void:
	# Arrange — a system reacting to day_ended ends the run (here: collapse)
	_cycle.start()
	Events.day_ended.connect(_collapse_on_day_end)

	# Act
	_cycle.advance(DAY_LENGTH)

	# Assert — game_ended fired once, and no day started after it
	assert_array(_endings).is_equal([[false, DayCycle.REASON_COLONISTS]])
	assert_array(_days_started).is_equal([1])
	assert_int(_cycle.current_day).is_equal(1)
	assert_bool(_cycle.is_running()).is_false()


func test_loss_during_last_day_ended_is_a_loss_not_a_win() -> void:
	# Arrange — reach the last day, then let day_ended end the run
	_cycle.start()
	_cycle.advance(DAY_LENGTH * (TOTAL_DAYS - 1))
	Events.day_ended.connect(_collapse_on_day_end)

	# Act
	_cycle.advance(DAY_LENGTH)

	# Assert — exactly one ending, and it is the loss
	assert_array(_endings).is_equal([[false, DayCycle.REASON_COLONISTS]])
	assert_array(_days_ended).is_equal([1, 2, 3])
	assert_bool(_cycle.is_running()).is_false()


func test_loss_after_win_does_not_emit_second_game_ended() -> void:
	# Arrange
	_cycle.start()
	_cycle.advance(DAY_LENGTH * TOTAL_DAYS)

	# Act
	Events.colonists_collapsed.emit()

	# Assert
	assert_int(_endings.size()).is_equal(1)


# --- station integrity ---

func test_configure_sets_cap_and_starts_full() -> void:
	# Act
	_integrity.configure(INTEGRITY_MAX)

	# Assert
	assert_float(_integrity.current).is_equal(INTEGRITY_MAX)
	assert_float(_integrity.max_value).is_equal(INTEGRITY_MAX)
	assert_array(_integrity_values).is_equal([INTEGRITY_MAX])


func test_apply_damage_reduces_current_and_emits_changed() -> void:
	# Arrange
	_integrity.configure(INTEGRITY_MAX)

	# Act
	_integrity.apply_damage(30.0)

	# Assert
	assert_float(_integrity.current).is_equal(70.0)
	assert_array(_integrity_values).is_equal([INTEGRITY_MAX, 70.0])


func test_apply_damage_never_goes_below_zero() -> void:
	# Arrange
	_integrity.configure(INTEGRITY_MAX)

	# Act
	_integrity.apply_damage(INTEGRITY_MAX * 5.0)

	# Assert
	assert_float(_integrity.current).is_equal(0.0)


func test_apply_damage_with_negative_amount_does_not_repair() -> void:
	# Arrange
	_integrity.configure(INTEGRITY_MAX)
	_integrity.apply_damage(40.0)

	# Act
	_integrity.apply_damage(-25.0)

	# Assert
	assert_float(_integrity.current).is_equal(60.0)
	assert_array(_integrity_values).is_equal([INTEGRITY_MAX, 60.0])


func test_damage_before_first_frame_is_not_refilled_by_startup() -> void:
	# Arrange — in the tree, _ready sets the cap at once and defers only the announcement
	var integrity: StationIntegrity = auto_free(StationIntegrity.new())
	add_child(integrity)

	# Act — damage lands in the same frame, before the deferred announcement runs
	integrity.apply_damage(30.0)
	await get_tree().process_frame

	# Assert — still damaged, and the announcement reports the damaged value
	assert_float(integrity.current).is_equal(integrity.max_value - 30.0)
	assert_float(_integrity_values[-1]).is_equal(integrity.max_value - 30.0)


func test_startup_announces_integrity_once_after_the_first_frame() -> void:
	# Arrange / Act
	var integrity: StationIntegrity = auto_free(StationIntegrity.new())
	add_child(integrity)
	var announced_before_frame := _integrity_values.size()
	await get_tree().process_frame

	# Assert
	assert_int(announced_before_frame).is_equal(0)
	assert_array(_integrity_values).is_equal([integrity.max_value])


# --- data file validation ---

func test_validate_accepts_complete_settings() -> void:
	# Arrange
	var data := {"day_length_seconds": 60.0, "total_days": 30, "integrity_max": 100}

	# Act / Assert
	assert_str(GameConfig.validate(data)).is_empty()


func test_validate_rejects_missing_key() -> void:
	# Arrange
	var data := {"day_length_seconds": 60.0, "total_days": 30}

	# Act / Assert
	assert_str(GameConfig.validate(data)).contains("integrity_max")


func test_validate_rejects_non_positive_values() -> void:
	# Arrange
	var data := {"day_length_seconds": 0, "total_days": 30, "integrity_max": 100}

	# Act / Assert
	assert_str(GameConfig.validate(data)).contains("day_length_seconds")


func test_validate_rejects_fractional_total_days() -> void:
	# Arrange
	var data := {"day_length_seconds": 60, "total_days": 2.5, "integrity_max": 100}

	# Act / Assert
	assert_str(GameConfig.validate(data)).contains("total_days")


func test_validate_rejects_non_dictionary() -> void:
	# Act / Assert
	assert_str(GameConfig.validate([1, 2])).is_not_empty()


func test_load_settings_returns_all_three_values_with_converted_types() -> void:
	# Act — the fixture mixes ints and floats on purpose
	var settings := GameConfig.load_settings(FIXTURE_DIR + "valid.json")

	# Assert
	assert_int(settings.size()).is_equal(3)
	assert_int(typeof(settings["day_length_seconds"])).is_equal(TYPE_FLOAT)
	assert_float(settings["day_length_seconds"]).is_equal(45.0)
	assert_int(typeof(settings["total_days"])).is_equal(TYPE_INT)
	assert_int(settings["total_days"]).is_equal(7)
	assert_int(typeof(settings["integrity_max"])).is_equal(TYPE_FLOAT)
	assert_float(settings["integrity_max"]).is_equal(250.5)


func test_load_settings_with_missing_file_returns_empty() -> void:
	# Act
	var settings := GameConfig.load_settings(FIXTURE_DIR + "does_not_exist.json")

	# Assert
	assert_dict(settings).is_empty()


func test_load_settings_with_non_json_file_returns_empty() -> void:
	# Act
	var settings := GameConfig.load_settings(FIXTURE_DIR + "not_json.json")

	# Assert
	assert_dict(settings).is_empty()


func test_load_settings_with_invalid_values_returns_empty() -> void:
	# Act
	var settings := GameConfig.load_settings(FIXTURE_DIR + "invalid_values.json")

	# Assert
	assert_dict(settings).is_empty()


func test_shipped_config_file_loads_with_sane_values() -> void:
	# Act — reads the real file; checks it loads and is plausible, not its tuning
	var settings := GameConfig.load_settings()

	# Assert
	assert_bool(settings.is_empty()).is_false()
	assert_float(settings["day_length_seconds"]).is_greater_equal(1.0)
	assert_int(settings["total_days"]).is_greater_equal(1)
	assert_float(settings["integrity_max"]).is_greater(0.0)
