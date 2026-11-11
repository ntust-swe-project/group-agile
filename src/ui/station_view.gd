## Read-only view of the station (story 002, 007): rooms as colored blocks with
## labels, connection lines, and every colonist as a dot with a fatigue bar and
## a status symbol, plus one text row per colonist (status, room, fatigue).
extends Control

const ROOM_SIZE := Vector2(180, 100)
const DOT_RADIUS := 9.0
## Room names and colonist status text (story 007: at least 24 px).
const FONT_SIZE := 24
const DOT_FONT_SIZE := 14
## Colonist text rows sit at the bottom of the screen, last row this far up.
const STATUS_BOTTOM_MARGIN := 24.0
const STATUS_LINE_HEIGHT := 32.0
## Colonist dots sit below the room centre, clear of the crisis label (story 004).
const DOT_OFFSET_Y := 40.0
## Outline width of the status symbol, so white stays readable on grey rooms.
const SYMBOL_OUTLINE_SIZE := 6
## Fatigue bar over the dot. Neutral grey/white on purpose: the crisis colours
## (orange, blue) belong to the room markers.
const BAR_SIZE := Vector2(40, 6)
const BAR_GAP := 8.0
const BAR_BACK_COLOR := Color(0.15, 0.15, 0.15)
const BAR_FILL_COLOR := Color(0.9, 0.9, 0.9)
const BAR_BORDER_COLOR := Color.BLACK

## Room graph to draw; set by Station.
var map: StationMap
## The Colonists node to read; set by Station once injected.
var colonists: Node

# Colonists are drawn on this child, one z level up, so the crisis markers
# (story 004, drawn later in the tree) never cover a colonist's status.
var _colonist_layer: Control


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	for pair: Array in map.connections:
		draw_line(_center(pair[0]), _center(pair[1]), Color.GRAY, 4.0)
	for id in map.room_ids:
		var room := map.get_room(id)
		var top_left := _center(id) - ROOM_SIZE / 2.0
		draw_rect(Rect2(top_left, ROOM_SIZE), Color(room["color"]))
		draw_string(font, top_left + Vector2(8, 22), room["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color.BLACK)
	if colonists == null:
		return
	# Text rows stay on this base layer; only the dots go above the crisis markers.
	for i in colonists.colonists.size():
		draw_string(font, Vector2(20, _status_row_y(i)), _status_line(colonists.colonists[i]), HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color.WHITE)


func _draw_colonists() -> void:
	if map == null or colonists == null:
		return
	var font := ThemeDB.fallback_font
	for i in colonists.colonists.size():
		var colonist: Colonist = colonists.colonists[i]
		_draw_colonist(_colonist_layer, font, i, colonist)


func _draw_colonist(canvas: CanvasItem, font: Font, index: int, colonist: Colonist) -> void:
	var mover := colonist.mover
	var pos := _center(mover.room_id)
	if mover.is_moving():
		pos = pos.lerp(_center(mover.next_room()), mover.hop_progress())
	pos += Vector2(-50 + index * 50, DOT_OFFSET_Y)
	var status := ColonistStatus.of(colonist)
	canvas.draw_circle(pos, DOT_RADIUS, Color.WHITE)
	canvas.draw_string(font, pos + Vector2(-8, 5), colonist.display_name.left(1), HORIZONTAL_ALIGNMENT_LEFT, -1, DOT_FONT_SIZE, Color.BLACK)
	# Black outline under the white symbol: readable on grey rooms and dark corridors alike.
	var symbol_pos := pos + Vector2(DOT_RADIUS + 2, 8)
	var symbol := ColonistStatus.symbol(status)
	canvas.draw_string_outline(font, symbol_pos, symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, SYMBOL_OUTLINE_SIZE, Color.BLACK)
	canvas.draw_string(font, symbol_pos, symbol, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color.WHITE)
	_draw_fatigue_bar(canvas, pos + Vector2(-BAR_SIZE.x / 2.0, -DOT_RADIUS - BAR_GAP - BAR_SIZE.y), ColonistStatus.fatigue_ratio(colonist))


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


func _center(room_id: StringName) -> Vector2:
	var pos: Array = map.get_room(room_id)["pos"]
	return Vector2(pos[0], pos[1])
