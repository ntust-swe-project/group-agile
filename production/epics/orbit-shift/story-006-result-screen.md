# Story 006: 結算畫面

> **Epic**: Orbit Shift（軌道值班）MVP
> **Status**: Ready
> **Issue**: #17
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: S
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: —

## Context

**GDD**: `design/game-brief.md`
**Requirement**: Brief MVP feature 6

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From `design/game-brief.md`, MVP 6 與 Player goal & fail state:*

- [ ] 收到 `Events.game_ended` 時顯示結算畫面（見 `EPIC.md`「整合約定」）
- [ ] 顯示結果：勝利，或失敗與失敗原因（完整度歸零／殖民者全員累垮）
- [ ] 顯示存活天數與剩餘完整度
- [ ] 顯示每名殖民者的名字與最後狀態；002 還沒 merge 時顯示「—」，不報錯
- [ ] 有「再玩一次」按鈕，按下後重新開始一場
- [ ] `ResultScreen` 掛在 `src/main.tscn` 底下，`godot --path .` 開起來玩到結束就看得到

---

## Implementation Notes

- 純文字 wireframe，不做美術
- 需要的數值由 `Main` 注入 `DayCycle`、`StationIntegrity`、`Colonists` 的參考來讀，不自己找節點

---

## Out of Scope

- 跨場次紀錄、排行榜（VISION §6 範圍外）
- 計分公式（之後試玩再決定要不要加）

---

## Files

- `src/ui/result_screen.tscn`
- `src/ui/result_screen.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: UI
**Required evidence**:
- UI: 勝利與失敗兩種結算畫面的截圖，保留於 `production/qa/evidence/`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/orbit-shift/story-001-day-cycle-and-ending.md`
- Unlocks: None
