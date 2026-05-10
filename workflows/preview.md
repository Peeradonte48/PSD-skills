# Workflow: psd-preview

Translate the technical planning artifacts (`ROADMAP.md`, `PLAN.md`, per-plan files) into **plain-English narrative** that a non-technical user can understand and react to. Read-only. Two trigger modes:

1. **Standalone** — user invokes `/psd-preview` (whole roadmap) or `/psd-preview [N]` (single phase) for re-viewing.
2. **Auto-gated** — `psd-init` and `psd-plan` invoke this internally as their final step before reporting "done." If the user rejects the preview, the orchestrating skill loops back to revise (max 2 revision rounds).

## Pre-flight (standalone only)
1. `.planning/` must exist — else suggest `/psd-init`.
2. If `[N]` is passed: `.planning/phases/Phase {N}/PLAN.md` should exist (preview phase from PLAN.md). If not, fall back to ROADMAP.md's Phase {N} entry (preview phase from roadmap).

## Subagent dispatch
Spawn `psd-previewer`:

```
You are psd-previewer. Read-only narrative translator.

Mode:
- "all" → narrate the whole ROADMAP.md (every phase)
- "phase N" → narrate just Phase {N}, using PLAN.md if it exists, else ROADMAP.md

Read yourself:
- .planning/PROJECT.md (skim Vision + Stack)
- .planning/ROADMAP.md
- if mode is "phase N" and PLAN.md exists: .planning/phases/Phase {N}/PLAN.md and a quick scan of its plans/*.md (don't read every plan; skim titles + behavior lines)

Read @$HOME/.claude/workflows/preview.md for the protocol.

Process:
1. For each phase in scope, produce a plain-English block (no jargon — no "atomic commits", no "vertical slice", no "wave plan").
2. Emphasize WHAT THE USER WILL BE ABLE TO DO when the phase is done, not what code gets written.
3. Compute a rough size: count atomic plans (or estimate from goal complexity if PLAN.md doesn't exist yet) → "small" (1-5 plans), "medium" (6-10), "large" (11+).
4. Format per the templates below.

Report back the FULL narrative as your response (do NOT abbreviate to <=200 words — this is the user's preview).
```

**Note**: This subagent breaks the usual ≤200-word return rule because the narrative IS the deliverable. Token cost is acceptable: the user is actively reviewing it, and it replaces what would otherwise be reams of jargon they'd skim.

## Output format

### Mode "all" (whole roadmap)
```markdown
# What you'll have when this is done — <Project name>

The big picture: <one sentence from PROJECT.md Vision, rephrased plainly>

---

## Phase 1: <name>
**When this is done:** <plain-English description of user-visible outcome>
**You (or a user) will be able to:**
- <capability>
- <capability>
**Roughly:** <small | medium | large> phase

## Phase 2: <name>
**When this is done:** ...
**You (or a user) will be able to:** ...
**Roughly:** ...

## Phase 3: <name>
...
```

### Mode "phase N" (single phase)
```markdown
# Phase {N}: <name> — preview

**The thing this delivers:** <one paragraph plain English>

**What you (or a user) will be able to do when it's done:**
- <user-visible capability>
- <user-visible capability>

**What's NOT in this phase (intentionally):**
- <thing — pulled from ROADMAP.md success criteria + PLAN.md out-of-scope notes>

**Roughly:** <count> small commits worth of work
```

## Plain-English translation rules

When narrating, replace technical jargon with user-facing equivalents:

| Don't say | Say instead |
|---|---|
| "Scaffold the Next.js app" | "Get a real working website at a real URL" |
| "Implement the auth route" | "People can sign in with their email" |
| "Add a Postgres table for X" | "Save your X stuff so it's still there next time" |
| "Wire up the API endpoint" | "The page can talk to the server to fetch/save things" |
| "Deploy to Vercel preview" | "Get a link you can share with friends to test it" |
| "Add unit tests" | "Make sure it doesn't break when we change other things" |
| "Refactor the data layer" | _(skip — not a user-visible outcome; refactors aren't phase-worthy)_ |

If a phase plan is *only* refactor/infrastructure with no user-visible outcome, flag it: "This phase is technical setup — no new feature. Result: faster/safer changes later." That's a yellow flag the user might want to question.

## Auto-gate behavior (when called from psd-init or psd-plan)

The orchestrator (init or plan skill):
1. Dispatches `psd-previewer` to generate the narrative
2. Shows the narrative to the user verbatim
3. AskUserQuestion: "Does this match what you want?"
   - **Yes, ship it** → orchestrator continues to "done"
   - **Revise — let me change something** → ask what to change (free-text or AskUserQuestion); re-dispatch the relevant write-subagent (`psd-initializer` for roadmap edits, `psd-planner` for phase plan edits) with the revision feedback; loop back to step 1
   - **Abort** → leave artifacts as-is, don't auto-advance state, tell user how to resume manually
4. **Max 2 revision rounds.** On the third "Revise" answer, force the user to choose between "Yes, ship what we have" or "Abort." This prevents infinite loops on indecisive users.

The auto-gate adds 1-3 questions to the user's flow but is the safety net for non-technical users who otherwise wouldn't know to run `/psd-preview` themselves.

## Hard rules
- **Read-only.** Never write any file.
- **No jargon in narrative output.** If you can't translate a technical concept to plain English, leave it out — it probably isn't a user-visible outcome.
- **Don't summarize past 200 words for the standalone mode.** The narrative IS the deliverable; an honest ≤500-word output is fine here.
- **For auto-gate mode**, the orchestrator handles the loop. The previewer just produces the narrative.
- **Refactor-only phases get flagged**, not hidden. The user deserves to know "this phase has no new feature."
