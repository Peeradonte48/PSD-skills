---
name: psd-new-milestone
description: Archive current milestone into milestones/v{N}/ and scaffold v{N+1} ROADMAP.md + reset STATE.md.
argument-hint: "[--force]"
allowed-tools:
  - Read
  - Write
  - Bash
  - Task
  - AskUserQuestion
---

<objective>
Atomically close the current milestone and open the next one. Archives ROADMAP + phases into `milestones/v{N}/`, rolls up phase summaries, asks the user for the next milestone's vision, generates a fresh ROADMAP for v{N+1}, resets STATE.

Orchestrator role: validate completeness gate, dispatch `psd-milestoner`, surface the new milestone's plan-1 starting point.
</objective>

<execution_context>
@$HOME/.claude/workflows/new-milestone.md
</execution_context>

<process>
1. **Pre-flight gates** (per workflows/new-milestone.md):
   - `.planning/STATE.md` must exist.
   - All phases in current ROADMAP.md must have `VERIFICATION.md` with `Result: PASS`. If not, block and list unfinished phases — UNLESS `$ARGUMENTS` contains `--force`.
   - Working tree clean.

2. **Dispatch `psd-milestoner`** with the `--force` flag if passed. The agent owns all AskUserQuestion calls for the new-milestone vision.

3. **Report** the milestoner's ≤200-word summary verbatim. Suggest `/psd-plan 1` to begin the new milestone.

Preserve all gates: refuse incomplete milestones without `--force`; use `git mv` when in a git repo so history follows; one commit for the archive+open transition.
</process>
