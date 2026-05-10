---
name: execute
description: Execute every atomic plan in a phase. One executor subagent per plan, atomic commits, wave-based parallelization.
argument-hint: "[phase]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Task
  - AskUserQuestion
---

<objective>
Execute each atomic plan in the specified phase. One `executor` subagent per plan, run in fresh contexts; plans within a wave run in parallel; waves run sequentially. One commit per plan.

Orchestrator role: validate preconditions, read PLAN.md's wave plan, dispatch executors wave-by-wave, halt on failure, summarize.
</objective>

<execution_context>
@$HOME/.claude/workflows/execute.md
</execution_context>

<process>
1. **Pre-flight gates** (per workflows/execute.md):
   - `phases/Phase {N}/PLAN.md` must exist; else suggest `/psd:plan {N}`.
   - Working tree must be clean; else ask user to commit/stash.

2. **Companion check (suggestion mode):** scan the available-skills list. If `superpowers:using-git-worktrees` is listed AND the phase has multiple waves OR appears risky (touches auth/payments/data-migration files per plan `files:` lists), print:

   > FYI: `superpowers:using-git-worktrees` is also available — runs the work in an isolated worktree so you can compare against current main. Recommended for risky phases. Abort and use it directly if helpful; otherwise continuing with `execute` (in current branch).

   Otherwise skip silently.

3. **Read PLAN.md's wave plan** (only the wave plan section; don't read all plan files).

3. **Idempotency check:** for each plan, check if its commit already exists (`git log --grep "<plan title>" --oneline`). Skip plans whose commit is already landed (resume-friendly).

4. **For each wave (sequential):**
   - Dispatch one `executor` per plan in the wave **in parallel** (multiple Task calls in one assistant message).
   - Wait for all to return.
   - If any reports FAIL or HALTED: STOP. Surface the failure. Do not start the next wave.

5. **Report** aggregated result: pass count, fail/halt list, suggested next:
   - all PASS → `/psd:verify {N}`
   - any FAIL → diagnose with the user before re-running

Preserve all gates: never `git add -A`, never amend, never push. Halt fast on first failure.
</process>
