## Station integrity: a capped value that can only go down.
##
## Repairing a crisis just stops the damage; nothing ever restores integrity.
## Emits [signal Events.integrity_changed]; DayCycle turns 0 into a loss.
## [codeblock]
## var integrity := StationIntegrity.new()
## integrity.configure(100.0)
## integrity.apply_damage(15.0)  # current is now 85.0
## [/codeblock]
class_name StationIntegrity
extends Node

## The cap, and the starting value.
var max_value: float = 100.0

## Current integrity, always within 0..max_value.
var current: float = 100.0


func _ready() -> void:
	var settings := GameConfig.load_settings()
	if settings.is_empty():
		return
	# Deferred so listeners created later in Main's _ready see the first value.
	configure.call_deferred(settings["integrity_max"])


## Sets the cap, refills to it and emits [signal Events.integrity_changed].
func configure(new_max_value: float) -> void:
	max_value = new_max_value
	current = new_max_value
	Events.integrity_changed.emit(current, max_value)


## Subtracts [param amount] (clamped at 0) and emits
## [signal Events.integrity_changed]. Amounts of 0 or less are ignored:
## integrity is damage-only. Example: [code]integrity.apply_damage(2.5)[/code]
func apply_damage(amount: float) -> void:
	if amount <= 0.0:
		return
	current = maxf(current - amount, 0.0)
	Events.integrity_changed.emit(current, max_value)
