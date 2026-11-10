# Checks the integration skeleton: src/main.tscn is the project's main scene,
# loads, and has one child node per system named in EPIC.md (整合約定).
extends GdUnitTestSuite

const MAIN_SCENE_PATH := "res://src/main.tscn"

# System nodes under Main, in the order EPIC.md lists them.
const SYSTEM_NODES := [
	"DayCycle", "StationIntegrity", "Station", "Colonists",
	"TaskBoard", "CrisisDirector", "AutoRepair", "ResultScreen",
]


func test_main_scene_setting_points_to_main_tscn() -> void:
	# Arrange
	var key := "application/run/main_scene"

	# Act
	var value: String = ProjectSettings.get_setting(key, "")

	# Assert
	assert_str(value).is_equal(MAIN_SCENE_PATH)


func test_main_scene_instantiates_with_root_named_main() -> void:
	# Arrange
	var packed: PackedScene = load(MAIN_SCENE_PATH)

	# Act
	var main: Node = auto_free(packed.instantiate())

	# Assert
	assert_object(main).is_not_null()
	assert_str(String(main.name)).is_equal("Main")


func test_main_scene_has_one_node_per_system() -> void:
	# Arrange
	var main: Node = auto_free((load(MAIN_SCENE_PATH) as PackedScene).instantiate())

	# Act
	var names := []
	for child in main.get_children():
		names.append(String(child.name))

	# Assert
	assert_array(names).is_equal(SYSTEM_NODES)
