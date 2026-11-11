## Read-only view of the station (story 002): rooms as colored blocks with
## labels, connection lines, and every colonist's room and fatigue as text.
extends Control

const ROOM_SIZE := Vector2(180, 100)
const DOT_RADIUS := 9.0
const FONT_SIZE := 16

## Room graph to draw; set by Station.
var map: StationMap
## The Colonists node to read; set by Station once injected.
var colonists: Node


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	queue_redraw()


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
	for i in colonists.colonists.size():
		var colonist: Colonist = colonists.colonists[i]
		_draw_colonist(font, i, colonist)


func _draw_colonist(font: Font, index: int, colonist: Colonist) -> void:
	var mover := colonist.mover
	var pos := _center(mover.room_id)
	var status := map.get_room(mover.room_id)["name"] as String
	if mover.is_moving():
		pos = pos.lerp(_center(mover.next_room()), mover.hop_progress())
		status = "%s -> %s" % [status, map.get_room(mover.next_room())["name"]]
	pos += Vector2(-50 + index * 50, 30)
	draw_circle(pos, DOT_RADIUS, Color.WHITE)
	draw_string(font, pos + Vector2(-8, 5), colonist.display_name.left(1), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.BLACK)
	var line := "%s  %s  fatigue %d/%d  %s" % [
		colonist.display_name, status, colonist.fatigue, colonist.fatigue_max,
		Colonist.State.keys()[colonist.state],
	]
	draw_string(font, Vector2(20, 560 + index * 24), line, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, Color.WHITE)


func _center(room_id: StringName) -> Vector2:
	var pos: Array = map.get_room(room_id)["pos"]
	return Vector2(pos[0], pos[1])
