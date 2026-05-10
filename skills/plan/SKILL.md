---
name: plan
description: Decompose a phase into atomic plans (one commit each). Writes PLAN.md and per-plan files.
argument-hint: "[phase] [--from-failure] [--research] [--deep] [--no-research] [--no-peer-review]"
allowed-tools:
  - Read
  - Write
  - Bash
  - Task
  - AskUserQuestion
---

<objective>
Plan one phase of the active milestone by decomposing it into atomic plans. Each plan = one commit's worth of work, with frontmatter and test criteria.

Orchestrator role: validate state, resolve phase number, gate against accidental overwrite, dispatch `planner`, summarize result.
</objective>

<execution_context>
@$HOME/.claude/workflows/plan.md
</execution_context>

<process>
1. **Pre-flight gates** (per workflows/plan.md):
   - `.planning/STATE.md` must exist; else suggest `/psd:init`.
   - Resolve phase number: if `$ARGUMENTS` empty, read `STATE.active_phase`; else use the int passed.
   - If `phases/Phase {N}/PLAN.md` already exists → AskUserQuestion: overwrite | append | abort.

2. **Companion check (suggestion mode):** look at PROJECT.md's Stack section and Phase {N}'s goal.
   - If AI keywords (LLM/agent/embedding/RAG) AND `gsd-ai-integration-phase` is in the available-skills list, print:
     > FYI: `gsd-ai-integration-phase` is also available — heavier AI-SPEC + eval planner. Run it directly before this `/psd:plan` if you need AI-critical rigor; otherwise continuing.
   - If UI keywords (page/screen/layout/design) AND `gsd-ui-phase` is in the available-skills list, print:
     > FYI: `gsd-ui-phase` is also available — heavier UI-SPEC contract. Run it directly before this `/psd:plan` for design-heavy phases; otherwise continuing.
   - Skip silently if neither applies.

3. **Dispatch `planner`** with the phase number and any flags. Default behavior (accuracy-first):
   - **Research fires by default** (5 fetches/target, 500-line RESEARCH.md cap). Skip with `--no-research`. Force re-research with `--research`. Deep mode (8 fetches/target, 700-line cap) with `--deep`.
   - **Plan-checker always runs** (deterministic, no LLM cost). Cannot be opted out.
   - **Peer-review fires by default**. Skip with `--no-peer-review`.
   - `--from-failure`: re-plan only the deltas from VERIFICATION.md failures (skips research and peer-review unless explicitly flagged).

3. **Report** the planner's ≤200-word summary verbatim. Suggest `/psd:execute {N}` next.

Preserve all gates: planner must produce real atomic plans (not "TODO" placeholders) — if the report says 0 plans + ambiguity, surface that and stop, don't auto-retry.
</process>
