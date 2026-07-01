---
name: setup-agents
description: >
  This skill should be used when the user runs "/setup-agents" or asks to
  "set up Claude Code in this project", "set up Antigravity", "scaffold a .claude
  or .agents folder", "add agents and rules to this repo", "install my agent
  config", or "configure Claude/Antigravity for this codebase". It scans the
  current project for its actual stack (JS/TS, Python, Go, Rust, Ruby, Java, or
  anything else evidence supports), then interactively installs review agents,
  rules, deterministic hooks, recommended skills, and a CLAUDE.md/AGENTS.md
  template — targeting whichever host it runs in (Claude Code → .claude/,
  Antigravity → .agents/plugins/setup-agents/) — with deeper built-in signals for
  a Next.js / Turborepo / Hono+Bun / Drizzle / BetterAuth / Sanity / Biome stack
  where present.
metadata:
  version: "0.6.0"
---

# /setup-agents

Scaffold a tailored agent workspace into the current project for the host you are
running in. This skill is the in-session entry point; `install.sh` at the plugin
root is the terminal equivalent and runs the same flow.

**Target directory is always the current working directory.** Do not ask the user
to confirm the directory — the in-session CWD is the target.

## Step 0 — Detect the host

Pick the materialization target from the host you are running in. **Do not ask** —
detect it:

- **Claude Code** — `$CLAUDE_PLUGIN_ROOT` or `$CLAUDE_PROJECT_DIR` is set, or you
  are otherwise running as Claude Code. Target `.claude/{agents,rules,hooks}` +
  `settings.json` + `CLAUDE.md`. This is the default; **Steps 1–6 below describe
  this path.**
- **Antigravity** — those env vars are absent and you are running inside
  Antigravity. Target `.agents/plugins/setup-agents/`. Run the **same** Steps 1–3
  (scan, confirm, plan); then materialize per the **"Antigravity install"**
  section near the end instead of Steps 4–5.

The scan and selection logic is host-agnostic. Only how the plan is written to
disk differs.

**Governing principle:** install nothing without evidence and consent. Every
agent, rule, hook, and skill installed must be justified by something found in
the scan or explicitly requested by the user. The Step 3 plan table is the
contract — Step 4 applies exactly that plan, nothing more.

**Interaction style:** conversational, one category at a time. Present each
category, show the scan-based recommendations pre-marked, and wait for the user's
reply before moving to the next. Keep messages tight — show the choices, not an
essay. Only write inside `.claude/` and `CLAUDE.md`; never touch anything else.

Source files live under `template/` at the plugin bundle root: `agents/`,
`rules/`, `hooks/`, `CLAUDE.md`, `settings.json`, and the catalogs in
`skills/setup-agents/references/` (sibling of this file). Resolve the bundle
root per host:

- **Claude Code** — `${CLAUDE_PLUGIN_ROOT}` (env var is always set).
- **Antigravity** — no equivalent env var is exposed to skills. `agy plugin
  install` stages the whole plugin tree verbatim under
  `~/.gemini/config/plugins/setup-agents/` (confirmed by inspecting a real
  install), so read `template/` and `skills/setup-agents/references/` from
  there. If that path doesn't exist, walk up from this file's own directory
  until you find a sibling `plugin.json` — that directory is the bundle root.

## Step 1 — Scan the project

Inspect the CWD and record what you find. Don't stop at manifests — open a
handful of real source/test files when a signal is ambiguous.

**Stack manifests** (any present):
- `package.json` (read it: dependencies, `name`/`description`, scripts)
- `pyproject.toml`, `requirements.txt` → Python
- `go.mod` → Go
- `Cargo.toml` → Rust
- `Gemfile` → Ruby
- `composer.json` → PHP
- `build.gradle`/`build.gradle.kts`/`pom.xml` → Java/Kotlin
- `Makefile` → record real build/test/lint targets regardless of language
- CI workflows: `.github/workflows/`, `.gitlab-ci.yml` — record real job commands

**JS/TS-specific signals:**
- `pnpm-workspace.yaml`, `turbo.json`, `lerna.json`, `nx.json`, or multiple
  manifests at depth 2+ → monorepo (list the packages)
- `next.config.*` → Next.js
- `drizzle.config.*` → Drizzle
- `sanity.config.*` or `@sanity/*` dep → Sanity
- `better-auth` dep / `auth.ts` / `app/api/auth/` → BetterAuth/auth
- `biome.json` / `biome.jsonc` → Biome
- `tsconfig.json` or `.ts`/`.tsx` files → TypeScript
- `react` dep → React
- `hono` dep → Hono
- `bunfig.toml`, `bun.lockb`, or `packageManager: bun@*` → Bun
- `tailwindcss` dep (v4) or `@theme` block in a CSS file → Tailwind

**Cross-language signals (drive catalog rows, not just JS):**
- Source layout: list the real source dirs found (`src/`, `app/`, `lib/`,
  `packages/*/src`, `cmd/`, `internal/`, ...) — these become rule `paths:`
  rewrites in Step 4, never assume `src/` blindly.
- Tests: config files (`jest.config.*`, `vitest.config.*`, `pytest.ini`,
  `conftest.py`, `playwright.config.*`, language-native test dirs) — if found,
  open 1-2 real test files to confirm runner and convention.
- Frontend: `.tsx`/`.jsx`/`.vue`/`.svelte` files or `**/components/**`,
  `**/pages/**`, `**/views/**` dirs.
- Backend/API/auth: route/controller/handler/service dirs, `src/api/`,
  `src/auth/`, `src/middleware/**`.
- Database: migration or ORM dirs (`**/migrations/**`, `prisma/`, `drizzle/`,
  `alembic/`, `db/migrate/`, `knex/migrations/`, ...).
- Docs: a `docs/` directory or substantial `.md` files beyond the README.
- Formatter/linter beyond Biome: configs AND binaries (Prettier, ESLint, Ruff,
  Black, rustfmt, gofmt) — only recommend `lint-on-stop`/`format-on-save` when
  one is actually present.
- Deploy signals: `Dockerfile`, `docker-compose.*`, `Caddyfile`, `nginx.conf`.
- Git: default branch (`git symbolic-ref refs/remotes/origin/HEAD`), whether
  `gh` is installed and a GitHub remote exists (gates PR-related skills).
- existing `.claude/` → **gap-analysis mode** (see below)

If the project has no source files and no manifests: say so, offer only the
minimal baseline (CLAUDE.md template + the four safety hooks), and stop after
installing it. Tell the user to re-run once code exists.

**Gap-analysis mode:** if `.claude/` already exists, read what's already there
(agents, rules, hooks wired in `settings.json`) directly from disk — no separate
install-record file is needed. Offer what's missing per the catalogs below, and
also flag anything present that current evidence no longer justifies (stack
signal removed, file hand-deleted from upstream, etc.) as a candidate for
**removal** in the Step 3 plan table. Never delete or overwrite an existing file
without it appearing in the approved plan first.

Build a `detectedStack` list from the hits.

## Step 1.5 — Confirm the detected stack

Before any selection, render a labeled summary of `detectedStack` so the user
can sanity-check what was found. **Evidence-driven, not assumed:** emit a row
only for a category that has a real signal; mark `—` for one that was looked for
but not found; omit categories that never apply. Append a `Packages` list when a
monorepo was detected.

```
Stack
  Frontend:   Next.js 15 (React, Tailwind v4, TS)
  Backend:    Hono + Bun
  Database:   Drizzle + PostgreSQL
  Auth:       BetterAuth + Google
  Realtime:   Soketi (Pusher-compat)
  Testing:    bun:test (game-engine)
  Formatter:  Prettier (printWidth 100)
  Typecheck:  tsc (no ESLint/Biome)
  Pkg mgr:    pnpm workspaces
  Git:        <default-branch>, gh <installed?/remote?>
  CI:         <detected workflow / —>
Packages
  apps/web              Next.js frontend
  apps/api              Hono + Bun backend
  packages/db           Drizzle schema + migrations
  packages/types        Zod schemas (single source of truth)
  packages/game-engine  Pure game logic + bun:test
  packages/ui           Shared React components
```

(The values above are an example; fill in only what the scan actually found.)

Then ask one `AskUserQuestion`: **Accept** / **Correct it**. On *Correct it*,
take the user's edits, patch `detectedStack`, re-render the summary, and re-ask
until accepted. Do not proceed until the stack is confirmed.

## Step 1.6 — Pick install tier

Once the stack is accepted, offer how to install. Ask one `AskUserQuestion`
with four options, each stating what's in and out:

- **Minimal** — CLAUDE.md template + the four safety hooks only
  (`block-dangerous-commands`, `scan-secrets`, `protect-files`,
  `warn-large-files`). Excludes all agents, rules, additional skills, and
  third-party plugins.
- **Standard (Recommended)** — read all 6 catalogs silently, apply every
  "Recommend when" rule against the scan, and build the recommended selection
  (bundled skills marked as already available, external skills queued for
  install). Excludes catalog items with no supporting evidence.
- **Full** — every item in all 6 catalogs plus all three third-party plugins.
  Excludes nothing.
- **Let me check** — the category-by-category flow in Step 2.

**One-shot tiers (Minimal / Standard / Full):** build the selection silently
from the catalogs, skip all per-category prompts, and go straight to Step 3's
plan table. Render the table (the contract still holds), then install without
further questions **except** when one of these fires — only then stop and ask:
- a required system dep is missing (`uv`/`pipx` for Graphify, `bunx` for
  skills, `gh auth` for a private skill repo), or
- a crucial/destructive action is pending (overwriting an existing
  `CLAUDE.md`, or overwriting/removing existing files in gap-analysis mode).
Otherwise apply the whole plan and report at Step 6.

**Let me check** → proceed to Step 2.

## Step 2 — Category-by-category selection

(Only reached from the **Let me check** tier.)

Read the matching catalog before presenting each category, and pre-mark the
recommended items per its **Recommend when** column against the scan.

Go in this order, one turn each:

1. **Agents** — read `references/agents-catalog.md`. List all 8 with a one-line
   purpose; pre-mark recommendations. Ask the user to confirm, adjust, or skip.
2. **Rules** — read `references/rules-catalog.md`. List all 16; pre-mark.
3. **Hooks** — read `references/hooks-catalog.md`. List all 10; **always
   pre-mark the four safety hooks** (`block-dangerous-commands`, `scan-secrets`,
   `protect-files`, `warn-large-files`); pre-mark `format-on-save` when Biome is
   detected, `typecheck-on-stop`/`lint-on-stop` when a type-checker/linter is
   detected, `session-start` by default (cheap).
4. **Third-party plugins** — read `references/third-party-plugins-catalog.md`. Present
   all three (Caveman, Ponytail, Graphify) **pre-marked by default**. These inject
   persistent behavior rules into `CLAUDE.md` on install, so confirm before proceeding.
   Note scope differences: Caveman is project-scoped; Ponytail is user-scoped (installs
   to `~/.claude/`); Graphify is a system tool that writes to the project `CLAUDE.md`.
5. **Skills** — read `references/skills-catalog.md`. Present in two groups:
   - **Bundled skills** (already included with this plugin — no install needed): scan
     `${CLAUDE_PLUGIN_ROOT}/skills/` for subdirectory names, exclude `setup-agents`
     itself. Show each bundled skill with its one-line description and pre-mark per
     the **Recommend when** column in the catalog's "Bundled Skills" section. Selected
     bundled skills are logged as "already available" — no action required at install.
   - **Additional skills** (installed from GitHub via `bunx skills add`): read the
     catalog's "External Skills" section. Pre-mark recommendations from the scan.
     Each selected skill runs `bunx skills add <repo-url> --skill <skill-name> -a claude-code -y`
     at install time.
6. **CLAUDE.md template** — ask once whether to copy the template to `./CLAUDE.md`.
   If `CLAUDE.md` already exists, ask whether to overwrite (default: keep
   existing, skip).

Use AskUserQuestion for each category so the user can multi-select. Accept
"all", "the recommended ones", "none", or specific names.

## Step 3 — Plan & approve

Before writing anything, render one table from everything selected (and, in
gap-analysis mode, everything flagged for removal):

| Component | Action | Evidence | Cost class |
|---|---|---|---|
| `security-reviewer` (agent) | install | API routes detected in `src/api/` | invoked-only |
| `security.md` (rule) | install | `src/auth/`, `src/middleware/` found | path-scoped |
| `testing.md` (rule) | install | `vitest.config.ts` + `*.test.ts` found | always-loaded (no `paths:`) |
| `block-dangerous-commands` (hook) | install | always-on safety | hook — no context cost |
| `caveman` (plugin) | install | default selected; user confirmed | CLAUDE.md snippet |
| `graphify` (plugin) | skip | `uv`/`pipx` not found on PATH | — |
| `pr-review` (skill) | skip | no GitHub remote / `gh` not installed | — |
| `old-custom-rule.md` (rule) | remove | no longer justified by scan; not in approved selection | — |

Cost class: `invoked-only` for agents/skills, `path-scoped` for rules with
`paths:` frontmatter, `always-loaded` for rules without it, `hook` for hooks
(zero per-turn context cost, registered in `settings.json`).

For the **Let me check** tier, ask one `AskUserQuestion`: **approve the plan** /
**adjust** (loop back to Step 2) / **cancel**. Do not proceed to Step 4 without
approval. For one-shot tiers (Minimal / Standard / Full), still render this
table, but auto-approve and proceed — interrupt only on the missing-dep or
crucial/destructive flags listed in Step 1.6. This table is the contract —
Step 4 installs and removes exactly what it lists.

## Step 4 — Install

Apply the approved plan exactly:

- **Agents:** create `.claude/agents/`; copy each selected
  `${CLAUDE_PLUGIN_ROOT}/template/agents/<name>.md` → `.claude/agents/<name>.md`.
- **Rules:** create `.claude/rules/`; copy each selected
  `${CLAUDE_PLUGIN_ROOT}/template/rules/<name>.md` → `.claude/rules/<name>.md`. For any
  copied rule that carries a `paths:` frontmatter block, rewrite the globs to
  the real source/migration/frontend dirs found in Step 1 (with monorepo
  package prefixes, e.g. `apps/web/src/api/**`, when applicable). Show the
  rewritten frontmatter before writing — never leave a rule's `paths:` pointing
  at a directory structure the project doesn't have.
- **Hooks:** create `.claude/hooks/`; copy each selected hook script from
  `${CLAUDE_PLUGIN_ROOT}/template/hooks/` → `.claude/hooks/`, `chmod +x` them, then merge
  the matching registration entries into `.claude/settings.json` (create if
  missing; merge without clobbering existing hooks; do not duplicate an entry
  that already exists; only add entries for hooks actually selected). Use the
  JSON shape in `references/hooks-catalog.md`. When generating
  `permissions.allow`, include only commands that actually exist in this
  project (real script names from the manifest read in Step 1, real `gh`
  subcommands only if a GitHub remote + `gh` were detected) — never paste in a
  generic allow-list wholesale.
- **Third-party plugins:** read `references/third-party-plugins-catalog.md` for exact
  install sequences. Apply in this order for each selected plugin:
  - **Caveman:** run `bunx skills add JuliusBrussee/caveman -a claude-code -y` from the
    project directory (project-scoped). Then append the caveman CLAUDE.md snippet from
    the catalog.
  - **Ponytail:** Ponytail uses the Claude Code native plugin system and installs to
    `~/.claude/` (user-scoped, not project-scoped). Print the two in-session commands
    for the user to run manually:
    ```
    /plugin marketplace add DietrichGebert/ponytail
    /plugin install ponytail@ponytail
    ```
    Tell the user to restart Claude Code after running them. Then append the ponytail
    CLAUDE.md snippet from the catalog.
  - **Graphify:** detect a Python package manager by priority `uv` → `pipx` → `pip`
    (`uv tool install graphifyy`, else `pipx install graphifyy`, else
    `pip install graphifyy`). If none is on PATH, warn and skip with a note to install
    `uv` first (`curl -LsSf https://astral.sh/uv/install.sh | sh`). After install run
    `graphify install --project`, append the graph-report CLAUDE.md snippet from the
    catalog, then tell the user to run `/graphify .` in Claude Code to build the graph
    and to commit `graphify-out/` so teammates share it.
  Treat all third-party plugin install failures as non-fatal — log the failure, skip
  that plugin, and continue.
- **Skills:** handle the two groups separately:
  - **Bundled skills:** no action required — they are already available via the plugin.
    Log each selected bundled skill as "available (bundled)" in the Step 6 summary.
  - **External skills:** for each selected external skill, run
    `bunx skills add <repo-url> --skill <skill-name> -a claude-code -y` from the
    project directory (repo URL and skill name from the catalog). Private repos (e.g.
    `madushan/next-pro-seo`) need `gh auth` — treat an auth failure as non-fatal and
    continue. There is no marketplace/plugin install step.
- **CLAUDE.md:** if selected, copy `${CLAUDE_PLUGIN_ROOT}/template/CLAUDE.md`
  → `./CLAUDE.md`. Then run the budget check: `grep -cv '^[[:space:]]*$' CLAUDE.md`.
  - Under 25 non-blank lines: pass, no message needed.
  - 25-50: warn — list the longest sections, ask the user (one
    `AskUserQuestion`) which to trim.
  - Over 50: must propose specific cuts and keep trimming until ≤50 before
    moving on.
- **Removals (gap-analysis mode only):** for each file the approved plan marks
  `remove`, delete it individually (never a bulk `rm`) and confirm immediately
  after — list what was removed and why in the Step 6 summary. Never remove a
  file that doesn't appear in the approved plan table.

## Step 5 — Finalize

If the `session-start` hook was installed, write the drift fingerprint so the
setup stays tuned over time:

```bash
[ -x .claude/hooks/session-start.sh ] && AGENT_STARTER_FINGERPRINT=1 .claude/hooks/session-start.sh > .claude/.agent-starter.json
```

This hashes the project's manifests (`hooks/claude/session-start.sh` already
implements this mode and already reads `.claude/.agent-starter.json`
back for the drift nudge — nothing to build here, just invoke it). From then
on, `session-start` emits a one-line "config drift" nudge whenever the
manifests change (new scripts, new framework, new package manager) — the
signal to re-run `/setup-agents`. Tell the user to commit this file so the
whole team shares the baseline.

If `session-start` was not installed, skip this and tell the user to re-run
`/setup-agents` manually after stack changes — there is no other drift signal.

Do not write any other install-record file. Gap-analysis mode (Step 1) reads
`.claude/` directly on every run instead of relying on a separate JSON record.

## Step 6 — Verify and report

1. **Mechanical checks:** every hook wired in `settings.json` has a matching
   executable file under `.claude/hooks/`; every installed `.md`/`.json` file
   parses (YAML frontmatter, JSON); nothing was installed or removed outside
   the approved Step 3 plan.
2. **Always-loaded token estimate:** `CLAUDE.md` + rules with no `paths:`
   frontmatter (e.g. `code-quality.md`, `testing.md`), chars/4. Report the
   number; if it's over ~1000 tokens, propose the single biggest trim.
3. **CLAUDE.md budget verdict:** PASS / WARN / FAIL per the thresholds in
   Step 4, restated here for the summary.
4. **Summary:** three lists — installed (with the evidence that justified
   each), skipped (with reason), removed (with reason, gap-analysis mode only).
   Tell the user to **restart Claude Code** so the new agents, rules, and hooks
   are picked up.

## Antigravity install

Reached only when Step 0 detected Antigravity. Run Steps 1–3 unchanged (same
scan, same catalogs, same plan table), then materialize the approved plan into
`.agents/plugins/setup-agents/` instead of `.claude/`. Antigravity's plugin
layout mirrors Claude's, with three differences that matter:

- **Agents ship as skills, not as `agy`'s native `agents/<name>.md`.** `agy
  plugin validate` does recognize an `agents/` component, but whether it
  behaves as a real delegable subagent at runtime (vs. Claude's Task-tool
  subagents) is unconfirmed — so use the verified path: write
  `.agents/plugins/setup-agents/skills/<name>/SKILL.md` with frontmatter reduced
  to `name` + `description` and the agent's body carried verbatim. It becomes a
  `/<name>` slash command.
- **All 10 hooks port, but 6 needed a redesign, not just a contract swap.**
  The four PreToolUse safety hooks (`block-dangerous-commands`, `scan-secrets`,
  `protect-files`, `warn-large-files`) map 1:1 onto Antigravity's `PreToolUse`.
  The rest can't, because Antigravity's `PostToolUse` carries no tool
  arguments at all (no file path, no tool name) — so `format-on-save`,
  `auto-test`, `typecheck-on-stop`, `lint-on-stop`, and `notify` instead run on
  `Stop` (fires once the execution loop is about to fully terminate), reading
  `git status`/`git diff` against `workspacePaths[0]` in place of a per-edit
  marker; `session-start` runs on `PreInvocation` (fires before every model
  call), gated to `invocationNum==0` to approximate "session start".
- **Project context goes in `AGENTS.md`** at the project root, not `CLAUDE.md`.

Materialize:

- **plugin.json** — write `{"name":"setup-agents","description":...}` at the
  bundle root (required marker).
- **Rules** → `rules/<name>.md`, identical markdown; apply the same `paths:`
  rewrite as the Claude path.
- **Agents** → `skills/<name>/SKILL.md` per the conversion above.
- **Hooks** → copy each supported hook's native script from
  `hooks/antigravity/<name>.sh` (not the `hooks/claude/` one — Antigravity gets
  its own duplicated-logic implementation, no translation shim) into the
  bundle root, `chmod +x`, then write `hooks.json`. Two different shapes
  depending on the hook's event:
  - `PreToolUse` (the 4 safety hooks): matcher+hooks wrapper —
    `{"<name>": {"PreToolUse": [{"matcher": "...", "hooks": [{"type":"command","command":"bash \"<abs>/.agents/plugins/setup-agents/<name>.sh\""}]}]}}`.
    Matcher `run_command` for `block-dangerous-commands`, else
    `write_to_file|replace_file_content|multi_replace_file_content`.
  - `PreInvocation`/`Stop` (the other 6): a flat handler array, no matcher —
    `{"<name>": {"Stop": [{"type":"command","command":"bash \"<abs>/.agents/plugins/setup-agents/<name>.sh\""}]}}`
    (`session-start` uses `"PreInvocation"` instead of `"Stop"`).
- **AGENTS.md** → copy the `CLAUDE.md` template to `./AGENTS.md` (skip if it
  already exists).
- **Drift fingerprint** → if `session-start` was installed, run
  `AGENT_STARTER_FINGERPRINT=1 .agents/plugins/setup-agents/session-start.sh > .agents/plugins/setup-agents/.agent-starter.json`
  (mirrors the Claude Step 5 fingerprint write; `session-start.sh` reads this
  path back by default on its next `invocationNum==0` `PreInvocation`).

The terminal `install.sh` implements exactly this; prefer matching its output.
Verify `hooks.json` is valid JSON, then report per Step 6. Tell the user to
reload Antigravity so the plugin is discovered.

## Guardrails

- Only ever write under `.claude/` + `./CLAUDE.md` (Claude) or
  `.agents/plugins/setup-agents/` + `./AGENTS.md` (Antigravity) in the target.
- Never overwrite, remove, or install a file without it appearing in the
  approved Step 3 plan first.
- If a category has no recommendations and the user skips it, that's fine — record
  it as empty and move on.
- Uncertain detection → ask, don't guess.
- Keep all user-facing messaging in plain language; don't dump file paths or JSON
  at the user unless they ask.
