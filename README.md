# agent-starter

A Claude Code plugin marketplace: 22 plugins (agents, skills, hooks, rules) that scaffold a tailored agent workspace into any project. Targets **Claude Code** (`.claude/`) and **Google Antigravity** (`.agents/plugins/setup-agents/`).

## Hosts

| Host        | Layout                                                         | Components ported                           |
| ----------- | -------------------------------------------------------------- | ------------------------------------------- |
| Claude Code | `.claude/{agents,rules,hooks}` + `settings.json` + `CLAUDE.md` | all                                         |
| Antigravity | `.agents/plugins/setup-agents/` + `AGENTS.md`                  | rules, agents→skills, all 10 hooks (native) |

On Antigravity, agents ship as **skills** (auto `/<name>` slash commands — Antigravity subagents have no static file format). All 10 hooks port, each as its own native implementation under `hooks/antigravity/` — duplicated logic, not a shim translating the Claude-shaped `hooks/claude/` scripts. The 4 safety hooks map 1:1 onto Antigravity's `PreToolUse` (`{toolCall}`→`{decision,reason}`); the other 6 needed a redesign since Antigravity's `PostToolUse` carries no tool args at all — they run on `Stop`/`PreInvocation` instead, using live `git status`/`git diff` in place of a per-edit marker. See `hooks/README.md` for the per-hook breakdown and open risks.

## Entry points

### `/setup-agents` (inside Claude Code or Antigravity)

Invoke the slash command in any session. It detects the host, scans the project, recommends the right subset, and installs only what the evidence justifies. On an existing config it runs as a gap analysis.

### `./install.sh` (terminal)

```bash
./install.sh
```

Same flow as `/setup-agents` but driven from the shell. Prompts for the target host (Claude Code / Antigravity / both), detects the target directory, prints numbered checklists per category, accepts space-separated numbers / `a` / `n` / Enter for defaults. Requires bash + `bunx`.

Both entry points write a drift fingerprint of the detected stack used by the `session-start` hook: `.claude/.agent-starter.json` on Claude Code, `.agents/plugins/setup-agents/.agent-starter.json` on Antigravity (read back on the first `PreInvocation` of each new conversation, since Antigravity has no direct `SessionStart` event).

## What gets installed

### Agents (8) → `.claude/agents/`

| Agent                   | Purpose                                                             | Default when                 |
| ----------------------- | ------------------------------------------------------------------- | ---------------------------- |
| `code-reviewer`         | TS/Next/Hono correctness, type safety, patterns                     | Always                       |
| `security-reviewer`     | Auth flows, API authorization, env, Drizzle injection               | Auth or API surface detected |
| `performance-reviewer`  | Re-renders, N+1 queries, bundle size                                | Next.js or Drizzle detected  |
| `sanity-reviewer`       | Sanity schema, GROQ queries, content modeling                       | `sanity.config.*` detected   |
| `doc-reviewer`          | Inline docs, README quality, CLAUDE.md completeness                 | Always                       |
| `frontend-designer`     | Tokens-first UI, anti-AI-slop aesthetics, accessibility             | Frontend files detected      |
| `pr-test-analyzer`      | Judges whether tests actually verify behavior, catches mock theater | Test runner detected         |
| `silent-failure-hunter` | Finds swallowed errors and failures masked as success               | Always                       |

Agents are invoked on demand (e.g. "use the security-reviewer agent") — they do not run automatically.

### Rules (16) → `.claude/rules/`

Always-loaded (cost tokens every turn — kept tight):

| Rule           | Covers                                                                      |
| -------------- | --------------------------------------------------------------------------- |
| `code-quality` | No premature abstraction, naming conventions, WHY-not-WHAT comments         |
| `testing`      | Behavior over implementation, real impls over mocks, one assertion per test |
| `git-workflow` | Conventional commits, no force-push, no `--no-verify`                       |

Path-scoped (only load when touching matching files):

| Rule             | Scope trigger                   | Covers                                                    |
| ---------------- | ------------------------------- | --------------------------------------------------------- |
| `typescript`     | `**/*.ts`, `**/*.tsx`           | No `any`, Drizzle/Zod inference, `satisfies`, branded IDs |
| `react`          | `**/*.tsx`, `**/*.jsx`          | Composition, stable keys, React 19 async primitives       |
| `nextjs`         | `app/**`, `next.config.*`       | App Router, server/client discipline, DAL pattern         |
| `hono`           | `**/*.ts`                       | Route structure, `zod-validator`, `onError`, RPC type     |
| `bun`            | `**/*.ts`, `bunfig.toml`        | Native APIs, `bun:test`, no `dotenv`                      |
| `golang`         | `**/*.go`                       | Standard layout, error wrapping, context, table tests     |
| `rust`           | `**/*.rs`, `Cargo.toml`         | `unsafe` discipline, typed errors, clippy-clean           |
| `tailwind`       | `**/*.tsx`, `**/*.css`          | v4 CSS-first `@theme`, `cn()`, container queries          |
| `monorepo`       | `apps/**`, `turbo.json`         | Turborepo boundaries, no cross-package `../`              |
| `security`       | `src/api/**`, `src/auth/**`     | Input validation, parameterized queries, rate limiting    |
| `error-handling` | `src/api/**`, `src/services/**` | Typed errors, no swallowing, HTTP error shapes            |
| `database`       | Migration dirs                  | Never edit existing migrations, reversibility, no raw SQL |
| `frontend`       | `**/*.tsx`, `**/components/**`  | Design tokens, WCAG 2.1 AA, performance budget            |

### Hooks (10) → `.claude/hooks/` + `settings.json`

Hooks exit `0` to allow and `2` to block; stderr is fed back to Claude.

**Safety (always pre-marked):**

| Hook                       | Event                    | Behavior                                                            |
| -------------------------- | ------------------------ | ------------------------------------------------------------------- |
| `block-dangerous-commands` | PreToolUse / Bash        | Blocks `rm -rf /~`, `DROP TABLE`, `git push --force`, `--no-verify` |
| `scan-secrets`             | PreToolUse / Write\|Edit | Blocks hardcoded tokens, DB URLs with credentials                   |
| `protect-files`            | PreToolUse / Write\|Edit | Blocks `.env*`, certs, lockfiles, generated/minified, `.git/`       |
| `warn-large-files`         | PreToolUse / Write\|Edit | Blocks `node_modules/`, build dirs, binary/media files              |

**Quality (stack-conditional):**

| Hook                | Event                             | Behavior                                                      |
| ------------------- | --------------------------------- | ------------------------------------------------------------- |
| `format-on-save`    | PostToolUse / Write\|Edit         | Auto-formats: Biome, Prettier, Ruff, Black, rustfmt, gofmt    |
| `auto-test`         | PostToolUse / Write\|Edit         | Runs matching test file after edit; silent on success         |
| `typecheck-on-stop` | PostToolUse (marks) + Stop (runs) | Type-checks once per turn; exits 2 on failure so Claude fixes |
| `lint-on-stop`      | PostToolUse (marks) + Stop (runs) | Lints once per turn (same pattern as typecheck)               |

**UX:**

| Hook            | Event        | Behavior                                                                          |
| --------------- | ------------ | --------------------------------------------------------------------------------- |
| `notify`        | Notification | Native OS notification (macOS/Linux/WSL)                                          |
| `session-start` | SessionStart | Injects branch + dirty-state context (~5–10 tokens); drift nudge if stack changed |

### Skills (12 bundled + 17 external)

**Bundled** — ship with this plugin, no install needed:

| Skill            | Invoke            | Purpose                                                              |
| ---------------- | ----------------- | -------------------------------------------------------------------- |
| `setup-agents`   | `/setup-agents`   | Scan → plan → install `.claude/` config, evidence-driven             |
| `catchup`        | `/catchup`        | Rebuild context after `/clear`; `handoff` to write the session note  |
| `debug-fix`      | `/debug-fix`      | Careful bug fix. `--fast` for hotfix branch                          |
| `explain`        | `/explain`        | One-sentence summary + mental model; `verbose` for ASCII diagram     |
| `fix-issue`      | `/fix-issue`      | GitHub issue → tested fix → closing PR                               |
| `pr-review`      | `/pr-review`      | Six specialist agents in parallel; merge/needs-changes verdict       |
| `refactor`       | `/refactor`       | Safe refactor with tests as safety net; `--diff` for pre-commit pass |
| `ship`           | `/ship`           | Commit → push → PR with confirmation at each step                    |
| `tdd`            | `/tdd`            | Red → green → refactor loop; commits after each cycle                |
| `test-writer`    | `/test-writer`    | Comprehensive tests: happy/edge/error/concurrency paths              |
| `claude-md`      | `/claude-md`      | Capture session learnings; `audit` to prune stale content            |
| `context-budget` | `/context-budget` | Token cost estimate for `.claude/` config; `--api` for exact counts  |

**External** — installed with the Vercel `skills` CLI:

```bash
bunx skills add <repo-url> --skill <skill-name> -a claude-code -y
```

| Skill                         | Repo                                   | Default when                  |
| ----------------------------- | -------------------------------------- | ----------------------------- |
| `frontend-design`             | `anthropics/skills`                    | Frontend detected             |
| `webapp-testing`              | `anthropics/skills`                    | Always                        |
| `next-pro-seo`                | `madushan/next-pro-seo`                | Next.js detected              |
| `brand-guidelines`            | `anthropics/skills`                    | Hospitality/marketing signals |
| `mcp-builder`                 | `anthropics/skills`                    | Opt-in                        |
| `skill-creator`               | `anthropics/skills`                    | Opt-in                        |
| `vercel-react-best-practices` | `vercel-labs/agent-skills`             | React detected                |
| `vercel-composition-patterns` | `vercel-labs/agent-skills`             | React detected                |
| `shadcn`                      | `shadcn/ui`                            | React + `components/` dir     |
| `systematic-debugging`        | `obra/superpowers`                     | Always                        |
| `next-best-practices`         | `vercel-labs/next-skills`              | Next.js detected              |
| `emil-design-eng`             | `emilkowalski/skills`                  | Next.js + framer-motion       |
| `agent-browser`               | `vercel-labs/agent-browser`            | Playwright/Cypress detected   |
| `web-design-guidelines`       | `vercel-labs/agent-skills`             | Frontend detected             |
| `tdd`                         | `mattpocock/skills`                    | Test config detected          |
| `to-prd`                      | `mattpocock/skills`                    | Opt-in                        |
| `ui-ux-pro-max`               | `nextlevelbuilder/ui-ux-pro-max-skill` | Frontend detected             |

### Third-party plugins

`/setup-agents` also offers three third-party plugins (all pre-selected by default):

| Plugin       | What it does                                                 | Install mechanism                                               |
| ------------ | ------------------------------------------------------------ | --------------------------------------------------------------- |
| **Caveman**  | Ultra-compressed communication mode — cuts token noise ~75%  | `bunx skills add JuliusBrussee/caveman -a claude-code -y`       |
| **Ponytail** | YAGNI enforcer — lazy senior dev discipline                  | `/plugin marketplace add DietrichGebert/ponytail` (user-scoped) |
| **Graphify** | Codebase knowledge graph — god-node detection, community map | `uv tool install graphifyy && graphify claude install`          |

### CLAUDE.md

Copies `templates/CLAUDE.template.md` to `./CLAUDE.md` (asks before overwriting). Includes stack, code-style rules, monorepo layout sketch, and placeholder `Project Overview / Key Decisions / Current Focus / Out of Scope` sections.

## Safety properties

- Neither entry point writes anywhere except `.claude/` and `./CLAUDE.md`.
- Existing files are kept, not overwritten; `CLAUDE.md` overwrite is always confirmed.
- `settings.json` merge is non-destructive and idempotent — existing hooks are preserved, re-running never duplicates entries.
- Hooks fail open (exit 0) when `jq` is missing, except file-protection hooks which fail closed.

## Plugin marketplace

All 22 plugins are individually installable via the Claude Code plugin system:

```bash
# Install the full marketplace
claude plugin marketplace add madushan/agent-starter

# Install a single plugin
claude plugin install setup-agents@agent-starter
claude plugin install safety-hooks@agent-starter
claude plugin install quality-hooks@agent-starter
```

### Antigravity (`agy`)

Every plugin here is also installable through the `agy` CLI — no separate build
or manifest needed, `agy` reads the same `plugins/` layout directly:

```bash
git clone https://github.com/madushan-sooriyarathne/agent-starter
agy plugin install ./agent-starter                    # installs all 22 plugins
agy plugin install ./agent-starter/plugins/setup-agents # or just one
```

`agy plugin install` on a directory containing a `plugins/` folder auto-detects
it as a bulk marketplace and installs every plugin found inside. There's no
`agy`-native equivalent of `claude plugin marketplace add <owner>/<repo>` yet
(`agy plugin link` requires a marketplace that's already registered, and no
`agy plugin marketplace add`-style command exists) — cloning locally and
pointing `agy plugin install` at the checkout is the supported path today.
Run `agy plugin list` afterward, then reload Antigravity or start a new
session so `/setup-agents` (and the other skills) are picked up.

## Layout

```
agent-starter/
├── .claude-plugin/marketplace.json   # marketplace manifest
├── agents/                           # 8 review agent definitions
├── rules/                            # 16 rule files
├── hooks/                            # 10 hook scripts + tests/
├── skills/                           # 11 bundled skill dirs
├── plugins/                          # 22 plugin dirs (plugin.json + symlinks)
├── scripts/
│   └── materialize-agy-skills.sh     # regenerates plugins/*/skills/ real copies for agy
├── templates/
│   ├── CLAUDE.template.md            # shipped to user projects by /setup-agents
│   └── settings.json                 # hook-wired settings template
├── install.sh                        # terminal entry point
└── README.md
```

`plugins/<name>/` contains a `.claude-plugin/plugin.json` and relative symlinks
into the top-level `agents/`/`rules/`/`hooks/` dirs — no copies. The one
exception is `plugins/<name>/skills/<name>/`: `agy`'s plugin scanner follows
symlinked _files_ but not symlinked _directories_, so those are real,
generated copies of `skills/<name>/` instead of symlinks (Claude Code doesn't
need this — it dereferences marketplace symlinks fine either way).

## Development

```bash
bash hooks/tests/run-all.sh              # run all hook fixture tests (requires jq)
claude plugin validate . --strict        # validate marketplace + plugin manifests
agy plugin validate plugins/<name>       # validate a single plugin against agy's schema
./scripts/materialize-agy-skills.sh      # after editing anything under skills/<name>/, regenerate plugins/*/skills/ copies
./scripts/materialize-agy-skills.sh --check  # verify copies aren't stale (no writes)
```

Every new or modified hook ships with fixtures under `hooks/tests/fixtures/<hook-name>/`. After changing any manifest, skill, or agent frontmatter, run `claude plugin validate . --strict`.
