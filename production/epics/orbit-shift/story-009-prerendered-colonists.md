# Story 009: 預渲染殖民者動畫

> **Epic**: Orbit Shift（軌道值班）MVP
> **Status**: Ready
> **Issue**: #29
> **Layer**: Presentation
> **Type**: Visual/Feel
> **Estimate**: L
> **Manifest Version**: N/A (minimal — no control manifest)
> **Last Updated**: —

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

*From Issue #25 的 PO 判定（VISION §3.1、§5、§6）:*

- [ ] **先試做**：1 名角色、1 個動作（走路）從 Meshy 生成到在遊戲裡播放，限時 2 小時；不可行就停，在本檔 Completion Notes 寫下原因並保留 story 008 的版本，本 story 即完成
- [ ] 3 名殖民者風格一致（從同一張參考圖生成）
- [ ] 站立、走路、躺下 3 個動作，用側面固定相機渲染成透明背景 sprite sheet，遊戲內用 `AnimatedSprite2D` 播放
- [ ] 狀態對應動作：移動＝走、工作＝站、休息或累垮＝躺（累垮加 `!`），使用 story 007 的狀態判斷函式
- [ ] 遊戲內沒有 3D 節點或 3D 相機；3D 原始檔（`.glb`、`.blend`）不放在 `res://` 內，或所在資料夾加 `.gdignore`
- [ ] Meshy 生成物記 ai-log，`docs/ai-log/README.md` 新增揭露列，相關 commit 加 `Assisted-by: Meshy:<模型>`
- [ ] `godot --path .` 開起來看得到 3 名殖民者依狀態播放對應動作

---

## Implementation Notes

- `AnimatedSprite2D`、`SpriteFrames` 不在 `docs/engine-reference/godot/` 內，使用前對照 Godot 4.7 文件，未驗證的在 ai-log 標 `unverified`
- 「躺下」動畫是否有現成的尚未確認；沒有就用試做結果決定是否手做或停在 story 008
- 渲染建議約 2 倍解析度再縮小，背景透明

---

## Out of Scope

- 遊戲內 3D 表現（VISION §5、§6）
- 表情、對話、個性等新機制

---

## Files

- `src/ui/station_view.gd`
- `assets/art/colonists/`（sprite sheet 與 `SpriteFrames`）
- `docs/ai-log/README.md`

---

## QA Test Cases

*N/A — no qa-lead specs at this tier; implement against the Acceptance Criteria above*

---

## Test Evidence

**Story Type**: Visual/Feel
**Required evidence**:
- Visual/Feel: 3 種動作的截圖或錄影，保留於 `production/qa/evidence/`，並由負責人簽核；試做不可行時改為 Completion Notes 的原因說明

**Status**: [ ] Not yet created

---

## Dependencies

- Depends on: `production/epics/orbit-shift/story-007-colonist-status.md`, `production/epics/orbit-shift/story-008-side-view-station.md`
- Unlocks: None
