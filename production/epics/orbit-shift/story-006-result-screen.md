# Story 006: 結算畫面

> **Epic**: Orbit Shift（軌道值班）MVP
> **Status**: Complete
> **Issue**: #17
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: S
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-11-12

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

- [x] 收到 `Events.game_ended` 時顯示結算畫面（見 `EPIC.md`「整合約定」）
- [x] 顯示結果：勝利，或失敗與失敗原因（完整度歸零／殖民者全員累垮）
- [x] 顯示存活天數與剩餘完整度
- [x] 顯示每名殖民者的名字與最後狀態；002 還沒 merge 時顯示「—」，不報錯
- [x] 有「再玩一次」按鈕，按下後重新開始一場
- [x] `ResultScreen` 掛在 `src/main.tscn` 底下，`godot --path .` 開起來玩到結束就看得到

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

- `src/ui/result_screen.tscn` — created（`CanvasLayer` 第 10 層、遮罩、不透明面板、`Play again` 按鈕）
- `src/ui/result_screen.gd` — created（`summary_lines()` 純函式、`restart()`、收到 `game_ended` 才顯示）
- `src/main.gd` — modified（`INJECTIONS` 加 `ResultScreen` 三列：`day_cycle`、`station_integrity`、`colonists`）
- `src/main.tscn` — modified（`ResultScreen` 節點套用 `result_screen.tscn`）
- `tests/unit/core/result_screen_test.gd` — created（19 個測試）
- `production/qa/evidence/story-006-result-screen/` — evidence（勝利、失敗截圖與 `repro.md`）

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: UI
**Required evidence**:
- UI: 勝利與失敗兩種結算畫面的截圖，保留於 `production/qa/evidence/`

**Status**: [x] Created — 截圖與 `repro.md` 在 `production/qa/evidence/story-006-result-screen/`；單元測試 `tests/unit/core/result_screen_test.gd`（19 個）

---

## Dependencies

- Depends on: `production/epics/orbit-shift/story-001-day-cycle-and-ending.md`
- Unlocks: None

## Completion Notes
**Completed**: 2026-11-12
**Criteria**: 6/6 passing (none deferred)
**Deviations**: ADVISORY — 畫面文字寫死為英文，沒有走在地化（MVP 沒有在地化系統，預設字型沒有中文字，HUD 與面板同樣為英文）；`restart()` 重新載入場景的行為沒有單元測試（會連測試場景一起重載），目前靠按鈕連線測試加上探針腳本驗證；勝利截圖用探針把天數直接設成 30，左上角 HUD 因此寫 `Day 1 / 30`（`repro.md` 已說明）。「存活天數」失敗時不算出事的那一天，為實作時的決定，story 未規定。Out of scope for awareness: `.godot/global_script_class_cache.cfg` 只有排列順序改變、不帶進本次 commit
**Test Evidence**: UI：截圖 `production/qa/evidence/story-006-result-screen/01-victory.png`、`02-station-lost.png`（面板改不透明後重拍）、`repro.md`；`tests/unit/core/result_screen_test.gd`（19 個）；全套件 210/210
**Code Review**: Complete（`/code-review` 2026-11-12，GDScript、Godot、QA 三個 specialist，APPROVED WITH SUGGESTIONS，6 點已修正）；solo 模式，未跑 LP-CODE-REVIEW gate
