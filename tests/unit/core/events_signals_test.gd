# Checks the Events autoload against the signal contract in
# production/epics/orbit-shift/EPIC.md (整合約定). If this fails, the code and
# the contract disagree: fix whichever one is wrong in the same PR.
extends GdUnitTestSuite

const EVENTS_PATH := "res://src/core/events.gd"

# Signal name -> ordered [arg name, Variant type] pairs, copied from EPIC.md.
const CONTRACT := {
	"day_started": [["day", TYPE_INT]],
	"day_ended": [["day", TYPE_INT]],
	"integrity_changed": [["current", TYPE_FLOAT], ["max_value", TYPE_FLOAT]],
	"game_ended": [["won", TYPE_BOOL], ["reason", TYPE_STRING_NAME]],
	"colonists_collapsed": [],
	"crisis_started": [["crisis_id", TYPE_INT], ["kind", TYPE_STRING_NAME], ["room_id", TYPE_STRING_NAME]],
	"crisis_resolved": [["crisis_id", TYPE_INT]],
	"task_completed": [["task_id", TYPE_INT], ["crisis_id", TYPE_INT]],
}


func _declared_signals() -> Dictionary:
	var script: Script = load(EVENTS_PATH)
	var result := {}
	for sig in script.get_script_signal_list():
		result[sig["name"]] = sig["args"]
	return result


func test_events_autoload_is_registered_to_events_script() -> void:
	# Arrange
	var key := "autoload/Events"

	# Act — the editor may store the path as a uid:// string; resolve it
	var value: String = ProjectSettings.get_setting(key, "")
	var path := value.trim_prefix("*")
	if path.begins_with("uid://"):
		path = ResourceUID.get_id_path(ResourceUID.text_to_id(path))

	# Assert — the leading * means it is a singleton (global name Events)
	assert_bool(value.begins_with("*")).is_true()
	assert_str(path).is_equal(EVENTS_PATH)


func test_events_declares_exactly_the_contract_signals() -> void:
	# Arrange
	var expected: Array = CONTRACT.keys()
	expected.sort()

	# Act
	var actual: Array = _declared_signals().keys()
	actual.sort()

	# Assert
	assert_array(actual).is_equal(expected)


func test_events_signal_args_match_contract_names_and_types() -> void:
	# Arrange
	var declared := _declared_signals()

	for signal_name in CONTRACT:
		# Act
		var args: Array = declared.get(signal_name, [])
		var actual := []
		for arg in args:
			actual.append([arg["name"], arg["type"]])

		# Assert
		assert_array(actual).override_failure_message(
			"signal %s args %s, contract says %s" % [signal_name, actual, CONTRACT[signal_name]]
		).is_equal(CONTRACT[signal_name])
