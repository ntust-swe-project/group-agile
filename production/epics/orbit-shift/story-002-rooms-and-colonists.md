# Story 002: 房間與殖民者

> **Epic**: Orbit Shift（軌道值班）MVP
> **Status**: Ready
> **Issue**: #13
> **Layer**: Core
> **Type**: Logic
> **Estimate**: M
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: —

## Context

**GDD**: `design/game-brief.md`
**Requirement**: Brief MVP feature 2

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From `design/game-brief.md`, MVP 2 與 Player goal & fail state:*

- [ ] 太空站由 6 個房間組成，房間之間的連接關係從資料檔讀取，其中一間是宿舍
- [ ] 畫面以色塊與文字顯示 6 個房間、連接線，以及每名殖民者目前所在的房間
- [ ] 遊戲開始時有 3 名殖民者，各自有名字與疲勞值
- [ ] 殖民者移動到相鄰房間需花固定秒數（可調參數），移動期間不能工作；到非相鄰房間依連接圖逐間移動
- [ ] 殖民者工作時疲勞上升、在宿舍休息時下降，上升與下降速度為可調參數
- [ ] 疲勞達上限時，殖民者放下手邊工作、自己前往宿舍休息，恢復到門檻以下才回去工作
- [ ] `Station`、`Colonists` 掛在 `src/main.tscn` 底下，`godot --path .` 開起來看得到房間與殖民者移動、疲勞變化
- [ ] 「累垮」＝疲勞達上限後，因為宿舍有未修好的危機（破洞或故障）而無法開始休息，持續超過 N 秒（可調參數）；正常去宿舍休息不算累垮
- [ ] 3 名殖民者同時處於累垮狀態時發出 `Events.colonists_collapsed`（見 `EPIC.md`「整合約定」）
- [ ] 移動邏輯集中在單一元件處理，之後可替換成沿走廊行走（A 方案佔位）而不必改殖民者其他邏輯

---

## Implementation Notes

- 房間圖、殖民者狀態做成可單元測試的邏輯類別；表現層只讀取狀態
- 累垮的 N 秒寫在資料檔；宿舍是否「有未修好的危機」從 `Events.crisis_started` / `crisis_resolved` 判斷

---

## Out of Scope

- Story 003：殖民者挑選任務的決策（這裡只做「去某房間」與疲勞）
- 沿走廊行走的移動動畫（範圍外，A 方案佔位）

---

## Files

- `src/core/station_map.gd`
- `src/core/colonist.gd`
- `src/core/mover.gd`
- `src/ui/station_view.tscn`
- `tests/unit/core/colonist_test.gd`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Logic
**Required evidence**:
- Logic: `tests/unit/core/colonist_test.gd` — must exist and pass
- 太空站畫面截圖保留於 `production/qa/evidence/`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: None（失敗判定入口由 `production/epics/orbit-shift/story-001-day-cycle-and-ending.md` 提供，可先用替身接上）
- Unlocks: `production/epics/orbit-shift/story-003-tasks-and-priorities.md`
