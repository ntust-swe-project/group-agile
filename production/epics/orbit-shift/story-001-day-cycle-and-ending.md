# Story 001: 日循環與結束

> **Epic**: Orbit Shift（軌道值班）MVP
> **Status**: Ready
> **Layer**: Foundation
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: —

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
- [ ] 站體完整度有上限，可被扣減與回補，數值不會低於 0 或超過上限
- [ ] 完整度降到 0 時立即判定失敗並停止時間推進
- [ ] 提供「殖民者全員崩潰」的失敗判定入口，觸發時立即判定失敗（實際條件由 story 002 接上）
- [ ] 第 30 天結束時判定勝利
- [ ] 不論勝敗都切到結算畫面，顯示：結果、存活天數、剩餘完整度、殖民者狀態摘要
- [ ] 天數長度、總天數、完整度上限都從資料檔讀取，不寫死在程式碼

---

## Implementation Notes

- 日循環與勝敗判定做成可單元測試的邏輯類別，時間由外部注入（測試時可直接推進），不依賴真實時間
- 結算畫面先用純文字 wireframe

---

## Out of Scope

- Story 002：殖民者狀態本身（這裡只留失敗判定入口與結算欄位）
- Story 004：扣完整度的危機

---

## Files

- `src/core/day_cycle.gd`
- `src/core/station_integrity.gd`
- `src/ui/result_screen.tscn`
- `tests/unit/core/day_cycle_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/core/day_cycle_test.gd` — must exist and pass
- 結算畫面截圖保留於 `production/qa/evidence/`（玩家看得到的變更，依 coding-standards 需截圖）

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None
- Unlocks: `production/epics/orbit-shift/story-004-escalating-crises.md`, `production/epics/orbit-shift/story-005-automation.md`
