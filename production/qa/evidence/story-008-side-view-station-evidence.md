# Story 008 證據：側視艙段（便宜版）

> **Story**：`production/epics/orbit-shift/story-008-side-view-station.md`（Issue #28）
> **Type**：Visual/Feel　**截圖日期**：2026-11-12　**引擎**：Godot 4.7.2，1920×1080 視窗

## 改版前後

| | 圖 | 看什麼 |
| --- | --- | --- |
| 改版前 | `story-007-colonist-status/01-moving-working-resting.png` | 俯視色塊房間、連線、圓點殖民者 |
| 改版後 | `story-008-side-view-station/01-side-view-walk-work-rest.png` | 上下兩層、每層三間的側視剖面；Ava 同層走向 Engine（`>`）、Ben 在 Lab 舉手工作（`W`）、Cleo 在 Dorm 躺下休息（`Z`）；太空＋星球＋站體的分層靜態背景 |
| 跨樓層 | `story-008-side-view-station/02-cross-floor-stairs.png` | 同一張裡三個進度：Ava（Bridge→Lab，15%）走向樓梯、Ben（Dorm→Storage，50%）在樓梯上、Cleo（Garden→Engine，85%）剛爬出樓梯口；沒有人斜著穿過牆或樓板 |
| 危機標示 | `story-008-side-view-station/03-two-crises-one-room-collapsed.png` | Lab 同時有 BREACH（實線橘框）與 FAULT（虛線藍框，內圈），標籤疊在右上角，不壓到殖民者；Dorm 有 BREACH，Ben 在裡面累垮躺下（`!`）；Engine 有 FAULT |

`stamp.txt` 記錄截圖當下 6 個畫面檔的雜湊；之後這些檔再改，`/story-done` 會提醒重拍。

## 對照驗收條件

| 驗收條件 | 證據 |
| --- | --- |
| 側視剖面、上下兩層各三間，只改 `pos`，ID 與連接不變 | 01；`git diff data/orbit_shift/station.json` 只有 `pos` |
| 向量剪影，分得出站立、行走、躺下 | 01（站立工作、行走、躺下）、03（閒置站立、累垮躺下） |
| 分層靜態背景，不用 `Parallax2D` | 01～03 背景相同不捲動；`src/ui/station_backdrop.gd` |
| 跨樓層沿路徑點移動 | 02；`tests/unit/core/station_path_test.gd`（12 個測試） |
| 007 狀態標示、004 危機標示仍看得到 | 01～03 的符號、疲勞條、底部文字列、面板；03 的危機框與標籤 |
| 危機標示改成側視版，仍照「房間狀態標示」規則 | 03：文字＋實線/虛線區分種類，灰階看得出，不閃爍 |
| CC0 素材列在 `CREDITS.md` | 沒有用外部素材，`CREDITS.md` 明寫「None」 |
| 沒有 3D 節點；不像《缺氧》 | 全部是 2D `_draw`；灰色剖面＋白色剪影，不用缺氧的造型與配色 |
| `godot --path .` 開得起來 | 三張圖都是開 `src/main.tscn` 拍的 |

## 怎麼重現

用下面的腳本開 `src/main.tscn`。第 3 幀凍結 `Colonists`、`TaskBoard`、`CrisisDirector`，接著用 `mover.start_move` 加 `mover.step` 擺好位置，第 40 幀截圖。
腳本不在 repo 裡，要重拍時存成任意路徑的 `states_s08.gd` 再執行：

```
godot --path . --windowed --resolution 1920x1080 -s <路徑>/states_s08.gd -- <輸出.png> A|B|C
```

擺法有兩個前提：
- 停在樓梯中間、累垮、同一間房兩個危機，這三種狀態都是直接設定的。
- 累垮是把 `_blocked_seconds` 設成 20，再發一個 Dorm 的 `crisis_started`。

實際遊玩時，移動、休息和危機都由遊戲邏輯自己跑出來。

```gdscript
# Evidence capture for story 008 (not part of the repo). Args: <out.png> <A|B|C>
extends SceneTree
var _f := 0
var _out: String
var _mode: String
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	_out = args[0]
	_mode = args[1]
	root.add_child(load("res://src/main.tscn").instantiate())
func _hop(c: Colonist, target: StringName, progress: float) -> void:
	c.mover.start_move(target)
	c.mover.step(c.mover.move_seconds * progress)
func _crisis(id: int, kind: StringName, room: StringName) -> void:
	var cd = root.get_node("Main/CrisisDirector")
	root.get_node("/root/Events").crisis_started.emit(id, kind, room)
	cd.active_crises[id] = Crisis.new(id, kind, room, 1, 0.0)
	cd._billed_until[id] = 0.0
func _process(_d: float) -> bool:
	_f += 1
	if _f == 3:
		var cs = root.get_node("Main/Colonists")
		for path in ["Main/Colonists", "Main/TaskBoard", "Main/CrisisDirector"]:
			root.get_node(path).set_process(false)
		var ava: Colonist = cs.colonists[0]
		var ben: Colonist = cs.colonists[1]
		var cleo: Colonist = cs.colonists[2]
		if _mode == "A":
			_hop(ava, &"engine", 0.5)
			ben.mover.room_id = &"lab"
			ben.assign_work(&"lab")
			cleo.mover.room_id = &"dorm"
			cleo.fatigue = cleo.fatigue_max
			cleo.assign_work(&"lab")
		elif _mode == "B":
			_hop(ava, &"lab", 0.15)
			ben.mover.room_id = &"dorm"
			_hop(ben, &"storage", 0.5)
			cleo.mover.room_id = &"garden"
			_hop(cleo, &"engine", 0.85)
		else:
			ava.mover.room_id = &"lab"
			ava.assign_work(&"lab")
			cleo.mover.room_id = &"lab"
			ben.mover.room_id = &"dorm"
			ben.fatigue = ben.fatigue_max
			ben.assign_work(&"lab")
			_crisis(901, CrisisKind.BREACH, &"lab")
			_crisis(902, CrisisKind.MALFUNCTION, &"lab")
			_crisis(903, CrisisKind.BREACH, &"dorm")
			_crisis(904, CrisisKind.MALFUNCTION, &"engine")
			ben.set("_blocked_seconds", 20.0)
	if _f == 40:
		_save()
	return _f > 50
func _save() -> void:
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_out)
```

## 已知限制（不擋這張）

- 截圖只能證明靜態畫面。走路擺動的頻率（每格兩步，約 1.3 Hz）好不好看，要在試玩時判斷。
- Lab 的樓梯有一小段會被危機標籤蓋住，但兩邊都還看得出來。
- 站位用的是殖民者的全域序號。殖民者超過 4 人時會超出房間寬度，目前只有 3 人。

## 簽核

| 角色 | 簽核 | 誰 | 日期 |
| --- | --- | --- | --- |
| 美術／畫面負責人 | [x] Approved | eden2289（實際開 `godot --path .` 試玩後同意） | 2026-11-12 |
