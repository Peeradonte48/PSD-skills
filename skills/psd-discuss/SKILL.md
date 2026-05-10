---
name: psd-discuss
description: Per-phase Socratic clarification BEFORE /psd-plan. Adaptive 3-7 questions, writes phases/Phase N/CONTEXT.md.
argument-hint: "[phase]"
allowed-tools:
  - Read
  - Write
  - Bash
  - Task
  - AskUserQuestion
---

<objective>
Capture phase-level decisions, constraints, and edge-case handling BEFORE planning. Adaptive Q&A — 3-7 targeted questions on what's unclear about the phase. Output: `phases/Phase {N}/CONTEXT.md` consumed by `psd-plan`.

Orchestrator role: validate state, resolve phase number, gate against accidental overwrite, dispatch `psd-discusser`, surface result.
</objective>

<execution_context>
@$HOME/.claude/workflows/discuss.md
</execution_context>

<process>
1. **Pre-flight gates** (per workflows/discuss.md):
   - `.planning/STATE.md` must exist; else suggest `/psd-init`.
   - Resolve phase number from `$ARGUMENTS` or `STATE.active_phase`.
   - Phase {N} must exist in ROADMAP.md.
   - If `phases/Phase {N}/CONTEXT.md` exists → AskUserQuestion: continue/refine | overwrite | abort.

2. **Companion check (suggestion mode):** look at PROJECT.md's Stack section and Phase {N}'s goal in ROADMAP.md.
   - If goal/Stack mentions AI/LLM/agent/embedding/RAG AND `gsd-ai-integration-phase` is in the available-skills list, print:
     > FYI: `gsd-ai-integration-phase` is also available — produces a heavier AI-SPEC contract with full eval rigor. Run it directly for AI-critical phases; otherwise continuing with `psd-discuss` (lightweight AI-SPEC.md).
   - If goal mentions page/screen/layout/design/UX AND `gsd-ui-phase` is in the available-skills list, print:
     > FYI: `gsd-ui-phase` is also available — produces a heavier UI-SPEC design contract. Run it directly for design-heavy phases; otherwise continuing with `psd-discuss` (lightweight UI-SPEC.md).
   - If both apply, print both. If neither, skip silently.

3. **Dispatch `psd-discusser`** with the phase number. The discusser owns all UAT-style AskUserQuestion calls.

4. **Report** the discusser's ≤200-word summary verbatim. Suggest `/psd-plan {N}` (which will read CONTEXT.md if present).

Preserve all gates: never run `/psd-plan` automatically, never exceed 12 questions (default 7 + opt-in extension), never fabricate decisions, never auto-delegate to companion (suggestion only).
</process>
