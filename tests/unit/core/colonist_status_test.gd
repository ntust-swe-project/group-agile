# Story 007 (production/epics/orbit-shift/story-007-colonist-status.md).
# Pure logic: colonists are driven with explicit deltas and injected data.
extends GdUnitTestSuite

# Line graph a - b - c - dorm. Tunables are exact binary fractions.
const DATA := {
	"dorm_id": "dorm",
	"start_room": "a",
	"rooms": [
		{"id": "a", "name": "A", "color": "#ffffff", "pos": [0, 0]},
		{"id": "b", "name": "B", "color": "#ffffff", "pos": [0, 0]},
		{"id": "c", "name": "C", "color": "#ffffff", "pos": [0, 0]},
		{"id": "dorm", "name": "Dorm", "color": "#ffffff", "pos": [0, 0]},
	],
	"connections": [["a", "b"], ["b", "c"], ["c", "dorm"]],
	"colonists": ["Ann"],
	"move_seconds": 2.0,
	"fatigue_max": 100.0,
	"fatigue_rise_per_sec": 10.0,
	"fatigue_fall_per_sec": 20.0,
	"rest_threshold": 40.0,
	"collapse_seconds": 5.0,
}


# Colonist standing in [param start_room], idle.
func _colonist(start_room: StringName = &"a") -> Colonist:
	var map := StationMap.new()
	map.setup(DATA)
	return Colonist.new("Ann", Mover.new(map, start_room, DATA["move_seconds"]), map.dorm_id, DATA)


# Colonist that stands in its work room "a" and is working.
func _working() -> Colonist:
	var colonist := _colonist()
	colonist.assign_work(&"a")
	return colonist


# Colonist at max fatigue standing in the dorm, blocked by a dorm crisis for longer
# than collapse_seconds.
func _collapsed() -> Colonist:
	var colonist := _colonist(&"dorm")
	colonist.fatigue = colonist.fatigue_max
	colonist.assign_work(&"a")
	colonist.tick(DATA["collapse_seconds"] + 1.0, true)
	return colonist


# --- the five states ---

func test_status_idle_colonist_is_idle() -> void:
	assert_int(ColonistStatus.of(_colonist())).is_equal(ColonistStatus.Kind.IDLE)


func test_status_working_colonist_in_work_room_is_working() -> void:
	assert_int(ColonistStatus.of(_working())).is_equal(ColonistStatus.Kind.WORKING)


func test_status_colonist_on_the_way_to_work_is_moving() -> void:
	var colonist := _colonist()
	colonist.assign_work(&"c")
	assert_int(ColonistStatus.of(colonist)).is_equal(ColonistStatus.Kind.MOVING)


func test_status_resting_colonist_in_dorm_is_resting() -> void:
	var colonist := _colonist(&"dorm")
	colonist.fatigue = colonist.fatigue_max
	colonist.assign_work(&"a")
	colonist.tick(0.5, false)
	assert_int(colonist.state).is_equal(Colonist.State.RESTING)
	assert_int(ColonistStatus.of(colonist)).is_equal(ColonistStatus.Kind.RESTING)


func test_status_blocked_exhausted_colonist_in_dorm_is_collapsed() -> void:
	assert_int(ColonistStatus.of(_collapsed())).is_equal(ColonistStatus.Kind.COLLAPSED)


# --- priority and "moving is not working" ---

func test_status_moving_colonist_with_working_state_reads_moving() -> void:
	# Arrange: ordered to b, so the state is WORKING while still walking there
	var colonist := _colonist()
	colonist.assign_work(&"b")
	# Assert
	assert_int(colonist.state).is_equal(Colonist.State.WORKING)
	assert_int(ColonistStatus.of(colonist)).is_equal(ColonistStatus.Kind.MOVING)


func test_status_colonist_walking_to_dorm_is_moving_not_resting() -> void:
	var colonist := _colonist()
	colonist.fatigue = colonist.fatigue_max
	colonist.assign_work(&"a")
	assert_int(colonist.state).is_equal(Colonist.State.RESTING)
	assert_int(ColonistStatus.of(colonist)).is_equal(ColonistStatus.Kind.MOVING)


func test_status_collapsed_colonist_that_starts_moving_reads_as_moving() -> void:
	# Arrange: a collapsed colonist is ordered to move again.
	var colonist := _collapsed()
	colonist.mover.start_move(&"c")
	assert_bool(colonist.mover.is_moving()).is_true()
	# Act / Assert: is_collapsed() itself requires "not moving", so collapsed and
	# moving never hold together; the status follows is_collapsed().
	assert_bool(colonist.is_collapsed()).is_false()
	assert_int(ColonistStatus.of(colonist)).is_equal(ColonistStatus.Kind.MOVING)


func test_status_collapsed_beats_the_state_based_kinds() -> void:
	var colonist := _collapsed()
	assert_int(colonist.state).is_equal(Colonist.State.RESTING)
	assert_int(ColonistStatus.of(colonist)).is_not_equal(ColonistStatus.Kind.RESTING)


# --- labels and symbols ---

func test_labels_are_different_for_every_status() -> void:
	var seen := {}
	for kind: int in ColonistStatus.Kind.values():
		var text := ColonistStatus.label(kind)
		assert_str(text).is_not_empty()
		assert_bool(seen.has(text)).is_false()
		seen[text] = true
	assert_int(seen.size()).is_equal(5)


func test_symbols_are_different_single_characters_for_every_status() -> void:
	var seen := {}
	for kind: int in ColonistStatus.Kind.values():
		var text := ColonistStatus.symbol(kind)
		assert_int(text.length()).is_equal(1)
		assert_bool(seen.has(text)).is_false()
		seen[text] = true
	assert_int(seen.size()).is_equal(5)


func test_symbols_are_ascii_so_the_default_font_can_draw_them() -> void:
	for kind: int in ColonistStatus.Kind.values():
		assert_bool(ColonistStatus.symbol(kind).unicode_at(0) < 128).is_true()


# --- fatigue ratio ---

func test_fatigue_ratio_is_zero_for_a_rested_colonist() -> void:
	assert_float(ColonistStatus.fatigue_ratio(_colonist())).is_equal(0.0)


func test_fatigue_ratio_is_the_share_of_max_in_between() -> void:
	var colonist := _colonist()
	colonist.fatigue = 25.0
	assert_float(ColonistStatus.fatigue_ratio(colonist)).is_equal(0.25)


func test_fatigue_ratio_is_one_at_max_fatigue() -> void:
	var colonist := _colonist()
	colonist.fatigue = colonist.fatigue_max
	assert_float(ColonistStatus.fatigue_ratio(colonist)).is_equal(1.0)


func test_fatigue_ratio_is_zero_when_max_fatigue_is_not_positive() -> void:
	# Arrange: a bad data value must not reach draw_rect as NaN or inf
	var colonist := _colonist()
	colonist.fatigue = 10.0
	colonist.fatigue_max = 0.0
	# Act / Assert
	assert_float(ColonistStatus.fatigue_ratio(colonist)).is_equal(0.0)


func test_status_colonist_after_clear_work_is_idle() -> void:
	# Arrange: working in a, then its task is taken away (TaskBoard does this, story 003)
	var colonist := _working()
	# Act
	colonist.clear_work()
	# Assert
	assert_int(ColonistStatus.of(colonist)).is_equal(ColonistStatus.Kind.IDLE)


func test_symbols_match_the_story_acceptance_examples() -> void:
	# Assert: > W Z - ! (story 007; "-" replaces "." because a 24 px dot is too small)
	assert_str(ColonistStatus.symbol(ColonistStatus.Kind.MOVING)).is_equal(">")
	assert_str(ColonistStatus.symbol(ColonistStatus.Kind.WORKING)).is_equal("W")
	assert_str(ColonistStatus.symbol(ColonistStatus.Kind.RESTING)).is_equal("Z")
	assert_str(ColonistStatus.symbol(ColonistStatus.Kind.IDLE)).is_equal("-")
	assert_str(ColonistStatus.symbol(ColonistStatus.Kind.COLLAPSED)).is_equal("!")


func test_labels_match_the_text_shown_on_screen() -> void:
	# Assert
	assert_str(ColonistStatus.label(ColonistStatus.Kind.MOVING)).is_equal("MOVING")
	assert_str(ColonistStatus.label(ColonistStatus.Kind.WORKING)).is_equal("WORKING")
	assert_str(ColonistStatus.label(ColonistStatus.Kind.RESTING)).is_equal("RESTING")
	assert_str(ColonistStatus.label(ColonistStatus.Kind.IDLE)).is_equal("IDLE")
	assert_str(ColonistStatus.label(ColonistStatus.Kind.COLLAPSED)).is_equal("COLLAPSED")
