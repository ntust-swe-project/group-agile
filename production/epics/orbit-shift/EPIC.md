# Epic: Orbit Shift（軌道值班）MVP

> **Workflow**: minimal（無 GDD、ADR、control manifest）
> **Source**: `design/game-brief.md`

**Goal:** 在一座危機逐日升級的太空站上，你不直接操作任何人，只排任務優先序，讓三名會累的殖民者自己撐過 30 天。

**Scope:** brief 的 MVP 6 項：日循環與結束、房間與殖民者、任務與優先序、逐波危機、自動化、結算畫面。

**Order:** 依 brief 的 Build order。2 與 4 可平行，3 等 2 完成。順序與增刪在組內會議定案。

## 整合約定（每張 story 都要遵守）

讓 001、002、004 可以同時開工，最後又能接在一起。改這一節要先在 PR 討論。

**主場景**
- 遊戲進入點是 `src/main.tscn`（根節點 `Main`），由 story 001 建立並設為 `project.godot` 的 `run/main_scene`。
- 每個系統是 `Main` 底下的一個子節點（001 的骨架已預留空節點，由各自的 story 掛上腳本）：`DayCycle`、`StationIntegrity`（001）、`Station`、`Colonists`（002）、`TaskBoard`（003）、`CrisisDirector`（004）、`AutoRepair`（005）、`ResultScreen`（006）。
- 系統之間不互相找節點，只透過下面的共用訊號溝通；需要呼叫對方的方法時，由 `Main` 在 `_ready()` 注入參考。
- 注入：`Main` 的腳本是 `src/main.gd`，不放遊戲邏輯。接收方腳本宣告以來源節點 snake_case 命名的屬性（例如 `var station_integrity: Node`），需要新依賴時在 `main.gd` 的 `INJECTIONS` 加一列。子節點的 `_ready()` 比 `Main` 先跑，所以注入的參考不能在自己的 `_ready()` 裡用。
- 每張 story 完成時，`godot --path .` 開起來就要看得到它的效果，不是只有單元測試過。
- 資料夾：照各 story 的 Files 清單，邏輯腳本放 `src/core/`，畫面與場景放 `src/ui/`，測試放 `tests/unit/core/`；檔名用系統名 snake_case（例如 `day_cycle.gd`）。`main.tscn` 已預留上面 8 個節點，各 story 把腳本掛上對應節點即可：不要改名、搬動或調整順序；需要時可以改節點型別（例如 `ResultScreen` 改成 `CanvasLayer`），也可以在 `Main` 底下另加非系統節點（例如 HUD）。

**共用訊號**：放在 autoload `Events`（`src/core/events.gd`，story 001 建立），只宣告訊號、不放邏輯。

| 訊號 | 誰發出 | 誰會聽 |
| --- | --- | --- |
| `day_started(day: int)` | 001 | 004（排當天危機） |
| `day_ended(day: int)` | 001 | 005（給建造點） |
| `integrity_changed(current: float, max_value: float)` | 001 | UI |
| `game_ended(won: bool, reason: StringName)` | 001 | 006（結算畫面）、所有系統停止 |
| `colonists_collapsed()` | 002 | 001（失敗判定） |
| `crisis_started(crisis_id: int, kind: StringName, room_id: StringName)` | 004 | 002（宿舍是否出事）、003（建立任務）、005 |
| `crisis_resolved(crisis_id: int)` | 004 | 002、UI |
| `task_completed(task_id: int, crisis_id: int)` | 003、005 | 004（停止扣血、標記解決） |

- 危機種類 `kind`：`&"breach"`（隕石破洞）、`&"malfunction"`（設備故障）。程式裡用 `CrisisKind.BREACH`、`CrisisKind.MALFUNCTION`（`src/core/crisis_kind.gd`），不要手打字串。
- 房間 ID 由 002 的資料檔定義，004 與 005 讀同一份。
- 扣完整度：004 呼叫 `StationIntegrity.apply_damage(amount)`（由 `Main` 注入），不透過訊號。

## Stories

| # | Story | Type | Status | ADR |
|---|-------|------|--------|-----|
| 001 | 日循環與結束 | Logic | Ready | N/A (minimal) |
| 002 | 房間與殖民者 | Logic | Ready | N/A (minimal) |
| 003 | 任務與優先序 | Logic | Ready | N/A (minimal) |
| 004 | 逐波危機 | Logic | Ready | N/A (minimal) |
| 005 | 自動化 | Logic | Ready | N/A (minimal) |
| 006 | 結算畫面 | UI | Ready | N/A (minimal) |
