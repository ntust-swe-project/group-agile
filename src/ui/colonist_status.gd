## The one place that decides what a colonist is doing, for display (story 007).
##
## Pure and static, no scene needed, so the station view, the priority panel and
## story 009 (animations) all show the same state. Reads [Colonist] only.
## Priority: collapsed > moving > working / resting / idle (by [member Colonist.state]).
## Every state has a text label and a one-character symbol, so it can be told
## apart without colour. The symbols are plain ASCII on purpose: the built-in
## default font has no glyph for arrow characters.
class_name ColonistStatus
extends RefCounted

enum Kind { MOVING, WORKING, RESTING, IDLE, COLLAPSED }

## Text label per [enum Kind].
const LABELS := {
	Kind.MOVING: "MOVING",
	Kind.WORKING: "WORKING",
	Kind.RESTING: "RESTING",
	Kind.IDLE: "IDLE",
	Kind.COLLAPSED: "COLLAPSED",
}
## One-character symbol per [enum Kind].
const SYMBOLS := {
	Kind.MOVING: ">",
	Kind.WORKING: "W",
	Kind.RESTING: "Z",
	Kind.IDLE: "-",
	Kind.COLLAPSED: "!",
}


## Status of [param colonist]: collapsed, then moving, then by its state.
static func of(colonist: Colonist) -> Kind:
	if colonist.is_collapsed():
		return Kind.COLLAPSED
	if colonist.mover.is_moving():
		return Kind.MOVING
	match colonist.state:
		Colonist.State.WORKING:
			return Kind.WORKING
		Colonist.State.RESTING:
			return Kind.RESTING
	return Kind.IDLE


## Text label of [param kind], for example "WORKING".
static func label(kind: Kind) -> String:
	return LABELS[kind]


## One-character symbol of [param kind], for example "W".
static func symbol(kind: Kind) -> String:
	return SYMBOLS[kind]


## Fatigue as a share of [member Colonist.fatigue_max], clamped to 0.0-1.0.
## A non-positive maximum gives 0.0 instead of a division by zero.
static func fatigue_ratio(colonist: Colonist) -> float:
	if colonist.fatigue_max <= 0.0:
		return 0.0
	return clampf(colonist.fatigue / colonist.fatigue_max, 0.0, 1.0)
