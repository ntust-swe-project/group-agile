# Test Infrastructure

**Engine**: Godot 4.7.2
**Test Framework**: GdUnit4 6.2.2 (committed under `addons/gdUnit4/`)
**CI**: `.github/workflows/tests.yml`
**Setup date**: 2026-11-09

## Directory Layout

```
tests/
  unit/           # Isolated unit tests (formulas, state machines, logic)
  integration/    # Cross-system and save/load tests
  smoke/          # Critical path test list for /smoke-check gate
```

```
production/qa/
  evidence/       # Screenshot logs and manual test sign-off records
```

> **Manual evidence lives under `production/qa/evidence/`, not `tests/`** — that
> is where every consumer reads it.

## Running Tests

From the repo root (`godot` = your Godot 4.7.2 executable):

```bash
godot --headless --path . --import
godot --headless -s -d --remote-debug tcp://127.0.0.1:0 res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://tests --ignoreHeadlessMode
```

Run the import first: a fresh clone has no `.godot/` class cache, and without
it the runner does not load (exit 1, no test ran).

Exit codes: **0** all passed · **100** a test failed · **101** all passed but
nodes leaked (warning) · **103/104** gdUnit4 could not run · **105** a test
script does not parse. Two `ERROR:` lines about the remote port
`127.0.0.1:0` are expected. `No test cases found` with exit 0 is **not** a pass.

## Installing GdUnit4

Already committed at `addons/gdUnit4/` (capital U), pinned to 6.2.2 — no install
needed. CI runs this copy (`version: installed`). To use the editor's test
inspector, enable it once: Project → Project Settings → Plugins → GdUnit4 ✓.

## Test Naming

Names follow the engine's language (`.claude/rules/test-standards.md`):

- **Godot**: file `[system]_[feature]_test.gd`, function `test_[scenario]_[expected]`
  — `combat_damage_test.gd` → `test_base_attack_returns_expected_damage()`

## Story Type → Test Evidence

| Story Type | Required Evidence | Location |
|---|---|---|
| Logic | Automated unit test — must pass | `tests/unit/[system]/` |
| Integration | Integration test OR playtest doc | `tests/integration/[system]/` |
| Visual/Feel | Screenshot + lead sign-off | `production/qa/evidence/` |
| UI | Retained screenshot of each screen touched | `production/qa/evidence/` |
| Config/Data | Smoke check pass | `production/qa/smoke-*.md` |

## CI

Tests run automatically on every push to `main` and on every pull request.
A failed test suite blocks merging once branch protection requires the
`Run GdUnit4 Tests` check.
