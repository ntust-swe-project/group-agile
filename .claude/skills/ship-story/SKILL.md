---
name: ship-story
description: "Takes a finished story to a pull request: runs the definition-of-done preflight, gets /story-done passed, drafts the ai-log entry for the user to confirm, pushes the branch and opens the PR from the team template with Closes #N. Use when the user says a story is done, wants to open a PR, or asks what is left before merging."
allowed-tools: Read, Edit, Glob, Grep, AskUserQuestion, Skill, Bash(bash .claude/team/team.sh preflight*), Bash(bash .claude/team/team.sh board*), Bash(git status*), Bash(git diff*), Bash(git log*), Bash(git add *), Bash(git commit *), Bash(git push -u origin *), Bash(gh pr create *), Bash(gh pr view*), Bash(bash "*/.claude/skills/ship-story/../../team/team.sh" preflight*)
---

# /ship-story — 完成 story、開 PR

規則依據 `docs/PROCESS.md` 的「完成的定義」。守門 hook 會在 `gh pr create` 時再檢查一次，所以這裡的每一步都要真的做到，不是勾選而已。

## 目前檢查結果

!`bash "${CLAUDE_SKILL_DIR}/../../team/team.sh" preflight`

## 步驟

照上面的 FAIL / NOT ASSESSED 逐項處理，每處理完一項就重跑 `bash .claude/team/team.sh preflight`。

1. **branch / issue 不對**：停下，請使用者先 `/claim-story`。
2. **story Status 不是 Complete**：執行 `/story-done <story 檔>`（用 Skill 工具）。它判定沒通過就回到 `/dev-story` 修，不要改 Status 硬過。
3. **缺測試或截圖**：Logic / Integration 要在 `tests/` 有測試；UI / Visual 要有 `production/qa/evidence/` 的截圖。回去補。
4. **ai-log 沒記**：照 `docs/ai-log/AI_LOGGING_RULES.md` 第 9 節起草：
   - 讀 `docs/ai-log/log-<GitHub 帳號>.md` 取下一個流水號；任務欄寫 `#<issue 編號> <簡述>`。
   - **結果、理由、工時**用 `TODO(人填)` 佔位，除非使用者已經明說；建議 `API` / `INV` / `DUP` 標記並說明依據。
   - 給使用者看草稿，請他填好；確認後才寫入，再 commit：`docs(ai-log): log #<編號>`（含 Co-Authored-By footer）。
   - 只改自己的 log 檔，不改舊列。
5. **有未 commit 的變更 / commit 格式不符**：照 `.gitmessage` 的格式 commit。舊 commit 格式錯就告訴使用者，請他決定是否要改寫（不要自行 rebase 或 force push）。
6. **全部 PASS 後**：
   - `git push -u origin <branch>`
   - 讀 `.github/pull_request_template.md`，填好內容：第一行 `Closes #<編號>`；「做了什麼」寫重點；只勾**已經確認**的項目（CI 還沒跑完就先不勾 CI 那格；ai-log 已記才勾）。
   - 問使用者要請哪位組員 review。
   - `gh pr create --base main --title "<type>(<scope>): <英文 subject>" --reviewer <組員> --body-file - <<'EOF' … EOF`
7. 回報 PR 連結，提醒使用者：等 1 人 approve 和 CI（`Run GdUnit4 Tests`、`process-check`）綠燈，再用 `gh pr merge <編號> --merge`。之後 `/claim-story` 拿下一張。

被【團隊流程】hook 擋下時，照訊息修正，不要換寫法繞過。
