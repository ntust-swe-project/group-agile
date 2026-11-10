# Checks Main's _ready() dependency injection (EPIC.md 整合約定: "由 Main 在
# _ready() 注入參考"). Stubs stand in for system scripts not written yet.
extends GdUnitTestSuite

const MAIN_SCENE_PATH := "res://src/main.tscn"
const MAIN_SCRIPT_PATH := "res://src/main.gd"


func _instantiate_main() -> Node:
	return auto_free((load(MAIN_SCENE_PATH) as PackedScene).instantiate())


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


func test_ready_on_bare_skeleton_leaves_system_nodes_untouched() -> void:
	# Arrange
	var main := _instantiate_main()

	# Act — entering the tree runs _ready(); must not error on script-less nodes
	add_child(main)

	# Assert
	for child in main.get_children():
		assert_object(child.get_script()).is_null()


func test_ready_injects_station_integrity_into_crisis_director() -> void:
	# Arrange
	var main := _instantiate_main()
	var director := main.get_node("CrisisDirector")
	director.set_script(_stub_with_property("station_integrity"))

	# Act
	add_child(main)

	# Assert
	assert_object(director.get("station_integrity")).is_same(main.get_node("StationIntegrity"))


func test_inject_dependencies_skips_target_without_the_property() -> void:
	# Arrange
	var main := _instantiate_main()
	var director := main.get_node("CrisisDirector")
	director.set_script(_stub_with_property("unrelated"))

	# Act
	main.inject_dependencies()

	# Assert
	assert_bool("station_integrity" in director).is_false()
	assert_object(director.get("unrelated")).is_null()
