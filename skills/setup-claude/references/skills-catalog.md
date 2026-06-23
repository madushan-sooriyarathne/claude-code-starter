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

| #   | Skill            | Repo URL                                   | `--skill`          | Recommend when                                |
| --- | ---------------- | ------------------------------------------ | ------------------ | --------------------------------------------- |
| 1   | frontend-design  | `https://github.com/anthropics/skills`     | `frontend-design`  | Next.js detected                              |
| 2   | webapp-testing   | `https://github.com/anthropics/skills`     | `webapp-testing`   | Always                                        |
| 3   | next-pro-seo     | `https://github.com/madushan/next-pro-seo` | `next-pro-seo`     | `next.config.*` detected                      |
| 4   | brand-guidelines | `https://github.com/anthropics/skills`     | `brand-guidelines` | Hospitality / real-estate / marketing signals |
| 5   | mcp-builder      | `https://github.com/anthropics/skills`     | `mcp-builder`      | Opt-in (off by default)                       |
| 6   | skill-creator    | `https://github.com/anthropics/skills`     | `skill-creator`    | Opt-in (off by default)                       |

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
