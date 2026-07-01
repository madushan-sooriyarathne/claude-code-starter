# Skills Catalog

## Bundled Skills

These skills ship with this plugin and are **already available** — no install command
needed. When selected in setup-agents, they are logged as "available (bundled)" in the
summary. Surface them to the user so they know what they have.

| #   | Skill            | Description                                                                                          | Recommend when                                                  |
| --- | ---------------- | ---------------------------------------------------------------------------------------------------- | --------------------------------------------------------------- |
| B1  | `catchup`        | Rebuild working context fast after `/clear` or a fresh session; summarizes branch changes            | Always                                                          |
| B2  | `debug-fix`      | Find and fix a bug. `--fast` flag for emergency hotfix mode                                          | Always                                                          |
| B3  | `explain`        | One-sentence summary + mental model. `verbose` for ASCII diagram + modification guide                | Always                                                          |
| B4  | `fix-issue`      | Take a GitHub issue number to tested fix, prep a closing PR                                          | `gh` + GitHub remote detected                                   |
| B5  | `pr-review`      | Parallel specialist-agent review (quality, security, performance, silent failures, tests, docs)      | `gh` + GitHub remote detected                                   |
| B6  | `refactor`       | Safe refactor with tests as safety net. `--diff` to simplify current diff before committing          | Always                                                          |
| B7  | `ship`           | Scan changes → commit → push → create PR, with confirmation at each step                             | `gh` + GitHub remote detected                                   |
| B8  | `tdd`            | TDD loop: failing test first → minimum code to pass → refactor → repeat                              | Test runner detected (`jest.config.*`, `vitest.config.*`, etc.) |
| B9  | `test-writer`    | Write comprehensive tests for new or changed code                                                    | Test runner detected                                            |
| B10 | `claude-md`      | Keep CLAUDE.md current and lean. `audit` to check for stale commands, drift, and bloat              | Always                                                          |
| B11 | `context-budget` | Estimate per-turn token cost of `.claude/` and `CLAUDE.md`; flags over-budget contributors          | Always                                                          |

## External Skills

Installed with the Vercel `skills` CLI
([vercel-labs/skills](https://github.com/vercel-labs/skills)) from a **GitHub repo URL
plus a skill name** — never via a Claude Code marketplace/plugin install. Each row
below maps a display name to its repo and `--skill` argument.

Install (non-interactive, into the project's Claude Code skills), run from the project
directory:

```bash
bunx skills add <repo-url> --skill <skill-name> -a claude-code -y
# example:
bunx skills add https://github.com/anthropics/skills --skill frontend-design -a claude-code -y
```

| #   | Skill                        | Repo URL                                              | `--skill`                      | Recommend when                                         |
| --- | ---------------------------- | ----------------------------------------------------- | ------------------------------ | ------------------------------------------------------ |
| 1   | frontend-design              | `https://github.com/anthropics/skills`                | `frontend-design`              | Frontend detected (`.tsx`/`.jsx`, `components/` dir)  |
| 2   | webapp-testing               | `https://github.com/anthropics/skills`                | `webapp-testing`               | Always                                                 |
| 3   | next-pro-seo                 | `https://github.com/madushan/next-pro-seo`            | `next-pro-seo`                 | `next.config.*` detected                               |
| 4   | brand-guidelines             | `https://github.com/anthropics/skills`                | `brand-guidelines`             | Hospitality / real-estate / marketing signals          |
| 5   | mcp-builder                  | `https://github.com/anthropics/skills`                | `mcp-builder`                  | Opt-in (off by default)                                |
| 6   | skill-creator                | `https://github.com/anthropics/skills`                | `skill-creator`                | Opt-in (off by default)                                |
| 7   | vercel-react-best-practices  | `https://github.com/vercel-labs/agent-skills`         | `vercel-react-best-practices`  | `react` dep detected                                   |
| 8   | vercel-composition-patterns  | `https://github.com/vercel-labs/agent-skills`         | `vercel-composition-patterns`  | `react` dep detected                                   |
| 9   | shadcn                       | `https://github.com/shadcn/ui`                        | `shadcn`                       | `react` dep + `components/` dir detected               |
| 10  | systematic-debugging         | `https://github.com/obra/superpowers`                 | `systematic-debugging`         | Always                                                 |
| 11  | next-best-practices          | `https://github.com/vercel-labs/next-skills`          | `next-best-practices`          | `next.config.*` detected                               |
| 12  | emil-design-eng              | `https://github.com/emilkowalski/skills`              | `emil-design-eng`              | Next.js + `framer-motion` or `motion` dep detected     |
| 13  | agent-browser                | `https://github.com/vercel-labs/agent-browser`        | `agent-browser`                | `playwright.config.*` or `cypress` detected            |
| 14  | web-design-guidelines        | `https://github.com/vercel-labs/agent-skills`         | `web-design-guidelines`        | Any frontend detected                                  |
| 15  | tdd                          | `https://github.com/mattpocock/skills`                | `tdd`                          | Test config detected (`jest.config.*`, `vitest.config.*`, etc.) |
| 16  | to-prd                       | `https://github.com/mattpocock/skills`                | `to-prd`                       | Opt-in (off by default)                                |
| 17  | ui-ux-pro-max                | `https://github.com/nextlevelbuilder/ui-ux-pro-max-skill` | `ui-ux-pro-max`           | Frontend detected                                      |

## Adding your own

Any GitHub repo whose skills live under `skills/<name>/SKILL.md` works — add a row with
the repo URL and the `--skill` name. To discover what a repo offers:

```bash
bunx skills add <repo-url> --list
```

## Notes

- **`-a claude-code -y`** targets the Claude Code agent and runs non-interactively.
  Run from the project directory for a project-level install; add `-g` for a user-level
  (global) install.
- **`--skill <name>`** installs one named skill from a multi-skill repo. Omit it to be
  prompted, or use `--skill '*'` to install all skills in the repo.
- Record installed skill names in `.setup-log.json`.
