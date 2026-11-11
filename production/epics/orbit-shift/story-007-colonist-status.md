# Story 007: 殖民者狀態可見

> **Epic**: Orbit Shift（軌道值班）MVP
> **Status**: Ready
> **Issue**: #27
> **Layer**: Presentation
> **Type**: UI
> **Estimate**: S
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: —

## Context

**GDD**: `design/game-brief.md`
**Requirement**: Proposal #23（PO 判定：精簡版）＋ Proposal #22 未完成部分（字級）；非 brief MVP 項目，由 PO 依提案新增

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From Issue #23 與 #22 的 PO 判定（VISION §3.1、§3.4）:*

- [ ] 每名殖民者顯示目前狀態：移動、工作、休息、閒置、累垮，不靠顏色也分得出（文字或符號，例如 `→`／`W`／`Z`／`.`／`!`）
- [ ] 狀態優先順序：累垮 > 移動 > 工作／休息／閒置；累垮用 `Colonist.is_collapsed()`，畫面不另外計時
- [ ] 移動中的殖民者不再顯示成 `WORKING`
- [ ] 每名殖民者頭上有疲勞條，長度對應 0～`fatigue_max`，用中性色（不用黃→紅，避免與 `EPIC.md`「房間狀態標示」的危機顏色撞色）
- [ ] 殖民者狀態文字與房名至少 24px，在 1920×1080 下不模糊
- [ ] 狀態判斷抽成可單元測試的函式，story 009 會共用
- [ ] S04 優先序面板（`src/ui/priority_panel.gd`）的 Colonists 欄改用同一個狀態判斷函式、字級至少 24px，畫面上不會有兩套不一致的狀態顯示（任務資訊如 `Going to Lab (Breach)` 可以保留）
- [ ] 只改顯示，不改 `Colonist`／`Colonists`／`TaskBoard` 的邏輯；`godot --path .` 開起來看得到 5 種狀態

---

## Implementation Notes

- 從現有狀態推算：`is_collapsed()` → 累垮；`mover.is_moving()` → 移動；否則依 `state`（`WORKING`／`RESTING`／`IDLE`）為工作、休息或閒置
- `IDLE` 在 S04 之後很常見：沒任務的殖民者會停在原地等任務
- 不做頭像、心情、個性；「換成走、站、躺動畫」屬 story 009
- 上方左側留給 story 001 的 HUD，不要和它重疊

---

## Out of Scope

- Story 008：側視艙段與角色剪影
- Story 009：預渲染角色動畫
- 危機與模組的房間標示（`EPIC.md`「房間狀態標示」，story 004、005）

---

## Files

- `src/ui/station_view.gd`
- `src/ui/colonist_status.gd`
- `src/ui/priority_panel.gd`（S04 面板的 Colonists 欄）
- `tests/unit/core/colonist_status_test.gd`（照 `EPIC.md`「整合約定」，測試放 `tests/unit/core/`）

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: UI
**Required evidence**:
- UI: 移動、工作、休息、閒置、累垮 5 種狀態各一張截圖（含優先序面板），保留於 `production/qa/evidence/`
- 狀態判斷函式：`tests/unit/core/colonist_status_test.gd`

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/orbit-shift/story-002-rooms-and-colonists.md`
- Unlocks: `production/epics/orbit-shift/story-009-prerendered-colonists.md`
