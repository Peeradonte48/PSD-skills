# Workflow: psd-ship

Create a PR (or branch), write `SUMMARY.md`, advance `STATE.md` to the next phase.

## Pre-flight gates
1. `phases/Phase {N}/VERIFICATION.md` must exist with `Result: PASS` (PARTIAL/FAIL → block).
2. Working tree must be clean.
3. Detect remote: `git remote get-url origin` → if absent, ship as branch only (no PR).
4. **If `phases/Phase {N}/REVIEW.md` exists:** parse `Verdict:` line.
   - `NEEDS-FIXES` with any unchecked P0 → BLOCK ship; tell user to fix (e.g., via `/psd-debug`) and re-run `/psd-review` until P0s clear.
   - Unchecked P1s → warn but allow.
   - `CLEAR` → proceed normally.
   - REVIEW.md absent → no review was run; allow ship but suggest running `/psd-review {N}` next time.

## Subagent dispatch (two-step: retrospect, then ship)

### Step 1 — `psd-retrospector` (always, before shipper)

Extract ≤5 obstacles from this phase so the next planner doesn't repeat them. See `@$HOME/.claude/workflows/retrospect.md` for the full schema/cap rules.

```
You are psd-retrospector for Phase {N}.

Read yourself:
- .planning/phases/Phase {N}/{VERIFICATION.md, REVIEW.md, PLAN.md}
- .planning/STATE.md "Recent decisions" section (filter to phase window)

Read @$HOME/.claude/workflows/retrospect.md.

Tasks:
1. Walk the 4 sources, extract ≤5 lessons (mandatory source: citation per record).
2. Write phases/Phase {N}/LESSONS.md (canonical) — `_clean phase_` marker if zero obstacles.
3. Append entries to .planning/LESSONS.md "## Active"; rewrite the AUTO:LESSONS_INDEX block; rebalance Active vs Archived per cap rule (last 15 OR all P0).

Report ≤80 words: count captured, dropped, notable lesson IDs.
```

**Timeout:** 60s. On error/timeout: pass `lessons_status=skipped:<reason>` to the shipper. **Never block the ship on retrospector failure** — the rollup is recoverable, the ship moment is not.

### Step 2 — `psd-shipper`

```
You are psd-shipper for Phase {N}.

Read yourself:
- .planning/phases/Phase {N}/PLAN.md
- .planning/phases/Phase {N}/VERIFICATION.md
- .planning/STATE.md
- relevant git log: `git log --oneline $(git merge-base HEAD origin/main)..HEAD` if origin exists, else last N commits matching this phase

Read @$HOME/.claude/workflows/ship.md.

Tasks:
1. Write phases/Phase {N}/SUMMARY.md (1-2 paragraphs: what shipped, why, decisions, follow-ups)
2. If on main/master → create branch `phase-{N}-<slug>` and push
3. If origin exists → open PR with title "Phase {N}: <name>" and body containing summary + verification link + commit list
4. Update .planning/STATE.md: increment last_completed_phase, set active_phase to {N}+1 (or stay if last phase of milestone)
5. Append decision to PROJECT.md decisions log
6. Stage the LESSONS.md files written by psd-retrospector (phases/Phase {N}/LESSONS.md + .planning/LESSONS.md) into the same `chore(planning): ship phase {N}` commit.

Report back in <=200 words: PR URL or branch name, summary one-liner, next-phase suggestion. Include the lessons-captured count from the retrospector's status (or `not captured — <reason>` if Step 1 failed).
```

## Artifact template

### `phases/Phase {N}/SUMMARY.md`
```markdown
# Phase {N} Summary

**Status:** Shipped
**PR:** <url or "branch: phase-N-slug">
**Commits:** N (see `git log`)

## What shipped
<1 paragraph>

## Why this approach
<1 paragraph — key tradeoffs or decisions made during execution>

## Follow-ups (out of scope for this phase)
- <item>

## Lessons / surprises
- <item>
```

## PR body — fill the project's `.github/pull_request_template.md`

`psd-init` scaffolds `.github/pull_request_template.md` for the team. The shipper **fills it in** and passes the result to `gh pr create --body-file`. This way:
- Teammates without PSD see a familiar PR template format
- The body contains stable cross-references (`.planning/phases/Phase N/VERIFICATION.md`, `AGENTS.md`) so any reviewer (or AI) can navigate
- One source of truth for PR shape (the template), versioned in the repo

Process:
1. Read `.github/pull_request_template.md` if it exists.
2. Fill placeholders:
   - `## Summary` — paste SUMMARY.md "What shipped" paragraph
   - `## Phase / Plans landed` — phase number + name + comma-separated plan IDs
   - `## Verification` — `Result: PASS` and link to VERIFICATION.md
   - `## Notes for reviewers` — keep the references to PROJECT.md, PLAN.md, AGENTS.md
   - `## Test plan` — copy the user-facing checks from VERIFICATION.md (top 3-5 phase-level criteria)
3. Write the filled body to a temp file (e.g., `.planning/phases/Phase {N}/.pr-body.md`).
4. Run: `gh pr create --title "Phase {N}: <name>" --body-file .planning/phases/Phase {N}/.pr-body.md`
5. Delete the temp file after success.

If `.github/pull_request_template.md` is missing (e.g., project pre-dates PSD), fall back to this minimal body:

```markdown
## Summary
<from SUMMARY.md "What shipped">

## Phase / Plans landed
- Phase: {N} — <name>
- Plans: <ids>

## Verification
See `.planning/phases/Phase {N}/VERIFICATION.md` — result: PASS

## Notes for reviewers
- Project plan: `.planning/PROJECT.md`
- Phase plan: `.planning/phases/Phase {N}/PLAN.md`
- Current state for any AI continuing work: `AGENTS.md`

## Commits
<bullet list from git log>
```

## STATE.md update (atomic)
Read current STATE.md, modify these fields, write back:
```
- last_completed_phase: {N}
- active_phase: {N+1}     # or unchanged if {N} was the last phase in ROADMAP.md
- last_skill: psd-ship
- updated: <ISO timestamp>
```
Append a line to "Recent decisions": "Phase {N} shipped <date> — <PR url or branch>".

## Post-conditions
- `phases/Phase {N}/SUMMARY.md` exists
- PR opened (if origin) or branch pushed
- `STATE.md` advanced

## Nudge in the shipper's report (binding)

The shipper's report MUST include a "Quality gates this phase" block with two lines (review + tests). When either was not run, the line includes a "consider /psd-review on future phases" / "consider /psd-add-tests on future phases" nudge. This is how the optional safety nets stay discoverable for users who shipped without them — without retroactively blocking the ship.

Don't nudge for milestone-completion or new-phase suggestions twice (that goes in the "STATE advanced" line). The quality-gates block is solely for review + tests.

## Failure modes
- VERIFICATION.md says FAIL/PARTIAL → refuse to ship; tell user to fix first.
- PR creation fails (auth, no remote) → fall back to branch-only mode and tell user how to push manually.
- Working tree dirty → refuse and report which files.
