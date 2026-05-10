# Workflow: psd-retrospector

Auto-extract obstacles from a completed phase so the next phase's planner doesn't repeat them. Runs as a sub-step of `/psd-ship`, never as a user-facing slash command.

## Why this exists

Today, every phase artifact (`VERIFICATION.md`, `REVIEW.md`, debug fixes, plan deviations) **dies with the phase**. The next planner reads only the *current* phase's CONTEXT/RESEARCH/SPECs — so the same mistakes (forgotten edge cases, recurring P0s, repeat library traps) keep happening across phases. This workflow gives the suite a memory.

## Capture sources (binding — only these four)

| Source | Where | What counts |
|---|---|---|
| Verify-fails | `phases/Phase {N}/VERIFICATION.md` | Lines containing `FAIL`, `PARTIAL`, or `unmet:` blocks |
| Review-fails | `phases/Phase {N}/REVIEW.md` | Unchecked `- [ ] P0` and `- [ ] P1` lines (skip `- [x]`) |
| Debug fixes | `.planning/STATE.md` "Recent decisions" | Lines tagged `Debug fix:` dated within the phase window |
| Plan deviations | `.planning/STATE.md` "Recent decisions" | Lines tagged `Plan deviation:` dated within the phase window |

**Phase window** = from the timestamp of the first commit referencing `phase-{N}` (or the `Phase {N}` planning commit) up to now. Anything older belongs to a prior phase.

## Lesson record schema

```markdown
### L{N}-{NN}  [P0|P1|P2]  [category]  "<5-8 word trigger>"
- **id:** L3-01
- **source:** phases/Phase 3/REVIEW.md:42-48
- **trigger:** Auth middleware ran twice on nested routes
- **lesson:** Wrap middleware registration in idempotent guard, or assert single-mount in tests
- **context:** Phase 3, plan 3-04, files: middleware/auth.ts
- **avoid:** Re-mounting middleware in route group layouts when parent already mounts it
```

**Fields (all required except `avoid`):**
- `id` — `L{phase}-{NN}`, sequential per phase, two digits
- `source` — `<file>:<line-range>` citation. **Mandatory.** Without it, drop the record.
- `trigger` — one-line factual restatement of what went wrong (paraphrase the source, never invent)
- `lesson` — one-line directive of what to do differently
- `context` — phase number, plan id (if known), comma-separated files touched (best-effort glob)
- `avoid` — optional, one-line "don't do this" pattern if the lesson generalizes

**Categories (pick exactly one):**
- `architecture` — structural / module boundary issues (generalizes across phases)
- `dependency` — library / version / API incompatibility (phase-specific usually)
- `tooling` — build, lint, deploy, env, CI (generalizes)
- `testing` — missing/wrong test coverage that let a bug through
- `integration` — service-to-service, API contract, schema mismatch
- `scope` — punted edge case that bit back, premature feature, scope creep (generalizes)
- `other` — only if no other category fits (rare)

**Severity (auto-assigned from source):**
- P0 — review P0 finding OR `Result: FAIL` in VERIFICATION
- P1 — review P1 finding OR `Result: PARTIAL` in VERIFICATION
- P2 — debug fix OR plan deviation

## Cap rule (hard)

**At most 5 lessons per phase.** If >5 raw obstacles, rank and drop the tail:

```
P0 review > FAIL verify > debug-fix > P1 review > PARTIAL verify > plan-deviation
```

Quality over coverage — better to surface 3 sharp lessons than 5 noisy ones. The dropped count surfaces in the report so users know to look at the raw artifacts if a pattern matters.

## Hallucination guard (most important rule)

**Every kept lesson MUST have a `source: <file>:<line-range>` citation.** No citation → drop the record.

The retrospector may only **quote** or **paraphrase** the cited content. Never invent. Never extrapolate. If the source line is `"middleware ran twice"`, the lesson can be `"Wrap middleware registration in idempotent guard"` (a direct directive from the symptom) but **not** `"Migrate to Redis-backed session store"` (an unstated jump).

When in doubt, drop the lesson. False signal corrupts the rollup; missing signal just costs one phase of repeat-mistake.

## Per-phase file template

`phases/Phase {N}/LESSONS.md`:

```markdown
# Phase {N} — Lessons

**Captured:** <ISO timestamp>
**Sources scanned:** VERIFICATION.md, REVIEW.md, STATE.md "Recent decisions", PLAN.md
**Raw obstacles:** <total count>
**Lessons kept:** <kept count> (capped at 5 — dropped <M> by rank)

## Lessons

### L{N}-01 ...
### L{N}-02 ...
```

If zero obstacles:

```markdown
# Phase {N} — Lessons

**Captured:** <ISO timestamp>

_No obstacles recorded — clean phase._
```

If sources missing:

```markdown
_Sources unavailable: REVIEW.md (not produced — /psd-review was not run)_
```

## Rollup file template

`.planning/LESSONS.md`:

```markdown
# Lessons (rolling)

<!-- AUTO:LESSONS_INDEX -->
**Active:** last 15 entries OR all P0 (whichever larger)
**Categories seen:** architecture(0), dependency(0), tooling(0), testing(0), integration(0), scope(0), other(0)
**Last updated:** <ISO timestamp>
<!-- /AUTO:LESSONS_INDEX -->

## Active

<!-- Entries here, newest first. Planner reads only this section. -->

## Archived (planner skips by default)

<!-- Entries beyond cap. Manually move back to Active to resurrect. -->
```

## Cap rule for rollup (binding)

Active = `last 15 entries OR all severity=P0 (whichever set is larger)`. Anything else → `## Archived`.

After every append, recompute the split. The archived entries are not deleted — users can manually move them back to `## Active` if they're still relevant.

## User-edit safety

The rollup body is **user-editable**. Users can:
- Move entries between `## Active` and `## Archived`
- Edit the `lesson:` or `avoid:` field for nuance
- Delete entries that turned out to be wrong
- Add manual entries (use `id: L{N}-{NN}` format; retrospector won't conflict)

The retrospector only rewrites content **inside** `<!-- AUTO:LESSONS_INDEX -->` ↔ `<!-- /AUTO:LESSONS_INDEX -->` markers (same pattern as `AGENTS.md` `AUTO:CURRENT_STATE` block). Body content the user moved is never touched.

Per-phase files (`phases/Phase {N}/LESSONS.md`) are **immutable convention** post-ship — not enforced, but the team should treat them as the historical audit trail. Edit the rollup, not the per-phase file.

## Cross-milestone archive

When `/psd-new-milestone` runs, `psd-milestoner`:
1. `git mv .planning/LESSONS.md .planning/milestones/v{N}/LESSONS.md`
2. The new milestone starts with **no rollup** — it's recreated on the first ship of v{N+1}.
3. The "Aggregate lessons" section in `milestones/v{N}/SUMMARY.md` sources its 3-5 distilled bullets **from the per-phase LESSONS.md files** (not freehand).

Persistent architectural lessons (e.g., "always use idempotent middleware") that should carry across milestones: user manually copies entries from `milestones/v{N}/LESSONS.md` into `.planning/LESSONS.md` "## Active" after the new milestone scaffolds. Explicit, not magic.

## Failure modes

- **Zero obstacles** → per-phase `_clean phase_` marker, rollup untouched. Idempotent.
- **All sources missing** → `_Sources unavailable: <list>_` in per-phase file. No rollup write. Never block ship.
- **>5 raw obstacles** → cap at 5; report `5 captured (M dropped)` to shipper.
- **Source-citation missing on a lesson** → drop the record at write time; never escape the agent.
- **Retrospector timeout (60s)** → `/psd-ship` proceeds; shipper reports `Lessons: not captured — timeout`.
- **Rollup body has user-moved entries** → respect them; only rewrite the AUTO index block.
