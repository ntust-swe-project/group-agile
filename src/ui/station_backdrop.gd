## Static background of the side-view station (story 008): two layers drawn in
## order, a space layer (sky, stars, planet limb) and a hull layer (the station's
## outer plating behind the rooms). Nothing scrolls or animates: no Parallax2D,
## the depth comes from the layering alone. Everything is drawn in code, so
## there are no external assets.
class_name StationBackdrop
extends Control

const SPACE_COLOR := Color(0.03, 0.04, 0.09)
const STAR_COUNT := 180
const STAR_SEED := 8
const PLANET_COLOR := Color(0.07, 0.10, 0.17)
const PLANET_RIM_COLOR := Color(0.22, 0.32, 0.45)
const PLANET_CENTER := Vector2(960.0, 2500.0)
const PLANET_RADIUS := 1900.0
const HULL_COLOR := Color(0.16, 0.18, 0.22)
const HULL_EDGE_COLOR := Color(0.38, 0.42, 0.48)
const HULL_SEAM_COLOR := Color(0.11, 0.12, 0.15)
const HULL_SEAM_SPACING := 170.0

## Outline of the station body, set by the view from the room positions.
var hull_rect: Rect2 = Rect2()

var _stars: Array[Vector3] = []  # x, y, brightness


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rng := RandomNumberGenerator.new()
	rng.seed = STAR_SEED
	var area := get_viewport_rect().size
	for i in STAR_COUNT:
		_stars.append(Vector3(rng.randf_range(0.0, area.x), rng.randf_range(0.0, area.y), rng.randf_range(0.25, 0.9)))


func _draw() -> void:
	_draw_space_layer()
	_draw_hull_layer()


func _draw_space_layer() -> void:
	draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), SPACE_COLOR)
	for star in _stars:
		var star_size := 2.0 if star.z > 0.7 else 1.0
		draw_rect(Rect2(star.x, star.y, star_size, star_size), Color(1, 1, 1, star.z))
	draw_circle(PLANET_CENTER, PLANET_RADIUS, PLANET_COLOR)
	draw_arc(PLANET_CENTER, PLANET_RADIUS, 0.0, TAU, 256, PLANET_RIM_COLOR, 3.0)


func _draw_hull_layer() -> void:
	if hull_rect.size == Vector2.ZERO:
		return
	draw_rect(hull_rect, HULL_COLOR)
	var x := hull_rect.position.x + HULL_SEAM_SPACING
	while x < hull_rect.end.x:
		draw_line(Vector2(x, hull_rect.position.y), Vector2(x, hull_rect.end.y), HULL_SEAM_COLOR, 3.0)
		x += HULL_SEAM_SPACING
	draw_rect(hull_rect, HULL_EDGE_COLOR, false, 4.0)
