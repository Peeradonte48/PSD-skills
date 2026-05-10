# Workflow: verify

Walk through the phase's success criteria with the user (UAT) and write `VERIFICATION.md`.

## Pre-flight gates
1. `phases/Phase {N}/PLAN.md` must exist
2. Phase {N}'s commits should be landed (warn if `git log` doesn't show plan-related commits, but proceed)

## Subagent dispatch
Spawn `verifier`:

```
You are verifier for Phase {N}.

Read yourself:
- .planning/phases/Phase {N}/PLAN.md (success criteria + plan list)
- .planning/phases/Phase {N}/plans/*.md (per-plan test criteria)
- recent git log: `git log --oneline -20`

Read @$HOME/.claude/workflows/verify.md for the protocol.

Process:
1. Compile a checklist: phase-level success criteria + per-plan test criteria
2. For each item, ask the user (one AskUserQuestion call, multiple questions): pass / fail / skip
3. For failures, ask the user for a one-line note on what went wrong
4. Write phases/Phase {N}/VERIFICATION.md with the marked checklist + notes
5. If any failure: also write a brief diagnosis section (which plans are likely culprits, ready to feed back to /psd:plan)

Report back in <=200 words: pass/fail/skip counts, blocking failures, recommended next step.
```

## UAT discipline
- **Don't auto-test.** This is the user's chance to actually click around / call the API / whatever. The verifier *prompts* and *records* — it doesn't run tests itself (that's execute's job).
- For each criterion, the verifier should describe *how* the user can check it ("Open the page at /foo and click X") if not obvious.
- Skipping is allowed for criteria that need data/access the user doesn't have today; mark them as `skip:<reason>`.

## Artifact template

### `phases/Phase {N}/VERIFICATION.md`
```markdown
# Verification — Phase {N}

**Date:** <ISO date>
**Result:** PASS | FAIL | PARTIAL
**Counts:** pass=X fail=Y skip=Z

## Phase-level success criteria
- [x] <criterion> — pass
- [ ] <criterion> — fail: <user note>

## Per-plan checks
### {N}-01: <title>
- [x] <test criterion> — pass

### {N}-02: <title>
- [ ] <test criterion> — fail: <user note>

## Diagnosis (only if any failures)
**Likely culprits:**
- Plan {N}-02 — <why>

**Suggested replan input:**
- New plan needed: <description>
- Modify plan {N}-02 step N: <what to change>

(Feed this section to `/psd:plan {N} --from-failure` to generate fix plans.)
```

## Post-conditions
- `phases/Phase {N}/VERIFICATION.md` written with explicit PASS/FAIL/PARTIAL header
- `STATE.md` updated: `last_skill: verify`, decision: "Phase {N} verified: <result>"
- If FAIL or PARTIAL: do **not** advance the active phase — user must run `/psd:plan {N} --from-failure` then re-execute then re-verify.

## Nudge in the verifier's report (binding)

When `Result: PASS`, the verifier's "Suggested next" section MUST list all three options in this order:

```
Suggested next (on PASS):
  • /psd:review {N}       (recommended — quick code + security + eval audit on the diff)
  • /psd:add-tests {N}    (recommended — regression tests from your PASS criteria)
  • /psd:ship {N}         (skip review/tests if you've already done them manually)
```

This is not a fixed boilerplate — it's the floor. The verifier may add a one-line context sentence (e.g., "Phase 3 touched auth — review especially recommended."), but it cannot omit the three bullets.

Why mandatory: non-technical users won't discover `/psd:review` and `/psd:add-tests` on their own. The nudge is the only consistent surface that exposes them. Keeping the user's opt-in choice intact: surfacing options is not the same as forcing them.

## Failure modes
- User wants to skip everything → still write VERIFICATION.md as PARTIAL with all skips, never fabricate passes
- Verifier can't find PLAN.md → report and ask user if they meant a different phase number
