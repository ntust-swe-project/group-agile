## Display-only overlay that marks every room with an auto-repair module (story 005).
##
## Follows EPIC.md 房間狀態標示 (proposal #24): the text label AUTO is the primary
## cue; the outline is a thin DOUBLE solid line, distinct from the crisis
## outlines (BREACH thick solid, FAULT dashed), so it reads in grayscale. Colour
## (Okabe-Ito green) is secondary. Nothing flashes.
##
## Side view layout (story 008 stacks two floors only [constant FLOOR_GAP] px
## apart), so nothing may be drawn far outside a room:
## - the double outline hugs the room edge, inside its own half of the floor gap;
## - the AUTO plate sits inside the room, top centre, at the same top margin as
##   the crisis plates: right of the room name, left of the BREACH / FAULT plates
##   (which stack down from the top-right corner), well above the colonists.
##
## PLACEHOLDER like crisis_markers.gd: story 008 may restyle it. It only reads
## `auto_repair.modules` and `auto_repair.map`.
extends Control

const ROOM_SIZE: Vector2 = preload("res://src/ui/station_view.gd").ROOM_SIZE
const LABEL_TEXT := "AUTO"
const LABEL_FONT_SIZE := 24
const COLOR := Color("#009E73")
const PLATE_COLOR := Color(0.0, 0.0, 0.0, 0.85)
const LABEL_PADDING := 4.0
const LINE_WIDTH := 1.5
## Vertical space between the two floors; the outlines of two stacked rooms
## must both fit in it, so each stays within half of it.
const FLOOR_GAP := 10.0
## Distances of the two thin outlines from the room edge. Both stay inside
## half of [constant FLOOR_GAP], and clear of the room's own 3 px border.
const INNER_GAP := 2.5
const OUTER_GAP := 4.5
## Top margin of the plate: the same as the crisis plates, so the labels line up.
const PLATE_TOP_MARGIN := 36.0

## The AutoRepair node to read; set by it.
var auto_repair: Node


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if auto_repair == null or auto_repair.map == null:
		return
	var map: StationMap = auto_repair.map
	for room_id: StringName in auto_repair.modules:
		var pos: Array = map.get_room(room_id)["pos"]
		var rect := Rect2(Vector2(pos[0], pos[1]) - ROOM_SIZE / 2.0, ROOM_SIZE)
		draw_rect(rect.grow(INNER_GAP), COLOR, false, LINE_WIDTH)
		draw_rect(rect.grow(OUTER_GAP), COLOR, false, LINE_WIDTH)
		_draw_label(rect)


func _draw_label(room: Rect2) -> void:
	var font := ThemeDB.fallback_font
	var text_size := font.get_string_size(LABEL_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE)
	var plate_size := Vector2(text_size.x + LABEL_PADDING * 2.0, font.get_height(LABEL_FONT_SIZE) + LABEL_PADDING * 2.0)
	var plate := Rect2(Vector2(room.get_center().x - plate_size.x / 2.0, room.position.y + PLATE_TOP_MARGIN), plate_size)
	draw_rect(plate, PLATE_COLOR)
	draw_rect(plate, COLOR, false, 2.0)
	var baseline := Vector2(plate.position.x + LABEL_PADDING, plate.position.y + LABEL_PADDING + font.get_ascent(LABEL_FONT_SIZE))
	draw_string(font, baseline, LABEL_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, Color.WHITE)
