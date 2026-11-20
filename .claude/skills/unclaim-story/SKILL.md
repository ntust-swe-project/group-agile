---
name: unclaim-story
description: "Gives the user's claimed story back to the backlog: asks why (blocked, too big, priority changed, no time), makes sure pushed work is not lost, records the reason on the GitHub issue, labels it blocked when stuck, unassigns the user and switches to main. Use when the user wants to drop, abandon, release, hand over or stop working on their story, or is stuck and wants to take another card."
argument-hint: "[issue-number]"
allowed-tools: Read, AskUserQuestion, Bash(bash .claude/team/team.sh board*), Bash(bash .claude/team/team.sh unclaim*), Bash(git status*), Bash(git log*), Bash(git push -u origin *), Bash(bash "*/.claude/skills/unclaim-story/../../team/team.sh" board*)
---

# /unclaim-story — 放棄認領，退回 backlog

規則依據 `docs/PROCESS.md` 的「放棄認領」。退卡不是失敗：卡住、太大、優先順序變了都是 Sprint 中正常會發生的事，重點是**讓大家看得到原因**，而且不把別人的卡或進度弄丟。

## 目前看板

!`bash "${CLAUDE_SKILL_DIR}/../../team/team.sh" board`

## 步驟

1. **確認是哪張。** 使用者沒指定就用看板「你手上」那張。只能退自己的卡；要退別人的卡，請使用者在每日同步問持卡人，或交給 PO 決定。
2. **問原因**（用 AskUserQuestion，四選一）並請使用者用一句話說明：

   | `--reason` | 什麼時候用 | 退完之後 |
   | --- | --- | --- |
   | `blocked` | 等別的 story、技術問題卡住 | 自動加 `blocked` label，前置解決後 PO 拿掉 |
   | `too-big` | 比預期大很多，該拆 | 請 PO 拆成較小的 story |
   | `priority` | PO 或團隊決定先做別的 | 請 PO 調整排序或延到下個 sprint |
   | `capacity` | 個人時間不夠 | 留在原排序，下一位接手 |

   說明要具體（卡在哪、做到哪、建議怎麼拆），接手的人和 Retro 都靠它。不要替使用者編原因。
3. **保住進度。** 看 `git status` 與 `git log origin/main..HEAD`：
   - 有未 commit 的變更：問使用者要留還是不要。要留就照 `.gitmessage` commit（`chore(<scope>): save wip for #<編號>` 這類）；不要就請使用者自己還原，Claude 不執行 `git checkout -- .`、`git reset`、`git clean`。
   - 有 commit 還沒推：`git push -u origin <branch>`，下一位 `/claim-story` 會從這個 branch 接著做。
4. **執行**：`bash .claude/team/team.sh unclaim [編號] --reason <原因> --note "<一句說明>"`
   - `FAIL`：把原因告訴使用者並停下。不要到網頁手動取消 assign 繞過，那樣不會留下紀錄。
   - `NOT ASSESSED`：通常是 `gh` 沒裝或沒登入。
   - `OK`：已在 issue 留言、取消 assign、切回 main。
5. **下一步**：原因是 `too-big` 或 `priority` 時，提醒使用者告訴 PO。然後建議 `/board` 看下一張（`blocked` 的卡退回後不會出現在「可以拿」）。

這一步用到 AI 就照 `docs/ai-log/AI_LOGGING_RULES.md` 記 ai-log（下次 `/ship-story` 時一起記即可）。
