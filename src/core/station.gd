## The `Station` node of Main (story 002): owns the room graph and shows it.
##
## The view is read-only. `colonists` is injected by Main (see main.gd
## INJECTIONS), so it is only usable after _ready; it is handed to the view
## on the first frame.
extends Node

const STATION_VIEW := preload("res://src/ui/station_view.tscn")

## Room graph loaded from the station data file.
var map: StationMap
## Set by Main before the first frame.
var colonists: Node

var _view: Control


func _ready() -> void:
	map = StationMap.new()
	map.setup(StationMap.load_data())
	_view = STATION_VIEW.instantiate()
	add_child(_view)
	_view.map = map


func _process(_delta: float) -> void:
	_view.colonists = colonists
