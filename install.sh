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
VERSION="0.3.0"

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

contains() { # contains needle "${haystack[@]}"
  local needle="$1"; shift
  local x; for x in "$@"; do [ "$x" = "$needle" ] && return 0; done; return 1
}

json_array() {
  local out="" first=1 x
  for x in "$@"; do
    if [ $first -eq 1 ]; then first=0; else out="$out, "; fi
    out="$out\"$x\""
  done
  printf '[%s]' "$out"
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

# ---- mechanical detection helpers (no node_modules/.git/vendor/build noise) ----
PRUNE_EXPR=( -path '*/node_modules/*' -o -path '*/.git/*' -o -path '*/vendor/*' -o -path '*/dist/*' -o -path '*/build/*' -o -path '*/.next/*' )
find_any() { find "$TARGET" -maxdepth 6 \( "${PRUNE_EXPR[@]}" \) -prune -o -name "$1" -print -quit 2>/dev/null; }
has_any()  { [ -n "$(find_any "$1")" ]; }
find_dir() { find "$TARGET" -maxdepth 6 \( "${PRUNE_EXPR[@]}" \) -prune -o -type d -name "$1" -print -quit 2>/dev/null; }
has_dir()  { [ -n "$(find_dir "$1")" ]; }

# ========================================================================
# Step 1 — Scan the project
# ========================================================================
HAS_PKG=0; HAS_MONOREPO=0; HAS_TURBO=0; HAS_NEXT=0; HAS_DRIZZLE=0
HAS_SANITY=0; HAS_AUTH=0; HAS_BIOME=0; HAS_TS=0; HAS_DEPLOY=0; HAS_CLAUDE=0
HAS_HOSPITALITY=0
HAS_REACT=0; HAS_HONO=0; HAS_BUN=0; HAS_TAILWIND=0
HAS_GO=0; HAS_RUST=0; HAS_PY=0; HAS_RUBY=0; HAS_PHP=0; HAS_JAVA=0
HAS_MAKEFILE=0; HAS_CI=0; HAS_TESTS=0; HAS_FRONTEND=0; HAS_BACKEND=0
HAS_DB=0; HAS_DOCS=0; HAS_LINTER=0; HAS_GH_REMOTE=0

# -- stack manifests --
[ -f "$TARGET/package.json" ] && HAS_PKG=1
[ -f "$TARGET/go.mod" ] && HAS_GO=1
[ -f "$TARGET/Cargo.toml" ] && HAS_RUST=1
{ [ -f "$TARGET/pyproject.toml" ] || [ -f "$TARGET/requirements.txt" ]; } && HAS_PY=1
[ -f "$TARGET/Gemfile" ] && HAS_RUBY=1
[ -f "$TARGET/composer.json" ] && HAS_PHP=1
{ [ -f "$TARGET/build.gradle" ] || [ -f "$TARGET/build.gradle.kts" ] || [ -f "$TARGET/pom.xml" ]; } && HAS_JAVA=1
[ -f "$TARGET/Makefile" ] && HAS_MAKEFILE=1
{ [ -d "$TARGET/.github/workflows" ] || [ -f "$TARGET/.gitlab-ci.yml" ]; } && HAS_CI=1

# -- JS/TS-specific signals --
[ -f "$TARGET/pnpm-workspace.yaml" ] && HAS_MONOREPO=1
[ -f "$TARGET/turbo.json" ] && { HAS_TURBO=1; HAS_MONOREPO=1; }
{ [ -f "$TARGET/lerna.json" ] || [ -f "$TARGET/nx.json" ]; } && HAS_MONOREPO=1
ls "$TARGET"/next.config.* >/dev/null 2>&1 && HAS_NEXT=1
ls "$TARGET"/drizzle.config.* >/dev/null 2>&1 && HAS_DRIZZLE=1
ls "$TARGET"/sanity.config.* >/dev/null 2>&1 && HAS_SANITY=1
{ [ -f "$TARGET/biome.json" ] || [ -f "$TARGET/biome.jsonc" ]; } && { HAS_BIOME=1; HAS_LINTER=1; }
[ -f "$TARGET/tsconfig.json" ] && HAS_TS=1
{ [ -f "$TARGET/bunfig.toml" ] || [ -f "$TARGET/bun.lockb" ]; } && HAS_BUN=1
[ -d "$TARGET/.claude" ] && HAS_CLAUDE=1

if [ "$HAS_PKG" = "1" ]; then
  PKG="$(cat "$TARGET/package.json" 2>/dev/null || printf '')"
  printf '%s' "$PKG" | grep -q '"better-auth"' && HAS_AUTH=1
  printf '%s' "$PKG" | grep -Eq '"@sanity/|"sanity"[[:space:]]*:' && HAS_SANITY=1
  printf '%s' "$PKG" | grep -Eq '"next"[[:space:]]*:' && HAS_NEXT=1
  printf '%s' "$PKG" | grep -Eq '"typescript"[[:space:]]*:' && HAS_TS=1
  printf '%s' "$PKG" | grep -Eq '"react"[[:space:]]*:' && HAS_REACT=1
  printf '%s' "$PKG" | grep -Eq '"hono"[[:space:]]*:' && HAS_HONO=1
  printf '%s' "$PKG" | grep -Eq 'packageManager.*bun@' && HAS_BUN=1
  printf '%s' "$PKG" | grep -Eq '"tailwindcss"[[:space:]]*:' && HAS_TAILWIND=1
  { printf '%s' "$PKG" | grep -Eq '"eslint"[[:space:]]*:|"prettier"[[:space:]]*:'; } && HAS_LINTER=1
  printf '%s' "$PKG" | grep -Eiq 'hotel|resort|booking|hospitality|property|listing|realty|real[-_ ]?estate' && HAS_HOSPITALITY=1
fi
{ [ -f "$TARGET/auth.ts" ] || [ -d "$TARGET/app/api/auth" ] || [ -d "$TARGET/src/app/api/auth" ]; } && HAS_AUTH=1
{ [ -f "$TARGET/Dockerfile" ] || ls "$TARGET"/docker-compose.* >/dev/null 2>&1 \
  || [ -f "$TARGET/Caddyfile" ] || [ -f "$TARGET/nginx.conf" ]; } && HAS_DEPLOY=1
has_any '@theme*' >/dev/null 2>&1 && HAS_TAILWIND=1
{ [ -f "$TARGET/.eslintrc.json" ] || [ -f "$TARGET/.eslintrc.js" ] || [ -f "$TARGET/.prettierrc" ] \
  || [ -f "$TARGET/ruff.toml" ] || [ -f "$TARGET/.rustfmt.toml" ]; } && HAS_LINTER=1

# -- cross-language signals --
{ has_any 'jest.config.*' || has_any 'vitest.config.*' || [ -f "$TARGET/pytest.ini" ] \
  || [ -f "$TARGET/conftest.py" ] || has_any 'playwright.config.*' || has_dir '__tests__' \
  || has_dir 'spec' || has_dir 'test'; } && HAS_TESTS=1
{ has_any '*.tsx' || has_any '*.jsx' || has_any '*.vue' || has_any '*.svelte' \
  || has_dir 'components' || has_dir 'pages' || has_dir 'views'; } && HAS_FRONTEND=1
{ has_dir 'controllers' || has_dir 'routes' || has_dir 'handlers' || has_dir 'services' \
  || has_dir 'api' || has_dir 'middleware' || has_dir 'auth'; } && HAS_BACKEND=1
{ has_dir 'migrations' || has_dir 'prisma' || has_dir 'drizzle' || has_dir 'alembic' \
  || [ -d "$TARGET/db/migrate" ] || has_dir 'liquibase' || has_dir 'flyway'; } && HAS_DB=1
[ -d "$TARGET/docs" ] && HAS_DOCS=1
if command -v gh >/dev/null 2>&1; then
  git -C "$TARGET" remote get-url origin 2>/dev/null | grep -q 'github.com' && HAS_GH_REMOTE=1
fi

# Primary source dir, for rule `paths:` rewriting in Step 4. Only set when the
# project clearly doesn't use `src/` — ponytail: single-dir rewrite only, no
# monorepo per-package prefixing; widen this if a multi-package project needs it.
PRIMARY_SRC_DIR=""
if [ ! -d "$TARGET/src" ]; then
  for d in app lib cmd internal; do
    [ -d "$TARGET/$d" ] && PRIMARY_SRC_DIR="$d" && break
  done
fi

detectedStack=()
[ "$HAS_NEXT" = "1" ]     && detectedStack+=("next.js")
[ "$HAS_TURBO" = "1" ]    && detectedStack+=("turborepo")
[ "$HAS_MONOREPO" = "1" ] && [ "$HAS_TURBO" != "1" ] && detectedStack+=("monorepo")
[ "$HAS_DRIZZLE" = "1" ]  && detectedStack+=("drizzle")
[ "$HAS_AUTH" = "1" ]     && detectedStack+=("betterauth")
[ "$HAS_SANITY" = "1" ]   && detectedStack+=("sanity")
[ "$HAS_BIOME" = "1" ]    && detectedStack+=("biome")
[ "$HAS_TS" = "1" ]       && detectedStack+=("typescript")
[ "$HAS_REACT" = "1" ]    && detectedStack+=("react")
[ "$HAS_HONO" = "1" ]     && detectedStack+=("hono")
[ "$HAS_BUN" = "1" ]      && detectedStack+=("bun")
[ "$HAS_TAILWIND" = "1" ] && detectedStack+=("tailwind")
[ "$HAS_GO" = "1" ]       && detectedStack+=("go")
[ "$HAS_RUST" = "1" ]     && detectedStack+=("rust")
[ "$HAS_PY" = "1" ]       && detectedStack+=("python")
[ "$HAS_RUBY" = "1" ]     && detectedStack+=("ruby")
[ "$HAS_PHP" = "1" ]      && detectedStack+=("php")
[ "$HAS_JAVA" = "1" ]     && detectedStack+=("java")

# ---- labeled stack summary (mirrors skill Step 1.5) ----
row() { # row "Label" "value" ; prints only when value non-empty, else dim "—"
  if [ -n "$2" ]; then printf "  %-11s %s\n" "$1" "$2"
  else printf "  %-11s %s—%s\n" "$1" "$DIM" "$RESET"; fi
}
fe=""; [ "$HAS_NEXT" = "1" ] && fe="Next.js"; [ "$HAS_REACT" = "1" ] && fe="${fe:+$fe + }React"
[ "$HAS_TAILWIND" = "1" ] && fe="${fe:+$fe + }Tailwind"; { [ -z "$fe" ] && [ "$HAS_FRONTEND" = "1" ]; } && fe="(frontend dirs)"
be=""; [ "$HAS_HONO" = "1" ] && be="Hono"; [ "$HAS_BUN" = "1" ] && be="${be:+$be + }Bun"
{ [ -z "$be" ] && [ "$HAS_BACKEND" = "1" ]; } && be="(backend dirs)"
db=""; [ "$HAS_DRIZZLE" = "1" ] && db="Drizzle"; { [ -z "$db" ] && [ "$HAS_DB" = "1" ]; } && db="(migrations/ORM)"
au=""; [ "$HAS_AUTH" = "1" ] && au="BetterAuth/auth"
ts=""; [ "$HAS_TESTS" = "1" ] && ts="present"
fmt=""; [ "$HAS_BIOME" = "1" ] && fmt="Biome"; { [ -z "$fmt" ] && [ "$HAS_LINTER" = "1" ]; } && fmt="ESLint/Prettier"
tc=""; [ "$HAS_TS" = "1" ] && tc="tsc"
pm=""; [ "$HAS_BUN" = "1" ] && pm="bun"; [ "$HAS_MONOREPO" = "1" ] && pm="${pm:+$pm }(monorepo)"
[ "$HAS_PKG" = "1" ] && [ -z "$pm" ] && pm="npm/node"
[ "$HAS_GO" = "1" ] && pm="go modules"; [ "$HAS_PY" = "1" ] && pm="${pm:-pip/uv}"
[ "$HAS_RUST" = "1" ] && pm="cargo"
gb="$(git -C "$TARGET" symbolic-ref --short HEAD 2>/dev/null || printf '')"
gh_s=""; command -v gh >/dev/null 2>&1 && gh_s="gh ✓"; [ "$HAS_GH_REMOTE" = "1" ] && gh_s="${gh_s:+$gh_s, }github remote"
git_s="${gb:+$gb}${gh_s:+${gb:+, }$gh_s}"
ci=""; [ "$HAS_CI" = "1" ] && ci="detected"

head "Detected stack"
row "Frontend:" "$fe"; row "Backend:" "$be"; row "Database:" "$db"; row "Auth:" "$au"
row "Testing:" "$ts"; row "Formatter:" "$fmt"; row "Typecheck:" "$tc"; row "Pkg mgr:" "$pm"
row "Git:" "$git_s"; row "CI:" "$ci"
[ "$HAS_CLAUDE" = "1" ] && say "  ${YELLOW}Existing .claude/ found — gap-analysis mode (missing items offered, stale ones flagged for removal).${RESET}"

# Empty project → minimal baseline, no further questions.
if [ ${#detectedStack[@]} -eq 0 ] && [ "$HAS_PKG" != "1" ] && ! has_any '*.go' && ! has_any '*.py' && ! has_any '*.rb'; then
  say "  ${YELLOW}No source files or manifests found.${RESET} Installing minimal baseline only (CLAUDE.md + safety hooks)."
  sel_agents=(); sel_rules=(); sel_hooks=(block-dangerous-commands scan-secrets protect-files warn-large-files)
  sel_skills=(); sel_plugins=(); WANT_CLAUDEMD=1
  EXIST_AGENTS=(); EXIST_RULES=(); EXIST_HOOKS=()
  REMOVE_AGENTS=(); REMOVE_RULES=(); REMOVE_HOOKS=()
  MINIMAL_BASELINE=1; TIER="minimal"
else
  MINIMAL_BASELINE=0
  # ---- Step 1.5 — confirm stack ----
  TIER=""
  if [ "$INTERACTIVE" = "1" ]; then
    printf "\nLooks right? [Y]es / [e]dit (correct via per-item toggles): "
    ask_line
    case "$REPLY_LINE" in e|E|edit|EDIT|n|N|no|NO) TIER="letmecheck"; say "  ${DIM}OK — use the per-item toggles below to correct.${RESET}" ;; esac
  fi
  # ---- Step 1.6 — pick install tier (skip if edit forced letmecheck) ----
  if [ -z "$TIER" ]; then
    head "Install tier"
    say "  1) Minimal   — CLAUDE.md + 4 safety hooks only"
    say "  2) Standard  — recommended picks from the scan ${DIM}(default)${RESET}"
    say "  3) Full      — everything in every category + all 3 plugins"
    say "  4) Let me check — choose each category by hand"
    printf "> "
    ask_line
    case "$REPLY_LINE" in
      1|minimal)            TIER="minimal" ;;
      ""|2|standard)        TIER="standard" ;;
      3|full)               TIER="full" ;;
      4|check|"let me check") TIER="letmecheck" ;;
      *)                    TIER="standard"; say "  ${DIM}Unrecognized — using Standard.${RESET}" ;;
    esac
  fi
  if [ "$TIER" = "minimal" ]; then
    sel_agents=(); sel_rules=(); sel_hooks=(block-dangerous-commands scan-secrets protect-files warn-large-files)
    sel_skills=(); sel_plugins=()
    WANT_CLAUDEMD=1
    [ -f "$TARGET/CLAUDE.md" ] && WANT_CLAUDEMD=0  # crucial: don't overwrite existing without asking
    if [ -f "$TARGET/CLAUDE.md" ] && [ "$INTERACTIVE" = "1" ]; then
      printf "  CLAUDE.md exists. Overwrite with template? [y/N]: "; ask_line
      case "$REPLY_LINE" in y|Y|yes|YES) WANT_CLAUDEMD=1 ;; esac
    fi
    MINIMAL_BASELINE=1
  fi
fi

# Existing managed files on disk (for gap-analysis removal diffing).
EXIST_AGENTS=(); EXIST_RULES=(); EXIST_HOOKS=()
if [ "$HAS_CLAUDE" = "1" ]; then
  for f in "$TARGET"/.claude/agents/*.md; do [ -f "$f" ] && EXIST_AGENTS+=("$(basename "$f" .md)"); done
  for f in "$TARGET"/.claude/rules/*.md; do [ -f "$f" ] && EXIST_RULES+=("$(basename "$f" .md)"); done
  for f in "$TARGET"/.claude/hooks/*.sh; do [ -f "$f" ] && EXIST_HOOKS+=("$(basename "$f" .sh)"); done
fi

# ========================================================================
# Numbered multi-select helper
#   Inputs (globals): names[], descs[], defaults[] (0/1)
#   Output (global):  selected[]
# ========================================================================
prompt_category() {
  local title="$1"; local n=${#names[@]}; local i
  # One-shot tiers: select without prompting.
  if [ "${TIER:-}" = "standard" ]; then
    selected=(); for ((i=0; i<n; i++)); do [ "${defaults[$i]}" = "1" ] && selected+=("${names[$i]}"); done
    return
  fi
  if [ "${TIER:-}" = "full" ]; then
    selected=("${names[@]}")
    return
  fi
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

copy_managed() { # copy_managed <src> <dest> <label> ; returns 0 if a fresh copy happened, 1 if skipped
  local src="$1" dest="$2" label="$3"
  if [ ! -f "$src" ]; then skip "$label (source missing: $src)"; return 1; fi
  if [ -e "$dest" ]; then skip "$label (exists, kept)"; return 1; fi
  cp "$src" "$dest" && ok "$label" && return 0
  return 1
}

# ========================================================================
# Step 2 — Category selection (skipped entirely for the empty-project baseline)
# ========================================================================
select_all() {
  # --- Agents ---
  names=(code-reviewer security-reviewer performance-reviewer sanity-reviewer doc-reviewer frontend-designer pr-test-analyzer silent-failure-hunter)
  descs=("TS/Next/Hono correctness" "auth, API, env, injection" "re-renders, N+1, bundle" "Sanity schema & GROQ" "docs, README, CLAUDE.md" "tokens-first UI design" "test quality, not existence" "swallowed errors, fake success")
  defaults=(1 0 0 0 1 0 0 1)
  { [ "$HAS_AUTH" = "1" ] || [ "$HAS_BACKEND" = "1" ]; } && defaults[1]=1
  { [ "$HAS_NEXT" = "1" ] || [ "$HAS_DRIZZLE" = "1" ]; } && defaults[2]=1
  [ "$HAS_SANITY" = "1" ] && defaults[3]=1
  [ "$HAS_FRONTEND" = "1" ] && defaults[5]=1
  [ "$HAS_TESTS" = "1" ] && defaults[6]=1
  prompt_category "Agents"
  sel_agents=(); [ ${#selected[@]} -gt 0 ] && sel_agents=("${selected[@]}")

  # --- Rules ---
  names=(typescript git-workflow nextjs monorepo react hono bun golang rust tailwind code-quality database error-handling frontend security testing)
  descs=("no any, strict tsconfig" "commits, branches, no force-push" "App Router, server/client" "Turbo/pnpm/nx boundaries" "composition, stable keys" "route structure, onError" "native APIs, bun:test" "error wrapping, goroutines" "unsafe discipline, ownership" "v4 @theme, cn() merging" "anti-defaults, naming" "migration discipline" "typed errors, no swallow" "tokens, a11y, perf" "input validation, no raw SQL" "behavior over implementation")
  defaults=(0 1 0 0 0 0 0 0 0 0 1 0 0 0 0 0)
  [ "$HAS_TS" = "1" ] && defaults[0]=1
  [ "$HAS_NEXT" = "1" ] && defaults[2]=1
  [ "$HAS_MONOREPO" = "1" ] && defaults[3]=1
  [ "$HAS_REACT" = "1" ] && defaults[4]=1
  [ "$HAS_HONO" = "1" ] && defaults[5]=1
  [ "$HAS_BUN" = "1" ] && defaults[6]=1
  [ "$HAS_GO" = "1" ] && defaults[7]=1
  [ "$HAS_RUST" = "1" ] && defaults[8]=1
  [ "$HAS_TAILWIND" = "1" ] && defaults[9]=1
  [ "$HAS_DB" = "1" ] && defaults[11]=1
  [ "$HAS_BACKEND" = "1" ] && defaults[12]=1
  [ "$HAS_FRONTEND" = "1" ] && defaults[13]=1
  { [ "$HAS_BACKEND" = "1" ] || [ "$HAS_AUTH" = "1" ]; } && defaults[14]=1
  [ "$HAS_TESTS" = "1" ] && defaults[15]=1
  prompt_category "Rules"
  sel_rules=(); [ ${#selected[@]} -gt 0 ] && sel_rules=("${selected[@]}")

  # --- Hooks ---
  names=(block-dangerous-commands scan-secrets protect-files warn-large-files format-on-save auto-test typecheck-on-stop lint-on-stop notify session-start)
  descs=("block rm -rf /, DROP TABLE, --force" "block hardcoded secrets" "block edits to .env/keys/lockfiles" "block writes to build/binary dirs" "biome check --write on .ts/.tsx" "run matching test after every edit (needs fast suite)" "typecheck once per turn on Stop" "lint once per turn on Stop" "OS notification on attention-needed" "branch+dirty context, drift nudge")
  defaults=(1 1 1 1 0 0 0 0 0 1)
  [ "$HAS_BIOME" = "1" ] && defaults[4]=1
  [ "$HAS_TS" = "1" ] && defaults[6]=1
  [ "$HAS_LINTER" = "1" ] && defaults[7]=1
  prompt_category "Hooks"
  sel_hooks=(); [ ${#selected[@]} -gt 0 ] && sel_hooks=("${selected[@]}")

  # --- Third-party plugins (behavior plugins; all pre-marked) ---
  names=(caveman ponytail graphify)
  descs=("ultra-compressed replies (bunx)" "lazy/YAGNI mode (claude plugin)" "codebase knowledge graph (uv/pipx/pip)")
  defaults=(1 1 1)
  prompt_category "Third-party plugins"
  sel_plugins=(); [ ${#selected[@]} -gt 0 ] && sel_plugins=("${selected[@]}")

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
  # Keep skills catalog arrays around for the install step's name->repo lookup.
  skills_names=("${names[@]}"); skills_repos=("${repos[@]}"); skills_skillnames=("${skillnames[@]}")

  # --- CLAUDE.md ---
  head "CLAUDE.md template"
  WANT_CLAUDEMD=0
  if [ -f "$TARGET/CLAUDE.md" ]; then
    # Crucial action — always confirm an overwrite, even in one-shot tiers.
    printf "  CLAUDE.md already exists. Overwrite with the template? [y/N]: "
    ask_line
    case "$REPLY_LINE" in y|Y|yes|YES) WANT_CLAUDEMD=1 ;; *) WANT_CLAUDEMD=0 ;; esac
  elif [ "$TIER" = "standard" ] || [ "$TIER" = "full" ]; then
    WANT_CLAUDEMD=1; say "  Copy CLAUDE.md template ${DIM}(auto: $TIER tier)${RESET}"
  else
    printf "  Copy the CLAUDE.md template to the project root? [Y/n]: "
    ask_line
    case "$REPLY_LINE" in ""|y|Y|yes|YES) WANT_CLAUDEMD=1 ;; *) WANT_CLAUDEMD=0 ;; esac
  fi
}

print_plan() {
  REMOVE_AGENTS=()
  for x in "${EXIST_AGENTS[@]:-}"; do [ -n "$x" ] || continue; contains "$x" "${sel_agents[@]:-}" || REMOVE_AGENTS+=("$x"); done
  REMOVE_RULES=()
  for x in "${EXIST_RULES[@]:-}"; do [ -n "$x" ] || continue; contains "$x" "${sel_rules[@]:-}" || REMOVE_RULES+=("$x"); done
  REMOVE_HOOKS=()
  for x in "${EXIST_HOOKS[@]:-}"; do [ -n "$x" ] || continue; contains "$x" "${sel_hooks[@]:-}" || REMOVE_HOOKS+=("$x"); done

  head "Plan"
  say "  Install agents:  ${sel_agents[*]:-(none)}"
  say "  Install rules:   ${sel_rules[*]:-(none)}"
  say "  Install hooks:   ${sel_hooks[*]:-(none)}"
  say "  Install plugins: ${sel_plugins[*]:-(none)}"
  say "  Install skills:  ${sel_skills[*]:-(none)}"
  say "  CLAUDE.md:       $([ "$WANT_CLAUDEMD" = "1" ] && echo "install/overwrite" || echo "skip")"
  if [ ${#REMOVE_AGENTS[@]} -gt 0 ] || [ ${#REMOVE_RULES[@]} -gt 0 ] || [ ${#REMOVE_HOOKS[@]} -gt 0 ]; then
    say "  ${YELLOW}Remove (on disk, not in this selection):${RESET}"
    [ ${#REMOVE_AGENTS[@]} -gt 0 ] && say "    agents: ${REMOVE_AGENTS[*]}"
    [ ${#REMOVE_RULES[@]} -gt 0 ]  && say "    rules:  ${REMOVE_RULES[*]}"
    [ ${#REMOVE_HOOKS[@]} -gt 0 ]  && say "    hooks:  ${REMOVE_HOOKS[*]}"
  fi
}

if [ "$MINIMAL_BASELINE" = "1" ]; then
  REMOVE_AGENTS=(); REMOVE_RULES=(); REMOVE_HOOKS=()
  sel_plugins=()
  print_plan
elif [ "$TIER" = "standard" ] || [ "$TIER" = "full" ]; then
  # One-shot tiers: build selection silently, render the plan, auto-proceed.
  select_all
  print_plan
  say "  ${DIM}($TIER tier — auto-approved)${RESET}"
else
  # Let me check: interactive, with approve/adjust loop.
  while true; do
    select_all
    print_plan
    printf "Approve plan? [Y]es / [a]djust / [c]ancel: "
    ask_line
    case "$REPLY_LINE" in
      ""|y|Y|yes|YES) break ;;
      a|A|adjust|ADJUST) continue ;;
      c|C|cancel|CANCEL|n|N|no|NO) say "Cancelled."; exit 0 ;;
      *) say "  Unrecognized, treating as approve."; break ;;
    esac
  done
fi

# ========================================================================
# Step 4 — Install
# ========================================================================
head "Installing"

if [ ${#sel_agents[@]} -gt 0 ]; then
  mkdir -p "$TARGET/.claude/agents"
  for a in "${sel_agents[@]}"; do
    copy_managed "$SCRIPT_DIR/agents/$a.md" "$TARGET/.claude/agents/$a.md" "agent: $a"
  done
fi

if [ ${#sel_rules[@]} -gt 0 ]; then
  mkdir -p "$TARGET/.claude/rules"
  for r in "${sel_rules[@]}"; do
    if copy_managed "$SCRIPT_DIR/rules/$r.md" "$TARGET/.claude/rules/$r.md" "rule: $r"; then
      if [ -n "$PRIMARY_SRC_DIR" ] && grep -q '^paths:' "$TARGET/.claude/rules/$r.md" 2>/dev/null; then
        RULE_FILE="$TARGET/.claude/rules/$r.md"
        BEFORE_SUM="$(cksum < "$RULE_FILE")"
        sed -i.bak "/^paths:/,/^---/ s#\"src/#\"$PRIMARY_SRC_DIR/#g" "$RULE_FILE"
        rm -f "$RULE_FILE.bak"
        AFTER_SUM="$(cksum < "$RULE_FILE")"
        [ "$BEFORE_SUM" != "$AFTER_SUM" ] && skip "rule: $r — paths: rewritten src/ -> $PRIMARY_SRC_DIR/"
      fi
    fi
  done
fi

if [ ${#sel_hooks[@]} -gt 0 ]; then
  mkdir -p "$TARGET/.claude/hooks"
  for h in "${sel_hooks[@]}"; do
    copy_managed "$SCRIPT_DIR/hooks/$h.sh" "$TARGET/.claude/hooks/$h.sh" "hook: $h"
    [ -f "$TARGET/.claude/hooks/$h.sh" ] && chmod +x "$TARGET/.claude/hooks/$h.sh"
  done
fi

# Removals (gap-analysis mode): only files the approved plan didn't re-select.
for a in "${REMOVE_AGENTS[@]:-}"; do [ -n "$a" ] && rm -f "$TARGET/.claude/agents/$a.md" && ok "removed agent: $a"; done
for r in "${REMOVE_RULES[@]:-}";  do [ -n "$r" ] && rm -f "$TARGET/.claude/rules/$r.md"   && ok "removed rule: $r";  done
for h in "${REMOVE_HOOKS[@]:-}";  do [ -n "$h" ] && rm -f "$TARGET/.claude/hooks/$h.sh"   && ok "removed hook: $h";  done

# settings.json: hook registration + scoped permissions.allow. Runs whenever
# there's anything to register, even with zero hooks selected (permissions
# still need writing) — only the entries for hooks actually selected are added.
mkdir -p "$TARGET/.claude"
PERMS=()
if [ "$HAS_PKG" = "1" ]; then
  for script in lint test typecheck check-types build format; do
    printf '%s' "${PKG:-}" | grep -q "\"$script\":" && PERMS+=("Bash(npm run $script *)")
  done
fi
PERMS+=("Bash(git status)" "Bash(git diff *)" "Bash(git log *)" "Bash(git branch *)" "Bash(git stash *)" \
        "Bash(git add *)" "Bash(git commit *)" "Bash(git fetch *)" "Bash(git checkout *)" "Bash(git switch *)")
[ "$HAS_GH_REMOTE" = "1" ] && PERMS+=("Bash(gh pr *)" "Bash(gh issue *)" "Bash(gh run *)")

JS=""
command -v node >/dev/null 2>&1 && JS="node"
[ -z "$JS" ] && command -v bun >/dev/null 2>&1 && JS="bun"
SETTINGS="$TARGET/.claude/settings.json"
if [ -n "$JS" ]; then
  MERGE="$(mktemp 2>/dev/null || printf '%s' "${TMPDIR:-/tmp}/ccs-merge.$$.js")"
  cat > "$MERGE" <<'JSEOF'
const fs = require('fs');
const [settingsPath, permsJson, ...hooks] = process.argv.slice(2);
const reg = {
  'block-dangerous-commands': [{ event: 'PreToolUse',  matcher: 'Bash' }],
  'scan-secrets':             [{ event: 'PreToolUse',  matcher: 'Write|Edit' }],
  'protect-files':            [{ event: 'PreToolUse',  matcher: 'Write|Edit' }],
  'warn-large-files':         [{ event: 'PreToolUse',  matcher: 'Write|Edit' }],
  'format-on-save':           [{ event: 'PostToolUse', matcher: 'Write|Edit' }],
  'auto-test':                [{ event: 'PostToolUse', matcher: 'Write|Edit' }],
  'typecheck-on-stop':        [{ event: 'PostToolUse', matcher: 'Write|Edit' }, { event: 'Stop', matcher: '' }],
  'lint-on-stop':             [{ event: 'PostToolUse', matcher: 'Write|Edit' }, { event: 'Stop', matcher: '' }],
  'notify':                   [{ event: 'Notification', matcher: '' }],
  'session-start':            [{ event: 'SessionStart', matcher: 'startup|resume|clear' }],
};
let s = {};
try { s = JSON.parse(fs.readFileSync(settingsPath, 'utf8') || '{}'); } catch (e) { s = {}; }
s.hooks = s.hooks || {};
for (const h of hooks) {
  const regs = reg[h];
  if (!regs) continue;
  const cmd = 'bash "$CLAUDE_PROJECT_DIR/.claude/hooks/' + h + '.sh"';
  for (const r of regs) {
    s.hooks[r.event] = s.hooks[r.event] || [];
    let group = s.hooks[r.event].find(g => g && g.matcher === r.matcher);
    if (!group) { group = { matcher: r.matcher, hooks: [] }; s.hooks[r.event].push(group); }
    group.hooks = group.hooks || [];
    if (!group.hooks.some(x => x && x.command === cmd)) {
      group.hooks.push({ type: 'command', command: cmd });
    }
  }
}
let perms = [];
try { perms = JSON.parse(permsJson || '[]'); } catch (e) { perms = []; }
if (perms.length) {
  s.permissions = s.permissions || {};
  s.permissions.allow = s.permissions.allow || [];
  for (const p of perms) {
    if (!s.permissions.allow.includes(p)) s.permissions.allow.push(p);
  }
}
fs.writeFileSync(settingsPath, JSON.stringify(s, null, 2) + '\n');
JSEOF
  PERMS_JSON="$(json_array "${PERMS[@]}")"
  if "$JS" "$MERGE" "$SETTINGS" "$PERMS_JSON" ${sel_hooks[@]+"${sel_hooks[@]}"}; then
    ok "updated .claude/settings.json (hooks + scoped permissions)"
  else
    skip "could not auto-update settings.json — edit manually"
  fi
  rm -f "$MERGE"
else
  skip "node/bun not found — hooks copied but settings.json not updated"
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
    for s_name in "${sel_skills[@]}"; do
      repo=""; skn="$s_name"; idx=0
      for nm in "${skills_names[@]}"; do
        if [ "$nm" = "$s_name" ]; then repo="${skills_repos[$idx]}"; skn="${skills_skillnames[$idx]}"; break; fi
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

# CLAUDE.md (+ budget check)
CLAUDEMD_VERDICT="n/a"
if [ "$WANT_CLAUDEMD" = "1" ]; then
  if [ -f "$SCRIPT_DIR/templates/CLAUDE.template.md" ]; then
    cp "$SCRIPT_DIR/templates/CLAUDE.template.md" "$TARGET/CLAUDE.md" && ok "CLAUDE.md"
    LINES=$(grep -cv '^[[:space:]]*$' "$TARGET/CLAUDE.md" 2>/dev/null || printf '0')
    if [ "$LINES" -gt 50 ] 2>/dev/null; then
      say "  ${YELLOW}FAIL${RESET}: CLAUDE.md has $LINES non-blank lines (cap 50) — trim before relying on it."
      CLAUDEMD_VERDICT="FAIL ($LINES lines)"
    elif [ "$LINES" -gt 25 ] 2>/dev/null; then
      say "  ${YELLOW}WARN${RESET}: CLAUDE.md has $LINES non-blank lines (target <25) — consider trimming."
      CLAUDEMD_VERDICT="WARN ($LINES lines)"
    else
      CLAUDEMD_VERDICT="PASS ($LINES lines)"
    fi
  else
    skip "CLAUDE.md template missing in plugin"
  fi
fi

# ========================================================================
# Third-party plugins (caveman / ponytail / graphify). All non-fatal.
# ========================================================================
append_claudemd() { # append_claudemd "<markdown block>" — creates CLAUDE.md if absent
  printf '\n%s\n' "$1" >> "$TARGET/CLAUDE.md"
}
if [ ${#sel_plugins[@]} -gt 0 ]; then
  head "Third-party plugins"
  PRUNNER=""
  command -v bunx >/dev/null 2>&1 && PRUNNER="bunx"
  [ -z "$PRUNNER" ] && command -v npx >/dev/null 2>&1 && PRUNNER="npx"

  for p in "${sel_plugins[@]}"; do
    case "$p" in
      caveman)
        if [ -z "$PRUNNER" ]; then skip "caveman: bunx/npx not found — skipped"; continue; fi
        if ( cd "$TARGET" && "$PRUNNER" skills add JuliusBrussee/caveman -a claude-code -y </dev/null ); then
          append_claudemd "# Communication style
Use caveman mode for all responses: drop articles, drop filler words, fragments OK.
Activate with \`/caveman\` at session start (or load via skill)."
          ok "plugin: caveman"
        else skip "caveman: install failed — continuing"; fi ;;
      ponytail)
        if command -v claude >/dev/null 2>&1; then
          if claude plugin marketplace add DietrichGebert/ponytail </dev/null 2>/dev/null \
             && claude plugin install ponytail@ponytail </dev/null 2>/dev/null; then
            ok "plugin: ponytail (user-scoped; restart Claude Code)"
          else skip "ponytail: claude plugin install failed — run manually:  claude plugin marketplace add DietrichGebert/ponytail && claude plugin install ponytail@ponytail"; fi
        else
          skip "ponytail: 'claude' CLI not found — run in a Claude Code session:  /plugin marketplace add DietrichGebert/ponytail  then  /plugin install ponytail@ponytail"
        fi
        append_claudemd "# Build discipline
Apply ponytail (YAGNI) discipline: stop at the first rung of the ladder that holds.
No speculative abstractions, no boilerplate for later. Activate with \`/ponytail\` or
load via the ponytail skill." ;;
      graphify)
        GPM=""
        if command -v uv >/dev/null 2>&1; then GPM="uv tool install graphifyy"
        elif command -v pipx >/dev/null 2>&1; then GPM="pipx install graphifyy"
        elif command -v pip >/dev/null 2>&1; then GPM="pip install graphifyy"
        fi
        if [ -z "$GPM" ]; then
          skip "graphify: no uv/pipx/pip on PATH — install one (e.g. curl -LsSf https://astral.sh/uv/install.sh | sh) then re-run; skipped"
          continue
        fi
        say "  graphify: installing via ${GPM%% *}…"
        if ( cd "$TARGET" && eval "$GPM" </dev/null ) && ( cd "$TARGET" && graphify install --project </dev/null ); then
          append_claudemd "# Codebase graph
Before searching raw files for architecture questions, read \`graphify-out/GRAPH_REPORT.md\`
for god nodes and community structure. Use it to locate high-impact files before grepping."
          ok "plugin: graphify — now run  /graphify .  in Claude Code to build the graph; commit graphify-out/"
        else skip "graphify: install failed — continuing"; fi
        case "$GPM" in pip\ *) say "  ${DIM}(pip: ensure graphify is on PATH — see uv/pipx if not)${RESET}";; esac ;;
    esac
  done
fi

# ========================================================================
# Step 5 — Drift fingerprint
# ========================================================================
if contains "session-start" "${sel_hooks[@]:-}" && [ -x "$TARGET/.claude/hooks/session-start.sh" ]; then
  CLAUDE_CODE_STARTER_FINGERPRINT=1 "$TARGET/.claude/hooks/session-start.sh" > "$TARGET/.claude/.claude-code-starter.json" \
    && ok "wrote drift fingerprint .claude/.claude-code-starter.json"
else
  skip "session-start hook not installed — no drift detection; re-run install.sh manually after stack changes"
fi

# ========================================================================
# Step 6 — Verify and report
# ========================================================================
head "Verify"
for h in "${sel_hooks[@]:-}"; do
  [ -n "$h" ] && [ ! -x "$TARGET/.claude/hooks/$h.sh" ] && say "  ${YELLOW}warn${RESET}: hook not executable: $h"
done

TOKEN_CHARS=0
[ -f "$TARGET/CLAUDE.md" ] && TOKEN_CHARS=$((TOKEN_CHARS + $(wc -c < "$TARGET/CLAUDE.md" | tr -d ' ')))
for r in "${sel_rules[@]:-}"; do
  f="$TARGET/.claude/rules/$r.md"
  [ -n "$r" ] && [ -f "$f" ] && ! grep -q '^paths:' "$f" && TOKEN_CHARS=$((TOKEN_CHARS + $(wc -c < "$f" | tr -d ' ')))
done
TOKEN_EST=$((TOKEN_CHARS / 4))

head "Done"
say "  Target:             $TARGET"
say "  Agents:              ${sel_agents[*]:-(none)}"
say "  Rules:               ${sel_rules[*]:-(none)}"
say "  Hooks:               ${sel_hooks[*]:-(none)}"
say "  Plugins:             ${sel_plugins[*]:-(none)}"
say "  Skills:              ${sel_skills[*]:-(none)}"
say "  CLAUDE.md:           $CLAUDEMD_VERDICT"
say "  Removed:             agents=${REMOVE_AGENTS[*]:-none} rules=${REMOVE_RULES[*]:-none} hooks=${REMOVE_HOOKS[*]:-none}"
say "  Always-loaded est.:  ~${TOKEN_EST} tokens (CLAUDE.md + path-less rules)"
[ "$TOKEN_EST" -gt 1000 ] 2>/dev/null && say "  ${YELLOW}Consider trimming — over the ~1000 token always-loaded budget.${RESET}"
say ""
say "${YELLOW}Restart Claude Code${RESET} so the new agents, rules, and hooks are picked up."
