# Story 004: 逐波危機

> **Epic**: Orbit Shift（軌道值班）MVP
> **Status**: Complete
> **Issue**: #15
> **Layer**: Feature
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-11-11

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

- [x] 有兩種危機：隕石破洞（外部）與設備故障（內部），各自發生在某個房間
- [x] 隕石破洞發生後，每秒持續扣站體完整度，直到對應的修理任務完成
- [x] 設備故障發生後產生修理任務；未修好時造成的影響為可調參數（例如每秒扣少量完整度）
- [x] 收到 `Events.day_started` 時排當天危機；危機發生時發出 `Events.crisis_started`，收到對應的 `Events.task_completed` 後停止影響並發出 `Events.crisis_resolved`（見 `EPIC.md`「整合約定」）
- [x] 扣完整度透過注入的 `StationIntegrity.apply_damage()`
- [ ] `CrisisDirector` 掛在 `src/main.tscn` 底下，`godot --path .` 開起來看得到危機出現與完整度下降
- [x] 每天的危機數量隨天數增加，數量曲線從資料檔讀取
- [x] 每天至少發生一次危機（每日保底），第 1 天也不例外
- [x] 危機的發生房間與時間點可用固定亂數種子重現，方便測試
- [ ] 畫面在發生危機的房間上標示危機種類

---

## 延後驗收（PO 決定，2026-11-11）

下面兩條的程式已完成並有單元測試，但要等 S01（#12，PR #26）讓 `Main` 發出
`Events.day_started`、HUD 顯示完整度後，畫面上才看得到。PO 決定 S03 先 merge，
這兩條的畫面驗收與截圖延到 PR #26 merge 之後，追蹤：#33。

- AC6：`godot --path .` 開起來看得到危機出現與完整度下降
- AC10：畫面在發生危機的房間上標示危機種類（截圖存 `production/qa/evidence/`）

PR #26 解 conflict 時：`src/main.tscn` 兩邊的 `ext_resource` 與節點都保留；
`.godot/global_script_class_cache.cfg` 用 Godot 重新產生（之後 `git status` 確認
`project.godot` 沒被改寫）。

---

## Implementation Notes

- 危機排程做成可單元測試的類別：輸入天數與亂數種子，輸出當天的危機清單
- 兩種危機都做。機制搭配不好時，試玩後另開 story 修正（持續迭代），不在本 story 砍範圍

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
- 危機標示截圖保留於 `production/qa/evidence/`（延後，見「延後驗收」）

**Status**: [x] 單元測試已建立並通過（全套件 102/102）；危機標示截圖延後，見「延後驗收」

---

## Dependencies

- Depends on: `production/epics/orbit-shift/story-001-day-cycle-and-ending.md`（天數與完整度）；任務清單來自 `production/epics/orbit-shift/story-003-tasks-and-priorities.md`，未完成前可先只產生危機、不接任務
- Unlocks: `production/epics/orbit-shift/story-005-automation.md`

---

## Completion Notes
**Completed**: 2026-11-11
**Criteria**: 8/10 passing；AC6（開起來看得到危機與完整度下降）、AC10（危機標示截圖）DEFERRED，PO 決定延到 PR #26 merge 之後，追蹤 #33
**Deviations**: ADVISORY — `CrisisDirector.day_length` 預設 60.0 寫在程式裡（有注入 `DayCycle` 時會被覆蓋，只是 fallback）；AC5 目前只用假的 integrity 測試，真的 `StationIntegrity` 整合測試列在 #33
**Test Evidence**: Logic：`tests/unit/core/crisis_scheduler_test.gd`（20）、`tests/unit/core/crisis_director_test.gd`（32），全套件 102/102 通過；截圖延後（#33）
**Code Review**: Complete（`/code-review` 2026-11-11，APPROVED WITH SUGGESTIONS，修正見 05ca25f）；solo 模式，未跑 LP-CODE-REVIEW gate
