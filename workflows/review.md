# Workflow: review

Lightweight code review + security check + eval audit on a phase's diff. One subagent does all three. Reads ONLY changed files for the phase (not the whole codebase). Produces `phases/Phase {N}/REVIEW.md` with findings tagged P0 / P1 / P2.

This is the missing-but-cheap quality gate. It runs **after `execute`** and **before `ship`** as an opt-in safety net.

## Pre-flight gates
1. `.planning/phases/Phase {N}/PLAN.md` must exist.
2. Phase must have committed work — `git log` must show at least one commit since the phase plan was written. Else: nothing to review; print one-liner and exit.
3. **Skip-path:** `phases/Phase {N}/REVIEW.md` already exists AND `--force` not passed → print "Already reviewed (REVIEW.md exists). Pass --force to re-review." and exit.

## Scope discipline (binding)

The reviewer reads ONLY files changed in the phase, NOT the whole codebase.

Source the file list from the union of `files:` lists in `phases/Phase {N}/plans/*.md` (frontmatter only). Optionally cross-check with `git log --name-only` over the phase commit range.

Cap at 25 changed files. If more, review the most recent 25 and flag "review truncated; re-run with smaller diffs."

## Subagent dispatch
Spawn `reviewer`:

```
You are reviewer for Phase {N}.

Read yourself:
- phases/Phase {N}/PLAN.md (success criteria + per-plan list)
- phases/Phase {N}/plans/*.md (frontmatter only — read `files:` lists)
- The actual changed source files (Read each)
- For AI phases: phases/Phase {N}/AI-SPEC.md if it exists (eval criteria)
- For UI phases: phases/Phase {N}/UI-SPEC.md if it exists (design contract)

Read @$HOME/.claude/workflows/review.md for the protocol.

Run THREE light checks per file (see reviewer agent for the checklist).

Write phases/Phase {N}/REVIEW.md per the template below.

Report back in <=200 words: P0 count, P1 count, P2 count, top concern, suggested next.
```

## Severity tags

- **P0** — must fix before ship: bug that breaks a success criterion, security hole, secret leaked
- **P1** — should fix before ship: code quality, missing error handling, missing test coverage on a key path
- **P2** — nice to fix later: style, refactor opportunity, comment cleanup

The reviewer **never auto-fixes**. Only reports. User decides what to address.

## Artifact template

### `phases/Phase {N}/REVIEW.md`
```markdown
# Phase {N} — Review

**Date:** <ISO>
**Files reviewed:** <count>
**Verdict:** <CLEAR | NEEDS-FIXES>
**Counts:** P0=<n> P1=<n> P2=<n>

## P0 — Must fix before ship
- [ ] **<file>:<line>** — <one-line concern>
  - Why: <one line>
  - Suggested fix: <one line>

## P1 — Should fix before ship
- [ ] **<file>:<line>** — <one-line concern>
  - Why: <one line>

## P2 — Nice to fix later
- [ ] **<file>:<line>** — <one-line concern>

## Security findings (separate listing)
- <severity>: <file>:<line> — <one-line>

## Eval findings (separate listing — vs PLAN.md / AI-SPEC.md criteria)
- <criterion>: <met | partial | missing> — <evidence>
```

## Hand-off to ship

`ship` reads REVIEW.md (if exists) and:
- If verdict is `NEEDS-FIXES` and any P0 unchecked → BLOCK ship and tell user to fix
- If P1s unchecked → warn but allow ship (user decision)
- If verdict is `CLEAR` → proceed normally

Findings can be checked off (`- [ ]` → `- [x]`) by `debug` when fixes land.

## Hard rules
- **Read-only file inspection.** Never auto-fix. Never edit source.
- **Diff-scoped.** Don't read the whole repo; only changed files (max 25).
- **Cite location.** Every finding has file path + line number (or block range).
- **Cap REVIEW.md at ~250 lines.** P0/P1/P2 listings are bullets, not essays.
- **Don't grade style.** "I'd prefer X" isn't a finding. Real bugs only.
- **Don't duplicate verify.** Verify is user-facing UAT; review is code-side.
