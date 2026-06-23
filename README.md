# claude-code-starter

A self-contained Claude Code plugin that scaffolds a tailored `.claude/` workspace
(review agents, rules, deterministic hooks, recommended skills) plus a `CLAUDE.md`
template into a project. Tuned for a **Next.js / Turborepo + pnpm / Hono on Bun /
Drizzle + PostgreSQL / BetterAuth / Sanity / Tailwind v4 / Biome / Vitest** stack,
and sensible on plain TypeScript, Lua, or Go repos too.

Everything is written fresh and bundled here — there is **no runtime dependency on
any upstream repo**.

## Two entry points, one flow

Both run the same five steps: scan the project → category-by-category selection
(pre-marked from the scan) → install → write a record → summary.

### 1. `/setup-claude` (inside Claude Code)

Run the slash command in a session. The target is always the current working
directory (no confirmation prompt). Each category is a conversational turn — Claude
shows the recommended selection, you confirm or adjust, and it proceeds.

### 2. `install.sh` (terminal)

```bash
./new/install.sh
```

Resolves its own location (`SCRIPT_DIR`), so it finds its bundled agents/rules/hooks
no matter where you invoke it from. It adds one step before the shared flow:

```
Detected target directory: /path/to/current/project
Install .claude/ here? [Y/n] or enter a different path:
```

Then each category prints as a numbered checklist. Enter space-separated numbers
(`1 3 4`), `a` for all, `n` for none, or just press Enter to accept the pre-marked
defaults. Requires only standard bash + `bunx` (no `fzf`/`dialog`/`jq`).

## What gets installed

### Agents → `.claude/agents/`

| Agent | Focus | Default when |
|-------|-------|--------------|
| `code-reviewer` | TS/Next/Hono correctness, type safety, patterns | always |
| `security-reviewer` | auth, API authorization, env, Drizzle injection | always |
| `performance-reviewer` | re-renders, N+1 queries, bundle size | Next.js or Drizzle |
| `sanity-reviewer` | Sanity schema, GROQ, content modeling | Sanity |
| `doc-reviewer` | inline docs, README, CLAUDE.md | always |

### Rules → `.claude/rules/`

| Rule | Covers | Default when |
|------|--------|--------------|
| `typescript` | no `any`, infer from Drizzle, Zod at boundaries | always |
| `git-workflow` | commits, branches, no force-push, no `--no-verify` | always |
| `nextjs` | App Router, server/client discipline | Next.js |
| `monorepo` | Turbo/pnpm boundaries, no cross-package `../`, no barrels | Turbo/pnpm |

### Hooks → `.claude/hooks/` + registered in `.claude/settings.json`

| Hook | Event / matcher | Behavior | Default when |
|------|-----------------|----------|--------------|
| `block-dangerous-commands` | PreToolUse / `Bash` | blocks `rm -rf /`, `DROP TABLE`, `TRUNCATE`, `git push --force`, `--no-verify` | always |
| `scan-secrets` | PreToolUse / `Write\|Edit` | blocks hardcoded secrets; skips `*.example`/`*.md`; ignores env refs & placeholders | always |
| `format-on-save` | PostToolUse / `Write\|Edit` | `biome check --write` on `.ts`/`.tsx`; silent no-op without a Biome config | Biome |

Hooks read the tool-call JSON from stdin, **exit 0 to allow** and **exit 2 to block**
(the stderr message is fed back to Claude). They are pure bash with an optional
JSON parser (`python3`/`node`) and a fallback — no required dependencies.

### Skills → installed via `bunx skills add … --skill …`

All skills are installed with the Vercel `skills` CLI
([vercel-labs/skills](https://github.com/vercel-labs/skills)) from a **GitHub repo URL
plus a skill name** — no marketplace or plugin install:

```bash
bunx skills add <repo-url> --skill <skill-name> -a claude-code -y
```

| Skill | Repo | `--skill` | Default when |
|-------|------|-----------|--------------|
| frontend-design | `anthropics/skills` | `frontend-design` | Next.js |
| webapp-testing | `anthropics/skills` | `webapp-testing` | always |
| next-pro-seo | `madushan/next-pro-seo` | `next-pro-seo` | Next.js |
| brand-guidelines | `anthropics/skills` | `brand-guidelines` | hospitality / real-estate |
| mcp-builder | `anthropics/skills` | `mcp-builder` | opt-in |
| skill-creator | `anthropics/skills` | `skill-creator` | opt-in |

Add any repo whose skills live under `skills/<name>/SKILL.md` as a new row (use
`bunx skills add <repo> --list` to discover names). Private repos (like
`madushan/next-pro-seo`) need `gh auth` first; auth failures are non-fatal. See
`skills/setup-claude/references/skills-catalog.md`.

### CLAUDE.md

Copies `templates/CLAUDE.template.md` to `./CLAUDE.md` (asks before overwriting an
existing one). Includes the stack, code-style rules, a monorepo layout sketch, and
placeholder `Project Overview` / `Key Decisions` / `Current Focus` / `Out of Scope`
sections.

## Record of what was installed

Both entry points write `.claude/.madushan-setup.json` capturing the version,
timestamp, detected stack, and exactly what was installed in each category.

## Safety properties

- Neither entry point writes anywhere except `.claude/` and `./CLAUDE.md`.
- Existing managed files are **kept, not overwritten**; `CLAUDE.md` overwrite is
  always confirmed.
- The `settings.json` merge is **non-destructive and idempotent** — existing hooks
  and other settings are preserved, and re-running never duplicates entries.

## Notes & conventions

- **Skills are GitHub-only.** Every skill is installed with
  `bunx skills add <repo-url> --skill <name> -a claude-code -y` (Bun-first stack; `npx
  skills add` works the same). No Claude Code marketplace or `claude plugin install` is
  used. Each catalog row is a repo URL + a `--skill` name; private repos need `gh auth`.
- **`Write|Edit` matcher** (not `Write` alone) so `Edit` operations are also
  scanned and formatted.
- `install.sh` finds its sources via `SCRIPT_DIR`; the slash command uses
  `${CLAUDE_PLUGIN_ROOT}`. Neither relies on the current directory for locating
  plugin files.

## Layout

```
new/
├── .claude-plugin/plugin.json
├── skills/setup-claude/
│   ├── SKILL.md
│   └── references/{agents,rules,hooks,skills}-catalog.md
├── agents/      # 5 review agents
├── rules/       # 4 rules
├── hooks/       # 3 hook scripts
├── templates/CLAUDE.template.md
├── install.sh
└── README.md
```

After running either entry point, **restart Claude Code** so the new agents, rules,
and hooks are loaded.
