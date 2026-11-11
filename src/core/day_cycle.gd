## Day clock and win/lose judge for one run.
##
## Time is injected: [method advance] moves the clock, and the node's
## [method _process] only forwards the frame delta, so tests can step time
## without real waiting. Emits [signal Events.day_started],
## [signal Events.day_ended] and [signal Events.game_ended]. Loses when
## [signal Events.integrity_changed] reports 0 or
## [signal Events.colonists_collapsed] fires; wins when the last day ends.
## [codeblock]
## var cycle := DayCycle.new()
## cycle.configure(60.0, 30)
## cycle.start()        # emits day_started(1)
## cycle.advance(60.0)  # emits day_ended(1), day_started(2)
## [/codeblock]
class_name DayCycle
extends Node

## Reason passed to [signal Events.game_ended] when the last day is survived.
const REASON_SURVIVED := &"survived"
## Reason when station integrity reached 0.
const REASON_INTEGRITY := &"integrity_depleted"
## Reason when all colonists collapsed.
const REASON_COLONISTS := &"colonists_collapsed"

## Seconds per day.
var day_length: float = 60.0

## Number of days in a run; finishing this day wins.
var total_days: int = 30

## The day in progress (starts at 1).
var current_day: int = 1

var _elapsed: float = 0.0
var _running: bool = false


func _ready() -> void:
	var settings := GameConfig.load_settings()
	if settings.is_empty():
		return
	configure(settings["day_length_seconds"], settings["total_days"])
	# Deferred so listeners created later in Main's _ready see day 1.
	start.call_deferred()


func _process(delta: float) -> void:
	advance(delta)


## Sets the day length (seconds) and total days. Call before [method start].
func configure(new_day_length: float, new_total_days: int) -> void:
	day_length = new_day_length
	total_days = new_total_days


## Begins a run at day 1, hooks up the loss signals and emits
## [signal Events.day_started] with 1.
func start() -> void:
	current_day = 1
	_elapsed = 0.0
	_running = true
	if not Events.integrity_changed.is_connected(_on_integrity_changed):
		Events.integrity_changed.connect(_on_integrity_changed)
	if not Events.colonists_collapsed.is_connected(_on_colonists_collapsed):
		Events.colonists_collapsed.connect(_on_colonists_collapsed)
	Events.day_started.emit(current_day)


## Moves the clock forward by [param delta] seconds. A delta spanning several
## days runs each day end in order. Does nothing once the run has ended.
func advance(delta: float) -> void:
	if not _running:
		return
	_elapsed += delta
	while _running and _elapsed >= day_length:
		_elapsed -= day_length
		_finish_day()


## True while the clock is running (started and not yet ended).
func is_running() -> bool:
	return _running


func _finish_day() -> void:
	Events.day_ended.emit(current_day)
	# A day_ended listener may have ended the run (e.g. colonists collapsed).
	if not _running:
		return
	if current_day >= total_days:
		_end(true, REASON_SURVIVED)
		return
	current_day += 1
	Events.day_started.emit(current_day)


func _on_integrity_changed(current: float, _max_value: float) -> void:
	if current <= 0.0:
		_end(false, REASON_INTEGRITY)


func _on_colonists_collapsed() -> void:
	_end(false, REASON_COLONISTS)


# Stops time first so nothing reacting to game_ended can advance the clock.
func _end(won: bool, reason: StringName) -> void:
	if not _running:
		return
	_running = false
	Events.game_ended.emit(won, reason)
