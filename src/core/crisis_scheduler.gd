## Decides which crises hit on a day (story 004, design/game-brief.md MVP 4).
##
## Pure logic: no Node, no signals, no file I/O. The same inputs always give
## the same crises, and a day's result does not depend on which days were
## scheduled before it, because every day seeds its own generator.
class_name CrisisScheduler
extends RefCounted

## Crisis ids are [code]day * ID_STRIDE + index + 1[/code], so a day holds at
## most ID_STRIDE - 1 crises and ids are never 0.
const ID_STRIDE := 100
## Smallest start delay ever used, even when the curve data says 0 or less.
const MIN_START_DELAY_FLOOR := 0.05
## Spreads the day number across the seed bits (a Fibonacci-hashing constant).
const _DAY_SEED_MIX := 0x9E3779B97F4A7C1


## The crises of [param day], sorted by firing time.
## [param run_seed] and [param day] fix the result. [param room_ids] are the
## rooms a crisis may hit; [param day_length] is the day's seconds. Returns an
## empty array for a day below 1 or when there are no rooms.
static func schedule(
	day: int,
	run_seed: int,
	room_ids: Array[StringName],
	curve: CrisisCurve,
	day_length: float,
) -> Array[Crisis]:
	var crises: Array[Crisis] = []
	if day < 1 or room_ids.is_empty() or curve == null:
		return crises
	var rng := RandomNumberGenerator.new()
	rng.seed = run_seed ^ (day * _DAY_SEED_MIX)
	var count := mini(curve.crises_for_day(day), ID_STRIDE - 1)
	for i in count:
		var kind := _pick_kind(rng, curve)
		var room_id := room_ids[rng.randi() % room_ids.size()]
		var start := _pick_start(rng, curve, day_length)
		crises.append(Crisis.new(0, kind, room_id, day, start))
	# Not a stable sort, but deterministic: equal inputs sort identically.
	crises.sort_custom(func(a: Crisis, b: Crisis) -> bool: return a.start_seconds < b.start_seconds)
	for i in crises.size():
		crises[i].id = make_id(day, i)
	return crises


## The id of the [param index]-th (0-based, by firing time) crisis of [param day].
static func make_id(day: int, index: int) -> int:
	return day * ID_STRIDE + index + 1


static func _pick_kind(rng: RandomNumberGenerator, curve: CrisisCurve) -> StringName:
	var total := 0.0
	for kind: StringName in CrisisKind.ALL:
		total += curve.weight_of(kind)
	if total <= 0.0:
		return CrisisKind.ALL[rng.randi() % CrisisKind.ALL.size()]
	var roll := rng.randf() * total
	for kind: StringName in CrisisKind.ALL:
		roll -= curve.weight_of(kind)
		if roll < 0.0:
			return kind
	return CrisisKind.ALL[CrisisKind.ALL.size() - 1]


static func _pick_start(rng: RandomNumberGenerator, curve: CrisisCurve, day_length: float) -> float:
	var earliest := maxf(curve.min_start_delay_seconds, MIN_START_DELAY_FLOOR)
	var latest := maxf(day_length * curve.latest_start_day_fraction, earliest)
	return earliest + rng.randf() * (latest - earliest)
