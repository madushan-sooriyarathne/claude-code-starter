---
name: setup-claude
description: >
  This skill should be used when the user runs "/setup-claude" or asks to
  "set up Claude Code in this project", "scaffold a .claude folder", "add agents
  and rules to this repo", "install my Claude config", or "configure Claude for
  this codebase". It scans the current project for its actual stack (JS/TS,
  Python, Go, Rust, Ruby, Java, or anything else evidence supports), then
  interactively installs review agents, rules, deterministic hooks, recommended
  skills, and a CLAUDE.md template — with deeper built-in signals for a
  Next.js / Turborepo / Hono+Bun / Drizzle / BetterAuth / Sanity / Biome stack
  where present.
metadata:
  version: "0.2.0"
---

# /setup-claude

Scaffold a tailored `.claude/` workspace into the current project. This skill is
the in-session entry point; `install.sh` at the plugin root is the terminal
equivalent and runs the same flow.

**Target directory is always the current working directory.** Do not ask the user
to confirm the directory — the in-session CWD is the target.

**Governing principle:** install nothing without evidence and consent. Every
agent, rule, hook, and skill installed must be justified by something found in
the scan or explicitly requested by the user. The Step 3 plan table is the
contract — Step 4 applies exactly that plan, nothing more.

**Interaction style:** conversational, one category at a time. Present each
category, show the scan-based recommendations pre-marked, and wait for the user's
reply before moving to the next. Keep messages tight — show the choices, not an
essay. Only write inside `.claude/` and `CLAUDE.md`; never touch anything else.

Source files live under `${CLAUDE_PLUGIN_ROOT}`:
`${CLAUDE_PLUGIN_ROOT}/agents/`, `/rules/`, `/hooks/`, `/templates/`, and the
catalogs in `${CLAUDE_PLUGIN_ROOT}/skills/setup-claude/references/`.

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

Build a `detectedStack` list from the hits. Briefly tell the user what you
detected (one or two lines) before starting the categories.

## Step 2 — Category-by-category selection

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
4. **Skills** — read `references/skills-catalog.md`. Each skill is a GitHub repo URL
   plus a skill name, installed with `bunx skills add <repo> --skill <name>`. Present
   the recommended set (pre-marked from the scan); the user picks which to install.
5. **CLAUDE.md template** — ask once whether to copy the template to `./CLAUDE.md`.
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
| `pr-review` (skill) | skip | no GitHub remote / `gh` not installed | — |
| `old-custom-rule.md` (rule) | remove | no longer justified by scan; not in approved selection | — |

Cost class: `invoked-only` for agents/skills, `path-scoped` for rules with
`paths:` frontmatter, `always-loaded` for rules without it, `hook` for hooks
(zero per-turn context cost, registered in `settings.json`).

Ask one `AskUserQuestion`: **approve the plan** / **adjust** (loop back to
Step 2) / **cancel**. Do not proceed to Step 4 without approval. This table is
the contract — Step 4 installs and removes exactly what it lists.

## Step 4 — Install

Apply the approved plan exactly:

- **Agents:** create `.claude/agents/`; copy each selected
  `${CLAUDE_PLUGIN_ROOT}/agents/<name>.md` → `.claude/agents/<name>.md`.
- **Rules:** create `.claude/rules/`; copy each selected
  `${CLAUDE_PLUGIN_ROOT}/rules/<name>.md` → `.claude/rules/<name>.md`. For any
  copied rule that carries a `paths:` frontmatter block, rewrite the globs to
  the real source/migration/frontend dirs found in Step 1 (with monorepo
  package prefixes, e.g. `apps/web/src/api/**`, when applicable). Show the
  rewritten frontmatter before writing — never leave a rule's `paths:` pointing
  at a directory structure the project doesn't have.
- **Hooks:** create `.claude/hooks/`; copy each selected hook script from
  `${CLAUDE_PLUGIN_ROOT}/hooks/` → `.claude/hooks/`, `chmod +x` them, then merge
  the matching registration entries into `.claude/settings.json` (create if
  missing; merge without clobbering existing hooks; do not duplicate an entry
  that already exists; only add entries for hooks actually selected). Use the
  JSON shape in `references/hooks-catalog.md`. When generating
  `permissions.allow`, include only commands that actually exist in this
  project (real script names from the manifest read in Step 1, real `gh`
  subcommands only if a GitHub remote + `gh` were detected) — never paste in a
  generic allow-list wholesale.
- **Skills:** for each selected skill, run
  `bunx skills add <repo-url> --skill <skill-name> -a claude-code -y` from the project
  directory (the repo URL and skill name come from the catalog). Private repos (e.g.
  `madushan/next-pro-seo`) need `gh auth` — treat an auth failure as non-fatal and
  continue. There is no marketplace/plugin install step.
- **CLAUDE.md:** if selected, copy `${CLAUDE_PLUGIN_ROOT}/templates/CLAUDE.template.md`
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
[ -x .claude/hooks/session-start.sh ] && CLAUDE_CODE_STARTER_FINGERPRINT=1 .claude/hooks/session-start.sh > .claude/.claude-code-starter.json
```

This hashes the project's manifests (`hooks/session-start.sh` already
implements this mode and already reads `.claude/.claude-code-starter.json`
back for the drift nudge — nothing to build here, just invoke it). From then
on, `session-start` emits a one-line "config drift" nudge whenever the
manifests change (new scripts, new framework, new package manager) — the
signal to re-run `/setup-claude`. Tell the user to commit this file so the
whole team shares the baseline.

If `session-start` was not installed, skip this and tell the user to re-run
`/setup-claude` manually after stack changes — there is no other drift signal.

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

## Guardrails

- Only ever write under `.claude/` and `./CLAUDE.md` in the target project.
- Never overwrite, remove, or install a file without it appearing in the
  approved Step 3 plan first.
- If a category has no recommendations and the user skips it, that's fine — record
  it as empty and move on.
- Uncertain detection → ask, don't guess.
- Keep all user-facing messaging in plain language; don't dump file paths or JSON
  at the user unless they ask.
