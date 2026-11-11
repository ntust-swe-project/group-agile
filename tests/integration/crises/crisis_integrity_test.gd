# Issue #33 / story 004 (production/epics/orbit-shift/story-004-escalating-crises.md).
# CrisisDirector wired to the real StationIntegrity and DayCycle of story 001,
# the way Main injects them; the unit tests use a fake integrity instead.
# No scene tree for the story 001 nodes (their _ready reads the data file), an
# explicit seed and explicit ticks, so the result is the same every run.
extends GdUnitTestSuite

const DIRECTOR_SCRIPT := preload("res://src/core/crisis_director.gd")
const SEED := 4242
const DAY_LENGTH := 60.0
const TOTAL_DAYS := 30
const BREACH_RATE := 2.0
const START_INTEGRITY := 100.0
const LOW_INTEGRITY := 5.0
const EPSILON := 0.0001

var _ended: Array = []


func before_test() -> void:
	_ended = []
	Events.game_ended.connect(_record_ended)


func after_test() -> void:
	if Events.game_ended.is_connected(_record_ended):
		Events.game_ended.disconnect(_record_ended)


func _record_ended(won: bool, reason: StringName) -> void:
	_ended.append([won, reason])


# Breach only, one crisis a day, so the damage rate is known exactly.
func _breach_curve() -> CrisisCurve:
	var curve := CrisisCurve.new()
	curve.base_crises = 1.0
	curve.growth_per_day = 0.0
	curve.min_crises_per_day = 1
	curve.max_crises_per_day = 1
	curve.breach_weight = 1.0
	curve.malfunction_weight = 0.0
	curve.breach_damage_per_second = BREACH_RATE
	curve.min_start_delay_seconds = 4.0
	curve.latest_start_day_fraction = 0.5
	return curve


func _rooms() -> Array[StringName]:
	return [&"dorm", &"bridge", &"engine"]


func _integrity(start: float) -> StationIntegrity:
	var integrity: StationIntegrity = auto_free(StationIntegrity.new())
	integrity.configure(start)
	return integrity


func _day_cycle() -> DayCycle:
	var cycle: DayCycle = auto_free(DayCycle.new())
	cycle.configure(DAY_LENGTH, TOTAL_DAYS)
	return cycle


func _director(curve: CrisisCurve, integrity: StationIntegrity, cycle: DayCycle) -> Node:
	var director: Node = auto_free(DIRECTOR_SCRIPT.new())
	director.auto_tick = false
	director.run_seed = SEED
	director.setup(curve, _rooms())
	director.station_integrity = integrity
	director.day_cycle = cycle
	add_child(director)
	return director


func _first_crisis(curve: CrisisCurve) -> Crisis:
	return CrisisScheduler.schedule(1, SEED, _rooms(), curve, DAY_LENGTH)[0]


func test_breach_lowers_the_real_integrity_until_its_task_is_completed() -> void:
	# Arrange: DayCycle.start() emits the real day_started(1)
	var curve := _breach_curve()
	var integrity := _integrity(START_INTEGRITY)
	var cycle := _day_cycle()
	var director := _director(curve, integrity, cycle)
	var crisis := _first_crisis(curve)
	cycle.start()
	director.tick(crisis.start_seconds)
	# Act: 3 seconds unresolved, then repaired, then 5 more seconds
	director.tick(3.0)
	var after_breach := integrity.current
	Events.task_completed.emit(1, crisis.id)
	director.tick(5.0)
	# Assert
	assert_float(after_breach).is_equal_approx(START_INTEGRITY - 3.0 * BREACH_RATE, EPSILON)
	assert_float(integrity.current).is_equal_approx(after_breach, EPSILON)
	assert_array(_ended).is_empty()


func test_integrity_reaching_zero_ends_the_game_and_stops_the_damage() -> void:
	# Arrange: low integrity, so the first breach empties it
	var curve := _breach_curve()
	var integrity := _integrity(LOW_INTEGRITY)
	var cycle := _day_cycle()
	var director := _director(curve, integrity, cycle)
	var crisis := _first_crisis(curve)
	cycle.start()
	director.tick(crisis.start_seconds)
	# Act: far longer than LOW_INTEGRITY / BREACH_RATE seconds
	for i in 20:
		director.tick(1.0)
	# Assert: DayCycle judged the loss once, integrity stopped at 0, time stopped
	assert_float(integrity.current).is_equal(0.0)
	assert_array(_ended).is_equal([[false, DayCycle.REASON_INTEGRITY]])
	assert_bool(cycle.is_running()).is_false()
