## Root of the main scene (`src/main.tscn`). Holds no game logic.
##
## Systems never look each other up. When one system must call another's
## methods, Main hands it a reference in [method _ready] (EPIC.md 整合約定).
## Convention: the receiving script declares a property named after the
## source node in snake_case, typed loosely so it works before the source has
## a script, and Main assigns it. Nodes without that property are skipped.
## [codeblock]
## # src/crisis_director/crisis_director.gd
## var station_integrity: Node  # set by Main before the first frame
## [/codeblock]
## Children run [method Node._ready] before Main does, so a system must not
## use an injected reference inside its own [method Node._ready].
extends Node

## Wiring table: [target node, property on target, source node].
## Add a row here when a story needs another system's methods.
const INJECTIONS := [
	[^"CrisisDirector", "station_integrity", ^"StationIntegrity"],
	[^"Station", "colonists", ^"Colonists"],
	[^"CrisisDirector", "day_cycle", ^"DayCycle"],
	[^"CrisisDirector", "station", ^"Station"],
]


func _ready() -> void:
	inject_dependencies()


## Applies every row of [constant INJECTIONS]. A row is a no-op when either
## node is missing or the target does not declare the property, so it is safe
## to call on the bare skeleton and again after scripts change.
func inject_dependencies() -> void:
	for row in INJECTIONS:
		var target := get_node_or_null(row[0])
		var source := get_node_or_null(row[2])
		if target == null or source == null:
			continue
		if row[1] in target:
			target.set(row[1], source)
