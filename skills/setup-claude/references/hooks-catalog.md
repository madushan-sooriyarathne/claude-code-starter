# Hooks Catalog

Ten deterministic shell hooks, copied from `${CLAUDE_PLUGIN_ROOT}/hooks/` (slash command)
or `$SCRIPT_DIR/hooks/` (install.sh) into the target project's `.claude/hooks/`, then
registered in `.claude/settings.json`.

All hooks read the tool-call JSON from stdin, exit `0` to allow and exit `2` to block
(stderr is fed back to Claude). No external dependencies are required beyond `jq` (hooks
that need it fail closed — deny — if it's missing).

| # | Hook | File | Event / matcher | Behavior | Recommend when |
|---|------|------|-----------------|----------|----------------|
| 1 | `block-dangerous-commands` | `block-dangerous-commands.sh` | `PreToolUse` / `Bash` | Blocks `rm -rf` on root/home, `DROP TABLE`, `TRUNCATE`, `git push --force` (without `--force-with-lease`), `git commit/push --no-verify` | **Always pre-mark** (safety) |
| 2 | `scan-secrets` | `scan-secrets.sh` | `PreToolUse` / `Write\|Edit` | Blocks writing hardcoded secrets (provider token shapes, DB connection strings with creds, generic secret assignments). Skips `*.example`/`*.sample`/`*.md`; ignores env-var references and placeholders | **Always pre-mark** (safety) |
| 3 | `protect-files` | `protect-files.sh` | `PreToolUse` / `Write\|Edit` | Blocks edits to `.env*`, key/cert files, lockfiles, generated/minified files, `.git/`, `secrets/`, and `.claude/hooks/*`; asks for confirmation before editing `.claude/settings*.json` | **Always pre-mark** (safety) |
| 4 | `warn-large-files` | `warn-large-files.sh` | `PreToolUse` / `Write\|Edit` | Blocks writes into `node_modules/`, `vendor/`, build output dirs, Python venvs/`__pycache__`, and binary/archive/media file extensions | **Always pre-mark** (safety) |
| 5 | `format-on-save` | `format-on-save.sh` | `PostToolUse` / `Write\|Edit` | Runs `biome check --write` on `.ts`/`.tsx` files. No-ops silently if no `biome.json`/`biome.jsonc` found or no biome binary available. Never blocks or errors | `biome.json` or `biome.jsonc` detected |
| 6 | `auto-test` | `auto-test.sh` | `PostToolUse` / `Write\|Edit` | Finds and runs the matching test file after an edit. Silent on success — only emits output (and tokens) on failure. Skips test files, config files, non-testable extensions | A test runner detected **and** explicitly selected — warn the user this runs on every edit, only sensible with a fast suite |
| 7 | `typecheck-on-stop` | `typecheck-on-stop.sh` | `PostToolUse(Edit\|Write)` marks dirty; `Stop` runs once | Runs the project's type-check once per turn (not per-file) when files changed. Silent on success; exits 2 with errors on failure so Claude keeps working | `tsconfig.json` or other typed-language config detected |
| 8 | `lint-on-stop` | `lint-on-stop.sh` | `PostToolUse(Edit\|Write)` marks dirty; `Stop` runs once | Runs the project's linter once per turn (not per-file) when files changed. Silent on success; exits 2 with errors on failure | A linter config detected (Biome, ESLint, Ruff, etc.) |
| 9 | `notify` | `notify.sh` | `Notification` | Native OS notification (macOS/Linux/WSL) when Claude needs attention | Personal taste — offer, default off |
| 10 | `session-start` | `session-start.sh` | `SessionStart` / `startup\|resume\|clear` | Injects branch + dirty-state context (~5-10 tokens). Also doubles as the fingerprint writer for drift detection (see Step 6) | Cheap, default on |

## settings.json registration

Merge the following into the target's `.claude/settings.json` (create if missing, merge
without clobbering existing hooks). Only include the blocks for hooks the user actually
selected — do not register a hook that wasn't installed.

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          { "type": "command", "command": "bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/block-dangerous-commands.sh\"" }
        ]
      },
      {
        "matcher": "Write|Edit",
        "hooks": [
          { "type": "command", "command": "bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/protect-files.sh\"" },
          { "type": "command", "command": "bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/warn-large-files.sh\"" },
          { "type": "command", "command": "bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/scan-secrets.sh\"" }
        ]
      }
    ],
    "PostToolUse": [
      {
        "matcher": "Write|Edit",
        "hooks": [
          { "type": "command", "command": "bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/format-on-save.sh\"" },
          { "type": "command", "command": "bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/auto-test.sh\"" },
          { "type": "command", "command": "bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/typecheck-on-stop.sh\"" },
          { "type": "command", "command": "bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/lint-on-stop.sh\"" }
        ]
      }
    ],
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          { "type": "command", "command": "bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/typecheck-on-stop.sh\"" },
          { "type": "command", "command": "bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/lint-on-stop.sh\"" }
        ]
      }
    ],
    "SessionStart": [
      {
        "matcher": "startup|resume|clear",
        "hooks": [
          { "type": "command", "command": "bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/session-start.sh\"" }
        ]
      }
    ],
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          { "type": "command", "command": "bash \"$CLAUDE_PROJECT_DIR/.claude/hooks/notify.sh\"" }
        ]
      }
    ]
  }
}
```

Notes:

- The `Write|Edit` matcher (rather than `Write` only) ensures `Edit` operations are also
  scanned/formatted/protected — Edit modifies file contents too.
- `typecheck-on-stop` and `lint-on-stop` need **both** their `PostToolUse` (dirty-marking)
  and `Stop` (run-once) entries — installing one without the other leaves it inert.
- `$CLAUDE_PROJECT_DIR` resolves to the project root at runtime, so the registration is
  portable across machines.
- When merging into an existing `settings.json`, append hook entries idempotently — do not
  add a duplicate entry for a hook command that is already registered.
