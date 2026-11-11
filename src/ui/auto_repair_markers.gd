## Display-only overlay that marks every room with an auto-repair module (story 005).
##
## Follows EPIC.md 房間狀態標示 (proposal #24): the text label AUTO is the primary
## cue; the outline is a thin DOUBLE solid line, distinct from the crisis
## outlines (BREACH thick solid, FAULT dashed), so it reads in grayscale. Colour
## (Okabe-Ito green) is secondary. Nothing flashes. The label sits above the
## room, right-aligned, clear of the room name, colonist dots, the priority panel
## and the top-left HUD area.
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
const LINE_WIDTH := 2.0
## Distances of the two thin outlines from the room edge (outside the crisis outline).
const OUTER_GAP := 23.0
const INNER_GAP := 18.0
## Space between the outer outline and the label plate.
const PLATE_GAP := 4.0

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
	var plate := Rect2(Vector2(room.end.x - plate_size.x, room.position.y - OUTER_GAP - PLATE_GAP - plate_size.y), plate_size)
	draw_rect(plate, PLATE_COLOR)
	draw_rect(plate, COLOR, false, 2.0)
	var baseline := Vector2(plate.position.x + LABEL_PADDING, plate.position.y + LABEL_PADDING + font.get_ascent(LABEL_FONT_SIZE))
	draw_string(font, baseline, LABEL_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE, Color.WHITE)
