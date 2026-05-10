---
name: review
description: Phase-diff code review + light security + eval audit. Writes REVIEW.md with P0/P1/P2 findings. Read-only — never auto-fixes.
argument-hint: "[phase] [--force]"
allowed-tools:
  - Read
  - Write
  - Bash
  - Task
---

<objective>
Run a lightweight quality gate on the phase's committed diff. One subagent does code review + security check + eval audit (against PLAN.md success criteria, AI-SPEC.md if AI phase, UI-SPEC.md if UI phase).

Use as an opt-in safety net AFTER `execute` (and `verify`) and BEFORE `ship`. `ship` reads REVIEW.md and blocks shipping on uncleared P0 findings.

Orchestrator role: validate state, dispatch `reviewer`, surface verdict + findings. Read-only — never modifies source.
</objective>

<execution_context>
@$HOME/.claude/workflows/review.md
</execution_context>

<process>
1. **Pre-flight gates** (per workflows/review.md):
   - `phases/Phase {N}/PLAN.md` must exist; else suggest `/psd:plan {N}`.
   - Phase must have committed work since the plan was written.
   - **Skip-path:** if `phases/Phase {N}/REVIEW.md` exists and `--force` was NOT passed → print "Already reviewed. Pass --force to re-review." and exit.

2. **Companion check (suggestion mode):** scan the available-skills list. If `code-review:code-review` is listed AND a PR exists for this phase (`gh pr list --head <branch>` non-empty), print:

   > FYI: `code-review:code-review` is also available — native GitHub PR review on the open PR. Run it directly for a PR-context review; otherwise continuing with `review` (diff-scoped local code + security + eval).

   If no PR or skill not listed, skip silently.

3. **Dispatch `reviewer`** with phase number and `--force` flag if passed.

4. **Report** the reviewer's ≤200-word summary verbatim. If `NEEDS-FIXES`, suggest `/psd:debug "<P0 finding>"` to address top concern.

Preserve all gates: never auto-fix, never edit source from this skill, never advance state, never auto-delegate to companion (suggestion only).
</process>
