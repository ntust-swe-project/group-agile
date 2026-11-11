## Display-only overlay that marks every active crisis on its room (story 004,
## side-view art by story 008).
##
## Added as a child by the CrisisDirector node; it only reads
## `director.active_crises` and `director.station.map` and never changes game
## state. Follows the PO ruling for proposal #24:
## - kind is shown as text (BREACH / FAULT) and as outline style (solid thick vs
##   dashed), so the two stay distinguishable in grayscale;
## - colour is only a secondary cue (colour-blind-safe Okabe-Ito orange / blue);
## - nothing flashes or animates;
## - the label is 24 px and keeps clear of the top-left HUD area (x < 400, y < 140).
## Side view layout: the outline hugs the inside of the room's cutaway (one more
## ring per extra crisis), and the label plates stack downward in the room's
## top-right corner, above the colonist row on the floor, so two crises in one
## room overlap neither each other nor the colonists.
extends Control

const ROOM_SIZE: Vector2 = preload("res://src/ui/station_view.gd").ROOM_SIZE
const LABEL_FONT_SIZE := 24
## Label text per crisis kind. Text is the primary cue.
const LABELS := {
	CrisisKind.BREACH: "BREACH",
	CrisisKind.MALFUNCTION: "FAULT",
}
## Secondary colour cue (Okabe-Ito): breach orange, malfunction blue.
const COLORS := {
	CrisisKind.BREACH: Color("#E69F00"),
	CrisisKind.MALFUNCTION: Color("#0072B2"),
}
## Breach: one solid thick outline.
const BREACH_OUTLINE_WIDTH := 8.0
## Malfunction: thinner dashed outline.
const MALFUNCTION_OUTLINE_WIDTH := 5.0
const DASH_LENGTH := 12.0
## Outline ring k sits this far inside the room edge (centre line of the stroke).
const OUTLINE_INSET := 6.0
## Plates start this far from the room's top and right edges, clear of the outline rings.
const PLATE_MARGIN := Vector2(36.0, 36.0)
const LABEL_PADDING := 4.0
const LABEL_STACK_SPACING := 4.0
const PLATE_COLOR := Color(0.0, 0.0, 0.0, 0.85)

## The CrisisDirector to read; set by the director.
var director: Node


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if director == null or director.active_crises.is_empty():
		return
	# Station builds its map in its own _ready and is injected later: read lazily.
	var station: Node = director.station
	if station == null or not "map" in station or station.map == null:
		return
	var map: StationMap = station.map
	var shown_in_room := {}
	var ids: Array = director.active_crises.keys()
	ids.sort()
	for id: int in ids:
		var crisis: Crisis = director.active_crises[id]
		if not map.has_room(crisis.room_id):
			continue
		var slot: int = shown_in_room.get(crisis.room_id, 0)
		shown_in_room[crisis.room_id] = slot + 1
		_draw_marker(_room_center(map, crisis.room_id), crisis.kind, slot)


func _draw_marker(center: Vector2, kind: StringName, slot: int) -> void:
	var color: Color = COLORS.get(kind, Color.WHITE)
	var width := MALFUNCTION_OUTLINE_WIDTH if kind == CrisisKind.MALFUNCTION else BREACH_OUTLINE_WIDTH
	# Several crises in one room get nested outlines, each ring inside the last.
	var inset := OUTLINE_INSET + slot * (BREACH_OUTLINE_WIDTH + OUTLINE_INSET)
	var rect := Rect2(center - ROOM_SIZE / 2.0, ROOM_SIZE).grow(-inset)
	if kind == CrisisKind.MALFUNCTION:
		_draw_dashed_rect(rect, color, width)
	else:
		draw_rect(rect, color, false, width)
	_draw_label(center, kind, slot, color)


# Plate [param slot] counts down from the room's top-right corner.
func _draw_label(center: Vector2, kind: StringName, slot: int, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var text: String = LABELS.get(kind, "?")
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE)
	var plate_size := Vector2(text_size.x + LABEL_PADDING * 2.0, font.get_height(LABEL_FONT_SIZE) + LABEL_PADDING * 2.0)
	var room_top_right := center + Vector2(ROOM_SIZE.x / 2.0, -ROOM_SIZE.y / 2.0)
	var plate := Rect2(
		Vector2(room_top_right.x - PLATE_MARGIN.x - plate_size.x, room_top_right.y + PLATE_MARGIN.y + slot * (plate_size.y + LABEL_STACK_SPACING)),
		plate_size,
	)
	draw_rect(plate, PLATE_COLOR)
	draw_rect(plate, color, false, 2.0)
	draw_string(font, Vector2(plate.position.x + LABEL_PADDING, plate.position.y + LABEL_PADDING + font.get_ascent(LABEL_FONT_SIZE)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, Color.WHITE)


func _draw_dashed_rect(rect: Rect2, color: Color, width: float) -> void:
	var top_left := rect.position
	var top_right := Vector2(rect.end.x, rect.position.y)
	var bottom_right := rect.end
	var bottom_left := Vector2(rect.position.x, rect.end.y)
	draw_dashed_line(top_left, top_right, color, width, DASH_LENGTH)
	draw_dashed_line(top_right, bottom_right, color, width, DASH_LENGTH)
	draw_dashed_line(bottom_right, bottom_left, color, width, DASH_LENGTH)
	draw_dashed_line(bottom_left, top_left, color, width, DASH_LENGTH)


func _room_center(map: StationMap, room_id: StringName) -> Vector2:
	var pos: Array = map.get_room(room_id)["pos"]
	return Vector2(pos[0], pos[1])
