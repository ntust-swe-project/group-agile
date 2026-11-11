# Story 003: 任務與優先序

> **Epic**: Orbit Shift（軌道值班）MVP
> **Status**: Complete
> **Issue**: #14
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-11-11

## Context

**GDD**: `design/game-brief.md`
**Requirement**: Brief MVP feature 3

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From `design/game-brief.md`, MVP 3 與 Core loop:*

- [ ] 有一個任務清單，任務帶有類型（`breach`、`malfunction`）與所在房間，可被新增與完成
- [ ] 玩家可在畫面上調整每種任務類型的優先序，調整立即生效
- [ ] 空閒且未累垮的殖民者自動挑「優先序最高、尚未被別人認領」的任務；同優先序時挑距離最近的
- [ ] 同一個任務同時只會被一名殖民者認領
- [ ] 殖民者移動到任務房間、工作一段時間（可調參數）後任務完成並從清單移除
- [ ] 殖民者因疲勞離開時，手上的任務釋放回清單，可被其他人認領
- [ ] 玩家不能直接指定某名殖民者去做某件事（間接控制）
- [ ] 畫面顯示任務清單與每名殖民者目前在做什麼
- [ ] 收到 `Events.crisis_started` 時建立對應任務（帶 `crisis_id`）；任務完成時發出 `Events.task_completed`（見 `EPIC.md`「整合約定」）
- [ ] `TaskBoard` 掛在 `src/main.tscn` 底下，`godot --path .` 開起來看得到殖民者依優先序接任務

---

## Implementation Notes

- 任務挑選邏輯做成純函式或可注入的類別，方便單元測試各種優先序與距離組合
- 這是驗證「間接控制好不好玩」的地方，完成後先內部試玩一次

---

## Out of Scope

- Story 004：產生任務的危機（這裡可先用測試或除錯按鈕手動產生任務）
- Story 005：自動修復模組完成任務

---

## Files

- `src/core/task_board.gd` — created (TaskBoard node: tasks, priorities, claiming, work, release, signals)
- `src/core/task_picker.gd` — created (pure task selection: priority, distance, id tie-break)
- `src/core/work_task.gd` — created (WorkTask data)
- `src/ui/priority_panel.tscn`, `src/ui/priority_panel.gd` — created (priority Up/Down, task list, colonist activity, debug add-task buttons until S03)
- `src/core/colonist.gd` — modified (added `clear_work()`)
- `src/core/colonists.gd` — modified (removed the story-002 demo placeholder)
- `src/main.gd` — modified (INJECTIONS row TaskBoard.colonists)
- `src/main.tscn` — modified (script attached to TaskBoard)
- `data/orbit_shift/station.json` — modified (+task_work_seconds, +default_priority, -demo_reassign_seconds)
- `tests/unit/core/task_picker_test.gd` — created
- `tests/unit/core/task_board_test.gd` — created
- `tests/unit/core/colonist_test.gd` — modified (demo keys removed, clear_work test)
- `production/qa/evidence/story-003-tasks-and-priorities/01-priority-panel-with-tasks.png` + `stamp.txt` — evidence

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/core/task_picker_test.gd` — must exist and pass
- 優先序面板截圖保留於 `production/qa/evidence/`

**Status**: [x] Created — `tests/unit/core/task_picker_test.gd`, `tests/unit/core/task_board_test.gd`; screenshots in `production/qa/evidence/story-003-tasks-and-priorities/`

---

## Dependencies

- Depends on: `production/epics/orbit-shift/story-002-rooms-and-colonists.md`
- Unlocks: `production/epics/orbit-shift/story-005-automation.md`

## Completion Notes
**Completed**: 2026-11-11
**Criteria**: 10/10 passing (none deferred)
**Deviations**: ADVISORY — the "no direct assignment" test only checks public method parameter names; ADVISORY — priority panel UI strings are hardcoded English (not localized). Out of scope for awareness: `.godot/global_script_class_cache.cfg` changed by Godot (restore before commit), `.uid` files (commit them), `docs/img/board-example.png.import` (unrelated).
**Test Evidence**: `tests/unit/core/task_picker_test.gd` (8), `tests/unit/core/task_board_test.gd` (21); full suite 77 passed; screenshots `production/qa/evidence/story-003-tasks-and-priorities/01…03`
**Reviewed by**: self, no independent review
