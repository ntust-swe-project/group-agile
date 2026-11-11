# Story 001: 日循環與結束

> **Epic**: Orbit Shift（軌道值班）MVP
> **Status**: Complete
> **Issue**: #12
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-11-11

## Context

**GDD**: `design/game-brief.md`
**Requirement**: Brief MVP feature 1

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From `design/game-brief.md`, MVP 1 與 Player goal & fail state:*

- [ ] 遊戲從第 1 天開始，每天長度為可調參數（預設約 60 秒），時間到自動進入下一天，並發出「新的一天」訊號
- [ ] 畫面持續顯示目前天數（例如 `Day 7 / 30`）與站體完整度
- [ ] 站體完整度有上限，只會被扣減（修好危機只是停止扣，不會補回），數值不會低於 0
- [ ] 完整度降到 0 時立即判定失敗並停止時間推進
- [ ] 提供「殖民者全員崩潰」的失敗判定入口，觸發時立即判定失敗（實際條件由 story 002 接上）
- [ ] 第 30 天結束時判定勝利
- [ ] 勝敗判定後發出 `Events.game_ended` 並停止時間推進（結算畫面由 story 006 負責）
- [ ] 天數長度、總天數、完整度上限都從資料檔讀取，不寫死在程式碼
- [ ] 建立 `src/main.tscn` 並設為 `project.godot` 的 `run/main_scene`，`DayCycle`、`StationIntegrity` 是它的子節點
- [ ] 建立 autoload `Events`，宣告 `EPIC.md`「整合約定」列出的全部訊號（其他 story 不必再改這個檔）
- [ ] 發出 `day_started`、`day_ended`、`integrity_changed`、`game_ended`；收到 `colonists_collapsed` 判定失敗
- [ ] `godot --path .` 開起來看得到天數推進與完整度

---

## Implementation Notes

- 日循環與勝敗判定做成可單元測試的邏輯類別，時間由外部注入（測試時可直接推進），不依賴真實時間
- 結算畫面不在本 story，見 story 006

---

## Out of Scope

- Story 002：殖民者狀態本身（這裡只留失敗判定入口）
- Story 004：扣完整度的危機

---

## Files

- `src/main.tscn`
- `src/core/game_config.gd`
- `src/core/day_cycle.gd`
- `src/core/station_integrity.gd`
- `src/ui/hud.gd`
- `assets/data/game_config.json`
- `tests/unit/core/day_cycle_test.gd`
- `tests/fixtures/game_config/valid.json`
- `tests/fixtures/game_config/not_json.json`
- `tests/fixtures/game_config/invalid_values.json`

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/core/day_cycle_test.gd` — must exist and pass
- 天數與完整度畫面截圖保留於 `production/qa/evidence/`（玩家看得到的變更，依 coding-standards 需截圖）

**Status**: [x] Created and passing (2026-11-11)
- `tests/unit/core/day_cycle_test.gd`（DayCycle、StationIntegrity、GameConfig；設定檔 fixture 在 `tests/fixtures/game_config/`）。完整套件 43/43 通過。
- 截圖（`production/qa/evidence/story-001-day-cycle-and-ending/`）：
  - `01-day-and-integrity.png`：Day 1 / 30，Integrity 100 / 100
  - `02-day2-integrity-full.png`：Day 2 / 30，Integrity 100 / 100
  - `03-day2-integrity-after-damage.png`：Day 2 / 30，Integrity 75 / 100
  - `04-day3.png`：Day 3 / 30，Integrity 75 / 100
  - 02～04 是用暫時的包裝場景把每天縮成 3 秒拍的（已刪除，設定檔未改動）

---

## Dependencies

- Depends on: None
- Unlocks: `production/epics/orbit-shift/story-004-escalating-crises.md`, `production/epics/orbit-shift/story-005-automation.md`, `production/epics/orbit-shift/story-006-result-screen.md`

---

## Completion Notes
**Completed**: 2026-11-11
**Criteria**: 12/12 passing (none deferred)
**Deviations**:
- ADVISORY: `day_cycle.gd` 與 `station_integrity.gd` 的欄位預設值（60.0、30、100.0）與資料檔重複；設定載入失敗時才會留下。
- ADVISORY: HUD 文字（`hud.gd:39`）與字級（`main.tscn:35-36`）寫死；專案目前沒有在地化系統。
- 多出的 `src/core/game_config.gd`（三個節點共用的設定載入與驗證）與 `tests/fixtures/game_config/`（測試 fixture），已列入 `## Files`。
- 未做的 code-review 建議：HUD 格式化函式與測試；story 004 注意 `day_started(1)` 發出時 `StationIntegrity` 尚未用設定檔上限初始化。
**Test Evidence**: `tests/unit/core/day_cycle_test.gd`（完整套件 43/43 通過）；截圖 `production/qa/evidence/story-001-day-cycle-and-ending/01`～`04`
**Reviewed by**: self, no independent review（solo 模式，review gate 已跳過）；對話中另跑過 `/code-review` 兩輪（APPROVED WITH SUGGESTIONS，必修的 W1 已修）
