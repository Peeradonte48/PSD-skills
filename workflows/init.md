# Workflow: init

Bootstrap a new project's `.planning/` directory.

## Pre-flight gates
1. If `.planning/` already exists → STOP. Print: "Project already initialized. Use `/psd:resume` to continue or `/psd:new-milestone` to start a new milestone." Do not overwrite.
2. If CWD is not a git repo → ask user (via AskUserQuestion) whether to `git init` first. If they decline, abort.
3. If `BRAINSTORM.md` exists at project root → **pre-fill** inputs from it (see "Brainstorm hand-off" below). Otherwise gather inputs interactively.

## Fields gathered (the agent runs the dialogue, not the orchestrator)

The `initializer` agent runs an adaptive Socratic Q&A and gathers these fields. If BRAINSTORM.md is present, pre-fill from its "Distilled" / "Top requirements" / "Out of scope" / "Hard constraints" sections and only confirm-or-edit; otherwise probe fresh.

- **Project name** — short identifier
- **Problem statement** — 1-3 sentences: what is being built and for whom
- **Top 3 requirements** — must-have capabilities for v1
- **Out of scope** — what v1 explicitly does *not* include
- **App type / persistence / auth** — only when needed to pick a stack (see Stack selection below)
- **Hard constraints** — deadline, must-use stack, services to integrate with — often empty

See "Clarification protocol" below for the dialogue rules (budget, clarification mode, "I don't know" handler, mid-flow reflect, "Keep going?" extension). The orchestrator never gathers these itself — it only gates and dispatches.

## Stack selection (binding step — happens before writing any file)

Designed for non-technical users: the agent should bias toward the **most batteries-included default** for the app type and only ask what's load-bearing.

### Detection first
1. **Existing codebase?** If `package.json`, `requirements.txt`, `Cargo.toml`, `pyproject.toml`, `Gemfile`, etc. exist → infer the stack and confirm with the user (don't reselect from scratch).
2. **Brainstorm hard constraint?** If BRAINSTORM.md's "Hard constraints" specifies a stack/language → honor it; ask only the remaining unknowns.

### If greenfield, adaptive Q&A (max 3 questions)
Pick from these only as needed; don't ask all of them:

- **App type:** Web app | Mobile app | CLI / script | API only | Browser extension | Desktop app
- **Persistence:** None / stateless | Local only (browser/disk) | Server database | File uploads
- **Auth/login:** No | Email-password | Social (Google/GitHub) | Magic links

### Default recommendations (presented to user with rationale; user can override)

| App type + needs | Recommendation |
|---|---|
| Web app + DB + auth | Next.js 16 App Router + TypeScript + Tailwind + shadcn/ui + Vercel + Supabase |
| Web app + DB only | Next.js + Tailwind + shadcn/ui + Vercel + Supabase |
| Web app + static (no DB) | Next.js + Tailwind + Vercel |
| Mobile app | Expo (React Native) + TypeScript |
| CLI / script | Node + TypeScript (preferred) or Python (if user prefers) |
| API only | Hono on Vercel Functions, or FastAPI on Vercel |
| Browser extension | WXT framework + TypeScript |
| Desktop app | Tauri + TypeScript |

The defaults bias toward Vercel-ecosystem because they minimize ops setup for non-technical users (zero-config deploys, managed DB, free tier). User can override.

### Output
The chosen stack goes into `.planning/PROJECT.md` under a `## Stack` section (template below). The planner reads this and uses the chosen tools, conventions, and idioms. The roadmap should be written **with the stack in mind** — e.g., for a Next.js project, Phase 1 is typically "scaffold app + happy-path route + deploy preview."

## Clarification protocol (binding)

The `initializer` agent runs the dialogue with the user. These rules mirror the brainstormer/discusser pattern so a fuzzy user gets the same Socratic feel everywhere in the suite.

### Adaptive Q&A budget
- **Default budget: 7 questions.** Target only fields that aren't already pre-filled by BRAINSTORM.md or detected codebase.
- Group multi-part questions into one `AskUserQuestion` call where supported.
- Each question: 2-4 options + free-form "Other".
- Don't waste questions on signals you already have — e.g., a detected `package.json` answers App Type; a BRAINSTORM.md "Hard constraints" line answers stack pre-emptively.

### Clarification mode (when "Other" is a question, not an answer)
If the user's "Other" text is a clarification request — detect via `?`, "what does", "what's the difference", "what do you mean", "explain", "I don't understand", "I'm not sure what", "huh", "give me an example" — the agent's NEXT response is to:
1. Explain the question / options in 1-3 plain-English sentences (no jargon).
2. Give a concrete example: "If you picked A, v1 would have X. If you picked B, Y."
3. Re-ask the SAME question, refining option wording if a missing case was revealed.

Clarifications do **NOT** count against the budget. Cap at 3 clarifications per underlying question — after 3, the agent picks the safest default with a one-line rationale and continues.

### "I don't know" handler
When a user answer is "I don't know" or vague:
1. Propose 2-3 reasonable defaults with one-line tradeoffs (derived from BRAINSTORM.md context, detected codebase, prior answers).
2. Re-ask with those as options + "Still not sure".
3. If "Still not sure" again, pick the safest default (most reversible) and tell the user: "I'll go with X for v1; we can revisit in `/psd:discuss` before planning."
4. Record both the IDK and the default applied (with reason) in PROJECT.md's "## Defaults applied" section.

This counts as **1 question** against the budget, not 2. Cap at 3 IDK rounds per underlying question.

### Mid-flow reflect (binding when shallow)
Trigger when EITHER: BRAINSTORM.md is absent AND the user's first answers are short (< ~20 words combined) OR an "I don't know" handler has already fired.

After 3-4 questions, the agent pauses Q&A and writes a one-paragraph reflective summary:

> "Here's what I think you want: a **{app type}** for **{persona / first user}**, where the core thing is **{smallest useful v1}**, deliberately not including **{out of scope}**. Recommended stack: **{stack}**. Did I get it right?"

`AskUserQuestion`: "Yes, that's right" / "Mostly, with tweaks" / "No, restart". Costs 1 question against the budget.

### "Keep going?" gate (mandatory after question 7)
After Q7 — even if the agent already has enough — issue one final `AskUserQuestion`:

```
Header: "Keep going?"
Question: "I have enough to set up the project, but want to dig deeper first?"
Options:
  • "Set it up now"
  • "Yes — 3 more questions"
  • "Yes — 5 more questions"
```

The gate itself does NOT count against the budget. Hard cap at **12 questions total**. After Q12, force-confirm-and-write regardless of clarity.

### Q&A log destination
After files are written, the agent appends two sections to `.planning/PROJECT.md`:
- `## Init Q&A log` — verbatim Q&A, with clarifications as nested entries.
- `## Defaults applied` — every IDK → chosen default with reason. Omit the heading if no defaults were applied.

The planner reads these for traceability without re-asking.

## Subagent dispatch
Spawn `initializer` with **only the cwd** (and `revision_feedback` when looping). The agent reads BRAINSTORM.md itself and runs the dialogue. Brief format:

```
You are initializer. Bootstrap a project's .planning/ directory.

Inputs:
- cwd: <pwd>
- revision_feedback: <string, only present in revision mode>

Read @$HOME/.claude/workflows/init.md for the full spec, including the Clarification protocol you must follow.

Tasks:
1. Run the adaptive Q&A (3-7 questions, opt-in extension to 12), with clarification, IDK defaults, and mid-flow reflect per the protocol.
2. Write .planning/PROJECT.md (vision, problem, requirements, out-of-scope, Stack, Init Q&A log, Defaults applied if any)
3. Write .planning/ROADMAP.md (3-6 phases, each with Goal + Success Criteria)
4. Write .planning/STATE.md (milestone v1, active phase: 1, no decisions yet)
5. Write .planning/CHECKPOINT.md (header only)
6. Write the 4 cross-AI handoff files at project root (AGENTS.md, CLAUDE.md, .github/pull_request_template.md, .gitattributes).

Report back in <=200 words: phase count, phase 1 goal, Q&A count, defaults applied count, anything ambiguous.
```

## Artifact templates

### `.planning/PROJECT.md`
```markdown
# <name>

## Problem
<problem statement>

## Vision (v1)
<one paragraph of what success looks like>

## Requirements (v1)
- <req 1>
- <req 2>
- <req 3>

## Out of scope (v1)
- <item>

## Stack
- **Type:** <web app | mobile | cli | api | extension | desktop>
- **Language:** <TypeScript | Python | ...>
- **Framework:** <Next.js 16 | Expo | Hono | FastAPI | ...>
- **UI library:** <Tailwind + shadcn/ui | n/a>
- **Hosting:** <Vercel | n/a>
- **Database:** <Supabase Postgres | none | ...>
- **Auth:** <Supabase Auth | none | ...>
- **Why this stack:** <one sentence — usually "minimal setup for the app type and the user's experience level">
- **Required CLIs:** <e.g., node 22+, vercel, supabase> (doctor or first-run will check these)

## Decisions log
<append-only as decisions are made>
```

### `.planning/ROADMAP.md`
```markdown
# Roadmap — Milestone v1

## Phase 1: <name>
**Goal:** <one sentence>
**Success criteria:**
- [ ] <criterion>
- [ ] <criterion>

## Phase 2: <name>
...
```

Phases should be **vertical slices** when possible (one feature end-to-end), 3-6 phases per milestone, sized so each fits in ~5-15 atomic plans.

### `.planning/STATE.md`
```markdown
# State

- milestone: v1
- active_phase: 1
- last_completed_phase: none
- last_skill: init
- updated: <ISO timestamp>

## Recent decisions
(none yet)
```

### `.planning/CHECKPOINT.md`
```markdown
# Checkpoint log

(appended by hooks; one line per event; trimmed to last 15 entries)
```

Entries are written by `hooks/psd-checkpoint.sh` as a single line each:
`## <timestamp>  <event>:<tool>  <clean|dirty:N>`. Consecutive same-event runs
collapse into a `ts1..ts2` range, so an Edit×8 burst is one entry, not eight.
Consumers (resumer, debugger) should `tail -10 .planning/CHECKPOINT.md`
via Bash rather than `Read` the whole file — the format is line-oriented and
the agent only ever needs the most recent ~5 entries.

## Cross-AI handoff files (project root, NOT under `.planning/`)

These files exist so any AI (Codex, bare Claude Code without PSD, Cursor) or human reviewer can pick up the project without needing PSD installed.

### `AGENTS.md` (canonical)
```markdown
# <project name> — Agent guide

> Any AI (or human) reading this for the first time: this file is your starting point. The full project plan lives in `.planning/`. You don't need PSD skills to continue work — see "Resume without PSD" at the bottom.

## What this is
<one paragraph from PROJECT.md "Vision" + "Problem">

## Stack
<copied from PROJECT.md "Stack" section>

## Conventions
- **Atomic commits.** One commit per logical change. Format: `<scope>: <imperative summary>`.
- **Phase structure.** Work is grouped into Phases (see `.planning/ROADMAP.md`). Each phase has atomic plans in `.planning/phases/Phase {N}/plans/{N}-NN.md`.
- **Verify before ship.** Every phase must produce a `VERIFICATION.md` with `Result: PASS` before being shipped.
- **Don't `git add -A`.** Stage only the files in your current plan's `files:` frontmatter.
- **Don't amend or force-push.** Make new commits.

## Where to look
| If you want to... | Read |
|---|---|
| Understand the goal of v1 | `.planning/PROJECT.md` |
| See the phase list | `.planning/ROADMAP.md` |
| Know what's currently in flight | the "Current state" block below |
| Read the active phase plan | `.planning/phases/Phase {N}/PLAN.md` |
| See per-task specs | `.planning/phases/Phase {N}/plans/*.md` |
| See verification status | `.planning/phases/Phase {N}/VERIFICATION.md` |

<!-- AUTO:CURRENT_STATE -->
## Current state (auto-updated — do not hand-edit)

**Last update:** <ISO timestamp>
**Milestone:** v1
**Active phase:** 1
**Last skill run:** init
**Last commit:** -
**Working tree:** clean

**Recent activity (last 5 hook entries):**
- (none yet)
<!-- /AUTO:CURRENT_STATE -->

## Resume without PSD installed

If you're an AI agent without the PSD skills (e.g. bare Claude Code, Codex, Cursor), here's the protocol — do not attempt to install PSD; just follow these steps:

1. Read `.planning/STATE.md`. Note `active_phase` and `last_skill`.
2. Read `.planning/phases/Phase {active_phase}/PLAN.md` for the current goal and atomic plan list.
3. Run `git log --oneline -20` to see which atomic plans have already been committed (commit messages match plan titles).
4. Pick the next uncommitted plan in PLAN.md's wave plan and read `.planning/phases/Phase {active_phase}/plans/{N}-NN.md`.
5. Implement only that plan. Touch only files in its `files:` frontmatter. Commit with the plan's `Commit message` field.
6. Repeat until all plans in the phase are committed, then ask the human to run `/psd:verify` (or do a manual checklist against `PLAN.md` success criteria).

If `VERIFICATION.md` exists with `Result: FAIL` or `PARTIAL`: do NOT ship. The human (or someone with PSD) needs to run the failure-replanning loop.

## How PSD users continue this work

Run `/psd:resume` for a structured "where you left off" summary. It will recommend the next skill to run.
```

### `CLAUDE.md` (stub)
```markdown
# Claude Code instructions

See [AGENTS.md](./AGENTS.md) for full project context, conventions, current state, and the resume protocol.
```

(A one-line `@AGENTS.md` reference works too if your Claude Code version resolves it; we ship the prose stub for portability.)

### `.github/pull_request_template.md`
```markdown
## Summary
<one-paragraph description>

## Phase / Plans landed
- Phase: <N — name from ROADMAP.md>
- Plans: <comma-separated IDs>

## Verification
- Result: <PASS | PARTIAL | FAIL>
- Details: `.planning/phases/Phase <N>/VERIFICATION.md`

## Notes for reviewers
- Project plan: `.planning/PROJECT.md`
- Phase plan: `.planning/phases/Phase <N>/PLAN.md`
- Current state for any AI continuing work: `AGENTS.md`

## Test plan
- [ ] <how to verify locally>
```

### `.gitattributes` (append, don't overwrite)
```
AGENTS.md merge=union
```

This keeps cross-team merges of AGENTS.md's auto-block painless. If `.gitattributes` already exists, append the line idempotently.

## Brainstorm hand-off (when BRAINSTORM.md is present)
1. Read BRAINSTORM.md from project root.
2. Pre-fill the AskUserQuestion options from its sections; user confirms or edits.
3. After successfully writing PROJECT.md, the subagent appends BRAINSTORM.md content as a `## Brainstorm origin` section at the bottom of PROJECT.md (preserves the trace).
4. Then `rm BRAINSTORM.md` (or `git rm` if already tracked) so it's not duplicated. The Q&A log lives forever inside PROJECT.md.

## Auto-preview + approval gate (final step before reporting "done")

After all files are written, the orchestrator runs an automatic preview-and-approval loop. This is the safety net for fuzzy users who otherwise wouldn't know to run `/psd:preview`.

**Loop (max 2 revision rounds):**

1. Dispatch `previewer` in mode `"all"` to generate a plain-English narrative of the just-written ROADMAP.md.
2. Show the narrative to the user verbatim.
3. AskUserQuestion: "Does this match what you want?"
   - **Yes, ship it** → proceed to "done" reporting
   - **Revise — change something** → ask what to change (free-text or structured AskUserQuestion); re-dispatch `initializer` with revision feedback to amend ROADMAP.md (and PROJECT.md if needed); loop back to step 1
   - **Abort** → leave artifacts as-is, do NOT continue, tell user the files are written but uncommitted/unconfirmed
4. **After 2 revision rounds**, the third "Revise" answer becomes a forced choice between "Yes, ship what we have" and "Abort" — no more revision loops.

The previewer is read-only; the initializer is the one that re-writes ROADMAP.md on revisions. Each revision counts against the question budget perceptually but doesn't cap the loop except via the 2-round limit.

## Post-conditions
- `.planning/` exists with 4 files above
- `PROJECT.md` contains an `## Init Q&A log` section with verbatim Q&A entries (and a `## Defaults applied` section if any IDK rounds fired)
- Project root has `AGENTS.md` (with sentinel markers + initial Current state block), `CLAUDE.md` stub, `.github/pull_request_template.md`, and `.gitattributes` containing `AGENTS.md merge=union`
- If BRAINSTORM.md was present: it's been merged into PROJECT.md (after the Q&A log) and removed from project root
- `STATE.md` shows active_phase=1, last_skill=init
- The user has been shown a plain-English preview of the roadmap and either approved it or explicitly aborted (no silent completion)
- Main context only sees the subagent's ≤200-word summary (Q&A and preview narrative are shown to the user but not retained in main context)

## Failure modes
- If subagent fails to write any file, report which one and stop. Do not retry blindly.
- If user provides empty answers, prompt them again (one re-ask max), else abort with a clear message.
- If BRAINSTORM.md is malformed, fall back to fresh interactive input and tell the user.
