## Room graph of the station (story 002, design/game-brief.md MVP 2).
##
## Pure logic, no scene dependency. Room ids are defined in the data file
## [constant DATA_PATH]; other systems (004, 005) read the same file.
class_name StationMap
extends RefCounted

## The single data file for rooms, colonists and every tunable of story 002.
const DATA_PATH := "res://data/orbit_shift/station.json"

## The dorm room, where colonists rest.
var dorm_id: StringName = &""
## Every room id, in data-file order.
var room_ids: Array[StringName] = []
## Undirected connections as [a, b] pairs of room ids, in data-file order.
var connections: Array = []

var _rooms: Dictionary = {}
var _adjacency: Dictionary = {}


## Reads and parses the data file. This is the only file I/O of story 002.
static func load_data(path: String = DATA_PATH) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("station data must be a JSON object: " + path)
		return {}
	return parsed


## Builds the graph from a data dictionary (see [constant DATA_PATH] for the shape).
func setup(data: Dictionary) -> void:
	dorm_id = StringName(data["dorm_id"])
	for entry: Dictionary in data["rooms"]:
		var id := StringName(entry["id"])
		room_ids.append(id)
		_rooms[id] = entry
		_adjacency[id] = []
	assert(_rooms.has(dorm_id), "dorm_id is not a room")
	for pair: Array in data["connections"]:
		var a := StringName(pair[0])
		var b := StringName(pair[1])
		assert(_rooms.has(a) and _rooms.has(b), "connection names an unknown room")
		_adjacency[a].append(b)
		_adjacency[b].append(a)
		connections.append([a, b])


## True when [param room_id] is a room of this station.
func has_room(room_id: StringName) -> bool:
	return _rooms.has(room_id)


## The raw data entry (id, name, color, pos) of a room.
func get_room(room_id: StringName) -> Dictionary:
	return _rooms[room_id]


## Rooms directly connected to [param room_id].
func neighbors(room_id: StringName) -> Array:
	return _adjacency[room_id]


## True when the two rooms share a connection.
func is_adjacent(a: StringName, b: StringName) -> bool:
	return _adjacency[a].has(b)


## Shortest route from [param from] to [param to] as the rooms to enter, in
## order, excluding [param from]. Empty when both are the same room, when
## either room is unknown, or when [param to] is unreachable.
func find_path(from: StringName, to: StringName) -> Array[StringName]:
	var path: Array[StringName] = []
	if not has_room(from) or not has_room(to):
		return path
	var previous := {from: &""}
	var queue: Array[StringName] = [from]
	var head := 0
	while head < queue.size() and not previous.has(to):
		var current := queue[head]
		head += 1
		for next: StringName in _adjacency[current]:
			if not previous.has(next):
				previous[next] = current
				queue.append(next)
	if not previous.has(to):
		return path
	var step := to
	while step != from:
		path.push_front(step)
		step = previous[step]
	return path
