#!/usr/bin/env bash
# Antigravity-native duplicate of hooks/claude/session-start.sh.
# Antigravity has no "SessionStart" event. Closest available substitute:
# PreInvocation, which fires before every model call -- gated here to only
# act on invocationNum==0 (the first model call of the conversation), since
# it would otherwise run this git plumbing on every single turn.
#
# Output goes through injectSteps.ephemeralMessage (a transient system
# message) instead of Claude's direct SessionStart context injection.
#
# ponytail: intentionally duplicated logic, not shared with the Claude-side
# script. Keep both in sync by hand when detection rules change.

set -uo pipefail

manifest_hash() {
  local root="$1"
  {
    if command -v jq >/dev/null 2>&1 && [ -f "$root/package.json" ]; then
      jq -S '.scripts // {}' "$root/package.json"
    elif [ -f "$root/package.json" ]; then
      cat "$root/package.json"
    fi
    for f in pyproject.toml Cargo.toml go.mod Gemfile composer.json Makefile; do
      [ -f "$root/$f" ] && cat "$root/$f"
    done
  } 2>/dev/null | cksum | tr -d ' '
}

# Fingerprint mode: same CLI contract as the Claude-side script, invoked
# directly by /setup-agents / install.sh at finalize time, not through the
# PreInvocation hook event.
# Used as: AGENT_STARTER_FINGERPRINT=1 session-start.sh > .agent-starter.json
if [ "${AGENT_STARTER_FINGERPRINT:-0}" = "1" ]; then
  printf '{"setup_date":"%s","manifest_hash":"%s"}\n' "$(date +%Y-%m-%d)" "$(manifest_hash "$PWD")"
  exit 0
fi

command -v jq >/dev/null 2>&1 || { printf '{}\n'; exit 0; }

INPUT=$(cat)
INVOCATION_NUM=$(printf '%s' "$INPUT" | jq -r '.invocationNum // -1')
# Cheap bail: only act on the very first model call of the conversation.
[ "$INVOCATION_NUM" = "0" ] || { printf '{}\n'; exit 0; }

ROOT=$(printf '%s' "$INPUT" | jq -r '.workspacePaths[0] // empty')
[ -z "$ROOT" ] && ROOT="$PWD"

# Bail early if not in a git repo (nothing useful to inject).
git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1 || { printf '{}\n'; exit 0; }

VERBOSE="${AGENT_STARTER_SESSION_VERBOSE:-0}"
CONTEXT=""

# Branch (essential, cheap).
BRANCH=$(git -C "$ROOT" branch --show-current 2>/dev/null)
if [ -n "$BRANCH" ]; then
  CONTEXT="Branch: $BRANCH"
else
  SHORT_SHA=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)
  [ -n "$SHORT_SHA" ] && CONTEXT="HEAD: detached at $SHORT_SHA"
fi

# Dirty indicator (binary, ~free, very useful).
if ! git -C "$ROOT" diff-index --quiet HEAD -- 2>/dev/null; then
  CONTEXT="$CONTEXT | dirty"
fi

# Config drift nudge (one short line, only when manifests changed since setup).
META="${AGENT_STARTER_META:-$ROOT/.agents/plugins/setup-agents/.agent-starter.json}"
if [ -f "$META" ]; then
  SAVED=$(grep -o '"manifest_hash"[: ]*"[^"]*"' "$META" 2>/dev/null | grep -o '"[^"]*"$' | tr -d '"')
  if [ -n "$SAVED" ] && [ "$(manifest_hash "$ROOT")" != "$SAVED" ]; then
    DRIFT="config drift: project manifests changed since setup. Re-run /setup-agents to re-tune"
    if [ -n "$CONTEXT" ]; then CONTEXT="$CONTEXT | $DRIFT"; else CONTEXT="$DRIFT"; fi
  fi
fi

# Verbose extras (opt-in via AGENT_STARTER_SESSION_VERBOSE=1).
if [ "$VERBOSE" = "1" ]; then
  LAST_COMMIT=$(git -C "$ROOT" log --oneline -1 2>/dev/null)
  [ -n "$LAST_COMMIT" ] && CONTEXT="$CONTEXT | Last: $LAST_COMMIT"

  CHANGES=$(git -C "$ROOT" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  [ "$CHANGES" -gt 0 ] 2>/dev/null && CONTEXT="$CONTEXT | $CHANGES files changed"

  if ! git -C "$ROOT" diff --cached --quiet 2>/dev/null; then
    CONTEXT="$CONTEXT | staged"
  fi

  STASH_COUNT=$(git -C "$ROOT" stash list 2>/dev/null | wc -l | tr -d ' ')
  [ "$STASH_COUNT" -gt 0 ] 2>/dev/null && CONTEXT="$CONTEXT | $STASH_COUNT stash(es)"

  if command -v gh >/dev/null 2>&1; then
    PR_INFO=$(cd "$ROOT" && gh pr view --json number,title,state --jq '"PR #\(.number): \(.title) (\(.state))"' 2>/dev/null)
    [ -n "$PR_INFO" ] && CONTEXT="$CONTEXT | $PR_INFO"
  fi
fi

if [ -n "$CONTEXT" ]; then
  jq -cn --arg m "$CONTEXT" '{injectSteps: [{ephemeralMessage: $m}]}'
else
  printf '{}\n'
fi
