# Checks CrisisKind against the `kind` values in EPIC.md (整合約定).
extends GdUnitTestSuite


func test_crisis_kind_constants_match_contract_values() -> void:
	# Arrange
	var expected := [&"breach", &"malfunction"]

	# Act
	var actual := [CrisisKind.BREACH, CrisisKind.MALFUNCTION]

	# Assert — StringName, not String, so `==` against signal args is exact
	assert_array(actual).is_equal(expected)
	assert_int(typeof(CrisisKind.BREACH)).is_equal(TYPE_STRING_NAME)


func test_crisis_kind_all_lists_every_kind_in_order() -> void:
	# Arrange
	var expected := [CrisisKind.BREACH, CrisisKind.MALFUNCTION]

	# Act
	var all: Array = CrisisKind.ALL

	# Assert
	assert_array(all).is_equal(expected)
