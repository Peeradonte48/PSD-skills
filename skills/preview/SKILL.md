---
name: preview
description: Show a plain-English narrative of what each phase will deliver. Read-only. Use anytime — no args = whole roadmap, [N] = single phase.
argument-hint: "[phase]"
allowed-tools:
  - Read
  - Bash
  - Task
---

<objective>
Translate the technical planning artifacts into plain-English narrative ("what you'll be able to do when this is done") for non-technical users. Read-only — does not modify any file.

Use cases:
- Re-view the roadmap after stepping away
- See what a specific phase will deliver before starting it
- Show a teammate what's planned without making them read PLAN.md jargon

Note: `init` and `plan` ALSO call this previewer automatically as their final step (with an approval gate). This skill is for ad-hoc re-viewing.
</objective>

<execution_context>
@$HOME/.claude/workflows/preview.md
</execution_context>

<process>
1. **Pre-flight gates:**
   - `.planning/` must exist; else print "No PSD project here. Run `/psd:init` to start one." and exit.
   - If `$ARGUMENTS` is non-empty and is an integer: mode is `"phase N"`. Else: mode is `"all"`.

2. **Dispatch `previewer`** with the mode. Subagent reads ROADMAP/PLAN/PROJECT itself and returns the narrative.

3. **Print the narrative verbatim.** No editing, no summarizing.

Preserve all gates: this skill is read-only — never let the previewer write files; never auto-advance state.
</process>
