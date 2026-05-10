# Workflow: psd-new-milestone

Archive the current milestone and scaffold the next.

## Pre-flight gates
1. `.planning/STATE.md` must exist
2. **Every phase in current ROADMAP.md must have `VERIFICATION.md` with `Result: PASS`** — else block with a list of unfinished phases. (User can override with `--force` flag if they accept the partial milestone.)
3. Working tree must be clean.

## Subagent dispatch
Spawn `psd-milestoner`:

```
You are psd-milestoner.

Read yourself:
- .planning/STATE.md (current milestone version)
- .planning/ROADMAP.md
- .planning/phases/Phase */SUMMARY.md (one per shipped phase)

Read @$HOME/.claude/workflows/new-milestone.md.

Tasks (in order, idempotent — safe to re-run on partial state):

1. Determine current milestone version from STATE.md (e.g., "v1") and next ("v2").

2. Archive current milestone:
   - mkdir -p .planning/milestones/v{N}
   - git mv .planning/ROADMAP.md       .planning/milestones/v{N}/ROADMAP.md
   - git mv .planning/phases           .planning/milestones/v{N}/phases  (if it exists)
   - git mv .planning/LESSONS.md       .planning/milestones/v{N}/LESSONS.md  (if it exists; new milestone starts with empty rollup)
   (Use git mv so history is preserved; if not in a git repo, plain mv.)

3. Roll up phase summaries into milestones/v{N}/SUMMARY.md:
   - Header with milestone version and date range (from git log)
   - One section per phase, paste its SUMMARY.md
   - Final "Aggregate lessons" section with 3-5 bullets distilled across phases. **Source these from the per-phase `LESSONS.md` files** under `milestones/v{N}/phases/Phase */LESSONS.md` (rank by severity: prefer P0/P1, generalize across phases). Fall back to freehand only if no per-phase LESSONS.md exist.

4. Ask user (AskUserQuestion) for the new milestone:
   - Vision/theme of v{N+1}
   - Top requirements
   - Anything dropped from v{N} that should NOT come back

5. Generate fresh .planning/ROADMAP.md for milestone v{N+1} with 3-6 new phases.

6. Reset .planning/STATE.md:
   - milestone: v{N+1}
   - active_phase: 1
   - last_completed_phase: none
   - last_skill: psd-new-milestone
   - decisions: append "Milestone v{N} closed <date>; v{N+1} opened with theme: <theme>"

7. Append a "Milestone v{N} closed" entry to PROJECT.md decisions log.

8. Refresh `AGENTS.md` STATIC sections (do NOT touch the AUTO:CURRENT_STATE block):
   - Update `## What this is` from the new PROJECT.md "Vision" + "Problem"
   - Update `## Stack` if PROJECT.md "Stack" section changed (rare during milestone close)
   - Use awk/sed surgically — preserve everything between `<!-- AUTO:CURRENT_STATE -->` and `<!-- /AUTO:CURRENT_STATE -->` exactly as the hook wrote it

Report back in <=200 words: archived path, new milestone version + theme, new phase 1 goal.
```

## Artifact templates

### `milestones/v{N}/SUMMARY.md`
```markdown
# Milestone v{N} — Summary

**Closed:** <ISO date>
**Phases:** 1 through {last}
**Commits:** <git log count for this period>

## Theme
<original vision from PROJECT.md at the time>

## Phase summaries
### Phase 1: <name>
<paste from phase SUMMARY.md>

### Phase 2: <name>
...

## Aggregate lessons
- <distilled across phases — 3-5 bullets>

## Carried forward to v{N+1}
- <item that became next-milestone scope>
```

## Post-conditions
- `.planning/milestones/v{N}/` populated with ROADMAP.md, phases/, SUMMARY.md
- `.planning/ROADMAP.md` is now the v{N+1} roadmap
- `.planning/phases/` is empty (or absent)
- `.planning/STATE.md` reset to phase 1 of v{N+1}
- PROJECT.md has a milestone-close decision entry

## Failure modes
- Phases unfinished and `--force` not passed → block, list which phases lack PASS
- `git mv` fails (not a git repo) → fall back to plain `mv` and warn the user
- User aborts the new-milestone vision questions → milestone archive is already done; STATE.md left pointing at old milestone with a `pending_new_milestone: true` flag so user can resume later

## Why this is one skill, not two
GSD splits this into `complete-milestone` + `new-milestone`. We collapse because in practice they're always run together — closing without opening leaves the project in a half-state. The atomic combined skill is harder to misuse.
