# Story 007 (production/epics/orbit-shift/story-007-colonist-status.md): the
# Colonists column of the S04 priority panel uses ColonistStatus words and adds a
# task line only for a colonist on a task. Built like task_board_test.gd: real
# Colonists and TaskBoard nodes, driven with explicit deltas, no file I/O.
extends GdUnitTestSuite

const COLONISTS_SCRIPT := preload("res://src/core/colonists.gd")
const BOARD_SCRIPT := preload("res://src/core/task_board.gd")

# Line graph a - b - c - dorm. Colonists start in a, a hop takes 2s, a task 4s.
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
var _panel: Control


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
	# TaskBoard adds the panel as its child in _ready.
	_panel = _board.get_child(0)
	# Only Ann takes tasks; Bob and Cat stay idle in a.
	_colonists.colonists[1].fatigue = 100.0
	_colonists.colonists[2].fatigue = 100.0


# One frame in the real order: colonists move first, then the board reacts.
func _step(delta: float) -> void:
	_colonists.tick(delta)
	_board.tick(delta)


func _ann() -> Colonist:
	return _colonists.colonists[0]


func test_task_detail_is_empty_for_a_colonist_without_a_task() -> void:
	# Assert: nothing on the board yet
	assert_str(_panel._task_detail(0, _ann())).is_empty()


func test_task_detail_shows_the_destination_while_walking_to_the_task() -> void:
	# Arrange
	_board.add_task(CrisisKind.BREACH, &"b")
	# Act: Ann claims and starts the 2s hop to b
	_step(0.5)
	# Assert
	assert_int(ColonistStatus.of(_ann())).is_equal(ColonistStatus.Kind.MOVING)
	assert_str(_panel._task_detail(0, _ann())).is_equal("to B (Breach)")


func test_task_detail_shows_the_percent_done_while_working_in_place() -> void:
	# Arrange
	_board.add_task(CrisisKind.BREACH, &"b")
	_step(0.5)  # claim
	_step(2.0)  # arrive, seen in place
	# Act: 1s of the 4s task
	_step(1.0)
	# Assert
	assert_int(ColonistStatus.of(_ann())).is_equal(ColonistStatus.Kind.WORKING)
	assert_str(_panel._task_detail(0, _ann())).is_equal("B (Breach) 25%")


func test_task_detail_is_empty_once_an_exhausted_colonist_heads_to_rest() -> void:
	# Arrange: Ann works a task in a at fatigue 95
	_ann().fatigue = 95.0
	_board.add_task(CrisisKind.BREACH, &"a")
	_step(0.5)  # claim (already in a)
	# Act: 1s of work takes her to max fatigue; the board releases the task
	_step(1.0)
	# Assert: walking to the dorm, no task line under her status
	assert_int(ColonistStatus.of(_ann())).is_equal(ColonistStatus.Kind.MOVING)
	assert_str(_panel._task_detail(0, _ann())).is_empty()


func test_colonist_lines_use_colonist_status_words_and_indent_the_task_line() -> void:
	# Arrange
	_board.add_task(CrisisKind.BREACH, &"b")
	# Act
	_step(0.5)
	# Assert: Ann has a task line, the idle colonists have none
	assert_str(_panel._colonist_lines()).is_equal(
			"Ann: MOVING\n   to B (Breach)\nBob: IDLE\nCat: IDLE")
