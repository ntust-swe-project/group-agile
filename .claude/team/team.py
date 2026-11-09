#!/usr/bin/env python3
"""group-agile team process: board, claim, preflight, publish, hooks and CI check.

The rules live in docs/PROCESS.md. This file is what makes a Claude Code session
follow them:

  board          the team board from GitHub Issues (what you hold, what is free)
  session-start  the board, printed into a new session's context (SessionStart hook)
  claim [N]      claim a story: WIP check, assign on GitHub, create feat/N-<slug>
  preflight      definition-of-done check before a PR is opened
  publish DIR    PO only: open one GitHub issue per story file in an epic folder
  hook-pretool   PreToolUse hook: blocks steps that break the process
  ci-check       the same rules for a pull request, run by GitHub Actions

GitHub is read and written through `gh api` (REST). Every check that cannot run
says so (NOT ASSESSED) instead of passing silently.
"""

import json
import os
import re
import shlex
import subprocess
import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

TYPES = ("feat", "fix", "docs", "refactor", "test", "chore", "build")
BRANCH_RE = re.compile(r"^(%s)/(\d+)-[a-z0-9]+(?:-[a-z0-9]+)*$" % "|".join(TYPES))
STORY_BRANCH_TYPES = ("feat", "fix")
SUBJECT_RE = re.compile(r"^(%s)(\([a-z0-9][a-z0-9-]*\))?!?: \S.*$" % "|".join(TYPES))
AI_TRAILER_RE = re.compile(
    r"^(Co-Authored-By:\s*.+<noreply@anthropic\.com>|Assisted-by:\s*\S+:\S+)\s*$",
    re.M | re.I,
)
PROTECTED = {"main", "master"}
STORY_LABEL = "story"
BLOCKED_LABEL = "blocked"
TEST_CHECK = "Run GdUnit4 Tests"
PROCESS_CHECK = "process-check"
AI_LOG_DIR = "docs/ai-log"
GUARD_FILES = (".claude/team/", ".claude/settings.json", ".github/workflows/process-check.yml")
TAG = "【團隊流程】"

PASS, FAIL, NA = "PASS", "FAIL", "NOT ASSESSED"


# --------------------------------------------------------------------------- io

def out(text=""):
    sys.stdout.buffer.write((text + "\n").encode("utf-8"))
    sys.stdout.flush()


def err(text):
    sys.stderr.buffer.write((text + "\n").encode("utf-8"))
    sys.stderr.flush()


def run(cmd, timeout=15, stdin=None):
    try:
        return subprocess.run(
            cmd, cwd=ROOT, capture_output=True, text=True, encoding="utf-8",
            errors="replace", timeout=timeout, input=stdin,
        )
    except (OSError, subprocess.TimeoutExpired):
        return None


def git(*args):
    p = run(["git", *args])
    return p.stdout.strip() if p is not None and p.returncode == 0 else None


class GhError(Exception):
    pass


def gh_api(path, method="GET", body=None, timeout=15):
    cmd = ["gh", "api", "-X", method, "-H", "Accept: application/vnd.github+json", path]
    if body is not None:
        cmd += ["--input", "-"]
    p = run(cmd, timeout=timeout, stdin=json.dumps(body) if body is not None else None)
    if p is None:
        raise GhError("找不到 gh 指令或連線逾時。請安裝 GitHub CLI 並執行 `gh auth login`。")
    if p.returncode != 0:
        msg = (p.stderr or p.stdout).strip().splitlines()
        raise GhError("gh api %s 失敗：%s" % (path, msg[-1] if msg else "未知錯誤"))
    return json.loads(p.stdout) if p.stdout.strip() else None


_cache = {}


def repo_slug():
    if "repo" not in _cache:
        env = os.environ.get("GITHUB_REPOSITORY")
        url = git("remote", "get-url", "origin") or ""
        m = re.search(r"[:/]([^/:]+)/([^/]+?)(?:\.git)?/?$", url)
        _cache["repo"] = env or ("%s/%s" % (m.group(1), m.group(2)) if m else None)
        if not _cache["repo"]:
            raise GhError("讀不到 origin remote，無法判斷 GitHub repo。")
    return _cache["repo"]


def me():
    if "me" not in _cache:
        _cache["me"] = gh_api("user")["login"]
    return _cache["me"]


def current_branch():
    return git("rev-parse", "--abbrev-ref", "HEAD") or "?"


def branch_issue(branch):
    m = BRANCH_RE.match(branch or "")
    return (m.group(1), int(m.group(2))) if m else (None, None)


# ---------------------------------------------------------------------- stories

def story_issues(state="all"):
    items = gh_api("repos/%s/issues?labels=%s&state=%s&per_page=100" % (repo_slug(), STORY_LABEL, state))
    return [i for i in items if "pull_request" not in i]


def logins(issue):
    return [a["login"] for a in issue.get("assignees") or []]


def labels(issue):
    return [l["name"] for l in issue.get("labels") or []]


def order_key(issue):
    m = re.match(r"\s*S(\d+)\b", issue["title"])
    return (0, int(m.group(1)), issue["number"]) if m else (1, 0, issue["number"])


def story_path_of(issue):
    m = re.search(r"^\s*Story\s*[:：]\s*`?([^`\s]+\.md)`?", issue.get("body") or "", re.M)
    return m.group(1) if m else None


def story_field(path, field):
    try:
        text = (ROOT / path).read_text(encoding="utf-8")
    except OSError:
        return None
    m = re.search(r"^[>\-\s]*\**%s\**\s*:?\**\s*:?\s*(.+)$" % re.escape(field), text, re.M | re.I)
    return m.group(1).strip() if m else None


def my_open_stories(exclude=None):
    user = me()
    return [i for i in story_issues("open") if user in logins(i) and i["number"] != exclude]


def wip_problem(number):
    """Reason the user may not hold story `number`, or None."""
    issue = gh_api("repos/%s/issues/%d" % (repo_slug(), number))
    if "pull_request" in issue:
        return "#%d 是 PR，不是 issue。" % number
    if issue["state"] != "open":
        return "#%d 已經關閉。" % number
    owners = logins(issue)
    if me() not in owners:
        if owners:
            return "#%d 已經是 %s 的卡。" % (number, "、".join(owners))
        return "#%d 還沒有人認領。先用 `/claim-story %d` 認領（會 assign 給你並開好 branch）。" % (number, number)
    others = my_open_stories(exclude=number) if STORY_LABEL in labels(issue) else []
    if others:
        return "你手上已經有 %s 在進行中，每人同時最多 1 張。先把它做完（/ship-story），或請 PO 把它退回 backlog。" % (
            "、".join("#%d" % i["number"] for i in others))
    return None


# ------------------------------------------------------------------------ board

def pr_state(pr):
    repo = repo_slug()
    reviews = gh_api("repos/%s/pulls/%d/reviews?per_page=100" % (repo, pr["number"])) or []
    latest = {}
    for r in reviews:
        if r["user"]["login"] != pr["user"]["login"] and r["state"] in ("APPROVED", "CHANGES_REQUESTED", "DISMISSED"):
            latest[r["user"]["login"]] = r["state"]
    approved = sorted(u for u, s in latest.items() if s == "APPROVED")
    changes = sorted(u for u, s in latest.items() if s == "CHANGES_REQUESTED")
    runs = gh_api("repos/%s/commits/%s/check-runs?per_page=100" % (repo, pr["head"]["sha"]))["check_runs"]
    checks = {}
    for c in runs:
        checks[c["name"]] = c["conclusion"] or c["status"]
    return {"approved": approved, "changes": changes, "checks": checks}


def check_icon(value):
    return {"success": "✅", "failure": "❌", None: "—"}.get(value, "⏳" if value in ("queued", "in_progress") else str(value))


def cmd_board(args, compact=False):
    repo = repo_slug()
    user = me()
    branch = current_branch()
    issues = story_issues("all")
    prs = gh_api("repos/%s/pulls?state=open&per_page=50" % repo) or []
    with ThreadPoolExecutor(max_workers=6) as pool:
        states = dict(zip([p["number"] for p in prs], pool.map(pr_state, prs)))

    open_ = sorted([i for i in issues if i["state"] == "open"], key=order_key)
    closed = [i for i in issues if i["state"] == "closed"]
    mine = [i for i in open_ if user in logins(i)]
    ready = [i for i in open_ if not logins(i) and BLOCKED_LABEL not in labels(i)]
    blocked = [i for i in open_ if not logins(i) and BLOCKED_LABEL in labels(i)]
    others = [i for i in open_ if logins(i) and user not in logins(i)]
    pr_for = {}
    for p in prs:
        _, n = branch_issue(p["head"]["ref"])
        if n:
            pr_for[n] = p

    def pr_text(p):
        s = states[p["number"]]
        review = "已 approve：%s" % "、".join(s["approved"]) if s["approved"] else "等 review"
        if s["changes"]:
            review = "要求修改：%s" % "、".join(s["changes"])
        return "PR #%d（%s，測試 %s，流程 %s）" % (
            p["number"], review, check_icon(s["checks"].get(TEST_CHECK)), check_icon(s["checks"].get(PROCESS_CHECK)))

    def line(i):
        t = "#%d %s" % (i["number"], i["title"])
        if i["number"] in pr_for:
            t += " → " + pr_text(pr_for[i["number"]])
        return t

    dirty = [l for l in (git("status", "--porcelain", "--untracked-files=no") or "").splitlines() if l.strip()]
    out("== group-agile 團隊看板（%s，你是 %s）==" % (repo, user))
    out("目前 branch：%s%s" % (branch, "（有 %d 個檔案未 commit）" % len(dirty) if dirty else ""))
    out("進度：%d / %d 張 story 完成" % (len(closed), len(issues)))
    out("")
    out("你手上：" + ("沒有" if not mine else ""))
    for i in mine:
        out("  " + line(i))
        path = story_path_of(i)
        if path:
            out("    story 檔：%s（Status：%s）" % (path, story_field(path, "Status") or "讀不到，可能還沒 merge 到這個 branch"))
    out("可以拿（依 PO 排序，拿最上面那張）：" + ("沒有" if not ready else ""))
    for k, i in enumerate(ready[: 3 if compact else 10]):
        out("  %d. %s%s" % (k + 1, line(i), "  ← 下一張" if k == 0 else ""))
    if compact and len(ready) > 3:
        out("  …還有 %d 張，用 /board 看全部" % (len(ready) - 3))
    if others:
        out("其他人進行中：")
        for i in others:
            out("  %s：%s" % ("、".join(logins(i)), line(i)))
    if blocked:
        out("卡住（label blocked）：" + "、".join("#%d" % i["number"] for i in blocked))
    review_wait = [p for p in prs if p["user"]["login"] != user and user not in states[p["number"]]["approved"]]
    if review_wait:
        out("可以幫忙 review：" + "、".join("PR #%d（%s）" % (p["number"], p["user"]["login"]) for p in review_wait))

    # next step
    _, bn = branch_issue(branch)
    out("")
    if not issues:
        nxt = "Backlog 還是空的：PO 用 /publish-stories 把 story 開成 issue。"
    elif mine:
        i = mine[0]
        if i["number"] in pr_for:
            nxt = "等 PR #%d 的 review 與 CI；有人要求修改就在同一個 branch 修。" % pr_for[i["number"]]["number"]
        elif bn == i["number"]:
            path = story_path_of(i)
            nxt = "繼續做 #%d：%s；做完用 /ship-story。" % (i["number"], "/dev-story " + path if path else "/dev-story")
        else:
            nxt = "你手上有 #%d，但目前不在它的 branch。切過去：git switch %s" % (
                i["number"], next((b for b in (git("branch", "--format=%(refname:short)") or "").split() if branch_issue(b)[1] == i["number"]), "feat/%d-..." % i["number"]))
    elif ready:
        nxt = "用 /claim-story 認領 #%d。" % ready[0]["number"]
    else:
        nxt = "目前沒有可以拿的卡：幫忙 review，或問 PO 下一步。"
    if bn and not any(i["number"] == bn for i in mine) and branch_issue(branch)[0] in STORY_BRANCH_TYPES:
        nxt = "注意：目前 branch %s 對應的 #%d 不在你手上。%s" % (branch, bn, nxt)
    out("下一步：" + nxt)
    return 0


def cmd_session_start(args):
    out("[group-agile 團隊流程] 以下是開 session 時自動抓的團隊看板。規則見 docs/PROCESS.md。")
    try:
        cmd_board(args, compact=True)
    except GhError as e:
        out("看板讀取失敗（NOT ASSESSED）：%s" % e)
        out("沒有 gh 就看不到看板，守門 hook 也無法確認認領狀態，相關操作會先問使用者。")
    return 0


# ------------------------------------------------------------------------ claim

def slugify(text):
    s = re.sub(r"[^a-z0-9]+", "-", (text or "").lower()).strip("-")
    return "-".join(s.split("-")[:5])


def cmd_claim(args):
    po_ok = "--po-ok" in args
    nums = [a.lstrip("#") for a in args if a.lstrip("#").isdigit()]
    repo = repo_slug()
    user = me()
    dirty = [l for l in (git("status", "--porcelain", "--untracked-files=no") or "").splitlines() if l.strip()]
    if dirty:
        out("FAIL：還有未 commit 的變更，先 commit 或 stash 再認領。")
        return 1
    open_ = sorted(story_issues("open"), key=order_key)
    held = [i for i in open_ if user in logins(i)]
    ready = [i for i in open_ if not logins(i) and BLOCKED_LABEL not in labels(i)]
    target = int(nums[0]) if nums else (ready[0]["number"] if ready else None)
    if target is None:
        out("FAIL：沒有可以拿的 story。")
        return 1
    if any(i["number"] != target for i in held):
        out("FAIL：你手上已經有 %s，每人同時最多 1 張。" % "、".join("#%d" % i["number"] for i in held if i["number"] != target))
        return 1
    issue = gh_api("repos/%s/issues/%d" % (repo, target))
    if issue["state"] != "open" or STORY_LABEL not in labels(issue):
        out("FAIL：#%d 不是開著的 story issue。" % target)
        return 1
    owners = logins(issue)
    if owners and user not in owners:
        out("FAIL：#%d 已經是 %s 的卡。" % (target, "、".join(owners)))
        return 1
    if not owners:
        if BLOCKED_LABEL in labels(issue):
            out("FAIL：#%d 標了 blocked，先問 PO。" % target)
            return 1
        if ready and ready[0]["number"] != target and not po_ok:
            out("FAIL：最上面那張是 #%d。要跳過排序先問 PO；PO 同意後再加 --po-ok。" % ready[0]["number"])
            return 1
        gh_api("repos/%s/issues/%d/assignees" % (repo, target), "POST", {"assignees": [user]})
        issue = gh_api("repos/%s/issues/%d" % (repo, target))
        if user not in logins(issue):
            out("FAIL：assign 沒有成功（你可能不是 repo 的 collaborator）。")
            return 1
        if len(logins(issue)) > 1:
            gh_api("repos/%s/issues/%d/assignees" % (repo, target), "DELETE", {"assignees": [user]})
            out("FAIL：#%d 同時被 %s 認領，已撤回你的認領，請跟對方協調。" % (target, "、".join(l for l in logins(issue) if l != user)))
            return 1
    path = story_path_of(issue)
    slug = ""
    if path:
        slug = re.sub(r"^story-\d+-?", "", Path(path).stem)
    slug = slugify(slug) or slugify(re.sub(r"^\s*S\d+\s*", "", issue["title"])) or "story"
    branch = "feat/%d-%s" % (target, slug)
    existing = [b for b in (git("branch", "--format=%(refname:short)") or "").split() if branch_issue(b)[1] == target]
    if existing:
        p = run(["git", "switch", existing[0]])
        branch = existing[0]
    else:
        run(["git", "fetch", "origin", "main"], timeout=60)
        p = run(["git", "switch", "-c", branch, "origin/main"])
    if p is None or p.returncode != 0:
        out("FAIL：已認領 #%d，但切 branch 失敗：%s" % (target, (p.stderr if p else "").strip()))
        return 1
    out("OK：已認領 #%d %s，現在在 branch %s" % (target, issue["title"], branch))
    out("story 檔：%s" % (path or "issue 內文沒有寫 Story 路徑，請問 PO"))
    if path and not (ROOT / path).exists():
        out("注意：%s 在這個 branch 上不存在（story 檔可能還沒 merge 到 main）。" % path)
    out("下一步：/dev-story %s" % (path or ""))
    return 0


# -------------------------------------------------------------------- preflight

def commits_since(base):
    raw = git("log", "--format=%H%x1f%P%x1f%B%x1e", "%s..HEAD" % base) or ""
    result = []
    for rec in raw.split("\x1e"):
        rec = rec.strip("\n")
        if not rec.strip():
            continue
        sha, parents, body = rec.split("\x1f", 2)
        result.append({"sha": sha, "merge": len(parents.split()) > 1, "body": body.strip()})
    return result


def commit_problems(commits):
    bad = []
    for c in commits:
        if c["merge"]:
            continue
        subject = c["body"].splitlines()[0] if c["body"] else ""
        why = message_problem(c["body"], require_trailer=False)
        if why:
            bad.append("%s「%s」：%s" % (c["sha"][:7], subject, why))
    return bad


def message_problem(message, require_trailer=True):
    lines = message.strip().splitlines()
    subject = lines[0].strip() if lines else ""
    if not SUBJECT_RE.match(subject):
        return "第一行要是 `<type>(<scope>): <subject>`，type 只能是 %s" % " ".join(TYPES)
    if len(subject) > 72:
        return "第一行超過 72 字元"
    if subject.endswith(".") or subject.endswith("。"):
        return "第一行句尾不加句號"
    if require_trailer and not AI_TRAILER_RE.search(message):
        return "由 AI 協助的 commit 要在 footer 加 `Co-Authored-By: <模型> <noreply@anthropic.com>`"
    return None


def changed_files(base):
    return [l for l in (git("diff", "--name-only", "%s...HEAD" % base) or "").splitlines() if l]


def preflight_results():
    res = []
    branch = current_branch()
    btype, n = branch_issue(branch)
    if n is None:
        return [(FAIL, "branch", "目前 branch「%s」不是 `feat/<issue>-<名稱>`" % branch)], None
    res.append((PASS, "branch", branch))
    user = issue = None
    try:
        user = me()
        issue = gh_api("repos/%s/issues/%d" % (repo_slug(), n))
        if issue["state"] != "open":
            res.append((FAIL, "issue", "#%d 已經關閉" % n))
        elif user not in logins(issue):
            res.append((FAIL, "issue", "#%d 不在你手上（assignee：%s）" % (n, "、".join(logins(issue)) or "無")))
        else:
            res.append((PASS, "issue", "#%d %s" % (n, issue["title"])))
    except GhError as e:
        res.append((NA, "issue", str(e)))

    dirty = [l for l in (git("status", "--porcelain", "--untracked-files=no") or "").splitlines() if l.strip()]
    res.append((FAIL, "工作目錄", "還有 %d 個檔案未 commit" % len(dirty)) if dirty else (PASS, "工作目錄", "乾淨"))

    run(["git", "fetch", "origin", "main"], timeout=60)
    base = "origin/main"
    commits = commits_since(base)
    if not commits:
        res.append((FAIL, "commits", "這個 branch 相對 main 沒有任何 commit"))
    else:
        bad = commit_problems(commits)
        res.append((FAIL, "commit 格式", "；".join(bad)) if bad else (PASS, "commit 格式", "%d 個 commit 都符合 COMMIT_CONVENTION" % len(commits)))
    files = changed_files(base)

    # ai-log
    if not (ROOT / AI_LOG_DIR).is_dir():
        res.append((NA, "ai-log", "repo 還沒有 %s（PR #2 未 merge）" % AI_LOG_DIR))
    elif user is None:
        res.append((NA, "ai-log", "不知道你的 GitHub 帳號（gh 無法使用）"))
    else:
        log = "%s/log-%s.md" % (AI_LOG_DIR, user)
        text = (ROOT / log).read_text(encoding="utf-8") if (ROOT / log).exists() else ""
        if log not in files:
            res.append((FAIL, "ai-log", "這個 branch 沒有更新 %s（AI_LOGGING_RULES 第 2 節：commit 前就記完）" % log))
        elif not re.search(r"#%d\b" % n, text):
            res.append((FAIL, "ai-log", "%s 裡找不到任務 #%d 的紀錄" % (log, n)))
        elif "TODO(人填)" in text:
            res.append((FAIL, "ai-log", "%s 還有 `TODO(人填)` 沒填（結果、理由、工時要由人確認）" % log))
        else:
            res.append((PASS, "ai-log", log))

    # story status + evidence
    path = story_path_of(issue) if issue else None
    if btype not in STORY_BRANCH_TYPES:
        res.append((PASS, "story", "%s branch 不需要 story 檔" % btype))
    elif not path:
        res.append((NA, "story", "issue 內文沒有 `Story: <路徑>`，無法確認 /story-done 是否通過"))
    else:
        status = story_field(path, "Status")
        if status is None:
            res.append((NA, "story", "讀不到 %s 的 Status" % path))
        elif re.match(r"(?i)(complete|done)\b", status):
            res.append((PASS, "story", "%s Status：%s" % (path, status)))
        else:
            res.append((FAIL, "story", "%s Status 是「%s」，先跑 /story-done %s" % (path, status, path)))
        stype = (story_field(path, "Type") or "").lower()
        if stype.startswith(("logic", "integration")):
            ok = any(f.startswith("tests/") for f in files)
            res.append((PASS if ok else FAIL, "測試", "有改到 tests/" if ok else "%s 類 story 要有自動測試（tests/ 沒有變更）" % stype))
        elif stype.startswith(("ui", "visual")):
            ok = any(f.startswith("production/qa/evidence/") for f in files)
            res.append((PASS if ok else FAIL, "截圖", "有截圖" if ok else "%s 類 story 要附截圖（production/qa/evidence/ 沒有變更）" % stype))
        elif stype:
            res.append((PASS, "測試/截圖", "%s 類不強制" % stype))
        else:
            res.append((NA, "測試/截圖", "讀不到 story 的 Type"))
    return res, n


def cmd_preflight(args):
    try:
        res, _ = preflight_results()
    except GhError as e:
        out("NOT ASSESSED：%s" % e)
        return 3
    for status, name, detail in res:
        out("%-12s %s：%s" % (status, name, detail))
    if any(s == FAIL for s, _, _ in res):
        out("\n結果：FAIL，還不能開 PR。")
        return 1
    if any(s == NA for s, _, _ in res):
        out("\n結果：NOT ASSESSED，有項目無法確認，請使用者決定是否繼續。")
        return 3
    out("\n結果：PASS，可以開 PR。")
    return 0


# ---------------------------------------------------------------------- publish

def cmd_publish(args):
    dry = "--dry-run" in args
    dirs = [a for a in args if not a.startswith("--")]
    if not dirs:
        out("用法：publish production/epics/<epic> [--dry-run]")
        return 2
    folder = ROOT / dirs[0]
    if folder.name == "EPIC.md":
        folder = folder.parent
    files = sorted(folder.glob("story-*.md"))
    if not files:
        out("FAIL：%s 底下沒有 story-*.md" % dirs[0])
        return 1
    repo = repo_slug()
    existing = story_issues("all")
    next_s = max([order_key(i)[1] for i in existing if order_key(i)[0] == 0] or [0]) + 1
    if not dry:
        names = {l["name"] for l in gh_api("repos/%s/labels?per_page=100" % repo)}
        for name, color, desc in ((STORY_LABEL, "1d76db", "可認領的 story（/claim-story）"),
                                  (BLOCKED_LABEL, "b60205", "卡住，暫時不能拿")):
            if name not in names:
                gh_api("repos/%s/labels" % repo, "POST", {"name": name, "color": color, "description": desc})
    for f in files:
        rel = f.relative_to(ROOT).as_posix()
        text = f.read_text(encoding="utf-8")
        if story_field(rel, "Issue"):
            out("略過 %s（已經有 Issue：%s）" % (rel, story_field(rel, "Issue")))
            continue
        m = re.search(r"^#\s*Story\s*\d*\s*[:：]?\s*(.+)$", text, re.M)
        title = "S%02d %s" % (next_s, (m.group(1).strip() if m else f.stem))
        ac = re.search(r"^##\s*Acceptance Criteria\s*$(.*?)(?=^##\s|\Z)", text, re.M | re.S)
        body = "\n".join([
            "Story: `%s`" % rel,
            "Type: %s　Estimate: %s" % (story_field(rel, "Type") or "?", story_field(rel, "Estimate") or "?"),
            "",
            "## 驗收條件",
            (ac.group(1).strip() if ac else "（見 story 檔）"),
            "",
            "---",
            "認領：`/claim-story`（拿排序最上面那張）。完成的定義見 `docs/PROCESS.md`。",
        ])
        if dry:
            out("會建立：%s  ←  %s" % (title, rel))
        else:
            issue = gh_api("repos/%s/issues" % repo, "POST", {"title": title, "body": body, "labels": [STORY_LABEL]})
            p = run(["bash", ".claude/scripts/md-section.sh", "set-field", rel, "Issue", "#%d" % issue["number"], "--after", "Status"])
            note = "" if p is not None and p.returncode == 0 else "（寫回 story 檔失敗，請手動加 `> **Issue**: #%d`）" % issue["number"]
            out("已建立 #%d %s  ←  %s%s" % (issue["number"], title, rel, note))
        next_s += 1
    if not dry:
        out("\n下一步：把更新過的 story 檔用 PR 合進 main，組員才讀得到。")
    return 0


# ------------------------------------------------------------------ hook: guard

class Decision(Exception):
    def __init__(self, kind, reason):
        super().__init__(reason)
        self.kind, self.reason = kind, reason


def deny(reason):
    raise Decision("deny", reason)


def ask(reason):
    raise Decision("ask", reason)


HEREDOC_RE = re.compile(r"<<-?\s*(['\"]?)([A-Za-z_][A-Za-z0-9_]*)\1")


def extract_heredocs(cmd):
    """Replace each heredoc with a placeholder token; return (command, bodies)."""
    bodies = []
    out_lines = []
    lines = cmd.split("\n")
    i = 0
    while i < len(lines):
        line = lines[i]
        pending = []

        def repl(m):
            pending.append(m.group(2))
            bodies.append(None)
            return " __HD%d__ " % (len(bodies) - 1)

        line = HEREDOC_RE.sub(repl, line)
        out_lines.append(line)
        i += 1
        idx = len(bodies) - len(pending)
        for delim in pending:
            body = []
            while i < len(lines) and lines[i].strip() != delim:
                body.append(lines[i])
                i += 1
            i += 1
            bodies[idx] = "\n".join(body)
            idx += 1
    return "\n".join(out_lines), bodies


def split_commands(cmd):
    """Tokenize a shell command into simple commands. Raises ValueError."""
    lex = shlex.shlex(cmd, posix=True, punctuation_chars=";&|()\n")
    lex.whitespace = " \t\r"
    lex.whitespace_split = True
    cmds, cur = [], []
    for tok in lex:
        if tok and set(tok) <= set(";&|()\n"):
            if cur:
                cmds.append(cur)
            cur = []
        else:
            cur.append(tok)
    if cur:
        cmds.append(cur)
    return cmds


def resolve_text(value, bodies):
    m = re.fullmatch(r"\s*\$\(\s*cat\s+__HD(\d+)__\s*\)?\s*", value or "")
    if m:
        return bodies[int(m.group(1))]
    return re.sub(r"__HD(\d+)__", lambda mm: bodies[int(mm.group(1))] or "", value)


def opt_values(args, shorts, longs):
    vals = []
    i = 0
    while i < len(args):
        a = args[i]
        if a in shorts or a in longs:
            if i + 1 < len(args):
                vals.append(args[i + 1])
            i += 2
            continue
        for l in longs:
            if a.startswith(l + "="):
                vals.append(a[len(l) + 1:])
        for s in shorts:
            if len(s) == 2 and a.startswith(s) and len(a) > 2 and not a.startswith("--"):
                vals.append(a[2:])
        i += 1
    return vals


def git_sub(tokens):
    """('commit', args) for `git [-C x] [-c k=v] commit ...`, else (None, None)."""
    while tokens and re.match(r"^[A-Za-z_][A-Za-z0-9_]*=", tokens[0]):
        tokens = tokens[1:]
    if not tokens:
        return None, None
    exe = tokens[0].replace("\\", "/").rsplit("/", 1)[-1].lower()
    if exe in ("git", "git.exe"):
        i = 1
        while i < len(tokens) and tokens[i].startswith("-"):
            i += 2 if tokens[i] in ("-C", "-c", "--git-dir", "--work-tree") else 1
        if i < len(tokens):
            return "git " + tokens[i], tokens[i + 1:]
    if exe in ("gh", "gh.exe") and len(tokens) >= 3 and tokens[1] == "pr":
        return "gh pr " + tokens[2], tokens[3:]
    return None, None


def check_branch_name(name):
    if name in PROTECTED:
        return
    if not BRANCH_RE.match(name):
        deny("branch 名稱「%s」不符合規則。要用 `<type>/<issue 編號>-<英文小寫名稱>`，例如 `feat/12-crisis-wave`；"
             "開發 story 請直接用 /claim-story，它會幫你認領並開好 branch。" % name)
    btype, n = branch_issue(name)
    if btype in STORY_BRANCH_TYPES:
        try:
            why = wip_problem(n)
        except GhError as e:
            ask("無法確認 #%d 是否已由你認領、你手上有沒有其他卡（%s）。確定要開 %s 嗎？" % (n, e, name))
        if why:
            deny(why)


def check_commit(args, bodies):
    branch = current_branch()
    if branch in PROTECTED:
        deny("不能直接 commit 到 %s。先用 /claim-story 認領 story，在 feat/ branch 上 commit。" % branch)
    if branch != "HEAD" and not BRANCH_RE.match(branch):
        deny("目前 branch「%s」不符合 `<type>/<issue>-<名稱>`，先改名：`git branch -m <新名稱>`。" % branch)
    msgs = [resolve_text(v, bodies) for v in opt_values(args, ("-m",), ("--message",))]
    for f in opt_values(args, ("-F",), ("--file",)):
        if f == "-":
            msgs.append(next((b for b in bodies if b), ""))
        else:
            try:
                msgs.append((ROOT / f).read_text(encoding="utf-8"))
            except OSError:
                pass
    if not msgs:
        if "--no-edit" in args:
            return
        deny("請用 -m 帶入完整 commit message（含 Co-Authored-By footer），不要開編輯器。")
    why = message_problem("\n\n".join(msgs))
    if why:
        deny("commit message 不符合規則：%s。規則見 .gitmessage 與 docs/PROCESS.md。" % why)


def check_push(args):
    if "--all" in args or "--mirror" in args:
        deny("不能用 --all / --mirror push。只 push 自己的 branch：`git push -u origin <branch>`。")
    pos = [a for a in args if not a.startswith("-")]
    refspecs = pos[1:]
    if not refspecs:
        if current_branch() in PROTECTED:
            deny("不能直接 push main。main 只能透過 PR merge。")
        return
    for spec in refspecs:
        dest = spec.lstrip("+").split(":")[-1].replace("refs/heads/", "")
        if dest in PROTECTED or (spec.lstrip("+") in ("HEAD",) and current_branch() in PROTECTED):
            deny("不能直接 push 到 %s。main 只能透過 PR merge（1 人 review、CI 綠燈）。" % dest)


def check_new_branch(sub, args):
    names = []
    if sub == "git checkout":
        names = opt_values(args, ("-b", "-B"), ())
    elif sub == "git switch":
        names = opt_values(args, ("-c", "-C"), ("--create", "--force-create"))
    elif sub == "git worktree" and args[:1] == ["add"]:
        names = opt_values(args[1:], ("-b", "-B"), ())
    elif sub == "git branch":
        if any(a in ("-m", "-M", "--move") for a in args):
            pos = [a for a in args if not a.startswith("-")]
            names = pos[-1:]
        elif not any(a.startswith("-") for a in args):
            pos = [a for a in args]
            names = pos[:1]
    for name in names:
        check_branch_name(name)


def check_pr_create(args, bodies):
    head = (opt_values(args, ("-H",), ("--head",)) or [current_branch()])[0]
    head = head.split(":")[-1]
    base = (opt_values(args, ("-B",), ("--base",)) or ["main"])[0]
    if base not in PROTECTED:
        deny("PR 要開到 main（目前 --base %s）。" % base)
    btype, n = branch_issue(head)
    if n is None:
        deny("branch「%s」不符合 `<type>/<issue>-<名稱>`，不能開 PR。" % head)
    bodies_given = [resolve_text(v, bodies) for v in opt_values(args, ("-b",), ("--body",))]
    for f in opt_values(args, ("-F",), ("--body-file",)):
        if f == "-":
            bodies_given.append(next((b for b in bodies if b), ""))
        else:
            try:
                bodies_given.append((ROOT / f).read_text(encoding="utf-8"))
            except OSError:
                pass
    if not bodies_given:
        deny("請用 --body 或 --body-file 帶入 PR 範本（.github/pull_request_template.md）的內容，不要用 --fill 或編輯器。")
    body = "\n".join(bodies_given)
    if btype in STORY_BRANCH_TYPES:
        if not re.search(r"(?i)\b(close[sd]?|fix(e[sd])?|resolve[sd]?)\s+#%d\b" % n, body):
            deny("PR 內文要寫 `Closes #%d`，merge 後 issue 才會自動關閉。" % n)
    elif not re.search(r"#%d\b" % n, body):
        deny("PR 內文要寫 `Refs #%d` 或 `Closes #%d`。" % (n, n))
    if re.search(r"-\s*\[\s\]\s*本 PR 的 AI 使用已記入", body):
        deny("「AI 使用已記入 ai-log」還沒勾。先照 docs/ai-log/AI_LOGGING_RULES.md 記好再開 PR。")
    if head != current_branch():
        ask("要開 PR 的 branch（%s）不是目前 branch，無法做出貨前檢查。確定要開嗎？" % head)
    try:
        res, _ = preflight_results()
    except GhError as e:
        ask("無法完成出貨前檢查（%s）。確定要開 PR 嗎？" % e)
    fails = ["%s：%s" % (name, d) for s, name, d in res if s == FAIL]
    if fails:
        deny("還沒達到完成的定義，不能開 PR：\n- " + "\n- ".join(fails) + "\n（/ship-story 會一步步帶你補齊）")
    nas = ["%s：%s" % (name, d) for s, name, d in res if s == NA]
    if nas:
        ask("有項目無法確認：\n- " + "\n- ".join(nas) + "\n確定要開 PR 嗎？")


def check_pr_merge(args):
    if any(a in ("--squash", "-s", "--rebase", "-r") for a in args):
        deny("團隊規則用 merge commit，不 squash、不 rebase。請用 `gh pr merge <編號> --merge`。")
    if "--admin" in args or "--auto" in args:
        deny("不能用 --admin / --auto 跳過 review 與 CI。")
    if not any(a in ("--merge", "-m") for a in args):
        deny("請明確加 --merge（團隊規則用 merge commit）。")
    pos = [a for a in args if not a.startswith("-")]
    try:
        repo = repo_slug()
        if pos:
            m = re.search(r"(\d+)\s*$", pos[0])
            pr = gh_api("repos/%s/pulls/%s" % (repo, m.group(1) if m else pos[0]))
        else:
            owner = repo.split("/")[0]
            found = gh_api("repos/%s/pulls?state=open&head=%s:%s" % (repo, owner, current_branch()))
            if not found:
                deny("找不到目前 branch 的 PR，請指定編號。")
            pr = found[0]
        s = pr_state(pr)
    except GhError as e:
        ask("無法確認 review 與 CI 狀態（%s）。確定要 merge 嗎？" % e)
    problems = []
    if not s["approved"]:
        problems.append("還沒有組員 approve（至少 1 人 review）")
    if s["changes"]:
        problems.append("%s 要求修改，還沒重新 approve" % "、".join(s["changes"]))
    for name in (TEST_CHECK, PROCESS_CHECK):
        if s["checks"].get(name) != "success":
            problems.append("CI `%s` 不是綠燈（%s）" % (name, s["checks"].get(name) or "沒有跑"))
    if problems:
        deny("PR #%d 還不能 merge：\n- %s" % (pr["number"], "\n- ".join(problems)))


def check_command(cmd):
    if not re.search(r"\bgit\b|\bgh\b", cmd):
        return
    stripped, bodies = extract_heredocs(cmd)
    try:
        commands = split_commands(stripped)
    except ValueError:
        if re.search(r"\bgit\s+(commit|push|checkout|switch|branch)\b|\bgh\s+pr\s+(create|merge)\b", cmd):
            ask("守門 hook 解析不了這個指令，無法確認是否符合流程。確定要執行嗎？")
        return
    for tokens in commands:
        sub, args = git_sub(tokens)
        if sub == "git commit":
            check_commit(args, bodies)
        elif sub == "git push":
            check_push(args)
        elif sub in ("git checkout", "git switch", "git branch", "git worktree"):
            check_new_branch(sub, args)
        elif sub == "gh pr create":
            check_pr_create(args, bodies)
        elif sub == "gh pr merge":
            check_pr_merge(args)


def check_write(path):
    if not path:
        return
    p = Path(path)
    if not p.is_absolute():
        p = ROOT / p
    try:
        rel = p.resolve().relative_to(ROOT).as_posix()
    except ValueError:
        return
    if rel.startswith(".git/"):
        deny("不要直接改 .git/ 底下的檔案。")
    if any(rel == g or rel.startswith(g) for g in GUARD_FILES):
        ask("%s 是團隊流程守門本身的設定。修改前請確認 PO 同意（並告知角色 C）。確定要改嗎？" % rel)
    branch = current_branch()
    ignored = run(["git", "check-ignore", "-q", rel])
    if ignored is not None and ignored.returncode == 0:
        return
    if branch in PROTECTED or branch == "HEAD":
        deny("現在在 %s，不能直接改 repo 裡的檔案（%s）。先用 /claim-story 認領 story，它會開好 feat/ branch。" % (branch, rel))
    if not BRANCH_RE.match(branch):
        deny("目前 branch「%s」不符合 `<type>/<issue>-<名稱>`，先改名：`git branch -m <新名稱>`。" % branch)


def cmd_hook_pretool(args):
    raw = sys.stdin.buffer.read().decode("utf-8", errors="replace")
    try:
        data = json.loads(raw)
    except ValueError:
        return 0
    tool = data.get("tool_name", "")
    ti = data.get("tool_input") or {}
    try:
        if tool in ("Write", "Edit", "MultiEdit", "NotebookEdit"):
            check_write(ti.get("file_path") or ti.get("notebook_path"))
        elif tool in ("Bash", "PowerShell"):
            check_command(ti.get("command") or "")
    except GhError as e:
        d = Decision("ask", "守門 hook 無法確認流程狀態（%s）。確定要繼續嗎？" % e)
        return emit_decision(d)
    except Decision as d:
        return emit_decision(d)
    return 0


def emit_decision(d):
    if d.kind == "deny":
        err(TAG + d.reason + "\n（這是 docs/PROCESS.md 的團隊規則。請向使用者說明並改走正確流程，不要換個寫法繞過。）")
        return 2
    out(json.dumps({"hookSpecificOutput": {
        "hookEventName": "PreToolUse",
        "permissionDecision": "ask",
        "permissionDecisionReason": TAG + d.reason,
    }}, ensure_ascii=False))
    return 0


# --------------------------------------------------------------------- ci-check

def cmd_ci_check(args):
    event = json.loads(Path(os.environ["GITHUB_EVENT_PATH"]).read_text(encoding="utf-8"))
    pr = event["pull_request"]
    branch, base = pr["head"]["ref"], pr["base"]["ref"]
    body = pr.get("body") or ""
    author = pr["user"]["login"]
    base_sha, head_sha = pr["base"]["sha"], pr["head"]["sha"]
    res = []
    btype, n = branch_issue(branch)
    res.append((PASS, "branch", branch) if n else (FAIL, "branch", "「%s」不符合 `<type>/<issue>-<名稱>`" % branch))
    res.append((PASS, "base", base) if base in PROTECTED else (FAIL, "base", "要開到 main"))
    if n:
        if btype in STORY_BRANCH_TYPES:
            ok = re.search(r"(?i)\b(close[sd]?|fix(e[sd])?|resolve[sd]?)\s+#%d\b" % n, body)
            res.append((PASS, "Closes", "#%d" % n) if ok else (FAIL, "Closes", "內文要寫 `Closes #%d`" % n))
        else:
            ok = re.search(r"#%d\b" % n, body)
            res.append((PASS, "Refs", "#%d" % n) if ok else (FAIL, "Refs", "內文要寫 `Refs #%d` 或 `Closes #%d`" % (n, n)))
    box = re.search(r"-\s*\[([ xX])\]\s*本 PR 的 AI 使用已記入", body)
    if not box:
        res.append((FAIL, "PR 範本", "內文缺少 PR 範本的「AI 使用」勾選欄"))
    elif box.group(1) == " ":
        res.append((FAIL, "ai-log 勾選", "「AI 使用已記入 ai-log」沒有勾"))
    else:
        res.append((PASS, "ai-log 勾選", "已勾"))
    commits = commits_since(base_sha) if git("rev-parse", "HEAD") == head_sha else []
    if not commits:
        raw = git("log", "--format=%H%x1f%P%x1f%B%x1e", "%s..%s" % (base_sha, head_sha)) or ""
        commits = [{"sha": r.split("\x1f")[0].strip(), "merge": len(r.split("\x1f")[1].split()) > 1,
                    "body": r.split("\x1f", 2)[2].strip()} for r in raw.split("\x1e") if r.strip()]
    bad = commit_problems(commits)
    res.append((FAIL, "commit 格式", "；".join(bad)) if bad else (PASS, "commit 格式", "%d 個 commit" % len(commits)))
    files = [l for l in (git("diff", "--name-only", "%s...%s" % (base_sha, head_sha)) or "").splitlines() if l]
    others = [f for f in files if re.match(r"^%s/log-(.+)\.md$" % AI_LOG_DIR, f)
              and f != "%s/log-%s.md" % (AI_LOG_DIR, author) and not f.endswith("log-TEMPLATE.md")]
    if others:
        res.append((FAIL, "ai-log", "不可修改他人的 log 檔：%s" % "、".join(others)))
    ai_commits = [c for c in commits if not c["merge"] and AI_TRAILER_RE.search(c["body"])]
    log = "%s/log-%s.md" % (AI_LOG_DIR, author)
    if ai_commits:
        text = (ROOT / log).read_text(encoding="utf-8") if (ROOT / log).exists() else ""
        if log not in files:
            res.append((FAIL, "ai-log", "%d 個 commit 有 AI footer，但這個 PR 沒有更新 %s" % (len(ai_commits), log)))
        elif n and not re.search(r"#%d\b" % n, text):
            res.append((FAIL, "ai-log", "%s 裡找不到任務 #%d 的紀錄" % (log, n)))
        elif "TODO(人填)" in text:
            res.append((FAIL, "ai-log", "%s 還有 `TODO(人填)`" % log))
        else:
            res.append((PASS, "ai-log", log))
    lines = ["## 團隊流程檢查（docs/PROCESS.md）", "", "| 結果 | 項目 | 說明 |", "| --- | --- | --- |"]
    for s, name, d in res:
        lines.append("| %s | %s | %s |" % ({"PASS": "✅", "FAIL": "❌"}.get(s, "⚠️"), name, d.replace("|", "\\|")))
    report = "\n".join(lines)
    out(report)
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as fh:
            fh.write(report + "\n")
    return 1 if any(s == FAIL for s, _, _ in res) else 0


# ------------------------------------------------------------------------- main

COMMANDS = {
    "board": cmd_board,
    "session-start": cmd_session_start,
    "claim": cmd_claim,
    "preflight": cmd_preflight,
    "publish": cmd_publish,
    "hook-pretool": cmd_hook_pretool,
    "ci-check": cmd_ci_check,
}


def main(argv):
    if not argv or argv[0] not in COMMANDS:
        out("用法：team.sh {%s}" % "|".join(COMMANDS))
        return 2
    try:
        return COMMANDS[argv[0]](argv[1:])
    except GhError as e:
        out("NOT ASSESSED：%s" % e)
        return 3


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
