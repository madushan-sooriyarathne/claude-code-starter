# agent-starter (this repo)

A Claude Code plugin marketplace: agents, skills, rules, and safety hooks, published from the top-level directories. There is no application code, build, or package manager here — everything is bash + markdown + JSON.

## Commands

```bash
bash hooks/tests/run-all.sh              # run all hook fixture tests (requires jq)
claude plugin validate . --strict        # validate marketplace + plugin manifests
agy plugin validate plugins/<name>       # validate a single plugin against agy's own schema
./scripts/materialize-agy-skills.sh --check  # verify plugins/*/skills/ copies aren't stale
```

## Architecture

- Top-level `agents/`, `skills/`, `rules/`, `hooks/` are the single source of truth. `plugins/<name>/` dirs contain a `plugin.json` plus **relative symlinks** into the top-level dirs (Claude Code dereferences marketplace-internal symlinks at install) — never put real component copies there. Plugin sources must NOT be `"./"`: with the repo root as plugin root, default component discovery would load every skill/agent into every plugin.
  - **Exception: `plugins/<name>/skills/<name>/`.** `agy`'s plugin scanner follows symlinked *files* (that's why `agents/<name>.md` symlinks work) but silently skips symlinked *directories* — so a whole-directory symlink for a skill is invisible to `agy plugin install`. Those are real, generated copies instead, produced by `./scripts/materialize-agy-skills.sh`. Run it (or at least `--check`) after touching anything under `skills/<name>/` and commit both the source and the regenerated copy.
- `templaes/CLAUDE.template.md` is the template shipped to user projects by `/setup-agents`. This file (`CLAUDE.md`) is for working on the repo itself — don't confuse the two.
- `templates/settings.json` is the template users copy to `.claude/settings.json`; it wires the hooks.
- **Two install hosts, two distribution mechanisms.**
  - **Scaffolding a target project** (`install.sh` / the `setup-agents` skill's in-session flow): materializes output into either Claude Code (`.claude/` + `settings.json`) or Antigravity (`.agents/plugins/setup-agents/` + `AGENTS.md`) in a project the user is working on; the platform prompt / `WANT_CLAUDE`/`WANT_AG` gate the two paths. Scan + selection are host-agnostic — only how the plan is written to disk differs.
  - **Installing this repo itself as a plugin**: Claude Code via `claude plugin marketplace add` + `.claude-plugin/marketplace.json` (existing); Antigravity via `agy plugin install <path-to-checkout>` — `agy` auto-detects a `plugins/` dir as a bulk marketplace and reads each `.claude-plugin/plugin.json` directly, no extra manifest needed. `plugins/setup-agents/plugin.json` (root-level, sibling to `.claude-plugin/plugin.json`) is the `agy`-native marker that also lets `agy plugin validate`/`install` target that one plugin directly. There's no confirmed `agy`-native equivalent of `claude plugin marketplace add <owner>/<repo>` yet (`agy plugin link` requires an already-registered marketplace name; no `marketplace add` subcommand was found) — local-path install is the supported flow for now.
- **Antigravity port rules:** `agy plugin validate` does recognize a native `agents/<name>.md` component, but whether `agy` actually runs it as a delegable subagent at runtime (vs. a passive prompt fragment) is unconfirmed — so agents still ship as skills (`skills/<name>/SKILL.md`, frontmatter reduced to name+description) rather than switching to the native component. `hooks/` splits into `hooks/claude/` and `hooks/antigravity/` — one subdir per host, no shared/flat scripts. All 10 hooks port, **duplicated** not translated: `hooks/antigravity/<name>.sh` reimplements the same detection rules as `hooks/claude/<name>.sh` directly against AG's native contract (always exits 0 — the gate/result lives in stdout), instead of shimming into the Claude-shaped `tool_input`/exit-2 contract. No shared source between the two copies — when detection rules change, mirror the change in both files by hand. `AG_SUPPORTED_HOOKS` in `install.sh` is the eligible set. `hooks/tests/fixtures/` mirrors the same split (`fixtures/claude/<name>/`, `fixtures/antigravity/<name>/`).
  - The 4 safety hooks map 1:1 onto `PreToolUse` (`{"toolCall":{"name","args"}}` stdin / `{"decision","reason"}` stdout). The other 6 needed a redesign, not just a contract swap, because AG's `PostToolUse` carries no tool args at all (confirmed against AG's own hooks docs — stdin is only `{stepIdx, error, conversationId, workspacePaths, ...}`, no file path, no tool name): `typecheck-on-stop`/`lint-on-stop`/`format-on-save`/`auto-test`/`notify` moved to `Stop` (fires once the execution loop is about to fully terminate), using `git status`/`git diff` against `workspacePaths[0]` in place of the Claude-side PostToolUse dirty-marker; `session-start` moved to `PreInvocation` (fires before every model call, gated to `invocationNum==0` to approximate "session start"). `install.sh`'s AG `hooks.json` generator emits two different shapes accordingly: `PreToolUse`/`PostToolUse` get the `matcher`+`hooks[]` wrapper, `PreInvocation`/`PostInvocation`/`Stop` are a flat handler array with no matcher.
  - **Unverified**: `typecheck-on-stop.sh` and `lint-on-stop.sh` both request `{"decision":"continue"}` on failure (AG only injects `reason` into the agent's context when `decision` is `"continue"`), guarded by a `conversationId`-keyed `/tmp` marker so each nags at most once per conversation per failing state. AG's `Stop` schema has no `stop_hook_active`-equivalent field, and its docs don't say how multiple independent Stop hooks' `decision` values combine if more than one requests `"continue"` in the same cycle — both are inferred designs, not documented behavior. Needs testing against a real Antigravity instance before relying on it.
  - Skills installed via `agy` (bulk or single-plugin) stage as a full verbatim copy of the plugin directory under `~/.gemini/config/plugins/<name>/` — confirmed by inspecting a real local install. A skill that needs sibling assets outside its own dir (like `setup-agents`'s `template/`) can rely on that path existing, since `$CLAUDE_PLUGIN_ROOT` is not set under Antigravity.
  - `install.sh`'s third-party skill/plugin catalog (`sel_skills`, `caveman`) installs through the Vercel `skills` CLI (`bunx skills add <repo> --skill <name> -a <agent>`), which ships a project-scoped `antigravity-cli` adapter (writes `.agents/skills/`) alongside `claude-code` (writes `.claude/skills/`) — confirmed via the installed package's own adapter registry. `install.sh` runs it once per selected host. `ponytail` (Claude plugin marketplace only) and `graphify` (host-agnostic Python tool) don't have/need that adapter split — see the Step 4c comments in `install.sh`.

## Key decisions

- Versioning: each `plugins/<name>/.claude-plugin/plugin.json` carries semver — bump it when that plugin's components change. Marketplace entries carry NO version (plugin.json silently wins; never set both). `plugins/setup-agents/plugin.json` (the `agy`-native marker) tracks the same version.
- Hooks fail open (exit 0) when `jq` is missing, except file-protection hooks which fail closed. Hook `timeout` values are in seconds.
- Agents never set `model` — users choose their own.
- No unconfirmed URLs get shipped in generated config (e.g. `plugin.json`'s `$schema`) — `agy` has no published schema URL, so none is set, rather than guessing one.

## Workflow

- Every new or modified hook MUST ship with fixtures under `hooks/tests/fixtures/<host>/<hook-name>/` (`<host>` = `claude` or `antigravity`).
- After changing any manifest, skill, or agent frontmatter, run `claude plugin validate . --strict`.
- After changing anything under `skills/<name>/`, run `./scripts/materialize-agy-skills.sh` and commit the regenerated `plugins/*/skills/<name>/` copies alongside it.
- Adding/renaming a skill or agent requires: marketplace entry, `plugins/<name>/` (plugin.json + symlink; skills additionally need a materialized copy, see above).
