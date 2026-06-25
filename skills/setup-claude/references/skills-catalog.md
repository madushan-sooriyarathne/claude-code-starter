# Skills Catalog

All skills are installed with the Vercel `skills` CLI
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
