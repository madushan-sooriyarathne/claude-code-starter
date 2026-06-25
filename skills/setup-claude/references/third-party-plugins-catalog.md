# Third-Party Plugins Catalog

Plugins with post-install configuration actions — they write rules or snippets into the
project's `CLAUDE.md` or `.claude/` to change Claude's default behavior. Presented as a
separate category from skills so the post-install actions are applied consistently.

All three are **pre-marked by default** (user must explicitly deselect).

---

## Install mechanisms

### Caveman — ultra-compressed communication mode

| Field         | Value |
|---------------|-------|
| Repo          | `https://github.com/JuliusBrussee/caveman` |
| Install cmd   | `bunx skills add JuliusBrussee/caveman -a claude-code -y` |
| Scope         | Project (skills CLI writes to `.claude/skills/`) |
| Default       | ✅ pre-selected |

**Post-install — append to `CLAUDE.md`:**

```markdown
# Communication style
Use caveman mode for all responses: drop articles, drop filler words, fragments OK.
Activate with `/caveman` at session start (or load via skill).
```

### Ponytail — lazy senior developer mode (YAGNI enforcer)

| Field         | Value |
|---------------|-------|
| Repo          | `https://github.com/DietrichGebert/ponytail` |
| Install cmd   | In-session: `/plugin marketplace add DietrichGebert/ponytail` then `/plugin install ponytail@ponytail` |
| Scope         | User-scoped (Claude Code plugin system; no `--project` flag available) |
| Default       | ✅ pre-selected |

> **Note:** Ponytail uses the Claude Code native plugin system which installs to `~/.claude/`
> (user scope), not the project `.claude/`. This means it is available across all projects
> for this user. Inform the user before installing.

**Post-install — append to `CLAUDE.md`:**

```markdown
# Build discipline
Apply ponytail (YAGNI) discipline: stop at the first rung of the ladder that holds.
No speculative abstractions, no boilerplate for later. Activate with `/ponytail` or
load via the ponytail skill.
```

**Post-install instruction to user:**
Tell the user to run these two commands in a Claude Code session in their project:
```
/plugin marketplace add DietrichGebert/ponytail
/plugin install ponytail@ponytail
```
Then restart Claude Code.

### Graphify — codebase knowledge graph

| Field         | Value |
|---------------|-------|
| Repo          | `https://github.com/safishamsi/graphify` |
| Install cmd   | `uv tool install graphifyy` (system-level) then `graphify claude install` (project CLAUDE.md) |
| Scope         | System tool + project CLAUDE.md config |
| Default       | ✅ pre-selected |
| Prerequisite  | Python 3.10+ and `uv` or `pipx` on PATH |

**Install sequence (run from project directory):**

```bash
# 1. Install the system tool (skip if already installed)
uv tool install graphifyy || pipx install graphifyy

# 2. Register with Claude Code (writes graphify instructions to CLAUDE.md)
graphify claude install

# 3. Build initial knowledge graph
graphify build

# 4. (Optional) Install auto-rebuild git hook
graphify hook install
```

**Post-install — `graphify claude install` writes to `CLAUDE.md` automatically.**
Additionally append this rule to `CLAUDE.md` after the graphify block:

```markdown
# Codebase graph
Before searching raw files for architecture questions, read `graphify-out/GRAPH_REPORT.md`
for god nodes and community structure. Use it to locate high-impact files before grepping.
```

**Team setup note:** commit `graphify-out/` so teammates get the graph immediately.
Tell the user to run `graphify hook install` on each machine.

---

## Handling in setup-claude flow

1. Present all three as a batch (AskUserQuestion multi-select, all pre-checked).
2. For each selected plugin, apply its install sequence above in order.
3. Caveman and Graphify are fully automated (shell commands). Ponytail requires user
   action — print the two `/plugin` commands and tell the user to run them, then
   continue with the rest of setup.
4. Check for prerequisites before running:
   - Graphify: verify `uv` or `pipx` is on PATH; if neither found, warn and skip with
     a note to install `uv` first (`curl -LsSf https://astral.sh/uv/install.sh | sh`).
5. After all selected plugins are processed, continue to the Skills step.
