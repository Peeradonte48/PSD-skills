#!/usr/bin/env bash
# Install PSD: symlink skills/agents/workflows + register checkpoint hooks.
#
# Two modes:
#   - Local: ./install.sh from a cloned repo. Symlinks point at the cloned dir.
#   - Remote: curl -fsSL .../install.sh | bash. Auto-clones to ~/.psd-skills
#     (or $PSD_HOME) and symlinks from there.
#
# Either way, idempotent — safe to re-run.
set -euo pipefail

PSD_HOME="${PSD_HOME:-$HOME/.psd-skills}"
PSD_REPO_URL="${PSD_REPO_URL:-https://github.com/Peeradonte48/PSD-skills.git}"
PSD_BRANCH="${PSD_BRANCH:-main}"

# --- 0. Detect remote vs local invocation -----------------------------------
# Remote when: piped from curl (BASH_SOURCE empty or $0 is bash/sh), OR the
# directory containing this script is not a git checkout we recognize.
SCRIPT_PATH="${BASH_SOURCE[0]:-}"
REMOTE_INSTALL=0
if [ -z "$SCRIPT_PATH" ]; then
  REMOTE_INSTALL=1
else
  case "$0" in
    bash|-bash|sh|-sh|/bin/bash|/bin/sh) REMOTE_INSTALL=1 ;;
  esac
  if [ "$REMOTE_INSTALL" = "0" ]; then
    SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
    # .git is a directory in regular clones, a file in worktrees — accept either.
    [ -e "$SCRIPT_DIR/.git" ] || REMOTE_INSTALL=1
    [ -d "$SCRIPT_DIR/skills" ] || REMOTE_INSTALL=1
  fi
fi

if [ "$REMOTE_INSTALL" = "1" ]; then
  command -v git >/dev/null 2>&1 || { echo "ERROR: git is required for remote install"; exit 1; }
  if [ -d "$PSD_HOME/.git" ]; then
    echo "Updating existing PSD checkout at $PSD_HOME..."
    git -C "$PSD_HOME" fetch --depth 1 origin "$PSD_BRANCH" 2>/dev/null || git -C "$PSD_HOME" fetch origin "$PSD_BRANCH"
    git -C "$PSD_HOME" reset --hard "origin/$PSD_BRANCH"
  else
    echo "Cloning PSD into $PSD_HOME..."
    git clone --depth 1 --branch "$PSD_BRANCH" "$PSD_REPO_URL" "$PSD_HOME"
  fi
  REPO="$PSD_HOME"
else
  REPO="$SCRIPT_DIR"
fi

HOOK_CMD="$REPO/hooks/psd-checkpoint.sh"
SETTINGS="$HOME/.claude/settings.json"

command -v jq >/dev/null 2>&1 || { echo "ERROR: jq is required (brew install jq / apt install jq)"; exit 1; }

# --- 0b. Plugin double-install warning --------------------------------------
PLUGIN_HINT="$HOME/.claude/plugins/marketplaces/PSD-skills"
if [ -e "$PLUGIN_HINT" ] || [ -e "$HOME/.claude/plugins/repos/Peeradonte48/PSD-skills" ]; then
  echo "WARNING: PSD plugin install detected. Running both the curl install AND"
  echo "         the /plugin install registers the same skills twice and may cause"
  echo "         duplicate hook fires. Pick one path. Continuing curl install..."
fi

mkdir -p "$HOME/.claude/skills" "$HOME/.claude/agents" "$HOME/.claude/workflows"

# --- 1. Skill directories ----------------------------------------------------
for dir in "$REPO"/skills/psd-*; do
  [ -d "$dir" ] || continue
  ln -sfn "$dir" "$HOME/.claude/skills/$(basename "$dir")"
done

# --- 2. Agent files ----------------------------------------------------------
for f in "$REPO"/agents/psd-*.md; do
  [ -f "$f" ] || continue
  ln -sfn "$f" "$HOME/.claude/agents/$(basename "$f")"
done

# --- 3. Workflow files -------------------------------------------------------
for f in "$REPO"/workflows/*.md; do
  [ -f "$f" ] || continue
  ln -sfn "$f" "$HOME/.claude/workflows/$(basename "$f")"
done

# --- 4. Hook script executable ----------------------------------------------
chmod +x "$HOOK_CMD" 2>/dev/null || true
chmod +x "$REPO/hooks/psd-bridge.sh" 2>/dev/null || true
chmod +x "$REPO/bin/psd-update" 2>/dev/null || true

# --- 5. Register hooks in ~/.claude/settings.json (idempotent; jq merge) -----
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

# --- 6. Install psd-update on PATH ------------------------------------------
UPDATE_SRC="$REPO/bin/psd-update"
UPDATE_DST=""
if [ -f "$UPDATE_SRC" ]; then
  if [ -w "/usr/local/bin" ]; then
    UPDATE_DST="/usr/local/bin/psd-update"
  else
    mkdir -p "$HOME/.local/bin"
    UPDATE_DST="$HOME/.local/bin/psd-update"
  fi
  ln -sfn "$UPDATE_SRC" "$UPDATE_DST"
fi

echo "PSD installed."
echo "  Source:    $REPO"
echo "  Skills:    $(ls -1 "$HOME"/.claude/skills/psd-* 2>/dev/null | wc -l | tr -d ' ') symlinks"
echo "  Agents:    $(ls -1 "$HOME"/.claude/agents/psd-*.md 2>/dev/null | wc -l | tr -d ' ') symlinks"
echo "  Workflows: $(ls -1 "$HOME"/.claude/workflows/*.md 2>/dev/null | wc -l | tr -d ' ') symlinks"
echo "  Hooks:     PostToolUse(Write|Edit|Bash|NotebookEdit) + Stop -> $HOOK_CMD"
if [ -n "$UPDATE_DST" ]; then
  echo "  Update:    psd-update -> $UPDATE_DST"
  case ":$PATH:" in
    *":$(dirname "$UPDATE_DST"):"*) ;;
    *) echo "             NOTE: $(dirname "$UPDATE_DST") is not on \$PATH. Add it or run $UPDATE_DST directly." ;;
  esac
fi
echo "Restart Claude Code to pick up the new skills and hooks."
