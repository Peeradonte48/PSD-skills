# Workflow: brainstorm

Project-level Socratic ideation BEFORE `init`. Designed for users who **don't fully know what they want to build yet**. Three discipline points:

1. **Anchor by archetype first** when the idea is shallow — give the user concrete options to point at, not abstract questions.
2. **Handle "I don't know" with defaults + tradeoffs**, not by recording it as unknown and moving on.
3. **Reflect mid-flow** — show the user a draft summary around question 4-5 so they can correct misunderstandings before BRAINSTORM.md is written.

Question budget: 7 by default. The user can opt into a "deeper" round if uncertainty is still high after the reflect step.

## Pre-flight gates
1. If `.planning/` already exists → STOP. Suggest `/psd:discuss [N]` instead (project is past brainstorm phase).
2. If `BRAINSTORM.md` already exists at project root → AskUserQuestion: continue/refine | start over | abort.

## Step 1 — Detect shallow vs. specific idea

The agent classifies the user's raw input:
- **Shallow**: < ~20 words OR no specific feature/tech mentioned (e.g. "a tool to track my workouts", "something for my book club")
- **Specific**: longer, names a feature/persona/constraint (e.g. "a Next.js app where my running club logs miles, sees a leaderboard, syncs from Strava")

Shallow input → go to Step 2 (anchor by archetype). Specific input → skip to Step 3 (targeted Q&A).

## Step 2 — Anchor by archetype (shallow input only)

**Single AskUserQuestion call**, header "Archetype". Offer 5 options + "Other":

| Option | One-line description |
|---|---|
| **Personal tool** | Just for you — like a journal or simple log. No accounts, saves to your device or your account only. |
| **Tracker / dashboard** | Record stuff over time and see charts/history. Like a Fitbit dashboard but for your thing. Just you, or a few people you invite. |
| **Content site** | A website to share info or work. Like a blog, docs, link-in-bio, or simple portfolio. Mostly read-only for visitors. |
| **Community / social** | Multiple people sign up, post things, see each other's stuff. Like a small Discord channel or mini-Reddit for your topic. |
| **Marketplace / transaction** | Buyers and sellers, payments. Like a tiny Etsy or Gumroad. |
| **Internal tool / workflow** | A focused tool for a team — admin dashboard, CRM, ops console. Replaces a spreadsheet or Notion page that's grown too messy. |

Once the archetype is locked, **a lot of downstream questions are answered implicitly**:

| Archetype | Implies |
|---|---|
| Personal tool | No auth (or single-user), local persistence, web app |
| Tracker / dashboard | Maybe-auth (1-N users), DB needed, web app |
| Content site | Likely no auth, no/light DB, web app |
| Community / social | Auth required, DB required, web app |
| Marketplace | Auth + DB + payments integration, web app |
| Internal tool | Auth required, DB required, often web app or extension |

Use this map to skip questions whose answers the archetype already implies.

## Step 3 — Targeted adaptive Q&A

Pick from these only as needed (don't ask all of them); group into AskUserQuestion calls where multi-question is supported:

- **Persona** — "Who's the first user? You alone, you + a few friends, strangers on the internet, a team at work?"
- **Smallest useful v1** — "What's the one thing this needs to do, that if it didn't, you'd consider it broken?"
- **Out of scope (deliberately)** — "What features sound related but you do NOT want in v1?"
- **Hard constraints** — "Any deadline, stack you must use, services it must integrate with?"
- **Riskiest assumption** — "What's the thing that, if wrong, makes this whole thing pointless?"

## Step 4 — "I don't know" handler (binding)

**When the user answers "I don't know" or vague (e.g. "maybe?", "not sure"):** do NOT record "unknown" and move on. Instead:

1. Propose 2-3 reasonable defaults with **one-line tradeoffs each**, derived from what's already locked (archetype + prior answers).
2. Re-ask via AskUserQuestion with those as options + "Other / Still not sure".
3. If they pick "Still not sure" again, **pick the safest default for them** (the one that's easiest to change later) and tell them: "I'll go with X for v1; we can revisit in /psd:discuss before planning."

Example:
> Q: "Does it need user accounts in v1?"
> User: "I don't know"
> Agent: "Most apps like yours start without accounts (simpler v1, ship faster) and add login in v2. Which fits?
> A) **No accounts in v1** — simpler, ship faster, add later if you need it
> B) **Accounts in v1** — required if you need per-user data isolation or paid plans
> C) **Still not sure** — I'll default to (A); we can revisit before planning."

This counts as 1 question against the budget, not 2.

## Step 5 — Draft + reflect (mid-flow checkpoint)

After **3-4 questions** (or earlier if you have enough), pause Q&A and write a one-paragraph reflective summary back to the user:

> "Here's what I think you want: a **{archetype}** for **{persona}**, where the core thing is **{smallest useful v1}**, deliberately not including **{out of scope}**. Riskiest assumption: **{assumption}**. Did I get it right?"

Then AskUserQuestion:
- **"Yes, that's right"** → continue to fill remaining gaps (≤2 more questions), then write BRAINSTORM.md
- **"Mostly, with tweaks"** → AskUserQuestion (one open Q + likely tweaks as options): "What should change?" Apply tweaks, then write BRAINSTORM.md
- **"No, restart"** → reset and start from Step 1 with what you've learned. Total questions still capped at 7 (the restart is a hint, not a free reset).

The reflect step costs 1 question against the budget but catches misunderstandings before BRAINSTORM.md is finalized.

## Step 6 — "Keep going?" gate (mandatory after question 7)

Same shape as `discuss`'s extension. After the 7th question is answered (or earlier if you have what you need), **always** issue one final AskUserQuestion before writing BRAINSTORM.md:

```
Header: "Keep going?"
Question: "I have enough to write the brainstorm, but want to dig deeper first?"
Options:
  • "Write what we have" — write BRAINSTORM.md now
  • "Yes — 3 more questions" — gives you 3 more (10 total)
  • "Yes — 5 more questions" — gives you 5 more (12 total; hard cap)
```

Rules:
- The "Keep going?" prompt does NOT count against the budget.
- Hard cap at **12 questions total**. After question 12, force-write BRAINSTORM.md.
- Extension questions follow the same adaptive rules: target unclear dimensions, group via multi-question.

This is mandatory — non-technical users won't think to ask for more on their own. The gate is the only consistent surface that exposes the option.

## Step 7 — Clarification mode (binding throughout the session)

When the user picks "Other" on any AskUserQuestion and their typed text is a **clarification request** rather than an answer, the agent responds with an explanation FIRST, then re-asks the original question.

### Detection signals (any one flips into clarification mode)
- Question mark (`?`) anywhere in the text
- Begins with: "what does", "what's the difference", "what do you mean", "explain", "huh", "I don't understand", "I'm not sure what", "not sure what you mean", "can you explain", "what's an example", "give an example"
- Pure interrogative without an answer

### How the agent responds
1. Write 1-3 plain-English sentences (no jargon) explaining what the question/options mean.
2. If helpful, give a concrete example: "If you picked option A, your v1 would have X. If you picked option B, your v1 would have Y."
3. Re-ask the same question — possibly with refined option labels or one extra option if the clarification revealed a missing case.

### Rules
- Clarification responses do NOT count against the question budget.
- **Cap at 3 clarification rounds per single underlying question.** After 3, pick the safest default with a one-line rationale ("I'll go with X for v1; we can revisit in `/psd:init` or `/psd:discuss`") and continue.
- Log clarifications as nested entries under the parent question in the Q&A log.

### Q&A log format with clarification

```markdown
**Q3:** Does this need user accounts in v1?
  - User clarification: "what does 'user accounts' actually mean for me?"
  - Agent: "It means each person who uses the app has their own login. So if your friends use it, they each see their own data. The alternative is everyone shares one space, which is simpler but means anyone with the link sees everything."
  - User answer: "No accounts in v1"
```

## Step 8 — Final stop conditions

Stop and write BRAINSTORM.md when ANY is true:
- You have archetype + persona + smallest-v1 + 1 out-of-scope item + reflect-confirmed AND user picked "Write what we have" at the gate
- You hit 12 questions (hard cap)
- User explicitly says "just write it" / "good enough" at any point

If you stop with gaps, list them under "Open questions left for /psd:init or /psd:discuss".

## What "adaptive" means (binding)
- Don't ask fixed questions every time. Look at what's already clear vs unclear (use the archetype implication table to skip).
- Group multi-part questions into ONE AskUserQuestion call where multi-question is supported.
- Default budget: **7 questions**, opt-in extension up to **12** via the mandatory "Keep going?" gate.
- Clarifications are free (don't count against the budget) but capped at 3 per underlying question.

## Artifact template

### `BRAINSTORM.md` (project root)
```markdown
# Brainstorm — <project name candidate>

**Date:** <ISO date>
**Status:** ready-for-init

## Raw idea (verbatim from user)
> <one or two sentences from the original prompt>

## Archetype
<personal-tool | tracker-dashboard | content-site | community-social | marketplace | internal-tool | other: <description>>

## Distilled
- **Name:** <kebab-case>
- **Problem:** <1-2 sentences>
- **For whom:** <user persona>
- **Smallest useful v1:** <one paragraph>

## Top requirements (v1)
1. <req>
2. <req>
3. <req>

## Out of scope (v1)
- <item>

## Hard constraints
- <stack / deadline / integration / compliance, or "none">

## Riskiest assumption
<one line — what would make this fail if wrong>

## Defaults applied (when user said "I don't know")
- <field>: defaulted to <value> because <reason>; revisit in /psd:discuss

## Open questions left for /psd:init or /psd:discuss
- <item, or "none">

## Q&A log (for traceability)
**Q1:** <question> → <answer>
**Q2:** <question> → <answer>
...
```

## Hand-off to init
- BRAINSTORM.md sits at project root (NOT inside `.planning/` since that doesn't exist yet)
- When `/psd:init` runs next, it detects BRAINSTORM.md and uses its sections to pre-fill PROJECT.md inputs. User confirms or edits before init writes anything.
- After `init` succeeds, the initializer appends BRAINSTORM.md content as a "## Brainstorm origin" section in PROJECT.md and deletes the standalone file.

## Hard rules
- Never write into `.planning/` (it doesn't exist yet)
- Never run `/psd:init` automatically — only suggest it
- Never exceed **12 questions total** (7 default + opt-in extension up to 5 more via the "Keep going?" gate)
- The "Keep going?" gate after question 7 is **mandatory** — even if you'd otherwise stop
- The reflect step (Step 5) is **not optional** when input was shallow — fuzzy users especially benefit from it
- Clarification responses do NOT count against the budget; cap at 3 clarifications per underlying question
- Q&A log must be verbatim (no editorializing); record clarifications as nested entries; when a default was applied for "I don't know", record both the user's answer AND the chosen default with rationale
