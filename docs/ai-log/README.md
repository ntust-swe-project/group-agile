# AI 使用紀錄 — group-agile

- 規範:[AI_LOGGING_RULES.md](AI_LOGGING_RULES.md)
- 個人紀錄:`log-<GitHub 帳號>.md`(從 [log-TEMPLATE.md](log-TEMPLATE.md) 複製)
- 統計:[stats.md](stats.md)

## 1. 工具揭露
工具、模型或自動化設定有變動時**新增一列**,不改舊的。

| 生效日 | 主要工具與版本 | 主要模型 | 啟用的自動化 | 其他工具 |
| --- | --- | --- | --- | --- |
| 2026-11-09 | eden2289:Claude Code 2.1.319 | `claude-sonnet-5-5` | 尚未啟用 CCGS;待 EJ 骨架完成後更新 | Godot 4.7.2.stable.official.ed1daf0bf(standard)、Python 3.14.5、git 2.55.0 |
| 2026-11-10 | eden2289:Claude Code 2.1.319 | `claude-opus-5-5` | 尚未啟用 CCGS;待 EJ 骨架完成後更新 | Godot 4.7.2.stable.official.ed1daf0bf(standard)、Python 3.11.9、git 2.49.0.windows.1 |
| 2026-11-11 | yichieh-chen:Claude Code 2.1.322 | `claude-opus-5-5` | CCGS v1.2.0 hooks(rigor: minimal);團隊流程 hook(`team.sh` session-start / hook-pretool)與 `/board`、`/claim-story`、`/ship-story`、`/publish-stories`;CI `process-check` | Godot 4.7.2.stable.official.ed1daf0bf(standard)、GitHub CLI |
