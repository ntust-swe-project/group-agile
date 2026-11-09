---
name: board
description: "Shows the team board from GitHub Issues: the story you hold, the stories free to claim in PO order, who is on what, PRs waiting for review, and your next step. Use when the user asks for project status, what to work on next, which stories are available, or what they currently hold."
allowed-tools: Bash(bash .claude/team/team.sh board*)
---

# /board — 團隊看板

## 看板（剛從 GitHub 抓的）

!`bash "${CLAUDE_SKILL_DIR}/../../team/team.sh" board`

## 怎麼回答

1. 用繁體中文、幾行字回答使用者：**你手上有什麼**、**下一張可以拿的是哪張**、**其他人在做什麼**、**有沒有 PR 等你 review**。
2. 最後一行照看板的「下一步」給一個具體建議（例如「用 `/claim-story` 認領 #13」）。
3. 只講看板上有的內容，不要自己補 story。看板顯示 `NOT ASSESSED` 時，說明原因（多半是 `gh` 沒裝或沒 `gh auth login`）並請使用者修好，不要猜狀態。
4. 規則依據：`docs/PROCESS.md`。
