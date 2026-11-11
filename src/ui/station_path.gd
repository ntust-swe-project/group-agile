## Display path of one hop between two rooms (story 008, view layer only).
##
## Pure and static, no scene needed. The room graph and [Mover] are untouched:
## the view asks this class where a colonist is drawn during a hop. A hop on one
## floor is a straight line along the floor. A hop between floors goes
## start -> stairs on the start floor -> up/down the stairs -> exit of the
## stairs -> destination, so a colonist never drifts diagonally through a wall.
## The stairs run from [code](stairs_x - half_run)[/code] on the upper floor down
## to [code](stairs_x + half_run)[/code] on the lower floor.
class_name StationPath
extends RefCounted

## Two feet positions closer than this in y are on the same floor.
const SAME_FLOOR_EPSILON := 1.0


## X of the stairs between two rooms: [param stairs_offset_x] right of the
## upper room's centre ([param a_center] / [param b_center] are room centres).
static func stairs_x(a_center: Vector2, b_center: Vector2, stairs_offset_x: float) -> float:
	var upper := a_center if a_center.y <= b_center.y else b_center
	return upper.x + stairs_offset_x


## Corner points of the walk from [param from] to [param to] (feet positions).
static func waypoints(from: Vector2, to: Vector2, stairs_x_pos: float, half_run: float) -> PackedVector2Array:
	if absf(from.y - to.y) < SAME_FLOOR_EPSILON:
		return PackedVector2Array([from, to])
	var from_is_upper := from.y < to.y
	var from_end_x := stairs_x_pos - half_run if from_is_upper else stairs_x_pos + half_run
	var to_end_x := stairs_x_pos + half_run if from_is_upper else stairs_x_pos - half_run
	return PackedVector2Array([from, Vector2(from_end_x, from.y), Vector2(to_end_x, to.y), to])


## Point at [param progress] (0.0-1.0, clamped) of the path's total length.
static func position_at(points: PackedVector2Array, progress: float) -> Vector2:
	var remaining := clampf(progress, 0.0, 1.0) * _length(points)
	for i in points.size() - 1:
		var segment := points[i].distance_to(points[i + 1])
		if remaining <= segment and segment > 0.0:
			return points[i].lerp(points[i + 1], remaining / segment)
		remaining -= segment
	return points[points.size() - 1]


## Horizontal facing (-1.0 left, 1.0 right) at [param progress]; 0.0 when the
## path has no horizontal movement there, so the caller keeps its last facing.
static func facing_at(points: PackedVector2Array, progress: float) -> float:
	var remaining := clampf(progress, 0.0, 1.0) * _length(points)
	for i in points.size() - 1:
		var segment := points[i].distance_to(points[i + 1])
		if segment > 0.0 and (remaining < segment or i == points.size() - 2):
			return signf(points[i + 1].x - points[i].x)
		remaining -= segment
	return 0.0


static func _length(points: PackedVector2Array) -> float:
	var total := 0.0
	for i in points.size() - 1:
		total += points[i].distance_to(points[i + 1])
	return total
