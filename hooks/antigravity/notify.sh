#!/usr/bin/env bash
# Antigravity-native duplicate of hooks/claude/notify.sh.
# Antigravity has no "Notification" event. Closest available signal: Stop
# firing with fullyIdle:true (the agent is completely finished, nothing
# running in the background) -- roughly the "needs your attention" case.
# The permission-prompt case Claude's Notification hook also covers doesn't
# need a hook here: Antigravity's client already surfaces that natively via
# the "ask"/"force_ask" PreToolUse decision.
#
# ponytail: intentionally duplicated logic, not shared with the Claude-side
# script. Keep both in sync by hand when detection rules change.

set -uo pipefail

ok() { printf '{"decision":"ok"}\n'; exit 0; }

# Can't tell fullyIdle without jq -- default to not notifying rather than guessing.
command -v jq >/dev/null 2>&1 || ok

INPUT=$(cat)
FULLY_IDLE=$(printf '%s' "$INPUT" | jq -r '.fullyIdle // false')
[ "$FULLY_IDLE" = "true" ] || ok

REASON=$(printf '%s' "$INPUT" | jq -r '.terminationReason // empty')
MESSAGE="Antigravity finished and is idle"
[ -n "$REASON" ] && MESSAGE="Antigravity finished ($REASON)"

TITLE="Antigravity"

# Test/dry-run mode: print instead of notifying (used by hook fixtures).
if [ "${AGENT_STARTER_NOTIFY_DRYRUN:-0}" = "1" ]; then
  echo "notify: $TITLE: $MESSAGE"
  ok
fi

# macOS
if command -v osascript >/dev/null 2>&1; then
  osascript -e "display notification \"$MESSAGE\" with title \"$TITLE\"" 2>/dev/null
  ok
fi

# Linux (native)
if command -v notify-send >/dev/null 2>&1; then
  notify-send "$TITLE" "$MESSAGE" 2>/dev/null
  ok
fi

# WSL → Windows toast
if command -v powershell.exe >/dev/null 2>&1; then
  powershell.exe -Command "[System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms') | Out-Null; \$n = New-Object System.Windows.Forms.NotifyIcon; \$n.Icon = [System.Drawing.SystemIcons]::Information; \$n.Visible = \$true; \$n.ShowBalloonTip(5000, '$TITLE', '$MESSAGE', 'Info')" 2>/dev/null
  ok
fi

ok
