# Story 008: 側視艙段（便宜版）

> **Epic**: Orbit Shift（軌道值班）MVP
> **Status**: Complete
> **Issue**: #28
> **Layer**: Presentation
> **Type**: Visual/Feel
> **Estimate**: M
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: 2026-11-12

## Context

**GDD**: `design/game-brief.md`
**Requirement**: Proposal #25（PO 判定：拆成 008、009，demo 後再做）；非 brief MVP 項目，由 PO 依提案新增

**ADR Governing Implementation**: N/A (minimal — no ADRs)
**ADR Decision Summary**: N/A (minimal — no ADRs)
**ADR Version**: N/A (minimal — no ADRs)

**Engine**: Godot 4.7.2 | **Risk**: HIGH
**Engine Notes**: none (no ADR engine-compatibility analysis at minimal)

**Control Manifest Rules (this layer)**: N/A (minimal — no control manifest)

---

## Acceptance Criteria

*From Issue #25 的 PO 判定（VISION §2、§3.1、§5、§6）:*

- [ ] 房間改成側視剖面排列（例如上下兩層、每層三間），只改 `station.json` 的房間位置，房間 ID 與連接不變
- [ ] 殖民者用向量剪影或 CC0 側視角色呈現，分得出站立、行走、躺下（躺下可用旋轉）
- [ ] 背景用分層靜態圖（太空、站體），不用 `Parallax2D` 捲動
- [ ] 跨樓層移動不會斜向飄過去：沿路徑點移動（走到樓梯、上下樓、再走）
- [ ] story 007 的狀態標示與 story 004 的危機標示在新畫面上仍看得到
- [ ] 危機標示改成符合側視美術的呈現，取代 `src/ui/crisis_markers.gd` 的佔位版（`TODO(008)`）；仍照 `EPIC.md`「房間狀態標示」規則（不只靠顏色、灰階分得出、不閃爍或低於 3 Hz）
- [ ] CC0 素材在 `CREDITS.md` 列出來源與授權
- [ ] 遊戲內沒有 3D 節點或 3D 相機；不重現《缺氧》的造型與配色
- [ ] `godot --path .` 開起來看得到側視艙段與殖民者移動

---

## Implementation Notes

- 畫面是靜態的，分層靜態圖即可得到大部分景深感
- 路徑點只在畫面層計算，不改 `Mover` 的房間圖邏輯
- 這張的版本要能被 story 009 的預渲染角色替換

---

## Out of Scope

- Story 009：預渲染 3D 角色動畫
- 新的房間、走廊或可互動的場景物件

---

## Files

- `data/orbit_shift/station.json` — modified (room `pos` only: two floors of three rooms; ids and connections unchanged)
- `src/ui/station_view.gd` — modified (side-view cutaway rooms, doorways, stairwells drawn after rooms, colonists via ColonistFigure and StationPath)
- `src/ui/crisis_markers.gd` — rewritten (side-view markers: rings inside the room, labels stacked top-right; TODO(008) removed)
- `src/ui/station_path.gd` — created (StationPath: view-only waypoints for a hop, stairs between floors)
- `src/ui/colonist_figure.gd` — created (ColonistFigure: vector silhouette standing / walking / lying; the one place story 009 replaces)
- `src/ui/station_backdrop.gd` — created (StationBackdrop: layered static space and hull background, no Parallax2D)
- `CREDITS.md` — created (no external assets)
- `tests/unit/core/station_path_test.gd` — created (12 tests)
- `.godot/global_script_class_cache.cfg` — regenerated (new class_names)
- `production/qa/evidence/story-008-side-view-station/` 01…03 + `stamp.txt`, `production/qa/evidence/story-008-side-view-station-evidence.md` — evidence and sign-off

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**:
- Visual/Feel: 改版前後截圖與殖民者跨樓層移動的截圖，保留於 `production/qa/evidence/`，並由負責人簽核

**Status**: [x] Created — screenshots in `production/qa/evidence/story-008-side-view-station/`, sign-off in `production/qa/evidence/story-008-side-view-station-evidence.md`; `tests/unit/core/station_path_test.gd` (12 tests)

---

## Dependencies

- Depends on: `production/epics/orbit-shift/story-002-rooms-and-colonists.md`, `production/epics/orbit-shift/story-004-escalating-crises.md`, `production/epics/orbit-shift/story-007-colonist-status.md`
- Unlocks: `production/epics/orbit-shift/story-009-prerendered-colonists.md`

## Completion Notes
**Completed**: 2026-11-12
**Criteria**: 9/9 passing (none deferred; the feel of the walk cycle was judged in a play session by the owner)
**Deviations**: ADVISORY — view constants (room size, colours, stairs position, silhouette size) live in `station_view.gd`, `colonist_figure.gd`, `crisis_markers.gd`, not in a data file; they are looks, not game values. OUT OF SCOPE — the story's `## Files` once listed `assets/art/station/`, unused because everything is code-drawn; `docs/img/board-example.png.import` is unrelated and stays uncommitted. Known limits: lying colonists and stairs can sit under a crisis label in Lab; colonist spots use the global index, so more than 4 colonists would leave the room width.
**Test Evidence**: `production/qa/evidence/story-008-side-view-station/01…03` + `stamp.txt` (all UNCHANGED), sign-off `production/qa/evidence/story-008-side-view-station-evidence.md` `[x] Approved`; `tests/unit/core/station_path_test.gd` (12); full suite 202/202
**Reviewed by**: self, no independent review (a godot-gdscript-specialist 4.7 check ran during /dev-story)
