---
name: brainstorm
description: Project-level Socratic ideation BEFORE /psd:init. Adaptive 3-7 question dialogue, writes BRAINSTORM.md.
argument-hint: "[free-form idea]"
allowed-tools:
  - Read
  - Write
  - Bash
  - Task
  - AskUserQuestion
---

<objective>
Distill a fuzzy project idea into a structured `BRAINSTORM.md` (at project root) that seeds `/psd:init`. Adaptive Q&A — asks 3-7 targeted questions based on what's unclear, not a fixed checklist.

Orchestrator role: gate against existing `.planning/`, dispatch `brainstormer`, surface its summary and suggest next.
</objective>

<execution_context>
@$HOME/.claude/workflows/brainstorm.md
</execution_context>

<process>
1. **Pre-flight gates** (per workflows/brainstorm.md):
   - If `.planning/` exists → STOP, suggest `/psd:discuss [N]` instead.
   - If `BRAINSTORM.md` exists at project root → AskUserQuestion: continue/refine | start over | abort.

2. **Companion check (suggestion mode):** scan the available-skills list (system reminder at session start). If `superpowers:brainstorming` is listed, print this single line **before** dispatching the subagent:

   > FYI: `superpowers:brainstorming` is also available — a more rigorous exploration of intent. Abort and run it directly if you'd prefer; otherwise continuing with `brainstorm`.

   If not listed, skip silently.

3. **Dispatch `brainstormer`** with the user's `$ARGUMENTS` as the raw idea.

4. **Report** the brainstormer's ≤200-word summary verbatim. Suggest `/psd:init`.

Preserve all gates: never write into `.planning/`, never auto-invoke `/psd:init`, never exceed 7 questions (12 with extension), never auto-delegate to companion (suggestion only).
</process>
