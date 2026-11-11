## Every tunable of story 004 as data (design/game-brief.md MVP 4).
##
## The shipped values live in `assets/data/crisis_curve.tres`; designers tune
## them there without touching code. Pure data plus two small lookups.
class_name CrisisCurve
extends Resource

## Crises on day 1 before rounding (the curve's starting height).
@export var base_crises: float = 1.0
## Crises added per day after day 1, before rounding down.
@export var growth_per_day: float = 0.3
## Daily floor (每日保底). Day 1 is not an exception.
@export var min_crises_per_day: int = 1
## Daily ceiling, so late days stay playable.
@export var max_crises_per_day: int = 8

## Relative chance that a crisis is a hull breach.
@export var breach_weight: float = 1.0
## Relative chance that a crisis is an equipment malfunction.
@export var malfunction_weight: float = 1.0

## Integrity lost per second while a breach is unresolved.
@export var breach_damage_per_second: float = 1.0
## Integrity lost per second while a malfunction is unresolved.
@export var malfunction_damage_per_second: float = 0.25

## No crisis fires earlier than this many seconds after its day starts. Must be
## above zero: StationIntegrity may reset its value right after day_started.
@export var min_start_delay_seconds: float = 3.0
## Latest firing time as a fraction of the day length (0..1).
@export_range(0.0, 1.0) var latest_start_day_fraction: float = 0.8


## Crises to schedule on [param day] (1-based): grows with the day, then is
## clamped to [member min_crises_per_day]..[member max_crises_per_day].
func crises_for_day(day: int) -> int:
	var raw := floori(base_crises + growth_per_day * float(maxi(day - 1, 0)))
	var upper := maxi(max_crises_per_day, min_crises_per_day)
	return clampi(raw, min_crises_per_day, upper)


## Integrity lost per second by an unresolved crisis of [param kind].
func damage_per_second(kind: StringName) -> float:
	if kind == CrisisKind.BREACH:
		return breach_damage_per_second
	if kind == CrisisKind.MALFUNCTION:
		return malfunction_damage_per_second
	return 0.0


## Relative spawn weight of [param kind].
func weight_of(kind: StringName) -> float:
	if kind == CrisisKind.BREACH:
		return maxf(breach_weight, 0.0)
	if kind == CrisisKind.MALFUNCTION:
		return maxf(malfunction_weight, 0.0)
	return 0.0
