# Story 002 (production/epics/orbit-shift/story-002-rooms-and-colonists.md).
# Logic is driven with explicit deltas and injected data; no file I/O.
extends GdUnitTestSuite

const COLONISTS_SCRIPT := preload("res://src/core/colonists.gd")

# Line graph a - b - c - dorm, plus d off b. Tunables are exact binary fractions.
const DATA := {
	"dorm_id": "dorm",
	"start_room": "a",
	"rooms": [
		{"id": "a", "name": "A", "color": "#ffffff", "pos": [0, 0]},
		{"id": "b", "name": "B", "color": "#ffffff", "pos": [0, 0]},
		{"id": "c", "name": "C", "color": "#ffffff", "pos": [0, 0]},
		{"id": "d", "name": "D", "color": "#ffffff", "pos": [0, 0]},
		{"id": "e", "name": "E", "color": "#ffffff", "pos": [0, 0]},
		{"id": "dorm", "name": "Dorm", "color": "#ffffff", "pos": [0, 0]},
	],
	"connections": [["a", "b"], ["b", "c"], ["c", "dorm"], ["b", "d"], ["d", "e"]],
	"colonists": ["Ann", "Bob", "Cat"],
	"move_seconds": 2.0,
	"fatigue_max": 100.0,
	"fatigue_rise_per_sec": 10.0,
	"fatigue_fall_per_sec": 20.0,
	"rest_threshold": 40.0,
	"collapse_seconds": 5.0,
}


func _map() -> StationMap:
	var map := StationMap.new()
	map.setup(DATA)
	return map


func _colonist(start_room: StringName = &"a") -> Colonist:
	var map := _map()
	return Colonist.new("Ann", Mover.new(map, start_room, DATA["move_seconds"]), map.dorm_id, DATA)


func _colonists_node() -> Node:
	var node: Node = auto_free(COLONISTS_SCRIPT.new())
	node.auto_tick = false
	node.setup(DATA)
	add_child(node)
	return node


# --- room graph ---

func test_station_map_reads_rooms_connections_and_dorm_from_data() -> void:
	# Arrange / Act
	var map := _map()
	# Assert
	assert_int(map.room_ids.size()).is_equal(6)
	assert_bool(map.is_adjacent(&"a", &"b")).is_true()
	assert_bool(map.is_adjacent(&"b", &"a")).is_true()
	assert_bool(map.is_adjacent(&"a", &"c")).is_false()
	assert_str(map.dorm_id).is_equal("dorm")


func test_station_map_find_path_follows_graph_hop_by_hop() -> void:
	# Arrange
	var map := _map()
	# Act / Assert
	assert_array(map.find_path(&"a", &"dorm")).is_equal([&"b", &"c", &"dorm"])
	assert_array(map.find_path(&"e", &"a")).is_equal([&"d", &"b", &"a"])
	assert_array(map.find_path(&"a", &"a")).is_empty()


# --- colonists exist ---

func test_colonists_node_creates_three_named_colonists_with_fatigue() -> void:
	# Arrange / Act
	var node := _colonists_node()
	# Assert
	assert_int(node.colonists.size()).is_equal(3)
	assert_str(node.colonists[0].display_name).is_equal("Ann")
	assert_str(node.colonists[2].display_name).is_equal("Cat")
	assert_float(node.colonists[1].fatigue).is_equal(0.0)


# --- movement ---

func test_move_to_adjacent_room_takes_fixed_seconds() -> void:
	# Arrange
	var colonist := _colonist()
	colonist.assign_work(&"b")
	# Act / Assert
	colonist.tick(1.0, false)
	assert_bool(colonist.mover.is_moving()).is_true()
	assert_str(colonist.mover.room_id).is_equal("a")
	colonist.tick(1.0, false)
	assert_bool(colonist.mover.is_moving()).is_false()
	assert_str(colonist.mover.room_id).is_equal("b")


func test_move_to_non_adjacent_room_goes_through_each_room_on_the_graph() -> void:
	# Arrange
	var colonist := _colonist()
	colonist.assign_work(&"c")
	# Act / Assert
	colonist.tick(2.0, false)
	assert_str(colonist.mover.room_id).is_equal("b")
	assert_bool(colonist.mover.is_moving()).is_true()
	colonist.tick(2.0, false)
	assert_str(colonist.mover.room_id).is_equal("c")
	assert_bool(colonist.mover.is_moving()).is_false()


func test_mover_carries_leftover_delta_across_hops() -> void:
	# Arrange
	var mover := Mover.new(_map(), &"a", 2.0)
	mover.start_move(&"c")
	# Act
	mover.step(5.0)
	# Assert: two hops (4s) done, 1s into none (arrived)
	assert_str(mover.room_id).is_equal("c")
	assert_bool(mover.is_moving()).is_false()


func test_mover_retarget_during_hop_finishes_hop_then_reroutes() -> void:
	# Arrange
	var mover := Mover.new(_map(), &"a", 2.0)
	mover.start_move(&"c")
	mover.step(1.0)
	# Act
	mover.start_move(&"a")
	mover.step(1.0)
	# Assert: reached b, now heading back to a
	assert_str(mover.room_id).is_equal("b")
	assert_str(mover.next_room()).is_equal("a")


func test_no_work_while_moving() -> void:
	# Arrange
	var colonist := _colonist()
	colonist.assign_work(&"b")
	# Act: 1s of a 2s move
	colonist.tick(1.0, false)
	# Assert
	assert_float(colonist.fatigue).is_equal(0.0)


func test_mover_is_a_single_replaceable_component_of_colonist() -> void:
	# Arrange: a stub mover that teleports; Colonist needs no other change
	var stub := TeleportMover.new(_map(), &"a", 2.0)
	var colonist := Colonist.new("Ann", stub, &"dorm", DATA)
	# Act
	colonist.assign_work(&"c")
	colonist.tick(1.0, false)
	# Assert
	assert_str(stub.room_id).is_equal("c")
	assert_float(colonist.fatigue).is_equal(10.0)


# --- fatigue ---

func test_fatigue_rises_at_tunable_rate_while_working() -> void:
	# Arrange
	var colonist := _colonist(&"b")
	colonist.assign_work(&"b")
	# Act
	colonist.tick(2.0, false)
	# Assert: 10/s * 2s
	assert_float(colonist.fatigue).is_equal(20.0)


func test_fatigue_unchanged_while_idle() -> void:
	# Arrange
	var colonist := _colonist()
	# Act
	colonist.tick(3.0, false)
	# Assert
	assert_float(colonist.fatigue).is_equal(0.0)


func test_fatigue_falls_at_tunable_rate_while_resting_in_dorm() -> void:
	# Arrange: exhausted colonist already in the dorm
	var colonist := _colonist(&"dorm")
	colonist.fatigue = 100.0
	colonist.assign_work(&"dorm")
	colonist.tick(0.0, false)
	# Act
	colonist.tick(1.0, false)
	# Assert: 20/s * 1s
	assert_float(colonist.fatigue).is_equal(80.0)
	assert_int(colonist.state).is_equal(Colonist.State.RESTING)


func test_at_max_fatigue_colonist_drops_work_and_goes_to_dorm() -> void:
	# Arrange
	var colonist := _colonist(&"c")
	colonist.assign_work(&"c")
	# Act: 10s of work reaches max
	colonist.tick(10.0, false)
	# Assert
	assert_int(colonist.state).is_equal(Colonist.State.RESTING)
	assert_str(colonist.mover.next_room()).is_equal("dorm")


func test_colonist_returns_to_work_after_fatigue_drops_below_threshold() -> void:
	# Arrange: at max, walk to dorm (2s)
	var colonist := _colonist(&"c")
	colonist.assign_work(&"c")
	colonist.tick(10.0, false)
	colonist.tick(2.0, false)
	# Act: 20/s from 100: 60 stays >= 40, 3.1s total drops below 40
	colonist.tick(2.0, false)
	assert_int(colonist.state).is_equal(Colonist.State.RESTING)
	colonist.tick(1.1, false)
	# Assert
	assert_int(colonist.state).is_equal(Colonist.State.WORKING)
	assert_str(colonist.mover.next_room()).is_equal("c")


# --- collapse ---

func test_normal_rest_in_dorm_without_crisis_is_not_collapse() -> void:
	# Arrange
	var colonist := _colonist(&"dorm")
	colonist.fatigue = 100.0
	colonist.assign_work(&"dorm")
	# Act
	colonist.tick(10.0, false)
	# Assert
	assert_bool(colonist.is_collapsed()).is_false()


func test_dorm_crisis_longer_than_n_seconds_at_max_fatigue_is_collapse() -> void:
	# Arrange
	var colonist := _colonist(&"dorm")
	colonist.fatigue = 100.0
	colonist.assign_work(&"dorm")
	# Act / Assert: N = 5s; exactly 5s is not yet "more than N"
	colonist.tick(5.0, true)
	assert_bool(colonist.is_collapsed()).is_false()
	colonist.tick(0.5, true)
	assert_bool(colonist.is_collapsed()).is_true()


func test_collapse_clears_when_dorm_crisis_is_resolved() -> void:
	# Arrange
	var colonist := _colonist(&"dorm")
	colonist.fatigue = 100.0
	colonist.assign_work(&"dorm")
	colonist.tick(6.0, true)
	# Act
	colonist.tick(0.5, false)
	# Assert
	assert_bool(colonist.is_collapsed()).is_false()
	assert_float(colonist.fatigue).is_less(100.0)


func test_dorm_crisis_below_max_fatigue_is_not_collapse() -> void:
	# Arrange
	var colonist := _colonist(&"dorm")
	colonist.assign_work(&"dorm")
	# Act: works in the dorm, fatigue 60 < max
	colonist.tick(6.0, true)
	# Assert
	assert_bool(colonist.is_collapsed()).is_false()


func test_colonists_collapsed_emitted_once_when_all_three_collapse() -> void:
	# Arrange
	var node := _colonists_node()
	var emitted := [0]
	var on_collapsed := func() -> void: emitted[0] += 1
	Events.colonists_collapsed.connect(on_collapsed)
	for colonist: Colonist in node.colonists:
		colonist.mover.room_id = &"dorm"
		colonist.fatigue = 100.0
		colonist.assign_work(&"dorm")
	Events.crisis_started.emit(1, CrisisKind.BREACH, &"dorm")
	# Act
	node.tick(5.0)
	var before: int = emitted[0]
	node.tick(1.0)
	node.tick(1.0)
	Events.colonists_collapsed.disconnect(on_collapsed)
	# Assert
	assert_int(before).is_equal(0)
	assert_int(emitted[0]).is_equal(1)


func test_colonists_collapsed_not_emitted_when_only_two_collapse() -> void:
	# Arrange
	var node := _colonists_node()
	var emitted := [0]
	var on_collapsed := func() -> void: emitted[0] += 1
	Events.colonists_collapsed.connect(on_collapsed)
	for i in 2:
		var colonist: Colonist = node.colonists[i]
		colonist.mover.room_id = &"dorm"
		colonist.fatigue = 100.0
		colonist.assign_work(&"dorm")
	Events.crisis_started.emit(1, CrisisKind.MALFUNCTION, &"dorm")
	# Act
	node.tick(6.0)
	Events.colonists_collapsed.disconnect(on_collapsed)
	# Assert
	assert_int(emitted[0]).is_equal(0)


func test_colonists_collapsed_not_emitted_when_roster_is_empty() -> void:
	# Arrange
	var data := DATA.duplicate(true)
	data["colonists"] = []
	var node: Node = auto_free(COLONISTS_SCRIPT.new())
	node.auto_tick = false
	node.setup(data)
	add_child(node)
	var emitted := [0]
	var on_collapsed := func() -> void: emitted[0] += 1
	Events.colonists_collapsed.connect(on_collapsed)
	# Act
	node.tick(1.0)
	Events.colonists_collapsed.disconnect(on_collapsed)
	# Assert
	assert_int(emitted[0]).is_equal(0)


func test_dorm_crisis_tracking_uses_crisis_ids_and_ignores_other_rooms() -> void:
	# Arrange
	var node := _colonists_node()
	# Act / Assert
	Events.crisis_started.emit(1, CrisisKind.BREACH, &"a")
	assert_bool(node.dorm_has_unresolved_crisis()).is_false()
	Events.crisis_started.emit(2, CrisisKind.BREACH, &"dorm")
	Events.crisis_started.emit(3, CrisisKind.MALFUNCTION, &"dorm")
	assert_bool(node.dorm_has_unresolved_crisis()).is_true()
	Events.crisis_resolved.emit(2)
	assert_bool(node.dorm_has_unresolved_crisis()).is_true()
	Events.crisis_resolved.emit(3)
	assert_bool(node.dorm_has_unresolved_crisis()).is_false()


func test_colonists_collapsed_emitted_again_after_recovery_and_second_collapse() -> void:
	# Arrange: all three exhausted in the dorm, collapse once on crisis 1
	var node := _colonists_node()
	var emitted := [0]
	var on_collapsed := func() -> void: emitted[0] += 1
	Events.colonists_collapsed.connect(on_collapsed)
	for colonist: Colonist in node.colonists:
		colonist.mover.room_id = &"dorm"
		colonist.fatigue = 100.0
		colonist.assign_work(&"dorm")
	Events.crisis_started.emit(1, CrisisKind.BREACH, &"dorm")
	node.tick(6.0)
	# Act: resolve, rest 100 -> 20 (back to work in the dorm), work 20 -> 100,
	# then a new dorm crisis blocks the next rest for more than 5s
	Events.crisis_resolved.emit(1)
	node.tick(0.5)
	node.tick(3.5)
	node.tick(8.0)
	Events.crisis_started.emit(2, CrisisKind.MALFUNCTION, &"dorm")
	node.tick(6.0)
	Events.colonists_collapsed.disconnect(on_collapsed)
	# Assert
	assert_int(emitted[0]).is_equal(2)


func test_tick_after_game_ended_freezes_fatigue_and_position() -> void:
	# Arrange: Ann walks a -> b, Bob works in a
	var node := _colonists_node()
	node.command_go_to(0, &"b")
	node.command_go_to(1, &"a")
	Events.game_ended.emit(false, &"test")
	# Act
	node.tick(10.0)
	# Assert
	var ann: Colonist = node.colonists[0]
	var bob: Colonist = node.colonists[1]
	assert_str(ann.mover.room_id).is_equal("a")
	assert_float(ann.mover.hop_progress()).is_equal(0.0)
	assert_float(bob.fatigue).is_equal(0.0)


func test_tick_after_game_ended_does_not_emit_colonists_collapsed() -> void:
	# Arrange: a state that would collapse all three after 5s
	var node := _colonists_node()
	var emitted := [0]
	var on_collapsed := func() -> void: emitted[0] += 1
	Events.colonists_collapsed.connect(on_collapsed)
	for colonist: Colonist in node.colonists:
		colonist.mover.room_id = &"dorm"
		colonist.fatigue = 100.0
		colonist.assign_work(&"dorm")
	Events.crisis_started.emit(1, CrisisKind.BREACH, &"dorm")
	Events.game_ended.emit(false, &"test")
	# Act
	node.tick(10.0)
	Events.colonists_collapsed.disconnect(on_collapsed)
	# Assert
	assert_int(emitted[0]).is_equal(0)


func test_assign_work_while_resting_stays_in_dorm_then_goes_to_new_room() -> void:
	# Arrange: exhausted and resting in the dorm
	var colonist := _colonist(&"dorm")
	colonist.fatigue = 100.0
	colonist.assign_work(&"dorm")
	colonist.tick(0.0, false)
	# Act / Assert: the order is remembered, rest continues
	colonist.assign_work(&"b")
	colonist.tick(1.0, false)
	assert_int(colonist.state).is_equal(Colonist.State.RESTING)
	assert_str(colonist.mover.room_id).is_equal("dorm")
	assert_bool(colonist.mover.is_moving()).is_false()
	# 80 -> 38 drops below 40: rest ends, head for b via c
	colonist.tick(2.1, false)
	assert_int(colonist.state).is_equal(Colonist.State.WORKING)
	assert_str(colonist.mover.next_room()).is_equal("c")
	colonist.tick(4.0, false)
	assert_str(colonist.mover.room_id).is_equal("b")
	assert_bool(colonist.mover.is_moving()).is_false()


func test_walk_to_dorm_during_dorm_crisis_does_not_count_toward_collapse() -> void:
	# Arrange: exhausted in c, one 2s hop from the dorm; crisis the whole time
	var colonist := _colonist(&"c")
	colonist.fatigue = 100.0
	colonist.assign_work(&"c")
	# Act / Assert: 2s walk + 5s waiting = 7s of crisis, but only 5s since arrival
	colonist.tick(1.0, true)
	colonist.tick(1.0, true)
	assert_str(colonist.mover.room_id).is_equal("dorm")
	colonist.tick(5.0, true)
	assert_bool(colonist.is_collapsed()).is_false()
	colonist.tick(0.5, true)
	assert_bool(colonist.is_collapsed()).is_true()


func test_clear_work_makes_working_colonist_idle_and_resting_colonist_idle_after_rest() -> void:
	# Arrange: one colonist working in b, one exhausted and resting in the dorm
	var worker := _colonist(&"b")
	worker.assign_work(&"b")
	var sleeper := _colonist(&"dorm")
	sleeper.fatigue = 100.0
	sleeper.assign_work(&"b")
	sleeper.tick(0.0, false)
	# Act
	worker.clear_work()
	sleeper.clear_work()
	sleeper.tick(4.0, false)
	# Assert: rest ended (100 -> 20) and no old room to walk back to
	assert_int(worker.state).is_equal(Colonist.State.IDLE)
	assert_str(worker.work_room).is_empty()
	assert_int(sleeper.state).is_equal(Colonist.State.IDLE)
	assert_bool(sleeper.mover.is_moving()).is_false()


func test_command_go_to_unknown_room_reports_error_and_leaves_colonist_unchanged() -> void:
	# Arrange
	var node := _colonists_node()
	var ann: Colonist = node.colonists[0]
	# Act / Assert
	await assert_error(func() -> void: node.command_go_to(0, &"nowhere")) \
		.is_push_error("command_go_to: unknown room nowhere")
	assert_int(ann.state).is_equal(Colonist.State.IDLE)
	assert_str(ann.work_room).is_empty()
	assert_bool(ann.mover.is_moving()).is_false()


func test_command_go_to_out_of_range_index_reports_error_and_changes_nothing() -> void:
	# Arrange
	var node := _colonists_node()
	# Act / Assert
	await assert_error(func() -> void: node.command_go_to(3, &"b")) \
		.is_push_error("command_go_to: no colonist at index 3")
	await assert_error(func() -> void: node.command_go_to(-1, &"b")) \
		.is_push_error("command_go_to: no colonist at index -1")
	for colonist: Colonist in node.colonists:
		assert_int(colonist.state).is_equal(Colonist.State.IDLE)
		assert_bool(colonist.mover.is_moving()).is_false()


func test_find_path_with_unknown_room_returns_empty() -> void:
	# Arrange
	var map := _map()
	# Act / Assert
	assert_array(map.find_path(&"a", &"nowhere")).is_empty()
	assert_array(map.find_path(&"nowhere", &"a")).is_empty()


func test_mover_to_unreachable_room_reports_error_and_stays() -> void:
	# Arrange: the fixture plus one room with no connections
	var data: Dictionary = DATA.duplicate(true)
	data["rooms"].append({"id": "island", "name": "Island", "color": "#ffffff", "pos": [0, 0]})
	var map := StationMap.new()
	map.setup(data)
	var mover := Mover.new(map, &"a", 2.0)
	# Act / Assert
	assert_array(map.find_path(&"a", &"island")).is_empty()
	await assert_error(func() -> void: mover.start_move(&"island")) \
		.is_push_error("Mover: no route from a to island")
	assert_bool(mover.is_moving()).is_false()
	assert_str(mover.room_id).is_equal("a")


# Deliberate exception to the no-file-I/O rule: a data-integrity check on the
# real station data file that the game and stories 004/005 read.
func test_real_station_data_file_has_six_connected_rooms_dorm_and_three_colonists() -> void:
	# Arrange
	var data := StationMap.load_data()
	var map := StationMap.new()
	# Act
	map.setup(data)
	# Assert
	assert_int(map.room_ids.size()).is_equal(6)
	assert_bool(map.has_room(map.dorm_id)).is_true()
	assert_int((data["colonists"] as Array).size()).is_equal(3)
	for id in map.room_ids:
		if id != map.dorm_id:
			assert_array(map.find_path(map.dorm_id, id)).is_not_empty()


# Replacement mover: arrives instantly. Same public surface as Mover.
class TeleportMover extends Mover:
	func start_move(target: StringName) -> void:
		room_id = target
