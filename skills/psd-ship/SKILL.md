---
name: psd-ship
description: Open a PR (or push a branch), write SUMMARY.md, advance STATE.md to the next phase.
argument-hint: "[phase]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Task
---

<objective>
Close out a verified phase: write phase SUMMARY.md, ship via PR (or branch if no remote), advance STATE.md's active_phase pointer.

Orchestrator role: validate VERIFICATION.md PASS gate, dispatch `psd-shipper`, surface PR/branch info.
</objective>

<execution_context>
@$HOME/.claude/workflows/ship.md
</execution_context>

<process>
1. **Pre-flight gates** (per workflows/ship.md):
   - `phases/Phase {N}/VERIFICATION.md` must exist with `Result: PASS` (case-sensitive). Else block and suggest `/psd-plan {N} --from-failure` flow.
   - Working tree clean.

2. **Dispatch `psd-retrospector`** for Phase {N}. It extracts ≤5 obstacles into `phases/Phase {N}/LESSONS.md` and appends to `.planning/LESSONS.md` "## Active". 60s timeout. On error/timeout, proceed; pass `lessons_status=skipped:<reason>` to the shipper. See `@$HOME/.claude/workflows/retrospect.md`.

3. **Dispatch `psd-shipper`** with the phase number and the retrospector's status. Shipper includes the new LESSONS.md files in the `chore(planning): ship phase {N}` commit and reports the lessons-captured count in its quality-gates block.

4. **Report** the shipper's ≤200-word summary verbatim. If milestone is now complete (last phase shipped), suggest `/psd-new-milestone`. Else suggest `/psd-plan {N+1}`.

Preserve all gates: never ship FAIL/PARTIAL; never force-push; never push to main directly; never amend.
</process>
