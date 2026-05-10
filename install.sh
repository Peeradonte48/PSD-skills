#!/usr/bin/env bash
# Install PSD: symlink skills/agents/workflows + register checkpoint hooks.
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
HOOK_CMD="$REPO/hooks/psd-checkpoint.sh"
SETTINGS="$HOME/.claude/settings.json"

command -v jq >/dev/null 2>&1 || { echo "ERROR: jq is required (brew install jq)"; exit 1; }

mkdir -p "$HOME/.claude/skills" "$HOME/.claude/agents" "$HOME/.claude/workflows"

# 1. Skill directories
for dir in "$REPO"/skills/psd-*; do
  [ -d "$dir" ] || continue
  ln -sfn "$dir" "$HOME/.claude/skills/$(basename "$dir")"
done

# 2. Agent files
for f in "$REPO"/agents/psd-*.md; do
  [ -f "$f" ] || continue
  ln -sfn "$f" "$HOME/.claude/agents/$(basename "$f")"
done

# 3. Workflow files
for f in "$REPO"/workflows/*.md; do
  [ -f "$f" ] || continue
  ln -sfn "$f" "$HOME/.claude/workflows/$(basename "$f")"
done

# 4. Hook script executable
chmod +x "$HOOK_CMD"

# 5. Register hooks in ~/.claude/settings.json (idempotent; jq merge)
[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"

# PostToolUse on mutating tools (primary — survives mid-turn failures)
jq --arg cmd "$HOOK_CMD" '
  .hooks //= {} |
  .hooks.PostToolUse //= [] |
  if any(.hooks.PostToolUse[]?; .matcher == "Write|Edit|Bash|NotebookEdit" and any(.hooks[]?; .command == $cmd))
  then .
  else .hooks.PostToolUse += [{"matcher":"Write|Edit|Bash|NotebookEdit","hooks":[{"type":"command","command":$cmd}]}]
  end
' "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"

# Stop (secondary — clean turn boundary marker)
jq --arg cmd "$HOOK_CMD" '
  .hooks //= {} |
  .hooks.Stop //= [] |
  if any(.hooks.Stop[]?; any(.hooks[]?; .command == $cmd)) then .
  else .hooks.Stop += [{"hooks":[{"type":"command","command":$cmd}]}]
  end
' "$SETTINGS" > "$SETTINGS.tmp" && mv "$SETTINGS.tmp" "$SETTINGS"

echo "PSD installed."
echo "  Skills:    $(ls -1 "$HOME"/.claude/skills/psd-* 2>/dev/null | wc -l | tr -d ' ') symlinks"
echo "  Agents:    $(ls -1 "$HOME"/.claude/agents/psd-*.md 2>/dev/null | wc -l | tr -d ' ') symlinks"
echo "  Workflows: $(ls -1 "$HOME"/.claude/workflows/*.md 2>/dev/null | wc -l | tr -d ' ') symlinks"
echo "  Hooks:     PostToolUse(Write|Edit|Bash|NotebookEdit) + Stop -> $HOOK_CMD"
echo "Restart Claude Code to pick up the new skills and hooks."
