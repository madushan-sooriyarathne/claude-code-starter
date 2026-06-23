#!/usr/bin/env bash
#
# claude-code-starter — install.sh
#
# Terminal entry point. Scaffolds a tailored .claude/ workspace (agents, rules,
# hooks, skills) and CLAUDE.md into a project. Same flow as the /setup-claude
# slash command. Standard bash + bunx only; no fzf/dialog/jq dependencies.
#
# Usage:  ./install.sh
#
# Resolves its own location via SCRIPT_DIR, so it finds its agents/rules/hooks
# regardless of where it is invoked from.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VERSION="0.1.0"

# ---- pretty output -------------------------------------------------------
if [ -t 1 ]; then
  BOLD="$(printf '\033[1m')"; DIM="$(printf '\033[2m')"; RESET="$(printf '\033[0m')"
  GREEN="$(printf '\033[32m')"; CYAN="$(printf '\033[36m')"; YELLOW="$(printf '\033[33m')"
else
  BOLD=""; DIM=""; RESET=""; GREEN=""; CYAN=""; YELLOW=""
fi
say()  { printf '%s\n' "$*"; }
head() { printf '\n%s%s%s\n' "$BOLD$CYAN" "$*" "$RESET"; }
ok()   { printf '  %s✓%s %s\n' "$GREEN" "$RESET" "$*"; }
skip() { printf '  %s•%s %s\n' "$DIM" "$RESET" "$*"; }

# Determine once whether a controlling terminal is actually readable.
INTERACTIVE=0
if (exec < /dev/tty) 2>/dev/null; then INTERACTIVE=1; fi

ask_line() {
  # Reads one line from the terminal into REPLY_LINE; empty if non-interactive.
  REPLY_LINE=""
  if [ "$INTERACTIVE" = "1" ]; then
    read -r REPLY_LINE < /dev/tty || REPLY_LINE=""
  fi
}

say "${BOLD}claude-code-starter${RESET} v$VERSION — Claude Code project setup"

# ========================================================================
# Step 0 — Target directory (install.sh only)
# ========================================================================
TARGET_DEFAULT="$(pwd)"
say ""
say "Detected target directory: ${BOLD}$TARGET_DEFAULT${RESET}"
printf "Install .claude/ here? [Y/n] or enter a different path: "
ask_line
case "$REPLY_LINE" in
  ""|y|Y|yes|YES) TARGET="$TARGET_DEFAULT" ;;
  n|N|no|NO)      say "Aborted."; exit 0 ;;
  *)              TARGET="$REPLY_LINE" ;;
esac
# Expand a leading ~ if present.
case "$TARGET" in "~"|"~/"*) TARGET="${HOME}${TARGET#\~}";; esac
if [ ! -d "$TARGET" ]; then
  say "${YELLOW}Path is not a directory:${RESET} $TARGET"; exit 1
fi
TARGET="$(cd "$TARGET" && pwd)"

# ========================================================================
# Step 1 — Scan the project
# ========================================================================
HAS_PKG=0; HAS_MONOREPO=0; HAS_TURBO=0; HAS_NEXT=0; HAS_DRIZZLE=0
HAS_SANITY=0; HAS_AUTH=0; HAS_BIOME=0; HAS_TS=0; HAS_DEPLOY=0; HAS_CLAUDE=0
HAS_HOSPITALITY=0

[ -f "$TARGET/package.json" ] && HAS_PKG=1
[ -f "$TARGET/pnpm-workspace.yaml" ] && HAS_MONOREPO=1
[ -f "$TARGET/turbo.json" ] && { HAS_TURBO=1; HAS_MONOREPO=1; }
ls "$TARGET"/next.config.* >/dev/null 2>&1 && HAS_NEXT=1
ls "$TARGET"/drizzle.config.* >/dev/null 2>&1 && HAS_DRIZZLE=1
ls "$TARGET"/sanity.config.* >/dev/null 2>&1 && HAS_SANITY=1
{ [ -f "$TARGET/biome.json" ] || [ -f "$TARGET/biome.jsonc" ]; } && HAS_BIOME=1
[ -f "$TARGET/tsconfig.json" ] && HAS_TS=1
[ -d "$TARGET/.claude" ] && HAS_CLAUDE=1

if [ "$HAS_PKG" = "1" ]; then
  PKG="$(cat "$TARGET/package.json" 2>/dev/null || printf '')"
  printf '%s' "$PKG" | grep -q '"better-auth"' && HAS_AUTH=1
  printf '%s' "$PKG" | grep -Eq '"@sanity/|"sanity"[[:space:]]*:' && HAS_SANITY=1
  printf '%s' "$PKG" | grep -Eq '"next"[[:space:]]*:' && HAS_NEXT=1
  printf '%s' "$PKG" | grep -Eq '"typescript"[[:space:]]*:' && HAS_TS=1
  printf '%s' "$PKG" | grep -Eiq 'hotel|resort|booking|hospitality|property|listing|realty|real[-_ ]?estate' && HAS_HOSPITALITY=1
fi
{ [ -f "$TARGET/auth.ts" ] || [ -d "$TARGET/app/api/auth" ] || [ -d "$TARGET/src/app/api/auth" ]; } && HAS_AUTH=1
{ [ -f "$TARGET/Dockerfile" ] || ls "$TARGET"/docker-compose.* >/dev/null 2>&1 \
  || [ -f "$TARGET/Caddyfile" ] || [ -f "$TARGET/nginx.conf" ]; } && HAS_DEPLOY=1

detectedStack=()
[ "$HAS_NEXT" = "1" ]     && detectedStack+=("next.js")
[ "$HAS_TURBO" = "1" ]    && detectedStack+=("turborepo")
[ "$HAS_MONOREPO" = "1" ] && [ "$HAS_TURBO" != "1" ] && detectedStack+=("pnpm-workspaces")
[ "$HAS_DRIZZLE" = "1" ]  && detectedStack+=("drizzle")
[ "$HAS_AUTH" = "1" ]     && detectedStack+=("betterauth")
[ "$HAS_SANITY" = "1" ]   && detectedStack+=("sanity")
[ "$HAS_BIOME" = "1" ]    && detectedStack+=("biome")
[ "$HAS_TS" = "1" ]       && detectedStack+=("typescript")

head "Scan results"
if [ ${#detectedStack[@]} -gt 0 ]; then
  say "  Detected: ${detectedStack[*]}"
else
  say "  No known stack markers found — defaults will be conservative."
fi
[ "$HAS_CLAUDE" = "1" ] && say "  ${YELLOW}Existing .claude/ found — existing files will be kept, not overwritten.${RESET}"

# ========================================================================
# Numbered multi-select helper
#   Inputs (globals): names[], descs[], defaults[] (0/1)
#   Output (global):  selected[]
# ========================================================================
prompt_category() {
  local title="$1"; local n=${#names[@]}; local i
  head "$title"
  for ((i=0; i<n; i++)); do
    local mark=" "; [ "${defaults[$i]}" = "1" ] && mark="x"
    printf "  %2d) [%s] %-26s %s%s%s\n" "$((i+1))" "$mark" "${names[$i]}" "$DIM" "${descs[$i]}" "$RESET"
  done
  say "  ${DIM}Enter numbers (e.g. 1 3), 'a' all, 'n' none, or Enter for [x] defaults.${RESET}"
  printf "> "
  ask_line
  selected=()
  case "$REPLY_LINE" in
    "")
      for ((i=0; i<n; i++)); do [ "${defaults[$i]}" = "1" ] && selected+=("${names[$i]}"); done ;;
    a|A|all|ALL)
      for ((i=0; i<n; i++)); do selected+=("${names[$i]}"); done ;;
    n|N|none|NONE|0)
      : ;;
    *)
      local tok
      for tok in $REPLY_LINE; do
        case "$tok" in
          ''|*[!0-9]*) continue ;;
        esac
        if [ "$tok" -ge 1 ] && [ "$tok" -le "$n" ]; then
          selected+=("${names[$((tok-1))]}")
        fi
      done ;;
  esac
}

contains() { # contains needle "${haystack[@]}"
  local needle="$1"; shift
  local x; for x in "$@"; do [ "$x" = "$needle" ] && return 0; done; return 1
}

# ========================================================================
# Step 2 — Category selection
# ========================================================================

# --- Agents ---
names=(code-reviewer security-reviewer performance-reviewer sanity-reviewer doc-reviewer)
descs=("TS/Next/Hono correctness" "auth, API, env, injection" "re-renders, N+1, bundle" "Sanity schema & GROQ" "docs, README, CLAUDE.md")
defaults=(1 1 0 0 1)
[ "$HAS_NEXT" = "1" ] || [ "$HAS_DRIZZLE" = "1" ] && defaults[2]=1
[ "$HAS_SANITY" = "1" ] && defaults[3]=1
prompt_category "Agents"
sel_agents=(); [ ${#selected[@]} -gt 0 ] && sel_agents=("${selected[@]}")

# --- Rules ---
names=(typescript git-workflow nextjs monorepo)
descs=("no any, infer from Drizzle, Zod" "commits, branches, no force-push" "App Router, server/client" "Turbo/pnpm boundaries")
defaults=(1 1 0 0)
[ "$HAS_NEXT" = "1" ] && defaults[2]=1
{ [ "$HAS_TURBO" = "1" ] || [ "$HAS_MONOREPO" = "1" ]; } && defaults[3]=1
prompt_category "Rules"
sel_rules=(); [ ${#selected[@]} -gt 0 ] && sel_rules=("${selected[@]}")

# --- Hooks ---
names=(block-dangerous-commands scan-secrets format-on-save)
descs=("block rm -rf /, DROP TABLE, --force" "block hardcoded secrets" "biome check --write on .ts/.tsx")
defaults=(1 1 0)
[ "$HAS_BIOME" = "1" ] && defaults[2]=1
prompt_category "Hooks"
sel_hooks=(); [ ${#selected[@]} -gt 0 ] && sel_hooks=("${selected[@]}")

# --- Skills (GitHub repos via `bunx skills add <repo> --skill <name>`) ---
# Parallel arrays: names[] (display) / repos[] (github URL) / skillnames[] / descs[] / defaults[]
names=(frontend-design      webapp-testing       next-pro-seo                              brand-guidelines     mcp-builder          skill-creator)
repos=(https://github.com/anthropics/skills https://github.com/anthropics/skills https://github.com/madushan/next-pro-seo https://github.com/anthropics/skills https://github.com/anthropics/skills https://github.com/anthropics/skills)
skillnames=(frontend-design webapp-testing       next-pro-seo                              brand-guidelines     mcp-builder          skill-creator)
descs=("UI / component design" "web app testing" "Next.js SEO/GEO (your repo, needs gh auth)" "brand voice & guidelines" "build MCP servers" "author new skills")
defaults=(0 1 0 0 0 0)
[ "$HAS_NEXT" = "1" ] && { defaults[0]=1; defaults[2]=1; }
[ "$HAS_HOSPITALITY" = "1" ] && defaults[3]=1
prompt_category "Skills (bunx skills add <repo> --skill <name>)"
sel_skills=(); [ ${#selected[@]} -gt 0 ] && sel_skills=("${selected[@]}")

# --- CLAUDE.md ---
head "CLAUDE.md template"
WANT_CLAUDEMD=0
if [ -f "$TARGET/CLAUDE.md" ]; then
  printf "  CLAUDE.md already exists. Overwrite with the template? [y/N]: "
  ask_line
  case "$REPLY_LINE" in y|Y|yes|YES) WANT_CLAUDEMD=1 ;; *) WANT_CLAUDEMD=0 ;; esac
else
  printf "  Copy the CLAUDE.md template to the project root? [Y/n]: "
  ask_line
  case "$REPLY_LINE" in ""|y|Y|yes|YES) WANT_CLAUDEMD=1 ;; *) WANT_CLAUDEMD=0 ;; esac
fi

# ========================================================================
# Step 3 — Install
# ========================================================================
head "Installing"

copy_managed() { # copy_managed <src> <dest> <label>
  local src="$1" dest="$2" label="$3"
  if [ ! -f "$src" ]; then skip "$label (source missing: $src)"; return; fi
  if [ -e "$dest" ]; then skip "$label (exists, kept)"; return; fi
  cp "$src" "$dest" && ok "$label"
}

if [ ${#sel_agents[@]} -gt 0 ]; then
  mkdir -p "$TARGET/.claude/agents"
  for a in "${sel_agents[@]}"; do
    copy_managed "$SCRIPT_DIR/agents/$a.md" "$TARGET/.claude/agents/$a.md" "agent: $a"
  done
fi

if [ ${#sel_rules[@]} -gt 0 ]; then
  mkdir -p "$TARGET/.claude/rules"
  for r in "${sel_rules[@]}"; do
    copy_managed "$SCRIPT_DIR/rules/$r.md" "$TARGET/.claude/rules/$r.md" "rule: $r"
  done
fi

if [ ${#sel_hooks[@]} -gt 0 ]; then
  mkdir -p "$TARGET/.claude/hooks"
  for h in "${sel_hooks[@]}"; do
    copy_managed "$SCRIPT_DIR/hooks/$h.sh" "$TARGET/.claude/hooks/$h.sh" "hook: $h"
    [ -f "$TARGET/.claude/hooks/$h.sh" ] && chmod +x "$TARGET/.claude/hooks/$h.sh"
  done

  # Register hooks in .claude/settings.json (merge via node/bun).
  JS=""
  command -v node >/dev/null 2>&1 && JS="node"
  [ -z "$JS" ] && command -v bun >/dev/null 2>&1 && JS="bun"
  SETTINGS="$TARGET/.claude/settings.json"
  if [ -n "$JS" ]; then
    MERGE="$(mktemp 2>/dev/null || printf '%s' "${TMPDIR:-/tmp}/ccs-merge.$$.js")"
    cat > "$MERGE" <<'JSEOF'
const fs = require('fs');
const [settingsPath, ...hooks] = process.argv.slice(2);
const reg = {
  'block-dangerous-commands': { event: 'PreToolUse',  matcher: 'Bash' },
  'scan-secrets':             { event: 'PreToolUse',  matcher: 'Write|Edit' },
  'format-on-save':           { event: 'PostToolUse', matcher: 'Write|Edit' },
};
let s = {};
try { s = JSON.parse(fs.readFileSync(settingsPath, 'utf8') || '{}'); } catch (e) { s = {}; }
s.hooks = s.hooks || {};
for (const h of hooks) {
  const r = reg[h];
  if (!r) continue;
  const cmd = 'bash "$CLAUDE_PROJECT_DIR/.claude/hooks/' + h + '.sh"';
  s.hooks[r.event] = s.hooks[r.event] || [];
  let group = s.hooks[r.event].find(g => g && g.matcher === r.matcher);
  if (!group) { group = { matcher: r.matcher, hooks: [] }; s.hooks[r.event].push(group); }
  group.hooks = group.hooks || [];
  if (!group.hooks.some(x => x && x.command === cmd)) {
    group.hooks.push({ type: 'command', command: cmd });
  }
}
fs.writeFileSync(settingsPath, JSON.stringify(s, null, 2) + '\n');
JSEOF
    if "$JS" "$MERGE" "$SETTINGS" "${sel_hooks[@]}"; then
      ok "registered hooks in .claude/settings.json"
    else
      skip "could not auto-register hooks — add them to settings.json manually"
    fi
    rm -f "$MERGE"
  else
    skip "node/bun not found — hooks copied but not registered in settings.json"
  fi
fi

# Skills (GitHub repos via the Vercel `skills` CLI: add <repo> --skill <name>)
if [ ${#sel_skills[@]} -gt 0 ]; then
  RUNNER=""
  command -v bunx >/dev/null 2>&1 && RUNNER="bunx"
  [ -z "$RUNNER" ] && command -v npx >/dev/null 2>&1 && RUNNER="npx"
  if [ -z "$RUNNER" ]; then
    skip "bunx/npx not found — skipping skill installation"
    sel_skills=()
  else
    installed_skills=()
    # Re-map selected display names to their repo URL + skill name.
    # (names[]/repos[]/skillnames[] are the skills arrays still in scope.)
    for s_name in "${sel_skills[@]}"; do
      repo=""; skn="$s_name"; idx=0
      for nm in "${names[@]}"; do
        if [ "$nm" = "$s_name" ]; then repo="${repos[$idx]}"; skn="${skillnames[$idx]}"; break; fi
        idx=$((idx+1))
      done
      printf "  installing skill: %s --skill %s\n" "$repo" "$skn"
      if ( cd "$TARGET" && "$RUNNER" skills add "$repo" --skill "$skn" -a claude-code -y </dev/null ); then
        ok "skill: $skn"
        installed_skills+=("$skn")
      else
        skip "skill failed: $skn (private repos need 'gh auth' — continuing)"
      fi
    done
    sel_skills=(); [ ${#installed_skills[@]} -gt 0 ] && sel_skills=("${installed_skills[@]}")
  fi
fi

# CLAUDE.md
if [ "$WANT_CLAUDEMD" = "1" ]; then
  if [ -f "$SCRIPT_DIR/templates/CLAUDE.template.md" ]; then
    cp "$SCRIPT_DIR/templates/CLAUDE.template.md" "$TARGET/CLAUDE.md" && ok "CLAUDE.md"
  else
    skip "CLAUDE.md template missing in plugin"
  fi
fi

# ========================================================================
# Step 4 — Finalize
# ========================================================================
json_array() {
  local out="" first=1 x
  for x in "$@"; do
    if [ $first -eq 1 ]; then first=0; else out="$out, "; fi
    out="$out\"$x\""
  done
  printf '[%s]' "$out"
}
TS_NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date)"
CLAUDEMD_BOOL="false"; [ "$WANT_CLAUDEMD" = "1" ] && [ -f "$TARGET/CLAUDE.md" ] && CLAUDEMD_BOOL="true"
mkdir -p "$TARGET/.claude"
cat > "$TARGET/.claude/.madushan-setup.json" <<EOF
{
  "version": "$VERSION",
  "installedAt": "$TS_NOW",
  "detectedStack": $(json_array ${detectedStack[@]+"${detectedStack[@]}"}),
  "installed": {
    "agents": $(json_array ${sel_agents[@]+"${sel_agents[@]}"}),
    "rules": $(json_array ${sel_rules[@]+"${sel_rules[@]}"}),
    "hooks": $(json_array ${sel_hooks[@]+"${sel_hooks[@]}"}),
    "skills": $(json_array ${sel_skills[@]+"${sel_skills[@]}"}),
    "claudeMd": $CLAUDEMD_BOOL
  }
}
EOF
ok "wrote .claude/.madushan-setup.json"

head "Done"
say "  Target:   $TARGET"
say "  Agents:   ${sel_agents[*]:-(none)}"
say "  Rules:    ${sel_rules[*]:-(none)}"
say "  Hooks:    ${sel_hooks[*]:-(none)}"
say "  Skills:   ${sel_skills[*]:-(none)}"
say "  CLAUDE.md: $CLAUDEMD_BOOL"
say ""
say "${YELLOW}Restart Claude Code${RESET} so the new agents, rules, and hooks are picked up."
