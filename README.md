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

### 需要的工具

| 工具 | 版本 / 說明 |
| --- | --- |
| [Godot](https://github.com/godotengine/godot/releases/tag/4.7.2-stable) | **4.7.2 stable，standard 版**（不是 mono / .NET 版）。三組一致，見 `common/docs/VISION.md` 第 10 節。裝在哪都可以，但要能用 `godot` 指令呼叫（見下節） |
| Git（Windows 用 [Git for Windows](https://gitforwindows.org/)） | CCGS 的 hooks 與 scripts 用 bash 執行；Windows 用附帶的 Git Bash |
| [Python 3](https://www.python.org/downloads/) | CCGS 部分 hooks / scripts 需要 |

### 讓 `godot` 指令可以用

`project.yaml` 的 `commands.*`（CCGS 跑測試、執行遊戲用）直接呼叫 `godot`，所以要把 Godot 加進 PATH：

- **Windows**：解壓 `Godot_v4.7.2-stable_win64.exe.zip`，把 `Godot_v4.7.2-stable_win64_console.exe` 複製一份叫 `godot.exe`，再把那個資料夾加進使用者 PATH。只用 Git Bash 的話，也可以建一個 `~/bin/godot` 檔，內容是 `exec "/c/<你的路徑>/Godot_v4.7.2-stable_win64_console.exe" "$@"`
- **macOS**：`ln -s /Applications/Godot.app/Contents/MacOS/Godot /usr/local/bin/godot`
- **Linux**：解壓 `Godot_v4.7.2-stable_linux.x86_64.zip`，`ln -s <路徑>/Godot_v4.7.2-stable_linux.x86_64 ~/.local/bin/godot`

確認：`godot --version` 要顯示 `4.7.2.stable.official.ed1daf0bf`。

### Clone

`common/` 是 [`project-common`](https://github.com/ntust-swe-project/project-common) 的 git submodule，clone 時要一起拉：

```bash
git clone --recurse-submodules https://github.com/ntust-swe-project/group-agile.git
```

已經 clone 過但 `common/` 是空的：

```bash
git submodule update --init
```

### 設定 commit 範本

```bash
git config commit.template .gitmessage
```

### 跑測試

測試用 gdUnit4 6.2.2（已放在 `addons/gdUnit4/`），在 repo 根目錄執行（Windows 用 Git Bash）：

```bash
godot --headless --path . --import
godot --headless -s -d --remote-debug tcp://127.0.0.1:0 res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests --ignoreHeadlessMode
```

結束碼 0 代表全部通過。執行時會印出幾行 `ERROR:`（`The remote port number must be between 1 and 65535`、`Remote Debugger: Unable to connect to host '127.0.0.1:0'`），這是 `--remote-debug tcp://127.0.0.1:0` 造成的，屬正常現象，不影響測試結果。詳見 [`tests/README.md`](tests/README.md)。

## main 的規則

私有 repo 在 GitHub 免費方案下無法開分支保護，所以先靠團隊約定：

- 不直接 push `main`
- PR 要 1 人 review、CI `Run GdUnit4 Tests` 綠燈才 merge
- 用 merge commit，不 squash

## 專案結構

本 repo 使用 [Claude Code Game Studios](https://github.com/Donchitos/Claude-Code-Game-Studios) v1.2.0（`.claude/`、`CLAUDE.md`、`project.yaml`），授權見 `.claude/LICENSE-CCGS`。第一次用 Claude Code 開啟本 repo 時可執行 `/help` 看下一步。
