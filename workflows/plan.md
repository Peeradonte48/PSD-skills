# Workflow: psd-plan

Decompose a phase into atomic plans (one commit each).

## Pre-flight gates
1. `.planning/STATE.md` must exist — else tell user to run `/psd-init` first.
2. Resolve phase number: if `$ARGUMENTS` is empty, read `STATE.md.active_phase`. Else use the int passed.
3. If `phases/Phase {N}/PLAN.md` already exists with content → ask user (AskUserQuestion): overwrite, append, or abort.

## Defaults: accuracy-first

`/psd-plan` is opinionated toward accurate research and planning, since errors here cascade to every downstream phase. **Research and peer-review are ON by default.**

- `--no-research` — skip research even if it would auto-fire (lean mode for trivial phases or quick re-plans)
- `--no-peer-review` — skip the adversarial plan reviewer
- `--deep` — raise research depth (8 fetches/target, 700-line cap; otherwise default is 5 fetches/target, 500-line cap)
- `--research` — force re-research even if RESEARCH.md exists
- `--from-failure` — re-plan only the deltas from VERIFICATION.md failures (skips research and peer-review unless explicitly flagged)

Plan-checker (deterministic, no LLM cost) ALWAYS runs. It can't be opted out.

## Research sub-step (before planner produces PLAN.md)

Research fires by default. The planner skips it only when ALL of these are true:
1. `--no-research` was passed, OR `--from-failure` mode AND no `--research` override, OR `phases/Phase {N}/RESEARCH.md` already exists AND neither `--research`/`--deep` nor `CONTEXT.md "research needed:"` line forces re-research
2. The phase goal doesn't reference any specific named library/API/integration the planner would benefit from looking up

Default research depth (raised from earlier "lean" defaults): 5 fetches per target, ≤500-line RESEARCH.md cap. `--deep` raises to 8 fetches and 700 lines.

Triggers (any one fires `psd-researcher`):
1. **Default behavior.** Research fires unless explicitly skipped.
2. **`--research` flag.** Forces re-research even if RESEARCH.md exists.
3. **`--deep` flag.** Forces re-research at deep caps.
4. **`CONTEXT.md "research needed:"` line.** Discusser surfaced explicit unknowns.
5. **Auto-detected unfamiliar lib/API in Stack or Phase goal.**

Skip conditions:
1. `--no-research` flag, AND no overriding flag/CONTEXT.md trigger.
2. `--from-failure` mode AND failure is logic-only (not knowledge gap).
3. `phases/Phase {N}/RESEARCH.md` exists AND no force-flag.

When research fires, the planner waits for `psd-researcher` to complete and produce `phases/Phase {N}/RESEARCH.md` before continuing. The planner then treats RESEARCH.md's "Guidance for the planner" section as **binding directives** for every atomic plan that touches a researched library/API.

Full research protocol: @$HOME/.claude/workflows/research.md.

## Plan-checker sub-step (deterministic, always runs, no LLM cost)

Right after PLAN.md and per-plan files are written, before peer-review and the auto-preview gate, the planner runs a rules-based check. No LLM call — these are mechanical assertions, fast and cheap.

**Rules (all binding):**

1. **Coverage** — every success criterion in PLAN.md is addressed by at least one plan. The planner extracts the criterion text and checks each plan's behavior/test-criteria for a substring or paraphrase match. Uncovered criteria → planner adds a plan or flags as a gap.

2. **Wave conflicts** — for each wave in the wave plan, union the `files:` lists across plans in the wave. Any file appearing in multiple plans of the same wave → conflict. Planner re-shuffles waves to resolve, or surfaces if it can't.

3. **Test-criteria specificity** — every plan must have at least one test criterion that's:
   - >10 characters of meaningful content
   - NOT one of these vague patterns: "works correctly", "is implemented", "no errors", "looks good", "passes", "succeeds", "behaves as expected"
   Vague criteria → planner rewrites with specific behavior; if it can't, flags for human input.

4. **Plan ID format** — all plan IDs match `{N}-NN` (phase-NN). Sequential, no gaps. Mismatch → renumber.

5. **Dependencies** — every `depends_on:` entry references a plan ID that exists in the plan list. Broken refs → fix or surface.

If any check fails AND the planner can self-correct, it does so and re-runs the check. If the planner can't self-correct (e.g., a criterion can't be made specific without user input), it surfaces the issue in the report and to the user via AskUserQuestion before proceeding.

Plan-checker logs (in PLAN.md's "Plan-checker results" section):
```
- coverage: 8/8 criteria covered
- wave conflicts: 0
- test-criteria specificity: all plans pass
- plan IDs: sequential (3-01 to 3-08)
- dependencies: all valid
```

This step is **always on**. It costs no LLM tokens (pure deterministic checks) and catches the most common plan defects cheaply.

## Peer-review sub-step (after plan-checker passes, before reporting "done")

Default behavior: **peer-review fires unless `--no-peer-review` was passed.** It dispatches `psd-plan-reviewer` in a fresh adversarial context. The reviewer reads PLAN.md / CONTEXT.md / RESEARCH.md / specs / PROJECT.md and surfaces concerns in ≤200 words.

The planner then either:
- **Addresses each concern** by modifying PLAN.md (re-order plans, split big plans, add missing coverage, etc.), OR
- **Acknowledges** with a one-line rationale appended to PLAN.md's "Open concerns acknowledged" section explaining why the plan stands as-is

Both are acceptable. The point is to make the trade-off explicit before the auto-preview asks the user to approve.

### Lessons-considered sub-section (planner-only, advisory)

If `.planning/LESSONS.md` exists, the planner reads its `## Active` section and surfaces relevant entries in a `### Lessons considered` sub-block under "Open concerns acknowledged". Filter rule: skip lessons whose `context.files` glob doesn't intersect this phase's anticipated touch surface, **unless** category is `architecture | scope | tooling` (those generalize across phases).

```markdown
## Open concerns acknowledged
<existing acknowledgments>

### Lessons considered
- L3-01 (P0/architecture): re-mount guard — applied via plan 4-02 step 3
- L2-04 (P1/tooling): n/a — different toolchain in this phase
```

Lessons are **advisory only**, never binding. If no lessons apply, omit the sub-section entirely (don't write "none applicable" — keep PLAN.md clean).

Order of sub-steps inside `psd-plan`:
1. Research (default ON, unless `--no-research`) → produce RESEARCH.md
2. Write PLAN.md + per-plan files
3. **Plan-checker (always)** → fix or surface defects
4. Peer-review (default ON, unless `--no-peer-review`) → produce concerns
5. Address or acknowledge concerns in PLAN.md
6. Auto-preview gate (always) → user approves
7. Done

## Subagent dispatch
Spawn `psd-planner`. **Pass only paths**, not content:

```
You are psd-planner for Phase {N}.

Read these files yourself (do not expect them to be in context):
- .planning/PROJECT.md
- .planning/ROADMAP.md (focus on Phase {N})
- .planning/STATE.md
- .planning/phases/Phase {N}/CONTEXT.md (IF IT EXISTS — output of /psd-discuss; binding decisions, hard constraints, edge cases punted)
- existing source code (use Glob/Grep/Read)

Read @$HOME/.claude/workflows/plan.md for the spec.

Tasks:
1. Confirm phase goal & success criteria from ROADMAP.md
2. Decompose into atomic plans (one commit each)
3. Write phases/Phase {N}/PLAN.md (overview + plan list)
4. Write phases/Phase {N}/plans/{N}-01.md ... {N}-NN.md (one per plan)

Report back in <=200 words: plan count, brief plan titles, any blockers/decisions for the user.
```

## What makes a "good" atomic plan
- **One commit's worth of work** — typically 1-4 files touched, <300 lines changed
- **Independently verifiable** — has its own test-criteria block
- **Self-contained** — links to no plan that comes after it (forward refs only via PLAN.md)
- **Wave-parallelizable when possible** — note dependencies explicitly

## Artifact templates

### `phases/Phase {N}/PLAN.md`
```markdown
# Phase {N}: <name>

**Goal:** <copied from ROADMAP.md>
**Success criteria:**
- [ ] <criterion>

## Plans

| ID | Title | Depends on | Files (primary) |
|---|---|---|---|
| {N}-01 | <title> | — | path/a.ts |
| {N}-02 | <title> | {N}-01 | path/b.ts |

## Wave plan (for parallel execution)
- Wave 1 (parallel): {N}-01, {N}-03
- Wave 2: {N}-02
- Wave 3: {N}-04
```

### `phases/Phase {N}/plans/{N}-NN.md`
```markdown
---
id: {N}-NN
title: <imperative title>
depends_on: [<ids>]
files: [path/a.ts, path/b.ts]
---

## Goal
<one sentence>

## Behavior
<what the change does, observable from outside>

## Steps
1. <concrete step>
2. <concrete step>

## Test criteria
- [ ] <how to verify it works>
- [ ] <edge case>

## Commit message
<imperative, present tense, <=72 chars>
```

## Re-plan mode
If invoked with `--from-failure` or when `VERIFICATION.md` shows failures, the planner reads `VERIFICATION.md`'s failure list and produces *only* the deltas (new/modified plans), not a full rewrite.

## Auto-preview + approval gate (final step before reporting "done")

Same shape as `psd-init`'s auto-preview loop, but mode `"phase N"`:

1. After PLAN.md and per-plan files are written, dispatch `psd-previewer` in mode `"phase {N}"`.
2. Show the plain-English narrative to the user verbatim.
3. AskUserQuestion: "Does this match what you want for Phase {N}?"
   - **Yes, ship it** → proceed to "done" reporting; suggest `/psd-execute {N}` next
   - **Revise — change something** → ask what to change; re-dispatch `psd-planner` in revision mode with the feedback; loop back to step 1
   - **Abort** → leave PLAN.md as-is, do NOT advance state, tell the user the plan is written but not approved
4. **Max 2 revision rounds.** Third "Revise" → forced choice: ship or abort.

This catches "the planner heard 'leaderboard' but I really meant 'just my own stats'" before any code is written.

## Post-conditions
- `phases/Phase {N}/PLAN.md` exists with a plan table
- `phases/Phase {N}/plans/` contains one file per plan, all with frontmatter
- The user has approved the plain-English preview (or explicitly aborted)
- `STATE.md` updated: `last_skill: psd-plan`, append decision: "Phase {N} planned with X plans"

## Failure modes
- Planner returns 0 plans → likely misread the phase scope; report and ask user to clarify
- Planner produces non-atomic plans (>500 LoC each) → reject the output, ask for re-decomposition
