---
name: psd-verify
description: Walk the user through phase UAT (success criteria + per-plan tests) and write VERIFICATION.md.
argument-hint: "[phase]"
allowed-tools:
  - Read
  - Write
  - Bash
  - Task
  - AskUserQuestion
---

<objective>
Conversational UAT: walk the user through every success criterion and per-plan test criterion, mark pass/fail/skip, write `VERIFICATION.md` with PASS/FAIL/PARTIAL header. On failure, generate a diagnosis ready to feed back into `/psd-plan --from-failure`.

Orchestrator role: validate preconditions, dispatch `psd-verifier`, surface result + next-step suggestion.
</objective>

<execution_context>
@$HOME/.claude/workflows/verify.md
</execution_context>

<process>
1. **Pre-flight gates:**
   - `phases/Phase {N}/PLAN.md` must exist.
   - Warn (don't block) if `git log` doesn't show plan-related commits — user may want to verify a partial phase.

2. **Dispatch `psd-verifier`** with the phase number. The verifier owns all AskUserQuestion calls for the UAT itself.

3. **Report** the verifier's ≤200-word summary. Suggest:
   - PASS → `/psd-ship {N}`
   - FAIL/PARTIAL → `/psd-plan {N} --from-failure`, then `/psd-execute {N}`, then re-verify

Preserve all gates: never fabricate a pass; never advance STATE beyond `last_skill: psd-verify` here (that's psd-ship's job).
</process>
