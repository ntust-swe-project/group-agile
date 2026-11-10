# Story 005: 自動化

> **Epic**: Orbit Shift（軌道值班）MVP
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: S
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: —

## Context

**GDD**: `design/game-brief.md`
**Requirement**: Brief MVP feature 5

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From `design/game-brief.md`, MVP 5 與 Core loop:*

- [ ] 每撐過一天，玩家獲得 1 點建造點，畫面顯示目前點數
- [ ] 玩家可花建造點在指定房間蓋一座「自動修復模組」，點數不足時不能蓋
- [ ] 同一房間最多一座模組
- [ ] 有模組的房間發生設備故障時，模組在一段時間（可調參數）後自動完成該修理任務，期間殖民者仍可搶先完成
- [ ] 模組不處理隕石破洞（破洞仍需殖民者）
- [ ] 畫面在有模組的房間上標示模組
- [ ] 收到 `Events.day_ended` 時加建造點；聽 `Events.crisis_started` 找有模組房間的故障，修好時發出 `Events.task_completed`（見 `EPIC.md`「整合約定」）
- [ ] `AutoRepair` 掛在 `src/main.tscn` 底下，`godot --path .` 開起來能蓋模組並看到它自動修復

---

## Implementation Notes

- 建造點與模組邏輯做成可單元測試的類別；費用與修復時間從資料檔讀取

---

## Out of Scope

- 其他種類的自動化設施、模組升級或拆除

---

## Files

- `src/core/build_points.gd`
- `src/core/auto_repair_module.gd`
- `tests/unit/core/auto_repair_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/core/auto_repair_test.gd` — must exist and pass
- 模組標示截圖保留於 `production/qa/evidence/`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/orbit-shift/story-001-day-cycle-and-ending.md`, `production/epics/orbit-shift/story-003-tasks-and-priorities.md`, `production/epics/orbit-shift/story-004-escalating-crises.md`
- Unlocks: None
