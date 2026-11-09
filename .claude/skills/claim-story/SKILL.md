---
name: claim-story
description: "Claims a story for the user: checks the one-card WIP limit and PO order, assigns the GitHub issue, and creates the feat/<issue>-<name> branch from the latest main. Use when the user wants to start a story, take the next card, or pick up issue #N. Run before /dev-story."
argument-hint: "[issue-number]"
allowed-tools: Read, AskUserQuestion, Bash(bash .claude/team/team.sh board*), Bash(bash .claude/team/team.sh claim*)
---

# /claim-story — 認領 story

規則依據 `docs/PROCESS.md`：每人同時最多 1 張；拿排序最上面那張；跳過要先問 PO。

## 目前看板

!`bash "${CLAUDE_SKILL_DIR}/../../team/team.sh" board`

## 步驟

1. **決定要拿哪張。**
   - 使用者沒指定編號：拿看板上「可以拿」的第 1 張。
   - 使用者指定的編號不是第 1 張：問使用者「PO 同意跳過排序了嗎？」。只有使用者明確說 PO 同意，才在下一步加 `--po-ok`。
2. **執行認領**（會檢查 WIP、assign、從最新 `origin/main` 開 branch）：
   `bash .claude/team/team.sh claim [編號] [--po-ok]`
3. **看結果。**
   - `FAIL`：把原因告訴使用者並停下。不要手動 assign、不要自己開 branch 繞過。
   - `NOT ASSESSED`：通常是 `gh` 沒裝或沒登入，請使用者先處理。
   - `OK`：讀輸出裡的 story 檔，用 3～5 行摘要驗收條件與 Type（Logic 要寫測試、UI/Visual 要截圖）。
4. **下一步**：問使用者是否要開始 `/dev-story <story 檔路徑>`。做完後的流程是 `/code-review` → `/story-done` → `/ship-story`。
