# Workflow: research (sub-step, not a user-facing skill)

Library/API/pattern research that runs **before** `plan` when the planner detects a knowledge gap. Produces `.planning/phases/Phase {N}/RESEARCH.md` consumed by the planner.

This is **not** a user-facing skill. There is no `/research` slash command. The research happens automatically as a sub-step of `/psd:plan` when triggered.

## Trigger conditions (any one fires the researcher)

The planner runs this decision before producing PLAN.md:

1. **`--research` flag passed.** User explicitly asked for research.
2. **`--deep` flag passed.** User asked for thorough research (raises caps — see "Deep mode" below).
3. **`phases/Phase {N}/CONTEXT.md` has a "research needed: <topic>" line** (case-insensitive). The discusser writes this when the user surfaces an unknown.
4. **Planner detects an unfamiliar library/API in the Stack or Phase goal.** Specifically: PROJECT.md "Stack" section names a library and Phase {N}'s success criteria reference behavior the planner can't confidently produce from training (e.g., Next.js 16 cache components, Vercel AI SDK v6, Supabase Auth callback paths, Stripe webhook signature verification, Anthropic Files API, etc.).

## Default and deep modes

PSD's accuracy-first defaults raised the research depth from earlier "lean" caps:

| Cap | Default | `--deep` mode |
|---|---|---|
| Fetches per target | 5 | 8 |
| Per-target section length | 120 lines | 200 lines |
| Total RESEARCH.md cap | 500 lines | 700 lines |

Default cross-references: primary docs + at least one secondary source (GitHub issue, blog post, or official example).
`--deep` cross-references: primary docs + GitHub issues + blog posts + at least one canonical example per target.

Use `--deep` when the phase touches a complex new framework or an integration where small mistakes are expensive (auth, payments, AI guardrails). Default is good for most research needs.

## Skip conditions (any one skips research, even when triggered)

1. **`phases/Phase {N}/RESEARCH.md` already exists.** Researcher's output is cached; reuse unless `--research` was passed (which forces re-research).
2. The planner is in `--from-failure` mode and the failure isn't research-related (it's a logic bug, not a missing-knowledge bug).

## Subagent dispatch
Spawn `researcher`:

```
You are researcher for Phase {N}.

Read yourself:
- .planning/PROJECT.md (Stack section + Vision)
- .planning/ROADMAP.md (Phase {N} only)
- .planning/phases/Phase {N}/CONTEXT.md (if exists — pull "research needed:" lines)
- triggering reason: <flag | CONTEXT.md flag | auto-detect>

Identify 1-5 research targets — specific named libraries, APIs, or patterns. Don't research broadly; research surgically. Examples of good targets:
  - "Next.js 16 server actions: how to handle progressive enhancement"
  - "Supabase Auth: the OAuth callback URL convention for Next.js App Router"
  - "Stripe webhooks: signature verification in Node.js 24"
  - "Vercel AI SDK v6: streamText with tool calling"

Bad targets (too broad):
  - "How does Next.js work" — train on docs first, ask the planner
  - "Best practices for web apps" — meaningless

For each target, in priority order:
  1. Try Context7 first (mcp__context7__*) — best for current library docs
  2. Fall back to WebFetch for specific URLs (when user gave one, or when official docs are at a known URL)
  3. Fall back to WebSearch for queries (last resort — slower, less reliable)

Read @$HOME/.claude/workflows/research.md.

Write phases/Phase {N}/RESEARCH.md per the template. Cap at ~300 lines total. Each target's section ≤80 lines.

Report back in <=200 words: target list, top finding per target, suggested next: /psd:plan {N}.
```

## Artifact template

### `.planning/phases/Phase {N}/RESEARCH.md`
```markdown
# Phase {N} — Research

**Date:** <ISO>
**Triggered by:** <flag | CONTEXT.md | auto-detect>
**Targets:**
- <target 1>
- <target 2>

---

## <Target 1: e.g., "Next.js 16 server actions">

**Why this matters for Phase {N}:** <one-line connection to phase goal>

**Key patterns:**
- <pattern> — <one-line explanation>
- <pattern>

**Code shape (illustrative, not copy-paste):**
```ts
// minimal example showing the canonical shape
```

**Gotchas:**
- <pitfall>

**Source:** <Context7 lib name + version | URL | "WebSearch query: ...">

---

## <Target 2: ...>
...

---

## Guidance for the planner

One-line directives the planner should reflect in atomic plans:
- <e.g., "Use server actions for form submissions, not API routes">
- <e.g., "The Supabase OAuth callback must be /auth/callback (matched in middleware)">
- <e.g., "Stripe webhook signature verification requires the RAW body — don't use express.json() middleware">
```

## Planner behavior with RESEARCH.md present

The planner adds RESEARCH.md to its read list. Treat its "Guidance for the planner" section as **binding constraints** when writing atomic plans (same precedence as CONTEXT.md's "Decisions" section).

## Hard rules
- **Surgical, not broad.** 1-5 specific named targets. Reject vague targets like "best practices" or "how to design X".
- **Cite sources.** Every section includes a Source line — Context7 lib version, specific URL, or WebSearch query. No unsourced claims.
- **Cap at ~300 lines total.** Researcher is meant to inform a planner, not replace docs. Long research reports indicate the targets were too broad; split or trim.
- **Idempotent.** If RESEARCH.md already exists, skip unless `--research` was forced.
- **No code generation.** Code examples are illustrative shape, not implementation. The planner produces atomic plans; the executor produces actual code.
- **Token-aware.** Research is the most expensive sub-step (web fetches). Trigger only when needed; reuse RESEARCH.md across phases when the targets overlap.
