# Source Directory

## Orbit Shift 整合骨架（每個 story 都要遵守）

正式規則在 `production/epics/orbit-shift/EPIC.md` 的「整合約定」，寫程式前先讀那一節。重點：

- 遊戲進入點是 `src/main.tscn`。`Main` 底下已預留 8 個系統節點（`DayCycle`、`StationIntegrity`、`Station`、`Colonists`、`TaskBoard`、`CrisisDirector`、`AutoRepair`、`ResultScreen`）。把你的腳本掛上對應節點；不要改名、搬動或調順序。
- 系統之間只透過 autoload `Events`（`src/core/events.gd`）的訊號溝通：通知別人用 `Events.<signal>.emit(...)`，接收用 `Events.<signal>.connect(...)`。不要用 `get_node` 找別的系統，也不要新增或修改訊號；要改請先在 PR 討論並更新 EPIC.md。
- 真的需要呼叫別的系統的方法時，在 `src/main.gd` 的 `INJECTIONS` 加一列，接收方宣告同名屬性（例如 `var station_integrity: Node`）。注入的參考不能在自己的 `_ready()` 裡用。
- 危機種類用 `CrisisKind.BREACH`、`CrisisKind.MALFUNCTION`（`src/core/crisis_kind.gd`），不要手打字串。
- 邏輯放 `src/core/`，畫面與場景放 `src/ui/`，測試放 `tests/unit/core/`。`tests/unit/core/events_signals_test.gd` 與 `tests/integration/main/` 會檢查上述約定，紅了代表你和約定不一致。

When writing or editing game code in this directory, follow these standards.

## Engine Version Warning

The LLM's training data predates the pinned engine version.
**Always check `docs/engine-reference/` before using any engine API.**
Do not guess at post-cutoff API signatures — look them up first.

## Coding Standards

- All public APIs require doc comments
- Gameplay values must be **data-driven** (external config files), never hardcoded
- Prefer dependency injection over singletons for testability
- Architecture decisions go in `docs/architecture/` as ADRs — **how many depends on
  `modes.workflow`**: all at `full`, critical only at `standard`, none required at
  `minimal` (the decision log carries them)
- Commits must reference the relevant story ID or design document

## File Routing

Match the engine-specialist agent to the file type being written.
`/setup-engine` records which specialist handles code, shaders and UI in the
`specialists` block of `project.yaml`.

When in doubt, use `specialists.code` from `project.yaml`.

## Tests

Tests live in `tests/` — not in `src/`.
Run `/test-setup` to scaffold the test framework if it doesn't exist yet.
Every gameplay system should have unit tests covering its formulas and edge cases.

## Verification-Driven Development

Write tests first when adding gameplay systems.
For UI changes, verify with screenshots.
Compare expected output to actual output before marking work complete.
