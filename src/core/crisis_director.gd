## The `CrisisDirector` node of Main (story 004, design/game-brief.md MVP 4).
##
## On [signal Events.day_started] it asks [CrisisScheduler] for that day's
## crises and fires each one when its time arrives: [signal Events.crisis_started].
## While a crisis is unresolved it damages the station every second through
## [code]station_integrity.apply_damage(amount)[/code]. When
## [signal Events.task_completed] names the crisis it stops the damage and emits
## [signal Events.crisis_resolved]. Crises survive day boundaries until resolved.
## After [signal Events.game_ended] nothing fires and nothing is damaged.
##
## Ordering rule: nothing is emitted or damaged inside the day_started handler.
## Crises fire at least [member CrisisCurve.min_start_delay_seconds] later, in
## [method tick], because StationIntegrity may reset its value in a deferred
## call right after day_started and would erase same-frame damage.
##
## Time only moves through [method tick]. Tests set [member auto_tick] to false.
extends Node

const CURVE_PATH := "res://assets/data/crisis_curve.tres"
const MARKERS := preload("res://src/ui/crisis_markers.gd")

## Tunables (curve, damage rates, timing); loaded from [member curve_path]
## in _ready unless a test already set it.
var curve: CrisisCurve
## Where _ready loads [member curve] from. A file that is missing or not a
## [CrisisCurve] is reported with push_error; the run then has no crises.
var curve_path: String = CURVE_PATH
## Seconds per day when no `day_cycle` supplies one. Same default as DayCycle.
var day_length: float = 60.0
## When true the node ticks itself in _process.
var auto_tick: bool = true
## Seed of this run. Random per run unless set before _ready; printed once at
## run start so a run can be replayed by setting it again.
var run_seed: int:
	set(value):
		run_seed = value
		_seed_fixed = true
## Crises that are active right now, crisis id -> [Crisis]. Read-only for others.
var active_crises: Dictionary = {}
## Set by Main (see main.gd INJECTIONS): has `apply_damage(amount: float)`.
## Unusable inside _ready, and may be a node without that method until story 001 lands.
var station_integrity: Node
## Set by Main: read for `day_length` when it has one. Loosely typed on purpose,
## so there is no hard dependency on story 001.
var day_cycle: Node
## Set by Main: the Station node; its `map` gives the markers the room geometry.
var station: Node

var _room_ids: Array[StringName] = []
var _seed_fixed: bool = false
var _clock: float = 0.0
# Not yet fired crises as [fire_at_clock_time, Crisis] pairs, ascending.
var _pending: Array = []
# Crisis id -> clock time up to which damage has been applied.
var _billed_until: Dictionary = {}
var _scheduled_days := {}
var _ended: bool = false


## Sets the data the director works from. Called by _ready with the shipped
## files unless a test already called it.
func setup(p_curve: CrisisCurve, p_room_ids: Array[StringName]) -> void:
	curve = p_curve
	_room_ids = p_room_ids.duplicate()


func _ready() -> void:
	if curve == null:
		if ResourceLoader.exists(curve_path):
			curve = load(curve_path) as CrisisCurve
		if curve == null:
			push_error("CrisisDirector: cannot load crisis curve from %s; no crises will be scheduled" % curve_path)
	if _room_ids.is_empty():
		var map := StationMap.new()
		map.setup(StationMap.load_data())
		_room_ids = map.room_ids.duplicate()
	if not _seed_fixed:
		run_seed = randi()
	print("[CrisisDirector] run_seed=%d" % run_seed)
	Events.day_started.connect(_on_day_started)
	Events.task_completed.connect(_on_task_completed)
	Events.game_ended.connect(_on_game_ended)
	var markers := MARKERS.new()
	markers.director = self
	add_child(markers)
	set_process(auto_tick)


func _process(delta: float) -> void:
	tick(delta)


## Advances time by [param delta] seconds: fires the crises that are due, then
## applies the damage of every active crisis for the time since it was last billed.
func tick(delta: float) -> void:
	if _ended or delta <= 0.0:
		return
	_clock += delta
	while not _pending.is_empty() and _pending[0][0] <= _clock:
		var due: Array = _pending.pop_front()
		_fire(due[1], due[0])
	# Iterate a snapshot: apply_damage can end the game or resolve a crisis
	# synchronously (story 001 emits game_ended when integrity reaches 0).
	for crisis: Crisis in active_crises.values():
		if _ended:
			return
		if active_crises.has(crisis.id):
			_apply_damage_for(crisis)


func _fire(crisis: Crisis, fire_at: float) -> void:
	active_crises[crisis.id] = crisis
	_billed_until[crisis.id] = fire_at
	Events.crisis_started.emit(crisis.id, crisis.kind, crisis.room_id)


func _apply_damage_for(crisis: Crisis) -> void:
	var seconds: float = _clock - _billed_until[crisis.id]
	_billed_until[crisis.id] = _clock
	var amount := curve.damage_per_second(crisis.kind) * seconds
	if amount <= 0.0:
		return
	# Until story 001 lands, station_integrity is a plain Node without the method.
	if station_integrity != null and station_integrity.has_method("apply_damage"):
		station_integrity.apply_damage(amount)


func _on_day_started(day: int) -> void:
	if _ended or curve == null or _scheduled_days.has(day):
		return
	_scheduled_days[day] = true
	if day_cycle != null and "day_length" in day_cycle and float(day_cycle.day_length) > 0.0:
		day_length = float(day_cycle.day_length)
	for crisis in CrisisScheduler.schedule(day, run_seed, _room_ids, curve, day_length):
		_pending.append([_clock + crisis.start_seconds, crisis])
	_pending.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])


func _on_task_completed(_task_id: int, crisis_id: int) -> void:
	if _ended or not active_crises.has(crisis_id):
		return
	active_crises.erase(crisis_id)
	_billed_until.erase(crisis_id)
	Events.crisis_resolved.emit(crisis_id)


func _on_game_ended(_won: bool, _reason: StringName) -> void:
	_ended = true
	_pending.clear()
