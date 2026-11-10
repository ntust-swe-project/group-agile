#!/bin/bash
# Entry point for the group-agile team process (docs/PROCESS.md).
# Finds a Python 3 the same way CCGS's yaml-helper does (python -> python3 -> py)
# and runs team.py. Used by the hooks in .claude/settings.json and the skills.
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
for candidate in python python3 py; do
  if command -v "$candidate" >/dev/null 2>&1 &&
     "$candidate" -c 'import sys; sys.exit(0 if sys.version_info[0] == 3 else 1)' >/dev/null 2>&1; then
    PYTHONIOENCODING=utf-8 exec "$candidate" "$HERE/team.py" "$@"
  fi
done
# No Python: say so instead of passing silently.
case "$1" in
  session-start)
    echo "[group-agile 團隊流程] 找不到 Python 3，看板與守門 hook 都沒有啟用（NOT ASSESSED）。請安裝 Python 3（Issue #1 準備清單）。" ;;
  hook-pretool)
    INPUT=$(cat)
    case "$INPUT" in
      *'"tool_input"'*git*|*'"tool_input"'*gh*|*'"tool_name":"Write"'*|*'"tool_name":"Edit"'*)
        printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"【團隊流程】找不到 Python 3，守門 hook 無法檢查這一步是否符合流程。確定要繼續嗎？"}}' ;;
    esac ;;
  *)
    echo "NOT ASSESSED：找不到 Python 3（試過 python、python3、py）。" ; exit 3 ;;
esac
exit 0
