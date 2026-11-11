## Draws one colonist as a vector silhouette (story 008).
##
## The single place that turns "where, what status, which way" into pixels, so
## story 009 (prerendered 3D colonists) only has to replace [method draw]. Pure
## drawing: it reads no game state, only the arguments.
## - standing (IDLE): upright, legs together;
## - working (WORKING): upright, front arm raised;
## - walking (MOVING): legs and arms swing with [param walk_phase];
## - lying (RESTING, COLLAPSED): the body turned about 90 degrees on the floor.
class_name ColonistFigure
extends RefCounted

const FILL_COLOR := Color(0.93, 0.93, 0.93)
const OUTLINE_COLOR := Color.BLACK
const OUTLINE_GROW := 2.5
const HEAD_RADIUS := 9.0
const HEAD_Y := -60.0
const NECK_Y := -50.0
const HIP_Y := -26.0
const LEG_LENGTH := 26.0
const ARM_LENGTH := 20.0
const LIMB_WIDTH := 6.0
const TORSO_WIDTH := 14.0
## Swing of legs and arms while walking, radians.
const WALK_SWING := 0.5
## Half the body width: a lying body is lifted this much to rest on the floor.
const LYING_LIFT := 8.0
## Leg spread when not walking, radians.
const STANDING_SPREAD := 0.12
const LYING_ANGLE := PI / 2.0


## Height of the figure above the feet, for placing bars and labels.
static func height(kind: ColonistStatus.Kind) -> float:
	if _is_lying(kind):
		return LYING_LIFT * 2.0 + 4.0
	return -HEAD_Y + HEAD_RADIUS


## Draws a colonist with feet at [param feet] on [param canvas].
## [param facing] is -1.0 (left) or 1.0 (right); [param walk_phase] is in
## cycles and only used while MOVING.
static func draw(canvas: CanvasItem, feet: Vector2, kind: ColonistStatus.Kind, facing: float, walk_phase: float) -> void:
	var side := -1.0 if facing < 0.0 else 1.0
	var angle := 0.0
	var origin := feet
	if _is_lying(kind):
		# Turned towards the facing side, so the head points the way they faced.
		angle = LYING_ANGLE * side
		origin = feet + Vector2(0.0, -LYING_LIFT)
	canvas.draw_set_transform(origin, angle, Vector2(side, 1.0))
	# Standing and working: legs slightly apart. Walking: swing with the phase.
	var swing := STANDING_SPREAD
	if kind == ColonistStatus.Kind.MOVING:
		swing = sin(walk_phase * TAU) * WALK_SWING
	_draw_body(canvas, OUTLINE_COLOR, OUTLINE_GROW, kind, swing)
	_draw_body(canvas, FILL_COLOR, 0.0, kind, swing)
	canvas.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _is_lying(kind: ColonistStatus.Kind) -> bool:
	return kind == ColonistStatus.Kind.RESTING or kind == ColonistStatus.Kind.COLLAPSED


# [param grow] widens every part, so a black pass under the light pass is an
# outline. Lines are capped with circles at every joint and end, so the
# unfeathered draw_line strokes leave no gaps at the joints.
static func _draw_body(canvas: CanvasItem, color: Color, grow: float, kind: ColonistStatus.Kind, swing: float) -> void:
	var hip := Vector2(0.0, HIP_Y)
	var neck := Vector2(0.0, NECK_Y)
	var shoulder := Vector2(0.0, NECK_Y + 4.0)
	var limb_width := LIMB_WIDTH + grow * 2.0
	var torso_width := TORSO_WIDTH + grow * 2.0
	canvas.draw_circle(Vector2(0.0, HEAD_Y), HEAD_RADIUS + grow, color)
	_limb(canvas, neck, hip, torso_width, color)
	_limb(canvas, hip, hip + Vector2(sin(swing), cos(swing)) * LEG_LENGTH, limb_width, color)
	_limb(canvas, hip, hip + Vector2(sin(-swing), cos(-swing)) * LEG_LENGTH, limb_width, color)
	# Back arm swings with the legs, front arm against them; WORKING raises the front arm.
	_limb(canvas, shoulder, shoulder + Vector2(sin(-swing), cos(-swing)) * ARM_LENGTH, limb_width, color)
	var front := Vector2(sin(swing), cos(swing))
	if kind == ColonistStatus.Kind.WORKING:
		front = Vector2(0.9, -0.4).normalized()
	_limb(canvas, shoulder, shoulder + front * ARM_LENGTH, limb_width, color)


# One stroke with round ends.
static func _limb(canvas: CanvasItem, from: Vector2, to: Vector2, width: float, color: Color) -> void:
	canvas.draw_line(from, to, color, width)
	canvas.draw_circle(from, width / 2.0, color)
	canvas.draw_circle(to, width / 2.0, color)
