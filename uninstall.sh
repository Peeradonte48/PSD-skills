#!/usr/bin/env bash
# Uninstall PSD: remove symlinks and deregister hooks.
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
HOOK_CMD="$REPO/hooks/psd-checkpoint.sh"
SETTINGS="$HOME/.claude/settings.json"

command -v jq >/dev/null 2>&1 || { echo "ERROR: jq is required"; exit 1; }

# 1. Remove symlinks (only if they're symlinks pointing into this repo)
remove_link() {
  local target="$1"
  if [ -L "$target" ] && [[ "$(readlink "$target")" == "$REPO"/* ]]; then
    rm "$target"
  fi
}

for dir in "$REPO"/skills/psd-*; do
  [ -d "$dir" ] || continue
  remove_link "$HOME/.claude/skills/$(basename "$dir")"
done
for f in "$REPO"/agents/psd-*.md; do
  [ -f "$f" ] || continue
  remove_link "$HOME/.claude/agents/$(basename "$f")"
done
for f in "$REPO"/workflows/*.md; do
  [ -f "$f" ] || continue
  remove_link "$HOME/.claude/workflows/$(basename "$f")"
done

# 2. Deregister hooks (surgical — preserve other hook entries)
if [ -f "$SETTINGS" ]; then
  jq --arg cmd "$HOOK_CMD" '
    if (.hooks // {}).PostToolUse then
      .hooks.PostToolUse |= map(select(.matcher != "Write|Edit|Bash|NotebookEdit" or all(.hooks[]?; .command != $cmd)))
    else . end |
    if (.hooks // {}).Stop then
      .hooks.Stop |= map(select(all(.hooks[]?; .command != $cmd)))
    else . end
  ' "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"
fi

echo "PSD uninstalled. Restart Claude Code."
