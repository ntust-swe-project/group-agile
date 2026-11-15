"""Tests for the team process guard. Run: python -m unittest discover -s .claude/team

GitHub and git state are stubbed, so these run offline.
"""

import json
import re
import os
import subprocess
import sys
import unittest
from pathlib import Path
from unittest import mock

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import team  # noqa: E402

TRAILER = "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"


def issue(number, assignees=(), state="open", labels=("story",), title="S01 x", body=""):
    return {"number": number, "state": state, "title": title, "body": body,
            "assignees": [{"login": a} for a in assignees],
            "labels": [{"name": l} for l in labels]}


class Guard(unittest.TestCase):
    def setUp(self):
        self.branch = "feat/12-crisis-wave"
        self.issues = {12: issue(12, ["alice"]), 13: issue(13), 14: issue(14, ["bob"])}
        self.preflight = ([(team.PASS, "x", "ok")], 12)
        patches = [
            mock.patch.object(team, "current_branch", lambda: self.branch),
            mock.patch.object(team, "me", lambda: "alice"),
            mock.patch.object(team, "repo_slug", lambda: "o/r"),
            mock.patch.object(team, "gh_api", self.fake_gh),
            mock.patch.object(team, "preflight_results", lambda: self.preflight),
            mock.patch.object(team, "run", self.fake_run),
        ]
        for p in patches:
            p.start()
            self.addCleanup(p.stop)

    def fake_run(self, cmd, timeout=15, stdin=None):
        # git check-ignore: nothing is ignored except production/session-state
        rc = 0 if cmd[:2] == ["git", "check-ignore"] and "session-state" in cmd[-1] else 1
        return subprocess.CompletedProcess(cmd, rc, "", "")

    def fake_gh(self, path, method="GET", body=None, timeout=15):
        if "/issues?" in path:
            return list(self.issues.values())
        if "/issues/" in path:
            return self.issues[int(path.rsplit("/", 1)[-1])]
        raise AssertionError(path)

    def decide(self, tool, **ti):
        payload = json.dumps({"tool_name": tool, "tool_input": ti})
        stdin = mock.Mock()
        stdin.buffer.read.return_value = payload.encode()
        with mock.patch.object(sys, "stdin", stdin), \
                mock.patch.object(team, "err") as err, mock.patch.object(team, "out") as out:
            rc = team.cmd_hook_pretool([])
        if rc == 2:
            return "deny", err.call_args[0][0]
        if out.called:
            return "ask", out.call_args[0][0]
        return "allow", ""

    def bash(self, cmd):
        return self.decide("Bash", command=cmd)

    # commits
    def test_commit_ok_heredoc(self):
        cmd = 'git add -A && git commit -m "$(cat <<\'EOF\'\nfeat(crisis): add wave timer\n\n* why\n\n%s\nEOF\n)"' % TRAILER
        self.assertEqual(self.bash(cmd)[0], "allow")

    def test_commit_heredoc_missing_trailer(self):
        cmd = 'git commit -m "$(cat <<\'EOF\'\nfeat(crisis): add wave timer\nEOF\n)"'
        self.assertEqual(self.bash(cmd)[0], "deny")

    def test_commit_ok_multiple_m(self):
        self.assertEqual(self.bash('git commit -m "fix(ui): align hud" -m "%s"' % TRAILER)[0], "allow")

    def test_commit_bad_subject(self):
        kind, msg = self.bash('git commit -m "Added stuff" -m "%s"' % TRAILER)
        self.assertEqual(kind, "deny")
        self.assertIn("<type>", msg)

    def test_commit_trailing_period(self):
        self.assertEqual(self.bash('git commit -m "feat: add x." -m "%s"' % TRAILER)[0], "deny")

    def test_commit_missing_trailer(self):
        kind, msg = self.bash('git commit -m "feat: add x"')
        self.assertEqual(kind, "deny")
        self.assertIn("Co-Authored-By", msg)

    def test_commit_on_main(self):
        self.branch = "main"
        self.assertEqual(self.bash('git commit -m "feat: add x" -m "%s"' % TRAILER)[0], "deny")

    def test_commit_bad_branch(self):
        self.branch = "my-stuff"
        self.assertEqual(self.bash('git commit -m "feat: add x" -m "%s"' % TRAILER)[0], "deny")

    def test_commit_editor(self):
        self.assertEqual(self.bash("git commit")[0], "deny")

    def test_commit_amend_no_edit(self):
        self.assertEqual(self.bash("git commit --amend --no-edit")[0], "allow")

    def test_git_dash_c(self):
        self.assertEqual(self.bash('git -C . commit -m "nope"')[0], "deny")

    # push
    def test_push_main(self):
        self.assertEqual(self.bash("git push origin main")[0], "deny")
        self.assertEqual(self.bash("git push origin HEAD:main")[0], "deny")
        self.assertEqual(self.bash("git push origin feat/12-x:refs/heads/main")[0], "deny")

    def test_push_branch(self):
        self.assertEqual(self.bash("git push -u origin feat/12-crisis-wave")[0], "allow")

    def test_push_bare_on_main(self):
        self.branch = "main"
        self.assertEqual(self.bash("git push")[0], "deny")

    # branches
    def test_branch_bad_name(self):
        self.assertEqual(self.bash("git checkout -b crisis")[0], "deny")
        self.assertEqual(self.bash("git switch -c feat/crisis")[0], "deny")

    def test_branch_unclaimed(self):
        kind, msg = self.bash("git switch -c feat/13-next origin/main")
        self.assertEqual(kind, "deny")
        self.assertIn("/claim-story 13", msg)

    def test_branch_someone_elses(self):
        self.assertEqual(self.bash("git checkout -b feat/14-x")[0], "deny")

    def test_branch_mine(self):
        self.assertEqual(self.bash("git checkout -b feat/12-crisis-wave")[0], "allow")

    def test_branch_wip_limit(self):
        self.issues[13] = issue(13, ["alice"])
        kind, msg = self.bash("git checkout -b feat/13-y")
        self.assertEqual(kind, "deny")
        self.assertIn("#12", msg)

    def test_branch_docs_no_gh(self):
        self.assertEqual(self.bash("git checkout -b docs/1-process")[0], "allow")

    def test_branch_rename(self):
        self.assertEqual(self.bash("git branch -m wrong")[0], "deny")

    def test_switch_existing(self):
        self.assertEqual(self.bash("git switch main && git pull")[0], "allow")

    # PRs
    BODY = "Closes #12\n\n## AI 使用\n- [x] 本 PR 的 AI 使用已記入 `docs/ai-log/log-<帳號>.md`\n"

    def test_pr_ok(self):
        cmd = "gh pr create --base main --title 'feat: x' --body-file - <<'EOF'\n%sEOF" % self.BODY
        self.assertEqual(self.bash(cmd)[0], "allow")

    def test_pr_missing_closes(self):
        self.assertEqual(self.bash("gh pr create --title t --body 'Refs #12'")[0], "deny")

    def test_pr_unchecked_ailog(self):
        body = self.BODY.replace("[x]", "[ ]")
        self.assertEqual(self.bash("gh pr create --title t --body '%s'" % body)[0], "deny")

    def test_pr_fill(self):
        self.assertEqual(self.bash("gh pr create --fill")[0], "deny")

    def test_pr_preflight_fail(self):
        self.preflight = ([(team.FAIL, "ai-log", "沒記")], 12)
        kind, msg = self.bash("gh pr create --title t --body '%s'" % self.BODY)
        self.assertEqual(kind, "deny")
        self.assertIn("沒記", msg)

    def test_pr_preflight_na(self):
        self.preflight = ([(team.NA, "story", "?")], 12)
        self.assertEqual(self.bash("gh pr create --title t --body '%s'" % self.BODY)[0], "ask")

    def test_pr_merge_squash(self):
        self.assertEqual(self.bash("gh pr merge 5 --squash")[0], "deny")
        self.assertEqual(self.bash("gh pr merge 5")[0], "deny")

    def test_pr_merge_checks(self):
        pr = {"number": 5, "user": {"login": "bob"}, "head": {"sha": "abc"}}
        with mock.patch.object(team, "gh_api", lambda *a, **k: pr), \
                mock.patch.object(team, "pr_state", lambda p: {"approved": [], "changes": [], "checks": {}}):
            kind, msg = self.bash("gh pr merge 5 --merge")
        self.assertEqual(kind, "deny")
        self.assertIn("approve", msg)
        good = {"approved": ["alice"], "changes": [], "checks": {team.TEST_CHECK: "success", team.PROCESS_CHECK: "success"}}
        with mock.patch.object(team, "gh_api", lambda *a, **k: pr), mock.patch.object(team, "pr_state", lambda p: good):
            self.assertEqual(self.bash("gh pr merge 5 --merge")[0], "allow")

    # writes
    def test_write_on_main(self):
        self.branch = "main"
        kind, msg = self.decide("Write", file_path=str(team.ROOT / "src/x.gd"))
        self.assertEqual(kind, "deny")
        self.assertIn("/claim-story", msg)

    def test_write_ignored_on_main(self):
        self.branch = "main"
        self.assertEqual(self.decide("Write", file_path=str(team.ROOT / "production/session-state/active.md"))[0], "allow")

    def test_write_on_branch(self):
        self.assertEqual(self.decide("Edit", file_path=str(team.ROOT / "src/x.gd"))[0], "allow")

    def test_write_outside_repo(self):
        self.branch = "main"
        self.assertEqual(self.decide("Write", file_path="/tmp/elsewhere.txt")[0], "allow")

    def test_write_guard_files(self):
        self.assertEqual(self.decide("Edit", file_path=str(team.ROOT / ".claude/team/team.py"))[0], "ask")

    def test_unrelated_bash(self):
        self.assertEqual(self.bash("ls -la && godot --headless --version")[0], "allow")

    def test_gh_down_asks(self):
        def broken(*a, **k):
            raise team.GhError("no gh")
        with mock.patch.object(team, "gh_api", broken):
            self.assertEqual(self.bash("git checkout -b feat/13-x")[0], "ask")


class Unclaim(unittest.TestCase):
    """/unclaim-story: only your own card, a reason is recorded, nothing is lost."""

    def setUp(self):
        self.branch = "feat/12-crisis-wave"
        self.issues = {12: issue(12, ["alice"], title="S03 crisis"), 13: issue(13), 14: issue(14, ["bob"])}
        self.prs, self.remote, self.dirty, self.ahead = [], [], "", ""
        self.local = "main\nfeat/12-crisis-wave"
        self.writes, self.ran, self.printed = [], [], []
        patches = [
            mock.patch.object(team, "current_branch", lambda: self.branch),
            mock.patch.object(team, "me", lambda: "alice"),
            mock.patch.object(team, "repo_slug", lambda: "o/r"),
            mock.patch.object(team, "gh_api", self.fake_gh),
            mock.patch.object(team, "git", self.fake_git),
            mock.patch.object(team, "run", self.fake_run),
            mock.patch.object(team, "out", self.printed.append),
        ]
        for p in patches:
            p.start()
            self.addCleanup(p.stop)

    def fake_git(self, *args):
        if args[0] == "status":
            return self.dirty
        if args[0] == "branch":
            return self.local
        if args[0] == "log":
            return self.ahead
        if args[0] == "rev-parse":
            return "localsha"
        return ""

    def fake_run(self, cmd, timeout=15, stdin=None):
        self.ran.append(cmd)
        return subprocess.CompletedProcess(cmd, 0, "", "")

    def fake_gh(self, path, method="GET", body=None, timeout=15):
        p = path.split("?")[0]
        if method != "GET":
            self.writes.append((method, p, body))
        if p.endswith("/assignees"):
            i = self.issues[int(p.split("/")[-2])]
            i["assignees"] = [a for a in i["assignees"] if a["login"] not in body["assignees"]]
            return i
        if p.endswith(("/comments", "/labels")):
            return {}
        if p == "repos/o/r/issues":
            return list(self.issues.values())
        if p.startswith("repos/o/r/issues/"):
            return self.issues[int(p.rsplit("/", 1)[-1])]
        if p.endswith("/pulls"):
            return self.prs
        if p.endswith("/branches"):
            return self.remote
        raise AssertionError(path)

    def unclaim(self, *args):
        return team.cmd_unclaim(list(args))

    def test_reason_required(self):
        self.assertEqual(self.unclaim("12", "--note", "x"), 2)
        self.assertEqual(self.unclaim("12", "--reason", "bored", "--note", "x"), 2)
        self.assertEqual(self.unclaim("12", "--reason", "blocked"), 2)
        self.assertEqual(self.writes, [])

    def test_only_your_own(self):
        self.assertEqual(self.unclaim("14", "--reason", "capacity", "--note", "x"), 1)
        self.assertEqual(self.writes, [])

    def test_open_pr(self):
        self.prs = [{"number": 5, "head": {"ref": "feat/12-crisis-wave"}}]
        self.assertEqual(self.unclaim("--reason", "capacity", "--note", "x"), 1)
        self.assertIn("PR #5", self.printed[-1])
        self.assertEqual(self.writes, [])

    def test_uncommitted(self):
        self.dirty = " M src/a.gd"
        self.assertEqual(self.unclaim("--reason", "capacity", "--note", "x"), 1)
        self.assertEqual(self.writes, [])

    def test_unpushed_commits(self):
        self.ahead = "abc\ndef"
        self.assertEqual(self.unclaim("--reason", "capacity", "--note", "x"), 1)
        self.assertIn("git push -u origin feat/12-crisis-wave", self.printed[-1])
        self.remote = [{"name": "feat/12-crisis-wave", "commit": {"sha": "localsha"}}]
        self.assertEqual(self.unclaim("--reason", "capacity", "--note", "x"), 0)

    def test_blocked(self):
        self.assertEqual(self.unclaim("--reason", "blocked", "--note", "waiting on #13"), 0)
        methods = [(m, p) for m, p, _ in self.writes]
        self.assertEqual(methods, [("POST", "repos/o/r/issues/12/comments"), ("POST", "repos/o/r/issues/12/labels"),
                                   ("DELETE", "repos/o/r/issues/12/assignees")])
        comment = self.writes[0][2]["body"]
        self.assertIn(team.UNCLAIM_MARK, comment)
        self.assertIn("waiting on #13", comment)
        self.assertIn("S03", comment)
        self.assertEqual(self.writes[2][2], {"assignees": ["alice"]})
        self.assertIn(["git", "switch", "main"], self.ran)

    def test_priority_asks_po(self):
        self.branch = "main"
        self.assertEqual(self.unclaim("12", "--reason", "priority", "--note", "x"), 0)
        self.assertEqual([p for _, p, _ in self.writes if p.endswith("/labels")], [])
        self.assertIn("PO", self.writes[0][2]["body"])
        self.assertNotIn(["git", "switch", "main"], self.ran)

    def test_pushed_work_is_named(self):
        self.remote = [{"name": "feat/12-crisis-wave", "commit": {"sha": "abc"}}]
        self.unclaim("--reason", "capacity", "--note", "x")
        self.assertIn("`feat/12-crisis-wave`", self.writes[0][2]["body"])


class Stale(unittest.TestCase):
    def test_idle_days_uses_newest_signal(self):
        events = [{"event": "assigned", "created_at": "2026-11-10T00:00:00Z"},
                  {"event": "labeled", "created_at": "2026-11-14T00:00:00Z"}]

        def gh(path, method="GET", body=None, timeout=15):
            if "/events" in path:
                return events
            return {"commit": {"committer": {"date": "2026-11-12T00:00:00Z"}}}
        fixed = team.datetime(2026, 11, 15, tzinfo=team.timezone.utc)
        with mock.patch.object(team, "gh_api", gh), mock.patch.object(team, "repo_slug", lambda: "o/r"), \
                mock.patch.object(team, "now", lambda: fixed):
            self.assertEqual(team.idle_days(issue(12, ["alice"]), {}), 5)
            self.assertEqual(team.idle_days(issue(12, ["alice"]), {12: ("feat/12-x", "abc")}), 3)


class SkillInjections(unittest.TestCase):
    """Each !`command` a skill injects must match one of its allowed-tools.

    Claude Code expands ${CLAUDE_SKILL_DIR} to an absolute path (C:/dev/... on
    Windows) before checking permissions; a pattern written as a relative path
    never matches, and /board fails with "This command requires approval".
    """

    def test_injected_commands_are_allowed(self):
        import fnmatch
        skills = team.ROOT / ".claude/skills"
        for name in ("board", "claim-story", "unclaim-story", "ship-story", "publish-stories"):
            text = (skills / name / "SKILL.md").read_text(encoding="utf-8")
            allowed = re.search(r"^allowed-tools:\s*(.*)$", text, re.M).group(1)
            patterns = re.findall(r"Bash\((.*?)\)(?:,|$)", allowed)
            for cmd in re.findall(r"^!`(.*)`\s*$", text, re.M):
                for skill_dir in ("C:/dev/swe_project/group-agile/.claude/skills/" + name,
                                  "/home/u/group-agile/.claude/skills/" + name):
                    expanded = cmd.replace("${CLAUDE_SKILL_DIR}", skill_dir)
                    self.assertTrue(any(fnmatch.fnmatchcase(expanded, p) for p in patterns),
                                    "%s: %s 不符合 allowed-tools %s" % (name, expanded, patterns))


class Messages(unittest.TestCase):
    def test_subjects(self):
        self.assertIsNone(team.message_problem("chore(repo): add x\n\n" + TRAILER))
        self.assertIsNone(team.message_problem("docs(ai-log): log #12", require_trailer=False))
        self.assertIsNotNone(team.message_problem("feature: x", require_trailer=False))
        self.assertIsNotNone(team.message_problem("feat: " + "x" * 80, require_trailer=False))
        self.assertIsNone(team.message_problem("feat: x\n\nAssisted-by: Copilot:gpt-5"))

    def test_order(self):
        issues = [issue(9, title="S03 c"), issue(3, title="no prefix"), issue(7, title="S01 a")]
        self.assertEqual([i["number"] for i in sorted(issues, key=team.order_key)], [7, 9, 3])

    def test_story_path(self):
        self.assertEqual(team.story_path_of({"body": "Story: `production/epics/core/story-001-a.md`\n"}),
                         "production/epics/core/story-001-a.md")


if __name__ == "__main__":
    unittest.main()
