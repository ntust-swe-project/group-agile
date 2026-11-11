## Read-only side-view cross-section of the station (story 002, 007, 008): two
## floors of rooms cut away so the inside shows, same-floor doorways, stairs
## between floors, and every colonist as a silhouette with a fatigue bar and a
## status symbol, plus one text row per colonist (status, room, fatigue).
##
## Room positions come from the data file; ids and connections are not touched.
## A hop between floors is drawn along [StationPath] waypoints (view only).
extends Control

## Size of a room cutaway; a room's `pos` is its centre.
const ROOM_SIZE := Vector2(500, 230)
## Room names and colonist status text (story 007: at least 24 px).
const FONT_SIZE := 24
const INITIAL_FONT_SIZE := 16
## Name sits this far from the room's top-left corner, inside the crisis outlines.
const ROOM_NAME_OFFSET := Vector2(32, 40)
## Colonist text rows sit at the bottom of the screen, last row this far up.
const STATUS_BOTTOM_MARGIN := 24.0
const STATUS_LINE_HEIGHT := 32.0
## Floor slab at the bottom of every room.
const FLOOR_THICKNESS := 8.0
## Doorway between two rooms on one floor.
const DOOR_HEIGHT := 90.0
## Feet of a colonist stand on the floor, relative to the room centre.
const FEET_OFFSET_Y := ROOM_SIZE.y / 2.0 - FLOOR_THICKNESS
## Colonists in one room are spread along the floor, this far apart.
const COLONIST_SPACING := 90.0
## Stairs: x right of the upper room's centre, and half their horizontal run.
const STAIRS_OFFSET_X := 180.0
const STAIRS_HALF_RUN := 50.0
const STAIRS_STEPS := 6
## Leg swing cycles per hop; slow enough to read as walking, not flicker.
const WALK_CYCLES_PER_HOP := 2.0
const HULL_MARGIN := 30.0
## Outline width of the status symbol and room names, so white stays readable.
const SYMBOL_OUTLINE_SIZE := 6
## Fatigue bar over the colonist. Neutral grey/white on purpose: the crisis
## colours (orange, blue) belong to the room markers.
const BAR_SIZE := Vector2(40, 6)
const BAR_GAP := 8.0
const BAR_BACK_COLOR := Color(0.15, 0.15, 0.15)
const BAR_FILL_COLOR := Color(0.9, 0.9, 0.9)
const BAR_BORDER_COLOR := Color.BLACK
const FLOOR_COLOR := Color(0.62, 0.62, 0.62)
const STAIRS_COLOR := Color(0.85, 0.85, 0.85)
const STAIRS_OUTLINE_COLOR := Color.BLACK
const STAIRS_WIDTH := 5.0
## Opening through the slab at the top of the stairs; it runs this far into the
## lower room so the room outline is visibly cut too.
const STAIRWELL_WIDTH := 48.0
const STAIRWELL_OVERLAP := 6.0
const STAIRWELL_COLOR := Color(0.06, 0.06, 0.08)
const ROOM_DARKEN := 0.55

## Room graph to draw; set by Station.
var map: StationMap:
	set(value):
		map = value
		_update_backdrop()
## The Colonists node to read; set by Station once injected.
var colonists: Node

# Static background, drawn behind this node.
var _backdrop: StationBackdrop
# Colonists are drawn on this child, one z level up, so the crisis markers
# (story 004, drawn later in the tree) never cover a colonist's status.
var _colonist_layer: Control
# Last horizontal facing per colonist index, kept while standing still.
var _facing: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop = StationBackdrop.new()
	_backdrop.show_behind_parent = true
	_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_backdrop)
	_update_backdrop()
	_colonist_layer = Control.new()
	_colonist_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_colonist_layer.z_index = 1
	_colonist_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_colonist_layer.draw.connect(_draw_colonists)
	add_child(_colonist_layer)


func _process(_delta: float) -> void:
	queue_redraw()
	_colonist_layer.queue_redraw()


func _draw() -> void:
	if map == null:
		return
	var font := ThemeDB.fallback_font
	# Doorways under the rooms; stairs over them, so the slab opening and steps show.
	for pair: Array in map.connections:
		if _same_floor(pair[0], pair[1]):
			_draw_doorway(pair[0], pair[1])
	for id in map.room_ids:
		_draw_room(font, id)
	for pair: Array in map.connections:
		if not _same_floor(pair[0], pair[1]):
			_draw_stairs(pair[0], pair[1])
	if colonists == null:
		return
	# Text rows stay on this base layer; only the colonists go above the crisis markers.
	for i in colonists.colonists.size():
		draw_string(font, Vector2(20, _status_row_y(i)), _status_line(colonists.colonists[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color.WHITE)


func _draw_room(font: Font, id: StringName) -> void:
	var room := map.get_room(id)
	var rect := Rect2(_center(id) - ROOM_SIZE / 2.0, ROOM_SIZE)
	var base := Color(room["color"])
	draw_rect(rect, base.darkened(ROOM_DARKEN))
	draw_rect(Rect2(rect.position.x, rect.end.y - FLOOR_THICKNESS, rect.size.x, FLOOR_THICKNESS), FLOOR_COLOR)
	draw_rect(rect, base, false, 3.0)
	var name_pos := rect.position + ROOM_NAME_OFFSET
	draw_string_outline(font, name_pos, room["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, SYMBOL_OUTLINE_SIZE, Color.BLACK)
	draw_string(font, name_pos, room["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color.WHITE)


func _same_floor(a: StringName, b: StringName) -> bool:
	return absf(_center(a).y - _center(b).y) < StationPath.SAME_FLOOR_EPSILON


# Doorway through the wall between two rooms on one floor.
func _draw_doorway(a: StringName, b: StringName) -> void:
	var ca := _center(a)
	var cb := _center(b)
	var left := ca if ca.x < cb.x else cb
	var floor_y := left.y + ROOM_SIZE.y / 2.0 - FLOOR_THICKNESS
	var rect := Rect2(left.x + ROOM_SIZE.x / 2.0, floor_y - DOOR_HEIGHT, absf(ca.x - cb.x) - ROOM_SIZE.x, DOOR_HEIGHT + FLOOR_THICKNESS)
	draw_rect(rect, Color(map.get_room(a)["color"]).darkened(ROOM_DARKEN))
	draw_rect(Rect2(rect.position.x, floor_y, rect.size.x, FLOOR_THICKNESS), FLOOR_COLOR)


# Stairwell between floors: an opening cut through the slab (and both room
# outlines), then steps from the upper floor down to the lower one. The steps
# are a light line over a dark one, so they read on any room fill.
func _draw_stairs(a: StringName, b: StringName) -> void:
	var ca := _center(a)
	var cb := _center(b)
	var upper := ca if ca.y < cb.y else cb
	var lower := cb if ca.y < cb.y else ca
	var sx := StationPath.stairs_x(ca, cb, STAIRS_OFFSET_X)
	var top := Vector2(sx - STAIRS_HALF_RUN, upper.y + FEET_OFFSET_Y)
	var bottom := Vector2(sx + STAIRS_HALF_RUN, lower.y + FEET_OFFSET_Y)
	var hole_top := top.y
	var hole_bottom := lower.y - ROOM_SIZE.y / 2.0 + STAIRWELL_OVERLAP
	var hole := Rect2(top.x - STAIRWELL_WIDTH / 2.0, hole_top, STAIRWELL_WIDTH, hole_bottom - hole_top)
	draw_rect(hole, STAIRWELL_COLOR)
	draw_line(hole.position, Vector2(hole.position.x, hole.end.y), FLOOR_COLOR, 2.0)
	draw_line(Vector2(hole.end.x, hole.position.y), hole.end, FLOOR_COLOR, 2.0)
	var steps := PackedVector2Array([top])
	for k in range(1, STAIRS_STEPS + 1):
		var corner := top.lerp(bottom, float(k) / STAIRS_STEPS)
		steps.append(Vector2(steps[steps.size() - 1].x, corner.y))
		steps.append(corner)
	draw_polyline(steps, STAIRS_OUTLINE_COLOR, STAIRS_WIDTH + 4.0)
	draw_polyline(steps, STAIRS_COLOR, STAIRS_WIDTH)


func _draw_colonists() -> void:
	if map == null or colonists == null:
		return
	var font := ThemeDB.fallback_font
	for i in colonists.colonists.size():
		_draw_colonist(_colonist_layer, font, i, colonists.colonists[i])


func _draw_colonist(canvas: CanvasItem, font: Font, index: int, colonist: Colonist) -> void:
	var mover := colonist.mover
	var slot := Vector2(-COLONIST_SPACING + index * COLONIST_SPACING, FEET_OFFSET_Y)
	var feet := _center(mover.room_id) + slot
	var phase := 0.0
	if mover.is_moving():
		var to_center := _center(mover.next_room())
		var points := StationPath.waypoints(feet, to_center + slot, StationPath.stairs_x(_center(mover.room_id), to_center, STAIRS_OFFSET_X), STAIRS_HALF_RUN)
		var progress := mover.hop_progress()
		feet = StationPath.position_at(points, progress)
		var facing := StationPath.facing_at(points, progress)
		if facing != 0.0:
			_facing[index] = facing
		phase = progress * WALK_CYCLES_PER_HOP
	var status := ColonistStatus.of(colonist)
	ColonistFigure.draw(canvas, feet, status, _facing.get(index, 1.0), phase)
	# Fatigue bar above the figure; initial on its left, status symbol on its right.
	var bar_top_left := feet + Vector2(-BAR_SIZE.x / 2.0, -ColonistFigure.height(status) - BAR_GAP - BAR_SIZE.y)
	_draw_fatigue_bar(canvas, bar_top_left, ColonistStatus.fatigue_ratio(colonist))
	var mid_y := bar_top_left.y + BAR_SIZE.y / 2.0
	var initial_pos := Vector2(bar_top_left.x - 16.0, mid_y + 6.0)
	var initial := colonist.display_name.left(1)
	canvas.draw_string_outline(font, initial_pos, initial, HORIZONTAL_ALIGNMENT_LEFT, -1, INITIAL_FONT_SIZE, 4, Color.BLACK)
	canvas.draw_string(font, initial_pos, initial, HORIZONTAL_ALIGNMENT_LEFT, -1, INITIAL_FONT_SIZE, Color.WHITE)
	# Black outline under the white symbol: readable on every room colour.
	var symbol_pos := Vector2(bar_top_left.x + BAR_SIZE.x + 6.0, mid_y + 8.0)
	var symbol := ColonistStatus.symbol(status)
	canvas.draw_string_outline(font, symbol_pos, symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, SYMBOL_OUTLINE_SIZE, Color.BLACK)
	canvas.draw_string(font, symbol_pos, symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color.WHITE)


# One bottom-left text row: name, status, room (or "from > to"), fatigue.
func _status_line(colonist: Colonist) -> String:
	var mover := colonist.mover
	var place := map.get_room(mover.room_id)["name"] as String
	if mover.is_moving():
		place = "%s > %s" % [place, map.get_room(mover.next_room())["name"]]
	return "%s  %s  %s  %d/%d" % [
		colonist.display_name, ColonistStatus.label(ColonistStatus.of(colonist)), place,
		colonist.fatigue, colonist.fatigue_max,
	]


# Fatigue bar: dark slot with a light fill, [param ratio] (0-1) of the width.
func _draw_fatigue_bar(canvas: CanvasItem, top_left: Vector2, ratio: float) -> void:
	canvas.draw_rect(Rect2(top_left, BAR_SIZE).grow(1.0), BAR_BORDER_COLOR)
	canvas.draw_rect(Rect2(top_left, BAR_SIZE), BAR_BACK_COLOR)
	canvas.draw_rect(Rect2(top_left, Vector2(BAR_SIZE.x * ratio, BAR_SIZE.y)), BAR_FILL_COLOR)


# Baseline y of colonist [param index]'s text row, stacked up from the screen bottom.
func _status_row_y(index: int) -> float:
	var rows: int = colonists.colonists.size()
	return get_viewport_rect().size.y - STATUS_BOTTOM_MARGIN - (rows - 1 - index) * STATUS_LINE_HEIGHT


# Hull outline around all rooms; called when the map arrives.
func _update_backdrop() -> void:
	if _backdrop == null or map == null:
		return
	var bounds := Rect2(_center(map.room_ids[0]) - ROOM_SIZE / 2.0, ROOM_SIZE)
	for id in map.room_ids:
		bounds = bounds.merge(Rect2(_center(id) - ROOM_SIZE / 2.0, ROOM_SIZE))
	_backdrop.hull_rect = bounds.grow(HULL_MARGIN)
	_backdrop.queue_redraw()


func _center(room_id: StringName) -> Vector2:
	var pos: Array = map.get_room(room_id)["pos"]
	return Vector2(pos[0], pos[1])
