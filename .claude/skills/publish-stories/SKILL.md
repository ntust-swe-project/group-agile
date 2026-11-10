---
name: publish-stories
description: "PO only: turns the story files that /create-stories wrote for an epic into GitHub issues labelled story, numbered S01, S02… in build order, and writes each issue number back into its story file. Use after /create-stories, when the PO wants the backlog on GitHub."
argument-hint: "[epic-slug | production/epics/<epic>]"
allowed-tools: Read, Glob, AskUserQuestion, Bash(bash .claude/team/team.sh publish*), Bash(bash .claude/team/team.sh board*), Bash(ls production/epics*)
---

# /publish-stories — 把 story 開成 issue（PO）

規則依據 `docs/PROCESS.md`「Backlog 怎麼表示」。

## 步驟

1. 確認使用者是 PO（yichieh-chen）。不是的話提醒：backlog 由 PO 維護，請 PO 執行。
2. 找 epic 資料夾：參數是 slug 就用 `production/epics/<slug>`；沒給就 `ls production/epics` 讓使用者選。
3. 先預覽：`bash .claude/team/team.sh publish production/epics/<epic> --dry-run`。把會建立的 issue（標題、順序）給使用者看。已經有 `Issue` 欄位的 story 會被略過。
4. 使用者確認後才執行：`bash .claude/team/team.sh publish production/epics/<epic>`。會建立 `story`、`blocked` label（如果還沒有）、開 issue、在 story 檔寫回 `> **Issue**: #N`。
5. 提醒使用者：story 檔要用 PR 合進 main（例如 branch `docs/1-stories`），組員從 main 開 branch 才讀得到；順序之後要調就改 issue 標題的 `S` 編號。最後跑 `bash .claude/team/team.sh board` 讓使用者確認看板。
