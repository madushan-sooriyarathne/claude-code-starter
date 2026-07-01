# Hooks

Hook scripts are deterministic enforcement. Unlike rules (advisory), hooks **guarantee** behavior by blocking or modifying tool calls before or after they execute.

Scripts live in two host-specific directories — `claude/` and `antigravity/` — never a shared one. Each host has its own stdin/stdout contract, so a hook that runs on both hosts is **duplicated**, not shared: `hooks/claude/protect-files.sh` and `hooks/antigravity/protect-files.sh` implement the same detection rules independently. There's no translation shim between them — keep both in sync by hand when detection rules change.

`hooks/tests/fixtures/` mirrors the same split (`fixtures/claude/<name>/`, `fixtures/antigravity/<name>/`); `tests/` holds the fixture suite (`bash hooks/tests/run-all.sh`) and doesn't belong in a project's `.claude/hooks/`.

## Claude Code hooks

Wired in `settings.json` under the `"hooks"` key. Each hook specifies an event, a matcher, and a command to run. `timeout` values are in **seconds**.

The four PreToolUse guards below are also packaged as the `safety-hooks` plugin (`/plugin install safety-hooks@agent-starter`) via `plugins/safety-hooks/hooks/hooks.json`, so you can get them without copying any files.

### protect-files.sh
**Event**: PreToolUse (`Edit` | `Write`)

Blocks edits to sensitive and generated files. Fails closed (blocks if `jq` is missing).

- `.env`, `.env.*`. Secrets, by basename and path.
- `*.pem`, `*.key`, `*.crt`, `*.p12`, `*.pfx`. Certificates and keys.
- `id_rsa`, `id_ed25519`, `credentials.json`, `.npmrc`, `.pypirc`. Credentials.
- `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`. Lock files.
- `*.gen.ts`, `*.generated.*`. Generated code.
- `*.min.js`, `*.min.css`. Minified bundles.
- Anything inside `.git/`, `secrets/`, or `.claude/hooks/`.
- Self-protecting: blocks edits to hook scripts and `settings.json`.

### warn-large-files.sh
**Event**: PreToolUse (`Edit` | `Write`)

Blocks writes to build artifacts, dependency directories, and binary files. Fails closed.

- `node_modules/`, `vendor/`, `dist/`, `build/`, `.next/`, `__pycache__/`, `.venv/`.
- `*.wasm`, `*.so`, `*.dylib`, `*.dll`, `*.exe`, `*.zip`, `*.tar.*`.
- `*.mp4`, `*.mov`, `*.mp3`, `*.pyc`, `*.class`.

### block-dangerous-commands.sh
**Event**: PreToolUse (`Bash`)

Blocks dangerous shell commands. Detects patterns even in chained commands (`&&`, `;`). Fails closed.

- **Git**: `git push origin main/master`, `git push --force` (allows `--force-with-lease`), bare `git push` on main.
- **Filesystem**: `rm -rf /`, `rm -rf ~`, recursive delete on root/home paths.
- **Database**: `DROP TABLE/DATABASE`, `DELETE FROM` without WHERE, `TRUNCATE TABLE`.
- **System**: `chmod 777`, piping `curl`/`wget` to `bash`/`sh`, `mkfs`, `dd if=`, writes to `/dev/`.

### scan-secrets.sh
**Event**: PreToolUse (`Edit` | `Write`)

Scans content being written for accidental secrets. Uses `ask` (not `deny`) — warns and lets you override, since a match could be a test fixture. Fails open if `jq` is missing (not a file-protection hook).

- AWS access key IDs (`AKIA...`) and secret keys.
- GitHub tokens (`ghp_`, `gho_`, `ghs_`, `ghr_`, `github_pat_`).
- API keys shaped like `sk-...` (OpenAI, Stripe, Anthropic).
- Slack tokens (`xox[bpras]-...`).
- Private key blocks (`-----BEGIN ... PRIVATE KEY-----`).
- Connection strings with embedded credentials (`mongodb://user:pass@...`, etc.).
- Generic `password`/`secret`/`token`/`api_key` assignments with a literal string value — ignores env-var references (`process.env`, `os.environ`, `${...}`, `getenv(...)`).

### format-on-save.sh
**Event**: PostToolUse (`Edit` | `Write`)

Auto-formats files after Claude edits them. Auto-detects formatters by checking for both the binary and a config file:

- Biome: `biome.json` plus `node_modules/.bin/biome`.
- Prettier: `.prettierrc*` or `package.json` prettier key plus `node_modules/.bin/prettier`.
- Ruff: `ruff.toml` or `pyproject.toml [tool.ruff]` plus `ruff` binary.
- Black: `pyproject.toml [tool.black]` plus `black` binary.
- rustfmt: standard for Rust (no config needed).
- gofmt: standard for Go (no config needed).

### session-start.sh
**Event**: SessionStart

Injects dynamic project context at session start.

**Default (minimal, ~5 to 10 tokens)**: current branch (or detached HEAD warning) and a `dirty` tag if there are uncommitted changes. That's it. No network calls, no extra detail.

**Verbose**: set `AGENT_STARTER_SESSION_VERBOSE=1` in your shell to also emit:
- Last commit oneline.
- Uncommitted file count.
- Staged indicator.
- Stash count.
- Active PR info via `gh` (adds a network round-trip).

The verbose payload runs ~30 to 90 tokens per session. Default is recommended for daily iterative work where every new conversation pays this cost.

**Drift nudge**: if `.claude/.agent-starter.json` exists (written by `/setup-agents` at the end of setup), the hook hashes the project's manifests (`package.json` scripts, `pyproject.toml`, `Cargo.toml`, `go.mod`, `Gemfile`, `composer.json`, `Makefile`) and appends a one-line re-tune nudge only when the hash no longer matches. `AGENT_STARTER_FINGERPRINT=1 session-start.sh` prints the fingerprint JSON (how the skill writes the file); `AGENT_STARTER_META` overrides the fingerprint path (used by tests).

### auto-test.sh
**Event**: PostToolUse (`Edit` | `Write`)

Finds and runs the test file matching the edited source file (same-dir, `__tests__/`, or parallel `tests/` conventions; vitest/jest/mocha, pytest/unittest, `go test`, `cargo test`). Silent on success — passing tests contribute zero tokens. Only emits output when tests fail. Skips test files themselves, config files, and non-code extensions.

### typecheck-on-stop.sh
**Event**: PostToolUse (`Edit` | `Write`) + Stop

Runs the project's type-check once Claude finishes its whole turn — not after every single file edit. `PostToolUse` just marks the session dirty (cheap); `Stop` checks the marker, runs the check, clears it. Silent on success; on failure exits 2 so Claude sees the errors and keeps working instead of stopping. Guards against `stop_hook_active` to avoid retriggering itself in a loop.

- JS/TS: runs the `typecheck` or `check-types` script from `package.json`, via the detected package manager (`bun`/`pnpm`/`yarn`/`npm`, by lockfile).
- Go: `go vet ./...` (Go has no separate type-check command).
- Rust: `cargo check`.
- No matching manifest or script: skips silently.

### lint-on-stop.sh
**Event**: PostToolUse (`Edit` | `Write`) + Stop

Same dirty-marker/Stop pattern as `typecheck-on-stop.sh`, for linting.

- JS/TS: runs the `lint` script from `package.json`, via the detected package manager.
- Go: `golangci-lint run` if installed (no fallback — `go vet` is already covered by `typecheck-on-stop.sh`).
- Rust: `cargo clippy --all-targets` if installed.
- No matching manifest, script, or linter binary: skips silently.

### notify.sh
**Event**: Notification

Sends a native OS notification when Claude needs your attention. Supports macOS (`osascript`), Linux (`notify-send`), and WSL (PowerShell toast). Extracts the actual message from the hook input when `jq` is available. Exits silently when no notifier exists. Set `AGENT_STARTER_NOTIFY_DRYRUN=1` to print instead of notify (used by the test fixtures).

## Antigravity-native hooks

All 10 Claude hooks have an Antigravity counterpart. Installed into `.agents/plugins/setup-agents/` by `install.sh` when the Antigravity host is selected, always exiting 0 (the gate/result lives in stdout, not the exit code) — same detection logic as the `hooks/claude/` counterpart, reimplemented against Antigravity's contract rather than translated into it.

**PreToolUse (direct port)** — reads `{"toolCall":{"name","args":{...}}}` stdin, writes `{"decision":"allow|deny|ask","reason":"..."}`:

- `protect-files.sh`, `warn-large-files.sh` — file path via `.toolCall.args.TargetFile`. No jq → deny (fail closed, matches the Claude-side script).
- `block-dangerous-commands.sh` — command via `.toolCall.args.CommandLine`, matcher `run_command`. No jq → deny.
- `scan-secrets.sh` — content field depends on `.toolCall.name`: `write_to_file`→`CodeContent`, `replace_file_content`→`ReplacementContent`, `multi_replace_file_content`→joined `ReplacementChunks[].ReplacementContent`. No jq → allow (fail open, matches the Claude-side script — it's a warn-and-override hook, not file protection).

**Stop / PreInvocation (redesigned)** — Antigravity's `PostToolUse` carries no tool args at all (no file path, no tool name), so nothing that needs "which file was just edited" can trigger off it. These 6 move to `Stop` (fires once the execution loop is about to fully terminate) or `PreInvocation` (fires before every model call), using `git status`/`git diff` against `workspacePaths[0]` instead of a per-edit marker:

- `typecheck-on-stop.sh`, `lint-on-stop.sh` — **Stop**. Live `git status --porcelain` replaces the Claude-side PostToolUse dirty-marker. Same typecheck/lint cascade. On failure, requests `{"decision":"continue","reason":"..."}` — `reason` only reaches the agent when `decision` is `"continue"` — guarded by a `conversationId`-keyed `/tmp` marker so it nags at most once per conversation per failing state (Antigravity's `Stop` schema has no `stop_hook_active`-equivalent field; this loop-guard is inferred, not documented — **needs live verification against a real Antigravity instance**).
- `format-on-save.sh` — **Stop**. Formats every file `git diff --name-only HEAD` (plus untracked new files) shows as changed, batched once per turn instead of per-edit. Never requests `"continue"`.
- `auto-test.sh` — **Stop**. Same git-diff-driven batching, runs the matching test file per changed file. Never requests `"continue"` (matches Claude-side: reports failures, never blocks). Less surgical than the Claude version — tests every dirty file at Stop, including pre-existing uncommitted changes the agent never touched.
- `notify.sh` — **Stop**. Antigravity has no `Notification` event; fires an OS notification when `fullyIdle:true` (agent fully finished, nothing running in the background). Loses the permission-prompt case Claude's `Notification` hook also covers — not needed here, since Antigravity's client already surfaces that natively via `ask`/`force_ask` on `PreToolUse`.
- `session-start.sh` — **PreInvocation**. Antigravity has no `SessionStart` event; gated to only act when `invocationNum==0` (first model call of the conversation) since `PreInvocation` otherwise fires every turn. Emits `{"injectSteps":[{"ephemeralMessage":"..."}]}` instead of Claude's direct context injection. Fingerprint mode (`AGENT_STARTER_FINGERPRINT=1 session-start.sh`) is unchanged — invoked directly by `/setup-agents`/`install.sh`, not through the hook event system.

**Open risk**: if multiple independent Stop hooks (e.g. `typecheck-on-stop.sh` and `lint-on-stop.sh`) each request `"continue"` in the same cycle, Antigravity's docs don't say how the results combine. Not resolvable without testing against a real Antigravity instance.

## Adding your own

1. Create a `.sh` script in `claude/` (and, if it should also guard Antigravity, a duplicate in `antigravity/` speaking its stdin/stdout contract).
2. Make it executable: `chmod +x claude/your-hook.sh`.
3. Wire the Claude-side script in `settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "$CLAUDE_PROJECT_DIR/.claude/hooks/your-hook.sh"
          }
        ]
      }
    ]
  }
}
```

- Exit 0 to allow, exit 2 to block.
- Scripts receive JSON on stdin with `tool_input`.
- Requires `jq` for JSON parsing.

See [Claude Code docs](https://code.claude.com/docs/en/hooks) for all hook events.
