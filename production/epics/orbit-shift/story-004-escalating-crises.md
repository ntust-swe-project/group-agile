# Story 004: 逐波危機

> **Epic**: Orbit Shift（軌道值班）MVP
> **Status**: Ready
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: —

## Context

**GDD**: `design/game-brief.md`
**Requirement**: Brief MVP feature 4

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From `design/game-brief.md`, MVP 4 與 Core loop:*

- [ ] 有兩種危機：隕石破洞（外部）與設備故障（內部），各自發生在某個房間
- [ ] 隕石破洞發生後，每秒持續扣站體完整度，直到對應的修理任務完成
- [ ] 設備故障發生後產生修理任務；未修好時造成的影響為可調參數（例如每秒扣少量完整度）
- [ ] 每種危機發生時都會在任務清單新增對應任務
- [ ] 每天的危機數量隨天數增加，數量曲線從資料檔讀取
- [ ] 每天至少發生一次危機（每日保底），第 1 天也不例外
- [ ] 危機的發生房間與時間點可用固定亂數種子重現，方便測試
- [ ] 畫面在發生危機的房間上標示危機種類

---

## Implementation Notes

- 危機排程做成可單元測試的類別：輸入天數與亂數種子，輸出當天的危機清單
- 若時間不夠，先做隕石破洞，設備故障第二

---

## Out of Scope

- 通訊中斷、動態調壓、其他危機種類（brief 範圍外）
- Story 005：自動修復

---

## Files

- `src/core/crisis_scheduler.gd`
- `src/core/crisis.gd`
- `assets/data/crisis_curve.tres`
- `tests/unit/core/crisis_scheduler_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/core/crisis_scheduler_test.gd` — must exist and pass
- 危機標示截圖保留於 `production/qa/evidence/`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/orbit-shift/story-001-day-cycle-and-ending.md`（天數與完整度）；任務清單來自 `production/epics/orbit-shift/story-003-tasks-and-priorities.md`，未完成前可先只產生危機、不接任務
- Unlocks: `production/epics/orbit-shift/story-005-automation.md`
