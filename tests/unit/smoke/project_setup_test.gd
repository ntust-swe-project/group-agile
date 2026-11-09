# Smoke test for the repo skeleton: proves gdUnit4 runs headless and that the
# project is the one CI thinks it is (name and pinned engine version).
extends GdUnitTestSuite


func test_project_name_is_group_agile() -> void:
	# Arrange
	var key := "application/config/name"

	# Act
	var project_name: String = ProjectSettings.get_setting(key)

	# Assert
	assert_str(project_name).is_equal("group-agile")


func test_engine_version_matches_pinned_4_7_2() -> void:
	# Arrange — the pin from project-common docs/VISION.md section 10
	var pinned := {"major": 4, "minor": 7, "patch": 2}

	# Act
	var info := Engine.get_version_info()

	# Assert
	assert_int(info["major"]).is_equal(pinned["major"])
	assert_int(info["minor"]).is_equal(pinned["minor"])
	assert_int(info["patch"]).is_equal(pinned["patch"])
