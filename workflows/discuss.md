# Workflow: psd-discuss

Per-phase clarification BEFORE `/psd-plan {N}`. Adaptive 3-7 question dialogue that captures decisions, constraints, and edge cases — written to `phases/Phase {N}/CONTEXT.md` for the planner to consume.

## Pre-flight gates
1. `.planning/STATE.md` must exist — else suggest `/psd-init`.
2. Resolve phase number: if `$ARGUMENTS` empty, read `STATE.active_phase`; else use the int passed.
3. Phase {N} must exist in ROADMAP.md.
4. If `phases/Phase {N}/CONTEXT.md` already exists → AskUserQuestion: continue/refine | overwrite | abort.

## Subagent dispatch
Spawn `psd-discusser`:

```
You are psd-discusser for Phase {N}.

Read yourself:
- .planning/PROJECT.md (skim — top of file is enough)
- .planning/ROADMAP.md → focus on Phase {N} section
- .planning/STATE.md (recent decisions)
- existing phases/Phase {N}/CONTEXT.md (if continuing)
- a brief look at the touch-point files (Glob/Grep, ≤5 reads)

Read @$HOME/.claude/workflows/discuss.md for the protocol.

Tasks:
1. Identify what's unclear about Phase {N}: behavior gaps, dependencies, edge cases, success metric.
2. Ask 3-7 ADAPTIVE questions via AskUserQuestion targeting only the unclear dimensions.
3. Stop when you have enough to feed psd-planner — typically: scope edges, hard constraints, dependency on other phases, edge cases worth handling, edge cases explicitly punted.
4. Write phases/Phase {N}/CONTEXT.md per template below.

Report back in <=200 words: distilled decisions + suggested /psd-plan {N}.
```

## What "adaptive" means (binding, same as brainstorm)
- Questions target unclear dimensions, not a fixed checklist.
- Group multi-part questions into one AskUserQuestion call where possible.
- **Default budget: 7 questions.** User can opt into extension (see "Extension mode" below) for up to 12 total.
- If the user gives "I don't know" repeatedly, record it as such and continue — don't stall.

## Extension mode (binding when triggered)

After the 7th question is answered (or earlier if the agent has run out of unclear dimensions), the agent **always** asks one final AskUserQuestion before writing CONTEXT.md:

```
Header: "Keep going?"
Question: "I have enough to write the context, but want to dig deeper first?"
Options:
  • "Write what we have" — agent writes CONTEXT.md now
  • "Yes — 3 more questions" — agent gets 3 more (10 total budget)
  • "Yes — 5 more questions" — agent gets 5 more (12 total budget; hard cap)
```

Rules:
- The "Keep going?" prompt itself does NOT count against the budget — it's metadata.
- Hard cap at **12 questions total**. After question 12, force-write CONTEXT.md regardless of clarity.
- Extension questions follow the same adaptive rules: target unclear dimensions, group via multi-question AskUserQuestion, no fixed checklist.
- If the user previously hit the AI/UI auto-detection trigger and got 3-5 extra spec questions, those count against the standard 7-budget; extension is on top of that.

Why mandatory: a non-technical user often doesn't know they need more questions until they're invited to consider it. The "Keep going?" gate is the only consistent surface that exposes the option.

## Clarification mode (binding)

When the user selects "Other" on any AskUserQuestion and their typed text is a **clarification request** rather than an answer, the agent responds with an explanation FIRST, then re-asks the original question.

### Detection signals (any one of these flips the response into clarification mode)
- The user's text contains a question mark (`?`)
- It begins with: "what does", "what's the difference", "what do you mean", "explain", "huh", "I don't understand", "I'm not sure what", "not sure what you mean", "can you explain", "what's an example"
- It ends in `?`
- The text is purely interrogative without giving an answer

### How the agent responds to clarification
1. Write a 1-3 sentence plain-English explanation of what the question means or what the options would imply in practice.
2. If helpful, give a concrete example: "For instance, if you picked option A, the v1 would have X. If you picked option B, the v1 would have Y."
3. Re-ask the **same** question (same AskUserQuestion call shape), possibly with refined option labels or one extra option if the user's clarification revealed a missing case.

### Rules
- Clarification responses **do NOT count against the question budget.**
- **Cap at 3 clarification rounds per single underlying question** — if the user is still confused after 3 explanations, the agent picks the safest default with a one-line rationale ("I'll go with X for v1; we can revisit in psd-plan if it doesn't fit") and continues. The user's "I don't know what to pick" answer is logged in the Q&A log for traceability.
- Clarifications are logged in CONTEXT.md's Q&A log as nested entries under the parent question.

### Q&A log format with clarification

```markdown
**Q3:** Does Phase 2 need server-side rendering for SEO?
  - User clarification: "what does server-side rendering mean?"
  - Agent: "It means the HTML is generated on the server when someone visits a page. This makes Google index your site better. The alternative is client-side rendering, where JavaScript builds the page in the user's browser — works fine for app dashboards but not great for marketing pages."
  - User answer: "Yes, server-side"
```

This is mostly seen by the user in the conversation; CONTEXT.md preserves the trace.

## Common dimensions to probe (when unclear)
- **Scope edges** — what's IN this phase but borderline? what's deliberately punted?
- **Dependencies** — does this depend on a prior phase, an external service, a file we haven't read?
- **Behavior on edge cases** — empty state, error state, concurrent access, network failure
- **Success metric** — how do we know it's working in production (not just tests)?
- **Performance / scale assumptions** — N items, P95 latency target, anything sensitive?
- **UX patterns to match** — existing project style we should mirror?
- **Risk** — what's the riskiest part? Should we de-risk early in the phase?

## Artifact template

### `phases/Phase {N}/CONTEXT.md`
```markdown
# Phase {N} Context

**Date:** <ISO date>
**Status:** ready-for-plan

## Phase recap (from ROADMAP.md)
**Goal:** <one sentence>
**Success criteria:**
- <criterion>
- <criterion>

## Decisions
- **<topic>:** <what was decided> — *why:* <one-line rationale>
- **<topic>:** <decision> — *why:* <rationale>

## Hard constraints (must-honor)
- <constraint>

## Edge cases to handle
- <case>

## Edge cases punted (explicitly NOT in scope)
- <case>

## Dependencies & touch points
- depends on: <phase ID, file, external service>
- modifies: <files / modules>

## Open questions for planner
- <or "none">

## Q&A log (for traceability)
**Q1:** <question> → <answer>
**Q2:** <question> → <answer>
...
```

## Auto-detected spec contracts (AI / UI phases)

The discusser **also** detects whether this phase is AI-heavy or UI-heavy, and writes a lightweight spec contract alongside CONTEXT.md when appropriate.

### Detection rules
- **AI phase** if ANY of:
  - PROJECT.md "Stack" section names an AI SDK / LLM provider (Anthropic, OpenAI, Vercel AI SDK, LangChain, Ollama, etc.)
  - Phase {N}'s goal in ROADMAP.md mentions: agent, chatbot, completion, embedding, LLM, prompt, RAG, vector
  - User answer in discuss surfaces AI behavior (e.g., "the model decides X")

- **UI phase** if ANY of:
  - Phase {N}'s goal mentions: page, screen, layout, dashboard, form, design, component, frontend, UX
  - Stack includes a frontend framework (Next.js, React, Vue, Svelte, Expo)
  - User explicitly says it's a UI-focused phase

A phase can be both (an AI-driven UI phase). Write both specs.

### Extra questions when an AI phase is detected (3-5, adaptive)
- "What's the eval criterion that decides 'good enough'? (E.g., 90% of test queries return relevant results, no harmful outputs over 100 trials)"
- "What's the latency budget? (User-perceived response time)"
- "What guardrails are required? (Rate limit, content filter, jailbreak resistance)"
- "What's the failure behavior? (Empty result, fallback model, error message)"
- "What's the cost ceiling per query / per day?"

### Extra questions when a UI phase is detected (3-5, adaptive)
- "What's the primary device? (Desktop, mobile, both — and which is priority)"
- "What component library? (shadcn/ui, MUI, custom, none — pull default from PROJECT.md Stack)"
- "What states must each interactive element handle? (Default / hover / focus / disabled / loading / error / empty / success)"
- "Light/dark mode required for v1, or just one?"
- "Any accessibility floor? (WCAG AA is a sensible default unless told otherwise)"

These are added to the standard adaptive Q&A, sharing the 7-question budget. Don't ask all five if the user's prior answers imply some.

## Spec artifact templates (lightweight — NOT exhaustive)

### `phases/Phase {N}/AI-SPEC.md`
```markdown
# Phase {N} AI Spec

**Date:** <ISO>

## Goal (AI-specific)
<one sentence: what should the model accomplish for the user>

## Eval criterion
<one specific, measurable criterion: e.g., "90% of 50 test queries return a result the user marks 'helpful'">

## Latency budget
- p50: <e.g., 2s>
- p95: <e.g., 5s>
- timeout: <e.g., 15s>

## Guardrails
- <e.g., refuse off-topic requests>
- <e.g., rate limit 10/user/min>
- <e.g., jailbreak resistance: refuse system-prompt-leak attempts>

## Failure behavior
- <e.g., on model error: show "couldn't generate, try again" not raw error>
- <e.g., on empty result: show "no results — try rephrasing">

## Cost ceiling
- per query: <e.g., $0.02 max>
- per day total: <e.g., $5 budget alert>

## Test prompts (optional)
- <prompt> → expected behavior
- <prompt> → expected behavior
```

### `phases/Phase {N}/UI-SPEC.md`
```markdown
# Phase {N} UI Spec

**Date:** <ISO>

## Goal (UI-specific)
<one sentence: what user-facing surface this phase delivers>

## Devices
- Primary: <desktop | mobile>
- Secondary: <if any>

## Components used
- <component name> (from <library>) — for <purpose>

## States to handle (per interactive element)
For each form/button/list:
- Default
- Hover (desktop only)
- Focus (keyboard)
- Disabled
- Loading
- Error
- Empty (for lists/tables)
- Success / confirmation

## Theme
- Light mode: <required | nice-to-have | not-yet>
- Dark mode: <required | nice-to-have | not-yet>

## Accessibility floor
WCAG <AA | A>: keyboard-navigable, focus-visible, sufficient contrast, alt text on images.

## Reference
- Existing component this should match style with: <path or "n/a">
```

## Hand-off to psd-plan
- `psd-plan` reads CONTEXT.md; if present, `psd-planner` treats Decisions and Hard constraints as **binding**.
- `psd-plan` ALSO reads `AI-SPEC.md` and/or `UI-SPEC.md` if they exist; the planner treats spec criteria as binding (every plan that touches AI/UI must reflect the relevant spec).
- The reviewer (`psd-review`) checks plans against AI-SPEC / UI-SPEC criteria.
- If CONTEXT.md is missing, `psd-plan` proceeds anyway (discuss is optional).

## Hard rules
- Never write source code or plan files
- Never run `/psd-plan` yourself — only suggest it
- Never exceed 7 questions
- Never fabricate decisions; record what the user actually said
- Q&A log entries must be verbatim
