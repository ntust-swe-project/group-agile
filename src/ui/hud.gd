## On-screen status: "Day N / total" and station integrity.
##
## Display only. Listens to [signal Events.day_started] and
## [signal Events.integrity_changed]; the total day count comes from
## [GameConfig].
extends CanvasLayer

var _day: int = 1
var _total_days: int = 0
var _integrity: float = 0.0
var _integrity_max: float = 0.0

@onready var _label: Label = $StatusLabel


func _ready() -> void:
	var settings := GameConfig.load_settings()
	if not settings.is_empty():
		_total_days = settings["total_days"]
		_integrity = settings["integrity_max"]
		_integrity_max = settings["integrity_max"]
	Events.day_started.connect(_on_day_started)
	Events.integrity_changed.connect(_on_integrity_changed)
	_refresh()


func _on_day_started(day: int) -> void:
	_day = day
	_refresh()


func _on_integrity_changed(current: float, max_value: float) -> void:
	_integrity = current
	_integrity_max = max_value
	_refresh()


func _refresh() -> void:
	_label.text = "Day %d / %d\nIntegrity %d / %d" % [
		_day, _total_days, ceili(_integrity), ceili(_integrity_max)
	]
