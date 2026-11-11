# Story 007 截圖怎麼重現

三張圖都用 Godot 4.7.2 開 `src/main.tscn`（1920×1080 視窗），由下面的腳本在第 3 幀擺好狀態、第 75 幀截圖。
腳本不在 repo 的 `res://` 內（只用來產生證據），要重拍時存成任意路徑的 `states_s07.gd` 再執行：

```
godot --path . --windowed --resolution 1920x1080 -s <路徑>/states_s07.gd -- <輸出.png> A|B|C
```

| 圖 | 模式 | 擺法 | 看什麼 |
| --- | --- | --- | --- |
| `01-moving-working-resting.png` | A | Ava 從 Bridge 被叫去 Garden；Ben 站在 Lab、Lab 有一個 Malfunction 任務；Cleo 在 Dorm 疲勞滿去休息 | 移動 `>`、工作 `W`、休息 `Z`，疲勞條、面板 Colonists 欄 |
| `02-idle-collapsed-moving.png` | B | Ava 留在 Bridge、沒有任務（正常閒置，疲勞 0）；Ben 在 Dorm 疲勞滿、Dorm 標成有未解危機超過 `collapse_seconds`；Cleo 被叫去 Engine | 閒置 `-`、累垮 `!`、移動 `>` |
| `03-crisis-markers-and-full-task-list.png` | C | 三人分別站在 Storage、Garden、Lab；9 個危機（同房間最多 2 個）讓任務清單超過 7 行 | 殖民者畫在危機標示之上、任務清單 `... +2 more`、面板高度 |

**擺出來的狀態**：累垮在正常遊玩要等宿舍危機持續 15 秒才會出現，所以 B 直接設定 `Colonists._dorm_crisis_ids` 與 `Colonist._blocked_seconds`；C 直接把危機放進 `CrisisDirector.active_crises`。其餘狀態都是遊戲邏輯自己跑出來的。

**已知問題（03）**：同一間房有 2 個危機時，第二個危機標籤（`crisis_markers.gd`，story 004）和殖民者圓點在同一區，會互相重疊。殖民者在上層所以狀態符號看得到，但標籤字會被壓到。危機標示屬於 story 004／008，留給 S08 處理。

```gdscript
# Evidence capture for story 007 (not part of the repo). Args: <out.png> <A|B>
extends SceneTree
var _f := 0
var _out: String
var _mode: String
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0]
	_mode = args[1]
	root.add_child(load("res://src/main.tscn").instantiate())
func _process(_d: float) -> bool:
	_f += 1
	var cs = root.get_node_or_null("Main/Colonists")
	if _f == 3:
		var ava: Colonist = cs.colonists[0]
		var ben: Colonist = cs.colonists[1]
		var cleo: Colonist = cs.colonists[2]
		if _mode == "A":
			# Ava walks bridge -> garden (MOVING), Ben works a task in lab (WORKING), Cleo rests in dorm (RESTING)
			ben.mover.room_id = &"lab"
			cleo.mover.room_id = &"dorm"
			cleo.fatigue = cleo.fatigue_max
			cleo.assign_work(&"dorm")
			cs.command_go_to(0, &"garden")
			root.get_node("Main/TaskBoard").add_task(&"malfunction", &"lab")
		elif _mode == "C":
			# Crisis markers over rooms with colonists, and more than 7 tasks
			var cd = root.get_node("Main/CrisisDirector")
			var ev = root.get_node("/root/Events")
			ava.mover.room_id = &"storage"
			ben.mover.room_id = &"garden"
			cleo.mover.room_id = &"lab"
			var rooms := [&"storage", &"garden", &"lab", &"engine", &"lab", &"bridge", &"storage", &"garden", &"engine"]
			var kinds := [&"breach", &"malfunction", &"breach", &"malfunction", &"malfunction", &"breach", &"malfunction", &"breach", &"breach"]
			for i in rooms.size():
				var id := 500 + i
				ev.crisis_started.emit(id, kinds[i], rooms[i])
				cd.active_crises[id] = Crisis.new(id, kinds[i], rooms[i], 1, 0.0)
				cd._billed_until[id] = 0.0
		else:
			# Ava idle in the bridge (no task exists), Ben collapsed in the dorm, Cleo walking
			ben.mover.room_id = &"dorm"
			ben.fatigue = ben.fatigue_max
			ben.assign_work(&"dorm")
			cs._dorm_crisis_ids[777] = true
			ben.set("_blocked_seconds", 20.0)
			cs.command_go_to(2, &"engine")
	if _f == 75:
		_save()
	return _f > 85
func _save() -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_out)
	var cs = root.get_node("Main/Colonists")
	for c: Colonist in cs.colonists:
		print("STATE ", c.display_name, " ", ColonistStatus.label(ColonistStatus.of(c)), " fatigue=", int(c.fatigue))
```
