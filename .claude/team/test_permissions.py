"""Over-reach tests: fail CI when Claude's permissions or the guard script grow.

Run: python -m unittest discover -s .claude/team

Three layers:
  1. Settings   .claude/settings.json may not be looser than permissions-baseline.json:
                allow only from the baseline, every baseline deny kept, same
                defaultMode, no new top-level keys, hooks only run scripts in this repo.
  2. Static     team.py reaches the outside world only through run(), and only
                writes the CI step summary.
  3. Runtime    every command team.py actually runs, across all its entry points,
                is on an allowlist: read-only git plus fetch/switch, `gh api` with
                GET, and only these writes on GitHub: assign/unassign *yourself*,
                open an issue, create a label.

Changing what is allowed means editing this file or the baseline, both of which
are guard files: process-check then requires an approval from someone other
than the PR author.
"""

import ast
import json
import os
import re
import shutil
import subprocess
import sys
import unittest
from pathlib import Path
from unittest import mock

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import team  # noqa: E402

ROOT = HERE.parents[1]
SETTINGS = json.loads((ROOT / ".claude/settings.json").read_text(encoding="utf-8"))
BASELINE = json.loads((HERE / "permissions-baseline.json").read_text(encoding="utf-8"))

LOOSE_MODES = {"acceptEdits", "bypassPermissions", "dontAsk", "auto"}
HOOK_CMD_RE = re.compile(r'^bash "\$CLAUDE_PROJECT_DIR/(\.claude/(?:hooks|team)/[\w.-]+\.sh)"(?: [\w-]+)?$')


# ------------------------------------------------------------------ 1. settings

class Settings(unittest.TestCase):
    def test_default_mode_unchanged(self):
        mode = SETTINGS.get("permissions", {}).get("defaultMode")
        self.assertEqual(mode, BASELINE["defaultMode"])
        self.assertNotIn(mode, LOOSE_MODES)

    def test_allow_is_subset_of_baseline(self):
        extra = set(SETTINGS["permissions"].get("allow", [])) - set(BASELINE["allow"])
        self.assertFalse(extra, "settings.json 新增了未經核准的 allow 規則：%s" % sorted(extra))

    def test_no_wildcard_allow(self):
        for rule in SETTINGS["permissions"].get("allow", []):
            self.assertNotRegex(rule, r"^(Bash|PowerShell)(\(\*\))?$", "不能整個放行 shell")
            self.assertNotRegex(rule, r"^(Write|Edit|WebFetch|mcp__.*)$", "不能整個放行 %s" % rule)

    def test_deny_kept(self):
        missing = set(BASELINE["deny"]) - set(SETTINGS["permissions"].get("deny", []))
        self.assertFalse(missing, "settings.json 拿掉了 deny 規則：%s" % sorted(missing))

    def test_no_ask_bypass_keys(self):
        perms = SETTINGS["permissions"]
        for key in ("additionalDirectories", "disableBypassPermissionsMode"):
            self.assertNotIn(key, perms)
        extra = set(SETTINGS) - set(BASELINE["topLevelKeys"])
        self.assertFalse(extra, "settings.json 新增了頂層設定：%s" % sorted(extra))

    def test_hooks_only_run_repo_scripts(self):
        for event, entries in SETTINGS.get("hooks", {}).items():
            for entry in entries:
                for hook in entry["hooks"]:
                    self.assertEqual(hook["type"], "command")
                    m = HOOK_CMD_RE.match(hook["command"])
                    self.assertTrue(m, "%s hook 跑了 repo 外或格式不明的指令：%s" % (event, hook["command"]))
                    self.assertTrue((ROOT / m.group(1)).is_file(), "hook 指向不存在的檔案：%s" % m.group(1))

    def test_team_guard_registered(self):
        cmds = [h["command"] for e in SETTINGS["hooks"]["PreToolUse"] for h in e["hooks"]
                if "team.sh" in h["command"]]
        self.assertTrue(cmds, "守門 hook 沒有註冊")
        matchers = {e["matcher"] for e in SETTINGS["hooks"]["PreToolUse"]
                    if any("team.sh" in h["command"] for h in e["hooks"])}
        covered = set("|".join(matchers).split("|"))
        self.assertTrue({"Bash", "PowerShell", "Write", "Edit"} <= covered, "守門 hook 沒有涵蓋 %s" % matchers)

    def test_guard_files_cover_permission_files(self):
        for path in (".claude/settings.json", ".claude/team/team.py", ".claude/team/permissions-baseline.json",
                     ".claude/team/test_permissions.py", ".claude/hooks/validate-push.sh",
                     ".github/workflows/process-check.yml"):
            self.assertTrue(any(path == g or path.startswith(g) for g in team.GUARD_FILES), path)


# -------------------------------------------------------------------- 2. static

class Static(unittest.TestCase):
    tree = ast.parse((HERE / "team.py").read_text(encoding="utf-8"))

    def calls(self):
        for node in ast.walk(self.tree):
            if isinstance(node, ast.Call):
                yield node

    @staticmethod
    def name(func):
        parts = []
        while isinstance(func, ast.Attribute):
            parts.append(func.attr)
            func = func.value
        if isinstance(func, ast.Name):
            parts.append(func.id)
        return ".".join(reversed(parts))

    def enclosing(self, target):
        for fn in ast.walk(self.tree):
            if isinstance(fn, ast.FunctionDef) and any(n is target for n in ast.walk(fn)):
                return fn.name
        return None

    ALLOWED_IMPORTS = {"json", "os", "re", "shlex", "subprocess", "sys", "concurrent.futures", "pathlib"}

    def test_imports(self):
        for node in ast.walk(self.tree):
            if isinstance(node, (ast.Import, ast.ImportFrom)):
                mods = [a.name for a in node.names] if isinstance(node, ast.Import) else [node.module]
                for mod in mods:
                    self.assertIn(mod, self.ALLOWED_IMPORTS, "team.py 新增了 import：%s" % mod)
                for a in node.names:
                    self.assertIsNone(a.asname, "不要用 import ... as（審查時看不出來在呼叫什麼）")

    def test_subprocess_only_in_run(self):
        spawn = ("system", "popen", "Popen", "call", "check_call", "check_output", "getoutput",
                 "getstatusoutput", "startfile")
        for c in self.calls():
            n = self.name(c.func)
            last = n.rsplit(".", 1)[-1]
            if n.startswith("subprocess.") or last in spawn or last.startswith(("exec", "spawn")):
                self.assertEqual(n, "subprocess.run", "team.py 不能用 %s 執行程式" % n)
                self.assertEqual(self.enclosing(c), "run", "subprocess 只能在 run() 裡呼叫")

    def test_no_destructive_file_calls(self):
        banned = ("os.remove", "os.unlink", "os.rmdir", "os.rename", "os.replace", "shutil.", "write_text",
                  "write_bytes", "unlink", "rmdir", "rename", "chmod", "eval", "exec", "__import__")
        for c in self.calls():
            n = self.name(c.func)
            self.assertFalse(any(n == b or n.startswith(b) or n.endswith("." + b) for b in banned), n)

    def test_open_only_for_step_summary(self):
        for c in self.calls():
            if self.name(c.func) == "open":
                self.assertEqual(self.enclosing(c), "cmd_ci_check", "只有 ci-check 能寫檔（GitHub step summary）")

    def test_gh_methods(self):
        for c in self.calls():
            if self.name(c.func) == "gh_api" and len(c.args) > 1:
                m = c.args[1]
                self.assertIsInstance(m, ast.Constant, "gh_api 的 method 要寫死，才能審查")
                self.assertIn(m.value, ("GET", "POST", "DELETE"))


# ------------------------------------------------------------------- 3. runtime

GIT_ALLOWED = {"rev-parse", "remote", "status", "log", "diff", "branch", "fetch", "switch", "check-ignore"}
GH_WRITES = [
    ("POST", re.compile(r"^repos/o/r/issues/\d+/assignees$")),
    ("DELETE", re.compile(r"^repos/o/r/issues/\d+/assignees$")),
    ("POST", re.compile(r"^repos/o/r/issues$")),
    ("POST", re.compile(r"^repos/o/r/labels$")),
]
ME = "alice"


class FakeWorld:
    """Answers every command team.py runs, and records it."""

    def __init__(self):
        self.calls = []
        self.branch = "main"
        self.issues = {
            12: self.issue(12, "S01 first", []),
            13: self.issue(13, "S02 second", []),
            14: self.issue(14, "S03 third", ["bob"]),
        }

    @staticmethod
    def issue(n, title, who):
        return {"number": n, "title": title, "state": "open", "body": "Story: `production/epics/zz/story-00%d-x.md`" % n,
                "assignees": [{"login": w} for w in who], "labels": [{"name": "story"}]}

    def run(self, cmd, timeout=15, stdin=None):
        self.calls.append((list(cmd), stdin))
        ok = lambda out="": subprocess.CompletedProcess(cmd, 0, out, "")  # noqa: E731
        if cmd[0] == "git":
            sub = cmd[1]
            if sub == "rev-parse":
                return ok(self.branch if "--abbrev-ref" in cmd else "deadbeef")
            if sub == "remote":
                return ok("https://github.com/o/r.git")
            if sub == "branch":
                return ok("main")
            if sub == "switch":
                self.branch = cmd[-2] if cmd[2] == "-c" else cmd[-1]
                return ok()
            if sub == "check-ignore":
                return subprocess.CompletedProcess(cmd, 1, "", "")
            return ok()
        if cmd[0] == "bash":
            return ok()
        if cmd[:2] == ["gh", "api"]:
            method, path = cmd[3], cmd[6]
            body = json.loads(stdin) if stdin else None
            return ok(json.dumps(self.gh(method, path, body)))
        raise AssertionError("unexpected command %s" % cmd)

    def gh(self, method, path, body):
        p = path.split("?")[0]
        if p == "user":
            return {"login": ME}
        m = re.match(r"repos/o/r/issues/(\d+)/assignees$", p)
        if m:
            i = self.issues[int(m.group(1))]
            names = [a["login"] for a in i["assignees"]]
            for who in body["assignees"]:
                if method == "POST" and who not in names:
                    names.append(who)
                if method == "DELETE" and who in names:
                    names.remove(who)
            i["assignees"] = [{"login": n} for n in names]
            return i
        m = re.match(r"repos/o/r/issues/(\d+)$", p)
        if m:
            return self.issues[int(m.group(1))]
        if p == "repos/o/r/issues":
            if method == "POST":
                return {"number": 99}
            return list(self.issues.values())
        if p.endswith("/pulls"):
            return [{"number": 5, "user": {"login": "bob"}, "head": {"ref": "feat/14-third", "sha": "abc"}}]
        if re.search(r"/pulls/\d+/reviews$", p):
            return []
        if re.search(r"/pulls/\d+$", p):
            return {"number": 5, "user": {"login": "bob"}, "head": {"ref": "feat/14-third", "sha": "abc"}}
        if "/check-runs" in p:
            return {"check_runs": []}
        if p.endswith("/labels"):
            return [] if method == "GET" else {}
        raise AssertionError("unexpected gh api %s %s" % (method, path))


class Runtime(unittest.TestCase):
    def setUp(self):
        self.world = FakeWorld()
        team._cache.clear()
        env = {k: v for k, v in os.environ.items() if k != "GITHUB_REPOSITORY"}  # CI sets it
        patches = [mock.patch.dict(os.environ, env, clear=True),
                   mock.patch.object(team, "run", self.world.run),
                   mock.patch.object(team, "out", lambda *a, **k: None),
                   mock.patch.object(team, "err", lambda *a, **k: None)]
        for p in patches:
            p.start()
            self.addCleanup(p.stop)
        self.addCleanup(team._cache.clear)

    def hook(self, tool, **ti):
        stdin = mock.Mock()
        stdin.buffer.read.return_value = json.dumps({"tool_name": tool, "tool_input": ti}).encode()
        with mock.patch.object(sys, "stdin", stdin):
            team.cmd_hook_pretool([])

    def exercise_everything(self):
        team.cmd_board([])
        team.cmd_session_start([])
        team.cmd_claim([])                     # takes #12
        team.cmd_preflight([])
        team.cmd_claim(["13", "--po-ok"])      # refused: WIP
        self.world.issues[12]["assignees"] = []
        self.world.issues[13]["assignees"] = [{"login": "bob"}]
        team.cmd_claim(["13", "--po-ok"])      # refused: someone else's
        epic = ROOT / "production/epics/zz-permission-test"
        epic.mkdir(parents=True, exist_ok=True)
        self.addCleanup(shutil.rmtree, epic, True)
        (epic / "story-001-x.md").write_text("# Story 001: X\n\n> **Status**: Ready\n", encoding="utf-8")
        team.cmd_publish([str(epic.relative_to(ROOT)), "--dry-run"])
        team.cmd_publish([str(epic.relative_to(ROOT))])
        self.world.branch = "feat/12-first"
        for cmd in ("git push origin main", "git checkout -b feat/12-first", "gh pr merge 5 --merge",
                    "gh pr create --title t --body 'Closes #12'", 'git commit -m "feat: x"'):
            self.hook("Bash", command=cmd)
        self.hook("Write", file_path=str(ROOT / "src/x.gd"))

    def test_every_command_is_allowed(self):
        self.exercise_everything()
        self.assertTrue(self.world.calls)
        for cmd, stdin in self.world.calls:
            if cmd[0] == "git":
                self.assertIn(cmd[1], GIT_ALLOWED, "team.py 執行了未允許的 git 指令：%s" % cmd)
                if cmd[1] == "branch":
                    self.assertTrue(all(a.startswith("--format") for a in cmd[2:]), "git branch 只能用來列出：%s" % cmd)
                if cmd[1] == "fetch":
                    self.assertEqual(cmd[2:], ["origin", "main"])
                if cmd[1] == "switch":
                    self.assertNotIn("--discard-changes", cmd)
                    self.assertNotIn("--force", cmd)
            elif cmd[0] == "bash":
                self.assertEqual(cmd[1:3], [".claude/scripts/md-section.sh", "set-field"], cmd)
                self.assertEqual(cmd[4], "Issue", "publish 只能寫 story 檔的 Issue 欄位")
            elif cmd[:2] == ["gh", "api"]:
                method, path = cmd[3], cmd[6]
                if method == "GET":
                    continue
                self.assertTrue(any(method == m and rx.match(path) for m, rx in GH_WRITES),
                                "team.py 對 GitHub 做了未允許的寫入：%s %s" % (method, path))
                if path.endswith("/assignees"):
                    self.assertEqual(json.loads(stdin), {"assignees": [ME]}, "只能 assign / 撤回自己")
            else:
                self.fail("team.py 執行了未允許的程式：%s" % cmd)

    def test_no_merge_push_or_close(self):
        self.exercise_everything()
        flat = [" ".join(c) for c, _ in self.world.calls]
        for word in ("push", "merge", "reset", "clean", "commit", "rebase", "PATCH", "PUT", "/merges", "/protection"):
            self.assertFalse([f for f in flat if re.search(r"(^|[\s/])%s($|[\s/])" % re.escape(word), f)],
                             "team.py 不應該執行 %s" % word)


if __name__ == "__main__":
    unittest.main()
