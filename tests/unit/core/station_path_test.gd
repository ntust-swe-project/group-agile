# Story 008 (production/epics/orbit-shift/story-008-side-view-station.md):
# display path of a hop. Pure functions, explicit numbers, no scene or file I/O.
extends GdUnitTestSuite

const STAIRS_X := 200.0
const HALF_RUN := 50.0
const UPPER_FEET := Vector2(100.0, 100.0)
const LOWER_FEET := Vector2(100.0, 300.0)
const SAMPLES := 20


func _up_points() -> PackedVector2Array:
	return StationPath.waypoints(LOWER_FEET, UPPER_FEET, STAIRS_X, HALF_RUN)


func _down_points() -> PackedVector2Array:
	return StationPath.waypoints(UPPER_FEET, LOWER_FEET, STAIRS_X, HALF_RUN)


func test_waypoints_same_floor_is_a_straight_line() -> void:
	var to := Vector2(500.0, 100.0)

	var points := StationPath.waypoints(UPPER_FEET, to, STAIRS_X, HALF_RUN)

	assert_array(points).is_equal([UPPER_FEET, to])


func test_waypoints_down_walks_to_stairs_then_down_then_to_target() -> void:
	var points := _down_points()

	assert_array(points).is_equal([
		UPPER_FEET, Vector2(150.0, 100.0), Vector2(250.0, 300.0), LOWER_FEET,
	])


func test_waypoints_up_walks_to_stairs_then_up_then_to_target() -> void:
	var points := _up_points()

	assert_array(points).is_equal([
		LOWER_FEET, Vector2(250.0, 300.0), Vector2(150.0, 100.0), UPPER_FEET,
	])


func test_waypoints_only_the_stairs_segment_changes_floor() -> void:
	for points: PackedVector2Array in [_down_points(), _up_points()]:
		var floor_changes := 0
		for i in points.size() - 1:
			if not is_equal_approx(points[i].y, points[i + 1].y):
				floor_changes += 1
				# That one segment is the stairs: it spans exactly the stairs run.
				assert_float(absf(points[i + 1].x - points[i].x)).is_equal(HALF_RUN * 2.0)
		assert_int(floor_changes).is_equal(1)


func test_position_at_endpoints_are_start_and_target() -> void:
	for points: PackedVector2Array in [_down_points(), _up_points()]:
		assert_vector(StationPath.position_at(points, 0.0)).is_equal(points[0])
		assert_vector(StationPath.position_at(points, 1.0)).is_equal(points[points.size() - 1])


func test_position_at_clamps_progress_outside_zero_to_one() -> void:
	var points := _down_points()

	assert_vector(StationPath.position_at(points, -0.5)).is_equal(UPPER_FEET)
	assert_vector(StationPath.position_at(points, 1.5)).is_equal(LOWER_FEET)


func test_position_at_same_floor_midpoint_stays_on_the_floor() -> void:
	var points := StationPath.waypoints(UPPER_FEET, Vector2(500.0, 100.0), STAIRS_X, HALF_RUN)

	assert_vector(StationPath.position_at(points, 0.5)).is_equal(Vector2(300.0, 100.0))


func test_position_at_never_leaves_the_path_segments() -> void:
	# Every sampled point lies on one of the path's segments: no diagonal drift.
	for points: PackedVector2Array in [_down_points(), _up_points()]:
		for step in SAMPLES + 1:
			var p := StationPath.position_at(points, float(step) / SAMPLES)
			var on_path := false
			for i in points.size() - 1:
				var closest := Geometry2D.get_closest_point_to_segment(p, points[i], points[i + 1])
				if closest.distance_to(p) < 0.001:
					on_path = true
			assert_bool(on_path).is_true()


func test_position_at_moves_monotonically_along_the_path() -> void:
	# Walked distance along the path never decreases as progress grows.
	var points := _down_points()
	var total := 0.0
	for i in points.size() - 1:
		total += points[i].distance_to(points[i + 1])
	var last_walked := -1.0
	for step in SAMPLES + 1:
		var p := StationPath.position_at(points, float(step) / SAMPLES)
		var walked := 0.0
		for i in points.size() - 1:
			var closest := Geometry2D.get_closest_point_to_segment(p, points[i], points[i + 1])
			if closest.distance_to(p) < 0.001:
				walked = maxf(walked, _length_to(points, i) + points[i].distance_to(closest))
		assert_float(walked).is_greater_equal(last_walked)
		last_walked = walked
	assert_float(last_walked).is_equal_approx(total, 0.001)


func test_stairs_x_is_right_of_the_upper_room_for_either_argument_order() -> void:
	var upper := Vector2(400.0, 100.0)
	var lower := Vector2(900.0, 300.0)

	assert_float(StationPath.stairs_x(upper, lower, 180.0)).is_equal(580.0)
	assert_float(StationPath.stairs_x(lower, upper, 180.0)).is_equal(580.0)


func test_facing_at_follows_the_walk_direction() -> void:
	var points := _down_points()

	# Down: walk right on the floor, right down the stairs. Up: left up the stairs.
	assert_float(StationPath.facing_at(points, 0.0)).is_equal(1.0)
	assert_float(StationPath.facing_at(points, 0.5)).is_equal(1.0)
	assert_float(StationPath.facing_at(_up_points(), 0.5)).is_equal(-1.0)


# Length of the path from its first point to point [param index].
func _length_to(points: PackedVector2Array, index: int) -> float:
	var length := 0.0
	for i in index:
		length += points[i].distance_to(points[i + 1])
	return length
