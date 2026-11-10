# Checks Main's _ready() dependency injection (EPIC.md 整合約定: "由 Main 在
# _ready() 注入參考"). Stubs stand in for system scripts, so these tests keep
# checking Main's wiring alone after stories attach real scripts.
extends GdUnitTestSuite

const MAIN_SCENE_PATH := "res://src/main.tscn"
const MAIN_SCRIPT_PATH := "res://src/main.gd"
const MAIN_SCRIPT := preload("res://src/main.gd")


func _instantiate_main() -> Node:
	return auto_free((load(MAIN_SCENE_PATH) as PackedScene).instantiate())


# Main with every system script removed, as on the bare skeleton. Stories attach
# real scripts to these nodes; removing them before the scene enters the tree
# keeps their _ready() (timers, signals, data files) out of these tests.
func _instantiate_bare_main() -> Node:
	var main := _instantiate_main()
	for child in main.get_children():
		child.set_script(null)
	return main


func _stub_with_property(property_name: String) -> GDScript:
	var stub := GDScript.new()
	stub.source_code = "extends Node\nvar %s: Node\n" % property_name
	stub.reload()
	return stub


func test_main_root_has_main_script_attached() -> void:
	# Arrange
	var main := _instantiate_main()

	# Act
	var script: Script = main.get_script()

	# Assert
	assert_object(script).is_not_null()
	assert_str(script.resource_path).is_equal(MAIN_SCRIPT_PATH)


func test_injections_rows_name_existing_main_children() -> void:
	# Arrange — a typo in INJECTIONS is skipped silently at runtime, so catch it here
	var main := _instantiate_main()

	for row in MAIN_SCRIPT.INJECTIONS:
		# Act
		var target := main.get_node_or_null(row[0])
		var source := main.get_node_or_null(row[2])

		# Assert
		assert_object(target).override_failure_message(
			"INJECTIONS target %s is not a child of Main" % row[0]
		).is_not_null()
		assert_object(source).override_failure_message(
			"INJECTIONS source %s is not a child of Main" % row[2]
		).is_not_null()


func test_ready_on_bare_skeleton_completes_without_injecting() -> void:
	# Arrange
	var main := _instantiate_bare_main()
	var director := main.get_node("CrisisDirector")

	# Act — entering the tree runs _ready(); must not fail on script-less nodes
	add_child(main)

	# Assert
	assert_bool(main.is_node_ready()).is_true()
	assert_bool("station_integrity" in director).is_false()


func test_ready_injects_station_integrity_into_crisis_director() -> void:
	# Arrange
	var main := _instantiate_bare_main()
	var director := main.get_node("CrisisDirector")
	director.set_script(_stub_with_property("station_integrity"))

	# Act
	add_child(main)

	# Assert
	assert_object(director.get("station_integrity")).is_same(main.get_node("StationIntegrity"))


func test_inject_dependencies_skips_target_without_the_property() -> void:
	# Arrange
	var main := _instantiate_bare_main()
	var director := main.get_node("CrisisDirector")
	director.set_script(_stub_with_property("unrelated"))

	# Act
	main.inject_dependencies()

	# Assert
	assert_bool("station_integrity" in director).is_false()
	assert_object(director.get("unrelated")).is_null()
