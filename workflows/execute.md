# Workflow: psd-execute

Execute every atomic plan in a phase, one commit per plan.

## Pre-flight gates
1. `phases/Phase {N}/PLAN.md` must exist — else tell user to run `/psd-plan {N}`.
2. Working tree must be clean (`git status --porcelain` empty) — else ask user to commit/stash first.
3. Read PLAN.md's wave plan to determine execution order.

## Execution model
- Each atomic plan gets its own **fresh `psd-executor` subagent context**.
- Plans within a wave run in parallel (multiple Task calls in one assistant message).
- Waves run sequentially: wait for wave K to finish before starting wave K+1.
- One plan = one commit. Commit message = the plan's `Commit message` field.

## Per-plan dispatch
For each plan ID `{N}-NN` in the current wave:

```
You are psd-executor for plan {N}-NN.

Read yourself:
- .planning/phases/Phase {N}/plans/{N}-NN.md (your spec)
- .planning/PROJECT.md (only if you need broader context)
- existing source files listed in the plan's `files:` frontmatter

Read @$HOME/.claude/workflows/execute.md for the executor protocol.

Tasks:
1. Implement per the plan's Steps + Behavior
2. Run any project tests/typecheck if obvious how (npm test, pytest, etc.) — skip if unclear
3. Stage only the files you modified
4. Commit with the plan's `Commit message` (no Claude/co-author trailer unless project convention dictates)
5. Verify the commit landed (git log -1)

Report back in <=200 words:
- commit SHA
- pass/fail of test criteria (your judgment)
- any deviation from the plan and why
- blockers for downstream plans
```

## Wave coordination
- After each wave, the orchestrator (main context) reads each executor's summary.
- If any plan in the wave failed: HALT. Do not start next wave. Report failures to the user with the diagnosis.
- If all passed: proceed to next wave.

## Halt conditions (orchestrator-level)
- Executor reports a test failure it couldn't fix
- Executor reports a deviation it can't justify
- A plan's commit didn't land
- Two plans in the same wave touch the same file (planner bug — escalate to user)

## Atomic commit protocol (executor-internal)
1. Make the change
2. Run smoke validation (typecheck/test if available)
3. `git add` only files in the plan's `files:` list
4. `git commit -m "<Commit message from plan>"`
5. Confirm with `git log -1 --pretty='%h %s'`

**Never `git add -A` or `git add .`** — strictly the files in the plan.

## Post-conditions
- One git commit per plan (verifiable: `git log --oneline | wc -l` increased by N)
- `STATE.md` updated: `last_skill: psd-execute`, decision entry like "Phase {N} executed: X commits"
- Working tree clean

## Recovery
If interrupted mid-wave (token limit, network):
- The PostToolUse hook has captured `CHECKPOINT.md` snapshots after each commit.
- `/psd-resume` will see committed plans and report which IDs are done vs. pending.
- Re-running `/psd-execute {N}` after resume should be **idempotent**: it skips plans whose commit already exists (detected via `git log --grep "<plan title>"` or by checking files were modified).
