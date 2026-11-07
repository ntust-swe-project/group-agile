# group-agile

期中專題 — **Agile + AI 組**。

## 共同輸入

共同輸入與共用規則在 [`project-common`](https://github.com/ntust-swe-project/project-common)：

| 檔案 | 說明 |
| --- | --- |
| `docs/VISION.md` | 起始文件。三組唯一的共同輸入 |
| `docs/COMMIT_CONVENTION.md` | commit message 規則，四個 repo 共用 |

## 本 repo

放本組的產出：需求分析、設計文件、UML、會議與客戶訪談紀錄、AI 使用紀錄，以及 prototype 程式碼。

## 規則重點

- **不要**在本 repo 另存 `VISION.md` 副本。起始文件只有 `project-common` 那一份，定案後要改須經三組同意。
- 交付物為 **prototype 與相關文件**；prototype 完成即視為本組完成。
- 完成前不讀取其他組的 repo。
- 引擎與 AI 工具的版本見 `project-common` 的 `docs/VISION.md` 第 10 節，三組必須一致。

## 開始前

```bash
git config commit.template .gitmessage
```
