#!/usr/bin/env bash
#
# materialize-agy-skills.sh — replace plugins/*/skills/<name>/ symlinks with
# real file copies of skills/<name>/.
#
# Why: plugins/<name>/ dirs normally symlink into the top-level skills/, agents/,
# rules/ dirs (single source of truth — see CLAUDE.md). Claude Code dereferences
# those symlinks fine at install. `agy` (Antigravity CLI) does not: its plugin
# scanner follows symlinked *files* (agents/<name>.md) but silently skips
# symlinked *directories* (skills/<name>/), so every skill-based plugin is
# invisible to `agy plugin install` unless skills/ contains real files.
#
# Run after editing anything under skills/<name>/, then commit both the source
# and the regenerated plugins/*/skills/<name>/ copies. `--check` verifies
# without writing (no symlinks left, no drift from source) and exits 1 if stale.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
CHECK=0
[ "${1:-}" = "--check" ] && CHECK=1
STALE=0

for src in "$SCRIPT_DIR"/skills/*/; do
  name="$(basename "$src")"
  for plugin_dir in "$SCRIPT_DIR"/plugins/*/; do
    dest="$plugin_dir/skills/$name"
    [ -e "$dest" ] || [ -L "$dest" ] || continue
    plugin="$(basename "$plugin_dir")"
    if [ "$CHECK" = "1" ]; then
      if [ -L "$dest" ]; then
        echo "stale: plugins/$plugin/skills/$name is a symlink (agy won't see it) — run scripts/materialize-agy-skills.sh"
        STALE=1
      elif ! diff -rq "$src" "$dest" >/dev/null 2>&1; then
        echo "drift: plugins/$plugin/skills/$name differs from skills/$name — run scripts/materialize-agy-skills.sh"
        STALE=1
      fi
    else
      rm -rf "$dest"
      mkdir -p "$dest"
      cp -R "${src}." "$dest/"
      echo "materialized: plugins/$plugin/skills/$name"
    fi
  done
done

if [ "$CHECK" = "1" ]; then
  [ "$STALE" = "1" ] && exit 1
  echo "ok: all plugins/*/skills/* copies are real files and match source"
fi
