#!/usr/bin/env bash
# Checkpoint hook — fires on PostToolUse (mutating tools) and Stop.
# Two responsibilities, both no-ops when their target file isn't there:
#   1. Append a snapshot to .planning/CHECKPOINT.md (rolling, 30 entries).
#   2. Refresh the <!-- AUTO:CURRENT_STATE --> block inside AGENTS.md
#      (project root) so any AI/teammate reading AGENTS.md sees fresh state.
# Always exits 0 so it never fails the user's turn.
set -uo pipefail
[ -d .planning ] || exit 0

input=$(cat 2>/dev/null || echo '{}')
event=$(echo "$input" | jq -r '.hook_event_name // "unknown"' 2>/dev/null || echo "unknown")
tool=$(echo "$input"  | jq -r '.tool_name       // ""'        2>/dev/null || echo "")

CP=".planning/CHECKPOINT.md"
ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "-")
last=$(git log -1 --pretty='%h %s' 2>/dev/null || echo "-")
dirty=$(git status --porcelain 2>/dev/null | head -10)
dirty_count=$(printf '%s\n' "$dirty" | grep -c . 2>/dev/null || echo 0)

# --- Part 1: append to CHECKPOINT.md -----------------------------------------
{
  echo "## $ts  [$event${tool:+:$tool}]"
  echo "- branch: $branch"
  echo "- last commit: $last"
  if [ -n "$dirty" ]; then
    echo "- dirty files:"
    echo "$dirty" | sed 's/^/  /'
  fi
  echo
} >> "$CP" 2>/dev/null || exit 0

# Trim CHECKPOINT.md to last 30 entries to keep the file bounded.
awk 'BEGIN{RS="\n## "} NR==1{print; next} {a[NR]=$0} END{n=NR; start=(n>30?n-29:2); for(i=start;i<=n;i++) printf "## %s", a[i]}' "$CP" > "$CP.tmp" 2>/dev/null && mv "$CP.tmp" "$CP" 2>/dev/null

# --- Part 2: refresh AGENTS.md auto-block ------------------------------------
# Skip silently if AGENTS.md missing (project not yet psd-init'd) or sentinels absent.
if [ -f AGENTS.md ] && grep -q '<!-- AUTO:CURRENT_STATE -->' AGENTS.md && grep -q '<!-- /AUTO:CURRENT_STATE -->' AGENTS.md; then
  milestone=$(grep '^- milestone:' .planning/STATE.md 2>/dev/null | awk '{print $3}' || echo "-")
  active=$(grep '^- active_phase:' .planning/STATE.md 2>/dev/null | awk '{print $3}' || echo "-")
  last_skill=$(grep '^- last_skill:' .planning/STATE.md 2>/dev/null | awk '{print $3}' || echo "-")

  if [ -z "$dirty" ]; then
    tree_state="clean"
  else
    tree_state="dirty (${dirty_count} files)"
  fi

  recent=$(tail -200 "$CP" 2>/dev/null | grep -E '^## ' | tail -5 | sed 's/^## /- /')

  block_file=$(mktemp 2>/dev/null) || exit 0
  {
    echo "<!-- AUTO:CURRENT_STATE -->"
    echo "## Current state (auto-updated — do not hand-edit)"
    echo
    echo "**Last update:** $ts"
    echo "**Milestone:** $milestone"
    echo "**Active phase:** $active"
    echo "**Last skill run:** $last_skill"
    echo "**Last commit:** $last"
    echo "**Working tree:** $tree_state"
    echo
    echo "**Recent activity (last 5 hook entries):**"
    if [ -n "$recent" ]; then
      printf '%s\n' "$recent"
    else
      echo "- (none)"
    fi
    echo "<!-- /AUTO:CURRENT_STATE -->"
  } > "$block_file"

  awk -v bf="$block_file" '
    BEGIN { skip=0 }
    /<!-- AUTO:CURRENT_STATE -->/ {
      while ((getline line < bf) > 0) print line
      close(bf)
      skip=1
      next
    }
    /<!-- \/AUTO:CURRENT_STATE -->/ {
      skip=0
      next
    }
    skip==0 { print }
  ' AGENTS.md > AGENTS.md.tmp 2>/dev/null && mv AGENTS.md.tmp AGENTS.md 2>/dev/null

  rm -f "$block_file" 2>/dev/null
fi

exit 0
