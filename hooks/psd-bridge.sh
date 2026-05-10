#!/usr/bin/env bash
# PSD plugin SessionStart bridge.
# Skills/agents reference workflow files via the absolute path
# `@$HOME/.claude/workflows/<name>.md`. In curl-install mode this path is
# satisfied by symlinks created by install.sh. In plugin mode the workflow
# files live at ${CLAUDE_PLUGIN_ROOT}/workflows/, so this script idempotently
# symlinks them into ~/.claude/workflows/ on every session boot.
#
# Always exits 0 — must never block a session.
set -u
cat >/dev/null 2>&1 || true   # drain hook stdin (Claude Code passes JSON)

# CLAUDE_PLUGIN_ROOT must be set by Claude Code when running plugin hooks.
[ -n "${CLAUDE_PLUGIN_ROOT:-}" ] || exit 0
SRC="$CLAUDE_PLUGIN_ROOT/workflows"
[ -d "$SRC" ] || exit 0

DST="$HOME/.claude/workflows"
mkdir -p "$DST" 2>/dev/null || exit 0

for f in "$SRC"/*.md; do
  [ -f "$f" ] || continue
  ln -sfn "$f" "$DST/$(basename "$f")" 2>/dev/null || true
done

exit 0
