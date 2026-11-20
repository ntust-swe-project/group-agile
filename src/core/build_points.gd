## Build point balance (story 005, design/game-brief.md MVP 5).
##
## Pure logic. The player earns points per surviving day and spends them on
## auto-repair modules.
## [codeblock]
## var points := BuildPoints.new()
## points.add(1)
## if points.spend(1):
##     print("built")
## [/codeblock]
class_name BuildPoints
extends RefCounted

## Points currently available.
var points: int = 0


## Adds [param amount] points.
func add(amount: int) -> void:
	points += amount


## True when at least [param cost] points are available.
func can_afford(cost: int) -> bool:
	return points >= cost


## Takes [param cost] points and returns true, or returns false and changes
## nothing when there are not enough.
func spend(cost: int) -> bool:
	if not can_afford(cost):
		return false
	points -= cost
	return true
