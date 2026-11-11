# Story 006 (production/epics/orbit-shift/story-006-result-screen.md): the result
# screen text and its show-on-game_ended behaviour. Text is built by a pure static
# function; the scene tests only emit Events.game_ended and never press the
# "Play again" button (that reloads the scene). No file I/O, no wall clock.
extends GdUnitTestSuite

const RESULT_SCREEN := preload("res://src/ui/result_screen.gd")
const RESULT_SCENE := preload("res://src/ui/result_screen.tscn")
const COLONISTS_SCRIPT := preload("res://src/core/colonists.gd")
const MAIN_SCENE := preload("res://src/main.tscn")

# Line graph a - b. Colonists start in a.
const DATA := {
	"dorm_id": "b",
	"start_room": "a",
	"rooms": [
		{"id": "a", "name": "A", "color": "#ffffff", "pos": [0, 0]},
		{"id": "b", "name": "B", "color": "#ffffff", "pos": [0, 0]},
	],
	"connections": [["a", "b"]],
	"colonists": ["Ann", "Bob"],
	"move_seconds": 2.0,
	"fatigue_max": 100.0,
	"fatigue_rise_per_sec": 10.0,
	"fatigue_fall_per_sec": 20.0,
	"rest_threshold": 40.0,
	"collapse_seconds": 5.0,
}


# DayCycle that is on [param day] of 30, not started (no signals hooked up).
func _cycle(day: int) -> Node:
	var cycle: Node = auto_free(DayCycle.new())
	cycle.configure(60.0, 30)
	cycle.current_day = day
	return cycle


func _integrity(current: float, max_value: float = 100.0) -> Node:
	var integrity: Node = auto_free(StationIntegrity.new())
	integrity.max_value = max_value
	integrity.current = current
	return integrity


# Colonists node with Ann idle and Bob working in room a.
func _colonists() -> Node:
	var colonists: Node = auto_free(COLONISTS_SCRIPT.new())
	colonists.auto_tick = false
	colonists.setup(DATA)
	colonists.colonists[1].assign_work(&"a")
	return colonists


func _screen() -> CanvasLayer:
	var screen: CanvasLayer = auto_free(RESULT_SCENE.instantiate())
	add_child(screen)
	return screen


# --- text ---

func test_summary_lines_victory_shows_title_and_all_days_survived() -> void:
	# Arrange
	var cycle := _cycle(30)
	# Act
	var lines := RESULT_SCREEN.summary_lines(true, DayCycle.REASON_SURVIVED, cycle, _integrity(40.0), null)
	# Assert
	assert_str(lines[0]).is_equal("VICTORY")
	assert_array(lines).contains(["Days survived: 30 / 30"])
	assert_array(lines).contains(["Integrity: 40 / 100"])


func test_summary_lines_victory_has_no_reason_line() -> void:
	# Act
	var lines := RESULT_SCREEN.summary_lines(true, DayCycle.REASON_SURVIVED, _cycle(30), null, null)
	# Assert
	for line in lines:
		assert_bool(line.begins_with("Reason")).is_false()


func test_summary_lines_integrity_loss_shows_reason_and_days_before_current() -> void:
	# Arrange: lost on day 8, so 7 days were survived
	var cycle := _cycle(8)
	# Act
	var lines := RESULT_SCREEN.summary_lines(false, DayCycle.REASON_INTEGRITY, cycle, _integrity(0.0), null)
	# Assert
	assert_str(lines[0]).is_equal("STATION LOST")
	assert_str(lines[1]).is_equal("Reason: Integrity depleted")
	assert_array(lines).contains(["Days survived: 7 / 30"])
	assert_array(lines).contains(["Integrity: 0 / 100"])


func test_summary_lines_colonists_loss_shows_all_collapsed_reason() -> void:
	# Act
	var lines := RESULT_SCREEN.summary_lines(false, DayCycle.REASON_COLONISTS, _cycle(3), _integrity(60.0), null)
	# Assert
	assert_str(lines[0]).is_equal("STATION LOST")
	assert_str(lines[1]).is_equal("Reason: All colonists collapsed")


func test_summary_lines_unknown_reason_shows_the_reason_string() -> void:
	# Act
	var lines := RESULT_SCREEN.summary_lines(false, &"meteor", _cycle(3), null, null)
	# Assert
	assert_str(lines[1]).is_equal("Reason: meteor")


func test_summary_lines_loss_on_day_one_survived_zero_days() -> void:
	# Act
	var lines := RESULT_SCREEN.summary_lines(false, DayCycle.REASON_INTEGRITY, _cycle(1), null, null)
	# Assert
	assert_array(lines).contains(["Days survived: 0 / 30"])


func test_summary_lines_integrity_is_rounded_up_like_the_hud() -> void:
	# Act
	var lines := RESULT_SCREEN.summary_lines(false, DayCycle.REASON_INTEGRITY, _cycle(2), _integrity(12.2), null)
	# Assert
	assert_array(lines).contains(["Integrity: 13 / 100"])


func test_summary_lines_colonists_null_shows_dash_without_error() -> void:
	# Act
	var lines := RESULT_SCREEN.summary_lines(true, DayCycle.REASON_SURVIVED, _cycle(30), _integrity(50.0), null)
	# Assert
	assert_array(lines).contains(["Colonists: —"])


func test_summary_lines_colonists_without_any_colonist_shows_dash() -> void:
	# Arrange: node exists but setup never ran
	var empty: Node = auto_free(COLONISTS_SCRIPT.new())
	# Act
	var lines := RESULT_SCREEN.summary_lines(true, DayCycle.REASON_SURVIVED, _cycle(30), _integrity(50.0), empty)
	# Assert
	assert_array(lines).contains(["Colonists: —"])


func test_summary_lines_lists_each_colonist_with_status_label() -> void:
	# Act
	var lines := RESULT_SCREEN.summary_lines(true, DayCycle.REASON_SURVIVED, _cycle(30), _integrity(50.0), _colonists())
	# Assert
	assert_array(lines).contains(["Colonists:", "  Ann: IDLE", "  Bob: WORKING"])


func test_summary_lines_missing_day_cycle_and_integrity_show_dash() -> void:
	# Act
	var lines := RESULT_SCREEN.summary_lines(false, DayCycle.REASON_INTEGRITY, null, null, null)
	# Assert
	assert_array(lines).contains(["Days survived: —", "Integrity: —", "Colonists: —"])


# --- scene ---

func test_screen_is_hidden_until_game_ended() -> void:
	# Act
	var screen := _screen()
	# Assert
	assert_bool(screen.visible).is_false()


func test_screen_shows_victory_text_after_game_ended() -> void:
	# Arrange
	var screen := _screen()
	screen.day_cycle = _cycle(30)
	screen.station_integrity = _integrity(55.0)
	screen.colonists = _colonists()
	# Act
	Events.game_ended.emit(true, DayCycle.REASON_SURVIVED)
	# Assert
	assert_bool(screen.visible).is_true()
	assert_str(screen.get_node("%TitleLabel").text).is_equal("VICTORY")
	assert_str(screen.get_node("%BodyLabel").text).contains("Days survived: 30 / 30")
	assert_str(screen.get_node("%BodyLabel").text).contains("Bob: WORKING")


func test_screen_shows_loss_reason_after_game_ended() -> void:
	# Arrange: injected refs left null, as when other stories are not merged
	var screen := _screen()
	# Act
	Events.game_ended.emit(false, DayCycle.REASON_COLONISTS)
	# Assert
	assert_bool(screen.visible).is_true()
	assert_str(screen.get_node("%TitleLabel").text).is_equal("STATION LOST")
	assert_str(screen.get_node("%BodyLabel").text).contains("Reason: All colonists collapsed")
	assert_str(screen.get_node("%BodyLabel").text).contains("Colonists: —")


func test_screen_draws_above_the_hud_layer_of_main() -> void:
	# Arrange: the real Hud of the main scene, not a guessed layer number
	var main: Node = auto_free(MAIN_SCENE.instantiate())
	var hud: CanvasLayer = main.get_node("Hud")
	# Act
	var screen := _screen()
	# Assert
	assert_int(screen.layer).is_greater(hud.layer)


func test_play_again_button_is_wired_to_restart_and_focused_on_show() -> void:
	# Arrange — pressing it would reload the test scene, so check the wiring
	var screen := _screen()
	var button: Button = screen.get_node("%PlayAgainButton")
	# Act
	Events.game_ended.emit(false, DayCycle.REASON_INTEGRITY)
	# Assert
	assert_bool(button.pressed.is_connected(screen.restart)).is_true()
	assert_bool(button.has_focus()).is_true()


func test_second_game_ended_keeps_the_first_result() -> void:
	# Arrange
	var screen := _screen()
	Events.game_ended.emit(false, DayCycle.REASON_INTEGRITY)
	# Act: a stray later emit with another result
	Events.game_ended.emit(true, DayCycle.REASON_SURVIVED)
	# Assert
	assert_bool(screen.visible).is_true()
	assert_str(screen.get_node("%TitleLabel").text).is_equal("STATION LOST")
	assert_str(screen.get_node("%BodyLabel").text).contains("Reason: Integrity depleted")


func test_summary_lines_shows_a_collapsed_colonist() -> void:
	# Arrange: Ann works until exhausted, walks to the dorm (b) and is kept out by
	# a dorm crisis for longer than collapse_seconds
	var colonists := _colonists()
	var ann: Colonist = colonists.colonists[0]
	ann.assign_work(&"a")
	for i in 40:
		ann.tick(0.5, true)
	# Act
	var lines := RESULT_SCREEN.summary_lines(false, DayCycle.REASON_COLONISTS, _cycle(4), null, colonists)
	# Assert
	assert_bool(ann.is_collapsed()).is_true()
	assert_array(lines).contains(["  Ann: COLLAPSED"])


func test_main_injects_day_cycle_integrity_and_colonists_into_the_result_screen() -> void:
	# Arrange: out of the tree, so no system _ready runs; only Main's wiring is used
	var main: Node = auto_free(MAIN_SCENE.instantiate())
	var screen: Node = main.get_node("ResultScreen")
	# Act
	main.inject_dependencies()
	# Assert: a dropped INJECTIONS row would otherwise show "—" everywhere
	assert_object(screen.day_cycle).is_same(main.get_node("DayCycle"))
	assert_object(screen.station_integrity).is_same(main.get_node("StationIntegrity"))
	assert_object(screen.colonists).is_same(main.get_node("Colonists"))
