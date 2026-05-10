# Workflow: resume

Read-only context restore after a session reset, interruption, or mid-turn failure.

## Skip-path (no subagent needed)
1. If `.planning/` doesn't exist → print: "No PSD project here. Run `/psd:init` to start one." Exit.
2. If `.planning/STATE.md` doesn't exist → print: "PSD initialized but STATE.md missing. Did init complete?" Exit.

## Subagent dispatch
Spawn `resumer`:

```
You are resumer. Read-only restore.

Read yourself (in this order):
1. .planning/STATE.md           — slow-moving project pointer
2. .planning/CHECKPOINT.md      — last 30 hook-written snapshots
3. .planning/ROADMAP.md         — only the active phase's section
4. ONE active artifact:
   - if STATE.last_skill is plan → phases/Phase {N}/PLAN.md
   - if STATE.last_skill is execute → `git log --oneline -20`
   - if STATE.last_skill is verify → phases/Phase {N}/VERIFICATION.md
   - if STATE.last_skill is ship → STATE.md is enough; just read latest commit

Read @$HOME/.claude/workflows/resume.md.

Do NOT read more than the files above. Do NOT read every plan/* file.

Report back in <=200 words, structured exactly:

WHERE YOU LEFT OFF
- milestone: vN
- active phase: {N} — <phase name>
- last skill: <name>
- last activity (from CHECKPOINT.md): <one line>

WHAT TO DO NEXT
- [recommended skill invocation, e.g. "/psd:execute 2"]
- why: <one sentence>

BLOCKERS / OPEN QUESTIONS
- <if any from VERIFICATION.md or recent CHECKPOINT.md fail entries>
- (none)
```

## What resume must NOT do
- Run any subagent that writes files (this is purely read-only)
- Auto-execute the suggested next skill — only suggest
- Re-explore the codebase (resume relies on cached artifacts; if they're stale, that's a `/psd:plan --from-failure` problem)
- Read every plan file in the phase tree (one active artifact only)

## Failure modes
- STATE.md is malformed → report what's malformed; suggest user inspect manually
- CHECKPOINT.md is empty → fine; just rely on STATE.md
- The active artifact for the last_skill is missing → that's a sign of an interrupted skill; report which skill and which artifact is missing, suggest re-running it
