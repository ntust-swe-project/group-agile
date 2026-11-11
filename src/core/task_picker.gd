## Chooses which task a free colonist takes (story 003, design/game-brief.md MVP 3).
##
## Pure logic, no scene dependency. Rule, in order:
## 1. only tasks nobody has claimed, in a room the colonist can reach;
## 2. the kind that comes first in the priority order (a kind missing from the
##    order ranks below every listed kind);
## 3. the fewest hops from the colonist's room ([method StationMap.find_path]);
## 4. the smaller task id, so ties always resolve the same way.
class_name TaskPicker
extends RefCounted


## Returns the task [param from_room] should take, or null when no unclaimed,
## reachable task exists. [param priority_order] lists kinds, highest first.
static func pick(tasks: Array, priority_order: Array[StringName], from_room: StringName, map: StationMap) -> WorkTask:
	var best: WorkTask = null
	var best_rank := 0
	var best_distance := 0
	for task: WorkTask in tasks:
		if task.is_claimed():
			continue
		var distance := _distance(map, from_room, task.room_id)
		if distance < 0:
			continue
		var rank := _rank(priority_order, task.kind)
		if best == null \
				or rank < best_rank \
				or (rank == best_rank and distance < best_distance) \
				or (rank == best_rank and distance == best_distance and task.id < best.id):
			best = task
			best_rank = rank
			best_distance = distance
	return best


# Hops between two rooms; -1 when a room is unknown or there is no route.
static func _distance(map: StationMap, from: StringName, to: StringName) -> int:
	if not map.has_room(from) or not map.has_room(to):
		return -1
	if from == to:
		return 0
	var path := map.find_path(from, to)
	return path.size() if not path.is_empty() else -1


static func _rank(priority_order: Array[StringName], kind: StringName) -> int:
	var index := priority_order.find(kind)
	return index if index >= 0 else priority_order.size()
