---
name: setup-claude
description: >
  This skill should be used when the user runs "/setup-claude" or asks to
  "set up Claude Code in this project", "scaffold a .claude folder", "add agents
  and rules to this repo", "install my Claude config", or "configure Claude for
  this codebase". It scans the current project, then interactively installs
  review agents, rules, deterministic hooks, recommended skills, and a CLAUDE.md
  template tuned for a Next.js / Turborepo / Hono+Bun / Drizzle / BetterAuth /
  Sanity / Biome stack.
metadata:
  version: "0.1.0"
---

# /setup-claude

Scaffold a tailored `.claude/` workspace into the current project. This skill is
the in-session entry point; `install.sh` at the plugin root is the terminal
equivalent and runs the same flow.

**Target directory is always the current working directory.** Do not ask the user
to confirm the directory — the in-session CWD is the target.

**Interaction style:** conversational, one category at a time. Present each
category, show the scan-based recommendations pre-marked, and wait for the user's
reply before moving to the next. Keep messages tight — show the choices, not an
essay. Only write inside `.claude/` and `CLAUDE.md`; never touch anything else.

Source files live under `${CLAUDE_PLUGIN_ROOT}`:
`${CLAUDE_PLUGIN_ROOT}/agents/`, `/rules/`, `/hooks/`, `/templates/`, and the
catalogs in `${CLAUDE_PLUGIN_ROOT}/skills/setup-claude/references/`.

## Step 1 — Scan the project

Inspect the CWD and record what you find. Detect:

- `package.json` (read it: dependencies, `name`/`description`, scripts)
- `pnpm-workspace.yaml`, `turbo.json` → monorepo
- `next.config.*` → Next.js
- `drizzle.config.*` → Drizzle
- `sanity.config.*` or `@sanity/*` dep → Sanity
- `better-auth` dep / `auth.ts` / `app/api/auth/` → BetterAuth/auth
- `biome.json` / `biome.jsonc` → Biome
- `tsconfig.json` or `.ts`/`.tsx` files → TypeScript
- deploy signals: `Dockerfile`, `docker-compose.*`, `Caddyfile`, `nginx.conf`
- existing `.claude/` → **gap-analysis mode** (see below)

Build a `detectedStack` list from the hits. Briefly tell the user what you
detected (one or two lines) before starting the categories.

**Gap-analysis mode:** if `.claude/` already exists, read what's already there
(agents, rules, hooks in `settings.json`) and only offer what's missing. Never
overwrite an existing file without asking.

## Step 2 — Category-by-category selection

Read the matching catalog before presenting each category, and pre-mark the
recommended items per its **Recommend when** column against the scan.

Go in this order, one turn each:

1. **Agents** — read `references/agents-catalog.md`. List all 5 with a one-line
   purpose; pre-mark recommendations. Ask the user to confirm, adjust, or skip.
2. **Rules** — read `references/rules-catalog.md`. List all 4; pre-mark.
3. **Hooks** — read `references/hooks-catalog.md`. List all 3; **always pre-mark
   `block-dangerous-commands` and `scan-secrets`**; pre-mark `format-on-save`
   when Biome is detected.
4. **Skills** — read `references/skills-catalog.md`. Each skill is a GitHub repo URL
   plus a skill name, installed with `bunx skills add <repo> --skill <name>`. Present
   the recommended set (pre-marked from the scan); the user picks which to install.
5. **CLAUDE.md template** — ask once whether to copy the template to `./CLAUDE.md`.
   If `CLAUDE.md` already exists, ask whether to overwrite (default: keep
   existing, skip).

Use AskUserQuestion for each category so the user can multi-select. Accept
"all", "the recommended ones", "none", or specific names.

## Step 3 — Install

After all categories are decided, perform the installs:

- **Agents:** create `.claude/agents/`; copy each selected
  `${CLAUDE_PLUGIN_ROOT}/agents/<name>.md` → `.claude/agents/<name>.md`.
- **Rules:** create `.claude/rules/`; copy each selected
  `${CLAUDE_PLUGIN_ROOT}/rules/<name>.md` → `.claude/rules/<name>.md`.
- **Hooks:** create `.claude/hooks/`; copy each selected hook script from
  `${CLAUDE_PLUGIN_ROOT}/hooks/` → `.claude/hooks/`, `chmod +x` them, then merge
  the matching registration entries into `.claude/settings.json` (create if
  missing; merge without clobbering existing hooks; do not duplicate an entry
  that already exists). Use the JSON shape in `references/hooks-catalog.md`.
- **Skills:** for each selected skill, run
  `bunx skills add <repo-url> --skill <skill-name> -a claude-code -y` from the project
  directory (the repo URL and skill name come from the catalog). Private repos (e.g.
  `madushan/next-pro-seo`) need `gh auth` — treat an auth failure as non-fatal and
  continue. There is no marketplace/plugin install step.
- **CLAUDE.md:** if selected, copy `${CLAUDE_PLUGIN_ROOT}/templates/CLAUDE.template.md`
  → `./CLAUDE.md`.

## Step 4 — Finalize

Write `.claude/.madushan-setup.json` recording the run:

```json
{
  "version": "0.1.0",
  "installedAt": "<ISO-8601 timestamp>",
  "detectedStack": ["next.js", "turborepo", "drizzle", "..."],
  "installed": {
    "agents": ["code-reviewer", "..."],
    "rules": ["typescript", "..."],
    "hooks": ["block-dangerous-commands", "..."],
    "skills": ["frontend-design", "next-pro-seo", "..."],
    "claudeMd": true
  }
}
```

Then print a concise summary: what was installed in each category, where, and any
skipped/failed items. Tell the user to **restart Claude Code** so the new agents,
rules, and hooks are picked up.

## Guardrails

- Only ever write under `.claude/` and `./CLAUDE.md` in the target project.
- Never overwrite an existing file without explicit confirmation.
- If a category has no recommendations and the user skips it, that's fine — record
  it as empty and move on.
- Keep all user-facing messaging in plain language; don't dump file paths or JSON
  at the user unless they ask.
